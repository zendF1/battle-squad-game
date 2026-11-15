#!/usr/bin/env python3
"""Tide's chibi bone rig (matches only: scenes/character/character.gd match_rig), the same rig as
Rookie's, Spark's, Tanko's and Flora's (../../flora/rig/make_rig.py: the same steps, parts, bones and draw
order), made from the one picture ../side_idle/idle_v2.png (797 x 969, pure white backdrop, 3/4 facing
right, standing, open hands down, no gun; made chibi from the user's picture by
../side_idle/chibi_edit/make_chibi.py):

  0. the chibi edit's two seams mended: the head layer over the neck (the shaded neck above y 510 against
     the light neck under it, the neck's front outline jogging there) and the shorts' trim over the legs
     (a faint line across the teal band at y 735);
  1. keyed: the white backdrop (the light px joined to the picture's border, the gap between the near arm
     and the waist, the gap between the legs) removed by flood from the border, not by a threshold (the
     near-white shirt, shorts and boots are inside their outlines), the soft outline edge un-mixed against
     the white (no grey fringe), the speckle dropped (only the figure's one blob kept);
  2. cut: the picture split into its flat-colour cells (between the dark outlines), each cell given to
     a part by PARTS (a cell mostly inside one polygon goes whole; a cell across two is cut px by px
     along them; the head's polygon cuts px by px: the shaded neck is one cell with the face); the outline
     px between two parts belong to the one in front (OWN). The bob ride the head (rigid, its back part
     too); the sleeves the upper arms; the knee pads the thighs; the open hands stay open (n_fist, f_fist);
  3. the hidden areas painted (UNDER) in the picture's flat colours with the bold outline, clipped to
     the picture's own outline (at rest every painted px is under a part in front): the shirt under the
     belt, the neck under the chin, the near shoulder under the sleeve and the shirt's back edge under the
     near arm, the seat, the shorts' edges under the hands, the thighs' hidden backs, the far sleeve and
     arm behind the chest (only the arm under it shows), and a cap at every joint (elbow, wrist, hips,
     knees under the pads);
  4. written at half size: assets/characters/tide/rig/<part>.png and rig.json (rig px = (source px -
     ORIGIN) / 2, the feet on y 0).

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow, OpenCV):

  python3 -I art_source/characters/tide/rig/make_rig.py [--debug DIR]

--debug DIR writes the part map over the picture, the parts contact sheet (each part alone, and
again with its painted areas tinted) and the parts re-assembled at rest beside the picture.
"""
import argparse
import json
import math
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SRC = os.path.join(HERE, "..", "side_idle", "idle_v2.png")
OUT = os.path.join(REPO, "assets", "characters", "tide", "rig")
ID = "tide"

NOISE = 0.06
OUTLINE_LUM = 24  # darker than this: the outline (the navy hair and leggings are lighter: cells)
INK = (10, 15, 26)  # the outline colour
INK_W = 5  # its width (source px)
ORIGIN = (440.0, 903.0)  # the feet: the near sole's ground line, under the hips
TOP_Y = 64.0  # the hair's top
HALF = 2  # parts written at 1 / HALF
CROP = (140, 50, 660, 912)  # the debug pictures' window (source px)

# The backdrop seen through the figure (enclosed white areas: the gap between the near arm and the waist,
# the gap between the legs), source px inside them.
HOLES = [(372, 640), (432, 825)]

SHIRT = (214, 236, 236)  # the sailor shirt's near-white
SHIRT_DARK = (160, 192, 196)
SHIRT_FAR = (176, 204, 206)
TEAL = (52, 128, 132)  # the collar, cuffs, belt, trim
TEAL_FAR = (44, 108, 112)
SKIN = (244, 180, 140)
SKIN_FAR = (218, 180, 152)  # the far arm's own skin
NECK = (205, 145, 120)
SHORTS = (226, 244, 244)
SHORTS_FAR = (190, 212, 214)
LEGGING = (34, 52, 80)
LEGGING_FAR = (28, 42, 66)

