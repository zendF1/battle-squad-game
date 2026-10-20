extends SceneTree
## Imports the weapon milestone back auras (scenes/character/back_aura.gd): the AI-drawn rings,
## art_source/fx/back_aura_<colour>.png (purple: +14, red: +16), drawn on black with no alpha.
## Reproducible: everything it does is in art_source/fx/back_aura.json. Runs headless (only Image
## is used; the editor may stay open):
##
##   $GODOT --headless --path . -s tools/import_back_aura.gd
##
## Per picture, in source px: the generator's grey "✦" watermark faded to black (a disc around
## `watermark.centre`: black inside `inner`, blended back to the picture at `outer`; it sits in the
## empty bottom-right corner, away from the ring and the red one's rays); scaled once to `size`
## (Lanczos: the picture over black IS premultiplied colour, so scaling it before keying makes no
## dark fringe); then black → transparency: alpha from the brightest channel m = max(r, g, b),
## curved, a = clamp((m − alphaFloor) / (1 − alphaFloor))^alphaGamma (the near-black haze and the
## generator's noise go fully transparent: no grey box on a bright sky), the colour un-premultiplied
## (rgb / m: the hue and saturation of the art, a red stays red, no pink / grey shift), and the
## outer `edgeFade` px faded so a ray never ends on a hard texture edge. Drawn with normal blending.
## Writes assets/fx/back_aura_<colour>.png (a new PNG gets an .import with mipmaps, an existing
## .import is never touched: let the editor import them; until then ui/art.gd reads the PNG).

const SRC := "res://art_source/fx/"
const CONFIG := SRC + "back_aura.json"
const OUT := "res://assets/fx/"


func _initialize() -> void:
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if not cfg is Dictionary:
		push_error("import_back_aura: %s is not a JSON object" % CONFIG)
		quit(1)
		return
	for colour in cfg["auras"]:
		var a: Dictionary = cfg["auras"][colour]
		var src := Image.load_from_file(ProjectSettings.globalize_path(SRC + str(a["source"])))
		if src == null or src.is_empty():
			push_error("import_back_aura: cannot read %s%s" % [SRC, a["source"]])
			continue
		var img := processed(src, cfg, a)
		_save(img, OUT + "back_aura_%s.png" % colour)
	quit(0)


## The picture keyed: watermark removed, scaled, black → alpha (see the header).
static func processed(src: Image, cfg: Dictionary, opts: Dictionary) -> Image:
	var watermark: Dictionary = opts.get("watermark", {})
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGB8)
	if not watermark.is_empty():
		remove_watermark(img, Vector2(watermark["centre"][0], watermark["centre"][1]), float(watermark["inner"]), float(watermark["outer"]))
	var size := int(cfg.get("size", 512))
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return keyed(img, float(cfg.get("alphaFloor", 0.035)), float(cfg.get("alphaGamma", 1.25)), float(cfg.get("alphaBoost", 1.0)),
		int(cfg.get("edgeFade", 12)), int(opts.get("outline", 0)), float(opts.get("outlineAlpha", 0.0)))


## Fades a disc to black: black within `inner` px of c, the picture again from `outer`.
static func remove_watermark(img: Image, c: Vector2, inner: float, outer: float) -> void:
	var x0 := maxi(0, int(c.x - outer))
	var y0 := maxi(0, int(c.y - outer))
	var x1 := mini(img.get_width() - 1, int(c.x + outer))
	var y1 := mini(img.get_height() - 1, int(c.y + outer))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d >= outer:
				continue
			var keep := smoothstep(inner, outer, d)
			var p := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(p.r * keep, p.g * keep, p.b * keep))


## Black → alpha on an RGB picture over black (see the header); RGBA8 out. outline > 0: the
## black outlines drawn round the art's shapes are kept as dark strokes (a px within `outline` px of
## a stronger one gets at least outlineAlpha × that alpha, its colour darkened to match: over black
## it is the same picture, over a bright sky the strokes stay dark instead of letting it through).
static func keyed(img: Image, floor_: float, gamma: float, boost: float, edge: int, outline: int = 0, outline_alpha: float = 0.0) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.get_data()
	var alpha := PackedFloat32Array()
	alpha.resize(w * h)
	for y in h:
		for x in w:
			var i := (y * w + x) * 3
			var m := maxf(src[i], maxf(src[i + 1], src[i + 2])) / 255.0
			var a := minf(1.0, pow(clampf((m - floor_) / (1.0 - floor_), 0.0, 1.0), gamma) * boost)
			if edge > 0:
				var e := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
				a *= smoothstep(0.0, float(edge), float(e))
			alpha[y * w + x] = a
	if outline > 0 and outline_alpha > 0.0:
		var near := _dilated(alpha, w, h, outline)
		for k in alpha.size():
			alpha[k] = maxf(alpha[k], near[k] * outline_alpha)
	var out := PackedByteArray()
	out.resize(w * h * 4)
	for k in alpha.size():
		var a := alpha[k]
		if a <= 0.0:
			continue # transparent black
		var i := k * 3
		var un := maxf(a, maxf(src[i], maxf(src[i + 1], src[i + 2])) / 255.0) # colour = rgb / un ≤ 1
		out[k * 4] = int(round(clampf(src[i] / 255.0 / un, 0.0, 1.0) * 255.0))
		out[k * 4 + 1] = int(round(clampf(src[i + 1] / 255.0 / un, 0.0, 1.0) * 255.0))
		out[k * 4 + 2] = int(round(clampf(src[i + 2] / 255.0 / un, 0.0, 1.0) * 255.0))
		out[k * 4 + 3] = int(round(a * 255.0))
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


## The largest value within r px (a square window: rows, then columns).
static func _dilated(v: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var rows := PackedFloat32Array()
	rows.resize(v.size())
	for y in h:
		for x in w:
			var best := 0.0
			for dx in range(maxi(0, x - r), mini(w - 1, x + r) + 1):
				best = maxf(best, v[y * w + dx])
			rows[y * w + x] = best
	var out := PackedFloat32Array()
	out.resize(v.size())
	for y in h:
		for x in w:
			var best := 0.0
			for dy in range(maxi(0, y - r), mini(h - 1, y + r) + 1):
				best = maxf(best, rows[dy * w + x])
			out[y * w + x] = best
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
		push_error("import_back_aura: cannot write %s (%s)" % [path, error_string(err)])
		return
	print("  %s  %dx%d  %.1f KB" % [path, img.get_width(), img.get_height(), FileAccess.get_file_as_bytes(abs_path).size() / 1024.0])
