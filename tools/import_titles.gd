extends SceneTree
## Imports the title plates (ui/title_plate.gd): the AI-drawn banners, one per rarity,
## art_source/ui/titles/title_<colour>.png (blue, orange, purple, red), drawn with no text on a
## dark, near-black background with no alpha. Reproducible: everything it does is in
## art_source/ui/titles/titles.json. Runs headless (only Image is used; the editor may stay open):
##
##   $GODOT --headless --path . -s tools/import_titles.gd [-- --debug=<dir>]
##
## Per picture, in source px: the background colour is sampled on the picture's border (the mean
## of the outer `borderSample` px); the generator's grey "✦" watermarks are painted out (the star
## shape at `centre` with half sizes `size`, grown by `watermarkGrow` px, re-filled from the px
## round it, so the glow or the ribbon corner it sits on carries on); the picture is scaled once to `scale` (Lanczos: the picture over its background is
## premultiplied colour, so scaling before keying makes no fringe). Then the background is keyed
## out without eating the dark outlines: d = the largest channel difference to the background
## colour; a flood fill from the border over px with d < `bgTolerance` is fully transparent (the
## outer glow around the art stops it before the outlines, which are as dark as the background);
## from there the glow is climbed (`climb`: a neighbour joins while d does not drop more than that
## below the highest d met on the way, and it is at most `glowWidth` px from the transparent
## region): those px get a soft alpha, the smallest alpha that un-mixes them from the background
## colour (a = max over the channels brighter than it of (c − bg) / (1 − bg)), curved like the back auras
## (floor `bgTolerance`, `alphaGamma`, `alphaBoost`), the colour un-premultiplied from the
## background (c = bg + (c − bg) / a: the glow keeps its hue, the red stays red). Every other px
## (the outlines and everything inside them) stays opaque. Last, the picture is trimmed to its
## content (alpha > `trimAlpha`) plus `margin` px.
##
## Writes assets/ui/titles/title_<colour>.png and assets/ui/titles/titles.json: per colour the
## texture size, the `stretch` x ranges (texture px: where a long name widens the plate; the ends
## and the centre ornaments between them are never stretched) and the `text` rect (texture px: the
## inner panel the name is centred in). A new PNG gets an .import with mipmaps, an existing .import
## is never touched: let the editor import them; until then ui/art.gd reads the PNG.
## --debug=<dir> also writes <colour>_mask.png (red: keyed out, green: glow, grey: opaque) and the
## plates over a light and a mid backdrop, to check for a dark box or eaten outlines.

const SRC := "res://art_source/ui/titles/"
const CONFIG := SRC + "titles.json"
const OUT := "res://assets/ui/titles/"


func _initialize() -> void:
	var debug := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--debug="):
			debug = a.trim_prefix("--debug=")
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if not cfg is Dictionary:
		push_error("import_titles: %s is not a JSON object" % CONFIG)
		quit(1)
		return
	var meta := {"_doc": "Written by tools/import_titles.gd (do not edit; edit art_source/ui/titles/titles.json and re-run). Texture px: size [w, h], stretch [[x0, x1], ...] (widened for a long name), text [x0, y0, x1, y1] (the name's box)."}
	for colour in cfg["titles"]:
		var t: Dictionary = cfg["titles"][colour]
		var src := Image.load_from_file(ProjectSettings.globalize_path(SRC + str(t["source"])))
		if src == null or src.is_empty():
			push_error("import_titles: cannot read %s%s" % [SRC, t["source"]])
			continue
		var res := processed(src, cfg, t)
		var img: Image = res["image"]
		_save(img, OUT + "title_%s.png" % colour)
		meta[colour] = {"size": [img.get_width(), img.get_height()], "stretch": res["stretch"], "text": res["text"]}
		if debug != "":
			DirAccess.make_dir_recursive_absolute(debug)
			(res["mask"] as Image).save_png(debug.path_join("%s_mask.png" % colour))
			for bd in [["light", Color(0.93, 0.93, 0.9)], ["mid", Color(0.36, 0.52, 0.42)]]:
				var back := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
				back.fill(bd[1])
				back.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
				back.save_png(debug.path_join("%s_%s.png" % [colour, bd[0]]))
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "titles.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t", false) + "\n")
	f.close()
	quit(0)