# The joints (source px).
J = {
    "hips": (440, 676), "torso": (440, 660), "head": (440, 488),
    "n_shoulder": (365, 550), "n_elbow": (338, 630), "n_hand": (336, 708),
    "f_shoulder": (495, 580), "f_elbow": (520, 640), "f_hand": (530, 708),
    "n_hip": (405, 690), "n_knee": (410, 782), "n_ankle": (392, 862),
    "f_hip": (480, 688), "f_knee": (497, 778), "f_ankle": (478, 852),
}
SOLE = {"n": 903.0, "f": 888.0}  # each foot's ground line (the far foot higher: 3/4 view)
BONES = [  # name, parent, joint
    ["hips", "", "hips"], ["torso", "hips", "torso"], ["head", "torso", "head"],
    ["f_shoulder", "torso", "f_shoulder"], ["f_elbow", "f_shoulder", "f_elbow"], ["f_hand", "f_elbow", "f_hand"],
    ["n_shoulder", "torso", "n_shoulder"], ["n_elbow", "n_shoulder", "n_elbow"], ["n_hand", "n_elbow", "n_hand"],
    ["f_hip", "hips", "f_hip"], ["f_knee", "f_hip", "f_knee"], ["f_ankle", "f_knee", "f_ankle"],
    ["n_hip", "hips", "n_hip"], ["n_knee", "n_hip", "n_knee"], ["n_ankle", "n_knee", "n_ankle"],
]

# Which part a px belongs to: the first polygon holding it (source px); the rest is the torso.
# The whole bob rides the head (its back part too: rigid when she looks up); the sleeves the upper arms;
# the knee pads the thighs; the neck under the jaw line is the torso's.
PARTS = {
    "head": [(140, 40), (660, 40), (660, 500), (600, 503), (470, 500), (468, 494), (440, 478), (424, 466),
             (418, 458), (428, 482), (430, 489), (394, 489), (388, 503), (140, 507)],
    "n_fist": [(296, 702), (362, 702), (364, 756), (296, 756)],
    "f_fist": [(514, 702), (562, 702), (562, 756), (516, 756)],
    "n_fore": [(296, 630), (364, 630), (362, 702), (296, 702)],
    "n_upper": [(300, 515), (340, 508), (378, 510), (390, 525), (394, 560), (392, 610), (372, 630), (296, 630)],
    "f_upper": [(500, 586), (556, 586), (556, 642), (508, 642)],
    "f_fore": [(508, 642), (556, 642), (556, 702), (514, 702)],
    "belt": [(372, 633), (440, 636), (468, 630), (524, 627), (524, 680), (504, 677), (488, 673), (472, 670), (440, 668), (400, 664), (372, 664)],
    "n_thigh": [(352, 664), (442, 668), (444, 800), (428, 806), (352, 806)],
    "f_thigh": [(442, 668), (532, 670), (532, 802), (428, 802)],
    "n_shin": [(326, 806), (428, 806), (428, 862), (452, 872), (458, 882), (458, 916), (326, 916)],
    "f_shin": [(428, 802), (592, 802), (592, 916), (458, 916), (458, 882), (452, 872), (428, 862)],
}
# Parts cut px by px along their polygon (the face and the shaded neck are one cell).
HARD = {"head"}
# Front-most first: who owns the outline between two parts.
OWN = ["n_fist", "n_fore", "n_upper", "head", "f_fist", "belt", "torso", "n_thigh", "n_shin", "f_thigh", "f_shin",
       "f_upper", "f_fore"]


def ellipse(cx, cy, rx, ry, n=48, a0=0.0, a1=360.0, rot=0.0):
    out = []
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        x, y = rx * math.cos(a), ry * math.sin(a)
        out.append((cx + x * c - y * s, cy + x * s + y * c))
    return out


