"""Regenerate the native SVG ballroom artwork (Python standard library only)."""
from pathlib import Path
import random

OUT = Path(__file__).resolve().parents[1] / "assets" / "floors"
OUT.mkdir(parents=True, exist_ok=True)


def floor(name, base, kind):
    rng = random.Random(14)
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1240" height="680" viewBox="0 0 1240 680">',
             '<defs><clipPath id="floor"><rect x="25" y="25" width="1190" height="630"/></clipPath>',
             '<radialGradient id="light"><stop stop-color="#fff1d0" stop-opacity=".07"/><stop offset="1" stop-color="#17120d" stop-opacity=".18"/></radialGradient></defs>',
             '<rect width="1240" height="680" fill="#463a2d"/>',
             f'<rect x="10" y="10" width="1220" height="660" fill="{base}"/>',
             '<g clip-path="url(#floor)">']

    def plank(x, y, w, h, color):
        parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}" stroke="#302218" stroke-opacity=".17" stroke-width=".8"/>')
        for _ in range(2):
            if w > h:
                gy = y + rng.uniform(2, h - 2)
                d = f'M{x+3:.1f} {gy:.1f} h{w-6}'
            else:
                gx = x + rng.uniform(2, w - 2)
                d = f'M{gx:.1f} {y+3:.1f} v{h-6}'
            parts.append(f'<path d="{d}" stroke="#eee0c0" stroke-opacity=".055" fill="none"/>')

    if kind == "oak":
        colors = ['#9b7a52', '#a17f56', '#997951', '#a38159', '#9e7e55']
        # Two perpendicular planks per lattice cell form a true herringbone tiling.
        parts.append('<g transform="translate(620 340) rotate(45)">')
        for a in range(-15, 16):
            for b in range(-65, 66):
                x, y = (a * 4 + b) * 16, (a * 4 - b) * 16
                if -800 < x < 800 and -800 < y < 800:
                    plank(x, y, 64, 16, rng.choice(colors))
                    plank(x + 64, y, 16, 64, rng.choice(colors))
        parts.append('</g>')
    elif kind == "walnut":
        colors = ['#80674f', '#856b52', '#896e55', '#816850']
        for row, y in enumerate(range(25, 700, 126)):
            for col, x in enumerate(range(25, 1250, 119)):
                for i in range(5):
                    if (row + col) % 2:
                        plank(x + i * 23.8, y, 23.8, 126, rng.choice(colors))
                    else:
                        plank(x, y + i * 25.2, 119, 25.2, rng.choice(colors))
                parts.append(f'<rect x="{x+3}" y="{y+3}" width="113" height="120" fill="none" stroke="#c1a36e" stroke-opacity=".22" stroke-width="1"/>')
    else:
        colors = ['#ad9b7d', '#b19f80', '#ab997b', '#b4a284']
        for row, y in enumerate(range(25, 700, 30)):
            for x in range(-220 + (row % 3) * 90, 1260, 270):
                plank(x, y, 270, 30, rng.choice(colors))
    parts += ['</g>', '<rect width="1240" height="680" fill="url(#light)"/>',
              '<rect x="11" y="11" width="1218" height="658" fill="none" stroke="#c0a577" stroke-opacity=".55"/>',
              '<rect x="24" y="24" width="1192" height="632" fill="none" stroke="#352b22" stroke-width="2"/>']
    if kind == "walnut":
        for x, y, angle in [(13, 13, 0), (1227, 13, 90), (1227, 667, 180), (13, 667, 270)]:
            parts.append(f'<path transform="translate({x} {y}) rotate({angle})" d="M0 50 V0 H50 M5 38 V5 H38 M0 18 L18 0" fill="none" stroke="#cab07a" stroke-width="1.2"/>')
    parts.append('</svg>')
    (OUT / name).write_text('\n'.join(parts), encoding='utf-8')


floor('classic_parquet.svg', '#775d40', 'oak')
floor('grand_ballroom.svg', '#594737', 'walnut')
floor('practice_studio.svg', '#89785f', 'maple')
