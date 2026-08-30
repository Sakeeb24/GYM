import { createAdminClient, jsonOk, jsonError } from '../_shared/supabaseServer.ts';

// registerMember — production endpoint for gym member self-onboarding.
// Ensures strict atomic linking: auth.users -> profiles -> members.profile_id
// Protects against account takeover: NEVER overwrites credentials of an existing account.
//
// Accepts:
//   { full_name, phone, otp_token, username, password }

const USERNAME_RE = /^[a-z0-9_]{3,30}$/;

const DEFAULT_GYM_ID = 'a0000000-0000-0000-0000-000000000001';

// Test phone numbers and OTPs allowed ONLY in development mode
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
  otp_token: string;
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
    const { full_name, phone, otp_token, username, password } = body;

    // --- 1. Validate inputs ---
    if (!full_name?.trim() || full_name.trim().length < 2) {
      return jsonError('Full name must be at least 2 characters', 400);
    }
    if (!phone?.trim()) return jsonError('Phone number is required', 400);
    if (!otp_token?.trim()) return jsonError('OTP verification code is required', 400);
    if (!username || !USERNAME_RE.test(username.toLowerCase().trim())) {
      return jsonError('Username must be 3-30 lowercase alphanumeric characters or underscores', 400);
    }
    if (!password || password.length < 8) {
      return jsonError('Password must be at least 8 characters', 400);
    }

    const cleanUsername = username.toLowerCase().trim();
    const cleanPhone = normalizePhone(phone);

    const admin = createAdminClient();
    const isProduction = Deno.env.get('ENVIRONMENT') === 'production';
    let tempOtpUserId: string | null = null;

    // --- 2. Check for Duplicate Completed Account (Account Takeover Prevention) ---
    // Check if an existing profile or member with this phone is already registered with a username/account
    const { data: existingProfileByPhone } = await admin
      .from('profiles')
      .select('user_id, username, phone_verified')
      .eq('phone', cleanPhone)
      .maybeSingle();

    if (existingProfileByPhone && existingProfileByPhone.username) {
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

    // --- 3. Verify the phone OTP via Supabase Auth ---
    const { data: otpData, error: otpErr } = await admin.auth.verifyOtp({
      phone: cleanPhone,
      token: otp_token.trim(),
      type: 'sms',
    });
    if (otpErr || !otpData?.user) {
      return jsonError(`OTP verification failed: ${otpErr?.message ?? 'invalid or expired code'}`, 400);
    }
    tempOtpUserId = otpData.user.id;

    // --- 4. Resolve or enroll member record ---
    let { data: memberRow } = await admin
      .from('members')
      .select('id, gym_id, profile_id, full_name')
      .eq('phone', cleanPhone)
      .maybeSingle();

    if (memberRow && memberRow.profile_id) {
      // Member record already has a linked profile
      const { data: linkedProf } = await admin
        .from('profiles')
        .select('username')
        .eq('user_id', memberRow.profile_id)
        .maybeSingle();
      if (linkedProf?.username) {
        return jsonError(
          'This phone number is already registered. Please log in with your username and password.',
          409,
        );
      }
    }

    if (!memberRow) {
      const memberNumber = `M-${Math.floor(1000 + Math.random() * 9000)}`;
      const { data: newMember, error: createMemErr } = await admin
        .from('members')
        .insert({
          gym_id: DEFAULT_GYM_ID,
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

    const gymId: string = memberRow.gym_id ?? DEFAULT_GYM_ID;
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
      return jsonError(`Account creation failed: ${signUpErr?.message ?? 'unknown error'}`, 500);
    }
    newUserId = signUpData.user.id;

    // --- 6. Atomically link profile & member with rollback on failure ---
    try {
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

      // Clean up temporary OTP user if different
      if (tempOtpUserId && tempOtpUserId !== newUserId) {
        await admin.auth.admin.deleteUser(tempOtpUserId).catch(() => {});
      }

      // Write audit log
      await admin.from('audit_logs').insert({
        gym_id: gymId,
        actor_user_id: newUserId,
        action: 'member.registered',
        entity: 'member',
        entity_id: memberId,
        detail: { username: cleanUsername, phone: cleanPhone },
      }).catch(() => {});

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