# The hidden areas, painted under each part (polygon, fill colour, outlined?): listed bottom first.
UNDER = {
    "torso": [
        # the shirt under the belt
        ([(374, 636), (500, 634), (504, 670), (470, 666), (440, 662), (374, 658)], SHIRT, False),
        # the neck under the chin
        ([(400, 440), (464, 440), (462, 520), (398, 520)], NECK, True),
        # the near shoulder under the sleeve (round, outlined: no ragged edge when the arm swings away)
        (ellipse(370, 552, 26, 28), SHIRT, True),
        # the back edge under the near arm: armpit → waist (kept under the arm at rest)
        ([(346, 560), (372, 528), (392, 548), (388, 640), (372, 640), (364, 604), (350, 584)], SHIRT_DARK, True),
    ],
    "seat": [
        ([(366, 664), (508, 668), (508, 720), (480, 736), (400, 736), (368, 720)], SHORTS, False),
    ],
    "n_thigh": [
        (ellipse(405, 678, 40, 12), SHORTS, False),  # the hip cap under the belt
        # the shorts' back edge under the near hand, outlined along the back edge only
        ([(354, 690), (384, 690), (384, 722), (354, 722)], SHORTS, [[(356, 690), (356, 722)]]),
        ([(354, 722), (384, 722), (384, 740), (354, 740)], TEAL, [[(356, 722), (356, 740), (384, 740)]]),
    ],
    "f_thigh": [
        (ellipse(480, 678, 28, 12), SHORTS_FAR, False),
        # the back under the near thigh (shorts, then the legging): outlined on the open edge only
        ([(430, 668), (456, 668), (456, 740), (430, 740)], SHORTS_FAR, [[(432, 668), (432, 740)]]),
        ([(430, 740), (456, 740), (456, 800), (430, 800)], LEGGING_FAR, [[(432, 740), (432, 800)]]),
        # the shorts' front under the far hand
        ([(500, 702), (520, 702), (520, 722), (500, 722)], SHORTS_FAR, [[(518, 702), (518, 722)]]),
        ([(500, 722), (520, 722), (520, 740), (500, 740)], TEAL_FAR, [[(518, 722), (518, 740), (500, 740)]]),
    ],
    # the far arm behind the chest (the picture shows only the arm under the sleeve): the sleeve with its
    # teal cuff, open at the elbow (the forearm in front of it shows there)
    "f_upper": [([(500, 588), (514, 580), (530, 600), (536, 640), (512, 646)], SKIN_FAR,
                 [[(510, 636), (500, 588)], [(514, 580), (530, 600), (536, 640)]]),
                ([(476, 574), (488, 556), (508, 556), (522, 576), (528, 606), (496, 610), (484, 596)], SHIRT_FAR, True),
                ([(492, 598), (528, 594), (530, 614), (494, 618)], TEAL_FAR, True)],
    "f_fore": [[(508, 628), (528, 626), (542, 664), (540, 704), (516, 706), (510, 664)]],
    # the joint caps (the child's end under its parent), whole ellipses
    "n_shin": [ellipse(408, 794, 30, 16)],  # the knees under the thighs' pads
    "f_shin": [ellipse(495, 790, 26, 16)],
    # bare skin: the elbow and wrist caps without an outline (no line across the arm as it bends)
    "n_fore": [(ellipse(338, 630, 22, 13), SKIN, False)],  # the elbow under the upper arm
    "n_fist": [(ellipse(336, 706, 24, 14), SKIN, False)],  # the wrist under the forearm
}
UNDER_FILL = {"n_thigh": LEGGING, "f_thigh": LEGGING_FAR, "n_shin": LEGGING, "f_shin": LEGGING_FAR, "n_fore": SKIN,
              "n_fist": SKIN, "f_fist": SKIN_FAR, "f_upper": SHIRT_FAR, "f_fore": SKIN_FAR}

