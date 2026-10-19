extends SceneTree
## Imports the hand-made (AI-made) gun sheet into the held guns and the weapon equipment icons.
## Reproducible: everything it does is in art_source/weapons/guns_v1.json (sheet px). Runs
## headless (only Image is used):
##
##   $GODOT --headless --path . -s tools/import_guns.gd [-- <config.json>]
##
## The sheet: one gun per cell, side view, muzzle right, on white; rows = kinds, columns = tiers.
## Only the cells the config lists are cut: not the seed launcher, bazooka and cannon rows, the shock
## rifle row only for the blaster (Flora's seed launcher, Rookie's bazooka, Tanko's cannon and Spark's
## shock rifle are hug art, their icons made by tools/import_hug_guns.gd with icons() below).
## It writes assets/weapons/<kind>/<tier>.png, assets/weapons/weapons.json (the format ui/art.gd
## gun() reads, plus "source": the config) and assets/icons/equipment/weapon_*.png. A new PNG gets
## an .import (mipmaps for the icons); an existing .import is never touched. Let the editor import
## them. tools/bake_art.gd skips the weapons group and the weapon icons while weapons.json has a
## "source" (the code-drawn guns would overwrite this art).
##
## Config: `cells` {name: {rect [x, y, w, h] (loose), grip [x, y] (the fist's centre on the pistol
## grip / rear handle, also the seed: the piece under it is kept), muzzle [x, y] (the barrel
## opening, the rocket / barrel tip, the dragon's mouth), keep [[x, y]...] (enclosed whites that are
## art, not holes)}}; `guns` {kind: {length (world px the
## kind's iron gun is long in the match), tiers {tier: {cell, recolour (a `recolours` name)}}}};
## `recolours` {name: {saturation, value (HSV multipliers on every pixel), hue (degrees added),
## hueRange [lo, hi] (degrees: only the pixels of that hue, 8° soft edge; default every pixel)} or
## {rules [{hue [lo, hi] degrees, minSat, ramp [colours dark → light]}], sparkles [[x, y, r]
## fractions of the gun's width / height / width]}}; `icons` {size, margin, tiltDeg, files {name
## with <tier>: {gun, tiers}}}. tools/import_hug_guns.gd uses the same recolour specs.
##
## Per cell (tools/cut_sheet.gd cut_part()): the white background is flood-filled from the rect's
## border (`tolerance`); enclosed pure-white areas (min channel within `holeTolerance` of white, at
## least `holeMinArea` px: the trigger guard's inside) are background too, the art's own whites
## (eyes, teeth, highlights) are smaller or tinted and stay; the edge alpha comes from how far a
## pixel is from white and its colour is un-blended from white (defringe: no white halo).
## Per tier: the recolour at sheet resolution (a ramp rule maps the pixels of its hue range, by
## their luminance between the 2nd and 98th percentile, onto the ramp: a palette swap that keeps
## the shading; the outline, too dark, and other hues stay).
## Per kind: every tier on one canvas with the grips on the same point (a tier swap does not move
## the hand), `pad` px round the union; one scale for the kind (the iron gun `length` world px
## long × `texPxPerWorldPx`), applied once (Lanczos, premultiplied colour). weapons.json
## pxPerUnit = texPxPerWorldPx × worldPxPerUnit (match/views/player_view.gd ART_SCALE), so the
## gun is drawn `length` world px long at the character's scale.
## Icons: the kind's sheet-resolution canvas turned `tiltDeg` (muzzle up), the union of the
## file group's tiers fitted into size − 2 × margin (one scale per group), centred, Lanczos once.

const CutSheet := preload("res://tools/cut_sheet.gd")
const CONFIG := "res://art_source/weapons/guns_v1.json"
const OUT := "res://assets/weapons/"
const ICONS := "res://assets/icons/equipment/"

var _written := 0
var _bytes := 0


func _initialize() -> void:
	var args: Array = Array(OS.get_cmdline_user_args()).filter(func(a): return str(a).ends_with(".json"))
	_import(str(args[0]) if not args.is_empty() else CONFIG)
	print("import_guns: wrote %d files, %.1f KB" % [_written, _bytes / 1024.0])
	quit()


