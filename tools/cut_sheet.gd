extends SceneTree
## Cuts a character's AI-made parts sheet (art_source/characters/<id>/, white background) into
## the part PNGs of one of its cutout rigs (assets/characters/<id>/<rig>/parts/<part>.png, see
## scenes/character/rig.gd and assets/README.md; <rig> is "lobby", the front view of the screens
## outside the match). Reproducible: everything it does is in art_source/characters/<id>/
## parts.json (and any other *parts.json there, one per rig). Runs headless or windowed (only
## Image is used):
##
##   $GODOT --headless --path . -s tools/cut_sheet.gd [-- <id> ...]    # default: every id with a parts.json
##
## parts.json: {"rig": "lobby", "sheet": "<file in the same folder>", "scale": output px per sheet
## px (pick it so the parts are drawn 1:1 where they are shown: the lobby rig's rig.json scale
## 0.64 puts them 1:1 on the 1600x900 lobby stage),
## "tolerance": 0..1 (how far from white still counts as background), "parts": {name: part}}.
## A part: "rect" [x, y, w, h] in sheet px (loose is fine), optional "seed" [x, y] (a sheet
## point on the part: the connected piece under it is kept, otherwise the largest piece in the
## rect), "clip" [[x, y], ...] a convex polygon in sheet px the part is cut to (to split joined
## pieces, e.g. the hips from the legs) with "feather" px of soft edge along the cut, "holes"
## [[x, y], ...] sheet points of enclosed white areas to clear (a fist's hole the gun's grip
## shows through).
##
## Per part: the white background is flood-filled from the rect's border (near-white pixels,
## `tolerance`), so enclosed whites (eyes, teeth, highlights) stay; only the piece under the
## seed is kept (no bits of neighbours); the edge pixels get their alpha from how far they are
## from white and their colour un-blended from white (no white halo, the anti-aliased outline
## stays soft); then the clip, a trim to the visible pixels (+2 px), the scale (Lanczos on
## premultiplied colour, once, from the full-resolution cut) and the PNG. A new PNG gets an
## .import without mipmaps (the parts are drawn at their own size); an existing .import is never
## touched.

const SRC := "res://art_source/characters/"
const OUT := "res://assets/characters/"
const PAD := 2
## Edge pixels whose distance from white is above this are fully opaque.
const EDGE_FULL := 0.85

var _written := 0
var _bytes := 0


func _initialize() -> void:
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = Array(DirAccess.get_directories_at(SRC))
	for id in ids:
		for f in DirAccess.get_files_at(SRC + str(id)):
			if f.ends_with("parts.json"):
				_cut_character(str(id), SRC + str(id) + "/" + f)
	print("cut_sheet: wrote %d parts, %.1f KB" % [_written, _bytes / 1024.0])
	quit()


func _cut_character(id: String, spec_path: String) -> void:
	var spec = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	if not spec is Dictionary:
		push_error("cut_sheet: %s missing or not a JSON object" % spec_path)
		return
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SRC + id + "/" + str(spec["sheet"])))
	if sheet == null:
		push_error("cut_sheet: cannot read the sheet of " + id)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var scale := float(spec.get("scale", 1.0))
	var tol := float(spec.get("tolerance", 0.1))
	var rig_name := str(spec.get("rig", "lobby"))
	print("%s %s: %s %dx%d, scale %.4f" % [id, rig_name, spec["sheet"], sheet.get_width(), sheet.get_height(), scale])
	var parts: Dictionary = spec["parts"]
	for part_name in parts:
		var cut := cut_part(sheet, parts[part_name], tol, scale)
		if cut.is_empty():
			push_error("cut_sheet: %s/%s is empty" % [id, part_name])
			continue
		_save(cut["image"], OUT + "%s/%s/parts/%s.png" % [id, rig_name, part_name], cut["origin"])


