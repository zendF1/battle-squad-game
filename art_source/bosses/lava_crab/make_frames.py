#!/usr/bin/env python3
"""Cua Dung Nham (boss id lava_crab): every picture the game needs, made from the one picture the user
gave, concept/lava_crab_v1.png (a crab with a dark basalt shell cracked with glowing orange-yellow lava,
angry yellow eyes, two big claws dripping lava, segmented legs; 3/4 view facing right, standing).

A crab is hard shell on hinges: the frames are posed with rigid cut-out parts turned round their joints
(as Khổng Lồ Đá), no AI sheets exist for this boss:

  1. keyed: the flat sky-blue backdrop and the darker blue ground-shadow ellipse under it (the game draws
     shadows) removed by colour (the crab has no blue), the ✦ watermark painted out first; every edge px
     un-mixed against its own nearest backdrop colour (colour-to-alpha), so the lava drips hanging over
     the sky keep their orange edge with no blue in it; the light ringing just outside the outline and
     specks cleared; only the figure kept;
  2. cut into parts: a rough polygon per part (PARTS) gives each part a seed (the polygon shrunk), a
     watershed over the picture's darkness grows the seeds up to the drawn outlines (the cuts follow
     the black lines where there are some, the polygon elsewhere); the outline px on a cut belong to
     both sides; every cut through flat colour gets a new outline (seal());
  3. the hidden areas painted (UNDER): the shell under the claws and the legs' roots, the palms under
     the moving upper pincers, the legs' tops up to their hips, in the same flat colours with the bold
     outline, only where a part in front hides them;
  4. a skeleton (RIG: root at the feet → shell (the body with the face) → left arm → left claw → its
     upper pincer; right arm → right palm → its upper pincer; the hanging lava drips on their claws;
     four drawn legs, two segments each, posed by a two-bone IK onto their tips: the tips stay planted
     while the shell moves, the walk steps them) and four far legs behind the shell (copies of the drawn
     ones, shaded darker: eight legs), posed per frame (ANIMS), with what glows: the lava (dim .. blazing,
     cooled to grey stone at death), the eyes (lit, shut), drops falling off the drips, a lava spout on
     the shell (the bombs), smoke (death);
  5. each frame drawn at full size in a fixed cell (the feet, the middle of the legs' ground contact,
     at CELL_FEET), halved into one row per animation: side_<anim>/sheet_v1.png, transparent.

Also written: skin/rest_v1.png (the rest pose at full size: the skinned idle's picture), the portrait,
the bust (the face with the shell, faded under it), parts/<name>_v1.png (the death's pieces in the last
death frame's pose), rig_v1.json (the points: source px and the unit frame),
assets/bosses/lava_crab/side/points.json (per frame), import.json (the importer's config) and the
minion's pictures (Cua con: the same crab, smaller, brighter): minion/side_<anim>/sheet_v1.png and
minion/import.json.

Run in battle-squad-game (Python 3 with numpy, scipy, scikit-image, Pillow, OpenCV):

  python3 -I art_source/bosses/lava_crab/make_frames.py [--debug DIR [--check | --preview walk,pincer]]
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- lava_crab lava_crab/minion

--debug DIR writes the keyed picture on dark / orange, the part map over the picture, every part alone
with its painted underlay, the joints, the rest pose against the keyed picture.
"""
import argparse
import json
import math
import os

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage
from skimage.segmentation import watershed

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "concept", "lava_crab_v1.png")
ASSETS = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "bosses", "lava_crab"))

# ── The picture (source px, 1380 × 752) ──────────────────────────────────────
WATERMARK = (1323, 697, 30)  # the ✦ on the backdrop: centre, radius (painted backdrop first)
NOISE = 0.08  # un-mixed alpha under this is backdrop noise / JPEG ringing
OUTLINE_LUM = 40  # darker than this is the outline
GROUND = 706.0  # the ground line (the near legs' tips; the far ones are lowered onto it at rest)
FEET = (680.0, GROUND)  # the middle of the legs' ground contact
REST_DROP_ = 44.0
TOP = 23.0 + REST_DROP_  # the raised left claw's top at rest (the crab lowered onto its legs): the body is TOP → FEET
BODY_H = FEET[1] - TOP
INK = (34, 22, 26)  # the outline colour
INK_W = 6  # the outline's width (source px)
ROCK = (80, 63, 58)  # the basalt's base
ROCK_DARK = (60, 42, 40)
ROCK_LIGHT = (100, 82, 76)
LAVA = (232, 96, 12)
LAVA_YELLOW = (252, 204, 24)
DRIP_RIM = (196, 74, 14)
STONE = (128, 122, 116)  # cooled lava (death)
EMBER = (255, 150, 40)  # the lava's glow colour (halos, the skin's glow)

# Rough part polygons (source px): each one's inside, shrunk, seeds a watershed over the picture's
# darkness, so the cuts land on the drawn outlines; the rest is the shell ("body").
PARTS = {
    "finger_l": [(346, 104), (372, 86), (430, 52), (480, 32), (540, 28), (566, 38), (582, 50), (536, 62), (524, 140),
                 (494, 136), (478, 122), (466, 152), (452, 190), (468, 214), (474, 236), (440, 224), (412, 216),
                 (384, 208), (352, 196)],
    "claw_l": [(288, 168), (318, 150), (346, 150), (352, 196), (384, 208), (412, 216), (440, 224), (474, 236), (462, 206),
               (476, 182), (504, 176), (530, 136), (548, 118), (568, 140), (590, 172), (596, 196), (582, 226), (560, 258),
               (556, 300), (560, 366), (520, 368), (500, 330), (476, 338), (452, 364), (440, 372), (380, 360), (346, 362),
               (318, 346), (298, 316), (288, 260)],
    "arm_l": [(338, 360), (380, 360), (440, 372), (468, 384), (476, 420), (466, 452), (440, 462), (380, 460), (352, 456),
              (338, 430), (334, 396)],
    "finger_r": [(1084, 182), (1108, 142), (1160, 118), (1206, 110), (1258, 120), (1300, 146), (1342, 182), (1320, 194),
                 (1272, 198), (1266, 252), (1232, 252), (1222, 222), (1212, 250), (1190, 272), (1176, 302), (1140, 304),
                 (1118, 284), (1100, 262), (1092, 232)],
    "palm_r": [(978, 268), (992, 228), (1036, 186), (1062, 174), (1084, 182), (1092, 232), (1100, 262), (1118, 284),
               (1140, 304), (1176, 302), (1206, 296), (1250, 282), (1288, 260), (1302, 280), (1292, 330), (1282, 372),
               (1288, 494), (1236, 494), (1230, 410), (1228, 462), (1192, 462), (1188, 420), (1150, 444), (1080, 448),
               (1036, 448), (1008, 444), (1000, 400), (996, 352), (978, 330)],
    "arm_r": [(836, 384), (872, 368), (906, 362), (944, 352), (984, 348), (996, 352), (1000, 400), (1008, 444), (968, 452),
              (924, 452), (884, 446), (848, 440), (832, 420)],
    "leg_a_up": [(288, 384), (314, 376), (346, 384), (352, 420), (344, 470), (320, 540), (300, 566), (270, 562), (252, 548),
                 (266, 500), (282, 440)],
    "leg_a_lo": [(232, 560), (252, 550), (276, 562), (290, 576), (284, 620), (262, 660), (246, 672), (228, 640), (226, 590)],
    "leg_b_up": [(452, 402), (520, 400), (572, 400), (596, 416), (598, 452), (580, 476), (520, 480), (492, 502), (466, 500),
                 (440, 486), (440, 456)],
    "leg_b_lo": [(360, 462), (402, 452), (440, 460), (448, 500), (440, 560), (420, 610), (412, 640), (420, 690), (400, 720),
                 (378, 712), (352, 660), (348, 600), (352, 520)],
    "leg_c_up": [(808, 452), (840, 440), (866, 456), (906, 470), (918, 500), (922, 560), (906, 576), (878, 572), (858, 530),
                 (850, 496), (820, 486)],
    "leg_c_lo": [(876, 568), (906, 562), (926, 574), (924, 610), (906, 642), (886, 636), (880, 600)],
    "leg_d_up": [(848, 440), (884, 446), (924, 452), (968, 456), (990, 470), (992, 500), (960, 502), (920, 492), (880, 484),
                 (858, 470)],
    "leg_d_lo": [(954, 480), (990, 470), (1012, 500), (1036, 560), (1052, 600), (1050, 640), (1032, 668), (1010, 660),
                 (1004, 610), (980, 570), (960, 530)],
}
# The shell's own seed (what no part polygon takes inside it).
BODY = [(470, 236), (520, 200), (590, 172), (700, 160), (790, 178), (880, 236), (944, 290), (940, 330), (900, 360),
        (850, 380), (830, 430), (800, 480), (720, 496), (640, 490), (600, 470), (560, 400), (520, 370), (480, 340)]
SEED_SHRINK = 6  # px: the polygon's inside farther than this from its edge seeds the watershed
# The hanging lava drips (polygons inside their claw; their top is the root they stretch from).
DRIPS = {
    "drip_fl": ("finger_l", [(496, 82), (526, 82), (526, 140), (496, 140)], (511, 86), (511, 134)),
    "drip_cl": ("claw_l", [(504, 228), (556, 228), (556, 364), (504, 364)], (530, 236), (540, 358)),
    "drip_fr": ("finger_r", [(1232, 204), (1266, 204), (1266, 250), (1232, 250)], (1249, 208), (1249, 245)),
    "drip_p1": ("palm_r", [(1190, 360), (1230, 360), (1230, 464), (1190, 464)], (1212, 366), (1212, 460)),
    "drip_p2": ("palm_r", [(1234, 372), (1290, 372), (1290, 496), (1234, 496)], (1262, 380), (1258, 492)),
}
EYE_BOXES = [(650, 318, 728, 368), (806, 300, 868, 352)]  # the yellow eyes
HEART = (728.0, 330.0)  # the shell's middle: heals / drains glow there
SHELL_TOP = (716.0, 176.0)  # the shell's top crack: the lava bombs burst out of it

# The joints (source px).
J = {
    "feet": FEET, "shell": (720.0, 470.0),
    "shoulder_l": (468.0, 418.0), "wrist_l": (392.0, 372.0), "hinge_l": (366.0, 196.0),
    "shoulder_r": (848.0, 410.0), "wrist_r": (1000.0, 400.0), "hinge_r": (1098.0, 246.0),
    # legs: hip, knee, tip (two segments each)
    "hip_a": (322.0, 392.0), "knee_a": (264.0, 562.0), "tip_a": (243.0, 668.0),
    "hip_b": (586.0, 438.0), "knee_b": (424.0, 466.0), "tip_b": (388.0, 712.0),
    "hip_c": (824.0, 466.0), "knee_c": (904.0, 568.0), "tip_c": (906.0, 640.0),
    "hip_d": (864.0, 456.0), "knee_d": (972.0, 486.0), "tip_d": (1031.0, 666.0),
}
for _nm, (_parent, _poly, _root, _tip) in DRIPS.items():
    J[_nm] = _root
