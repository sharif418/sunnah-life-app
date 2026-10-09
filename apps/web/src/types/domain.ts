// ─────────────────────────────────────────────────────────────────────────────
// Sunnah Life — shared domain types (single source of truth for client + API).
// These mirror docs/API_CONTRACTS.md. Keep in sync.
// ─────────────────────────────────────────────────────────────────────────────

export type Gender = "M" | "F";
export type Role = "user" | "daee" | "usrah_head" | "invigilator" | "full_admin";
export type Level = "none" | "muhibbus_sunnah" | "farze_ain_1" | "farze_ain_2";
export type UserCategory = "general" | "hafez" | "alim";
export type Lang = "bn" | "en" | "ar";
export type CalcMethodKey = "ifb" | "karachi" | "mwl" | "isna" | "egypt" | "makkah" | "dubai";
export type Madhhab = "hanafi" | "shafii";

export const ROLE_LABELS_BN: Record<Role, string> = {
  user: "সাধারণ ব্যবহারকারী",
  daee: "দায়ী",
  usrah_head: "উসরা প্রধান",
  invigilator: "পরিদর্শক",
  full_admin: "প্রধান অ্যাডমিন",
};

export const LEVEL_LABELS_BN: Record<Level, string> = {
  none: "শুরুর পর্যায়",
  muhibbus_sunnah: "মুহিব্বুস সুন্নাহ",
  farze_ain_1: "ফরযে আইন — ক্যাটাগরি ১",
  farze_ain_2: "ফরযে আইন — ক্যাটাগরি ২",
};

export const ROLE_RANK: Record<Role, number> = {
  user: 0,
  daee: 1,
  usrah_head: 2,
  invigilator: 2,
  full_admin: 3,
};

export interface User {
  id: string;
  phone: string | null;
  email?: string | null;
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
  language: Lang;
  madhhab: Madhhab;
  calcMethod: CalcMethodKey;
  /** per-waqt minutes to match the member's own mosque ({} = none) */
  prayerAdjust?: PrayerAdjust;
  lat: number | null;
  lng: number | null;
  city: string | null;
  createdAt: string;
  lastActiveAt: string;
}

// ── Amal (Muhasaba diary) ───────────────────────────────────────────────────

export type AmalInputType = "tristate" | "boolean" | "count" | "quantity" | "text";
export type AmalCadence = "daily" | "weekly:any" | "weekly:fri" | "weekly:mon_thu" | "monthly:ayyam_beez";
export type AmalCategory =
  | "salah"
  | "quran"
  | "dhikr"
  | "akhlaq"
  | "dawat"
  | "lifestyle"
  | "sunnah"
  | "personal";

export const AMAL_CATEGORY_LABELS_BN: Record<AmalCategory, string> = {
  salah: "নামাজ",
  quran: "কুরআন",
  dhikr: "যিকর ও দোয়া",
  akhlaq: "আখলাক",
  dawat: "দাওয়াত",
  lifestyle: "জীবনাচরণ",
  sunnah: "সাপ্তাহিক ও মাসিক সুন্নাহ",
  personal: "ব্যক্তিগত লক্ষ্য",
};

/** tristate value: জামাত ✔ / একা / কাযা */
export type TriState = "jamaat" | "alone" | "qaza";
export type AmalValue = TriState | boolean | number | string;

export interface AmalDefinition {
  key: string;
  titleBn: string;
  titleEn: string;
  category: AmalCategory;
  inputType: AmalInputType;
  cadence: AmalCadence;
  /** {"general":1,"hafez":1,"alim":10} */
  target: Record<string, number> | null;
  unit: string | null;
  minLevel: Level;
  sortOrder: number;
  autoSource: string | null;
}

export interface AmalEntry {
  id?: string;
  amalKey: string;
  /** YYYY-MM-DD */
  date: string;
  /** ISO datetime of last client edit — conflict winner */
  clientUpdatedAt: string;
  value: AmalValue;
  source: string;
  serverUpdatedAt?: string;
}

export interface AmalUpsertResult {
  accepted: AmalEntry[];
  rejected: { date: string; amalKey: string; reason: string }[];
}

export interface DayStatus {
  date: string;
  locked: boolean;
  unlocked: boolean;
}

// ── Prayer engine ────────────────────────────────────────────────────────────

export interface PrayerConfig {
  lat: number;
  lng: number;
  city: string;
  method: CalcMethodKey;
  madhhab: Madhhab;
  /** hours offset from UTC, e.g. 6 for Dhaka */
  tzOffsetHours: number;
  /** the member's own mosque: whole minutes added to each start time */
  adjust?: PrayerAdjust;
}

/** The five start times a member may shift to match their own mosque. */
export type PrayerAdjustKey = "fajr" | "dhuhr" | "asr" | "maghrib" | "isha";
/** Minutes per waqt, −30..30; a missing key means 0. */
export type PrayerAdjust = Partial<Record<PrayerAdjustKey, number>>;

