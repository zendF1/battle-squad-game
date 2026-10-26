extends SceneTree
## Imports the hug guns: the big guns a character's ready pose hugs against the chest
## (scenes/character/poses/<id>_ready.tscn, ui/art.gd hug_gun()). One picture per gun,
## art_source/weapons/hug/<kind>_<tier>.png (kind = ui/art.gd GUN_KINDS, tier = one of its
## GUN_TIERS): the gun alone, horizontal, the muzzle (warhead) pointing RIGHT, no hand grips, on a
## flat backdrop (a solid green screen, or magenta: the corners' colour is the key). Reproducible:
## everything it does is in art_source/weapons/hug/hug.json. Runs headless (only Image is used):
##
##   $GODOT --headless --path . -s tools/import_hug_guns.gd                      # every picture there
##   $GODOT --headless --path . -s tools/import_hug_guns.gd -- bazooka_iron ...  # some of them
##
## Per picture: the backdrop keyed out (tools/import_frames.gd key_background(): the corner colour,
## soft edge, no green / pink rim), the small detached pieces dropped (clean(): an AI sparkle), trimmed;
## the hold point (where the pose's GunSocket turns it: by default the middle of the tube, the
## centre of its bounding box with the median column middle as its height, so a sight on top does
## not lift it) and the muzzle (the right end at the tube's middle height; both may be set per gun
## in source px); scaled once (Lanczos, premultiplied colour) so the gun is `length` world px long ×
## `texPxPerWorldPx` (the held guns' 2 texture px per world px: drawn at the weapons' scale it is
## `length` world px long). Writes assets/weapons/<kind>/hug_<tier>.png (a new PNG gets an .import
## without mipmaps; an existing .import is never touched: let the editor import them), with
## `uiLength` also assets/weapons/<kind>/ui_<tier>.png (the same canvas scaled once from the source
## so the tube is uiLength px long, an .import with mipmaps: the screens outside the match draw it
## in the match texture's place, ui/art.gd ui_gun_texture(), as they show the gun several times
## bigger than the match does) and
## assets/weapons/hug.json {source, pxPerUnit, guns {kind: {tier: {size, hold, muzzle}}}} (px in the
## PNG), keeping the entries of the guns not imported this run.
##
## The equipment icons of hug.json "icons" {files {<name with <tier>>: {gun, tiers}}} (today
## weapon_bazooka_<tier>, weapon_cannon_<tier>, weapon_launcher_<tier> and weapon_rifle_<tier>:
## Rookie's bazooka, Tanko's cannon, Flora's seed launcher and Spark's shock rifle have no held
## sprites) are made from these pictures too,
## the same look as the held guns' icons (size / margin / tiltDeg from art_source/weapons/guns_v1.json
## "icons" unless hug.json sets them; tools/import_guns.gd icons()), written to
## assets/icons/equipment/ whenever a run imports a gun of that kind.
##
## A gun with no picture of its own can be made from another tier's (hug.json guns.<kind>_<tier>
## {from: <tier>, recolour}): that tier's picture, keyed and cleaned the same way, then recoloured
## (tools/import_guns.gd recolour(): HSV multipliers / hue shift, optionally only a hue range;
## the same specs as the held guns' art_source/weapons/guns_v1.json "recolours"), so it has the
## same shape, hold and muzzle. It is imported with every run, and with its source when some guns
## are named.
##
## hug.json: {length (world px, default for every gun), texPxPerWorldPx, uiLength, worldPxPerUnit, pad,
## background (key_background() options), alphaCut, keepPieces, icons, guns {<kind>_<tier>: {length,
## hold [x, y], muzzle [x, y] (source px), background (key options over the shared ones, e.g. a
## smaller holeMin for a small enclosed pocket of backdrop; glow: a soft glow painted into the
## backdrop un-mixed from it), despill (true: despill() the whole gun, for art with none of the
## key's colour; {hueRange [lo, hi]}: only the pixels of those hues, a magenta key's specks next to
## the art's reds), from (a tier: its picture), recolour}}}.

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
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) if FileAccess.file_exists(CONFIG) else {}
	if not cfg is Dictionary:
		push_error("import_hug_guns: %s is not a JSON object" % CONFIG)
		cfg = {}
	var found := sources_for(OS.get_cmdline_user_args(), SRC, derived_of(cfg))
	for name in found["unknown"]:
		push_error("import_hug_guns: no %s%s.png (a <kind>_<tier> name, kind one of %s)" % [SRC, name, Art.GUN_KINDS])
	var old = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
	var data := {"source": CONFIG.trim_prefix("res://"),
		"pxPerUnit": snappedf(float(cfg.get("texPxPerWorldPx", 2.0)) * float(cfg.get("worldPxPerUnit", 0.35)), 0.0001),
		"guns": kept_guns(old)}
	var done := {} # <kind>_<tier> -> prepared(): the icons reuse them
	var kinds: Array = []
	for g in found["guns"]:
		done[g["name"]] = prepared(cfg, g["kind"], g["tier"], g["source"])
		var meta := _import(cfg, g["kind"], g["tier"], g["source"], done[g["name"]]) if not done[g["name"]].is_empty() else {}
		if meta.is_empty():
			continue
		if not kinds.has(g["kind"]):
			kinds.append(g["kind"])
		if not data["guns"].get(g["kind"]) is Dictionary:
			data["guns"][g["kind"]] = {}
		data["guns"][g["kind"]][g["tier"]] = meta
	_write_text(DATA, JSON.stringify(data, "\t", false) + "\n")
	_icons(cfg, kinds, done, derived_of(cfg))
	print("import_hug_guns: wrote %d files, %.1f KB" % [_written, _bytes / 1024.0])
	quit(1 if not found["unknown"].is_empty() else 0)


