"use client";

// Typed API client — the ONLY sanctioned fetch layer of the web app.
//
//   • URL building goes through apiUrl() (src/lib/api-base.ts):
//       sandbox  → same-origin "/api/…?XTransformPort=3001" via the gateway
//       prod     → absolute `${NEXT_PUBLIC_API_BASE}/api/…`
//   • Route literals are compile-checked against @sunnahlife/shared-types
//     (dist/schema.d.ts, generated from the running API's OpenAPI document —
//     `cd packages/shared-types && bun run generate`).
//   • Session = HttpOnly cookies set by the NestJS API (sl_access 15 min +
//     sl_refresh 7 days). When the access token expires any request 401s;
//     we transparently POST /api/auth/refresh (cookie-based, deduped) and
//     retry once. Guests never loop: a failed refresh is remembered for 30s.
//   • Error envelope everywhere: { error: "messageBn" } (ApiError filter).

import { API_BASE, apiUrl } from "@/lib/api-base";
// Type-only import from the generated OpenAPI surface (erased at build time —
// no runtime dependency, works thanks to next.config.ts externalDir).
import type { paths as OpenApiPaths } from "../../../../packages/shared-types/dist/schema";
import type {
  AmalDefinition,
  AmalEntry,
  AmalUpsertResult,
  AppConfig,
  AssessmentDetail,
  AssessmentTemplate,
  Course,
  CourseSummary,
  DawahOverview,
  DawahRequirements,
  EnrollmentItem,
  QuizAttemptItem,
  UsrahQuestionItem,
  User,
  Usrah,
  UsrahMember,
  Announcement,
  UsrahJoinRequestItem,
  MyMasala,
  SupportMessage,
  SupportThread,
  GoalQueueItem,
  PersonalGoal,
  WeeklyReview,
  ReminderItem,
  LiveProgramItem,
  MonthGrid,
  AdminOverview,
  AuditEntry,
  Gender,
  Role,
  Level,
} from "@/types/domain";

/** Route keys exactly as the API exports them (OpenAPI paths, no "/api" prefix). */
export type ApiRoute = Extract<keyof OpenApiPaths, string>;
/** The parameterised routes of the surface (path params → template literals). */
type SurahRoute = `/quran/surah/${number}`;
type CourseRoute = `/courses/${string}`;
type UsrahAnswerRoute = `/usrah-questions/${string}/answers`;

/**
 * Compile-checked route builder: ("/amal/entries", {from, to}) →
 * "/api/amal/entries?from=…&to=…". A renamed/removed API route fails the
 * web build instead of 404-ing at runtime.
 */
function route(
  path: ApiRoute | SurahRoute | CourseRoute | UsrahAnswerRoute,
  query?: Record<string, string | number | undefined | null>
): string {
  const clean = `/api/${path.replace(/^\//, "")}`;
  if (!query) return clean;
  const qs = Object.entries(query)
    .filter(([, v]) => v !== undefined && v !== null && v !== "")
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
    .join("&");
  return qs ? `${clean}?${qs}` : clean;
}

// cross-origin (prod) needs explicit credentials; same-origin sends cookies anyway
const CREDENTIALS: RequestCredentials = API_BASE ? "include" : "same-origin";

// ── transparent access-token refresh (cookie-based) ──────────────────────────

let refreshInFlight: Promise<boolean> | null = null;
let lastRefreshFailure = 0;

async function tryRefresh(): Promise<boolean> {
  if (refreshInFlight) return refreshInFlight;
  if (Date.now() - lastRefreshFailure < 30_000) return false; // don't spam for guests
  refreshInFlight = (async () => {
    try {
      const res = await fetch(apiUrl("/api/auth/refresh"), {
        method: "POST",
        credentials: CREDENTIALS,
        headers: { "Content-Type": "application/json" },
        body: "{}",
      });
      if (!res.ok) {
        lastRefreshFailure = Date.now();
        return false;
      }
      return true;
    } catch {
      lastRefreshFailure = Date.now();
      return false;
    } finally {
      refreshInFlight = null;
    }
  })();
  return refreshInFlight;
}

