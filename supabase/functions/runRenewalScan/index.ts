import {
  createAdminClient,
  jsonOk,
  jsonError,
} from '../_shared/supabaseServer.ts';
import { assertCron, dueReminderStage, renewalEligible } from '../_shared/business_rules.ts';

// R4/R7 renewal automation. Scheduled (idempotent). One renewal_order per
// (member, window) via idempotency_key prevents duplicate campaigns.

Deno.serve(async (req: Request) => {
  try {
    if (!assertCron(req)) return jsonError('Unauthorized', 401);
    const client = createAdminClient();

    const { data: gyms, error: gErr } = await client.from('gyms').select('id').eq('is_active', true);
    if (gErr) return jsonError(gErr.message, 500);

    let ordersCreated = 0;
    for (const gym of gyms ?? []) {
      const setting = await client.from('gym_settings')
        .select('reminder_windows_days')
        .eq('gym_id', gym.id).maybeSingle();
      const windows = setting.data?.reminder_windows_days ?? [14, 7, 3];

      // Eligible memberships: active / paused / frozen / expired (not canceled).
      const { data: mems, error: mErr } = await client.from('memberships')
        .select('id, member_id, plan_id, expires_at, status')
        .eq('gym_id', gym.id)
        .in('status', ['active', 'paused', 'frozen', 'expired']);
      if (mErr) continue;

      for (const m of mems ?? []) {
        const memberId = (m as { member_id: string }).member_id;
        const planId = (m as { plan_id: string }).plan_id;
        const expiresAt = new Date((m as { expires_at: string }).expires_at);

        // communication preference for the default channel
        const pref = await client.from('communication_preferences')
          .select('opted_in').eq('member_id', memberId).eq('channel', 'email').maybeSingle();
        const commOptedIn = pref.data?.opted_in ?? false;

        const eligible = renewalEligible({
          commOptedIn,
          reminderWindows: windows,
          postExpiryDays: 3,
          expiresAt,
        });
        if (!eligible) continue;

        const stage = dueReminderStage({
          commOptedIn, reminderWindows: windows, postExpiryDays: 3, expiresAt,
        });
        if (!stage) continue;

        const plan = await client.from('membership_plans')
          .select('price_cents,currency').eq('id', planId).maybeSingle();
        const amount = plan.data?.price_cents ?? 0;
        const currency = plan.data?.currency ?? 'USD';

        const idempotencyKey = `${memberId}|${stage}`;
        const res = await client.from('renewal_orders').insert({
          gym_id: gym.id,
          member_id: memberId,
          plan_id: planId,
          due_at: expiresAt.toISOString(),
          amount_cents: amount,
          currency,
          status: 'pending',
          reminder_stage: stage,
          idempotency_key: idempotencyKey,
        }).select('id,status').maybeSingle();
        if (res.data) {
          ordersCreated++;
          await client.from('notifications').insert({
            gym_id: gym.id,
            member_id: memberId,
            type: stage === 'post_expiry' ? 'renewal_overdue' : 'renewal_due',
            channel: 'push',
            status: 'queued',
            scheduled_at: new Date().toISOString(),
            idempotency_key: `notify|${idempotencyKey}`,
          });
        }
      }
    }
    return jsonOk({ orders_created: ordersCreated });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`runRenewalScan error: ${msg}`, 500);
  }
});
