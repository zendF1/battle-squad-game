extends Control
## The guild's pictures, drawn in code (placeholder art, original: bright flat shapes in a dark
## outline like ui/glyph_icon.gd) on a 96 × 96 canvas scaled into the control's square, centred:
## - "crest": the guild's banner shield in `tint` (GuildGlyphs.crest_color(guild id)) with a gold rim
##   and a white star: the guild itself (the lobby button, the page header, a ranking row, the
##   result screen's guild EXP tile, the match info popup);
## - "crown": the leader's badge (a gold three-point crown with red gems);
## - "deputy": the deputy's badge (a silver shield with two blue chevrons);
## - "dungeon": the guild dungeon (a stone arch with a swirling purple portal);
## - "dungeon_done": the same gate cleared (a green check disc on its corner);
## - "quest": the daily shared quest (crossed swords over a gold laurel: member victories);
## - "lock": a padlock (a guild skill not reached yet);
## - "invite": the crest with a green plus (Mời vào bang hội; the friends' picture is a person);
## - "leave": a door with an arrow leaving it (Rời bang hội).
## make() for a layout. Colours by id are visual mappings; the rules are the server's.

const OUTLINE := Color(0.07, 0.07, 0.14)
const W := 5.0
const GOLD := Color(1.0, 0.8, 0.22)
const GOLD_DARK := Color(0.86, 0.5, 0.1)
const STEEL := Color(0.86, 0.9, 0.98)
const STEEL_DARK := Color(0.55, 0.62, 0.74)
const RUBY := Color(0.95, 0.25, 0.3)
const CHEVRON := Color(0.3, 0.6, 1.0)
const STONE := Color(0.56, 0.54, 0.62)
const STONE_DARK := Color(0.36, 0.34, 0.42)
const PORTAL := Color(0.62, 0.3, 1.0)
const PORTAL_LIGHT := Color(0.9, 0.75, 1.0)
const CHECK := Color(0.3, 0.85, 0.4)
const LAUREL := Color(0.45, 0.8, 0.35)
const WOOD := Color(0.62, 0.4, 0.22)
const WOOD_DARK := Color(0.42, 0.26, 0.14)
const WHITE := Color(0.97, 0.98, 1.0)

const KINDS := ["crest", "crown", "deputy", "dungeon", "dungeon_done", "quest", "lock", "invite", "leave"]

## The crest colours a guild id picks from (crest_color()).
const CREST_COLORS := [Color(0.85, 0.25, 0.3), Color(0.25, 0.5, 0.95), Color(0.25, 0.7, 0.4), Color(0.6, 0.35, 0.9),
	Color(0.95, 0.55, 0.15), Color(0.15, 0.7, 0.75), Color(0.85, 0.3, 0.65), Color(0.45, 0.5, 0.6)]

var kind := "crest":
	set(v):
		kind = v
		queue_redraw()
var tint := CREST_COLORS[1]:
	set(v):
		tint = v
		queue_redraw()


## A `px` square picture of `kind` that ignores the mouse (tint: the crest's colour).
static func make(glyph_kind: String, px: int, color: Color = CREST_COLORS[1]) -> Control:
	var g = load("res://ui/guild_glyphs.gd").new()
	g.kind = glyph_kind
	g.tint = color
	g.custom_minimum_size = Vector2(px, px)
	g.size = Vector2(px, px)
	g.mouse_filter = MOUSE_FILTER_IGNORE
	g.size_flags_horizontal = SIZE_SHRINK_CENTER
	g.size_flags_vertical = SIZE_SHRINK_CENTER
	return g


## The crest of guild `guild_id`: its colour (crest_color()).
static func crest(guild_id: String, px: int) -> Control:
	return make("crest", px, crest_color(guild_id))


## A guild's crest colour, the same for one id everywhere (a visual mapping, not a rule).
static func crest_color(guild_id: String) -> Color:
	if guild_id == "":
		return CREST_COLORS[1]
	return CREST_COLORS[posmod(hash(guild_id), CREST_COLORS.size())]


func _init() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := minf(size.x, size.y) / 96.0
	if s <= 0.0:
		return
	draw_set_transform((size - Vector2(96, 96) * s) / 2.0, 0.0, Vector2(s, s))
	match kind:
		"crest": _crest()
		"crown": _crown()
		"deputy": _deputy()
		"dungeon": _dungeon(false)
		"dungeon_done": _dungeon(true)
		"quest": _quest()
		"lock": _lock()
		"invite": _invite()
		"leave": _leave()


