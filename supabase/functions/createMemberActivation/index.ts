import {
  createAdminClient,
  requireAuth,
  jsonOk,
  jsonError,
  corsHeaders,
} from '../_shared/supabaseServer.ts';
import { roleCan } from '../_shared/business_rules.ts';

// createMemberActivation: owner/front_desk only.
// Returns or creates the persistent, deterministic Monthly Activation QR token
// for the caller's gym. Valid throughout the calendar month for unlimited new member onboarding.

async function sha256Hex(str: string): Promise<string> {
  const data = new TextEncoder().encode(str);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
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
    const auth = await requireAuth(req);
    if (auth instanceof Response) return auth;
    const { user, gymId, role } = auth;

    if (!roleCan(role, 'createMember')) {
      return jsonError('Forbidden: only owner/front_desk can generate member activation QR', 403);
    }

    const admin = createAdminClient();

    // Fetch gym details
    const { data: gymData, error: gymErr } = await admin
      .from('gyms')
      .select('id, name, slug')
      .eq('id', gymId)
      .single();

    if (gymErr || !gymData) {
      return jsonError('Gym not found', 404);
    }

    const now = new Date();
    const year = now.getUTCFullYear();
    const monthNum = now.getUTCMonth() + 1;
    const monthKey = `${year}-${String(monthNum).padStart(2, '0')}`;
    const endOfMonth = new Date(Date.UTC(year, monthNum, 0, 23, 59, 59, 999));

    // 1. Check for existing active monthly activation token for this gym and calendar month
    const { data: existingToken } = await admin
      .from('member_activation_tokens')
      .select('id, raw_token, token_hash, expires_at')
      .eq('gym_id', gymId)
      .eq('token_type', 'monthly')
      .eq('month_key', monthKey)
      .is('revoked_at', null)
      .gt('expires_at', now.toISOString())
      .maybeSingle();

    if (existingToken && existingToken.raw_token) {
      const qrPayload = `liftflow://member-activation/${existingToken.raw_token}`;
      const lifetimeSeconds = Math.max(60, Math.floor((new Date(existingToken.expires_at).getTime() - now.getTime()) / 1000));
      return jsonOk({
        activation_token: existingToken.raw_token,
        qr_payload: qrPayload,
        expires_at: existingToken.expires_at,
        lifetime_seconds: lifetimeSeconds,
        month_key: monthKey,
        gym: {
          id: gymData.id,
          name: gymData.name,
          slug: gymData.slug,
        },
      }, 200);
    }

    // 2. Generate deterministic monthly token & SHA-256 hash
    const rawToken = `act_${gymData.slug}_${year}_${String(monthNum).padStart(2, '0')}`;
    const tokenHash = await sha256Hex(rawToken);

    const { data: tokenRow, error: insertErr } = await admin
      .from('member_activation_tokens')
      .insert({
        gym_id: gymId,
        created_by: user.id,
        token_type: 'monthly',
        month_key: monthKey,
        raw_token: rawToken,
        token_hash: tokenHash,
        expires_at: endOfMonth.toISOString(),
      })
      .select('id, raw_token, expires_at')
      .maybeSingle();

    if (insertErr || !tokenRow) {
      // Concurrency fallback: If another worker just inserted the monthly token simultaneously
      const { data: retryToken } = await admin
        .from('member_activation_tokens')
        .select('id, raw_token, expires_at')
        .eq('gym_id', gymId)
        .eq('token_type', 'monthly')
        .eq('month_key', monthKey)
        .is('revoked_at', null)
        .maybeSingle();

      if (retryToken && retryToken.raw_token) {
        const qrPayload = `liftflow://member-activation/${retryToken.raw_token}`;
        const lifetimeSeconds = Math.max(60, Math.floor((new Date(retryToken.expires_at).getTime() - now.getTime()) / 1000));
        return jsonOk({
          activation_token: retryToken.raw_token,
          qr_payload: qrPayload,
          expires_at: retryToken.expires_at,
          lifetime_seconds: lifetimeSeconds,
          month_key: monthKey,
          gym: {
            id: gymData.id,
            name: gymData.name,
            slug: gymData.slug,
          },
        }, 200);
      }

      return jsonError(`Failed to create activation token: ${insertErr?.message ?? 'database error'}`, 500);
    }

    // Write audit log
    try {
      await admin.from('audit_logs').insert({
        gym_id: gymId,
        actor_user_id: user.id,
        action: 'member_activation.monthly_qr_created',
        entity: 'member_activation_token',
        entity_id: tokenRow.id,
        detail: {
          month_key: monthKey,
          expires_at: endOfMonth.toISOString(),
          created_by_role: role,
        },
      });
    } catch (_) {
      // Non-blocking audit log
    }

    const qrPayload = `liftflow://member-activation/${rawToken}`;
    const lifetimeSeconds = Math.max(60, Math.floor((endOfMonth.getTime() - now.getTime()) / 1000));

    return jsonOk({
      activation_token: rawToken,
      qr_payload: qrPayload,
      expires_at: endOfMonth.toISOString(),
      lifetime_seconds: lifetimeSeconds,
      month_key: monthKey,
      gym: {
        id: gymData.id,
        name: gymData.name,
        slug: gymData.slug,
      },
    }, 201);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`createMemberActivation error: ${msg}`, 500);
  }
});