# The rig's per-character tuning, written into rig.json (scenes/character/rig/rig_model.gd: aimPath,
# fallDeg, headBackDeg, torsoBackDeg; the gun's length and back sling are the carry scene's,
# scenes/character/poses/tide_carry.tscn).
RIG_TUNING = {
    "fallDeg": -72.0,  # lying on the back: the back of the bob on the ground, the heels just off it
    # RigModel.AIM_PATH's rows, the tube sliding up through the hands from 30 degrees (her chest is low
    # under the big head: without it the tail digs into the ground at 45)
    "aimPath": [
        [-30.0, 4.0, 4.0, -10.0, 44.0, 0.0],
        [0.0, 4.0, 0.0, -12.0, 48.0, 0.0],
        [30.0, 8.0, -2.0, -14.0, 44.0, 20.0],
        [45.0, 10.0, -2.0, -14.0, 40.0, 40.0],
        [60.0, 8.0, -4.0, -14.0, 32.0, 60.0],
        [80.0, 6.0, -4.0, -16.0, 16.0, 80.0],
        [90.0, 4.0, -4.0, -16.0, 10.0, 95.0],
    ],
}

# Draw order, bottom first: (part png, bone).
ORDER = [
    ("f_fore", "f_elbow"), ("f_upper", "f_shoulder"),
    ("seat", "hips"), ("f_shin", "f_knee"), ("f_thigh", "f_hip"), ("n_shin", "n_knee"), ("n_thigh", "n_hip"),
    ("torso", "torso"), ("belt", "hips"), ("head", "head"),
    ("f_fist", "f_hand"),
    ("n_fist", "n_hand"),  # the gun goes right under the near hand (rig.json gunUnder): only the near arm over it
    ("n_fore", "n_elbow"), ("n_upper", "n_shoulder"),
]


def mend_seams(rgb):
    """The chibi edit's seams (make_chibi.py stacked the scaled head, shirt and legs): the shaded neck of
    the head layer (down to y 508) graded towards its bottom into the neck under it (column by
    column, by their measured difference), the neck's front outline drawn as one stroke
    across the jog (the backdrop notch right of it whitened); the faint line across the shorts' teal trim
    (y ~735) smoothed away down each column."""
    out = rgb.copy()
    lum_ = lum(rgb)
    skin = (rgb[..., 0] > 150) & (rgb[..., 0] - rgb[..., 2] > 40) & (lum_ > 110)
    # per column, the shaded neck's bottom (rows 503..508) against the light neck under it (rows 510..514),
    # both averaged over the skin of the columns round it (no streaks, the collar's columns borrow their
    # neighbours'), the difference ramped in over the head layer's rows
    def band(y0, y1):
        m = skin[y0:y1].astype(np.float64)
        c = (rgb[y0:y1] * m[..., None]).sum(axis=0)
        n = m.sum(axis=0)
        k = np.ones(13)
        c = np.stack([np.convolve(c[:, i], k, mode="same") for i in range(3)], 1)
        n = np.convolve(n, k, mode="same")
        return c / np.maximum(n, 1e-6)[:, None], n > 0
    up, ok_up = band(503, 509)
    down, ok_down = band(510, 515)
    diff = np.where((ok_up & ok_down)[:, None], down - up, 0.0)
    for y in range(492, 509):  # the head layer's rows (the shirt layer's start at 509)
        t = (y - 492) / (508 - 492)
        t = t * t * (3 - 2 * t)
        for x in range(396, 462):
            if skin[y, x]:
                out[y, x] += diff[x] * t
    # the front outline: one stroke over the head layer's and the shirt layer's, the notch right of it
    # backdrop
    stroke = [(463.0, 488.0), (462.0, 503.0), (456.0, 518.0)]
    for y in range(494, 517):
        (xa, ya), (xb, yb) = (stroke[0], stroke[1]) if y < 503 else (stroke[1], stroke[2])
        cx = xa + (xb - xa) * (y - ya) / (yb - ya)
        for x in range(int(cx + 3), 474):
            if lum_[y, x] > 90:
                out[y, x] = 255.0
    big = np.zeros((rgb.shape[0] * 4, rgb.shape[1] * 4), np.uint8)
    cv2.polylines(big, [np.round(np.array(stroke) * 4).astype(np.int32)], False, 255, INK_W * 4, lineType=cv2.LINE_AA)
    a = cv2.resize(big.astype(np.float32) / 255.0, (rgb.shape[1], rgb.shape[0]), interpolation=cv2.INTER_AREA)
    out = out * (1 - a[..., None]) + np.array(INK, np.float64) * a[..., None]
    # the trim: teal px of rows 726..741 smoothed down their column
    teal = (rgb[..., 1] > 95) & (rgb[..., 2] > 95) & (rgb[..., 0] < 90)
    for x in range(366, 520):
        ys = [y for y in range(726, 742) if teal[y, x]]
        if len(ys) < 6:
            continue
        col = out[ys, x].copy()
        k = np.array([1, 2, 3, 2, 1], np.float64)
        sm = np.stack([np.convolve(np.pad(col[:, c], 2, mode="edge"), k / k.sum(), mode="valid") for c in range(3)], 1)
        out[ys, x] = sm
    return np.clip(out, 0, 255)