func _poly(pts: PackedVector2Array, fill: Color, w: float = W) -> void:
	if w > 0.0:
		for o in Geometry2D.offset_polygon(pts, w, Geometry2D.JOIN_ROUND):
			draw_colored_polygon(o, OUTLINE)
	draw_colored_polygon(pts, fill)


func _stroke(pts: PackedVector2Array, color: Color, width: float, w: float = W) -> void:
	if w > 0.0:
		for o in Geometry2D.offset_polyline(pts, width / 2.0 + w, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			draw_colored_polygon(o, OUTLINE)
	for o in Geometry2D.offset_polyline(pts, width / 2.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
		draw_colored_polygon(o, color)


func _disc(c: Vector2, r: float, fill: Color) -> void:
	draw_circle(c, r + W, OUTLINE, true, -1.0, true)
	draw_circle(c, r, fill, true, -1.0, true)


static func _star(c: Vector2, outer: float, inner: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := -PI / 2.0 + PI * i / points
		pts.append(c + Vector2(cos(a), sin(a)) * (outer if i % 2 == 0 else inner))
	return pts


## A heraldic shield's outline: flat top with notched corners, sides curving to a point.
static func _shield_pts(top: float, left: float, right: float, bottom: float) -> PackedVector2Array:
	var mid := (left + right) / 2.0
	var pts := PackedVector2Array([Vector2(left + 6, top), Vector2(mid, top + 6), Vector2(right - 6, top), Vector2(right, top + 6)])
	var side := top + (bottom - top) * 0.45
	pts.append(Vector2(right, side))
	for i in range(1, 9):
		var t := float(i) / 8.0
		pts.append(Vector2(lerpf(right, mid, t), side + (bottom - side) * sin(t * PI / 2.0)))
	for i in range(7, -1, -1):
		var t := float(i) / 8.0
		pts.append(Vector2(lerpf(left, mid, t), side + (bottom - side) * sin(t * PI / 2.0)))
	pts.append(Vector2(left, top + 6))
	return pts


func _crest() -> void:
	_poly(_shield_pts(10, 14, 82, 90), GOLD)
	draw_colored_polygon(_shield_pts(17, 21, 75, 81), tint)
	draw_colored_polygon(PackedVector2Array([Vector2(48, 22), Vector2(72, 20), Vector2(72, 50), Vector2(48, 76)]), Color(1, 1, 1, 0.14))
	_poly(_star(Vector2(48, 46), 19, 8, 5), WHITE, 3.0)


func _crown() -> void:
	var pts := PackedVector2Array([Vector2(14, 34), Vector2(32, 52), Vector2(48, 20), Vector2(64, 52), Vector2(82, 34),
		Vector2(76, 76), Vector2(20, 76)])
	_poly(pts, GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(22, 64), Vector2(74, 64), Vector2(72, 76), Vector2(24, 76)]), GOLD_DARK)
	for p in [Vector2(14, 32), Vector2(48, 18), Vector2(82, 32)]:
		_disc(p, 6.0, GOLD)
	for p in [Vector2(34, 66), Vector2(48, 66), Vector2(62, 66)]:
		draw_circle(p, 5.0, RUBY, true, -1.0, true)


func _deputy() -> void:
	_poly(_shield_pts(10, 16, 80, 90), STEEL)
	draw_colored_polygon(_shield_pts(16, 22, 74, 82), STEEL_DARK.lerp(STEEL, 0.4))
	for y in [34.0, 54.0]:
		_stroke(PackedVector2Array([Vector2(30, y), Vector2(48, y + 14), Vector2(66, y)]), CHEVRON, 9.0, 3.0)


func _dungeon(done: bool) -> void:
	# the arch: two stone pillars and a rounded top
	var arch := PackedVector2Array([Vector2(12, 90), Vector2(12, 44)])
	for i in 13:
		var a := PI + PI * i / 12.0
		arch.append(Vector2(48, 44) + Vector2(cos(a), sin(a)) * 36.0)
	arch.append(Vector2(84, 90))
	_poly(arch, STONE)
	var door := PackedVector2Array([Vector2(26, 90), Vector2(26, 46)])
	for i in 13:
		var a := PI + PI * i / 12.0
		door.append(Vector2(48, 46) + Vector2(cos(a), sin(a)) * 22.0)
	door.append(Vector2(70, 90))
	draw_colored_polygon(door, PORTAL)
	for i in 3: # the portal's swirl
		var pts := PackedVector2Array()
		for k in 14:
			var t := float(k) / 13.0
			var a := t * TAU * 0.8 + i * TAU / 3.0
			pts.append(Vector2(48, 62) + Vector2(cos(a), sin(a)) * (4.0 + t * 14.0))
		_stroke(pts, PORTAL_LIGHT, 3.0, 0.0)
	for p in [Vector2(18, 58), Vector2(78, 58), Vector2(30, 18), Vector2(66, 18)]: # the stones' joints
		draw_circle(p, 2.5, STONE_DARK, true, -1.0, true)
	if done:
		_disc(Vector2(74, 74), 16.0, CHECK)
		_stroke(PackedVector2Array([Vector2(66, 74), Vector2(72, 80), Vector2(83, 67)]), WHITE, 5.0, 0.0)


func _quest() -> void:
	for side: float in [-1.0, 1.0]: # the laurel: leaves along two arcs
		for i in 6:
			var a := PI / 2.0 + side * (0.35 + i * 0.36)
			var at := Vector2(48, 50) + Vector2(cos(a), sin(a)) * 36.0
			var leaf := PackedVector2Array()
			for k in 8:
				var t := TAU * k / 8.0
				leaf.append(at + Vector2(cos(t) * 7.0, sin(t) * 4.0).rotated(a + PI / 2.0))
			_poly(leaf, LAUREL, 2.5)
	for side: float in [-1.0, 1.0]: # the crossed swords
		var tip := Vector2(48 + side * 26, 16)
		var hilt := Vector2(48 - side * 22, 70)
		_stroke(PackedVector2Array([hilt, tip]), STEEL, 8.0)
		_stroke(PackedVector2Array([hilt + Vector2(-side * 6, -8), hilt + Vector2(side * 10, 6)]), GOLD, 6.0, 3.0)
		_disc(hilt + Vector2(-side * 6, 7), 4.5, GOLD)


func _lock() -> void:
	var shackle := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		shackle.append(Vector2(48, 42) + Vector2(cos(a), sin(a)) * 18.0)
	shackle.insert(0, Vector2(30, 52))
	shackle.append(Vector2(66, 52))
	_stroke(shackle, STEEL_DARK, 9.0)
	_poly(PackedVector2Array([Vector2(20, 46), Vector2(76, 46), Vector2(76, 88), Vector2(20, 88)]), GOLD)
	draw_circle(Vector2(48, 62), 6.0, OUTLINE, true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(45, 64), Vector2(51, 64), Vector2(53, 78), Vector2(43, 78)]), OUTLINE)


