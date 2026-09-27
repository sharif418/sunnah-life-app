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
};

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
