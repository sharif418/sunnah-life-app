import { NextRequest } from "next/server";
import { json, errorResponse } from "@/lib/server/guard";
import { loadQuran } from "@/lib/server/quran";


export async function GET(_req: NextRequest, ctx: { params: Promise<{ number: string }> }) {
  try {
    const { number } = await ctx.params;
    const n = parseInt(number, 10);
    if (!Number.isFinite(n) || n < 1 || n > 114) {
      return json({ error: "সূরা নম্বর সঠিক নয়" }, 400);
    }
    const cache = await loadQuran();
    const s = cache.surahs.find((x) => x.number === n);
    if (!s) return json({ error: "সূরা পাওয়া যায়নি" }, 404);
    const bn = cache.bnBySurah.get(n) ?? [];

    const bismillahPre = n !== 1 && n !== 9;
    // Robust Bismillah strip: the first 4 space-separated words of ayah 1 are
    // the Basmala (Uthmani datasets embed it with varying diacritics).
    const stripBismillah = (i: number, text: string) => {
      const clean = text.replace(/^\ufeff/, "");
      if (bismillahPre && i === 0 && clean.startsWith("بِسْمِ")) {
        const words = clean.split(/ +/);
        if (words.length > 4) return words.slice(4).join(" ");
      }
      return clean;
    };

    return json({
      surah: {
        number: s.number,
        name: s.name,
        nameBn: cache.bnNames?.[n] ?? s.englishName,
        englishName: s.englishName,
        englishNameTranslation: s.englishNameTranslation,
        revelationType: s.revelationType,
        bismillahPre,
        ayahs: s.ayahs.map((a, i) => ({
          numberInSurah: a.numberInSurah,
          text: stripBismillah(i, a.text),
          translationBn: bn[a.numberInSurah - 1] ?? undefined,
          page: a.page,
          juz: a.juz,
        })),
      },
    });
  } catch (e) {
    return errorResponse(e);
  }
}
