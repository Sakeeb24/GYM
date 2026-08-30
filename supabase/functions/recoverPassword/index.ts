import { createAdminClient, jsonOk, jsonError } from '../_shared/supabaseServer.ts';

// recoverPassword — Secure password recovery flow.
// Step 1: action = 'request_otp' -> locates account by username, dispatches SMS OTP to registered phone.
// Step 2: action = 'reset_password' -> verifies OTP, securely updates password on auth.users.

const DEV_TEST_PHONE_OTPS: Record<string, string> = {
  '+917019707247': '123456',
  '+919876543210': '123456',
  '+15555550100': '123456',
};

function maskPhone(phone: string): string {
  if (phone.length <= 4) return '****';
  const visibleStart = phone.slice(0, 3);
  const visibleEnd = phone.slice(-4);
  return `${visibleStart} *** *** ${visibleEnd}`;
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
    const body = await req.json();
    const { action, username, otp_token, new_password } = body;

    if (!username?.trim()) {
      return jsonError('Username is required', 400);
    }

    const cleanUsername = username.toLowerCase().trim();
    const admin = createAdminClient();
    const isProduction = Deno.env.get('ENVIRONMENT') === 'production';

    // Find profile
    const { data: profile, error: profErr } = await admin
      .from('profiles')
      .select('user_id, gym_id, phone, full_name')
      .eq('username', cleanUsername)
      .maybeSingle();

    if (profErr || !profile) {
      return jsonError('No account found with this username', 404);
    }

    if (!profile.phone) {
      return jsonError('No phone number is registered for this account. Please contact gym staff.', 400);
    }

    if (action === 'request_otp') {
      // Step 1: Send OTP to the registered phone
      const isDevTest = !isProduction && Boolean(DEV_TEST_PHONE_OTPS[profile.phone]);
      if (!isDevTest) {
        const { error: otpSendErr } = await admin.auth.signInWithOtp({
          phone: profile.phone,
        });
        if (otpSendErr) {
          return jsonError(`Failed to send SMS OTP: ${otpSendErr.message}`, 500);
        }
      }

      return jsonOk({
        message: 'OTP sent to your registered phone number.',
        masked_phone: maskPhone(profile.phone),
        phone: isDevTest ? profile.phone : undefined,
      });
    } else if (action === 'reset_password') {
      // Step 2: Verify OTP and update password
      if (!otp_token?.trim()) return jsonError('OTP code is required', 400);
      if (!new_password || new_password.length < 8) {
        return jsonError('New password must be at least 8 characters', 400);
      }

      const isDevTest = !isProduction && DEV_TEST_PHONE_OTPS[profile.phone] === otp_token.trim();

      if (!isDevTest) {
        const { error: verifyErr } = await admin.auth.verifyOtp({
          phone: profile.phone,
          token: otp_token.trim(),
          type: 'sms',
        });
        if (verifyErr) {
          return jsonError(`Invalid or expired OTP: ${verifyErr.message}`, 400);
        }
      }

      // Update password on auth user
      const { error: updateErr } = await admin.auth.admin.updateUserById(
        profile.user_id,
        { password: new_password },
      );

      if (updateErr) {
        return jsonError(`Failed to update password: ${updateErr.message}`, 500);
      }

      // Write audit log
      await admin.from('audit_logs').insert({
        gym_id: profile.gym_id,
        actor_user_id: profile.user_id,
        action: 'user.password_reset',
        entity: 'profile',
        entity_id: profile.user_id,
        detail: { username: cleanUsername },
      }).catch(() => {});

      return jsonOk({
        message: 'Password has been reset successfully. Please log in with your new password.',
      });
    } else {
      return jsonError("Invalid action. Must be 'request_otp' or 'reset_password'", 400);
    }
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`recoverPassword error: ${msg}`, 500);
  }
});
