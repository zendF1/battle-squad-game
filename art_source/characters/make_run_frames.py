#!/usr/bin/env python3
"""The match run frames of a rigged character (the user's call: in matches the run is drawn frames, no
bones; scenes/character/rig/char_rig.gd load_run()), from the user's run pictures:

  art_source/characters/<id>/side_run_v2/sheet.png        the whole grid (4 x 2 equal cells, read left to
                                                          right, top row first), or
  art_source/characters/<id>/side_run_v2/frame_1.png ...  the frames already cut (frame_1 .. frame_N)

white (or transparent) background, the character facing right, no gun (the slung gun is drawn over the
frames by the game, riding each frame's torso).

  1. the sheet cut into its cells: by the white gutters between them (rows / columns with nothing drawn,
     the thin light-grey cell borders count as drawn), else by GRID equal cells;
  2. each cell / frame keyed: the white backdrop and the light-grey cell border removed by flood from the
     cell's border (not by a threshold: the near-white shirts inside their outlines stay), the soft edge
     un-mixed against the white, only the figure's blob kept; enclosed gaps (between an arm and the body,
     between the legs) stay white unless listed in HOLES ({"frame_3": [[x, y], ...]}, px of the cell, in
     side_run_v2/holes.json);
  3. scaled so the tallest frame is as tall as the standing rig (rig.json height; --scale k to change),
     the feet of every frame on the ground (its lowest px on y 0), the head over the standing picture's
     head (the centre of each frame's top 40 % over the centre of the rig's head part);
  4. written: assets/characters/<id>/rig/run/run_<i>.png (rig px), their .import files, and
     assets/characters/<id>/rig/run.json {frames, xf (image px -> rig px), bob (rig px each frame's head
     sits lower than standing: the slung gun follows it), fps}.

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow):

  python3 -I art_source/characters/make_run_frames.py <id> [--fps 12] [--scale 1.0] [--debug DIR]

Then focus the Godot editor (it imports the new PNGs). Without run.json a walking character shows its
standing picture lifting with each step; delete run.json (and run/) to go back to that.
"""
import argparse
import glob
import hashlib
import json
import os
import random
import re
import shutil

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
GRID = (4, 2)  # the sheet's cells when no gutter shows: columns, rows
NOISE = 0.06
LIGHT = 150  # the backdrop flood goes through px whose darkest channel is over this and that are grey
GREY_SAT = 40
WHITE = 236  # a gutter: no px darker than this
TOP_SHARE = 0.4  # the head: the frame's top share of its height

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="res://.godot/imported/{name}-{md5}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{md5}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def uid_text():
    n = random.getrandbits(62) | 1
    out = ""
    while n:
        c = n % 36
        out = (chr(ord("a") + c) if c < 26 else chr(ord("0") + c - 26)) + out
        n //= 36
    return "uid://" + out


def write_import(path):
    res = "res://" + os.path.relpath(path, REPO).replace(os.sep, "/")
    imp = path + ".import"
    uid = uid_text()
    if os.path.exists(imp):  # keep the uid the editor knows
        m = re.search(r'uid="(uid://[a-z0-9]+)"', open(imp).read())
        uid = m.group(1) if m else uid
    name = os.path.basename(path)
    with open(imp, "w") as f:
        f.write(IMPORT.format(uid=uid, name=name, md5=hashlib.md5(res.encode()).hexdigest(), res=res))


def runs(flags):
    """[start, end) runs of True."""
    out, start = [], None
    for i, v in enumerate(list(flags) + [False]):
        if v and start is None:
            start = i
        elif not v and start is not None:
            out.append((start, i))
            start = None
    return out


