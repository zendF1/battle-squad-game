#!/usr/bin/env python3
"""The rig preview's PNG frames (tools/record_rig_preview.sh) into a looping GIF (30 fps → 15 fps)."""
import os
import sys

from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
names = sorted(n for n in os.listdir(src) if n.endswith(".png"))
frames = [Image.open(os.path.join(src, n)).convert("RGB") for n in names[::2]]
pal = [f.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames]
pal[0].save(dst, save_all=True, append_images=pal[1:], duration=66, loop=0, optimize=True, disposal=1)
print("gif:", dst, len(frames), "frames")
