#!/usr/bin/env python3
"""Generate the game's tileset (R-16, R-23, D-15).

Original cartoon art in a warm, chunky, hand-painted style inspired by the *feel* of
Spelunky 2 - bold dark outlines, earthy colours, shaded rounded shapes, big-headed
characters. Nothing is copied or traced from any other game.

Usage:  python3 tools/make_tiles.py
Writes: art/tiles.png            atlas, 64x64 cells, 8 columns
        art/tiles_preview.png    every tile on a dark background, labelled
        scripts/tile_atlas.gd    name -> atlas index, used by scripts/map_view.gd
        testing.html             its built-in tile index (between TILE_ATLAS markers) is refreshed
Needs:  Pillow
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
S = 256            # paint at 4x, downsample for smooth edges
CELL = 64
COLS = 8
OUTLINE = (30, 20, 16, 255)
OW = 9             # outline thickness at 4x

TILES = []         # (name, Image)


# --------------------------------------------------------------------------- colour helpers

def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)) + (c1[3] if len(c1) > 3 else 255,)


def light(c, t):
    return mix(c, (255, 255, 255, 255), t)


def dark(c, t):
    return mix(c, (0, 0, 0, 255), t)


# --------------------------------------------------------------------------- drawing helpers

def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def _mask(kind, geom, radius=0):
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    if kind == "ellipse":
        d.ellipse(geom, fill=255)
    elif kind == "rect":
        d.rectangle(geom, fill=255)
    elif kind == "rrect":
        d.rounded_rectangle(geom, radius=radius, fill=255)
    elif kind == "poly":
        d.polygon(geom, fill=255)
    elif kind == "line":  # thick stroke: geom = (points, width)
        pts, w = geom
        d.line(pts, fill=255, width=w, joint="curve")
        for p in (pts[0], pts[-1]):
            d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=255)
    return m


def _gradient(c, bbox, top=0.25, bot=0.3):
    g = Image.new("RGBA", (S, S), c)
    gd = ImageDraw.Draw(g)
    y0, y1 = bbox[1], bbox[3]
    h = max(1, y1 - y0)
    for y in range(max(0, y0), min(S, y1 + 1)):
        t = (y - y0) / h
        col = light(c, top * (1 - t * 2)) if t < 0.5 else dark(c, bot * (t - 0.5) * 2)
        gd.line([(0, y), (S, y)], fill=col)
    return g


def shape(img, kind, geom, c, radius=0, outline=True, w=OW, top=0.25, bot=0.3, gloss=0.0):
    """Filled, shaded shape with a dark outline drawn *outside* it (cartoon style)."""
    m = _mask(kind, geom, radius)
    bbox = m.getbbox()
    if bbox is None:
        return m
    if outline:
        ring = m.filter(ImageFilter.MaxFilter(w * 2 + 1))
        img.paste(Image.new("RGBA", (S, S), OUTLINE), (0, 0), ring)
    img.paste(_gradient(c, bbox, top, bot), (0, 0), m)
    if gloss > 0:
        x0, y0, x1, y1 = bbox
        g = Image.new("L", (S, S), 0)
        ImageDraw.Draw(g).ellipse([x0 + (x1 - x0) * 0.12, y0 + (y1 - y0) * 0.08,
                                   x0 + (x1 - x0) * 0.45, y0 + (y1 - y0) * 0.35], fill=int(255 * gloss))
        g = ImageChops.multiply(g, m).filter(ImageFilter.GaussianBlur(4))
        img.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), (0, 0), g)
    return m


def stroke(img, pts, c, w, outline=True):
    return shape(img, "line", (pts, w), c, outline=outline, top=0.1, bot=0.15)


def eyes(img, cx, cy, gap=24, size=22, look=(2, 3), glow=None, angry=False):
    for sx in (-1, 1):
        x = cx + sx * gap
        if glow:
            g = Image.new("L", (S, S), 0)
            ImageDraw.Draw(g).ellipse([x - size, cy - size, x + size, cy + size], fill=150)
            img.paste(Image.new("RGBA", (S, S), glow), (0, 0), g.filter(ImageFilter.GaussianBlur(8)))
            shape(img, "ellipse", [x - size * 0.5, cy - size * 0.55, x + size * 0.5, cy + size * 0.55],
                  light(glow, 0.5), w=4)
            continue
        shape(img, "ellipse", [x - size * 0.55, cy - size * 0.7, x + size * 0.55, cy + size * 0.7],
              (250, 248, 240, 255), w=5, top=0, bot=0.1)
        px, py = x + look[0], cy + look[1]
        d = ImageDraw.Draw(img)
        d.ellipse([px - size * 0.28, py - size * 0.36, px + size * 0.28, py + size * 0.36], fill=OUTLINE)
        d.ellipse([px - size * 0.2, py - size * 0.3, px - size * 0.02, py - size * 0.1], fill=(255, 255, 255, 255))
        if angry:
            d.line([(x - size * 0.7, cy - size * 0.95 - sx * 0), (x + size * 0.7, cy - size * 0.95 + sx * 8)],
                   fill=OUTLINE, width=7) if sx < 0 else \
                d.line([(x - size * 0.7, cy - size * 0.95 + 8), (x + size * 0.7, cy - size * 0.95)], fill=OUTLINE, width=7)


def resized(img, f):
    """Scale a finished figure about its bottom centre. f <= 1, so nothing is cropped."""
    f = min(f, 1.0)
    n = int(S * f)
    out = canvas()
    out.alpha_composite(img.resize((n, n), Image.LANCZOS), ((S - n) // 2, S - n))
    return out


def add(name, img):
    TILES.append((name, img.resize((CELL, CELL), Image.LANCZOS)))


# --------------------------------------------------------------------------- terrain

THEMES = {
    #           wall base   stone light   floor        accent
    "cellars": ("8f5c33", "c08850", "5f4430", "3d2a1c"),
    "warrens": ("6b6f35", "98a050", "4b4a2b", "2f2e18"),
    "caverns": ("50708c", "86a6c2", "33465a", "1f2c3a"),
    "crypts": ("b9ad8f", "e4dac0", "625d55", "3d3a35"),
    "forge": ("3e2a28", "6a4a42", "433030", "ff7a26"),
    "throne": ("62487f", "9a7cc0", "3a2d50", "e8c170"),
}
BRICK = {"crypts", "throne"}


def rock_texture(img, rnd, base, stone, region, density=70, outlined=6):
    x0, y0, x1, y1 = region
    d = ImageDraw.Draw(img)
    for _ in range(density):  # soft mottling
        r = rnd.randint(6, 22)
        x, y = rnd.randint(x0 - 10, x1 + 10), rnd.randint(y0 - 10, y1 + 10)
        col = light(base, rnd.uniform(0.03, 0.12)) if rnd.random() < 0.5 else dark(base, rnd.uniform(0.05, 0.18))
        d.ellipse([x - r, y - r * 0.8, x + r, y + r * 0.8], fill=col)
    for _ in range(outlined):  # chunky embedded stones
        r = rnd.randint(14, 30)
        x, y = rnd.randint(x0 + r, x1 - r), rnd.randint(y0 + r, y1 - r)
        shape(img, "ellipse", [x - r, y - r * 0.75, x + r, y + r * 0.75], mix(stone, base, rnd.uniform(0, 0.4)),
              w=5, top=0.35, bot=0.35)


def bricks(img, rnd, base, region, rows=4):
    x0, y0, x1, y1 = region
    h = (y1 - y0) / rows
    for r in range(rows):
        off = 0 if r % 2 == 0 else -h
        x = x0 + off
        while x < x1:
            w = h * 2 * rnd.uniform(0.9, 1.1)
            col = mix(base, light(base, 0.2), rnd.random()) if rnd.random() < 0.5 else dark(base, rnd.uniform(0, 0.15))
            shape(img, "rrect", [x + 4, y0 + r * h + 4, x + w - 4, y0 + (r + 1) * h - 4], col, radius=10, w=5)
            x += w


def wall_top(key, seed):
    base, stone, floor, accent = (C(v) for v in THEMES[key])
    rnd = random.Random(seed)
    img = Image.new("RGBA", (S, S), base)
    if key in BRICK:
        bricks(img, rnd, base, (0, 0, S, S), rows=4)
    else:
        rock_texture(img, rnd, base, stone, (0, 0, S, S), density=90, outlined=4)
    if key == "forge":
        _cracks(img, rnd, accent)
    if key == "warrens":
        _roots(img, rnd)
    # soft top light, darker bottom so stacked walls read as a mass
    ov = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    for y in range(S):
        a = int(40 * (y / S))
        od.line([(0, y), (S, y)], fill=(0, 0, 0, a))
    img.alpha_composite(ov)
    return img


def wall_face(key, seed):
    """Wall seen from above with its front face showing (floor below it)."""
    base, stone, floor, accent = (C(v) for v in THEMES[key])
    rnd = random.Random(seed + 7)
    img = wall_top(key, seed)
    top_h = int(S * 0.42)
    face = dark(base, 0.28)
    d = ImageDraw.Draw(img)
    d.rectangle([0, top_h, S, S], fill=face)
    if key in BRICK:
        bricks(img, rnd, dark(base, 0.2), (0, top_h + 6, S, S - 10), rows=3)
    else:
        rock_texture(img, rnd, face, dark(stone, 0.25), (0, top_h + 10, S, S - 10), density=40, outlined=3)
        for _ in range(5):  # vertical streaks
            x = rnd.randint(10, S - 10)
            d.line([(x, top_h + 14), (x + rnd.randint(-6, 6), S - rnd.randint(20, 60))], fill=dark(face, 0.3), width=5)
    if key == "forge":
        _cracks(img, rnd, accent, region=(0, top_h, S, S))
    # rim highlight + outline where top meets face, and a dark foot
    d = ImageDraw.Draw(img)
    d.rectangle([0, top_h - 12, S, top_h - 2], fill=light(base, 0.18))
    d.rectangle([0, top_h - 2, S, top_h + 6], fill=OUTLINE)
    d.rectangle([0, S - 12, S, S], fill=dark(face, 0.45))
    return img


def _cracks(img, rnd, glow, region=(0, 0, S, S)):
    x0, y0, x1, y1 = region
    gl = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(gl)
    d = ImageDraw.Draw(img)
    for _ in range(2):
        x, y = rnd.randint(x0, x1), rnd.randint(y0, y1)
        pts = [(x, y)]
        for _ in range(5):
            x += rnd.randint(-40, 40)
            y += rnd.randint(-40, 40)
            pts.append((x, y))
        gd.line(pts, fill=255, width=22)
        d.line(pts, fill=light(glow, 0.3), width=7)
    img.paste(Image.new("RGBA", (S, S), glow[:3] + (255,)), (0, 0), gl.filter(ImageFilter.GaussianBlur(10)).point(lambda v: v // 2))
    for p in range(0, 1):
        pass


def _roots(img, rnd):
    d = ImageDraw.Draw(img)
    for _ in range(2):
        x = rnd.randint(20, S - 20)
        pts = [(x, 0)]
        y = 0
        while y < S:
            y += rnd.randint(30, 60)
            x += rnd.randint(-25, 25)
            pts.append((x, y))
        d.line(pts, fill=C("3c2a16"), width=10, joint="curve")
        d.line(pts, fill=C("6a4a28"), width=4, joint="curve")


def floor(key, seed):
    base, stone, fl, accent = (C(v) for v in THEMES[key])
    rnd = random.Random(seed)
    img = Image.new("RGBA", (S, S), fl)
    d = ImageDraw.Draw(img)
    for _ in range(140):  # speckle
        r = rnd.randint(2, 7)
        x, y = rnd.randint(0, S), rnd.randint(0, S)
        col = light(fl, rnd.uniform(0.04, 0.12)) if rnd.random() < 0.5 else dark(fl, rnd.uniform(0.05, 0.16))
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)
    if key in ("crypts", "throne"):  # flagstones
        for (a, b, c2, e) in [(4, 4, 124, 124), (132, 4, 252, 124), (4, 132, 124, 252), (132, 132, 252, 252)]:
            off = rnd.randint(-6, 6)
            shape(img, "rrect", [a + 6 + off, b + 6, c2 - 6 + off, e - 6], mix(fl, light(fl, 0.15), rnd.random()),
                  radius=12, w=4, top=0.12, bot=0.12)
        if key == "throne" and seed % 2 == 0:
            d.rectangle([90, 0, 166, S], fill=dark(C("8a2030"), 0.2))  # carpet runner
            d.line([(96, 0), (96, S)], fill=C("e8c170"), width=4)
            d.line([(160, 0), (160, S)], fill=C("e8c170"), width=4)
    else:
        for _ in range(rnd.randint(3, 5)):  # pebbles
            r = rnd.randint(8, 16)
            x, y = rnd.randint(20, S - 20), rnd.randint(20, S - 20)
            shape(img, "ellipse", [x - r, y - r * 0.7, x + r, y + r * 0.7], mix(stone, fl, 0.55), w=4, top=0.3, bot=0.3)
        for _ in range(2):  # hairline cracks
            x, y = rnd.randint(0, S), rnd.randint(0, S)
            pts = [(x, y)]
            for _ in range(3):
                x += rnd.randint(-30, 30)
                y += rnd.randint(-30, 30)
                pts.append((x, y))
            d.line(pts, fill=dark(fl, 0.3), width=3)
    if key == "forge":
        for _ in range(6):
            x, y = rnd.randint(10, S - 10), rnd.randint(10, S - 10)
            d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=C("ff9a3a"))
    return img


def water():
    rnd = random.Random(3)
    img = Image.new("RGBA", (S, S), C("2b6aa8"))
    d = ImageDraw.Draw(img)
    for y in range(S):
        d.line([(0, y), (S, y)], fill=mix(C("3a86c8"), C("1f4f86"), y / S))
    for _ in range(26):
        r = rnd.randint(10, 26)
        x, y = rnd.randint(0, S), rnd.randint(0, S)
        d.ellipse([x - r, y - r * 0.5, x + r, y + r * 0.5], fill=mix(C("3a86c8"), C("1f4f86"), rnd.random()))
    for _ in range(9):
        x, y = rnd.randint(0, S - 50), rnd.randint(10, S - 20)
        d.arc([x, y, x + 56, y + 24], 200, 340, fill=OUTLINE[:3] + (90,), width=9)
        d.arc([x, y - 3, x + 56, y + 21], 200, 340, fill=C("bfe6ff"), width=5)
    return img


def lava():
    rnd = random.Random(5)
    img = Image.new("RGBA", (S, S), C("c2381a"))
    d = ImageDraw.Draw(img)
    for y in range(S):
        d.line([(0, y), (S, y)], fill=mix(C("e8521f"), C("a12a12"), y / S))
    for _ in range(9):
        r = rnd.randint(12, 30)
        x, y = rnd.randint(0, S), rnd.randint(0, S)
        shape(img, "ellipse", [x - r, y - r * 0.7, x + r, y + r * 0.7], C("ffb43a"), outline=False, top=0.4, bot=0.1)
    for _ in range(4):
        r = rnd.randint(14, 26)
        x, y = rnd.randint(0, S), rnd.randint(0, S)
        shape(img, "ellipse", [x - r, y - r * 0.6, x + r, y + r * 0.6], C("3b1e18"), w=5)
    return img


def stairs(sealed=False):
    img = canvas()
    shape(img, "rrect", [22, 28, 234, 236], C("7a4a26"), radius=18, w=OW)          # wooden frame
    for x in range(40, 230, 38):                                                    # planks
        ImageDraw.Draw(img).line([(x, 34), (x, 230)], fill=C("5a3518"), width=4)
    shape(img, "rrect", [54, 60, 202, 210], C("120c0e"), radius=14, w=6, top=0, bot=0)  # pit
    d = ImageDraw.Draw(img)
    for x in (88, 168):                                                              # ladder rails
        d.rectangle([x - 6, 66, x + 6, 210], fill=C("8a5a2e"))
    for y in range(80, 205, 30):                                                     # rungs fade into dark
        a = max(60, 255 - (y - 80) * 2)
        d.rectangle([82, y, 174, y + 9], fill=C("a8723c", a))
    if sealed:
        for x in range(64, 200, 26):
            stroke(img, [(x, 50), (x, 214)], C("8a8f98"), 10)
        stroke(img, [(44, 100), (212, 100)], C("8a8f98"), 10)
        stroke(img, [(44, 168), (212, 168)], C("8a8f98"), 10)
        g = Image.new("L", (S, S), 0)
        ImageDraw.Draw(g).ellipse([96, 100, 160, 170], fill=170)
        img.paste(Image.new("RGBA", (S, S), C("ff3a3a")), (0, 0), g.filter(ImageFilter.GaussianBlur(12)))
        shape(img, "rrect", [108, 124, 148, 160], C("c8a040"), radius=6, w=6)      # padlock
        d = ImageDraw.Draw(img)
        d.arc([112, 104, 144, 136], 180, 360, fill=OUTLINE, width=9)
    return img


# --------------------------------------------------------------------------- items

def potion(col, sparkle=False):
    img = canvas()
    shape(img, "ellipse", [70, 96, 186, 212], C(col), gloss=0.7)
    shape(img, "rrect", [106, 56, 150, 104], C("cfe6ef"), radius=8, w=7, gloss=0.4)
    shape(img, "rrect", [100, 40, 156, 66], C("9a6a3a"), radius=8, w=7)
    if sparkle:
        d = ImageDraw.Draw(img)
        for (x, y, r) in [(196, 70, 14), (60, 80, 10), (188, 150, 8)]:
            d.polygon([(x, y - r), (x + r * 0.3, y - r * 0.3), (x + r, y), (x + r * 0.3, y + r * 0.3),
                       (x, y + r), (x - r * 0.3, y + r * 0.3), (x - r, y), (x - r * 0.3, y - r * 0.3)], fill=C("fff3b0"))
    return img


def gold():
    img = canvas()
    rnd = random.Random(11)
    spots = [(78, 190), (128, 196), (178, 190), (100, 160), (154, 160), (128, 128)]
    for x, y in spots:
        r = rnd.randint(26, 32)
        shape(img, "ellipse", [x - r, y - r * 0.75, x + r, y + r * 0.75], C("f2c23a"), w=7, gloss=0.6)
    d = ImageDraw.Draw(img)
    d.polygon([(190, 96), (196, 112), (212, 118), (196, 124), (190, 140), (184, 124), (168, 118), (184, 112)], fill=C("fffbe0"))
    return img


def sword_icon():
    img = canvas()
    shape(img, "poly", [(160, 40), (186, 46), (112, 170), (96, 158)], C("d8dee6"), w=7, gloss=0.5)
    stroke(img, [(70, 140), (140, 196)], C("e0b040"), 18)
    stroke(img, [(96, 176), (62, 214)], C("7a4a26"), 20)
    shape(img, "ellipse", [44, 204, 72, 232], C("e0b040"), w=6)
    return img


def armor_icon():
    img = canvas()
    shape(img, "poly", [(64, 64), (102, 50), (128, 70), (154, 50), (192, 64), (200, 120), (176, 210),
                        (128, 226), (80, 210), (56, 120)], C("9aa8b8"), w=OW, gloss=0.5)
    d = ImageDraw.Draw(img)
    d.line([(128, 76), (128, 214)], fill=dark(C("9aa8b8"), 0.35), width=6)
    shape(img, "ellipse", [110, 110, 146, 146], C("e8c170"), w=6)
    return img


# --------------------------------------------------------------------------- sanctuaries (R-27)

def secret_door():
    """Arched wooden door set in a stone frame, warm light leaking round the edges."""
    img = canvas()
    g = Image.new("L", (S, S), 0)
    ImageDraw.Draw(g).rounded_rectangle([30, 20, 226, 250], radius=90, fill=150)
    img.paste(Image.new("RGBA", (S, S), C("ffd27a")), (0, 0), g.filter(ImageFilter.GaussianBlur(14)))
    shape(img, "rrect", [40, 26, 216, 250], C("8a8378"), radius=88, w=OW)              # stone arch
    shape(img, "rrect", [62, 50, 194, 250], C("7a4a26"), radius=66, w=7, gloss=0.2)     # door leaf
    d = ImageDraw.Draw(img)
    for x in (95, 128, 161):                                                           # planks
        d.line([(x, 60), (x, 246)], fill=C("5a3518"), width=5)
    for y in (104, 196):                                                               # iron bands
        d.rectangle([66, y, 190, y + 12], fill=C("3a3a42"))
    shape(img, "ellipse", [158, 150, 180, 172], C("e8c170"), w=5, gloss=0.6)          # ring handle
    return img


def chest():
    img = canvas()
    shape(img, "rrect", [40, 116, 216, 222], C("8a4f22"), radius=12, w=OW, gloss=0.2)   # body
    shape(img, "rrect", [40, 66, 216, 128], C("a0602a"), radius=40, w=OW, gloss=0.4)    # lid
    d = ImageDraw.Draw(img)
    for x in (70, 186):                                                                # gold bands
        d.rectangle([x - 8, 70, x + 8, 220], fill=C("e0b040"))
    d.rectangle([44, 124, 212, 134], fill=C("e0b040"))
    shape(img, "rrect", [112, 118, 144, 156], C("f2c23a"), radius=6, w=6, gloss=0.5)   # lock
    for x, y in [(96, 58), (140, 48), (176, 60)]:                                       # coins peeking out
        shape(img, "ellipse", [x - 18, y - 12, x + 18, y + 12], C("f2c23a"), w=5, gloss=0.6)
    d = ImageDraw.Draw(img)
    d.polygon([(206, 30), (212, 46), (228, 52), (212, 58), (206, 74), (200, 58), (184, 52), (200, 46)], fill=C("fffbe0"))
    return img


def fountain():
    img = canvas()
    g = Image.new("L", (S, S), 0)
    ImageDraw.Draw(g).ellipse([20, 40, 236, 250], fill=140)
    img.paste(Image.new("RGBA", (S, S), C("9fe8ff")), (0, 0), g.filter(ImageFilter.GaussianBlur(18)))
    shape(img, "ellipse", [34, 150, 222, 236], C("a8a196"), w=OW)                    # basin rim
    shape(img, "ellipse", [54, 162, 202, 222], C("4fb6e8"), w=5, top=0.4, bot=0.1)   # water
    shape(img, "rrect", [110, 92, 146, 190], C("bdb6a8"), radius=10, w=7)            # pillar
    shape(img, "ellipse", [84, 78, 172, 112], C("a8a196"), w=7)                      # top bowl
    d = ImageDraw.Draw(img)
    for x0, x1 in [(100, 70), (156, 186)]:                                             # water arcs
        d.line([(128, 70), ((x0 + x1) // 2, 54), (x1, 160)], fill=C("bff0ff"), width=8, joint="curve")
    shape(img, "ellipse", [112, 40, 144, 76], C("9fe8ff"), w=5, gloss=0.8)           # spout
    for (x, y, r) in [(60, 80, 12), (200, 96, 10), (186, 40, 8)]:                      # sparkles
        d.polygon([(x, y - r), (x + r * 0.3, y - r * 0.3), (x + r, y), (x + r * 0.3, y + r * 0.3),
                   (x, y + r), (x - r * 0.3, y + r * 0.3), (x - r, y), (x - r * 0.3, y - r * 0.3)], fill=C("fff3b0"))
    return img


# --------------------------------------------------------------------------- characters

def feet(img, col, y=212, spread=26):
    for sx in (-1, 1):
        x = 128 + sx * spread
        shape(img, "ellipse", [x - 22, y, x + 22, y + 26], col, w=7)


def body(img, col, box=(84, 136, 172, 216), radius=26):
    shape(img, "rrect", list(box), col, radius=radius, w=OW, gloss=0.25)


def arms(img, col, hand, y=150, out=0):
    for sx in (-1, 1):
        x = 128 + sx * (52 + out)
        shape(img, "ellipse", [x - 18, y, x + 18, y + 52], col, w=7)
        shape(img, "ellipse", [x - 14, y + 40, x + 14, y + 66], hand, w=6)


def head(img, skin, c=(128, 96), r=58):
    shape(img, "ellipse", [c[0] - r, c[1] - r, c[0] + r, c[1] + r], skin, w=OW, gloss=0.35)


def mouth(img, cx=128, cy=126, kind="smile"):
    d = ImageDraw.Draw(img)
    if kind == "smile":
        d.arc([cx - 16, cy - 14, cx + 16, cy + 8], 20, 160, fill=OUTLINE, width=6)
    elif kind == "grim":
        d.line([(cx - 14, cy), (cx + 14, cy)], fill=OUTLINE, width=6)
    elif kind == "fangs":
        d.line([(cx - 20, cy), (cx + 20, cy)], fill=OUTLINE, width=6)
        for x in (cx - 12, cx + 6):
            d.polygon([(x, cy), (x + 7, cy), (x + 3, cy + 12)], fill=(250, 248, 240, 255))
    elif kind == "teeth":
        shape(img, "rrect", [cx - 22, cy - 6, cx + 22, cy + 12], C("2a1414"), radius=6, w=5)
        for x in range(cx - 18, cx + 16, 9):
            d.rectangle([x, cy - 4, x + 6, cy + 2], fill=(240, 236, 220, 255))


def sword(img, x=190, y=196, ang=-55, length=110, col="d8dee6"):
    a = math.radians(ang)
    tip = (x + math.cos(a) * length, y + math.sin(a) * length)
    stroke(img, [(x, y), tip], C(col), 16)
    stroke(img, [(x - 18 * math.sin(a), y + 18 * math.cos(a)), (x + 18 * math.sin(a), y - 18 * math.cos(a))], C("e0b040"), 12)


def axe(img, x=192, y=200):
    stroke(img, [(x, y + 20), (x + 8, y - 110)], C("7a4a26"), 14)
    shape(img, "poly", [(x + 4, y - 108), (x + 50, y - 128), (x + 56, y - 70), (x + 6, y - 78)], C("b8c0c8"), w=7, gloss=0.5)


def club(img, x=190, y=204):
    stroke(img, [(x, y + 10), (x + 22, y - 96)], C("8a5a2e"), 20)
    shape(img, "ellipse", [x - 4, y - 140, x + 52, y - 70], C("9a6634"), w=7)


def bow(img, x=60, y=170):
    d = ImageDraw.Draw(img)
    d.arc([x - 40, y - 86, x + 34, y + 70], 100, 260, fill=OUTLINE, width=18)
    d.arc([x - 40, y - 86, x + 34, y + 70], 100, 260, fill=C("9a6634"), width=9)
    d.line([(x - 4, y - 80), (x - 4, y + 64)], fill=C("e8e0c8"), width=3)


def staff(img, orb, x=192, y=214):
    stroke(img, [(x, y), (x + 6, y - 150)], C("7a4a26"), 13)
    g = Image.new("L", (S, S), 0)
    ImageDraw.Draw(g).ellipse([x - 30, y - 196, x + 42, y - 124], fill=160)
    img.paste(Image.new("RGBA", (S, S), C(orb)), (0, 0), g.filter(ImageFilter.GaussianBlur(10)))
    shape(img, "ellipse", [x - 16, y - 180, x + 28, y - 136], light(C(orb), 0.3), w=6, gloss=0.8)


def dagger(img, x=190, y=196):
    stroke(img, [(x, y), (x + 30, y - 50)], C("d8dee6"), 11)
    stroke(img, [(x - 10, y - 6), (x + 10, y + 6)], C("7a4a26"), 10)


def mace(img, x=190, y=204):
    stroke(img, [(x, y), (x + 14, y - 90)], C("7a4a26"), 12)
    shape(img, "ellipse", [x - 8, y - 128, x + 38, y - 82], C("c8ccd4"), w=7, gloss=0.5)


def shield(img, col="3c6ec0", x=64, y=178):
    shape(img, "ellipse", [x - 40, y - 44, x + 40, y + 44], C(col), w=OW, gloss=0.4)
    shape(img, "ellipse", [x - 14, y - 14, x + 14, y + 14], C("e0b040"), w=6)


def pointy_ears(img, col, y=96, size=40):
    for sx in (-1, 1):
        x = 128 + sx * 52
        shape(img, "poly", [(x, y - 14), (x + sx * size * 1.3, y - size * 0.6), (x, y + 16)], col, w=7)


def hood(img, col, face_skin, c=(128, 96), r=62, face_r=40):
    shape(img, "poly", [(c[0] - r - 6, c[1] + 40), (c[0] - r, c[1] - 20), (c[0], c[1] - r - 22),
                        (c[0] + r, c[1] - 20), (c[0] + r + 6, c[1] + 40)], col, w=OW, gloss=0.25)
    shape(img, "ellipse", [c[0] - face_r, c[1] - face_r + 8, c[0] + face_r, c[1] + face_r + 8], face_skin, w=6)


def helmet(img, col="aab4c0", spike=False, horns=False):
    shape(img, "poly", [(66, 98), (72, 56), (100, 34), (128, 28), (156, 34), (184, 56), (190, 98)], C(col), w=OW, gloss=0.5)
    stroke(img, [(128, 70), (128, 118)], C(col), 12)
    if spike:
        shape(img, "poly", [(118, 34), (128, 4), (138, 34)], C(col), w=6)
    if horns:
        for sx in (-1, 1):
            shape(img, "poly", [(128 + sx * 56, 60), (128 + sx * 104, 24), (128 + sx * 92, 4), (128 + sx * 86, 30), (128 + sx * 60, 46)],
                  C("efe4c8"), w=7)


def crown(img, y=46):
    shape(img, "poly", [(76, y + 20), (80, y - 16), (102, y + 4), (128, y - 26), (154, y + 4), (176, y - 16), (180, y + 20)],
          C("f0c43a"), w=7, gloss=0.6)
    for x in (102, 128, 154):
        shape(img, "ellipse", [x - 7, y + 4, x + 7, y + 18], C("d02a4a"), w=4)


def wizard_hat(img):
    shape(img, "poly", [(58, 66), (128, -6), (198, 66)], C("3a54b8"), w=OW, gloss=0.3)
    shape(img, "ellipse", [44, 50, 212, 84], C("2e4498"), w=OW)
    d = ImageDraw.Draw(img)
    x, y, r = 134, 30, 12
    d.polygon([(x, y - r), (x + r * 0.3, y - r * 0.3), (x + r, y), (x + r * 0.3, y + r * 0.3), (x, y + r),
               (x - r * 0.3, y + r * 0.3), (x - r, y), (x - r * 0.3, y - r * 0.3)], fill=C("ffe27a"))


def wild_hair(img, col):
    pts = []
    for i in range(13):
        a = math.pi * (1.05 + i / 12 * 0.9)
        r = 78 if i % 2 == 0 else 56
        pts.append((128 + math.cos(a) * r, 92 + math.sin(a) * r))
    pts += [(186, 120), (70, 120)]
    shape(img, "poly", pts, C(col), w=OW, gloss=0.3)


def skull_head(img, c=(128, 94), r=56, eye_glow=None):
    shape(img, "ellipse", [c[0] - r, c[1] - r, c[0] + r, c[1] + r * 0.9], C("efe9d6"), w=OW, gloss=0.4)
    shape(img, "rrect", [c[0] - 30, c[1] + 30, c[0] + 30, c[1] + 60], C("e2dbc4"), radius=10, w=7)
    d = ImageDraw.Draw(img)
    for sx in (-1, 1):
        x = c[0] + sx * 22
        d.ellipse([x - 16, c[1] - 12, x + 16, c[1] + 18], fill=C("1a1214"))
        if eye_glow:
            g = Image.new("L", (S, S), 0)
            ImageDraw.Draw(g).ellipse([x - 16, c[1] - 12, x + 16, c[1] + 18], fill=255)
            img.paste(Image.new("RGBA", (S, S), C(eye_glow)), (0, 0), g.filter(ImageFilter.GaussianBlur(6)))
            d.ellipse([x - 5, c[1] - 1, x + 5, c[1] + 9], fill=light(C(eye_glow), 0.6))
    d.polygon([(c[0] - 6, c[1] + 24), (c[0] + 6, c[1] + 24), (c[0], c[1] + 12)], fill=C("1a1214"))
    for x in range(c[0] - 22, c[0] + 22, 11):
        d.line([(x, c[1] + 36), (x, c[1] + 56)], fill=C("8a8270"), width=3)


def ribcage(img, col="e8e1cc"):
    shape(img, "rrect", [96, 140, 160, 206], C("2a2024"), radius=18, w=7, top=0, bot=0)
    d = ImageDraw.Draw(img)
    d.line([(128, 142), (128, 204)], fill=C(col), width=10)
    for y in range(150, 200, 14):
        d.arc([100, y - 10, 156, y + 14], 200, 340, fill=C(col), width=8)
    for sx in (-1, 1):
        stroke(img, [(128 + sx * 30, 150), (128 + sx * 54, 196)], C(col), 12)
        stroke(img, [(128 + sx * 18, 206), (128 + sx * 24, 234)], C(col), 12)


# heroes ---------------------------------------------------------------------------

SKIN = C("f0c69a")


def hero(cls):
    img = canvas()
    if cls == "fighter":
        feet(img, C("5a3a22")); arms(img, C("3c6ec0"), SKIN); body(img, C("3c6ec0"))
        shape(img, "rrect", [92, 172, 164, 186], C("7a4a26"), radius=4, w=5)
        head(img, SKIN); eyes(img, 128, 102); mouth(img, cy=128, kind="grim"); helmet(img)
        shield(img); sword(img)
    elif cls == "rogue":
        feet(img, C("2a2a30")); arms(img, C("3a3a46"), SKIN); body(img, C("3a3a46"))
        hood(img, C("2c2c36"), SKIN); eyes(img, 128, 102, gap=18, size=18)
        shape(img, "rrect", [94, 112, 162, 138], C("1f1f26"), radius=10, w=5)   # mask
        dagger(img); dagger(img, x=66, y=196)
    elif cls == "barbarian":
        feet(img, C("5a3a22")); arms(img, SKIN, SKIN, out=4)
        body(img, SKIN); shape(img, "rrect", [84, 176, 172, 216], C("8a5a2e"), radius=14, w=7)  # fur kilt
        wild_hair(img, "d8642a"); head(img, SKIN, r=54); eyes(img, 128, 100, angry=True); mouth(img, cy=128, kind="grim")
        axe(img)
    elif cls == "ranger":
        feet(img, C("5a3a22")); arms(img, C("4a6a2e"), SKIN); body(img, C("6a4a2a"))
        hood(img, C("3e6a2e"), SKIN); eyes(img, 128, 102, gap=18, size=18); mouth(img, cy=130)
        bow(img)
    elif cls == "wizard":
        feet(img, C("2e3c78")); arms(img, C("3a54b8"), SKIN); body(img, C("3a54b8"), box=(80, 136, 176, 226))
        head(img, SKIN); eyes(img, 128, 104); shape(img, "poly", [(98, 120), (158, 120), (128, 176)], C("eeeeee"), w=6)  # beard
        wizard_hat(img); staff(img, "6ad0ff")
    elif cls == "cleric":
        feet(img, C("8a6a3a")); arms(img, C("f2ede0"), SKIN); body(img, C("f2ede0"), box=(80, 136, 176, 226))
        shape(img, "ellipse", [110, 156, 146, 192], C("e8c170"), w=6, gloss=0.5)   # sun emblem
        head(img, SKIN); eyes(img, 128, 102); mouth(img, cy=128)
        shape(img, "rrect", [84, 40, 172, 70], C("e8c170"), radius=10, w=7)       # circlet
        mace(img)
    return img


# monsters -------------------------------------------------------------------------

def quadruped(col, kind):
    img = canvas()
    belly = light(C(col), 0.25)
    if kind == "rat":
        d = ImageDraw.Draw(img)
        d.arc([10, 120, 120, 236], 90, 250, fill=OUTLINE, width=16)
        d.arc([10, 120, 120, 236], 90, 250, fill=C("e8a0a0"), width=8)
    for x in (80, 110, 160, 190):
        shape(img, "rrect", [x - 12, 186, x + 12, 232], dark(C(col), 0.15), radius=10, w=7)
    shape(img, "ellipse", [56, 120, 210, 212], C(col), w=OW, gloss=0.3)
    shape(img, "ellipse", [84, 176, 180, 208], belly, outline=False)
    hx, hy = 188, 128
    if kind == "wolf":
        for sx in (-1, 1):
            shape(img, "poly", [(hx + sx * 22, hy - 30), (hx + sx * 30, hy - 78), (hx + sx * 2, hy - 46)], C(col), w=7)
        stroke(img, [(60, 150), (14, 112)], C(col), 26)
    if kind == "rat":
        for sx in (-1, 1):
            shape(img, "ellipse", [hx + sx * 26 - 20, hy - 66, hx + sx * 26 + 20, hy - 26], C("e8a0a0"), w=7)
    shape(img, "ellipse", [hx - 46, hy - 46, hx + 46, hy + 40], C(col), w=OW, gloss=0.3)
    shape(img, "ellipse", [hx + 10, hy - 4, hx + 66, hy + 34], light(C(col), 0.15), w=7)   # snout
    shape(img, "ellipse", [hx + 50, hy + 2, hx + 68, hy + 18], C("2a1a1a"), w=4)
    eyes(img, hx - 8, hy - 12, gap=18, size=16, look=(4, 2), angry=True)
    return img


def spider():
    img = canvas()
    col = C("6a4c8c")
    for i, sx in [(k, s) for k in range(4) for s in (-1, 1)]:
        y = 120 + i * 22
        stroke(img, [(128 + sx * 30, y), (128 + sx * 84, y - 40 + i * 8), (128 + sx * 112, y + 46)], dark(col, 0.2), 12)
    shape(img, "ellipse", [70, 92, 186, 200], col, w=OW, gloss=0.35)
    shape(img, "ellipse", [96, 150, 160, 222], dark(col, 0.1), w=OW, gloss=0.3)
    d = ImageDraw.Draw(img)
    for (x, y, r) in [(112, 172, 8), (144, 172, 8), (100, 186, 6), (156, 186, 6), (122, 192, 5), (134, 192, 5)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=C("ff3a3a"))
    stroke(img, [(114, 212), (108, 232)], C("efe4c8"), 8)
    stroke(img, [(142, 212), (148, 232)], C("efe4c8"), 8)
    return img


def humanoid(skin, outfit, *, ears=False, snout=False, weapon=None, hat=None, eyes_kw=None, mouth_kind="fangs",
             robe=False, hood_col=None, extra=None):
    img = canvas()
    if weapon == "bow":
        bow(img)
    feet(img, dark(C(outfit), 0.35))
    arms(img, C(outfit), C(skin))
    body(img, C(outfit), box=(80, 136, 176, 226) if robe else (84, 136, 172, 216))
    if ears:
        pointy_ears(img, C(skin))
    if hood_col:
        hood(img, C(hood_col), C(skin))
    else:
        head(img, C(skin))
    if snout:
        shape(img, "ellipse", [100, 104, 156, 144], light(C(skin), 0.15), w=7)
        d = ImageDraw.Draw(img)
        d.ellipse([114, 112, 122, 120], fill=OUTLINE)
        d.ellipse([134, 112, 142, 120], fill=OUTLINE)
    eyes(img, 128, 92 if snout else 100, **(eyes_kw or {"angry": True}))
    if not snout and mouth_kind:
        mouth(img, cy=130, kind=mouth_kind)
    if hat == "helmet_spike":
        helmet(img, "8a8f98", spike=True)
    elif hat == "horned":
        helmet(img, "6a6f78", horns=True)
    elif hat == "feathers":
        for i, col in enumerate(["e04a3a", "f0c43a", "3ab0e0"]):
            shape(img, "poly", [(110 + i * 18, 44), (100 + i * 22, -2), (124 + i * 18, 40)], C(col), w=6)
    elif hat == "horns":
        for sx in (-1, 1):
            shape(img, "poly", [(128 + sx * 34, 50), (128 + sx * 54, 10), (128 + sx * 52, 52)], C("efe4c8"), w=6)
    if weapon == "sword":
        sword(img)
    elif weapon == "scimitar":
        sword(img, ang=-70, length=96, col="c8ccd4")
    elif weapon == "dagger":
        dagger(img)
    elif weapon == "axe":
        axe(img)
    elif weapon == "club":
        club(img)
    elif weapon and weapon.startswith("staff:"):
        staff(img, weapon.split(":")[1])
    if extra:
        extra(img)
    return img


def skeleton(weapon=None, glow=None, crown_on=False, armor=None):
    img = canvas()
    if weapon == "bow":
        bow(img)
    ribcage(img)
    if armor:
        shape(img, "rrect", [88, 138, 168, 200], C(armor), radius=18, w=OW, gloss=0.4)
    for sx in (-1, 1):
        stroke(img, [(128 + sx * 40, 146), (128 + sx * 60, 196)], C("e8e1cc"), 12)
    skull_head(img, eye_glow=glow)
    if crown_on:
        crown(img, y=44)
    if weapon == "sword":
        sword(img, col="b8c0c8")
    return img


def ghost(col, glow):
    img = canvas()
    pts = [(70, 110), (80, 60), (128, 26), (176, 60), (186, 110), (196, 230), (172, 206), (150, 236), (128, 206),
           (106, 236), (84, 206), (60, 230)]
    shape(img, "poly", pts, C(col), w=OW, gloss=0.3)
    shape(img, "ellipse", [90, 66, 166, 136], C("0e0a14"), w=5, top=0, bot=0)
    eyes(img, 128, 100, gap=18, size=16, glow=C(glow))
    stroke(img, [(76, 140), (40, 176)], C(col), 22)
    stroke(img, [(180, 140), (216, 176)], C(col), 22)
    return img


def zombie():
    img = humanoid("8fae7a", "6a5a44", mouth_kind="teeth", eyes_kw={"look": (0, 0), "size": 18},
                   extra=lambda im: ImageDraw.Draw(im).polygon([(100, 200), (112, 216), (124, 198), (136, 218), (148, 200), (160, 216), (172, 200), (172, 230), (84, 230), (84, 200)], fill=C("4a3e30")))
    return img


NORMAL = 0.86   # ordinary figures; small creatures go lower, big ones up to 1.0


def large(img, f=1.0):
    return resized(img, f)


def monsters():
    out = {}
    out["rat"] = resized(quadruped("8a7a6a", "rat"), 0.68)
    out["wolf"] = resized(quadruped("8c8c94", "wolf"), 0.9)
    out["spider"] = resized(spider(), 0.92)
    out["kobold"] = resized(humanoid("d86a3a", "7a4a26", snout=True, weapon="dagger", hat="horns"), 0.7)
    out["kobold_shaman"] = resized(humanoid("e07a3a", "6a3a8a", snout=True, weapon="staff:ffb43a", hat="feathers", robe=True), 0.72)
    out["goblin"] = resized(humanoid("7fb84a", "7a5a3a", ears=True, weapon="scimitar"), NORMAL)
    out["goblin_archer"] = resized(humanoid("8fc85a", "5a6a3a", ears=True, weapon="bow"), NORMAL)
    out["hobgoblin"] = resized(humanoid("d8743a", "6a6f78", ears=True, weapon="sword", hat="helmet_spike"), NORMAL)
    out["cult_acolyte"] = resized(humanoid("e8c8a8", "6a3a8a", robe=True, hood_col="5a2e78", mouth_kind=None,
                                   eyes_kw={"gap": 16, "size": 16}, weapon="dagger"), NORMAL)
    out["dark_adept"] = resized(humanoid("c8b8a8", "2a2034", robe=True, hood_col="1e1828", mouth_kind=None,
                                 eyes_kw={"gap": 16, "size": 16, "glow": C("7dff6a")}, weapon="staff:7dff6a"), NORMAL)
    out["necromancer"] = resized(humanoid("d8d0c0", "1a1620", robe=True, hood_col="141018", mouth_kind=None,
                                  eyes_kw={"gap": 16, "size": 16, "glow": C("b07cff")}, weapon="staff:b07cff"), NORMAL)
    out["skeleton"] = resized(skeleton("sword"), NORMAL)
    out["skeleton_archer"] = resized(skeleton("bow"), NORMAL)
    out["zombie"] = resized(zombie(), NORMAL)
    out["ghoul"] = resized(humanoid("b8c4a8", "4a4440", mouth_kind="fangs", eyes_kw={"glow": C("ff4a3a"), "size": 16},
                            extra=lambda im: [stroke(im, [(70, 214), (52, 232)], C("efe4c8"), 6) for _ in (0,)]), NORMAL)
    out["wight"] = resized(skeleton("sword", glow="6ad0ff", armor="3a3f4a"), NORMAL)
    out["wraith"] = resized(ghost("3a2a5a", "b07cff"), NORMAL)
    out["bugbear"] = large(humanoid("a8783a", "6a4a26", ears=True, weapon="club", mouth_kind="fangs"), 0.96)
    out["ogre"] = large(humanoid("c8a878", "7a5a3a", weapon="club", mouth_kind="teeth"), 1.0)
    out["minotaur"] = large(humanoid("8a5a34", "5a3a22", snout=True, hat="horns", weapon="axe"), 1.0)
    out["troll"] = large(humanoid("5f9a5a", "4a5a3a", ears=True, mouth_kind="teeth",
                                  extra=lambda im: shape(im, "poly", [(128, 100), (176, 132), (128, 134)], C("5f9a5a"), w=7)), 1.0)
    out["giant"] = large(humanoid("e0b890", "7a6a4a", weapon="club", mouth_kind="grim",
                                  extra=lambda im: shape(im, "poly", [(92, 120), (164, 120), (128, 184)], C("8a5a2e"), w=7)), 1.0)
    out["warchief"] = large(humanoid("6fa83a", "8a2a2a", ears=True, weapon="axe", hat="horned"), 1.0)
    out["oracle"] = large(humanoid("a8d8e0", "1f6f7a", robe=True, hood_col="16545e", mouth_kind=None,
                                   eyes_kw={"gap": 16, "size": 16, "glow": C("6ad0ff")}, weapon="staff:6ad0ff"), 1.0)
    out["bone_warden"] = large(skeleton("sword", glow="ff4a3a", armor="5a4a3a"), 1.0)
    hk = skeleton(None, glow="c58bff", crown_on=True)
    cape = canvas()
    shape(cape, "poly", [(70, 140), (186, 140), (212, 236), (44, 236)], C("5a2e78"), w=OW, gloss=0.3)
    cape.alpha_composite(hk)
    staff(cape, "c58bff")
    out["hollow_king"] = large(cape, 1.0)
    return out


# --------------------------------------------------------------------------- build

def main():
    for i, key in enumerate(THEMES):
        add(f"{key}_top_a", wall_top(key, 100 + i))
        add(f"{key}_top_b", wall_top(key, 150 + i))
        add(f"{key}_face_a", wall_face(key, 100 + i))
        add(f"{key}_face_b", wall_face(key, 150 + i))
        add(f"{key}_floor_a", floor(key, 200 + i * 2))
        add(f"{key}_floor_b", floor(key, 201 + i * 2))
    add("water", water())
    add("lava", lava())
    add("stairs", stairs())
    add("sealed", stairs(sealed=True))
    add("potion", potion("e03a4a"))
    add("greater", potion("c040d8", sparkle=True))
    add("gold", gold())
    add("weapon", sword_icon())
    add("armor", armor_icon())
    for cls in ["fighter", "rogue", "barbarian", "ranger", "wizard", "cleric"]:
        add(f"hero_{cls}", resized(hero(cls), 0.9))
    for key, img in monsters().items():
        add(f"m_{key}", img)
    add("door", secret_door())      # R-27
    add("chest", chest())
    add("fountain", fountain())

    rows = (len(TILES) + COLS - 1) // COLS
    atlas = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    for i, (_, im) in enumerate(TILES):
        atlas.alpha_composite(im, ((i % COLS) * CELL, (i // COLS) * CELL))
    art = os.path.join(ROOT, "art")
    os.makedirs(art, exist_ok=True)
    atlas.save(os.path.join(art, "tiles.png"))

    # labelled preview for humans
    from PIL import ImageFont
    pc = 96
    prev = Image.new("RGBA", (COLS * (pc + 8) + 8, rows * (pc + 26) + 8), (14, 13, 20, 255))
    pd = ImageDraw.Draw(prev)
    font = ImageFont.load_default()
    for i, (name, im) in enumerate(TILES):
        x, y = 8 + (i % COLS) * (pc + 8), 8 + (i // COLS) * (pc + 26)
        prev.alpha_composite(im.resize((pc, pc), Image.LANCZOS), (x, y))
        pd.text((x, y + pc + 4), name[:16], fill=(200, 196, 180), font=font)
    prev.save(os.path.join(art, "tiles_preview.png"))

    lines = ['class_name TileAtlas', 'extends RefCounted', '## Generated by tools/make_tiles.py - do not edit by hand (D-09, D-15).',
             '', f'const CELL := {CELL}', f'const COLS := {COLS}', 'const INDEX := {']
    lines += [f'\t"{name}": {i},' for i, (name, _) in enumerate(TILES)]
    lines += ['}', '']
    with open(os.path.join(ROOT, "scripts", "tile_atlas.gd"), "w") as f:
        f.write("\n".join(lines))
    # Same index, built into testing.html so its sprite thumbnails need only art/tiles.png.
    idx = (f"window.TILE_ATLAS = {{cell: {CELL}, cols: {COLS}, width: {atlas.size[0]}, height: {atlas.size[1]}, index: {{"
           + ", ".join(f'"{n}": {i}' for i, (n, _) in enumerate(TILES)) + "}};")
    page = os.path.join(ROOT, "testing.html")
    if os.path.exists(page):
        html = open(page).read()
        a, b = html.find("// TILE_ATLAS:BEGIN"), html.find("// TILE_ATLAS:END")
        if a != -1 and b != -1:
            a = html.index("\n", a) + 1
            html = html[:a] + idx + "\n" + html[b:]
            open(page, "w").write(html)
    print(f"Wrote art/tiles.png ({len(TILES)} tiles, {atlas.size[0]}x{atlas.size[1]}), art/tiles_preview.png, scripts/tile_atlas.gd, testing.html index")


if __name__ == "__main__":
    main()
