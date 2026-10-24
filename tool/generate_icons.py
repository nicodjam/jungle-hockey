"""Generates the Jungle Hockey launcher icons: a mallet made of half a coconut
on a bamboo handle, crowned with a hibiscus, that has just struck a
pineapple-slice puck, on a jungle background matching the table decor.

Usage (from the project root):
    pip install pillow playwright && playwright install chromium
    python3 tool/generate_icons.py

Edit the SVG drawing in foreground() and background(), then run the script
again: it rewrites assets/icon/ and every Android launcher icon.

Android draws an adaptive icon (Android 8+) from two 108 dp layers: the
background, cropped by the launcher's mask (circle, squircle...), and the
foreground, whose art must stay within the central 66 dp circle (radius
313 in the 1024 box below). The same foreground serves as the monochrome
layer of themed icons (Android 13+). Older launchers get ic_launcher.png.
"""

import asyncio
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_decor as decor  # noqa: E402  (leaves, palm fronds, gradients)

from PIL import Image, ImageDraw  # noqa: E402

ROOT = decor.ROOT
ICON_DIR = os.path.join(ROOT, "assets", "icon")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")


def svg(content, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
            f'{decor.defs()}<defs>{defs}</defs>{content}</svg>')


def background():
    """Mossy clearing, framed by jungle leaves (the mask crops the edges)."""
    decor.rng = random.Random(11)
    s = (
        '<radialGradient id="bg" cx="0.5" cy="0.5" r="0.6">'
        '<stop offset="0" stop-color="#3f8a3f"/><stop offset="0.6" stop-color="#2a6a30"/>'
        '<stop offset="1" stop-color="#174a1f"/></radialGradient>'
    )
    body = '<rect width="1024" height="1024" fill="url(#bg)"/>'
    body += '<circle cx="512" cy="540" r="300" fill="#e6ff9e" fill-opacity="0.12" filter="url(#blur-30)"/>'
    leaves = ""
    # Two clumps of jungle, top left and bottom right, starting just
    # outside the visible circle (radius 341) and sweeping along its edge.
    for sgn in (1, -1):
        def p(x, y):
            return (x, y) if sgn > 0 else (1024 - x, 1024 - y)
        turn = 0 if sgn > 0 else 180
        for (x, y), angle, length, green in (
            ((90, 470), -62, 330, "deep"), ((120, 360), -42, 340, "mid"),
            ((200, 210), -12, 330, "bright"), ((340, 110), 14, 300, "mid"),
            ((150, 260), -30, 260, "lime"),
        ):
            leaves += decor.palm_frond(*p(x, y), angle + turn, length, 0.12, green)
        leaves += decor.heart_leaf(*p(150, 190), 40 + turn, 210, 200, "teal", splits=4, uid=f"icon-{sgn}")
        leaves += decor.leaf(*p(110, 330), -8 + turn, 230, 70, "bright")
        leaves += decor.leaf(*p(300, 120), 70 + turn, 220, 64, "deep")
    body += f'<g filter="url(#soft-shadow)">{leaves}</g>'
    body += decor.hibiscus(318, 286, 46, 1, 20)
    body += decor.hibiscus(706, 742, 40, 2, 200)
    return svg(body, s)


