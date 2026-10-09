// ─────────────────────────────────────────────────────────────────────────────
// Bangladesh's mosques from OpenStreetMap — the dataset "mosques near me" is
// answered from. One Overpass query fetches the whole country (~12,000
// mosques, ~2 minutes); it is stored compactly (~1.3 MB) and refreshed
// weekly. A snapshot ships with the content (packages/content/
// osm-mosques-bd.json) so a fresh server has data before its first refresh.
//
// The public Overpass servers are often busy (500/504/429, or an HTML error
// page with status 200), so every mirror is tried and the result is checked
// before it replaces anything.
//
// Licence: OpenStreetMap data, ODbL 1.0 — "© OpenStreetMap contributors"
// must be shown wherever the data is (the app shows it under the list).
// ─────────────────────────────────────────────────────────────────────────────

export const OSM_ATTRIBUTION = "© OpenStreetMap contributors";

/** [id, name, nameEn, lat, lng, area] — compact rows (the file is per mosque). */
export type OsmMosqueRow = [string, string | null, string | null, number, number, string | null];

export interface OsmMosqueDataset {
  source: "OpenStreetMap";
  license: string;
  fetchedAt: string;
  count: number;
  fields: ["id", "name", "nameEn", "lat", "lng", "area"];
  rows: OsmMosqueRow[];
}

export interface OsmElement {
  type: string;
  id: number;
  lat?: number;
  lon?: number;
  center?: { lat: number; lon: number };
  tags?: Record<string, string>;
}

export const DEFAULT_OVERPASS_MIRRORS = [
  "https://overpass-api.de/api/interpreter",
  "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
  "https://overpass.private.coffee/api/interpreter",
];

export const COUNTRY_QUERY =
  '[out:json][timeout:240];area["ISO3166-1"="BD"][admin_level=2]->.bd;(' +
  'node["amenity"="place_of_worship"]["religion"="muslim"](area.bd);' +
  'way["amenity"="place_of_worship"]["religion"="muslim"](area.bd);' +
  'relation["amenity"="place_of_worship"]["religion"="muslim"](area.bd);' +
  ");out center tags;";

const clean = (s: string | undefined) => (s ?? "").trim() || null;

/** "Name, Road, City" → ["Name", "Road, City"]; a plain name stays whole. */
export function splitName(raw: string | null): [string | null, string | null] {
  if (!raw) return [null, null];
  const i = raw.search(/[,،]/);
  if (i < 3) return [raw, null];
  const head = raw.slice(0, i).trim();
  const tail = raw.slice(i + 1).trim();
  return [head, tail || null];
}
const round6 = (n: number) => Math.round(n * 1e6) / 1e6;

/** One OSM element → a row (null without a position). Bengali name first. */
export function rowFromOsm(e: OsmElement): OsmMosqueRow | null {
  const lat = e.lat ?? e.center?.lat;
  const lng = e.lon ?? e.center?.lon;
  if (typeof lat !== "number" || typeof lng !== "number") return null;
  const t = e.tags ?? {};
  const bn = clean(t["name:bn"]);
  // mappers often type the address into the name ("X Jame Masjid, Port
  // Connecting Rd, Chattogram") — keep the name short, the rest is the place
  const [name, nameTail] = splitName(bn ?? clean(t.name));
  const [nameEn] = splitName(clean(t["name:en"]) ?? (bn ? clean(t.name) : null));
  const area =
    clean(t["addr:suburb"]) ??
    clean(t["addr:neighbourhood"]) ??
    nameTail ??
    clean(t["addr:city"]) ??
    clean(t["addr:district"]);
  return [`osm:${e.type[0]}${e.id}`, name, nameEn === name ? null : nameEn, round6(lat), round6(lng), area];
}

export function datasetFrom(elements: OsmElement[], fetchedAt = new Date()): OsmMosqueDataset {
  const rows = elements.map(rowFromOsm).filter((r): r is OsmMosqueRow => r !== null);
  return {
    source: "OpenStreetMap",
    license: `ODbL 1.0 — ${OSM_ATTRIBUTION}`,
    fetchedAt: fetchedAt.toISOString(),
    count: rows.length,
    fields: ["id", "name", "nameEn", "lat", "lng", "area"],
    rows,
  };
}

/** The whole country from the first mirror that answers with real data. */
export async function fetchCountry(
  fetchImpl: typeof fetch,
  mirrors: string[] = DEFAULT_OVERPASS_MIRRORS
): Promise<OsmMosqueDataset> {
  const body = new URLSearchParams({ data: COUNTRY_QUERY }).toString();
  const errors: string[] = [];
  for (const url of mirrors) {
    try {
      const res = await fetchImpl(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent": "SunnahLife/1.0 (As-Sunnah Foundation app; weekly mosque import)",
        },
        body,
        signal: AbortSignal.timeout(300_000),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const text = await res.text();
      // a busy server answers 200 with an HTML error page
      if (!text.trimStart().startsWith("{")) throw new Error("not JSON");
      const json = JSON.parse(text) as { elements?: OsmElement[] };
      return datasetFrom(json.elements ?? []);
    } catch (e) {
      errors.push(`${new URL(url).host}: ${e instanceof Error ? e.message : String(e)}`);
    }
  }
  throw new Error(`every Overpass mirror failed — ${errors.join("; ")}`);
}
