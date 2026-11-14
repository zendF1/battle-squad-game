#!/usr/bin/env python3
"""Flora's chibi bone rig (matches only: scenes/character/character.gd match_rig), the same rig as
Rookie's, Spark's and Tanko's (../../tanko/rig/make_rig.py: the same steps, parts, bones and draw order),
made from the one picture ../side_idle/idle_v2.png (1365 x 768, off-white backdrop, a grey column on the
right edge, 3/4 facing right, standing, fists down, no gun, no watermark):

  1. keyed: the off-white backdrop (the light px joined to the picture's border, the gap between the near
     arm and the waist, the gap between the boots) removed, the soft outline edge un-mixed against the
     backdrop's own colour (BG, measured on the border: no grey fringe), the speckle and the right edge's
     grey column dropped (only the figure's one blob kept);
  2. cut: the picture split into its flat-colour cells (between the dark outlines), each cell given to
     a part by PARTS (a cell mostly inside one polygon goes whole; a cell across two is cut px by px
     along them); the outline px between two parts belong to the one in front (OWN). The bandana, its
     flower and its two knotted tails ride the head (rigid); the shoulder and elbow pads the upper arms
     (round on the elbow joint, the elbow pad covers the forearm's top however it bends); the knee pads
     the thighs;
  3. the hidden areas painted (UNDER) in the picture's flat colours with the bold outline, clipped to
     the picture's own outline (at rest every painted px is under a part in front): the jumpsuit under
     the near arm, its shoulder and the belt, the neck under the chin, the belt's back end under the near
     fist, the seat and the thighs under the fists and each other, the far sleeve, shoulder pad and
     forearm behind the chest (only a sliver shows), and a cap at every joint (elbow, wrist, hips, knees
     under the pads);
  4. written at half size: assets/characters/flora/rig/<part>.png and rig.json (rig px = (source px -
     ORIGIN) / 2, the feet on y 0).

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
SRC = os.path.join(HERE, "..", "side_idle", "idle_v2.png")
OUT = os.path.join(REPO, "assets", "characters", "flora", "rig")
ID = "flora"

NOISE = 0.06
OUTLINE_LUM = 38  # darker than this: the outline (the cells' walls)
INK = (30, 30, 24)  # the outline colour
INK_W = 5  # its width (source px)
ORIGIN = (652.0, 685.0)  # the feet: the near sole's ground line, under the hips
TOP_Y = 76.0  # the bandana's top
HALF = 2  # parts written at 1 / HALF
CROP = (430, 60, 820, 700)  # the debug pictures' window (source px)

# The backdrop seen through the figure (enclosed light areas: the gap between the near arm and the
# waist, the gap between the boots over the near toe, a chink between the hair and the near shoulder), source
# px inside them.
HOLES = [(617, 425), (651, 615), (621, 337)]

SUIT = (99, 104, 69)  # the jumpsuit's green
SUIT_DARK = (77, 81, 56)
SLEEVE_FAR = (80, 85, 56)
PAD = (110, 114, 104)  # the grey pads
PAD_FAR = (88, 92, 84)
SKIN = (228, 174, 132)
SKIN_FAR = (204, 152, 116)
NECK = (205, 150, 120)
GLOVE = (104, 111, 72)
GLOVE_FAR = (86, 92, 60)
POUCH = (61, 51, 42)
BELT = (40, 36, 25)
PANTS = (99, 104, 69)
PANTS_FAR = (82, 87, 56)
CUFF = (70, 74, 49)

# The joints (source px).
J = {
    "hips": (652, 482), "torso": (652, 470), "head": (668, 348),
    "n_shoulder": (600, 368), "n_elbow": (590, 432), "n_hand": (595, 495),
    "f_shoulder": (700, 378), "f_elbow": (713, 436), "f_hand": (720, 495),
    "n_hip": (626, 486), "n_knee": (634, 560), "n_ankle": (622, 635),
    "f_hip": (682, 486), "f_knee": (694, 560), "f_ankle": (682, 628),
}
SOLE = {"n": 685.0, "f": 668.0}  # each foot's ground line (the far foot higher: 3/4 view)
BONES = [  # name, parent, joint
    ["hips", "", "hips"], ["torso", "hips", "torso"], ["head", "torso", "head"],
    ["f_shoulder", "torso", "f_shoulder"], ["f_elbow", "f_shoulder", "f_elbow"], ["f_hand", "f_elbow", "f_hand"],
    ["n_shoulder", "torso", "n_shoulder"], ["n_elbow", "n_shoulder", "n_elbow"], ["n_hand", "n_elbow", "n_hand"],
    ["f_hip", "hips", "f_hip"], ["f_knee", "f_hip", "f_knee"], ["f_ankle", "f_knee", "f_ankle"],
    ["n_hip", "hips", "n_hip"], ["n_knee", "n_hip", "n_knee"], ["n_ankle", "n_knee", "n_ankle"],
]

# Which part a px belongs to: the first polygon holding it (source px); the rest is the torso.
# The bandana, its flower and its two knotted tails ride the head; the shoulder pads and the elbow pads
# ride the upper arms (a round pad on the elbow joint covers the forearm's top however it bends); the
# knee pads ride the thighs.
PARTS = {
    "head": [(430, 60), (830, 60), (830, 362), (760, 362), (700, 358), (672, 351), (650, 341), (630, 347),
             (615, 349), (598, 350), (585, 356), (540, 362), (430, 362)],
    "n_fist": [(560, 466), (614, 466), (622, 480), (622, 526), (560, 526)],
    "f_fist": [(703, 464), (745, 464), (745, 530), (700, 530)],
    "n_fore": [(560, 436), (608, 436), (610, 466), (560, 466)],
    "n_upper": [(550, 362), (585, 356), (598, 352), (615, 351), (626, 353), (628, 362), (626, 392), (614, 412), (608, 436), (560, 446), (550, 446)],
    "f_upper": [(694, 352), (730, 352), (730, 440), (700, 440)],
    "f_fore": [(700, 440), (730, 440), (730, 464), (703, 464)],
    "belt": [(606, 443), (724, 443), (724, 480), (606, 480)],
    "n_thigh": [(585, 480), (656, 480), (656, 586), (612, 586), (600, 575), (585, 575)],
    "f_thigh": [(656, 480), (724, 480), (724, 586), (676, 586), (668, 580), (656, 580)],
    "n_shin": [(560, 575), (600, 575), (612, 586), (650, 586), (650, 640), (670, 648), (670, 700), (560, 700)],
    "f_shin": [(656, 580), (668, 580), (676, 586), (760, 586), (760, 700), (670, 700), (670, 648), (650, 640),
               (650, 586)],
}
# Parts cut px by px along their polygon.
HARD = set()
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
        # the jumpsuit under the belt
        ([(612, 440), (700, 440), (700, 478), (612, 478)], SUIT, False),
        # the neck under the chin
        ([(644, 320), (690, 320), (692, 372), (642, 372)], NECK, True),
        # the near shoulder under its pad (round, outlined: no ragged edge when the arm swings away)
        (ellipse(622, 372, 22, 22), SUIT, True),
        # the back edge under the near arm: armpit → waist (kept under the arm at rest)
        ([(596, 376), (622, 356), (636, 368), (628, 450), (612, 450), (608, 420), (598, 400)], SUIT_DARK, True),
    ],
    "belt": [
        # the belt's back end under the near fist
        ([(608, 446), (628, 446), (628, 478), (608, 478)], POUCH, [[(610, 446), (610, 478)]]),
    ],
    "seat": [
        ([(608, 470), (718, 470), (716, 504), (680, 516), (640, 518), (612, 506)], PANTS, False),
    ],
    "n_thigh": [
        (ellipse(626, 484, 30, 10), PANTS, False),  # the hip cap under the belt
        # the back under the near fist, outlined along the back edge only
        ([(596, 476), (626, 476), (626, 540), (592, 540)], PANTS, [[(596, 476), (592, 540)]]),
    ],
    "f_thigh": [
        (ellipse(682, 484, 30, 10), PANTS_FAR, False),
        # the back under the near thigh, the front under the far fist: outlined on the open edge only
        ([(646, 478), (668, 478), (668, 584), (646, 584)], PANTS_FAR, [[(648, 478), (648, 584)]]),
        ([(702, 478), (720, 478), (720, 530), (702, 530)], PANTS_FAR, [[(720, 478), (720, 530)]]),
    ],
    # the far arm behind the chest (the picture shows only its outer sliver): the grey shoulder pad and
    # the sleeve, open at the elbow (the forearm in front of it shows there)
    "f_upper": [([(680, 380), (688, 366), (702, 360), (716, 368), (720, 400), (722, 436), (694, 436), (686, 410)],
                 SLEEVE_FAR, [[(694, 436), (686, 410), (680, 380), (688, 366), (702, 360), (716, 368), (720, 400),
                               (722, 436)]]),
                (ellipse(702, 374, 18, 15), PAD_FAR, True)],
    "f_fore": [[(694, 426), (708, 420), (720, 424), (724, 444), (724, 470), (698, 470), (694, 448)]],
    # the joint caps (the child's end under its parent), whole ellipses
    "n_shin": [ellipse(630, 568, 26, 18)],  # the knees under the thighs' pads
    "f_shin": [ellipse(694, 568, 24, 16)],
    "n_fore": [ellipse(590, 434, 18, 8)],  # the elbow under the upper arm's pad
    "n_fist": [ellipse(594, 468, 18, 6)],  # the wrist under the forearm (the far fist is over its forearm)
}
UNDER_FILL = {"n_thigh": PANTS, "f_thigh": PANTS_FAR, "n_shin": CUFF, "f_shin": CUFF, "n_fore": SKIN,
              "n_fist": GLOVE, "f_fist": GLOVE_FAR, "f_upper": SLEEVE_FAR, "f_fore": SKIN_FAR}

# The rig's per-character tuning, written into rig.json (scenes/character/rig/rig_model.gd: aimPath,
# fallDeg, headBackDeg, torsoBackDeg; the gun's length and back sling are the carry scene's,
# scenes/character/poses/flora_carry.tscn).
RIG_TUNING = {
    "fallDeg": -80.0,  # lying on the back: the back of the head and the heels on the ground (Rookie -72)
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
            img = np.dstack([np.clip(rgb, 0, 255), np.clip(a * 255, 0, 255)]).astype(np.uint8)
            Image.fromarray(img, "RGBA").save(os.path.join(OUT, nm + ".png"), optimize=True)
            # image px (halved) → rig px: scale by HALF, place at (x0, y0), the part's rest transform, then
            # source → rig.
            m = np.array([[1.0 / HALF, 0, -ORIGIN[0] / HALF], [0, 1.0 / HALF, -ORIGIN[1] / HALF], [0, 0, 1]])
            m = m @ self.xf[nm] @ np.array([[HALF, 0, x0], [0, HALF, y0], [0, 0, 1.0]])
            parts.append({"name": nm, "png": nm + ".png", "bone": bone,
                          "xf": [round(float(v), 4) for v in (m[0, 0], m[1, 0], m[0, 1], m[1, 1], m[0, 2], m[1, 2])]})
        bones = [{"name": b, "parent": p, "pos": to_rig(J[j])} for b, p, j in BONES]
        gun_chest = (658, 400)
        data = {
            "source": "art_source/characters/flora/rig/make_rig.py",
            "note": "rig px = source px / 2, feet at (0, 0); parts bottom first; xf = the part's rest "
                    "transform (image px -> rig px, Transform2D columns x, y, origin)",
            "height": round((ORIGIN[1] - TOP_Y) / HALF, 1),
            "bones": bones,
            "parts": parts,
            "points": {
                "n_sole": to_rig((J["n_ankle"][0], SOLE["n"])), "f_sole": to_rig((J["f_ankle"][0], SOLE["f"])),
                "chest": to_rig(gun_chest),
                # the outline points a body lying down rests on (char_rig: the fall lifts the lowest to the ground)
                "head_back": to_rig((540, 300)), "cap_back": to_rig((548, 150)), "cap_top": to_rig((660, 78)),
                "back": to_rig((566, 420)),
                "eye": to_rig((706, 240)),  # the near eye (tests: the muzzle stays off the face)
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
