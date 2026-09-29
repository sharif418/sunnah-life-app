import { Controller, Get, Param } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { Injectable, Logger } from "@nestjs/common";
import { loadPack, loadQuran, PACK_KEYS, packDocuments, type PackKey } from "../shared/quran";
import { ApiError } from "../common/api-error";

@Injectable()
export class ContentService {
  /** GET /api/quran/surahs — full surah list (cached content pack). */
  async surahs() {
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
    return { surahs };
  }

  /** GET /api/quran/surah/:number — ayahs with Bengali translation. */
  async surah(n: number) {
    const cache = await loadQuran();
    const s = cache.surahs.find((x) => x.number === n);
    if (!s) throw new ApiError(404, "সূরা পাওয়া যায়নি");
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

    return {
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
    };
  }

  /** GET /api/content/:pack — static content packs (duas, adhkar, names99, …). */
  async pack(key: string) {
    if (!PACK_KEYS.includes(key as PackKey)) {
      throw new ApiError(404, "কন্টেন্ট প্যাক পাওয়া যায়নি");
    }
    const data = await loadPack(key);
    if (data === null) throw new ApiError(404, "কন্টেন্ট প্যাক পাওয়া যায়নি");
    return { pack: key, data };
  }
}

/**
 * Meilisearch indexer — fire-and-forget on boot when MEILI_HOST is set.
 * Indexes duas / names99 / articles from the content packs. Never throws:
 * absence of Meilisearch must not crash the API.
 */
@Injectable()
export class MeiliIndexer {
  private readonly logger = new Logger(MeiliIndexer.name);
  readonly indexes: { uid: string; pack: PackKey }[] = [
    { uid: "duas", pack: "duas" },
    { uid: "names99", pack: "names99" },
    { uid: "articles", pack: "articles" },
  ];

  onModuleInit() {
    const host = process.env.MEILI_HOST;
    if (!host) {
      this.logger.log("MEILI_HOST not set — skipping search indexing");
      return;
    }
    void this.syncAll(host);
  }

  private async syncAll(host: string) {
    for (const { uid, pack } of this.indexes) {
      try {
        const data = await loadPack(pack);
        const docs = packDocuments(data);
        if (!docs.length) continue;
        // POST /indexes with the uid in the BODY is the Meilisearch v1.x
        // create route [C-W5-ops]. The old code POSTed /indexes/{uid}, which
        // v1.x answers with 405 Method Not Allowed — seen on the live staging
        // deployment as "create index … → 405" on every boot, so the indexes
        // were never created and the document adds below always failed.
        const res = await fetch(`${host}/indexes`, {
          method: "POST",
          headers: this.headers(),
          body: JSON.stringify({ uid, primaryKey: "id" }),
        });
        if (!res.ok) {
          const detail = await res.text().catch(() => "");
          // 400 index_already_exists = normal second-boot path — sync the
          // documents anyway. Any other failure: warn with the meili error
          // body (it names the real cause) and skip this index.
          if (!(res.status === 400 && detail.includes("index_already_exists"))) {
            this.logger.warn(`Meilisearch create index ${uid} → ${res.status} ${detail.slice(0, 200)}`);
            continue;
          }
        }
        const add = await fetch(`${host}/indexes/${uid}/documents?primaryKey=id`, {
          method: "POST",
          headers: this.headers(),
          body: JSON.stringify(docs),
        });
        this.logger.log(`Meilisearch ${uid}: ${docs.length} docs → ${add.status}`);
      } catch (e) {
        this.logger.warn(`Meilisearch index ${uid} failed: ${e instanceof Error ? e.message : e}`);
      }
    }
  }

  private headers(): Record<string, string> {
    const h: Record<string, string> = { "Content-Type": "application/json" };
    if (process.env.MEILI_KEY) h.Authorization = `Bearer ${process.env.MEILI_KEY}`;
    return h;
  }
}

@ApiTags("content")
@Controller()
export class ContentController {
  constructor(private readonly service: ContentService) {}

  @Get("quran/surahs")
  @ApiOperation({ summary: "Qur'an surah index (114)" })
  surahs() {
    return this.service.surahs();
  }

  @Get("quran/surah/:number")
  @ApiOperation({ summary: "Surah with Uthmani text + Bengali translation" })
  surah(@Param("number") number: string) {
    const n = parseInt(number, 10);
    if (!Number.isFinite(n) || n < 1 || n > 114) {
      throw new ApiError(400, "সূরা নম্বর সঠিক নয়");
    }
    return this.service.surah(n);
  }

  @Get("content/:pack")
  @ApiOperation({ summary: "Content pack: duas, adhkar, names99, courses, …" })
  pack(@Param("pack") pack: string) {
    return this.service.pack(pack);
  }
}
