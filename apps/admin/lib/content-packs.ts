// ─────────────────────────────────────────────────────────────────────────────
// The content packs the admin edits (everything but the Qur'an): what each
// pack's list holds, the form for one entry, and the helpers the editor, the
// review diff and the CSV import share — field conversion, entry identity and
// mapping validation issues back to the entry they belong to.
// ─────────────────────────────────────────────────────────────────────────────
import type { CmsPackKey, PackIssue } from "./api";

export type Doc = Record<string, unknown>;
export type Item = Record<string, unknown>;

export interface FieldOption {
  value: string;
  label: string;
}

export interface PackField {
  key: string;
  label: string;
  /** int = whole number; bool = checkbox; lines = one array element per line
   * (quiz options); select = a fixed list (or one the pack itself holds) */
  type: "text" | "textarea" | "number" | "int" | "bool" | "lines" | "select";
  required?: boolean;
  hint?: string;
  rtl?: boolean;
  /** a long text — a taller box */
  long?: boolean;
  options?: FieldOption[];
  /** select: the options come from the pack (duas → categories) */
  optionsFrom?: { listKey: string; valueKey: string; labelKey: string };
}

/** A nested list inside each entry (a set's dhikr, a course's lessons). */
export interface ChildConfig {
  key: string;
  labelBn: string;
  titleKey: string;
  subtitleKey?: string;
  fields: PackField[];
  /** the child's `order` follows the list (the apps sort by it) */
  autoOrder?: boolean;
  /** CSV: the column naming the parent entry */
  parentColumn: string;
}

/** A small side list the pack also keeps (duas → its categories). */
export interface ExtraList {
  key: string;
  labelBn: string;
  titleKey: string;
  fields: PackField[];
}

export interface PackConfig {
  key: CmsPackKey;
  labelBn: string;
  /** one entry, for buttons ("নতুন দোয়া") */
  entryBn: string;
  /** one line for the overview card */
  descBn: string;
  arrayKey: string;
  /** the entry's id field; none → entries are known by their place (faq) */
  idKey?: string;
  /** numeric ids (99 names, baby names, iman branches) — a new entry gets the next number */
  numericId?: boolean;
  /** string ids — a new entry gets `${prefix}-<random>` (editable before the first save) */
  idPrefix?: string;
  titleKey: string;
  subtitleKey?: string;
  fields: PackField[];
  child?: ChildConfig;
  extra?: ExtraList;
  /** the religious rule: every entry carries its source */
  needsSource?: boolean;
}

export interface PackGroup {
  labelBn: string;
  packs: CmsPackKey[];
}

/** The overview's grouping — the Ilm tab's groups, then the rest. */
export const PACK_GROUPS: PackGroup[] = [
  { labelBn: "যিকির, দোয়া ও সুন্নাহ", packs: ["adhkar", "duas", "sunnahs"] },
  { labelBn: "জ্ঞান", packs: ["names99", "iman-branches", "islamic-names", "articles"] },
  { labelBn: "শেখা", packs: ["courses", "quizzes"] },
  { labelBn: "অন্যান্য", packs: ["mosques", "faq"] },
];

const PERIODS: FieldOption[] = [
  { value: "morning", label: "সকাল" },
  { value: "evening", label: "সন্ধ্যা" },
  { value: "post_salat", label: "নামাজের পর" },
  { value: "other", label: "অন্যান্য" },
];

const ID_LOCK_HINT = "আইডি দিয়ে সদস্যদের সংরক্ষিত তথ্য (প্রিয়, অগ্রগতি) বাঁধা — তাই পরে বদলানো যায় না";

