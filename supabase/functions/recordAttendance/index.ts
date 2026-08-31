import { createHmac } from 'node:crypto';
import {
  requireAuth,
  jsonOk,
  jsonError,
} from '../_shared/supabaseServer.ts';
import { computeMembershipStatus, computeStreak, MembershipLike, roleCan } from '../_shared/business_rules.ts';

interface AttendanceReq {
  qrPayload: string;     // "<payload>.<hmac>" or dev payload
  source?: 'qr_self' | 'qr_assisted' | 'manual';
  member_id?: string;    // If staff is performing assisted check-in
  idempotencyKey?: string;
}

function b64urlDecode(input: string): Buffer {
  return Buffer.from(input.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
}

// QR HMAC signature verification
function verifyQr(payload: string, secret: string, isProduction: boolean): { gym_id: string; exp: number } | null {
  // Allow plain JSON parsing strictly in non-production dev environments
  if (!isProduction && payload.trim().startsWith('{')) {
    try {
      const parsed = JSON.parse(payload);
      if (typeof parsed.gym_id === 'string') {
        return { gym_id: parsed.gym_id, exp: parsed.exp ?? 9999999999 };
      }
    } catch {
      // Fall through to HMAC check
    }
  }

  const sep = payload.lastIndexOf('.');
  if (sep === -1) return null;
  const body = payload.slice(0, sep);
  const sig = payload.slice(sep + 1);
  const expected = createHmac('sha256', secret).update(body).digest('base64url');
  if (expected !== sig) {
    return null;
  }
  let parsed: { gym_id?: string; exp?: number; issued_at?: number; nonce?: string };
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

  try {
    const auth = await requireAuth(req);
    if (auth instanceof Response) return auth;
    const { client, user, gymId, role } = auth;

    // Only members (self) or front_desk/owner (assisted) may record attendance.
    if (!roleCan(role, 'selfCheckIn') && !roleCan(role, 'assistedCheckIn')) {
      return jsonError('Forbidden: role cannot record attendance', 403);
    }

    const body: AttendanceReq = await req.json();
    const isProduction = Deno.env.get('ENVIRONMENT') === 'production';

    // Retrieve dedicated QR signing secret from env or gym_settings
    const envQrSecret = Deno.env.get('QR_SIGNING_SECRET');
    let secret = envQrSecret;
    if (!secret) {
      const qrSetting = await client.from('gym_settings').select('qr_signing_secret')
        .eq('gym_id', gymId).maybeSingle();
      secret = qrSetting.data?.qr_signing_secret || gymId;
    }
    const effectiveSecret: string = secret ?? gymId;

    const qr = verifyQr(body.qrPayload, effectiveSecret, isProduction);
    if (!qr) return jsonError('Invalid or expired QR code', 400);
    if (qr.gym_id !== gymId) return jsonError('QR code does not belong to this gym', 403);

    const source = body.source ?? 'qr_self';
    const isAssisted = source === 'qr_assisted' || Boolean(body.member_id);

    if (isAssisted && !roleCan(role, 'assistedCheckIn')) {
      return jsonError('Forbidden: cannot record assisted check-in', 403);
    }

    // Resolve member: for assisted check-in, use body.member_id; for self, use auth user
    let memberQuery = client.from('members')
      .select('id, status, profile_id, member_number, full_name, phone, email')
      .eq('gym_id', gymId);

    if (isAssisted && body.member_id) {
      memberQuery = memberQuery.eq('id', body.member_id);
    } else {
      memberQuery = memberQuery.eq('profile_id', user.id);
    }

    const memberRes = await memberQuery.maybeSingle();

    if (!memberRes.data) {
      return jsonError('Member record not found for this gym account', 404);
    }
    const member = memberRes.data as { id: string; full_name: string; status: string; member_number: string };

    if (member.status === 'inactive') {
      return jsonError('Check-in denied: member is inactive. Please see front desk.', 403);
    }

    // Resolve current membership (R2: eligibility)
    const memRes = await client.from('memberships')
      .select('status, started_at, expires_at, paused_until, canceled_at')
      .eq('member_id', member.id)
      .in('status', ['active', 'paused', 'frozen', 'expired'])
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    const m: MembershipLike = memRes.data
      ? {
          canceledAt: memRes.data.canceled_at ? new Date(memRes.data.canceled_at) : null,
          pausedUntil: memRes.data.paused_until ? new Date(memRes.data.paused_until) : null,
          expiresAt: memRes.data.expires_at ? new Date(memRes.data.expires_at) : null,
          startedAt: memRes.data.started_at ? new Date(memRes.data.started_at) : new Date(),
        }
      : { canceledAt: null, pausedUntil: null, expiresAt: null, startedAt: new Date() };

    const membershipStatus = memRes.data ? computeMembershipStatus(m) : 'inactive';
    const denied = membershipStatus === 'canceled' || membershipStatus === 'expired' || membershipStatus === 'inactive';
    if (denied) {
      return jsonError(`Check-in denied: membership is ${membershipStatus}`, 403);
    }

    // R5: duplicate check-in prevention (idempotency key + 5 min grace window)
    const nowSec = Math.floor(Date.now() / 1000);
    const graceWindow = 60 * 5; // 5 minutes
    const idem = body.idempotencyKey ?? `${member.id}:${nowSec - (nowSec % graceWindow)}`;
    const dupRes = await client.from('attendance')
      .select('id, check_in_at').eq('idempotency_key', idem).maybeSingle();
    if (dupRes.data) {
      return jsonOk({ attendance: dupRes.data, duplicate: true, membership_status: membershipStatus });
    }

    // Record attendance
    const checkInTime = new Date().toISOString();
    const insertRes = await client.from('attendance')
      .insert({
        gym_id: gymId,
        member_id: member.id,
        check_in_at: checkInTime,
        source: isAssisted ? 'qr_assisted' : 'qr_self',
        staff_id: roleCan(role, 'assistedCheckIn') ? user.id : null,
        idempotency_key: idem,
      })
      .select('*')
      .single();

    if (insertRes.error) {
      return jsonError(`Failed to record attendance: ${insertRes.error.message}`, 500);
    }

    // Accurate streak calculation across all historical check-ins
    const { data: pastAtt } = await client.from('attendance')
      .select('check_in_at')
      .eq('gym_id', gymId)
      .eq('member_id', member.id)
      .order('check_in_at', { ascending: false });

    const checkInDates = (pastAtt ?? [])
      .map((a: { check_in_at: string }) => new Date(a.check_in_at))
      .filter((d: Date) => !isNaN(d.getTime()));

    const streakResult = computeStreak(checkInDates);

    // Auto-resolve open no-show cases
    await client.from('no_show_cases')
      .update({
        status: 'resolved',
        resolved_at: checkInTime,
        resolution_notes: `Auto-resolved on check-in via ${source}`,
      })
      .eq('gym_id', gymId)
      .eq('member_id', member.id)
      .eq('status', 'open');

    return jsonOk({
      attendance: insertRes.data,
      member: {
        id: member.id,
        full_name: member.full_name,
        member_number: member.member_number,
      },
      membership_status: membershipStatus,
      streak: streakResult.current,
      longest_streak: streakResult.longest,
      duplicate: false,
    }, 201);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`recordAttendance error: ${msg}`, 500);
  }
});
