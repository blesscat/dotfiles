#!/usr/bin/python3
"""Draw the agent usage page icons: three "remaining" meter bars on a dark tile.

Needs Pillow, for example:  uv run --with pillow python make-icons.py
Writes icon-192.png, icon-512.png, icon-maskable-512.png, apple-touch-icon.png and favicon.svg
next to this script.
"""
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
BACKGROUND = (23, 32, 43)
TRACK = (44, 54, 68)
BARS = [((76, 194, 126), 0.86), ((228, 172, 53), 0.52), ((240, 102, 95), 0.22)]   # colour, fill
SUPERSAMPLE = 4


def draw(size, rounded, content_scale):
    """rounded: corner radius as a fraction of size (0 = full bleed square).
    content_scale: share of the tile the bars span (smaller for maskable icons' safe zone)."""
    big = size * SUPERSAMPLE
    image = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    pen = ImageDraw.Draw(image)
    pen.rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * rounded), fill=BACKGROUND)
    width = big * content_scale
    left = (big - width) / 2
    bar_height = width * 0.17
    gap = width * 0.13
    top = (big - (3 * bar_height + 2 * gap)) / 2
    for index, (colour, fill) in enumerate(BARS):
        y = top + index * (bar_height + gap)
        radius = bar_height / 2
        pen.rounded_rectangle([left, y, left + width, y + bar_height], radius=radius, fill=TRACK)
        pen.rounded_rectangle([left, y, left + max(width * fill, bar_height), y + bar_height], radius=radius, fill=colour)
    return image.resize((size, size), Image.LANCZOS)


def svg():
    rows = []
    for index, (colour, fill) in enumerate(BARS):
        y = 31 + index * 15
        rows.append(f'<rect x="18" y="{y}" width="64" height="11" rx="5.5" fill="rgb{TRACK}"/>')
        rows.append(f'<rect x="18" y="{y}" width="{max(64 * fill, 11):.1f}" height="11" rx="5.5" fill="rgb{colour}"/>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
            f'<rect width="100" height="100" rx="22" fill="rgb{BACKGROUND}"/>' + ''.join(rows) + '</svg>\n')


def main():
    draw(192, 0.22, 0.64).save(HERE / 'icon-192.png', optimize=True)
    draw(512, 0.22, 0.64).save(HERE / 'icon-512.png', optimize=True)
    # Maskable: full bleed, content inside the central safe zone (a circle of 80% diameter).
    draw(512, 0, 0.52).save(HERE / 'icon-maskable-512.png', optimize=True)
    # iOS rounds the corners itself and shows transparency as black, so keep it full bleed.
    draw(180, 0, 0.60).convert('RGB').save(HERE / 'apple-touch-icon.png', optimize=True)
    (HERE / 'favicon.svg').write_text(svg().replace('rgb(', 'rgb('))


if __name__ == '__main__':
    main()
