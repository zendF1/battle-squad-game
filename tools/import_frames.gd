extends SceneTree
## Imports hand-made (AI-made) side-view frames of a character into the match art: one JSON
## config per set, art_source/characters/<id>/side_*/import.json, next to its source frames
## (any size, transparent background, facing right). Reproducible: everything it does is in the
## config. Runs headless (only Image is used):
##
##   $GODOT --headless --path . -s tools/import_frames.gd [-- <config.json> ...]
##
## (default: every art_source/characters/*/side*/import.json). It writes the config's `out`
## folder (assets/characters/<id>/side/): <anim>_<i>.png, hand.png, side.json and
## gun_anchors.json (formats in assets/README.md, read by ui/art.gd side_view()). A new PNG gets
## an .import without mipmaps; an existing .import is never touched. Let the editor import them.
##
## Per source frame:
##   1. clean: alpha below `alphaCut` is cleared; only the big connected pieces stay (8-connected,
##      at least `keepPieces` × the largest), so the stray pixels near the canvas edges go;
##      defringe: in the `band` px next to the transparency, light grey pixels (the white halo of
##      the removed background round the black outline, chroma ≤ `maxChroma`) get the outline
##      colour and an alpha from how light they are, so the edge is dark and soft.
##   2. measure: the top and the lowest pixel row (the soles: the ground contact), and the
##      column profile of the rows `stabilise.rows` (0 = top, 1 = soles: head, backpack and torso).
## Then:
##   3. stabilise: every frame is shifted so its soles touch the same row as frame 0 and its
##      torso profile best matches frame 0's (least absolute difference, ±`stabilise.search` px):
##      the cycle runs in place, the body does not jitter left / right.
##   4. pivot: the feet point = the median of the frames' hip centres (middle of the rows
##      `hipRows`), on the soles' row; the same pixel in every frame.
##   5. crop: one canvas round all the shifted frames (+`pad` px), the pivot at the same place.
##   6. scale once (Lanczos, premultiplied colour) so the figure is `height` world px tall ×
##      `oversample` texture px per world px; pxPerUnit = worldPxPerUnit × oversample.
## Animations (`anims`): `frames` are source frame indices (written as <anim>_<i>.png) or "idle"
## (reuse idle's PNGs, `count` entries: the code motion makes them move); fps, loop, motion
## (scenes/character/character.gd: breathe, recoil, knockback, fall). Gun anchors: the grip
## follows the near fist (`gun.fists`, source px per frame) by `follow` from a carry point
## (`gun.carry`, source px from the pivot) and, in an anim with `swing`, tilts by up to
## `swingDeg` with the arm (forward = muzzle up); shoot /
## hurt angles and the shoot flash per frame from the anim; `front` false behind the body.

const CutSheet := preload("res://tools/cut_sheet.gd")
const SRC := "res://art_source/characters/"

var _written := 0
var _bytes := 0


func _initialize() -> void:
	var configs: Array = Array(OS.get_cmdline_user_args()).filter(func(a): return str(a).ends_with(".json"))
	if configs.is_empty():
		configs = _find_configs()
	for c in configs:
		_import(str(c))
	print("import_frames: wrote %d files, %.1f KB" % [_written, _bytes / 1024.0])
	quit()


func _find_configs() -> Array:
	var out: Array = []
	for id in DirAccess.get_directories_at(SRC):
		for sub in DirAccess.get_directories_at(SRC + id):
			if sub.begins_with("side") and FileAccess.file_exists(SRC + "%s/%s/import.json" % [id, sub]):
				out.append(SRC + "%s/%s/import.json" % [id, sub])
	return out


