"""Generates the jungle decor of the table: assets/decor/jungle.webp.

Usage (from the project root):
    pip install pillow playwright && playwright install chromium
    python3 tool/generate_decor.py
    python3 tool/generate_decor.py --preview build/decor-preview.png

The decor is one full-screen picture: the playing surface (a mossy jungle
clearing) framed by a bamboo fence, with lush vegetation, flowers, vines,
coconuts and butterflies around it. The game draws the markings, the goals'
team colors, the mallets and the puck on top.

The sizes come from the game itself (lib/game/config.dart and
lib/ui/table_layout.dart): change the table there, run this script again.
The frame is drawn for one half and copied rotated by 180 degrees, so both
players see the same decor from their side. Everything is seeded: the same
script always draws the same picture. Change SEED for another variation.

--preview also renders the decor with the markings, two mallets, a puck and
a power item, to judge it without building the app.
"""

import argparse
import asyncio
import math
import os
import random
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "decor", "jungle.webp")
SEED = 7
PIXEL_WIDTH = 2560  # Galaxy Tab S11: 2560 x 1600


def dart_const(path, name):
    text = open(os.path.join(ROOT, path)).read()
    m = re.search(rf"static const double {name} = ([0-9.]+);", text)
    if not m:
        raise SystemExit(f"{name} not found in {path}")
    return float(m.group(1))


W = dart_const("lib/game/config.dart", "tableWidth")
H = dart_const("lib/game/config.dart", "tableHeight")
GOAL = dart_const("lib/game/config.dart", "goalWidth")
R = dart_const("lib/ui/table_layout.dart", "rail")
TW, TH = W + 2 * R, H + 2 * R  # whole picture, in table units
BAMBOO = 34  # thickness of the bamboo fence, along the field edge

rng = random.Random(SEED)


def f(x):
    return f"{x:.1f}"


# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

# Leaf gradients: (edge, middle) — the middle is the lit midrib.
GREENS = {
    "deep": ("#0f3418", "#1f5a2a"),
    "mid": ("#17501f", "#2f8a3a"),
    "bright": ("#2a7a2c", "#62b84a"),
    "lime": ("#4f8f25", "#a3d14a"),
    "teal": ("#124a3a", "#2a8a68"),
}
HIBISCUS = [("#a3001c", "#ff5470"), ("#b8360a", "#ff9a3c"), ("#9c0057", "#ff6fb0")]


