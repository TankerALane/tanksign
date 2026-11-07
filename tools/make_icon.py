"""Draws the Tanksign icon with no third-party libraries.

Usage (from the repo root):  python tools/make_icon.py

Concept: an ivory skull with gold trim, a small grey shield behind it, and a thin,
mostly drained deep-red health bar below, on a near-black rounded square.

Writes:
  Tanksign/media/icon.tga          128x128, 32-bit, for the AddOns list (IconTexture)
  Tanksign/media/skull.tga         64x64 white skull on transparent, tinted in game (on/off button)
  assets/logo/png/icon-<n>.png     64, 128, 256, 512 previews for GitHub and CurseForge

Shapes are signed-distance functions sampled 4x4 per pixel for anti-aliasing.
"""
import math
import pathlib
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Palette (Tanksign/UI/Palette.lua, Plain skin) plus the icon's own ivory and red.
BG = (0.05, 0.05, 0.06)
GOLD = (1.0, 0.82, 0.0)
GREY = (0.45, 0.45, 0.5)
GREY_DARK = (0.25, 0.25, 0.28)
IVORY = (0.95, 0.93, 0.86)
SOCKET = (0.08, 0.08, 0.09)
RED = (0.62, 0.08, 0.06)
TRACK = (0.16, 0.05, 0.05)


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def rounded_box(px, py, cx, cy, hw, hh, r):
    qx = abs(px - cx) - hw + r
    qy = abs(py - cy) - hh + r
    outside = math.hypot(max(qx, 0), max(qy, 0))
    return outside + min(max(qx, qy), 0) - r


def circle(px, py, cx, cy, r):
    return math.hypot(px - cx, py - cy) - r


def ellipse(px, py, cx, cy, rx, ry):
    # Approximate distance, good enough for anti-aliased edges.
    k = math.hypot((px - cx) / rx, (py - cy) / ry)
    return (k - 1) * min(rx, ry)


def shield(px, py):
    # Upper rounded rectangle joined to a pointed lower half, centred behind the skull.
    top = rounded_box(px, py, 0.5, 0.36, 0.30, 0.16, 0.05)
    # Lower part: intersection of two big circles makes the point.
    left = circle(px, py, 0.80, 0.40, 0.48)
    right = circle(px, py, 0.20, 0.40, 0.48)
    lower = max(left, right, -(py - 0.36))
    return min(top, lower)


def skull(px, py):
    cranium = ellipse(px, py, 0.5, 0.42, 0.205, 0.19)
    jaw = rounded_box(px, py, 0.5, 0.60, 0.115, 0.075, 0.035)
    return min(cranium, jaw)


def skull_holes(px, py):
    eye_l = ellipse(px, py, 0.425, 0.45, 0.055, 0.06)
    eye_r = ellipse(px, py, 0.575, 0.45, 0.055, 0.06)
    # Nose: small upside-down triangle approximated by a narrow ellipse.
    nose = ellipse(px, py, 0.5, 0.54, 0.022, 0.032)
    # Teeth gaps: thin vertical slots in the jaw.
    gaps = min(rounded_box(px, py, 0.5 + dx, 0.635, 0.006, 0.03, 0.003) for dx in (-0.06, -0.02, 0.02, 0.06))
    return min(eye_l, eye_r, nose, gaps)


def cover(d, pixel):
    # Signed distance in unit space -> coverage for a sample of size `pixel`.
    return clamp(0.5 - d / pixel)


def blend(dst, src, a):
    return tuple(dst[i] * (1 - a) + src[i] * a for i in range(3))


def shade_icon(px, py, pixel):
    """Returns (r, g, b, a) for one sample point of the full icon."""
    tile = rounded_box(px, py, 0.5, 0.5, 0.48, 0.48, 0.12)
    a = cover(tile, pixel)
    if a <= 0:
        return (0, 0, 0, 0)
    col = BG
    # Gold trim just inside the tile edge.
    col = blend(col, GOLD, cover(abs(tile + 0.025) - 0.012, pixel))
    # Shield behind the skull: grey with a darker inner face.
    s = shield(px, py)
    col = blend(col, GREY, cover(s, pixel))
    col = blend(col, GREY_DARK, cover(s + 0.03, pixel))
    # Skull: gold outline, ivory fill, dark holes.
    k = skull(px, py)
    col = blend(col, GOLD, cover(k - 0.018, pixel))
    col = blend(col, IVORY, cover(k, pixel))
    col = blend(col, SOCKET, cover(skull_holes(px, py), pixel))
    # Health bar: gold frame, dark track, deep-red fill at about 22%.
    bar = rounded_box(px, py, 0.5, 0.82, 0.30, 0.045, 0.02)
    col = blend(col, GOLD, cover(bar - 0.012, pixel))
    col = blend(col, TRACK, cover(bar, pixel))
    fill_right = 0.2 + 0.6 * 0.22
    fill = max(bar + 0.012, px - fill_right)
    col = blend(col, RED, cover(fill, pixel))
    return (*col, a)


def shade_skull_mask(px, py, pixel):
    """White skull with holes, transparent elsewhere (tinted with SetVertexColor in game)."""
    # Re-centre the skull (it sits a little high in the icon layout) and enlarge it.
    qx = 0.5 + (px - 0.5) * 0.5
    qy = 0.5 + (py - 0.5) * 0.5 + 0.015
    k = skull(qx, qy)
    a = cover(k, pixel * 0.5) * (1 - cover(skull_holes(qx, qy), pixel * 0.5))
    return (1.0, 1.0, 1.0, a)


def render(size, shader, ss=4):
    rows = []
    pixel = 1.0 / size
    for y in range(size):
        row = []
        for x in range(size):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in range(ss):
                for sx in range(ss):
                    px = (x + (sx + 0.5) / ss) / size
                    py = (y + (sy + 0.5) / ss) / size
                    r, g, b, a = shader(px, py, pixel)
                    acc[0] += r * a
                    acc[1] += g * a
                    acc[2] += b * a
                    acc[3] += a
            n = ss * ss
            a = acc[3] / n
            if a > 0:
                rgb = [acc[i] / acc[3] for i in range(3)]
            else:
                rgb = [0.0, 0.0, 0.0]
            row.append(tuple(int(round(clamp(v) * 255)) for v in (*rgb, a)))
        rows.append(row)
    return rows


def write_tga(path, rows):
    h, w = len(rows), len(rows[0])
    # Uncompressed true-color, 32 bpp, top-left origin (descriptor bit 5) with 8 alpha bits.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x28)
    body = bytearray()
    for row in rows:
        for r, g, b, a in row:
            body += bytes((b, g, r, a))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + bytes(body))


def write_png(path, rows):
    h, w = len(rows), len(rows[0])
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for px in row:
            raw += bytes(px)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def main():
    media = ROOT / "Tanksign" / "media"
    write_tga(media / "icon.tga", render(128, shade_icon))
    write_tga(media / "skull.tga", render(64, shade_skull_mask))
    for n in (64, 128, 256, 512):
        write_png(ROOT / "assets" / "logo" / "png" / f"icon-{n}.png", render(n, shade_icon, ss=4 if n <= 256 else 2))
    write_png(ROOT / "assets" / "logo" / "png" / "skull-64.png", render(64, shade_skull_mask))
    print("Wrote Tanksign/media/icon.tga, skull.tga and assets/logo/png/icon-*.png")


if __name__ == "__main__":
    main()