func _invite() -> void:
	# the guild's crest (smaller, top-left) with a green plus disc: an invitation to the guild,
	# unlike the friends' person-with-a-plus
	_poly(_shield_pts(6, 8, 66, 80), GOLD)
	draw_colored_polygon(_shield_pts(12, 14, 60, 72), tint)
	_poly(_star(Vector2(37, 38), 15, 6.5, 5), WHITE, 3.0)
	_disc(Vector2(72, 70), 17.0, CHECK)
	_stroke(PackedVector2Array([Vector2(72, 60), Vector2(72, 80)]), WHITE, 6.0, 0.0)
	_stroke(PackedVector2Array([Vector2(62, 70), Vector2(82, 70)]), WHITE, 6.0, 0.0)


func _leave() -> void:
	_poly(PackedVector2Array([Vector2(16, 10), Vector2(58, 10), Vector2(58, 88), Vector2(16, 88)]), WOOD)
	draw_colored_polygon(PackedVector2Array([Vector2(22, 16), Vector2(52, 16), Vector2(52, 82), Vector2(22, 82)]), WOOD_DARK)
	draw_circle(Vector2(46, 50), 4.0, GOLD, true, -1.0, true)
	_stroke(PackedVector2Array([Vector2(44, 50), Vector2(84, 50)]), RUBY, 9.0)
	_poly(PackedVector2Array([Vector2(74, 36), Vector2(90, 50), Vector2(74, 64)]), RUBY, 3.0)
