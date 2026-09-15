import { createAdminClient, jsonOk, jsonError, corsHeaders } from '../_shared/supabaseServer.ts';

// registerMember: Public endpoint called by the prospective member app
// when completing account setup from an activation QR code.
// Validates gym activation token (monthly reusable or single-use),
// enforces username uniqueness and phone format/uniqueness,
// and creates the member record, auth user, profile, and active membership atomically.

async function sha256Hex(str: string): Promise<string> {
  const data = new TextEncoder().encode(str);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

interface RegisterReq {
  full_name: string;
  phone: string;
  username?: string;
  password?: string;
  activation_token: string;
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (req.method !== 'POST') return jsonError('Method not allowed', 405);

  try {
    const body: RegisterReq = await req.json();
    let { full_name, phone, username, password, activation_token } = body;

    // --- 1. Validate required fields ---
    if (!full_name?.trim()) return jsonError('Full name is required', 400);
    if (!phone?.trim()) return jsonError('Phone number is required', 400);
    if (!activation_token?.trim()) return jsonError('Activation token is required', 400);

    // Support deep link or raw token
    activation_token = activation_token.trim();
    if (activation_token.startsWith('liftflow://member-activation/')) {
      activation_token = activation_token.replace('liftflow://member-activation/', '').trim();
    } else if (activation_token.includes('/activate/')) {
      activation_token = activation_token.split('/activate/')[1].trim();
    }

    if (!username?.trim()) {
      return jsonError('Username is required for zero-OTP member registration.', 400);
    }
    if (!password || password.length < 8) {
      return jsonError('Password must be at least 8 characters.', 400);
    }

    // --- 2. Clean and format inputs ---
    let cleanPhone = phone.trim().replace(/[\s\-()]/g, '');
    if (!cleanPhone.startsWith('+')) {
      if (/^\d{10}$/.test(cleanPhone)) {
        cleanPhone = `+91${cleanPhone}`;
      } else {
        cleanPhone = `+${cleanPhone}`;
      }
    }

    const cleanUsername = username.trim().toLowerCase();
    if (!/^[a-z0-9_]{3,30}$/.test(cleanUsername)) {
      return jsonError('Username must be 3-30 characters (letters, numbers, underscores only).', 400);
    }

    const admin = createAdminClient();

    // Check if phone is already registered on profiles
    const { data: existingProfileByPhone } = await admin
      .from('profiles')
      .select('user_id')
      .eq('phone', cleanPhone)
      .maybeSingle();

    if (existingProfileByPhone) {
      return jsonError(
        'This phone number is already registered. Please log in with your username and password.',
        409,
      );
    }

    // Check if username is already taken
    const { data: existingProfileByUsername } = await admin
      .from('profiles')
      .select('user_id')
      .eq('username', cleanUsername)
      .maybeSingle();

    if (existingProfileByUsername) {
      return jsonError('Username is already taken. Please choose another username.', 409);
    }

    if (!/^[a-zA-Z0-9_\-]+$/.test(activation_token)) {
      return jsonError('This activation token is invalid.', 400);
    }

    // --- 3. Pre-validate activation token & resolve gymId for Auth user app_metadata ---
    const tokenHash = await sha256Hex(activation_token);
    const { data: tokenRecord } = await admin
      .from('member_activation_tokens')
      .select('id, gym_id, created_by, token_type, month_key, expires_at, used_at, revoked_at')
      .eq('token_hash', tokenHash)
      .maybeSingle();

    let gymId: string;

    if (tokenRecord) {
      if (tokenRecord.revoked_at) {
        return jsonError('This activation QR has been refreshed or canceled. Ask the gym owner for a new QR code.', 410);
      }
      if (tokenRecord.token_type === 'single_use' && tokenRecord.used_at) {
        return jsonError('This activation QR has already been used. Ask the gym owner for a new QR code.', 410);
      }
      const expiresAt = new Date(tokenRecord.expires_at);
      if (expiresAt.getTime() <= Date.now()) {
        return jsonError('This activation QR has expired. Ask the gym owner to generate a new one.', 410);
      }
      gymId = tokenRecord.gym_id;
    } else if (activation_token.startsWith('act_')) {
      const parts = activation_token.split('_');
      if (parts.length >= 4) {
        const slug = parts.slice(1, parts.length - 2).join('_');
        const tokenYear = parseInt(parts[parts.length - 2], 10);
        const tokenMonth = parseInt(parts[parts.length - 1], 10);

        const now = new Date();
        const currentYear = now.getUTCFullYear();
        const currentMonth = now.getUTCMonth() + 1;

        if (!isNaN(tokenYear) && !isNaN(tokenMonth)) {
          if (tokenYear !== currentYear || tokenMonth !== currentMonth) {
            if (tokenYear < currentYear || (tokenYear === currentYear && tokenMonth < currentMonth)) {
              return jsonError('This activation QR has expired. Ask the gym owner to generate a new one.', 410);
            } else {
              return jsonError('This activation QR is not valid for the current month.', 400);
            }
          }
        }

        const { data: gym } = await admin
          .from('gyms')
          .select('id, is_active')
          .eq('slug', slug)
          .maybeSingle();
        if (!gym || !gym.is_active) {
          return jsonError('This QR code is not valid for LiftFlow.', 404);
        }
        gymId = gym.id;
      } else {
        return jsonError('This QR code is not valid for LiftFlow.', 404);
      }
    } else {
      return jsonError('This QR code is not valid for LiftFlow.', 404);
    }

    const syntheticEmail = `${cleanUsername}@liftflow.internal`;

    // --- 4. Create Supabase Auth User with gym_id & role app_metadata ---
    const { data: signUpData, error: signUpErr } = await admin.auth.admin.createUser({
      email: syntheticEmail,
      password,
      phone: cleanPhone,
      app_metadata: { gym_id: gymId, role: 'member' },
      user_metadata: { full_name: full_name.trim() },
      email_confirm: true,
      phone_confirm: true,
    });

    if (signUpErr || !signUpData?.user) {
      const errLower = (signUpErr?.message ?? '').toLowerCase();
      const isAlreadyRegistered =
        errLower.includes('already registered') ||
        errLower.includes('already been registered') ||
        errLower.includes('already exists') ||
        errLower.includes('duplicate') ||
        errLower.includes('email address has already') ||
        errLower.includes('phone number has already') ||
        (signUpErr as any)?.code === 'user_already_exists' ||
        (signUpErr as any)?.code === 'email_exists' ||
        (signUpErr as any)?.status === 422;

      if (isAlreadyRegistered) {
        return jsonError(
          'This phone number or username is already registered. Please log in with your credentials.',
          409,
        );
      }
      return jsonError(`Account creation failed: ${signUpErr?.message ?? 'unknown error'}`, 500);
    }

    const newUserId = signUpData.user.id;

    // --- 5. Call Atomic Database RPC (complete_member_registration) ---
    const { data: rpcData, error: rpcErr } = await admin.rpc('complete_member_registration', {
      p_user_id: newUserId,
      p_full_name: full_name.trim(),
      p_phone: cleanPhone,
      p_username: cleanUsername,
      p_email: syntheticEmail,
      p_activation_token: activation_token,
      p_token_hash: tokenHash,
    });

    if (rpcErr) {
      // Manual compensation: Remove orphaned Auth user when DB transaction fails/rolls back
      await admin.auth.admin.deleteUser(newUserId).catch(() => {});

      const errMsg = rpcErr.message || '';

      if (
        errMsg.includes('PHONE_ALREADY_REGISTERED') ||
        errMsg.includes('idx_profiles_phone_unique') ||
        (errMsg.includes('23505') && errMsg.includes('phone'))
      ) {
        return jsonError(
          'This phone number is already registered. Please log in with your username and password.',
          409,
        );
      }
      if (
        errMsg.includes('USERNAME_ALREADY_TAKEN') ||
        errMsg.includes('profiles_username_key') ||
        errMsg.includes('idx_profiles_username') ||
        (errMsg.includes('23505') && errMsg.includes('username'))
      ) {
        return jsonError('Username is already taken. Please choose another username.', 409);
      }
      if (errMsg.includes('TOKEN_REVOKED')) {
        return jsonError('This activation QR has been refreshed or canceled. Ask the gym owner for a new QR code.', 410);
      }
      if (errMsg.includes('TOKEN_ALREADY_USED')) {
        return jsonError('This activation QR has already been consumed or has expired. Please ask your gym owner for a new QR code.', 409);
      }
      if (errMsg.includes('TOKEN_EXPIRED')) {
        return jsonError('This activation QR has expired. Ask the gym owner to generate a new one.', 410);
      }
      if (errMsg.includes('TOKEN_INVALID_MONTH')) {
        return jsonError('This activation QR is not valid for the current month.', 400);
      }
      if (errMsg.includes('TOKEN_INVALID')) {
        return jsonError('This QR code is not valid for LiftFlow.', 404);
      }

      return jsonError(`Registration transaction rolled back: ${errMsg}`, 500);
    }

    const memberId = rpcData?.member_id;
    const gymId = rpcData?.gym_id;
    const tokenId = rpcData?.token_id;
    const tokenType = rpcData?.token_type ?? 'monthly';

    // --- 5. Audit log (Non-blocking) ---
    try {
      if (gymId && memberId) {
        await admin.from('audit_logs').insert({
          gym_id: gymId,
          actor_user_id: newUserId,
          action: 'member.registered_via_activation_qr',
          entity: 'member',
          entity_id: memberId,
          detail: { username: cleanUsername, phone: cleanPhone, activation_token_id: tokenId, token_type: tokenType },
        });
      }
    } catch (_) {
      // Non-blocking audit log
    }

    return jsonOk({
      message: 'Registration successful. You can now sign in with your username and password.',
      user_id: newUserId,
      member_id: memberId,
    }, 201);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`registerMember error: ${msg}`, 500);
  }
});