LEGS = ["a", "b", "c", "d"]
# The skeleton: part → (parent, pivot joint). The legs are posed by IK (world transforms), not here.
RIG = {
    "root": (None, "feet"),
    "body": ("root", "shell"),
    "arm_l": ("body", "shoulder_l"), "claw_l": ("arm_l", "wrist_l"), "finger_l": ("claw_l", "hinge_l"),
    "arm_r": ("body", "shoulder_r"), "palm_r": ("arm_r", "wrist_r"), "finger_r": ("palm_r", "hinge_r"),
    "drip_fl": ("finger_l", "drip_fl"), "drip_cl": ("claw_l", "drip_cl"), "drip_fr": ("finger_r", "drip_fr"),
    "drip_p1": ("palm_r", "drip_p1"), "drip_p2": ("palm_r", "drip_p2"),
}
# Draw order, back to front.
ORDER = ["leg_a_lo", "leg_a_up", "leg_c_lo", "leg_c_up", "leg_d_lo", "leg_d_up", "body", "arm_l", "leg_b_lo",
         "leg_b_up", "claw_l", "drip_cl", "finger_l", "drip_fl", "arm_r", "palm_r", "drip_p1", "drip_p2", "finger_r",
         "drip_fr"]
SEGMENTED = [p for p in ORDER if not p.startswith("drip_")]  # the parts the watershed cuts


def ellipse(cx, cy, rx, ry, n=40, a0=0.0, a1=360.0):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / (n - 1))),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / (n - 1)))) for i in range(n)]


def capsule(a, b, ra, rb, n=24):
    """A tapered capsule round the segment a → b (radii ra at a, rb at b)."""
    ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
    return ellipse(b[0], b[1], rb, rb, n, ang - 90, ang + 90) + ellipse(a[0], a[1], ra, ra, n, ang + 90, ang + 270)


# The hidden areas (painted under a part, fill colour, outlined): part → [(polygon, colour)].
UNDER = {
    "body": [([(470, 236), (520, 200), (600, 176), (640, 190), (640, 420), (600, 470), (520, 470), (466, 430), (456, 330)],
              ROCK),
             ([(800, 330), (880, 330), (900, 380), (890, 450), (850, 480), (800, 480)], ROCK_DARK)],
    "claw_l": [([(352, 150), (420, 120), (470, 140), (480, 200), (470, 236), (360, 210)], ROCK_DARK),
               ([(380, 196), (420, 150), (452, 120), (474, 150), (462, 200), (476, 236), (420, 222)], LAVA)],
    "palm_r": [([(1060, 176), (1110, 170), (1150, 230), (1180, 290), (1120, 300), (1080, 260)], ROCK_DARK),
               ([(1100, 250), (1150, 214), (1200, 206), (1214, 250), (1192, 280), (1178, 306), (1130, 306)], LAVA)],
    "arm_l": [([(330, 340), (420, 330), (470, 360), (478, 420), (440, 400), (360, 380)], ROCK_DARK)],
    "arm_r": [([(984, 346), (1030, 340), (1040, 420), (1008, 446), (990, 400)], ROCK_DARK)],
    "leg_a_up": [(capsule(J["hip_a"], (300, 470), 26, 26), ROCK)],
    "leg_b_up": [(capsule(J["hip_b"], (500, 446), 30, 30), ROCK)],
    "leg_b_lo": [(capsule(J["knee_b"], (410, 520), 30, 30), ROCK)],
    "leg_c_up": [(capsule(J["hip_c"], (880, 520), 26, 26), ROCK)],
    "leg_d_up": [(capsule(J["hip_d"], (940, 476), 26, 26), ROCK)],
    "leg_d_lo": [(capsule(J["knee_d"], (1000, 540), 26, 26), ROCK)],
    "leg_a_lo": [(capsule(J["knee_a"], (258, 590), 20, 20), ROCK)],
    "leg_c_lo": [(capsule(J["knee_c"], (904, 590), 18, 18), ROCK)],
}

CELL = (1560, 980)  # the full-size cell
CELL_FEET = (640, 930)  # the feet in it
HALF = 2  # the sheets are halved


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
    # The light ringing just outside the outline (lighter than the sky, not lava): backdrop.
    hue, sat, _ = hsv(col)
    lava_like = (hue < 60) & (sat > 0.45)
    speck = band & (alpha < 0.6) & (lum(col) > 80) & ~lava_like
    speck |= band & (alpha < 0.35) & (lum(col) > 120)
    alpha[speck] = 0
    alpha[alpha < 0.03] = 0
    # Any blue left in the un-mixed edge: its blue pulled to its red / green (no sky tint on the lava).
    bluish = band & (lum(col) > 70) & (col[..., 2] > np.maximum(col[..., 0], col[..., 1]))
    col[bluish, 2] = np.maximum(col[bluish, 0], col[bluish, 1]) * 0.5
    # Only the figure's piece.
    lab, n = ndimage.label(alpha > 0.3, structure=np.ones((3, 3)))
    if n > 1:
        sizes = ndimage.sum(np.ones_like(alpha), lab, range(1, n + 1))
        keep = ndimage.binary_dilation(lab == (1 + int(np.argmax(sizes))), iterations=2)
        alpha[~keep] = 0
    col[alpha <= 0] = 0
    return col, alpha


def segment(col, alpha):
    """Per part its px (names → masks; the drips cut out of their claws) and the outline mask."""
    h, w = alpha.shape
    solid = alpha > 0.5
    rim = solid & (ndimage.distance_transform_edt(solid) <= 2.5)
    outline = solid & ((lum(col) < OUTLINE_LUM) | rim)
    names = list(PARTS) + ["body"]
    markers = np.zeros((h, w), np.int32)
    taken = np.zeros((h, w), bool)
    for k, nm in enumerate(PARTS):
        m = poly_mask(h, w, PARTS[nm])
        inner = ndimage.distance_transform_edt(m) > SEED_SHRINK
        markers[inner & solid & ~taken] = k + 1
        taken |= m
    # The shell: its polygon, away from the parts'.
    far = ndimage.distance_transform_edt(~taken) > SEED_SHRINK
    markers[far & solid & poly_mask(h, w, BODY)] = len(names)
    dark = ndimage.gaussian_filter(255.0 - lum(col), 1.0)
    lab = watershed(dark, markers, mask=alpha > 0)
    # the cuts through flat colour smoothed (no stair steps): each label blurred, the strongest wins
    stack = np.stack([ndimage.gaussian_filter((lab == k + 1).astype(np.float32), 2.0) for k in range(len(names))])
    lab = np.where(alpha > 0, np.argmax(stack, axis=0) + 1, 0)
    part = {nm: lab == k + 1 for k, nm in enumerate(names)}
    # The drips: the lava px in their box (with their dark rim) out of their claw.
    hue, sat, val = hsv(col)
    lava = (hue < 55) & (sat > 0.5) & (val > 0.55) & solid
    for dn, (parent, poly, root, tip) in DRIPS.items():
        box = poly_mask(h, w, poly)
        m = ndimage.binary_dilation(lava & box, iterations=4) & box & part[parent]
        m = ndimage.binary_closing(m, iterations=2) & part[parent]
        part[dn] = m
        part[parent] = part[parent] & ~m
    return part, outline


def pm(colour, alpha):
    return np.dstack([colour * alpha[..., None], alpha]).astype(np.float32)


def over(dst, src):
    """src over dst (premultiplied float RGBA), in place."""
    a = src[..., 3:4]
    dst *= (1 - a)
    dst += src


def unpm(layer):
    a = layer[..., 3:4]
    rgb = np.where(a > 1e-4, layer[..., :3] / np.maximum(a, 1e-4), 0)
    return np.dstack([np.clip(rgb, 0, 255), np.clip(a * 255, 0, 255)]).astype(np.uint8)