async function req<T>(path: string, init?: RequestInit, isRetry = false): Promise<T> {
  const res = await fetch(apiUrl(path), {
    ...init,
    credentials: CREDENTIALS,
    headers: { "Content-Type": "application/json", ...(init?.headers ?? {}) },
  });
  // Expired sl_access → one cookie refresh + retry (never for /api/auth/*).
  if (res.status === 401 && !isRetry && !path.startsWith("/api/auth/")) {
    if (await tryRefresh()) return req<T>(path, init, true);
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error((data as { error?: string }).error ?? `Request failed (${res.status})`);
  }
  return data as T;
}

export const api = {
  // auth (cookies are set by the API on verify/refresh; no token juggling here)
  requestOtp: (phone: string) =>
    req<{ ok: boolean; devCode: string }>(route("/auth/otp/request"), {
      method: "POST",
      body: JSON.stringify({ phone }),
    }),
  verifyOtp: (payload: {
    phone: string;
    code: string;
    name?: string;
    gender?: Gender;
    referredByCode?: string;
    guestEntries?: AmalEntry[];
  }) =>
    req<{ user: User; accessToken?: string; refreshToken?: string; tokenType?: string; expiresIn?: number }>(
      route("/auth/otp/verify"),
      { method: "POST", body: JSON.stringify(payload) }
    ),
  logout: () => req<{ ok: boolean }>(route("/auth/logout"), { method: "POST", body: "{}" }),

  me: () => req<{ user: User | null }>(route("/me")),
  /** DELETE /api/me — delete the signed-in account (Play's rule; see /delete-account). */
  deleteMe: () =>
    req<{ ok: boolean }>(route("/me"), { method: "DELETE", body: JSON.stringify({ confirm: "DELETE" }) }),
  updateMe: (patch: Partial<Pick<User, "name" | "language" | "madhhab" | "calcMethod" | "lat" | "lng" | "city" | "district" | "workplace" | "department" | "category">>) =>
    req<{ user: User }>(route("/me"), { method: "PATCH", body: JSON.stringify(patch) }),

  config: () => req<AppConfig>(route("/config")),

  // amal
  amalDefinitions: () => req<{ definitions: AmalDefinition[] }>(route("/amal/definitions")),
  amalEntries: (from: string, to: string, userId?: string) =>
    req<{ entries: AmalEntry[] }>(route("/amal/entries", { from, to, userId })),
  amalUpsert: (entries: AmalEntry[]) =>
    req<AmalUpsertResult>(route("/amal/entries"), { method: "POST", body: JSON.stringify({ entries }) }),
  amalUnlock: (userId: string, date: string, reason?: string) =>
    req<{ ok: boolean }>(route("/amal/unlock"), {
      method: "POST",
      body: JSON.stringify({ userId, date, reason }),
    }),

  // dawah engine
  dawahOverview: () => req<DawahOverview>(route("/dawah")),
  /** B6: live next-level checklist (progress chips + auto hint). */
  dawahRequirements: () => req<DawahRequirements>(route("/dawah/requirements")),
  usrah: () => req<{ usrah: (Usrah & { members: UsrahMember[] }) | null; announcements: Announcement[] }>(route("/usrah")),
  reviews: () => req<{ reviews: WeeklyReview[] }>(route("/reviews")),
  reviewsQueue: () => req<{ queue: (WeeklyReview & { user: UsrahMember })[] }>(route("/reviews", { scope: "queue" })),
  submitReview: (payload: { userId: string; weekStart: string; comment: string; rating: number; nextGoals: string }) =>
    req<{ review: WeeklyReview }>(route("/reviews"), { method: "POST", body: JSON.stringify(payload) }),
  assessments: (userId?: string) =>
    req<{ assessments: AssessmentDetail[] }>(route("/assessments", { userId })),
  // personal goals (W4c)
  goals: () => req<{ goals: PersonalGoal[] }>(route("/goals")),
  proposeGoal: (payload: { amalKey: string; title: string; startDate: string; target?: string; note?: string }) =>
    req<{ goal: PersonalGoal }>(route("/goals"), { method: "POST", body: JSON.stringify(payload) }),
  deleteGoal: (id: string) => req<{ ok: boolean }>(route("/goals", { id }), { method: "DELETE" }),
  usrahGoals: () => req<{ queue: GoalQueueItem[] }>(route("/usrah/goals")),
  approveGoal: (id: string) =>
    req<{ goal: PersonalGoal }>(`/api/goals/${encodeURIComponent(id)}/approve`, { method: "POST", body: "{}" }),
  rejectGoal: (id: string, reason?: string) =>
    req<{ goal: PersonalGoal }>(`/api/goals/${encodeURIComponent(id)}/reject`, {
      method: "POST",
      body: JSON.stringify(reason ? { reason } : {}),
    }),
  /** The signed-in member's OWN assessments, every status (W4i). */
  myAssessments: () => req<{ assessments: AssessmentDetail[] }>(route("/assessments/me")),
  assessmentConfirmRequest: (id: string) =>
    req<{ ok: boolean; devCode?: string }>(`/api/assessments/${encodeURIComponent(id)}/confirm-request`, {
      method: "POST",
      body: "{}",
    }),
  assessmentConfirm: (id: string, code: string) =>
    req<{ assessment: AssessmentDetail }>(`/api/assessments/${encodeURIComponent(id)}/confirm`, {
      method: "POST",
      body: JSON.stringify({ code }),
    }),
  assessmentDecline: (id: string, reason?: string) =>
    req<{ assessment: AssessmentDetail }>(`/api/assessments/${encodeURIComponent(id)}/decline`, {
      method: "POST",
      body: JSON.stringify(reason ? { reason } : {}),
    }),
  assessmentTemplates: () => req<{ templates: AssessmentTemplate[] }>(route("/assessments/templates")),
  createAssessment: (payload: {
    assesseeId: string;
    templateKey: string;
    participantCategory: number;
    scores: Record<string, { score: 0 | 1 | 2; comment?: string }>;
    overallComment: string;
  }) =>
    req<{ assessment: AssessmentDetail }>(route("/assessments"), { method: "POST", body: JSON.stringify(payload) }),

  // admin (RolesGuard-enforced supervisor/full_admin floors on the API side)
  adminOverview: () => req<AdminOverview>(route("/admin/overview")),
  adminUsers: (q?: string) =>
    req<{ users: (User & { usrahName?: string | null })[] }>(route("/admin/users", { q })),
  adminMonthGrid: (userId: string, month: string) =>
    req<{ grid: MonthGrid }>(route("/admin/month-grid", { userId, month })),
  adminUpdateUser: (userId: string, patch: { role?: Role; gender?: Gender; usrahId?: string | null; category?: User["category"] }) =>
    req<{ user: User }>(route("/admin/users"), { method: "PATCH", body: JSON.stringify({ userId, ...patch }) }),
  adminPromote: (userId: string, toLevel: Level) =>
    req<{ user: User }>(route("/admin/promote"), { method: "POST", body: JSON.stringify({ userId, toLevel }) }),
  adminBroadcast: (payload: { usrahId?: string | null; gender?: Gender | null; body: string }) =>
    req<{ ok: boolean }>(route("/admin/broadcast"), { method: "POST", body: JSON.stringify(payload) }),
  adminUpsertAmal: (def: Partial<AmalDefinition> & { key: string }) =>
    req<{ definitions: AmalDefinition[] }>(route("/admin/amal-catalog"), { method: "POST", body: JSON.stringify(def) }),
  adminAudit: () => req<{ entries: AuditEntry[] }>(route("/admin/audit")),

  // referral landing (public)
  joinInfo: (code: string) =>
    req<{ inviterName: string; inviterLevel: Level }>(route("/join", { code })),

  // misc
  reminders: () => req<{ reminders: ReminderItem[] }>(route("/reminders")),
  /** The Foundation's announcements (public; gender-scoped ones for that gender). */
  announcements: () => req<{ announcements: Announcement[] }>(route("/announcements")),
  readReminder: (id: string) =>
    req<{ ok: boolean }>(route("/reminders"), { method: "PATCH", body: JSON.stringify({ id }) }),
  live: () => req<{ programs: LiveProgramItem[] }>(route("/live")),
  notifyLive: (id: string) => req<{ ok: boolean }>(route("/live"), { method: "POST", body: JSON.stringify({ id }) }),
  // usrah join request (W4d)
  joinRequestStatus: () => req<{ request: UsrahJoinRequestItem | null }>(route("/usrah/join-request")),
  joinRequestCreate: (message?: string) =>
    req<{ request: UsrahJoinRequestItem }>(route("/usrah/join-request"), {
      method: "POST",
      body: JSON.stringify(message ? { message } : {}),
    }),
  /** My মাসআলা questions and their answers (signed in). */
  myMasala: () => req<{ questions: MyMasala[] }>(route("/masala/mine")),
  // live support (W4d)
  supportThreads: () => req<{ threads: SupportThread[] }>(route("/support")),
  supportCreate: (subject: string, message: string) =>
    req<{ thread: SupportThread }>(route("/support"), { method: "POST", body: JSON.stringify({ subject, message }) }),
  supportThread: (id: string) =>
    req<{ thread: SupportThread; messages: SupportMessage[] }>(`/api/support/${encodeURIComponent(id)}`),
  supportAppend: (id: string, message: string) =>
    req<{ message: SupportMessage }>(`/api/support/${encodeURIComponent(id)}/messages`, {
      method: "POST",
      body: JSON.stringify({ message }),
    }),
  masala: (payload: { name: string; phone?: string; question: string }) =>
    req<{ ok: boolean }>(route("/masala"), { method: "POST", body: JSON.stringify(payload) }),
  feedback: (message: string) =>
    req<{ ok: boolean }>(route("/feedback"), { method: "POST", body: JSON.stringify({ message }) }),
  enroll: (courseId: string) =>
    req<{ ok: boolean }>(route("/enroll"), { method: "POST", body: JSON.stringify({ courseId }) }),
  saveProgress: (courseId: string, progressJson: string) =>
    req<{ ok: boolean }>(route("/enroll"), { method: "PATCH", body: JSON.stringify({ courseId, progressJson }) }),
  quizAttempt: (quizId: string, score: number, total: number) =>
    req<{ ok: boolean }>(route("/quiz-attempt"), { method: "POST", body: JSON.stringify({ quizId, score, total }) }),

  // ilm — course catalog + enrollment/quiz history + usrah questions (B4)
  courses: () => req<{ courses: CourseSummary[] }>(route("/courses")),
  course: (id: string) =>
    req<{
      course: Course;
      enrolledCount: number;
      myEnrollment: { progress: { done?: string[] } | null; updatedAt: string } | null;
    }>(route(`/courses/${id}`)),
  enrollments: () => req<{ enrollments: EnrollmentItem[] }>(route("/enrollments")),
  quizAttempts: () => req<{ attempts: QuizAttemptItem[] }>(route("/quiz-attempts")),
  usrahQuestions: () => req<{ questions: UsrahQuestionItem[] }>(route("/usrah-questions")),
  askUsrahQuestion: (payload: { question: string; category?: string }) =>
    req<{ question: UsrahQuestionItem }>(route("/usrah-questions"), { method: "POST", body: JSON.stringify(payload) }),
  answerUsrahQuestion: (id: string, answer: string) =>
    req<{ question: UsrahQuestionItem }>(route(`/usrah-questions/${id}/answers`), {
      method: "POST",
      body: JSON.stringify({ answer }),
    }),
  quizLiveToken: (quizId: string) =>
    req<{ token: string; room: string; role: "host" | "player"; quizId: string | null; exp: number }>(
      route("/quiz/live-token", { quizId })
    ),

  // quran
  quranSurahs: () =>
    req<{
      surahs: {
        number: number;
        name: string;
        nameBn: string;
        englishName: string;
        ayahCount: number;
        revelationType: string;
      }[];
    }>(route("/quran/surahs")),
  quranSurah: (n: number) =>
    req<{
      surah: {
        number: number;
        name: string;
        nameBn: string;
        englishName: string;
        revelationType: string;
        bismillahPre: boolean;
        ayahs: { numberInSurah: number; text: string; translationBn?: string; page: number; juz: number }[];
      };
    }>(route(`/quran/surah/${n}`)),
};
