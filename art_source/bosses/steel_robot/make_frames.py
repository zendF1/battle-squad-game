#!/usr/bin/env python3
"""Đĩa Bay Thép (boss id steel_robot): every picture the game needs, made from the one concept
picture concept/ufo_v1.png (the user's, facing right: the twin cannons on the right).

The concept is cut into parts and redrawn into the animations (no AI sheets exist for this boss):

  1. keyed: the ✦ watermark painted out, the sky-blue backdrop removed by a flood from the borders
     stopped at the black outline (4-connected, so the closed outline holds: the see-through dome
     shows the same sky blue inside and stays), the enclosed backdrop pockets between the leg struts
     keyed too (never the dome's), every backdrop px un-mixed (colour-to-alpha against the backdrop
     colour: the red lamps' and the muzzles' glows keep their own colour at soft alpha, no blue
     fringe); the AI's thruster jets are dropped and painted again (jet()) so they can flicker;
  2. parts by geometry (constants below, source px): the twin barrels (slid back along their axis
     for the recoil), the bottom claw (its two halves swung open round their roots, a lit hatch
     between them), the lamps (blinking), the orange port, the dome (glass, pilot, antenna, ring);
  3. each frame drawn at full size in a fixed cell (the claw's bottom, the feet, at the same cell
     point in every frame), turned / shifted for the hurt, then halved (Lanczos on premultiplied
     colour) into one row per animation: side_<anim>/sheet_v1.png, transparent.

tools/import_boss_frames.gd then imports them like the witch's sheets (import.json here: "key":
"alpha", the cuts and feet anchors at the fixed cells, bodyHeight). Pictures: portrait/portrait_v1.png
(the whole craft, full size), portrait/bust_v1.png (the dome with the pilot), parts/hull_v1.png and
parts/dome_v1.png (one cell each, for a death that pops the dome off).

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow):

  python3 -I art_source/bosses/steel_robot/make_frames.py [--debug DIR]
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- steel_robot

--debug DIR writes the keyed picture on dark / orange and the part masks over the picture.
"""
import argparse
import math
import os

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "concept", "ufo_v1.png")

# ── Geometry of the concept picture (source px, 1045 × 1024) ─────────────────
WATERMARK = (990, 965, 36)  # the ✦: centre, radius
OUTLINE_LUM = 75  # darker than this is the black outline (the flood's wall)
NOISE = 0.12  # un-mixed alpha under this is backdrop noise / JPEG ringing: cleared
FEET = (512, 855)  # the claw head's bottom centre (measured: check_geometry())
DOME_TOP = 171  # the glass dome's top (the body: dome top → feet)
# The twin barrels: axis direction (degrees below horizontal), muzzle face centres, half width.
BARREL_DEG = 19.5
MUZZLES = [(984, 705), (919, 752)]  # upper (behind), lower (in front)
BARREL_HALF = 37
BARREL_BACK = 112  # along the axis behind the muzzle centre: the part that slides (the rest stays)
BARREL_FRONT = 40
# The claw: everything under CLAW_Y between CLAW_X, split at its middle, each half swung round its root.
CLAW_Y = 748
CLAW_X = (452, 574)
CLAW_MID = 512
CLAW_ROOTS = [(494, 750), (530, 750)]
HATCH = (512, 752, 30, 11)  # centre, half width, half height (the opening between the roots)
# The dome: the ring's outer outline as an ellipse (centre, semi-axes); above its centre line the
# dome is everything between the ring's ends.
RING = (512, 362, 214, 86)
ANTENNA = (355, 80, 470, 220)  # its box (the ball and the stem down to the glass)
# Lamps: (bulb centre, radius) + its glow strip under the hull (centre, radius) or None.
LAMPS = [
    ((73, 513, 15), None),  # left side (a half dome past the hull)
    ((184, 597, 22), (157, 619, 24)),
    ((322, 632, 22), (322, 667, 30)),
    ((509, 647, 22), (510, 685, 34)),
    ((694, 638, 22), (682, 674, 30)),
    ((836, 605, 22), (893, 609, 20)),
    ((957, 514, 15), None),  # right side
]
RING_DOTS = [(319, 368), (350, 403), (427, 424), (511, 430), (595, 424), (676, 404), (707, 369)]
PORT = (662, 496, 40)
# Thruster jets: top centre (under each foot), width, length (the AI's were about this size).
JETS = [(337, 776, 34, 70), (514, 853, 42, 72), (689, 776, 34, 70)]
JET_RECTS = [(295, 768, 380, 900), (466, 848, 562, 960), (640, 768, 735, 900)]

