#!/usr/bin/env python3
"""Khổng Lồ Đá (boss id rock_giant): every picture the game needs, made from the one picture the user
gave, concept/ram_golem_v1.png (a brown stone giant in grey-trimmed ancient armour, a helmet with
glowing yellow eyes, golden ram horns, an amber gem on the chest; front view, standing still).

The picture is cut into parts and posed on a skeleton (rigid cut-out parts turned round their joints,
no AI sheets exist for this boss):

  1. keyed: the flat sky-blue backdrop and the darker blue ground-shadow ellipse under the feet (the
     game draws shadows) removed by colour (the giant has no blue at all), every backdrop px next to
     the figure un-mixed against its own local backdrop colour (colour-to-alpha: the navy outline
     keeps its soft edge, no blue fringe), the faint light specks the un-mixing leaves cleared, only
     the figure's piece kept (the ✦ watermark sits on the backdrop: it goes with it);
  2. cut into parts: the picture split into its flat-colour cells (the regions between the black
     outlines), each cell given to a part by the polygons below (PARTS, source px: a cell mostly
     inside one polygon goes whole, so the cuts follow the drawn outlines), the horns found by their
     golden colour; the outline px between two parts belong to the one in front (OWN order) and are
     copied into the one behind; every cut through flat colour gets a new outline (seal());
  3. the hidden areas painted (UNDER): what a part covers in the picture is painted on the part
     behind it in the same flat colours with the bold outline, so nothing tears when a part moves:
     the torso under the shoulder pads, the helmet and the horns, the belt under the chest, the
     thighs under the skirt, the upper arms from the shoulder joint (under the pads) to the elbow
     (under the bracers), the wrists under the wrist bands, the pads' tops under the horns;
  4. a skeleton (RIG: root at the feet → pelvis (belt + skirt) → chest → head (helmet + horns),
     shoulder pads, arms (upper → forearm → fist); the legs on the root) posed per frame (ANIMS:
     angles in degrees, offsets in source px), with what glows: the chest gem (pulse / flare), the
     eyes (flicker), the armour carvings on the chest and the belt (gold), the death's cracks (amber),
     a boulder in the throwing fist;
  5. each frame drawn at full size in a fixed cell (the feet, the midpoint between the soles, at the
     same cell point CELL_FEET), halved (premultiplied area resampling) into one row per animation:
     side_<anim>/sheet_v1.png, transparent.

Also written: skin/rest_v1.png (the rest pose at full size: the skinned idle's picture), the
portrait (the rest pose, gem and eyes lit) and the bust (the head with the horns), parts/<name>_v1.png
(the death's pieces in the last death frame's pose, one cell each, the frames' feet: horns, helmet,
shoulder pads, torso and belt boulders, arms, fists, legs), rig_v1.json (the points the game needs,
source px and the unit frame) and import.json (the importer's config: cuts, feet anchors, the
skin's joints and bones, the parts' order).

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow, OpenCV):

  python3 -I art_source/bosses/rock_giant/make_frames.py [--debug DIR]
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- rock_giant

--debug DIR writes the keyed picture on dark / orange, the part map over the picture, every part
alone with its painted underlay, and the rig's joints.
"""
import argparse
import json
import math
import os

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "concept", "ram_golem_v1.png")

# ── The picture (source px, 1380 × 752) ──────────────────────────────────────
WATERMARK = (1323, 697, 30)  # the ✦ on the backdrop: centre, radius (painted backdrop first)
NOISE = 0.08  # un-mixed alpha under this is backdrop noise / JPEG ringing
OUTLINE_LUM = 33  # darker than this is the navy outline (the cells' walls)
FEET = (700.0, 712.0)  # the midpoint between the soles, on the ground line
TOP = 52.0  # the horns' top: the body is TOP → FEET (660 px)
BODY_H = FEET[1] - TOP
INK = (6, 12, 22)  # the outline colour
INK_W = 6  # the outline's width (source px)
BROWN = (91, 73, 57)  # the stone armour's base
DARK = (64, 47, 39)  # its shade
BELT = (79, 69, 68)
GREY = (145, 138, 130)  # the trims
KNUCKLE = (142, 121, 104)
GOLD = (255, 205, 70)  # the carvings' and the cracks' glow
AMBER = (255, 176, 40)

# Part polygons (source px): a cell goes to the first polygon (in this order) holding most of it;
# the rest is the chest. The horns are found by colour (HORN_*), the helmet by its polygon.
HELMET = [(626, 162), (690, 100), (792, 100), (910, 156), (910, 200), (812, 206), (808, 245), (790, 282),
          (748, 300), (728, 299), (688, 276), (656, 238), (640, 205), (626, 200)]
PARTS = {
    "pauldron_l": [(428, 268), (606, 268), (606, 378), (428, 382)],
    "pauldron_r": [(852, 285), (948, 285), (948, 372), (862, 370), (852, 342)],
    "fore_l": [(362, 370), (445, 370), (472, 432), (532, 468), (538, 527), (380, 552), (362, 552)],
    "fore_r": [(905, 370), (998, 370), (998, 524), (842, 524), (838, 452), (905, 445), (934, 425)],
    "fist_l": [(378, 545), (540, 524), (548, 634), (378, 634)],
    "fist_r": [(866, 524), (998, 524), (998, 630), (866, 630)],
    "upper_l": [(420, 355), (588, 355), (598, 452), (470, 472), (420, 425)],
    "upper_r": [(830, 345), (845, 355), (862, 368), (934, 368), (934, 425), (905, 445), (840, 452), (810, 404), (806, 388),
                (822, 375)],
    "leg_l": [(498, 556), (650, 558), (657, 604), (645, 640), (662, 722), (498, 722)],
    "leg_r": [(764, 576), (832, 572), (905, 560), (905, 722), (764, 722)],
    "pelvis": [(582, 438), (800, 438), (848, 500), (842, 578), (764, 584), (760, 630), (650, 630), (645, 566),
               (544, 566), (548, 492), (588, 438)],
}
HORN_HUE = (25, 58)  # degrees: the gold and the tan of the horns
HORN_BELOW = 335  # horns only above this row
GEM_BOX = (700, 322, 795, 428)
EYES = [(722, 212), (792, 214)]  # the eyes' glow centres
EYE_BOX = (690, 195, 815, 232)
GEM = (744, 376)  # the gem's centre: the heart
# The carvings (thin light lines on the chest bands and the belt): light px inside these.
CARVE_ZONES = [[(588, 282), (705, 318), (700, 350), (588, 318)], [(780, 300), (888, 280), (888, 318), (782, 352)],
               [(592, 446), (792, 446), (792, 494), (592, 494)]]
CARVE_LUM = 112

# The joints (source px).
J = {
    "feet": FEET, "waist": (722.0, 505.0), "belly": (738.0, 452.0), "neck": (742.0, 292.0),
    "shoulder_l": (548.0, 345.0), "elbow_l": (468.0, 428.0), "wrist_l": (458.0, 532.0),
    "shoulder_r": (868.0, 345.0), "elbow_r": (904.0, 430.0), "wrist_r": (918.0, 530.0),
    "hip_l": (612.0, 520.0), "hip_r": (798.0, 520.0), "fist_l": (462.0, 585.0), "fist_r": (922.0, 578.0),
}
# The skeleton: part → (parent, pivot joint).
RIG = {
    "root": (None, "feet"),
    "leg_l": ("root", "hip_l"), "leg_r": ("root", "hip_r"),
    "pelvis": ("root", "waist"), "chest": ("pelvis", "belly"), "head": ("chest", "neck"),
    "pauldron_l": ("chest", "shoulder_l"), "pauldron_r": ("chest", "shoulder_r"),
    "upper_l": ("chest", "shoulder_l"), "fore_l": ("upper_l", "elbow_l"), "fist_l": ("fore_l", "wrist_l"),
    "upper_r": ("chest", "shoulder_r"), "fore_r": ("upper_r", "elbow_r"), "fist_r": ("fore_r", "wrist_r"),
}
# Draw order, back to front (an arm "front" goes over the head: the throw's release).
ORDER = ["upper_l", "upper_r", "leg_l", "leg_r", "pelvis", "chest", "pauldron_l", "pauldron_r",
         "fist_l", "fore_l", "fist_r", "fore_r", "head"]
