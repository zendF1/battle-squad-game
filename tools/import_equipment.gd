extends SceneTree
## Imports the AI-drawn equipment sheets into the equipment icons (everything but the weapons):
## one sheet per tier, art_source/equipment/<tier>.png (tier = ui/art.gd EQUIP_TIERS), every sheet
## the same layout: the items in one row on a flat backdrop (solid magenta; the corners' colour is
## the key), left → right as art_source/equipment/equipment.json "items" says (helmet, armor,
## gloves, pants, boots). Reproducible: everything it does is in equipment.json. Runs headless
## (only Image is used):
##
##   $GODOT --headless --path . -s tools/import_equipment.gd
##
## Per sheet: the backdrop keyed out (tools/import_frames.gd key_background(): the corner colour,
## soft edge, no pink rim; the enclosed pockets of backdrop between the pants legs, inside the
## helmet straps, between fingers / boots are holes of at least `holeMin` px, the art's own colours
## are far from the key and stay), the purple-tinted outline px despilled (tools/import_hug_guns.gd
## despill() on the `despill.hueRange` hues), faint px cleared (alphaCut); then split(): the
## connected pieces (8-connected), the big ones (≥ `split.anchor` × the largest: an item's body)
## grouped into items by their columns (pieces whose x ranges overlap or are at most `split.gap` empty px columns apart
## are one item: two gloves, two boots), the small ones joined to the item whose box (grown by
## `split.join` px) they touch (a strap end, a stud) and dropped otherwise (the AI "✦" sparkle,
## stray specks). There must be as many items as "items" names (else `split.cuts`, the x of the
## n − 1 boundaries in sheet px, sorts the big pieces by their middle instead).
## Per slot: fit(): every tier's item on one canvas in sheet px (the sheets share the layout, so a
## tier keeps its place), the union of the tiers fitted into `size` − 2 × `margin` (one scale per
## slot: the largest tier fits, the tiers do not jump in size or place), centred, scaled once
## (Lanczos, premultiplied colour: tools/import_guns.gd scaled()); then the tier's sparkles (white
## four-point stars in px of a 128 px icon, scaled to `size`, as the old painted icons had: `sparkles` {tier: {stars [[x, y, r]],
## colour [r, g, b, a], slots (default every item)}}).
## Writes assets/icons/equipment/<slot>_<tier>.png (the names ui/art.gd equipment_icon_path()
## reads: every screen shows them, no code change; a new PNG gets an .import with mipmaps, an
## existing one is never touched: let the editor import them). tools/bake_art.gd skips the
## code-drawn icons of the slots imported here (imported_slots()).

const ImportFrames := preload("res://tools/import_frames.gd")
const ImportGuns := preload("res://tools/import_guns.gd")
const ImportHugGuns := preload("res://tools/import_hug_guns.gd")
const Art := preload("res://ui/art.gd")
const SRC := "res://art_source/equipment/"
const CONFIG := SRC + "equipment.json"
const OUT := "res://assets/icons/equipment/"
## The icon size the sparkles' stars and nudge (equipment.json "sparkles", from the old painted
## 128 px icons) are given for: scaled to the icon's `size`.
const SPARKLE_ICON_PX := 128.0

var _written := 0
var _bytes := 0


func _initialize() -> void:
	var cfg := load_config()
	var items := items_of(cfg)
	if items.is_empty():
		push_error("import_equipment: %s has no valid \"items\" (slots of %s)" % [CONFIG, Art.EQUIP_SLOTS])
		quit(1)
		return
	var failed := false
	var parts := {} # slot -> {tier: {image, rect}}
	for slot in items:
		parts[slot] = {}
	for tier in Art.EQUIP_TIERS:
		var path: String = SRC + tier + ".png"
		if not FileAccess.file_exists(path):
			print("  %s: no sheet, the icons stay" % path)
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null or img.is_empty():
			push_error("import_equipment: cannot read %s" % path)
			failed = true
			continue
		var k := keyed(img, cfg)
		var split_cfg: Dictionary = cfg["split"] if cfg.get("split") is Dictionary else {}
		var got := split(img, items.size(), split_cfg)
		if got["items"].size() != items.size():
			push_error("import_equipment: %s: %d items, want %d (%s): set split.cuts" % [path, got["items"].size(), items.size(), items])
			failed = true
			continue
		var line := []
		for i in items.size():
			parts[items[i]][tier] = got["items"][i]
			line.append("%s %s" % [items[i], got["items"][i]["rect"]])
		print("  %s %dx%d: backdrop %d px, removed %d stray px (%d pieces); %s" % [path, img.get_width(), img.get_height(),
			k["keyed"], k["removed"] + got["dropped"], got["droppedPieces"], ", ".join(line)])
	var size := int(cfg.get("size", Art.EQUIP_ICON_SIZE.x))
	for slot in items:
		if parts[slot].is_empty():
			continue
		var fitted := fit(parts[slot], size, int(cfg.get("margin", 6)))
		print("  %s: tiers %s in %s sheet px → %s px (×%.4f)" % [slot, fitted["tiers"], fitted["union"], fitted["size"], fitted["scale"]])
		for tier in fitted["icons"]:
			var icon: Image = fitted["icons"][tier]
			add_sparkles(icon, slot, tier, cfg)
			_save(icon, Art.equipment_icon_path(slot, tier))
	print("import_equipment: wrote %d files, %.1f KB" % [_written, _bytes / 1024.0])
	quit(1 if failed else 0)