def paint(h, w, poly, fill, ss=4):
    """A filled polygon with the bold outline (premultiplied RGBA, anti-aliased)."""
    pts = np.round(np.array(poly) * ss).astype(np.int32)
    big = np.zeros((h * ss, w * ss, 4), np.uint8)
    cv2.fillPoly(big, [pts], (*fill, 255))
    cv2.polylines(big, [pts], True, (*INK, 255), INK_W * ss, lineType=cv2.LINE_8)
    inside = np.zeros((h * ss, w * ss), np.uint8)
    cv2.fillPoly(inside, [pts], 1)
    grow = cv2.dilate(inside, np.ones((INK_W * ss // 2 + 1, INK_W * ss // 2 + 1), np.uint8))
    big[grow == 0] = 0
    small = cv2.resize(big.astype(np.float32) / 255.0, (w, h), interpolation=cv2.INTER_AREA)
    return np.dstack([small[..., :3] * 255.0, small[..., 3]]).astype(np.float32)


def fill(h, w, poly, ss=4):
    big = np.zeros((h * ss, w * ss), np.uint8)
    cv2.fillPoly(big, [np.round(np.array(poly) * ss).astype(np.int32)], 255)
    return cv2.resize(big.astype(np.float32) / 255.0, (w, h), interpolation=cv2.INTER_AREA)


def stroke(h, w, pts, width, ss=4):
    big = np.zeros((h * ss, w * ss), np.uint8)
    cv2.polylines(big, [np.round(np.array(pts) * ss).astype(np.int32)], False, 255, max(1, int(width * ss)), lineType=cv2.LINE_AA)
    return cv2.resize(big.astype(np.float32) / 255.0, (w, h), interpolation=cv2.INTER_AREA)


def seal(colour, mask, opaque, r=4):
    """Outline the cuts: the px of `mask` within r of a px opaque in the picture but not in `mask`."""
    cut = opaque & ~mask
    near = ndimage.binary_dilation(cut, iterations=r) & mask
    rim = mask & ~ndimage.binary_erosion(mask, iterations=r)
    colour = colour.copy()
    colour[near & rim] = INK
    return colour


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
    a = (np.clip(1 - d, 0, 1) ** 2 * strength).clip(0, 1).astype(np.float32)
    sub = dst[y0:y1, x0:x1]
    src = np.array(colour, np.float32)[None, None, :] * a[..., None]
    sub[..., :3] = sub[..., :3] + src * (1 - sub[..., :3] / 255.0)
    sub[..., 3] = sub[..., 3] + a * (1 - sub[..., 3])


def sprite(poly, rim, fillc, highlight=None, rim_w=4.0, ss=4):
    """A small painted shape (premultiplied, its own canvas) and its top-left: a polygon filled with
    `fillc`, outlined in `rim`, an optional highlight ellipse (cx, cy, rx, ry, colour)."""
    pts = np.array(poly, np.float64)
    x0, y0 = np.floor(pts.min(axis=0) - rim_w - 2).astype(int)
    x1, y1 = np.ceil(pts.max(axis=0) + rim_w + 2).astype(int)
    w, h = x1 - x0, y1 - y0
    big = np.zeros((h * ss, w * ss, 4), np.uint8)
    p = np.round((pts - [x0, y0]) * ss).astype(np.int32)
    cv2.fillPoly(big, [p], (*rim, 255))
    inner = np.zeros((h * ss, w * ss), np.uint8)
    cv2.fillPoly(inner, [p], 255)
    inner = cv2.erode(inner, np.ones((int(rim_w * ss), int(rim_w * ss)), np.uint8))
    big[inner > 0] = (*fillc, 255)
    if highlight is not None:
        hx, hy, rx, ry, hc = highlight
        hl = np.zeros_like(inner)
        cv2.ellipse(hl, (int((hx - x0) * ss), int((hy - y0) * ss)), (int(rx * ss), int(ry * ss)), 0, 0, 360, 255, -1)
        big[(hl > 0) & (inner > 0)] = (*hc, 255)
    small = cv2.resize(big.astype(np.float32) / 255.0, (w, h), interpolation=cv2.INTER_AREA)
    return np.dstack([small[..., :3] * small[..., 3:4] * 255.0, small[..., 3]]).astype(np.float32), (x0, y0)


def blit(dst, spr, x0, y0, alpha=1.0):
    h, w = dst.shape[:2]
    sh, sw = spr.shape[:2]
    x0, y0 = int(round(x0)), int(round(y0))
    ax0, ay0, ax1, ay1 = max(0, x0), max(0, y0), min(w, x0 + sw), min(h, y0 + sh)
    if ax0 >= ax1 or ay0 >= ay1:
        return
    over(dst[ay0:ay1, ax0:ax1], spr[ay0 - y0:ay1 - y0, ax0 - x0:ax1 - x0] * alpha)


def blob_sprite(circles, rim, fillc, highlights=(), rim_w=4.0, ss=4):
    """Round blobs merged into one shape (circles [(cx, cy, r)]), filled, outlined once in `rim`, with
    highlight circles [(cx, cy, r, colour)]; premultiplied, its own canvas, and its top-left."""
    c = np.array(circles, np.float64)
    x0, y0 = np.floor((c[:, :2] - c[:, 2:3]).min(axis=0) - rim_w - 2).astype(int)
    x1, y1 = np.ceil((c[:, :2] + c[:, 2:3]).max(axis=0) + rim_w + 2).astype(int)
    w, h = x1 - x0, y1 - y0
    shape = np.zeros((h * ss, w * ss), np.uint8)
    for cx, cy, r in circles:
        cv2.circle(shape, (int((cx - x0) * ss), int((cy - y0) * ss)), int(r * ss), 255, -1)
    inner = cv2.erode(shape, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (int(rim_w * ss) * 2 + 1, int(rim_w * ss) * 2 + 1)))
    big = np.zeros((h * ss, w * ss, 4), np.uint8)
    big[shape > 0] = (*rim, 255)
    big[inner > 0] = (*fillc, 255)
    for hx, hy, hr, hc in highlights:
        hl = np.zeros_like(inner)
        cv2.circle(hl, (int((hx - x0) * ss), int((hy - y0) * ss)), int(hr * ss), 255, -1)
        big[(hl > 0) & (inner > 0)] = (*hc, 255)
    small = cv2.resize(big.astype(np.float32) / 255.0, (w, h), interpolation=cv2.INTER_AREA)
    return np.dstack([small[..., :3] * small[..., 3:4] * 255.0, small[..., 3]]).astype(np.float32), (x0, y0)


def drop_sprite(cx, cy, size, stretch=1.0):
    """A falling lava drop (a teardrop, its point up), its round part centred on (cx, cy)."""
    top = size * 2.1 * stretch
    pts = []
    for i in range(29):
        ang = math.radians(-35 + 250 * i / 28)  # round the bottom, y down
        pts.append((cx + size * math.cos(ang), cy + size * math.sin(ang)))
    pts.append((cx, cy - top))
    return sprite(pts, DRIP_RIM, (246, 140, 14), (cx - size * 0.3, cy - size * 0.05, size * 0.28, size * 0.42, (255, 224, 90)), rim_w=3.0)


def puff_sprite(cx, cy, r, seed):
    """A cartoon smoke puff (a few round lobes), grey with a soft darker rim."""
    rng = np.random.default_rng(seed)
    circles = [(cx, cy, r * 0.62)]
    for i in range(6):
        ang = i / 6 * 2 * math.pi + rng.uniform(-0.3, 0.3)
        circles.append((cx + r * 0.5 * math.cos(ang), cy + r * 0.4 * math.sin(ang), r * rng.uniform(0.36, 0.5)))
    return blob_sprite(circles, (92, 88, 88), (164, 160, 158), [(cx - r * 0.25, cy - r * 0.25, r * 0.28, (196, 192, 190))], rim_w=3.5)


def spout_sprite(bx, by, k, seed=11):
    """The lava bursting out of the shell's top: a column of molten globs (k 0..1 its height)."""
    rng = np.random.default_rng(seed)
    hgt = 30 + 170 * k
    circles, hls = [], []
    n = 7
    for i in range(n):
        t = i / (n - 1)
        r = (46 - 20 * t) * (0.6 + 0.4 * k)
        x = bx + 10 * math.sin(t * 5 + 1) * k
        y = by - hgt * t
        circles.append((x, y, r))
        for _ in range(2):
            circles.append((x + rng.uniform(-28, 28) * (0.5 + t), y + rng.uniform(-10, 10), r * rng.uniform(0.5, 0.75)))
        hls.append((x - r * 0.25, y + r * 0.1, r * 0.45, (255, 214, 70)))
    hls.append((bx, by - hgt * 0.5, 9 + 6 * k, (255, 246, 190)))
    return blob_sprite(circles, DRIP_RIM, (250, 128, 14), hls, rim_w=4.0)


class Crab:
    def __init__(self, tone="boss", debug=None):
        rgb = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64)
        self.h, self.w = rgb.shape[:2]
        h, w = self.h, self.w
        self.col, self.alpha = key(rgb)
        self.opaque = self.alpha > 0.5
        self.mask, self.outline = segment(self.col, self.alpha)
        hue, sat, val = hsv(self.col)
        self.lava = ((hue < 58) & (sat > 0.5) & (val > 0.5) & self.opaque)
        eyes = np.zeros((h, w), bool)
        self.eye_masks = []
        for (x0, y0, x1, y1) in EYE_BOXES:
            box = poly_mask(h, w, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
            m = box & (hue > 35) & (hue < 64) & (sat > 0.5) & (val > 0.7)
            lab, n = ndimage.label(m)
            if n:
                sizes = ndimage.sum(np.ones((h, w)), lab, range(1, n + 1))
                m = lab == (1 + int(np.argmax(sizes)))
            m = ndimage.binary_dilation(m, iterations=1) & ~(lum(self.col) < OUTLINE_LUM)
            self.eye_masks.append(m)
            eyes |= m
        self.eyes = eyes
        self.lava &= ~eyes
        self.eye_c = [tuple(np.array(np.nonzero(m)[::-1]).mean(axis=1)) for m in self.eye_masks]
        if tone == "minion":
            self.col = minion_colours(self.col, self.lava, self.eyes, self.outline)
        self.tone = tone
        self.lava_f = self.lava.astype(np.float32)
        self.lava_halo = np.clip(ndimage.gaussian_filter(self.lava_f, 5.0) * 1.6, 0, 1)
        self.core = (self.lava & (hue > 36)).astype(np.float32)  # the yellow cores
        self.mask_drips = np.zeros((h, w), bool)
        for dn in DRIPS:
            self.mask_drips |= self.mask[dn]
        self.layers = {nm: self._layer(nm) for nm in ORDER}
        self.boxes = {nm: bbox(lay) for nm, lay in self.layers.items()}
        self._cache = {}

    def _layer(self, nm):
        """The part's own px (with the outline px next to it) over its painted underlay; premultiplied RGBA."""
        h, w = self.h, self.w
        own = self.mask[nm]
        if nm.startswith("drip_"):
            lay = pm(self.col, np.where(own, self.alpha, 0.0))
            return lay * ndimage.binary_dilation(lay[..., 3] > 0.3, iterations=2)[..., None]
        edge = self.outline & (ndimage.distance_transform_edt(~own) <= 4) & ~own
        for dn in DRIPS:  # a drip's rim is the drip's
            edge &= ~self.mask[dn]
        m = own | edge
        a = np.where(m, self.alpha, 0.0)
        colour = self.col
        if nm != "body":  # a plate's cut through flat colour gets its own outline
            colour = seal(self.col, m, self.opaque & ~self.mask_drips, r=3)
        out = np.zeros((h, w, 4), np.float32)
        for poly, fillc in UNDER.get(nm, []):
            over(out, paint(h, w, poly, fillc))
        behind = np.zeros((h, w), bool)
        for other in ORDER[:ORDER.index(nm)]:
            behind |= self.mask[other]
        hidden = ndimage.binary_erosion(self.opaque, iterations=1) & ~behind
        out *= hidden[..., None]
        front = np.zeros((h, w), bool)
        for other in ORDER[ORDER.index(nm) + 1:]:
            if not other.startswith("drip_"):
                front |= self.mask[other]
        ring = ndimage.binary_dilation(m & self.opaque, iterations=4) & ~m & front & self.opaque
        over(out, pm(np.broadcast_to(np.array(INK, np.float64), (h, w, 3)), ring.astype(np.float64)))
        over(out, pm(colour, a))
        if nm != "body":
            solid = (out[..., 3] > 0.3).astype(np.uint8)
            k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * INK_W + 1, 2 * INK_W + 1))
            keep = cv2.morphologyEx(solid, cv2.MORPH_OPEN, k).astype(bool) | (own & ~self.outline)
            keep = ndimage.binary_dilation(keep, iterations=1)
            out *= keep[..., None]
        # faint stray px away from the part (specks of the soft edge)
        out *= ndimage.binary_dilation(out[..., 3] > 0.3, iterations=2)[..., None]
        return out

    # ── variants: what glows ──────────────────────────────────────────────
    def variant(self, nm, fx, far=False):
        g = round(float(fx.get("glow", 0.5)), 2)
        bl = round(float(fx.get("blaze", 0.0)), 2)
        cool = round(float(fx.get("cool", 0.0)), 2)
        e = round(float(fx.get("eyes", 1.0)), 2) if nm == "body" else 1.0
        crack = int(fx.get("crack", 0)) if nm in CRACK_PARTS else 0
        key_ = (nm, g, bl, cool, e, crack, far)
        if key_ in self._cache:
            return self._cache[key_]
        lay = self.layers[nm]
        x0, y0, x1, y1 = self.boxes[nm]
        lay = lay[y0:y1, x0:x1].copy()
        lava = self.lava_f[y0:y1, x0:x1]
        core = self.core[y0:y1, x0:x1]
        halo = self.lava_halo[y0:y1, x0:x1]
        a = lay[..., 3:4]
        rgb = lay[..., :3]
        # the lava's brightness
        if g > 0.5:
            k = (g - 0.5) * 2 * 0.55
            rgb = mix(rgb, a, lava * k, (255, 226, 120))
        elif g < 0.5:
            k = (0.5 - g) * 2 * 0.6
            rgb = mix(rgb, a, lava * k, (168, 46, 8))
        if bl > 0:
            rgb = mix(rgb, a, lava * bl * 0.45, (255, 236, 150))
            rgb = mix(rgb, a, core * bl * 0.5, (255, 252, 220))
        # the lava's light on the rock round it
        lit = halo * (1 - lava) * (0.15 + 0.3 * max(0.0, g - 0.4) + 0.3 * bl) * (1 - cool)
        rgb = rgb + (np.array(EMBER, np.float32) * a - rgb) * lit[..., None] * 0.55
        if cool > 0:
            stone = (lum(unpm_rgb(rgb, a)) * 0.45 + 62)[..., None] * np.array([1.0, 0.96, 0.93], np.float32) * a
            rgb = rgb * (1 - (lava * cool)[..., None]) + stone * (lava * cool)[..., None]
            grey = lum(unpm_rgb(rgb, a))[..., None] * np.array([1.0, 0.97, 0.95], np.float32) * a
            k = (0.55 * cool * (1 - lava))[..., None]
            rgb = rgb * (1 - k) + grey * k
        if nm == "body" and e < 1.0:
            rgb = self._eyes(rgb, a, e, x0, y0)
        lay = np.dstack([rgb, a]).astype(np.float32)
        if crack:
            lay = self._cracks(lay, crack, cool, x0, y0)
        if far:
            lay[..., :3] *= FAR_SHADE
        out = (lay, (x0, y0))
        self._cache[key_] = out
        return out

    def _eyes(self, rgb, a, e, x0, y0):
        """The eyes narrowed (e 0.5: the top half lidded) or shut (0)."""
        h, w = rgb.shape[:2]
        rgb = rgb.copy()
        for m, (cx, cy) in zip(self.eye_masks, self.eye_c):
            mm = m[y0:y0 + h, x0:x0 + w]
            ys, xs = np.nonzero(mm)
            if len(ys) == 0:
                continue
            top, bot = ys.min(), ys.max()
            cut = top + (bot - top + 1) * (1.0 - e)  # rows above it are lidded
            lid = mm & (np.arange(h)[:, None] < cut)
            rgb[lid] = np.array(ROCK_DARK, np.float32) * a[lid]
            # the lid's edge: a bold line along the cut, across the eye
            line_y = min(cut, bot - 1) if e > 0 else (top + bot) / 2 + 2
            xs_l = np.nonzero(mm.any(axis=0))[0]
            pts = [(xs_l.min() - 3, line_y - 2), ((xs_l.min() + xs_l.max()) / 2, line_y + 1), (xs_l.max() + 3, line_y - 2)]
            cov = stroke(h, w, pts, 5.0) * (a[..., 0] > 0.5)
            rgb = rgb * (1 - cov[..., None]) + np.array(INK, np.float32) * cov[..., None] * a
        return rgb

    def _cracks(self, lay, stage, cool, x0, y0):
        h, w = lay.shape[:2]
        lay = lay.copy()
        solid = lay[..., 3] > 0.6
        core_c = np.array(LAVA, np.float32) * (1 - cool) + np.array((150, 146, 140), np.float32) * cool
        for st, pts in CRACKS:
            if st > stage:
                continue
            p = [(x - x0, y - y0) for x, y in pts]
            dark = stroke(h, w, p, 8.0) * solid
            core = stroke(h, w, p, 2.4) * solid
            for cov, rgb in ((dark, np.array(INK, np.float32)), (core, core_c)):
                lay[..., :3] = lay[..., :3] * (1 - cov[..., None]) + rgb * cov[..., None] * lay[..., 3:4]
        return lay

    # ── posing ───────────────────────────────────────────────────────────
    def world(self, pose):
        """Per part its 3 × 3 transform (source px → source px) for the pose; the legs (and the far
        legs, 'leg_a_up~' ...) by IK onto their tips."""
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
        # the drips hang down whatever their claw does: their root carried, only their stretch kept
        for dn in DRIPS:
            rx, ry = J[dn]
            wx, wy = (mats[RIG[dn][0]] @ np.array([rx, ry, 1.0]))[:2]
            sy = pose.get(dn, {}).get("sy", 1.0)
            mats[dn] = np.array([[1, 0, wx], [0, 1, wy], [0, 0, 1]]) @ np.diag([1.0, sy, 1.0]) @ \
                np.array([[1, 0, -rx], [0, 1, -ry], [0, 0, 1]])
        body = mats["body"]
        tips = pose.get("tips", {})
        for leg in LEGS:
            for far in (False, True):
                hip0, knee0, tip0 = np.array(J["hip_" + leg]), np.array(J["knee_" + leg]), np.array(J["tip_" + leg])
                off = np.array(FAR[leg]) if far else np.zeros(2)
                hip_w = (body @ np.array([*(hip0 + off), 1.0]))[:2]
                t = np.array(REST_TIPS[leg]) + np.array(tips.get(leg + ("~" if far else ""), (0.0, 0.0)))
                if far:
                    t = t + np.array([off[0], FAR_TIP_UP])
                m_up, m_lo = ik(hip0, knee0, tip0, hip_w, t)
                sfx = "~" if far else ""
                mats["leg_%s_up%s" % (leg, sfx)] = m_up
                mats["leg_%s_lo%s" % (leg, sfx)] = m_lo
        return mats

    def point(self, pose, part, xy, mats=None):
        m = (mats or self.world(pose))[part]
        v = m @ np.array([xy[0], xy[1], 1.0])
        return float(v[0]), float(v[1])

    def frame(self, pose, size=CELL, feet_at=CELL_FEET):
        """The pose drawn in a cell (premultiplied RGBA), the feet at feet_at."""
        mats = self.world(pose)
        fx = pose.get("fx", {})
        shift = np.array([[1, 0, feet_at[0] - FEET[0]], [0, 1, feet_at[1] - FEET[1]], [0, 0, 1]])
        out = np.zeros((size[1], size[0], 4), np.float32)
        only = pose.get("only")
        order = ([] if (only is not None or not pose.get("far", True)) else FAR_ORDER) + ORDER
        for nm in order:
            if only is not None and nm not in only:
                continue
            far = nm.endswith("~")
            lay, (x0, y0) = self.variant(nm.rstrip("~"), fx, far)
            m = shift @ mats[nm] @ np.array([[1, 0, x0], [0, 1, y0], [0, 0, 1]])
            warp_over(out, lay, m)
        if only is None:
            self._fx(out, pose, mats, shift, fx)
        return out

    def _fx(self, out, pose, mats, shift, fx):
        def at(part, xy):
            v = shift @ mats[part] @ np.array([xy[0], xy[1], 1.0])
            return float(v[0]), float(v[1])
        g = float(fx.get("glow", 0.5))
        bl = float(fx.get("blaze", 0.0))
        cool = float(fx.get("cool", 0.0))
        hx, hy = at("body", HEART)
        if bl > 0:
            glow(out, hx, hy, 190 + 70 * bl, EMBER, 0.25 * bl)
            glow(out, *at("body", SHELL_TOP), 120 + 80 * bl, (255, 200, 90), 0.45 * bl)
        e = float(fx.get("eyes", 1.0))
        if e > 0.6 and cool < 0.5:
            for c in self.eye_c:
                px, py = at("body", c)
                glow(out, px, py, 26 + 6 * g, (255, 230, 90), 0.4 * (e - 0.6) / 0.4 * (1 - cool * 2))
        sp = float(fx.get("spout", 0.0))
        if sp > 0:
            bx, by = at("body", SHELL_TOP)
            spr, (sx0, sy0) = spout_sprite(bx, by + 24, sp)
            blit(out, spr, sx0, sy0)
            rng = np.random.default_rng(11)
            for i in range(5):
                ang = math.radians(-90 + rng.uniform(-38, 38))
                d = (120 + 140 * rng.uniform()) * sp
                spr, (dx0, dy0) = drop_sprite(bx + d * math.cos(ang), by - 40 + d * math.sin(ang), 9 + 5 * rng.uniform())
                blit(out, spr, dx0, dy0)
            glow(out, bx, by - 80 * sp, 140, (255, 210, 110), 0.55 * sp)
        for dn, t in fx.get("drops", {}).items():
            if t is None or t < 0 or t > 1:
                continue
            parent, poly, root, tip = DRIPS[dn]
            tx, ty = at(dn, tip)
            gy = (shift @ np.array([0, GROUND, 1.0]))[1]
            y = ty + 10 + (gy - ty - 16) * t * t
            size = DROP_SIZE.get(dn, 9) * (1.0 - 0.25 * t)
            spr, (dx0, dy0) = drop_sprite(tx, y, size, 1.0 + 0.6 * t)
            blit(out, spr, dx0, dy0, 1.0 if t < 0.85 else (1 - t) / 0.15)
        for i, (px, py, r, a) in enumerate(fx.get("smoke", [])):
            x, y = at("body", (px, py))
            spr, (sx0, sy0) = puff_sprite(x, y, r, 30 + i)
            blit(out, spr, sx0, sy0, a)