export const PACK_CONFIGS: Record<CmsPackKey, PackConfig> = {
  adhkar: {
    key: "adhkar",
    entryBn: "সেট",
    labelBn: "আযকার",
    descBn: "সকাল-সন্ধ্যা ও নামাজের পরের যিকির — গণনা ও সূত্রসহ",
    arrayKey: "sets",
    idKey: "id",
    idPrefix: "set",
    titleKey: "titleBn",
    subtitleKey: "period",
    needsSource: true,
    fields: [
      { key: "id", label: "আইডি", type: "text", required: true },
      { key: "titleBn", label: "সেটের নাম", type: "text", required: true },
      { key: "period", label: "সময়", type: "select", required: true, options: PERIODS },
      { key: "totalMin", label: "মোট সময় (মিনিট)", type: "int" },
    ],
    child: {
      key: "items",
      labelBn: "যিকির",
      titleKey: "translationBn",
      subtitleKey: "reference",
      autoOrder: true,
      parentColumn: "set",
      fields: [
        { key: "id", label: "যিকিরের আইডি", type: "text", required: true },
        { key: "arabic", label: "আরবি", type: "textarea", rtl: true, required: true },
        { key: "translitBn", label: "বাংলা উচ্চারণ", type: "textarea" },
        { key: "translationBn", label: "বাংলা অর্থ", type: "textarea", required: true },
        { key: "count", label: "কতবার", type: "int", required: true },
        { key: "reference", label: "সূত্র", type: "text", required: true, hint: "যেমন: সহীহ মুসলিম ২৭২৩" },
        { key: "virtue", label: "ফযীলত", type: "textarea" },
      ],
    },
  },
  duas: {
    key: "duas",
    entryBn: "দোয়া",
    labelBn: "দোয়া",
    descBn: "প্রতিদিনের মাসনূন দোয়া — বিভাগ ও সূত্রসহ",
    arrayKey: "items",
    idKey: "id",
    idPrefix: "dua",
    titleKey: "titleBn",
    subtitleKey: "reference",
    needsSource: true,
    fields: [
      { key: "id", label: "আইডি", type: "text", required: true },
      {
        key: "category",
        label: "বিভাগ",
        type: "select",
        required: true,
        optionsFrom: { listKey: "categories", valueKey: "key", labelKey: "labelBn" },
      },
      { key: "titleBn", label: "শিরোনাম", type: "text", required: true },
      { key: "arabic", label: "আরবি", type: "textarea", rtl: true, required: true },
      { key: "translitBn", label: "বাংলা উচ্চারণ", type: "textarea" },
      { key: "translationBn", label: "বাংলা অর্থ", type: "textarea", required: true },
      { key: "reference", label: "সূত্র", type: "text", required: true, hint: "যেমন: সূরা আল-বাকারা ২০১ / সহীহ বুখারী ৬৩০৬" },
      { key: "virtue", label: "ফযীলত", type: "textarea" },
    ],
    extra: {
      key: "categories",
      labelBn: "বিভাগ",
      titleKey: "labelBn",
      fields: [
        { key: "key", label: "বিভাগের কী", type: "text", required: true, hint: "ইংরেজি ছোট হাতের, যেমন: travel" },
        { key: "labelBn", label: "বিভাগের নাম", type: "text", required: true },
      ],
    },
  },
  sunnahs: {
    key: "sunnahs",
    entryBn: "সুন্নাহ",
    labelBn: "সুন্নাহ",
    descBn: "দৈনন্দিন, নামাজের ও ভুলে যাওয়া সুন্নাহ — সূত্রসহ",
    arrayKey: "items",
    idKey: "id",
    idPrefix: "sunnah",
    titleKey: "titleBn",
    subtitleKey: "reference",
    needsSource: true,
    fields: [
      { key: "id", label: "আইডি", type: "text", required: true },
      {
        key: "category",
        label: "বিভাগ",
        type: "select",
        required: true,
        options: [
          { value: "daily", label: "দৈনন্দিন সুন্নাহ" },
          { value: "salah", label: "নামাজের সুন্নাহ" },
          { value: "forgotten", label: "ভুলে যাওয়া সুন্নাহ" },
        ],
      },
      { key: "titleBn", label: "শিরোনাম", type: "text", required: true },
      { key: "detailBn", label: "বিবরণ", type: "textarea", required: true },
      { key: "reference", label: "সূত্র", type: "text", required: true, hint: "যেমন: সহীহ বুখারী ১৬৮" },
    ],
  },
  names99: {
    key: "names99",
    entryBn: "নাম",
    labelBn: "আল্লাহর ৯৯ নাম",
    descBn: "আরবি নাম, উচ্চারণ, অর্থ ও ফযীলত",
    arrayKey: "names",
    idKey: "id",
    numericId: true,
    titleKey: "translitBn",
    subtitleKey: "meaningBn",
    fields: [
      { key: "id", label: "ক্রমিক নম্বর", type: "int", required: true },
      { key: "arabic", label: "আরবি নাম", type: "text", rtl: true, required: true },
      { key: "translitBn", label: "উচ্চারণ", type: "text", required: true },
      { key: "meaningBn", label: "অর্থ", type: "textarea", required: true },
      { key: "virtue", label: "ফযীলত ও দলিল", type: "textarea" },
    ],
  },
  "islamic-names": {
    key: "islamic-names",
    entryBn: "নাম",
    labelBn: "ইসলামিক নাম",
    descBn: "শিশুর অর্থবহ নাম — ছেলে ও মেয়ে",
    arrayKey: "names",
    idKey: "id",
    numericId: true,
    titleKey: "name",
    subtitleKey: "meaningBn",
    fields: [
      { key: "id", label: "ক্রমিক নম্বর", type: "int", required: true },
      { key: "name", label: "নাম", type: "text", required: true },
      {
        key: "gender",
        label: "কার নাম",
        type: "select",
        required: true,
        options: [
          { value: "boy", label: "ছেলে" },
          { value: "girl", label: "মেয়ে" },
        ],
      },
      { key: "meaningBn", label: "অর্থ", type: "textarea", required: true },
      { key: "gender_note", label: "টীকা / দলিল", type: "textarea" },
    ],
  },
  "iman-branches": {
    key: "iman-branches",
    entryBn: "শাখা",
    labelBn: "ঈমানের শাখা",
    descBn: "সত্তরটি শাখা — অন্তর, জবান ও দেহের",
    arrayKey: "branches",
    idKey: "id",
    numericId: true,
    titleKey: "titleBn",
    subtitleKey: "detailBn",
    fields: [
      { key: "id", label: "ক্রমিক নম্বর", type: "int", required: true },
      {
        key: "group",
        label: "ভাগ",
        type: "select",
        required: true,
        options: [
          { value: "heart", label: "অন্তরের আমল" },
          { value: "tongue", label: "জবানের আমল" },
          { value: "body", label: "দেহের আমল" },
        ],
      },
      { key: "titleBn", label: "শাখার নাম", type: "text", required: true },
      { key: "detailBn", label: "বিবরণ ও দলিল", type: "textarea" },
    ],
  },
  articles: {
    key: "articles",
    entryBn: "আর্টিকেল",
    labelBn: "আর্টিকেল",
    descBn: "তারবিয়াহ, দাওয়াহ ও সুন্নাহ নিয়ে লেখা",
    arrayKey: "items",
    idKey: "id",
    idPrefix: "article",
    titleKey: "titleBn",
    subtitleKey: "excerptBn",
    fields: [
      { key: "id", label: "আইডি", type: "text", required: true },
      { key: "titleBn", label: "শিরোনাম", type: "text", required: true },
      { key: "excerptBn", label: "সার-সংক্ষেপ", type: "textarea" },
      {
        key: "category",
        label: "বিভাগ",
        type: "select",
        options: [
          { value: "tarbiyah", label: "তারবিয়াহ" },
          { value: "dawah", label: "দাওয়াহ" },
          { value: "sunnah", label: "সুন্নাহ" },
        ],
      },
      { key: "readMinutes", label: "পড়ার সময় (মিনিট)", type: "int" },
      { key: "publishedAt", label: "প্রকাশের তারিখ", type: "text", hint: "YYYY-MM-DD" },
      { key: "bodyBn", label: "মূল লেখা", type: "textarea", long: true, required: true, hint: "অনুচ্ছেদ আলাদা করতে খালি লাইন দিন" },
    ],
  },
  courses: {
    key: "courses",
    entryBn: "কোর্স",
    labelBn: "কোর্স",
    descBn: "ধাপে ধাপে শেখার পাঠ",
    arrayKey: "courses",
    idKey: "id",
    idPrefix: "course",
    titleKey: "titleBn",
    subtitleKey: "descBn",
    fields: [
      { key: "id", label: "আইডি", type: "text", required: true },
      { key: "titleBn", label: "কোর্সের নাম", type: "text", required: true },
      { key: "descBn", label: "বিবরণ", type: "textarea" },
      { key: "level", label: "স্তর", type: "text", hint: "যেমন: মুহিব্বুস সুন্নাহ" },
    ],
    child: {
      key: "lessons",
      labelBn: "পাঠ",
      titleKey: "titleBn",
      autoOrder: true,
      parentColumn: "course",
      fields: [
        { key: "id", label: "পাঠের আইডি", type: "text", required: true },
        { key: "titleBn", label: "পাঠের নাম", type: "text", required: true },
        { key: "minutes", label: "সময় (মিনিট)", type: "int" },
        { key: "bodyBn", label: "পাঠের লেখা", type: "textarea", long: true, required: true, hint: "অনুচ্ছেদ আলাদা করতে খালি লাইন দিন" },
      ],
    },
  },
  quizzes: {
    key: "quizzes",
    entryBn: "কুইজ",
    labelBn: "কুইজ",
    descBn: "প্রশ্ন, উত্তর ও ব্যাখ্যা — লাইভ কুইজেও",
    arrayKey: "quizzes",
    idKey: "id",
    idPrefix: "quiz",
    titleKey: "titleBn",
    subtitleKey: "descBn",
    fields: [
      { key: "id", label: "আইডি", type: "text", required: true },
      { key: "titleBn", label: "কুইজের নাম", type: "text", required: true },
      { key: "descBn", label: "বিবরণ", type: "textarea" },
      { key: "category", label: "বিভাগ", type: "text", hint: "যেমন: salah / aqeedah / quran_sunnah" },
      { key: "minutes", label: "সময় (মিনিট)", type: "int" },
      { key: "live", label: "লাইভ কুইজে ব্যবহারযোগ্য", type: "bool" },
    ],
    child: {
      key: "questions",
      labelBn: "প্রশ্ন",
      titleKey: "questionBn",
      subtitleKey: "explanationBn",
      parentColumn: "quiz",
      fields: [
        { key: "id", label: "প্রশ্নের আইডি", type: "text", required: true },
        { key: "questionBn", label: "প্রশ্ন", type: "textarea", required: true },
        { key: "options", label: "উত্তরগুলো (প্রতি লাইনে একটি)", type: "lines", required: true, hint: "২–৬টি উত্তর, প্রতিটি আলাদা লাইনে" },
        { key: "answerIndex", label: "সঠিক উত্তর (কত নম্বর লাইন, ১ থেকে)", type: "int", required: true },
        { key: "explanationBn", label: "ব্যাখ্যা", type: "textarea" },
        {
          key: "difficulty",
          label: "কাঠিন্য",
          type: "select",
          options: [
            { value: "easy", label: "সহজ" },
            { value: "medium", label: "মাঝারি" },
            { value: "hard", label: "কঠিন" },
          ],
        },
      ],
    },
  },
  mosques: {
    key: "mosques",
    entryBn: "মসজিদ",
    labelBn: "মসজিদ",
    descBn: "কাছের মসজিদের তালিকা — নাম, ঠিকানা ও অবস্থান",
    arrayKey: "mosques",
    idKey: "id",
    idPrefix: "msj",
    titleKey: "nameBn",
    subtitleKey: "addressBn",
    fields: [
      { key: "id", label: "আইডি", type: "text", required: true },
      { key: "nameBn", label: "নাম (বাংলা)", type: "text", required: true },
      { key: "nameEn", label: "নাম (ইংরেজি)", type: "text" },
      { key: "addressBn", label: "ঠিকানা", type: "text" },
      { key: "area", label: "এলাকা", type: "text" },
      { key: "lat", label: "অক্ষাংশ (lat)", type: "number", required: true, hint: "গুগল ম্যাপে মসজিদে চাপ দিলে প্রথম সংখ্যাটি" },
      { key: "lng", label: "দ্রাঘিমাংশ (lng)", type: "number", required: true, hint: "দ্বিতীয় সংখ্যাটি" },
    ],
  },
  faq: {
    key: "faq",
    entryBn: "প্রশ্নোত্তর",
    labelBn: "জিজ্ঞাসা (FAQ)",
    descBn: "অ্যাপের সাহায্য পাতার প্রশ্নোত্তর",
    arrayKey: "items",
    titleKey: "q",
    subtitleKey: "a",
    fields: [
      { key: "q", label: "প্রশ্ন", type: "textarea", required: true },
      { key: "a", label: "উত্তর", type: "textarea", required: true },
      {
        key: "group",
        label: "ভাগ",
        type: "select",
        options: [
          { value: "app", label: "অ্যাপ" },
          { value: "amal", label: "আমল" },
          { value: "salat", label: "নামাজ" },
          { value: "ilm", label: "ইলম" },
          { value: "dawah", label: "দাওয়াহ" },
        ],
      },
    ],
  },
};

