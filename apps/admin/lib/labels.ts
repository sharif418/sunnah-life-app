// Bengali label tables (mirrors apps/api/src/shared/domain.ts + the web app).

import type {
  AmalCadence,
  AmalCategory,
  AmalInputType,
  Gender,
  Level,
  Role,
  UserCategory,
} from "./api";
import { toBn } from "./bn";

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

export const LEVEL_ORDER: Level[] = ["none", "muhibbus_sunnah", "farze_ain_1", "farze_ain_2"];

export const GENDER_LABELS_BN: Record<Gender, string> = { M: "পুরুষ", F: "নারী" };

export const CATEGORY_LABELS_BN: Record<UserCategory, string> = {
  general: "সাধারণ",
  hafez: "হাফেজ",
  alim: "আলেম",
};

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

export const INPUT_TYPE_LABELS_BN: Record<AmalInputType, string> = {
  tristate: "জামাত / একা / কাযা",
  boolean: "হ্যাঁ–না",
  count: "সংখ্যা",
  quantity: "পরিমাণ",
  text: "লেখা",
};

export const CADENCE_LABELS_BN: Record<AmalCadence, string> = {
  daily: "প্রতিদিন",
  "weekly:any": "সাপ্তাহে যেকোনো দিন",
  "weekly:fri": "শুক্রবার",
  "weekly:mon_thu": "সোম ও বৃহস্পতি",
  "monthly:ayyam_beez": "আইয়ামে বীজ (১৩–১৫)",
};

export const REVIEW_STATUS_LABELS_BN: Record<string, string> = {
  pending: "অপেক্ষমাণ",
  done: "সম্পন্ন",
  overdue: "বিলম্বিত",
};

/** W4d — support-thread lifecycle labels. */
export const SUPPORT_STATUS_LABELS_BN: Record<string, string> = {
  open: "উত্তর বাকি",
  answered: "উত্তর দেওয়া হয়েছে",
  closed: "বন্ধ",
};

/** W4d — usrah join-request lifecycle labels. */
export const JOIN_STATUS_LABELS_BN: Record<string, string> = {
  pending: "অপেক্ষমাণ",
  approved: "অনুমোদিত",
  rejected: "বাতিল",
};

export const ASSESSMENT_RESULT_LABELS_BN: Record<string, string> = {
  passed: "উত্তীর্ণ",
  not_yet: "আরও উন্নতি প্রয়োজন",
};

export const AUDIT_ACTION_LABELS_BN: Record<string, string> = {
  unlock_day: "দিন আনলক",
  change_role: "ভূমিকা পরিবর্তন",
  change_gender: "লিঙ্গ পরিবর্তন",
  promote_level: "স্তর উন্নয়ন",
  broadcast: "ঘোষণা প্রেরণ",
  create_assessment: "মূল্যায়ন সম্পন্ন",
  sign_assessment: "মূল্যায়ন স্বাক্ষর",
  support_reply: "সাপোর্ট উত্তর",
  support_close: "সাপোর্ট বন্ধ",
  join_request_approve: "উসরা অনুরোধ অনুমোদন",
  join_request_reject: "উসরা অনুরোধ বাতিল",
  approve_goal: "লক্ষ্য অনুমোদন",
  reject_goal: "লক্ষ্য বাতিল",
  update_app_config: "অ্যাপ কনফিগ হালনাগাদ",
  level_rules_update: "স্তরের নিয়ম সম্পাদনা",
  content_pack_update: "কনটেন্ট হালনাগাদ",
  answer_masala: "মাসআলার উত্তর",
  assessment_confirm: "মূল্যায়ন নিশ্চিত",
  assessment_decline: "মূল্যায়নে আপত্তি",
  change_phone: "ফোন নম্বর পরিবর্তন",
  create_assessment_template: "মূল্যায়ন ফর্ম তৈরি",
  update_assessment_template: "মূল্যায়ন ফর্ম সম্পাদনা",
  create_live_program: "লাইভ প্রোগ্রাম তৈরি",
  update_live_program: "লাইভ প্রোগ্রাম সম্পাদনা",
  delete_live_program: "লাইভ প্রোগ্রাম মুছে ফেলা",
  create_usrah: "উসরা তৈরি",
  update_usrah: "উসরা সম্পাদনা",
  move_usrah_member: "উসরা পরিবর্তন",
  import_members: "সদস্য ইমপোর্ট",
  reorder_amal_catalog: "আমলের ক্রম পরিবর্তন",
  update_amal_definition: "আমল সম্পাদনা",
};

/** What an audited action touched, in words. */
export const AUDIT_TARGET_LABELS_BN: Record<string, string> = {
  user: "সদস্য",
  amal_day: "ডায়েরির দিন",
  assessment: "মূল্যায়ন",
  assessment_template: "মূল্যায়ন ফর্ম",
  announcement: "ঘোষণা",
  content_pack: "কনটেন্ট",
  live_program: "লাইভ প্রোগ্রাম",
  usrah: "উসরা",
  usrah_join_request: "উসরার অনুরোধ",
  level_rules: "স্তরের নিয়ম",
  amal_definition: "আমল",
  app_config: "অ্যাপ সেটিংস",
  support_thread: "সাপোর্ট বার্তা",
  masala: "মাসআলা",
  goal: "লক্ষ্য",
};