func _import(cfg_path: String) -> void:
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
	if not cfg is Dictionary:
		push_error("import_guns: %s missing or not a JSON object" % cfg_path)
		return
	var dir := cfg_path.get_base_dir() + "/"
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(dir + str(cfg["sheet"])))
	if sheet == null or sheet.is_empty():
		push_error("import_guns: cannot read " + dir + str(cfg["sheet"]))
		return
	sheet.convert(Image.FORMAT_RGBA8)
	print("%s: %s %dx%d" % [cfg_path, cfg["sheet"], sheet.get_width(), sheet.get_height()])
	# 1. Cut every cell.
	var cuts := {} # cell -> {image, origin, grip, muzzle} (sheet px)
	for name in cfg["cells"]:
		var c: Dictionary = cfg["cells"][name]
		var rect := _rect(c["rect"])
		var holes := find_holes(sheet, rect, float(cfg.get("holeTolerance", 0.04)), int(cfg.get("holeMinArea", 40)), c.get("keep", []))
		var cut := CutSheet.cut_part(sheet, {"rect": c["rect"], "seed": c["grip"], "holes": holes, "pad": 0},
			float(cfg.get("tolerance", 0.1)), 1.0)
		if cut.is_empty():
			push_error("import_guns: cell %s is empty" % name)
			return
		cuts[name] = {"image": cut["image"], "origin": Vector2(cut["origin"]), "grip": _v(c["grip"]), "muzzle": _v(c["muzzle"])}
		var img: Image = cut["image"]
		print("  cut %s: %dx%d at %s, %d holes %s" % [name, img.get_width(), img.get_height(), cut["origin"], holes.size(), holes])
	# 2. Every kind: the tiers on one grip-aligned canvas, one scale.
	var tex_per_world := float(cfg.get("texPxPerWorldPx", 2.0))
	var ppu := tex_per_world * float(cfg.get("worldPxPerUnit", 0.35))
	var pad := float(cfg.get("pad", 2))
	var guns := {}
	var canvases := {} # kind -> {tier: Image (sheet resolution, straight alpha, grip at the same px)}
	var report: Array = []
	for kind in cfg["guns"]:
		var spec: Dictionary = cfg["guns"][kind]
		var tiers: Dictionary = spec["tiers"]
		var parts := {} # tier -> {image, at (top-left from the grip), muzzle (from the grip)}
		for tier in tiers:
			var t: Dictionary = tiers[tier]
			var cut: Dictionary = cuts[str(t["cell"])]
			var img: Image = cut["image"].duplicate()
			if t.has("recolour"):
				recolour(img, cfg["recolours"][str(t["recolour"])])
			parts[tier] = {"image": img, "at": cut["origin"] - cut["grip"], "muzzle": cut["muzzle"] - cut["grip"]}
		var ref_tier := "iron" if parts.has("iron") else str(parts.keys()[0])
		var ref_w := float(parts[ref_tier]["image"].get_width())
		var s := float(spec["length"]) * tex_per_world / ref_w # texture px per sheet px
		var u := Rect2()
		for tier in parts:
			var r := Rect2(parts[tier]["at"], Vector2(parts[tier]["image"].get_size()))
			u = r if u.size == Vector2.ZERO else u.merge(r)
		u = u.grow(pad / s)
		var src := Vector2i(ceili(u.size.x), ceili(u.size.y))
		var dst := Vector2i(maxi(1, roundi(src.x * s)), maxi(1, roundi(src.y * s)))
		var k := Vector2(dst) / Vector2(src)
		guns[kind] = {}
		canvases[kind] = {}
		for tier in parts:
			var canvas := Image.create(src.x, src.y, false, Image.FORMAT_RGBA8)
			var img: Image = parts[tier]["image"]
			canvas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((parts[tier]["at"] - u.position).round()))
			canvases[kind][tier] = canvas
			var out := scaled(canvas, dst)
			_save(out, OUT + "%s/%s.png" % [kind, tier], false)
			var grip := (-u.position) * k
			var muzzle: Vector2 = (parts[tier]["muzzle"] - u.position) * k
			guns[kind][tier] = {"size": [dst.x, dst.y], "grip": [snappedf(grip.x, 0.1), snappedf(grip.y, 0.1)],
				"muzzle": [snappedf(muzzle.x, 0.1), snappedf(muzzle.y, 0.1)]}
		var used := scaled(canvases[kind][ref_tier], dst).get_used_rect()
		report.append("  %s: %dx%d px, %s %d px long = %.1f world px (%.3f px per sheet px)" % [kind, dst.x, dst.y, ref_tier,
			used.size.x, used.size.x / tex_per_world, s])
	for line in report:
		print(line)
	var data := {"source": cfg_path.trim_prefix("res://"), "pxPerUnit": snappedf(ppu, 0.0001), "guns": guns}
	_write_text(OUT + "weapons.json", JSON.stringify(data, "\t", false) + "\n")
	# 3. The equipment icons.
	var ic: Dictionary = cfg.get("icons", {})
	for pattern in ic.get("files", {}):
		var f: Dictionary = ic["files"][pattern]
		var out := icons(canvases[str(f["gun"])], f["tiers"], ic)
		for tier in f["tiers"]:
			_save(out[tier], ICONS + str(pattern).replace("<tier>", str(tier)) + ".png", true)