def foreground():
    """The mallet and the puck, in a three-quarter view, gone tropical:
    a half coconut on a bamboo handle crowned with a hibiscus, striking a
    pineapple slice."""
    d = (
        # Coconut shell (side), flesh (top face) and its hollow.
        '<linearGradient id="shell" x1="0" y1="0" x2="1" y2="0">'
        '<stop offset="0" stop-color="#3f2410"/><stop offset="0.45" stop-color="#8a5a2e"/>'
        '<stop offset="1" stop-color="#3a210e"/></linearGradient>'
        '<radialGradient id="flesh" cx="0.45" cy="0.4" r="0.7">'
        '<stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#f1e6cf"/></radialGradient>'
        '<radialGradient id="hollow" cx="0.5" cy="0.3" r="0.8">'
        '<stop offset="0" stop-color="#d9c9a6"/><stop offset="1" stop-color="#fbf4e4"/></radialGradient>'
        # Bamboo handle and wooden knob.
        '<linearGradient id="bamboo" x1="0" y1="0" x2="1" y2="0">'
        '<stop offset="0" stop-color="#6b5416"/><stop offset="0.3" stop-color="#c9ae55"/>'
        '<stop offset="0.5" stop-color="#ecdc8c"/><stop offset="1" stop-color="#6b5416"/></linearGradient>'
        '<radialGradient id="knob" cx="0.35" cy="0.3" r="0.8">'
        '<stop offset="0" stop-color="#e0a866"/><stop offset="0.55" stop-color="#9a5e2a"/>'
        '<stop offset="1" stop-color="#5a3313"/></radialGradient>'
        # Pineapple slice: rind on the side, flesh on top.
        '<linearGradient id="rind" x1="0" y1="0" x2="1" y2="0">'
        '<stop offset="0" stop-color="#9a5a12"/><stop offset="0.5" stop-color="#e3a12f"/>'
        '<stop offset="1" stop-color="#9a5a12"/></linearGradient>'
        '<radialGradient id="pineapple" cx="0.5" cy="0.5" r="0.5">'
        '<stop offset="0" stop-color="#fff6b8"/><stop offset="0.3" stop-color="#ffe45c"/>'
        '<stop offset="1" stop-color="#ffc928"/></radialGradient>'
        '<filter id="shadow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>'
    )

    # --- Mallet: half coconut, base centered at (mx, my) ---
    mx, my, rx, ry, height = 440, 630, 168, 62, 50
    side = f"M{mx - rx} {my}V{my + height}A{rx} {ry} 0 0 0 {mx + rx} {my + height}V{my}Z"
    fibers = ""
    for k in range(70):
        x = mx - rx + 8 + (2 * rx - 16) * ((k * 37) % 70) / 70
        y = my + 10 + (k * 13) % (height + 30)
        fibers += (f'<path d="M{x:.1f} {y:.1f}q{(k % 5) - 2} 9 {(k % 7) - 3} 18" stroke="#c08a52" '
                   f'stroke-opacity="0.55" stroke-width="2.2" fill="none"/>')
    mallet = (
        f'<ellipse cx="{mx + 14}" cy="{my + height + 24}" rx="{rx + 10}" ry="{ry}" fill="#000" fill-opacity="0.45" filter="url(#shadow)"/>'
        f'<clipPath id="shell-side"><path d="{side}"/></clipPath>'
        f'<path d="{side}" fill="url(#shell)"/>'
        f'<g clip-path="url(#shell-side)">{fibers}</g>'
        f'<ellipse cx="{mx}" cy="{my}" rx="{rx}" ry="{ry}" fill="#4a2a10"/>'
        f'<ellipse cx="{mx}" cy="{my}" rx="{rx - 9}" ry="{ry - 6}" fill="url(#flesh)"/>'
        f'<ellipse cx="{mx}" cy="{my + 4}" rx="{rx * .72:.1f}" ry="{ry * .66:.1f}" fill="url(#hollow)"/>'
    )
    # Bamboo handle, with a node, rising from the hollow.
    hx0, hx1, top = mx - 44, mx + 44, my - 120
    mallet += (
        f'<path d="M{hx0} {my + 6}V{top}A44 15 0 0 1 {hx1} {top}V{my + 6}A44 15 0 0 1 {hx0} {my + 6}Z" fill="url(#bamboo)"/>'
        f'<rect x="{hx0}" y="{my - 58}" width="88" height="9" fill="#6e561a"/>'
        f'<rect x="{hx0 + 6}" y="{my - 49}" width="76" height="3" fill="#f6e9a8" fill-opacity="0.8"/>'
        f'<circle cx="{mx}" cy="{my - 168}" r="72" fill="url(#knob)"/>'
        f'<path d="M{mx - 60} {my - 150}q60 26 120 0" stroke="#4a2a10" stroke-opacity="0.35" stroke-width="5" fill="none"/>'
        f'<ellipse cx="{mx - 26}" cy="{my - 198}" rx="22" ry="13" fill="#fff" fill-opacity="0.45" transform="rotate(-25 {mx - 26} {my - 198})"/>'
    )
    mallet += decor.hibiscus(mx + 8, my - 214, 50, 0, 15)

    # --- Puck: pineapple slice flying toward the top right ---
    px, py, prx, pry, ph = 690, 400, 92, 34, 26
    puck = (
        f'<ellipse cx="{px + 10}" cy="{py + ph + 40}" rx="{prx}" ry="{pry}" fill="#000" fill-opacity="0.35" filter="url(#shadow)"/>'
        f'<path d="M{px - prx} {py}V{py + ph}A{prx} {pry} 0 0 0 {px + prx} {py + ph}V{py}Z" fill="url(#rind)"/>'
        f'<ellipse cx="{px}" cy="{py}" rx="{prx}" ry="{pry}" fill="#c98622"/>'
        f'<ellipse cx="{px}" cy="{py}" rx="{prx - 10}" ry="{pry - 5}" fill="url(#pineapple)"/>'
    )
    for k in range(18):  # fibers of the flesh, from the core outward
        a = 2 * math.pi * k / 18
        puck += (f'<line x1="{px + 22 * math.cos(a):.1f}" y1="{py + 8 * math.sin(a):.1f}" '
                 f'x2="{px + (prx - 14) * math.cos(a):.1f}" y2="{py + (pry - 7) * math.sin(a):.1f}" '
                 f'stroke="#f0b419" stroke-opacity="0.7" stroke-width="2.5"/>')
    for k in range(12):  # "eyes" of the pineapple, near the rind
        a = 2 * math.pi * (k + .5) / 12
        puck += (f'<ellipse cx="{px + (prx - 16) * math.cos(a):.1f}" cy="{py + (pry - 8) * math.sin(a):.1f}" '
                 f'rx="4" ry="2.4" fill="#a8681a"/>')
    puck += f'<ellipse cx="{px}" cy="{py}" rx="20" ry="7.5" fill="#fffbe0" stroke="#f0c84a" stroke-width="2"/>'

    # Starburst where the mallet hit the puck, speed lines along the path.
    sx, sy = 618, 590
    ux, uy = sx - px, sy - py
    norm = math.hypot(ux, uy)
    ux, uy = ux / norm, uy / norm
    lines = ""
    for offset, start, length in ((-46, 70, 90), (0, 60, 120), (46, 70, 90)):
        x0, y0 = px + ux * start + uy * offset, py + uy * start - ux * offset
        lines += (f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x0 + ux * length:.1f}" y2="{y0 + uy * length:.1f}" '
                  f'stroke="#fff" stroke-opacity="0.8" stroke-width="12" stroke-linecap="round"/>')
    points = []
    for k in range(16):
        r = 58 if k % 2 == 0 else 22
        a = k * math.pi / 8 + 0.2
        points.append(f"{sx + r * math.cos(a):.1f},{sy + r * math.sin(a):.1f}")
    spark = (f'<polygon points="{" ".join(points)}" fill="#FFF3B0" stroke="#FFD54F" stroke-width="6" '
             f'stroke-linejoin="round"/>')
    return svg(lines + spark + mallet + puck, d)


