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
## shows through), "pad" px of transparent border kept round it (default 2).
##
## Per part: the white background is flood-filled from the rect's border (near-white pixels,
## `tolerance`), so enclosed whites (eyes, teeth, highlights) stay; only the piece under the
## seed is kept (no bits of neighbours); the edge pixels get their alpha from how far they are
## from white and their colour un-blended from white (no white halo, the anti-aliased outline
## stays soft); then the clip, a trim to the visible pixels (+2 px), the scale (Lanczos on
## premultiplied colour, once, from the full-resolution cut) and the PNG. A new PNG gets an
## .import without mipmaps (the parts are drawn at their own size); an existing .import is never
## touched.
##
## Lineup mode (`-- lineup [<id> ...]`, also run by default): art_source/characters/
## lineup_parts.json cuts one coherent full-body picture per character out of a lineup image
## (all the characters side by side on white) into assets/characters/<id>/lobby/full.png +
## full.json (the screens outside the match draw it, skinned on a skeleton, instead of the rig:
## scenes/character/full_body.gd, assets/README.md). lineup_parts.json: {"sheet", "tolerance",
## "pad" (transparent px kept round the figure), "drawScale" (full.png px → character px, 0.64 =
## 1:1 on the lobby stage), "figures": {id: a part as above (rect, seed, holes, clip, feather) +
## "scale" (full.png px per sheet px), "joints" {name: [x, y] sheet px, see SKELETON},
## optional "strength" {bone: k} and "anims" (merged over the shared
## assets/characters/lobby_full_anims.json)}}. full.json: {size, pivot (the feet: the middle of
## the boots' outer edges, the soles' bottom; px in full.png), height (feet to the top of the
## head, px), scale (= drawScale), bones [{name, parent, at (the joint), tip (the end of its
## segment), strength}] in full.png px, anims, mesh {vertices (px in full.png = uv), triangles
## (3 indices each)}, weights (per vertex: bone index, weight, ...)} (tools/full_mesh.gd).

const FullMesh := preload("res://tools/full_mesh.gd")
const SRC := "res://art_source/characters/"
const OUT := "res://assets/characters/"
const PAD := 2
## Edge pixels whose distance from white is above this are fully opaque.
const EDGE_FULL := 0.85

var _written := 0
var _bytes := 0


func _initialize() -> void:
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.has("lineup"): # only the lineup (figure ids after it pick some)
		_cut_lineup(SRC + "lineup_parts.json")
		_done()
		return
	if ids.is_empty():
		ids = Array(DirAccess.get_directories_at(SRC))
		_cut_lineup(SRC + "lineup_parts.json")
	for id in ids:
		for f in DirAccess.get_files_at(SRC + str(id)):
			if f.ends_with("parts.json"):
				_cut_character(str(id), SRC + str(id) + "/" + f)
	_done()


func _done() -> void:
	print("cut_sheet: wrote %d pictures, %.1f KB" % [_written, _bytes / 1024.0])
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


func _cut_lineup(spec_path: String) -> void:
	var spec = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	if not spec is Dictionary:
		push_error("cut_sheet: %s missing or not a JSON object" % spec_path)
		return
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SRC + str(spec["sheet"])))
	if sheet == null:
		push_error("cut_sheet: cannot read " + str(spec["sheet"]))
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var tol := float(spec.get("tolerance", 0.1))
	print("lineup: %s %dx%d" % [spec["sheet"], sheet.get_width(), sheet.get_height()])
	var figures: Dictionary = spec["figures"]
	var only: Array = Array(OS.get_cmdline_user_args()).filter(func(a): return figures.has(a))
	for id in figures:
		if not only.is_empty() and not only.has(id):
			continue
		var p: Dictionary = figures[id].duplicate()
		p["pad"] = int(spec.get("pad", PAD))
		var cut := cut_part(sheet, p, tol, float(p.get("scale", 1.0)))
		if cut.is_empty():
			push_error("cut_sheet: lineup figure %s is empty" % id)
			continue
		var img: Image = cut["image"]
		var out := OUT + "%s/lobby/full" % id
		_save(img, out + ".png", cut["origin"])
		var feet := feet_of(img)
		# Sheet px → full.png px.
		var k := Vector2(img.get_size()) / Vector2(cut["box"])
		var origin: Vector2 = Vector2(cut["origin"])
		var joints := {"feet": feet["pivot"]}
		for j in p.get("joints", {}):
			var q: Array = p["joints"][j]
			joints[j] = ((Vector2(float(q[0]), float(q[1])) - origin) * k).round()
		var bones: Array = []
		for b in SKELETON:
			if not joints.has(b[2]) or not joints.has(b[3]):
				push_error("cut_sheet: %s needs the joints %s and %s" % [id, b[2], b[3]])
				return
			var strength := float(p.get("strength", {}).get(b[0], STRENGTH.get(b[0], 1.0)))
			bones.append({"name": b[0], "parent": b[1], "at": joints[b[2]], "tip": joints[b[3]], "strength": strength})
		var t0 := Time.get_ticks_msec()
		var mesh := FullMesh.build(img)
		var weights := FullMesh.weights(img, mesh["vertices"], bones)
		print("  mesh: %d vertices, %d triangles, %d uncovered px, %.1f s" % [mesh["vertices"].size(), mesh["triangles"].size() / 3, mesh["gaps"], (Time.get_ticks_msec() - t0) / 1000.0])
		_write_full_json(out + ".json", img, feet, bones, mesh, weights, float(spec.get("drawScale", 0.64)),
			"art_source/characters/" + str(spec["sheet"]), p.get("anims", {}))


