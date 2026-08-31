import { createAdminClient, jsonOk, jsonError } from '../_shared/supabaseServer.ts';

// registerMember — production endpoint for gym member registration via owner QR activation.
// Validates owner-issued single-use short-lived activation token.
// Ensures strict atomic linking: auth.users -> profiles -> members.profile_id
// Protects against account takeover: NEVER overwrites credentials of an existing account.
//
// Accepts:
//   { full_name, phone, activation_token, username, password }

const USERNAME_RE = /^[a-z0-9_]{3,30}$/;

async function sha256Hex(str: string): Promise<string> {
  const data = new TextEncoder().encode(str);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

function normalizePhone(raw: string): string {
  let cleaned = raw.replaceAll(/[\s\-()]/g, '');
  if (cleaned.startsWith('00')) {
    cleaned = '+' + cleaned.slice(2);
  } else if (cleaned.startsWith('0') && cleaned.length === 11) {
    cleaned = '+91' + cleaned.slice(1);
  } else if (!cleaned.startsWith('+')) {
    cleaned = cleaned.length === 10 ? `+91${cleaned}` : `+${cleaned}`;
  }
  return cleaned;
}

interface RegisterReq {
  full_name: string;
  phone: string;
  activation_token: string;
  username: string;
  password: string;
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
      },
    });
  }

  if (req.method !== 'POST') return jsonError('Method not allowed', 405);

  try {
    const body: RegisterReq = await req.json();
    let { full_name, phone, activation_token, username, password } = body;

    // --- 1. Validate inputs ---
    if (!full_name?.trim() || full_name.trim().length < 2) {
      return jsonError('Full name must be at least 2 characters', 400);
    }
    if (!phone?.trim()) return jsonError('Phone number is required', 400);
    if (!activation_token?.trim()) {
      return jsonError('Gym activation token is required. Please scan the QR code displayed by your gym owner.', 400);
    }
    if (!username || !USERNAME_RE.test(username.toLowerCase().trim())) {
      return jsonError('Username must be 3-30 lowercase alphanumeric characters or underscores', 400);
    }
    if (!password || password.length < 8) {
      return jsonError('Password must be at least 8 characters', 400);
    }

    // Clean / extract token
    activation_token = activation_token.trim();
    if (activation_token.startsWith('liftflow://member-activation/')) {
      activation_token = activation_token.replace('liftflow://member-activation/', '').trim();
    } else if (activation_token.includes('/activate/')) {
      activation_token = activation_token.split('/activate/')[1].trim();
    }

    if (activation_token.length < 16) {
      return jsonError('This QR code is not valid for LiftFlow.', 400);
    }

    const cleanUsername = username.toLowerCase().trim();
    const cleanPhone = normalizePhone(phone);
    const admin = createAdminClient();

    // --- 2. Check for Duplicate Completed Account (Account Takeover Prevention) ---
    // Check if an existing profile with this phone is already registered
    const { data: existingProfileByPhone } = await admin
      .from('profiles')
      .select('user_id, username')
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
    const { data: tokenRecord, error: tokenFetchErr } = await admin
      .from('member_activation_tokens')
      .select('id, gym_id, created_by, expires_at, used_at, revoked_at')
      .eq('token_hash', tokenHash)
      .maybeSingle();

    if (tokenFetchErr || !tokenRecord) {
      return jsonError('This QR code is not valid for LiftFlow.', 404);
    }

    if (tokenRecord.revoked_at) {
      return jsonError('This activation QR has been refreshed or canceled. Ask the gym owner for a new QR code.', 410);
    }

    if (tokenRecord.used_at) {
      return jsonError('This activation QR has already been used. Ask the gym owner for a new QR code.', 410);
    }

    const expiresAt = new Date(tokenRecord.expires_at);
    if (expiresAt.getTime() <= Date.now()) {
      return jsonError('This activation QR has expired. Ask the gym owner to generate a new one.', 410);
    }

    const gymId = tokenRecord.gym_id;
    const tokenId = tokenRecord.id;

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

    // --- 6. Atomically consume activation token & link profile/member with rollback ---
    try {
      // Atomic token consumption with race condition prevention
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
        throw new Error('This activation QR has already been consumed or has expired. Please ask your gym owner for a new QR code.');
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

      if (profileErr) throw new Error(`Profile creation failed: ${profileErr.message}`);

      // Link member
      const { error: linkErr } = await admin
        .from('members')
        .update({
          profile_id: newUserId,
          full_name: full_name.trim(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', memberId);

      if (linkErr) throw new Error(`Member linking failed: ${linkErr.message}`);

      // Ensure active membership exists
      const { data: activeMem } = await admin
        .from('memberships')
        .select('id')
        .eq('member_id', memberId)
        .maybeSingle();

      if (!activeMem) {
        await admin.from('memberships').insert({
          gym_id: gymId,
          member_id: memberId,
          plan_id: 'b0000000-0000-0000-0000-000000000001',
          started_at: new Date().toISOString(),
          expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
          status: 'active',
        });
      }

      // Write audit log
      try {
        await admin.from('audit_logs').insert({
          gym_id: gymId,
          actor_user_id: newUserId,
          action: 'member.registered',
          entity: 'member',
          entity_id: memberId,
          detail: { username: cleanUsername, phone: cleanPhone, activation_token_id: tokenId },
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
      const msg = txErr instanceof Error ? txErr.message : String(txErr);
      return jsonError(`Registration transaction rolled back: ${msg}`, 500);
    }
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`registerMember error: ${msg}`, 500);
  }
});