## The entries of an earlier assets/weapons/hug.json (parsed) kept for the guns not imported this
## run: {kind: {tier: {size, hold, muzzle}}}, sizes back to whole px (JSON numbers parse as
## floats: written again they would read 118.0).
static func kept_guns(old: Variant) -> Dictionary:
	var guns = old.get("guns") if old is Dictionary else null
	if not guns is Dictionary:
		return {}
	for kind in guns:
		if not guns[kind] is Dictionary:
			continue
		for tier in guns[kind]:
			var e = guns[kind][tier]
			if e is Dictionary and e.get("size") is Array:
				e["size"] = e["size"].map(func(v): return int(v) if (v is float or v is int) else v)
	return guns


## The guns hug.json makes from another tier's picture: {<kind>_<tier>: <kind>_<from tier>} (only
## valid <kind>_<tier> names and from tiers of the same kind).
static func derived_of(cfg: Dictionary) -> Dictionary:
	var out := {}
	var guns = cfg.get("guns")
	if not guns is Dictionary:
		return out
	for name in guns:
		var e = guns[name]
		var kt := split_name(str(name))
		if not e is Dictionary or str(e.get("from", "")) == "" or kt.is_empty():
			continue
		if not Art.GUN_TIERS[kt["kind"]].has(str(e["from"])) or str(e["from"]) == kt["tier"]:
			continue
		out[str(name)] = "%s_%s" % [kt["kind"], e["from"]]
	return out


## The pictures the command line names: {guns [{kind, tier, name, source (the picture's name:
## name, or the source of a derived gun)}], unknown [names without a picture or not
## <kind>_<tier>]}; no argument: every <kind>_<tier>.png in dir (sorted) and every derived gun
## (derived_of(): {name: source name}) whose source picture is there. Naming a picture also takes
## the guns derived from it.
static func sources_for(args: Array, dir: String, derived: Dictionary = {}) -> Dictionary:
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
	var keys := derived.keys()
	keys.sort()
	for d in keys:
		if not names.has(d) and (all or names.has(derived[d])):
			names.append(d)
	var guns: Array = []
	var unknown: Array = []
	for name in names:
		var kt := split_name(name)
		var source := str(derived.get(name, name))
		if kt.is_empty() or not FileAccess.file_exists(dir + source + ".png"):
			if not all:
				unknown.append(name)
			continue
		guns.append({"kind": kt["kind"], "tier": kt["tier"], "name": name, "source": source})
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