export { ID_LOCK_HINT };

// ── values ───────────────────────────────────────────────────────────────────

const BN_DIGIT = /[০-৯]/g;
/** Bengali digits → ASCII (editors type ১২৩ as often as 123). */
export const asciiDigits = (s: string) => s.replace(BN_DIGIT, (d) => String(d.charCodeAt(0) - 0x09e6));

/** Stored → form text: answerIndex is 0-based in the pack, 1-based in the form. */
export function toForm(f: PackField, raw: unknown): string {
  if (raw === undefined || raw === null) return f.type === "bool" ? "false" : "";
  if (f.type === "lines" && Array.isArray(raw)) return raw.map(String).join("\n");
  if (f.key === "answerIndex" && typeof raw === "number") return String(raw + 1);
  if (f.type === "bool") return raw === true ? "true" : "false";
  return String(raw);
}

/** Form text → stored value. `undefined` = leave the key out (empty). */
export function fromForm(f: PackField, text: string): { value?: unknown; error?: string } {
  const v = text.trim();
  if (f.type === "bool") return { value: ["true", "1", "হ্যাঁ", "yes"].includes(v.toLowerCase()) };
  if (v === "") return {};
  if (f.type === "lines") {
    // a CSV cell keeps them on one line, split by " | "
    const parts = v.includes("\n") ? v.split("\n") : v.split("|");
    return { value: parts.map((x) => x.trim()).filter(Boolean) };
  }
  if (f.type === "number" || f.type === "int") {
    const n = Number(asciiDigits(v));
    if (!Number.isFinite(n)) return { error: `${f.label} সংখ্যা হতে হবে` };
    if (f.type === "int" && !Number.isInteger(n)) return { error: `${f.label} পূর্ণ সংখ্যা হতে হবে` };
    return { value: f.key === "answerIndex" ? n - 1 : n };
  }
  return { value: v };
}

