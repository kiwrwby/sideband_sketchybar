#!/usr/bin/env python3
"""Pixel art PNGs for the bar. Standard library only.

  pixel.py icons    <dir> <text> <text3> <warn> <err> <bg> <line> <accent>
  pixel.py progress <dir> <width pt> <fill colour> <track colour> [prefix]

Colours are 0xAARRGGBB. 1pt = 2px (Retina). Output names:
  port.png  ts_on.png  ts_off.png         capsule icons
  cat_<1-4>[_warn].png                    cat on grass, 33pt circle
  pilo_<state>_<n>.png  pilo_s_<state>_<n>.png   Pilo face (button / popup row)
  <prefix>_<0-100>.png                    media progress line (prefix default "prog")
"""
import os
import struct
import sys
import zlib


def rgba(h):
    v = int(h, 16)
    return ((v >> 16) & 255, (v >> 8) & 255, v & 255, (v >> 24) & 255)


def mix(a, b, t):
    """a * t + b * (1 - t), per channel."""
    return tuple(int(round(x * t + y * (1 - t))) for x, y in zip(a, b))


def write_png(path, px):
    """px: rows of (r, g, b, a) tuples or None, written 1:1."""
    h, w = len(px), len(px[0])
    raw = b"".join(b"\0" + b"".join(bytes(c if c else (0, 0, 0, 0)) for c in row) for row in px)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def write_pt(path, rows):
    """rows are in points; every point becomes 2x2 px."""
    write_png(path, [r2 for r in rows for r2 in (
        [c for c in r for _ in (0, 1)],) * 2])


def bitmap(lines, col):
    return [[col if ch == "#" else None for ch in l] for l in lines]


# ── capsule icons ─────────────────────────────────────────────────────────────
PORT = ["...........", "###########", "#.........#", "#.#.#.#.#.#", "#.........#", "#.........#",
        "#.........#", "###.....###", "..#.....#..", "..#######..", "..........."]


def dots(on, lit, dim):
    g = [[None] * 11 for _ in range(11)]
    for r in range(3):
        for c in range(3):
            col = lit if (r, c) in on else dim
            for y in range(3):
                for x in range(3):
                    g[r * 4 + y][c * 4 + x] = col
    return g


# ── cat ───────────────────────────────────────────────────────────────────────
CAT_TOP = ["...........#..#.", "#..........####.", "#..........#.##.", ".#.........####.",
           "..#############.", "..############..", "..###########..."]
CAT_LEGS = {1: [".##.........##..", "#.............#.", "................"],
            2: ["..#.#.....#.#...", "..#..#...#..#...", "................"],
            3: ["...##.....##....", "....#.....#.....", "....#.....#....."]}
CAT_LEGS[4] = CAT_LEGS[2]
GRASS = [0, 2, 1, 0, 2, 0, 1, 2, 0]   # blade height pattern, 9 cells
UP = 2                                  # grass and cat raised together by one cell


def inside(x, y):
    return (x + 0.5 - 33) ** 2 + (y + 0.5 - 33) ** 2 <= 31 ** 2


def span(i):
    """px range of cell i at 2.5px per cell (alternating 2 and 3px)."""
    return int(i * 2.5), int((i + 1) * 2.5)


