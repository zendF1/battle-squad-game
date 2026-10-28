extends SceneTree
## Imports the AI-drawn rank art (cấp bậc): per grade a card frame (khung: round the player card on
## the lobby party slots and the Matchmaking / VS cards) and a badge (huy hiệu: next to the name in
## the match and on the result screens). Prompts: art_source/ranks/PROMPTS.md. Reproducible:
## everything it does is in art_source/ranks/ranks.json. Runs headless (only Image is used; the
## editor may stay open):
##
##   $GODOT --headless --path . -s tools/import_rank_art.gd [-- <grade> ...] [--debug=<dir>]
##
## Sources: art_source/ranks/frames/frame_<grade>.png and badges/badge_<grade>.png on a flat
## magenta backdrop (any canvas size), or the cells of a sheet ("sheets": equal cells, row-major;
## a single file wins over its cell). A grade without a picture is skipped (the game keeps its
## code-drawn placeholder).
##
## Every picture, in source px: the ✦ watermarks listed in "files" are rebuilt from the px round
## them (tools/import_titles.gd remove_watermark(): a ✦ over the art); the backdrop keyed out
## (tools/import_frames.gd key_background(): the corners' colour, soft edge, despilled rim, the
## enclosed pockets of backdrop (the frame's opening, between laurel leaves) keyed as holes, an
## optional painted glow un-mixed: "glow" per group); then islands(): opaque specks smaller than
## `minIsland` px are dropped, and a small separate piece inside the bottom-right `watermarkBox`
## (the generator's ✦ on the backdrop) is dropped and reported.
##
## Frames are registered by their opening, never trimmed (every grade's opening lands on the same
## texture rect, so the client stretches any frame round a card the same way): window_of() measures
## the opening's inner edges from the middle outwards on the `measureX` columns (top / bottom
## edges) and `measureY` rows (left / right edges), the plain band runs clear of the seat and the
## bottom emblem (median of the hits; a picture whose middle is not transparent needs "window" in
## "files", plus "forceWindow"); the picture is mapped so that opening covers frame.window of the
## `size` canvas (one Lanczos resample on premultiplied colour, tools/import_guns.gd scaled(); x and
## y scales may differ a little: warned above 6 %), ornaments falling off the canvas are counted
## and warned. Then "mirror" (optional), "forceWindow" (optional: the opening cleared, rounded by
## `windowRadius`), and the checks: opaque px inside the opening's core (something drawn in the
## card's place), the upscale (a source whose opening is narrower than the shipped one), and the
## stretch runs' uniformity (stretch_error(): each column of a stretchX run / row of a stretchY run
## against the run's middle one; above `stretchTolerance` the art has ornaments where a taller or
## wider card stretches it).
##
## Badges are trimmed to their content and fitted: the longer side fills `fill`[group] of size −
## 2 × margin (the silhouette grows with the group), centred, one Lanczos resample.
##
## Writes assets/ranks/frame_<grade>.png, badge_<grade>.png (the paths ui/art.gd rank_frame_path() /
## rank_badge_path() read; a new PNG gets an .import with lossless compression and mipmaps, an
## existing .import is never touched: let the editor import them; until then ui/art.gd reads the
## PNG) and assets/ranks/ranks.json: the frame layout in texture px (size, window, seat, stretchX,
## stretchY) and the grades that have a frame / a badge.
## --debug=<dir> also writes per picture <name>_preview.png (on a dark and a light page with a mock
## card in the opening; frames also sliced to the party slot's and the VS card's proportions with
## the stretch runs, the way sliced() does it), <name>_corner.png (the source's bottom-right
## box after the import: check no ✦ is left), and ladder_frames.png / ladder_badges.png (every
## imported grade in order, badges at 24, 48 and 96 px on dark and light: the visual ladder).

const ImportFrames := preload("res://tools/import_frames.gd")
const ImportGuns := preload("res://tools/import_guns.gd")
const ImportTitles := preload("res://tools/import_titles.gd")
const SRC := "res://art_source/ranks/"
const CONFIG := SRC + "ranks.json"
const OUT := "res://assets/ranks/"
## The card proportions the debug previews slice a frame to (screens/home/party_slot.gd SIZE,
## screens/ranked/player_card.gd SIZE).
const PREVIEW_CARDS := [Vector2(330, 500), Vector2(268, 520)]
const DARK := Color(0.07, 0.09, 0.16)
const LIGHT := Color(0.86, 0.89, 0.93)
const CARD := Color(0.16, 0.27, 0.5)

