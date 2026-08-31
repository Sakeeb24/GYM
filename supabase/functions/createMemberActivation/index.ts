import {
  createAdminClient,
  requireAuth,
  jsonOk,
  jsonError,
} from '../_shared/supabaseServer.ts';
import { roleCan } from '../_shared/business_rules.ts';

// createMemberActivation: owner/front_desk only.
// Generates a short-lived (60s), single-use, cryptographically secure activation QR token
// bound strictly to the authenticated caller's gym.

async function sha256Hex(str: string): Promise<string> {
  const data = new TextEncoder().encode(str);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

function generateSecureToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

const DEFAULT_QR_LIFETIME_SECONDS = 60;

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
    const auth = await requireAuth(req);
    if (auth instanceof Response) return auth;
    const { client, user, gymId, role } = auth;

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

    // Auto-revoke previous active unused tokens for this creator to prevent abandoned lingering tokens
    await admin
      .from('member_activation_tokens')
      .update({ revoked_at: new Date().toISOString() })
      .eq('gym_id', gymId)
      .eq('created_by', user.id)
      .is('used_at', null)
      .is('revoked_at', null);

    // Generate cryptographically secure token & SHA-256 hash
    const rawToken = generateSecureToken();
    const tokenHash = await sha256Hex(rawToken);

    const now = new Date();
    const expiresAt = new Date(now.getTime() + DEFAULT_QR_LIFETIME_SECONDS * 1000);

    const { data: tokenRow, error: insertErr } = await admin
      .from('member_activation_tokens')
      .insert({
        gym_id: gymId,
        created_by: user.id,
        token_hash: tokenHash,
        expires_at: expiresAt.toISOString(),
      })
      .select('id, expires_at')
      .single();

    if (insertErr || !tokenRow) {
      return jsonError(`Failed to create activation token: ${insertErr?.message ?? 'database error'}`, 500);
    }

    // Write audit log (never logging raw token)
    try {
      await admin.from('audit_logs').insert({
        gym_id: gymId,
        actor_user_id: user.id,
        action: 'member_activation.qr_created',
        entity: 'member_activation_token',
        entity_id: tokenRow.id,
        detail: {
          expires_at: expiresAt.toISOString(),
          created_by_role: role,
        },
      });
    } catch (_) {
      // Non-blocking audit log
    }

    const qrPayload = `liftflow://member-activation/${rawToken}`;

    return jsonOk({
      activation_token: rawToken,
      qr_payload: qrPayload,
      expires_at: expiresAt.toISOString(),
      lifetime_seconds: DEFAULT_QR_LIFETIME_SECONDS,
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
