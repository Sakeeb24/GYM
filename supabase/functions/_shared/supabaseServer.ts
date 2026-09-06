import { createClient, SupabaseClient, User } from 'npm:@supabase/supabase-js@2';
import { AppRole } from './business_rules.ts';

// Service-role client: privileged, MUST only run server-side in Edge Functions.
export function createAdminClient(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required');
  }
  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export interface AuthedContext {
  client: SupabaseClient;
  user: User;
  gymId: string; // tenant boundary, read from verified user/app_metadata
  role: AppRole;
}

function bearerToken(req: Request): string | undefined {
  const header = req.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return undefined;
  return header.substring(7);
}

// Centralised, server-side authorisation (rule 10). Returns a 401/403 JSON
// Response on failure, or the authenticated context on success. Callers narrow
// with `if (auth instanceof Response) return auth;`.
export async function requireAuth(
  req: Request,
  opts: { client?: SupabaseClient } = {},
): Promise<AuthedContext | Response> {
  const token = bearerToken(req);
  if (!token) {
    return jsonError('Unauthorized: missing bearer token', 401);
  }
  const client = opts.client ?? createAdminClient();
  const { data: { user }, error: authError } = await client.auth.getUser(token);
  if (authError || !user) {
    return jsonError('Unauthorized: invalid session', 401);
  }
  const app = (user.app_metadata ?? {}) as { gym_id?: string; role?: string };
  const gymId = app.gym_id;
  const role = parseRole(app.role);
  if (!gymId || !role) {
    return jsonError('Forbidden: user has no gym assignment', 403);
  }
  return { client, user, gymId, role };
}

const roleOrder: AppRole[] = ['owner', 'front_desk', 'trainer', 'member'];

export function parseRole(value: unknown): AppRole | undefined {
  if (typeof value === 'string' && roleOrder.includes(value as AppRole)) {
    return value as AppRole;
  }
  return undefined;
}

// Standard CORS headers allowing all Supabase client headers
export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-retry-count, traceparent, tracestate, baggage',
};

// JSON response helpers.
export function jsonOk(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
    },
  });
}
export function jsonError(message: string, status: number): Response {
  return jsonOk({ error: message }, status);
}