/** The entry with its form fields replaced by `values` — keys the form does
 * not know (a quiz's scheduledAt, a set's dhikr) are kept, cleared fields go. */
export function applyFields(original: Item | null, fields: PackField[], values: Item): Item {
  const out: Item = { ...(original ?? {}) };
  for (const f of fields) delete out[f.key];
  // keep the pack's own key order: known fields first, in form order
  const ordered: Item = {};
  for (const f of fields) if (values[f.key] !== undefined) ordered[f.key] = values[f.key];
  return { ...ordered, ...out };
}

export function optionsFor(f: PackField, doc: Doc | null): FieldOption[] {
  if (f.options) return f.options;
  if (f.optionsFrom && doc) {
    const list = doc[f.optionsFrom.listKey];
    if (Array.isArray(list)) {
      return list
        .filter((x): x is Item => !!x && typeof x === "object")
        .map((x) => ({ value: String(x[f.optionsFrom!.valueKey] ?? ""), label: String(x[f.optionsFrom!.labelKey] ?? "") }));
    }
  }
  return [];
}

/** Human text for a stored value (the list, the diff). */
export function displayValue(f: PackField | undefined, raw: unknown, doc: Doc | null = null): string {
  if (raw === undefined || raw === null || raw === "") return "";
  if (!f) return typeof raw === "string" ? raw : JSON.stringify(raw);
  if (f.type === "select") return optionsFor(f, doc).find((o) => o.value === raw)?.label ?? String(raw);
  if (f.type === "bool") return raw === true ? "হ্যাঁ" : "না";
  if (f.type === "lines" && Array.isArray(raw)) return raw.map((x, i) => `${i + 1}. ${x}`).join("\n");
  if (f.key === "answerIndex" && typeof raw === "number") return String(raw + 1);
  return String(raw);
}