var _failed := false
var _bytes := 0
var _written := 0


func _initialize() -> void:
	var debug := ""
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--debug="):
			debug = a.trim_prefix("--debug=")
		elif not a.begins_with("--"):
			only.append(a)
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if not cfg is Dictionary or not cfg.get("groups") is Dictionary:
		push_error("import_rank_art: %s is not a valid config" % CONFIG)
		quit(1)
		return
	var grades := grades_of(cfg)
	for g in only:
		if not g in grades:
			push_error("import_rank_art: unknown grade %s (ranks.json groups)" % g)
			quit(1)
			return
	if debug != "":
		DirAccess.make_dir_recursive_absolute(debug)
	var pics := sources(cfg)
	for g in grades:
		if not only.is_empty() and not g in only:
			continue
		for kind in ["frame", "badge"]:
			var name: String = "%s_%s" % [kind, g]
			if not pics.has(name):
				print("  %s: no picture, the placeholder stays" % name)
				continue
			var opts: Dictionary = cfg["files"].get(name, {}) if cfg.get("files") is Dictionary else {}
			var res := frame(pics[name]["image"], cfg, group_of(cfg, g), opts) if kind == "frame" else badge(pics[name]["image"], cfg, group_of(cfg, g), opts)
			print("  %s (%s %dx%d)" % [name, pics[name]["from"], pics[name]["image"].get_width(), pics[name]["image"].get_height()])
			for line in res["notes"]:
				print("      " + line)
			for line in res["warnings"]:
				push_warning("import_rank_art: %s: %s" % [name, line])
				print("      WARNING " + line)
			if res["image"] == null:
				_failed = true
				continue
			_save(res["image"], OUT + name + ".png")
			if debug != "":
				_debug_picture(debug, name, kind, res, cfg)
	_write_layout(cfg, grades)
	if debug != "":
		_ladders(debug, cfg, grades)
	print("import_rank_art: %d PNG, %.1f KB" % [_written, _bytes / 1024.0])
	quit(1 if _failed else 0)


## Every grade id, lowest first (the groups' lists in order).
static func grades_of(cfg: Dictionary) -> Array:
	var out := []
	for group in cfg["groups"]:
		for g in cfg["groups"][group]:
			out.append(str(g))
	return out


static func group_of(cfg: Dictionary, grade: String) -> String:
	for group in cfg["groups"]:
		if grade in cfg["groups"][group]:
			return group
	return ""


## {frame_<grade> | badge_<grade>: {image, from}}: the sheets' cells, then the single files over them.
static func sources(cfg: Dictionary) -> Dictionary:
	var out := {}
	for s in cfg.get("sheets", []):
		var path: String = SRC + str(s["file"])
		var img := Image.load_from_file(ProjectSettings.globalize_path(path)) if FileAccess.file_exists(path) else null
		if img == null or img.is_empty():
			print("  %s: no sheet" % path)
			continue
		var cols := int(s.get("cols", 1))
		var rows := int(s.get("rows", 1))
		var cw := img.get_width() / cols
		var ch := img.get_height() / rows
		var list: Array = s.get("grades", [])
		for i in mini(list.size(), cols * rows):
			if str(list[i]) == "":
				continue
			var cell := img.get_region(Rect2i((i % cols) * cw, (i / cols) * ch, cw, ch))
			out["%s_%s" % [s.get("kind", "frame"), list[i]]] = {"image": cell, "from": "%s cell %d" % [s["file"], i + 1]}
	for g in grades_of(cfg):
		for kind in ["frame", "badge"]:
			var path: String = SRC + "%ss/%s_%s.png" % [kind, kind, g]
			if not FileAccess.file_exists(path):
				continue
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img == null or img.is_empty():
				push_error("import_rank_art: cannot read %s" % path)
				continue
			out["%s_%s" % [kind, g]] = {"image": img, "from": path.trim_prefix(SRC)}
	return out