/** A value from an audit record shown to people: levels, roles and genders
 * in Bengali, anything else as it is. */
export function auditValueBn(v: string): string {
  return (
    (LEVEL_LABELS_BN as Record<string, string>)[v] ??
    (ROLE_LABELS_BN as Record<string, string>)[v] ??
    (GENDER_LABELS_BN as Record<string, string>)[v] ??
    v
  );
}

export function auditActionLabel(action: string): string {
  return AUDIT_ACTION_LABELS_BN[action] ?? action;
}

export function roleRank(role: string): number {
  return ({ user: 0, daee: 1, usrah_head: 2, invigilator: 2, full_admin: 3 } as Record<string, number>)[role] ?? -1;
}

export function isSupervisor(role: string | undefined | null): boolean {
  return !!role && roleRank(role) >= 2;
}

export function isFullAdmin(role: string | undefined | null): boolean {
  return role === "full_admin";
}

export function pctBn(value: number | null | undefined): string {
  if (value === null || value === undefined) return "—";
  return `${toBn(value)}%`;
}

/** The 64 districts by their English name (lowercase) → Bengali, so a
 * district typed or imported in English ("dhaka") reads in Bengali. */
const DISTRICT_BN: Record<string, string> = {
  "dhaka": "ঢাকা",
  "gazipur": "গাজীপুর",
  "narayanganj": "নারায়ণগঞ্জ",
  "narsingdi": "নরসিংদী",
  "manikganj": "মানিকগঞ্জ",
  "munshiganj": "মুন্সিগঞ্জ",
  "tangail": "টাঙ্গাইল",
  "kishoreganj": "কিশোরগঞ্জ",
  "faridpur": "ফরিদপুর",
  "madaripur": "মাদারীপুর",
  "shariatpur": "শরীয়তপুর",
  "rajbari": "রাজবাড়ী",
  "gopalganj": "গোপালগঞ্জ",
  "chattogram": "চট্টগ্রাম",
  "cox's bazar": "কক্সবাজার",
  "cumilla": "কুমিল্লা",
  "brahmanbaria": "ব্রাহ্মণবাড়িয়া",
  "noakhali": "নোয়াখালী",
  "feni": "ফেনী",
  "chandpur": "চাঁদপুর",
  "lakshmipur": "লক্ষ্মীপুর",
  "rangamati": "রাঙামাটি",
  "khagrachhari": "খাগড়াছড়ি",
  "bandarban": "বান্দরবান",
  "sylhet": "সিলেট",
  "moulvibazar": "মৌলভীবাজার",
  "habiganj": "হবিগঞ্জ",
  "sunamganj": "সুনামগঞ্জ",
  "rajshahi": "রাজশাহী",
  "bogura": "বগুড়া",
  "pabna": "পাবনা",
  "sirajganj": "সিরাজগঞ্জ",
  "natore": "নাটোর",
  "naogaon": "নওগাঁ",
  "joypurhat": "জয়পুরহাট",
  "chapainawabganj": "চাঁপাইনবাবগঞ্জ",
  "rangpur": "রংপুর",
  "dinajpur": "দিনাজপুর",
  "kurigram": "কুড়িগ্রাম",
  "gaibandha": "গাইবান্ধা",
  "lalmonirhat": "লালমনিরহাট",
  "nilphamari": "নীলফামারী",
  "thakurgaon": "ঠাকুরগাঁও",
  "panchagarh": "পঞ্চগড়",
  "khulna": "খুলনা",
  "jashore": "যশোর",
  "satkhira": "সাতক্ষীরা",
  "bagerhat": "বাগেরহাট",
  "jhenaidah": "ঝিনাইদহ",
  "kushtia": "কুষ্টিয়া",
  "magura": "মাগুরা",
  "narail": "নড়াইল",
  "chuadanga": "চুয়াডাঙ্গা",
  "meherpur": "মেহেরপুর",
  "barishal": "বরিশাল",
  "patuakhali": "পটুয়াখালী",
  "bhola": "ভোলা",
  "pirojpur": "পিরোজপুর",
  "barguna": "বরগুনা",
  "jhalokati": "ঝালকাঠি",
  "mymensingh": "ময়মনসিংহ",
  "jamalpur": "জামালপুর",
  "netrokona": "নেত্রকোণা",
  "sherpur": "শেরপুর",
  "chittagong": "চট্টগ্রাম",
  "comilla": "কুমিল্লা",
  "barisal": "বরিশাল",
  "jessore": "যশোর",
  "bogra": "বগুড়া",
};

export function districtBn(d: string | null | undefined): string {
  if (!d) return "—";
  return DISTRICT_BN[d.trim().toLowerCase()] ?? d;
}