## One part (see the header): {image (straight-alpha RGBA), origin (sheet px of the image's
## top-left before the scale)}, or {} when nothing is left.
static func cut_part(sheet: Image, p: Dictionary, tol: float, scale: float) -> Dictionary:
	var r: Array = p["rect"]
	var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])).intersection(Rect2i(Vector2i.ZERO, sheet.get_size()))
	var img := sheet.get_region(rect)
	var w := img.get_width()
	var h := img.get_height()
	var px := img.get_data() # RGBA8
	var n := w * h
	# Distance from white per pixel (0 white .. 1 a saturated or black channel).
	var dist := PackedFloat32Array()
	dist.resize(n)
	for i in n:
		var o := i * 4
		dist[i] = 1.0 - minf(minf(px[o], px[o + 1]), px[o + 2]) / 255.0
	# Background: near-white pixels connected to the rect's border (and the listed holes).
	var bg := PackedByteArray()
	bg.resize(n)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	for hole in p.get("holes", []):
		var hp := Vector2i(int(hole[0]), int(hole[1])) - rect.position
		if Rect2i(0, 0, w, h).has_point(hp):
			stack.append(hp.y * w + hp.x)
	_flood(stack, bg, dist, tol, w, h)
	# The piece under the seed (or the largest one).
	var keep := _pick_piece(bg, w, h, p.get("seed"), rect.position)
	if keep.is_empty():
		return {}
	# Alpha: the piece opaque; its edge band (piece pixels next to the background and background
	# pixels next to the piece) by distance from white, colour un-blended from white.
	var alpha := PackedFloat32Array()
	alpha.resize(n)
	for i in n:
		alpha[i] = 1.0 if keep[i] == 1 else 0.0
	for i in n:
		var x := i % w
		var y := i / w
		var near_bg := false
		var near_keep := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var xx := x + dx
				var yy := y + dy
				if xx < 0 or yy < 0 or xx >= w or yy >= h:
					continue
				var j := yy * w + xx
				if bg[j] == 1:
					near_bg = true
				elif keep[j] == 1:
					near_keep = true
		if keep[i] == 1 and near_bg:
			alpha[i] = clampf(dist[i] / EDGE_FULL, 0.0, 1.0)
		elif bg[i] == 1 and near_keep:
			alpha[i] = clampf(dist[i] / EDGE_FULL, 0.0, 1.0)
	# The clip polygon (convex, sheet px) with a soft edge: a coverage on top of the edge alpha.
	var clip: Array = p.get("clip", [])
	var poly := PackedVector2Array()
	for q in clip:
		poly.append(Vector2(float(q[0]), float(q[1])) - Vector2(rect.position))
	var feather := maxf(0.5, float(p.get("feather", 1.0)))
	var ccw := _signed_area(poly) > 0.0
	# Premultiplied colour (the edge un-blended from white: c = a*F + (1-a)*white), then trim.
	var out := PackedByteArray()
	out.resize(n * 4)
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for i in n:
		var e := alpha[i]
		if e <= 0.004:
			continue
		var a := e
		if poly.size() >= 3:
			a *= clampf(_inside_distance(poly, Vector2(i % w, i / w) + Vector2(0.5, 0.5), ccw) / feather + 0.5, 0.0, 1.0)
			if a <= 0.004:
				continue
		var o := i * 4
		for c in 3:
			var v := px[o + c] / 255.0
			if e < 1.0:
				v = clampf((v - (1.0 - e)) / e, 0.0, 1.0)
			out[o + c] = int(round(v * a * 255.0))
		out[o + 3] = int(round(a * 255.0))
		var x := i % w
		var y := i / w
		x0 = mini(x0, x)
		y0 = mini(y0, y)
		x1 = maxi(x1, x)
		y1 = maxi(y1, y)
	if x1 < 0:
		return {}
	var full := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)
	var box := Rect2i(x0 - PAD, y0 - PAD, x1 - x0 + 1 + 2 * PAD, y1 - y0 + 1 + 2 * PAD)
	var trimmed := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	trimmed.blit_rect(full, box.intersection(Rect2i(0, 0, w, h)), (box.intersection(Rect2i(0, 0, w, h)).position - box.position))
	if not is_equal_approx(scale, 1.0):
		trimmed.resize(maxi(1, int(round(box.size.x * scale))), maxi(1, int(round(box.size.y * scale))), Image.INTERPOLATE_LANCZOS)
	return {"image": _unpremultiply(trimmed), "origin": rect.position + box.position}


