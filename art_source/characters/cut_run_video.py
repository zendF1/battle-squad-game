"""Cut a run cycle out of an AI video (character running in place, locked camera, plain background).

Finds the cleanest loop inside the first --within seconds (default 3: later the video only repeats), the start s
and length P, 14..40 video frames, whose frame s+P looks most like frame s,
over the figure's box), writes every video frame of that loop as side_run_v2/frame_1..P.png (cropped round the
figure), then runs make_run_frames.py with the video's fps. No fixed frame count: one full stride, however many
frames it has. Rookie, 2026-11-16: 24 frames (41-64) of a 24 fps Gemini video.

  python3 -I art_source/characters/cut_run_video.py <id> <video.mp4> [--within 3] [--skip 0.25] [--min 14] [--max 40] [--no-import]
"""
import argparse, os, subprocess, sys
import cv2, numpy as np
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("id"); ap.add_argument("video")
    ap.add_argument("--min", type=int, default=14); ap.add_argument("--max", type=int, default=40)
    ap.add_argument("--no-import", action="store_true")
    ap.add_argument("--within", type=float, default=3.0, help="only the first N seconds (the rest just repeats)")
    ap.add_argument("--count", type=int, default=0, help="instead of a loop: N frames evenly spaced over the first --within seconds")
    ap.add_argument("--skip", type=float, default=0.25, help="seconds to skip at the start (the still picture starting to move)")
    a = ap.parse_args()
    cap = cv2.VideoCapture(a.video)
    fps = cap.get(cv2.CAP_PROP_FPS) or 24.0
    frames = []
    while True:
        ok, f = cap.read()
        if not ok:
            break
        frames.append(cv2.cvtColor(f, cv2.COLOR_BGR2RGB))
    if len(frames) < a.min * 2:
        sys.exit("video too short: %d frames" % len(frames))
    small = np.stack([cv2.resize(f, (320, 180)) for f in frames]).astype(np.float32).mean(3) / 255.0
    fig = (small < 0.85).any(0)
    ys, xs = np.where(fig)
    g = small[:, ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    n = min(len(g), int(round(a.within * fps)) + 1)  # the user: only the first ~3 s are right, the rest repeats
    skip = int(round(a.skip * fps))
    best = None
    for P in range(a.min, a.max + 1):
        for s in range(skip, n - P):
            d = float(np.abs(g[s] - g[s + P]).mean())
            if best is None or d < best[0]:
                best = (d, s, P)
    d, s, P = best
    picks = list(range(s, s + P))
    play_fps = fps
    if a.count:  # the user's way (2026-11-16): the first 3 s, N frames evenly spaced, same speed as the video
        span = min(len(frames), int(round(a.within * fps)))
        picks = [int(k * span / a.count) for k in range(a.count)]
        s, P, d = picks[0], len(picks), float("nan")
        play_fps = a.count / (span / fps)
    # crop round the figure over the whole loop, with a margin
    H, W = frames[0].shape[:2]
    full = np.stack([frames[i].astype(np.int16).min(2) < 200 for i in picks]).any(0)
    fy, fx = np.where(full)
    m = int(0.06 * H)
    box = (max(0, fx.min() - m), max(0, fy.min() - m), min(W, fx.max() + m), min(H, fy.max() + m))
    out = os.path.join(REPO, "art_source/characters", a.id, "side_run_v2")
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.startswith("frame_") and f.endswith(".png"):
            os.remove(os.path.join(out, f))
    for k, i in enumerate(picks, 1):
        Image.fromarray(frames[i]).crop(box).save(os.path.join(out, "frame_%d.png" % k))
    note = ("%s run frames (match): frame_1..%d.png cut by cut_run_video.py from %s (%dx%d, %.0f fps, %d frames):\n"
            "video frames %s, cropped to %s; played at %.2f fps (the video's speed).\n"
            % (a.id, P, os.path.basename(a.video), W, H, fps, len(frames), " ".join(map(str, picks)), box, play_fps))
    open(os.path.join(out, "README.txt"), "w").write(note)
    print(note)
    if not a.no_import:
        run_dir = os.path.join(REPO, "assets/characters", a.id, "rig/run")
        if os.path.isdir(run_dir):  # a shorter loop than last time must not leave old frames behind
            for f in os.listdir(run_dir):
                if f.startswith("run_"):
                    os.remove(os.path.join(run_dir, f))
        subprocess.check_call([sys.executable, "-I", os.path.join(REPO, "art_source/characters/make_run_frames.py"),
                               a.id, "--fps", "%g" % play_fps])


if __name__ == "__main__":
    main()
