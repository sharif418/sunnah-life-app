import { Controller, Get, Param, Query } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { Injectable, Logger } from "@nestjs/common";
import { loadPack, loadQuran, PACK_KEYS, packDocuments, type PackKey } from "../shared/quran";
import { ApiError } from "../common/api-error";
import { SearchService } from "./search.service";

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
 * Per-pack Meilisearch settings [W4j]. `typoTolerance.minWordSizeForTypos`
 * is the Bengali adjustment: Bengali vowels/signs are separate code points,
 * so real-world words measure 4–10 cps — allowing ONE typo from 4 cps keeps
 * short words like "নাম" adjacent while still refusing 2-cp fragments.
 * `searchableAttributes` ranks the display title first (a title hit should
 * outrank a body hit) and keeps ids/references out of the index query path.
 */
export function searchSettings(pack: PackKey): Record<string, unknown> {
  const base = { typoTolerance: { minWordSizeForTypos: { oneTypo: 4, twoTypos: 8 } } };
  const searchable: Record<PackKey, string[]> = {
    duas: ["titleBn", "translationBn", "translitBn", "virtue", "arabic"],
    adhkar: ["titleBn", "items.translationBn", "items.translitBn", "items.arabic"],
    names99: ["translitBn", "meaningBn", "virtue", "arabic"],
    "islamic-names": ["name", "meaningBn", "gender_note"],
    articles: ["titleBn", "excerptBn", "bodyBn", "category"],
    // packs below are not meili-indexed — settings kept for completeness
    "iman-branches": [],
    sunnahs: [],
    courses: [],
    quizzes: [],
    mosques: [],
    faq: [],
  };
  return { ...base, searchableAttributes: searchable[pack] };
}

/**
 * Meilisearch indexer — fire-and-forget on boot when MEILI_HOST is set.
 * Indexes duas / adhkar / names99 / islamic-names / articles from the content
 * packs. Never throws: absence of Meilisearch must not crash the API.
 */
@Injectable()
export class MeiliIndexer {
  private readonly logger = new Logger(MeiliIndexer.name);
  readonly indexes: { uid: string; pack: PackKey }[] = [
    { uid: "duas", pack: "duas" },
    { uid: "adhkar", pack: "adhkar" },
    { uid: "names99", pack: "names99" },
    { uid: "islamic-names", pack: "islamic-names" },
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
        // [W4j] Bengali typo tolerance + relevance: one typo allowed from
        // 4-character words (Bengali vowels are separate code points, so the
        // default 5 makes common words like "দোয়া" (5 cps) borderline and
        // 3–4 cp words typo-deaf) and searchable fields ranked title-first so
        // a title hit outranks a body hit. Settings are an enhancement: a
        // non-2xx answer warns and the documents still sync (default
        // typoTolerance remains active server-side).
        const settings = await fetch(`${host}/indexes/${uid}/settings`, {
          method: "PATCH",
          headers: this.headers(),
          body: JSON.stringify(searchSettings(pack)),
        });
        if (!settings.ok) {
          this.logger.warn(`Meilisearch settings ${uid} → ${settings.status}`);
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
  constructor(
    private readonly service: ContentService,
    private readonly searchService: SearchService
  ) {}

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

  /** GET /api/search — public (guests can search; content packs are public,
   *  same convention as /api/content/:pack + /api/courses). */
  @Get("search")
  @ApiOperation({ summary: "Unified pack search: duas, adhkar, 99 names, Islamic names, articles" })
  search(@Query("q") q?: string, @Query("limit") limit?: string) {
    return this.searchService.search(q, limit);
  }

  @Get("content/:pack")
  @ApiOperation({ summary: "Content pack: duas, adhkar, names99, courses, …" })
  pack(@Param("pack") pack: string) {
    return this.service.pack(pack);
  }
}