def ik(hip0, knee0, tip0, hip_w, target):
    """Two-bone IK: the world transforms of a leg's upper (hip → knee) and lower (knee → tip) parts
    with the hip at hip_w and the tip on target (as near as it reaches), bent the way it is at rest."""
    l1 = float(np.linalg.norm(knee0 - hip0))
    l2 = float(np.linalg.norm(tip0 - knee0))
    d_vec = target - hip_w
    d = float(np.linalg.norm(d_vec))
    d = min(max(d, abs(l1 - l2) + 1e-3), l1 + l2 - 1e-3)
    base = math.atan2(d_vec[1], d_vec[0])
    cos_a = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    a = math.acos(max(-1.0, min(1.0, cos_a)))
    v1, v2 = knee0 - hip0, tip0 - hip0
    bend = 1.0 if (v1[0] * v2[1] - v1[1] * v2[0]) < 0 else -1.0  # the knee's side at rest
    ang_up = base + bend * a
    knee_w = hip_w + l1 * np.array([math.cos(ang_up), math.sin(ang_up)])
    ang_lo = math.atan2(*(target - knee_w)[::-1]) if d >= 0 else 0.0
    rest_up = math.atan2(v1[1], v1[0])
    w2 = tip0 - knee0
    rest_lo = math.atan2(w2[1], w2[0])

    def tr(p_from, p_to, ang):
        c, s = math.cos(ang), math.sin(ang)
        return np.array([[1, 0, p_to[0]], [0, 1, p_to[1]], [0, 0, 1]]) @ np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]]) @ \
            np.array([[1, 0, -p_from[0]], [0, 1, -p_from[1]], [0, 0, 1]])
    return tr(hip0, hip_w, ang_up - rest_up), tr(knee0, knee_w, ang_lo - rest_lo)