# ── Frames ────────────────────────────────────────────────────────────────────
CELL = (1240, 1180)  # full-size cell
OFFSET = (98, 41)  # source (0, 0) in the cell: the feet land on even cell px
SCALE = 0.5  # the sheets are halved
CELL_OUT = (CELL[0] // 2, CELL[1] // 2)
FEET_CELL = (FEET[0] + OFFSET[0], FEET[1] + OFFSET[1])
HULL_CENTRE = (512, 560)  # the hurt turns round it

INK = (24, 22, 30)


# ── Keying ────────────────────────────────────────────────────────────────────

def key(rgb):
    """Straight colour (H, W, 3) and alpha (H, W) of the keyed concept, the jets left in."""
    h, w, _ = rgb.shape
    corners = np.concatenate([rgb[:8, :8].reshape(-1, 3), rgb[:8, -8:].reshape(-1, 3),
                              rgb[-8:, :8].reshape(-1, 3), rgb[-8:, -8:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    yy, xx = np.mgrid[0:h, 0:w]
    wx, wy, wr = WATERMARK
    rgb = rgb.copy()
    rgb[(xx - wx) ** 2 + (yy - wy) ** 2 < wr ** 2] = bg  # on the backdrop: becomes backdrop
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    wall = lum < OUTLINE_LUM
    lab, n = ndimage.label(~wall)  # 4-connected: a diagonal outline still holds
    border = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    border = border[border > 0]
    outside = np.isin(lab, border)
    # Enclosed pockets of backdrop (between the leg struts): mostly backdrop colour, not in the dome.
    dist = np.linalg.norm(rgb - bg, axis=2)
    ids = np.arange(1, n + 1)
    size = ndimage.sum(np.ones_like(dist), lab, ids)
    near = ndimage.mean((dist < 24).astype(float), lab, ids)
    cy = ndimage.mean(yy.astype(float), lab, ids)
    cx = ndimage.mean(xx.astype(float), lab, ids)
    pockets = []
    for i, l in enumerate(ids):
        if l in border or size[i] < 4 or near[i] <= 0.6:
            continue
        if in_dome(cx[i], cy[i]):
            continue
        pockets.append(l)
    outside |= np.isin(lab, pockets)
    # Colour-to-alpha against the backdrop, a ramp to the px as drawn where it is nearly opaque.
    up = (rgb - bg) / (255.0 - bg)
    dn = (bg - rgb) / bg
    a = np.where(rgb > bg, up, dn).max(axis=2)
    a = np.clip((a - NOISE) / (1.0 - NOISE), 0.0, 1.0)
    unmixed = bg + (rgb - bg) / np.maximum(a, 1e-4)[..., None]
    s = np.clip((a - 0.5) / 0.3, 0.0, 1.0)
    al = a * (1 - s) + s
    col = np.clip(unmixed, 0, 255) * (1 - s)[..., None] + rgb * s[..., None]
    alpha = np.where(outside, al, 1.0)
    colour = np.where(outside[..., None], col, rgb)
    colour[alpha <= 0] = 0
    return colour, alpha, outside


def in_dome(x, y):
    rx, ry, ra, rb = RING
    if y < ry:
        return abs(x - rx) <= ra and y > 60
    return ((x - rx) / ra) ** 2 + ((y - ry) / rb) ** 2 <= 1.0


def dome_mask(h, w):
    yy, xx = np.mgrid[0:h, 0:w]
    rx, ry, ra, rb = RING
    lower = (yy >= ry) & (((xx - rx) / ra) ** 2 + ((yy - ry) / rb) ** 2 <= 1.0)
    ring_top = (yy < ry) & (((xx - rx) / ra) ** 2 + ((yy - ry) / 30.0) ** 2 <= 1.0)  # not the hull's edge behind it
    glass = (yy < ry) & (((xx - rx) / 200.0) ** 2 + ((yy - ry - 3) / 205.0) ** 2 <= 1.0)
    ax0, ay0, ax1, ay1 = ANTENNA
    antenna = (xx >= ax0) & (xx <= ax1) & (yy >= ay0) & (yy <= ay1)
    return lower | ring_top | glass | antenna


def strip_jets(colour, alpha, outside):
    """The AI's jets cleared (light un-mixed px under the feet): painted again by jet()."""
    lum = colour @ np.array([0.299, 0.587, 0.114])
    for x0, y0, x1, y1 in JET_RECTS:
        reg = (slice(y0, y1), slice(x0, x1))
        kill = outside[reg] & (lum[reg] > 140)
        alpha[reg][kill] = 0.0
    # The faint rest of them (un-mixed white specks round where they were).
    for x0, y0, x1, y1 in JET_RECTS:
        reg = (slice(y0, y1), slice(x0, x1))
        kill = outside[reg] & (alpha[reg] < 0.35) & (lum[reg] > 100)
        alpha[reg][kill] = 0.0


# ── Premultiplied layers ──────────────────────────────────────────────────────

def pm(colour, alpha):
    return np.dstack([colour * alpha[..., None] / 255.0, alpha])


def over(dst, src, at=(0, 0)):
    """src (premultiplied, h × w × 4) over dst at the cell px `at` (top-left), clipped."""
    x, y = at
    h, w = src.shape[:2]
    H, W = dst.shape[:2]
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, W), min(y + h, H)
    if x1 <= x0 or y1 <= y0:
        return dst
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    d = dst[y0:y1, x0:x1]
    dst[y0:y1, x0:x1] = s + d * (1 - s[..., 3:4])
    return dst


def layer_from_pil(img):
    a = np.asarray(img).astype(np.float64) / 255.0
    return np.dstack([a[..., :3] * a[..., 3:4], a[..., 3]])


def affine(layer, matrix, out_shape):
    """layer warped: out(p) = layer(matrix @ [p, 1]) (matrix: out px → layer px, 2 × 3), bilinear."""
    m = np.array(matrix, dtype=np.float64)
    # ndimage works in (row, col): swap x / y.
    A = np.array([[m[1, 1], m[1, 0]], [m[0, 1], m[0, 0]]])
    off = np.array([m[1, 2], m[0, 2]])
    out = np.zeros(out_shape + (4,))
    for c in range(4):
        out[..., c] = ndimage.affine_transform(layer[..., c], A, offset=off, output_shape=out_shape, order=1,
                                               mode="constant", cval=0.0)
    return np.clip(out, 0.0, 1.0)


def rotation_about(cx, cy, deg, shift=(0.0, 0.0)):
    """Out px → layer px for the layer turned `deg` (positive: anticlockwise on screen) round (cx, cy)
    then moved by shift."""
    t = math.radians(deg)
    c, s = math.cos(t), math.sin(t)
    # forward (screen, y down): p' = R(p - c) + c + shift with R = [[c, s], [-s, c]] (anticlockwise)
    # inverse: p = R^T (p' - c - shift) + c
    sx, sy = shift
    return [[c, -s, cx - c * (cx + sx) + s * (cy + sy)],
            [s, c, cy - s * (cx + sx) - c * (cy + sy)]]


def halve(layer):
    h, w = layer.shape[:2]
    size = (w // 2, h // 2)
    out = np.zeros((size[1], size[0], 4))
    for c in range(4):
        im = Image.fromarray(layer[..., c].astype(np.float32), mode="F")
        out[..., c] = np.asarray(im.resize(size, Image.LANCZOS))
    out = np.clip(out, 0.0, 1.0)
    out[..., :3] = np.minimum(out[..., :3], out[..., 3:4])
    return out


def to_image(layer):
    a = layer[..., 3]
    rgb = np.where(a[..., None] > 1e-4, layer[..., :3] / np.maximum(a, 1e-4)[..., None], 0.0)
    out = np.dstack([np.clip(rgb, 0, 1) * 255.0, a * 255.0]).round().clip(0, 255).astype(np.uint8)
    out[out[..., 3] <= 2] = 0
    return Image.fromarray(out, "RGBA")


# ── Painted bits ──────────────────────────────────────────────────────────────

def glow(dst, cx, cy, r, colour, strength):
    """A soft round glow (r: its radius) over dst, cell px."""
    H, W = dst.shape[:2]
    x0, y0 = int(max(cx - r * 1.6, 0)), int(max(cy - r * 1.6, 0))
    x1, y1 = int(min(cx + r * 1.6, W)), int(min(cy + r * 1.6, H))
    if x1 <= x0 or y1 <= y0:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    d = np.hypot(xx - cx, yy - cy) / r
    a = strength * np.exp(-2.6 * d * d)
    src = np.dstack([np.array(colour)[None, None, :] / 255.0 * a[..., None], a])
    over(dst, src, (x0, y0))


def draw_layer(size, fn, ss=2):
    """A layer painted by fn(draw, k) (k: the supersampling factor for coordinates) at ss× and reduced."""
    w, h = size
    img = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    fn(ImageDraw.Draw(img), ss)
    img = img.resize((w, h), Image.LANCZOS)
    return layer_from_pil(img)


def jet(dst, x, y, width, length, power=1.0):
    """A thruster jet hanging from (x, y) (cell px): a pale cyan flame, a white core, a soft glow; no
    outline (it is light)."""
    pad = 24
    w = int(width * 1.6 + pad * 2)
    h = int(length + pad * 2)
    ox, oy = x - w / 2, y - pad

    def paint(d, k):
        def flame(wd, ln, fill, wave):
            cx = w / 2
            pts = []
            steps = 18
            for i in range(steps + 1):  # right side down, then left side up
                t = i / steps
                half = wd / 2 * (1 - t ** 1.6) * (1 + wave * math.sin(t * 9.0))
                pts.append(((cx + half) * k, (pad + t * ln) * k))
            for i in range(steps, -1, -1):
                t = i / steps
                half = wd / 2 * (1 - t ** 1.6) * (1 + wave * math.sin(t * 9.0 + 1.7))
                pts.append(((cx - half) * k, (pad + t * ln) * k))
            d.polygon(pts, fill=fill)
        flame(width, length, (120, 205, 255, int(200 * min(power, 1.0))), 0.06)
        flame(width * 0.68, length * 0.74, (190, 236, 255, int(235 * min(power, 1.0))), 0.05)
        flame(width * 0.34, length * 0.46, (250, 253, 255, 255), 0.0)

    lay = draw_layer((w, h), paint)
    glow(dst, x, y + length * 0.3, width * 0.9, (150, 220, 255), 0.22 * power)
    over(dst, lay, (int(round(ox)), int(round(oy))))


def star(d, k, cx, cy, n, r_out, r_in, rot, fill, outline=None, width=0):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + math.pi * i / n
        pts.append(((cx + r * math.cos(a)) * k, (cy + r * math.sin(a)) * k))
    d.polygon(pts, fill=fill)
    if outline:
        d.line(pts + [pts[0]], fill=outline, width=int(width * k), joint="curve")


def muzzle_flash(dst, cx, cy, size):
    """The shot leaving: a two-tone starburst with a dark-orange outline (cell px)."""
    r = int(size * 1.3)

    def paint(d, k):
        c = r
        star(d, k, c, c, 8, size, size * 0.45, 0.2, (255, 160, 40, 255), (130, 50, 12, 255), 4)
        star(d, k, c, c, 8, size * 0.62, size * 0.28, 0.2 + math.pi / 8, (255, 236, 150, 255))
        d.ellipse([(c - size * 0.2) * k, (c - size * 0.2) * k, (c + size * 0.2) * k, (c + size * 0.2) * k],
                  fill=(255, 255, 245, 255))

    glow(dst, cx, cy, size * 1.2, (255, 170, 60), 0.55)
    over(dst, draw_layer((2 * r, 2 * r), paint), (int(cx - r), int(cy - r)))


def puffs(dst, blobs, alpha=0.92):
    """Smoke: round grey puffs, a shade, the dark outline (cell px: [(x, y, r)])."""
    x0 = int(min(b[0] - b[2] for b in blobs)) - 8
    y0 = int(min(b[1] - b[2] for b in blobs)) - 8
    x1 = int(max(b[0] + b[2] for b in blobs)) + 8
    y1 = int(max(b[1] + b[2] for b in blobs)) + 8

    def paint(d, k):
        a = int(255 * alpha)
        for x, y, r in blobs:
            e = [(x - x0 - r - 4) * k, (y - y0 - r - 4) * k, (x - x0 + r + 4) * k, (y - y0 + r + 4) * k]
            d.ellipse(e, fill=(52, 50, 62, a))
        for x, y, r in blobs:
            d.ellipse([(x - x0 - r) * k, (y - y0 - r) * k, (x - x0 + r) * k, (y - y0 + r) * k], fill=(168, 168, 180, a))
        for x, y, r in blobs:
            q = r * 0.78
            d.ellipse([(x - x0 - q - r * 0.12) * k, (y - y0 - q - r * 0.16) * k, (x - x0 + q - r * 0.12) * k,
                       (y - y0 + q - r * 0.16) * k], fill=(214, 214, 222, a))

    over(dst, draw_layer((x1 - x0, y1 - y0), paint), (x0, y0))


def sparks(dst, cx, cy, size, seed):
    """A burst of sparks: short bright strokes with a dark edge and a few dots (cell px)."""
    rng = np.random.default_rng(seed)
    r = int(size * 1.4)

    def paint(d, k):
        c = r
        angles = rng.uniform(0, 2 * math.pi, 7)
        for a in angles:
            l0 = size * rng.uniform(0.15, 0.3)
            l1 = size * rng.uniform(0.7, 1.15)
            p0 = ((c + l0 * math.cos(a)) * k, (c + l0 * math.sin(a)) * k)
            p1 = ((c + l1 * math.cos(a)) * k, (c + l1 * math.sin(a)) * k)
            d.line([p0, p1], fill=(110, 40, 10, 255), width=int(9 * k))
            d.line([p0, p1], fill=(255, 210, 70, 255), width=int(5 * k))
        star(d, k, c, c, 4, size * 0.45, size * 0.14, 0.4, (255, 250, 210, 255), (150, 70, 15, 255), 3)

    glow(dst, cx, cy, size * 0.9, (255, 190, 80), 0.45)
    over(dst, draw_layer((2 * r, 2 * r), paint), (int(cx - r), int(cy - r)))


# ── The craft ─────────────────────────────────────────────────────────────────

class Craft:
    def __init__(self, debug=None):
        rgb = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64)
        self.h, self.w = rgb.shape[:2]
        colour, alpha, outside = key(rgb)
        self.keyed_with_jets = (colour.copy(), alpha.copy())
        strip_jets(colour, alpha, outside)
        self.colour, self.alpha = colour, alpha
        h, w = self.h, self.w
        yy, xx = np.mgrid[0:h, 0:w]
        self.yy, self.xx = yy, xx
        # The barrels' band (the sliding part): axis frame per muzzle.
        t = math.radians(BARREL_DEG)
        self.axis = np.array([math.cos(t), math.sin(t)])
        normal = np.array([-math.sin(t), math.cos(t)])
        band = np.zeros((h, w), bool)
        for mx, my in MUZZLES:
            along = (xx - mx) * self.axis[0] + (yy - my) * self.axis[1]
            across = (xx - mx) * normal[0] + (yy - my) * normal[1]
            band |= (along >= -BARREL_BACK) & (along <= BARREL_FRONT) & (np.abs(across) <= BARREL_HALF)
        self.barrels = band & (alpha > 0)
        self.claw = (yy >= CLAW_Y) & (xx >= CLAW_X[0]) & (xx <= CLAW_X[1]) & (alpha > 0)
        self.dome = dome_mask(h, w) & (alpha > 0)
        r, g, b = colour[..., 0], colour[..., 1], colour[..., 2]
        self.warm = (r > 150) & (r - b > 70) & (g < r * 0.72)
        self.lamps = []
        for bulb, strip in LAMPS:
            m = self._disc(bulb) & self.warm
            if strip:
                m |= self._disc(strip) & self.warm
            self.lamps.append(m)
        self.dots = [self._disc((x, y, 7)) & self.warm for x, y in RING_DOTS]
        self.port = self._disc(PORT) & self.warm
        self.muzzle_discs = [self._disc((x, y, 22)) & self.warm for x, y in MUZZLES]
        if debug:
            self._debug(debug)

    def _disc(self, c):
        x, y, r = c
        return (self.xx - x) ** 2 + (self.yy - y) ** 2 <= r * r

    def _debug(self, out):
        os.makedirs(out, exist_ok=True)
        c, a = self.keyed_with_jets
        for name, bgc in (("on_dark", (40, 30, 45)), ("on_orange", (235, 120, 40))):
            bg = np.ones_like(c) * np.array(bgc)
            Image.fromarray((c * a[..., None] + bg * (1 - a[..., None])).round().astype(np.uint8)).save(
                os.path.join(out, "keyed_%s.png" % name))
        bg = np.ones_like(c) * np.array((40, 30, 45))
        base = self.colour * self.alpha[..., None] + bg * (1 - self.alpha[..., None])
        tint = base.copy()
        for m, col in ((self.barrels, (0, 255, 255)), (self.claw, (255, 0, 255)), (self.dome, (0, 255, 0)),
                       (self.port, (255, 255, 0))):
            tint[m] = tint[m] * 0.5 + np.array(col) * 0.5
        for m in self.lamps + self.dots + self.muzzle_discs:
            tint[m] = tint[m] * 0.3 + np.array((255, 255, 255)) * 0.7
        Image.fromarray(tint.round().clip(0, 255).astype(np.uint8)).save(os.path.join(out, "masks.png"))

    def check_geometry(self):
        a = self.alpha
        cols = slice(FEET[0] - 22, FEET[0] + 23)
        rows = np.nonzero((a[:, cols] > 0.5).any(axis=1))[0]
        feet = rows.max() + 1
        top = np.nonzero((a[:, 480:546] > 0.5).any(axis=1))[0].min()
        print("measured: feet y %d (FEET %d), dome top %d (DOME_TOP %d)" % (feet, FEET[1], top, DOME_TOP))

    # A frame, full size, in the cell: premultiplied (CELL[1], CELL[0], 4).
    def frame(self, st):
        ox, oy = OFFSET
        colour = self.colour.copy()
        alpha = self.alpha.copy()
        lamp_state = st.get("lamps", ["n"] * len(LAMPS))
        dot_state = st.get("dots", ["n"] * len(RING_DOTS))
        on_glows = []
        for m, s, (bulb, _strip) in zip(self.lamps, lamp_state, LAMPS):
            self._lamp(colour, m, s)
            if s == "on":
                on_glows.append(bulb)
        for m, s in zip(self.dots, dot_state):
            self._lamp(colour, m, s)
        port = float(st.get("port", 0.0))
        if port > 0:
            colour[self.port] = colour[self.port] * (1 - 0.6 * port) + np.array((255, 238, 180)) * 0.6 * port
        heat = float(st.get("heat", 0.0))
        if heat > 0:
            for m in self.muzzle_discs:
                colour[m] = colour[m] * (1 - 0.75 * heat) + np.array((255, 246, 205)) * 0.75 * heat
        full = pm(colour, alpha)
        cell = np.zeros((CELL[1], CELL[0], 4))
        # Behind the craft: the jets (their tops under the feet).
        jets = st.get("jets", [1.0, 1.0, 1.0])
        power = float(st.get("jet_power", 1.0))
        widen = float(st.get("jet_width", 1.0))
        for (x, y, wd, ln), k in zip(JETS, jets):
            if k > 0:
                jet(cell, x + ox, y + oy - 4, wd * widen, ln * k, power)
        # The craft, its moving parts cut out of it.
        moving = np.zeros(alpha.shape, bool)
        recoil = float(st.get("recoil", 0.0))
        claw = float(st.get("claw", 0.0))
        if recoil:
            moving |= self.barrels
        if claw:
            moving |= self.claw
        if st.get("no_dome"):
            moving |= self.dome
        body = full.copy()
        body[moving] = 0.0
        over(cell, body, (ox, oy))
        if st.get("no_dome"):
            self._cockpit(cell)
        if claw:
            self._claw(cell, full, claw, float(st.get("hatch", 0.0)))
        if recoil:
            bar = np.zeros_like(full)
            bar[self.barrels] = full[self.barrels]
            d = -recoil * self.axis
            moved = affine(bar, [[1, 0, -d[0]], [0, 1, -d[1]]], bar.shape[:2])
            moved[~self.barrels] = 0.0  # it slides into the mount: clipped to its band
            over(cell, moved, (ox, oy))
        # Lights over it.
        for x, y, r in on_glows:
            glow(cell, x + ox, y + oy, r * 1.9, (255, 120, 60), 0.42)
        if port > 0:
            glow(cell, PORT[0] + ox, PORT[1] + oy, PORT[2] * 1.5, (255, 170, 70), 0.5 * port)
        if heat > 0:
            for mx, my in self._muzzles(recoil):
                glow(cell, mx + ox, my + oy, 34 + 14 * heat, tuple(st.get("heat_colour", (255, 160, 60))), 0.6 * heat)
        for kind, arg in st.get("fx", []):
            self._fx(cell, kind, arg, recoil)
        tilt = float(st.get("tilt", 0.0))
        shift = st.get("shift", (0.0, 0.0))
        if tilt or shift != (0.0, 0.0):
            cx, cy = HULL_CENTRE[0] + ox, HULL_CENTRE[1] + oy
            cell = affine(cell, rotation_about(cx, cy, tilt, shift), cell.shape[:2])
        return cell

    def _muzzles(self, recoil=0.0):
        d = -recoil * self.axis
        return [(mx + d[0], my + d[1]) for mx, my in MUZZLES]

    @staticmethod
    def _lamp(colour, m, s):
        if s == "off":
            colour[m] = colour[m] * 0.4 + np.array((26, 4, 6))
        elif s == "on":
            colour[m] = colour[m] * 0.55 + np.array((255, 226, 160)) * 0.45

    def _fx(self, cell, kind, arg, recoil):
        ox, oy = OFFSET
        u = self.axis
        if kind == "flash":  # arg: size
            for mx, my in self._muzzles(recoil):
                muzzle_flash(cell, mx + ox + u[0] * arg * 0.55, my + oy + u[1] * arg * 0.55, arg)
        elif kind == "smoke":  # arg: (along, rise, scale)
            along, rise, k = arg
            for i, (mx, my) in enumerate(self._muzzles(recoil)):
                bx, by = mx + ox + u[0] * along, my + oy + u[1] * along - rise
                puffs(cell, [(bx, by, 17 * k), (bx + 18 * k, by - 10 * k, 13 * k), (bx - 6 * k, by - 20 * k, 11 * k)],
                      0.9 if i == 1 else 0.85)
        elif kind == "laser":  # arg: level 0..1 (the charge), ≥ 1: firing
            lvl = float(arg)
            for mx, my in self._muzzles(recoil):
                cx, cy = mx + ox, my + oy
                glow(cell, cx, cy, 40 + 34 * lvl, (255, 90, 40), min(0.85, 0.35 + 0.45 * lvl))
                self._laser_core(cell, cx + u[0] * 6, cy + u[1] * 6, lvl)
        elif kind == "motes":  # energy drawn into the muzzles: arg: (seed, reach)
            seed, reach = arg
            rng = np.random.default_rng(seed)
            for mx, my in self._muzzles(recoil):
                for _ in range(5):
                    a = rng.uniform(-1.9, 1.9) + math.atan2(u[1], u[0])
                    d = reach * rng.uniform(0.6, 1.0)
                    px, py = mx + ox + d * math.cos(a), my + oy + d * math.sin(a)
                    glow(cell, px, py, 9, (255, 140, 60), 0.55)
                    self._dot(cell, px, py, 4.5)
        elif kind == "sparks":  # arg: [(x, y, size, seed)] source px
            for x, y, size, seed in arg:
                sparks(cell, x + ox, y + oy, size, seed)
        elif kind == "beam_light":  # the hatch's light falling: arg: strength
            self._cone(cell, float(arg))

    @staticmethod
    def _dot(cell, x, y, r):
        def paint(d, k):
            d.ellipse([2 * k, 2 * k, (2 + 2 * r) * k, (2 + 2 * r) * k], fill=(255, 245, 210, 255), outline=(200, 70, 20, 255),
                      width=int(2 * k))
        n = int(2 * r + 4)
        over(cell, draw_layer((n, n), paint), (int(x - r - 2), int(y - r - 2)))

    @staticmethod
    def _laser_core(cell, cx, cy, lvl):
        """The charged muzzle: a dark-red rimmed ring, an orange disc, a white-hot core."""
        r = 16 + 14 * min(lvl, 1.0) + (8 if lvl >= 1.0 else 0)
        n = int(r * 2.6)

        def paint(d, k):
            c = n / 2
            if lvl >= 1.0:
                star(d, k, c, c, 6, r * 1.25, r * 0.7, 0.3, (255, 120, 50, 255), (120, 25, 15, 255), 4)
            d.ellipse([(c - r) * k, (c - r) * k, (c + r) * k, (c + r) * k], fill=(255, 140, 50, 255), outline=(140, 30, 18, 255),
                      width=int(4 * k))
            q = r * 0.62
            d.ellipse([(c - q) * k, (c - q) * k, (c + q) * k, (c + q) * k], fill=(255, 225, 150, 255))
            q = r * 0.34
            d.ellipse([(c - q) * k, (c - q) * k, (c + q) * k, (c + q) * k], fill=(255, 255, 250, 255))

        over(cell, draw_layer((n, n), paint), (int(cx - n / 2), int(cy - n / 2)))

    def _cone(self, cell, strength):
        ox, oy = OFFSET
        x, y = HATCH[0] + ox, HATCH[1] + oy
        H, W = cell.shape[:2]
        length = 230
        yy, xx = np.mgrid[int(y):min(int(y + length), H), int(x - 120):int(x + 120)]
        t = (yy - y) / length
        half = 26 + 90 * t
        inside = np.clip((half - np.abs(xx - x)) / 14.0, 0, 1)
        a = strength * 0.42 * inside * (1 - t) ** 1.4
        src = np.dstack([np.array((255, 226, 150))[None, None, :] / 255.0 * a[..., None], a])
        over(cell, src, (int(x - 120), int(y)))

    def _claw(self, cell, full, open_k, hatch):
        """The claw's halves swung open by open_k (0..1: 0..26 degrees) round their roots, the hatch lit
        between them."""
        ox, oy = OFFSET
        hx, hy, hw, hh = HATCH
        w = hw * (0.6 + 0.4 * open_k)
        h = hh * (0.6 + 0.4 * open_k)

        def paint(d, k):
            c = (w + 8, h + 8)
            d.ellipse([(c[0] - w - 3) * k, (c[1] - h - 3) * k, (c[0] + w + 3) * k, (c[1] + h + 3) * k], fill=INK + (255,))
            d.ellipse([(c[0] - w) * k, (c[1] - h) * k, (c[0] + w) * k, (c[1] + h) * k], fill=(70, 40, 40, 255))
            q = 0.35 + 0.5 * hatch
            d.ellipse([(c[0] - w * q) * k, (c[1] - h * q) * k, (c[0] + w * q) * k, (c[1] + h * q) * k],
                      fill=(255, 200 + int(40 * hatch), 110 + int(80 * hatch), 255))

        lay = draw_layer((int(2 * w + 16), int(2 * h + 16)), paint)
        over(cell, lay, (int(hx + ox - w - 8), int(hy + oy - h - 8)))
        if hatch > 0:
            glow(cell, hx + ox, hy + oy + 6, 34, (255, 200, 110), 0.5 * hatch)
        deg = 26.0 * open_k
        for side, (rx, ry) in enumerate(CLAW_ROOTS):
            half = np.zeros_like(full)
            m = self.claw & ((self.xx < CLAW_MID) if side == 0 else (self.xx >= CLAW_MID))
            half[m] = full[m]
            self._seal(half, side)
            # Left half: its bottom swings left (clockwise on screen); right half: anticlockwise.
            turned = affine(half, rotation_about(rx, ry, -deg if side == 0 else deg), half.shape[:2])
            over(cell, turned, (ox, oy))

    def _seal(self, half, side):
        """The cut down the claw's middle gets the black outline (a jaw's inner edge)."""
        x = CLAW_MID - 1 if side == 0 else CLAW_MID
        col = half[:, x, 3] > 0.3
        for dx in range(4):
            xx = x - dx if side == 0 else x + dx
            half[col, xx] = np.array([INK[0] / 255, INK[1] / 255, INK[2] / 255, 1.0])

    def _cockpit(self, cell):
        """With the dome gone: the hull's top behind it and the open cockpit ring."""
        ox, oy = OFFSET
        rx, ry, ra, rb = RING
        top_b = 18  # the hull's top edge just over the ring's ends

        def paint(d, k):
            px = lambda x, y: ((x - (rx - ra - 10)) * k, (y - (ry - top_b - 10)) * k)  # noqa: E731
            e = [px(rx - ra, ry - top_b), px(rx + ra, ry + top_b)]
            d.ellipse([e[0][0] - 5 * k, e[0][1] - 5 * k, e[1][0] + 5 * k, e[1][1] + 5 * k], fill=INK + (255,))
            d.ellipse([e[0][0], e[0][1], e[1][0], e[1][1]], fill=(150, 156, 166, 255))
            pit = [px(rx - ra * 0.8, ry - top_b * 0.3), px(rx + ra * 0.8, ry + rb * 0.7)]
            d.ellipse([pit[0][0] - 5 * k, pit[0][1] - 5 * k, pit[1][0] + 5 * k, pit[1][1] + 5 * k], fill=INK + (255,))
            d.ellipse([pit[0][0], pit[0][1], pit[1][0], pit[1][1]], fill=(52, 58, 72, 255))
            d.ellipse([pit[0][0] + 14 * k, pit[0][1] + 10 * k, pit[1][0] - 14 * k, pit[1][1] - 18 * k], fill=(36, 40, 52, 255))

        w = 2 * ra + 20
        h = top_b + rb + 30
        lay = draw_layer((w, h), paint)
        # Only where the dome was (the ring's ellipse and the band over it), under nothing else.
        rows, cols = np.mgrid[0:h, 0:w]
        rows = rows + (ry - top_b - 10)
        cols = cols + (rx - ra - 10)
        was_dome = self.dome[np.clip(rows, 0, self.h - 1), np.clip(cols, 0, self.w - 1)]
        inside = was_dome | (((cols - rx) / ra) ** 2 + ((rows - ry) / (rb * 0.75)) ** 2 <= 1.0)
        lay[~inside] = 0.0
        over(cell, lay, (rx - ra - 10 + ox, ry - top_b - 10 + oy))

    def dome_only(self):
        """The dome (glass, pilot, antenna, ring) alone, full size in the cell."""
        ox, oy = OFFSET
        full = pm(self.colour, self.alpha)
        full[~self.dome] = 0.0
        # Where the mask cut through the drawing (the ring's ends, its bottom), the black outline again.
        inner = ndimage.binary_erosion(self.dome, iterations=4)
        cut = ndimage.binary_dilation((~self.dome) & (self.alpha > 0.5), iterations=4)
        seal = self.dome & ~inner & cut
        full[seal] = np.array([INK[0] / 255, INK[1] / 255, INK[2] / 255, 1.0])
        cell = np.zeros((CELL[1], CELL[0], 4))
        over(cell, full, (ox, oy))
        return cell


# ── The animations ────────────────────────────────────────────────────────────

def chase(i, n=len(LAMPS)):
    """The rim lamps' chase at step i: one lamp bright, the one behind it fading, one dim across."""
    out = []
    for k in range(n):
        p = (k - i) % n
        out.append("on" if p == 0 else ("off" if p == n // 2 + 1 else "n"))
    return out


def twinkle(i):
    return ["on" if (k + i) % 3 == 0 else "n" for k in range(len(RING_DOTS))]


ANIMS = {}
ANIMS["idle"] = [
    {"lamps": chase(i), "dots": twinkle(i // 2), "jets": [j * a for a in (1.0, 0.94, 1.04)], "port": p}
    for i, (j, p) in enumerate(zip((1.0, 0.9, 1.06, 0.94, 1.04, 0.88, 1.02), (0.0, 0.08, 0.16, 0.22, 0.16, 0.08, 0.0)))
]
ANIMS["fly"] = [
    {"lamps": ["on" if (k + i) % 2 == 0 else "n" for k in range(len(LAMPS))], "dots": twinkle(i),
     "jets": [j * a for a in (1.0, 0.95, 1.05)], "jet_power": 1.0, "jet_width": 1.18, "port": 0.2}
    for i, j in enumerate((1.6, 1.45, 1.68, 1.5))
]
ANIMS["cast"] = [
    {"jets": [1.0, 1.0, 1.0]},
    {"jets": [1.05, 1.05, 1.05], "heat": 0.35, "port": 0.2},
    {"jets": [1.1, 1.1, 1.1], "heat": 0.75, "port": 0.4, "recoil": -4},
    {"jets": [0.8, 0.8, 0.8], "heat": 1.0, "port": 0.5, "recoil": 24, "shift": (-10, -2), "fx": [("flash", 64)],
     "lamps": ["on"] * len(LAMPS)},
    {"jets": [0.9, 0.9, 0.9], "heat": 0.5, "port": 0.25, "recoil": 12, "shift": (-4, 0), "fx": [("smoke", (34, 10, 1.6))]},
    {"jets": [1.0, 1.0, 1.0], "heat": 0.15, "recoil": 3, "fx": [("smoke", (28, 40, 1.3))]},
]
ANIMS["burst"] = [
    {"jets": [1.0, 1.0, 1.0], "port": 0.35, "fx": [("laser", 0.15)], "lamps": chase(0)},
    {"jets": [1.1, 1.1, 1.1], "port": 0.7, "heat": 0.6, "fx": [("motes", (3, 85)), ("laser", 0.55)], "lamps": ["on"] * len(LAMPS)},
    {"jets": [1.2, 1.25, 1.2], "port": 1.0, "heat": 1.0, "recoil": 7, "shift": (-5, 0), "fx": [("laser", 1.0)],
     "lamps": ["on"] * len(LAMPS), "dots": ["on"] * len(RING_DOTS)},
    {"jets": [1.05, 1.05, 1.05], "port": 0.6, "heat": 0.7, "recoil": 4, "fx": [("laser", 0.45)]},
    {"jets": [1.0, 1.0, 1.0], "port": 0.25, "heat": 0.3, "recoil": 1, "fx": [("smoke", (24, 18, 1.2))]},
    {"jets": [1.0, 1.0, 1.0], "port": 0.05},
]
ANIMS["summon"] = [
    {"claw": 0.3, "hatch": 0.3, "port": 0.15, "jets": [1.0, 0.0, 1.0]},
    {"claw": 0.75, "hatch": 0.7, "port": 0.3, "jets": [1.05, 0.0, 1.05], "lamps": ["on" if k % 2 else "n" for k in range(len(LAMPS))]},
    {"claw": 1.0, "hatch": 1.0, "port": 0.4, "jets": [1.1, 0.0, 1.1], "fx": [("beam_light", 1.0)], "lamps": ["on"] * len(LAMPS)},
    {"claw": 0.4, "hatch": 0.35, "port": 0.15, "jets": [1.0, 0.0, 1.0], "fx": [("beam_light", 0.35)]},
]
ANIMS["hurt"] = [
    {"tilt": 9.0, "shift": (-14, -6), "jets": [0.45, 0.3, 0.55], "lamps": ["off"] * len(LAMPS),
     "dots": ["off"] * len(RING_DOTS), "fx": [("sparks", [(880, 560, 62, 1), (735, 650, 48, 2), (600, 470, 40, 3)])]},
    {"tilt": 3.5, "shift": (-5, -2), "jets": [0.8, 0.7, 0.85], "lamps": ["off" if k % 2 else "n" for k in range(len(LAMPS))]},
]


def sheet(frames):
    w, h = CELL_OUT
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(to_image(halve(f)), (i * w, 0))
    return out


def save(img, rel):
    path = os.path.join(HERE, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print("  %s  %dx%d  %.1f KB" % (rel, img.width, img.height, os.path.getsize(path) / 1024.0))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--debug", help="write the keyed picture and the part masks here")
    ap.add_argument("--only", help="only this animation (a quick look)")
    args = ap.parse_args()
    craft = Craft(args.debug)
    craft.check_geometry()
    body_h = (FEET[1] - DOME_TOP) * SCALE
    fx, fy = FEET_CELL[0] * SCALE, FEET_CELL[1] * SCALE
    print("sheet cells %dx%d, feet at (%g, %g) in each cell, body %g px (dome top to the claw's bottom)"
          % (CELL_OUT[0], CELL_OUT[1], fx, fy, body_h))
    for name, states in ANIMS.items():
        if args.only and name != args.only:
            continue
        img = sheet([craft.frame(s) for s in states])
        save(img, "side_%s/sheet_v1.png" % name)
        n = len(states)
        print("    %s: cuts %s anchors %s" % (name, [CELL_OUT[0] * i for i in range(1, n)],
                                             [[CELL_OUT[0] * i + fx, fy] for i in range(n)]))
    if args.only:
        return
    # The pictures: the whole craft at rest (full size, the jets painted), the dome with the pilot.
    rest = craft.frame({"dots": twinkle(0)})
    save(to_image(rest), "portrait/portrait_v1.png")
    save(to_image(craft.dome_only()), "portrait/bust_v1.png")
    # Parts for a death that pops the dome off: the hull (the cockpit open) and the dome, one cell each.
    save(to_image(halve(craft.frame({"no_dome": True, "jets": [0, 0, 0]}))), "parts/hull_v1.png")
    save(to_image(halve(craft.dome_only())), "parts/dome_v1.png")


if __name__ == "__main__":
    main()
