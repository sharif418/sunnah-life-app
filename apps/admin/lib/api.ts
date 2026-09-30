// ─────────────────────────────────────────────────────────────────────────────
// Sunnah Life admin — typed API client for the NestJS API.
//
// ONE variable decides where requests go: NEXT_PUBLIC_API_BASE (e.g.
// https://api.sunnahlife.app), baked at BUILD time — pass it as a Docker
// build arg (infra/admin.Dockerfile) or set it in the dev environment.
// Empty → same-origin requests (a reverse proxy fronts both apps).
//
// Auth: Bearer access token (15 min) + rotating refresh token; both live in
// localStorage (desktop admin tool — the PWA/mobile apps use HttpOnly cookies).
// A 401 triggers one transparent refresh + retry before giving up.
// ─────────────────────────────────────────────────────────────────────────────

export const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "";

export const TOKEN_KEY = "sl_admin_token";
export const REFRESH_KEY = "sl_admin_refresh";

let token: string | null = null;
let refreshToken: string | null = null;

export function setTokens(access: string | null, refresh?: string | null) {
  token = access;
  if (typeof window !== "undefined") {
    if (access) window.localStorage.setItem(TOKEN_KEY, access);
    else window.localStorage.removeItem(TOKEN_KEY);
    if (refresh) window.localStorage.setItem(REFRESH_KEY, refresh);
    else if (refresh === null) window.localStorage.removeItem(REFRESH_KEY);
  }
}

export function getToken(): string | null {
  if (token) return token;
  if (typeof window !== "undefined") token = window.localStorage.getItem(TOKEN_KEY);
  return token;
}

function getRefreshToken(): string | null {
  if (refreshToken) return refreshToken;
  if (typeof window !== "undefined") refreshToken = window.localStorage.getItem(REFRESH_KEY);
  return refreshToken;
}

/** Read the stored refresh token (for logout revocation). */
export function getRefreshTokenSafe(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(REFRESH_KEY);
}

/** Absolute (or same-origin when API_BASE is empty) URL for a path. */
export function gatewayUrl(path: string): string {
  return `${API_BASE}${path}`;
}

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
    this.name = "ApiError";
  }
}

/** Fired when the session is unrecoverable (refresh failed) — session.tsx listens. */
export const SESSION_EXPIRED_EVENT = "sl_admin_session_expired";

type CallInit = RequestInit & { json?: unknown; skipAuthRefresh?: boolean };

