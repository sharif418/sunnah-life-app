// ─────────────────────────────────────────────────────────────────────────────
// Content pack canary (Phase C/W1c) — regression tests for the bugs that only
// showed up on the owner's real phone:
//   1. quran-meta-bn.json was { "surahs": [] }  → the Qur'an reader showed
//      NOTHING. Asserts: exactly 114 surahs, real names, 6236 ayahs.
//   2. Mobile asset copies drifted from packages/content (faq/mosques were
//      {} in the app, amal-catalog/level-rules missing entirely).
//   3. The assessment criteria text drifted from the client's PDF
//      (তাদাব্বুর→আলোচনা, ধীরস্থিরভাবে→ধৈর্য). Asserts verbatim strings.
//   4. The Muhibbus checklist was six generic lines (one misspelled
//      "ত্যাগ-ো-কুরবানি"). Asserts the full outline ≥ 30 goals + ladder fix.
// ─────────────────────────────────────────────────────────────────────────────
import { promises as fs } from "fs";
import path from "path";

const CONTENT_DIR = process.env.CONTENT_DIR
  ? path.resolve(process.env.CONTENT_DIR)
  : path.resolve(__dirname, "..", "..", "..", "packages", "content");
const MOBILE_CONTENT_DIR = path.resolve(
  __dirname, "..", "..", "..", "apps", "mobile", "assets", "content"
);

async function readJson(file: string, dir = CONTENT_DIR): Promise<any> {
  return JSON.parse(await fs.readFile(path.join(dir, file), "utf8"));
}