## The equipment icons of one file group (`icons` size, margin, tiltDeg): {tier: Image size² px}
## from canvases {tier: Image (straight alpha, every tier at the same resolution and lined up on
## the same point)}: each turned tiltDeg (muzzle up), the union of the group's tiers fitted into
## size − 2 × margin (one scale per group, the same region of every tier), centred, Lanczos once.
## tools/import_hug_guns.gd makes the hug guns' icons with it too.
static func icons(canvases: Dictionary, tiers: Array, ic: Dictionary) -> Dictionary:
	var size := int(ic.get("size", 128))
	var box := float(size - 2 * int(ic.get("margin", 6)))
	var turned := {}
	var u := Rect2i()
	for tier in tiers:
		var img := rotated(canvases[tier], deg_to_rad(float(ic.get("tiltDeg", 0.0))))
		turned[tier] = img
		var r := img.get_used_rect()
		u = r if u.size == Vector2i.ZERO else u.merge(r)
	var s := minf(box / u.size.x, box / u.size.y)
	var dst := Vector2i(maxi(1, roundi(u.size.x * s)), maxi(1, roundi(u.size.y * s)))
	var out := {}
	for tier in tiers:
		var part: Image = turned[tier].get_region(u)
		var small := scaled(part, dst)
		var icon := Image.create(size, size, false, Image.FORMAT_RGBA8)
		icon.blit_rect(small, Rect2i(Vector2i.ZERO, dst), (Vector2i(size, size) - dst) / 2)
		out[tier] = icon
	return out


## Points (sheet px) of the enclosed near-white areas in rect: near-white pixels (min channel within
## tol of white) connected to each other but not to the rect's border, at least min_area px; not
## the areas under the `keep` points (sheet px: the art's own large whites, e.g. a rocket's
## stripes, a screen's line).
static func find_holes(sheet: Image, rect: Rect2i, tol: float, min_area: int, keep: Array = []) -> Array:
	rect = rect.intersection(Rect2i(Vector2i.ZERO, sheet.get_size()))
	var w := rect.size.x
	var h := rect.size.y
	var px := sheet.get_region(rect).get_data()
	var n := w * h
	var white := PackedByteArray()
	white.resize(n)
	var lim := int(round((1.0 - tol) * 255.0))
	for i in n:
		var o := i * 4
		white[i] = 1 if mini(mini(px[o], px[o + 1]), px[o + 2]) >= lim else 0
	var seen := PackedByteArray()
	seen.resize(n)
	var out: Array = []
	var stack := PackedInt32Array()
	var starts: Array[int] = []
	for k in keep:
		var kp := Vector2i(int(k[0]), int(k[1])) - rect.position
		if Rect2i(0, 0, w, h).has_point(kp):
			starts.append(kp.y * w + kp.x)
	var kept := starts.size()
	for s in n:
		starts.append(s)
	for si in starts.size():
		var s: int = starts[si]
		if white[s] == 0 or seen[s] == 1:
			continue
		var area := 0
		var border := false
		var sum := Vector2.ZERO
		stack.append(s)
		seen[s] = 1
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var x := i % w
			var y := i / w
			area += 1
			sum += Vector2(x, y)
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				border = true
			for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1]:
				if j >= 0 and white[j] == 1 and seen[j] == 0:
					seen[j] = 1
					stack.append(j)
		if border or area < min_area or si < kept:
			continue
		# Its centre when that is in it (the flood starts there), else its first pixel.
		var c := sum / area
		var best := s
		var q := Vector2i(c.round())
		if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and white[q.y * w + q.x] == 1:
			best = q.y * w + q.x
		out.append([rect.position.x + best % w, rect.position.y + best / w])
	return out