## art_source/equipment/equipment.json parsed ({} when missing or not an object).
static func load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG):
		return {}
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	return cfg if cfg is Dictionary else {}


## The config's "items" (left → right on a sheet) when every one is an equipment slot (not the
## weapon: the guns have their own tools), else [].
static func items_of(cfg: Dictionary) -> Array:
	var items = cfg.get("items")
	if not items is Array or items.is_empty():
		return []
	var out: Array = []
	for s in items:
		if not Art.EQUIP_SLOTS.has(str(s)) or str(s) == "weapon" or out.has(str(s)):
			return []
		out.append(str(s))
	return out


## The slots whose icons are imported art (tools/bake_art.gd does not bake them): the config's
## items while it and at least one sheet exist.
static func imported_slots() -> Array:
	for tier in Art.EQUIP_TIERS:
		if FileAccess.file_exists(SRC + tier + ".png"):
			return items_of(load_config())
	return []


## A sheet keyed in place (key_background() with cfg "background", despill() on cfg
## "despill.hueRange", alphaCut): {keyed (backdrop px), removed (faint px cleared)}.
static func keyed(img: Image, cfg: Dictionary) -> Dictionary:
	img.convert(Image.FORMAT_RGBA8)
	var key: Dictionary = cfg["background"] if cfg.get("background") is Dictionary else {"key": "corners"}
	var kc := ImportFrames.corner_colour(img, int(key.get("corner", 8)))
	var bg := ImportFrames.key_background(img, key)
	var ds = cfg.get("despill")
	if ds is Dictionary:
		var chans := ImportFrames.key_channels(kc)
		if not chans.is_empty():
			var hues = ds.get("hueRange")
			ImportHugGuns.despill(img, chans[0], chans[1] if chans.size() > 1 else -1,
				Vector2(float(hues[0]), float(hues[1])) if hues is Array and hues.size() >= 2 else Vector2(-1, -1))
	var removed := ImportFrames.clean(img, {"alphaCut": cfg.get("alphaCut", 24), "keepPieces": 0.0, "defringe": {"band": 0}})
	return {"keyed": bg, "removed": removed}