## The backdrop keyed out and cleaned (see the header), in source px: {image, notes, warnings}.
static func cleaned(src: Image, kc: Dictionary, glow: Variant, opts: Dictionary) -> Dictionary:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var notes := []
	var warnings := []
	var key := ImportFrames.corner_colour(img, int(kc["background"].get("corner", 8)))
	for wm in opts.get("watermarks", []):
		ImportTitles.remove_watermark(img, Vector2(wm["centre"][0], wm["centre"][1]), float(wm["size"][0]), float(wm["size"][1]), float(wm.get("grow", 3.0)), key)
		notes.append("watermark rebuilt at %s" % [wm["centre"]])
	if minf(key.r, key.b) < 0.7 or key.g > 0.3:
		warnings.append("the corners are not magenta (%s): leave the corners empty backdrop" % key.to_html(false))
	var bg: Dictionary = kc["background"].duplicate()
	if glow is Dictionary:
		bg["glow"] = glow
	var cleared := ImportFrames.key_background(img, bg)
	notes.append("backdrop %s keyed, %d px cleared" % [key.to_html(false), cleared])
	var isl := islands(img, int(kc.get("minIsland", 40)), float(kc.get("watermarkBox", 0.16)), float(kc.get("watermarkMaxArea", 0.004)))
	if isl["specks"] > 0:
		notes.append("%d stray specks dropped" % isl["specks"])
	for wm in isl["watermarks"]:
		notes.append("✦ dropped at %s (%d px)" % [wm["centre"], wm["px"]])
	if isl["watermarks"].is_empty() and opts.get("watermarks", []).is_empty():
		notes.append("no separate ✦ in the bottom-right corner (check the corner preview if one sits on the art)")
	return {"image": img, "notes": notes, "warnings": warnings}


## Drops the 8-connected opaque pieces (alpha > 0) smaller than min_px, and the small ones (at most
## max_area × the picture) lying wholly inside the bottom-right box (box × the size) that are not the
## largest piece: the ✦. {specks, watermarks [{centre, px}]}.
static func islands(img: Image, min_px: int, box: float, max_area: float) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var label := PackedInt32Array()
	label.resize(w * h)
	var pieces := [] # [size, x0, y0, x1, y1, first]
	var stack := PackedInt32Array()
	for s in w * h:
		if data[s * 4 + 3] == 0 or label[s] != 0:
			continue
		var id := pieces.size() + 1
		label[s] = id
		stack.resize(0)
		stack.append(s)
		var n := 0
		var lo := Vector2i(w, h)
		var hi := Vector2i(-1, -1)
		while not stack.is_empty():
			var i := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			n += 1
			var x := i % w
			var y := i / w
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
			for dy in [-1, 0, 1]:
				var yy: int = y + dy
				if yy < 0 or yy >= h:
					continue
				for dx in [-1, 0, 1]:
					var xx: int = x + dx
					if xx < 0 or xx >= w:
						continue
					var j := yy * w + xx
					if label[j] == 0 and data[j * 4 + 3] > 0:
						label[j] = id
						stack.append(j)
		pieces.append([n, lo.x, lo.y, hi.x, hi.y])
	var largest := 0
	for p in pieces:
		largest = maxi(largest, p[0])
	var drop := {}
	var out := {"specks": 0, "watermarks": []}
	for k in pieces.size():
		var p: Array = pieces[k]
		if p[0] < min_px:
			drop[k + 1] = true
			out["specks"] += 1
		elif p[0] < largest and p[0] <= max_area * w * h and p[1] >= w * (1.0 - box) and p[2] >= h * (1.0 - box):
			drop[k + 1] = true
			out["watermarks"].append({"centre": [(p[1] + p[3]) / 2, (p[2] + p[4]) / 2], "px": p[0]})
	if drop.is_empty():
		return out
	for i in w * h:
		if drop.has(label[i]):
			var o := i * 4
			data[o] = 0
			data[o + 1] = 0
			data[o + 2] = 0
			data[o + 3] = 0
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)
	return out