/** JSON with object keys sorted — the database (jsonb) keeps its own key
 * order, so two copies of the same content only compare equal this way. */
export function stableJson(v: unknown): string {
  return JSON.stringify(v ?? null, (_k, val: unknown) =>
    val && typeof val === "object" && !Array.isArray(val)
      ? Object.fromEntries(Object.keys(val as Item).sort().map((k) => [k, (val as Item)[k]]))
      : val
  );
}

export function listOf(doc: Doc | null | undefined, key: string): Item[] {
  const v = doc?.[key];
  return Array.isArray(v) ? (v.filter((x) => !!x && typeof x === "object") as Item[]) : [];
}

/** How an entry is known across versions: its id, else its place. */
export function entryKey(idKey: string | undefined, item: Item, index: number): string {
  if (idKey && item[idKey] !== undefined && item[idKey] !== null && item[idKey] !== "") return String(item[idKey]);
  return `#${index + 1}`;
}

/** A fresh id for a new entry. */
export function nextId(cfg: { numericId?: boolean; idPrefix?: string }, items: Item[], key = "id"): string | number {
  if (cfg.numericId) {
    const nums = items.map((x) => Number(x[key])).filter((n) => Number.isFinite(n));
    return (nums.length ? Math.max(...nums) : 0) + 1;
  }
  const taken = new Set(items.map((x) => String(x[key] ?? "")));
  for (;;) {
    const id = `${cfg.idPrefix ?? "item"}-${Math.random().toString(36).slice(2, 7)}`;
    if (!taken.has(id)) return id;
  }
}

