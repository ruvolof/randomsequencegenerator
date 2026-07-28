#!/usr/bin/env python3
"""Regenerate the launcher icon sources.

The original icon was a black rounded square with the binary string 100101 in
white monospace across the middle. No vector source survives in the repo, so
this rebuilds the concept at 1024x1024 and writes the two PNGs that
flutter_launcher_icons consumes:

  assets/icon/app_icon.png             the full icon, rounded black background
  assets/icon/app_icon_foreground.png  digits only on transparent, sized to
                                       survive the adaptive icon's circular mask

Usage:  python3 tool/generate_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
TEXT = "100101"
CORNER_RADIUS = 180
BACKGROUND = (0, 0, 0, 255)
FOREGROUND = (255, 255, 255, 255)

# Fraction of the icon width the text should span. The full icon can use most
# of it; the adaptive foreground has to fit the 66% safe zone, so it stays well
# inside.
FULL_WIDTH_RATIO = 0.78
ADAPTIVE_WIDTH_RATIO = 0.60

FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = REPO_ROOT / "assets" / "icon"


def fit_font(draw, target_width):
    """Binary-search the font size whose rendered TEXT is target_width wide."""
    low, high = 1, SIZE
    best = ImageFont.truetype(FONT_PATH, 1)
    while low <= high:
        mid = (low + high) // 2
        font = ImageFont.truetype(FONT_PATH, mid)
        # textsize was removed in Pillow 10; textbbox is the replacement.
        left, _, right, _ = draw.textbbox((0, 0), TEXT, font=font)
        if right - left <= target_width:
            best = font
            low = mid + 1
        else:
            high = mid - 1
    return best


def draw_centered(draw, font):
    """Draw TEXT centred on the canvas, correcting for the glyph bbox offsets."""
    left, top, right, bottom = draw.textbbox((0, 0), TEXT, font=font)
    x = (SIZE - (right - left)) / 2 - left
    y = (SIZE - (bottom - top)) / 2 - top
    draw.text((x, y), TEXT, font=font, fill=FOREGROUND)


def build_full_icon(path):
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        [0, 0, SIZE - 1, SIZE - 1], radius=CORNER_RADIUS, fill=BACKGROUND
    )
    draw_centered(draw, fit_font(draw, SIZE * FULL_WIDTH_RATIO))
    image.save(path)


def build_adaptive_foreground(path):
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw_centered(draw, fit_font(draw, SIZE * ADAPTIVE_WIDTH_RATIO))
    image.save(path)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    build_full_icon(OUTPUT_DIR / "app_icon.png")
    build_adaptive_foreground(OUTPUT_DIR / "app_icon_foreground.png")
    print(f"wrote app_icon.png and app_icon_foreground.png to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