async def _render(pairs):
    from playwright.async_api import async_playwright
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={"width": 1024, "height": 1024})
        for svg_text, png_path, transparent in pairs:
            await page.set_content(f"<html><body style='margin:0;background:transparent'>{svg_text}</body></html>")
            await page.locator("svg").screenshot(path=png_path, omit_background=transparent)
        await browser.close()


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    bg_svg, fg_svg = background(), foreground()
    open(os.path.join(ICON_DIR, "icon_background.svg"), "w").write(bg_svg)
    open(os.path.join(ICON_DIR, "icon_foreground.svg"), "w").write(fg_svg)
    bg_png = os.path.join(ICON_DIR, "icon_background.png")
    fg_png = os.path.join(ICON_DIR, "icon_foreground.png")
    asyncio.run(_render([(bg_svg, bg_png, False), (fg_svg, fg_png, True)]))
    bg = Image.open(bg_png).convert("RGBA")
    fg = Image.open(fg_png).convert("RGBA")

    # Full icon (legacy launchers, store): both layers, the art a little
    # larger, in a rounded square.
    big = fg.resize((1180, 1180), Image.LANCZOS)
    full = bg.copy()
    full.alpha_composite(big, (-78, -78))
    mask = Image.new("L", full.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1023, 1023), radius=200, fill=255)
    full.putalpha(mask)
    full.save(os.path.join(ICON_DIR, "icon.png"), optimize=True)

    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        full.resize((size, size), Image.LANCZOS).save(os.path.join(folder, "ic_launcher.png"), optimize=True)
        layer = size * 108 // 48
        fg.resize((layer, layer), Image.LANCZOS).save(os.path.join(folder, "ic_launcher_foreground.png"), optimize=True)
        bg.convert("RGB").resize((layer, layer), Image.LANCZOS).save(os.path.join(folder, "ic_launcher_background.png"), optimize=True)

    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    open(os.path.join(anydpi, "ic_launcher.xml"), "w").write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Generated by tool/generate_icons.py -->\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
    print("Icons generated.")


if __name__ == "__main__":
    main()
