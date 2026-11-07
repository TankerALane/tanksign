"""Draws the Tanksign logos with no third-party libraries (uses tools/make_icon.py).

Usage (from the repo root):  python tools/make_logo.py

Writes:
  assets/logo/png/logo-1280x640.png   icon + TANKSIGN wordmark (GitHub social preview, README header)
  assets/logo/png/logo-square-400.png icon with TANKSIGN under it (CurseForge project avatar)

The wordmark is a small stroke font (rounded strokes, drawn as signed distances), so no font
file is needed. Colors are the icon's: ivory letters, gold underline, on the Plain background.
"""
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import make_icon as mi  # noqa: E402

ROOT = mi.ROOT


def seg(px, py, ax, ay, bx, by):
    """Distance from point to segment."""
    dx, dy = bx - ax, by - ay
    t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy or 1e-9)
    t = max(0.0, min(1.0, t))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def arc(cx, cy, rx, ry, a0, a1, n=24):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


# Glyphs in a box: x 0..width, y 0 (baseline) .. 1 (cap height), y up. Each is a list of polylines.
GLYPHS = {
    "T": (0.80, [[(0, 1), (0.8, 1)], [(0.4, 1), (0.4, 0)]]),
    "A": (0.84, [[(0, 0), (0.42, 1), (0.84, 0)], [(0.17, 0.38), (0.67, 0.38)]]),
    "N": (0.76, [[(0, 0), (0, 1), (0.76, 0), (0.76, 1)]]),
    "K": (0.74, [[(0, 0), (0, 1)], [(0.74, 1), (0.02, 0.42)], [(0.26, 0.62), (0.74, 0)]]),
    "S": (0.72, [arc(0.36, 0.75, 0.34, 0.25, 15, 270) + arc(0.36, 0.25, 0.36, 0.25, 90, -165)]),
    "I": (0.0, [[(0, 0), (0, 1)]]),
    "G": (0.80, [arc(0.42, 0.5, 0.42, 0.5, 35, 325) + [(0.84, 0.24), (0.84, 0.46), (0.48, 0.46)]]),
}
STROKE = 0.085   # half width of a stroke, in cap heights
GAP = 0.28       # space between letters


def layout(text):
    """Returns segments (in cap-height units, y up) and the total width."""
    segs, x = [], 0.0
    for ch in text:
        width, lines = GLYPHS[ch]
        for line in lines:
            for (ax, ay), (bx, by) in zip(line, line[1:]):
                segs.append((x + ax, ay, x + bx, by))
        x += width + GAP + 2 * STROKE
    return segs, x - GAP - 2 * STROKE


def render_text(canvas, segs, ox, oy, cap, color, ss=3):
    """Draw segments onto canvas (list of rows of [r,g,b]) at pixel origin ox (left), oy (baseline)."""
    h, w = len(canvas), len(canvas[0])
    pad = STROKE * cap + 2
    xs = [v for s in segs for v in (s[0], s[2])]
    x0 = int(ox + min(xs) * cap - pad)
    x1 = int(ox + max(xs) * cap + pad) + 1
    y0 = int(oy - cap - pad)
    y1 = int(oy + pad) + 1
    for y in range(max(0, y0), min(h, y1)):
        for x in range(max(0, x0), min(w, x1)):
            cover = 0.0
            for sy in range(ss):
                for sx in range(ss):
                    px = (x + (sx + 0.5) / ss - ox) / cap
                    py = (oy - (y + (sy + 0.5) / ss)) / cap
                    d = min(seg(px, py, *s) for s in segs)
                    if d <= STROKE:
                        cover += 1
            a = cover / (ss * ss)
            if a > 0:
                canvas[y][x] = [canvas[y][x][i] * (1 - a) + color[i] * a for i in range(3)]


def canvas(w, h, color):
    return [[list(color) for _ in range(w)] for _ in range(h)]


def paste(canvas_rows, rows, ox, oy):
    """Alpha-composite an RGBA image (0-255 tuples) onto the float canvas."""
    for y, row in enumerate(rows):
        for x, (r, g, b, a) in enumerate(row):
            if a == 0:
                continue
            al = a / 255
            c = canvas_rows[oy + y][ox + x]
            canvas_rows[oy + y][ox + x] = [c[0] * (1 - al) + r / 255 * al, c[1] * (1 - al) + g / 255 * al,
                                          c[2] * (1 - al) + b / 255 * al]


def rect(canvas_rows, x0, y0, x1, y1, color):
    for y in range(y0, y1):
        for x in range(x0, x1):
            canvas_rows[y][x] = list(color)


def to_rgba(canvas_rows):
    return [[tuple(int(round(mi.clamp(v) * 255)) for v in (*c, 1.0)) for c in row] for row in canvas_rows]


def wide():
    W, H = 1280, 640
    c = canvas(W, H, mi.BG)
    icon = mi.render(340, mi.shade_icon, ss=3)
    paste(c, icon, 70, 150)
    segs, width = layout("TANKSIGN")
    left, right = 460, 1210
    cap = min(150, (right - left) / width)
    ox, oy = left, int(H / 2 + cap / 2)
    render_text(c, segs, ox, oy, cap, mi.IVORY)
    rect(c, ox, oy + 40, int(ox + width * cap), oy + 48, mi.GOLD)
    return to_rgba(c)


def square():
    W = 400
    c = canvas(W, W, mi.BG)
    icon = mi.render(280, mi.shade_icon, ss=3)
    paste(c, icon, 60, 16)
    segs, width = layout("TANKSIGN")
    cap = (W - 56) / width
    ox = int((W - width * cap) / 2)
    render_text(c, segs, ox, 362, cap, mi.IVORY)
    return to_rgba(c)


def main():
    out = ROOT / "assets" / "logo" / "png"
    mi.write_png(out / "logo-1280x640.png", wide())
    mi.write_png(out / "logo-square-400.png", square())
    print("Wrote assets/logo/png/logo-1280x640.png and logo-square-400.png")


if __name__ == "__main__":
    main()
