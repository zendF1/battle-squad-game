#!/usr/bin/env python3
"""Draws a picture with the Gemini API (Nano Banana image models) and saves it as a PNG.

Setup once: copy .env.example to .env at the repo root and fill GEMINI_API_KEY (Google AI Studio,
"Get API key", with billing on: the image models have no free tier). .env is git-ignored.

  python3 tools/gen_image.py "a bronze chest icon ..." --out art_source/ui/chest_v1.png
  python3 tools/gen_image.py -f art_source/bosses/x/style.txt -f art_source/bosses/x/cast.txt \
      --ref art_source/bosses/x/concept/model_sheet_v1.png --aspect 16:9 --size 2K \
      --out art_source/bosses/x/side_cast/sheet_v1.png

Options:
  prompt text (positional) and/or -f/--prompt-file FILE (repeatable): all joined, files first,
      blank line between, so a shared STYLE block + the picture's own part go in one request.
  --ref FILE (repeatable): reference pictures sent with the prompt (keep the character / style).
      Pictures above 2048 px are scaled down first (fewer input tokens).
  --out FILE: where the PNG goes (default art_source/gen/<time>.png). Never overwrites: an
      existing name ending _v<k> moves to the next free _v<k+1>, any other to <name>_2, _3...
  -n N: N separate requests (N pictures to choose from).
  --aspect 1:1 | 16:9 | 9:16 | 4:3 | 3:4 | 3:2 | 2:3 | 21:9 ... (default 1:1)
  --size 1K | 2K | 4K (default 1K)
  --model (default GEMINI_IMAGE_MODEL from .env, else gemini-nano-banana-2.1)
  --dry-run: print what would be sent and the estimated cost, call nothing.

Game art convention (art_source/**/PROMPTS.md): the subject on flat magenta #FF00FF, the import
tools (tools/import_*.gd) key it out. The API adds no visible watermark.

Every call appends one line to art_source/gen_log.jsonl: time, model, prompt, refs, files saved,
token usage, images returned and the estimated cost in USD (the price table below, from
ai.google.dev/gemini-api/docs/pricing; a model missing from it logs tokens only). It prints the
cost of the call and of the whole log so far.
"""

import argparse
import base64
import datetime as dt
import io
import json
import mimetypes
import os
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOG = os.path.join(ROOT, "art_source", "gen_log.jsonl")
DEFAULT_MODEL = "gemini-nano-banana-2.1"
API_BASE = "https://generativelanguage.googleapis.com/v1"
MAX_REF_PX = 2048
RETRY_STATUS = (429, 500, 502, 503, 504)

# USD per 1M tokens: input (text / image), text and thinking output, image output.
# Nano Banana 2.1: $0.0336 per 1K image, $0.0504 per 2K, $0.113 per 4K.
PRICES = {
    "gemini-nano-banana-2.1": {"in": 1.50, "text_out": 7.50, "image_out": 30.0},
}


def load_env():
    path = os.path.join(ROOT, ".env")
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key, value = key.strip(), value.strip().strip('"').strip("'")
            if value and key not in os.environ:
                os.environ[key] = value


def build_prompt(args):
    parts = []
    for path in args.prompt_file or []:
        with open(path, encoding="utf-8") as f:
            parts.append(f.read().strip())
    if args.prompt:
        parts.append(" ".join(args.prompt).strip())
    prompt = "\n\n".join(p for p in parts if p)
    if not prompt:
        sys.exit("gen_image: no prompt (give text and/or -f FILE)")
    return prompt


def ref_part(path):
    mime = mimetypes.guess_type(path)[0] or "image/png"
    with open(path, "rb") as f:
        data = f.read()
    try:
        from PIL import Image
        im = Image.open(io.BytesIO(data))
        if max(im.size) > MAX_REF_PX:
            im.thumbnail((MAX_REF_PX, MAX_REF_PX))
            buf = io.BytesIO()
            im.save(buf, "PNG")
            data, mime = buf.getvalue(), "image/png"
    except ImportError:
        pass
    return {"inline_data": {"mime_type": mime, "data": base64.b64encode(data).decode()}}


def free_path(path):
    """path, or the next free name: stem_v<k> -> stem_v<k+1>, else stem_2, stem_3..."""
    if not os.path.exists(path):
        return path
    stem, ext = os.path.splitext(path)
    m = re.match(r"^(.*_v)(\d+)$", stem)
    k = int(m.group(2)) + 1 if m else 2
    while True:
        cand = f"{m.group(1)}{k}{ext}" if m else f"{stem}_{k}{ext}"
        if not os.path.exists(cand):
            return cand
        k += 1


