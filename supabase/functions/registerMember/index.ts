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

    // --- 3. Validate Activation Token ---
    const tokenHash = await sha256Hex(activation_token);
    const { data: tokenRecord } = await admin
      .from('member_activation_tokens')
      .select('id, gym_id, created_by, token_type, month_key, expires_at, used_at, revoked_at')
      .or(`token_hash.eq.${tokenHash},raw_token.eq.${activation_token}`)
      .maybeSingle();

    let gymId: string;
    let tokenId: string | null = null;
    let tokenType = 'monthly';

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
      tokenId = tokenRecord.id;
      tokenType = tokenRecord.token_type ?? 'monthly';
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
          if (tokenYear < currentYear || (tokenYear === currentYear && tokenMonth < currentMonth)) {
            return jsonError('This activation QR has expired. Ask the gym owner to generate a new one.', 410);
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
        tokenType = 'monthly';
      } else {
        return jsonError('This QR code is not valid for LiftFlow.', 404);
      }
    } else {
      return jsonError('This QR code is not valid for LiftFlow.', 404);
    }

    // --- 4. Resolve or enroll member record ---
    let { data: memberRow } = await admin
      .from('members')
      .select('id, gym_id, profile_id, full_name')
      .eq('gym_id', gymId)
      .eq('phone', cleanPhone)
      .maybeSingle();

    if (memberRow && memberRow.profile_id) {
      return jsonError(
        'This phone number is already registered. Please log in with your username and password.',
        409,
      );
    }

    if (!memberRow) {
      const memberNumber = `M-${Math.floor(1000 + Math.random() * 9000)}`;
      const { data: newMember, error: createMemErr } = await admin
        .from('members')
        .insert({
          gym_id: gymId,
          member_number: memberNumber,
          full_name: full_name.trim(),
          phone: cleanPhone,
        })
        .select('id, gym_id, profile_id, full_name')
        .single();

      if (createMemErr || !newMember) {
        return jsonError(`Failed to enroll member: ${createMemErr?.message ?? 'database error'}`, 500);
      }
      memberRow = newMember;
    }

    const memberId: string = memberRow.id;
    const syntheticEmail = `${cleanUsername}@liftflow.internal`;

    // --- 5. Create Auth User atomically ---
    let newUserId: string;
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
      if (errLower.includes('already registered') || errLower.includes('already exists') || errLower.includes('duplicate')) {
        return jsonError(
          'This phone number is already registered. Please log in with your username and password.',
          409,
        );
      }
      return jsonError(`Account creation failed: ${signUpErr?.message ?? 'unknown error'}`, 500);
    }
    newUserId = signUpData.user.id;

    // --- 6. Handle token consumption (only for single_use tokens) & link profile/member ---
    try {
      if (tokenType === 'single_use' && tokenId) {
        // Atomic single-use token consumption with race condition prevention
        const { data: consumedToken, error: consumeErr } = await admin
          .from('member_activation_tokens')
          .update({
            used_at: new Date().toISOString(),
            used_by_profile_id: newUserId,
            updated_at: new Date().toISOString(),
          })
          .eq('id', tokenId)
          .is('used_at', null)
          .is('revoked_at', null)
          .gt('expires_at', new Date().toISOString())
          .select('id');

        if (consumeErr || !consumedToken || consumedToken.length === 0) {
          await admin.auth.admin.deleteUser(newUserId).catch(() => {});
          return jsonError(
            'This activation QR has already been consumed or has expired. Please ask your gym owner for a new QR code.',
            409,
          );
        }
      }

      // Upsert profile
      const { error: profileErr } = await admin
        .from('profiles')
        .upsert({
          user_id: newUserId,
          gym_id: gymId,
          username: cleanUsername,
          full_name: full_name.trim(),
          phone: cleanPhone,
          email: syntheticEmail,
          role: 'member',
          status: 'active',
          phone_verified: true,
          updated_at: new Date().toISOString(),
        });

      if (profileErr) {
        throw new Error(`Profile creation failed: ${profileErr.message}`);
      }

      // Link member row to newly created auth profile
      const { error: linkErr } = await admin
        .from('members')
        .update({
          profile_id: newUserId,
          status: 'active',
          updated_at: new Date().toISOString(),
        })
        .eq('id', memberId);

      if (linkErr) {
        throw new Error(`Member profile link failed: ${linkErr.message}`);
      }

      // Automatically assign default membership plan if no active membership exists
      const { data: existingMembership } = await admin
        .from('memberships')
        .select('id')
        .eq('member_id', memberId)
        .eq('status', 'active')
        .maybeSingle();

      if (!existingMembership) {
        // Find default plan or create standard 30-day onboarding membership
        const { data: defaultPlan } = await admin
          .from('membership_plans')
          .select('id, duration_days')
          .eq('gym_id', gymId)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

        const planId = defaultPlan?.id ?? null;
        const durationDays = defaultPlan?.duration_days ?? 30;
        const now = new Date();
        const expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);

        if (planId) {
          await admin.from('memberships').insert({
            gym_id: gymId,
            member_id: memberId,
            plan_id: planId,
            started_at: now.toISOString(),
            expires_at: expiresAt.toISOString(),
            status: 'active',
          });
        }
      }

      // Audit log
      try {
        await admin.from('audit_logs').insert({
          gym_id: gymId,
          actor_user_id: newUserId,
          action: 'member.registered_via_activation_qr',
          entity: 'member',
          entity_id: memberId,
          detail: { username: cleanUsername, phone: cleanPhone, activation_token_id: tokenId, token_type: tokenType },
        });
      } catch (_) {
        // Non-blocking
      }

      return jsonOk({
        message: 'Registration successful. You can now sign in with your username and password.',
        user_id: newUserId,
        member_id: memberId,
      }, 201);
    } catch (txErr: unknown) {
      // Rollback newly created Auth user to prevent orphaned state
      await admin.auth.admin.deleteUser(newUserId).catch(() => {});

      // Rollback consumed token state if this transaction marked it used (single_use only)
      if (tokenType === 'single_use' && tokenId) {
        await admin
          .from('member_activation_tokens')
          .update({
            used_at: null,
            used_by_profile_id: null,
            updated_at: new Date().toISOString(),
          })
          .eq('id', tokenId)
          .eq('used_by_profile_id', newUserId)
          .catch(() => {});
      }

      if (txErr instanceof Error) {
        const errMsg = txErr.message.toLowerCase();
        if (errMsg.includes('duplicate') || errMsg.includes('already exists') || errMsg.includes('23505') || errMsg.includes('already registered')) {
          return jsonError('Username or phone number is already registered.', 409);
        }
      }

      const msg = txErr instanceof Error ? txErr.message : String(txErr);
      return jsonError(`Registration transaction rolled back: ${msg}`, 500);
    }
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`registerMember error: ${msg}`, 500);
  }
});