## A frame (see the header): {image (null: failed), window (source px), notes, warnings}.
static func frame(src: Image, cfg: Dictionary, group: String, opts: Dictionary) -> Dictionary:
	var fc: Dictionary = cfg["frame"]
	var c := cleaned(src, fc, cfg.get("glow", {}).get(group), opts)
	var img: Image = c["image"]
	var notes: Array = c["notes"]
	var warnings: Array = c["warnings"]
	var win := Rect2()
	if opts.get("window") is Array:
		var r: Array = opts["window"]
		win = Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
		notes.append("opening from the config: %s" % win)
	else:
		win = window_of(img, fc)
		if win.size == Vector2.ZERO:
			warnings.append("no transparent opening found in the middle (something drawn in the card's place?): regenerate, or give \"window\" [x0, y0, x1, y1] and \"forceWindow\": true in ranks.json files")
			return {"image": null, "window": win, "notes": notes, "warnings": warnings}
		notes.append("opening measured: x %d..%d, y %d..%d (%dx%d)" % [win.position.x, win.end.x, win.position.y, win.end.y, win.size.x, win.size.y])
	var size := Vector2i(int(fc["size"][0]), int(fc["size"][1]))
	var tw := target_window(fc)
	var sc := Vector2(tw.size.x / win.size.x, tw.size.y / win.size.y)
	if absf(sc.x / sc.y - 1.0) > 0.06:
		warnings.append("the opening's proportions are off by %d %% (x and y scaled differently): the window should be %.2f wide per 1 tall" % [roundi(absf(sc.x / sc.y - 1.0) * 100.0), tw.size.x / tw.size.y])
	if maxf(sc.x, sc.y) > 1.05:
		warnings.append("upscaled ×%.2f: the source opening is %d px wide, the shipped one %d: regenerate larger (canvas ≥ %d px wide)" % [maxf(sc.x, sc.y), win.size.x, tw.size.x, ceili(src.get_width() * maxf(sc.x, sc.y))])
	var reg := registered(img, win, tw, size)
	if reg["clipped"] > 0:
		warnings.append("%d opaque source px fall off the canvas (ornaments too far out for the shipped canvas): keep everything inside the canvas margins" % reg["clipped"])
	var out: Image = reg["image"]
	if str(opts.get("mirror", "")) in ["left", "right"]:
		mirror(out, str(opts["mirror"]) == "left")
		notes.append("mirrored from the %s half" % opts["mirror"])
	if opts.get("forceWindow", false):
		var n := clear_window(out, tw, float(fc.get("windowRadius", 0.06)) * size.x)
		notes.append("opening forced clear (%d px)" % n)
	var inside := core_px(out, fc)
	if inside > 0:
		warnings.append("%d opaque px inside the opening's core (drawn in the card's place): regenerate, or set \"forceWindow\": true" % inside)
	for axis in ["stretchX", "stretchY"]:
		for run in fc.get(axis, []):
			var e := stretch_error(out, run, axis == "stretchX")
			var line := "%s %s: %.1f %%" % [axis, run, e * 100.0]
			if e > float(fc.get("stretchTolerance", 0.08)):
				warnings.append(line + " non-uniform: ornaments in a stretch run (they smear on a taller / wider card): keep those band runs plain")
			else:
				notes.append(line + " uniform")
	return {"image": out, "window": win, "notes": notes, "warnings": warnings}


## The opening in texture px (frame.window fractions of frame.size).
static func target_window(fc: Dictionary) -> Rect2:
	var s := Vector2(fc["size"][0], fc["size"][1])
	var r: Array = fc["window"]
	return Rect2(Vector2(r[0], r[1]) * s, Vector2(r[2] - r[0], r[3] - r[1]) * s)


## The frame's opening in source px, measured from the middle outwards (see the header); a zero
## rect when the middle is not transparent or the opening is less than half the picture.
static func window_of(img: Image, fc: Dictionary) -> Rect2:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var a := func(x: int, y: int) -> int: return data[(y * w + x) * 4 + 3]
	var left := []
	var right := []
	for fy in fc.get("measureY", [0.37, 0.63]):
		var y := clampi(int(h * fy), 0, h - 1)
		if a.call(w / 2, y) >= 128:
			continue
		var x := w / 2
		while x > 0 and a.call(x - 1, y) < 128:
			x -= 1
		left.append(x)
		x = w / 2
		while x < w - 1 and a.call(x + 1, y) < 128:
			x += 1
		right.append(x + 1)
	var top := []
	var bottom := []
	for fx in fc.get("measureX", [0.3, 0.7]):
		var x := clampi(int(w * fx), 0, w - 1)
		if a.call(x, h / 2) >= 128:
			continue
		var y := h / 2
		while y > 0 and a.call(x, y - 1) < 128:
			y -= 1
		top.append(y)
		y = h / 2
		while y < h - 1 and a.call(x, y + 1) < 128:
			y += 1
		bottom.append(y + 1)
	if left.is_empty() or top.is_empty():
		return Rect2()
	var r := Rect2(_median(left), _median(top), _median(right) - _median(left), _median(bottom) - _median(top))
	if r.size.x < w * 0.5 or r.size.y < h * 0.5 or r.position.x <= 0 or r.position.y <= 0 or r.end.x >= w or r.end.y >= h:
		return Rect2()
	return r