## One gun's picture made ready (from the picture `source`: its own, or the tier it is derived
## from): keyed, cleaned, recoloured (a derived gun): {image (straight alpha, source px), rect (its
## opaque bounds), tube (tube_points(): of the solid gun, a kept glow left out), canvas (a gun with
## a kept glow: the source px its PNG is cut from, else an empty rect), hold, muzzle (source px),
## length (world px), keyed (backdrop px), removed (stray px)}; {} on an error. _import() and the
## icons start from it.
static func prepared(cfg: Dictionary, kind: String, tier: String, source: String = "") -> Dictionary:
	var name := "%s_%s" % [kind, tier]
	if source == "":
		source = name
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + source + ".png"))
	if img == null or img.is_empty():
		push_error("import_hug_guns: cannot read %s%s.png" % [SRC, source])
		return {}
	img.convert(Image.FORMAT_RGBA8)
	var guns_cfg: Dictionary = cfg["guns"] if cfg.get("guns") is Dictionary else {}
	var own: Dictionary = guns_cfg.get(name, {}) if guns_cfg.get(name) is Dictionary else {}
	if source != name and guns_cfg.get(source) is Dictionary: # the source's length / hold / muzzle, unless its own
		var merged: Dictionary = guns_cfg[source].duplicate()
		merged.merge(own, true)
		own = merged
	var key: Dictionary = (cfg["background"] if cfg.get("background") is Dictionary else {"key": "corners"}).duplicate()
	if own.get("background") is Dictionary: # this picture's own key options over the shared ones
		key.merge(own["background"], true)
	var src := img.duplicate() as Image
	var k := _keyed(img, key, own, cfg)
	if source != name and own.get("recolour") is Dictionary:
		ImportGuns.recolour(img, own["recolour"])
	var tp := tube_points(img)
	if tp.is_empty():
		push_error("import_hug_guns: %s is empty after keying" % name)
		return {}
	var length := float(own.get("length", cfg.get("length", 57.0)))
	var canvas := Rect2i()
	if key.get("glow") is Dictionary and float(key["glow"].get("alpha", 1.0)) > 0.0:
		# A kept glow is not the gun: measured without it (the tube as long as the other tiers'),
		# faded out over the pad round the solid gun, the canvas the solid gun + the pad.
		var bare_key := key.duplicate(true)
		bare_key["glow"]["alpha"] = 0.0
		var solid := tube_points(_keyed(src, bare_key, own, cfg)["image"])
		if not solid.is_empty():
			tp = solid
			var pad_src := ceili(float(cfg.get("pad", 2)) / (length * float(cfg.get("texPxPerWorldPx", 2.0)) / float(tp["rect"].size.x)))
			fade_outside(img, tp["rect"], pad_src)
			canvas = tp["rect"].grow(pad_src)
	return {"image": img, "rect": img.get_used_rect(), "tube": tp, "canvas": canvas,
		"hold": _v(own["hold"]) if own.get("hold") is Array else tp["hold"],
		"muzzle": _v(own["muzzle"]) if own.get("muzzle") is Array else tp["muzzle"],
		"length": length, "keyed": k["keyed"], "removed": k["removed"]}


## A picture keyed in place (key_background() with the key options, despill, clean()): {image,
## keyed (backdrop px), removed (stray px)}.
static func _keyed(img: Image, key: Dictionary, own: Dictionary, cfg: Dictionary) -> Dictionary:
	var kc := ImportFrames.corner_colour(img, int(key.get("corner", 8)))
	var bg := ImportFrames.key_background(img, key)
	var ds = own.get("despill", false)
	if ds is Dictionary or (ds is bool and ds):
		var chans := ImportFrames.key_channels(kc)
		var hues = ds.get("hueRange") if ds is Dictionary else null
		despill(img, chans[0], chans[1] if chans.size() > 1 else -1, _v(hues) if hues is Array else Vector2(-1, -1))
	var removed := ImportFrames.clean(img, {"alphaCut": cfg.get("alphaCut", 24), "keepPieces": cfg.get("keepPieces", 0.02), "defringe": {"band": 0}})
	return {"image": img, "keyed": bg, "removed": removed}


## Alpha outside rect faded to nothing over `band` px (the farther of the x / y distances), in
## place: a glow round the gun ends softly at the canvas edge.
static func fade_outside(img: Image, rect: Rect2i, band: int) -> void:
	var w := img.get_width()
	var px := img.get_data()
	for o in range(0, px.size(), 4):
		if px[o + 3] == 0:
			continue
		var x := (o / 4) % w
		var y := (o / 4) / w
		var d := maxi(maxi(rect.position.x - x, x - (rect.end.x - 1)), maxi(rect.position.y - y, y - (rect.end.y - 1)))
		if d > 0:
			px[o + 3] = roundi(px[o + 3] * clampf(1.0 - float(d) / float(maxi(1, band)), 0.0, 1.0))
	img.set_data(w, img.get_height(), false, Image.FORMAT_RGBA8, px)