def defs():
    out = []
    for name, (edge, mid) in GREENS.items():
        out.append(
            f'<linearGradient id="leaf-{name}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{edge}"/><stop offset="0.5" stop-color="{mid}"/>'
            f'<stop offset="1" stop-color="{edge}"/></linearGradient>'
        )
    for i, (dark, light) in enumerate(HIBISCUS):
        out.append(
            f'<radialGradient id="petal-{i}" cx="0" cy="0.5" r="1">'
            f'<stop offset="0" stop-color="{dark}"/><stop offset="0.35" stop-color="{dark}"/>'
            f'<stop offset="1" stop-color="{light}"/></radialGradient>'
        )
    out.append(
        '<radialGradient id="plumeria" cx="0" cy="0.5" r="1">'
        '<stop offset="0" stop-color="#ffc928"/><stop offset="0.45" stop-color="#fff3c4"/>'
        '<stop offset="1" stop-color="#ffffff"/></radialGradient>'
    )
    # Bamboo, across its thickness (horizontal and vertical poles).
    stops = (
        '<stop offset="0" stop-color="#5a4612"/><stop offset="0.18" stop-color="#a88c34"/>'
        '<stop offset="0.42" stop-color="#ecdc8c"/><stop offset="0.62" stop-color="#cdb45a"/>'
        '<stop offset="1" stop-color="#6b5416"/>'
    )
    out.append(f'<linearGradient id="bamboo-h" x1="0" y1="0" x2="0" y2="1">{stops}</linearGradient>')
    out.append(f'<linearGradient id="bamboo-v" x1="0" y1="0" x2="1" y2="0">{stops}</linearGradient>')
    out.append(
        '<radialGradient id="coconut" cx="0.35" cy="0.3" r="0.8">'
        '<stop offset="0" stop-color="#a77446"/><stop offset="0.6" stop-color="#6b4223"/>'
        '<stop offset="1" stop-color="#3b220f"/></radialGradient>'
    )
    out.append(
        f'<radialGradient id="field" cx="{f(TW / 2)}" cy="{f(TH / 2)}" r="{f(W * 0.62)}" '
        'gradientUnits="userSpaceOnUse">'
        '<stop offset="0" stop-color="#3a7d3c"/><stop offset="0.55" stop-color="#2b6630"/>'
        '<stop offset="1" stop-color="#1b4a22"/></radialGradient>'
    )
    out.append(
        '<linearGradient id="hole" x1="1" y1="0" x2="0" y2="0">'
        '<stop offset="0" stop-color="#0d2412"/><stop offset="0.5" stop-color="#050d07"/>'
        '<stop offset="1" stop-color="#000000"/></linearGradient>'
    )
    # Everything outside the playing surface (the foliage never covers it).
    out.append(
        f'<clipPath id="outside"><path clip-rule="evenodd" d="M0 0H{f(TW)}V{f(TH)}H0Z '
        f'M{f(R)} {f(R)}V{f(R + H)}H{f(R + W)}V{f(R)}Z"/></clipPath>'
    )
    out.append(f'<clipPath id="inside"><rect x="{f(R)}" y="{f(R)}" width="{f(W)}" height="{f(H)}" rx="6"/></clipPath>')
    out.append(
        '<filter id="soft-shadow" x="-30%" y="-30%" width="160%" height="160%">'
        '<feDropShadow dx="0" dy="0" stdDeviation="5" flood-color="#000" flood-opacity="0.55"/></filter>'
    )
    out.append('<filter id="blur-30" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="30"/></filter>')
    out.append('<filter id="blur-14" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>')
    out.append('<filter id="blur-8" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="8"/></filter>')
    # Moss texture of the playing surface.
    out.append(
        '<filter id="moss" x="0" y="0" width="100%" height="100%">'
        '<feTurbulence type="fractalNoise" baseFrequency="0.03" numOctaves="4" seed="3"/>'
        '<feColorMatrix type="matrix" values="0 0 0 0 0.55  0 0 0 0 0.85  0 0 0 0 0.35  0 0 0 1.4 -0.62"/>'
        '</filter>'
    )
    return "<defs>" + "".join(out) + "</defs>"


# ---------------------------------------------------------------------------
# Shapes (drawn in a local frame: base at the origin, pointing along +x)
# ---------------------------------------------------------------------------

def leaf(x, y, angle, length, width, green, veins=True, solid=None):
    """A lanceolate leaf with its midrib and a few veins (or a plain
    silhouette filled with [solid])."""
    L, w = length, width / 2
    body = (
        f"M0 0C{f(L * .22)} {f(-w * 1.05)} {f(L * .68)} {f(-w * .95)} {f(L)} 0"
        f"C{f(L * .68)} {f(w * .95)} {f(L * .22)} {f(w * 1.05)} 0 0Z"
    )
    if solid:
        return f'<path transform="translate({f(x)} {f(y)}) rotate({f(angle)})" d="{body}" fill="{solid}"/>'
    edge, mid = GREENS[green]
    s = (
        f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})">'
        f'<path d="{body}" fill="url(#leaf-{green})"/>'
        f'<path d="M{f(L * .04)} 0Q{f(L * .5)} {f(-w * .08)} {f(L * .96)} 0" fill="none" '
        f'stroke="{mid}" stroke-opacity="0.9" stroke-width="{f(max(1.5, w * .09))}" stroke-linecap="round"/>'
    )
    if veins and L > 60:
        for t in (0.25, 0.42, 0.59, 0.76):
            vx = L * t
            half = w * 0.85 * math.sin(math.pi * min(1.0, t + 0.08)) ** 0.7
            for sgn in (-1, 1):
                s += (
                    f'<path d="M{f(vx)} 0Q{f(vx + half * .5)} {f(sgn * half * .45)} {f(vx + half * .8)} {f(sgn * half * .85)}" '
                    f'fill="none" stroke="{edge}" stroke-opacity="0.45" stroke-width="1.6"/>'
                )
    return s + "</g>"