static func _median(v: Array) -> float:
	var s := v.duplicate()
	s.sort()
	return float(s[s.size() / 2]) if s.size() % 2 == 1 else (s[s.size() / 2 - 1] + s[s.size() / 2]) / 2.0


## img mapped so its opening `win` (source px) covers `tw` of a `size` canvas: {image, clipped (opaque
## source px off the canvas)}.
static func registered(img: Image, win: Rect2, tw: Rect2, size: Vector2i) -> Dictionary:
	var sc := Vector2(tw.size.x / win.size.x, tw.size.y / win.size.y)
	var pos := win.position - tw.position / sc
	var rect := Rect2i(Vector2i(roundi(pos.x), roundi(pos.y)), Vector2i(roundi(size.x / sc.x), roundi(size.y / sc.y)))
	var region := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	var inside := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if inside.has_area():
		region.blit_rect(img, inside, inside.position - rect.position)
	var clipped := 0
	var data := img.get_data()
	var w := img.get_width()
	for y in img.get_height():
		for x in w:
			if data[(y * w + x) * 4 + 3] > 64 and not rect.has_point(Vector2i(x, y)):
				clipped += 1
	return {"image": ImportGuns.scaled(region, size), "clipped": clipped}


## Copies one half of img onto the other, mirrored (left: the left half is kept).
static func mirror(img: Image, keep_left: bool) -> void:
	var w := img.get_width()
	for y in img.get_height():
		for x in range(w / 2, w):
			var a := w - 1 - x
			if keep_left:
				img.set_pixel(x, y, img.get_pixel(a, y))
			else:
				img.set_pixel(a, y, img.get_pixel(x, y))


## Clears every px inside the rounded rect r (corner radius rad); returns how many were opaque.
static func clear_window(img: Image, r: Rect2, rad: float) -> int:
	var n := 0
	for y in range(int(r.position.y), int(ceil(r.end.y))):
		for x in range(int(r.position.x), int(ceil(r.end.x))):
			var p := Vector2(x + 0.5, y + 0.5)
			var q := Vector2(clampf(p.x, r.position.x + rad, r.end.x - rad), clampf(p.y, r.position.y + rad, r.end.y - rad))
			if p.distance_to(q) > rad:
				continue
			if img.get_pixel(x, y).a > 0.0:
				n += 1
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	return n


## Opaque px (alpha > 0.25) in the opening's core: the opening shrunk by 5 % of the width at the sides,
## by the seat's radius + 3 % at the top (the seat sits on the top edge) and by 10 % at the bottom (the
## bottom emblem may dip in).
static func core_px(img: Image, fc: Dictionary) -> int:
	var s := Vector2(img.get_size())
	var tw := target_window(fc)
	var seat := float(fc.get("seat", {}).get("radius", 0.1)) * s.x
	var r := Rect2(tw.position + Vector2(0.05 * s.x, seat + 0.03 * s.y), tw.size - Vector2(0.1 * s.x, seat + 0.03 * s.y + 0.1 * s.y))
	var n := 0
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			if img.get_pixel(x, y).a > 0.25:
				n += 1
	return n


## How far a stretch run is from uniform: per column (x run) or row (y run) the mean over its px of
## the largest premultiplied RGBA difference to the run's middle column / row; the largest of those.
static func stretch_error(img: Image, run: Array, along_x: bool) -> float:
	var s := img.get_size()
	var length := s.x if along_x else s.y
	var span := s.y if along_x else s.x
	var a := int(run[0] * length)
	var b := int(run[1] * length)
	var mid := (a + b) / 2
	var pick := func(i: int, j: int) -> Color:
		var c := img.get_pixel(i, j) if along_x else img.get_pixel(j, i)
		return Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a)
	var ref := []
	for j in span:
		ref.append(pick.call(mid, j))
	var worst := 0.0
	for i in range(a, b):
		var sum := 0.0
		for j in span:
			var c: Color = pick.call(i, j)
			var r: Color = ref[j]
			sum += maxf(maxf(absf(c.r - r.r), absf(c.g - r.g)), maxf(absf(c.b - r.b), absf(c.a - r.a)))
		worst = maxf(worst, sum / span)
	return worst * float(span) / maxf(1.0, _band_px(img, along_x, mid))


