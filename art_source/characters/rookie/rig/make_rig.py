#!/usr/bin/env python3
"""Rookie's bone rig (TEST, not used in matches): the chibi standing picture cut into parts for a
Skeleton2D (scenes/character/rig/char_rig.gd), made from the one picture
../side_idle/idle_v2.png (1364 x 768, white backdrop, facing right, standing, no gun).

  1. keyed: the white backdrop (the white px joined to the picture's border) removed, the soft
     outline edge un-mixed against white (no white fringe);
  2. cut: the picture split into its flat-colour cells (the regions between the dark outlines), each
     cell given to a part by the polygons below (PARTS, source px: a cell mostly inside one polygon
     goes whole, so the cuts follow the drawn outlines); the outline px between two parts belong to
     the one in front (OWN);
  3. the hidden areas painted (UNDER): what a part covers in the picture is painted on the part behind
     it in the same flat colours with the bold outline, so nothing tears or blurs when a part moves:
     the torso's back edge under the near sleeve, the neck under the chin, the shirt under the belt,
     the belt's ends under both fists, the thighs' backs / fronts under the fists and under each
     other, and a round cap at every joint (the child's end under its parent: elbow, wrist, hip,
     knee) so a bent joint shows a closed outline;
  4. the far arm: only a sliver of it shows in the picture (beside the chest): its upper arm and
     forearm are that sliver over a painted sleeve (a capsule behind the chest at rest), its fist the
     picture's own;
  5. written at half size (premultiplied area resampling): assets/characters/rookie/rig/<part>.png
     and rig.json (the bones' rest points, each part's bone, rest transform and draw order, and the
     points the motions use: grips, ankles, soles, the gun's chest point), rig px = (source px -
     ORIGIN) / 2, the feet on y 0.

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow, OpenCV):

  python3 -I art_source/characters/rookie/rig/make_rig.py [--debug DIR]

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
OUT = os.path.join(REPO, "assets", "characters", "rookie", "rig")

NOISE = 0.06
OUTLINE_LUM = 40  # darker than this: the outline (the cells' walls)
INK = (30, 30, 38)  # the outline colour
INK_W = 5  # its width (source px)
ORIGIN = (690.0, 727.0)  # the feet: the near sole's ground line, between the feet
HALF = 2  # parts written at 1 / HALF

SHIRT = (71, 105, 134)
TROUSER = (48, 65, 85)
SKIN = (225, 178, 144)
NECK = (205, 150, 125)
BELT = (96, 85, 68)
POUCH = (90, 80, 64)
SLEEVE_FAR = (66, 98, 128)

# The joints (source px).
J = {
    "hips": (690, 560), "torso": (690, 548), "head": (697, 402),
    "n_shoulder": (600, 438), "n_elbow": (590, 494), "n_hand": (594, 577),
    "f_shoulder": (757, 446), "f_elbow": (774, 503), "f_hand": (779, 569),
    "n_hip": (648, 576), "n_knee": (652, 618), "n_ankle": (638, 690),
    "f_hip": (724, 576), "f_knee": (734, 618), "f_ankle": (732, 680),
}
SOLE = {"n": 727.0, "f": 712.0}  # each foot's ground line (the far foot higher: 3/4 view)
BONES = [  # name, parent, joint
    ["hips", "", "hips"], ["torso", "hips", "torso"], ["head", "torso", "head"],
    ["f_shoulder", "torso", "f_shoulder"], ["f_elbow", "f_shoulder", "f_elbow"], ["f_hand", "f_elbow", "f_hand"],
    ["n_shoulder", "torso", "n_shoulder"], ["n_elbow", "n_shoulder", "n_elbow"], ["n_hand", "n_elbow", "n_hand"],
    ["f_hip", "hips", "f_hip"], ["f_knee", "f_hip", "f_knee"], ["f_ankle", "f_knee", "f_ankle"],
    ["n_hip", "hips", "n_hip"], ["n_knee", "n_hip", "n_knee"], ["n_ankle", "n_knee", "n_ankle"],
]

# Which part a px belongs to: the first polygon holding it (source px); the rest is the torso.
PARTS = {
    "head": [(420, 30), (950, 30), (950, 330), (802, 356), (784, 380), (762, 395), (735, 401), (705, 401),
             (680, 399), (655, 396), (636, 391), (620, 395), (602, 399), (575, 399), (540, 401), (420, 401)],
    "n_fist": [(556, 549), (628, 549), (629, 606), (556, 606)],
    "f_fist": [(756, 545), (808, 538), (810, 600), (756, 600)],
    "n_fore": [(540, 491), (621, 501), (619, 520), (618, 549), (540, 549)],
    "n_upper": [(540, 401), (603, 400), (616, 410), (629, 425), (637, 445), (637, 462), (631, 480), (621, 501),
                (540, 491)],
    "f_upper": [(757, 412), (805, 418), (805, 497), (761, 503), (760, 470), (758, 430)],
    "f_fore": [(761, 503), (805, 497), (805, 546), (764, 546), (762, 515)],
    "belt": [(608, 512), (776, 512), (776, 563), (608, 563)],
    "n_thigh": [(590, 563), (702, 563), (699, 576), (692, 598), (684, 619), (590, 619)],
    "f_thigh": [(686, 563), (780, 563), (780, 619), (686, 619)],
    "n_shin": [(580, 619), (690, 619), (690, 745), (580, 745)],
    "f_shin": [(690, 619), (810, 619), (810, 745), (690, 745)],
}
# Parts cut px by px along their polygon (the cells there run on into the chest).
HARD = {"f_upper", "f_fore"}
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


def capsule(a, b, ra, rb, n=24):
    """A stadium round a segment a → b, radius ra at a, rb at b."""
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    out = []
    for i in range(n + 1):
        t = ang + math.pi / 2 + math.pi * i / n
        out.append((a[0] + ra * math.cos(t), a[1] + ra * math.sin(t)))
    for i in range(n + 1):
        t = ang - math.pi / 2 + math.pi * i / n
        out.append((b[0] + rb * math.cos(t), b[1] + rb * math.sin(t)))
    return out


# The hidden areas, painted under each part (polygon, fill colour, outlined?): listed bottom first.
UNDER = {
    "torso": [
        # the shirt under the belt (hidden by the belt and the seat)
        ([(612, 505), (756, 505), (756, 556), (612, 556)], SHIRT, False),
        # the neck under the chin
        ([(668, 360), (728, 360), (730, 418), (666, 418)], NECK, True),
        # the back edge under the near sleeve: shoulder → waist
        ([(598, 416), (612, 405), (650, 403), (660, 520), (614, 522), (604, 506), (597, 476), (594, 446)], SHIRT, True),
    ],
    "belt": [
        # the belt's back end under the near cuff and fist
        ([(610, 516), (640, 516), (640, 559), (610, 559), (606, 538)], BELT, True),
        # the right pouch's bottom under the far fist
        ([(750, 515), (765, 515), (766, 562), (752, 562)], POUCH, True),
    ],
    "seat": [
        ([(612, 548), (770, 548), (766, 586), (738, 600), (700, 606), (660, 600), (616, 588)], TROUSER, False),
    ],
    "n_thigh": [
        (ellipse(650, 568, 40, 16), TROUSER, False),  # the hip cap under the belt
        # the back under the near fist, outlined along the back edge only
        ([(606, 556), (650, 556), (650, 619), (603, 619), (603, 600)], TROUSER, [[(606, 556), (603, 600), (603, 619)]]),
    ],
    "f_thigh": [
        (ellipse(722, 568, 34, 16), TROUSER, False),
        # the back under the near thigh, the front under the far fist: outlined on the open edge only
        ([(689, 560), (712, 560), (708, 619), (695, 619)], TROUSER, [[(689, 560), (695, 619)]]),
        ([(732, 556), (758, 556), (757, 619), (732, 619)], TROUSER, [[(758, 556), (757, 619)]]),
    ],
    # the far sleeve behind the chest (the picture shows only its outer sliver)
    "f_upper": [[(737, 436), (745, 428), (755, 425), (760, 442), (767, 480), (772, 500), (762, 504), (746, 500),
                 (739, 470)]],
    "f_fore": [[(747, 497), (752, 488), (764, 485), (776, 496), (783, 510), (788, 528), (788, 546), (754, 548),
                (749, 520)]],
    # the joint caps (the child's end under its parent), whole ellipses: their lower half is under the
    # child's own px, so no outline crosses the limb
    "n_shin": [ellipse(646, 620, 33, 16)],  # the knees under the thighs
    "f_shin": [ellipse(727, 620, 28, 16)],
    "n_fore": [ellipse(591, 497, 28, 13)],  # the elbow under the upper arm
    "n_fist": [ellipse(594, 556, 22, 9)],  # the wrist under the cuff
}
UNDER_FILL = {"n_thigh": TROUSER, "f_thigh": TROUSER, "n_shin": TROUSER, "f_shin": TROUSER, "n_fore": SHIRT,
              "n_fist": SKIN, "f_fist": SKIN, "f_upper": SLEEVE_FAR, "f_fore": SLEEVE_FAR}

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
    """Straight colour and alpha of the picture with its white backdrop removed."""
    h, w, _ = rgb.shape
    white = rgb.min(axis=2) > 236
    lab, _n = ndimage.label(white)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    core = ndimage.binary_erosion(bg, iterations=1)
    band = (ndimage.distance_transform_edt(~bg) <= 3) & ~core
    a = ((255.0 - rgb) / 255.0).max(axis=2)
    a = np.clip((a - NOISE) / (1 - NOISE), 0, 1)
    alpha = np.where(bg & ~band, 0.0, 1.0)
    alpha = np.where(band, a, alpha)
    col = 255.0 + (rgb - 255.0) / np.maximum(alpha, 1e-4)[..., None]
    s = np.clip((alpha - 0.5) / 0.3, 0, 1)
    col = np.clip(col, 0, 255) * (1 - s)[..., None] + rgb * s[..., None]
    col = np.where(band[..., None], col, rgb)
    alpha[alpha < 0.03] = 0
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
        gun_chest = (722, 468)
        data = {
            "source": "art_source/characters/rookie/rig/make_rig.py",
            "note": "TEST rig: rig px = source px / 2, feet at (0, 0); parts bottom first; xf = the part's rest "
                    "transform (image px -> rig px, Transform2D columns x, y, origin)",
            "height": round((ORIGIN[1] - 68.0) / HALF, 1),
            "bones": bones,
            "parts": parts,
            "points": {
                "n_sole": to_rig((J["n_ankle"][0], SOLE["n"])), "f_sole": to_rig((J["f_ankle"][0], SOLE["f"])),
                "chest": to_rig(gun_chest),
                # the outline points a body lying down rests on (char_rig: the fall lifts the lowest to the ground)
                "head_back": to_rig((474, 300)), "cap_back": to_rig((492, 190)), "cap_top": to_rig((640, 72)),
                "back": to_rig((556, 480)),
            },
            "gunUnder": "n_fist",
        }
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
        Image.fromarray(mix.astype(np.uint8)).crop((440, 40, 920, 745)).save(os.path.join(d, "part_map.png"))
        # rest compose beside the picture
        rest = self.compose_rest()
        bg = np.full((h, w, 3), 205.0)
        a = rest[..., 3:4]
        comp = bg * (1 - a) + rest[..., :3]
        orig = bg * (1 - self.alpha[..., None]) + self.col * self.alpha[..., None]
        both = np.concatenate([orig[40:745, 440:920], comp[40:745, 440:920]], axis=1)
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