def lum(rgb):
    return rgb @ np.array([0.299, 0.587, 0.114])


def key(rgb):
    """Straight colour and alpha of the picture with its off-white backdrop removed."""
    h, w, _ = rgb.shape
    edge = np.concatenate([rgb[2:12, 2:-6].reshape(-1, 3), rgb[-12:-2, 2:-6].reshape(-1, 3),
                           rgb[2:-2, 2:12].reshape(-1, 3)])
    bgc = np.median(edge, axis=0)  # the backdrop's colour (~253)
    white = rgb.min(axis=2) > bgc.min() - 18
    lab, _n = ndimage.label(white)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    for x, y in HOLES:  # the backdrop seen through the figure
        if lab[y, x]:
            bg |= lab == lab[y, x]
    core = ndimage.binary_erosion(bg, iterations=1)
    band = (ndimage.distance_transform_edt(~bg) <= 3) & ~core
    # un-mixed against the backdrop's own colour: a = how far towards the ink each channel went
    a = ((bgc - rgb) / np.maximum(bgc, 1.0)).max(axis=2)
    a = np.clip((a - NOISE) / (1 - NOISE), 0, 1)
    alpha = np.where(bg & ~band, 0.0, 1.0)
    alpha = np.where(band, a, alpha)
    col = bgc + (rgb - bgc) / np.maximum(alpha, 1e-4)[..., None]
    s = np.clip((alpha - 0.5) / 0.3, 0, 1)
    col = np.clip(col, 0, 255) * (1 - s)[..., None] + rgb * s[..., None]
    col = np.where(band[..., None], col, rgb)
    # the faint edge px take the ink (a light rim px un-mixed is noise: no grey fringe)
    rim = band & (alpha < 0.6)
    col[rim] = np.array(INK, np.float64)
    alpha[alpha < 0.05] = 0
    lab, n = ndimage.label(alpha > 0.3, structure=np.ones((3, 3)))
    if n >= 1:  # only the figure: the faint JPEG speckle and the right edge's grey column dropped
        sizes = ndimage.sum(np.ones_like(alpha), lab, range(1, n + 1))
        keep = ndimage.binary_dilation(lab == (1 + int(np.argmax(sizes))), iterations=2)
        alpha[~keep] = 0
    col[alpha <= 0] = 0
    return col, alpha


def poly_mask(h, w, pts):
    m = np.zeros((h, w), np.uint8)
    cv2.fillPoly(m, [np.round(np.array(pts) * 8).astype(np.int32)], 1, lineType=cv2.LINE_8, shift=3)
    return m.astype(bool)


