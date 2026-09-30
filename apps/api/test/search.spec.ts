// ─────────────────────────────────────────────────────────────────────────────
// search.spec.ts [W4j] — the Meilisearch query endpoint:
//   GET /api/search?q=…&limit=20  (public — guests can search)
//
// The meili client is stubbed the way test/meili-indexer.spec.ts stubs it
// (globalThis.fetch), so no Meilisearch container is needed — mirroring the
// CI api job which deliberately leaves MEILI_HOST unset.
//
// Typo-tolerance honesty: the ENGINE is Meilisearch's own Damerau–Levenshtein;
// what these tests pin is OUR side — (a) the indexer ships the Bengali
// typoTolerance settings (pinned in meili-indexer.spec.ts), (b) this
// endpoint forwards the raw q VERBATIM (never trimmed into a different
// word), and (c) the hit → grouped-row mapping works for the typo'd query's
// hit the way a configured meili answers it.
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request from "supertest";

import { AppModule } from "src/app.module";
import { loadPack, packDocuments } from "src/shared/quran";

const HOST = "http://meili.test:7700";
const originalFetch = globalThis.fetch;
/** The grouping order mirrors src/content/search.service.ts INDEXES. */
const UIDS = ["duas", "adhkar", "names99", "islamic-names", "articles"] as const;

type Call = { url: string; method?: string; body?: string };

/** Builds a meili multi-search answer: `hits` per index (default []). */
const meiliAnswer = (hits: Partial<Record<(typeof UIDS)[number], unknown[]>>) => ({
  results: UIDS.map((uid) => ({
    indexUid: uid,
    query: "",
    hits: hits[uid] ?? [],
    estimatedTotalHits: (hits[uid] ?? []).length,
    processingTimeMs: 1,
  })),
});

/** Stub fetch for ONE multi-search call; anything else = unexpected. */
function stubMultiSearch(respond: (body: { queries: { indexUid: string; q: string; limit: number }[] }) => {
  status: number;
  body: unknown;
}): Call[] {
  const calls: Call[] = [];
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    calls.push({ url, method: init?.method, body: typeof init?.body === "string" ? init.body : undefined });
    if (url === `${HOST}/multi-search` && init?.method === "POST") {
      const hit = respond(JSON.parse(String(init.body)));
      return new Response(JSON.stringify(hit.body), {
        status: hit.status,
        headers: { "Content-Type": "application/json" },
      });
    }
    throw new Error(`unexpected fetch: ${init?.method} ${url}`);
  }) as typeof fetch;
  return calls;
}

let app: INestApplication;
let http: () => ReturnType<typeof request>;
/** Real pack docs so the hit shapes are the production ones. */
let duasDocs: Record<string, unknown>[];

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
  await app.init();
  http = () => request(app.getHttpServer());
  // boot with MEILI_HOST unset (the indexer skips — no boot-time fetch), each
  // meili-backed test sets the var itself before the request.
  duasDocs = packDocuments(await loadPack("duas"));
});

afterEach(() => {
  globalThis.fetch = originalFetch;
  delete process.env.MEILI_HOST;
});

afterAll(async () => {
  await app.close();
});

describe("W4j — short-q rule (documented: <2 code points ⇒ 200 + empty list)", () => {
  it("a single Bengali character answers 200 with an empty list and never touches meili", async () => {
    stubMultiSearch(() => ({ status: 500, body: {} })); // any meili call would fail loudly
    const res = await http().get("/api/search?q=খ").expect(200);
    expect(res.body.query).toBe("খ");
    expect(res.body.results).toEqual([]);
  });

  it("missing / whitespace-only q behaves the same", async () => {
    stubMultiSearch(() => ({ status: 500, body: {} }));
    await http().get("/api/search").expect(200).expect((r) => expect(r.body.results).toEqual([]));
    await http().get("/api/search?q=%20%20").expect(200).expect((r) => expect(r.body.results).toEqual([]));
  });
});

describe("W4j — grouped results over the five packs (guest, no auth)", () => {
  const dua = () => duasDocs.find((d) => d.id === "rabbi-zidni-ilma")!;

  it("maps meili hits to grouped rows in the dua → dhikr → name99 → islamic_name → article order", async () => {
    process.env.MEILI_HOST = HOST;
    const calls = stubMultiSearch(() => ({
      status: 200,
      body: meiliAnswer({
        // deliberately answered out of display order — the endpoint groups
        articles: [{ id: "muhasaba-daily", titleBn: "মুহাসাবা: প্রতিদিনের আমলের হিসাব", excerptBn: "নিজের হিসাব নিন" }],
        names99: [{ id: 1, translitBn: "আল্লাহ", meaningBn: "সর্বোচ্চ নাম" }],
        duas: [dua()],
      }),
    }));

    const res = await http().get("/api/search?q=%E0%A6%9C%E0%A7%8D%E0%A6%9E%E0%A6%BE%E0%A6%A8").expect(200);
    expect(res.body.query).toBe("জ্ঞান");
    expect(res.body.results).toHaveLength(3);
    expect(res.body.results.map((r: { kind: string }) => r.kind)).toEqual(["dua", "name99", "article"]);

    const [row, name, article] = res.body.results;
    expect(row).toMatchObject({
      kind: "dua",
      id: "rabbi-zidni-ilma",
      title: "জ্ঞান বৃদ্ধির দোয়া",
      kindLabelBn: "দোয়া",
    });
    expect(row.subtitle).toContain("জ্ঞান");
    expect(name).toMatchObject({ kind: "name99", id: "1", title: "আল্লাহ", kindLabelBn: "আল্লাহর নাম" });
    expect(article).toMatchObject({ kind: "article", id: "muhasaba-daily", kindLabelBn: "আর্টিকেল" });

    // the wire: ONE multi-search with one query per index, same q + limit
    expect(calls).toHaveLength(1);
    const body = JSON.parse(calls[0].body ?? "");
    expect(body.queries.map((q: { indexUid: string }) => q.indexUid)).toEqual([...UIDS]);
    for (const q of body.queries) {
      expect(q.q).toBe("জ্ঞান");
      expect(q.limit).toBe(20); // default
    }
  });

  it("the adhkar subtitle reports the set's item count in Bengali digits", async () => {
    process.env.MEILI_HOST = HOST;
    const adhkarSets = packDocuments(await loadPack("adhkar"));
    const morning = adhkarSets.find((s) => s.id === "morning") as { items: unknown[] };
    expect(morning).toBeTruthy();
    stubMultiSearch(() => ({
      status: 200,
      body: meiliAnswer({ adhkar: [morning] }),
    }));

    const res = await http().get("/api/search?q=%E0%A6%B8%E0%A6%95%E0%A6%BE%E0%A6%B2").expect(200);
    expect(res.body.results).toHaveLength(1);
    expect(res.body.results[0]).toMatchObject({ kind: "dhikr", id: "morning", kindLabelBn: "আযকার", title: "সকালের মাসনূন আযকার" });
    expect(res.body.results[0].subtitle).toBe("৯টি আযকার"); // 9 items → Bengali digits
  });
});