def call(model, body, key):
    url = f"{os.environ.get('GEMINI_API_BASE', API_BASE)}/models/{model}:generateContent"
    data = json.dumps(body).encode()
    for attempt in range(4):
        req = urllib.request.Request(url, data=data, method="POST", headers={
            "x-goog-api-key": key, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:
            text = e.read().decode(errors="replace")
            try:
                msg = json.loads(text)["error"]["message"]
            except (ValueError, KeyError, TypeError):
                msg = text[:500]
            if e.code in RETRY_STATUS and attempt < 3:
                wait = 5 * 2 ** attempt
                print(f"gen_image: HTTP {e.code} ({msg[:120]}), retry in {wait}s", file=sys.stderr)
                time.sleep(wait)
                continue
            sys.exit(f"gen_image: HTTP {e.code}: {msg}")
        except urllib.error.URLError as e:
            if attempt < 3:
                time.sleep(5 * 2 ** attempt)
                continue
            sys.exit(f"gen_image: network error: {e.reason}")
    sys.exit("gen_image: gave up")


def cost_of(model, usage):
    price = PRICES.get(model)
    if not price or not usage:
        return None
    image_out = text_out = 0
    for d in usage.get("candidatesTokensDetails") or []:
        if d.get("modality") == "IMAGE":
            image_out += d.get("tokenCount", 0)
        else:
            text_out += d.get("tokenCount", 0)
    if not usage.get("candidatesTokensDetails"):
        image_out = usage.get("candidatesTokenCount", 0)  # no breakdown: count it all as image
    text_out += usage.get("thoughtsTokenCount", 0)
    usd = (usage.get("promptTokenCount", 0) * price["in"] + text_out * price["text_out"]
           + image_out * price["image_out"]) / 1e6
    return round(usd, 5)


def log_total():
    total = 0.0
    if os.path.exists(LOG):
        with open(LOG, encoding="utf-8") as f:
            for line in f:
                try:
                    total += json.loads(line).get("costUsd") or 0
                except ValueError:
                    pass
    return total


def main():
    ap = argparse.ArgumentParser(description="Draw a picture with the Gemini API (see the header).")
    ap.add_argument("prompt", nargs="*")
    ap.add_argument("-f", "--prompt-file", action="append")
    ap.add_argument("--ref", action="append", default=[])
    ap.add_argument("--out")
    ap.add_argument("-n", type=int, default=1)
    ap.add_argument("--aspect", default="1:1")
    ap.add_argument("--size", default="1K", choices=["1K", "2K", "4K"])
    ap.add_argument("--model")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    load_env()
    model = args.model or os.environ.get("GEMINI_IMAGE_MODEL") or DEFAULT_MODEL
    prompt = build_prompt(args)
    for r in args.ref:
        if not os.path.isfile(r):
            sys.exit(f"gen_image: no such reference picture: {r}")
    out = args.out or os.path.join(ROOT, "art_source", "gen",
                                   dt.datetime.now().strftime("%Y%m%d_%H%M%S") + ".png")
    if not out.lower().endswith(".png"):
        out += ".png"

    per_image = {"1K": 1120, "2K": 1680, "4K": 3780}[args.size]
    est = PRICES.get(model, {}).get("image_out")
    est_text = f"~${per_image * est / 1e6 * args.n:.3f}" if est else "unknown (model not in PRICES)"
    if args.dry_run:
        print(f"model {model}, {args.n} request(s), {args.aspect} {args.size}, refs {args.ref or 'none'}")
        print(f"out {out}\nestimated image cost {est_text}\n--- prompt ---\n{prompt}")
        return

    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        sys.exit("gen_image: GEMINI_API_KEY is empty: fill it in .env at the repo root (see .env.example)")

    parts = [{"text": prompt}] + [ref_part(r) for r in args.ref]
    body = {"contents": [{"parts": parts}],
            "generationConfig": {"responseModalities": ["TEXT", "IMAGE"],
                                 "imageConfig": {"aspectRatio": args.aspect, "imageSize": args.size}}}

    stem, ext = os.path.splitext(out)
    for i in range(args.n):
        target = out if args.n == 1 else f"{stem}_{i + 1}{ext}"
        started = time.time()
        resp = call(model, body, key)
        saved, texts = [], []
        for cand in resp.get("candidates") or []:
            for part in (cand.get("content") or {}).get("parts") or []:
                blob = part.get("inlineData") or part.get("inline_data")
                if blob and not part.get("thought"):
                    path = free_path(target)
                    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
                    raw = base64.b64decode(blob["data"])
                    try:
                        from PIL import Image
                        Image.open(io.BytesIO(raw)).save(path, "PNG")
                    except ImportError:
                        with open(path, "wb") as f:
                            f.write(raw)
                    saved.append(os.path.relpath(path, ROOT))
                elif part.get("text") and not part.get("thought"):
                    texts.append(part["text"].strip())
        usage = resp.get("usageMetadata") or {}
        cost = cost_of(model, usage)
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(json.dumps({
                "time": dt.datetime.now().isoformat(timespec="seconds"), "model": model,
                "aspect": args.aspect, "size": args.size, "prompt": prompt, "refs": args.ref,
                "files": saved, "images": len(saved), "usage": usage, "costUsd": cost,
                "seconds": round(time.time() - started, 1)}, ensure_ascii=False) + "\n")
        for t in texts:
            print(f"model says: {t[:300]}")
        if not saved:
            reason = [c.get("finishReason") for c in resp.get("candidates") or []]
            block = (resp.get("promptFeedback") or {}).get("blockReason")
            sys.exit(f"gen_image: no picture returned (finish {reason}, block {block})")
        cost_text = f"${cost:.4f}" if cost is not None else "unknown"
        print(f"saved {', '.join(saved)} ({len(saved)} image(s), {cost_text}, log total ${log_total():.2f})")


if __name__ == "__main__":
    main()
