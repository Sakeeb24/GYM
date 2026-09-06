// supabase/functions/createRazorpayOrder/index.ts
// Secure Razorpay Order Creation Server-Side Endpoint
import {
  createAdminClient,
  requireAuth,
  jsonOk,
  jsonError,
  corsHeaders,
} from '../_shared/supabaseServer.ts';

interface CreateOrderReq {
  plan_id: string;
  amount_inr?: number;
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (req.method !== 'POST') return jsonError('Method not allowed', 405);

  try {
    const auth = await requireAuth(req);
    if (auth instanceof Response) return auth;
    const { client, user, gymId } = auth;

    const body: CreateOrderReq = await req.json();
    if (!body.plan_id) return jsonError('plan_id is required', 400);

    const admin = createAdminClient();

    // 1. Fetch Plan Details
    const { data: plan, error: planErr } = await admin
      .from('membership_plans')
      .select('id, name, duration_days, price_cents')
      .eq('id', body.plan_id)
      .single();

    if (planErr || !plan) {
      return jsonError('Membership plan not found', 404);
    }

    // 2. Fetch Member Record
    const { data: member, error: memberErr } = await admin
      .from('members')
      .select('id, full_name, phone, email')
      .eq('profile_id', user.id)
      .eq('gym_id', gymId)
      .single();

    if (memberErr || !member) {
      return jsonError('Member profile not found for this gym', 404);
    }

    // 3. Amount in paise (1 INR = 100 paise)
    const amountPaise = plan.price_cents > 0 ? plan.price_cents : (body.amount_inr ? body.amount_inr * 100 : 199900);
    const receiptId = `rcpt_${member.id.substring(0, 8)}_${Date.now()}`;

    // 4. Generate order identifier (simulated or real Razorpay API invocation)
    const razorpayKeyId = Deno.env.get('RAZORPAY_KEY_ID') || 'rzp_test_liftflow_demo';
    const razorpayKeySecret = Deno.env.get('RAZORPAY_KEY_SECRET') || 'secret_liftflow_demo';

    let orderId = `order_${crypto.randomUUID().replaceAll('-', '').substring(0, 16)}`;

    // If live credentials present, invoke Razorpay API
    if (Deno.env.get('RAZORPAY_KEY_ID') && Deno.env.get('RAZORPAY_KEY_SECRET')) {
      try {
        const basicAuth = btoa(`${razorpayKeyId}:${razorpayKeySecret}`);
        const rzpRes = await fetch('https://api.razorpay.com/v1/orders', {
          method: 'POST',
          headers: {
            'Authorization': `Basic ${basicAuth}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            amount: amountPaise,
            currency: 'INR',
            receipt: receiptId,
            notes: {
              gym_id: gymId,
              member_id: member.id,
              plan_id: plan.id,
            },
          }),
        });
        if (rzpRes.ok) {
          const rzpData = await rzpRes.json();
          orderId = rzpData.id;
        }
      } catch (_) {
        // Fallback to local order ID
      }
    }

    // 5. Create pending payment record
    const { data: paymentRow } = await admin.from('payments').insert({
      gym_id: gymId,
      member_id: member.id,
      provider: 'razorpay',
      provider_reference: orderId,
      amount_cents: amountPaise,
      currency: 'INR',
      status: 'pending',
      idempotency_key: orderId,
    }).select('id').single();

    return jsonOk({
      order_id: orderId,
      amount_paise: amountPaise,
      currency: 'INR',
      key_id: razorpayKeyId,
      receipt: receiptId,
      plan: {
        id: plan.id,
        name: plan.name,
        duration_days: plan.duration_days,
      },
      member: {
        id: member.id,
        name: member.full_name,
        phone: member.phone,
        email: member.email,
      },
    }, 201);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`createRazorpayOrder error: ${msg}`, 500);
  }
});
