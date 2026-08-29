import { createAdminClient, jsonOk, jsonError } from '../_shared/supabaseServer.ts';

// registerMember — public endpoint for gym member self-onboarding.
// Ensures strict atomic linking: auth.users -> profiles -> members.profile_id
//
// Accepts:
//   { full_name, phone, otp_token, username, password }
//
// Steps (all server-side with service_role):
//   1. Verify phone OTP token via Supabase Auth Admin.
//   2. Look up members table by phone to resolve gym_id and pre-enrolled member.
//   3. Prevent duplicate account registration if member is already claimed.
//   4. Check username uniqueness.
//   5. Create auth.users with synthetic email ({username}@liftflow.internal).
//   6. Update profiles with username, phone_verified, full_name, phone.
//   7. Link pre-enrolled member: members.profile_id = newUserId.
//   8. Clean up intermediate OTP temporary user (if created).

const USERNAME_RE = /^[a-z0-9_]{3,30}$/;

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
    const cleanPhone = phone.trim();
    const admin = createAdminClient();

    // --- 2. Verify the phone OTP ---
    const { data: otpData, error: otpErr } = await admin.auth.verifyOtp({
      phone: cleanPhone,
      token: otp_token.trim(),
      type: 'sms',
    });
    if (otpErr || !otpData?.user) {
      return jsonError(`OTP verification failed: ${otpErr?.message ?? 'invalid or expired token'}`, 400);
    }
    const tempOtpUserId = otpData.user.id;

    // --- 3. Resolve member record from members table by phone ---
    const { data: memberRow, error: memberErr } = await admin
      .from('members')
      .select('id, gym_id, profile_id, full_name')
      .eq('phone', cleanPhone)
      .maybeSingle();

    if (memberErr || !memberRow) {
      return jsonError(
        'No gym membership found for this phone number. Please contact your gym front desk to enroll first.',
        404,
      );
    }

    // --- 4. Prevent duplicate registration if already claimed ---
    if (memberRow.profile_id != null) {
      return jsonError('This gym member account has already been registered. Please sign in instead.', 409);
    }

    const gymId: string = memberRow.gym_id;
    const memberId: string = memberRow.id;

    // --- 5. Check username uniqueness in profiles ---
    const { data: existingProfile } = await admin
      .from('profiles')
      .select('user_id')
      .eq('username', cleanUsername)
      .maybeSingle();

    if (existingProfile) {
      return jsonError('Username is already taken. Please choose another username.', 409);
    }

    // --- 6. Create permanent auth.users with synthetic email & tenant metadata ---
    const syntheticEmail = `${cleanUsername}@liftflow.internal`;
    const { data: signUpData, error: signUpErr } = await admin.auth.admin.createUser({
      email: syntheticEmail,
      password,
      phone: cleanPhone,
      app_metadata: { gym_id: gymId, role: 'member' },
      user_metadata: { full_name: full_name.trim() },
      email_confirm: true, // skip email confirmation — verified by phone OTP
    });

    if (signUpErr || !signUpData?.user) {
      return jsonError(`Account creation failed: ${signUpErr?.message ?? 'unknown error'}`, 500);
    }

    const newUserId = signUpData.user.id;

    // --- 7. Update/Upsert profile with username + phone_verified ---
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
      console.warn(`registerMember: profile upsert warning: ${profileErr.message}`);
    }

    // --- 8. Link the member record: members.profile_id = newUserId ---
    const { error: linkErr } = await admin
      .from('members')
      .update({
        profile_id: newUserId,
        full_name: full_name.trim(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', memberId);

    if (linkErr) {
      return jsonError(`Failed to link member record: ${linkErr.message}`, 500);
    }

    // --- 9. Clean up temporary OTP user (if different from new user) ---
    if (tempOtpUserId && tempOtpUserId !== newUserId) {
      await admin.auth.admin.deleteUser(tempOtpUserId).catch(() => {});
    }

    // --- 10. Write audit log ---
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
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`registerMember error: ${msg}`, 500);
  }
});
