// ─────────────────────────────────────────────────────────────────────────────
// meili-indexer.spec.ts [C/W5-ops] — pins the Meilisearch v1.x contract of the
// boot indexer. The live staging deployment logged "create index … → 405" on
// every boot because the code POSTed /indexes/{uid}; Meilisearch v1.x creates
// indexes via POST /indexes with the uid in the BODY (POST /indexes/{uid} is
// not a route — it answers 405). The same inspection found packDocuments
// returning the FIRST array property (duas.json's `categories` — no id field)
// so the duas index silently stayed empty; these tests pin both fixes.
// Unit-level: global.fetch is stubbed, no Meilisearch needed.
// ─────────────────────────────────────────────────────────────────────────────
import { MeiliIndexer } from "src/content/content.controller";
import { loadPack, packDocuments } from "src/shared/quran";

const HOST = "http://meili.test:7700";
const originalFetch = globalThis.fetch;

type Call = { url: string; method?: string; body?: string; headers?: Record<string, string> };

interface StubResponse {
  status: number;
  body: string;
}

function stubFetch(respond: (call: Call) => StubResponse | undefined): Call[] {
  const calls: Call[] = [];
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    const call: Call = {
      url,
      method: init?.method,
      body: typeof init?.body === "string" ? init.body : undefined,
      headers: init?.headers as Record<string, string> | undefined,
    };
    calls.push(call);
    const hit = respond(call);
    if (!hit) throw new Error(`unexpected fetch: ${call.method} ${call.url}`);
    return new Response(hit.body, {
      status: hit.status,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return calls;
}

/** happy-path meili: create → 202 task, settings PATCH → 202 task,
 * add documents → 202 task */
const happy = (call: Call): StubResponse | undefined => {
  if (call.url === `${HOST}/indexes` && call.method === "POST") {
    return { status: 202, body: '{"taskUid":1,"indexUid":"x","type":"indexCreation","enqueuedAt":"2026-10-01T00:00:00Z"}' };
  }
  if (/\/indexes\/[a-z0-9_-]+\/settings\/?$/.test(call.url) && call.method === "PATCH") {
    return { status: 202, body: '{"taskUid":3,"type":"settingsUpdate","enqueuedAt":"2026-10-01T00:00:00Z"}' };
  }
  if (/\/indexes\/[a-z0-9_-]+\/documents\?primaryKey=id$/.test(call.url) && call.method === "POST") {
    return { status: 202, body: '{"taskUid":2,"type":"documentAdditionOrUpdate","enqueuedAt":"2026-10-01T00:00:00Z"}' };
  }
  return undefined;
};

/** Run the (private) syncAll deterministically. */
const syncAll = (ix: MeiliIndexer, host: string): Promise<void> => (ix as unknown as { syncAll: (h: string) => Promise<void> }).syncAll(host);

afterEach(() => {
  globalThis.fetch = originalFetch;
  delete process.env.MEILI_KEY;
});

describe("MeiliIndexer — Meilisearch v1.x routes [C/W5-ops]", () => {
  it("creates indexes via POST /indexes (uid in the body) — never the 405 route POST /indexes/{uid}", async () => {
    const calls = stubFetch(happy);
    await syncAll(new MeiliIndexer(), HOST);

    const creates = calls.filter((c) => c.url === `${HOST}/indexes` && c.method === "POST");
    expect(creates).toHaveLength(5); // duas, adhkar, names99, islamic-names, articles [W4j]
    for (const c of creates) {
      const body = JSON.parse(c.body ?? "");
      expect(typeof body.uid).toBe("string");
      expect(body.primaryKey).toBe("id");
    }
    // the route Meilisearch answers with 405 must appear NOWHERE
    const badRoute = calls.filter((c) => c.method === "POST" && /\/indexes\/[a-z0-9_-]+\/?$/.test(c.url));
    expect(badRoute).toEqual([]);
  });

  it("adds the documents of every index after create (5 adds, primaryKey=id in the query)", async () => {
    const calls = stubFetch(happy);
    await syncAll(new MeiliIndexer(), HOST);

    const adds = calls.filter((c) => c.method === "POST" && c.url.includes("/documents?primaryKey=id"));
    expect(adds).toHaveLength(5);
    for (const c of adds) {
      const docs = JSON.parse(c.body ?? "");
      expect(Array.isArray(docs)).toBe(true);
      expect(docs.length).toBeGreaterThan(0);
      for (const d of docs) expect("id" in d).toBe(true);
    }
  });

  it("duas pack yields its 32 id-bearing items (packDocuments walks past `categories`)", async () => {
    // direct pin of the packDocuments fix — duas.json's FIRST array is
    // `categories` (no id); the fix must surface `items` (32, with id).
    const data = await loadPack("duas");
    expect(packDocuments(data)).toHaveLength(32);
  });

  it("400 index_already_exists still syncs the documents (normal second boot)", async () => {
    const calls = stubFetch((call) => {
      if (call.url === `${HOST}/indexes` && call.method === "POST") {
        return {
          status: 400,
          body: JSON.stringify({
            message: "Index `duas` already exists.",
            code: "index_already_exists",
            type: "invalid_request",
            link: "https://www.meilisearch.com/docs/reference/errors/error_codes#index_already_exists",
          }),
        };
      }
      return happy(call);
    });
    await syncAll(new MeiliIndexer(), HOST);
    expect(calls.filter((c) => c.method === "POST" && c.url.includes("/documents?primaryKey=id"))).toHaveLength(5);
  });

  it("any other create failure (e.g. 401) skips the document add for that index", async () => {
    let denied = false;
    const calls = stubFetch((call) => {
      if (call.url === `${HOST}/indexes` && call.method === "POST") {
        if (!denied) {
          denied = true;
          return { status: 401, body: JSON.stringify({ message: "Invalid API key", code: "invalid_api_key" }) };
        }
        return happy(call);
      }
      return happy(call);
    });
    await syncAll(new MeiliIndexer(), HOST);
    // only the four successful creates got their documents added
    expect(calls.filter((c) => c.method === "POST" && c.url.includes("/documents?primaryKey=id"))).toHaveLength(4);
  });

  it("sends the MEILI_KEY bearer when configured", async () => {
    process.env.MEILI_KEY = "master-key-for-test";
    const calls = stubFetch(happy);
    await syncAll(new MeiliIndexer(), HOST);
    for (const c of calls) {
      expect((c.headers ?? {}).Authorization).toBe("Bearer master-key-for-test");
    }
  });

  it("[W4j] PATCHes Bengali typo tolerance + ranked searchableAttributes on every index", async () => {
    const calls = stubFetch(happy);
    await syncAll(new MeiliIndexer(), HOST);

    const patches = calls.filter((c) => c.method === "PATCH" && /\/indexes\/[a-z0-9_-]+\/settings\/?$/.test(c.url));
    expect(patches).toHaveLength(5);
    for (const c of patches) {
      const body = JSON.parse(c.body ?? "");
      // Bengali adjustment: one typo allowed from 4-code-point words
      expect(body.typoTolerance.minWordSizeForTypos.oneTypo).toBe(4);
      expect(body.typoTolerance.minWordSizeForTypos.twoTypos).toBe(8);
      // ranked searchable attributes — the display title first
      expect(Array.isArray(body.searchableAttributes)).toBe(true);
      expect(body.searchableAttributes.length).toBeGreaterThan(0);
    }
    const duas = patches.find((c) => c.url.includes("/indexes/duas/"));
    expect(JSON.parse(duas!.body ?? "").searchableAttributes[0]).toBe("titleBn");
  });

  it("[W4j] a settings failure only warns — the documents still sync", async () => {
    const calls = stubFetch((call) => {
      if (/\/indexes\/[a-z0-9_-]+\/settings\/?$/.test(call.url) && call.method === "PATCH") {
        return { status: 500, body: JSON.stringify({ message: "boom", code: "internal" }) };
      }
      return happy(call);
    });
    await syncAll(new MeiliIndexer(), HOST);
    expect(calls.filter((c) => c.method === "POST" && c.url.includes("/documents?primaryKey=id"))).toHaveLength(5);
  });
});
