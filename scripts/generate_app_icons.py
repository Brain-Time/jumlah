"""Erzeugt App-Icon/Logo-Assets aus assets/jumla.jpeg (Task E2).

Schneidet das Logo (Gold-Kalligraphie auf dunklem Hintergrund, passend zum
App-Design-System #0D1117) quadratisch zu und exportiert:
  - assets/branding/jumla_logo.png   (1024x1024, In-App-Nutzung z.B. Splash Screen)
  - android/app/src/main/res/mipmap-*/ic_launcher.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png
  - web/icons/Icon-*.png, web/favicon.png

Erneut ausfuehren, falls sich assets/jumla.jpeg aendert (z.B. neues Logo).
Ersetzt keine adaptiven Android-Icons (nur klassisches ic_launcher.png) —
fuer den aktuellen Bedarf ausreichend, siehe projectstatus.md Task E2.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "jumla.jpeg"
MASTER_SIZE = 1024
PADDING_FACTOR = 1.3  # 30% Rand um das eigentliche Logo-Motiv


def crop_square_logo(source: Path) -> Image.Image:
    im = Image.open(source).convert("RGB")
    bg = im.getpixel((2, 2))
    bg_img = Image.new("RGB", im.size, bg)
    diff = ImageChops.difference(im, bg_img).point(lambda p: 255 if p > 25 else 0)
    bbox = diff.getbbox()
    if bbox is None:
        raise ValueError("Konnte Logo-Motiv nicht vom Hintergrund unterscheiden.")

    left, top, right, bottom = bbox
    cx, cy = (left + right) / 2, (top + bottom) / 2
    side = max(right - left, bottom - top) * PADDING_FACTOR

    half = side / 2
    crop_box = (
        max(0, int(cx - half)),
        max(0, int(cy - half)),
        min(im.width, int(cx + half)),
        min(im.height, int(cy + half)),
    )
    square = im.crop(crop_box)
    # Falls der Ausschnitt am Bildrand nicht exakt quadratisch werden konnte,
    # auf ein Quadrat mit Hintergrundfarbe auffuellen statt zu verzerren.
    size = max(square.size)
    if square.size != (size, size):
        padded = Image.new("RGB", (size, size), bg)
        padded.paste(square, ((size - square.width) // 2, (size - square.height) // 2))
        square = padded
    return square.resize((MASTER_SIZE, MASTER_SIZE), Image.LANCZOS)


def save(im: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.resize((size, size), Image.LANCZOS).save(path)
    print(f"  {path.relative_to(ROOT)} ({size}x{size})")


def main() -> None:
    master = crop_square_logo(SOURCE)

    branding_path = ROOT / "assets" / "branding" / "jumla_logo.png"
    save(master, branding_path, MASTER_SIZE)

    print("Android mipmaps:")
    android_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for density, size in android_sizes.items():
        save(
            master,
            ROOT / "android" / "app" / "src" / "main" / "res" / f"mipmap-{density}" / "ic_launcher.png",
            size,
        )

    print("iOS AppIcon.appiconset:")
    ios_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for filename, size in ios_sizes.items():
        save(master, ios_dir / filename, size)

    print("Web:")
    web_icons = ROOT / "web" / "icons"
    save(master, web_icons / "Icon-192.png", 192)
    save(master, web_icons / "Icon-512.png", 512)
    save(master, web_icons / "Icon-maskable-192.png", 192)
    save(master, web_icons / "Icon-maskable-512.png", 512)
    save(master, ROOT / "web" / "favicon.png", 32)

    print("Fertig.")


if __name__ == "__main__":
    main()
