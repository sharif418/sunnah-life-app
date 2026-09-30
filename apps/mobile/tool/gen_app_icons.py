"""Generate the Android + iOS launcher icons from the brand mark.

Single source: apps/web/public/icon.svg (deep-green tile + gold khatam/dome).

    python apps/mobile/tool/gen_app_icons.py      # from the repo root

Writes:
  android  mipmap-*/ic_launcher.png            legacy square icon (rounded tile)
           mipmap-*/ic_launcher_round.png      legacy round icon
           mipmap-*/ic_launcher_foreground.png adaptive foreground (emblem, safe zone)
           mipmap-*/ic_launcher_monochrome.png Android 13 themed icon
           mipmap-anydpi-v26/ic_launcher(.xml|_round.xml)
           values/ic_launcher_background.xml   the brand green
           drawable/launch_splash.png          splash emblem
  ios      Assets.xcassets/AppIcon.appiconset/*  full-bleed, no alpha

Requires PyMuPDF (SVG rasteriser) and Pillow.
"""
from __future__ import annotations

import io
import json
import re
from pathlib import Path

import pymupdf
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "apps/web/public/icon.svg"
RES = ROOT / "apps/mobile/android/app/src/main/res"
IOS = ROOT / "apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset"
GREEN = "#1F4D3D"

svg = SRC.read_text(encoding="utf-8")
# The emblem = everything after the background tile <rect ... fill="#1F4D3D"/>.
body = re.sub(r"<rect[^>]*fill=\"#1F4D3D\"\s*/>", "", svg.split(">", 1)[1].rsplit("</svg>", 1)[0], count=1)


def render(svg_text: str, px: int) -> Image.Image:
    doc = pymupdf.open(stream=svg_text.encode(), filetype="svg")
    page = doc[0]
    zoom = px / page.rect.width
    pix = page.get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), alpha=True)
    return Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGBA")


def emblem_svg(canvas: float, scale: float, color: str | None = None, bg: str | None = None) -> str:
    """Emblem (drawn in a 48-unit box, centred on 24,24) placed on a canvas."""
    b = body if color is None else re.sub(r'(fill|stroke)="#C99A3B"', rf'\1="{color}"', body)
    off = canvas / 2 - 24 * scale
    bg_rect = f'<rect width="{canvas}" height="{canvas}" fill="{bg}"/>' if bg else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {canvas} {canvas}" '
        f'width="{canvas}" height="{canvas}">{bg_rect}'
        f'<g transform="translate({off} {off}) scale({scale})">{b}</g></svg>'
    )


def rounded(img: Image.Image, radius_frac: float) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    r = int(img.size[0] * radius_frac)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], r, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def circle(img: Image.Image) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, img.size[0] - 1, img.size[1] - 1], fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


# Full-bleed tile at 1024 (square green + emblem, emblem ~62% of the tile).
full = render(emblem_svg(48, 1.25, bg=GREEN), 1024)

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for name, d in DENSITIES.items():
    folder = RES / f"mipmap-{name}"
    folder.mkdir(parents=True, exist_ok=True)
    legacy = int(48 * d)
    rounded(full, 0.22).resize((legacy, legacy), Image.LANCZOS).save(folder / "ic_launcher.png")
    circle(full).resize((legacy, legacy), Image.LANCZOS).save(folder / "ic_launcher_round.png")
    fg = int(108 * d)
    # adaptive: 108-unit canvas, safe zone = centre 66; emblem ~44 units wide
    render(emblem_svg(108, 2.1), fg).save(folder / "ic_launcher_foreground.png")
    render(emblem_svg(108, 2.1, color="#FFFFFF"), fg).save(folder / "ic_launcher_monochrome.png")

anydpi = RES / "mipmap-anydpi-v26"
anydpi.mkdir(exist_ok=True)
adaptive = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"""
(anydpi / "ic_launcher.xml").write_text(adaptive, encoding="utf-8")
(anydpi / "ic_launcher_round.xml").write_text(adaptive, encoding="utf-8")
(RES / "values/ic_launcher_background.xml").write_text(
    f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    f'    <color name="ic_launcher_background">{GREEN}</color>\n</resources>\n',
    encoding="utf-8",
)
# Splash emblem (pre-Android-12 launch_background.xml centres it on green).
render(emblem_svg(48, 1.0), 288).save(RES / "drawable/launch_splash.png")

# iOS: full-bleed square, NO alpha (App Store rejects transparency).
contents = json.loads((IOS / "Contents.json").read_text(encoding="utf-8"))
flat = Image.new("RGB", full.size, GREEN)
flat.paste(full, (0, 0), full)
for img in contents["images"]:
    size = float(img["size"].split("x")[0])
    scale = int(img["scale"].rstrip("x"))
    px = int(round(size * scale))
    flat.resize((px, px), Image.LANCZOS).save(IOS / img["filename"])

print("icons written")