func _import(cfg_path: String) -> void:
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
	if not cfg is Dictionary:
		push_error("import_frames: %s missing or not a JSON object" % cfg_path)
		return
	var dir := cfg_path.get_base_dir() + "/"
	var out_dir := str(cfg["out"])
	print("%s → %s" % [cfg_path, out_dir])
	# 1–2. Clean and measure every source frame.
	var frames: Array = [] # {image, top, bottom, profile, hip}
	for f in cfg["frames"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path(dir + str(f)))
		if img == null or img.is_empty():
			push_error("import_frames: cannot read " + dir + str(f))
			return
		img.convert(Image.FORMAT_RGBA8)
		var removed := clean(img, cfg)
		var m := measure(img, cfg)
		if m.is_empty():
			push_error("import_frames: %s is empty after cleaning" % f)
			return
		m["image"] = img
		frames.append(m)
		print("  %s %dx%d: removed %d stray px, figure rows %d..%d" % [f, img.get_width(), img.get_height(), removed, m["top"], m["bottom"]])
	# 3. Stabilise against frame 0: soles on one row, torso profiles matched.
	var search := int(cfg.get("stabilise", {}).get("search", 40))
	var ref: Dictionary = frames[0]
	for fr in frames:
		var oy: int = int(ref["bottom"]) - int(fr["bottom"])
		var ox := best_shift(ref["profile"], fr["profile"], search)
		fr["offset"] = Vector2i(ox, oy)
	# 4. Pivot: the median hip centre (shifted), on the soles' row.
	var hips: Array = []
	for fr in frames:
		hips.append(float(fr["hip"]) + fr["offset"].x)
	hips.sort()
	var pivot := Vector2(hips[hips.size() / 2], float(ref["bottom"]) + 1.0)
	# 5. One canvas round every shifted frame.
	var union := Rect2i()
	for fr in frames:
		var r: Rect2i = fr["rect"]
		r.position += fr["offset"]
		union = r if union.size == Vector2i.ZERO else union.merge(r)
	var fig_h := float(ref["bottom"]) + 1.0 - float(ref["top"])
	var oversample := float(cfg.get("oversample", 2.0))
	var s := float(cfg["height"]) * oversample / fig_h
	var pad_src := int(ceil(float(cfg.get("pad", 2)) / s))
	var origin := union.position - Vector2i(pad_src, pad_src)
	var src_size := union.size + Vector2i(2 * pad_src, 2 * pad_src)
	var out_size := Vector2i(int(ceil(src_size.x * s)), int(ceil(src_size.y * s)))
	src_size = Vector2i(int(round(out_size.x / s)), int(round(out_size.y / s)))
	var k := Vector2(float(out_size.x) / src_size.x, float(out_size.y) / src_size.y) # out px per source px
	var to_out := func(p: Vector2) -> Vector2: return (p - Vector2(origin)) * k
	var pivot_out: Vector2 = to_out.call(pivot)
	print("  stabilised: offsets %s; pivot %s source → %s px; canvas %s (from %s source px, ×%.4f)" % [
		str(frames.map(func(fr): return fr["offset"])), pivot, pivot_out.snapped(Vector2(0.01, 0.01)), out_size, src_size, s])
	# 6. Scale each used frame once.
	var outs := {} # source index -> Image
	var anims: Dictionary = cfg["anims"]
	for anim in anims:
		var fs = anims[anim]["frames"]
		if fs is Array:
			for i in fs:
				if not outs.has(int(i)):
					outs[int(i)] = _scaled(frames[int(i)], origin, src_size, out_size)
	var used := Rect2i()
	for i in outs:
		var r: Rect2i = outs[i].get_used_rect()
		used = r if used.size == Vector2i.ZERO else used.merge(r)
	# Gun anchors: the grip follows the near fist from the carry point, tilting with the swing.
	var gun: Dictionary = cfg.get("gun", {})
	var carry := pivot + _v(gun.get("carry", [0, -fig_h * 0.33]))
	var follow := float(gun.get("follow", 0.35))
	var fists: Array = []
	for i in frames.size():
		var fist: Variant = gun.get("fists", [])[i] if i < gun.get("fists", []).size() else null
		fists.append(_v(fist) + Vector2(frames[i]["offset"]) if fist != null else carry)
	var fx_min := INF
	var fx_max := -INF
	for f in fists:
		fx_min = minf(fx_min, f.x)
		fx_max = maxf(fx_max, f.x)
	var fx_mid := (fx_min + fx_max) * 0.5
	var fx_half := maxf(1.0, (fx_max - fx_min) * 0.5)
	var hold := func(i: int, swing: bool) -> Dictionary:
		var f: Vector2 = fists[i]
		var grip: Vector2 = to_out.call(carry + (f - carry) * follow)
		var tilt := -float(gun.get("swingDeg", 0.0)) * (f.x - fx_mid) / fx_half if swing else 0.0
		return {"grip": [snappedf(grip.x, 0.01), snappedf(grip.y, 0.01)], "angle": snappedf(tilt, 0.01), "front": true, "flash": 0.0}
	# Write the frames and the description.
	var side_anims := {}
	var anchors := {}
	var idle_src: int = int(anims["idle"]["frames"][0])
	for anim in anims:
		var spec: Dictionary = anims[anim]
		var stems: Array = []
		var holds: Array = []
		if spec["frames"] is Array:
			for j in spec["frames"].size():
				var si := int(spec["frames"][j])
				var stem := "%s_%d" % [anim, j]
				_save(outs[si], out_dir + stem + ".png")
				stems.append(stem)
				holds.append(hold.call(si, bool(spec.get("swing", false))))
		else: # reuse idle's PNGs
			for j in int(spec.get("count", 1)):
				stems.append("idle_0")
				holds.append(hold.call(idle_src, false))
		for j in holds.size():
			var a: Dictionary = holds[j]
			if spec.has("angle"):
				a["angle"] = snappedf(float(a["angle"]) + float(spec["angle"][mini(j, spec["angle"].size() - 1)]), 0.01)
			if spec.has("flash"):
				a["flash"] = float(spec["flash"][mini(j, spec["flash"].size() - 1)])
			a["front"] = bool(spec.get("front", true))
		side_anims[anim] = {"frames": stems, "fps": float(spec.get("fps", 8)), "loop": bool(spec.get("loop", false)), "motion": str(spec.get("motion", ""))}
		anchors[anim] = holds
	var side := {
		"size": [out_size.x, out_size.y],
		"pivot": [snappedf(pivot_out.x, 0.01), snappedf(pivot_out.y, 0.01)],
		"pxPerUnit": snappedf(float(cfg.get("worldPxPerUnit", 0.35)) * oversample, 0.0001),
		"height": snappedf(fig_h * k.y, 0.01),
		"extent": {"back": snappedf(pivot_out.x - used.position.x, 0.01), "front": snappedf(used.end.x - pivot_out.x, 0.01),
			"top": snappedf(pivot_out.y - used.position.y, 0.01)},
		"anims": side_anims,
	}
	var hand: Dictionary = cfg.get("hand", {})
	if not hand.is_empty():
		_save(_cut_hand(frames[int(hand["frame"])]["image"], _v(hand["center"]), float(hand["radius"]), float(hand.get("feather", 2.0)), s), out_dir + "hand.png")
		side["hand"] = "hand.png"
	_write_text(out_dir + "side.json", JSON.stringify(side, "\t", false) + "\n")
	_write_text(out_dir + "gun_anchors.json", JSON.stringify({"frameSize": side["size"], "pivot": side["pivot"], "anims": anchors}, "\t", false) + "\n")
	_report_feet(anims, outs, pivot_out, oversample)