## How many px of the run's middle column / row are not transparent (the error is a mean over the band, not the
## empty canvas round it).
static func _band_px(img: Image, along_x: bool, mid: int) -> float:
	var n := 0
	var span := img.get_height() if along_x else img.get_width()
	for j in span:
		var c := img.get_pixel(mid, j) if along_x else img.get_pixel(j, mid)
		if c.a > 0.05:
			n += 1
	return float(n)


## A badge (see the header): {image (null: failed), notes, warnings}.
static func badge(src: Image, cfg: Dictionary, group: String, opts: Dictionary) -> Dictionary:
	var bc: Dictionary = cfg["badge"]
	var c := cleaned(src, bc, cfg.get("glow", {}).get(group), opts)
	var img: Image = c["image"]
	var box := ImportTitles.content_rect(img, 0.02, 0)
	if box.size == img.get_size() and img.get_pixel(img.get_width() / 2, img.get_height() / 2).a == 0.0:
		c["warnings"].append("nothing left after keying")
		return {"image": null, "notes": c["notes"], "warnings": c["warnings"]}
	var size := Vector2i(int(bc["size"][0]), int(bc["size"][1]))
	var margin := int(bc.get("margin", 8))
	var fill := float(bc.get("fill", {}).get(group, 0.9))
	var avail := Vector2(size - Vector2i(margin, margin) * 2) * fill
	var k := minf(avail.x / box.size.x, avail.y / box.size.y)
	var fit := Vector2i(maxi(1, roundi(box.size.x * k)), maxi(1, roundi(box.size.y * k)))
	if k > 1.05:
		c["warnings"].append("upscaled ×%.2f: the badge is only %dx%d source px: regenerate larger (fill the canvas)" % [k, box.size.x, box.size.y])
	var piece := ImportGuns.scaled(img.get_region(box), fit)
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(piece, Rect2i(Vector2i.ZERO, fit), (size - fit) / 2)
	c["notes"].append("content %dx%d → %dx%d (fill %.2f, ×%.2f)" % [box.size.x, box.size.y, fit.x, fit.y, fill, k])
	return {"image": out, "notes": c["notes"], "warnings": c["warnings"]}


## The frame drawn round a card of size `card` the way the client should slice it: the scale k fits
## the opening's width (only stretchY runs: the shipped layout) or height (only stretchX runs) to the
## card, or the smaller of both (runs on both axes, so the runs only grow); the ornaments drawn at k,
## the missing (or, negative, surplus) width / height shared out over that axis's runs by their
## widths.
## Returns {image (the whole frame), window (the card's rect in it)}.
static func sliced(img: Image, fc: Dictionary, card: Vector2) -> Dictionary:
	var s := Vector2(img.get_size())
	var tw := target_window(fc)
	var runs_x: Array = fc.get("stretchX", [])
	var runs_y: Array = fc.get("stretchY", [])
	var k := minf(card.x / tw.size.x, card.y / tw.size.y)
	if runs_x.is_empty() and not runs_y.is_empty():
		k = card.x / tw.size.x
	elif runs_y.is_empty() and not runs_x.is_empty():
		k = card.y / tw.size.y
	var xs := _segments(s.x, runs_x, card.x - tw.size.x * k, k)
	var ys := _segments(s.y, runs_y, card.y - tw.size.y * k, k)
	var total := Vector2i(roundi(xs[xs.size() - 1][3]), roundi(ys[ys.size() - 1][3]))
	var out := Image.create(total.x, total.y, false, Image.FORMAT_RGBA8)
	for sy in ys:
		for sx in xs:
			var src := Rect2i(int(sx[0]), int(sy[0]), int(sx[1] - sx[0]), int(sy[1] - sy[0]))
			var dst := Rect2i(roundi(sx[2]), roundi(sy[2]), roundi(sx[3]) - roundi(sx[2]), roundi(sy[3]) - roundi(sy[2]))
			if not src.has_area() or not dst.has_area():
				continue
			var part := img.get_region(src)
			part.resize(dst.size.x, dst.size.y, Image.INTERPOLATE_BILINEAR)
			out.blit_rect(part, Rect2i(Vector2i.ZERO, dst.size), dst.position)
	var x0 := _mapped(tw.position.x, xs)
	var y0 := _mapped(tw.position.y, ys)
	return {"image": out, "window": Rect2(x0, y0, _mapped(tw.end.x, xs) - x0, _mapped(tw.end.y, ys) - y0)}