## The picture keyed and trimmed (see the header): {image, mask, stretch, text} in texture px.
static func processed(src: Image, cfg: Dictionary, opts: Dictionary) -> Dictionary:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGB8)
	var bg := border_colour(img, int(cfg.get("borderSample", 3)))
	for wm in opts.get("watermarks", []):
		remove_watermark(img, Vector2(wm["centre"][0], wm["centre"][1]), float(wm["size"][0]), float(wm["size"][1]), float(cfg.get("watermarkGrow", 2.0)), bg)
	var scale := float(cfg.get("scale", 0.5))
	img.resize(int(round(img.get_width() * scale)), int(round(img.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	var k := keyed(img, bg, float(cfg.get("bgTolerance", 0.04)), float(cfg.get("climb", 0.05)),
		int(round(float(cfg.get("glowWidth", 40)) * scale)), float(cfg.get("alphaGamma", 1.0)), float(cfg.get("alphaBoost", 1.0)),
		int(cfg.get("minIsland", 0)))
	var keyed_img: Image = k["image"]
	var box := content_rect(keyed_img, float(cfg.get("trimAlpha", 0.02)), int(cfg.get("margin", 4)))
	var out := keyed_img.get_region(box)
	var mask := (k["mask"] as Image).get_region(box)
	var stretch := []
	for r in opts.get("stretch", []):
		stretch.append([int(round(r[0] * scale)) - box.position.x, int(round(r[1] * scale)) - box.position.x])
	var tr: Array = opts.get("text", [0, 0, src.get_width(), src.get_height()])
	var text := [int(round(tr[0] * scale)) - box.position.x, int(round(tr[1] * scale)) - box.position.y,
		int(round(tr[2] * scale)) - box.position.x, int(round(tr[3] * scale)) - box.position.y]
	return {"image": out, "mask": mask, "stretch": stretch, "text": text}


## The mean colour of the outer `ring` px of the picture.
static func border_colour(img: Image, ring: int) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in h:
		for x in w:
			if x >= ring and x < w - ring and y >= ring and y < h - ring:
				continue
			sum += img.get_pixel(x, y)
			n += 1
	return Color(sum.r / n, sum.g / n, sum.b / n)


## Paints out a grey "✦": the star's shape (4 concave points, (|dx| / rx)^0.75 + (|dy| / ry)^0.75 <= 1
## round c, grown by `grow` px for its soft edge) is re-filled from the px round it (repeated
## averaging, a harmonic fill: the glow, outline or gold under it carries on smoothly).
static func remove_watermark(img: Image, c: Vector2, rx: float, ry: float, grow: float, bg: Color) -> void:
	var hole := []
	for y in range(maxi(1, int(c.y - ry - grow - 1)), mini(img.get_height() - 2, int(c.y + ry + grow + 1)) + 1):
		for x in range(maxi(1, int(c.x - rx - grow - 1)), mini(img.get_width() - 2, int(c.x + rx + grow + 1)) + 1):
			var dx := absf(x + 0.5 - c.x)
			var dy := absf(y + 0.5 - c.y)
			if pow(dx / (rx + grow), 0.75) + pow(dy / (ry + grow), 0.75) <= 1.0 or Vector2(dx, dy).length() <= grow + 1.0:
				hole.append(Vector2i(x, y))
	for q in hole:
		img.set_pixelv(q, bg)
	for _i in 400:
		for q in hole:
			var sum := Color(0, 0, 0, 0)
			for n in [q + Vector2i(1, 0), q + Vector2i(-1, 0), q + Vector2i(0, 1), q + Vector2i(0, -1)]:
				sum += img.get_pixelv(n)
			img.set_pixelv(q, Color(sum.r / 4.0, sum.g / 4.0, sum.b / 4.0))


## Keys the background colour out (see the header): {image (RGBA8), mask (RGB8 debug)}.
static func keyed(img: Image, bg: Color, tolerance: float, climb: float, glow_width: int, gamma: float, boost: float, min_island: int = 0) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.get_data()
	var b := [bg.r, bg.g, bg.b]
	var d := PackedFloat32Array()
	d.resize(w * h)
	for k in w * h:
		var i := k * 3
		d[k] = maxf(absf(src[i] / 255.0 - b[0]), maxf(absf(src[i + 1] / 255.0 - b[1]), absf(src[i + 2] / 255.0 - b[2])))
	# The flood fill reads d smoothed over 3 × 3 px (the generator's noise on the background); the
	# climb reads it unsmoothed (a 1 px dark outline must stop it)
	var ds := PackedFloat32Array()
	ds.resize(w * h)
	for y in h:
		for x in w:
			var sum := 0.0
			var n := 0
			for yy in range(maxi(0, y - 1), mini(h - 1, y + 1) + 1):
				for xx in range(maxi(0, x - 1), mini(w - 1, x + 1) + 1):
					sum += d[yy * w + xx]
					n += 1
			ds[y * w + x] = sum / n
	# 0 = opaque, 1 = keyed out (background), 2 = glow
	var state := PackedByteArray()
	state.resize(w * h)
	var queue := PackedInt32Array()
	for x in w:
		for y in [0, h - 1]:
			var k: int = y * w + x
			if ds[k] < tolerance and state[k] == 0:
				state[k] = 1
				queue.append(k)
	for y in h:
		for x in [0, w - 1]:
			var k: int = y * w + x
			if ds[k] < tolerance and state[k] == 0:
				state[k] = 1
				queue.append(k)
	var head := 0
	while head < queue.size():
		var k := queue[head]
		head += 1
		for n in _neighbours(k, w, h):
			if state[n] == 0 and ds[n] < tolerance:
				state[n] = 1
				queue.append(n)
	# The glow: climbed from the keyed-out region; peak = the highest d on the way, dist = steps
	var peak := PackedFloat32Array()
	peak.resize(w * h)
	var dist := PackedInt32Array()
	dist.resize(w * h)
	var glow := PackedInt32Array()
	for k in w * h:
		if state[k] == 1:
			peak[k] = d[k]
			glow.append(k)
	head = 0
	while head < glow.size():
		var k := glow[head]
		head += 1
		if dist[k] >= glow_width:
			continue
		for n in _neighbours(k, w, h):
			if state[n] != 0 or d[n] < peak[k] - climb:
				continue
			state[n] = 2
			peak[n] = maxf(peak[k], d[n])
			dist[n] = dist[k] + 1
			glow.append(n)
	# Specks the climb stepped round (opaque islands smaller than min_island px) are glow too
	var seen := PackedByteArray()
	seen.resize(w * h)
	for k0 in w * h:
		if state[k0] != 0 or seen[k0] != 0:
			continue
		var island := PackedInt32Array([k0])
		seen[k0] = 1
		var at := 0
		while at < island.size():
			for n in _neighbours(island[at], w, h):
				if state[n] == 0 and seen[n] == 0:
					seen[n] = 1
					island.append(n)
			at += 1
		if island.size() <= min_island:
			for k in island:
				state[k] = 2
	var out := PackedByteArray()
	out.resize(w * h * 4)
	var mask := PackedByteArray()
	mask.resize(w * h * 3)
	for k in w * h:
		var i := k * 3
		var o := k * 4
		if state[k] == 1:
			mask[i] = 200
			continue # transparent black
		if state[k] == 0:
			out[o] = src[i]
			out[o + 1] = src[i + 1]
			out[o + 2] = src[i + 2]
			out[o + 3] = 255
			mask[i] = 110
			mask[i + 1] = 110
			mask[i + 2] = 110
			continue
		mask[i + 1] = 200
		var need := 0.0 # the smallest alpha that un-mixes this px from bg (a glow only adds light:
		for c in 3: # a channel below the background is the generator's noise, not a darker colour)
			var v := src[i + c] / 255.0
			if v > b[c]:
				need = maxf(need, (v - b[c]) / (1.0 - b[c]))
		var a := minf(1.0, pow(clampf((need - tolerance) / (1.0 - tolerance), 0.0, 1.0), gamma) * boost)
		a = maxf(a, need) if a > 0.0 else 0.0
		if a <= 0.0:
			continue
		for c in 3:
			out[o + c] = int(round(clampf(b[c] + maxf(0.0, src[i + c] / 255.0 - b[c]) / a, 0.0, 1.0) * 255.0))
		out[o + 3] = int(round(a * 255.0))
	return {"image": Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out),
		"mask": Image.create_from_data(w, h, false, Image.FORMAT_RGB8, mask)}


static func _neighbours(k: int, w: int, h: int) -> Array:
	var x := k % w
	var y := k / w
	var out := []
	if x > 0:
		out.append(k - 1)
	if x < w - 1:
		out.append(k + 1)
	if y > 0:
		out.append(k - w)
	if y < h - 1:
		out.append(k + w)
	return out


## The bounding box of the px with alpha > min_alpha, grown by margin px (inside the picture).
static func content_rect(img: Image, min_alpha: float, margin: int) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	var data := img.get_data()
	var limit := int(min_alpha * 255.0)
	for y in h:
		for x in w:
			if data[(y * w + x) * 4 + 3] > limit:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i(0, 0, w, h)
	x0 = maxi(0, x0 - margin)
	y0 = maxi(0, y0 - margin)
	x1 = mini(w - 1, x1 + margin)
	y1 = mini(h - 1, y1 + margin)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func _save(img: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if not FileAccess.file_exists(abs_path + ".import"):
		var f := FileAccess.open(abs_path + ".import", FileAccess.WRITE)
		f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\n')
		f.close()
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("import_titles: cannot write %s (%s)" % [path, error_string(err)])
		return
	print("  %s  %dx%d  %.1f KB" % [path, img.get_width(), img.get_height(), FileAccess.get_file_as_bytes(abs_path).size() / 1024.0])