## Clears the stray pixels and the white fringe in place; returns how many pixels it cleared.
static func clean(img: Image, cfg: Dictionary) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var n := w * h
	var px := img.get_data()
	var cut := int(cfg.get("alphaCut", 128))
	var removed := 0
	for i in n:
		if px[i * 4 + 3] < cut and px[i * 4 + 3] > 0:
			px[i * 4 + 3] = 0
			removed += 1
	# Connected pieces (8-connected); keep the ones at least keepPieces × the largest.
	var label := PackedInt32Array()
	label.resize(n)
	var sizes := PackedInt32Array([0])
	var stack := PackedInt32Array()
	for s in n:
		if px[s * 4 + 3] == 0 or label[s] != 0:
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
			var y := i / w
			for dy in range(-1, 2):
				var yy := y + dy
				if yy < 0 or yy >= h:
					continue
				for dx in range(-1, 2):
					var xx := x + dx
					if xx < 0 or xx >= w:
						continue
					var j := yy * w + xx
					if label[j] == 0 and px[j * 4 + 3] != 0:
						label[j] = id
						stack.append(j)
		sizes.append(count)
	var largest := 0
	for id in range(1, sizes.size()):
		largest = maxi(largest, sizes[id])
	var min_keep := float(cfg.get("keepPieces", 0.02)) * largest
	for i in n:
		if label[i] != 0 and sizes[label[i]] < min_keep:
			px[i * 4 + 3] = 0
			removed += 1
	# Defringe: distance (4-steps) from the transparency, up to `band`.
	var df: Dictionary = cfg.get("defringe", {})
	var band := int(df.get("band", 2))
	if band > 0:
		var dist := PackedByteArray()
		dist.resize(n)
		dist.fill(255)
		var front := PackedInt32Array()
		for i in n:
			if px[i * 4 + 3] == 0:
				continue
			var x := i % w
			var y := i / w
			if (x > 0 and px[(i - 1) * 4 + 3] == 0) or (x < w - 1 and px[(i + 1) * 4 + 3] == 0) \
					or (y > 0 and px[(i - w) * 4 + 3] == 0) or (y < h - 1 and px[(i + w) * 4 + 3] == 0) \
					or x == 0 or y == 0 or x == w - 1 or y == h - 1:
				dist[i] = 1
				front.append(i)
		for d in range(2, band + 1):
			var next := PackedInt32Array()
			for i in front:
				var x := i % w
				for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
					if j >= 0 and j < n and px[j * 4 + 3] != 0 and dist[j] == 255:
						dist[j] = d
						next.append(j)
			front = next
		var oc: Array = df.get("outline", [24, 22, 30])
		var out_l := (float(oc[0]) + float(oc[1]) + float(oc[2])) / 3.0
		var max_chroma := int(df.get("maxChroma", 56))
		for i in n:
			if dist[i] == 255:
				continue
			var o := i * 4
			var r := px[o]
			var g := px[o + 1]
			var b := px[o + 2]
			var l := (r + g + b) / 3.0
			if l <= out_l or maxi(r, maxi(g, b)) - mini(r, mini(g, b)) > max_chroma:
				continue
			var a := clampf((255.0 - l) / (255.0 - out_l), 0.0, 1.0)
			px[o] = int(oc[0])
			px[o + 1] = int(oc[1])
			px[o + 2] = int(oc[2])
			px[o + 3] = int(round(px[o + 3] * a))
	img.set_data(w, h, false, Image.FORMAT_RGBA8, px)
	return removed