export type PrayerKey =
  | "fajr"
  | "sunrise"
  | "ishraq"
  | "duha"
  | "dhuhr"
  | "asr"
  | "maghrib"
  | "sunset"
  | "isha"
  | "tahajjud";

export interface PrayerTimes {
  /** minutes from local midnight, floats */
  fajr: number;
  sunrise: number;
  ishraq: number;
  duha: number;
  dhuhr: number;
  asr: number;
  maghrib: number;
  sunset: number;
  isha: number;
  tahajjud: number;
  /** Dhuhr as calculated, before the member's adjustment — the zawal
   *  window is tied to the sun, not to the mosque's adhan */
  noon: number;
}

export const PRAYER_LABELS_BN: Record<PrayerKey, string> = {
  fajr: "ফজর",
  sunrise: "সূর্যোদয়",
  ishraq: "ইশরাক",
  duha: "দুহা",
  dhuhr: "যোহর",
  asr: "আসর",
  maghrib: "মাগরিব",
  sunset: "সূর্যাস্ত",
  isha: "এশা",
  tahajjud: "তাহাজ্জুদ",
};

export const FARZ_PRAYERS: PrayerKey[] = ["fajr", "dhuhr", "asr", "maghrib", "isha"];

// ── Usrah / Dawah engine ─────────────────────────────────────────────────────

export interface Usrah {
  id: string;
  name: string;
  gender: Gender;
  headUserId: string | null;
  invigilatorUserId: string | null;
  district: string | null;
  headName?: string | null;
  memberCount?: number;
}

export interface UsrahMember
  extends Pick<
    User,
    "id" | "name" | "gender" | "level" | "memberCode" | "category" | "lastActiveAt"
  > {
  completion7d?: number | null;
  reviewsDone?: number;
  reviewsTotal?: number;
}

export interface Announcement {
  id: string;
  usrahId: string | null;
  authorId: string;
  authorName?: string;
  kind: "announcement" | "question" | "exam";
  body: string;
  pinned: boolean;
  createdAt: string;
}

export interface DownlineNode {
  id: string;
  name: string;
  gender: Gender;
  level: Level;
  memberCode: string | null;
  depth: number;
  lastActiveAt: string;
  joinedAt?: string;
}

export interface LevelRequirement {
  key: string;
  label: string;
  done: boolean;
  detail: string;
}

/** One row of the live next-level checklist (B6 — GET /api/dawah/requirements). */
export interface LevelCheckRow {
  key: string;
  labelBn: string;
  /** Machine-evaluated progress (null for invigilator-verified items). */
  current: number | null;
  target: number | null;
  met: boolean;
  /** Whether this row is machine-checkable (drives auto-promotion). */
  autoChecked: boolean;
  detailBn: string;
}

export interface DawahRequirements {
  level: Level;
  nextLevel: Level;
  rulesApply: boolean;
  allMet: boolean;
  autoEligible: boolean;
  requirements: LevelCheckRow[];
}

export interface AssessmentSummary {
  id: string;
  templateKey: string;
  result: "passed" | "not_yet";
  createdAt: string;
  assessorSignedAt: string | null;
  assesseeSignedAt: string | null;
  participantCategory: number;
  scorePct: number | null;
  /** W4i: final only after the assessee's own OTP confirmation */
  status?: "pending_confirmation" | "confirmed" | "declined";
  confirmedAt?: string | null;
  declinedAt?: string | null;
  decisionNote?: string | null;
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
  nextLevel: Level;
  assessments: AssessmentSummary[];
}

// ── Reviews ─────────────────────────────────────────────────────────────────

export interface WeeklyReview {
  id: string;
  userId: string;
  userName?: string;
  reviewerId: string;
  reviewerName?: string;
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
}

// ── Assessment ───────────────────────────────────────────────────────────────

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
export interface AssessmentDetail extends AssessmentSummary {
  template: AssessmentTemplate;
  assessorName?: string;
  assesseeName?: string;
  participantCategory: number;
  scores: Record<string, { score: 0 | 1 | 2; comment?: string }>;
  overallComment: string | null;
}

// ── Admin ───────────────────────────────────────────────────────────────────

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

