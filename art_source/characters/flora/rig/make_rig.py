#!/usr/bin/env python3
"""Flora's chibi bone rig (matches only: scenes/character/character.gd match_rig), the same rig as Rookie's,
Spark's, Tanko's and Tide's (the same steps, parts, bones and draw order), made from the one picture
../side_idle/idle_final.png (the user's final chibi set, 896 x 1200, pure white backdrop, 3/4 facing right,
standing, gloved fists down, no gun):

  1. keyed: the white backdrop (the light px joined to the picture's border, and the enclosed gaps in HOLES)
     removed by flood from the border, not by a threshold (the eye whites are inside their outlines), the
     soft outline edge un-mixed against the white (no grey fringe), the speckle dropped (only the figure's
     one blob kept);
  2. cut: the picture split into its flat-colour cells (between the dark outlines), each cell given to
     a part by PARTS (a cell mostly inside one polygon goes whole; a cell across two is cut px by px
     along them; HARD parts cut px by px along their polygon); the outline px between two parts belong
     to the one in front (OWN). The bandana, its flower and its two knotted tails and the hair ride the
     head (rigid; the head cut px by px along the jaw: the neck's shade is one cell with the face); the
     shoulder and elbow pads the upper arms; the knee pads the thighs;
  3. the hidden areas painted (UNDER) in the picture's flat colours with the bold outline, clipped to
     the picture's own outline (at rest every painted px is under a part in front): the jumpsuit under
     the belt, the neck under the chin, the near shoulder under its pad and the suit's back edge under the
     near arm, the belt's back end under the near arm, the seat, the thighs' hidden edges, the far sleeve, shoulder pad and
     forearm behind the chest, and a cap at every joint (elbow, wrist, hips, knees);
  4. written at a third of the size: assets/characters/flora/rig/<part>.png and rig.json (rig px =
     (source px - ORIGIN) / 3, the feet on y 0).

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow, OpenCV):

  python3 -I art_source/characters/flora/rig/make_rig.py [--debug DIR]

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
SRC = os.path.join(HERE, "..", "side_idle", "idle_final.png")
OUT = os.path.join(REPO, "assets", "characters", "flora", "rig")
ID = "flora"

NOISE = 0.06
OUTLINE_LUM = 26  # darker than this: the outline (the cells' walls; the black hair is all outline)
INK = (5, 5, 3)  # the outline colour
INK_W = 6  # its width (source px)
ORIGIN = (550.0, 1182.0)  # the feet: the near sole's ground line, under the hips
TOP_Y = 10.0  # the bandana's top
HALF = 3  # parts written at 1 / HALF
CROP = (60, 0, 760, 1195)  # the debug pictures' window (source px)

# The backdrop seen through the figure (enclosed white areas), source px inside them.
HOLES = [(435, 740), (510, 1070)]  # the gap between the near arm and the waist, the gap between the boots

SUIT = (82, 92, 56)  # the jumpsuit's green
SUIT_DARK = (68, 78, 48)
SLEEVE_FAR = (66, 74, 46)
PAD = (115, 121, 109)  # the grey pads
PAD_FAR = (94, 99, 90)
SKIN = (240, 186, 142)
SKIN_FAR = (214, 164, 126)
NECK = (214, 160, 124)
GLOVE = (103, 108, 67)
GLOVE_FAR = (86, 92, 56)
BELT = (95, 82, 61)
PANTS = (82, 92, 56)
PANTS_FAR = (68, 76, 46)
BOOT = (65, 90, 63)

# The joints (source px).
J = {
    "hips": (550, 840), "torso": (550, 820), "head": (520, 556),
    "n_shoulder": (398, 616), "n_elbow": (345, 730), "n_hand": (388, 818),
    "f_shoulder": (622, 626), "f_elbow": (648, 742), "f_hand": (672, 820),
    "n_hip": (500, 852), "n_knee": (504, 970), "n_ankle": (470, 1100),
    "f_hip": (610, 852), "f_knee": (633, 968), "f_ankle": (620, 1086),
}
SOLE = {"n": 1182.0, "f": 1160.0}  # each foot's ground line (the far foot higher: 3/4 view)

# Which part a px belongs to: the first polygon holding it (source px); the rest is the torso.
PARTS = {
    "head": [(40, 0), (860, 0), (860, 556), (660, 554), (630, 551), (600, 551), (560, 532), (540, 520), (500, 500), (470, 486),
             (452, 500), (440, 540), (420, 550), (40, 550)],
    "n_fist": [(300, 812), (440, 812), (450, 840), (450, 890), (440, 918), (300, 918)],
    "f_fist": [(646, 810), (730, 810), (730, 900), (646, 900)],
    "n_fore": [(290, 754), (422, 754), (422, 812), (290, 812)],
    "n_upper": [(290, 570), (420, 560), (460, 590), (462, 660), (440, 700), (432, 754), (290, 754)],
    "f_upper": [(700, 600), (760, 600), (760, 740), (700, 740)],
    "f_fore": [(700, 740), (760, 740), (760, 810), (700, 810)],
    "belt": [(420, 756), (700, 756), (700, 842), (420, 842)],
    "n_thigh": [(330, 842), (556, 842), (556, 1004), (330, 1004)],
    "f_thigh": [(556, 842), (690, 842), (690, 1004), (556, 1004)],
    "n_shin": [(300, 1004), (505, 1004), (505, 1118), (570, 1124), (570, 1210), (300, 1210)],
    "f_shin": [(505, 1004), (760, 1004), (760, 1210), (570, 1210), (570, 1124), (505, 1118)],
}
# Parts cut px by px along their polygon (the neck's shade behind the jaw is one cell with the face).
HARD = {"head"}
# Front-most first: who owns the outline between two parts.
OWN = ["n_fist", "n_fore", "n_upper", "head", "f_fist", "belt", "torso", "n_thigh", "n_shin", "f_thigh", "f_shin",
       "f_upper", "f_fore"]
BONES = [  # name, parent, joint
    ["hips", "", "hips"], ["torso", "hips", "torso"], ["head", "torso", "head"],
    ["f_shoulder", "torso", "f_shoulder"], ["f_elbow", "f_shoulder", "f_elbow"], ["f_hand", "f_elbow", "f_hand"],
    ["n_shoulder", "torso", "n_shoulder"], ["n_elbow", "n_shoulder", "n_elbow"], ["n_hand", "n_elbow", "n_hand"],
    ["f_hip", "hips", "f_hip"], ["f_knee", "f_hip", "f_knee"], ["f_ankle", "f_knee", "f_ankle"],
    ["n_hip", "hips", "n_hip"], ["n_knee", "n_hip", "n_knee"], ["n_ankle", "n_knee", "n_ankle"],
]


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
        # the jumpsuit under the belt
        ([(440, 752), (690, 752), (690, 836), (440, 836)], SUIT, False),
        # the neck under the chin
        ([(450, 470), (580, 470), (582, 590), (448, 590)], NECK, True),
        # the near shoulder under its pad (round, outlined: no ragged edge when the arm swings away)
        (ellipse(420, 620, 38, 42), SUIT, True),
        # the back edge under the near arm: armpit → waist (kept under the arm at rest)
        ([(380, 650), (420, 600), (452, 630), (450, 770), (420, 770), (410, 720), (390, 690)], SUIT_DARK, True),
    ],
    "belt": [
        # the belt's back end under the near fist
        ([(428, 760), (452, 760), (452, 838), (428, 838)], BELT, [[(430, 760), (430, 838)]]),
    ],
    "seat": [
        ([(440, 820), (690, 820), (686, 900), (630, 930), (490, 930), (444, 900)], PANTS, False),
    ],
    "n_thigh": [
        (ellipse(500, 850, 56, 16), PANTS, False),  # the hip cap under the belt
        # the back under the near fist, outlined along the back edge only
        ([(420, 836), (456, 836), (456, 930), (414, 930)], PANTS, [[(420, 836), (414, 930)]]),
    ],
    "f_thigh": [
        (ellipse(610, 850, 50, 16), PANTS_FAR, False),
        # the back under the near thigh, the front under the far fist: outlined on the open edge only
        ([(544, 836), (574, 836), (574, 970), (544, 970)], PANTS_FAR, [[(546, 836), (546, 970)]]),
        ([(650, 836), (680, 836), (680, 900), (650, 900)], PANTS_FAR, [[(680, 836), (680, 900)]]),
    ],
    # the far arm behind the chest (only its outer sliver shows): the sleeve and its shoulder pad, open
    # at the elbow (the forearm in front of it shows there)
    "f_upper": [([(612, 634), (626, 606), (650, 596), (676, 608), (684, 660), (688, 742), (644, 742), (628, 690)],
                 SLEEVE_FAR, [[(644, 742), (628, 690), (612, 634), (626, 606), (650, 596), (676, 608), (684, 660),
                               (688, 742)]]),
                (ellipse(646, 616, 30, 26), PAD_FAR, True)],
    "f_fore": [[(630, 720), (656, 710), (684, 718), (696, 750), (696, 818), (640, 818), (630, 770)]],
    # the joint caps (the child's end under its parent), whole ellipses
    "n_shin": [ellipse(491, 972, 59, 26)],  # the knees under the thighs' pads
    "f_shin": [ellipse(627, 970, 45, 24)],
    # bare skin: no outline (no line across the arm as it bends)
    "n_fore": [(ellipse(352, 738, 34, 16), SKIN, False)],  # the elbow under the upper arm's pad
    "n_fist": [(ellipse(388, 814, 34, 10), SKIN, False)],  # the wrist under the glove's cuff
}
UNDER_FILL = {"n_thigh": PANTS, "f_thigh": PANTS_FAR, "n_shin": PANTS, "f_shin": PANTS_FAR, "n_fore": SKIN,
              "n_fist": GLOVE, "f_fist": GLOVE_FAR, "f_upper": SLEEVE_FAR, "f_fore": SKIN_FAR}

# The rig's per-character tuning, written into rig.json (scenes/character/rig/rig_model.gd: aimPath,
# fallDeg, headBackDeg, torsoBackDeg; the gun's length and back sling are the carry scene's,
# scenes/character/poses/flora_carry.tscn).
RIG_TUNING = {
    "fallDeg": -71.0,  # lying on the back: the back of the head and the heels on the ground
    # RigModel.AIM_PATH's rows at this rig's size (391 px tall, the default's figure 330), the tube
    # sliding up through the fists from 30 degrees so its tail stays off the ground
    "aimPath": [
        [-30.0, 5.0, 5.0, -12.0, 51.0, 0.0],
        [0.0, 5.0, 0.0, -14.0, 56.0, 0.0],
        [30.0, 9.0, -2.0, -15.0, 50.0, 18.0],
        [45.0, 12.0, -2.0, -16.0, 46.0, 36.0],
        [60.0, 9.0, -5.0, -16.0, 37.0, 55.0],
        [80.0, 7.0, -5.0, -19.0, 19.0, 81.0],
        [90.0, 5.0, -5.0, -19.0, 12.0, 105.0],
    ],
}

# The gun's chest point and the outline points a body lying down rests on (source px).
GUN_CHEST = (560, 670)
POINTS = {
    "head_back": (140, 440), "cap_back": (260, 70), "cap_top": (484, 12),
    "back": (380, 700),
    "eye": (596, 342),  # the near eye (tests: the muzzle stays off the face)
}

# Draw order, bottom first: (part png, bone).
ORDER = [
    ("f_fore", "f_elbow"), ("f_upper", "f_shoulder"),
    ("seat", "hips"), ("f_shin", "f_knee"), ("f_thigh", "f_hip"), ("n_shin", "n_knee"), ("n_thigh", "n_hip"),
    ("torso", "torso"), ("belt", "hips"), ("head", "head"),
    ("f_fist", "f_hand"),
    ("n_fist", "n_hand"),  # the gun goes right under the near fist (rig.json gunUnder): only the near arm over it
    ("n_fore", "n_elbow"), ("n_upper", "n_shoulder"),
]


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
        self.col, self.alpha = key(rgb)
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
        data = {
            "source": "art_source/characters/%s/rig/make_rig.py" % ID,
            "note": "rig px = source px / %d, feet at (0, 0);" % HALF + " parts bottom first; xf = the part's rest "
                    "transform (image px -> rig px, Transform2D columns x, y, origin)",
            "height": round((ORIGIN[1] - TOP_Y) / HALF, 1),
            "bones": bones,
            "parts": parts,
            "points": {
                "n_sole": to_rig((J["n_ankle"][0], SOLE["n"])), "f_sole": to_rig((J["f_ankle"][0], SOLE["f"])),
                "chest": to_rig(GUN_CHEST),
                # the outline points a body lying down rests on (char_rig: the fall lifts the lowest to the ground)
                **{k: to_rig(v) for k, v in POINTS.items()},
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