## {rect (opaque bbox), top, bottom (lowest opaque row), profile (opaque px per column in the
## stabilise rows), hip (the middle of the hip rows' spans, x)}; {} when empty.
static func measure(img: Image, cfg: Dictionary) -> Dictionary:
	var rect := img.get_used_rect()
	if rect.size == Vector2i.ZERO:
		return {}
	var w := img.get_width()
	var px := img.get_data()
	var top := rect.position.y
	var bottom := rect.end.y - 1
	var hgt := float(bottom - top)
	var rows: Array = cfg.get("stabilise", {}).get("rows", [0.0, 0.62])
	var profile := PackedInt32Array()
	profile.resize(w)
	for y in range(top + int(hgt * float(rows[0])), top + int(hgt * float(rows[1])) + 1):
		for x in range(rect.position.x, rect.end.x):
			if px[(y * w + x) * 4 + 3] > 127:
				profile[x] += 1
	var hr: Array = cfg.get("hipRows", [0.74, 0.8])
	var hip := 0.0
	var count := 0
	for y in range(top + int(hgt * float(hr[0])), top + int(hgt * float(hr[1])) + 1):
		var x0 := -1
		var x1 := -1
		for x in range(rect.position.x, rect.end.x):
			if px[(y * w + x) * 4 + 3] > 127:
				if x0 < 0:
					x0 = x
				x1 = x
		if x0 >= 0:
			hip += (x0 + x1 + 1) * 0.5
			count += 1
	return {"rect": rect, "top": top, "bottom": bottom, "profile": profile, "hip": hip / maxi(1, count)}


## The shift o (px) for which b(x - o) best matches a(x): least sum of absolute differences.
static func best_shift(a: PackedInt32Array, b: PackedInt32Array, search: int) -> int:
	var best := 0
	var best_cost := 1 << 62
	var w := a.size()
	for o in range(-search, search + 1):
		var cost := 0
		for x in w:
			var bx := x - o
			var bv := b[bx] if bx >= 0 and bx < w else 0
			cost += absi(a[x] - bv)
		if cost < best_cost or (cost == best_cost and absi(o) < absi(best)):
			best_cost = cost
			best = o
	return best


