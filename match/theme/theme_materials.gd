extends RefCounted
## The textures of a terrain material (match/theme/material_painter.gd), cached for the session.
## grass_dirt is today's ground (assets/terrain/dirt.png + grass_edge.png via ui/art.gd). Every
## other part is painted in code, unless an artist drops a PNG at override_path(id, part)
## (assets/terrain/themes/<id>_<part>.png, same layout: see material_painter.gd); it is read
## directly until the editor imports it.

const Art := preload("res://ui/art.gd")
const Painter := preload("res://match/theme/material_painter.gd")

const OVERRIDE_DIR := "res://assets/terrain/themes/"

static var _cache := {} # id -> material()


static func override_path(id: String, part: String) -> String:
	return OVERRIDE_DIR + "%s_%s.png" % [id, part]


## {fill, edge, hang: Texture2D, cap, hang_rows: int, hard: bool, bottom_tint, rim: Color,
## rim_mix: float} of a material id (an unknown id is grass_dirt).
static func material(id: String) -> Dictionary:
	if not Painter.SPECS.has(id):
		id = "grass_dirt"
	if _cache.has(id):
		return _cache[id]
	var s := Painter.spec(id)
	var m := {
		"id": id,
		"cap": int(s["cap"]),
		"hard": bool(s["hard"]),
		"bottom_tint": s["bottom_tint"],
		"rim": s["rim"],
		"rim_mix": float(s["rim_mix"]),
	}
	if id == "grass_dirt":
		m["fill"] = Art.terrain("dirt")
		m["edge"] = Art.terrain("grass_edge")
		m["cap"] = Art.GRASS_TUFT_ROWS
	else:
		m["fill"] = _part(id, "fill")
		m["edge"] = _part(id, "edge")
	m["hang"] = _part(id, "hang")
	m["hang_rows"] = m["hang"].get_height() if m["hang"].get_height() > 1 else 0
	_cache[id] = m
	return m


static func _part(id: String, part: String) -> Texture2D:
	var path := override_path(id, part)
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var t := Art.texture(path)
		if t != Art.placeholder():
			return t
	var img := Painter.paint(id, part)
	if img == null:
		img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
