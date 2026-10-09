// ─────────────────────────────────────────────────────────────────────────────
// Content-pack validation (2026-10-09). What a pack must hold before it can
// go to review — the shape the apps read, unique ids, and the religious
// rule: every dua, dhikr and sunnah carries its source (সূত্র). Messages are
// Bengali (they are shown to the editor next to the item).
// ─────────────────────────────────────────────────────────────────────────────
import type { PackKey } from "../shared/quran";

export interface PackIssue {
  /** e.g. "items[3].reference" */
  path: string;
  message: string;
}

type Obj = Record<string, unknown>;

const isObj = (v: unknown): v is Obj => !!v && typeof v === "object" && !Array.isArray(v);
const text = (v: unknown): string => (typeof v === "string" ? v.trim() : "");
const isInt = (v: unknown): v is number => typeof v === "number" && Number.isInteger(v);

/** The array each pack keeps its entries in (the editor's list). */
export const PACK_LIST_KEY: Record<PackKey, string> = {
  duas: "items",
  adhkar: "sets",
  names99: "names",
  "islamic-names": "names",
  "iman-branches": "branches",
  sunnahs: "items",
  articles: "items",
  courses: "courses",
  quizzes: "quizzes",
  mosques: "mosques",
  faq: "items",
};

/** Bengali pack names for the admin and the audit log. */
export const PACK_LABEL_BN: Record<PackKey, string> = {
  duas: "দোয়া",
  adhkar: "আযকার",
  names99: "আল্লাহর ৯৯ নাম",
  "islamic-names": "ইসলামিক নাম",
  "iman-branches": "ঈমানের শাখা",
  sunnahs: "সুন্নাহ",
  articles: "আর্টিকেল",
  courses: "কোর্স",
  quizzes: "কুইজ",
  mosques: "মসজিদ",
  faq: "জিজ্ঞাসা (FAQ)",
};

/** Number of entries (nested lessons/questions/dhikr counted inside). */
export function countItems(pack: PackKey, data: unknown): number {
  if (!isObj(data)) return 0;
  const list = data[PACK_LIST_KEY[pack]];
  return Array.isArray(list) ? list.length : 0;
}