## A keyed sheet (straight alpha) split into its n items, left → right: {items [{image (the item
## alone, cropped to rect), rect (sheet px)}], dropped (px of the pieces left out), droppedPieces}.
## The pieces (alpha > 0, 8-connected) of at least anchor × the largest are grouped by column
## (x ranges overlapping or at most gap empty px columns apart; or, with cuts [x, ...], by their middle between those
## x); every smaller piece joins the item whose box grown by join px it touches (the nearest
## middle) or is dropped. items has another size than n when the columns do not come out as n.
static func split(img: Image, n: int, cfg: Dictionary = {}) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var px := img.get_data()
	var count := w * h
	var label := PackedInt32Array()
	label.resize(count)
	var pieces: Array = [] # {size, rect}
	var stack := PackedInt32Array()
	stack.resize(count)
	for s in count:
		if px[s * 4 + 3] == 0 or label[s] != 0:
			continue
		var id := pieces.size() + 1
		var size := 0
		var x0 := w
		var y0 := h
		var x1 := -1
		var y1 := -1
		var top := 1
		stack[0] = s
		label[s] = id
		while top > 0:
			top -= 1
			var i: int = stack[top]
			size += 1
			var x := i % w
			var y := i / w
			x0 = mini(x0, x)
			x1 = maxi(x1, x)
			y0 = mini(y0, y)
			y1 = maxi(y1, y)
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
						stack[top] = j
						top += 1
		pieces.append({"size": size, "rect": Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)})
	var largest := 0
	for p in pieces:
		largest = maxi(largest, p["size"])
	var anchor := float(cfg.get("anchor", 0.05)) * largest
	var gap := int(cfg.get("gap", 2))
	var join := int(cfg.get("join", 8))
	var cuts: Array = cfg.get("cuts", []) if cfg.get("cuts") is Array else []
	# The items: groups of big pieces, each {rect, ids}.
	var groups: Array = []
	var order: Array = []
	for i in pieces.size():
		if pieces[i]["size"] >= anchor and pieces[i]["size"] > 0:
			order.append(i)
	order.sort_custom(func(a, b): return pieces[a]["rect"].position.x < pieces[b]["rect"].position.x)
	if not cuts.is_empty():
		for k in cuts.size() + 1:
			groups.append({"rect": Rect2i(), "ids": []})
		for i in order:
			var r: Rect2i = pieces[i]["rect"]
			var mid := r.position.x + r.size.x * 0.5
			var k := 0
			while k < cuts.size() and mid >= float(cuts[k]):
				k += 1
			_add(groups[k], i + 1, r)
		groups = groups.filter(func(g): return not g["ids"].is_empty())
	else:
		for i in order:
			var r: Rect2i = pieces[i]["rect"]
			if not groups.is_empty() and r.position.x <= groups[-1]["rect"].end.x + gap:
				_add(groups[-1], i + 1, r)
			else:
				groups.append({"rect": r, "ids": [i + 1]})
	# The small pieces: joined to the item they touch, or dropped.
	var keep := PackedInt32Array() # piece id -> group index + 1 (0: dropped)
	keep.resize(pieces.size() + 1)
	for g in groups.size():
		for id in groups[g]["ids"]:
			keep[id] = g + 1
	var dropped := 0
	var dropped_pieces := 0
	for i in pieces.size():
		if keep[i + 1] != 0:
			continue
		var r: Rect2i = pieces[i]["rect"]
		var best := -1
		var best_d := INF
		for g in groups.size():
			var gr: Rect2i = groups[g]["rect"]
			if not gr.grow(join).intersects(r):
				continue
			var d := (Vector2(gr.get_center()) - Vector2(r.get_center())).length()
			if d < best_d:
				best_d = d
				best = g
		if best < 0:
			dropped += pieces[i]["size"]
			dropped_pieces += 1
			continue
		keep[i + 1] = best + 1
	for i in pieces.size(): # a joined piece widens its item's box after the joining (no chains)
		if keep[i + 1] != 0 and not groups[keep[i + 1] - 1]["ids"].has(i + 1):
			_add(groups[keep[i + 1] - 1], i + 1, pieces[i]["rect"])
	var items: Array = []
	for g in groups.size():
		var r: Rect2i = groups[g]["rect"]
		var out := PackedByteArray()
		out.resize(r.size.x * r.size.y * 4)
		for y in r.size.y:
			for x in r.size.x:
				var i := (r.position.y + y) * w + r.position.x + x
				if label[i] != 0 and keep[label[i]] == g + 1:
					var o := (y * r.size.x + x) * 4
					for c in 4:
						out[o + c] = px[i * 4 + c]
		items.append({"image": Image.create_from_data(r.size.x, r.size.y, false, Image.FORMAT_RGBA8, out), "rect": r})
	if items.size() != n:
		push_warning("import_equipment: split into %d items, want %d" % [items.size(), n])
	return {"items": items, "dropped": dropped, "droppedPieces": dropped_pieces}


static func _add(group: Dictionary, id: int, r: Rect2i) -> void:
	group["ids"].append(id)
	group["rect"] = r if group["rect"].size == Vector2i.ZERO else group["rect"].merge(r)


## One slot's icons from its tiers' items {tier: {image, rect (sheet px)}}: the union of the rects
## fitted into size − 2 × margin (one scale for every tier), each tier on that union canvas at its
## own sheet place, scaled once and centred in a size² icon: {icons {tier: Image}, tiers, union,
## size (the scaled union, px), scale}.
static func fit(parts: Dictionary, size: int, margin: int) -> Dictionary:
	var tiers: Array = []
	for tier in Art.EQUIP_TIERS: # in tier order (any other names after)
		if parts.has(tier):
			tiers.append(tier)
	for tier in parts:
		if not tiers.has(tier):
			tiers.append(tier)
	var u := Rect2i()
	for tier in tiers:
		var r: Rect2i = parts[tier]["rect"]
		u = r if u.size == Vector2i.ZERO else u.merge(r)
	var box := float(size - 2 * margin)
	var s := minf(box / u.size.x, box / u.size.y)
	var dst := Vector2i(maxi(1, roundi(u.size.x * s)), maxi(1, roundi(u.size.y * s)))
	var icons := {}
	for tier in tiers:
		var part: Image = parts[tier]["image"]
		var canvas := Image.create(u.size.x, u.size.y, false, Image.FORMAT_RGBA8)
		canvas.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), parts[tier]["rect"].position - u.position)
		var small := ImportGuns.scaled(canvas, dst)
		var icon := Image.create(size, size, false, Image.FORMAT_RGBA8)
		icon.blit_rect(small, Rect2i(Vector2i.ZERO, dst), (Vector2i(size, size) - dst) / 2)
		icons[tier] = icon
	return {"icons": icons, "tiers": tiers, "union": u, "size": dst, "scale": s}