export function renumber(children: Item[]): Item[] {
  return children.map((c, i) => ({ ...c, order: i + 1 }));
}

// ── validation issues → the entry (and field) they belong to ────────────────

export interface ParsedPath {
  index: number;
  childIndex: number | null;
  field: string | null;
}

/** "sets[0].items[2].reference" → { index: 0, childIndex: 2, field: "reference" } */
export function parseIssuePath(arrayKey: string, childKey: string | undefined, path: string): ParsedPath | null {
  const m = new RegExp(`^${arrayKey.replace(/[-]/g, "\\-")}\\[(\\d+)\\](.*)$`).exec(path);
  if (!m) return null;
  const index = Number(m[1]);
  let rest = m[2];
  let childIndex: number | null = null;
  if (childKey) {
    const c = new RegExp(`^\\.${childKey}\\[(\\d+)\\](.*)$`).exec(rest);
    if (c) {
      childIndex = Number(c[1]);
      rest = c[2];
    }
  }
  const field = rest.startsWith(".") ? rest.slice(1) : null;
  return { index, childIndex, field: field || (childKey && rest === `.${childKey}` ? childKey : null) };
}

export interface EntryIssue extends ParsedPath {
  message: string;
}

/** Issues grouped by entry index; the rest (pack-level) under -1. */
export function issuesByEntry(cfg: PackConfig, issues: PackIssue[]): Map<number, EntryIssue[]> {
  const map = new Map<number, EntryIssue[]>();
  for (const is of issues) {
    const p = parseIssuePath(cfg.arrayKey, cfg.child?.key, is.path);
    const k = p ? p.index : -1;
    const list = map.get(k) ?? [];
    list.push({ ...(p ?? { index: -1, childIndex: null, field: null }), message: is.message });
    map.set(k, list);
  }
  return map;
}