## A frame shifted by its offset into the shared canvas, then scaled once (Lanczos on
## premultiplied colour).
static func _scaled(fr: Dictionary, origin: Vector2i, src_size: Vector2i, out_size: Vector2i) -> Image:
	var src: Image = fr["image"]
	var canvas := Image.create(src_size.x, src_size.y, false, Image.FORMAT_RGBA8)
	var from := Rect2i(origin - Vector2i(fr["offset"]), src_size)
	var clip := from.intersection(Rect2i(Vector2i.ZERO, src.get_size()))
	canvas.blit_rect(src, clip, clip.position - from.position)
	canvas.premultiply_alpha()
	canvas.resize(out_size.x, out_size.y, Image.INTERPOLATE_LANCZOS)
	var out := CutSheet._unpremultiply(canvas)
	_clear_faint(out)
	return out


## Lanczos rings: clears the near-invisible alpha it leaves round the figure.
static func _clear_faint(img: Image) -> void:
	var data := img.get_data()
	for o in range(0, data.size(), 4):
		if data[o + 3] < 4:
			data[o] = 0
			data[o + 1] = 0
			data[o + 2] = 0
			data[o + 3] = 0
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


## A round cut (radius px, soft edge) of the cleaned frame centred on `center`, scaled by s.
static func _cut_hand(src: Image, center: Vector2, radius: float, feather: float, s: float) -> Image:
	var r := int(ceil(radius + feather))
	var size := 2 * r + 1
	var cut := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2i(int(round(center.x)), int(round(center.y)))
	var from := Rect2i(c - Vector2i(r, r), Vector2i(size, size))
	var clip := from.intersection(Rect2i(Vector2i.ZERO, src.get_size()))
	cut.blit_rect(src, clip, clip.position - from.position)
	for y in size:
		for x in size:
			var col := cut.get_pixel(x, y)
			var d := Vector2(x - r, y - r).length()
			col.a *= clampf((radius - d) / feather + 0.5, 0.0, 1.0)
			cut.set_pixel(x, y, col)
	cut.premultiply_alpha()
	var o := maxi(1, int(round(size * s)))
	cut.resize(o, o, Image.INTERPOLATE_LANCZOS)
	var out := CutSheet._unpremultiply(cut)
	_clear_faint(out)
	return out


## Prints where the soles touch the ground per walk frame (px from the pivot, world px) to tune
## the walk fps against the walk speed: a planted foot should move back by speed / fps per frame.
func _report_feet(anims: Dictionary, outs: Dictionary, pivot: Vector2, oversample: float) -> void:
	if not anims.has("walk") or not anims["walk"]["frames"] is Array:
		return
	var line := "  walk soles (world px from the pivot, the 3 rows over the pivot):"
	for si in anims["walk"]["frames"]:
		var img: Image = outs[int(si)]
		var y1 := int(round(pivot.y))
		var x0 := INF
		var x1 := -INF
		for y in range(y1 - 3, y1):
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.25:
					x0 = minf(x0, x)
					x1 = maxf(x1, x)
		line += " [%.1f, %.1f]" % [(x0 - pivot.x) / oversample, (x1 + 1 - pivot.x) / oversample]
	print(line)


static func _v(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and a.size() >= 2 else Vector2.ZERO


func _save(img: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if not FileAccess.file_exists(abs_path + ".import"):
		var f := FileAccess.open(abs_path + ".import", FileAccess.WRITE)
		f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=false\n')
		f.close()
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("import_frames: cannot write %s (%s)" % [path, error_string(err)])
		return
	var bytes := FileAccess.get_file_as_bytes(abs_path).size()
	_written += 1
	_bytes += bytes
	print("  %s  %dx%d  %.1f KB" % [path, img.get_width(), img.get_height(), bytes / 1024.0])


func _write_text(path: String, text: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	_written += 1
	_bytes += text.length()
	print("  %s  %.1f KB" % [path, text.length() / 1024.0])