export interface AdminOverview {
  role: Role;
  totals: { users: number; daees: number; usrahs: number; pendingReviews: number };
  usrahs: UsrahHealth[];
  recentAudit: AuditEntry[];
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

export interface MonthGridCell {
  date: string;
  value: AmalValue | null;
  source: string;
}
/** rows: amalKey → 31 cells */
export type MonthGrid = {
  amalKeys: string[];
  definitions: AmalDefinition[];
  days: string[];
  rows: Record<string, MonthGridCell[]>;
};

// ── Reminders / notifications ───────────────────────────────────────────────

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

// ── Content packs (static) ───────────────────────────────────────────────────

export interface DuaItem {
  id: string;
  category: string;
  titleBn: string;
  arabic: string;
  translitBn?: string;
  translationBn: string;
  reference: string;
  virtue?: string;
}

export interface DhikrItem {
  id: string;
  order: number;
  arabic: string;
  translitBn: string;
  translationBn: string;
  count: number;
  reference: string;
  virtue?: string;
}
export interface DhikrSet {
  id: string;
  titleBn: string;
  period: "morning" | "evening" | "post_salat" | "other";
  totalMin?: number;
  items: DhikrItem[];
}

export interface NameOfAllah {
  id: number;
  arabic: string;
  translitBn: string;
  meaningBn: string;
  virtue?: string;
}

export interface IslamicName {
  id: number;
  name: string;
  gender: "boy" | "girl";
  meaningBn: string;
  gender_note?: string;
}

export interface ImanBranch {
  id: number;
  group: "heart" | "tongue" | "body";
  titleBn: string;
  detailBn?: string;
}

export interface SunnahItem {
  id: string;
  category: "daily" | "forgotten" | "salah";
  titleBn: string;
  detailBn: string;
  reference?: string;
}

export interface ArticleItem {
  id: string;
  titleBn: string;
  excerptBn: string;
  bodyBn: string;
  category?: string;
  publishedAt?: string;
  readMinutes?: number;
}

export interface QuizQuestion {
  id: string;
  questionBn: string;
  options: string[];
  answerIndex: number;
  explanationBn?: string;
  difficulty?: "easy" | "medium" | "hard";
}
export interface Quiz {
  id: string;
  titleBn: string;
  descBn?: string;
  category: string;
  minutes: number;
  questions: QuizQuestion[];
  live?: boolean;
  /** scheduled live session (ISO) — upcoming hint on the card */
  scheduledAt?: string;
}

export interface CourseLesson {
  id: string;
  titleBn: string;
  bodyBn: string;
  minutes: number;
  order?: number;
}
export interface Course {
  id: string;
  titleBn: string;
  descBn: string;
  level: string;
  lessons: CourseLesson[];
}

/** GET /api/courses row (lesson bodies stripped, stats included). */
export interface CourseSummary {
  id: string;
  titleBn: string;
  descBn: string;
  level: string;
  lessonCount: number;
  totalMinutes: number;
  enrolledCount: number;
  attemptedCount: number;
}

/** GET /api/enrollments row. */
export interface EnrollmentItem {
  courseId: string;
  progress: { done?: string[] } | null;
  updatedAt: string;
}

/** GET /api/quiz-attempts row. */
export interface QuizAttemptItem {
  id: string;
  quizId: string;
  score: number;
  total: number;
  createdAt: string;
}

/** GET /api/usrah-questions row (own usrah only — RLS). */
export interface UsrahQuestionItem {
  id: string;
  usrahId: string;
  authorId: string;
  authorName: string | null;
  category: "general" | "aqeedah" | "salah" | "quran" | "muamalah" | "tarbiyah";
  question: string;
  answer: string | null;
  answeredByName: string | null;
  answeredAt: string | null;
  createdAt: string;
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
  /** AMOL-17: set when the program is a scheduled live quiz. */
  quizId?: string | null;
}

export interface MosqueInfo {
  id: string;
  nameBn: string;
  addressBn: string;
  lat: number;
  lng: number;
  nameEn?: string;
  area?: string;
}

// ── Misc ─────────────────────────────────────────────────────────────────────

export interface AppConfig {
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
}

// ── Personal goals (W4c) ─────────────────────────────────────────────────────

export type GoalStatus = "proposed" | "approved" | "rejected" | "completed" | "withdrawn";

export interface PersonalGoal {
  id: string;
  userId: string;
  amalKey: string;
  title: string;
  note: string | null;
  target: string | null;
  startDate: string; // YYYY-MM-DD
  active: boolean;
  status: GoalStatus;
  decidedById: string | null;
  decidedAt: string | null;
  reason: string | null;
  createdAt: string;
}

/** A goal in the usrah head's approval queue, with the member's name. */
export interface GoalQueueItem extends PersonalGoal {
  userName: string;
}

// ── Live support (W4d) ───────────────────────────────────────────────────────

export interface SupportThread {
  id: string;
  userId: string;
  subject: string;
  status: "open" | "answered" | "closed";
  createdAt: string;
  updatedAt: string;
  closedAt: string | null;
  /** list rows only */
  lastPreview?: string | null;
  /** list rows only: the last message is the team's reply */
  unreadForUser?: boolean;
}

export interface SupportMessage {
  id: string;
  threadId: string;
  authorId: string;
  isAdmin: boolean;
  body: string;
  createdAt: string;
}

/** One of my মাসআলা questions (GET /api/masala/mine). */
export interface MyMasala {
  id: string;
  question: string;
  status: "new" | "answered";
  answer: string | null;
  answeredAt: string | null;
  createdAt: string;
}

/** My request to join an usrah (W4d). */
export interface UsrahJoinRequestItem {
  id: string;
  userId: string;
  message: string | null;
  status: "pending" | "approved" | "rejected";
  handledById: string | null;
  handledAt: string | null;
  usrahId: string | null;
  reason: string | null;
  createdAt: string;
}