def segment(col, alpha):
    """Per part name, its px of the picture."""
    h, w = alpha.shape
    solid = alpha > 0.5
    rim = solid & (ndimage.distance_transform_edt(solid) <= 2.5)
    outline = solid & ((lum(col) < OUTLINE_LUM) | rim)
    cells, n = ndimage.label(solid & ~outline)
    ids = np.arange(1, n + 1)
    names = list(PARTS) + ["torso"]
    idx = np.full((h, w), len(names) - 1, np.int16)
    for k in range(len(names) - 2, -1, -1):
        idx[poly_mask(h, w, PARTS[names[k]])] = k
    # A cell mostly (>= 85 %) inside one part goes whole to it.
    hard = np.isin(idx, [names.index(nm) for nm in HARD])
    for i in ids:
        sel = cells == i
        if hard[sel].any():
            continue
        vals = idx[sel]
        counts = np.bincount(vals, minlength=len(names))
        k = int(np.argmax(counts))
        if counts[k] >= 0.85 * vals.size:
            idx[sel] = k
    label = np.full((h, w), -1, np.int16)
    label[solid & ~outline] = idx[solid & ~outline]
    sizes = ndimage.sum(np.ones((h, w)), cells, ids)
    small = np.isin(cells, ids[sizes < 30])
    big = (label >= 0) & ~small
    _, (iy, ix) = ndimage.distance_transform_edt(~big, return_indices=True)
    label[small] = label[iy[small], ix[small]]
    # The outline px: the front-most part with px within INK_W + 1 that its polygon also holds.
    owner = np.full((h, w), -1, np.int16)
    for nm in reversed(OWN):
        k = names.index(nm)
        near = ndimage.binary_dilation(label == k, iterations=INK_W + 1)
        near &= ndimage.binary_dilation(idx == k, iterations=3)
        owner[near & outline] = k
    # The rest of the dark px (the black hair is all "outline": far from any cell) go by the polygons,
    # not to the nearest cell (that would hand the hair's ends to the shoulder pad under them).
    left = outline & (owner < 0)
    owner[left] = idx[left]
    label[outline] = owner[outline]
    faint = (alpha > 0) & (label < 0)
    _, (iy, ix) = ndimage.distance_transform_edt(~(label >= 0), return_indices=True)
    label[faint] = label[iy[faint], ix[faint]]
    return {nm: label == k for k, nm in enumerate(names)}


def pm(colour, alpha):
    return np.dstack([colour * alpha[..., None], alpha]).astype(np.float32)


def over(dst, src):
    a = src[..., 3:4]
    dst *= (1 - a)
    dst += src


def paint(h, w, poly, fill, outlined=True, ss=4):
    """A filled polygon with the bold outline inside its edge (premultiplied RGBA, anti-aliased).
    outlined: True all round, False none, or a list of polylines: only along those edges."""
    pts = np.round(np.array(poly) * ss).astype(np.int32)
    big = np.zeros((h * ss, w * ss, 4), np.uint8)
    cv2.fillPoly(big, [pts], (*fill, 255), lineType=cv2.LINE_AA)
    if outlined:
        inside = np.zeros((h * ss, w * ss), np.uint8)
        cv2.fillPoly(inside, [pts], 1)
        if outlined is True:
            ring = inside & (1 - cv2.erode(inside, np.ones((INK_W * ss, INK_W * ss), np.uint8)))
        else:
            ring = np.zeros_like(inside)
            for line in outlined:
                cv2.polylines(ring, [np.round(np.array(line) * ss).astype(np.int32)], False, 1, 2 * INK_W * ss)
            ring &= inside
        big[ring > 0, :3] = INK
    small = cv2.resize(big.astype(np.float32) / 255.0, (w, h), interpolation=cv2.INTER_AREA)
    return np.dstack([small[..., :3] * 255.0, small[..., 3]]).astype(np.float32)