def bbox(lay, pad=2):
    ys, xs = np.nonzero(lay[..., 3] > 0.002)
    if len(xs) == 0:
        return 0, 0, 1, 1
    h, w = lay.shape[:2]
    return max(0, xs.min() - pad), max(0, ys.min() - pad), min(w, xs.max() + pad + 1), min(h, ys.max() + pad + 1)


def warp_over(dst, lay, m):
    """lay (its own px) warped by m (its px → dst px) over dst, only in the warped box."""
    h, w = lay.shape[:2]
    corners = m @ np.array([[0, w, w, 0], [0, 0, h, h], [1, 1, 1, 1]], np.float64)
    x0, y0 = int(max(0, math.floor(corners[0].min()) - 2)), int(max(0, math.floor(corners[1].min()) - 2))
    x1, y1 = int(min(dst.shape[1], math.ceil(corners[0].max()) + 2)), int(min(dst.shape[0], math.ceil(corners[1].max()) + 2))
    if x0 >= x1 or y0 >= y1:
        return
    mm = np.array([[1, 0, -x0], [0, 1, -y0], [0, 0, 1]]) @ m
    warped = cv2.warpAffine(lay, mm[:2], (x1 - x0, y1 - y0), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    over(dst[y0:y1, x0:x1], warped)


def mix(rgb, a, k, colour):
    """Premultiplied rgb blended toward colour by k (H, W) where opaque."""
    return rgb * (1 - k[..., None]) + np.array(colour, np.float32) * a * k[..., None]


def unpm_rgb(rgb, a):
    return rgb / np.maximum(a, 1e-4)


def minion_colours(col, lava, eyes, outline):
    """Cua con's colours: the basalt warmed to a red-brown, the lava brighter and more yellow."""
    col = col.copy()
    rock = ~lava & ~eyes & ~outline
    l = lum(col)[..., None]
    warm = np.clip(np.array([1.62, 0.98, 0.8]) * col + np.array([18, 4, 0]), 0, 255)
    col = np.where(rock[..., None], warm, col)
    hot = np.clip(col * np.array([1.0, 1.18, 1.0]) + np.array([10, 22, 10]), 0, 255)
    col = np.where(lava[..., None], hot, col)
    _ = l
    return col


# ── the legs, the far legs, what the death does ───────────────────────────────
REST_DROP = REST_DROP_  # the crab lowered at rest so its legs' tips reach the ground (the near ones)
REST_TIPS = {"a": (243.0, 706.0), "b": (388.0, 699.0), "c": (908.0, 690.0), "d": (1031.0, 704.0)}
# The far legs (the other four, behind the shell): a drawn leg's copy, its hip moved this much (body
# px) and its tip as far along the ground and FAR_TIP_UP higher (farther back), shaded darker.
FAR = {"a": (40.0, -22.0), "b": (58.0, -26.0), "c": (-34.0, -22.0), "d": (-50.0, -26.0)}
FAR_TIP_UP = -10.0
FAR_SHADE = 0.5
FAR_ORDER = ["leg_a_lo~", "leg_a_up~", "leg_b_lo~", "leg_b_up~", "leg_c_lo~", "leg_c_up~", "leg_d_lo~", "leg_d_up~"]
DROP_SIZE = {"drip_fl": 8, "drip_cl": 9, "drip_fr": 8, "drip_p1": 10, "drip_p2": 11}
# The death's cracks (source px polylines; the stage they appear in, 1..3), on these parts.
CRACK_PARTS = ("body", "claw_l", "palm_r")
CRACKS = [
    (1, [(716, 182), (706, 214), (724, 240), (712, 268)]),
    (1, [(640, 420), (662, 440), (652, 470)]),
    (2, [(712, 268), (690, 290), (700, 318)]),
    (2, [(820, 220), (842, 250), (832, 284), (856, 304)]),
    (2, [(560, 300), (586, 326), (578, 360)]),
    (2, [(400, 240), (420, 270), (408, 300)]),
    (3, [(760, 440), (786, 462), (780, 488)]),
    (3, [(1100, 330), (1120, 360), (1110, 392)]),
    (3, [(880, 300), (900, 330), (916, 340)]),
    (3, [(620, 200), (640, 226), (630, 252)]),
]
# The death's pieces: the shell split along this line (the left piece; the rest stays "body").
SHELL_SPLIT = [(400, 100), (716, 100), (716, 182), (706, 214), (724, 240), (712, 268), (690, 290), (700, 318),
               (708, 360), (700, 420), (712, 520), (400, 520)]
PIECES = ["leg_a_lo", "leg_a_up", "leg_c_lo", "leg_c_up", "leg_d_lo", "leg_d_up", "shell_r", "shell_l", "arm_l",
          "leg_b_lo", "leg_b_up", "claw_l", "finger_l", "arm_r", "palm_r", "finger_r"]


# ── poses ────────────────────────────────────────────────────────────────────
def pose(root=(0, 0, 0), body=(0, 0, 0, 1.0), arm_l=0.0, claw_l=0.0, finger_l=0.0, arm_r=0.0, palm_r=0.0, finger_r=0.0,
         reach=0.0, lift_l=0.0, lift_r=0.0, tips=None, drips=None, fx=None, **extra):
    """root (dx, dy, rot round the feet; dy on top of REST_DROP), body (dx, dy, rot round the shell's
    bottom, sy: its breath), arm_l / claw_l (degrees, + raises the left claw), finger_l / finger_r
    (degrees, + opens the upper pincer), arm_r / palm_r (+ raises the right claw), reach (px: the right
    arm pushed out along itself), tips {leg: (dx, dy)} (the legs' tips from their rest place; 'a~' a far
    leg), lift_l / lift_r (px: an arm lifted off its shoulder, up), drips {drip: stretch}."""
    p = {"root": {"dx": root[0], "dy": REST_DROP + root[1], "rot": root[2]},
         "body": {"dx": body[0], "dy": body[1], "rot": body[2], "sy": body[3]},
         "arm_l": {"rot": arm_l, "dy": -lift_l, "dx": -lift_l * 0.15}, "claw_l": {"rot": claw_l}, "finger_l": {"rot": -finger_l},
         "arm_r": {"rot": -arm_r, "dx": reach * 0.9 + lift_r * 0.15, "dy": -reach * 0.25 - lift_r}, "palm_r": {"rot": -palm_r},
         "finger_r": {"rot": -finger_r},
         "tips": dict(tips or {})}
    for dn, k in (drips or {}).items():
        p[dn] = {"sy": k}
    p["fx"] = dict({"glow": 0.5, "eyes": 1.0}, **(fx or {}))
    p.update(extra)
    return p


REST = pose()
# The picture as drawn (the rest_diff check): no drop, the legs' tips where they are drawn.
SOURCE_POSE = pose(root=(0, -REST_DROP, 0), tips={leg: (J["tip_" + leg][0] - REST_TIPS[leg][0], J["tip_" + leg][1] - REST_TIPS[leg][1])
                                                    for leg in LEGS}, far=False)


def wave(t, lag=0.0):
    return math.sin(t - lag)


def idle_frames(n=12):
    out = []
    # a drop falls off each drip once a loop: (the frame it lets go, the frames it falls)
    release = {"drip_p2": 1, "drip_fl": 4, "drip_p1": 6, "drip_cl": 8, "drip_fr": 10}
    for i in range(n):
        t = i / n * 2 * math.pi
        b = math.sin(t)
        drips, drops = {}, {}
        for dn, k in release.items():
            u = ((i - k) % n) / n  # 0 just let go .. 1 about to let go
            drips[dn] = 1.0 + 0.22 * u
            if (i - k) % n < 3:
                drops[dn] = ((i - k) % n + 0.5) / 3.0
        out.append(pose(body=(0, -2.0 * b, 0.25 * wave(t, 0.4), 1.0 + 0.012 * b),
                        arm_l=1.4 * wave(t, 0.7), claw_l=1.2 * wave(t, 1.2), finger_l=2.5 + 2.5 * wave(2 * t, 0.5),
                        arm_r=1.4 * wave(t, 0.9), palm_r=1.0 * wave(t, 1.4), finger_r=2.0 + 2.5 * wave(2 * t, 1.6),
                        drips=drips,
                        fx={"glow": 0.5 + 0.38 * wave(t, 0.3), "drops": drops,
                            "eyes": 0.0 if i == 8 else (0.5 if i in (7, 9) else 1.0)}))
    return out


# The walk: the legs step in two alternating groups (a, d and the far b, c / b, c and the far a, d),
# a stance sliding the tip back along the ground, a swing lifting it forward; the shell bobs twice a step.
STEP = 26.0  # px a tip slides each way
LIFT = 34.0  # px a swinging tip rises
GROUPS = {"a": 0.0, "d": 0.0, "b~": 0.0, "c~": 0.0, "b": 0.5, "c": 0.5, "a~": 0.5, "d~": 0.5}


def walk_frames(n=8, step=STEP, lift=LIFT, bob=5.0):
    out = []
    for i in range(n):
        ph = i / n
        tips = {}
        for leg, off in GROUPS.items():
            u = (ph + off) % 1.0
            if u < 0.5:  # stance: planted, sliding back (the crab moves right)
                x = step - 4 * step * u
                y = 0.0
            else:
                v = (u - 0.5) / 0.5
                x = -step + 2 * step * (0.5 - 0.5 * math.cos(v * math.pi))
                y = -lift * math.sin(v * math.pi)
            tips[leg] = (x, y)
        t = ph * 2 * math.pi
        out.append(pose(root=(0, -bob * (0.5 - 0.5 * math.cos(2 * t)), 0), body=(0, 0, 1.2 * math.sin(t), 1.0),
                        arm_l=2.5 * math.sin(2 * t - 1.0), claw_l=2.0 * math.sin(2 * t - 1.6), finger_l=3.0,
                        arm_r=2.5 * math.sin(2 * t - 1.2), palm_r=2.0 * math.sin(2 * t - 1.8), finger_r=3.0,
                        tips=tips, fx={"glow": 0.55 + 0.1 * math.sin(2 * t)}))
    return out


def shake(i, amp):
    return amp * (1 if i % 2 == 0 else -1)


SLAM_ARM = 34.0  # the right arm's turn down at the slam's impact (refined so the claw meets the ground)


def slam_frames():
    return [
        REST,
        pose(root=(-4, 0, 0), body=(0, 0, -2, 1.0), arm_r=14, palm_r=14, lift_r=16, finger_r=8, fx={"glow": 0.6}),
        pose(root=(-8, -4, 0), body=(-4, -4, -4, 1.01), arm_r=26, palm_r=30, lift_r=40, finger_r=14, arm_l=4, fx={"glow": 0.75}),
        pose(root=(-10, -8, 0), body=(-6, -6, -5, 1.02), arm_r=32, palm_r=38, lift_r=52, finger_r=14, arm_l=6, fx={"glow": 0.85}),
        pose(root=(10, 14, 0), body=(6, 6, 5, 0.97), arm_r=-SLAM_ARM, palm_r=-18, finger_r=0, arm_l=-6, claw_l=-4,
             drips={"drip_p1": 0.02, "drip_p2": 0.02}, fx={"glow": 1.0, "blaze": 0.3}),
        pose(root=(8, 10, 0), body=(5, 4, 4, 0.98), arm_r=-SLAM_ARM + 3, palm_r=-16, arm_l=-3,
             drips={"drip_p1": 0.25, "drip_p2": 0.25}, fx={"glow": 0.85}),
        pose(root=(4, 4, 0), body=(2, 2, 2, 0.99), arm_r=-14, palm_r=-6, drips={"drip_p1": 0.7, "drip_p2": 0.7}, fx={"glow": 0.7}),
        pose(root=(1, 1, 0), arm_r=-4, palm_r=-2, fx={"glow": 0.6}),
        REST]


ANIMS = {
    # name: (frames, fps, loop, peak)
    "idle": (idle_frames(), 6, True, None),
    "walk": (walk_frames(), 12, True, None),
    "fire_bombs": ([
        REST,
        pose(root=(0, 16, 0), body=(0, 4, 0, 0.97), arm_l=-6, claw_l=4, arm_r=-8, palm_r=-6, fx={"glow": 0.7}),
        pose(root=(0, 6, 0), body=(0, -2, 0, 1.0), arm_l=6, claw_l=-8, lift_l=16, arm_r=14, palm_r=10, lift_r=14,
             finger_l=8, finger_r=8, fx={"glow": 0.85, "blaze": 0.3}),
        pose(root=(0, -10, 0), body=(0, -6, 0, 1.03), arm_l=10, claw_l=-16, lift_l=34, arm_r=22, palm_r=20, lift_r=30,
             finger_l=16, finger_r=16, fx={"glow": 1.0, "blaze": 0.7, "spout": 0.25}),
        pose(root=(0, -16, 0), body=(0, -8, 0, 1.04), arm_l=12, claw_l=-20, lift_l=42, arm_r=26, palm_r=24, lift_r=38,
             finger_l=24, finger_r=24, fx={"glow": 1.0, "blaze": 1.0, "spout": 1.0}),
        pose(root=(0, -8, 0), body=(0, -5, 0, 1.02), arm_l=9, claw_l=-14, lift_l=30, arm_r=20, palm_r=18, lift_r=26,
             finger_l=16, finger_r=16, fx={"glow": 1.0, "blaze": 0.7, "spout": 0.5}),
        pose(root=(0, 4, 0), body=(0, 0, 0, 0.99), arm_l=3, claw_l=-4, lift_l=10, arm_r=8, palm_r=6, lift_r=8,
             finger_l=6, finger_r=6, fx={"glow": 0.8, "blaze": 0.3}),
        pose(fx={"glow": 0.65})], 10, False, 4),
    "claw_slam": (slam_frames(), 10, False, 4),
    "pincer": ([
        REST,
        pose(root=(12, 2, 0), body=(2, 0, 2, 1.0), arm_r=-10, palm_r=-4, reach=14, finger_r=8, fx={"glow": 0.6}),
        pose(root=(22, 4, 0), body=(4, 2, 3, 1.0), arm_r=-16, palm_r=-6, reach=34, finger_r=24, fx={"glow": 0.7}),
        pose(root=(30, 4, 0), body=(5, 2, 4, 1.0), arm_r=-18, palm_r=-8, reach=50, finger_r=34, drips={"drip_p1": 0.5, "drip_p2": 0.5}, fx={"glow": 0.8}),
        pose(root=(34, 5, 0), body=(6, 2, 4, 1.0), arm_r=-19, palm_r=-8, reach=58, finger_r=38, drips={"drip_p1": 0.4, "drip_p2": 0.4}, fx={"glow": 0.85}),
        pose(root=(36, 5, 0), body=(6, 2, 4, 1.0), arm_r=-20, palm_r=-10, reach=60, finger_r=-5, drips={"drip_p1": 0.4, "drip_p2": 0.4}, fx={"glow": 1.0, "blaze": 0.25}),
        pose(root=(30, 4, 0), body=(5, 2, 3, 1.0), arm_r=-17, palm_r=-8, reach=50, finger_r=-4, drips={"drip_p1": 0.5, "drip_p2": 0.5}, fx={"glow": 0.8}),
        pose(root=(12, 2, 0), body=(2, 0, 1, 1.0), arm_r=-6, palm_r=-3, reach=20, finger_r=2, fx={"glow": 0.6})], 10, False, 5),
    "summon": ([
        REST,
        pose(root=(4, 2, 0), body=(4, 0, 1.5, 1.0), arm_l=6, arm_r=8, finger_l=10, finger_r=10, fx={"glow": 0.7}),
        pose(root=(-5, 4, 0), body=(-5, 2, -2, 0.99), arm_l=10, arm_r=12, finger_l=18, finger_r=18, fx={"glow": 0.9, "blaze": 0.3}),
        pose(root=(5, 6, 0), body=(6, 3, 2.5, 0.98), arm_l=14, arm_r=16, finger_l=22, finger_r=22, fx={"glow": 1.0, "blaze": 0.7}),
        pose(root=(-4, 4, 0), body=(-5, 2, -2, 0.99), arm_l=12, arm_r=14, finger_l=18, finger_r=18, fx={"glow": 0.95, "blaze": 0.5}),
        pose(root=(3, 2, 0), body=(3, 1, 1, 1.0), arm_l=6, arm_r=6, finger_l=8, finger_r=8, fx={"glow": 0.75, "blaze": 0.2}),
        pose(fx={"glow": 0.6})], 8, False, 3),
    "hurt": ([
        pose(root=(-18, 4, 0), body=(-6, 4, -5, 0.98), arm_l=10, claw_l=8, arm_r=14, palm_r=10, finger_l=14, finger_r=14,
             tips={"b": (-6, 0), "a": (-4, 0)}, fx={"eyes": 0.35, "glow": 0.9}),
        pose(root=(-8, 2, 0), body=(-2, 1, -2, 0.99), arm_l=4, claw_l=3, arm_r=5, palm_r=4, finger_l=6, finger_r=6,
             fx={"eyes": 0.5, "glow": 0.7})], 7, False, None),
    "death": ([
        pose(root=(-14, 6, 0), body=(-4, 4, -4, 0.98), arm_l=8, claw_l=6, arm_r=10, palm_r=8, finger_l=12, finger_r=12,
             fx={"eyes": 0.35, "glow": 0.9}),
        pose(root=(-6, 26, 0), body=(-2, 4, -2, 0.98), arm_l=-6, claw_l=-6, arm_r=-6, palm_r=-6, finger_l=6, finger_r=6,
             tips={"a": (-10, 0), "b": (-6, 0), "c": (6, 0), "d": (10, 0)},
             fx={"eyes": 0.5, "glow": 0.4, "cool": 0.2, "crack": 1, "smoke": [(716, 140, 40, 0.75)]}),
        pose(root=(-2, 54, 0), body=(0, 6, 1, 0.97), arm_l=-16, claw_l=-14, arm_r=-16, palm_r=-12, finger_l=2, finger_r=2,
             tips={"a": (-22, 0), "b": (-14, 0), "c": (12, 0), "d": (22, 0)},
             fx={"eyes": 0.25, "glow": 0.3, "cool": 0.5, "crack": 2,
                 "smoke": [(712, 100, 56, 0.8), (600, 150, 38, 0.7), (840, 190, 34, 0.7)]}),
        pose(root=(0, 82, 0), body=(0, 8, 2, 0.96), arm_l=-26, claw_l=-22, arm_r=-30, palm_r=-18, finger_l=0, finger_r=0,
             tips={"a": (-34, 0), "b": (-22, 0), "c": (18, 0), "d": (32, 0)},
             fx={"eyes": 0.0, "glow": 0.2, "cool": 0.8, "crack": 3,
                 "smoke": [(708, 50, 70, 0.8), (585, 105, 50, 0.7), (855, 135, 46, 0.7), (420, 170, 32, 0.6)]}),
        pose(root=(0, 100, 0), body=(0, 10, 2.5, 0.96), arm_l=-30, claw_l=-26, arm_r=-36, palm_r=-20,
             tips={"a": (-42, 0), "b": (-28, 0), "c": (22, 0), "d": (40, 0)},
             fx={"eyes": 0.0, "glow": 0.1, "cool": 1.0, "crack": 3,
                 "smoke": [(704, 0, 80, 0.6), (575, 60, 56, 0.5), (865, 80, 52, 0.5)]}),
        ], 6, False, None),
}
DEATH_POSE = ANIMS["death"][0][-1]
# The minion (Cua con): the same crab, brighter, its own short set.
MINION_ANIMS = {
    "idle": (None, 8, True, None),
    "walk": (None, 14, True, None),
    "prime": (None, 10, True, None),
    "hurt": (None, 7, False, None),
}


def minion_poses():
    idle = []
    for i in range(8):
        t = i / 8 * 2 * math.pi
        b = math.sin(t)
        idle.append(pose(body=(0, -2.5 * b, 0, 1.0 + 0.015 * b), arm_l=2.0 * wave(t, 0.7), arm_r=2.0 * wave(t, 0.9),
                         finger_l=3 + 3 * wave(2 * t, 0.5), finger_r=3 + 3 * wave(2 * t, 1.6),
                         drips={dn: 1.0 + 0.1 * (0.5 + 0.5 * wave(t, k)) for k, dn in enumerate(DRIPS)},
                         fx={"glow": 0.6 + 0.3 * wave(t, 0.3), "eyes": 0.0 if i == 5 else (0.5 if i in (4, 6) else 1.0)}))
    prime = []
    for i in range(4):
        k = 0.5 + 0.5 * math.cos(i / 4 * 2 * math.pi)
        prime.append(pose(root=(shake(i, 3), -2 * k, 0), body=(0, -4 * k, shake(i, 1.5), 1.03 + 0.03 * k), arm_l=14, arm_r=18,
                          finger_l=18, finger_r=18, fx={"glow": 1.0, "blaze": 0.5 + 0.5 * k}))
    return {"idle": idle, "walk": walk_frames(8, step=30, lift=40, bob=7.0), "prime": prime,
            "hurt": ANIMS["hurt"][0]}


MINION_CELL = CELL
MINION_HEIGHT = 160  # texture px of its body (the boss: 320)


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
    """Source px (rest-posed: the feet at FEET) → the unit frame (the body 100 tall, the feet at the
    origin, facing right, y down)."""
    return [round((p[0] - FEET[0]) / BODY_H * 100, 2), round((p[1] - FEET[1]) / BODY_H * 100, 2)]


# Points on the parts (source px of the picture): the claws' tips, the pincer's grip, the slam's
# striking knuckle, the drips' tips.
FINGER_L_TIP = (572.0, 46.0)
FINGER_R_TIP = (1334.0, 184.0)
LOWER_R_TIP = (1294.0, 268.0)
LOWER_L_TIP = (548.0, 122.0)
SLAM_KNUCKLE = (1150.0, 444.0)  # the right palm's underside: it strikes the ground


def slam_contact(g, p):
    """The right claw's lowest px (its drips too; source px, posed) of pose p."""
    mats = g.world(p)
    lowest = None
    for nm in ("palm_r", "finger_r", "drip_p1", "drip_p2"):
        lay = g.layers[nm]
        ys, xs = np.nonzero(lay[..., 3] > 0.5)
        pts = mats[nm] @ np.vstack([xs, ys, np.ones_like(xs)])
        k = int(np.argmax(pts[1]))
        if lowest is None or pts[1, k] > lowest[1]:
            lowest = (float(pts[0, k]), float(pts[1, k]))
    return lowest


def fit_slam(g):
    """The slam's arm turn so the right claw's lowest px lands on the ground at the peak."""
    global SLAM_ARM
    lo, hi = 0.0, 80.0
    for _ in range(18):
        mid = (lo + hi) / 2
        SLAM_ARM = mid
        p = slam_frames()[4]
        y = slam_contact(g, p)[1]
        if y < GROUND + 2:
            lo = mid
        else:
            hi = mid
    SLAM_ARM = round(lo, 2)
    frames = slam_frames()
    ANIMS["claw_slam"] = (frames, ANIMS["claw_slam"][1], False, 4)
    # the death's drooping right claw rests on the ground, not under it (its drips cooled short)
    for i, p in enumerate(ANIMS["death"][0]):
        if i >= 2:
            for dn in ("drip_p1", "drip_p2"):
                p[dn] = {"sy": 0.25}
        a0 = -p["arm_r"]["rot"]
        if slam_contact(g, p)[1] <= GROUND + 2:
            continue
        lo, hi = a0, 0.0
        for _ in range(16):
            mid_ = (lo + hi) / 2
            p["arm_r"]["rot"] = -mid_
            if slam_contact(g, p)[1] > GROUND + 2:
                lo = mid_
            else:
                hi = mid_
        p["arm_r"]["rot"] = -round(hi, 2)
    return slam_contact(g, frames[4])


def write_points(g, path, anims):
    frames = {}
    for anim, (poses, fps, loop, peak) in anims.items():
        rows = []
        for p in poses:
            mats = g.world(p)
            fx = p.get("fx", {})

            def at(part, xy):
                return unit(g.point(p, part, xy, mats))
            eyes = [g.point(p, "body", c, mats) for c in g.eye_c]
            row = {"heart": at("body", HEART), "shellTop": at("body", SHELL_TOP),
                   "eyes": unit(((eyes[0][0] + eyes[1][0]) / 2, (eyes[0][1] + eyes[1][1]) / 2)),
                   "clawL": unit(mid(g.point(p, "finger_l", FINGER_L_TIP, mats), g.point(p, "claw_l", LOWER_L_TIP, mats))),
                   "clawR": unit(mid(g.point(p, "finger_r", FINGER_R_TIP, mats), g.point(p, "palm_r", LOWER_R_TIP, mats))),
                   "knuckle": at("palm_r", SLAM_KNUCKLE),
                   "glow": round(float(fx.get("glow", 0.5)) + 0.5 * float(fx.get("blaze", 0.0)) - float(fx.get("cool", 0.0)), 2),
                   "eyesLit": round(float(fx.get("eyes", 1.0)) * (1 - float(fx.get("cool", 0.0))), 2)}
            for dn, (parent, poly, root, tip) in DRIPS.items():
                row[dn] = at(dn, tip)
            rows.append(row)
        frames[anim] = rows
    out = {"_doc": "Written by art_source/bosses/lava_crab/make_frames.py (do not edit). Cua Dung Nham's points per frame of side.json, in the unit frame BossArt draws in (the body 100 tall = side.json height, the feet at the origin, facing right, y down; mirror x when it faces left): heart = the shell's middle (heals / drains), shellTop = the shell's top crack (the lava bombs burst out of it: fire_bombs' peak), eyes = between the eyes, clawL / clawR = between the upper and the lower pincer's tips of the left / right claw (clawR: the pincer's grip, closed at pincer's peak), knuckle = the right palm's underside (on the ground at claw_slam's peak: the impact), drip_* = the lava drips' tips (a drop falls from there), glow = how bright the lava is (0.5 as drawn, 1+ blazing, below 0 cooled to stone), eyesLit (1 open .. 0 shut).",
           "frames": frames}
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(json.dumps(out, ensure_ascii=False) + "\n")
    print("  wrote", os.path.relpath(path, os.path.join(HERE, "..", "..", "..")))


def mid(a, b):
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)


