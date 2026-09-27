"use client";

// Typed API client — single source for all fetches. Mirrors docs/API_CONTRACTS.md.

import type {
  AmalDefinition,
  AmalEntry,
  AmalUpsertResult,
  AppConfig,
  AssessmentDetail,
  AssessmentTemplate,
  DawahOverview,
  User,
  Usrah,
  UsrahMember,
  Announcement,
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

async function req<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, {
    ...init,
    credentials: "same-origin",
    headers: { "Content-Type": "application/json", ...(init?.headers ?? {}) },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error((data as { error?: string }).error ?? `Request failed (${res.status})`);
  }
  return data as T;
}

export const api = {
  // auth
  requestOtp: (phone: string) => req<{ ok: boolean; devCode: string }>("/api/auth/otp/request", { method: "POST", body: JSON.stringify({ phone }) }),
  verifyOtp: (payload: { phone: string; code: string; name?: string; gender?: Gender; referredByCode?: string; guestEntries?: AmalEntry[] }) =>
    req<{ user: User }>("/api/auth/otp/verify", { method: "POST", body: JSON.stringify(payload) }),
  logout: () => req<{ ok: boolean }>("/api/auth/logout", { method: "POST" }),

  me: () => req<{ user: User | null }>("/api/me"),
  updateMe: (patch: Partial<Pick<User, "name" | "language" | "madhhab" | "calcMethod" | "lat" | "lng" | "city" | "district" | "workplace" | "department" | "category">>) =>
    req<{ user: User }>("/api/me", { method: "PATCH", body: JSON.stringify(patch) }),

  config: () => req<AppConfig>("/api/config"),

  // amal
  amalDefinitions: () => req<{ definitions: AmalDefinition[] }>("/api/amal/definitions"),
  amalEntries: (from: string, to: string, userId?: string) =>
    req<{ entries: AmalEntry[] }>(`/api/amal/entries?from=${from}&to=${to}${userId ? `&userId=${userId}` : ""}`),
  amalUpsert: (entries: AmalEntry[]) =>
    req<AmalUpsertResult>("/api/amal/entries", { method: "POST", body: JSON.stringify({ entries }) }),
  amalUnlock: (userId: string, date: string, reason?: string) =>
    req<{ ok: boolean }>("/api/amal/unlock", { method: "POST", body: JSON.stringify({ userId, date, reason }) }),

  // dawah engine
  dawahOverview: () => req<DawahOverview>("/api/dawah"),
  usrah: () => req<{ usrah: (Usrah & { members: UsrahMember[] }) | null; announcements: Announcement[] }>("/api/usrah"),
  reviews: () => req<{ reviews: WeeklyReview[] }>("/api/reviews"),
  reviewsQueue: () => req<{ queue: (WeeklyReview & { user: UsrahMember })[] }>("/api/reviews?scope=queue"),
  submitReview: (payload: { userId: string; weekStart: string; comment: string; rating: number; nextGoals: string }) =>
    req<{ review: WeeklyReview }>("/api/reviews", { method: "POST", body: JSON.stringify(payload) }),
  assessments: (userId?: string) => req<{ assessments: AssessmentDetail[] }>(`/api/assessments${userId ? `?userId=${userId}` : ""}`),
  assessmentTemplates: () => req<{ templates: AssessmentTemplate[] }>("/api/assessments/templates"),
  createAssessment: (payload: { assesseeId: string; templateKey: string; participantCategory: number; scores: Record<string, { score: 0 | 1 | 2; comment?: string }>; overallComment: string }) =>
    req<{ assessment: AssessmentDetail }>("/api/assessments", { method: "POST", body: JSON.stringify(payload) }),

  // admin
  adminOverview: () => req<AdminOverview>("/api/admin/overview"),
  adminUsers: (q?: string) => req<{ users: (User & { usrahName?: string })[] }>(`/api/admin/users${q ? `?q=${encodeURIComponent(q)}` : ""}`),
  adminMonthGrid: (userId: string, month: string) => req<{ grid: MonthGrid }>(`/api/admin/month-grid?userId=${userId}&month=${month}`),
  adminUpdateUser: (userId: string, patch: { role?: Role; gender?: Gender; usrahId?: string | null; category?: User["category"] }) =>
    req<{ user: User }>("/api/admin/users", { method: "PATCH", body: JSON.stringify({ userId, ...patch }) }),
  adminPromote: (userId: string, toLevel: Level) =>
    req<{ user: User }>("/api/admin/promote", { method: "POST", body: JSON.stringify({ userId, toLevel }) }),
  adminBroadcast: (payload: { usrahId?: string | null; gender?: Gender | null; body: string }) =>
    req<{ ok: boolean }>("/api/admin/broadcast", { method: "POST", body: JSON.stringify(payload) }),
  adminUpsertAmal: (def: Partial<AmalDefinition> & { key: string }) =>
    req<{ definitions: AmalDefinition[] }>("/api/admin/amal-catalog", { method: "POST", body: JSON.stringify(def) }),
  adminAudit: () => req<{ entries: AuditEntry[] }>("/api/admin/audit"),

  // referral landing
  joinInfo: (code: string) => req<{ inviterName: string; inviterLevel: Level }>(`/api/join?code=${encodeURIComponent(code)}`),

  // misc
  reminders: () => req<{ reminders: ReminderItem[] }>("/api/reminders"),
  readReminder: (id: string) => req<{ ok: boolean }>(`/api/reminders`, { method: "PATCH", body: JSON.stringify({ id }) }),
  live: () => req<{ programs: LiveProgramItem[] }>("/api/live"),
  notifyLive: (id: string) => req<{ ok: boolean }>("/api/live", { method: "POST", body: JSON.stringify({ id }) }),
  masala: (payload: { name: string; phone?: string; question: string }) =>
    req<{ ok: boolean }>("/api/masala", { method: "POST", body: JSON.stringify(payload) }),
  feedback: (message: string) => req<{ ok: boolean }>("/api/feedback", { method: "POST", body: JSON.stringify({ message }) }),
  enroll: (courseId: string) => req<{ ok: boolean }>("/api/enroll", { method: "POST", body: JSON.stringify({ courseId }) }),
  saveProgress: (courseId: string, progressJson: string) =>
    req<{ ok: boolean }>("/api/enroll", { method: "PATCH", body: JSON.stringify({ courseId, progressJson }) }),
  quizAttempt: (quizId: string, score: number, total: number) =>
    req<{ ok: boolean }>("/api/quiz-attempt", { method: "POST", body: JSON.stringify({ quizId, score, total }) }),

  // quran
  quranSurahs: () => req<{ surahs: { number: number; name: string; nameBn: string; englishName: string; ayahCount: number; revelationType: string }[] }>("/api/quran/surahs"),
  quranSurah: (n: number) => req<{ surah: { number: number; name: string; nameBn: string; englishName: string; revelationType: string; bismillahPre: boolean; ayahs: { numberInSurah: number; text: string; translationBn?: string; page: number; juz: number }[] } }>(`/api/quran/surah/${n}`),
};
