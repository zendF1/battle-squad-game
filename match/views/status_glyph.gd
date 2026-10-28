extends Control
## A status effect as a picture, drawn in code (original art) on a 96 × 96 canvas scaled into the
## control's square, on a round badge in the effect's colour: stun stars circling, a freeze
## snowflake, a burn flame, a net web, root rocks, a poison drop with a skull, a blindfolded eye;
## an armed shot effect whose id is a battle item (power_shot, drill_bomb, …) shows that item's
## icon; the boss's shield / armour going on or breaking ("shield", "shield_break", "armor",
## "armor_break"). `skip` adds the lost-turn mark (a turn arrow struck through) on its corner.
## Unknown ids draw a plain badge. For the status bursts over a unit (status_burst.gd) and the
## move notice (hud.gd).

const Art := preload("res://ui/art.gd")
const Items := preload("res://match/items.gd")

const OUTLINE := Color(0.07, 0.07, 0.14)
const COLORS := {
	"stun": Color(1.0, 0.82, 0.25), "freeze": Color(0.55, 0.85, 1.0), "burn": Color(1.0, 0.5, 0.15),
	"net": Color(0.85, 0.85, 0.92), "root": Color(0.66, 0.5, 0.32), "poison": Color(0.5, 0.9, 0.3),
	"blind": Color(0.92, 0.92, 0.98), "shield": Color(0.45, 0.8, 1.0), "shield_break": Color(0.45, 0.8, 1.0),
	"armor": Color(0.72, 0.6, 0.45), "armor_break": Color(0.72, 0.6, 0.45),
}
## An effect named apart from the item that gives it.
const ITEM_OF := {"wind_stop": "wind_stopper"}
const KINDS := ["stun", "freeze", "burn", "net", "root", "poison", "blind", "shield", "shield_break", "armor", "armor_break"]

var effect := "":
	set(v):
		effect = v
		queue_redraw()
var skip := false:
	set(v):
		skip = v
		queue_redraw()


static func make(effect_id: String, px: float, lost_turn: bool = false) -> Control:
	var g = load("res://match/views/status_glyph.gd").new()
	g.effect = effect_id
	g.skip = lost_turn
	g.size = Vector2(px, px)
	g.custom_minimum_size = Vector2(px, px)
	return g


## Whether `effect_id` has a picture (a drawn kind or a battle item's icon).
static func has_picture(effect_id: String) -> bool:
	return KINDS.has(effect_id) or Items.order().has(item_of(effect_id))


## The battle item whose icon an effect shows (its own id, or ITEM_OF's).
static func item_of(effect_id: String) -> String:
	return str(ITEM_OF.get(effect_id, effect_id))


