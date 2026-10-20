extends SceneTree
## Imports the gun tiers' own shell pictures (match/views/projectile_view.gd, Art.tier_projectile()):
## the AI-drawn shells, art_source/fx/projectiles/<kind>_<tier>.png (kinds bazooka, cannon,
## shock_rifle, seed_launcher, blaster; tiers iron, steel, mithril, dragon), facing right (the
## nose / +x is the flight; nothing is rotated). Every file present is imported, the others are
## left out (the match then draws the kind's projectile.png). Reproducible: everything it does is
## in art_source/fx/projectiles/projectiles.json. Runs headless (only Image is used; the editor
## may stay open):
##
##   $GODOT --headless --path . -s tools/import_projectiles.gd
##
## Per picture, in source px, by its kind's mode (projectiles.json "modes"):
## - "solid" (bazooka, cannon, seed_launcher: an object with a thick dark outline on a flat WHITE
##   background): the white is flood-filled from the picture's border over near-white px (every
##   channel ≥ 1 − whiteTolerance; it stops at the outline) and made transparent; the object's px
##   next to it get a soft 1-px edge (alpha un-mixed from the white, a = (1 − min channel) /
##   edgeSoft, the colour un-premultiplied from the white), the rest stays opaque;
## - "glow" (shock_rifle, blaster: an energy object on pure BLACK): black → alpha from the
##   brightest channel m = max(r, g, b) by alphaCurve, the colour un-premultiplied as
##   tools/import_back_aura.gd keyed() (rgb / max(a, m): the hue stays true):
##   "linear" (the default, for soft glows): a = clamp((m − alphaFloor) / (1 − alphaFloor))^alphaGamma
##   × alphaBoost, at most m-ish, so a halo keeps its bright colour fading out (no dark ring on a
##   bright sky); "smoothstep" (an orb with a dark but solid part, e.g. the lava orb's maroon
##   shell, m ≈ 0.3): a = smoothstep(alphaLo, alphaHi, m), the dark shell opaque in its own dark
##   colour instead of half see-through and muddy, only the black and the faint haze fade. A file
##   may give its own alphaCurve / alphaFloor / alphaGamma / alphaBoost / alphaLo / alphaHi.
## Both: the generator's grey "✦" watermark near the bottom-right corner is painted over with the
## background first (found_watermark(): the grey px in the corner box `watermarkBox` × the size,
## a small blob; a per-file "watermark": {"centre": [x, y], "radius": r} overrides it, false skips
## it); the picture is keyed, trimmed to its content (alpha > trimAlpha) plus `margin` px, then the
## source is cropped there, scaled down once (Lanczos, never up) to fit `scale` × the kind's
## projectile.png size (the match fits it into that size anyway: the source resolution does not
## matter) and keyed again. Writes assets/fx/<kind>/projectile_<tier>.png (a new PNG gets an
## .import with mipmaps, an existing .import is never touched: let the editor import them; until
## then ui/art.gd reads the PNG).

const Art := preload("res://ui/art.gd")

const SRC := "res://art_source/fx/projectiles/"
const CONFIG := SRC + "projectiles.json"


func _initialize() -> void:
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if not cfg is Dictionary:
		push_error("import_projectiles: %s is not a JSON object" % CONFIG)
		quit(1)
		return
	var done := 0
	for kind in Art.SHOT_KINDS:
		for tier in Art.PROJECTILE_TIERS:
			var name := "%s_%s" % [kind, tier]
			var path := ProjectSettings.globalize_path(SRC + name + ".png")
			if not FileAccess.file_exists(path):
				continue
			var src := Image.load_from_file(path)
			if src == null or src.is_empty():
				push_error("import_projectiles: cannot read %s" % path)
				continue
			var base := Image.load_from_file(ProjectSettings.globalize_path(Art.shot_path(kind, "projectile")))
			var base_size := Vector2(base.get_size()) if base != null and not base.is_empty() else Vector2(64, 64)
			var opts: Dictionary = cfg.get("files", {}).get(name, {})
			var img := processed(src, str(cfg["modes"].get(kind, "solid")), cfg, opts, base_size * float(cfg.get("scale", 4.0)))
			_save(img, Art.tier_projectile_path(kind, tier))
			done += 1
	print("import_projectiles: %d picture(s)" % done)
	quit(0)


