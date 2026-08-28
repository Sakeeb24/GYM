import { createAdminClient, jsonOk, jsonError } from '../_shared/supabaseServer.ts';

// schedulerTick: single cron entrypoint that runs all idempotent daily jobs.
// Invoked by an external job (e.g. GitHub Actions cron) with ?token=...
// Each job is independently idempotent so missed/double ticks are safe.

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const token = url.searchParams.get('token');
  if (!token || token !== Deno.env.get('CRON_TOKEN')) {
    return jsonError('Unauthorized', 401);
  }
  const client = createAdminClient();
  const results: Record<string, unknown> = {};

  // We can't call the other functions in-process; instead we re-run the daily
  // jobs here directly (idempotent). Kept minimal + auditable.
  // 1) no-show scan
  let noShow = 0;
  const { data: gyms } = await client.from('gyms').select('id').eq('is_active', true);
  for (const gym of gyms ?? []) {
    const setting = await client.from('gym_settings').select('inactivity_threshold_days')
      .eq('gym_id', (gym as { id: string }).id).maybeSingle();
    const threshold = setting.data?.inactivity_threshold_days ?? 7;
    const { data: members } = await client.from('members')
      .select('id').eq('gym_id', (gym as { id: string }).id).eq('status', 'active');
    for (const m of members ?? []) {
      const { data: last } = await client.from('attendance')
        .select('check_in_at').eq('gym_id', (gym as { id: string }).id)
        .eq('member_id', (m as { id: string }).id)
        .order('check_in_at', { ascending: false }).limit(1).maybeSingle();
      const lastAt = last ? new Date(last.check_in_at) : null;
      const needs = lastAt == null || (Date.now() - lastAt.getTime()) >= threshold * 86400000;
      if (needs) {
        await client.from('no_show_cases').insert({
          gym_id: (gym as { id: string }).id, member_id: (m as { id: string }).id,
          status: 'open', reason: 'inactivity',
          last_seen_at: lastAt?.toISOString() ?? new Date().toISOString(),
        }).select('id').maybeSingle(); // unique index dedups
        noShow++;
      }
    }
  }
  results.no_show_scan = { cases_checked: noShow };

  // 2) data-quality scan (lightweight: flag memberships missing expiry)
  let dq = 0;
  const { data: bad } = await client.from('memberships')
    .select('id').is('expires_at', null).eq('status', 'active');
  dq = (bad ?? []).length;
  results.data_quality = { missing_expiry: dq };

  return jsonOk({ ok: true, results });
});