## Recolours a straight-alpha image in place (see the header).
static func recolour(img: Image, spec: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if spec.has("saturation") or spec.has("value") or spec.has("hue"):
		var ks := float(spec.get("saturation", 1.0))
		var kv := float(spec.get("value", 1.0))
		var dh := float(spec.get("hue", 0.0)) / 360.0
		var hr = spec.get("hueRange")
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				var wt := 1.0
				if hr is Array and hr.size() >= 2:
					var hue := c.h * 360.0
					wt = clampf(minf(hue - float(hr[0]), float(hr[1]) - hue) / 8.0 + 0.5, 0.0, 1.0)
					if wt <= 0.0:
						continue
				var to := Color.from_hsv(fposmod(c.h + dh, 1.0), clampf(c.s * ks, 0.0, 1.0), clampf(c.v * kv, 0.0, 1.0), c.a)
				img.set_pixel(x, y, c.lerp(to, wt) if wt < 1.0 else to)
	# Every rule reads the original pixels (a pixel one rule recoloured is not picked up by the next).
	var src: Image = img.duplicate()
	for rule in spec.get("rules", []):
		var ramp: Array[Color] = []
		for hex in rule["ramp"]:
			ramp.append(Color(str(hex)))
		var weights := PackedFloat32Array()
		weights.resize(w * h)
		var lums: Array[float] = []
		for y in h:
			for x in w:
				var c := src.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				var wt := _weight(c, rule)
				weights[y * w + x] = wt
				if wt >= 0.5:
					lums.append(c.get_luminance())
		if lums.size() < 10:
			continue
		lums.sort()
		var lo: float = lums[int(lums.size() * 0.02)]
		var hi: float = lums[int(lums.size() * 0.98)]
		for y in h:
			for x in w:
				var wt := weights[y * w + x]
				if wt <= 0.0:
					continue
				var t := clampf((src.get_pixel(x, y).get_luminance() - lo) / maxf(0.001, hi - lo), 0.0, 1.0)
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.lerp(_ramp(ramp, t), wt), c.a))
	for sp in spec.get("sparkles", []):
		_sparkle(img, Vector2(float(sp[0]) * w, float(sp[1]) * h), float(sp[2]) * w)


## How much a rule takes a pixel: its hue in the range (8° soft), saturated and bright enough
## (the dark outline stays).
static func _weight(c: Color, rule: Dictionary) -> float:
	var hue := c.h * 360.0
	var lo := float(rule["hue"][0])
	var hi := float(rule["hue"][1])
	var inside := minf(hue - lo, hi - hue) # degrees inside the range (negative: outside)
	var wh := clampf(inside / 8.0 + 0.5, 0.0, 1.0)
	var ws := clampf((c.s - float(rule.get("minSat", 0.2))) / 0.08 + 0.5, 0.0, 1.0)
	var wv := clampf((c.v - float(rule.get("minValue", 0.18))) / 0.08 + 0.5, 0.0, 1.0)
	return wh * ws * wv


static func _ramp(ramp: Array[Color], t: float) -> Color:
	if ramp.size() == 1:
		return ramp[0]
	var f := t * (ramp.size() - 1)
	var i := mini(int(f), ramp.size() - 2)
	return ramp[i].lerp(ramp[i + 1], f - i)