## The picture keyed and trimmed, fitted into `fit` px (see the header); RGBA8.
static func processed(src: Image, mode: String, cfg: Dictionary, opts: Dictionary, fit: Vector2) -> Image:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGB8)
	var bg := Color.WHITE if mode == "solid" else Color.BLACK
	var wm = opts.get("watermark", null)
	if wm == null:
		wm = found_watermark(img, bg, float(cfg.get("watermarkBox", 0.16)))
	if wm is Dictionary and not wm.is_empty():
		paint_disc(img, Vector2(wm["centre"][0], wm["centre"][1]), float(wm["radius"]), bg)
	var kcfg := cfg.duplicate()
	for k in ["alphaCurve", "alphaFloor", "alphaGamma", "alphaBoost", "alphaLo", "alphaHi"]:
		if opts.has(k):
			kcfg[k] = opts[k]
	cfg = kcfg
	var first := key(img, mode, cfg)
	var box := content_rect(first, float(cfg.get("trimAlpha", 0.03)), int(cfg.get("margin", 6)))
	img = img.get_region(box)
	var size := fitted(Vector2(img.get_size()), fit)
	if size.x < img.get_width():
		img.resize(maxi(1, int(round(size.x))), maxi(1, int(round(size.y))), Image.INTERPOLATE_LANCZOS)
	return key(img, mode, cfg)


## Keys the background out by mode ("solid": white flood fill, "glow": black → alpha).
static func key(img: Image, mode: String, cfg: Dictionary) -> Image:
	if mode == "glow":
		return black_keyed(img, cfg)
	return white_keyed(img, float(cfg.get("whiteTolerance", 0.1)), float(cfg.get("edgeSoft", 0.6)))


## The glow mode's alpha of a px whose brightest channel is m, by cfg's alphaCurve (see the header).
static func glow_alpha(m: float, cfg: Dictionary) -> float:
	if str(cfg.get("alphaCurve", "linear")) == "smoothstep":
		var lo := float(cfg.get("alphaLo", 0.03))
		return smoothstep(lo, maxf(float(cfg.get("alphaHi", 0.25)), lo + 0.001), m)
	var f := float(cfg.get("alphaFloor", 0.035))
	return minf(1.0, pow(clampf((m - f) / (1.0 - f), 0.0, 1.0), float(cfg.get("alphaGamma", 1.0))) * float(cfg.get("alphaBoost", 1.0)))


## Black background → alpha (an RGB picture; RGBA8 out): glow_alpha() of the brightest channel,
## the colour un-premultiplied (rgb / max(a, m)).
static func black_keyed(img: Image, cfg: Dictionary) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.get_data()
	var out := PackedByteArray()
	out.resize(w * h * 4)
	out.fill(0)
	for k in w * h:
		var i := k * 3
		var m := maxf(src[i], maxf(src[i + 1], src[i + 2])) / 255.0
		var a := glow_alpha(m, cfg)
		if a <= 0.0:
			continue
		var un := maxf(a, m)
		for c in 3:
			out[k * 4 + c] = int(round(clampf(src[i + c] / 255.0 / un, 0.0, 1.0) * 255.0))
		out[k * 4 + 3] = int(round(a * 255.0))
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


## `src` scaled down to fit into `box` keeping its aspect (never up).
static func fitted(src: Vector2, box: Vector2) -> Vector2:
	if src.x <= 0.0 or src.y <= 0.0:
		return src
	return src * minf(1.0, minf(box.x / src.x, box.y / src.y))


## Whether c is near white: every channel ≥ 1 − tol.
static func is_white(c: Color, tol: float) -> bool:
	return minf(c.r, minf(c.g, c.b)) >= 1.0 - tol


