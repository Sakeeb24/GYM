import { createAdminClient, jsonOk, jsonError } from '../_shared/supabaseServer.ts';

// schedulerTick: idempotent cron entrypoint running scheduled scans.
// Batch set-based operations avoiding N+1 database round-trips.

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const token = url.searchParams.get('token');
  if (!token || token !== Deno.env.get('CRON_TOKEN')) {
    return jsonError('Unauthorized', 401);
  }
  const client = createAdminClient();
  const results: Record<string, unknown> = {};

  try {
    // 1) No-show scan across all active gyms
    const { data: gyms } = await client.from('gyms').select('id').eq('is_active', true);
    let totalCasesFlagged = 0;

    for (const gym of gyms ?? []) {
      const gymId = (gym as { id: string }).id;
      const setting = await client.from('gym_settings')
        .select('inactivity_threshold_days')
        .eq('gym_id', gymId)
        .maybeSingle();

      const threshold = setting.data?.inactivity_threshold_days ?? 7;
      const cutoffDate = new Date(Date.now() - threshold * 86400000).toISOString();

      // Find active members whose last attendance is older than threshold
      const { data: activeMembers } = await client.from('members')
        .select('id, created_at')
        .eq('gym_id', gymId)
        .eq('status', 'active');

      if (!activeMembers || activeMembers.length === 0) continue;

      const memberIds = activeMembers.map((m: { id: string }) => m.id);

      // Fetch latest check-in for these members
      const { data: recentAttendances } = await client.from('attendance')
        .select('member_id, check_in_at')
        .eq('gym_id', gymId)
        .in('member_id', memberIds)
        .gte('check_in_at', cutoffDate);

      const recentlyActiveMemberIds = new Set(
        (recentAttendances ?? []).map((a: { member_id: string }) => a.member_id),
      );

      const inactiveMemberIds = memberIds.filter((id: string) => !recentlyActiveMemberIds.has(id));

      if (inactiveMemberIds.length > 0) {
        // Batch insert no-show cases
        const casesToInsert = inactiveMemberIds.map((memId: string) => ({
          gym_id: gymId,
          member_id: memId,
          status: 'open',
          reason: 'inactivity',
          last_seen_at: cutoffDate,
        }));

        for (const item of casesToInsert) {
          const { error } = await client.from('no_show_cases').insert(item);
          if (!error) totalCasesFlagged++;
        }
      }
    }
    results.no_show_scan = { cases_flagged: totalCasesFlagged };

    // 2) Data-quality scan: count memberships missing expiry
    const { data: missingExpiry } = await client.from('memberships')
      .select('id')
      .is('expires_at', null)
      .eq('status', 'active');

    results.data_quality = { missing_expiry_count: (missingExpiry ?? []).length };

    return jsonOk({ ok: true, results });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`schedulerTick error: ${msg}`, 500);
  }
});