## The skeleton every lineup figure gets: [bone, parent, joint it turns at, joint its segment
## ends at] (joints: lineup_parts.json `joints`, sheet px; `feet` is the pivot). l / r: the
## arm or leg on the left / right of the picture.
const SKELETON := [
	["root", "", "feet", "hips"],
	["hips", "root", "hips", "chest"],
	["chest", "hips", "chest", "neck"],
	["head", "chest", "neck", "crown"],
	["arm_l_upper", "chest", "l_shoulder", "l_elbow"],
	["arm_l_fore", "arm_l_upper", "l_elbow", "l_wrist"],
	["hand_l", "arm_l_fore", "l_wrist", "l_hand"],
	["arm_r_upper", "chest", "r_shoulder", "r_elbow"],
	["arm_r_fore", "arm_r_upper", "r_elbow", "r_wrist"],
	["hand_r", "arm_r_fore", "r_wrist", "r_hand"],
	["leg_l_thigh", "hips", "l_hip", "l_knee"],
	["leg_l_shin", "leg_l_thigh", "l_knee", "l_ankle"],
	["foot_l", "leg_l_shin", "l_ankle", "l_toe"],
	["leg_r_thigh", "hips", "r_hip", "r_knee"],
	["leg_r_shin", "leg_r_thigh", "r_knee", "r_ankle"],
	["foot_r", "leg_r_shin", "r_ankle", "r_toe"],
]
## How strongly a bone holds the vertices near it (the head and the chest move as one piece;
## the root holds none). lineup_parts.json `strength` overrides per figure.
const STRENGTH := {"root": 0.0, "hips": 1.5, "chest": 2.0, "head": 4.0}


func _write_full_json(path: String, img: Image, feet: Dictionary, bones: Array, mesh: Dictionary, weights: Array,
		draw_scale: float, source: String, anims: Dictionary) -> void:
	var v: Array = []
	for p in mesh["vertices"]:
		v.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
	var wt: Array = []
	for row in weights:
		var flat: Array = []
		for c in row:
			flat.append(c[0])
			flat.append(snappedf(c[1], 0.001))
		wt.append(flat)
	var bone_lines: Array = []
	for b in bones:
		bone_lines.append("\t\t" + JSON.stringify({"name": b["name"], "parent": b["parent"], "at": [b["at"].x, b["at"].y],
			"tip": [b["tip"].x, b["tip"].y], "strength": b["strength"]}))
	var lines: Array = [
		"{",
		'\t"_doc": "Generated by tools/cut_sheet.gd (lineup mode) from art_source/characters/lineup_parts.json: edit that and re-cut. Drawn by scenes/character/full_body.gd, see assets/README.md.",',
		'\t"source": %s,' % JSON.stringify(source),
		'\t"size": [%d, %d],' % [img.get_width(), img.get_height()],
		'\t"pivot": [%d, %d],' % [feet["pivot"].x, feet["pivot"].y],
		'\t"height": %d,' % feet["height"],
		'\t"scale": %s,' % JSON.stringify(draw_scale),
		'\t"bones": [\n%s\n\t],' % ",\n".join(bone_lines),
		'\t"anims": %s,' % JSON.stringify(anims),
		'\t"mesh": {"vertices": %s,\n\t\t"triangles": %s},' % [JSON.stringify(v), JSON.stringify(Array(mesh["triangles"]))],
		'\t"weights": %s' % JSON.stringify(wt),
		"}",
	]
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("  %s  pivot %s, height %d px, %.1f KB" % [path, feet["pivot"], feet["height"], FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(path)).size() / 1024.0])


## The feet of a full-body picture: {pivot (Vector2: x the middle of the outer edges of the
## lowest tenth (the boots), y the bottom of the soles), height (px from the soles to the top)},
## from the pixels at least half opaque.
static func feet_of(img: Image) -> Dictionary:
	var top := -1
	var bottom := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.5:
				if top < 0:
					top = y
				bottom = y
				break
	if top < 0:
		return {"pivot": Vector2.ZERO, "height": 0}
	var band := maxi(1, int((bottom - top) * 0.1))
	var x0 := img.get_width()
	var x1 := -1
	for y in range(bottom - band, bottom + 1):
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.5:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
	return {"pivot": Vector2(round((x0 + x1 + 1) / 2.0), bottom + 1), "height": bottom + 1 - top}


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
	var pad := int(p.get("pad", PAD))
	var box := Rect2i(x0 - pad, y0 - pad, x1 - x0 + 1 + 2 * pad, y1 - y0 + 1 + 2 * pad)
	var trimmed := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	trimmed.blit_rect(full, box.intersection(Rect2i(0, 0, w, h)), (box.intersection(Rect2i(0, 0, w, h)).position - box.position))
	if not is_equal_approx(scale, 1.0):
		trimmed.resize(maxi(1, int(round(box.size.x * scale))), maxi(1, int(round(box.size.y * scale))), Image.INTERPOLATE_LANCZOS)
	return {"image": _unpremultiply(trimmed), "origin": rect.position + box.position, "box": box.size}


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
