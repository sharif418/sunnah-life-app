// ─────────────────────────────────────────────────────────────────────────────
// Mosques near a point — anywhere in Bangladesh, not only the Foundation's
// curated list (24 mosques in Dhaka: everyone outside Dhaka saw mosques
// 100+ km away).
//
// Answered from our own copy of OpenStreetMap's Bangladesh mosques
// (osm-mosques.ts: ~12,000, refreshed weekly; a snapshot ships with the
// content). Nothing is asked of a third party at request time — fast, works
// when OSM is down, and the reader's location never leaves our server (the
// access log drops query strings). The Foundation's curated mosques are
// merged in, marked verified, and replace the OSM entry for the same
// building.
//
// Refresh: on start and every 6 h the API checks the dataset's age; past 7
// days ONE instance (Redis lock) fetches the country again; the new set
// replaces the old only when it is complete (≥ 80% of the previous count),
// written atomically to STORAGE_DIR/osm/. A failed refresh changes nothing.
// ─────────────────────────────────────────────────────────────────────────────
import { Injectable, Logger, OnApplicationBootstrap, OnModuleDestroy } from "@nestjs/common";
import { promises as fs } from "fs";
import Redis from "ioredis";
import path from "path";

import { ApiError } from "../common/api-error";
import { contentDir } from "../shared/levels";
import { loadPack } from "../shared/quran";
import { DEFAULT_OVERPASS_MIRRORS, fetchCountry, OSM_ATTRIBUTION, type OsmMosqueDataset } from "./osm-mosques";

export interface NearbyMosque {
  /** "osm:n123" / "osm:w123", or the curated pack id */
  id: string;
  /** Bengali name when mapped, else the local name; null when unnamed */
  name: string | null;
  nameEn: string | null;
  address: string | null;
  area: string | null;
  lat: number;
  lng: number;
  distanceM: number;
  /** from the Foundation's curated list */
  verified: boolean;
}

export interface NearbyResult {
  mosques: NearbyMosque[];
  attribution: string;
  /** when the OpenStreetMap copy was taken (null: none loaded) */
  dataAsOf: string | null;
}

type Candidate = Omit<NearbyMosque, "distanceM">;

export const NEAR_RADIUS_M = 5000;
const MAX_RESULTS = 60;
const SAME_PLACE_M = 80;
const REFRESH_AFTER_MS = 7 * 86_400_000;
const CHECK_EVERY_MS = 6 * 3_600_000;
const SNAPSHOT = "osm-mosques-bd.json";

export function distanceM(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const R = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(bLat - aLat);
  const dLng = toRad(bLng - aLng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLng / 2) ** 2;
  return Math.round(2 * R * Math.asin(Math.sqrt(h)));
}

interface CuratedMosque {
  id?: string;
  nameBn?: string;
  nameEn?: string;
  addressBn?: string;
  area?: string;
  lat?: number;
  lng?: number;
}

/** The dataset's rows within reach of a point (a cheap box first, then the circle's job is mergeNear's). */
export function osmCandidates(ds: OsmMosqueDataset | null, lat: number, lng: number): Candidate[] {
  if (!ds) return [];
  const dLat = NEAR_RADIUS_M / 111_000 + 0.01;
  const dLng = dLat / Math.max(0.2, Math.cos((lat * Math.PI) / 180));
  const out: Candidate[] = [];
  for (const [id, name, nameEn, mLat, mLng, area] of ds.rows) {
    if (Math.abs(mLat - lat) > dLat || Math.abs(mLng - lng) > dLng) continue;
    out.push({ id, name, nameEn, address: null, area, lat: mLat, lng: mLng, verified: false });
  }
  return out;
}

/** OSM + curated around a point: curated wins for the same building; sorted by distance. */
export function mergeNear(
  osm: Candidate[],
  curated: CuratedMosque[],
  lat: number,
  lng: number,
  radiusM = NEAR_RADIUS_M
): NearbyMosque[] {
  const verified: Candidate[] = curated
    .filter((c) => typeof c.lat === "number" && typeof c.lng === "number" && c.id)
    .map((c) => ({
      id: c.id!,
      name: c.nameBn?.trim() || c.nameEn?.trim() || null,
      nameEn: c.nameEn?.trim() || null,
      address: c.addressBn?.trim() || null,
      area: c.area?.trim() || null,
      lat: c.lat!,
      lng: c.lng!,
      verified: true,
    }));
  const rest = osm.filter((o) => !verified.some((v) => distanceM(v.lat, v.lng, o.lat, o.lng) <= SAME_PLACE_M));
  return [...verified, ...rest]
    .map((m) => ({ ...m, distanceM: distanceM(lat, lng, m.lat, m.lng) }))
    .filter((m) => m.distanceM <= radiusM)
    .sort((a, b) => a.distanceM - b.distanceM)
    .slice(0, MAX_RESULTS);
}

/** Is the new set complete enough to replace the old one? */
export function acceptRefresh(next: OsmMosqueDataset, current: OsmMosqueDataset | null): boolean {
  if (next.count < 1000) return false; // Bangladesh has ~12,000 — a few hundred is a broken answer
  return !current || next.count >= current.count * 0.8;
}

