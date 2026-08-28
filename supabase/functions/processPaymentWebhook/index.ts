import { createHmac, timingSafeEqual } from 'node:crypto';
import {
  createAdminClient,
  jsonOk,
  jsonError,
} from '../_shared/supabaseServer.ts';

// R8 / rule 8: payment success is ONLY decided by the provider webhook.
// Never trust any client-declared payment state.

const STRIPE_WEBHOOK_SECRET_ENV = 'STRIPE_WEBHOOK_SECRET';

// Minimal Stripe signature verification (timing-safe). Real implementation
// must validate the full `t`,`v1` scheme from stripe-signature header.
function verifyStripeSignature(
  body: ArrayBuffer,
  sigHeader: string | null,
  secret: string,
): boolean {
  if (!sigHeader) return false;
  const parts: Record<string, string> = {};
  for (const kv of sigHeader.split(',')) {
    const i = kv.indexOf('=');
    if (i > 0) parts[kv.slice(0, i).trim()] = kv.slice(i + 1).trim();
  }
  const timestamp = parts['t'];
  const v1 = parts['v1'];
  if (!timestamp || !v1) return false;
  const payload = `${timestamp}.${Buffer.from(body).toString('utf8')}`;
  const expected = createHmac('sha256', secret).update(payload).digest('hex');
  const eb = Buffer.from(expected, 'hex');
  const vb = Buffer.from(v1, 'hex');
  if (eb.length !== vb.length) return false;
  return timingSafeEqual(eb, vb);
}

interface StripeEvent {
  id: string;
  type: string;
  data: { object: Record<string, unknown> };
}

Deno.serve(async (req: Request) => {
  try {
    const sig = req.headers.get('stripe-signature');
    const secret = Deno.env.get(STRIPE_WEBHOOK_SECRET_ENV);
    if (!secret) return jsonError('Webhook secret not configured', 500);

    const body = await req.arrayBuffer();
    if (!verifyStripeSignature(body, sig, secret)) {
      return jsonError('Invalid Stripe signature', 401);
    }

    const client = createAdminClient();
    const event: StripeEvent = JSON.parse(Buffer.from(body).toString('utf8'));

    const obj = event.data.object as {
      id?: string;
      amount?: number;
      currency?: string;
      metadata?: Record<string, string>;
      status?: string;
    };
    const providerReference = obj.id ?? event.id; // charge/intent id
    if (!providerReference) return jsonError('Missing provider reference', 400);

    // Idempotency (rule 8/52.7): dedupe by provider_reference.
    const existing = await client.from('payments')
      .select('id,status').eq('provider_reference', providerReference).maybeSingle();
    if (existing.data) {
      // Already processed — reconcile status only if a real state change occurs.
      return jsonOk({ already_processed: true, payment_id: existing.data.id });
    }

    const amount = typeof obj.amount === 'number' ? obj.amount : 0;
    const currency = obj.currency ?? 'USD';
    const idempotencyKey = event.id;

    let status: 'pending' | 'succeeded' | 'failed' | 'canceled' = 'pending';
    switch (event.type) {
      case 'payment_intent.succeeded':
      case 'charge.succeeded':
        status = 'succeeded';
        break;
      case 'payment_intent.payment_failed':
      case 'charge.failed':
        status = 'failed';
        break;
      case 'payment_intent.canceled':
        status = 'canceled';
        break;
      case 'payment_intent.processing':
      case 'checkout.session.expired':
        status = 'pending';
        break;
      default:
        // Unhandled event types are ignored (idempotent; safe to skip).
        return jsonOk({ ignored: true });
    }

    // Insert payment (server-authoritative).
    const insertRes = await client.from('payments').insert({
      gym_id: (obj.metadata ?? {})['gym_id'],
      member_id: (obj.metadata ?? {})['member_id'],
      provider: 'stripe',
      provider_reference: providerReference,
      amount_cents: amount,
      currency,
      status,
      idempotency_key: idempotencyKey,
    }).select('id').single();
    if (insertRes.error) return jsonError(`Payment insert failed: ${insertRes.error.message}`, 500);

    // R8: on success, extend the member's currently active membership.
    if (status === 'succeeded') {
      const memberId = (obj.metadata ?? {})['member_id'];
      const gymId = (obj.metadata ?? {})['gym_id'];
      const planId = (obj.metadata ?? {})['plan_id'];
      const plan = await client.from('membership_plans').select('duration_days').eq('id', planId ?? '').maybeSingle();
      const duration = plan.data?.duration_days ?? 30;

      const mem = await client.from('memberships')
        .select('expires_at,status').eq('member_id', memberId).eq('gym_id', gymId)
        .in('status', ['active', 'paused', 'frozen']).maybeSingle();
      const now = new Date();
      const base = (mem.data?.expires_at && new Date(mem.data.expires_at) > now)
        ? new Date(mem.data.expires_at)
        : now;
      const newExpiry = new Date(base.getTime() + duration * 24 * 60 * 60 * 1000);

      await client.from('memberships').update({
        expires_at: newExpiry.toISOString(),
        status: 'active',
        updated_at: new Date().toISOString(),
      }).eq('member_id', memberId).eq('gym_id', gymId).eq('status', mem.data?.status ?? 'active');

      await client.from('payments').update({ status: 'succeeded' }).eq('id', insertRes.data!.id);
      await client.from('audit_logs').insert({
        gym_id: gymId, action: 'payment.succeeded', entity: 'payment',
        entity_id: insertRes.data!.id,
        detail: { provider: 'stripe', provider_reference: providerReference, amount_cents: amount },
      });
    }

    return jsonOk({ payment_id: insertRes.data!.id, status });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`Webhook error: ${msg}`, 500);
  }
});