class Rig:
    def __init__(self, debug=None):
        rgb = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64)
        self.h, self.w = rgb.shape[:2]
        self.col, self.alpha = key(mend_seams(rgb))
        self.debug = debug
        self.part = segment(self.col, self.alpha)
        self.layers = {}  # name -> premultiplied RGBA at source size
        self.painted = {}  # name -> painted coverage under the visible px (for the contact sheet)
        self.xf = {}  # name -> 3x3 rest transform: part image px → source px

    def build(self):
        h, w = self.h, self.w
        for nm in list(PARTS) + ["torso", "seat"]:
            lay = np.zeros((h, w, 4), np.float32)
            for item in UNDER.get(nm, []):
                if isinstance(item, tuple):
                    poly, fill, outlined = item
                else:
                    poly, fill, outlined = item, UNDER_FILL[nm], True
                over(lay, paint(h, w, poly, fill, outlined))
            # painted only inside the picture's outline: at rest every painted px lies under a part in
            # front (nothing shows round the figure, in the arm's gap or between the legs)
            lay *= self.alpha[..., None].astype(np.float32)
            painted = lay[..., 3].copy()
            if nm in self.part:
                vis = self.part[nm].astype(np.float32) * self.alpha
                over(lay, pm(self.col, vis.astype(np.float64)))
                painted = painted * (1 - vis)
            self.layers[nm] = lay
            self.painted[nm] = painted
            self.xf[nm] = np.eye(3)

    def crop(self, nm):
        lay = self.layers[nm]
        ys, xs = np.nonzero(lay[..., 3] > 0.004)
        pad = 2 * HALF
        x0, y0 = max(0, xs.min() - pad), max(0, ys.min() - pad)
        x1, y1 = min(self.w, xs.max() + 1 + pad), min(self.h, ys.max() + 1 + pad)
        x0 -= x0 % HALF
        y0 -= y0 % HALF
        x1 += (-x1) % HALF
        y1 += (-y1) % HALF
        return lay[y0:y1, x0:x1], (x0, y0)

    def write(self):
        os.makedirs(OUT, exist_ok=True)
        to_rig = lambda p: [round((p[0] - ORIGIN[0]) / HALF, 2), round((p[1] - ORIGIN[1]) / HALF, 2)]
        parts = []
        for nm, bone in ORDER:
            lay, (x0, y0) = self.crop(nm)
            small = cv2.resize(lay, (lay.shape[1] // HALF, lay.shape[0] // HALF), interpolation=cv2.INTER_AREA)
            a = small[..., 3:4]
            rgb = np.where(a > 1e-4, small[..., :3] / np.maximum(a, 1e-4), 0)
            # the clear px take their nearest drawn px's colour (no dark fringe where the sprite is
            # filtered, imported or not: like the import's fix_alpha_border)
            seen = a[..., 0] > 1e-4
            if seen.any():
                _, (iy, ix) = ndimage.distance_transform_edt(~seen, return_indices=True)
                rgb = rgb[iy, ix]
            img = np.dstack([np.clip(rgb, 0, 255), np.clip(a * 255, 0, 255)]).astype(np.uint8)
            Image.fromarray(img, "RGBA").save(os.path.join(OUT, nm + ".png"), optimize=True)
            # image px (halved) → rig px: scale by HALF, place at (x0, y0), the part's rest transform, then
            # source → rig.
            m = np.array([[1.0 / HALF, 0, -ORIGIN[0] / HALF], [0, 1.0 / HALF, -ORIGIN[1] / HALF], [0, 0, 1]])
            m = m @ self.xf[nm] @ np.array([[HALF, 0, x0], [0, HALF, y0], [0, 0, 1.0]])
            parts.append({"name": nm, "png": nm + ".png", "bone": bone,
                          "xf": [round(float(v), 4) for v in (m[0, 0], m[1, 0], m[0, 1], m[1, 1], m[0, 2], m[1, 2])]})
        bones = [{"name": b, "parent": p, "pos": to_rig(J[j])} for b, p, j in BONES]
        gun_chest = (446, 590)
        data = {
            "source": "art_source/characters/tide/rig/make_rig.py",
            "note": "rig px = source px / 2, feet at (0, 0); parts bottom first; xf = the part's rest "
                    "transform (image px -> rig px, Transform2D columns x, y, origin)",
            "height": round((ORIGIN[1] - TOP_Y) / HALF, 1),
            "bones": bones,
            "parts": parts,
            "points": {
                "n_sole": to_rig((J["n_ankle"][0], SOLE["n"])), "f_sole": to_rig((J["f_ankle"][0], SOLE["f"])),
                "chest": to_rig(gun_chest),
                # the outline points a body lying down rests on (char_rig: the fall lifts the lowest to the ground)
                "head_back": to_rig((158, 390)), "cap_back": to_rig((215, 180)), "cap_top": to_rig((400, 66)),
                "back": to_rig((326, 590)),
                "eye": to_rig((520, 345)),  # the near eye (tests: the muzzle stays off the face)
            },
            "gunUnder": "n_fist",
        }
        data.update(RIG_TUNING)
        with open(os.path.join(OUT, "rig.json"), "w") as f:
            json.dump(data, f, indent=1)
        return data

    def compose_rest(self):
        """Every part at its rest transform, bottom first (premultiplied, source size)."""
        out = np.zeros((self.h, self.w, 4), np.float32)
        for nm, _bone in ORDER:
            lay = self.layers[nm]
            m = self.xf[nm]
            if not np.allclose(m, np.eye(3)):
                lay = cv2.warpAffine(lay, m[:2], (self.w, self.h), flags=cv2.INTER_LINEAR)
            over(out, lay)
        return out

    def debug_out(self, d):
        os.makedirs(d, exist_ok=True)
        h, w = self.h, self.w
        # part map
        rng = np.random.default_rng(3)
        mp = np.full((h, w, 3), 255.0)
        for nm, m in self.part.items():
            c = rng.integers(40, 230, 3)
            mp[m] = c
        mix = (mp * 0.55 + self.col * 0.45) * (self.alpha[..., None] > 0) + 255 * (self.alpha[..., None] <= 0)
        Image.fromarray(mix.astype(np.uint8)).crop(CROP).save(os.path.join(d, "part_map.png"))
        # rest compose beside the picture
        rest = self.compose_rest()
        bg = np.full((h, w, 3), 205.0)
        a = rest[..., 3:4]
        comp = bg * (1 - a) + rest[..., :3]
        orig = bg * (1 - self.alpha[..., None]) + self.col * self.alpha[..., None]
        x0, y0, x1, y1 = CROP
        both = np.concatenate([orig[y0:y1, x0:x1], comp[y0:y1, x0:x1]], axis=1)
        Image.fromarray(both.astype(np.uint8)).save(os.path.join(d, "rest_vs_picture.png"))
        # contact sheet: each part, then with its painted areas tinted magenta
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 18)
        tiles = []
        for nm, _bone in ORDER:
            lay, (x0, y0) = self.crop(nm)
            pt = self.painted[nm][y0:y0 + lay.shape[0], x0:x0 + lay.shape[1]]
            tiles.append((nm, lay, pt))
        cw, ch, cols = 290, 360, 7
        nrow = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cw * cols, ch * nrow * 2 + 20), (255, 255, 255))
        dr = ImageDraw.Draw(sheet)
        for half, tint in enumerate((False, True)):
            for i, (nm, lay, pt) in enumerate(tiles):
                x0, y0 = (i % cols) * cw, (half * nrow + i // cols) * ch + half * 20
                dr.rectangle((x0, y0, x0 + cw - 2, y0 + ch - 2), fill=(214, 222, 230))
                a = lay[..., 3:4]
                rgb = lay[..., :3].copy()
                if tint:
                    t = np.clip(pt, 0, 1)[..., None] * 0.55
                    rgb = rgb * (1 - t) + np.array([255, 0, 200]) * t * a
                tile = np.full(lay.shape[:2] + (3,), 214.0) * (1 - a) + rgb
                im = Image.fromarray(np.clip(tile, 0, 255).astype(np.uint8))
                k = min(1.0, (cw - 10) / im.width, (ch - 40) / im.height)
                im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
                sheet.paste(im, (x0 + (cw - im.width) // 2, y0 + 32))
                dr.text((x0 + 6, y0 + 4), nm + (" (painted: magenta)" if tint else ""), fill=(20, 20, 30), font=font)
        sheet.save(os.path.join(d, "parts_sheet.png"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--debug")
    args = ap.parse_args()
    rig = Rig(args.debug)
    rig.build()
    data = rig.write()
    if args.debug:
        rig.debug_out(args.debug)
    print("parts:", len(data["parts"]), "bones:", len(data["bones"]), "->", os.path.relpath(OUT, REPO))


if __name__ == "__main__":
    main()
