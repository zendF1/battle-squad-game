extends Control
## A chest's icon drawn in code (placeholder art until real art) on a 96 × 96 canvas scaled to
## fit, readable from about 24 px, on light and dark grounds (a dark outline): a wooden chest
## with metal bands, its lid's lock gem in the kind's colour; a stone chest (kind "stone") oak
## with iron bands and a blue gem, an equipment chest (kind "equipment") dark red with gold bands
## and a violet gem, richer (a gold star on the lid) for a higher upgrade level. The boss chests
## have their own look by id (CHEST_LOOKS): bronze copper with dark bands and a teal gem, silver
## bright steel with dark bands, a trim along the lid and a cyan gem, gold all gold with a ruby, a
## trim and a star on the lid, so colour and shape both tell them apart even small. The kind and
## the level are the game data's (GET /gamedata chests); an unknown chest draws the stone look,
## the old stone_chest keeps it.

const GameData := preload("res://autoload/game_data_model.gd")

const OUTLINE := Color(0.08, 0.06, 0.1)
## kind -> {wood [light, main, dark], band [light, main], gem [light, main]}
const LOOKS := {
	"stone": {"wood": [Color(0.86, 0.6, 0.34), Color(0.64, 0.4, 0.2), Color(0.4, 0.22, 0.1)],
		"band": [Color(0.86, 0.9, 0.96), Color(0.55, 0.6, 0.7)], "gem": [Color(0.7, 0.92, 1.0), Color(0.24, 0.6, 1.0)]},
	"equipment": {"wood": [Color(0.86, 0.38, 0.36), Color(0.62, 0.16, 0.18), Color(0.36, 0.06, 0.1)],
		"band": [Color(1.0, 0.93, 0.6), Color(0.96, 0.7, 0.18)], "gem": [Color(0.94, 0.75, 1.0), Color(0.66, 0.3, 0.96)]},
}

## chest id -> a look of its own (LOOKS' fields, trim: the lid's edge in the band's light colour,
## star: a star on the lid).
const CHEST_LOOKS := {
	"stone_chest_bronze": {"wood": [Color(0.97, 0.63, 0.33), Color(0.78, 0.42, 0.16), Color(0.5, 0.24, 0.08)],
		"band": [Color(0.8, 0.5, 0.26), Color(0.42, 0.22, 0.1)], "gem": [Color(0.62, 1.0, 0.86), Color(0.1, 0.66, 0.58)]},
	"stone_chest_silver": {"wood": [Color(0.96, 0.98, 1.0), Color(0.72, 0.78, 0.88), Color(0.46, 0.52, 0.66)],
		"band": [Color(0.72, 0.8, 0.94), Color(0.34, 0.42, 0.6)], "gem": [Color(0.78, 1.0, 1.0), Color(0.12, 0.74, 0.92)],
		"trim": true},
	"stone_chest_gold": {"wood": [Color(1.0, 0.94, 0.58), Color(0.97, 0.73, 0.16), Color(0.72, 0.44, 0.06)],
		"band": [Color(1.0, 0.98, 0.8), Color(0.84, 0.5, 0.08)], "gem": [Color(1.0, 0.72, 0.72), Color(0.92, 0.1, 0.22)],
		"trim": true, "star": true},
}

var chest_id := "":
	set(v):
		chest_id = v
		queue_redraw()


## A chest's look: its own (CHEST_LOOKS), else its kind's, else the plain stone chest.
static func look_of(id: String) -> Dictionary:
	if CHEST_LOOKS.has(id):
		return CHEST_LOOKS[id]
	return LOOKS.get(GameData.chest_kind(id), LOOKS["stone"])


## The chest draws a star on its lid.
static func has_star(id: String) -> bool:
	return bool(look_of(id).get("star", false)) or GameData.chest_upgrade_level(id) >= 16


static func make(id: String, px: float) -> Control:
	var c = load("res://ui/chest_icon.gd").new()
	c.chest_id = id
	c.custom_minimum_size = Vector2(px, px)
	c.size = Vector2(px, px)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := minf(size.x, size.y) / 96.0
	draw_set_transform((size - Vector2(96, 96) * s) / 2.0, 0.0, Vector2(s, s))
	var look := look_of(chest_id)
	var wood: Array = look["wood"]
	var band: Array = look["band"]
	var gem: Array = look["gem"]
	# the body
	_rect(Rect2(12, 44, 72, 40), wood[1], 4.0)
	draw_rect(Rect2(12, 44, 72, 8), wood[2])
	draw_rect(Rect2(16, 56, 64, 3), Color(wood[0], 0.5))
	draw_rect(Rect2(16, 70, 64, 3), Color(wood[0], 0.5))
	# the lid: a rounded top
	var lid := PackedVector2Array()
	lid.append(Vector2(10, 46))
	for i in 13:
		var a := PI + PI * i / 12.0
		lid.append(Vector2(48 + cos(a) * 38, 40 + sin(a) * 26))
	lid.append(Vector2(86, 46))
	for o in Geometry2D.offset_polygon(lid, 4.0, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(o, OUTLINE)
	draw_colored_polygon(lid, wood[1].lightened(0.08))
	var shine := PackedVector2Array()
	for i in 7:
		var a := PI * 1.12 + PI * 0.4 * i / 6.0
		shine.append(Vector2(48 + cos(a) * 32, 40 + sin(a) * 20))
	draw_polyline(shine, Color(wood[0], 0.8), 3.0, true)
	if look.get("trim", false): # the lid's edge
		var rim := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			rim.append(Vector2(48 + cos(a) * 36, 40 + sin(a) * 24))
		draw_polyline(rim, band[0], 3.5, true)
	# the bands
	for x in [22.0, 66.0]:
		_rect(Rect2(x, 18, 8, 66), band[1], 2.5)
		draw_rect(Rect2(x, 18, 3, 66), Color(band[0], 0.8))
	draw_rect(Rect2(10, 44, 76, 5), OUTLINE)
	# the lock with its gem
	_rect(Rect2(39, 38, 18, 22), band[1], 3.0)
	var g := PackedVector2Array([Vector2(48, 41), Vector2(54, 48), Vector2(48, 56), Vector2(42, 48)])
	draw_colored_polygon(g, gem[1])
	draw_colored_polygon(PackedVector2Array([Vector2(48, 41), Vector2(54, 48), Vector2(48, 48), Vector2(42, 48)]), gem[0])
	if has_star(chest_id): # the richer chest: a gold star on the lid
		var st := PackedVector2Array()
		for i in 10:
			st.append(Vector2(48, 24) + Vector2.from_angle(-PI / 2 + PI * i / 5.0) * (9.0 if i % 2 == 0 else 4.0))
		for o in Geometry2D.offset_polygon(st, 2.5, Geometry2D.JOIN_ROUND):
			draw_colored_polygon(o, OUTLINE)
		draw_colored_polygon(st, band[0])


func _rect(r: Rect2, color: Color, w: float) -> void:
	draw_rect(r.grow(w), OUTLINE)
	draw_rect(r, color)