def pieces(g):
    """The death's pieces in DEATH_POSE, each a full cell (premultiplied), in PIECES order."""
    mats = g.world(DEATH_POSE)
    fx = DEATH_POSE["fx"]
    shift = np.array([[1, 0, CELL_FEET[0] - FEET[0]], [0, 1, CELL_FEET[1] - FEET[1]], [0, 0, 1]])
    cells = {}
    for sn in PIECES:
        nm = "body" if sn.startswith("shell_") else sn
        lay, (x0, y0) = g.variant(nm, fx)
        lay = lay.copy()
        if nm in ("claw_l", "finger_l", "palm_r", "finger_r"):  # its drips with it
            for dn, (parent, poly, root, tip) in DRIPS.items():
                if parent == nm:
                    dl, (dx0, dy0) = g.variant(dn, fx)
                    full = np.zeros_like(lay)
                    sub = full[dy0 - y0:dy0 - y0 + dl.shape[0], dx0 - x0:dx0 - x0 + dl.shape[1]]
                    sub[...] = dl[:sub.shape[0], :sub.shape[1]]
                    over(lay, full)
        if sn.startswith("shell_"):
            m = poly_mask(g.h, g.w, SHELL_SPLIT)[y0:y0 + lay.shape[0], x0:x0 + lay.shape[1]]
            m = m if sn == "shell_l" else ~m
            m = m & (lay[..., 3] > 0)
            opaque = lay[..., 3] > 0.5
            colour = unpm(lay * m[..., None])[..., :3].astype(np.float64)
            colour = seal(colour, m & opaque, opaque, r=4)
            lay = pm(colour, lay[..., 3] * m)
        out = np.zeros((CELL[1], CELL[0], 4), np.float32)
        warp_over(out, lay, shift @ mats[nm] @ np.array([[1, 0, x0], [0, 1, y0], [0, 0, 1]]))
        cells[sn] = out
    return cells