## [[src0, src1, dst0, dst1], ...] along one axis of length len: fixed parts × k, runs × k plus their
## share of extra.
static func _segments(length: float, runs: Array, extra: float, k: float) -> Array:
	var cuts := [0.0]
	var stretch := []
	var run_px := 0.0
	for r in runs:
		cuts.append(r[0] * length)
		cuts.append(r[1] * length)
		run_px += (r[1] - r[0]) * length
	cuts.append(length)
	var out := []
	var at := 0.0
	for i in cuts.size() - 1:
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		var d := (b - a) * k
		if i % 2 == 1 and run_px > 0.0: # a run
			d = maxf(1.0, d + extra * (b - a) / run_px)
		out.append([a, b, at, at + d])
		at += d
	return out


static func _mapped(v: float, segs: Array) -> float:
	for s in segs:
		if v <= s[1]:
			return s[2] + (v - s[0]) / maxf(0.001, s[1] - s[0]) * (s[3] - s[2])
	return segs[segs.size() - 1][3]


func _write_layout(cfg: Dictionary, grades: Array) -> void:
	var fc: Dictionary = cfg["frame"]
	var s := Vector2(fc["size"][0], fc["size"][1])
	var tw := target_window(fc)
	var px := func(runs: Array, length: float) -> Array:
		var out := []
		for r in runs:
			out.append([roundi(r[0] * length), roundi(r[1] * length)])
		return out
	var frames := []
	var badges := []
	for g in grades:
		if FileAccess.file_exists(OUT + "frame_%s.png" % g):
			frames.append(g)
		if FileAccess.file_exists(OUT + "badge_%s.png" % g):
			badges.append(g)
	var seat: Dictionary = fc.get("seat", {"centre": [0.5, 0.12], "radius": 0.1})
	var meta := {
		"_doc": "Written by tools/import_rank_art.gd (do not edit; edit art_source/ranks/ranks.json and re-run). Texture px of every frame_<grade>.png (all share it): size [w, h]; window [x, y, w, h] (the transparent opening the card fills); seat {centre [x, y], radius} (the plain medallion on the top edge the badge is drawn on); stretchX / stretchY [[from, to], ...] (plain band runs, empty arrays: none on that axis: to frame a card of another proportion, draw the frame at one scale k = card w / window w when only stretchY has runs (card h / window h when only stretchX has; the smaller of both when both have) and heighten / widen only these runs by their share of the card's missing (negative: surplus) height / width, so the ornaments are never squashed; tools/import_rank_art.gd sliced()). frames / badges: the grades that have one.",
		"frame": {
			"size": [int(s.x), int(s.y)],
			"window": [roundi(tw.position.x), roundi(tw.position.y), roundi(tw.size.x), roundi(tw.size.y)],
			"seat": {"centre": [roundi(seat["centre"][0] * s.x), roundi(seat["centre"][1] * s.y)], "radius": roundi(seat["radius"] * s.x)},
			"stretchX": px.call(fc.get("stretchX", []), s.x),
			"stretchY": px.call(fc.get("stretchY", []), s.y),
		},
		"badge": {"size": [int(cfg["badge"]["size"][0]), int(cfg["badge"]["size"][1])]},
		"frames": frames,
		"badges": badges,
	}
	var path := ProjectSettings.globalize_path(OUT + "ranks.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t", false) + "\n")
	f.close()


func _debug_picture(dir: String, name: String, kind: String, res: Dictionary, cfg: Dictionary) -> void:
	var img: Image = res["image"]
	var fc: Dictionary = cfg["frame"]
	var tiles := []
	if kind == "frame":
		var tw := target_window(fc)
		for page in [DARK, LIGHT]:
			tiles.append(_on_page(img, tw, page))
		for card in PREVIEW_CARDS:
			var sl := sliced(img, fc, card * 1.6)
			for page in [DARK, LIGHT]:
				tiles.append(_on_page(sl["image"], sl["window"], page))
	else:
		for page in [DARK, LIGHT]:
			var t := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
			t.fill(page)
			t.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
			tiles.append(t)
	_row(tiles, 16, DARK.darkened(0.5)).save_png(dir.path_join(name + "_preview.png"))
	var box := Rect2i(int(img.get_width() * 0.8), int(img.get_height() * 0.8), img.get_width() - int(img.get_width() * 0.8), img.get_height() - int(img.get_height() * 0.8))
	var corner := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	corner.fill(Color(0.5, 0.5, 0.5))
	corner.blend_rect(img, box, Vector2i.ZERO)
	corner.resize(box.size.x * 3, box.size.y * 3, Image.INTERPOLATE_NEAREST)
	corner.save_png(dir.path_join(name + "_corner.png"))


