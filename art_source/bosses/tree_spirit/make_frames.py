#!/usr/bin/env python3
"""Mộc Tinh (boss id tree_spirit): every picture the game needs, made from the one picture the user
gave, concept/ancient_tree_v1.png (an ancient tree with a grumpy face on its trunk, glowing green eyes
with purple rims, a dark green canopy with purple leaves, glowing green / purple mushrooms on the trunk
and the branches, a few crystals, bare side roots, big roots; front view, standing still).

A tree bends, it does not hinge: the frames are posed by a smooth skin over the whole picture (every px
moved by the bones near it, the weights blended over a few px, so wood bends at a joint and nothing
tears), not by rigid cut-outs. No AI sheets exist for this boss:

  1. keyed: the flat sky-blue backdrop and the darker blue ground-shadow ellipse removed by colour (the
     tree has no such blue), the ✦ watermark painted out first; the glows round the mushrooms and the
     crystals that sit on the sky kept as their own soft layer (the halo: alpha in its own mint colour,
     un-mixed from the sky, no blue in it); the figure's edge un-mixed against the colour next to it
     (the sky, or the halo where it glows), so no blue fringe; the tiny sky pockets between leaves
     filled from their neighbours;
  2. cut into parts: the picture split into its flat-colour cells (between the dark outlines), each
     cell given to a part (the four canopy clumps by their leaf colour and where they are, the left /
     right leafy branch, the two bare side roots, the outer roots left / right, the trunk with its face
     and mushrooms: PARTS); the outline px between two parts to the one in front;
  3. a skeleton (RIG: root at the feet → trunk (its base) → crown (the fork under the canopy) → the
     four canopy clumps; the trunk → the leafy branches; the root → the side roots (two bones each, a
     chain: they curl), the outer roots) with per-px weights (each part's px, blurred so joints bend);
  4. per frame (ANIMS) the bones posed, the swell of the trunk (the drain), and what glows or changes:
     the eyes (dim .. flare), the mushrooms and the crystals with their halos (out .. blaze), the heart
     (a green glow on the trunk under the mouth, the drain's end), the leaves withering brown, bark
     cracks, a painted root that snakes out along the ground (the root drag), painted leaves falling;
  5. each frame drawn at full size in a fixed cell (the feet, the trunk's foot on the ground line, at
     CELL_FEET), halved into one row per animation: side_<anim>/sheet_v1.png, transparent.

Also written: skin/rest_v1.png (the rest pose: the skinned idle's picture), the portrait (the rest
pose, glows lit), the bust (the face with the canopy, faded out under the mouth), parts/<name>_v1.png
(the death's pieces in the last death frame's pose: the four withered canopy clumps, the branches, the
side roots, the outer roots, the trunk; cut edges outlined), rig_v1.json (the points: source px and
the unit frame), assets/bosses/tree_spirit/side/points.json (per frame) and import.json (the importer's
config).

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow, OpenCV):

  python3 -I art_source/bosses/tree_spirit/make_frames.py [--debug DIR [--check | --preview a,b]]
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- tree_spirit

--debug DIR writes the keyed picture on dark / orange, the halo alone, the part map, the weights.
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
SRC = os.path.join(HERE, "concept", "ancient_tree_v1.png")
ASSETS = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "bosses", "tree_spirit"))

# ── The picture (source px, 1380 × 752) ──────────────────────────────────────
SKY = np.array([116.0, 179.0, 233.0])  # the flat backdrop
SHADOW = np.array([85.0, 137.0, 177.0])  # the ground-shadow ellipse
WATERMARK = (1322, 697, 30)  # the ✦ on the sky: centre, radius
FEET = (706.0, 718.0)  # the trunk's foot on the ground line (the roots rest on it)
TOP = 16.0  # the canopy's top: the body is TOP → FEET (702 px)
BODY_H = FEET[1] - TOP
OUTLINE_LUM = 34  # darker than this is outline (the cells' walls)
INK = (8, 20, 30)  # the outline colour
INK_W = 6
BARK = (102, 90, 76)
BARK_LIGHT = (112, 106, 80)
BARK_SHADE = (66, 56, 64)
WOOD = (150, 128, 92)  # the pale wood at a crack's edge
MINT = (150, 255, 200)  # the glows' colour (mushrooms, eyes, crystals, the heart)
HEART = (712.0, 566.0)  # the tree's heart on the trunk, under the mouth (the drain's end)
CANOPY_PT = (706.0, 120.0)  # where the poison thorns leave the canopy (its middle, near the top)
EYE_BOX = (680, 425, 822, 472)
FACE_BOX = (600, 380, 860, 600)

# The glows (mushrooms, crystals): centre, radius of the zone their px and halo live in.
GLOWS = {
    "mush_branch_l": ((598, 286), 34), "mush_trunk": ((778, 326), 44), "mush_branch_r": ((858, 310), 30),
    "mush_side": ((614, 420), 32), "shelf": ((620, 498), 30),
    "crystal_canopy": ((460, 168), 34), "crystal_top": ((904, 52), 34), "crystal_branch": ((906, 330), 28),
}
MUSHROOMS = ["mush_branch_l", "mush_trunk", "mush_branch_r", "mush_side", "shelf"]

# Parts: polygons that take a cell first (in this order); then the leaf cells inside CANOPY go to
# the clump grown from the nearest seed (CLUMPS) up to the drawn outlines; the rest is the trunk.
PARTS = {
    "branch_l": [(398, 336), (420, 314), (512, 306), (548, 326), (588, 336), (592, 366), (540, 380), (516, 428),
                 (430, 428), (396, 404)],
    "branch_r": [(944, 372), (972, 330), (1072, 318), (1078, 404), (1036, 412), (1016, 432), (980, 424), (944, 404)],
    "tendril_l": [(418, 448), (470, 446), (506, 494), (548, 514), (566, 540), (560, 574), (530, 584), (494, 548),
                  (446, 522), (416, 484)],
    "tendril_r": [(918, 562), (944, 512), (978, 486), (1002, 496), (998, 560), (962, 586), (944, 604), (924, 600)],
    "root_l": [(350, 604), (472, 600), (480, 650), (470, 730), (350, 730)],
    "root_r": [(966, 600), (1060, 600), (1060, 710), (972, 710)],
}
# Leaf cells inside this outline are canopy (under it: the limbs, the fork).
CANOPY = [(316, 10), (1094, 10), (1094, 318), (1000, 318), (960, 312), (900, 300), (850, 290), (800, 262), (760, 258),
          (720, 268), (660, 270), (610, 282), (566, 300), (520, 308), (470, 318), (420, 342), (316, 352)]
CLUMPS = [("canopy_l", (430, 220), 50), ("canopy_ml", (630, 110), 50), ("canopy_mr", (820, 140), 50),
          ("canopy_r", (1000, 225), 45)]  # the clumps: a seed each (centre, radius)
# Who owns the outline px between two parts (front first).
OWN = ["branch_l", "branch_r", "canopy_mr", "canopy_ml", "canopy_l", "canopy_r", "tendril_l", "tendril_r", "trunk",
       "root_l", "root_r"]

# The joints (source px).
J = {
    "feet": FEET, "trunk": (708.0, 650.0), "crown": (712.0, 330.0),
    "canopy_l": (560.0, 252.0), "canopy_ml": (650.0, 214.0), "canopy_mr": (790.0, 214.0), "canopy_r": (900.0, 252.0),
    "branch_l": (588.0, 352.0), "branch_r": (944.0, 390.0),
    "tendril_l": (548.0, 562.0), "tendril_l2": (480.0, 516.0), "tendril_r": (936.0, 598.0), "tendril_r2": (958.0, 546.0),
    "root_l": (500.0, 650.0), "root_r": (950.0, 640.0),
}
# The skeleton: bone → (parent, pivot joint).
RIG = {
    "root": (None, "feet"),
    "trunk": ("root", "trunk"), "crown": ("trunk", "crown"),
    "canopy_l": ("crown", "canopy_l"), "canopy_ml": ("crown", "canopy_ml"), "canopy_mr": ("crown", "canopy_mr"),
    "canopy_r": ("crown", "canopy_r"),
    "branch_l": ("trunk", "branch_l"), "branch_r": ("trunk", "branch_r"),
    "tendril_l": ("root", "tendril_l"), "tendril_l2": ("tendril_l", "tendril_l2"),
    "tendril_r": ("root", "tendril_r"), "tendril_r2": ("tendril_r", "tendril_r2"),
    "root_l": ("root", "root_l"), "root_r": ("root", "root_r"),
}
TIPS = {"tendril_l": (432.0, 460.0), "tendril_r": (984.0, 500.0)}  # the side roots' tips (their chain's axis)
CROWN_FROM = (440.0, 262.0)  # rows: the trunk's weight goes to the crown between these (bottom → top)
BLUR = 9.0  # the weights' blur (px)

# The death's bark cracks (source px polylines; the stage they appear in, 1..3).
CRACKS = [
    (1, [(712, 520), (704, 548), (716, 572), (708, 600)]),
    (1, [(660, 400), (672, 424), (664, 446)]),
    (2, [(770, 392), (758, 414), (768, 432)]),
    (2, [(708, 600), (690, 624), (700, 650), (686, 676)]),
    (2, [(640, 470), (652, 500), (642, 530), (650, 556)]),
    (2, [(800, 480), (788, 508), (798, 536)]),
    (3, [(716, 572), (740, 598), (734, 626), (752, 652)]),
    (3, [(600, 600), (586, 622), (596, 646)]),
    (3, [(840, 590), (852, 612), (842, 636)]),
    (3, [(700, 260), (712, 290), (704, 318)]),
]
# The death's pieces, back to front.
PIECES = ["tendril_l", "tendril_r", "root_l", "root_r", "trunk", "branch_l", "branch_r", "canopy_l", "canopy_r",
          "canopy_ml", "canopy_mr"]

CELL = (1100, 820)  # the full-size cell
CELL_FEET = (420, 788)  # the feet in it
HALF = 2

# The root drag's root (painted): it leaves from behind the right roots along the ground line.
DRAG_FROM = (900.0, 698.0)
DRAG_REACH = 250.0  # px along the ground at full reach
LEAF_SEEDS = 11


def lum(rgb):
    return rgb @ np.array([0.299, 0.587, 0.114])


def hsv(rgb):
    mx, mn = rgb.max(axis=-1), rgb.min(axis=-1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return hue, (mx - mn) / np.maximum(mx, 1e-6), mx / 255.0


def poly_mask(h, w, pts):
    m = np.zeros((h, w), np.uint8)
    cv2.fillPoly(m, [np.round(np.array(pts) * 8).astype(np.int32)], 1, lineType=cv2.LINE_8, shift=3)
    return m.astype(bool)


def disc(h, w, c, r):
    yy, xx = np.mgrid[0:h, 0:w]
    return (xx - c[0]) ** 2 + (yy - c[1]) ** 2 <= r * r


def key(rgb):
    """The keyed picture as two premultiplied layers (H, W, 4): the body (the figure, its soft edge)
    and the halo (the glows on the sky, under the body's edge)."""
    h, w, _ = rgb.shape
    rgb = rgb.copy()
    wx, wy, wr = WATERMARK
    rgb[disc(h, w, (wx, wy), wr)] = SKY
    # The backdrop: the sky, the shadow and the soft line between them (residual from that segment).
    v = SHADOW - SKY
    t = np.clip(((rgb - SKY) @ v) / (v @ v), 0, 1)
    res = np.linalg.norm(rgb - (SKY + t[..., None] * v), axis=2)
    core = res < 9
    _, (iy, ix) = ndimage.distance_transform_edt(~core, return_indices=True)
    bg = SKY + t[iy, ix][..., None] * v
    d = rgb - bg
    up = np.where(d > 0, d / np.maximum(255 - bg, 1), 0).max(axis=2)
    # The halo: lighter and greener than the backdrop, in blobs of some size.
    halo = (~core) & (d[..., 1] > 10) & (d[..., 1] > d[..., 2] + 6) & (lum(rgb) >= lum(bg) - 6)
    lab, n = ndimage.label(halo)
    if n:
        sizes = ndimage.sum(np.ones((h, w)), lab, range(1, n + 1))
        halo &= np.isin(lab, 1 + np.nonzero(sizes >= 150)[0])
    # Backdrop noise (JPEG ringing, lighter px near the backdrop colours that are not halo).
    core |= (~core) & (~halo) & (lum(rgb) >= lum(bg) - 4) & (res < 40)
    back = core | halo
    lab, n = ndimage.label(back)
    keep = np.unique(lab[core])
    back = np.isin(lab, keep[keep > 0])
    halo &= back
    ah = np.where(halo, np.clip((up - 0.05) / 0.95, 0, 1), 0.0)
    ch = np.clip(bg + d / np.maximum(ah, 1e-3)[..., None], 0, 255)
    ah[ah < 0.04] = 0
    # Its outer edge softened (a fade, not a step).
    zone = ndimage.binary_dilation(halo, iterations=4) & back
    _, (hy, hx) = ndimage.distance_transform_edt(~halo, return_indices=True)
    ch = np.where((zone & ~halo)[..., None], ch[hy, hx], ch)
    soft = ndimage.gaussian_filter(ah, 1.5)
    ah = np.where(zone, np.where(halo, ah, soft), 0.0)
    # The figure and its edge band (≤ 3 px from the backdrop): un-mixed (darker only: the edge is the
    # dark outline) against the colour seen next to it.
    fig = ~back
    band = fig & (ndimage.distance_transform_edt(fig) <= 3)
    _, (jy, jx) = ndimage.distance_transform_edt(fig, return_indices=True)
    obs = rgb[jy, jx]
    dd = rgb - obs
    ae = np.where(dd < 0, -dd / np.maximum(obs, 1), 0).max(axis=2)
    ae = np.clip((ae - 0.06) / 0.72, 0, 1)
    ce = np.clip(obs + dd / np.maximum(ae, 1e-3)[..., None], 0, 255)
    s = np.clip((ae - 0.5) / 0.3, 0, 1)[..., None]
    ce = ce * (1 - s) + rgb * s
    a_body = np.where(band, ae, np.where(fig, 1.0, 0.0))
    c_body = np.where(band[..., None], ce, rgb)
    # The halo under the edge band: the halo next to it.
    a_halo = np.where(band, ah[jy, jx], ah)
    c_halo = np.where(band[..., None], ch[jy, jx], ch)
    # Specks: faint light px in the band that are not glow.
    speck = band & (a_body < 0.45) & (lum(c_body) > 100) & (a_halo < 0.05)
    a_body[speck] = 0
    # Tiny sky pockets between the leaves (light grey-blue px inside the figure): their neighbours' colour.
    pocket = fig & ~band & (lum(rgb) > 135) & (rgb[..., 2] > rgb[..., 0] + 18) & (rgb[..., 2] >= rgb[..., 1])
    for (cx, cy), r in GLOWS.values():
        pocket &= ~disc(h, w, (cx, cy), r + 6)
    plab, pn = ndimage.label(pocket)
    if pn:
        psz = ndimage.sum(np.ones((h, w)), plab, range(1, pn + 1))
        pocket = np.isin(plab, 1 + np.nonzero(psz < 40)[0])
        grow = ndimage.binary_dilation(pocket, iterations=1)
        _, (qy, qx) = ndimage.distance_transform_edt(grow, return_indices=True)
        c_body[grow] = rgb[qy[grow], qx[grow]]
    # Only the figure (its biggest piece) and what is near it.
    lab, n = ndimage.label(a_body > 0.5, structure=np.ones((3, 3)))
    sizes = ndimage.sum(np.ones((h, w)), lab, range(1, n + 1))
    main = lab == (1 + int(np.argmax(sizes)))
    near = ndimage.distance_transform_edt(~main) < 60
    a_body[~ndimage.binary_dilation(main, iterations=2)] = 0
    a_halo[~near] = 0
    body = np.dstack([c_body * a_body[..., None], a_body]).astype(np.float32)
    hal = np.dstack([c_halo * a_halo[..., None], a_halo]).astype(np.float32)
    return body, hal


def over(dst, src):
    """src over dst (premultiplied float RGBA), in place."""
    a = src[..., 3:4]
    dst *= (1 - a)
    dst += src


def unpm(layer):
    a = layer[..., 3:4]
    rgb = np.where(a > 1e-4, layer[..., :3] / np.maximum(a, 1e-4), 0)
    return np.dstack([np.clip(rgb, 0, 255), np.clip(a * 255, 0, 255)]).astype(np.uint8)


def straight(layer):
    a = layer[..., 3]
    return np.where(a[..., None] > 1e-4, layer[..., :3] / np.maximum(a, 1e-4)[..., None], 0), a


def segment(body):
    """Per part its px (names → masks) and the outline mask."""
    h, w = body.shape[:2]
    col, alpha = straight(body)
    solid = alpha > 0.5
    rim = solid & (ndimage.distance_transform_edt(solid) <= 2.5)
    outline = solid & ((lum(col) < OUTLINE_LUM) | rim)
    cells, n = ndimage.label(solid & ~outline)
    ids = np.arange(1, n + 1)
    hue, sat, val = hsv(col)
    leafy = (((hue >= 85) & (hue <= 205) & (sat > 0.2)) | ((hue >= 240) & (hue <= 300) & (sat > 0.22))) & (val < 0.72)
    for (cx, cy), r in GLOWS.values():
        if cy > 120 and not (cx < 480):  # the mushrooms and the branch crystal are not leaves
            leafy &= ~disc(h, w, (cx, cy), r)
    leaf_share = ndimage.mean(leafy.astype(float), cells, ids)
    yy, xx = np.mgrid[0:h, 0:w]
    names = list(PARTS) + [c[0] for c in CLUMPS] + ["trunk"]
    idx = np.full((h, w), names.index("trunk"), np.int16)
    # The canopy: leaf cells high up, by band.
    in_canopy = ndimage.mean(poly_mask(h, w, CANOPY).astype(float), cells, ids)
    canopy_cells = [int(i) for i, s_, c_ in zip(ids, leaf_share, in_canopy) if s_ > 0.5 and c_ > 0.5]
    canopy = np.isin(cells, canopy_cells) & poly_mask(h, w, CANOPY)
    # The glowing crystal in the canopy and the top crystal belong to it.
    for g in ("crystal_canopy", "crystal_top"):
        (gx, gy), r = GLOWS[g]
        canopy |= disc(h, w, (gx, gy), r - 6) & solid
    # The clumps: grown from their seeds over the canopy (watershed), meeting on the drawn outlines.
    ridge = np.where(lum(col) < 70, 255, 0).astype(np.uint8)
    ridge = cv2.GaussianBlur(ridge, (0, 0), 1.5)
    markers = np.zeros((h, w), np.int32)
    markers[~canopy] = 1
    for k, (nm, (sx_, sy_), r) in enumerate(CLUMPS):
        markers[disc(h, w, (sx_, sy_), r) & canopy] = 2 + k
    ws = cv2.watershed(np.dstack([ridge] * 3), markers)
    lab = np.where(canopy, ws, 0)
    stray = canopy & (lab < 2)
    good = lab >= 2
    _, (iy, ix) = ndimage.distance_transform_edt(~good, return_indices=True)
    lab[stray] = lab[iy[stray], ix[stray]]
    for k, (nm, _, _) in enumerate(CLUMPS):
        idx[canopy & (lab == 2 + k)] = names.index(nm)
    for k in range(len(PARTS) - 1, -1, -1):
        idx[poly_mask(h, w, PARTS[names[k]])] = k
    # A cell mostly (≥ 75 %) in one part goes whole to it.
    order = np.argsort(cells.ravel(), kind="stable")
    flat = idx.ravel()[order]
    bounds = np.searchsorted(cells.ravel()[order], np.arange(0, n + 2))
    for i in ids:
        vals = flat[bounds[i]:bounds[i + 1]]
        if vals.size == 0 or vals.size > 12000:  # a huge cell (leaves and bark run together): px by px
            continue
        cnt = np.bincount(vals, minlength=len(names))
        k = int(np.argmax(cnt))
        if cnt[k] >= 0.75 * vals.size:
            idx[cells == i] = k
    label = np.full((h, w), -1, np.int16)
    label[solid & ~outline] = idx[solid & ~outline]
    sizes = ndimage.sum(np.ones((h, w)), cells, ids)
    small = np.isin(cells, ids[sizes < 30])
    big = (label >= 0) & ~small
    _, (iy, ix) = ndimage.distance_transform_edt(~big, return_indices=True)
    label[small] = label[iy[small], ix[small]]
    owner = np.full((h, w), -1, np.int16)
    for nm in reversed(OWN):
        k = names.index(nm)
        near = ndimage.binary_dilation(label == k, iterations=INK_W + 1)
        owner[near & outline] = k
    left = outline & (owner < 0)
    if left.any():
        _, (iy, ix) = ndimage.distance_transform_edt(label < 0, return_indices=True)
        owner[left] = label[iy[left], ix[left]]
    label[outline] = owner[outline]
    faint = (alpha > 0) & (label < 0)
    _, (iy, ix) = ndimage.distance_transform_edt(~(label >= 0), return_indices=True)
    label[faint] = label[iy[faint], ix[faint]]
    # Every px (also the transparent ones) to the nearest part: the weights cover the whole picture.
    full = label.copy()
    _, (iy, ix) = ndimage.distance_transform_edt(label < 0, return_indices=True)
    full[label < 0] = label[iy[label < 0], ix[label < 0]]
    return {nm: label == k for k, nm in enumerate(names)}, {nm: full == k for k, nm in enumerate(names)}, outline, leafy


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def stroke(h, w, pts, width, ss=4):
    big = np.zeros((h * ss, w * ss), np.uint8)
    cv2.polylines(big, [np.round(np.array(pts) * ss).astype(np.int32)], False, 255, max(1, int(width * ss)), lineType=cv2.LINE_AA)
    return cv2.resize(big.astype(np.float32) / 255.0, (w, h), interpolation=cv2.INTER_AREA)


def fill_poly(h, w, poly, ss=4):
    big = np.zeros((h * ss, w * ss), np.uint8)
    cv2.fillPoly(big, [np.round(np.array(poly) * ss).astype(np.int32)], 255)
    return cv2.resize(big.astype(np.float32) / 255.0, (w, h), interpolation=cv2.INTER_AREA)


def tint(lay, mask, rgb, k):
    """Blend the masked px of a premultiplied layer toward rgb by k (mask 0..1 or bool)."""
    if np.isscalar(k) and k <= 0:
        return lay
    m = (mask.astype(np.float32) * k)[..., None]
    out = lay.copy()
    out[..., :3] = lay[..., :3] * (1 - m) + np.array(rgb, np.float32) * lay[..., 3:4] * m
    return out


def glow(dst, cx, cy, r, colour, strength):
    """A soft round glow over dst (premultiplied), its alpha added where the figure is not."""
    if strength <= 0 or r <= 0:
        return
    h, w = dst.shape[:2]
    x0, x1 = max(0, int(cx - r)), min(w, int(cx + r) + 1)
    y0, y1 = max(0, int(cy - r)), min(h, int(cy + r) + 1)
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    a = np.clip(1 - d, 0, 1) ** 2 * strength
    a = np.clip(a, 0, 1).astype(np.float32)
    sub = dst[y0:y1, x0:x1]
    src = np.array(colour, np.float32)[None, None, :] * a[..., None]
    sub[..., :3] = sub[..., :3] + src * (1 - sub[..., :3] / 255.0)
    sub[..., 3] = sub[..., 3] + a * (1 - sub[..., 3])


def leaf_sprite(size, colour, rot, ss=4):
    """A painted leaf (pointed oval, midrib, bold outline), premultiplied, centred in a square."""
    n = int(size * 2.4) | 1
    big = np.zeros((n * ss, n * ss, 4), np.uint8)
    c = n * ss / 2
    L, W = size * ss, size * ss * 0.42
    pts = []
    for i in range(24):
        t = i / 23 * math.pi
        pts.append((c + L * math.cos(t) * 1.0 - 0, c + W * math.sin(t)))
    for i in range(24):
        t = math.pi + i / 23 * math.pi
        pts.append((c + L * math.cos(t), c + W * math.sin(t)))
    rr = math.radians(rot)
    pts = [(c + (x - c) * math.cos(rr) - (y - c) * math.sin(rr), c + (x - c) * math.sin(rr) + (y - c) * math.cos(rr)) for x, y in pts]
    p = np.round(np.array(pts)).astype(np.int32)
    cv2.fillPoly(big, [p], (*INK, 255))
    inner = np.zeros((n * ss, n * ss), np.uint8)
    cv2.fillPoly(inner, [p], 255)
    inner = cv2.erode(inner, np.ones((int(2.2 * ss), int(2.2 * ss)), np.uint8))
    big[inner > 0] = (*colour, 255)
    a, b = (c - L * 0.8 * math.cos(rr), c - L * 0.8 * math.sin(rr)), (c + L * 0.8 * math.cos(rr), c + L * 0.8 * math.sin(rr))
    rib = np.zeros_like(inner)
    cv2.line(rib, (int(a[0]), int(a[1])), (int(b[0]), int(b[1])), 255, max(1, int(1.2 * ss)))
    dark = tuple(int(v * 0.62) for v in colour)
    big[(rib > 0) & (inner > 0)] = (*dark, 255)
    small = cv2.resize(big.astype(np.float32) / 255.0, (n, n), interpolation=cv2.INTER_AREA)
    return np.dstack([small[..., :3] * small[..., 3:4] * 255.0, small[..., 3]]).astype(np.float32)


def blit(dst, spr, cx, cy):
    """Premultiplied sprite over dst, centred at (cx, cy)."""
    h, w = dst.shape[:2]
    sh, sw = spr.shape[:2]
    x0, y0 = int(round(cx - sw / 2)), int(round(cy - sh / 2))
    ax0, ay0, ax1, ay1 = max(0, x0), max(0, y0), min(w, x0 + sw), min(h, y0 + sh)
    if ax0 >= ax1 or ay0 >= ay1:
        return
    over(dst[ay0:ay1, ax0:ax1], spr[ay0 - y0:ay1 - y0, ax0 - x0:ax1 - x0])


LEAF_COLOURS = {"green": (62, 120, 84), "dark": (44, 84, 70), "purple": (110, 82, 150), "brown": (150, 100, 48),
                "brown2": (120, 78, 40)}


class Tree:
    def __init__(self, debug=None):
        rgb = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64)
        self.h, self.w = rgb.shape[:2]
        h, w = self.h, self.w
        self.body, self.halo = key(rgb)
        self.mask, self.full, self.outline, leafy = segment(self.body)
        col, alpha = straight(self.body)
        hue, sat, val = hsv(col)
        solid = alpha > 0.4
        # What glows: the eyes, the mushrooms, the crystals (per zone).
        eb = EYE_BOX
        self.eyes = poly_mask(h, w, [(eb[0], eb[1]), (eb[2], eb[1]), (eb[2], eb[3]), (eb[0], eb[3])]) & solid & \
            (col[..., 1] > 150) & (col[..., 1] > col[..., 0] + 40)
        ys, xs = np.nonzero(self.eyes)
        left = xs < (eb[0] + eb[2]) / 2
        self.eye_pts = [(float(xs[left].mean()), float(ys[left].mean())), (float(xs[~left].mean()), float(ys[~left].mean()))]
        self.glow_px = {}
        for g, ((cx, cy), r) in GLOWS.items():
            zone = disc(h, w, (cx, cy), r) & solid
            greenish = (col[..., 1] > 140) & (col[..., 1] > col[..., 0] + 30)
            purplish = (hue >= 240) & (hue <= 300) & (val > 0.5) & (sat > 0.12)
            pale = (val > 0.55) & (sat < 0.45)
            self.glow_px[g] = zone & (greenish | purplish | (pale if g.startswith("crystal") else False)) & ~self.eyes
        self.mush = np.zeros((h, w), bool)
        for g in GLOWS:
            self.mush |= self.glow_px[g]
        # The leaves (wither): leaf colours in the canopy and the leafy branches.
        foliage = np.zeros((h, w), bool)
        for nm in ("canopy_l", "canopy_ml", "canopy_mr", "canopy_r", "branch_l", "branch_r"):
            foliage |= self.mask[nm]
        lit = disc(h, w, GLOWS["crystal_canopy"][0], GLOWS["crystal_canopy"][1] + 14)  # leaves lit by its glow
        self.leaves = foliage & (leafy | lit) & ~self.mush & (lum(col) > OUTLINE_LUM - 4)
        self.leaves |= self.glow_px["crystal_canopy"]  # the glowing crystal leaf withers with the leaves
        self.leaf_lum = lum(col)
        # The bones' weights (each part's px blurred; the trunk shared with the crown up the fork; the
        # side roots split along their chain).
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        raw = {}
        for nm in ("canopy_l", "canopy_ml", "canopy_mr", "canopy_r", "branch_l", "branch_r", "root_l", "root_r"):
            raw[nm] = self.full[nm].astype(np.float32)
        tr = self.full["trunk"].astype(np.float32)
        up = smoothstep(CROWN_FROM[0], CROWN_FROM[1], yy) if CROWN_FROM[0] > CROWN_FROM[1] else None
        up = 1.0 - smoothstep(CROWN_FROM[1], CROWN_FROM[0], yy)
        raw["crown"] = tr * up
        raw["trunk"] = tr * (1 - up)
        for side in ("l", "r"):
            nm = "tendril_" + side
            m = self.full[nm].astype(np.float32)
            a, b = np.array(J[nm]), np.array(TIPS[nm])
            ax = (b - a) / np.linalg.norm(b - a) ** 2
            t = (xx - a[0]) * ax[0] + (yy - a[1]) * ax[1]
            s2 = smoothstep(0.25, 0.6, t)
            raw[nm] = m * (1 - s2)
            raw[nm + "2"] = m * s2
        self.bones = list(raw)
        ws = np.stack([cv2.GaussianBlur(raw[b], (0, 0), BLUR) for b in self.bones])
        ws /= np.maximum(ws.sum(axis=0), 1e-6)
        self.weights = ws.astype(np.float32)
        self.xx, self.yy = xx, yy
        self._cache = {}
        if debug:
            self._debug(debug)

    # ── variants: what glows, withers, cracks ────────────────────────────
    def variant(self, fx):
        k = tuple(round(float(fx.get(n, d)), 2) for n, d in (("eyes", 1.0), ("glow", 1.0), ("wither", 0.0), ("crack", 0)))
        if k in self._cache:
            return self._cache[k]
        eyes, gl, wither, crack = k
        lay = self.body.copy()
        # the eyes: dark (0) .. lit (1) .. flaring (2)
        lay = tint(lay, self.eyes, (34, 52, 48), 0.9 * max(0.0, 1 - eyes))
        lay = tint(lay, self.eyes, (236, 255, 240), 0.6 * min(1.0, max(0.0, eyes - 1)))
        # the mushrooms and crystals: out (0) .. lit (1) .. blazing (2)
        lay = tint(lay, self.mush, (84, 82, 74), 0.88 * max(0.0, 1 - gl))
        lay = tint(lay, self.mush, (226, 255, 236), 0.55 * min(1.0, max(0.0, gl - 1)))
        if wither > 0:
            lay = self._wither(lay, wither)
        if crack > 0:
            lay = self._cracks(lay, int(crack))
        hal = self.halo * min(gl, 1.0)
        self._cache[k] = (lay, hal)
        return lay, hal

    def _wither(self, lay, k):
        L = np.clip(self.leaf_lum, 0, 255)
        ramp = np.stack([np.interp(L, [20, 60, 100, 150], c) for c in ((52, 102, 150, 196), (32, 62, 96, 140), (20, 30, 44, 70))], axis=-1)
        m = self.leaves.astype(np.float32)[..., None] * k
        out = lay.copy()
        out[..., :3] = lay[..., :3] * (1 - m) + ramp.astype(np.float32) * lay[..., 3:4] * m
        return out

    def _cracks(self, lay, stage):
        h, w = self.h, self.w
        lay = lay.copy()
        solid = (lay[..., 3] > 0.6).astype(np.float32)
        for st, pts in CRACKS:
            if st > stage:
                continue
            dark = stroke(h, w, pts, 8.0) * solid
            core = stroke(h, w, [(x + 3.0, y + 1.0) for x, y in pts[1:-1]] if len(pts) > 3 else pts, 2.0) * solid * 0.8
            for cov, rgb in ((dark, INK), (core, WOOD)):
                lay[..., :3] = lay[..., :3] * (1 - cov[..., None]) + np.array(rgb, np.float32) * cov[..., None] * lay[..., 3:4]
        return lay

    # ── posing ───────────────────────────────────────────────────────────
    def mats(self, pose):
        out = {}
        for nm, (parent, joint) in RIG.items():
            p = pose.get(nm, {})
            jx, jy = J[joint]
            rot = math.radians(p.get("rot", 0.0))
            c, s = math.cos(rot), math.sin(rot)
            local = np.array([[1, 0, jx + p.get("dx", 0.0)], [0, 1, jy + p.get("dy", 0.0)], [0, 0, 1]]) @ \
                np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]]) @ np.diag([p.get("sx", 1.0), p.get("sy", 1.0), 1.0]) @ \
                np.array([[1, 0, -jx], [0, 1, -jy], [0, 0, 1]])
            out[nm] = (out[parent] if parent else np.eye(3)) @ local
        return out

    def field(self, pose):
        """The displacement (H, W, 2) of every source px for the pose (skin + the trunk's swell)."""
        ms = self.mats(pose)
        dx = np.zeros((self.h, self.w), np.float32)
        dy = np.zeros((self.h, self.w), np.float32)
        x, y = self.xx, self.yy
        for i, b in enumerate(self.bones):
            m = ms[b]
            wt = self.weights[i]
            dx += wt * (m[0, 0] * x + m[0, 1] * y + m[0, 2] - x)
            dy += wt * (m[1, 0] * x + m[1, 1] * y + m[1, 2] - y)
        sw = pose.get("swell", 0.0)
        if sw:
            bump = np.exp(-((y - HEART[1]) / 120.0) ** 2) * np.exp(-((x - HEART[0]) / 200.0) ** 2)
            tw = self.weights[self.bones.index("trunk")] + self.weights[self.bones.index("crown")]
            dx += (x - HEART[0]) * sw * bump * tw
            dy += (y - HEART[1]) * sw * 0.35 * bump * tw
        return np.dstack([dx, dy])

    def point(self, pose, xy):
        """Where a source point goes in the pose (its own weights)."""
        d = self.field_at(pose, [xy])[0]
        return float(xy[0] + d[0]), float(xy[1] + d[1])

    def field_at(self, pose, pts):
        ms = self.mats(pose)
        out = []
        for (px, py) in pts:
            ix, iy = int(np.clip(round(px), 0, self.w - 1)), int(np.clip(round(py), 0, self.h - 1))
            d = np.zeros(2)
            for i, b in enumerate(self.bones):
                m = ms[b]
                d += self.weights[i, iy, ix] * (np.array([m[0, 0] * px + m[0, 1] * py + m[0, 2], m[1, 0] * px + m[1, 1] * py + m[1, 2]]) - np.array([px, py]))
            sw = pose.get("swell", 0.0)
            if sw:
                bump = math.exp(-((py - HEART[1]) / 120.0) ** 2) * math.exp(-((px - HEART[0]) / 200.0) ** 2)
                tw = self.weights[self.bones.index("trunk"), iy, ix] + self.weights[self.bones.index("crown"), iy, ix]
                d += np.array([(px - HEART[0]) * sw * bump * tw, (py - HEART[1]) * sw * 0.35 * bump * tw])
            out.append(d)
        return out

    def frame(self, pose, size=CELL, feet_at=CELL_FEET, layers=None):
        """The pose drawn in a cell (premultiplied RGBA), the feet at feet_at. layers: draw only these
        source layers instead of the whole picture (the death's pieces)."""
        fx = pose.get("fx", {})
        lay, hal = self.variant(fx)
        sx, sy = feet_at[0] - FEET[0], feet_at[1] - FEET[1]
        D = self.field(pose)
        gy, gx = np.mgrid[0:size[1], 0:size[0]].astype(np.float32)
        tx, ty = gx - sx, gy - sy  # the target in source px
        px, py = tx.copy(), ty.copy()
        for _ in range(14):
            d = cv2.remap(D, px, py, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
            px = 0.5 * px + 0.5 * (tx - d[..., 0])
            py = 0.5 * py + 0.5 * (ty - d[..., 1])
        for _ in range(6):
            d = cv2.remap(D, px, py, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
            px, py = tx - d[..., 0], ty - d[..., 1]

        def warp(img):
            return cv2.remap(img, px, py, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        if layers is not None:
            return [warp(l) for l in layers]
        src = np.zeros_like(lay)
        drag = fx.get("drag")
        if drag:
            over(src, self._drag_root(*drag))  # behind the tree: it leaves from under the right roots
        over(src, hal)
        over(src, lay)
        out = warp(src)
        self._glows(out, pose, fx, sx, sy)
        for leaf in fx.get("leaves", []):
            x, y, rot, size, kind = leaf
            blit(out, leaf_sprite(size, LEAF_COLOURS[kind], rot), x + sx, y + sy)
        return out

    def _glows(self, out, pose, fx, sx, sy):
        gl = fx.get("glow", 1.0)
        if gl > 1.0:
            pts = [c for c, r in GLOWS.values()]
            moved = [self.point(pose, p) for p in pts]
            for (g, ((cx, cy), r)), (mx, my) in zip(GLOWS.items(), moved):
                k = (gl - 1.0) * (1.25 if g in MUSHROOMS else 0.8)
                glow(out, mx + sx, my + sy, r * (1.0 + 0.9 * k), MINT, 0.45 * k)
        e = fx.get("eyes", 1.0)
        if e > 0.6:
            for ex, ey in self.eye_pts:
                mx, my = self.point(pose, (ex, ey))
                glow(out, mx + sx, my + sy, 16 + 16 * max(0.0, e - 1.0), MINT, 0.3 * min(1.0, (e - 0.6) / 0.4) + 0.4 * max(0.0, e - 1.0))
        hb = fx.get("heart", 0.0)
        if hb > 0:
            mx, my = self.point(pose, HEART)
            glow(out, mx + sx, my + sy, 46 + 60 * hb, MINT, 0.7 * hb)
            glow(out, mx + sx, my + sy, 16 + 14 * hb, (240, 255, 236), 0.6 * hb)

    def _drag_root(self, ext, wave, curl):
        """The root drag's root (source px, premultiplied): from DRAG_FROM along the ground to the right,
        `ext` of DRAG_REACH out, snaking (`wave` its phase), the tip curled up by `curl`."""
        h, w = self.h, self.w
        out = np.zeros((h, w, 4), np.float32)
        if ext <= 0:
            return out
        L = DRAG_REACH * ext + 150.0  # the first 150 px are under the roots
        n = 40
        cen = []
        for i in range(n + 1):
            s = L * i / n
            x = DRAG_FROM[0] + s
            amp = 14.0 * min(1.0, max(0.0, s - 120.0) / 160.0)
            y = DRAG_FROM[1] - 2.0 - amp * math.sin(s / 70.0 - wave)
            cen.append((x, y))
        # the tip curls up (a hook) at the end
        tx, ty = cen[-1]
        for i in range(1, 9):  # a hook: the last bit turns up by up to 110 degrees
            a = math.radians(110 * curl * i / 8)
            px_, py_ = cen[-1]
            cen.append((px_ + 5.0 * math.cos(a), py_ - 5.0 * math.sin(a)))
        cen = np.array(cen)
        m = len(cen)
        widths = np.array([max(9.0, 46.0 - 18.0 * (i / (m - 1)) - 22.0 * max(0.0, (i / (m - 1) - 0.55) / 0.45) ** 1.5) for i in range(m)])
        tang = np.gradient(cen, axis=0)
        tang /= np.maximum(np.linalg.norm(tang, axis=1, keepdims=True), 1e-6)
        nor = np.stack([-tang[:, 1], tang[:, 0]], axis=1)
        top = cen + nor * widths[:, None] * 0.5 * -1
        bot = cen + nor * widths[:, None] * 0.5
        poly = np.concatenate([top, bot[::-1]])
        body = fill_poly(h, w, poly)
        inner = np.clip(ndimage.grey_erosion(body, size=(INK_W, INK_W)), 0, 1)
        out[..., 3] = body
        col = np.zeros((h, w, 3), np.float32) + np.array(INK, np.float32)
        col = col * (1 - inner[..., None]) + np.array(BARK, np.float32) * inner[..., None]
        # a light stripe along its top, a shade under it, a groove
        hi = fill_poly(h, w, np.concatenate([cen + nor * widths[:, None] * -0.32, (cen + nor * widths[:, None] * -0.05)[::-1]])) * inner
        lo = fill_poly(h, w, np.concatenate([cen + nor * widths[:, None] * 0.22, (cen + nor * widths[:, None] * 0.5)[::-1]])) * inner
        col = col * (1 - hi[..., None]) + np.array(BARK_LIGHT, np.float32) * hi[..., None]
        col = col * (1 - lo[..., None]) + np.array(BARK_SHADE, np.float32) * lo[..., None]
        k0 = int(m * 0.25)
        k1 = int(m * 0.7)
        groove = stroke(h, w, [tuple(p) for p in (cen[k0:k1] + nor[k0:k1] * 2.0)], 2.4) * inner
        col = col * (1 - groove[..., None]) + np.array(INK, np.float32) * groove[..., None]
        out[..., :3] = col * body[..., None]
        return out

    def _debug(self, d):
        os.makedirs(d, exist_ok=True)
        h, w = self.h, self.w
        comp = np.zeros((h, w, 4), np.float32)
        over(comp, self.halo)
        over(comp, self.body)
        for nm, c in (("dark", (30, 30, 40)), ("orange", (255, 140, 0))):
            col, a = straight(comp)
            base = np.ones((h, w, 3)) * np.array(c)
            Image.fromarray((col * a[..., None] + base * (1 - a[..., None])).astype(np.uint8)).save(os.path.join(d, f"keyed_{nm}.png"))
        hc, ha = straight(self.halo)
        Image.fromarray((hc * ha[..., None] + np.array([30, 30, 40]) * (1 - ha[..., None])).astype(np.uint8)).save(os.path.join(d, "halo.png"))
        rng = np.random.default_rng(3)
        vis = np.zeros((h, w, 3))
        for nm, m in self.mask.items():
            vis[m] = rng.integers(60, 255, 3)
        vis[self.outline] *= 0.4
        vis[self.eyes] = (255, 0, 0)
        vis[self.mush] = (255, 255, 0)
        Image.fromarray(vis.astype(np.uint8)).save(os.path.join(d, "parts_map.png"))
        lv = unpm(self.body)[..., :3].astype(np.float32) * 0.4
        lv[self.leaves] = (0, 255, 0)
        Image.fromarray(lv.astype(np.uint8)).save(os.path.join(d, "leaves.png"))
        wv = np.zeros((h, w, 3))
        for i, b in enumerate(self.bones):
            wv += self.weights[i][..., None] * rng.integers(40, 255, 3)
        Image.fromarray(np.clip(wv, 0, 255).astype(np.uint8)).save(os.path.join(d, "weights.png"))


# ── poses ────────────────────────────────────────────────────────────────────
def pose(trunk=0.0, crown=0.0, canopy=(0, 0, 0, 0), lift=(0, 0, 0, 0), shift=(0, 0, 0, 0), puff=1.0, branch=(0, 0),
         tendril_l=(0, 0), tendril_r=(0, 0), roots=(0, 0), root=(0, 0, 0), sag=1.0, swell=0.0, fx=None, **extra):
    """trunk / crown: degrees (+ leans right, round the trunk's foot / the fork); canopy: the clumps'
    turn (l, ml, mr, r, degrees); lift: their rise (px, up +); shift: their sideways move (px);
    puff: the clumps' scale; branch (l, r): + lifts the tip, − whips it down; tendril_*: (base, tip)
    degrees, + curls up / outward; roots (l, r): the outer roots' tips up (degrees); root: the whole
    tree (dx, dy, degrees round the feet); sag: the trunk's height scale; swell: the trunk swells."""
    p = {"root": {"dx": root[0], "dy": root[1], "rot": root[2]},
         "trunk": {"rot": trunk, "sy": sag}, "crown": {"rot": crown}}
    for nm, r, l, s in zip(("canopy_l", "canopy_ml", "canopy_mr", "canopy_r"), canopy, lift, shift):
        p[nm] = {"rot": r, "dy": -l, "dx": s, "sx": puff, "sy": puff}
    p["branch_l"] = {"rot": branch[0]}  # the left branch points left: + turns its tip up
    p["branch_r"] = {"rot": -branch[1]}
    p["tendril_l"] = {"rot": tendril_l[0]}
    p["tendril_l2"] = {"rot": tendril_l[1]}
    p["tendril_r"] = {"rot": -tendril_r[0]}
    p["tendril_r2"] = {"rot": -tendril_r[1]}
    p["root_l"] = {"rot": roots[0]}
    p["root_r"] = {"rot": -roots[1]}
    p["swell"] = swell
    p["fx"] = dict({"eyes": 1.0, "glow": 1.0}, **(fx or {}))
    p.update(extra)
    return p


REST = pose()


def falling(seed, n, t, spread=(380, 1040), y0=(150, 330), fall=260.0, kinds=("green", "dark", "purple")):
    """n painted leaves t (0..1) into their fall from the canopy (source px), drifting and turning."""
    rng = np.random.default_rng(seed)
    out = []
    for i in range(n):
        x = rng.uniform(*spread)
        y = rng.uniform(*y0)
        ph = rng.uniform(0, 2 * math.pi)
        tt = min(1.0, max(0.0, t - rng.uniform(0, 0.25)))
        out.append((x + 26 * math.sin(ph + tt * 5.0) + 30 * tt * rng.uniform(-1, 1), y + fall * tt * rng.uniform(0.7, 1.1),
                    rng.uniform(0, 180) + 220 * tt, rng.uniform(20, 27), kinds[i % len(kinds)]))
    return out


def idle_frames(n=12):
    out = []
    for i in range(n):
        t = i / n * 2 * math.pi
        s = math.sin(t)
        out.append(pose(trunk=0.25 * s, crown=0.5 * math.sin(t - 0.4),
                        canopy=(1.2 * math.sin(t - 0.9), 0.8 * math.sin(t - 0.6), 0.8 * math.sin(t - 1.1), 1.2 * math.sin(t - 1.4)),
                        lift=(1.2 * math.sin(t - 0.3), 1.6 * math.sin(t), 1.6 * math.sin(t - 0.5), 1.2 * math.sin(t - 0.8)),
                        branch=(2.2 * math.sin(t - 1.2), 2.2 * math.sin(t - 1.6)),
                        tendril_l=(2.0 * math.sin(t - 0.5), 3.5 * math.sin(t - 1.3)), tendril_r=(2.0 * math.sin(t - 2.0), 3.5 * math.sin(t - 2.8)),
                        fx={"glow": 0.9 + 0.22 * math.sin(t - 0.7),
                            "eyes": 0.3 if i == 8 else (0.7 if i in (7, 9) else 1.0)}))
    return out


def shake(i, amp):
    rng = np.random.default_rng(100 + i)
    return tuple(rng.uniform(-1, 1) * amp for _ in range(4))


ANIMS = {
    # name: (frames, fps, loop, peak)
    "idle": (idle_frames(), 6, True, None),
    "vine_lash": ([
        REST,
        pose(crown=-0.8, canopy=(-1, -0.5, 0.5, 1), lift=(2, 2, 2, 2), branch=(6, 6), tendril_l=(8, 10), tendril_r=(8, 10),
             roots=(3, 3), fx={"eyes": 1.4}),
        pose(trunk=-0.6, crown=-1.5, canopy=(-2, -1, 1, 2), lift=(4, 4, 4, 4), branch=(12, 12), tendril_l=(16, 22),
             tendril_r=(16, 22), roots=(6, 6), fx={"eyes": 1.8, "glow": 1.15}),
        pose(trunk=0.8, crown=1.6, canopy=(2.5, 1, -1, -2.5), lift=(-4, -2, -2, -4), branch=(-16, -16), tendril_l=(-10, -16),
             tendril_r=(-10, -16), roots=(-2, -2), fx={"eyes": 2.0, "glow": 1.2}),
        pose(trunk=0.6, crown=1.0, canopy=(1.5, 0.6, -0.6, -1.5), lift=(-3, -1, -1, -3), branch=(-12, -12), tendril_l=(-6, -10),
             tendril_r=(-6, -10), roots=(-1, -1), fx={"eyes": 1.7, "glow": 1.1}),
        pose(trunk=0.2, crown=0.3, canopy=(0.5, 0.2, -0.2, -0.5), branch=(-4, -4), tendril_l=(2, 3), tendril_r=(2, 3), fx={"eyes": 1.3}),
        REST], 10, False, 3),
    "poison_thorns": ([
        REST,
        pose(crown=0, canopy=(1, 0.5, -0.5, -1), lift=(-3, -4, -4, -3), puff=0.98, branch=(-3, -3), fx={"eyes": 1.3}),
        pose(crown=-1.2, canopy=shake(2, 2.5), shift=shake(12, 5), lift=(-2, -3, -3, -2), puff=0.985, fx={"eyes": 1.5}),
        pose(crown=1.2, canopy=shake(3, 2.5), shift=shake(13, 6), lift=(0, 1, 1, 0), branch=(3, 3), fx={"eyes": 1.6}),
        pose(crown=0, canopy=(-2.5, -1.2, 1.2, 2.5), shift=(-8, -3, 3, 8), lift=(6, 9, 9, 6), puff=1.045, branch=(8, 8),
             tendril_l=(4, 6), tendril_r=(4, 6), fx={"eyes": 1.9, "glow": 1.2,
                                                     "leaves": falling(31, 4, 0.15, y0=(120, 260), fall=120)}),
        pose(crown=-0.8, canopy=shake(5, 2.0), shift=shake(15, 5), lift=(3, 5, 5, 3), puff=1.02, branch=(2, 2),
             fx={"eyes": 1.5, "leaves": falling(31, 4, 0.5, y0=(120, 260), fall=120)}),
        pose(crown=0.6, canopy=shake(6, 1.0), shift=shake(16, 2), lift=(1, 1, 1, 1), fx={"eyes": 1.2,
                                                                                      "leaves": falling(31, 4, 0.85, y0=(120, 260), fall=120)}),
        REST], 10, False, 4),
    "life_drain": ([
        REST,
        pose(roots=(-2, -2), tendril_l=(4, 6), tendril_r=(4, 6), branch=(4, 4), fx={"eyes": 1.4, "glow": 1.3, "heart": 0.2}),
        pose(roots=(-3, -3), tendril_l=(8, 12), tendril_r=(8, 12), branch=(7, 7), lift=(2, 3, 3, 2), swell=0.03,
             fx={"eyes": 1.7, "glow": 1.6, "heart": 0.5}),
        pose(roots=(-3, -3), tendril_l=(10, 15), tendril_r=(10, 15), branch=(9, 9), lift=(4, 5, 5, 4), puff=1.02, swell=0.06,
             fx={"eyes": 2.0, "glow": 2.0, "heart": 1.0}),
        pose(roots=(-2, -2), tendril_l=(8, 12), tendril_r=(8, 12), branch=(7, 7), lift=(3, 4, 4, 3), puff=1.01, swell=0.035,
             fx={"eyes": 1.8, "glow": 1.7, "heart": 0.7}),
        pose(roots=(-2, -2), tendril_l=(9, 14), tendril_r=(9, 14), branch=(8, 8), lift=(4, 5, 5, 4), puff=1.02, swell=0.055,
             fx={"eyes": 1.9, "glow": 1.9, "heart": 0.9}),
        pose(tendril_l=(3, 5), tendril_r=(3, 5), branch=(3, 3), lift=(1, 1, 1, 1), swell=0.015, fx={"eyes": 1.3, "glow": 1.3, "heart": 0.3}),
        REST], 8, False, 3),
    "root_drag": ([
        REST,
        pose(trunk=0.8, crown=0.6, canopy=(0.8, 0.5, 0.5, 0.8), branch=(-3, 3), roots=(0, 3), fx={"eyes": 1.4, "drag": (0.18, 0.0, 0.0)}),
        pose(trunk=1.6, crown=1.2, canopy=(1.4, 0.9, 0.9, 1.4), branch=(-5, 6), roots=(0, 5), tendril_r=(6, 8),
             fx={"eyes": 1.6, "drag": (0.5, 1.2, 0.2)}),
        pose(trunk=2.2, crown=1.6, canopy=(1.8, 1.2, 1.2, 1.8), branch=(-6, 9), roots=(0, 6), tendril_r=(10, 14),
             fx={"eyes": 1.8, "drag": (0.82, 2.4, 0.5)}),
        pose(trunk=2.5, crown=1.8, canopy=(2.0, 1.4, 1.4, 2.0), branch=(-6, 10), roots=(0, 7), tendril_r=(12, 16),
             fx={"eyes": 2.0, "glow": 1.15, "drag": (1.0, 3.4, 1.0)}),
        pose(trunk=-2.0, crown=-2.4, canopy=(-2.5, -1.6, -1.6, -2.5), lift=(-2, -2, -2, -2), branch=(8, -10), roots=(0, -2),
             tendril_r=(-8, -10), fx={"eyes": 1.8, "glow": 1.1, "drag": (0.55, 4.6, 1.0)}),
        pose(trunk=-1.0, crown=-1.2, canopy=(-1.2, -0.8, -0.8, -1.2), branch=(4, -5), tendril_r=(-3, -4),
             fx={"eyes": 1.4, "drag": (0.22, 5.4, 0.8)}),
        REST], 9, False, 4),
    "summon": ([
        REST,
        pose(roots=(2, 2), tendril_l=(3, 4), tendril_r=(-3, -4), lift=(1, 1, 1, 1), fx={"glow": 1.4, "eyes": 1.2}),
        pose(roots=(-2, -2), tendril_l=(-4, -5), tendril_r=(4, 5), lift=(3, 3, 3, 3), puff=1.01, fx={"glow": 2.0, "eyes": 1.5}),
        pose(roots=(2, 2), tendril_l=(4, 5), tendril_r=(-4, -5), lift=(3, 3, 3, 3), puff=1.01, fx={"glow": 1.85, "eyes": 1.5}),
        pose(roots=(-1, -1), tendril_l=(-2, -3), tendril_r=(2, 3), lift=(2, 2, 2, 2), fx={"glow": 1.5, "eyes": 1.3}),
        pose(fx={"glow": 1.15, "eyes": 1.1}),
        REST], 8, False, 2),
    "hurt": ([
        pose(root=(-6, 0, -1.2), trunk=-1.0, crown=-2.2, canopy=(-2.5, -1.5, -1.5, -2.5), shift=(-6, -4, -4, -6), lift=(-2, -3, -3, -2),
             branch=(6, -6), tendril_l=(6, 8), tendril_r=(-6, -8), fx={"eyes": 0.45, "glow": 0.8,
                                                                         "leaves": falling(41, 5, 0.12, fall=200)}),
        pose(root=(-2, 0, -0.4), trunk=-0.3, crown=-0.8, canopy=(-1, -0.5, -0.5, -1), shift=(-2, -1, -1, -2), branch=(2, -2),
             fx={"eyes": 0.8, "leaves": falling(41, 5, 0.5, fall=200)}),
        ], 7, False, None),
    "death": ([
        pose(root=(-5, 0, -1.0), trunk=-0.8, crown=-1.8, canopy=(-2, -1, -1, -2), shift=(-4, -3, -3, -4), branch=(4, -4),
             fx={"eyes": 0.5, "glow": 0.55, "wither": 0.3, "leaves": falling(51, 6, 0.15, fall=240, kinds=("green", "brown", "purple"))}),
        pose(trunk=-0.3, crown=-0.6, canopy=(-4, -1.5, 1.5, 4), lift=(-6, -4, -4, -6), branch=(-6, -6), tendril_l=(-6, -10),
             tendril_r=(-6, -10), sag=0.985,
             fx={"eyes": 0.2, "glow": 0.2, "wither": 0.7, "crack": 1,
                 "leaves": falling(51, 6, 0.55, fall=240, kinds=("green", "brown", "purple")) + falling(52, 5, 0.1, fall=260, kinds=("brown", "brown2"))}),
        pose(trunk=0.2, crown=0.5, canopy=(-7, -3, 3, 7), lift=(-12, -9, -9, -12), branch=(-12, -12), tendril_l=(-12, -20),
             tendril_r=(-12, -20), roots=(-2, -2), sag=0.97,
             fx={"eyes": 0.0, "glow": 0.0, "wither": 1.0, "crack": 2,
                 "leaves": falling(51, 6, 0.95, fall=240, kinds=("green", "brown", "purple")) + falling(52, 5, 0.5, fall=260, kinds=("brown", "brown2"))}),
        pose(trunk=0.4, crown=1.0, canopy=(-9, -4, 4, 9), lift=(-18, -14, -14, -18), shift=(-4, -2, 2, 4), branch=(-16, -16),
             tendril_l=(-16, -26), tendril_r=(-16, -26), roots=(-3, -3), sag=0.955,
             fx={"eyes": 0.0, "glow": 0.0, "wither": 1.0, "crack": 3}),
        ], 6, False, None),
}
DEATH_POSE = ANIMS["death"][0][-1]

# The skinned idle (on skin/rest_v1.png: the rest pose in a cell): its joints (source px) and bones.
SKIN_JOINTS = {"hips": (708, 640), "neck": (712, 330), "canopy_l": (560, 252), "canopy_l_tip": (420, 190),
               "canopy_ml": (650, 214), "canopy_ml_tip": (610, 80), "canopy_mr": (790, 214), "canopy_mr_tip": (820, 80),
               "canopy_r": (900, 252), "canopy_r_tip": (1010, 190), "branch_l": (588, 352), "branch_l_tip": (452, 372),
               "branch_r": (944, 390), "branch_r_tip": (1030, 368), "tendril_l": (548, 562), "tendril_l_tip": (432, 460),
               "tendril_r": (936, 598), "tendril_r_tip": (984, 500), "root_l": (520, 650), "root_l_tip": (380, 690),
               "root_r": (920, 640), "root_r_tip": (1030, 680), "heart": HEART}
SKIN_BONES = [["root", "", "feet", "hips", 0], ["trunk", "root", "hips", "neck", 1.5],
              ["canopy_l", "trunk", "canopy_l", "canopy_l_tip", 2], ["canopy_ml", "trunk", "canopy_ml", "canopy_ml_tip", 2],
              ["canopy_mr", "trunk", "canopy_mr", "canopy_mr_tip", 2], ["canopy_r", "trunk", "canopy_r", "canopy_r_tip", 2],
              ["branch_l", "trunk", "branch_l", "branch_l_tip", 2], ["branch_r", "trunk", "branch_r", "branch_r_tip", 2],
              ["tendril_l", "root", "tendril_l", "tendril_l_tip", 2], ["tendril_r", "root", "tendril_r", "tendril_r_tip", 2],
              ["root_l", "root", "root_l", "root_l_tip", 1], ["root_r", "root", "root_r", "root_r_tip", 1]]
# Its sway (tools/import_boss_frames.gd "tracks": per bone a sine of the loop: rot degrees, y of the
# height (up), sy, lag radians behind).
SKIN_TRACKS = {"period": 3.0, "keys": 16, "bones": {
    "trunk": {"rot": 0.3, "lag": 0.0},
    "canopy_l": {"rot": 1.2, "lag": 0.9, "y": 0.002}, "canopy_ml": {"rot": 0.8, "lag": 0.6, "y": 0.002},
    "canopy_mr": {"rot": 0.8, "lag": 1.1, "y": 0.002}, "canopy_r": {"rot": -1.2, "lag": 1.4, "y": 0.002},
    "branch_l": {"rot": 2.0, "lag": 1.2}, "branch_r": {"rot": -2.0, "lag": 1.6},
    "tendril_l": {"rot": 2.5, "lag": 0.5}, "tendril_r": {"rot": -2.5, "lag": 2.0}}}


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


def drag_tip(fx):
    d = fx.get("drag")
    if not d or d[0] <= 0:
        return None
    ext, wave, curl = d
    s = DRAG_REACH * ext + 150.0
    amp = 14.0 * min(1.0, max(0.0, s - 120.0) / 160.0)
    x, y = DRAG_FROM[0] + s, DRAG_FROM[1] - 2.0 - amp * math.sin(s / 70.0 - wave)
    for i in range(1, 9):
        a = math.radians(110 * curl * i / 8)
        x, y = x + 5.0 * math.cos(a), y - 5.0 * math.sin(a)
    return (x, y)


def seal(colour, mask, opaque, r=4):
    cut = opaque & ~mask
    near = ndimage.binary_dilation(cut, iterations=r) & mask
    rim = mask & ~ndimage.binary_erosion(mask, iterations=r)
    colour = colour.copy()
    colour[near & rim] = INK
    return colour


def pieces(g):
    """The death's pieces in DEATH_POSE, each a full cell (premultiplied), in PIECES order."""
    lay, _ = g.variant(DEATH_POSE["fx"])
    col, a = straight(lay)
    opaque = a > 0.5
    layers = []
    for nm in PIECES:
        m = g.mask[nm]
        mm = m & (a > 0.02)
        lab, n = ndimage.label(mm, structure=np.ones((3, 3)))
        if n > 1:
            sizes = ndimage.sum(np.ones(m.shape), lab, range(1, n + 1))
            keep = np.isin(lab, 1 + np.nonzero(sizes >= 0.02 * sizes.max())[0])
            m = m & ndimage.binary_dilation(keep, iterations=1)
        c = seal(col, m & opaque, opaque, r=4)
        layers.append(np.dstack([c * (a * m)[..., None], a * m]).astype(np.float32))
    cells = g.frame(DEATH_POSE, layers=layers)
    return dict(zip(PIECES, cells))


def write_frame_points(g):
    frames = {}
    for anim, (poses, fps, loop, peak) in ANIMS.items():
        rows = []
        for p in poses:
            pts = g.field_at(p, [HEART, CANOPY_PT, g.eye_pts[0], g.eye_pts[1], GLOWS["mush_trunk"][0], J["branch_l"], J["branch_r"]])
            moved = [(q[0] + d[0], q[1] + d[1]) for q, d in zip([HEART, CANOPY_PT, g.eye_pts[0], g.eye_pts[1], GLOWS["mush_trunk"][0]], pts)]
            ex = ((moved[2][0] + moved[3][0]) / 2, (moved[2][1] + moved[3][1]) / 2)
            row = {"heart": unit(moved[0]), "canopy": unit(moved[1]), "eyes": unit(ex), "mushrooms": unit(moved[4]),
                   "glow": round(float(p["fx"].get("glow", 1.0)), 2), "eyesLit": round(float(p["fx"].get("eyes", 1.0)), 2)}
            tip = drag_tip(p["fx"])
            if tip:
                row["rootTip"] = unit(tip)
            rows.append(row)
        frames[anim] = rows
    out = {"_doc": "Written by art_source/bosses/tree_spirit/make_frames.py (do not edit). Mộc Tinh's points per frame of side.json, in the unit frame BossArt draws in (the body 100 tall = side.json height, the feet at the origin, facing right, y down; mirror x when it faces left): heart = the tree's heart on the trunk under the mouth (the drain's end, the heal glow), canopy = where the poison thorns leave the canopy, eyes = between the eyes, mushrooms = the glowing cluster in the fork (the summon's / the regen's source on the tree), glow = how lit the mushrooms and crystals are (0 out, 1 normal, 2 blazing), eyesLit = the eyes (0 dark, 1 lit, 2 flaring), rootTip = the root drag's root tip while it shows (on the ground line).",
           "frames": frames}
    path = os.path.join(ASSETS, "side", "points.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(json.dumps(out, ensure_ascii=False) + "\n")
    print("  wrote assets/bosses/tree_spirit/side/points.json")


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
    eyes = [[round(e[0] + off[0], 1), round(e[1] + off[1], 1)] for e in frames["_eyes"]]
    cfg = {
        "_doc": "Written by make_frames.py here (do not edit: edit the script and re-run it). tools/import_boss_frames.gd reads it (see its header and README.txt here). The sheets are already transparent (background.key 'alpha'), one row per animation in fixed %d x %d cells with the feet (the trunk's foot on the ground line) at (%g, %g) of every cell: cuts at the cells, anchors the feet, bodyHeight %g (the canopy's top to the feet, sheet px) -> height texture px. body: every colour (measured only for the width). skins.idle: the rest pose (skin/rest_v1.png, full size) on a skeleton: joints (that picture's px), bones, feet / bodyHeight given, tracks (the sway: a sine per bone), glow = the heart on the trunk, eyes. parts: the death's pieces in the last death frame's pose, one cell each at the frames' scale (feet given), back to front." % (cw, ch, fx, fy, BODY_H / HALF),
        "out": "res://assets/bosses/tree_spirit/",
        "height": 320,
        "pad": 4,
        "background": {"key": "alpha"},
        "alphaCut": 4,
        "edgeFade": 0,
        "body": {"hue": [0, 360], "minSat": 0.0, "minVal": 0.12, "maxVal": 1.0, "centreRows": [0.6, 0.85], "minPiece": 0.08},
        "anims": anims,
        "skins": {"idle": {"motion": "breath", "src": "skin/rest_v1.png", "height": 360, "pad": 6,
                           "feet": [CELL_FEET[0], CELL_FEET[1]], "bodyHeight": BODY_H,
                           "glow": {"joint": "heart", "bone": "trunk", "colour": [0.6, 1.0, 0.78]},
                           "eyes": eyes, "joints": joints, "bones": SKIN_BONES, "tracks": SKIN_TRACKS}},
        "parts": {"bodyHeight": BODY_H / HALF, "feet": [fx, fy], "src": {sn: f"parts/{sn}_v1.png" for sn in PIECES}},
        "pictures": {
            "portrait": {"src": "portrait/portrait_v1.png", "size": 512, "margin": 8},
            "bust": {"src": "portrait/bust_v1.png", "size": 384, "margin": 6},
        },
    }
    with open(os.path.join(HERE, "import.json"), "w") as f:
        f.write(json.dumps(cfg, indent="\t", ensure_ascii=False) + "\n")
    print("  wrote import.json")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--debug")
    ap.add_argument("--check", action="store_true", help="with --debug: only the debug pictures")
    ap.add_argument("--preview", help="with --debug: only these animations (comma separated), as one strip each")
    args = ap.parse_args()
    g = Tree(debug=args.debug)
    if args.debug and args.check:
        return
    if args.preview and args.debug:
        for anim in args.preview.split(","):
            fs = [unpm(halve(g.frame(p))) for p in ANIMS[anim][0]]
            strip = np.concatenate(fs, axis=1).astype(np.float64)
            bg = np.ones(strip.shape[:2] + (3,)) * np.array([70, 110, 160])
            a = strip[..., 3:4] / 255.0
            Image.fromarray((strip[..., :3] * a + bg * (1 - a)).astype(np.uint8)).save(os.path.join(args.debug, f"strip_{anim}.png"))
        return
    frames = {}
    for anim, (poses, fps, loop, peak) in ANIMS.items():
        frames[anim] = [g.frame(p) for p in poses]
        save(sheet(frames[anim]), f"side_{anim}/sheet_v1.png")
    used = np.zeros(CELL[::-1], bool)
    for fs in frames.values():
        for f in fs:
            used |= f[..., 3] > 0.02
    ys, xs = np.nonzero(used)
    print(f"  frames' union in the cell: x {xs.min()}..{xs.max()}, y {ys.min()}..{ys.max()} (cell {CELL}, feet {CELL_FEET})")
    assert xs.min() > 2 and ys.min() > 2 and xs.max() < CELL[0] - 3 and ys.max() < CELL[1] - 3, "a frame leaves the cell"
    rest = g.frame(pose(fx={"glow": 1.0, "eyes": 1.0}))
    rx = np.nonzero((rest[..., 3] > 0.5).any(axis=0))[0]
    rest_w = rx.max() - rx.min() + 1
    save(unpm(rest), "skin/rest_v1.png")
    portrait = g.frame(pose(fx={"glow": 1.25, "eyes": 1.2}))
    save(unpm(portrait), "portrait/portrait_v1.png")
    # The bust: the face with the fork and the canopy's middle, faded out at the sides, over the canopy's top and
    # under the mouth.
    bust = g.frame(pose(fx={"glow": 1.25, "eyes": 1.25}))
    sx, sy = CELL_FEET[0] - FEET[0], CELL_FEET[1] - FEET[1]
    yy, xx = np.mgrid[0:CELL[1], 0:CELL[0]].astype(np.float32)
    x0, x1, y0, y1 = 470 + sx, 950 + sx, 110 + sy, 556 + sy
    ramp = np.clip((y1 - yy) / 24, 0, 1) * np.clip((yy - y0) / 30, 0, 1) * np.clip((xx - x0) / 40, 0, 1) * np.clip((x1 - xx) / 40, 0, 1)
    bust *= ramp[..., None]
    save(unpm(bust), "portrait/bust_v1.png")
    cells = pieces(g)
    for sn in PIECES:
        save(unpm(halve(cells[sn])), f"parts/{sn}_v1.png")
    rig = {
        "_doc": "Written by make_frames.py (do not edit). Source px of concept/ancient_tree_v1.png (the body: TOP → FEET, 702 px) and the unit frame BossArt draws in (the body 100 tall, the feet at the origin, facing right, y down).",
        "feet": list(FEET), "top": TOP, "bodyHeight": BODY_H,
        "heart": {"src": list(HEART), "unit": unit(HEART)},
        "canopy": {"src": list(CANOPY_PT), "unit": unit(CANOPY_PT)},
        "eyes": {"src": [[round(e[0], 1), round(e[1], 1)] for e in g.eye_pts], "unit": [unit(e) for e in g.eye_pts]},
        "mushrooms": {"src": list(GLOWS["mush_trunk"][0]), "unit": unit(GLOWS["mush_trunk"][0])},
        "width": round(float(rest_w) / BODY_H, 3),
    }
    with open(os.path.join(HERE, "rig_v1.json"), "w") as f:
        json.dump(rig, f, indent="\t")
        f.write("\n")
    print("  rig:", json.dumps(rig))
    write_frame_points(g)
    frames["_eyes"] = g.eye_pts
    write_import(frames)


if __name__ == "__main__":
    main()
