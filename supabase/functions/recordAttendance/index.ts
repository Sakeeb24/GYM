import { createHmac } from 'node:crypto';
import {
  requireAuth,
  jsonOk,
  jsonError,
} from '../_shared/supabaseServer.ts';
import { computeMembershipStatus, MembershipLike, roleCan } from '../_shared/business_rules.ts';

interface AttendanceReq {
  qrPayload: string;     // "<payload>.<hmac>" where payload is base64url JSON {gym_id,nonce,exp}
  source?: 'qr_self' | 'qr_assisted' | 'manual';
  idempotencyKey?: string;
}

function b64urlDecode(input: string): Buffer {
  return Buffer.from(input.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
}

// R: QR HMAC signature verification (never trust a client-asserted gym_id).
function verifyQr(payload: string, secret: string): { gym_id: string; exp: number } | null {
  const sep = payload.lastIndexOf('.');
  if (sep === -1) return null;
  const body = payload.slice(0, sep);
  const sig = payload.slice(sep + 1);
  const expected = createHmac('sha256', secret).update(body).digest('base64url');
  if (expected !== sig) {
    return null;
  }
  let parsed: { gym_id?: string; exp?: number };
  try {
    parsed = JSON.parse(b64urlDecode(body).toString('utf8'));
  } catch {
    return null;
  }
  if (typeof parsed.gym_id !== 'string' || typeof parsed.exp !== 'number') return null;
  if (Date.now() / 1000 > parsed.exp) return null; // expired QR
  return { gym_id: parsed.gym_id, exp: parsed.exp };
}

Deno.serve(async (req: Request) => {
  try {
    const auth = await requireAuth(req);
    if (auth instanceof Response) return auth;
    const { client, user, gymId, role } = auth;

    // Only members (self) or front_desk/owner (assisted) may record attendance.
    if (!roleCan(role, 'selfCheckIn') && !roleCan(role, 'assistedCheckIn')) {
      return jsonError('Forbidden: role cannot record attendance', 403);
    }

    const body: AttendanceReq = await req.json();
    const qrSecret = (await client.from('gym_settings').select('stripe_secret_key')
      .eq('gym_id', gymId).maybeSingle()) as unknown as {
        data?: { stripe_secret_key?: string | null }; error?: { message?: string } | null;
      };
    // NOTE: `stripe_secret_key` is a stand-in column reused to read a server secret
    // here to keep the schema minimal; a dedicated `qr_secret` column is expected.

    const secret = qrSecret.data?.stripe_secret_key;
    if (!secret) return jsonError('Gym QR secret not configured', 500);

    const qr = verifyQr(body.qrPayload, secret);
    if (!qr) return jsonError('Invalid or expired QR', 400);
    if (qr.gym_id !== gymId) return jsonError('QR does not belong to this gym', 403);

    const source = body.source ?? 'qr_self';
    if (source === 'qr_assisted' && !roleCan(role, 'assistedCheckIn')) {
      return jsonError('Forbidden: cannot record assisted check-in', 403);
    }

    // Resolve the member row for the authenticated user.
    const memberRes = await client.from('members')
      .select('id:member_id, status, profile_id, member_number, full_name, phone, email')
      .eq('profile_id', user.id)
      .eq('gym_id', gymId)
      .maybeSingle();
    if (!memberRes.data) return jsonError('Member profile not found in this gym', 404);
    const member = memberRes.data as { id: string };

    // Resolve current membership (R2: eligibility).
    const memRes = await client.from('memberships')
      .select('status, started_at, expires_at, paused_until, canceled_at')
      .eq('member_id', member.id)
      .in('status', ['active', 'paused', 'frozen'])
      .maybeSingle();
    const m: MembershipLike = memRes.data
      ? { canceledAt: null, pausedUntil: new Date(memRes.data.paused_until), expiresAt: new Date(memRes.data.expires_at), startedAt: new Date(memRes.data.started_at) }
      : { canceledAt: null, pausedUntil: null, expiresAt: null, startedAt: new Date() };

    const status = memRes.data ? computeMembershipStatus(m) : 'inactive';
    // Paused is allowed; expired/canceled denied.
    const denied = status === 'canceled' || status === 'expired' || status === 'inactive';
    if (denied) return jsonError(`Check-in denied: membership ${status}`, 403);

    // R5: duplicate check-in prevention (idempotency key + grace window).
    const now = Math.floor(Date.now() / 1000);
    const grace = 60 * 5; // qr_session_grace_minutes default 5
    const idem = body.idempotencyKey ?? `${user.id}:${now - (now % grace)}`;
    const dupRes = await client.from('attendance')
      .select('id').eq('idempotency_key', idem).maybeSingle();
    if (dupRes.data) return jsonOk({ attendance: dupRes.data, duplicate: true });

    // R3: record attendance, then update streak.
    const insertRes = await client.from('attendance')
      .insert({ gym_id: gymId, member_id: member.id, check_in_at: new Date().toISOString(), source, staff_id: roleCan(role, 'assistedCheckIn') ? user.id : null, idempotency_key: idem })
      .select('*')
      .single();
    if (insertRes.error) return jsonError(`Attendance failed: ${insertRes.error.message}`, 500);

    await client.from('streaks').upsert({
      member_id: member.id, gym_id: gymId,
      current_streak: 1, longest_streak: 1, last_check_in_at: insertRes.data?.check_in_at ?? new Date().toISOString(),
    });

    // R4: a return voids any OPEN no-show case for this member.
    await client.from('no_show_cases')
      .update({ status: 'resolved', resolved_outcome: 'returned', resolved_at: new Date().toISOString() })
      .eq('member_id', member.id).eq('gym_id', gymId).eq('status', 'open');

    await client.from('audit_logs').insert({
      gym_id: gymId, actor_user_id: user.id, action: 'attendance.recorded',
      entity: 'attendance', entity_id: insertRes.data?.id,
      detail: { source, member_id: member.id, status },
    });

    return jsonOk({ attendance: insertRes.data, duplicate: false, membership_status: status });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`Internal: ${msg}`, 500);
  }
});