describe("W4j — the typo story (wiring) + limit clamp", () => {
  it("forwards the typo'd q VERBATIM and maps the hit a configured meili returns", async () => {
    process.env.MEILI_HOST = HOST;
    const typoQuery = "জ্ঞাণ বৃদ্ধির দোয়া"; // ণ vs ন — the classic Bengali misspelling
    const calls = stubMultiSearch(() => ({
      status: 200,
      // what meili answers once typoTolerance.minWordSizeForTypos.oneTypo=4
      // is applied (the settings the indexer PATCHes are pinned separately
      // in test/meili-indexer.spec.ts)
      body: meiliAnswer({ duas: [duasDocs.find((d) => d.id === "rabbi-zidni-ilma")!] }),
    }));

    const res = await http().get(`/api/search?q=${encodeURIComponent(typoQuery)}`).expect(200);
    expect(res.body.results).toHaveLength(1);
    expect(res.body.results[0]).toMatchObject({ kind: "dua", id: "rabbi-zidni-ilma", title: "জ্ঞান বৃদ্ধির দোয়া" });

    // the raw q — not normalized, not trimmed into a different word
    const body = JSON.parse(calls[0].body ?? "");
    expect(body.queries[0].q).toBe(typoQuery);
    expect(body.queries.every((q: { q: string }) => q.q === typoQuery)).toBe(true);
  });

  it("clamps limit: garbage or ≤0 → default 20, >50 → 50; the response is sliced", async () => {
    process.env.MEILI_HOST = HOST;
    const many = Array.from({ length: 40 }, (_, i) => ({ id: `dua-${i}`, titleBn: `দোয়া ${i}`, translationBn: "অনুবাদ" }));
    const calls = stubMultiSearch(() => ({ status: 200, body: meiliAnswer({ duas: many }) }));

    // garbage limit → default 20 forwarded, 20 rows back
    await http().get("/api/search?q=%E0%A6%A6%E0%A7%8B%E0%A6%AF%E0%A6%BC%E0%A6%BE&limit=abc").expect(200)
      .expect((r) => expect(r.body.results).toHaveLength(20));
    expect(JSON.parse(calls[0].body ?? "").queries[0].limit).toBe(20);

    // negative → the same default (≤0 is "no limit given")
    await http().get("/api/search?q=%E0%A6%A6%E0%A7%8B%E0%A6%AF%E0%A6%BC%E0%A6%BE&limit=-2").expect(200)
      .expect((r) => expect(r.body.results).toHaveLength(20));

    // >50 → clamped to 50
    await http().get("/api/search?q=%E0%A6%A6%E0%A7%8B%E0%A6%AF%E0%A6%BC%E0%A6%BE&limit=200").expect(200)
      .expect((r) => expect(r.body.results).toHaveLength(40)); // only 40 hits exist
    expect(JSON.parse(calls[2].body ?? "").queries[0].limit).toBe(50);
  });
});

describe("W4j — meili down / absent ⇒ honest 503", () => {
  it("MEILI_HOST unset → 503 with the Bengali message", async () => {
    const res = await http().get("/api/search?q=%E0%A6%A6%E0%A7%8B%E0%A6%AF%E0%A6%BC%E0%A6%BE").expect(503);
    expect(res.body.error).toContain("অনুসন্ধান সেবা");
  });

  it("meili unreachable (network error) → 503", async () => {
    process.env.MEILI_HOST = HOST;
    globalThis.fetch = (async () => {
      throw new Error("connect ECONNREFUSED");
    }) as typeof fetch;
    const res = await http().get("/api/search?q=%E0%A6%A6%E0%A7%8B%E0%A6%AF%E0%A6%BC%E0%A6%BE").expect(503);
    expect(res.body.error).toContain("অনুসন্ধান সেবা");
  });

  it("meili answering 500 → 503 (never a half-baked fallback)", async () => {
    process.env.MEILI_HOST = HOST;
    stubMultiSearch(() => ({ status: 500, body: { message: "boom" } }));
    await http().get("/api/search?q=%E0%A6%A6%E0%A7%8B%E0%A6%AF%E0%A6%BC%E0%A6%BE").expect(503);
  });
});
