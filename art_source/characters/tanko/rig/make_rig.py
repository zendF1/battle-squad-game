#!/usr/bin/env python3
"""Tanko's chibi bone rig (matches only: scenes/character/character.gd match_rig), the same rig as
Rookie's and Spark's (../../spark/rig/make_rig.py: the same steps, parts, bones and draw order), made from
the one picture ../side_idle/idle_v2.png (1365 x 768, off-white backdrop, a grey column on the right edge,
3/4 facing right, standing, fists down, no gun, no watermark):

  1. keyed: the off-white backdrop (the light px joined to the picture's border, and the gap between the
     near arm and the chest) removed, the soft outline edge un-mixed against the backdrop's own colour
     (BG, measured on the border: no grey fringe), the speckle and the right edge's grey column dropped
     (only the figure's one blob kept);
  2. cut: the picture split into its flat-colour cells (between the dark outlines), each cell given to
     a part by PARTS (a cell mostly inside one polygon goes whole; a cell across two is cut px by px
     along them); the outline px between two parts belong to the one in front (OWN). The big steel
     helmet and the chin strap ride the head; the shoulder pads the upper arms; the knee pads the thighs
     (round on the knee joint, they cover the shin's top however the knee bends);
  3. the hidden areas painted (UNDER) in the picture's flat colours with the bold outline, clipped to
     the picture's own outline (at rest every painted px is under a part in front): the shirt under the
     near arm, its shoulder and the belt, the neck under the chin strap, the belt's back end under the near sleeve, the
     seat and the thighs under the fists and each other, the far sleeve and shoulder pad behind the chest
     (only a sliver shows), and a cap at every joint (elbow, wrist, hips, knees under the pads);
  4. written at half size: assets/characters/tanko/rig/<part>.png and rig.json (rig px = (source px -
     ORIGIN) / 2, the feet on y 0).

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow, OpenCV):

  python3 -I art_source/characters/tanko/rig/make_rig.py [--debug DIR]

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
OUT = os.path.join(REPO, "assets", "characters", "tanko", "rig")
ID = "tanko"

NOISE = 0.06
OUTLINE_LUM = 38  # darker than this: the outline (the cells' walls)
INK = (30, 30, 26)  # the outline colour
INK_W = 5  # its width (source px)
ORIGIN = (638.0, 684.0)  # the feet: the near sole's ground line, under the hips
TOP_Y = 73.0  # the helmet's top
HALF = 2  # parts written at 1 / HALF
CROP = (470, 60, 820, 700)  # the debug pictures' window (source px)

# The backdrop seen through the figure (enclosed light areas: the gap between the near arm and the
# chest, the gap between the boots over the near toe), source px inside them.
HOLES = [(593, 452), (632, 620)]

SHIRT = (111, 119, 78)  # the uniform's green (shirt and sleeves)
SHIRT_DARK = (90, 93, 61)
SLEEVE_FAR = (88, 94, 60)
PAD = (106, 114, 105)  # the grey steel (shoulder and knee pads, the chest plate)
PAD_FAR = (86, 93, 86)
SKIN = (229, 179, 140)
SKIN_FAR = (205, 158, 126)
NECK = (205, 150, 125)
POUCH = (93, 82, 67)
BELT = (60, 60, 48)
PANTS = (83, 87, 64)
PANTS_FAR = (70, 74, 54)
CUFF = (60, 62, 47)

# The joints (source px).
J = {
    "hips": (638, 508), "torso": (638, 496), "head": (648, 378),
    "n_shoulder": (578, 392), "n_elbow": (572, 458), "n_hand": (580, 525),
    "f_shoulder": (690, 402), "f_elbow": (702, 460), "f_hand": (709, 517),
    "n_hip": (608, 512), "n_knee": (614, 570), "n_ankle": (603, 645),
    "f_hip": (670, 512), "f_knee": (686, 570), "f_ankle": (672, 636),
}
SOLE = {"n": 684.0, "f": 669.0}  # each foot's ground line (the far foot higher: 3/4 view)
BONES = [  # name, parent, joint
    ["hips", "", "hips"], ["torso", "hips", "torso"], ["head", "torso", "head"],
    ["f_shoulder", "torso", "f_shoulder"], ["f_elbow", "f_shoulder", "f_elbow"], ["f_hand", "f_elbow", "f_hand"],
    ["n_shoulder", "torso", "n_shoulder"], ["n_elbow", "n_shoulder", "n_elbow"], ["n_hand", "n_elbow", "n_hand"],
    ["f_hip", "hips", "f_hip"], ["f_knee", "f_hip", "f_knee"], ["f_ankle", "f_knee", "f_ankle"],
    ["n_hip", "hips", "n_hip"], ["n_knee", "n_hip", "n_knee"], ["n_ankle", "n_knee", "n_ankle"],
]

# Which part a px belongs to: the first polygon holding it (source px); the rest is the torso.
# The helmet and the chin strap ride the head; the knee pads ride the thighs (a round pad on the knee
# joint covers the shin's top whichever way the knee bends).
PARTS = {
    "head": [(470, 60), (830, 60), (830, 393), (750, 393), (700, 393), (688, 386), (668, 383), (645, 379), (626, 368),
             (610, 354), (598, 348), (560, 352), (470, 352)],
    "n_fist": [(550, 503), (598, 503), (604, 520), (604, 552), (550, 552)],
    "f_fist": [(698, 496), (730, 496), (730, 545), (694, 545), (694, 508)],
    "n_fore": [(536, 458), (592, 458), (592, 503), (536, 503)],
    "n_upper": [(536, 352), (598, 348), (606, 362), (605, 400), (595, 420), (592, 458), (536, 458)],
    "f_upper": [(686, 384), (720, 384), (720, 460), (690, 460)],
    "f_fore": [(690, 460), (720, 460), (720, 494), (694, 494)],
    "belt": [(582, 466), (704, 466), (704, 503), (582, 503)],
    "n_thigh": [(556, 503), (642, 503), (646, 548), (646, 594), (600, 594), (590, 578), (556, 578)],
    "f_thigh": [(642, 503), (712, 503), (712, 594), (668, 594), (660, 586), (646, 586)],
    "n_shin": [(540, 578), (590, 578), (600, 594), (639, 594), (639, 646), (650, 650), (650, 700), (540, 700)],
    "f_shin": [(646, 586), (660, 586), (668, 594), (740, 594), (740, 700), (650, 700), (650, 650), (639, 646), (639, 594)],
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
        # the shirt under the belt
        ([(590, 440), (700, 440), (700, 512), (590, 512)], SHIRT, False),
        # the neck under the chin strap
        ([(622, 340), (672, 340), (674, 400), (620, 400)], NECK, True),
        # the near shoulder under the shoulder pad and the collar under the strap (a round, outlined
        # shoulder: no ragged strap ends show when the near arm swings away)
        (ellipse(606, 390, 26, 24), SHIRT, True),
        # the back edge under the near arm: armpit → waist (kept under the arm at rest)
        ([(566, 392), (600, 378), (612, 390), (604, 470), (590, 470), (588, 440), (572, 420)], SHIRT_DARK, True),
    ],
    "belt": [
        # the belt's back end under the near forearm
        ([(584, 468), (604, 468), (604, 502), (584, 502)], BELT, [[(586, 468), (586, 502)]]),
    ],
    "seat": [
        ([(584, 494), (702, 494), (700, 530), (660, 544), (620, 546), (588, 534)], PANTS, False),
    ],
    "n_thigh": [
        (ellipse(608, 508, 36, 12), PANTS, False),  # the hip cap under the belt
        # the back under the near fist, outlined along the back edge only
        ([(574, 500), (606, 500), (606, 556), (570, 556)], PANTS, [[(574, 500), (570, 556)]]),
    ],
    "f_thigh": [
        (ellipse(670, 508, 34, 12), PANTS, False),
        # the back under the near thigh, the front under the far fist: outlined on the open edge only
        ([(632, 500), (654, 500), (654, 590), (632, 590)], PANTS, [[(634, 500), (634, 590)]]),
        ([(690, 500), (708, 500), (708, 548), (690, 548)], PANTS, [[(708, 500), (708, 548)]]),
    ],
    # the far arm behind the chest (the picture shows only its outer sliver): the grey shoulder pad and
    # the sleeve, open at the elbow (the forearm in front of it shows there)
    "f_upper": [([(668, 410), (676, 396), (692, 388), (708, 396), (712, 430), (714, 462), (682, 462), (674, 436)],
                 SLEEVE_FAR, [[(682, 462), (674, 436), (668, 410), (676, 396), (692, 388), (708, 396), (712, 430),
                               (714, 462)]]),
                (ellipse(692, 404, 20, 16), PAD_FAR, True)],
    "f_fore": [[(680, 452), (696, 446), (712, 450), (718, 470), (718, 500), (686, 500), (680, 478)]],
    # the joint caps (the child's end under its parent), whole ellipses
    "n_shin": [ellipse(612, 578, 30, 20)],  # the knees under the thighs' pads
    "f_shin": [ellipse(683, 580, 26, 18)],
    "n_fore": [ellipse(572, 458, 22, 10)],  # the elbow under the upper arm
    "n_fist": [ellipse(580, 506, 20, 7)],  # the wrist under the cuff (the far fist is over its forearm)
}
UNDER_FILL = {"n_thigh": PANTS, "f_thigh": PANTS_FAR, "n_shin": CUFF, "f_shin": CUFF, "n_fore": SHIRT,
              "n_fist": SKIN, "f_fist": SKIN_FAR, "f_upper": SLEEVE_FAR, "f_fore": SLEEVE_FAR}

# The rig's per-character tuning, written into rig.json (scenes/character/rig/rig_model.gd: aimPath,
# fallDeg, headBackDeg, torsoBackDeg; the gun's length and back sling are the carry scene's,
# scenes/character/poses/tanko_carry.tscn).
RIG_TUNING = {
    "fallDeg": -80.0,  # lying on the back: the big helmet and the heels on the ground (Rookie -72)
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
    left = outline & (owner < 0)
    if left.any():
        _, (iy, ix) = ndimage.distance_transform_edt(label < 0, return_indices=True)
        owner[left] = label[iy[left], ix[left]]
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
        gun_chest = (640, 428)
        data = {
            "source": "art_source/characters/tanko/rig/make_rig.py",
            "note": "rig px = source px / 2, feet at (0, 0); parts bottom first; xf = the part's rest "
                    "transform (image px -> rig px, Transform2D columns x, y, origin)",
            "height": round((ORIGIN[1] - TOP_Y) / HALF, 1),
            "bones": bones,
            "parts": parts,
            "points": {
                "n_sole": to_rig((J["n_ankle"][0], SOLE["n"])), "f_sole": to_rig((J["f_ankle"][0], SOLE["f"])),
                "chest": to_rig(gun_chest),
                # the outline points a body lying down rests on (char_rig: the fall lifts the lowest to the ground)
                "head_back": to_rig((494, 272)), "cap_back": to_rig((512, 180)), "cap_top": to_rig((640, 74)),
                "back": to_rig((550, 440)),
                "eye": to_rig((706, 262)),  # the near eye (tests: the muzzle stays off the face)
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