def heart_leaf(x, y, angle, length, width, green, splits=0, uid=None):
    """Big heart-shaped leaf; with splits, a monstera (cuts from the edge)."""
    L, w = length, width / 2
    body = (
        f"M0 0C{f(-L * .26)} {f(-w * .25)} {f(-L * .24)} {f(-w * .95)} {f(L * .15)} {f(-w)}"
        f"C{f(L * .52)} {f(-w * 1.04)} {f(L * .86)} {f(-w * .5)} {f(L)} 0"
        f"C{f(L * .86)} {f(w * .5)} {f(L * .52)} {f(w * 1.04)} {f(L * .15)} {f(w)}"
        f"C{f(-L * .24)} {f(w * .95)} {f(-L * .26)} {f(w * .25)} 0 0Z"
    )
    edge, mid = GREENS[green]
    mask_ref = ""
    s = ""
    if splits:
        mask_id = f"monstera-{uid}"
        cuts = ""
        for k in range(splits):
            t = 0.12 + 0.72 * (k + 0.5) / splits
            for sgn in (-1, 1):
                cx = L * t
                cuts += (
                    f'<path d="M{f(cx + L * .06)} {f(sgn * w * 1.2)}L{f(cx - L * .02)} {f(sgn * w * .32)}" '
                    f'stroke="#000" stroke-width="{f(L * .035)}" stroke-linecap="round"/>'
                )
            if k % 2 == 0:
                cuts += f'<ellipse cx="{f(L * (t + .05))}" cy="{f(w * .18 * (1 if k % 4 else -1))}" rx="{f(L * .025)}" ry="{f(w * .07)}" fill="#000"/>'
        s += (
            f'<mask id="{mask_id}" maskUnits="userSpaceOnUse" x="{f(-L)}" y="{f(-2 * w)}" width="{f(3 * L)}" height="{f(4 * w)}">'
            f'<path d="{body}" fill="#fff"/>{cuts}</mask>'
        )
        mask_ref = f' mask="url(#{mask_id})"'
    s += f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})"><g{mask_ref}>'
    s += f'<path d="{body}" fill="url(#leaf-{green})"/>'
    s += f'<path d="M0 0Q{f(L * .5)} {f(-w * .05)} {f(L * .95)} 0" fill="none" stroke="{mid}" stroke-width="{f(w * .07)}"/>'
    for k in range(6):
        a = (k - 2.5) * 0.42
        tx, ty = L * .62 * math.cos(a) + L * .1, w * .85 * math.sin(a) * 1.3
        s += f'<path d="M{f(L * .05)} 0Q{f(tx * .5)} {f(ty * .3)} {f(tx)} {f(ty)}" fill="none" stroke="{edge}" stroke-opacity="0.5" stroke-width="2.4"/>'
    return s + "</g></g>"


def palm_frond(x, y, angle, length, bend, green, density=26):
    """A palm frond: a curved rachis with thin leaflets on both sides."""
    L = length
    pts = []
    for i in range(density + 1):
        t = i / density
        px = L * t
        py = bend * L * t * t  # droops to one side
        pts.append((t, px, py))
    s = f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})">'
    for t, px, py in pts[1:-1]:
        dx = L / density
        dy = 2 * bend * L * t * dx / L if L else 0
        heading = math.degrees(math.atan2(dy, dx))
        ll = L * 0.36 * math.sin(math.pi * (0.15 + 0.85 * t)) * (1.05 - 0.4 * t)
        for sgn in (-1, 1):
            s += leaf(px, py, heading + sgn * (52 - 18 * t) + rng.uniform(-6, 6), max(ll, 12), max(ll * 0.16, 5), green, veins=False)
    d = "M0 0" + "".join(f"L{f(px)} {f(py)}" for _, px, py in pts[1:])
    s += f'<path d="{d}" fill="none" stroke="#5d6b1e" stroke-width="5" stroke-linecap="round"/>'
    return s + "</g>"


