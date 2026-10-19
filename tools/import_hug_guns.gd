extends SceneTree
## Imports the hug guns: the big guns a character's ready pose hugs against the chest
## (scenes/character/poses/<id>_ready.tscn, ui/art.gd hug_gun()). One picture per gun,
## art_source/weapons/hug/<kind>_<tier>.png (kind = ui/art.gd GUN_KINDS, tier = one of its
## GUN_TIERS): the gun alone, horizontal, the muzzle (warhead) pointing RIGHT, no hand grips, on a
## flat backdrop (a solid green screen). Reproducible: everything it does is in
## art_source/weapons/hug/hug.json. Runs headless (only Image is used):
##
##   $GODOT --headless --path . -s tools/import_hug_guns.gd                      # every picture there
##   $GODOT --headless --path . -s tools/import_hug_guns.gd -- bazooka_iron ...  # some of them
##
## Per picture: the backdrop keyed out (tools/import_frames.gd key_background(): the corner colour,
## soft edge, no green rim), the small detached pieces dropped (clean(): an AI sparkle), trimmed;
## the hold point (where the pose's GunSocket turns it: by default the middle of the tube, the
## centre of its bounding box with the median column middle as its height, so a sight on top does
## not lift it) and the muzzle (the right end at the tube's middle height; both may be set per gun
## in source px); scaled once (Lanczos, premultiplied colour) so the gun is `length` world px long ×
## `texPxPerWorldPx` (the held guns' 2 texture px per world px: drawn at the weapons' scale it is
## `length` world px long). Writes assets/weapons/<kind>/hug_<tier>.png (a new PNG gets an .import
## without mipmaps; an existing .import is never touched: let the editor import them) and
## assets/weapons/hug.json {source, pxPerUnit, guns {kind: {tier: {size, hold, muzzle}}}} (px in the
## PNG), keeping the entries of the guns not imported this run.
##
## hug.json: {length (world px, default for every gun), texPxPerWorldPx, worldPxPerUnit, pad,
## background (key_background() options), alphaCut, keepPieces, guns {<kind>_<tier>: {length,
## hold [x, y], muzzle [x, y] (source px)}}}.

const ImportFrames := preload("res://tools/import_frames.gd")
const ImportGuns := preload("res://tools/import_guns.gd")
const Art := preload("res://ui/art.gd")
const SRC := "res://art_source/weapons/hug/"
const CONFIG := SRC + "hug.json"
const OUT := "res://assets/weapons/"
const DATA := OUT + "hug.json"

var _written := 0
var _bytes := 0


func _initialize() -> void:
	var found := sources_for(OS.get_cmdline_user_args(), SRC)
	for name in found["unknown"]:
		push_error("import_hug_guns: no %s%s.png (a <kind>_<tier> name, kind one of %s)" % [SRC, name, Art.GUN_KINDS])
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) if FileAccess.file_exists(CONFIG) else {}
	if not cfg is Dictionary:
		push_error("import_hug_guns: %s is not a JSON object" % CONFIG)
		cfg = {}
	var old = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
	var data := {"source": CONFIG.trim_prefix("res://"),
		"pxPerUnit": snappedf(float(cfg.get("texPxPerWorldPx", 2.0)) * float(cfg.get("worldPxPerUnit", 0.35)), 0.0001),
		"guns": old["guns"] if old is Dictionary and old.get("guns") is Dictionary else {}}
	for g in found["guns"]:
		var meta := _import(cfg, g["kind"], g["tier"])
		if meta.is_empty():
			continue
		if not data["guns"].get(g["kind"]) is Dictionary:
			data["guns"][g["kind"]] = {}
		data["guns"][g["kind"]][g["tier"]] = meta
	_write_text(DATA, JSON.stringify(data, "\t", false) + "\n")
	print("import_hug_guns: wrote %d files, %.1f KB" % [_written, _bytes / 1024.0])
	quit(1 if not found["unknown"].is_empty() else 0)


## The pictures the command line names: {guns [{kind, tier, name}], unknown [names without a
## picture or not <kind>_<tier>]}; no argument: every <kind>_<tier>.png in dir (sorted).
static func sources_for(args: Array, dir: String) -> Dictionary:
	var names: Array = []
	for a in args:
		var arg := str(a).strip_edges().trim_suffix(".png")
		if arg != "":
			names.append(arg)
	var all := names.is_empty()
	if all and DirAccess.dir_exists_absolute(dir):
		var files := DirAccess.get_files_at(dir)
		files.sort()
		for f in files:
			if f.get_extension() == "png":
				names.append(f.get_basename())
	var guns: Array = []
	var unknown: Array = []
	for name in names:
		var kt := split_name(name)
		if kt.is_empty() or not FileAccess.file_exists(dir + name + ".png"):
			if not all:
				unknown.append(name)
			continue
		guns.append({"kind": kt["kind"], "tier": kt["tier"], "name": name})
	return {"guns": guns, "unknown": unknown}