## One gun (prepared()): trimmed, scaled, written; its hug.json entry {size, hold, muzzle} (px in
## the PNG), {} on an error.
func _import(cfg: Dictionary, kind: String, tier: String, source: String = "", p: Dictionary = {}) -> Dictionary:
	var name := "%s_%s" % [kind, tier]
	if source == "":
		source = name
	if p.is_empty():
		p = prepared(cfg, kind, tier, source)
	if p.is_empty():
		return {}
	var img: Image = p["image"]
	var tp: Dictionary = p["tube"]
	var rect: Rect2i = p["rect"]
	var hold: Vector2 = p["hold"]
	var muzzle: Vector2 = p["muzzle"]
	var tex_per_world := float(cfg.get("texPxPerWorldPx", 2.0))
	var s := float(p["length"]) * tex_per_world / float(tp["rect"].size.x) # PNG px per source px
	var pad := ceili(float(cfg.get("pad", 2)) / s)
	var from: Rect2i = p["canvas"] if p.get("canvas", Rect2i()) != Rect2i() else rect.grow(pad)
	var canvas := Image.create(from.size.x, from.size.y, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(img, rect, rect.position - from.position)
	var dst := Vector2i(maxi(1, roundi(from.size.x * s)), maxi(1, roundi(from.size.y * s)))
	var k := Vector2(dst) / Vector2(from.size)
	_save(ImportGuns.scaled(canvas, dst), OUT + "%s/hug_%s.png" % [kind, tier], false)
	if cfg.has("uiLength"): # the screens outside the match: the same canvas, the tube uiLength px long
		var su := float(cfg["uiLength"]) / float(tp["rect"].size.x)
		var dst_ui := Vector2i(maxi(1, roundi(from.size.x * su)), maxi(1, roundi(from.size.y * su)))
		_save(ImportGuns.scaled(canvas, dst_ui), OUT + "%s/ui_%s.png" % [kind, tier], true)
	var hold_out := (hold - Vector2(from.position)) * k
	var muzzle_out := (muzzle - Vector2(from.position)) * k
	print("  %s%s %dx%d: backdrop %d px, removed %d stray px, gun %s, hold %s, muzzle %s source px → %s px, %.1f world px long (×%.4f)" % [
		name, " (from %s)" % source if source != name else "", img.get_width(), img.get_height(), p["keyed"], p["removed"], rect, hold, muzzle, dst, tp["rect"].size.x * k.x / tex_per_world, s])
	return {"size": [dst.x, dst.y], "hold": [snappedf(hold_out.x, 0.1), snappedf(hold_out.y, 0.1)],
		"muzzle": [snappedf(muzzle_out.x, 0.1), snappedf(muzzle_out.y, 0.1)]}


## The icon settings (hug.json "icons" over the held guns' art_source/weapons/guns_v1.json "icons":
## size, margin, tiltDeg; the same look as the other weapon icons) and hug.json's icon files
## {<name with <tier>>: {gun (a kind), tiers}}.
static func icon_config(cfg: Dictionary, held_cfg: Dictionary) -> Dictionary:
	var out := {}
	var held = held_cfg.get("icons")
	for key in ["size", "margin", "tiltDeg"]:
		if held is Dictionary and held.has(key):
			out[key] = held[key]
	var own = cfg.get("icons")
	if own is Dictionary:
		for key in own:
			if not str(key).begins_with("_"):
				out[key] = own[key]
	if not out.get("files") is Dictionary:
		out["files"] = {}
	return out


## The canvases a file group's icons are made from (tools/import_guns.gd icons() wants every tier at
## the same resolution, lined up): {tier: Image}; each prepared() picture trimmed and scaled at
## source resolution (Lanczos) so its tube is as long as the first tier's (a tier swap does not
## resize the icon's gun), its hold point at the same canvas px.
static func icon_canvases(pics: Dictionary, tiers: Array) -> Dictionary:
	var ref_len := float(pics[tiers[0]]["tube"]["rect"].size.x)
	var parts := {} # tier -> {image, at (top-left from the hold)}
	var u := Rect2()
	for tier in tiers:
		var p: Dictionary = pics[tier]
		var img: Image = p["image"]
		var rect: Rect2i = p["rect"].grow(2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var n := ref_len / float(p["tube"]["rect"].size.x)
		var part := img.get_region(rect)
		var dst := Vector2i(maxi(1, roundi(rect.size.x * n)), maxi(1, roundi(rect.size.y * n)))
		if dst != rect.size:
			part = ImportGuns.scaled(part, dst)
		var k := Vector2(dst) / Vector2(rect.size)
		var at: Vector2 = (Vector2(rect.position) - p["hold"]) * k
		parts[tier] = {"image": part, "at": at}
		var r := Rect2(at, Vector2(dst))
		u = r if u.size == Vector2.ZERO else u.merge(r)
	var size := Vector2i(ceili(u.size.x) + 1, ceili(u.size.y) + 1)
	var out := {}
	for tier in tiers:
		var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		var part: Image = parts[tier]["image"]
		canvas.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i((parts[tier]["at"] - u.position).round()))
		out[tier] = canvas
	return out


## The equipment icons of the kinds imported this run (icon_config() files): every tier of a file
## group prepared (done: name -> prepared() of this run's guns, reused), icon_canvases(),
## tools/import_guns.gd icons(), written to assets/icons/equipment/ (a new PNG gets an .import with
## mipmaps, as the other icons).
func _icons(cfg: Dictionary, kinds: Array, done: Dictionary, derived: Dictionary) -> void:
	var held = JSON.parse_string(FileAccess.get_file_as_string(ImportGuns.CONFIG)) if FileAccess.file_exists(ImportGuns.CONFIG) else {}
	var ic := icon_config(cfg, held if held is Dictionary else {})
	for pattern in ic["files"]:
		var f = ic["files"][pattern]
		if not f is Dictionary or not kinds.has(str(f.get("gun", ""))) or not f.get("tiers") is Array or f["tiers"].is_empty():
			continue
		var kind := str(f["gun"])
		var got := {}
		for tier in f["tiers"]:
			var name := "%s_%s" % [kind, tier]
			if not done.has(name):
				var source := str(derived.get(name, name))
				done[name] = prepared(cfg, kind, str(tier), source) if FileAccess.file_exists(SRC + source + ".png") else {}
			if done[name].is_empty():
				push_error("import_hug_guns: icons %s: no %s picture" % [pattern, name])
				break
			got[tier] = done[name]
		if got.size() != f["tiers"].size():
			continue
		var icons := ImportGuns.icons(icon_canvases(got, f["tiers"]), f["tiers"], ic)
		for tier in f["tiers"]:
			_save(icons[tier], ImportGuns.ICONS + str(pattern).replace("<tier>", str(tier)) + ".png", true)


## The key's channel (0 r, 1 g, 2 b) capped at the larger of the other two on every pixel, in place
## (hug.json "despill": a gun with none of the key's colour in its art: no backdrop tint left in
## a pocket the key could not reach); with a second channel (a magenta key: 0 and 2,
## tools/import_frames.gd key_channels()) both are lowered by the part of them above the third
## instead (a pink tint turns grey). hues [lo, hi] (degrees, lo ≥ 0): only the pixels of those
## hues (a magenta key: its purple / magenta specks, not the art's reds and crimsons). Returns how
## many pixels changed.
static func despill(img: Image, channel: int, second: int = -1, hues: Vector2 = Vector2(-1, -1)) -> int:
	var px := img.get_data()
	var changed := 0
	for o in range(0, px.size(), 4):
		if px[o + 3] == 0:
			continue
		if hues.x >= 0.0:
			var h := Color8(px[o], px[o + 1], px[o + 2]).h * 360.0
			if h < hues.x or h > hues.y:
				continue
		if second >= 0:
			var excess := mini(px[o + channel], px[o + second]) - px[o + 3 - channel - second]
			if excess > 0:
				px[o + channel] -= excess
				px[o + second] -= excess
				changed += 1
			continue
		var cap := maxi(px[o + (channel + 1) % 3], px[o + (channel + 2) % 3])
		if px[o + channel] > cap:
			px[o + channel] = cap
			changed += 1
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, px)
	return changed


static func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a.size() >= 2 else Vector2.ZERO


func _save(img: Image, path: String, mipmaps: bool) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if not FileAccess.file_exists(abs_path + ".import"):
		var f := FileAccess.open(abs_path + ".import", FileAccess.WRITE)
		f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=%s\n' % ("true" if mipmaps else "false"))
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