## White background → transparent (an RGB picture; RGBA8 out): a flood fill from the border over
## near-white px; the object's px touching it get alpha (1 − min channel) / soft, capped at 1,
## their colour un-mixed from the white; everything else is opaque as drawn.
static func white_keyed(img: Image, tol: float, soft: float) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var bg := PackedByteArray()
	bg.resize(w * h)
	bg.fill(0)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i := stack[-1]
		stack.remove_at(stack.size() - 1)
		if bg[i] != 0 or not is_white(img.get_pixel(i % w, i / w), tol):
			continue
		bg[i] = 1
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := y * w + x
			if bg[i] != 0:
				continue # transparent
			var c := img.get_pixel(x, y)
			var edge := (x > 0 and bg[i - 1] != 0) or (x < w - 1 and bg[i + 1] != 0) or (y > 0 and bg[i - w] != 0) or (y < h - 1 and bg[i + w] != 0)
			if not edge:
				out.set_pixel(x, y, Color(c, 1.0))
				continue
			var a := edge_alpha(c, soft)
			out.set_pixel(x, y, Color(unmix_white(c, a), a))
	return out


## The soft edge's alpha of a px mixed with the white: (1 − its darkest channel) / soft, ≤ 1.
static func edge_alpha(c: Color, soft: float) -> float:
	return clampf((1.0 - minf(c.r, minf(c.g, c.b))) / maxf(0.001, soft), 0.0, 1.0)


## The colour that, at alpha a over white, shows c.
static func unmix_white(c: Color, a: float) -> Color:
	if a <= 0.0:
		return Color(1, 1, 1)
	return Color(clampf((c.r - (1.0 - a)) / a, 0.0, 1.0), clampf((c.g - (1.0 - a)) / a, 0.0, 1.0), clampf((c.b - (1.0 - a)) / a, 0.0, 1.0))


## The generator's grey "✦" in the bottom-right corner box (box × the picture's size): the
## grey px there (not the background: at least 0.12 from it, and low saturation), when they form
## a small blob (at most box / 2 × the smaller side); {centre: [x, y], radius} or {} (none, or
## something bigger is there: then nothing is painted, give "watermark" in the config).
static func found_watermark(img: Image, bg: Color, box: float) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := int(w * (1.0 - box))
	var y0 := int(h * (1.0 - box))
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	var n := 0
	for y in range(y0, h):
		for x in range(x0, w):
			var c := img.get_pixel(x, y)
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			var diff := maxf(absf(c.r - bg.r), maxf(absf(c.g - bg.g), absf(c.b - bg.b)))
			if diff < 0.12 or mx - mn > 0.12:
				continue
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
			n += 1
	if n < 4:
		return {}
	var size := Vector2(hi - lo) + Vector2.ONE
	if maxf(size.x, size.y) > box * 0.5 * mini(w, h):
		return {}
	var c := (Vector2(lo) + Vector2(hi) + Vector2.ONE) / 2.0
	return {"centre": [c.x, c.y], "radius": size.length() / 2.0 + 3.0}


## Paints a disc of colour c (radius r round centre).
static func paint_disc(img: Image, centre: Vector2, r: float, c: Color) -> void:
	for y in range(maxi(0, int(centre.y - r)), mini(img.get_height() - 1, int(centre.y + r)) + 1):
		for x in range(maxi(0, int(centre.x - r)), mini(img.get_width() - 1, int(centre.x + r)) + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(centre) <= r:
				img.set_pixel(x, y, c)


## The rect of the px with alpha > a_min, grown by margin px (inside the picture); the whole
## picture when it is empty.
static func content_rect(img: Image, a_min: float, margin: int) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > a_min:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		return Rect2i(0, 0, w, h)
	lo = Vector2i(maxi(0, lo.x - margin), maxi(0, lo.y - margin))
	hi = Vector2i(mini(w - 1, hi.x + margin), mini(h - 1, hi.y + margin))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _save(img: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if not FileAccess.file_exists(abs_path + ".import"):
		var f := FileAccess.open(abs_path + ".import", FileAccess.WRITE)
		f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\n')
		f.close()
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("import_projectiles: cannot write %s (%s)" % [path, error_string(err)])
		return
	print("  %s  %dx%d  %.1f KB" % [path, img.get_width(), img.get_height(), FileAccess.get_file_as_bytes(abs_path).size() / 1024.0])
