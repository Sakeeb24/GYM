import { createAdminClient, jsonOk, jsonError } from '../_shared/supabaseServer.ts';

// registerMember — public endpoint (no auth required; user does not yet exist).
// Accepts:
//   { full_name, phone, otp_token, username, password }
//
// Steps (all server-side, service_role):
//   1. Verify phone OTP token via Supabase Auth.
//   2. Look up members table by phone to resolve gym_id.
//   3. Check username uniqueness.
//   4. Create auth.users with synthetic email ({username}@liftflow.internal).
//   5. Update profiles row (created by trigger) with username, phone_verified, full_name, phone.
//   6. Return success.

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

    // --- Validate inputs ---
    if (!full_name?.trim() || full_name.trim().length < 2) {
      return jsonError('full_name must be at least 2 characters', 400);
    }
    if (!phone?.trim()) return jsonError('phone is required', 400);
    if (!otp_token?.trim()) return jsonError('otp_token is required', 400);
    if (!username || !USERNAME_RE.test(username)) {
      return jsonError('username must be 3-30 lowercase alphanumeric characters or underscores', 400);
    }
    if (!password || password.length < 8) {
      return jsonError('password must be at least 8 characters', 400);
    }

    const admin = createAdminClient();

    // --- 1. Verify the phone OTP ---
    const { data: otpData, error: otpErr } = await admin.auth.verifyOtp({
      phone,
      token: otp_token,
      type: 'sms',
    });
    if (otpErr || !otpData?.user) {
      return jsonError(`OTP verification failed: ${otpErr?.message ?? 'invalid token'}`, 400);
    }
    // otpData.user is the temporary Supabase auth user created by the OTP step.
    // We will NOT use this user — we create a fresh one with the synthetic email.
    // Sign out the OTP session immediately.
    const otpUserId = otpData.user.id;

    // --- 2. Resolve gym_id from members table by phone number ---
    const { data: memberRow } = await admin
      .from('members')
      .select('gym_id')
      .eq('phone', phone)
      .maybeSingle();

    if (!memberRow) {
      return jsonError(
        'No gym account found for this phone number. Please contact your gym to be added first.',
        404,
      );
    }
    const gymId: string = (memberRow as { gym_id: string }).gym_id;

    // --- 3. Check username uniqueness ---
    const { data: existingUsername } = await admin
      .from('profiles')
      .select('user_id')
      .eq('username', username)
      .maybeSingle();

    if (existingUsername) {
      return jsonError('Username is already taken. Please choose a different one.', 409);
    }

    // --- 4. Create auth.users with synthetic email ---
    const syntheticEmail = `${username}@liftflow.internal`;
    const { data: signUpData, error: signUpErr } = await admin.auth.admin.createUser({
      email: syntheticEmail,
      password,
      phone,
      app_metadata: { gym_id: gymId, role: 'member' },
      user_metadata: { full_name: full_name.trim() },
      email_confirm: true, // skip email verification — we verified via phone OTP
    });

    if (signUpErr || !signUpData?.user) {
      return jsonError(`Registration failed: ${signUpErr?.message ?? 'unknown error'}`, 500);
    }

    const newUserId = signUpData.user.id;

    // --- 5. Update profile (created by trigger) with username + phone_verified ---
    // Retry up to 3× since the trigger fires asynchronously.
    let profileUpdated = false;
    for (let attempt = 0; attempt < 3; attempt++) {
      await new Promise((r) => setTimeout(r, 300));
      const { error: updateErr } = await admin
        .from('profiles')
        .update({
          username,
          phone_verified: true,
          full_name: full_name.trim(),
          phone,
        })
        .eq('user_id', newUserId);
      if (!updateErr) { profileUpdated = true; break; }
    }

    if (!profileUpdated) {
      // Non-fatal: auth user created successfully; profile will be updated on next sign-in.
      console.warn(`registerMember: profile update deferred for user ${newUserId}`);
    }

    // --- 6. Clean up the temporary OTP auth user (if different from new user) ---
    if (otpUserId !== newUserId) {
      await admin.auth.admin.deleteUser(otpUserId).catch(() => {});
    }

    return jsonOk({ message: 'Registration successful. You can now sign in.' }, 201);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`registerMember error: ${msg}`, 500);
  }
});
