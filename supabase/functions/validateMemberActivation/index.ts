import { createAdminClient, jsonOk, jsonError } from '../_shared/supabaseServer.ts';

// validateMemberActivation: Public endpoint called by the prospective member app
// when scanning an activation QR code. Validates token authenticity, lifetime, and status,
// and returns verified gym details for UI confirmation prior to account setup.

async function sha256Hex(str: string): Promise<string> {
  const data = new TextEncoder().encode(str);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

interface ValidateReq {
  token: string;
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
    const body: ValidateReq = await req.json();
    let { token } = body;

    if (!token?.trim()) {
      return jsonError('Activation token is required', 400);
    }

    // Support deep link or raw token
    token = token.trim();
    if (token.startsWith('liftflow://member-activation/')) {
      token = token.replace('liftflow://member-activation/', '').trim();
    } else if (token.includes('/activate/')) {
      token = token.split('/activate/')[1].trim();
    }

    if (token.length < 16) {
      return jsonError('This QR code is not valid for LiftFlow.', 400);
    }

    const tokenHash = await sha256Hex(token);
    const admin = createAdminClient();

    // Query token details joined with gym
    const { data: tokenRecord, error: fetchErr } = await admin
      .from('member_activation_tokens')
      .select('id, gym_id, expires_at, used_at, revoked_at, gyms(id, name, slug)')
      .eq('token_hash', tokenHash)
      .maybeSingle();

    if (fetchErr || !tokenRecord) {
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

    const gymData = tokenRecord.gyms as unknown as { id: string; name: string; slug: string } | null;
    if (!gymData) {
      return jsonError('Associated gym not found', 404);
    }

    return jsonOk({
      valid: true,
      gym: {
        id: gymData.id,
        name: gymData.name,
        slug: gymData.slug,
      },
      expires_at: tokenRecord.expires_at,
    }, 200);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`validateMemberActivation error: ${msg}`, 500);
  }
});