def cat_frames(out, text, warn, blade):
    for k in range(1, 5):
        for suffix, col in (("", text), ("_warn", warn)):
            g = [[None] * 66 for _ in range(66)]
            for x in range(66):
                for y in range(54 - UP, 66):
                    g[y][x] = blade
                h = GRASS[(x // 2) % 9]
                if h >= 1:
                    g[52 - UP][x] = g[53 - UP][x] = blade
                if h == 2:
                    g[50 - UP][x] = g[51 - UP][x] = blade
            x_origin, y_origin = 13, 27 - UP
            for r, line in enumerate(CAT_TOP + CAT_LEGS[k]):
                for c, ch in enumerate(line):
                    if ch == "#":
                        y0, y1 = span(r)
                        x0, x1 = span(c)
                        for yy in range(y_origin + y0, y_origin + y1):
                            for xx in range(x_origin + x0, x_origin + x1):
                                g[yy][xx] = col
            write_png("%s/cat_%d%s.png" % (out, k, suffix),
                      [[g[y][x] if inside(x, y) else None for x in range(66)] for y in range(66)])


# ── Pilo face ─────────────────────────────────────────────────────────────────
BODY = ["...####...", ".########."] + ["##########"] * 6 + [".########.", "...####..."]
ARM = {"down": [(6, 2), (7, 1), (8, 1)], "mid": [(6, 2), (6, 1), (6, 0)], "up": [(5, 2), (4, 1), (3, 0)],
       "upb": [(5, 2), (4, 1), (3, 1)], "droop": [(7, 2), (8, 2), (9, 2)],
       "head": [(4, 2), (3, 2), (2, 3), (1, 4)], "headb": [(4, 2), (3, 2), (2, 3)],
       "tuck": [(7, 2), (8, 2)], None: []}
EYES = {"open": [(4, 5), (5, 5)], "shut": [(5, 4), (5, 5)], "x": [(4, 4), (4, 6), (5, 5), (6, 4), (6, 6)],
        "gt": [(4, 4), (5, 5), (6, 4)], "dot": [(5, 5)]}      # left eye; the right one is mirrored
MOUTH = {"smile": [(7, 6), (8, 7), (8, 8), (7, 9)], "o": [(8, 7), (8, 8)], "flat": [(8, 6), (8, 7), (8, 8), (8, 9)],
         "frown": [(8, 6), (7, 7), (7, 8), (8, 9)], "low": [(8, 6), (8, 7), (8, 8), (8, 9)],
         "low1": [(8, 7), (8, 8), (8, 9)], "": []}


def pilo_poses(text, text3, warn, err):
    """state -> (colour, frames); frame = (left arm, right arm, eyes, mouth, breathing)."""
    return {
        "running": (text, [("up", "down", "open", "smile", 0), ("mid", "mid", "open", "smile", 0),
                           ("down", "up", "open", "smile", 0), ("mid", "mid", "open", "smile", 0)]),
        "blocked": (warn, [("down", "up", "open", "o", 0), ("down", "upb", "open", "o", 0)]),
        "stalled": (warn, [("droop", "droop", "dot", "frown", 0), ("droop", "droop", "shut", "frown", 0)]),
        "failed": (err, [("up", "up", "x", "flat", 0), ("upb", "upb", "x", "flat", 0)]),
        "gaveUp": (err, [("head", "head", "shut", "flat", 0), ("headb", "headb", "shut", "flat", 0)]),
        "limited": (text3, [("down", "down", "gt", "low1", 0), ("down", "down", "gt", "low", 0)]),
        "idle": (text3, [("tuck", "tuck", "shut", "", 0), ("tuck", "tuck", "shut", "", 1)]),
        "unbound": (text3, [(None, None, None, "", 0)]),
    }


def pilo_cells(col, frame):
    la, ra, e, m, br = frame
    g = [[None] * 16 for _ in range(12)]
    for r, line in enumerate(BODY[1:] if br else BODY):
        for c, ch in enumerate(line):
            if ch == "#":
                g[r + 1 + br][c + 3] = col
    if e is None:   # no session: outline only
        full = [[bool(x) for x in row] for row in g]
        for r in range(12):
            for c in range(16):
                if full[r][c] and all(0 <= r + dr < 12 and 0 <= c + dc < 16 and full[r + dr][c + dc]
                                      for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    g[r][c] = None
        return g
    for r, c in EYES[e] + MOUTH[m]:
        g[r][c] = None
    for r, c in EYES[e]:
        g[r][15 - c] = None
    for r, c in ARM[la]:
        g[r][c] = col
    for r, c in ARM[ra]:
        g[r][15 - c] = col
    return g


def pilo_frames(out, text, text3, warn, err):
    for state, (col, frames) in pilo_poses(text, text3, warn, err).items():
        for k, frame in enumerate(frames):
            cells = pilo_cells(col, frame)
            g = [[None] * 66 for _ in range(66)]
            for r, row in enumerate(cells):
                for c, v in enumerate(row):
                    if v:
                        for yy in range(15 + r * 3, 18 + r * 3):
                            for xx in range(9 + c * 3, 12 + c * 3):
                                g[yy][xx] = v
            write_png("%s/pilo_%s_%d.png" % (out, state, k + 1),
                      [[g[y][x] if inside(x, y) else None for x in range(66)] for y in range(66)])
            small = [[v for v in row for _ in (0, 1)] for row in cells for _ in (0, 1)]   # 2px cells: 32x24px
            write_png("%s/pilo_s_%s_%d.png" % (out, state, k + 1), small)


# ── media progress ────────────────────────────────────────────────────────────
def progress(out, width_pt, fill, track, prefix="prog"):
    """101 images, 2pt tall, width_pt wide: filled up to N percent."""
    w = max(2, int(width_pt) * 2)
    for pct in range(101):
        edge = w * pct // 100
        row = [fill if x < edge else track for x in range(w)]
        write_png("%s/%s_%d.png" % (out, prefix, pct), [row] * 4)


def main():
    cmd, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    if cmd == "icons":
        text, text3, warn, err, bg, _line, accent = (rgba(x) for x in sys.argv[3:10])
        write_pt("%s/port.png" % out, bitmap(PORT, text))
        write_pt("%s/ts_on.png" % out, dots({(1, 0), (1, 1), (1, 2), (2, 1)}, text, text3))
        write_pt("%s/ts_off.png" % out, dots(set(), text, text3))
        cat_frames(out, text, warn, mix(accent, bg, 0.55)[:3] + (255,))
        pilo_frames(out, text, text3, warn, err)
    elif cmd == "progress":
        progress(out, float(sys.argv[3]), rgba(sys.argv[4]), rgba(sys.argv[5]),
                 sys.argv[6] if len(sys.argv) > 6 else "prog")
    else:
        sys.exit("usage: pixel.py icons|progress ...")


if __name__ == "__main__":
    main()