describe("content packs (canary — the on-device regressions)", () => {
  describe("quran-meta-bn.json — the Qur'an reader must not be empty", () => {
    it("lists exactly 114 surahs with Bengali + Arabic + English names", async () => {
      const meta = await readJson("quran-meta-bn.json");
      expect(Array.isArray(meta.surahs)).toBe(true);
      expect(meta.surahs).toHaveLength(114);
      for (const s of meta.surahs) {
        expect(s.number).toBeGreaterThan(0);
        expect(s.name).toMatch(/سورة|سُورَة/); // Arabic name present
        expect(String(s.nameBn ?? "").length).toBeGreaterThan(0);
        expect(String(s.englishName ?? "").length).toBeGreaterThan(0);
        expect(["মাক্কী", "মাদানী"]).toContain(s.revelationType);
        expect(s.ayahCount).toBeGreaterThanOrEqual(3);
      }
    });

    it("totals 6236 ayahs across the 114 surahs", async () => {
      const meta = await readJson("quran-meta-bn.json");
      const total = meta.surahs.reduce((a: number, s: { ayahCount: number }) => a + s.ayahCount, 0);
      expect(total).toBe(6236);
    });

    it("anchors: ফাতিহা=7, বাকারা=286 মাদানী, ইউসুফ মাক্কী, নাস=6", async () => {
      const meta = await readJson("quran-meta-bn.json");
      const by = (n: number) => meta.surahs.find((s: { number: number }) => s.number === n);
      expect(by(1).nameBn).toBe("আল-ফাতিহা");
      expect(by(1).ayahCount).toBe(7);
      expect(by(2).ayahCount).toBe(286);
      expect(by(2).revelationType).toBe("মাদানী");
      expect(by(12).nameBn).toBe("ইউসুফ");
      expect(by(12).revelationType).toBe("মাক্কী");
      expect(by(114).nameBn).toBe("আন-নাস");
      expect(by(114).ayahCount).toBe(6);
    });
  });

  describe("mobile asset copies — single source (packages/content)", () => {
    const PACKS = [
      "amal-catalog.json", "assessment-farze-ain-v1.json", "level-rules.json",
      "diary-instructions.json", "duas.json", "adhkar.json", "names99.json",
      "islamic-names.json", "iman-branches.json", "sunnahs.json",
      "articles.json", "courses.json", "quizzes.json", "mosques.json",
      "faq.json", "quran-meta-bn.json", "quran-uthmani.json", "quran-bn.json",
    ];

    it.each(PACKS)("%s is byte-identical in apps/mobile/assets/content", async (pack) => {
      const src = await fs.readFile(path.join(CONTENT_DIR, pack), "utf8");
      const dst = await fs.readFile(path.join(MOBILE_CONTENT_DIR, pack), "utf8");
      expect(dst).toBe(src);
    });

    it("faq + mosques packs are not the empty {} the phone shipped with", async () => {
      const faq = await readJson("faq.json", MOBILE_CONTENT_DIR);
      expect(faq.items.length).toBeGreaterThanOrEqual(15);
      const mosques = await readJson("mosques.json", MOBILE_CONTENT_DIR);
      expect(mosques.mosques.length).toBeGreaterThanOrEqual(20);
    });
  });

  describe("farze_ain_v1.1 — the client's VERBATIM text", () => {
    it("has exactly 23 criteria across the four sections (৫+৫+৬+৭)", async () => {
      const t = await readJson("assessment-farze-ain-v1.json");
      expect(t.key).toBe("farze_ain_v1.1");
      const counts = t.sections.map((s: { criteria: unknown[] }) => s.criteria.length);
      expect(counts).toEqual([5, 5, 6, 7]);
      expect(counts.reduce((a: number, b: number) => a + b, 0)).toBe(23);
    });

    it("carries the exact drifted-back phrases (তাদাব্বুর, ধীরস্থিরভাবে, নিভৃতে)", async () => {
      const t = await readJson("assessment-farze-ain-v1.json");
      const all = t.sections.flatMap((s: { criteria: { titleBn: string }[] }) =>
        s.criteria.map((c: { titleBn: string }) => c.titleBn)).join("\n");
      expect(all).toContain("তিলাওয়াত ও তাদাব্বুর করতে পারেন");
      expect(all).toContain("সর্বদা ধীরস্থিরভাবে ও দীর্ঘ সময় নিয়ে সালাত আদায় করেন");
      expect(all).toContain("নিভৃতে দুআ-মুনাজাত ও মুহাসাবা");
      expect(all).toContain("জেনেবুঝে পূর্ণাঙ্গ বিশ্বাস");
      // the drifted v1 wordings must NOT be there
      expect(all).not.toContain("ধৈর্য ও দীর্ঘায়িতভাবে");
      expect(all).not.toContain("অর্থসহ তিলাওয়াত ও আলোচনা");
    });

    it("carries the instructions line + both category descriptions + signatures", async () => {
      const t = await readJson("assessment-farze-ain-v1.json");
      expect(t.instructionsBn).toContain("যথাযথ ঘরে (✔) চিহ্ন দিন");
      expect(t.instructionsBn).toContain("'সম্পূর্ণ' পর্যায়ে পৌঁছালে");
      expect(t.categories).toHaveLength(2);
      expect(t.categories[0].descriptionBn).toContain("দৈনিক ৪৫ মিনিট থেকে ১ ঘণ্টা");
      expect(t.categories[1].descriptionBn).toContain("পূর্ণাঙ্গ দাঈ");
      expect(t.categoriesFooterBn).toContain("চারটি স্তম্ভের ওপর দাঁড়িয়ে আছে");
      expect(t.signatures.map((s: { labelBn: string }) => s.labelBn)).toEqual([
        "দায়িত্বশীলের স্বাক্ষর ও তারিখ",
        "অংশগ্রহণকারীর স্বাক্ষর ও তারিখ",
      ]);
      expect(t.headerFields.map((h: { labelBn: string }) => h.labelBn)).toContain("ক্যাটাগরি (১ বা ২)");
      expect(t.scale.map((s: { labelBn: string }) => s.labelBn)).toEqual(["হয়নি", "আংশিক", "সম্পূর্ণ"]);
    });
  });

  describe("level-rules.json — corrected Muhibbus Sunnah model", () => {
    it("Muhibbus: 4 months + outline review + 5 people, NOT the assessment", async () => {
      const r = await readJson("level-rules.json");
      const m = r.levels.muhibbus_sunnah;
      expect(m.minMonths).toBe(4);
      expect(m.requireAssessmentPassed).toBe(false);
      expect(m.outlineReviewRequired).toBe(true);
      expect(m.minReferralsAtLevel).toBe(5);
    });

    it("the outline carries ≥30 verbatim goals across the six categories", async () => {
      const r = await readJson("level-rules.json");
      const list = r.levels.muhibbus_sunnah.checklistBn;
      expect(list.length).toBeGreaterThanOrEqual(30);
      const cats = [...new Set(list.map((x: { categoryBn: string }) => x.categoryBn))];
      expect(cats).toEqual(["ঈমান", "ইবাদাত", "ইলম", "আখলাক", "সিফাত", "ত্যাগ ও কুরবানি"]);
    });

    it("anchor phrases from the client's outline are verbatim", async () => {
      const r = await readJson("level-rules.json");
      const labels = r.levels.muhibbus_sunnah.checklistBn
        .map((x: { label: string }) => x.label).join("\n");
      expect(labels).toContain("তাখলিয়াহ"); // আখলাক — was paraphrased before
      expect(labels).toContain("কিতাবুল আরবাঈন");
      expect(labels).toContain("মাহরাম-গায়রে মাহরাম");
      expect(labels).toContain("রাত ১০ টায় বিছানায় চলে যাবেন");
      // the misspelled "ত্যাগ-ো-কুরবানি" of the old six-line list is gone
      expect(labels).not.toContain("ত্যাগ-ো-কুরবানি");
    });

    it("farze_ain levels gate on the 23-criterion assessment", async () => {
      const r = await readJson("level-rules.json");
      expect(r.levels.farze_ain_1.requireAssessmentPassed).toBe(true);
      expect(r.levels.farze_ain_1.assessmentKey).toBe("farze_ain_v1.1");
      expect(r.levels.farze_ain_1.assessmentCategory).toBe(1);
      expect(r.levels.farze_ain_2.assessmentCategory).toBe(2);
      expect(r.ladder).toEqual(["muhibbus_sunnah", "farze_ain_1", "farze_ain_2"]);
    });
  });

  describe("diary-instructions.json — the paper diary's rules 1–6", () => {
    it("carries all six verbatim instructions + the cover quote", async () => {
      const d = await readJson("diary-instructions.json");
      expect(d.instructions).toHaveLength(6);
      expect(d.instructions[1].textBn).toContain("সেদিনই পূরণ করতে হবে");
      expect(d.instructions[5].textBn).toContain("হতাশ না হয়ে তাওবা করুন");
      expect(d.coverQuoteBn).toContain("তিরমিযী: ২৪৫৯");
      expect(d.coverQuoteAr).toContain("الكَيِّسُ");
    });
  });
});
