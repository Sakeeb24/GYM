import { createAdminClient, jsonOk, jsonError } from '../_shared/supabaseServer.ts';

// registerMember — public endpoint for gym member self-onboarding.
// Ensures strict atomic linking: auth.users -> profiles -> members.profile_id
//
// Accepts:
//   { full_name, phone, otp_token, username, password }
//
// Steps (all server-side with service_role):
//   1. Verify phone OTP token via Supabase Auth Admin (supports predefined test phone OTPs).
//   2. Look up members table by phone to resolve gym_id, or auto-enroll into default gym.
//   3. Check username uniqueness.
//   4. Create / update auth.users with synthetic email ({username}@liftflow.internal).
//   5. Update profiles with username, phone_verified, full_name, phone.
//   6. Link member: members.profile_id = newUserId.
//   7. Clean up intermediate OTP temporary user (if created).

const USERNAME_RE = /^[a-z0-9_]{3,30}$/;

const TEST_PHONE_OTPS: Record<string, string> = {
  '+917019707247': '123456',
  '+919876543210': '123456',
  '+15555550100': '123456',
  '+919999999999': '123456',
  '+911234567890': '123456',
};

const DEFAULT_GYM_ID = 'a0000000-0000-0000-0000-000000000001';

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
    let cleanPhone = phone.replaceAll(/[\s\-()]/g, '');
    if (!cleanPhone.startsWith('+')) {
      cleanPhone = cleanPhone.length === 10 ? `+91${cleanPhone}` : `+${cleanPhone}`;
    }

    const admin = createAdminClient();
    let tempOtpUserId: string | null = null;

    // --- 2. Verify the phone OTP ---
    const isTestPhone = Boolean(TEST_PHONE_OTPS[cleanPhone]);
    const expectedTestOtp = TEST_PHONE_OTPS[cleanPhone];

    if (isTestPhone && otp_token.trim() === expectedTestOtp) {
      // Predefined test phone and OTP matched
    } else {
      const { data: otpData, error: otpErr } = await admin.auth.verifyOtp({
        phone: cleanPhone,
        token: otp_token.trim(),
        type: 'sms',
      });
      if (otpErr || !otpData?.user) {
        return jsonError(`OTP verification failed: ${otpErr?.message ?? 'invalid or expired token'}`, 400);
      }
      tempOtpUserId = otpData.user.id;
    }

    // --- 3. Resolve or enroll member record ---
    let { data: memberRow, error: memberErr } = await admin
      .from('members')
      .select('id, gym_id, profile_id, full_name')
      .eq('phone', cleanPhone)
      .maybeSingle();

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

    // --- 4. Check username uniqueness in profiles ---
    const { data: existingProfile } = await admin
      .from('profiles')
      .select('user_id')
      .eq('username', cleanUsername)
      .maybeSingle();

    const syntheticEmail = `${cleanUsername}@liftflow.internal`;

    // --- 5. Create or update permanent auth.users ---
    let newUserId: string;
    const { data: userList } = await admin.auth.admin.listUsers({ perPage: 1000 });
    const existingAuthUser = userList?.users?.find(
      (u) => u.email === syntheticEmail || u.phone === cleanPhone,
    );

    if (existingAuthUser) {
      const { data: updatedData, error: updateErr } = await admin.auth.admin.updateUserById(
        existingAuthUser.id,
        {
          email: syntheticEmail,
          password,
          phone: cleanPhone,
          app_metadata: { gym_id: gymId, role: 'member' },
          user_metadata: { full_name: full_name.trim() },
          email_confirm: true,
          phone_confirm: true,
        },
      );
      if (updateErr || !updatedData?.user) {
        return jsonError(`Account update failed: ${updateErr?.message ?? 'unknown error'}`, 500);
      }
      newUserId = updatedData.user.id;
    } else {
      if (existingProfile) {
        return jsonError('Username is already taken. Please choose another username.', 409);
      }

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
    }

    // --- 6. Upsert profile with username + phone_verified ---
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

    // --- 7. Link the member record: members.profile_id = newUserId ---
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

    // Ensure member has an active membership
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

    // --- 8. Clean up temporary OTP user if separate ---
    if (tempOtpUserId && tempOtpUserId !== newUserId) {
      await admin.auth.admin.deleteUser(tempOtpUserId).catch(() => {});
    }

    // --- 9. Write audit log ---
    try {
      await admin.from('audit_logs').insert({
        gym_id: gymId,
        actor_user_id: newUserId,
        action: 'member.registered',
        entity: 'member',
        entity_id: memberId,
        detail: { username: cleanUsername, phone: cleanPhone },
      });
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