@Injectable()
export class MosquesService implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger(MosquesService.name);
  private dataset: OsmMosqueDataset | null = null;
  private loading: Promise<void> | null = null;
  private timer: NodeJS.Timeout | null = null;
  private redis: Redis | null = null;
  private refreshing = false;

  /** Test seams. */
  fetchImpl: typeof fetch = (...args) => fetch(...args);
  storageDir = () => path.resolve(process.env.STORAGE_DIR || "./storage", "osm");

  private get mirrors(): string[] {
    const env = (process.env.OVERPASS_URLS ?? "").split(",").map((s) => s.trim()).filter(Boolean);
    return env.length ? env : DEFAULT_OVERPASS_MIRRORS;
  }

  onApplicationBootstrap() {
    if (process.env.NODE_ENV === "test" || process.env.MOSQUE_SYNC === "off") return;
    // first check a minute after start (not in the boot path), then every 6 h
    this.timer = setTimeout(() => {
      void this.refreshIfStale();
      this.timer = setInterval(() => void this.refreshIfStale(), CHECK_EVERY_MS);
      this.timer.unref?.();
    }, 60_000);
    this.timer.unref?.();
  }

  async onModuleDestroy() {
    if (this.timer) clearTimeout(this.timer);
    await this.redis?.quit().catch(() => undefined);
  }

  private async readFile(file: string): Promise<OsmMosqueDataset | null> {
    try {
      const ds = JSON.parse(await fs.readFile(file, "utf8")) as OsmMosqueDataset;
      return Array.isArray(ds.rows) ? ds : null;
    } catch {
      return null;
    }
  }

  /** The newer of the refreshed copy (STORAGE_DIR) and the shipped snapshot. */
  private async load(): Promise<void> {
    const [stored, shipped] = await Promise.all([
      this.readFile(path.join(this.storageDir(), SNAPSHOT)),
      this.readFile(path.join(contentDir(), SNAPSHOT)),
    ]);
    const pick = [stored, shipped]
      .filter((d): d is OsmMosqueDataset => d !== null)
      .sort((a, b) => +new Date(b.fetchedAt) - +new Date(a.fetchedAt))[0];
    this.dataset = pick ?? null;
  }

  private async ensureLoaded(): Promise<OsmMosqueDataset | null> {
    if (!this.dataset) {
      this.loading ??= this.load().finally(() => (this.loading = null));
      await this.loading;
    }
    return this.dataset;
  }

  /** Test seam / admin use: replace the in-memory copy. */
  setDataset(ds: OsmMosqueDataset | null) {
    this.dataset = ds;
  }

  private client(): Redis | null {
    if (this.redis) return this.redis;
    try {
      this.redis = new Redis(process.env.REDIS_URL || "redis://127.0.0.1:6380", {
        maxRetriesPerRequest: 1,
        enableOfflineQueue: false,
      });
      this.redis.on("error", () => undefined);
    } catch {
      this.redis = null;
    }
    return this.redis;
  }

  /** Fetch the country again when the copy is a week old (one instance at a time). */
  async refreshIfStale(force = false): Promise<"fresh" | "busy" | "refreshed" | "kept"> {
    const current = await this.ensureLoaded();
    const age = current ? Date.now() - +new Date(current.fetchedAt) : Infinity;
    if (!force && age < REFRESH_AFTER_MS) return "fresh";
    if (this.refreshing) return "busy";
    const lock = await this.client()
      ?.set("mosques:osm:refresh-lock", String(process.pid), "EX", 3600, "NX")
      .catch(() => "OK");
    if (lock !== "OK" && lock !== undefined) return "busy";
    this.refreshing = true;
    try {
      const next = await fetchCountry(this.fetchImpl, this.mirrors);
      if (!acceptRefresh(next, current)) {
        this.logger.warn(`mosque refresh kept the old copy: ${next.count} mosques looks incomplete`);
        return "kept";
      }
      const dir = this.storageDir();
      await fs.mkdir(dir, { recursive: true });
      const target = path.join(dir, SNAPSHOT);
      await fs.writeFile(`${target}.tmp`, JSON.stringify(next), "utf8");
      await fs.rename(`${target}.tmp`, target);
      this.dataset = next;
      this.logger.log(`mosques refreshed from OpenStreetMap: ${next.count}`);
      return "refreshed";
    } catch (e) {
      this.logger.warn(`mosque refresh failed (the old copy stays): ${e instanceof Error ? e.message : String(e)}`);
      return "kept";
    } finally {
      this.refreshing = false;
      await this.client()?.del("mosques:osm:refresh-lock").catch(() => undefined);
    }
  }

  /** GET /api/mosques/near?lat&lng */
  async near(rawLat: unknown, rawLng: unknown): Promise<NearbyResult> {
    const lat = Number(rawLat);
    const lng = Number(rawLng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
      throw new ApiError(400, "অবস্থান ঠিক নয়");
    }
    const [ds, pack] = await Promise.all([
      this.ensureLoaded(),
      loadPack("mosques").catch(() => null) as Promise<{ mosques?: CuratedMosque[] } | null>,
    ]);
    return {
      mosques: mergeNear(osmCandidates(ds, lat, lng), pack?.mosques ?? [], lat, lng),
      attribution: OSM_ATTRIBUTION,
      dataAsOf: ds?.fetchedAt ?? null,
    };
  }
}