## "<kind>_<tier>" (kind may hold an underscore: shock_rifle_iron) → {kind, tier}; {} when the kind
## or the tier is not one of ui/art.gd GUN_KINDS / GUN_TIERS.
static func split_name(name: String) -> Dictionary:
	var i := name.rfind("_")
	if i <= 0:
		return {}
	var kind := name.substr(0, i)
	var tier := name.substr(i + 1)
	if not Art.GUN_TIERS.has(kind) or not Art.GUN_TIERS[kind].has(tier):
		return {}
	return {"kind": kind, "tier": tier}


## Where a gun picture's tube is (straight alpha, alpha > 127 counts): {rect (the opaque bounds),
## hold (the bounds' middle x at the tube's middle height: the median of the columns' middles),
## muzzle (the right end at that height)}; {} when empty.
static func tube_points(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var px := img.get_data()
	var mids: Array[float] = []
	var x0 := w
	var x1 := -1
	var y0 := h
	var y1 := -1
	for x in w:
		var top := -1
		var bot := -1
		for y in h:
			if px[(y * w + x) * 4 + 3] > 127:
				if top < 0:
					top = y
				bot = y
		if top < 0:
			continue
		mids.append((top + bot + 1) * 0.5)
		x0 = mini(x0, x)
		x1 = maxi(x1, x)
		y0 = mini(y0, top)
		y1 = maxi(y1, bot)
	if mids.is_empty():
		return {}
	mids.sort()
	var cy: float = mids[mids.size() / 2]
	var rect := Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	return {"rect": rect, "hold": Vector2((x0 + x1 + 1) * 0.5, cy), "muzzle": Vector2(x1 + 1, cy)}


## One gun: keyed, cleaned, trimmed, scaled, written; its hug.json entry {size, hold, muzzle} (px in
## the PNG), {} on an error.
func _import(cfg: Dictionary, kind: String, tier: String) -> Dictionary:
	var name := "%s_%s" % [kind, tier]
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + name + ".png"))
	if img == null or img.is_empty():
		push_error("import_hug_guns: cannot read %s%s.png" % [SRC, name])
		return {}
	img.convert(Image.FORMAT_RGBA8)
	var own: Dictionary = cfg.get("guns", {}).get(name, {}) if cfg.get("guns") is Dictionary else {}
	var bg := ImportFrames.key_background(img, cfg.get("background", {"key": "corners"}))
	var removed := ImportFrames.clean(img, {"alphaCut": cfg.get("alphaCut", 24), "keepPieces": cfg.get("keepPieces", 0.02), "defringe": {"band": 0}})
	var tp := tube_points(img)
	if tp.is_empty():
		push_error("import_hug_guns: %s is empty after keying" % name)
		return {}
	var rect: Rect2i = img.get_used_rect()
	var hold: Vector2 = _v(own["hold"]) if own.get("hold") is Array else tp["hold"]
	var muzzle: Vector2 = _v(own["muzzle"]) if own.get("muzzle") is Array else tp["muzzle"]
	var tex_per_world := float(cfg.get("texPxPerWorldPx", 2.0))
	var s := float(own.get("length", cfg.get("length", 57.0))) * tex_per_world / float(tp["rect"].size.x) # PNG px per source px
	var pad := ceili(float(cfg.get("pad", 2)) / s)
	var from := rect.grow(pad)
	var canvas := Image.create(from.size.x, from.size.y, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(img, rect, rect.position - from.position)
	var dst := Vector2i(maxi(1, roundi(from.size.x * s)), maxi(1, roundi(from.size.y * s)))
	var k := Vector2(dst) / Vector2(from.size)
	_save(ImportGuns.scaled(canvas, dst), OUT + "%s/hug_%s.png" % [kind, tier])
	var hold_out := (hold - Vector2(from.position)) * k
	var muzzle_out := (muzzle - Vector2(from.position)) * k
	print("  %s %dx%d: backdrop %d px, removed %d stray px, gun %s, hold %s, muzzle %s source px → %s px, %.1f world px long (×%.4f)" % [
		name, img.get_width(), img.get_height(), bg, removed, rect, hold, muzzle, dst, tp["rect"].size.x * k.x / tex_per_world, s])
	return {"size": [dst.x, dst.y], "hold": [snappedf(hold_out.x, 0.1), snappedf(hold_out.y, 0.1)],
		"muzzle": [snappedf(muzzle_out.x, 0.1), snappedf(muzzle_out.y, 0.1)]}


static func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a.size() >= 2 else Vector2.ZERO


func _save(img: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if not FileAccess.file_exists(abs_path + ".import"):
		var f := FileAccess.open(abs_path + ".import", FileAccess.WRITE)
		f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=false\n')
		f.close()
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("import_hug_guns: cannot write %s (%s)" % [path, error_string(err)])
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
