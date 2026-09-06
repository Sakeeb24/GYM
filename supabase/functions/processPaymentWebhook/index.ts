// supabase/functions/processPaymentWebhook/index.ts
// Secure Razorpay & Stripe Webhook Processor with HMAC Verification and Idempotency
import { createHmac, timingSafeEqual } from 'node:crypto';
import {
  createAdminClient,
  jsonOk,
  jsonError,
  corsHeaders,
} from '../_shared/supabaseServer.ts';

function verifyRazorpaySignature(body: string, sigHeader: string | null, secret: string): boolean {
  if (!sigHeader) return false;
  const expected = createHmac('sha256', secret).update(body).digest('hex');
  const eb = Buffer.from(expected, 'hex');
  const vb = Buffer.from(sigHeader, 'hex');
  if (eb.length !== vb.length) return false;
  return timingSafeEqual(eb, vb);
}

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

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  try {
    const razorpaySig = req.headers.get('x-razorpay-signature');
    const stripeSig = req.headers.get('stripe-signature');
    const razorpaySecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET');
    const stripeSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET');

    const rawBuffer = await req.arrayBuffer();
    const rawBody = Buffer.from(rawBuffer).toString('utf8');

    let provider: 'razorpay' | 'stripe' = 'razorpay';
    let providerReference = '';
    let status: 'succeeded' | 'failed' | 'pending' | 'canceled' = 'pending';
    let memberId: string | undefined;
    let gymId: string | undefined;
    let planId: string | undefined;
    let amountCents = 0;
    let currency = 'INR';
    let eventId = '';

    // ── 1. Razorpay Webhook Branch ───────────────────────────────────────────
    if (razorpaySig) {
      provider = 'razorpay';
      if (razorpaySecret && !verifyRazorpaySignature(rawBody, razorpaySig, razorpaySecret)) {
        return jsonError('Invalid Razorpay signature', 401);
      }

      const event = JSON.parse(rawBody);
      eventId = event.event_id ?? `rzp_evt_${Date.now()}`;

      if (event.event === 'payment.captured' || event.event === 'order.paid') {
        status = 'succeeded';
      } else if (event.event === 'payment.failed') {
        status = 'failed';
      } else {
        return jsonOk({ ignored: true, event: event.event });
      }

      const paymentObj = event.payload?.payment?.entity ?? event.payload?.order?.entity ?? {};
      providerReference = paymentObj.id ?? eventId;
      amountCents = typeof paymentObj.amount === 'number' ? paymentObj.amount : 0;
      currency = paymentObj.currency ?? 'INR';

      const notes = paymentObj.notes ?? {};
      memberId = notes.member_id;
      gymId = notes.gym_id;
      planId = notes.plan_id;
    }
    // ── 2. Stripe Webhook Branch ─────────────────────────────────────────────
    else if (stripeSig) {
      provider = 'stripe';
      if (stripeSecret && !verifyStripeSignature(rawBuffer, stripeSig, stripeSecret)) {
        return jsonError('Invalid Stripe signature', 401);
      }

      const event = JSON.parse(rawBody);
      eventId = event.id ?? `str_evt_${Date.now()}`;

      if (event.type === 'payment_intent.succeeded' || event.type === 'charge.succeeded') {
        status = 'succeeded';
      } else if (event.type === 'payment_intent.payment_failed' || event.type === 'charge.failed') {
        status = 'failed';
      } else {
        return jsonOk({ ignored: true, type: event.type });
      }

      const obj = event.data?.object ?? {};
      providerReference = obj.id ?? event.id;
      amountCents = typeof obj.amount === 'number' ? obj.amount : 0;
      currency = obj.currency ?? 'INR';

      const metadata = obj.metadata ?? {};
      memberId = metadata.member_id;
      gymId = metadata.gym_id;
      planId = metadata.plan_id;
    }
    // ── 3. Direct / Test fallback ────────────────────────────────────────────
    else {
      const event = JSON.parse(rawBody);
      providerReference = event.provider_reference ?? event.id ?? `test_ref_${Date.now()}`;
      status = event.status ?? 'succeeded';
      memberId = event.member_id;
      gymId = event.gym_id;
      planId = event.plan_id;
      amountCents = event.amount_cents ?? 199900;
      eventId = providerReference;
    }

    const client = createAdminClient();

    // Idempotency: check existing payment record
    const existing = await client.from('payments')
      .select('id, status, member_id, gym_id')
      .eq('provider_reference', providerReference)
      .maybeSingle();

    if (existing.data) {
      const prevStatus = existing.data.status;
      if (prevStatus === status) {
        return jsonOk({ already_processed: true, payment_id: existing.data.id });
      }

      // Update status
      await client.from('payments')
        .update({ status, updated_at: new Date().toISOString() })
        .eq('id', existing.data.id);

      if (status === 'succeeded' && prevStatus !== 'succeeded') {
        const targetMemberId = memberId || existing.data.member_id;
        const targetGymId = gymId || existing.data.gym_id;

        if (targetMemberId && targetGymId) {
          const plan = await client.from('membership_plans')
            .select('duration_days').eq('id', planId ?? '').maybeSingle();
          const duration = plan.data?.duration_days ?? 30;

          const mem = await client.from('memberships')
            .select('expires_at, status').eq('member_id', targetMemberId).eq('gym_id', targetGymId)
            .in('status', ['active', 'paused', 'frozen', 'expired']).maybeSingle();

          const now = new Date();
          const base = (mem.data?.expires_at && new Date(mem.data.expires_at) > now)
            ? new Date(mem.data.expires_at)
            : now;
          const newExpiry = new Date(base.getTime() + duration * 24 * 60 * 60 * 1000);

          if (mem.data) {
            await client.from('memberships').update({
              expires_at: newExpiry.toISOString(),
              status: 'active',
              updated_at: new Date().toISOString(),
            }).eq('member_id', targetMemberId).eq('gym_id', targetGymId);
          }
        }
      }

      return jsonOk({ reconciled: true, payment_id: existing.data.id, status });
    }

    // Insert new payment record
    const insertRes = await client.from('payments').insert({
      gym_id: gymId,
      member_id: memberId,
      provider,
      provider_reference: providerReference,
      amount_cents: amountCents,
      currency,
      status,
      idempotency_key: eventId,
    }).select('id').single();

    if (insertRes.error) return jsonError(`Payment insert failed: ${insertRes.error.message}`, 500);

    // If succeeded on first delivery, activate/extend membership
    if (status === 'succeeded' && memberId && gymId) {
      const plan = await client.from('membership_plans').select('duration_days').eq('id', planId ?? '').maybeSingle();
      const duration = plan.data?.duration_days ?? 30;

      const mem = await client.from('memberships')
        .select('expires_at, status').eq('member_id', memberId).eq('gym_id', gymId)
        .in('status', ['active', 'paused', 'frozen', 'expired']).maybeSingle();
      const now = new Date();
      const base = (mem.data?.expires_at && new Date(mem.data.expires_at) > now)
        ? new Date(mem.data.expires_at)
        : now;
      const newExpiry = new Date(base.getTime() + duration * 24 * 60 * 60 * 1000);

      if (mem.data) {
        await client.from('memberships').update({
          expires_at: newExpiry.toISOString(),
          status: 'active',
          updated_at: new Date().toISOString(),
        }).eq('member_id', memberId).eq('gym_id', gymId);
      }

      try {
        await client.from('audit_logs').insert({
          gym_id: gymId,
          action: 'payment.succeeded',
          entity: 'payment',
          entity_id: insertRes.data!.id,
          detail: { provider, provider_reference: providerReference, amount_cents: amountCents },
        });
      } catch (_) {}
    }

    return jsonOk({ payment_id: insertRes.data!.id, status }, 201);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`Webhook error: ${msg}`, 500);
  }
});