def hibiscus(x, y, size, palette, angle):
    s = f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)}) scale({f(size / 60)})" filter="url(#soft-shadow)">'
    for k in range(5):
        s += (
            f'<path transform="rotate({k * 72})" d="M0 0C6 -26 46 -40 62 -18C72 -2 70 6 62 20C46 40 6 26 0 0Z" '
            f'fill="url(#petal-{palette})"/>'
            f'<path transform="rotate({k * 72})" d="M6 0L50 -6M6 0L52 8" stroke="#000" stroke-opacity="0.12" stroke-width="2"/>'
        )
    dark = HIBISCUS[palette][0]
    s += f'<circle r="9" fill="{dark}"/><path d="M0 0L40 -14" stroke="#ffe0e6" stroke-width="4" stroke-linecap="round"/>'
    for dx, dy in ((38, -20), (44, -12), (36, -8), (42, -22), (46, -17)):
        s += f'<circle cx="{dx}" cy="{dy}" r="3.6" fill="#ffd21f"/>'
    return s + "</g>"


def plumeria(x, y, size, angle):
    s = f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)}) scale({f(size / 30)})" filter="url(#soft-shadow)">'
    for k in range(5):
        s += f'<ellipse transform="rotate({k * 72}) translate(15 4)" rx="16" ry="9" fill="url(#plumeria)"/>'
    return s + '<circle r="5" fill="#ffb300"/></g>'


def butterfly(x, y, angle, wing, body="#2b1d0e"):
    s = f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})" filter="url(#soft-shadow)">'
    for sgn in (-1, 1):
        s += (
            f'<ellipse transform="rotate({sgn * 28})" cx="{sgn * 14}" cy="-8" rx="14" ry="11" fill="{wing}" stroke="#1a1208" stroke-width="2.5"/>'
            f'<ellipse transform="rotate({sgn * -20})" cx="{sgn * 10}" cy="10" rx="9" ry="8" fill="{wing}" stroke="#1a1208" stroke-width="2.5"/>'
            f'<circle cx="{sgn * 17}" cy="-11" r="3" fill="#fff" fill-opacity="0.8"/>'
        )
    s += f'<rect x="-2.5" y="-16" width="5" height="30" rx="2.5" fill="{body}"/>'
    s += f'<path d="M-1 -15Q-6 -26 -10 -27M1 -15Q6 -26 10 -27" stroke="{body}" stroke-width="1.6" fill="none"/>'
    return s + "</g>"


def coconuts(x, y, angle):
    s = f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})" filter="url(#soft-shadow)">'
    for cx, cy in ((0, 0), (30, 6), (14, 26)):
        s += f'<circle cx="{cx}" cy="{cy}" r="19" fill="url(#coconut)"/>'
        s += "".join(f'<circle cx="{cx + dx}" cy="{cy + dy}" r="2.6" fill="#24140a"/>' for dx, dy in ((-5, -4), (3, -6), (-1, 2)))
    return s + "</g>"


# ---------------------------------------------------------------------------
# Frame
# ---------------------------------------------------------------------------

def side_group(transform, length, goal=False):
    """Foliage bank behind the fence, along one side.

    Local frame: u along the side (0..length), v from the screen edge (0)
    to the field edge (R). Returns (behind_fence, over_fence) SVG strings.
    """
    gap = (length / 2 - GOAL / 2 - 10, length / 2 + GOAL / 2 + 10) if goal else None

    def in_gap(u):
        return gap and gap[0] < u < gap[1]

    back, front = [], []
    # Back layer: dark, large leaves pointing toward the field.
    u = -40
    while u < length + 40:
        if not in_gap(u):
            back.append(leaf(u, rng.uniform(-30, 25), rng.uniform(25, 155), rng.uniform(150, 230),
                             rng.uniform(46, 66), rng.choice(["deep", "teal", "deep"])))
        u += rng.uniform(34, 52)
    # Heart-shaped leaves and monsteras.
    u = rng.uniform(40, 120)
    while u < length - 40:
        if not in_gap(u) and not (gap and gap[0] - 60 < u < gap[1] + 60):
            uid = f"{len(back)}-{int(u)}-{rng.randint(0, 9999)}"
            back.append(heart_leaf(u, rng.uniform(-10, 20), rng.uniform(50, 130), rng.uniform(110, 150),
                                   rng.uniform(110, 140), rng.choice(["mid", "teal", "bright"]),
                                   splits=rng.choice([0, 3, 4]), uid=uid))
        u += rng.uniform(170, 260)
    # Palm fronds lying along the side.
    u = rng.uniform(0, 100)
    while u < length:
        if not in_gap(u):
            direction = rng.choice([1, -1])
            back.append(palm_frond(u, rng.uniform(5, 35), (10 if direction > 0 else 170) + rng.uniform(-12, 12),
                                   rng.uniform(200, 290), 0.25 * direction * rng.choice([1, -1]) * rng.uniform(0.4, 1),
                                   rng.choice(["bright", "mid", "lime"])))
        u += rng.uniform(140, 210)
    # Middle layer: brighter leaves.
    u = -20
    while u < length + 20:
        if not in_gap(u):
            back.append(leaf(u, rng.uniform(10, 45), rng.uniform(15, 165), rng.uniform(90, 150),
                             rng.uniform(30, 44), rng.choice(["bright", "lime", "mid", "bright"])))
        u += rng.uniform(26, 40)

    # Over the fence: leaves draped on the bamboo, but stopping at the field.
    u = rng.uniform(30, 90)
    while u < length - 30:
        if not in_gap(u):
            for _ in range(20):
                a = rng.choice([rng.uniform(-28, 12), rng.uniform(168, 208)])
                L = rng.uniform(60, 95)
                v0 = rng.uniform(25, 55)
                reach = v0 + L * math.sin(math.radians(a)) + 0.45 * 28 * abs(math.cos(math.radians(a)))
                if reach < R - 4 and v0 - 20 > -30:
                    front.append(leaf(u, v0, a, L, rng.uniform(24, 30), rng.choice(["bright", "lime"])))
                    break
        u += rng.uniform(120, 200)
    # A vine twisting along part of the bamboo.
    for start in (length * 0.08, length * 0.58):
        if gap and gap[0] - 80 < start + length * 0.3 and start < gap[1]:
            continue
        seg = length * 0.3
        pts = []
        steps = 40
        for i in range(steps + 1):
            t = i / steps
            pts.append((start + seg * t, R - BAMBOO / 2 + 11 * math.sin(t * math.pi * 7)))
        d = "M" + "L".join(f"{f(px)} {f(py)}" for px, py in pts)
        front.append(f'<path d="{d}" fill="none" stroke="#2e6b1f" stroke-width="5" stroke-linecap="round"/>')
        for i in range(2, steps - 1, 3):
            px, py = pts[i]
            side = -1 if i % 2 else 1
            front.append(leaf(px, py, -90 * side + rng.uniform(-30, 30) if side < 0 else rng.choice([-150, -30]),
                              rng.uniform(18, 24), 13, "lime", veins=False))
    # Flowers among the leaves, outside the fence.
    u = rng.uniform(60, 160)
    while u < length - 60:
        if not in_gap(u):
            if rng.random() < 0.62:
                front.append(hibiscus(u, rng.uniform(22, 48), rng.uniform(26, 34), rng.randrange(len(HIBISCUS)), rng.uniform(0, 360)))
            else:
                for k in range(rng.randint(2, 3)):
                    front.append(plumeria(u + k * 26 + rng.uniform(-6, 6), rng.uniform(18, 50), rng.uniform(17, 21), rng.uniform(0, 360)))
        u += rng.uniform(150, 240)

    return (f'<g transform="{transform}">' + "".join(back) + "</g>",
            f'<g transform="{transform}">' + "".join(front) + "</g>")


def bamboo_pole(x0, y0, x1, y1, vertical):
    """A bamboo pole, with its nodes."""
    if vertical:
        x, w, h = x0, BAMBOO, y1 - y0
        s = f'<rect x="{f(x)}" y="{f(y0)}" width="{f(w)}" height="{f(h)}" rx="8" fill="url(#bamboo-v)"/>'
        pos = y0 + rng.uniform(40, 90)
        while pos < y1 - 30:
            s += f'<rect x="{f(x)}" y="{f(pos)}" width="{f(w)}" height="6" fill="#6e561a"/>'
            s += f'<rect x="{f(x + 4)}" y="{f(pos + 6)}" width="{f(w - 8)}" height="2.5" fill="#f6e9a8" fill-opacity="0.8"/>'
            pos += rng.uniform(120, 165)
    else:
        y, h, w = y0, BAMBOO, x1 - x0
        s = f'<rect x="{f(x0)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" rx="8" fill="url(#bamboo-h)"/>'
        pos = x0 + rng.uniform(40, 90)
        while pos < x1 - 30:
            s += f'<rect x="{f(pos)}" y="{f(y)}" width="6" height="{f(h)}" fill="#6e561a"/>'
            s += f'<rect x="{f(pos + 6)}" y="{f(y + 4)}" width="2.5" height="{f(h - 8)}" fill="#f6e9a8" fill-opacity="0.8"/>'
            pos += rng.uniform(120, 165)
    return s


def bamboo_end(cx, cy):
    """Cut end of a bamboo pole, seen from above (the goal posts)."""
    r = BAMBOO / 2 + 2
    return (
        f'<g filter="url(#soft-shadow)"><circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="#c9ae55"/>'
        f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r - 3)}" fill="none" stroke="#f3e39a" stroke-width="2.5"/>'
        f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r - 8)}" fill="#3b2a0c"/></g>'
    )


