import {
  createAdminClient,
  jsonOk,
  jsonError,
} from '../_shared/supabaseServer.ts';
import { assertCron, shouldOpenNoShowCase } from '../_shared/business_rules.ts';

// R4 / rule 15 no-show automation. Scheduled (idempotent). The partial unique
// index on no_show_cases prevents duplicate open cases even if logic races.

Deno.serve(async (req: Request) => {
  try {
    if (!assertCron(req)) return jsonError('Unauthorized', 401);
    const client = createAdminClient();

    const { data: gyms, error: gErr } = await client
      .from('gyms')
      .select('id, name')
      .eq('is_active', true);
    if (gErr) return jsonError(gErr.message, 500);

    let casesCreated = 0;
    for (const gym of gyms ?? []) {
      const setting = await client.from('gym_settings')
        .select('inactivity_threshold_days')
        .eq('gym_id', gym.id).maybeSingle();
      const threshold = setting.data?.inactivity_threshold_days ?? 7;

      // Eligible members: active roster + an active/paused/frozen membership.
      const { data: members, error: mErr } = await client
        .from('members')
        .select(`id, status,
          memberships!inner(id, started_at, expires_at, paused_until, canceled_at, status)`)
        .eq('gym_id', gym.id).eq('status', 'active');
      if (mErr) continue;

      for (const m of members ?? []) {
        const mem = (m as { memberships: any[] }).memberships?.[0];
        if (!mem) continue;
        const mLike = {
          canceledAt: mem.canceled_at ? new Date(mem.canceled_at) : null,
          pausedUntil: mem.paused_until ? new Date(mem.paused_until) : null,
          expiresAt: mem.expires_at ? new Date(mem.expires_at) : null,
          startedAt: new Date(mem.started_at),
        };
        // last valid attendance
        const lastAtt = await client.from('attendance')
          .select('check_in_at').eq('gym_id', gym.id).eq('member_id', m.id)
          .order('check_in_at', { ascending: false }).limit(1).maybeSingle();
        const last = lastAtt.data ? new Date(lastAtt.data.check_in_at) : null;

        if (shouldOpenNoShowCase({ membership: mLike, lastCheckInAt: last, inactivityThresholdDays: threshold })) {
          const res = await client.from('no_show_cases').insert({
            gym_id: gym.id,
            member_id: m.id,
            status: 'open',
            reason: 'inactivity',
            last_seen_at: last?.toISOString() ?? new Date().toISOString(),
          }).select('id').maybeSingle();
          if (res.data) {
            casesCreated++;
            // default follow-up assigned to owner of the gym
            const owner = await client.from('profiles').select('user_id')
              .eq('gym_id', gym.id).eq('role', 'owner').limit(1).maybeSingle();
            await client.from('follow_ups').insert({
              gym_id: gym.id,
              member_id: m.id,
              no_show_case_id: res.data.id,
              assigned_to: owner.data?.user_id ?? null,
              status: 'open',
              next_action_at: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
            });
          }
        }
      }
    }
    return jsonOk({ cases_created: casesCreated });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`runNoShowScan error: ${msg}`, 500);
  }
});
