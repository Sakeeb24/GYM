import {
  createAdminClient,
  requireAuth,
  jsonOk,
  jsonError,
} from '../_shared/supabaseServer.ts';
import { roleCan } from '../_shared/business_rules.ts';

// createMember: owner/front_desk only (R10). Server-side gym assignment — the
// client can NEVER specify another gym's id.

interface CreateMemberReq {
  full_name: string;
  phone?: string;
  email?: string;
  member_number: string;
  plan_id?: string; // optional: activate a membership on creation
  dob?: string; // ISO date
}

Deno.serve(async (req: Request) => {
  try {
    const auth = await requireAuth(req);
    if (auth instanceof Response) return auth;
    const { client, gymId, role } = auth;
    if (!roleCan(role, 'createMember')) {
      return jsonError('Forbidden: only owner/front_desk can create members', 403);
    }

    const body: CreateMemberReq = await req.json();
    if (!body.full_name || body.full_name.trim().length < 2) {
      return jsonError('Invalid member name', 400);
    }
    if (!body.member_number) return jsonError('member_number required', 400);

    const insertRes = await client.from('members').insert({
      gym_id: gymId, // server-controlled tenant; ignores any client gym_id
      member_number: body.member_number,
      full_name: body.full_name.trim(),
      phone: body.phone ?? null,
      email: body.email ?? null,
      dob: body.dob ?? null,
      status: 'active',
    }).select('id').single();
    if (insertRes.error) {
      if (insertRes.error.message?.includes('member_unique_per_gym_number')) {
        return jsonError('Member number already exists in this gym', 409);
      }
      return jsonError(`Create member failed: ${insertRes.error.message}`, 500);
    }

    const memberId = insertRes.data!.id;

    // Optionally activate a membership.
    if (body.plan_id) {
      const plan = await client.from('membership_plans').select('duration_days,grace_period_days')
        .eq('id', body.plan_id).eq('gym_id', gymId).maybeSingle();
      if (!plan.data) return jsonError('Plan not found', 404);
      const dur = (plan.data as { duration_days: number }).duration_days ?? 30;
      await client.from('memberships').insert({
        gym_id: gymId,
        member_id: memberId,
        plan_id: body.plan_id,
        status: 'active',
        started_at: new Date().toISOString(),
        expires_at: new Date(Date.now() + dur * 86400000).toISOString(),
      });
    }

    await client.from('audit_logs').insert({
      gym_id: gymId, actor_user_id: auth.user.id, action: 'member.created',
      entity: 'member', entity_id: memberId,
      detail: { member_number: body.member_number },
    });

    return jsonOk({ member_id: memberId }, 201);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(`createMember error: ${msg}`, 500);
  }
});