async function rawCall<T>(path: string, init?: CallInit): Promise<T> {
  const res = await fetch(gatewayUrl(path), {
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
  if (!res.ok) {
    throw new ApiError(res.status, (data as { error?: string })?.error ?? `HTTP ${res.status}`);
  }
  return data as T;
}

async function call<T>(path: string, init?: CallInit): Promise<T> {
  try {
    return await rawCall<T>(path, init);
  } catch (err) {
    const is401 = err instanceof ApiError && err.status === 401;
    const canRefresh =
      is401 && !init?.skipAuthRefresh && !path.startsWith("/api/auth/") && getRefreshToken();
    if (!canRefresh) throw err;
    // one transparent refresh + retry
    try {
      const refreshed = await rawCall<{ accessToken: string; refreshToken: string }>(
        "/api/auth/refresh",
        { method: "POST", json: { refreshToken: getRefreshToken() }, skipAuthRefresh: true }
      );
      setTokens(refreshed.accessToken, refreshed.refreshToken);
      return await rawCall<T>(path, init);
    } catch {
      setTokens(null, null);
      if (typeof window !== "undefined") {
        window.dispatchEvent(new Event(SESSION_EXPIRED_EVENT));
      }
      throw err instanceof ApiError ? err : new ApiError(401, "সেশন শেষ হয়ে গেছে — আবার লগইন করুন");
    }
  }
}

// ── domain shapes (verified against apps/api/src/shared/domain.ts + live API) ─

export type Gender = "M" | "F";
export type Role = "user" | "daee" | "usrah_head" | "invigilator" | "full_admin";
export type Level = "none" | "muhibbus_sunnah" | "farze_ain_1" | "farze_ain_2";
export type UserCategory = "general" | "hafez" | "alim";
export type AmalInputType = "tristate" | "boolean" | "count" | "quantity" | "text";
export type AmalCadence =
  | "daily"
  | "weekly:any"
  | "weekly:fri"
  | "weekly:mon_thu"
  | "monthly:ayyam_beez";
export type AmalCategory =
  | "salah"
  | "quran"
  | "dhikr"
  | "akhlaq"
  | "dawat"
  | "lifestyle"
  | "sunnah"
  | "personal";
export type AmalValue = "jamaat" | "alone" | "qaza" | boolean | number | string;

export interface User {
  id: string;
  phone: string | null;
  name: string;
  photoUrl: string | null;
  gender: Gender;
  role: Role;
  category: UserCategory;
  memberCode: string | null;
  referredById: string | null;
  usrahId: string | null;
  level: Level;
  levelStartedAt: string | null;
  district: string | null;
  workplace: string | null;
  department: string | null;
  language: "bn" | "en" | "ar";
  madhhab: "hanafi" | "shafii";
  calcMethod: string;
  lat: number | null;
  lng: number | null;
  city: string | null;
  createdAt: string;
  lastActiveAt: string;
  usrahName?: string | null;
}

export interface AmalDefinition {
  key: string;
  titleBn: string;
  titleEn: string;
  category: AmalCategory;
  inputType: AmalInputType;
  cadence: AmalCadence;
  target: Record<string, number> | null;
  unit: string | null;
  minLevel: Level;
  sortOrder: number;
  autoSource: string | null;
  /** Present when the API includes it; /api/amal/definitions returns active-only. */
  active?: boolean;
}

export interface AmalEntry {
  id?: string;
  amalKey: string;
  date: string;
  clientUpdatedAt: string;
  value: AmalValue;
  source: string;
  serverUpdatedAt?: string;
}

export interface UsrahHealth {
  id: string;
  name: string;
  gender: Gender;
  district: string | null;
  members: number;
  reviewPct: number;
  avgCompletion: number;
  inactiveCount: number;
}

export interface AuditEntry {
  id: string;
  actorId: string | null;
  actorName?: string | null;
  action: string;
  targetType: string;
  targetId: string | null;
  meta: Record<string, unknown> | null;
  createdAt: string;
}

export interface AdminOverview {
  role: Role;
  totals: { users: number; daees: number; usrahs: number; pendingReviews: number };
  usrahs: UsrahHealth[];
  recentAudit: AuditEntry[];
}

export interface MonthGridCell {
  date: string;
  value: AmalValue | null;
  source: string;
}
export interface MonthGrid {
  amalKeys: string[];
  definitions: AmalDefinition[];
  days: string[];
  rows: Record<string, MonthGridCell[]>;
}

export interface UsrahMember {
  id: string;
  name: string;
  gender: Gender;
  level: Level;
  memberCode: string | null;
  category: UserCategory;
  lastActiveAt: string;
  completion7d?: number | null;
}

export interface Usrah {
  id: string;
  name: string;
  gender: Gender;
  headUserId: string | null;
  invigilatorUserId: string | null;
  district: string | null;
  headName?: string | null;
  memberCount?: number;
  members?: UsrahMember[];
}

export interface Announcement {
  id: string;
  usrahId: string | null;
  authorId: string;
  authorName?: string | null;
  kind: "announcement" | "question" | "exam";
  body: string;
  pinned: boolean;
  createdAt: string;
}

export interface WeeklyReview {
  id: string;
  userId: string;
  userName?: string;
  reviewerId: string;
  reviewerName?: string | null;
  weekStart: string;
  summary: {
    overallPct?: number;
    byCategory?: Record<string, number>;
    streak?: number;
    missedDays?: number;
    counts?: Record<string, number>;
  } | null;
  comment: string | null;
  rating: number | null;
  nextGoals: string | null;
  status: "pending" | "done" | "overdue";
  createdAt: string;
  completedAt: string | null;
  user?: UsrahMember;
}

export interface AssessmentCriterion {
  key: string;
  titleBn: string;
  hintBn?: string;
}
export interface AssessmentSection {
  key: string;
  titleBn: string;
  criteria: AssessmentCriterion[];
}
export interface AssessmentTemplate {
  key: string;
  version: number;
  titleBn: string;
  titleEn: string;
  sections: AssessmentSection[];
}
export interface AssessmentDetail {
  id: string;
  templateKey: string;
  result: "passed" | "not_yet";
  createdAt: string;
  assessorSignedAt: string | null;
  assesseeSignedAt: string | null;
  participantCategory: number;
  scorePct: number | null;
  template: AssessmentTemplate;
  assessorName?: string;
  assesseeName?: string;
  scores: Record<string, { score: 0 | 1 | 2; comment?: string }>;
  overallComment: string | null;
}

export interface LiveProgramItem {
  id: string;
  titleBn: string;
  descBn: string | null;
  hostName: string | null;
  startsAt: string;
  endsAt: string | null;
  youtubeId: string | null;
  gender: Gender;
  status: "upcoming" | "live" | "past";
  recordingUrl: string | null;
}

export interface ReminderItem {
  id: string;
  kind: string;
  title: string;
  body: string | null;
  link: string | null;
  scheduledAt: string | null;
  read: boolean;
  createdAt: string;
}

/** B6 — level promotion history row (GET /api/admin/level-transitions). */
export interface LevelTransitionItem {
  id: string;
  userId: string;
  userName: string;
  memberCode: string | null;
  gender: Gender;
  fromLevel: Level;
  toLevel: Level;
  method: "auto" | "admin";
  reason: string | null;
  actorId: string | null;
  at: string;
}

/** B6 — admin view of one assessment template version. */
export interface AdminTemplateItem {
  id: string;
  key: string;
  version: number;
  titleBn: string;
  titleEn: string;
  active: boolean;
  sections: AssessmentSection[];
  createdAt: string;
}

/** B6 — admin payload for live program create/edit. */
export interface LiveProgramInput {
  titleBn: string;
  descBn?: string | null;
  hostName?: string | null;
  startsAt: string;
  endsAt?: string | null;
  youtubeId?: string | null;
  gender?: Gender;
  recordingUrl?: string | null;
}

export interface GoalItem {
  id: string;
  amalKey: string;
  title: string;
  note: string | null;
  target: string | null;
  startDate: string;
  active: boolean;
  createdAt: string;
}

/** W4d — support inbox row (GET /api/admin/support). */
export interface SupportThreadItem {
  id: string;
  userId: string;
  userName: string;
  userMemberCode: string | null;
  userGender: Gender;
  subject: string;
  status: "open" | "answered" | "closed";
  messageCount: number;
  lastMessageAt: string | null;
  lastPreview: string | null;
  lastFromAdmin: boolean;
  createdAt: string;
  closedAt: string | null;
}

/** W4d — one thread + full history (GET /api/admin/support/:id). */
export interface SupportThreadDetail {
  thread: {
    id: string;
    userId: string;
    subject: string;
    status: "open" | "answered" | "closed";
    createdAt: string;
    updatedAt: string;
    closedAt: string | null;
  };
  messages: {
    id: string;
    threadId: string;
    authorId: string;
    authorName: string | null;
    isAdmin: boolean;
    body: string;
    createdAt: string;
  }[];
}

/** W4d — usrah join-request queue row (GET /api/usrah/join-requests). */
export interface UsrahJoinRequestItem {
  id: string;
  userId: string;
  userName: string;
  userGender: Gender;
  message: string | null;
  status: "pending" | "approved" | "rejected";
  handledById: string | null;
  handledAt: string | null;
  usrahId: string | null;
  usrahName: string | null;
  reason: string | null;
  createdAt: string;
}

/** W4h — GET /api/usrah/goals row (the supervisor approval queue). */
export interface GoalQueueItem extends GoalItem {
  status: "proposed" | "approved" | "rejected" | "completed" | "withdrawn";
  decidedById: string | null;
  decidedAt: string | null;
  reason: string | null;
  userName: string;
}

/** W4h — GET /api/admin/level-rules row: the raw merged node + its origin. */
export interface LevelRulesLevelInfo {
  node: Record<string, unknown>;
  source: "db" | "pack" | "default";
}
export interface LevelRulesDoc {
  levels: Record<string, LevelRulesLevelInfo>;
  packNote: string | null;
}

/** W4h — GET /api/admin/invigilator-health row (mirror of the API type). */
export interface InvigilatorHealthRow {
  id: string;
  name: string;
  memberCode: string | null;
  gender: Gender;
  usrahNames: string[];
  memberCount: number;
  reviewPct: number | null;
  amalPct: number | null;
  activePct: number | null;
  overdueCount: number;
  assessments30d: number;
  unsignedAssessments: number;
  score: number | null;
}

/** W4h — one node of the cursor-paged referral forest. */
export interface ReferralTreeNode {
  id: string;
  name: string;
  gender: Gender;
  level: Level;
  memberCode: string | null;
  role: Role;
  lastActiveAt: string;
  joinedAt: string;
  childCount: number;
}
export interface ReferralTreePage {
  nodes: ReferralTreeNode[];
  nextCursor: string | null;
  remaining: number;
}

/** W4h — the admin-editable app configuration (GET/PATCH /api/admin/config). */
export interface AdminAppConfig {
  donationUrl: string;
  domain: string;
  hijriAdjust: number;
  nisab: { goldPerGramBdt: number; silverPerGramBdt: number };
  contacts: {
    org: string;
    descBn: string;
    phone?: string;
    email?: string;
    website?: string;
    address?: string;
  }[];
  groups: { titleBn: string; url: string; descBn?: string }[];
  audioBase: string;
  leaderboardEnabled: boolean;
  detoxEnabled: boolean;
}

export interface MonthlyReportItem {
  id: string;
  userId: string;
  userName: string | null;
  memberCode: string | null;
  month: string;
  storageKey: string;
  byteSize: number;
  status: string;
  errorBn: string | null;
  generatedAt: string;
}

// ── endpoints ────────────────────────────────────────────────────────────────

export const api = {
  // auth
  requestOtp: (phone: string) =>
    call<{ ok: boolean; devCode: string }>("/api/auth/otp/request", {
      method: "POST",
      json: { phone },
      skipAuthRefresh: true,
    }),
  verifyOtp: (phone: string, code: string) =>
    call<{ user: User; accessToken: string; refreshToken: string; tokenType: string; expiresIn: number }>(
      "/api/auth/otp/verify",
      { method: "POST", json: { phone, code }, skipAuthRefresh: true }
    ),
  logout: (refresh: string | null) =>
    call<{ ok: boolean }>("/api/auth/logout", {
      method: "POST",
      json: { refreshToken: refresh ?? undefined },
      skipAuthRefresh: true,
    }).catch(() => ({ ok: true }) as { ok: boolean }),

  // me
  me: () => call<{ user: User | null }>("/api/me"),

  // amal
  definitions: () => call<{ definitions: AmalDefinition[] }>("/api/amal/definitions"),
  amalEntries: (from: string, to: string, userId?: string) =>
    call<{ entries: AmalEntry[] }>(
      `/api/amal/entries?from=${from}&to=${to}${userId ? `&userId=${userId}` : ""}`
    ),
  unlockDay: (userId: string, date: string, reason?: string) =>
    call<{ ok: boolean }>("/api/amal/unlock", {
      method: "POST",
      json: { userId, date, reason },
    }),

  // admin
  overview: () => call<AdminOverview>("/api/admin/overview"),
  users: (q: string) => call<{ users: User[] }>(`/api/admin/users?q=${encodeURIComponent(q)}`),
  patchUser: (dto: {
    userId: string;
    role?: Role;
    gender?: Gender;
    usrahId?: string | null;
    category?: UserCategory;
    reason?: string;
  }) =>
    call<{ user: User }>("/api/admin/users", { method: "PATCH", json: dto }),
  promote: (userId: string, toLevel: Level, reason: string) =>
    call<{ user: User }>("/api/admin/promote", {
      method: "POST",
      json: { userId, toLevel, reason },
    }),
  levelTransitions: () =>
    call<{ transitions: LevelTransitionItem[] }>("/api/admin/level-transitions"),
  monthGrid: (userId: string, month: string) =>
    call<{ grid: MonthGrid }>(`/api/admin/month-grid?userId=${userId}&month=${month}`),
  broadcast: (dto: { usrahId?: string | null; gender?: Gender | null; body: string }) =>
    call<{ ok: boolean }>("/api/admin/broadcast", { method: "POST", json: dto }),
  upsertCatalog: (dto: {
    key: string;
    titleBn?: string;
    titleEn?: string;
    category?: AmalCategory;
    inputType?: AmalInputType;
    cadence?: AmalCadence;
    target?: Record<string, number> | null;
    unit?: string | null;
    minLevel?: Level;
    sortOrder?: number;
    autoSource?: string | null;
    active?: boolean;
  }) =>
    call<{ definitions: AmalDefinition[] }>("/api/admin/amal-catalog", {
      method: "POST",
      json: dto,
    }),
  /** B6: full catalog incl. inactive. */
  adminCatalog: () => call<{ definitions: AmalDefinition[] }>("/api/admin/amal-catalog"),
  patchCatalog: (key: string, dto: Partial<Omit<AmalDefinition, "key">>) =>
    call<{ definition: AmalDefinition }>(`/api/admin/amal-catalog/${encodeURIComponent(key)}`, {
      method: "PATCH",
      json: dto,
    }),
  reorderCatalog: (keys: string[]) =>
    call<{ definitions: AmalDefinition[] }>("/api/admin/amal-catalog", {
      method: "PATCH",
      json: { keys },
    }),

  // B6: versioned assessment templates
  adminTemplates: () => call<{ templates: AdminTemplateItem[] }>("/api/admin/assessment-templates"),
  createTemplateVersion: (dto: {
    key: string;
    titleBn: string;
    titleEn?: string;
    sections: AssessmentSection[];
    version?: number;
  }) =>
    call<{ template: AdminTemplateItem }>("/api/admin/assessment-templates", {
      method: "POST",
      json: dto as unknown as Record<string, unknown>,
    }),
  patchTemplate: (
    id: string,
    dto: { active?: boolean; titleBn?: string; titleEn?: string; sections?: AssessmentSection[] }
  ) =>
    call<{ template: AdminTemplateItem }>(`/api/admin/assessment-templates/${id}`, {
      method: "PATCH",
      json: dto as unknown as Record<string, unknown>,
    }),

  // B6: usrah management
  createUsrah: (dto: { name: string; gender: Gender; district?: string }) =>
    call<{ usrah: Usrah }>("/api/admin/usrah", { method: "POST", json: dto }),
  patchUsrah: (
    id: string,
    dto: { name?: string; headUserId?: string | null; invigilatorUserId?: string | null; district?: string | null }
  ) => call<{ usrah: Usrah }>(`/api/admin/usrah/${id}`, { method: "PATCH", json: dto }),
  addUsrahMember: (usrahId: string, userId: string) =>
    call<{ ok: boolean }>(`/api/admin/usrah/${usrahId}/members`, {
      method: "POST",
      json: { userId },
    }),
  removeUsrahMember: (usrahId: string, userId: string) =>
    call<{ ok: boolean }>(`/api/admin/usrah/${usrahId}/members/${userId}`, {
      method: "DELETE",
    }),

  // B6: live program CRUD
  createLiveProgram: (dto: LiveProgramInput) =>
    call<{ program: LiveProgramItem }>("/api/admin/live", { method: "POST", json: dto }),
  patchLiveProgram: (id: string, dto: Partial<LiveProgramInput>) =>
    call<{ program: LiveProgramItem }>(`/api/admin/live/${id}`, { method: "PATCH", json: dto }),
  deleteLiveProgram: (id: string) =>
    call<{ ok: boolean }>(`/api/admin/live/${id}`, { method: "DELETE" }),
  audit: () => call<{ entries: AuditEntry[] }>("/api/admin/audit"),

  // W4d: live support inbox (full_admin)
  supportInbox: (status?: string) =>
    call<{ threads: SupportThreadItem[] }>(
      `/api/admin/support${status ? `?status=${encodeURIComponent(status)}` : ""}`
    ),
  supportThread: (id: string) => call<SupportThreadDetail>(`/api/admin/support/${id}`),
  supportReply: (id: string, message: string) =>
    call<{ message: SupportThreadDetail["messages"][number] }>(`/api/admin/support/${id}/messages`, {
      method: "POST",
      json: { message },
    }),
  supportClose: (id: string) => call<{ thread: SupportThreadDetail["thread"] }>(`/api/admin/support/${id}/close`, {
    method: "POST",
  }),

  // W4d: usrah join-request queue (full_admin)
  joinRequests: () => call<{ requests: UsrahJoinRequestItem[] }>("/api/usrah/join-requests"),
  approveJoinRequest: (id: string, usrahId: string) =>
    call<{ request: UsrahJoinRequestItem }>(`/api/usrah/join-requests/${id}/approve`, {
      method: "POST",
      json: { usrahId },
    }),
  rejectJoinRequest: (id: string, reason?: string) =>
    call<{ request: UsrahJoinRequestItem }>(`/api/usrah/join-requests/${id}/reject`, {
      method: "POST",
      json: reason ? { reason } : {},
    }),

  // W4h: goal approval queue (usrah_head+; RLS scopes whose goals appear)
  goalQueue: () => call<{ queue: GoalQueueItem[] }>("/api/usrah/goals"),
  approveGoal: (id: string) =>
    call<{ goal: GoalQueueItem }>(`/api/goals/${id}/approve`, { method: "POST" }),
  rejectGoal: (id: string, reason?: string) =>
    call<{ goal: GoalQueueItem }>(`/api/goals/${id}/reject`, {
      method: "POST",
      json: reason ? { reason } : {},
    }),

  // W4h: level-rules editor (full_admin)
  levelRules: () => call<LevelRulesDoc>("/api/admin/level-rules"),
  updateLevelRules: (level: string, patch: Record<string, unknown>) =>
    call<{ level: string; node: Record<string, unknown>; changed: string[] }>(
      `/api/admin/level-rules/${encodeURIComponent(level)}`,
      { method: "PUT", json: patch }
    ),
  resetLevelRules: (level: string) =>
    call<{ level: string; reset: boolean }>(`/api/admin/level-rules/${encodeURIComponent(level)}`, {
      method: "DELETE",
    }),

  // W4h: invigilator health (full_admin: all; invigilator: self)
  invigilatorHealth: () => call<{ invigilators: InvigilatorHealthRow[] }>("/api/admin/invigilator-health"),

  // W4h: referral forest, cursor-paged (full_admin)
  referralTree: (opts: { userId?: string; cursor?: string; limit?: number } = {}) => {
    const qs = new URLSearchParams();
    if (opts.userId) qs.set("userId", opts.userId);
    if (opts.cursor) qs.set("cursor", opts.cursor);
    if (opts.limit) qs.set("limit", String(opts.limit));
    const q = qs.toString();
    return call<ReferralTreePage>(`/api/admin/referral-tree${q ? `?${q}` : ""}`);
  },

  // W4h: content pack CMS (full_admin write; the read is the public pack route)
  contentPack: (pack: string) =>
    call<{ pack: string; data: unknown }>(`/api/content/${encodeURIComponent(pack)}`),
  updateContentPack: (pack: string, doc: Record<string, unknown>) =>
    call<{ pack: string; itemCount: number; bytes: number }>(
      `/api/admin/content/${encodeURIComponent(pack)}`,
      { method: "PUT", json: doc }
    ),

  // W4h: app configuration CMS (full_admin)
  adminConfig: () => call<AdminAppConfig>("/api/admin/config"),
  updateAdminConfig: (dto: Partial<Omit<AdminAppConfig, "nisab">> & {
    nisab?: { goldPerGramBdt?: number; silverPerGramBdt?: number };
  }) =>
    call<AdminAppConfig>("/api/admin/config", { method: "PATCH", json: dto }),

  // usrah
  myUsrah: () => call<{ usrah: (Usrah & { members: UsrahMember[] }) | null; announcements: Announcement[] }>(
    "/api/usrah"
  ),

  // reviews
  reviewQueue: () => call<{ queue: WeeklyReview[] }>("/api/reviews?scope=queue"),
  submitReview: (dto: {
    userId: string;
    weekStart: string;
    comment?: string;
    rating: number;
    nextGoals?: string;
  }) => call<{ review: WeeklyReview }>("/api/reviews", { method: "POST", json: dto }),

  // assessments
  assessmentTemplates: () => call<{ templates: AssessmentTemplate[] }>("/api/assessments/templates"),
  assessments: (userId?: string) =>
    call<{ assessments: AssessmentDetail[] }>(
      userId ? `/api/assessments?userId=${userId}` : "/api/assessments"
    ),
  submitAssessment: (dto: {
    assesseeId: string;
    templateKey: string;
    participantCategory: 1 | 2;
    scores: Record<string, { score: 0 | 1 | 2; comment?: string }>;
    overallComment?: string;
  }) => call<{ assessment: AssessmentDetail }>("/api/assessments", { method: "POST", json: dto }),

  // live
  livePrograms: () => call<{ programs: LiveProgramItem[] }>("/api/live"),
  notifyLive: (id: string) => call<{ ok: boolean }>("/api/live", { method: "POST", json: { id } }),

  // reminders (own)
  reminders: () => call<{ reminders: ReminderItem[] }>("/api/reminders"),

  // goals (own)
  goals: () => call<{ goals: GoalItem[] }>("/api/goals"),

  // dawah dashboard (daee+): own member code, downline, level requirements
  dawah: () => call<DawahOverview>("/api/dawah"),

  // monthly Muhasaba PDF reports (B3)
  monthlyReports: (month?: string, userId?: string) => {
    const qs = new URLSearchParams();
    if (month) qs.set("month", month);
    if (userId) qs.set("userId", userId);
    const q = qs.toString();
    return call<{ reports: MonthlyReportItem[] }>(`/api/admin/reports${q ? `?${q}` : ""}`);
  },
  generateReport: (userId: string, month: string) =>
    call<MonthlyReportItem>("/api/admin/reports/generate", { method: "POST", json: { userId, month } }),
};

/**
 * Download a monthly report PDF through the gateway (auth header can't ride
 * on a plain window.open link — fetch → blob → object URL). One transparent
 * token refresh + retry on 401, same contract as call().
 */
export async function downloadReportPdf(report: MonthlyReportItem): Promise<void> {
  const doFetch = () =>
    fetch(gatewayUrl(`/api/admin/reports/${report.id}/download`), {
      headers: { ...(getToken() ? { Authorization: `Bearer ${getToken()}` } : {}) },
      cache: "no-store",
    });

  let res = await doFetch();
  if (res.status === 401) {
    const refreshed = await rawCall<{ accessToken: string; refreshToken: string }>("/api/auth/refresh", {
      method: "POST",
      json: { refreshToken: getRefreshToken() },
      skipAuthRefresh: true,
    });
    setTokens(refreshed.accessToken, refreshed.refreshToken);
    res = await doFetch();
  }
  if (!res.ok) {
    const data = (await res.json().catch(() => null)) as { error?: string } | null;
    throw new ApiError(res.status, data?.error ?? `HTTP ${res.status}`);
  }
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `muhasaba-${report.memberCode ?? report.userId.slice(0, 8)}-${report.month}.pdf`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

export interface DownlineNode {
  id: string;
  name: string;
  gender: Gender;
  level: Level;
  memberCode: string | null;
  depth: number;
  lastActiveAt: string;
  joinedAt: string;
}

export interface LevelRequirement {
  key: string;
  titleBn: string;
  done: boolean;
  detailBn?: string | null;
}

export interface DawahOverview {
  memberCode: string;
  referralLink: string;
  invitedCount: number;
  downline: DownlineNode[];
  level: Level;
  levelStartedAt: string | null;
  monthsInLevel: number;
  requirements: LevelRequirement[];
  nextLevel: Level | null;
  assessments: {
    id: string;
    templateKey: string;
    result: "passed" | "not_yet";
    createdAt: string;
    assessorSignedAt: string | null;
    assesseeSignedAt: string | null;
    participantCategory: number;
    scorePct: number | null;
  }[];
}