def lashing(cx, cy):
    """Rope tying two poles at a corner."""
    s = f'<g transform="translate({f(cx)} {f(cy)}) rotate(45)" filter="url(#soft-shadow)">'
    for k in range(-3, 4):
        s += f'<rect x="{k * 6.5 - 2.8}" y="-27" width="5.6" height="54" rx="2.8" fill="#9a7445"/>'
        s += f'<rect x="{k * 6.5 - 1.6}" y="-25" width="1.6" height="50" fill="#d8b47c" fill-opacity="0.8"/>'
    return s + "</g>"


def half_frame():
    """One half of the frame (top side, left side, two corners); the other
    half is the same, rotated by 180 degrees."""
    top_back, top_front = side_group("", TW)
    left_back, left_front = side_group("matrix(0 1 1 0 0 0)", TH, goal=True)

    corners = []
    for cx, cy, base in ((0, 0, 45), (TW, 0, 135)):
        sweep = 1 if base == 45 else -1
        for k, da in enumerate((-38, -14, 10, 34, 58)):
            corners.append(palm_frond(cx + sweep * rng.uniform(-8, 8), cy + rng.uniform(-8, 8),
                                      base + sweep * (da - 10), rng.uniform(250, 320),
                                      0.18 * rng.choice([-1, 1]), rng.choice(["mid", "bright", "lime"])))
        uid = f"corner-{int(cx)}"
        corners.append(heart_leaf(cx + sweep * 30, cy + 25, base + sweep * 8, 175, 165, "teal", splits=4, uid=uid))
    corner_front = [coconuts(R - BAMBOO - 22, R - BAMBOO - 40, 15),
                    butterfly(TW * 0.31, 38, 20, "#2f9bff"),
                    butterfly(48, TH * 0.24, 110, "#ff8a1f")]

    hole_top = TH / 2 - GOAL / 2
    hole = (
        f'<rect x="-20" y="{f(hole_top)}" width="{f(R + 20)}" height="{f(GOAL)}" fill="url(#hole)"/>'
        f'<rect x="-20" y="{f(hole_top)}" width="{f(R + 20)}" height="{f(GOAL)}" fill="none" '
        f'stroke="#000" stroke-opacity="0.7" stroke-width="18" filter="url(#blur-8)"/>'
    )
    hole_leaves = []
    for sgn, base_y in ((1, hole_top), (-1, hole_top + GOAL)):
        for k in range(3):
            hole_leaves.append(leaf(rng.uniform(-10, 30), base_y + sgn * rng.uniform(-6, 4),
                                    90 * sgn + rng.uniform(-25, 25) - sgn * 15, rng.uniform(55, 85),
                                    rng.uniform(22, 30), rng.choice(["bright", "lime", "mid"])))

    fence = (
        bamboo_pole(-20, R - BAMBOO, TW + 20, R, vertical=False)
        + bamboo_pole(R - BAMBOO, -20, R, hole_top, vertical=True)
        + bamboo_pole(R - BAMBOO, hole_top + GOAL, R, TH + 20, vertical=True)
        + bamboo_end(R - BAMBOO / 2, hole_top - BAMBOO / 2 + 2)
        + bamboo_end(R - BAMBOO / 2, hole_top + GOAL + BAMBOO / 2 - 2)
        + lashing(R - BAMBOO / 2, R - BAMBOO / 2)
    )
    behind = '<g clip-path="url(#outside)">' + hole + "".join(corners) + top_back + left_back + "</g>"
    over = '<g clip-path="url(#outside)">' + "".join(hole_leaves) + "</g>"
    return behind, over, fence, top_front + left_front + "".join(corner_front)