# Who owns the outline px between two parts (front first).
OWN = ["head", "fore_l", "fore_r", "fist_l", "fist_r", "pauldron_l", "pauldron_r", "chest", "upper_l", "upper_r",
       "pelvis", "leg_l", "leg_r"]


def ellipse(cx, cy, rx, ry, n=40, a0=0.0, a1=360.0):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / (n - 1))),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / (n - 1)))) for i in range(n)]


def capsule(a, b, ra, rb, n=24):
    """A tapered capsule round the segment a → b (radii ra at a, rb at b)."""
    ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
    pts = ellipse(b[0], b[1], rb, rb, n, ang - 90, ang + 90) + ellipse(a[0], a[1], ra, ra, n, ang + 90, ang + 270)
    return pts


# The hidden areas (painted under a part, fill colour, outlined): part → [(polygon, colour)].
UNDER = {
    "chest": [([(562, 335), (574, 282), (606, 238), (660, 206), (742, 196), (822, 206), (858, 240), (868, 296),
                (862, 352), (828, 416), (804, 446), (622, 450), (598, 412), (570, 372)], BROWN)],
    "pelvis": [([(600, 426), (786, 426), (790, 470), (596, 470)], BELT)],
    "leg_l": [([(578, 498), (648, 498), (650, 584), (576, 584)], BROWN)],
    "leg_r": [([(772, 500), (824, 500), (826, 590), (772, 590)], BROWN)],
    "upper_l": [(capsule((552, 350), J["elbow_l"], 42, 38), BROWN)],
    "upper_r": [(capsule(J["shoulder_r"], J["elbow_r"], 44, 36), BROWN)],
    "fist_l": [(ellipse(460, 530, 58, 32), BROWN)],
    "fist_r": [(ellipse(920, 528, 52, 30), BROWN)],
    "pauldron_l": [([(446, 312), (456, 284), (492, 266), (560, 262), (596, 274), (600, 312)], DARK)],
    "pauldron_r": [([(866, 318), (870, 292), (892, 278), (918, 280), (926, 300), (926, 318)], DARK)],
}

# The death's cracks (source px polylines; the stage they appear in, 1..3). Jagged on purpose.
CRACKS = [
    (1, [(744, 420), (736, 440), (748, 462), (738, 488)]),
    (1, [(744, 330), (752, 310), (742, 296)]),
    (1, [(712, 360), (690, 352), (676, 336), (650, 330), (630, 312)]),
    (2, [(776, 372), (800, 380), (812, 360), (838, 352), (856, 330)]),
    (2, [(738, 488), (726, 512), (734, 540), (722, 566), (728, 600)]),
    (2, [(640, 400), (620, 420), (626, 446)]),
    (2, [(760, 150), (752, 170), (762, 186)]),
    (2, [(512, 300), (530, 320), (522, 350)]),
    (2, [(890, 300), (900, 322), (892, 352)]),
    (3, [(450, 450), (470, 470), (456, 492), (472, 520)]),
    (3, [(930, 450), (912, 470), (926, 496), (914, 520)]),
    (3, [(600, 640), (586, 660), (598, 684)]),
    (3, [(810, 620), (826, 642), (814, 668)]),
    (3, [(680, 500), (664, 530), (676, 560)]),
    (3, [(800, 400), (790, 420), (804, 440)]),
    (3, [(706, 130), (716, 150), (708, 172)]),
]
# The death's pieces: big parts split further along these lines (polygons in source px: the piece
# is the part's px inside; the remainder stays the part's name).
SPLITS = {
    "chest": {"chest_l": [(500, 150), (744, 150), (744, 330), (712, 360), (690, 352), (676, 336), (650, 330), (630, 312),
                          (600, 300), (500, 300)],
              "chest_r": [(744, 150), (1000, 150), (1000, 352), (856, 330), (838, 352), (812, 360), (800, 380), (776, 372),
                          (760, 340), (744, 330)]},
    "pelvis": {"pelvis_r": [(738, 400), (1000, 400), (1000, 700), (728, 700), (722, 566), (734, 540), (726, 512), (738, 488)]},
    "head": {"horn_l": None, "horn_r": None},  # the horns: by colour, left / right of the helmet
}

CELL = (1180, 940)  # the full-size cell
CELL_FEET = (560, 900)  # the feet in it
HALF = 2  # the sheets are halved


def lum(rgb):
    return rgb @ np.array([0.299, 0.587, 0.114])


def key(rgb):
    """Straight colour (H, W, 3) and alpha (H, W) of the keyed picture."""
    h, w, _ = rgb.shape
    rgb = rgb.copy()
    yy, xx = np.mgrid[0:h, 0:w]
    wx, wy, wr = WATERMARK
    star = (xx - wx) ** 2 + (yy - wy) ** 2 < wr ** 2
    rgb[star] = rgb[wy - wr - 10, wx]  # the backdrop just above it
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    blue = (b > r + 40) & (b > g + 15) & (b > 110)
    core = ndimage.binary_erosion(blue, iterations=2)
    _, (iy, ix) = ndimage.distance_transform_edt(~core, return_indices=True)
    bg = rgb[iy, ix]  # each px's nearest clean backdrop colour (sky or shadow)
    up = (rgb - bg) / np.maximum(255.0 - bg, 1)
    dn = (bg - rgb) / np.maximum(bg, 1)
    a = np.where(rgb > bg, up, dn).max(axis=2)
    a = np.clip((a - NOISE) / (1 - NOISE), 0, 1)
    band = (ndimage.distance_transform_edt(~blue) <= 3) & ~core
    alpha = np.where(blue & ~band, 0.0, 1.0)
    alpha = np.where(band, a, alpha)
    col = bg + (rgb - bg) / np.maximum(alpha, 1e-4)[..., None]
    s = np.clip((alpha - 0.5) / 0.3, 0, 1)
    col = np.clip(col, 0, 255) * (1 - s)[..., None] + rgb * s[..., None]
    col = np.where(band[..., None], col, rgb)
    # Specks: faint light px in the band (JPEG ringing round the horn tips).
    speck = band & (alpha < 0.45) & (lum(col) > 90)
    alpha[speck] = 0
    alpha[alpha < 0.02] = 0
    # Only the figure's piece.
    lab, n = ndimage.label(alpha > 0.3, structure=np.ones((3, 3)))
    if n > 1:
        sizes = ndimage.sum(np.ones_like(alpha), lab, range(1, n + 1))
        keep = ndimage.binary_dilation(lab == (1 + int(np.argmax(sizes))), iterations=2)
        alpha[~keep] = 0
    col[alpha <= 0] = 0
    return col, alpha


def poly_mask(h, w, pts):
    m = np.zeros((h, w), np.uint8)
    cv2.fillPoly(m, [np.round(np.array(pts) * 8).astype(np.int32)], 1, lineType=cv2.LINE_8, shift=3)
    return m.astype(bool)