def write_import(dest, anims, out_res, height, skins=None, parts=None, pictures=None, doc=""):
    cw, ch = CELL[0] // HALF, CELL[1] // HALF
    fx_, fy_ = CELL_FEET[0] / HALF, CELL_FEET[1] / HALF
    a_out = {}
    for anim, (poses, fps, loop, peak) in anims.items():
        n = len(poses)
        a = {"src": f"side_{anim}/sheet_v1.png", "frames": n, "fps": fps, "loop": loop, "bodyHeight": BODY_H / HALF,
             "cuts": [cw * i for i in range(1, n)], "anchors": [[fx_ + cw * i, fy_] for i in range(n)]}
        if peak is not None:
            a["peak"] = peak
        a_out[anim] = a
    cfg = {"_doc": doc % (cw, ch, fx_, fy_, BODY_H / HALF),
           "out": out_res, "height": height, "pad": 4, "background": {"key": "alpha"}, "alphaCut": 4, "edgeFade": 0,
           "body": {"hue": [0, 360], "minSat": 0.0, "minVal": 0.12, "maxVal": 1.0, "centreRows": [0.55, 0.8], "minPiece": 0.08},
           "anims": a_out}
    if skins:
        cfg["skins"] = skins
    if parts:
        cfg["parts"] = parts
    if pictures:
        cfg["pictures"] = pictures
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "w") as f:
        f.write(json.dumps(cfg, indent="\t", ensure_ascii=False) + "\n")
    print("  wrote", os.path.relpath(dest, HERE))


IMPORT_DOC = ("Written by make_frames.py here (do not edit: edit the script and re-run it). tools/import_boss_frames.gd reads it "
              "(see its header and README.txt here). The sheets are already transparent (background.key 'alpha'), one row per "
              "animation in fixed %d x %d cells with the feet (the middle of the legs' ground contact) at (%g, %g) of every cell: "
              "cuts at the cells, anchors the feet, bodyHeight %g (the raised left claw's top to the feet, sheet px) -> height "
              "texture px. body: every colour (measured only for the width).")
BOSS_DOC = IMPORT_DOC + (" skins.idle: the rest pose (skin/rest_v1.png, full size) on a skeleton: joints (that picture's px), "
                         "bones, feet / bodyHeight given, tracks (the breath: a sine per bone), glow = the shell's middle on "
                         "the body bone in ember orange, eyes. parts: the death's pieces in the last death frame's pose, one "
                         "cell each at the frames' scale (feet given), back to front.")
MINION_DOC = IMPORT_DOC + (" Cua con (minion crab): the boss's own picture, its shell warmed to a red-brown and its lava "
                           "brighter, imported smaller (height); written by ../make_frames.py.")


