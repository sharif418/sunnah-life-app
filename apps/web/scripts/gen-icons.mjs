// One-off PWA icon generator — renders public/icon.svg to the PNG set the
// manifest/installability criteria expect (Chrome wants a 192 + 512 raster
// pair; the maskable variant keeps the mark inside the 80%-diameter safe
// circle on adaptive launcher masks).
// Run: node scripts/gen-icons.mjs   (sharp is already a dependency)
import sharp from "sharp";
import { fileURLToPath } from "url";
import path from "path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const svg = path.join(__dirname, "../public/icon.svg");

await sharp(svg).resize(192, 192).png().toFile(path.join(__dirname, "../public/icon-192.png"));
await sharp(svg).resize(512, 512).png().toFile(path.join(__dirname, "../public/icon-512.png"));

// Maskable: brand-green canvas with the mark scaled to ~70% — the gold
// khatam/dome then sits fully inside the maskable safe zone.
const mk = await sharp(svg).resize(358, 358).png().toBuffer();
await sharp({
  create: { width: 512, height: 512, channels: 4, background: "#1F4D3D" },
})
  .composite([{ input: mk, gravity: "center" }])
  .png()
  .toFile(path.join(__dirname, "../public/icon-maskable-512.png"));

console.log("icons: icon-192.png, icon-512.png, icon-maskable-512.png written");