def hsv(rgb):
    mx, mn = rgb.max(axis=-1), rgb.min(axis=-1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return hue, (mx - mn) / np.maximum(mx, 1e-6), mx / 255.0


def segment(col, alpha):
    """Per px the part it belongs to (names; '' transparent), the horn mask and the outline mask."""
    h, w = alpha.shape
    solid = alpha > 0.5
    rim = solid & (ndimage.distance_transform_edt(solid) <= 2.5)  # the outer edge: outline whatever its un-mixed colour
    outline = solid & ((lum(col) < OUTLINE_LUM) | rim)
    cells, n = ndimage.label(solid & ~outline)
    ids = np.arange(1, n + 1)
    hue, sat, val = hsv(col)
    # The horns: gold / tan cells above HORN_BELOW, out of the gem and the eyes.
    cy = ndimage.mean(np.mgrid[0:h, 0:w][0].astype(float), cells, ids)
    cx = ndimage.mean(np.mgrid[0:h, 0:w][1].astype(float), cells, ids)
    goldish = (hue >= HORN_HUE[0]) & (hue <= HORN_HUE[1]) & (sat > 0.35) & (val > 0.55)
    gold_share = ndimage.mean(goldish.astype(float), cells, ids)
    horn_ids = [int(i) for i, s_, y_, x_ in zip(ids, gold_share, cy, cx)
                if s_ > 0.6 and y_ < HORN_BELOW and not (GEM_BOX[0] <= x_ <= GEM_BOX[2] and GEM_BOX[1] <= y_ <= GEM_BOX[3])
                and not (EYE_BOX[0] <= x_ <= EYE_BOX[2] and EYE_BOX[1] <= y_ <= EYE_BOX[3])]
    horn_cells = np.isin(cells, horn_ids)
    # the horns' own thin segment lines (dark brown, not the outline): cells inside the horns' hull
    hull = ndimage.binary_closing(horn_cells, structure=np.ones((3, 3)), iterations=6)
    inside = ndimage.mean(hull.astype(float), cells, ids)
    horn_cells |= np.isin(cells, [int(i) for i, s_ in zip(ids, inside) if s_ > 0.9])
    # Per px the first polygon holding it; the head = the helmet's polygon and the horn cells.
    names = ["head"] + list(PARTS) + ["chest"]
    idx = np.full((h, w), len(names) - 1, np.int16)
    for k in range(len(names) - 2, -1, -1):
        m = poly_mask(h, w, HELMET) if names[k] == "head" else poly_mask(h, w, PARTS[names[k]])
        idx[m] = k
    idx[horn_cells] = 0
    # A cell mostly (≥ 80 %) inside one part goes whole to it.
    for i in ids:
        sel = cells == i
        vals = idx[sel]
        counts = np.bincount(vals, minlength=len(names))
        k = int(np.argmax(counts))
        if counts[k] >= 0.8 * vals.size:
            idx[sel] = k
    label = np.full((h, w), -1, np.int16)
    label[solid & ~outline] = idx[solid & ~outline]
    # Specks (cells under 40 px, the outline's own noise): the part of the nearest big cell.
    sizes = ndimage.sum(np.ones((h, w)), cells, ids)
    small = np.isin(cells, ids[sizes < 40])
    big = (label >= 0) & ~small
    _, (iy, ix) = ndimage.distance_transform_edt(~big, return_indices=True)
    label[small] = label[iy[small], ix[small]]
    # The outline px: the front-most part with px within INK_W + 1.
    owner = np.full((h, w), -1, np.int16)
    for nm in reversed(OWN):
        k = names.index(nm)
        near = ndimage.binary_dilation(label == k, iterations=INK_W + 1)
        owner[near & outline] = k
    left = outline & (owner < 0)
    if left.any():  # outline far from any cell: the nearest labelled px
        _, (iy, ix) = ndimage.distance_transform_edt(label < 0, return_indices=True)
        owner[left] = label[iy[left], ix[left]]
    label[outline] = owner[outline]
    faint = (alpha > 0) & (label < 0)  # the soft edge: its nearest px's part
    _, (iy, ix) = ndimage.distance_transform_edt(~(label >= 0), return_indices=True)
    label[faint] = label[iy[faint], ix[faint]]
    part = {}
    for k, nm in enumerate(names):
        part[nm] = label == k
    return part, horn_cells, outline


def pm(colour, alpha):
    return np.dstack([colour * alpha[..., None], alpha]).astype(np.float32)


def over(dst, src):
    """src over dst (premultiplied float RGBA), in place."""
    a = src[..., 3:4]
    dst *= (1 - a)
    dst += src


def paint(h, w, poly, fill, ss=4):
    """A filled polygon with the bold outline (premultiplied RGBA, anti-aliased)."""
    pts = np.round(np.array(poly) * ss).astype(np.int32)
    big = np.zeros((h * ss, w * ss, 4), np.uint8)
    cv2.fillPoly(big, [pts], (*fill, 255))
    cv2.polylines(big, [pts], True, (*INK, 255), INK_W * ss, lineType=cv2.LINE_8)
    # Outline only inside the filled shape (as the art's outline sits on the edge).
    inside = np.zeros((h * ss, w * ss), np.uint8)
    cv2.fillPoly(inside, [pts], 1)
    grow = cv2.dilate(inside, np.ones((INK_W * ss // 2 + 1, INK_W * ss // 2 + 1), np.uint8))
    big[grow == 0] = 0
    small = cv2.resize(big.astype(np.float32) / 255.0, (w, h), interpolation=cv2.INTER_AREA)
    return np.dstack([small[..., :3] * 255.0, small[..., 3]]).astype(np.float32)  # colour 0 outside: premultiplied


def fill(h, w, poly, ss=4):
    """A polygon's coverage (0..1, anti-aliased), no outline."""
    big = np.zeros((h * ss, w * ss), np.uint8)
    cv2.fillPoly(big, [np.round(np.array(poly) * ss).astype(np.int32)], 255)
    return cv2.resize(big.astype(np.float32) / 255.0, (w, h), interpolation=cv2.INTER_AREA)


def seal(colour, alpha, mask, opaque, r=4):
    """Outline the cuts: the px of `mask` within r of a px opaque in the picture but not in `mask`."""
    cut = opaque & ~mask
    near = ndimage.binary_dilation(cut, iterations=r) & mask
    rim = mask & ~ndimage.binary_erosion(mask, iterations=r)
    ring = near & rim
    colour = colour.copy()
    colour[ring] = INK
    return colour


def stroke(h, w, pts, width, rgb, ss=4):
    big = np.zeros((h * ss, w * ss, 4), np.uint8)
    cv2.polylines(big, [np.round(np.array(pts) * ss).astype(np.int32)], False, (*rgb, 255), int(width * ss), lineType=cv2.LINE_AA)
    small = cv2.resize(big.astype(np.float32) / 255.0, (w, h), interpolation=cv2.INTER_AREA)
    return small  # straight rgb (0..1) and coverage


class Giant:
    def __init__(self, debug=None):
        rgb = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64)
        self.h, self.w = rgb.shape[:2]
        self.col, self.alpha = key(rgb)
        self.opaque = self.alpha > 0.5
        self.mask, self.horn_cells, self.outline = segment(self.col, self.alpha)
        h, w = self.h, self.w
        hue, sat, val = hsv(self.col)
        self.gem = poly_mask(h, w, [(GEM_BOX[0], GEM_BOX[1]), (GEM_BOX[2], GEM_BOX[1]), (GEM_BOX[2], GEM_BOX[3]), (GEM_BOX[0], GEM_BOX[3])]) \
            & (hue < 60) & (sat > 0.45) & (val > 0.6)
        self.eyes = poly_mask(h, w, [(EYE_BOX[0], EYE_BOX[1]), (EYE_BOX[2], EYE_BOX[1]), (EYE_BOX[2], EYE_BOX[3]), (EYE_BOX[0], EYE_BOX[3])]) \
            & (hue < 62) & (sat > 0.35) & (val > 0.6)
        carve = np.zeros((h, w), bool)
        for z in CARVE_ZONES:
            carve |= poly_mask(h, w, z)
        self.carve = carve & (lum(self.col) > CARVE_LUM) & ~self.gem & (sat < 0.4) & self.opaque
        self.layers = {}
        for nm in ORDER:
            self.layers[nm] = self._layer(nm)
        self._cache = {}
        if debug:
            self._debug(debug)

    def _layer(self, nm):
        """The part's own px (sealed cuts) over its painted underlay; premultiplied RGBA."""
        h, w = self.h, self.w
        own = self.mask[nm]
        # the outline px next to it that a part in front owns, so its edge has its own outline
        edge = self.outline & (ndimage.distance_transform_edt(~own) <= 4) & ~own
        m = own | edge
        a = np.where(m, self.alpha, 0.0)
        out = np.zeros((h, w, 4), np.float32)
        for poly, fill in UNDER.get(nm, []):
            over(out, paint(h, w, poly, fill))
        # The underlay only where a part in front hides it: never over the backdrop or a part behind.
        behind = np.zeros((h, w), bool)
        for other in ORDER[:ORDER.index(nm)]:
            behind |= self.mask[other]
        hidden = ndimage.binary_erosion(self.opaque, iterations=1) & ~behind
        out *= hidden[..., None]
        # Its cuts against the parts in front: an outline just past its edge, under them (hidden at
        # rest, its edge outlined once they move apart).
        front = np.zeros((h, w), bool)
        for other in ORDER[ORDER.index(nm) + 1:]:
            front |= self.mask[other]
        ring = ndimage.binary_dilation(m & self.opaque, iterations=4) & ~m & front & self.opaque
        over(out, pm(np.broadcast_to(np.array(INK, np.float64), (h, w, 3)), ring.astype(np.float64)))
        over(out, pm(self.col, a))
        # Dangling bits of outline (a neighbour's line ending on this part): an opening drops what
        # is thinner than the outline and sticks out; the part's own colour px always stay.
        if nm != "head":
            solid = (out[..., 3] > 0.3).astype(np.uint8)
            k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * INK_W + 1, 2 * INK_W + 1))
            keep = cv2.morphologyEx(solid, cv2.MORPH_OPEN, k).astype(bool) | (own & ~self.outline)
            keep = ndimage.binary_dilation(keep, iterations=1)
            out *= keep[..., None]
        return out

    # ── variants: what glows ──────────────────────────────────────────────
    def variant(self, nm, fx):
        key_ = (nm, round(fx.get("gem", 0.5), 2) if nm == "chest" else 0, round(fx.get("eyes", 1.0), 2) if nm == "head" else 0,
                round(fx.get("carve", 0.0), 2) if nm in ("chest", "pelvis") else 0, int(fx.get("crack", 0)),
                bool(fx.get("boulder")) if nm == "fist_r" else False)
        if key_ in self._cache:
            return self._cache[key_]
        lay = self.layers[nm].copy()
        h, w = self.h, self.w
        if nm == "chest":
            g = fx.get("gem", 0.5)
            lay = self._tint(lay, self.gem, (255, 248, 190), 0.55 * g)
            lay = self._tint(lay, self.gem, (190, 120, 30), 0.45 * max(0.0, 0.35 - g))
        if nm == "head":
            e = fx.get("eyes", 1.0)
            lay = self._tint(lay, self.eyes, (255, 250, 210), 0.5 * max(0.0, e - 0.6))
            lay = self._tint(lay, self.eyes, (90, 70, 30), 0.85 * max(0.0, 0.6 - e) / 0.6)
        c = fx.get("carve", 0.0)
        if c > 0 and nm in ("chest", "pelvis"):
            m = self.carve & self.mask[nm]
            lay = self._tint(lay, m, GOLD, min(1.0, c * 1.1))
            glow = ndimage.gaussian_filter(m.astype(np.float32), 3.0) * 2.2 * c
            glow = np.clip(glow, 0, 0.8) * (lay[..., 3] > 0.5)
            lay[..., :3] = lay[..., :3] * (1 - glow[..., None]) + np.array(GOLD, np.float32) * glow[..., None] * lay[..., 3:4]
        k = int(fx.get("crack", 0))
        if k > 0:
            lay = self._cracks(lay, k)
        if nm == "fist_r" and fx.get("boulder"):
            under = np.zeros_like(lay)
            over(under, self._boulder())
            over(under, lay)
            lay = under
        self._cache[key_] = lay
        return lay

    @staticmethod
    def _tint(lay, mask, rgb, k):
        if k <= 0:
            return lay
        lay = lay.copy()
        m = mask.astype(np.float32)[..., None] * k
        lay[..., :3] = lay[..., :3] * (1 - m) + np.array(rgb, np.float32) * lay[..., 3:4] * m
        return lay

    def _cracks(self, lay, stage):
        h, w = self.h, self.w
        lay = lay.copy()
        solid = lay[..., 3] > 0.6
        for st, pts in CRACKS:
            if st > stage:
                continue
            dark = stroke(h, w, pts, 7.5, INK)
            core = stroke(h, w, pts, 2.6, AMBER)
            halo = ndimage.gaussian_filter(core[..., 3], 3.0) * 0.6
            for cov, rgb in ((np.clip(halo, 0, 1), (255, 150, 40)), (dark[..., 3], INK), (core[..., 3], AMBER)):
                cov = cov * solid
                lay[..., :3] = lay[..., :3] * (1 - cov[..., None]) + np.array(rgb, np.float32) * cov[..., None] * lay[..., 3:4]
        return lay

    def _boulder(self):
        """A rough boulder held in the throwing fist (beyond its knuckles at rest), straight from the art's palette."""
        h, w = self.h, self.w
        cx, cy = J["fist_r"][0] + 6, J["fist_r"][1] + 58
        rng = np.random.default_rng(7)
        pts = [(cx + 66 * (1 + 0.1 * rng.uniform(-1, 1)) * math.cos(a), cy + 58 * (1 + 0.1 * rng.uniform(-1, 1)) * math.sin(a))
               for a in np.linspace(0, 2 * math.pi, 11)[:-1]]
        out = paint(h, w, pts, (122, 100, 80))
        inner = ndimage.binary_erosion(out[..., 3] > 0.99, iterations=INK_W // 2 + 1).astype(np.float32)
        inner = ndimage.gaussian_filter(inner, 0.7)
        for poly, rgb in (([(cx - 70, cy + 6), (cx + 70, cy - 4), (cx + 70, cy + 70), (cx - 70, cy + 70)], (92, 74, 60)),
                          ([(cx - 36, cy - 30), (cx - 8, cy - 44), (cx + 20, cy - 36), (cx - 14, cy - 22)], (170, 148, 122))):
            m = fill(h, w, poly) * inner
            out[..., :3] = out[..., :3] * (1 - m[..., None]) + np.array(rgb, np.float32) * m[..., None]
        # a crack line across it, in the outline colour
        line = stroke(h, w, [(cx - 20, cy - 52), (cx - 6, cy - 20), (cx + 18, cy - 6)], 4.0, INK)[..., 3] * inner
        out[..., :3] = out[..., :3] * (1 - line[..., None]) + np.array(INK, np.float32) * line[..., None]
        return out

    # ── posing ───────────────────────────────────────────────────────────
    def world(self, pose):
        """Per part its 3 × 3 transform (source px → source px) for the pose."""
        mats = {}
        for nm in RIG:
            parent, joint = RIG[nm]
            p = pose.get(nm, {})
            jx, jy = J[joint]
            rot = math.radians(p.get("rot", 0.0))
            sx, sy = p.get("sx", 1.0), p.get("sy", 1.0)
            c, s = math.cos(rot), math.sin(rot)
            local = np.array([[1, 0, jx + p.get("dx", 0.0)], [0, 1, jy + p.get("dy", 0.0)], [0, 0, 1]]) @ \
                np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]]) @ np.diag([sx, sy, 1.0]) @ \
                np.array([[1, 0, -jx], [0, 1, -jy], [0, 0, 1]])
            mats[nm] = (mats[parent] if parent else np.eye(3)) @ local
        return mats

    def point(self, pose, part, xy):
        m = self.world(pose)[part]
        v = m @ np.array([xy[0], xy[1], 1.0])
        return float(v[0]), float(v[1])

    def frame(self, pose, size=CELL, feet_at=CELL_FEET):
        """The pose drawn in a cell (premultiplied RGBA), the feet at feet_at."""
        mats = self.world(pose)
        fx = pose.get("fx", {})
        shift = np.array([[1, 0, feet_at[0] - FEET[0]], [0, 1, feet_at[1] - FEET[1]], [0, 0, 1]])
        out = np.zeros((size[1], size[0], 4), np.float32)
        order = list(ORDER)
        for arm in ("l", "r"):
            if pose.get("front_" + arm):
                for nm in ("fist_" + arm, "fore_" + arm):
                    order.remove(nm)
                    order.append(nm)
        only = pose.get("only")
        for nm in order:
            if only is not None and nm not in only:
                continue
            lay = self.variant(nm, fx)
            m = (shift @ mats[nm])[:2]
            warped = cv2.warpAffine(lay, m, size, flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
            over(out, warped)
        if only is None:
            self._halos(out, pose, mats, shift, fx)
        return out

    def _halos(self, out, pose, mats, shift, fx):
        g = fx.get("gem", 0.5)
        flare = fx.get("flare", 0.0)
        gx, gy = (shift @ mats["chest"] @ np.array([*GEM, 1.0]))[:2]
        glow(out, gx, gy, 46 + 30 * g + 150 * flare, (255, 196, 70), 0.18 + 0.35 * g + 0.5 * flare)
        if flare > 0:
            glow(out, gx, gy, 30 + 30 * flare, (255, 250, 220), 0.7 * flare)
        e = fx.get("eyes", 1.0)
        if e > 0.6:
            for ex, ey in EYES:
                px, py = (shift @ mats["head"] @ np.array([ex, ey, 1.0]))[:2]
                glow(out, px, py, 20 + 10 * e, (255, 236, 120), 0.35 * (e - 0.6) / 0.4)


def glow(dst, cx, cy, r, colour, strength):
    """A soft round glow over dst (premultiplied), its alpha added where the figure is not."""
    h, w = dst.shape[:2]
    x0, x1 = max(0, int(cx - r)), min(w, int(cx + r) + 1)
    y0, y1 = max(0, int(cy - r)), min(h, int(cy + r) + 1)
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    a = np.clip(1 - d, 0, 1) ** 2 * strength
    sub = dst[y0:y1, x0:x1]
    src = np.dstack([np.array(colour, np.float32)[None, None, :] / 255.0 * 255.0 * a[..., None], a]).astype(np.float32)
    # screen-like: lighten the figure, add alpha outside
    sub[..., :3] = sub[..., :3] + src[..., :3] * (1 - sub[..., :3] / 255.0)
    sub[..., 3] = sub[..., 3] + a * (1 - sub[..., 3])


# ── poses ────────────────────────────────────────────────────────────────────
def arm(side, raise_=0.0, flex=0.0, wrist=0.0, pauldron=0.35):
    """An arm's pose: raise (degrees, outward / up, 0 hanging), flex (the elbow, the forearm toward
    the body), wrist; the shoulder pad follows `pauldron` of the raise."""
    s = 1.0 if side == "l" else -1.0
    return {"upper_" + side: {"rot": s * raise_}, "fore_" + side: {"rot": -s * flex}, "fist_" + side: {"rot": -s * wrist},
            "pauldron_" + side: {"rot": s * raise_ * (pauldron if side == "l" else pauldron * 0.6) if raise_ > 0 else s * raise_ * 0.15}}


def pose(root=(0, 0, 0), drop=0.0, hip_dx=0.0, chest=(0, 0, 0, 1.0), head=(0, 0, 0), arm_l=(0, 0), arm_r=(0, 0),
         leg_l=(0, 0, 0, 1.0), leg_r=(0, 0, 0, 1.0), fx=None, **extra):
    """root (dx, dy, rot round the feet), drop (the pelvis lowered, px), chest (dx, dy, rot, sy),
    head (dx, dy, rot), arm_* (raise, flex[, wrist]), leg_* (dx, dy, rot, sy round the hip: a lifted
    leg is shortened, its knee toward the viewer)."""
    p = {"root": {"dx": root[0], "dy": root[1], "rot": root[2]},
         "pelvis": {"dx": hip_dx, "dy": drop},
         "chest": {"dx": chest[0], "dy": chest[1], "rot": chest[2], "sy": chest[3]},
         "head": {"dx": head[0], "dy": head[1], "rot": head[2]},
         "leg_l": {"dx": leg_l[0], "dy": leg_l[1], "rot": leg_l[2], "sy": leg_l[3]},
         "leg_r": {"dx": leg_r[0], "dy": leg_r[1], "rot": leg_r[2], "sy": leg_r[3]}}
    p.update(arm("l", *arm_l))
    p.update(arm("r", *arm_r))
    p["fx"] = dict({"gem": 0.5, "eyes": 1.0}, **(fx or {}))
    p.update(extra)
    return p


REST = pose()


def idle_frames(n=10):
    out = []
    for i in range(n):
        t = i / n * 2 * math.pi
        b = math.sin(t)  # the breath: in at the top
        out.append(pose(drop=-1.0 * b, chest=(0, -2.5 * b, 0.0, 1.0 + 0.008 * b), head=(0, -2.0 * math.sin(t - 0.5), 0.4 * math.sin(t - 0.8)),
                        arm_l=(1.2 + 1.2 * math.sin(t - 0.6), 1.0 * math.sin(t - 1.0)), arm_r=(1.2 + 1.2 * math.sin(t - 0.6), 1.0 * math.sin(t - 1.0)),
                        fx={"gem": 0.45 + 0.4 * (0.5 + 0.5 * math.sin(t - 0.4)),
                            "eyes": 0.35 if i == 6 else (0.75 if i in (5, 7) else 1.0)}))
    return out


ANIMS = {
    # name: (frames, fps, loop, peak)
    "idle": (idle_frames(), 5, True, None),
    "throw": ([
        REST,
        pose(chest=(0, 0, -2, 1.0), arm_r=(70, 35), arm_l=(10, 5), fx={"boulder": True}),
        pose(chest=(-4, 0, -5, 1.0), head=(0, 0, -2), arm_r=(165, 60), arm_l=(22, 10), fx={"boulder": True}),
        pose(drop=-4, chest=(-8, 0, -8, 1.0), head=(-2, 0, -4), arm_r=(205, 80), arm_l=(30, 12), fx={"boulder": True, "gem": 0.8}),
        pose(root=(10, 0, 0), drop=6, chest=(8, 0, 7, 1.0), head=(3, 2, 4), arm_r=(118, 0), arm_l=(12, 20), front_r=True,
             fx={"gem": 0.9}),
        pose(root=(12, 0, 0), drop=8, chest=(8, 0, 9, 1.0), head=(3, 3, 5), arm_r=(62, 10), arm_l=(6, 15), front_r=True),
        pose(root=(5, 0, 0), drop=3, chest=(3, 0, 4, 1.0), head=(1, 1, 2), arm_r=(22, 6), arm_l=(2, 6)),
        REST], 10, False, 4),
    "roll": ([
        REST,
        pose(drop=10, chest=(0, 6, 0, 0.96), head=(0, 10, 0), arm_l=(-14, 30), arm_r=(-14, 30)),
        pose(drop=26, chest=(0, 14, 0, 0.92), head=(0, 24, 0), arm_l=(-26, 62), arm_r=(-26, 62), fx={"gem": 0.7}),
        pose(root=(26, 0, 0), drop=22, chest=(6, 12, 6, 0.93), head=(6, 20, 3), arm_l=(-58, 18), arm_r=(32, 4), front_l=True,
             fx={"gem": 0.9}),
        pose(root=(28, 0, 0), drop=20, chest=(6, 11, 6, 0.93), head=(6, 18, 3), arm_l=(-60, 14), arm_r=(36, 2), front_l=True),
        pose(root=(12, 0, 0), drop=8, chest=(2, 4, 2, 0.97), head=(2, 7, 1), arm_l=(-20, 10), arm_r=(10, 4)),
        REST], 9, False, 3),
    "stomp": ([
        REST,
        pose(hip_dx=-10, chest=(-4, 0, -3, 1.0), head=(-2, 0, -1), arm_l=(14, 10), arm_r=(20, 12), leg_r=(0, -6, 0, 1.0)),
        pose(hip_dx=-16, drop=-8, chest=(-6, 0, -5, 1.0), head=(-3, 0, -2), arm_l=(34, 26), arm_r=(42, 30),
             leg_r=(4, -26, -5, 0.78)),
        pose(hip_dx=-18, drop=-12, chest=(-7, 0, -6, 1.0), head=(-3, -2, -3), arm_l=(44, 32), arm_r=(54, 36),
             leg_r=(6, -34, -7, 0.68), fx={"gem": 0.7}),
        pose(drop=20, chest=(0, 6, 0, 0.96), head=(0, 10, 0), arm_l=(8, 6), arm_r=(10, 6), fx={"gem": 0.9}),
        pose(root=(7, 3, 0), drop=16, chest=(0, 5, 1, 0.97), head=(2, 8, 2), arm_l=(10, 8), arm_r=(6, 6)),
        pose(root=(-6, 2, 0), drop=12, chest=(0, 4, -1, 0.98), head=(-2, 6, -2), arm_l=(5, 5), arm_r=(9, 6)),
        pose(root=(3, 1, 0), drop=5, chest=(0, 2, 0, 0.99), head=(1, 3, 1), arm_l=(3, 3), arm_r=(3, 3)),
        REST], 10, False, 4),
    "spikes": ([
        REST,
        pose(drop=-4, arm_l=(95, 35), arm_r=(95, 35), head=(0, -2, 0), fx={"carve": 0.25, "gem": 0.6}),
        pose(drop=-8, chest=(0, -3, 0, 1.01), head=(0, -5, 0), arm_l=(124, 52), arm_r=(124, 52), fx={"carve": 0.55, "gem": 0.75}),
        pose(drop=58, chest=(0, 12, 4, 0.93), head=(0, 20, 2), arm_l=(-14, -10, -8), arm_r=(-12, -6, -8),
             fx={"carve": 1.0, "gem": 1.0}),
        pose(root=(0, 3, 0), drop=58, chest=(0, 12, 4, 0.93), head=(0, 21, 2), arm_l=(-14, -10, -8), arm_r=(-12, -6, -8),
             fx={"carve": 1.0, "gem": 0.9}),
        pose(drop=22, chest=(0, 5, 1, 0.97), head=(0, 8, 0), arm_l=(4, 4), arm_r=(4, 4), fx={"carve": 0.55, "gem": 0.6}),
        pose(fx={"carve": 0.2}),
        ], 9, False, 3),
    "summon": ([
        REST,
        pose(arm_l=(70, 22), arm_r=(70, 22), fx={"gem": 0.7, "flare": 0.15}),
        pose(drop=-6, chest=(0, -4, 0, 1.02), head=(0, -6, 0), arm_l=(118, 34), arm_r=(118, 34), fx={"gem": 1.0, "flare": 1.0}),
        pose(drop=-7, chest=(0, -5, 0, 1.02), head=(0, -7, 0), arm_l=(122, 30), arm_r=(122, 30), fx={"gem": 1.0, "flare": 0.7}),
        pose(arm_l=(60, 20), arm_r=(60, 20), fx={"gem": 0.7, "flare": 0.2}),
        REST], 7, False, 2),
    "hurt": ([
        pose(root=(-12, 0, -3), drop=6, chest=(-4, 4, -4, 0.97), head=(-4, 6, -9), arm_l=(22, 18), arm_r=(16, 14),
             fx={"eyes": 0.5, "gem": 0.3}),
        pose(root=(-5, 0, -1), drop=2, chest=(-1, 1, -1, 0.99), head=(-1, 2, -3), arm_l=(8, 6), arm_r=(6, 5)),
        ], 7, False, None),
    "death": ([
        pose(root=(-8, 0, -2), drop=6, chest=(-3, 4, -3, 0.97), head=(-3, 6, -6), arm_l=(14, 12), arm_r=(10, 10),
             fx={"crack": 1, "gem": 0.8, "eyes": 0.75}),
        pose(root=(-4, 0, -1), drop=12, chest=(-2, 8, 2, 0.96), head=(-2, 12, 4), arm_l=(6, 6), arm_r=(4, 6),
             fx={"crack": 2, "gem": 0.6, "eyes": 0.5}),
        pose(root=(0, 0, 0), drop=18, chest=(0, 12, 4, 0.95), head=(0, 18, 7), arm_l=(2, 4), arm_r=(0, 4),
             fx={"crack": 3, "gem": 0.15, "eyes": 0.0}),
        ], 6, False, None),
}
DEATH_POSE = ANIMS["death"][0][-1]
# The death's pieces, back to front (each a part, or a split of one, in DEATH_POSE).
PIECES = ["upper_l", "upper_r", "leg_l", "leg_r", "pelvis", "pelvis_r", "chest", "chest_l", "chest_r", "pauldron_l",
          "pauldron_r", "fist_l", "fore_l", "fist_r", "fore_r", "horn_l", "horn_r", "helmet"]
# The skinned idle (on skin/rest_v1.png: the rest pose in a cell): its joints (source px) and bones.
SKIN_JOINTS = {"hips": (722, 500), "neck": (742, 300), "crown": (742, 108), "shoulder_l": (552, 352), "elbow_l": (470, 432),
               "fist_l": (462, 590), "shoulder_r": (866, 352), "elbow_r": (904, 432), "fist_r": (922, 584),
               "horn_l_root": (680, 150), "horn_l_tip": (452, 190), "horn_r_root": (806, 150), "horn_r_tip": (930, 190),
               "knee_l": (590, 600), "knee_r": (830, 600), "crystal": GEM}
SKIN_BONES = [["root", "", "feet", "hips", 0], ["leg_l", "root", "hips", "knee_l", 0.6], ["leg_r", "root", "hips", "knee_r", 0.6],
              ["torso", "root", "hips", "neck", 1.5], ["head", "torso", "neck", "crown", 3],
              ["horn_l", "head", "horn_l_root", "horn_l_tip", 3], ["horn_r", "head", "horn_r_root", "horn_r_tip", 3],
              ["arm_l", "torso", "shoulder_l", "elbow_l", 1.5], ["fore_l", "arm_l", "elbow_l", "fist_l", 2],
              ["arm_r", "torso", "shoulder_r", "elbow_r", 1.5], ["fore_r", "arm_r", "elbow_r", "fist_r", 2]]
# Its breath (tools/import_boss_frames.gd "tracks": per bone a sine of the loop: rot degrees, y of
# the height (up), sy, lag radians behind the breath).
SKIN_TRACKS = {"period": 2.6, "keys": 14, "bones": {
    "torso": {"rot": 0.25, "lag": 0.0, "sy": 0.008},
    "head": {"rot": 0.6, "lag": 0.6, "y": 0.003},
    "arm_l": {"rot": -0.9, "lag": 0.6}, "arm_r": {"rot": 0.9, "lag": 0.6},
    "fore_l": {"rot": 1.0, "lag": 1.0}, "fore_r": {"rot": -1.0, "lag": 1.0}}}


def unpm(layer):
    a = layer[..., 3:4]
    rgb = np.where(a > 1e-4, layer[..., :3] / np.maximum(a, 1e-4), 0)
    return np.dstack([np.clip(rgb, 0, 255), np.clip(a * 255, 0, 255)]).astype(np.uint8)


def halve(layer):
    h, w = layer.shape[:2]
    return cv2.resize(layer, (w // HALF, h // HALF), interpolation=cv2.INTER_AREA)


def save(img, rel):
    path = os.path.join(HERE, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    (img if isinstance(img, Image.Image) else Image.fromarray(img)).save(path, optimize=True)
    print("  wrote", rel)


def sheet(frames):
    cw, ch = CELL[0] // HALF, CELL[1] // HALF
    out = np.zeros((ch, cw * len(frames), 4), np.float32)
    for i, f in enumerate(frames):
        out[:, i * cw:(i + 1) * cw] = halve(f)
    return unpm(out)


def unit(p):
    """Source px → the unit frame (the body 100 tall, the feet at the origin, facing right)."""
    return [round((p[0] - FEET[0]) / BODY_H * 100, 2), round((p[1] - FEET[1]) / BODY_H * 100, 2)]


def pieces(g):
    """The death's pieces in DEATH_POSE, each a full cell (premultiplied), in PIECES order."""
    out = {}
    mats = g.world(DEATH_POSE)
    for nm in ORDER:
        lay = g.variant(nm, DEATH_POSE["fx"])
        splits = SPLITS.get(nm, {})
        rest = lay[..., 3] > 0
        subs = {}
        if nm == "head":
            horn = ndimage.binary_dilation(g.horn_cells, iterations=INK_W) & (lay[..., 3] > 0) & ~poly_mask(g.h, g.w, HELMET)
            xs = np.mgrid[0:g.h, 0:g.w][1]
            subs = {"horn_l": horn & (xs < GEM[0]), "horn_r": horn & (xs >= GEM[0])}
            rest = rest & ~horn
            name_rest = "helmet"
        else:
            for sn, poly in splits.items():
                m = poly_mask(g.h, g.w, poly) & rest
                subs[sn] = m
                rest = rest & ~m
            name_rest = nm
        subs[name_rest] = rest
        opaque = lay[..., 3] > 0.5
        for sn, m in subs.items():
            # specks (bits of outline the split leaves): only pieces of at least 2 % of the largest
            lab, n = ndimage.label(m & (lay[..., 3] > 0.05), structure=np.ones((3, 3)))
            if n > 1:
                sizes = ndimage.sum(np.ones(m.shape), lab, range(1, n + 1))
                keep = np.isin(lab, 1 + np.nonzero(sizes >= 0.02 * sizes.max())[0])
                m = m & ndimage.binary_dilation(keep, iterations=1)
            piece = lay * m[..., None]
            colour = unpm(piece)[..., :3].astype(np.float64)
            a = piece[..., 3]
            colour = seal(colour, a, m & opaque, opaque, r=4)
            piece = pm(colour, a)
            out[sn] = (nm, piece)
    cells = {}
    for sn in PIECES:
        nm, piece = out[sn]
        shift = np.array([[1, 0, CELL_FEET[0] - FEET[0]], [0, 1, CELL_FEET[1] - FEET[1]], [0, 0, 1]])
        m = (shift @ mats[nm])[:2]
        cells[sn] = cv2.warpAffine(piece, m, CELL, flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    return cells


def debug_out(g, d):
    os.makedirs(d, exist_ok=True)
    for nm, c in (("dark", (30, 30, 40)), ("orange", (255, 140, 0))):
        base = np.ones((g.h, g.w, 3)) * np.array(c)
        a = g.alpha[..., None]
        Image.fromarray((g.col * a + base * (1 - a)).astype(np.uint8)).save(os.path.join(d, f"keyed_{nm}.png"))
    rng = np.random.default_rng(3)
    vis = np.zeros((g.h, g.w, 3))
    for nm, m in g.mask.items():
        vis[m] = rng.integers(60, 255, 3)
    vis[g.outline] *= 0.4
    vis[g.carve] = (255, 255, 0)
    vis[g.gem] = (255, 0, 0)
    vis[g.eyes] = (0, 255, 0)
    Image.fromarray(vis.astype(np.uint8)).save(os.path.join(d, "parts_map.png"))
    tiles = []
    for nm in ORDER:
        lay = g.layers[nm]
        bg = np.ones((g.h, g.w, 4), np.float32) * np.array([255, 140, 0, 255], np.float32) / np.array([1, 1, 1, 255])
        bg[..., 3] = 1
        comp = bg.copy()
        comp[..., :3] *= 0.35
        over(comp, lay)
        ys, xs = np.nonzero(lay[..., 3] > 0.05)
        crop = comp[max(0, ys.min() - 6):ys.max() + 6, max(0, xs.min() - 6):xs.max() + 6, :3]
        Image.fromarray(np.clip(crop, 0, 255).astype(np.uint8)).save(os.path.join(d, f"part_{nm}.png"))
    # The rest pose against the keyed picture: what the underlays or the cuts change (red).
    rest = g.frame(pose(fx={"gem": 0.5, "eyes": 1.0}), size=(g.w, g.h), feet_at=FEET)
    src = pm(g.col, g.alpha)
    diff = np.abs(rest - src).max(axis=2)
    vis = unpm(rest)[..., :3].astype(np.float32) * 0.5
    vis[diff > 60] = (255, 0, 0)
    Image.fromarray(vis.astype(np.uint8)).save(os.path.join(d, "rest_diff.png"))
    Image.fromarray(unpm(rest)).save(os.path.join(d, "rest.png"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--debug")
    ap.add_argument("--check", action="store_true", help="with --debug: only the debug pictures and the rest check")
    ap.add_argument("--preview", help="with --debug: only these animations (comma separated), as one strip each")
    args = ap.parse_args()
    g = Giant()
    if args.preview and args.debug:
        os.makedirs(args.debug, exist_ok=True)
        for anim in args.preview.split(","):
            fs = [unpm(g.frame(p)) for p in ANIMS[anim][0]]
            strip = np.concatenate([f[180:] for f in fs], axis=1)
            bg = np.ones(strip.shape[:2] + (3,)) * np.array([70, 110, 160])
            a = strip[..., 3:4] / 255.0
            Image.fromarray((strip[..., :3] * a + bg * (1 - a)).astype(np.uint8)).save(os.path.join(args.debug, f"strip_{anim}.png"))
        return
    if args.debug:
        debug_out(g, args.debug)
        if args.check:
            return
    frames = {}
    for anim, (poses, fps, loop, peak) in ANIMS.items():
        frames[anim] = [g.frame(p) for p in poses]
        save(sheet(frames[anim]), f"side_{anim}/sheet_v1.png")
    # The union of every frame (a check that the cell holds them).
    used = np.zeros(CELL[::-1], bool)
    for fs in frames.values():
        for f in fs:
            used |= f[..., 3] > 0.02
    ys, xs = np.nonzero(used)
    print(f"  frames' union in the cell: x {xs.min()}..{xs.max()}, y {ys.min()}..{ys.max()} (cell {CELL}, feet {CELL_FEET})")
    assert xs.min() > 2 and ys.min() > 2 and xs.max() < CELL[0] - 3 and ys.max() < CELL[1] - 3, "a frame leaves the cell"
    rest = g.frame(pose(fx={"gem": 0.55, "eyes": 1.0}))
    rx = np.nonzero((rest[..., 3] > 0.5).any(axis=0))[0]
    rest_w = rx.max() - rx.min() + 1
    save(unpm(rest), "skin/rest_v1.png")
    portrait = g.frame(pose(fx={"gem": 0.8, "eyes": 1.0}))
    save(unpm(portrait), "portrait/portrait_v1.png")
    # The bust: the head (helmet and horns) with the top of the chest and the pads, cut under the gem's top.
    bust = g.frame(pose(fx={"gem": 0.8, "eyes": 1.0}))
    cut = int(CELL_FEET[1] - FEET[1] + 352)
    fade = 14
    ramp = np.clip((cut - np.arange(CELL[1])) / fade, 0, 1).astype(np.float32)
    bust *= ramp[:, None, None]
    save(unpm(bust), "portrait/bust_v1.png")
    cells = pieces(g)
    for sn in PIECES:
        save(unpm(halve(cells[sn])), f"parts/{sn}_v1.png")
    # The points the game needs.
    peak = ANIMS["throw"][0][ANIMS["throw"][3]]
    hand = g.point(peak, "fist_r", (J["fist_r"][0] + 6, J["fist_r"][1] + 30))
    rig = {
        "_doc": "Written by make_frames.py (do not edit). Source px of concept/ram_golem_v1.png (the body: TOP → FEET, 660 px) and the unit frame BossArt draws in (the body 100 tall, the feet at the origin, facing right, y down).",
        "feet": list(FEET), "top": TOP, "bodyHeight": BODY_H,
        "heart": {"src": list(GEM), "unit": unit(GEM)},
        "throwHand": {"src": [round(hand[0], 1), round(hand[1], 1)], "unit": unit(hand), "frame": ANIMS["throw"][3]},
        "eyes": {"src": [list(e) for e in EYES], "unit": [unit(e) for e in EYES]},
        "width": round(float(rest_w) / BODY_H, 3),
    }
    with open(os.path.join(HERE, "rig_v1.json"), "w") as f:
        json.dump(rig, f, indent="\t")
        f.write("\n")
    print("  rig:", json.dumps(rig))
    write_frame_points(g)
    write_import(frames)


# Per frame, where the game attaches its own drawings (the unit frame: the body 100 tall, the feet at
# the origin, facing right, y down; mirror x when it faces left): the gem (heals and drains glow there),
# both fists (the boulder of the throw leaves the right one at the throw's peak), the eyes' middle, and
# the parts the totems' stone plates sit on (chest, shoulder pads, belt: their joint's place and turn,
# degrees, so a plate drawn at rest round that joint follows the frame).
POINT_PARTS = {"chest": "belly", "pauldron_l": "shoulder_l", "pauldron_r": "shoulder_r", "pelvis": "waist", "head": "neck"}


def write_frame_points(g):
    def ang(m):
        return round(math.degrees(math.atan2(m[1, 0], m[0, 0])), 2)
    frames = {}
    for anim, (poses, fps, loop, peak) in ANIMS.items():
        rows = []
        for p in poses:
            mats = g.world(p)
            row = {"heart": unit(g.point(p, "chest", GEM)),
                   "fist_l": unit(g.point(p, "fist_l", J["fist_l"])), "fist_r": unit(g.point(p, "fist_r", J["fist_r"])),
                   "hand_r": unit(g.point(p, "fist_r", (J["fist_r"][0] + 6, J["fist_r"][1] + 30))),
                   "eyes": unit(g.point(p, "head", ((EYES[0][0] + EYES[1][0]) / 2, (EYES[0][1] + EYES[1][1]) / 2)))}
            for part, joint in POINT_PARTS.items():
                row[part] = unit(g.point(p, part, J[joint])) + [ang(mats[part])]
            rows.append(row)
        frames[anim] = rows
    rest = {part: unit(J[joint]) for part, joint in POINT_PARTS.items()}
    out = {"_doc": "Written by art_source/bosses/rock_giant/make_frames.py (do not edit). Khổng Lồ Đá's points per frame of side.json, in the unit frame BossArt draws in (the body 100 tall = side.json height, the feet at the origin, facing right, y down; mirror x when it faces left): heart = the chest gem (heal / drain glow), fist_l / fist_r = the fists' centres, hand_r = the right fist's knuckles (the throw's boulder leaves it at throw's peak frame), eyes = between the eyes, chest / pauldron_l / pauldron_r / pelvis / head = [x, y, degrees]: that part's joint now and its turn (a plate drawn at rest round restJoints[part] follows the frame: move it by now - rest, turn it round now by the degrees).",
           "restJoints": rest, "frames": frames}
    path = os.path.join(HERE, "..", "..", "..", "assets", "bosses", "rock_giant", "side", "points.json")
    with open(os.path.normpath(path), "w") as f:
        f.write(json.dumps(out, ensure_ascii=False) + "\n")
    print("  wrote assets/bosses/rock_giant/side/points.json")


def write_import(frames):
    cw, ch = CELL[0] // HALF, CELL[1] // HALF
    fx, fy = CELL_FEET[0] / HALF, CELL_FEET[1] / HALF
    anims = {}
    for anim, (poses, fps, loop, peak) in ANIMS.items():
        n = len(poses)
        a = {"src": f"side_{anim}/sheet_v1.png", "frames": n, "fps": fps, "loop": loop, "bodyHeight": BODY_H / HALF,
             "cuts": [cw * i for i in range(1, n)], "anchors": [[fx + cw * i, fy] for i in range(n)]}
        if peak is not None:
            a["peak"] = peak
        anims[anim] = a
    off = (CELL_FEET[0] - FEET[0], CELL_FEET[1] - FEET[1])
    joints = {k: [v[0] + off[0], v[1] + off[1]] for k, v in SKIN_JOINTS.items()}
    cfg = {
        "_doc": "Written by make_frames.py here (do not edit: edit the script and re-run it). tools/import_boss_frames.gd reads it (see its header and README.txt here). The sheets are already transparent (background.key 'alpha'), one row per animation in fixed %d x %d cells with the feet (the midpoint between the soles) at (%g, %g) of every cell: cuts at the cells, anchors the feet, bodyHeight %g (the horns' top to the feet, sheet px) -> height texture px. body: every colour (measured only for the width). skins.idle: the rest pose (skin/rest_v1.png, full size) on a skeleton: joints (that picture's px), bones, feet / bodyHeight given, tracks (the breath: a sine per bone). parts: the death's pieces in the last death frame's pose, one cell each at the frames' scale (feet given), back to front." % (cw, ch, fx, fy, BODY_H / HALF),
        "out": "res://assets/bosses/rock_giant/",
        "height": 320,
        "pad": 4,
        "background": {"key": "alpha"},
        "alphaCut": 6,
        "edgeFade": 0,
        "body": {"hue": [0, 360], "minSat": 0.0, "minVal": 0.12, "maxVal": 1.0, "centreRows": [0.45, 0.7], "minPiece": 0.08},
        "anims": anims,
        "skins": {"idle": {"motion": "breath", "src": "skin/rest_v1.png", "height": 360, "pad": 6,
                           "feet": [CELL_FEET[0], CELL_FEET[1]], "bodyHeight": BODY_H,
                           "glow": {"joint": "crystal", "bone": "torso", "colour": [1.0, 0.76, 0.24]},
                           "eyes": [[e[0] + off[0], e[1] + off[1]] for e in EYES],
                           "joints": joints, "bones": SKIN_BONES, "tracks": SKIN_TRACKS}},
        "parts": {"bodyHeight": BODY_H / HALF, "feet": [fx, fy], "src": {sn: f"parts/{sn}_v1.png" for sn in PIECES}},
        "pictures": {
            "portrait": {"src": "portrait/portrait_v1.png", "size": 512, "margin": 8},
            "bust": {"src": "portrait/bust_v1.png", "size": 384, "margin": 6},
        },
    }
    with open(os.path.join(HERE, "import.json"), "w") as f:
        f.write(json.dumps(cfg, indent="\t", ensure_ascii=False) + "\n")
    print("  wrote import.json")


if __name__ == "__main__":
    main()
