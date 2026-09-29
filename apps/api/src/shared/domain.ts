// ─────────────────────────────────────────────────────────────────────────────
// Sunnah Life — shared domain types (single source of truth for client + API).
// These mirror docs/API_CONTRACTS.md. Keep in sync.
// ─────────────────────────────────────────────────────────────────────────────

export type Gender = "M" | "F";
/** Sentinel stored for social-sign-in accounts created BEFORE the user
 *  completed gender onboarding. Gender is set once (onboarding / one-time
 *  PATCH /api/me) and locked afterwards — "unspecified" is the pre-state. */
export type GenderOrUnset = Gender | "unspecified";
export type Role = "user" | "daee" | "usrah_head" | "invigilator" | "full_admin";
export type Level = "none" | "muhibbus_sunnah" | "farze_ain_1" | "farze_ain_2";
export type UserCategory = "general" | "hafez" | "alim";
export type Lang = "bn" | "en" | "ar";
export type CalcMethodKey = "karachi" | "mwl" | "isna" | "egypt" | "makkah" | "dubai";
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
  email: string | null;
  name: string;
  photoUrl: string | null;
  /** "unspecified" until the (social-created) account completes gender
   *  onboarding — set once via POST /api/auth/social or PATCH /api/me, then
   *  locked (full_admin may still change it through the admin console). */
  gender: GenderOrUnset;
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
  /** IANA time zone (prayer pushes, week starts, day-lock). */
  tz: string;
  calcMethod: CalcMethodKey;
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
  /** serverValue: on a newerVersion rejection, the server's winning value —
   * lets the client reconcile instead of guessing (Phase C/W2g). */
  rejected: { date: string; amalKey: string; reason: string; serverValue?: AmalValue }[];
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
}

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

export interface AssessmentSummary {
  id: string;
  templateKey: string;
  result: "passed" | "not_yet";
  createdAt: string;
  assessorSignedAt: string | null;
  assesseeSignedAt: string | null;
  participantCategory: number;
  scorePct: number | null;
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
  /** Verbatim client form metadata (farze_ain_v1.1+): instructions,
   *  category descriptions, scale, header fields, signature labels. */
  meta?: {
    instructionsBn?: string | null;
    categories?: { id: number; titleBn: string; descriptionBn: string }[] | null;
    categoriesFooterBn?: string | null;
    scale?: { key: number; labelBn: string }[] | null;
    scaleNoteBn?: string | null;
    summarySpec?: { noteBn?: string | null; columnsBn?: string[] | null } | null;
    overallCommentLabelBn?: string | null;
    signatures?: { key: string; labelBn: string }[] | null;
    headerFields?: { key: string; labelBn: string }[] | null;
  };
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

/** W4h — GET /api/admin/invigilator-health row (full_admin: every invigilator;
 * invigilator: only self). Null components/score = empty scope (no usrahs of
 * that gender). */
export interface InvigilatorHealthItem {
  id: string;
  name: string;
  memberCode: string | null;
  gender: Gender;
  usrahNames: string[];
  memberCount: number;
  /** done reviews ÷ (members × 4 weeks), last 27 days. */
  reviewPct: number | null;
  /** mean 7-day amal completion of the members. */
  amalPct: number | null;
  /** members active in the last 3 days ÷ members. */
  activePct: number | null;
  /** reviews of the members currently flagged overdue. */
  overdueCount: number;
  /** assessments of the members created in the last 30 days. */
  assessments30d: number;
  /** of those — still missing an assessor or assessee signature. */
  unsignedAssessments: number;
  /** 0.35·reviewPct + 0.35·amalPct + 0.20·activePct + 0.10·onTimePct. */
  score: number | null;
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
}
export interface Quiz {
  id: string;
  titleBn: string;
  descBn?: string;
  category: string;
  minutes: number;
  questions: QuizQuestion[];
  live?: boolean;
}

export interface CourseLesson {
  id: string;
  titleBn: string;
  bodyBn: string;
  minutes: number;
}
export interface Course {
  id: string;
  titleBn: string;
  descBn: string;
  level: string;
  lessons: CourseLesson[];
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

export interface MosqueInfo {
  id: string;
  nameBn: string;
  addressBn: string;
  lat: number;
  lng: number;
}

// ── Misc ─────────────────────────────────────────────────────────────────────

export interface AppConfig {
  donationUrl: string;
  domain: string;
  /** ± days applied to the Umm al-Qura Hijri date (admin-set, per community
   *  moon sighting). The mobile date bar and web header must apply this. */
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
  /** Gender-scoped amal leaderboard is gated on the scholars' decision. */
  leaderboardEnabled: boolean;
  /** Social-media-detox reminders (Android UsageStats, Guard-module seed). */
  detoxEnabled: boolean;
}