## The tier's sparkles (cfg "sparkles" {tier: {stars [[x, y, r]] icon px, colour [r, g, b, a]
## 0..255 (default white), slots (default every one)}}) drawn over the icon, in place.
static func add_sparkles(img: Image, slot: String, tier: String, cfg: Dictionary) -> void:
	var all = cfg.get("sparkles")
	var sp = all.get(tier) if all is Dictionary else null
	if not sp is Dictionary:
		return
	if sp.get("slots") is Array and not sp["slots"].has(slot):
		return
	var colour := Color(1, 1, 1, 0.95)
	if sp.get("colour") is Array and sp["colour"].size() >= 3:
		var c: Array = sp["colour"]
		colour = Color8(int(c[0]), int(c[1]), int(c[2]), int(c[3]) if c.size() > 3 else 255)
	var k := img.get_width() / SPARKLE_ICON_PX # the stars and the nudge are given on a 128 px icon
	var nudge := roundi(float(sp.get("nudge", all.get("nudge", 0))) * k)
	var spots: Array = [] # the stars are placed on the art as it was before any of them
	for st in sp.get("stars", []):
		if st is Array and st.size() >= 3:
			spots.append([free_spot(img, Vector2(float(st[0]), float(st[1])) * k, float(st[2]) * k, nudge), float(st[2]) * k])
	for s in spots:
		sparkle(img, s[0], s[1], colour)


## Where a sparkle of radius r near c covers the least art: the point within nudge px of c (2 px
## steps, the star kept inside the image) with the smallest sum of alpha inside r / 2, the nearest
## to c of equal ones; c itself when nudge is 0.
static func free_spot(img: Image, c: Vector2, r: float, nudge: int) -> Vector2:
	if nudge <= 0:
		return c
	var w := img.get_width()
	var h := img.get_height()
	var px := img.get_data()
	var core := maxf(1.0, r * 0.5)
	var best := c
	var best_cover := INF
	var best_d := INF
	for dy in range(-nudge, nudge + 1, 2):
		for dx in range(-nudge, nudge + 1, 2):
			var p := c + Vector2(dx, dy)
			var d := Vector2(dx, dy).length()
			if d > nudge or p.x - r < 0 or p.y - r < 0 or p.x + r > w or p.y + r > h:
				continue
			var cover := 0
			for y in range(maxi(0, floori(p.y - core)), mini(h, ceili(p.y + core) + 1)):
				for x in range(maxi(0, floori(p.x - core)), mini(w, ceili(p.x + core) + 1)):
					if (Vector2(x + 0.5, y + 0.5) - p).length() <= core:
						cover += px[(y * w + x) * 4 + 3]
			if cover < best_cover or (cover == best_cover and d < best_d):
				best = p
				best_cover = cover
				best_d = d
	return best


## A four-point star (tips at r on the axes, waist 0.26 r on the diagonals: the old painted icons'
## tools/art/equipment_painter.gd _sparkle()) at c, colour over the image, anti-aliased (4 × 4
## samples a px), in place.
static func sparkle(img: Image, c: Vector2, r: float, colour: Color) -> void:
	var star := PackedVector2Array()
	for i in 8:
		star.append(c + Vector2.from_angle(PI * i / 4.0) * (r if i % 2 == 0 else r * 0.26))
	for y in range(maxi(0, floori(c.y - r)), mini(img.get_height(), ceili(c.y + r) + 1)):
		for x in range(maxi(0, floori(c.x - r)), mini(img.get_width(), ceili(c.x + r) + 1)):
			var hits := 0
			for sy in 4:
				for sx in 4:
					if Geometry2D.is_point_in_polygon(Vector2(x + (sx + 0.5) / 4.0, y + (sy + 0.5) / 4.0), star):
						hits += 1
			if hits == 0:
				continue
			var a := colour.a * hits / 16.0
			var under := img.get_pixel(x, y)
			var out_a := a + under.a * (1.0 - a)
			var rgb := (Color(colour.r, colour.g, colour.b) * a + Color(under.r, under.g, under.b) * under.a * (1.0 - a)) / maxf(out_a, 0.0001)
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, out_a))


func _save(img: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if not FileAccess.file_exists(abs_path + ".import"):
		var f := FileAccess.open(abs_path + ".import", FileAccess.WRITE)
		f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\n')
		f.close()
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("import_equipment: cannot write %s (%s)" % [path, error_string(err)])
		return
	var bytes := FileAccess.get_file_as_bytes(abs_path).size()
	_written += 1
	_bytes += bytes
	print("  %s  %dx%d  %.1f KB" % [path, img.get_width(), img.get_height(), bytes / 1024.0])