def field():
    """The playing surface: a mossy clearing with dappled light and the
    shadows of the canopy near the edges."""
    s = f'<rect x="{f(R)}" y="{f(R)}" width="{f(W)}" height="{f(H)}" rx="6" fill="url(#field)"/>'
    s += f'<g clip-path="url(#inside)">'
    s += f'<rect x="{f(R)}" y="{f(R)}" width="{f(W)}" height="{f(H)}" filter="url(#moss)" opacity="0.28"/>'
    for _ in range(36):
        s += (f'<ellipse cx="{f(rng.uniform(R, R + W))}" cy="{f(rng.uniform(R, R + H))}" '
              f'rx="{f(rng.uniform(40, 130))}" ry="{f(rng.uniform(30, 90))}" fill="#e6ff9e" '
              f'fill-opacity="{f(rng.uniform(0.04, 0.09))}" filter="url(#blur-30)"/>')
    shadows = ""
    for _ in range(26):
        side = rng.randrange(4)
        if side == 0:
            x, y, a = rng.uniform(R, R + W), R - 20, rng.uniform(40, 140)
        elif side == 1:
            x, y, a = rng.uniform(R, R + W), R + H + 20, rng.uniform(220, 320)
        elif side == 2:
            x, y, a = R - 20, rng.uniform(R, R + H), rng.uniform(-50, 50)
        else:
            x, y, a = R + W + 20, rng.uniform(R, R + H), rng.uniform(130, 230)
        shadows += leaf(x, y, a, rng.uniform(140, 260), rng.uniform(50, 80), "deep", solid="#000")
    s += f'<g opacity="0.28" filter="url(#blur-14)">{shadows}</g>'
    # Shadow of the fence on the surface.
    s += (f'<rect x="{f(R)}" y="{f(R)}" width="{f(W)}" height="{f(H)}" fill="none" stroke="#000" '
          f'stroke-opacity="0.55" stroke-width="40" filter="url(#blur-14)"/>')
    return s + "</g>"