static func color_of(effect_id: String) -> Color:
	return COLORS.get(effect_id, Color(0.6, 0.75, 1.0))


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := minf(size.x, size.y) / 96.0
	if s <= 0.0:
		return
	draw_set_transform((size - Vector2(96, 96) * s) / 2.0, 0.0, Vector2(s, s))
	var c := color_of(effect)
	# the badge
	draw_circle(Vector2(48, 48), 46, OUTLINE)
	draw_circle(Vector2(48, 48), 41, c.darkened(0.55))
	draw_circle(Vector2(48, 44), 36, c.darkened(0.3))
	match effect:
		"stun": _stun(c)
		"freeze": _freeze(c)
		"burn": _burn(c)
		"net": _net(c)
		"root": _root(c)
		"poison": _poison(c)
		"blind": _blind(c)
		"shield": _shield(c, false)
		"shield_break": _shield(c, true)
		"armor": _armor(c, false)
		"armor_break": _armor(c, true)
		_:
			if Items.order().has(item_of(effect)):
				draw_texture_rect(Art.item_icon(item_of(effect)), Rect2(16, 16, 64, 64), false)
	if skip:
		_skip_mark()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _poly(pts: PackedVector2Array, fill: Color, w: float = 4.0) -> void:
	for o in Geometry2D.offset_polygon(pts, w, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(o, OUTLINE)
	draw_colored_polygon(pts, fill)


func _line(pts: PackedVector2Array, color: Color, width: float, w: float = 3.5) -> void:
	for o in Geometry2D.offset_polyline(pts, width / 2.0 + w, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
		draw_colored_polygon(o, OUTLINE)
	for o in Geometry2D.offset_polyline(pts, width / 2.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
		draw_colored_polygon(o, color)


static func _star_pts(at: Vector2, outer: float, inner: float, rot: float = -PI / 2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(at + Vector2.from_angle(rot + PI * i / 5.0) * (outer if i % 2 == 0 else inner))
	return pts


func _stun(c: Color) -> void:
	# a dizzy swirl with three stars round it
	var sw := PackedVector2Array()
	for i in 40:
		var t := i / 39.0
		sw.append(Vector2(48, 50) + Vector2.from_angle(t * TAU * 1.6) * (4.0 + 16.0 * t))
	_line(sw, Color(1, 1, 1, 0.95), 4.0, 2.5)
	for i in 3:
		var at := Vector2(48, 48) + Vector2.from_angle(-PI / 2 + TAU * i / 3.0) * 26.0
		_poly(_star_pts(at, 12.0, 5.0), c.lightened(0.2), 3.0)


func _freeze(c: Color) -> void:
	for i in 3:
		var d := Vector2.from_angle(PI / 2 + PI * i / 3.0) * 30.0
		_line(PackedVector2Array([Vector2(48, 48) - d, Vector2(48, 48) + d]), Color(0.92, 0.98, 1.0), 6.0)
	for i in 6:
		var dir := Vector2.from_angle(PI / 2 + PI * i / 3.0)
		var tip := Vector2(48, 48) + dir * 20.0
		for side in [-1.0, 1.0]:
			_line(PackedVector2Array([tip, tip + dir.rotated(side * 0.8) * 10.0]), Color(0.92, 0.98, 1.0), 4.0, 2.5)
	draw_circle(Vector2(48, 48), 7, c.lightened(0.4))


func _burn(_c: Color) -> void:
	var outer := PackedVector2Array([Vector2(48, 14), Vector2(62, 34), Vector2(70, 52), Vector2(66, 70), Vector2(48, 80),
		Vector2(30, 70), Vector2(26, 52), Vector2(36, 40), Vector2(40, 50), Vector2(44, 30)])
	_poly(outer, Color(1.0, 0.36, 0.1))
	var inner := PackedVector2Array([Vector2(48, 40), Vector2(58, 56), Vector2(56, 70), Vector2(48, 76), Vector2(40, 70),
		Vector2(38, 58)])
	draw_colored_polygon(inner, Color(1.0, 0.85, 0.3))


func _net(c: Color) -> void:
	var hub := Vector2(48, 48)
	var web := c.lightened(0.5)
	var spokes: Array = []
	for i in 8:
		spokes.append(PackedVector2Array([hub, hub + Vector2.from_angle(TAU * i / 8.0 + 0.2) * 32.0]))
	var rings: Array = []
	for r in [11.0, 21.0, 31.0]:
		var ring := PackedVector2Array()
		for i in 9:
			var a := TAU * i / 8.0 + 0.2
			ring.append(hub + Vector2.from_angle(a) * r)
		rings.append(ring)
	for pass_i in 2: # the dark outline under, then the threads
		for pts in spokes + rings:
			draw_polyline(pts, OUTLINE if pass_i == 0 else web, 6.0 if pass_i == 0 else 3.0, true)


func _root(c: Color) -> void:
	_poly(PackedVector2Array([Vector2(18, 76), Vector2(26, 52), Vector2(40, 46), Vector2(50, 58), Vector2(48, 76)]), c.lightened(0.1))
	_poly(PackedVector2Array([Vector2(44, 76), Vector2(52, 40), Vector2(66, 32), Vector2(78, 50), Vector2(78, 76)]), c.lightened(0.25))
	_line(PackedVector2Array([Vector2(30, 70), Vector2(36, 60), Vector2(34, 54)]), c.darkened(0.4), 3.0, 0.0)
	_line(PackedVector2Array([Vector2(60, 70), Vector2(64, 54), Vector2(70, 46)]), c.darkened(0.4), 3.0, 0.0)
	_line(PackedVector2Array([Vector2(12, 80), Vector2(84, 80)]), c.darkened(0.2), 6.0)


func _poison(c: Color) -> void:
	var drop := PackedVector2Array()
	for i in 25:
		var t := PI * 0.15 + (TAU - PI * 0.3) * i / 24.0
		drop.append(Vector2(48, 56) + Vector2(sin(t), -cos(t)) * 24.0)
	drop.append(Vector2(48, 14))
	_poly(drop, c)
	# a little skull on it
	draw_circle(Vector2(48, 56), 11, Color(0.95, 1.0, 0.9))
	draw_rect(Rect2(42, 62, 12, 7), Color(0.95, 1.0, 0.9))
	draw_circle(Vector2(44, 55), 3, OUTLINE)
	draw_circle(Vector2(52, 55), 3, OUTLINE)


func _blind(c: Color) -> void:
	var eye := PackedVector2Array()
	for i in 13:
		eye.append(Vector2(48 + cos(PI + PI * i / 12.0) * 30, 48 + sin(PI + PI * i / 12.0) * 18))
	for i in 13:
		eye.append(Vector2(48 + cos(PI * i / 12.0) * 30, 48 + sin(PI * i / 12.0) * 18))
	_poly(eye, c)
	draw_circle(Vector2(48, 48), 10, Color(0.25, 0.3, 0.45))
	_line(PackedVector2Array([Vector2(16, 30), Vector2(80, 66)]), Color(0.9, 0.2, 0.2), 6.0)


func _shield(c: Color, broken: bool) -> void:
	var pts := PackedVector2Array([Vector2(48, 14), Vector2(76, 24), Vector2(74, 50), Vector2(48, 82), Vector2(22, 50), Vector2(20, 24)])
	if broken:
		var left := PackedVector2Array([Vector2(46, 14), Vector2(20, 24), Vector2(22, 50), Vector2(44, 80), Vector2(40, 60), Vector2(50, 46),
			Vector2(42, 32)])
		var right := PackedVector2Array([Vector2(52, 16), Vector2(76, 26), Vector2(74, 52), Vector2(54, 80), Vector2(58, 60),
			Vector2(48, 46), Vector2(56, 32)])
		for i in left.size():
			left[i] += Vector2(-5, 2)
			right[i] += Vector2(5, -2)
		_poly(left, c)
		_poly(right, c)
		return
	_poly(pts, c)
	draw_colored_polygon(PackedVector2Array([Vector2(48, 20), Vector2(70, 28), Vector2(68, 48), Vector2(48, 74)]), c.lightened(0.35))


func _armor(c: Color, broken: bool) -> void:
	var plates := [Rect2(22, 24, 24, 22), Rect2(50, 24, 24, 22), Rect2(22, 50, 24, 22), Rect2(50, 50, 24, 22)]
	for i in plates.size():
		var r: Rect2 = plates[i]
		if broken:
			r.position += (r.get_center() - Vector2(48, 48)).normalized() * 7.0
		_poly(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
			c.lightened(0.1 * (i % 2)), 3.0)
	if broken:
		_line(PackedVector2Array([Vector2(48, 16), Vector2(44, 40), Vector2(52, 56), Vector2(46, 80)]), Color(1, 0.95, 0.8), 3.0, 2.0)


## The lost-turn mark on the bottom-right: a turn arrow struck through in red.
func _skip_mark() -> void:
	var at := Vector2(74, 74)
	draw_circle(at, 20, OUTLINE)
	draw_circle(at, 16, Color(0.95, 0.95, 1.0))
	var arc := PackedVector2Array()
	for i in 13:
		arc.append(at + Vector2.from_angle(-PI * 0.9 + PI * 1.5 * i / 12.0) * 9.0)
	draw_polyline(arc, Color(0.2, 0.3, 0.5), 3.5, true)
	var tip := arc[arc.size() - 1]
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-6, -2), tip + Vector2(4, -5), tip + Vector2(2, 5)]), Color(0.2, 0.3, 0.5))
	draw_line(at + Vector2(-12, -12), at + Vector2(12, 12), Color(0.9, 0.15, 0.15), 5.0, true)