def cut_sheet(rgba):
    """The cells' boxes (x0, y0, x1, y1), left to right, top row first."""
    rgb = rgba[..., :3].astype(np.float64)
    drawn = (rgb.min(axis=2) < WHITE) & (rgba[..., 3] > 20)
    h, w = drawn.shape
    rows = runs(drawn.any(axis=1))
    cols = runs(drawn.any(axis=0))
    rows = [r for r in rows if r[1] - r[0] > h * 0.1]
    cols = [c for c in cols if c[1] - c[0] > w * 0.06]
    if len(rows) * len(cols) >= 2:
        return [(c[0], r[0], c[1], r[1]) for r in rows for c in cols]
    ys, xs = np.nonzero(drawn)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    cw, ch = (x1 - x0) / GRID[0], (y1 - y0) / GRID[1]
    return [(round(x0 + i * cw), round(y0 + j * ch), round(x0 + (i + 1) * cw), round(y0 + (j + 1) * ch))
            for j in range(GRID[1]) for i in range(GRID[0])]


def key(rgba, holes=()):
    """Straight colour and alpha of one cell, the backdrop (white, the light-grey border, transparent)
    flooded from the cell's border."""
    rgb = rgba[..., :3].astype(np.float64)
    a0 = rgba[..., 3].astype(np.float64) / 255.0
    light = ((rgb.min(axis=2) > LIGHT) & (rgb.max(axis=2) - rgb.min(axis=2) < GREY_SAT)) | (a0 < 0.1)
    lab, _n = ndimage.label(light)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    for x, y in holes:
        if 0 <= y < lab.shape[0] and 0 <= x < lab.shape[1] and lab[y, x]:
            bg |= lab == lab[y, x]
    core = ndimage.binary_erosion(bg, iterations=1)
    band = (ndimage.distance_transform_edt(~bg) <= 3) & ~core
    a = ((255.0 - rgb) / 255.0).max(axis=2)
    a = np.clip((a - NOISE) / (1 - NOISE), 0, 1) * a0
    alpha = np.where(bg & ~band, 0.0, a0)
    alpha = np.where(band, a, alpha)
    col = 255.0 + (rgb - 255.0) / np.maximum(alpha, 1e-4)[..., None]
    col = np.where(band[..., None], np.clip(col, 0, 255), rgb)
    alpha[alpha < 0.05] = 0
    lab, n = ndimage.label(alpha > 0.3, structure=np.ones((3, 3)))
    if n >= 1:
        sizes = ndimage.sum(np.ones_like(alpha), lab, range(1, n + 1))
        keep = ndimage.binary_dilation(lab == (1 + int(np.argmax(sizes))), iterations=2)
        alpha[~keep] = 0
    return col, alpha


def frames_of(cid):
    d = os.path.join(HERE, cid, "side_run_v2")
    holes = {}
    if os.path.exists(os.path.join(d, "holes.json")):
        holes = json.load(open(os.path.join(d, "holes.json")))
    out = []
    files = sorted(glob.glob(os.path.join(d, "frame_*.png")), key=lambda p: int(re.findall(r"\d+", os.path.basename(p))[0]))
    if files:
        for i, p in enumerate(files):
            out.append(key(np.asarray(Image.open(p).convert("RGBA")), holes.get("frame_%d" % (i + 1), ())))
    elif os.path.exists(os.path.join(d, "sheet.png")):
        sheet = np.asarray(Image.open(os.path.join(d, "sheet.png")).convert("RGBA"))
        for i, (x0, y0, x1, y1) in enumerate(cut_sheet(sheet)):
            out.append(key(sheet[y0:y1, x0:x1], holes.get("frame_%d" % (i + 1), ())))
    else:
        raise SystemExit("no side_run_v2/sheet.png or frame_1.png ... in " + os.path.relpath(d, REPO))
    return out


