import { createAdminClient, jsonOk, jsonError } from '../_shared/supabaseServer.ts';

// registerOwner — server-side owner registration + gym provisioning.
//
// SECURITY CONTRACT:
//   • Caller must supply the OWNER_SETUP_SECRET (env var). Validated server-side.
//   • role='owner' is assigned here — never accepted from the Flutter client.
//   • Service-role key never leaves this function.
//   • Gym, gym_settings, auth user, and profile are provisioned atomically.
//     Any sub-step failure triggers a full rollback.
//
// Accepts:
//   { gym_name, gym_slug?, full_name, phone, username, password, setup_secret }

const USERNAME_RE = /^[a-z0-9_]{3,30}$/;
const SLUG_RE     = /^[a-z0-9][a-z0-9-]{1,48}[a-z0-9]$|^[a-z0-9]{2,50}$/;

// ── helpers ──────────────────────────────────────────────────────────────────

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

function slugify(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '')
    .replace(/--+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 50);
}

// Constant-time string comparison to resist timing attacks.
function safeEquals(a: string, b: string): boolean {
  if (a.length !== b.length) {
    // Still do a full comparison to keep timing consistent.
    let diff = 0;
    const shorter = a.length < b.length ? a : b;
    const longer  = a.length < b.length ? b : a;
    for (let i = 0; i < longer.length; i++) {
      diff |= (shorter.charCodeAt(i % shorter.length) ^ longer.charCodeAt(i));
    }
    return diff === 0 && false; // lengths differ → always false
  }
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= (a.charCodeAt(i) ^ b.charCodeAt(i));
  }
  return diff === 0;
}

// ── main handler ──────────────────────────────────────────────────────────────

interface RegisterOwnerReq {
  gym_name: string;
  gym_slug?: string;
  full_name: string;
  phone: string;
  username: string;
  password: string;
  setup_secret: string;
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
    const body: RegisterOwnerReq = await req.json();
    const {
      gym_name,
      full_name,
      phone,
      username,
      password,
      setup_secret,
    } = body;

    // ── 1. Validate OWNER_SETUP_SECRET ───────────────────────────────────────
    const expectedSecret = Deno.env.get('OWNER_SETUP_SECRET');
    if (!expectedSecret) {
      return jsonError('Owner setup is not configured on this server. Contact support.', 503);
    }
    if (!setup_secret?.trim() || !safeEquals(setup_secret.trim(), expectedSecret)) {
      return jsonError('Invalid setup code. Please contact LiftFlow support.', 403);
    }

    // ── 2. Validate inputs ───────────────────────────────────────────────────
    if (!gym_name?.trim() || gym_name.trim().length < 2) {
      return jsonError('Gym name must be at least 2 characters.', 400);
    }
    if (gym_name.trim().length > 100) {
      return jsonError('Gym name must be 100 characters or fewer.', 400);
    }
    if (!full_name?.trim() || full_name.trim().length < 2) {
      return jsonError('Full name must be at least 2 characters.', 400);
    }
    if (!phone?.trim()) {
      return jsonError('Phone number is required.', 400);
    }
    if (!username || !USERNAME_RE.test(username.toLowerCase().trim())) {
      return jsonError('Username must be 3–30 lowercase letters, digits, or underscores.', 400);
    }
    if (!password || password.length < 8) {
      return jsonError('Password must be at least 8 characters.', 400);
    }

    // ── 3. Normalize values ──────────────────────────────────────────────────
    const cleanGymName   = gym_name.trim();
    const rawSlug        = body.gym_slug?.trim() || slugify(cleanGymName);
    const cleanSlug      = slugify(rawSlug);
    const cleanUsername  = username.toLowerCase().trim();
    const cleanPhone     = normalizePhone(phone.trim());
    const syntheticEmail = `${cleanUsername}@liftflow.internal`;
    const cleanFullName  = full_name.trim();

    if (!SLUG_RE.test(cleanSlug)) {
      return jsonError(
        'Gym slug must be 2–50 characters: lowercase letters, digits, and hyphens only.',
        400,
      );
    }

    const admin = createAdminClient();

    // ── 4. Uniqueness pre-checks (fail fast, no writes yet) ──────────────────
    const { data: existingSlug } = await admin
      .from('gyms')
      .select('id')
      .eq('slug', cleanSlug)
      .maybeSingle();

    if (existingSlug) {
      return jsonError(
        `Gym slug "${cleanSlug}" is already taken. Please choose a different gym name or slug.`,
        409,
      );
    }

