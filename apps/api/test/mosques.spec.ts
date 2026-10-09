// ─────────────────────────────────────────────────────────────────────────────
// mosques.spec.ts (2026-10-09) — GET /api/mosques/near: mosques anywhere in
// Bangladesh, answered from our own copy of OpenStreetMap (refreshed weekly)
// merged with the Foundation's verified list.
//   • OSM elements → compact rows (Bengali name first; ways by their centre)
//   • a verified mosque replaces the OSM entry for the same building
//   • the shipped snapshot covers the whole country (a fresh server has data)
//   • a refresh replaces the copy only when complete; busy mirrors (HTML with
//     status 200) fall through; a failed refresh keeps the old copy
// ─────────────────────────────────────────────────────────────────────────────
import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import { promises as fs } from "fs";
import Redis from "ioredis";
import os from "os";
import path from "path";
import request from "supertest";

import { AppModule } from "src/app.module";
import { acceptRefresh, mergeNear, MosquesService, osmCandidates } from "src/mosques/mosques.service";
import { datasetFrom, rowFromOsm, type OsmElement } from "src/mosques/osm-mosques";

const BAITUL_MUKARRAM = { lat: 23.7275, lng: 90.4122 }; // in the curated pack

const elements: OsmElement[] = [
  // the same building as the curated Baitul Mukarram (~25 m away)
  { type: "node", id: 1, lat: 23.7277, lon: 90.4123, tags: { name: "Baitul Mukarram" } },
  { type: "node", id: 2, lat: 23.729, lon: 90.414, tags: { name: "Paltan Jame Masjid", "name:bn": "পল্টন জামে মসজিদ", "addr:suburb": "পল্টন" } },
  { type: "way", id: 3, center: { lat: 23.731, lon: 90.41 }, tags: {} },
  { type: "node", id: 4, lat: 23.9, lon: 90.6, tags: { name: "far away" } }, // > 5 km
];

describe("pure parts", () => {
  it("OSM → rows: Bengali name first, way centres, unnamed → null", () => {
    expect(rowFromOsm(elements[1])).toEqual(["osm:n2", "পল্টন জামে মসজিদ", "Paltan Jame Masjid", 23.729, 90.414, "পল্টন"]);
    expect(rowFromOsm(elements[2])).toEqual(["osm:w3", null, null, 23.731, 90.41, null]);
    expect(rowFromOsm({ type: "node", id: 9, tags: {} })).toBeNull();
    // the address typed into the name becomes the place
    expect(
      rowFromOsm({ type: "node", id: 5, lat: 22.3, lon: 91.8, tags: { name: "Haji Abdul Ali Jame Mosque, Port Connecting Rd, Chattogram" } })
    ).toEqual(["osm:n5", "Haji Abdul Ali Jame Mosque", null, 22.3, 91.8, "Port Connecting Rd, Chattogram"]);
  });

  it("verified replaces the same building; nearest first; 5 km cap", () => {
    const ds = datasetFrom(elements);
    const out = mergeNear(
      osmCandidates(ds, 23.728, 90.413),
      [{ id: "msj-bm", nameBn: "বায়তুল মোকাররম", ...BAITUL_MUKARRAM }],
      23.728,
      90.413
    );
    expect(out.map((m) => m.id)).toEqual(["msj-bm", "osm:n2", "osm:w3"]);
    expect(out[0]).toMatchObject({ verified: true, name: "বায়তুল মোকাররম" });
  });

  it("a refresh must look complete before it replaces the copy", () => {
    const big = { ...datasetFrom([]), count: 12000 };
    expect(acceptRefresh({ ...big, count: 300 }, null)).toBe(false);
    expect(acceptRefresh({ ...big, count: 9000 }, big)).toBe(false);
    expect(acceptRefresh({ ...big, count: 11800 }, big)).toBe(true);
  });
});

describe("GET /api/mosques/near", () => {
  let app: INestApplication;
  let service: MosquesService;
  let storage: string;

  beforeAll(async () => {
    storage = await fs.mkdtemp(path.join(os.tmpdir(), "sl-osm-"));
    process.env.OVERPASS_URLS = "https://mirror-a.test/api,https://mirror-b.test/api";
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix("api", { exclude: ["health", "metrics"] });
    await app.init();
    service = app.get(MosquesService);
    service.storageDir = () => storage;
  });

  afterAll(async () => {
    delete process.env.OVERPASS_URLS;
    await app.close();
    await fs.rm(storage, { recursive: true, force: true });
  });

  it("rejects a bad point", async () => {
    await request(app.getHttpServer()).get("/api/mosques/near?lat=abc&lng=90").expect(400);
  });

  it("the shipped snapshot covers the country — Dhaka, Chattogram, a district town", async () => {
    service.setDataset(null); // load from disk
    for (const [lat, lng, atLeast] of [
      [23.7808, 90.4067, 40], // Tejgaon
      [22.3569, 91.7832, 40], // Chattogram
      [23.607, 89.8429, 5], // Faridpur
    ]) {
      const r = await request(app.getHttpServer()).get(`/api/mosques/near?lat=${lat}&lng=${lng}`).expect(200);
      expect(r.body.mosques.length).toBeGreaterThanOrEqual(atLeast);
      expect(r.body.attribution).toContain("OpenStreetMap");
      expect(r.body.dataAsOf).toBeTruthy();
      const d = r.body.mosques.map((m: { distanceM: number }) => m.distanceM);
      expect(d).toEqual([...d].sort((a: number, b: number) => a - b));
    }
  });

  it("refresh: a busy mirror (HTML, 200) falls through; an incomplete answer is not taken", async () => {
    const calls: string[] = [];
    const answer = JSON.stringify({ elements: Array.from({ length: 1500 }, (_, i) => ({ type: "node", id: i, lat: 23 + i / 1e4, lon: 90 })) });
    service.fetchImpl = (async (url: string) => {
      calls.push(new URL(url).host);
      return url.includes("mirror-a")
        ? new Response("<html>busy</html>", { status: 200 })
        : new Response(answer, { status: 200 });
    }) as never;
    service.setDataset({ ...datasetFrom([]), count: 1200, fetchedAt: "2020-01-01T00:00:00Z" });
    // (a lock left in the shared Redis by another process must not decide this)
    const redis = new Redis(process.env.REDIS_URL || "redis://127.0.0.1:6380");
    await redis.del("mosques:osm:refresh-lock");
    await redis.quit();
    expect(await service.refreshIfStale()).toBe("refreshed");
    expect(calls).toEqual(["mirror-a.test", "mirror-b.test"]);
    const saved = JSON.parse(await fs.readFile(path.join(storage, "osm-mosques-bd.json"), "utf8"));
    expect(saved.count).toBe(1500);

    // a later refresh that returns far fewer keeps the copy
    service.fetchImpl = (async () => new Response(JSON.stringify({ elements: [] }), { status: 200 })) as never;
    expect(await service.refreshIfStale(true)).toBe("kept");
    expect(JSON.parse(await fs.readFile(path.join(storage, "osm-mosques-bd.json"), "utf8")).count).toBe(1500);
  });
});