def head_centre_x(rig_dir, rig):
    """The centre x (rig px) of the standing picture's head part."""
    part = next(p for p in rig["parts"] if p["name"] == "head")
    a = np.asarray(Image.open(os.path.join(rig_dir, part["png"])).convert("RGBA"))[..., 3]
    xs = np.nonzero(a.max(axis=0) > 30)[0]
    cx = (xs.min() + xs.max() + 1) / 2.0
    xx, _xy, _yx, _yy, ox, _oy = part["xf"]
    return xx * cx + ox


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("id")
    ap.add_argument("--fps", type=float, default=12.0)
    ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--debug")
    args = ap.parse_args()
    rig_dir = os.path.join(REPO, "assets", "characters", args.id, "rig")
    rig = json.load(open(os.path.join(rig_dir, "rig.json")))
    frames = frames_of(args.id)
    boxes = []
    for col, alpha in frames:
        ys, xs = np.nonzero(alpha > 0.3)
        boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    tallest = max(b[3] - b[1] for b in boxes)
    s = float(rig["height"]) / tallest * args.scale
    head_x = head_centre_x(rig_dir, rig)
    out_dir = os.path.join(rig_dir, "run")
    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)
    os.makedirs(out_dir)
    data = {"source": "art_source/characters/make_run_frames.py", "frames": [], "xf": [], "bob": [], "fps": args.fps}
    sheet = []
    for i, ((col, alpha), (x0, y0, x1, y1)) in enumerate(zip(frames, boxes)):
        pad = 4
        x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
        x1, y1 = min(alpha.shape[1], x1 + pad), min(alpha.shape[0], y1 + pad)
        c, a = col[y0:y1, x0:x1], alpha[y0:y1, x0:x1]
        w, h = max(1, round(c.shape[1] * s)), max(1, round(c.shape[0] * s))
        pm = Image.fromarray(np.dstack([c * a[..., None], a * 255]).clip(0, 255).astype(np.uint8), "RGBA")
        pm = np.asarray(pm.resize((w, h), Image.LANCZOS)).astype(np.float64)
        aa = pm[..., 3:4] / 255.0
        rgb = np.where(aa > 1e-3, pm[..., :3] / np.maximum(aa, 1e-3), 0)
        seen = aa[..., 0] > 1e-3
        if seen.any():  # clear px take their nearest drawn colour (no dark fringe when filtered)
            _, (iy, ix) = ndimage.distance_transform_edt(~seen, return_indices=True)
            rgb = rgb[iy, ix]
        img = np.dstack([rgb.clip(0, 255), (aa * 255).clip(0, 255)]).astype(np.uint8)
        name = "run_%d.png" % i
        Image.fromarray(img, "RGBA").save(os.path.join(out_dir, name), optimize=True)
        write_import(os.path.join(out_dir, name))
        # image px -> rig px: feet (the lowest drawn row) on y 0, the head's centre over the standing one's
        ys, xs = np.nonzero(img[..., 3] > 76)
        bottom = ys.max() + 1
        top_rows = img[: ys.min() + max(1, round((bottom - ys.min()) * TOP_SHARE)), :, 3] > 76
        hx = np.nonzero(top_rows.any(axis=0))[0]
        cx = (hx.min() + hx.max() + 1) / 2.0
        data["frames"].append("run/" + name)
        data["xf"].append([1.0, 0.0, 0.0, 1.0, round(head_x - cx, 2), float(-bottom)])
        data["bob"].append(round(float(rig["height"]) - float(bottom - ys.min()), 2))
        sheet.append(img)
    with open(os.path.join(rig_dir, "run.json"), "w") as f:
        json.dump(data, f, indent=1)
    if args.debug:
        os.makedirs(args.debug, exist_ok=True)
        hh = max(im.shape[0] for im in sheet)
        strip = Image.new("RGBA", (sum(im.shape[1] + 10 for im in sheet), hh + 10), (205, 205, 205, 255))
        x = 0
        for im in sheet:
            strip.alpha_composite(Image.fromarray(im, "RGBA"), (x, hh - im.shape[0]))
            x += im.shape[1] + 10
        strip.save(os.path.join(args.debug, "run_%s.png" % args.id))
    print("frames:", len(sheet), "scale %.3f" % s, "->", os.path.relpath(rig_dir, REPO) + "/run.json")


if __name__ == "__main__":
    main()
