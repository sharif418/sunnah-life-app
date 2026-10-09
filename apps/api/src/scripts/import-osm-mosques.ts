// Refresh the shipped snapshot of Bangladesh's mosques (OpenStreetMap):
//   bun src/scripts/import-osm-mosques.ts              # fetch live (≈2 min)
//   bun src/scripts/import-osm-mosques.ts raw.json     # from a saved Overpass answer
// Writes packages/content/osm-mosques-bd.json — what a fresh server answers
// "mosques near me" from until its own weekly refresh (mosques.service.ts).
import { promises as fs } from "fs";
import path from "path";

import { datasetFrom, fetchCountry, type OsmElement } from "../mosques/osm-mosques";

async function main() {
  const src = process.argv[2];
  const ds = src
    ? datasetFrom((JSON.parse(await fs.readFile(src, "utf8")) as { elements: OsmElement[] }).elements)
    : await fetchCountry((...a) => fetch(...a));
  if (ds.count < 1000) throw new Error(`only ${ds.count} mosques — not writing an incomplete snapshot`);
  const out = path.resolve(__dirname, "../../../../packages/content/osm-mosques-bd.json");
  await fs.writeFile(out, `${JSON.stringify(ds)}\n`, "utf8");
  const named = ds.rows.filter((r) => r[1]).length;
  console.log(`✓ ${ds.count} mosques (${named} named) → ${out}`);
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