def skin_cfg(g):
    off = (CELL_FEET[0] - FEET[0], CELL_FEET[1] - FEET[1])
    mats = g.world(REST)

    def p(part, xy):
        x, y = g.point(REST, part, xy, mats)
        return [round(x + off[0], 1), round(y + off[1], 1)]
    joints = {
        "hips": p("body", (720, 470)), "crown": p("body", (716, 176)),
        "shoulder_l": p("arm_l", J["shoulder_l"]), "wrist_l": p("claw_l", J["wrist_l"]),
        "claw_l_tip": p("claw_l", (400, 160)), "hinge_l": p("finger_l", J["hinge_l"]), "finger_l_tip": p("finger_l", FINGER_L_TIP),
        "shoulder_r": p("arm_r", J["shoulder_r"]), "wrist_r": p("palm_r", J["wrist_r"]),
        "palm_r_tip": p("palm_r", (1250, 360)), "hinge_r": p("finger_r", J["hinge_r"]), "finger_r_tip": p("finger_r", FINGER_R_TIP),
        "heart": p("body", HEART),
    }
    for leg in LEGS:
        joints["hip_" + leg] = p("leg_%s_up" % leg, J["hip_" + leg])
        joints["knee_" + leg] = p("leg_%s_lo" % leg, J["knee_" + leg])
        joints["tip_" + leg] = p("leg_%s_lo" % leg, J["tip_" + leg])
    bones = [["root", "", "feet", "hips", 0], ["body", "root", "hips", "crown", 1.5],
             ["arm_l", "body", "shoulder_l", "wrist_l", 1.5], ["claw_l", "arm_l", "wrist_l", "claw_l_tip", 2.5],
             ["finger_l", "claw_l", "hinge_l", "finger_l_tip", 3],
             ["arm_r", "body", "shoulder_r", "wrist_r", 1.5], ["palm_r", "arm_r", "wrist_r", "palm_r_tip", 2.5],
             ["finger_r", "palm_r", "hinge_r", "finger_r_tip", 3]]
    for leg in LEGS:
        bones.append(["leg_%s_up" % leg, "root", "hip_" + leg, "knee_" + leg, 1.5])
        bones.append(["leg_%s_lo" % leg, "leg_%s_up" % leg, "knee_" + leg, "tip_" + leg, 1.5])
    eyes = [[round(x + off[0], 1), round(y + off[1], 1)] for x, y in (g.point(REST, "body", c, mats) for c in g.eye_c)]
    tracks = {"period": 2.4, "keys": 14, "bones": {
        "body": {"rot": 0.25, "lag": 0.0, "sy": 0.012},
        "arm_l": {"rot": 1.4, "lag": 0.7}, "claw_l": {"rot": 1.2, "lag": 1.2}, "finger_l": {"rot": -2.5, "lag": 1.6},
        "arm_r": {"rot": -1.4, "lag": 0.9}, "palm_r": {"rot": -1.0, "lag": 1.4}, "finger_r": {"rot": -2.5, "lag": 2.0}}}
    return {"idle": {"motion": "breath", "src": "skin/rest_v1.png", "height": 360, "pad": 6,
                     "feet": [CELL_FEET[0], CELL_FEET[1]], "bodyHeight": BODY_H,
                     "glow": {"joint": "heart", "bone": "body", "colour": [1.0, 0.55, 0.16]},
                     "eyes": eyes, "joints": joints, "bones": bones, "tracks": tracks}}


def debug_out(g, d):
    os.makedirs(d, exist_ok=True)
    for nm, c in (("dark", (30, 30, 40)), ("orange", (255, 140, 0)), ("white", (255, 255, 255))):
        base = np.ones((g.h, g.w, 3)) * np.array(c)
        a = g.alpha[..., None]
        Image.fromarray((g.col * a + base * (1 - a)).astype(np.uint8)).save(os.path.join(d, f"keyed_{nm}.png"))
    rng = np.random.default_rng(3)
    vis = g.col * 0.35
    for nm, m in g.mask.items():
        vis[m] = vis[m] * 0.4 + rng.integers(60, 255, 3) * 0.6
    vis[g.eyes] = (0, 255, 0)
    Image.fromarray(vis.astype(np.uint8)).save(os.path.join(d, "parts_map.png"))
    for nm in ORDER:
        lay = g.layers[nm]
        comp = np.ones((g.h, g.w, 4), np.float32) * np.array([255 * 0.35, 140 * 0.35, 0, 1], np.float32)
        over(comp, lay)
        x0, y0, x1, y1 = bbox(lay, 6)
        Image.fromarray(np.clip(comp[y0:y1, x0:x1, :3], 0, 255).astype(np.uint8)).save(os.path.join(d, f"part_{nm}.png"))
    src = pm(g.col, g.alpha)
    rest = g.frame(SOURCE_POSE, size=(g.w, g.h), feet_at=FEET)
    diff = np.abs(rest - src).max(axis=2)
    vis = unpm(rest)[..., :3].astype(np.float32) * 0.5
    vis[diff > 60] = (255, 0, 0)
    Image.fromarray(vis.astype(np.uint8)).save(os.path.join(d, "rest_diff.png"))
    print("  rest diff px > 60:", int((diff > 60).sum()))


def preview(g, anims, d, name):
    for anim, (poses, fps, loop, peak) in anims.items():
        fs = [unpm(g.frame(p)) for p in poses]
        strip = np.concatenate([f[200:, 60:-60] for f in fs], axis=1)
        bg = np.ones(strip.shape[:2] + (3,)) * np.array([70, 110, 160])
        bg[CELL_FEET[1] - 200:, :] = (90, 80, 60)
        a = strip[..., 3:4] / 255.0
        Image.fromarray((strip[..., :3] * a + bg * (1 - a)).astype(np.uint8)).save(os.path.join(d, f"{name}_{anim}.png"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--debug")
    ap.add_argument("--check", action="store_true", help="with --debug: only the debug pictures and the rest check")
    ap.add_argument("--preview", help="with --debug: only these animations (comma separated), as one strip each")
    args = ap.parse_args()
    g = Crab()
    contact = fit_slam(g)
    print(f"  slam: arm {SLAM_ARM}°, the claw meets the ground at {contact[0]:.1f}, {contact[1]:.1f}")
    if args.debug:
        if args.preview:
            os.makedirs(args.debug, exist_ok=True)
            names = args.preview.split(",")
            preview(g, {a: v for a, v in ANIMS.items() if a in names}, args.debug, "strip")
            if "minion" in names:
                m = Crab("minion")
                mp = minion_poses()
                preview(m, {a: (mp[a], *MINION_ANIMS[a][1:]) for a in MINION_ANIMS}, args.debug, "minion")
            return
        debug_out(g, args.debug)
        if args.check:
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
    rest = g.frame(pose(fx={"glow": 0.55}), )
    rx = np.nonzero((rest[..., 3] > 0.5).any(axis=0))[0]
    ry = np.nonzero((rest[..., 3] > 0.5).any(axis=1))[0]
    print(f"  rest: top {ry.min() - (CELL_FEET[1] - FEET[1]):.0f} (TOP {TOP}), width {rx.max() - rx.min() + 1}")
    save(unpm(rest), "skin/rest_v1.png")
    portrait = g.frame(pose(arm_l=6, arm_r=10, finger_l=14, finger_r=16, fx={"glow": 0.85, "blaze": 0.15}))
    save(unpm(portrait), "portrait/portrait_v1.png")
    bust = g.frame(pose(fx={"glow": 0.8}), )
    # the bust: the face with the shell and the claws' roots, cut under the shell (the eyes in its middle)
    cut = int(CELL_FEET[1] - FEET[1] + REST_DROP + 452)
    ramp = np.clip((cut - np.arange(CELL[1])) / 16, 0, 1).astype(np.float32)
    xc = int(CELL_FEET[0] - FEET[0] + 720)
    side = np.clip((250 - np.abs(np.arange(CELL[0]) - xc)) / 36, 0, 1).astype(np.float32)
    bust *= ramp[:, None, None] * side[None, :, None]
    save(unpm(bust), "portrait/bust_v1.png")
    cells = pieces(g)
    for sn in PIECES:
        save(unpm(halve(cells[sn])), f"parts/{sn}_v1.png")
    mats = g.world(REST)

    def src_unit(part, xy):
        return unit(g.point(REST, part, xy, mats))
    peak_slam = ANIMS["claw_slam"][0][4]
    peak_pincer = ANIMS["pincer"][0][5]
    peak_bombs = ANIMS["fire_bombs"][0][4]
    rig = {
        "_doc": "Written by make_frames.py (do not edit). The unit frame BossArt draws in (the body 100 tall = the raised left claw's top to the ground at rest, the feet at the origin, facing right, y down); src = source px of concept/lava_crab_v1.png posed at rest (the crab lowered %g px so its legs reach the ground)." % REST_DROP,
        "feet": list(FEET), "top": TOP, "bodyHeight": BODY_H, "restDrop": REST_DROP,
        "heart": src_unit("body", HEART),
        "eyes": [src_unit("body", c) for c in g.eye_c],
        "bombs": {"unit": unit(g.point(peak_bombs, "body", SHELL_TOP)), "frame": 4, "rest": src_unit("body", SHELL_TOP)},
        "slamImpact": {"unit": unit(contact), "frame": 4},
        "pincerTip": {"unit": unit(mid(g.point(peak_pincer, "finger_r", FINGER_R_TIP), g.point(peak_pincer, "palm_r", LOWER_R_TIP))),
                      "frame": 5},
        "drips": {dn: src_unit(dn, tip) for dn, (parent, poly, root, tip) in DRIPS.items()},
        "width": round(float(rx.max() - rx.min() + 1) / BODY_H, 3),
    }
    with open(os.path.join(HERE, "rig_v1.json"), "w") as f:
        json.dump(rig, f, indent="\t")
        f.write("\n")
    print("  rig:", json.dumps(rig))
    write_points(g, os.path.join(ASSETS, "side", "points.json"), ANIMS)
    write_import(os.path.join(HERE, "import.json"), ANIMS, "res://assets/bosses/lava_crab/", 320, skins=skin_cfg(g),
                 parts={"bodyHeight": BODY_H / HALF, "feet": [CELL_FEET[0] / HALF, CELL_FEET[1] / HALF],
                        "src": {sn: f"parts/{sn}_v1.png" for sn in PIECES}},
                 pictures={"portrait": {"src": "portrait/portrait_v1.png", "size": 512, "margin": 8},
                           "bust": {"src": "portrait/bust_v1.png", "size": 384, "margin": 6}},
                 doc=BOSS_DOC)
    # Cua con
    m = Crab("minion")
    mp = minion_poses()
    m_anims = {a: (mp[a], *MINION_ANIMS[a][1:]) for a in MINION_ANIMS}
    for anim, (poses, fps, loop, peak) in m_anims.items():
        save(sheet([m.frame(p) for p in poses]), f"minion/side_{anim}/sheet_v1.png")
    write_points(m, os.path.join(ASSETS, "minion", "side", "points.json"), m_anims)
    write_import(os.path.join(HERE, "minion", "import.json"), m_anims, "res://assets/bosses/lava_crab/minion/", MINION_HEIGHT,
                 doc=MINION_DOC)


if __name__ == "__main__":
    main()