def decor_svg(overlay=""):
    behind, over, fence, front = half_frame()
    # Back layers of both halves first, then fences and front layers, so a
    # half never covers the fence of the other one.
    back_only = f'<g id="back">{behind}</g>'
    top = f'<g id="top">{fence}{over}{front}</g>'
    body = (
        f'<rect width="{f(TW)}" height="{f(TH)}" fill="#0c2612"/>'
        + field()
        + back_only + f'<use href="#back" transform="rotate(180 {f(TW / 2)} {f(TH / 2)})"/>'
        + top + f'<use href="#top" transform="rotate(180 {f(TW / 2)} {f(TH / 2)})"/>'
        + overlay
    )
    px_h = round(PIXEL_WIDTH * TH / TW)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'viewBox="0 0 {f(TW)} {f(TH)}" width="{PIXEL_WIDTH}" height="{px_h}">{defs()}{body}</svg>'), px_h


def preview_overlay():
    """What the game draws on top, roughly: to judge the decor."""
    cx, cy = TW / 2, TH / 2
    line = 'stroke="#fff" stroke-opacity="0.25" stroke-width="6" fill="none"'
    s = f'<line x1="{f(cx)}" y1="{f(R)}" x2="{f(cx)}" y2="{f(R + H)}" {line}/>'
    s += f'<circle cx="{f(cx)}" cy="{f(cy)}" r="130" {line}/>'
    for gx, color, sweep in ((R, "#2E9BFF", 1), (R + W, "#FF4D5E", 0)):
        s += (f'<path d="M{f(gx)} {f(cy - 230)}A230 230 0 0 {sweep} {f(gx)} {f(cy + 230)}" '
              f'stroke="{color}" stroke-opacity="0.45" stroke-width="6" fill="none"/>')
    s += f'<rect x="0" y="{f(cy - GOAL / 2)}" width="8" height="{f(GOAL)}" fill="#2E9BFF"/>'
    s += f'<rect x="{f(TW - 8)}" y="{f(cy - GOAL / 2)}" width="8" height="{f(GOAL)}" fill="#FF4D5E"/>'
    for x, y, c in ((R + W * .14, cy, "#2E9BFF"), (R + W * .86, cy - 90, "#FF4D5E")):
        s += f'<circle cx="{f(x + 6)}" cy="{f(y + 9)}" r="52" fill="#000" fill-opacity="0.4" filter="url(#blur-8)"/>'
        s += f'<circle cx="{f(x)}" cy="{f(y)}" r="52" fill="{c}"/><circle cx="{f(x)}" cy="{f(y)}" r="22" fill="#fff" fill-opacity="0.35"/>'
    s += f'<circle cx="{f(R + W * .42)}" cy="{f(cy + 160)}" r="30" fill="#FFD54F"/>'
    s += (f'<circle cx="{f(R + W * .62)}" cy="{f(R + 230)}" r="42" fill="#0B1220" fill-opacity="0.85" '
          f'stroke="#FF9100" stroke-width="6"/>')
    return s


async def render(svg, path, px_h):
    from playwright.async_api import async_playwright
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={"width": PIXEL_WIDTH, "height": px_h})
        await page.set_content(f"<html><body style='margin:0'>{svg}</body></html>")
        await page.locator("svg").screenshot(path=path)
        await browser.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--preview", help="also render a preview with mallets and puck to this PNG")
    args = parser.parse_args()

    from PIL import Image

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tmp = OUT + ".png"
    global rng
    rng = random.Random(SEED)
    svg, px_h = decor_svg()
    asyncio.run(render(svg, tmp, px_h))
    Image.open(tmp).convert("RGB").save(OUT, "WEBP", quality=88, method=6)
    os.remove(tmp)
    print(f"{os.path.relpath(OUT, ROOT)}: {PIXEL_WIDTH}x{px_h}, {os.path.getsize(OUT) // 1024} KB "
          f"(table {W:g}x{H:g}, rails {R:g}, goals {GOAL:g})")

    if args.preview:
        rng = random.Random(SEED)  # same decor
        svg, px_h = decor_svg(preview_overlay())
        asyncio.run(render(svg, args.preview, px_h))
        print(f"preview: {args.preview}")


if __name__ == "__main__":
    main()