## img over a page colour, a mock card (rounded) filling the opening `win`.
static func _on_page(img: Image, win: Rect2, page: Color) -> Image:
	var t := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	t.fill(page)
	var rad := minf(win.size.x, win.size.y) * 0.07
	for y in range(int(win.position.y), int(win.end.y)):
		for x in range(int(win.position.x), int(win.end.x)):
			var p := Vector2(x + 0.5, y + 0.5)
			var q := Vector2(clampf(p.x, win.position.x + rad, win.end.x - rad), clampf(p.y, win.position.y + rad, win.end.y - rad))
			if p.distance_to(q) <= rad:
				t.set_pixel(x, y, CARD.lerp(CARD.lightened(0.3), (y - win.position.y) / win.size.y))
	t.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	return t


## The images side by side (top-aligned), gap px apart, on a background colour.
static func _row(images: Array, gap: int, back: Color) -> Image:
	var w := gap
	var h := 0
	for i in images:
		w += i.get_width() + gap
		h = maxi(h, i.get_height())
	var out := Image.create(w, h + gap * 2, false, Image.FORMAT_RGBA8)
	out.fill(back)
	var x := gap
	for i in images:
		out.blit_rect(i, Rect2i(Vector2i.ZERO, i.get_size()), Vector2i(x, gap))
		x += i.get_width() + gap
	return out


## The visual ladder: every imported frame (one row per group) and badge (24 / 48 / 96 px on dark and
## light), in grade order.
func _ladders(dir: String, cfg: Dictionary, grades: Array) -> void:
	var fc: Dictionary = cfg["frame"]
	var rows := []
	for group in cfg["groups"]:
		var tiles := []
		for g in cfg["groups"][group]:
			var path := ProjectSettings.globalize_path(OUT + "frame_%s.png" % g)
			if not FileAccess.file_exists(path):
				continue
			var img := Image.load_from_file(path)
			img.resize(img.get_width() / 3, img.get_height() / 3, Image.INTERPOLATE_LANCZOS)
			var tw := target_window(fc)
			tiles.append(_on_page(img, Rect2(tw.position / 3.0, tw.size / 3.0), DARK))
		if not tiles.is_empty():
			rows.append(_row(tiles, 8, DARK.darkened(0.5)))
	if not rows.is_empty():
		_column(rows).save_png(dir.path_join("ladder_frames.png"))
	var lines := []
	for page in [DARK, LIGHT]:
		for px in [24, 48, 96]:
			var tiles := []
			for g in grades:
				var path := ProjectSettings.globalize_path(OUT + "badge_%s.png" % g)
				if not FileAccess.file_exists(path):
					continue
				var img := Image.load_from_file(path)
				img.resize(px, px, Image.INTERPOLATE_LANCZOS)
				var t := Image.create(px + 8, px + 8, false, Image.FORMAT_RGBA8)
				t.fill(page)
				t.blend_rect(img, Rect2i(0, 0, px, px), Vector2i(4, 4))
				tiles.append(t)
			if not tiles.is_empty():
				lines.append(_row(tiles, 4, page))
	if not lines.is_empty():
		_column(lines).save_png(dir.path_join("ladder_badges.png"))


static func _column(images: Array) -> Image:
	var w := 0
	var h := 0
	for i in images:
		w = maxi(w, i.get_width())
		h += i.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(DARK.darkened(0.5))
	var y := 0
	for i in images:
		out.blit_rect(i, Rect2i(Vector2i.ZERO, i.get_size()), Vector2i(0, y))
		y += i.get_height()
	return out


func _save(img: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if not FileAccess.file_exists(abs_path + ".import"):
		var f := FileAccess.open(abs_path + ".import", FileAccess.WRITE)
		f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\n')
		f.close()
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("import_rank_art: cannot write %s (%s)" % [path, error_string(err)])
		_failed = true
		return
	var bytes := FileAccess.get_file_as_bytes(abs_path).size()
	_written += 1
	_bytes += bytes
	var big := "  (over 2048 px)" if maxi(img.get_width(), img.get_height()) > 2048 else ""
	print("      → %s  %dx%d  %.1f KB%s" % [path, img.get_width(), img.get_height(), bytes / 1024.0, big])