export function validatePack(pack: PackKey, data: unknown): PackIssue[] {
  const issues: PackIssue[] = [];
  const add = (path: string, message: string) => issues.push({ path, message });
  if (!isObj(data)) {
    add("", "প্যাকটি অবজেক্ট আকারে দিন");
    return issues;
  }
  const listKey = PACK_LIST_KEY[pack];
  const list = data[listKey];
  if (!Array.isArray(list) || list.length === 0) {
    add(listKey, "অন্তত একটি এন্ট্রি দিন");
    return issues;
  }

  const seen = new Set<string>();
  const uniqueId = (path: string, id: unknown) => {
    const key = typeof id === "number" ? String(id) : text(id);
    if (!key) {
      add(`${path}.id`, "আইডি দিন");
      return;
    }
    if (seen.has(key)) add(`${path}.id`, `আইডি "${key}" দুবার আছে`);
    seen.add(key);
  };
  const need = (path: string, o: Obj, field: string, label: string) => {
    if (!text(o[field])) add(`${path}.${field}`, `${label} দিন`);
  };
  const needSource = (path: string, o: Obj) => {
    if (!text(o.reference)) add(`${path}.reference`, "সূত্র (হাদিস/আয়াত) দিন — সূত্র ছাড়া যাচাইয়ে পাঠানো যায় না");
  };

  list.forEach((raw, i) => {
    const p = `${listKey}[${i}]`;
    if (!isObj(raw)) {
      add(p, "এন্ট্রিটি ঠিক আকারে নেই");
      return;
    }
    const o = raw;
    switch (pack) {
      case "duas":
        uniqueId(p, o.id);
        need(p, o, "titleBn", "শিরোনাম");
        need(p, o, "arabic", "আরবি");
        need(p, o, "translationBn", "অনুবাদ");
        need(p, o, "category", "বিভাগ");
        needSource(p, o);
        break;
      case "sunnahs":
        uniqueId(p, o.id);
        need(p, o, "titleBn", "শিরোনাম");
        need(p, o, "detailBn", "বিবরণ");
        need(p, o, "category", "বিভাগ");
        needSource(p, o);
        break;
      case "adhkar": {
        uniqueId(p, o.id);
        need(p, o, "titleBn", "সেটের নাম");
        if (!["morning", "evening", "post_salat", "other"].includes(text(o.period))) {
          add(`${p}.period`, "সময় বেছে নিন (সকাল / সন্ধ্যা / নামাজের পর)");
        }
        const items = o.items;
        if (!Array.isArray(items) || items.length === 0) {
          add(`${p}.items`, "অন্তত একটি যিকির দিন");
          break;
        }
        const ids = new Set<string>();
        items.forEach((it, j) => {
          const q = `${p}.items[${j}]`;
          if (!isObj(it)) return add(q, "যিকিরটি ঠিক আকারে নেই");
          const id = text(it.id);
          if (!id) add(`${q}.id`, "আইডি দিন");
          else if (ids.has(id)) add(`${q}.id`, `আইডি "${id}" দুবার আছে`);
          ids.add(id);
          need(q, it, "arabic", "আরবি");
          need(q, it, "translationBn", "অনুবাদ");
          if (!isInt(it.count) || (it.count as number) < 1) add(`${q}.count`, "কতবার পড়তে হবে (১ বা বেশি) দিন");
          needSource(q, it);
        });
        break;
      }
      case "names99":
        uniqueId(p, o.id);
        if (!isInt(o.id)) add(`${p}.id`, "ক্রমিক নম্বর দিন");
        need(p, o, "arabic", "আরবি নাম");
        need(p, o, "translitBn", "উচ্চারণ");
        need(p, o, "meaningBn", "অর্থ");
        break;
      case "islamic-names":
        uniqueId(p, o.id);
        need(p, o, "name", "নাম");
        need(p, o, "meaningBn", "অর্থ");
        if (!["boy", "girl"].includes(text(o.gender))) add(`${p}.gender`, "ছেলে না মেয়ের নাম, বেছে নিন");
        break;
      case "iman-branches":
        uniqueId(p, o.id);
        need(p, o, "titleBn", "শাখার নাম");
        if (!["heart", "tongue", "body"].includes(text(o.group))) add(`${p}.group`, "ভাগ বেছে নিন (অন্তর / জবান / দেহ)");
        break;
      case "articles":
        uniqueId(p, o.id);
        need(p, o, "titleBn", "শিরোনাম");
        need(p, o, "bodyBn", "লেখা");
        break;
      case "courses": {
        uniqueId(p, o.id);
        need(p, o, "titleBn", "কোর্সের নাম");
        const lessons = o.lessons;
        if (!Array.isArray(lessons) || lessons.length === 0) add(`${p}.lessons`, "অন্তত একটি পাঠ দিন");
        else
          lessons.forEach((l, j) => {
            if (!isObj(l)) return add(`${p}.lessons[${j}]`, "পাঠটি ঠিক আকারে নেই");
            need(`${p}.lessons[${j}]`, l, "titleBn", "পাঠের নাম");
            need(`${p}.lessons[${j}]`, l, "bodyBn", "পাঠের লেখা");
          });
        break;
      }
      case "quizzes": {
        uniqueId(p, o.id);
        need(p, o, "titleBn", "কুইজের নাম");
        const qs = o.questions;
        if (!Array.isArray(qs) || qs.length === 0) add(`${p}.questions`, "অন্তত একটি প্রশ্ন দিন");
        else
          qs.forEach((q, j) => {
            const qp = `${p}.questions[${j}]`;
            if (!isObj(q)) return add(qp, "প্রশ্নটি ঠিক আকারে নেই");
            need(qp, q, "questionBn", "প্রশ্ন");
            const opts = q.options;
            if (!Array.isArray(opts) || opts.filter((x) => text(x)).length < 2) {
              add(`${qp}.options`, "অন্তত দুটি উত্তর দিন");
            } else if (!isInt(q.answerIndex) || (q.answerIndex as number) < 0 || (q.answerIndex as number) >= opts.length) {
              add(`${qp}.answerIndex`, "সঠিক উত্তরটি বেছে নিন");
            }
          });
        break;
      }
      case "mosques":
        uniqueId(p, o.id);
        need(p, o, "nameBn", "মসজিদের নাম");
        if (typeof o.lat !== "number" || typeof o.lng !== "number") add(`${p}.lat`, "অবস্থান (অক্ষাংশ/দ্রাঘিমাংশ) দিন");
        break;
      case "faq":
        need(p, o, "q", "প্রশ্ন");
        need(p, o, "a", "উত্তর");
        break;
    }
  });
  return issues;
}