## A four-point white star with a soft core at p (radius r px), added over the image.
static func _sparkle(img: Image, p: Vector2, r: float) -> void:
	var x0 := maxi(0, floori(p.x - r))
	var x1 := mini(img.get_width() - 1, ceili(p.x + r))
	var y0 := maxi(0, floori(p.y - r))
	var y1 := mini(img.get_height() - 1, ceili(p.y + r))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := (Vector2(x, y) + Vector2(0.5, 0.5) - p) / r
			var ax := absf(d.x)
			var ay := absf(d.y)
			var star := maxf(clampf(1.0 - (ax + ay * 3.5), 0.0, 1.0), clampf(1.0 - (ay + ax * 3.5), 0.0, 1.0))
			var core := clampf(1.0 - d.length() * 3.5, 0.0, 1.0)
			var a := clampf(maxf(star, core) * 1.6, 0.0, 1.0)
			if a <= 0.0:
				continue
			var c := img.get_pixel(x, y)
			var out_a := a + c.a * (1.0 - a)
			var rgb := (Color(1, 1, 1) * a + c * c.a * (1.0 - a)) / maxf(out_a, 0.0001)
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, out_a))


## img (straight alpha) resized once to size: Lanczos on premultiplied colour, faint pixels cleared.
static func scaled(img: Image, size: Vector2i) -> Image:
	var pm := premultiplied(img)
	if pm.get_size() != size:
		pm.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var out := CutSheet._unpremultiply(pm)
	var data := out.get_data()
	for o in range(0, data.size(), 4):
		if data[o + 3] <= 2:
			data[o] = 0
			data[o + 1] = 0
			data[o + 2] = 0
			data[o + 3] = 0
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, data)


static func premultiplied(img: Image) -> Image:
	var data := img.get_data()
	for o in range(0, data.size(), 4):
		var a := data[o + 3]
		for c in 3:
			data[o + c] = int(round(data[o + c] * a / 255.0))
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


## img (straight alpha) turned by angle (radians, + clockwise on screen) round its centre on a
## canvas that holds it all; bilinear on premultiplied colour (at sheet resolution, before the
## one downscale). Straight alpha out.
static func rotated(img: Image, angle: float) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var src := premultiplied(img).get_data()
	var cs := cos(angle)
	var sn := sin(angle)
	var ow := ceili(absf(w * cs) + absf(h * sn)) + 2
	var oh := ceili(absf(w * sn) + absf(h * cs)) + 2
	var out := PackedByteArray()
	out.resize(ow * oh * 4)
	var c_in := Vector2(w, h) / 2.0
	var c_out := Vector2(ow, oh) / 2.0
	for y in oh:
		for x in ow:
			var d := Vector2(x + 0.5, y + 0.5) - c_out
			# inverse rotation
			var sx := d.x * cs + d.y * sn + c_in.x - 0.5
			var sy := -d.x * sn + d.y * cs + c_in.y - 0.5
			if sx < -1.0 or sy < -1.0 or sx > w or sy > h:
				continue
			var x0 := floori(sx)
			var y0 := floori(sy)
			var fx := sx - x0
			var fy := sy - y0
			var acc := [0.0, 0.0, 0.0, 0.0]
			for j in 2:
				for i in 2:
					var xx := x0 + i
					var yy := y0 + j
					if xx < 0 or yy < 0 or xx >= w or yy >= h:
						continue
					var wt := (fx if i == 1 else 1.0 - fx) * (fy if j == 1 else 1.0 - fy)
					var o := (yy * w + xx) * 4
					for c in 4:
						acc[c] += src[o + c] * wt
			var p := (y * ow + x) * 4
			for c in 4:
				out[p + c] = clampi(roundi(acc[c]), 0, 255)
	return CutSheet._unpremultiply(Image.create_from_data(ow, oh, false, Image.FORMAT_RGBA8, out))


static func _rect(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


static func _v(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _save(img: Image, path: String, mipmaps: bool) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if not FileAccess.file_exists(abs_path + ".import"):
		var f := FileAccess.open(abs_path + ".import", FileAccess.WRITE)
		f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=%s\n' % ("true" if mipmaps else "false"))
		f.close()
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("import_guns: cannot write %s (%s)" % [path, error_string(err)])
		return
	var bytes := FileAccess.get_file_as_bytes(abs_path).size()
	_written += 1
	_bytes += bytes
	print("  %s  %dx%d  %.1f KB" % [path, img.get_width(), img.get_height(), bytes / 1024.0])


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	f.store_string(text)
	f.close()
	_written += 1
	_bytes += text.length()
	print("  %s  %.1f KB" % [path, text.length() / 1024.0])
