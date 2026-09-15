"""Erzeugt die Play-Store-Feature-Graphic (1024x500, Task F1) aus dem Logo.

Google Play verlangt fuer das Store-Listing eine Feature-Graphic im Format
1024x500 px (max. 15 MB, JPG oder PNG). Die Haupt-/Logo-Elemente muessen im
mittleren Bereich (Safe Zone) liegen, rechts/links und oben/unten bleibt Platz.

Die Graphic nutzt das zentrierte, quadratisch zugeschnittene Logo-Motiv auf
dunklem Hintergrund (#0D1117, App-Design-System) — ohne Text (Text wird von
Google in Store-Sprachen uebersetzt umgebaut bzw. ist nicht lokalisierbar).

Ausfuehren:  python3 scripts/generate_feature_graphic.py
Ergebnis:    assets/branding/feature_graphic.png (1024x500)
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "assets" / "branding" / "jumla_logo.png"
OUT = ROOT / "assets" / "branding" / "feature_graphic.png"

WIDTH, HEIGHT = 1024, 500
LOGO_SIZE = 520  # in der Safe Zone (zentriert, ~52% der Breite)
BG = (13, 17, 23)  # #0D1117 — App-Theme-Hintergrund


def main() -> None:
    im = Image.open(LOGO).convert("RGB")
    # Das Logo-Motiv vom (dunklen) Hintergrund trennen, um es sauber auf den
    # 1024x500-Canvas zu setzen — sonst entsteht ein sichtbares Quadrat-Raster.
    bg = im.getpixel((2, 2))
    bg_img = Image.new("RGB", im.size, bg)
    diff = ImageChops.difference(im, bg_img).point(lambda p: 255 if p > 25 else 0)
    bbox = diff.getbbox()
    if bbox is None:
        raise ValueError("Konnte Logo-Motiv nicht vom Hintergrund unterscheiden.")

    left, top, right, bottom = bbox
    cx, cy = (left + right) / 2, (top + bottom) / 2
    side = max(right - left, bottom - top) * 1.05  # nur wenig Rand ums Motiv
    half = side / 2
    crop_box = (
        max(0, int(cx - half)),
        max(0, int(cy - half)),
        min(im.width, int(cx + half)),
        min(im.height, int(cy + half)),
    )
    motif = im.crop(crop_box)
    motif.thumbnail((LOGO_SIZE, LOGO_SIZE), Image.LANCZOS)

    canvas = Image.new("RGB", (WIDTH, HEIGHT), BG)
    # Motiv zentriert und leicht horizontal achsensymmetrisch positionieren
    # (Safe Zone = mittlere 80% der Breite, ~80% der Hoehe).
    x = (WIDTH - motif.width) // 2
    y = (HEIGHT - motif.height) // 2
    canvas.paste(motif, (x, y))

    canvas.save(OUT, optimize=True)
    print(f"Feature-Graphic erzeugt: {OUT.relative_to(ROOT)} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()