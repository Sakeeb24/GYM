// Derived TypeScript port of the canonical Dart business rules (docs/BUSINESS_RULES.md).
// These MUST match lib/core/business_rules/... exactly for each release.

export type AppRole = 'owner' | 'front_desk' | 'trainer' | 'member';

export type MembershipStatus = 'active' | 'paused' | 'frozen' | 'expired' | 'canceled' | 'expiring' | 'inactive';

export interface MembershipLike {
  canceledAt: Date | null;
  pausedUntil: Date | null;
  expiresAt: Date | null;
  startedAt: Date;
}

// R1
export function computeMembershipStatus(m: MembershipLike, now: Date = new Date()): MembershipStatus {
  if (m.canceledAt) return 'canceled';
  if (m.pausedUntil && m.pausedUntil > now) return 'paused';
  if (m.expiresAt && m.expiresAt <= now) return 'expired';
  if (m.expiresAt && m.expiresAt <= new Date(now.getTime() + 24 * 60 * 60 * 1000)) return 'expiring';
  return 'active';
}

// Active for retention = eligible for no-show consideration.
export function isActiveForRetention(m: MembershipLike, now: Date = new Date()): boolean {
  const s = computeMembershipStatus(m, now);
  return s === 'active' || s === 'paused' || s === 'frozen' || s === 'expiring';
}

// R2
export function canCheckIn(m: MembershipLike, now: Date = new Date()): boolean {
  const s = computeMembershipStatus(m, now);
  if (s === 'canceled' || s === 'expired') return false;
  return now >= m.startedAt;
}

// R7 renewal windows ----------------------------------------------------------
export interface RenewalInputLike {
  commOptedIn: boolean;
  reminderWindows: number[]; // ascending expected
  postExpiryDays: number;
  expiresAt: Date | null;
}

// R6: eligible when active/expiring/expired, subscribed, not canceled (canceled
// excluded upstream by the scan query).
export function renewalEligible(input: RenewalInputLike): boolean {
  if (!input.commOptedIn) return false;
  return true;
}

// R7: the reminder stage due NOW (band upper = smallest window >= daysUntil).
export function dueReminderStage(
  input: RenewalInputLike,
  now: Date = new Date(),
): string | null {
  if (!input.expiresAt) return null;
  const daysUntil = Math.floor((input.expiresAt.getTime() - now.getTime()) / 86400000);
  if (daysUntil < 0) {
    if (-daysUntil <= input.postExpiryDays) return 'post_expiry';
    return null;
  }
  const windows = [...input.reminderWindows].sort((a, b) => a - b);
  for (const w of windows) {
    if (daysUntil <= w) return `d_${w}`;
  }
  return null;
}

// R4 no-show -----------------------------------------------------------------
export interface NoShowInput {
  membership: MembershipLike;
  lastCheckInAt: Date | null;
  inactivityThresholdDays: number;
}

export function shouldOpenNoShowCase(input: NoShowInput, now: Date = new Date()): boolean {
  if (!isActiveForRetention(input.membership, now)) return false;
  if (!input.lastCheckInAt) return true;
  const ms = now.getTime() - input.lastCheckInAt.getTime();
  return ms >= input.inactivityThresholdDays * 86400000;
}

export interface StreakResult {
  current: number;
  longest: number;
}
export function computeStreak(
  checkIns: Date[],
  opts: { minConsecutive?: number; initialLongest?: number } = {},
): StreakResult {
  if (checkIns.length === 0) {
    return { current: 0, longest: opts.initialLongest ?? 0 };
  }
  const min = opts.minConsecutive ?? 1;
  const dayMap = new Map<number, Date>();
  for (const d of checkIns) {
    const dayDate = new Date(d.getFullYear(), d.getMonth(), d.getDate());
    dayMap.set(dayDate.getTime(), dayDate);
  }
  const days = Array.from(dayMap.values()).sort((a, b) => a.getTime() - b.getTime());

  let run = 1;
  let longest = Math.max(1, opts.initialLongest ?? 0);
  for (let i = 1; i < days.length; i++) {
    const diff = Math.round((days[i].getTime() - days[i - 1].getTime()) / 86400000);
    if (diff === 1) {
      run += 1;
    } else {
      run = 1;
    }
    if (run > longest) longest = run;
  }

  const current = run >= min ? run : 0;
  const effectiveLongest = longest >= min ? longest : (opts.initialLongest ?? 0);
  return { current, longest: effectiveLongest };
}
export const CAPABILITIES = {
  selfCheckIn: ['member', 'owner'],
  assistedCheckIn: ['front_desk', 'owner'],
  createMember: ['front_desk', 'owner'],
  editMember: ['front_desk', 'owner'],
  manageRedList: ['front_desk', 'owner'],
  managePlans: ['owner'],
  manageStaff: ['owner'],
  manageSettings: ['owner'],
  managePayments: ['owner'],
  viewReports: ['owner', 'front_desk'],
} as const;

export function roleCan(role: AppRole, capability: keyof typeof CAPABILITIES): boolean {
  return (CAPABILITIES[capability] as readonly string[]).includes(role);
}

// R10: internal/cron authorisation (service-to-service).
export function assertCron(req: Request): boolean {
  const url = new URL(req.url);
  const token = url.searchParams.get('token');
  const expected = Deno.env.get('CRON_TOKEN');
  if (!expected || !token) return false;
  return token === expected;
}
