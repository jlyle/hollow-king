#!/usr/bin/env python3
"""Generate the app-menu icon from the hero sprite in art/tiles.png (D-09, D-14).

Usage:  python3 tools/make_icons.py   (run make_tiles.py first)
Writes: art/icon_512.png   installed by tools/build.sh install as the desktop icon
Needs:  Pillow
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
ART = os.path.join(ROOT, "art")
HERO_INDEX = 6          # keep in sync with make_tiles.py ORDER
GOLD = (232, 193, 112)
BG = (11, 11, 18)
GLOW = (52, 38, 18)


def hero_sprite():
    atlas = Image.open(os.path.join(ART, "tiles.png")).convert("RGBA")
    x, y = (HERO_INDEX % 8) * 16, (HERO_INDEX // 8) * 16
    return atlas.crop((x, y, x + 16, y + 16))


def background(size):
    """Dark square with a warm radial glow (matches the game's title screen)."""
    img = Image.new("RGBA", (size, size), BG + (255,))
    cx, cy = size / 2, size * 0.42
    px = img.load()
    for yy in range(size):
        for xx in range(size):
            d = ((xx - cx) ** 2 + (yy - cy) ** 2) ** 0.5 / (size * 0.62)
            t = max(0.0, 1.0 - d)
            px[xx, yy] = tuple(int(BG[i] + (GLOW[i] - BG[i]) * t) for i in range(3)) + (255,)
    return img


def framed(size, sprite_px, border=True, rounded=0.0):
    img = background(size)
    hero = hero_sprite().resize((sprite_px, sprite_px), Image.NEAREST)
    img.alpha_composite(hero, ((size - sprite_px) // 2, (size - sprite_px) // 2 + size // 40))
    if border:
        d = ImageDraw.Draw(img)
        w = max(2, size // 64)
        inset = size // 16
        d.rounded_rectangle([inset, inset, size - inset, size - inset], radius=size // 8, outline=GOLD + (200,), width=w)
    if rounded:
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * rounded), fill=255)
        img.putalpha(mask)
    return img


def main():
    framed(512, 384, border=True, rounded=0.18).save(os.path.join(ART, "icon_512.png"))
    print("Wrote art/icon_512.png")


if __name__ == "__main__":
    main()