    const { data: existingUsername } = await admin
      .from('profiles')
      .select('user_id')
      .eq('username', cleanUsername)
      .maybeSingle();

    if (existingUsername) {
      return jsonError('Username is already taken. Please choose a different username.', 409);
    }

    const { data: existingPhone } = await admin
      .from('profiles')
      .select('user_id')
      .eq('phone', cleanPhone)
      .maybeSingle();

    if (existingPhone) {
      return jsonError(
        'A LiftFlow account with this phone number already exists. Please sign in.',
        409,
      );
    }

    // ── 5. Create Gym (write phase begins here) ──────────────────────────────
    let gymId: string;

    const { data: gymRow, error: gymErr } = await admin
      .from('gyms')
      .insert({
        name:      cleanGymName,
        slug:      cleanSlug,
        is_active: true,
      })
      .select('id')
      .single();

    if (gymErr || !gymRow) {
      return jsonError(`Failed to create gym: ${gymErr?.message ?? 'database error'}`, 500);
    }
    gymId = gymRow.id;

    // ── 6. Create gym_settings (defaults) ────────────────────────────────────
    const { error: settingsErr } = await admin
      .from('gym_settings')
      .insert({
        gym_id:                      gymId,
        inactivity_threshold_days:   7,
        streak_required_consecutive: 1,
        qr_mode:                     'static',
        qr_session_grace_minutes:    5,
        reminder_windows_days:       [14, 7, 3],
        renewal_post_expiry_days:    3,
        notification_channels:       ['push', 'email'],
        daily_summary_time:          '08:00',
      });

    if (settingsErr) {
      // Rollback gym
      await admin.from('gyms').delete().eq('id', gymId);
      return jsonError(`Failed to create gym settings: ${settingsErr.message}`, 500);
    }

    // ── 7. Create Auth User ───────────────────────────────────────────────────
    let newUserId: string;

    const { data: signUpData, error: signUpErr } = await admin.auth.admin.createUser({
      email:         syntheticEmail,
      password,
      phone:         cleanPhone,
      app_metadata:  { gym_id: gymId, role: 'owner' },
      user_metadata: { full_name: cleanFullName },
      email_confirm: true,
      phone_confirm: true,
    });

    if (signUpErr || !signUpData?.user) {
      // Rollback gym (cascade removes gym_settings)
      await admin.from('gyms').delete().eq('id', gymId);
      const errMsg = (signUpErr?.message ?? '').toLowerCase();
      if (errMsg.includes('already registered') || errMsg.includes('already exists')) {
        return jsonError(
          'An account with this username already exists. Please choose a different username.',
          409,
        );
      }
      return jsonError(
        `Owner account creation failed: ${signUpErr?.message ?? 'unknown error'}`,
        500,
      );
    }
    newUserId = signUpData.user.id;

    // ── 8. Upsert profile (adds username; trigger may have already created base row) ──
    try {
      const { error: profileErr } = await admin
        .from('profiles')
        .upsert({
          user_id:    newUserId,
          gym_id:     gymId,
          username:   cleanUsername,
          full_name:  cleanFullName,
          phone:      cleanPhone,
          email:      syntheticEmail,
          role:       'owner',
          status:     'active',
          phone_verified: true,
          updated_at: new Date().toISOString(),
        });

      if (profileErr) {
        throw new Error(`Profile upsert failed: ${profileErr.message}`);
      }

      // ── 9. Audit log ─────────────────────────────────────────────────────
      await admin.from('audit_logs').insert({
        gym_id:        gymId,
        actor_user_id: newUserId,
        action:        'owner.registered',
        entity:        'gym',
        entity_id:     gymId,
        detail: {
          gym_name:  cleanGymName,
          gym_slug:  cleanSlug,
          username:  cleanUsername,
          phone:     cleanPhone,
        },
      });

      return jsonOk({
        message:  'Gym and owner account created successfully. You can now sign in.',
        user_id:  newUserId,
        gym_id:   gymId,
        gym_name: cleanGymName,
        gym_slug: cleanSlug,
      }, 201);
    } catch (txErr: unknown) {
      // Rollback: delete auth user (gym cascade will be left; delete explicitly)
      try {
        await admin.auth.admin.deleteUser(newUserId);
      } catch {}
      await admin.from('gyms').delete().eq('id', gymId);
      const msg = txErr instanceof Error ? txErr.message : String(txErr);
      return jsonError(`Owner registration rolled back: ${msg}`, 500);
    }
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`registerOwner error: ${msg}`, 500);
  }
});