static func _flood(stack: PackedInt32Array, bg: PackedByteArray, dist: PackedFloat32Array, tol: float, w: int, h: int) -> void:
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if bg[i] == 1 or dist[i] > tol:
			continue
		bg[i] = 1
		var x := i % w
		if x > 0:
			stack.append(i - 1)
		if x < w - 1:
			stack.append(i + 1)
		if i >= w:
			stack.append(i - w)
		if i < (h - 1) * w:
			stack.append(i + w)


## 1 for the pixels of the kept piece (4-connected non-background pixels).
static func _pick_piece(bg: PackedByteArray, w: int, h: int, seed: Variant, origin: Vector2i) -> PackedByteArray:
	var n := w * h
	var label := PackedInt32Array()
	label.resize(n)
	var sizes := [0]
	var stack := PackedInt32Array()
	for s in n:
		if bg[s] == 1 or label[s] != 0:
			continue
		var id := sizes.size()
		var count := 0
		stack.append(s)
		label[s] = id
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			count += 1
			var x := i % w
			for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if j >= 0 and j < n and bg[j] == 0 and label[j] == 0:
					label[j] = id
					stack.append(j)
		sizes.append(count)
	var want := 0
	if seed is Array and seed.size() >= 2:
		var sp := Vector2i(int(seed[0]), int(seed[1])) - origin
		var best := INF
		for i in n: # the nearest piece pixel to the seed
			if label[i] == 0:
				continue
			var d := Vector2(i % w, i / w).distance_squared_to(Vector2(sp))
			if d < best:
				best = d
				want = label[i]
	if want == 0:
		var most := 0
		for id in range(1, sizes.size()):
			if sizes[id] > most:
				most = sizes[id]
				want = id
	var keep := PackedByteArray()
	if want == 0:
		return keep
	keep.resize(n)
	for i in n:
		keep[i] = 1 if label[i] == want else 0
	return keep


static func _signed_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## Distance from p to the nearest edge of a convex polygon, positive inside, negative outside.
static func _inside_distance(poly: PackedVector2Array, p: Vector2, ccw: bool) -> float:
	var d := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := (b - a).normalized()
		var normal := Vector2(-e.y, e.x) if ccw else Vector2(e.y, -e.x) # points inside
		d = minf(d, (p - a).dot(normal))
	return d


static func _unpremultiply(img: Image) -> Image:
	var data := img.get_data()
	for o in range(0, data.size(), 4):
		var a := data[o + 3]
		if a == 0:
			data[o] = 0
			data[o + 1] = 0
			data[o + 2] = 0
			continue
		for c in 3:
			data[o + c] = mini(255, int(round(data[o + c] * 255.0 / a)))
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


func _save(img: Image, path: String, origin: Vector2i) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if not FileAccess.file_exists(abs_path + ".import"):
		var f := FileAccess.open(abs_path + ".import", FileAccess.WRITE)
		f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=false\n')
		f.close()
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("cut_sheet: cannot write %s (%s)" % [path, error_string(err)])
		return
	var bytes := FileAccess.get_file_as_bytes(abs_path).size()
	_written += 1
	_bytes += bytes
	print("  %s  %dx%d  %.1f KB  from sheet %d,%d" % [path, img.get_width(), img.get_height(), bytes / 1024.0, origin.x, origin.y])
