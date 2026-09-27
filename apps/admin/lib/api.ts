// Sunnah Life admin — typed API client for the NestJS API (same REST contract
// as the web PWA: docs/API_CONTRACTS.md). Token in localStorage (admin desktop
// tool; the mobile/web apps use HttpOnly cookies).
export const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE ?? "http://localhost:3001";

let token: string | null = null;
export function setToken(t: string | null) {
  token = t;
  if (typeof window !== "undefined") {
    if (t) window.localStorage.setItem("sl_admin_token", t);
    else window.localStorage.removeItem("sl_admin_token");
  }
}
export function getToken(): string | null {
  if (token) return token;
  if (typeof window !== "undefined") token = window.localStorage.getItem("sl_admin_token");
  return token;
}

async function call<T>(path: string, init?: RequestInit & { json?: unknown }): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(getToken() ? { Authorization: `Bearer ${getToken()}` } : {}),
      ...(init?.headers ?? {}),
    },
    body: init?.json !== undefined ? JSON.stringify(init.json) : init?.body,
    cache: "no-store",
  });
  const data = res.status === 204 ? null : await res.json().catch(() => null);
  if (!res.ok) throw new Error((data as { error?: string })?.error ?? `HTTP ${res.status}`);
  return data as T;
}

// ── domain shapes (mirrors packages/api src/shared/domain.ts) ───────────────
export interface AdminUser {
  id: string; phone: string | null; name: string; gender: "M" | "F";
  role: string; category: string; memberCode: string | null; level: string;
  usrahId: string | null; lastActiveAt: string;
}
export interface UsrahHealth {
  id: string; name: string; gender: string; memberCount: number;
  reviewPct: number; avgCompletion: number; inactiveCount: number; headName: string | null;
}
export interface Overview {
  me: AdminUser;
  totals: { users: number; daees: number; usrahs: number; pendingReviews: number };
  usrahs: UsrahHealth[];
  recentAudit: { id: string; action: string; actorName: string | null; targetId: string | null; meta: Record<string, unknown> | null; createdAt: string }[];
}
export interface MonthGridResponse {
  user: { id: string; name: string; memberCode: string | null; category: string };
  month: string;
  rows: { amalKey: string; titleBn: string; category: string; cells: ({ value: unknown; source: string } | null)[] }[];
  days: number[];
}
export interface ReviewQueueItem {
  id: string; userId: string; userName: string; memberCode: string | null;
  level: string; completion7d: number; status: string; weekStart: string;
}
export interface DefRow {
  key: string; titleBn: string; inputType: string; cadence: string;
  category: string; sortOrder: number; target: Record<string, number> | null;
}

// ── endpoints ────────────────────────────────────────────────────────────────
export const api = {
  requestOtp: (phone: string) =>
    call<{ ok: boolean; devCode: string }>("/api/auth/otp/request", { method: "POST", json: { phone } }),
  verifyOtp: (phone: string, code: string) =>
    call<{ user: AdminUser; accessToken: string; refreshToken?: string }>("/api/auth/otp/verify", { method: "POST", json: { phone, code } }),
  me: () => call<{ user: AdminUser | null }>("/api/me"),
  overview: () => call<Overview>("/api/admin/overview"),
  users: (q: string) => call<{ users: AdminUser[] }>(`/api/admin/users?q=${encodeURIComponent(q)}`),
  monthGrid: (userId: string, month: string) =>
    call<MonthGridResponse>(`/api/admin/month-grid?userId=${userId}&month=${month}`),
  reviewQueue: () => call<{ queue: ReviewQueueItem[] }>("/api/reviews?scope=queue"),
  completeReview: (reviewId: string, comment: string, rating: number, nextGoals: string) =>
    call<unknown>(`/api/reviews?id=${reviewId}`, { method: "POST", json: { comment, rating, nextGoals } }),
  definitions: () => call<{ definitions: DefRow[] }>("/api/amal/definitions"),
  upsertDefinition: (d: Partial<DefRow> & { key: string }) =>
    call<{ definitions: DefRow[] }>("/api/admin/amal-catalog", { method: "POST", json: d }),
  audit: () => call<{ entries: unknown[] }>("/api/admin/audit"),
};
