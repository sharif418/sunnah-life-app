import { json, errorResponse } from "@/lib/server/guard";
import { loadQuran } from "@/lib/server/quran";

export async function GET() {
  try {
    const cache = await loadQuran();
    const surahs = cache.surahs.map((s) => ({
      number: s.number,
      name: s.name,
      nameBn: cache.bnNames?.[s.number] ?? s.englishName,
      englishName: s.englishName,
      englishNameTranslation: s.englishNameTranslation,
      ayahCount: s.ayahs.length,
      revelationType: s.revelationType,
    }));
    return json({ surahs });
  } catch (e) {
    return errorResponse(e);
  }
}
