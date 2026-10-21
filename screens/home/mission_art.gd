extends Control
## Code-drawn pictures for "Nhiệm Vụ Ngày", in the icon style (bright shapes with a dark rounded
## outline, tools/art/icon_painter.gd), drawn on a 96 × 96 canvas scaled to fit the control:
## STAR (a mission's activity points), SHIELD (today's activity badge, the number is a label on
## top), CHEST (a daily chest: closed; `opened` with its lid up and a green check once claimed;
## `glow` a soft gold halo while claimable; `tint` its colour), RAYS (a gold sunburst fading
## out, put behind a claimable chest and turned) and BOARD (the lobby button: a clipboard with
## ticked lines).

enum Kind { STAR, SHIELD, CHEST, BOARD, RAYS }

const OUTLINE := Color(0.07, 0.07, 0.14)
const W := 4.0
const GOLD := Color(1.0, 0.8, 0.22)
const GOLD_LIGHT := Color(1.0, 0.93, 0.6)
const GOLD_DARK := Color(0.85, 0.5, 0.1)
const GREEN := Color(0.3, 0.78, 0.38)
## Chest colours by position (20 / 40 / 60 / 80 / 100).
const CHEST_TINTS := [Color(0.25, 0.68, 0.72), Color(0.28, 0.5, 0.92), Color(0.58, 0.38, 0.9), Color(0.9, 0.32, 0.36), Color(1.0, 0.72, 0.18)]

var kind := Kind.STAR:
	set(v):
		kind = v
		queue_redraw()
var opened := false:
	set(v):
		opened = v
		queue_redraw()
var glow := false:
	set(v):
		glow = v
		queue_redraw()
var tint: Color = CHEST_TINTS[1]:
	set(v):
		tint = v
		queue_redraw()

static var _boxes := {}


static func make(k: Kind, px: Vector2) -> Control:
	var c = load("res://screens/home/mission_art.gd").new()
	c.kind = k
	c.custom_minimum_size = px
	c.size = px
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := minf(size.x, size.y) / 96.0
	draw_set_transform((size - Vector2(96, 96) * s) / 2.0, 0.0, Vector2(s, s))
	match kind:
		Kind.STAR: _star_badge()
		Kind.SHIELD: _shield()
		Kind.CHEST: _chest()
		Kind.BOARD: _board()
		Kind.RAYS: _rays()


# ── Shapes ──────────────────────────────────────────────────────────────────

func _poly(pts: Array, fill: Color, w: float = W) -> void:
	var packed := PackedVector2Array(pts)
	if w > 0.0:
		for o in Geometry2D.offset_polygon(packed, w, Geometry2D.JOIN_ROUND):
			draw_colored_polygon(o, OUTLINE)
	draw_colored_polygon(packed, fill)


func _fill(pts: Array, fill: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), fill)


func _rect(r: Rect2, color: Color, radius: float, w: float = W) -> void:
	var key := [color, radius, w]
	var box: StyleBoxFlat = _boxes.get(key)
	if box == null:
		box = StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(int(radius))
		box.anti_aliasing = true
		box.corner_detail = 10
		if w > 0.0:
			box.border_color = OUTLINE
			box.set_border_width_all(int(w))
			box.set_expand_margin_all(w)
		_boxes[key] = box
	draw_style_box(box, r)


func _stroke(pts: Array, color: Color, width: float, w: float = W) -> void:
	var packed := PackedVector2Array(pts)
	if w > 0.0:
		for o in Geometry2D.offset_polyline(packed, width / 2 + w, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			draw_colored_polygon(o, OUTLINE)
	for o in Geometry2D.offset_polyline(packed, width / 2, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
		draw_colored_polygon(o, color)


static func star_points(c: Vector2, outer: float, inner: float, points: int = 5, rot: float = -PI / 2) -> Array:
	var out := []
	for i in points * 2:
		out.append(c + Vector2.from_angle(rot + PI * i / points) * (outer if i % 2 == 0 else inner))
	return out


func _sparkle(c: Vector2, r: float) -> void:
	_fill(star_points(c, r, r * 0.28, 4, 0.0), Color(1, 1, 1, 0.95))


## A soft disc: `inner` at the centre fading to transparent at r.
func _halo(c: Vector2, r: float, inner: Color = Color(1.0, 0.9, 0.45, 0.75)) -> void:
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([inner])
	for i in 41:
		pts.append(c + Vector2.from_angle(TAU * i / 40.0) * r)
		cols.append(Color(inner, 0.0))
	for i in 40:
		draw_polygon(PackedVector2Array([pts[0], pts[i + 1], pts[i + 2]]), PackedColorArray([cols[0], cols[i + 1], cols[i + 2]]))


func _rays() -> void:
	var c := Vector2(48, 48)
	for i in 12:
		var a := TAU * i / 12.0
		var tip := c + Vector2.from_angle(a) * 48.0
		var l := c + Vector2.from_angle(a - 0.13) * 48.0
		var r := c + Vector2.from_angle(a + 0.13) * 48.0
		draw_polygon(PackedVector2Array([c, l, tip, r]), PackedColorArray([Color(1.0, 0.92, 0.5, 0.7), Color(1.0, 0.85, 0.3, 0.0),
			Color(1.0, 0.85, 0.3, 0.0), Color(1.0, 0.85, 0.3, 0.0)]))
	_halo(c, 30, Color(1.0, 0.95, 0.65, 0.6))


# ── Pictures ────────────────────────────────────────────────────────────────

func _star_badge() -> void:
	var c := Vector2(48, 50)
	_poly(star_points(c, 44, 20), GOLD)
	_fill(star_points(c + Vector2(0, -2), 34, 15), GOLD_LIGHT)
	_fill(star_points(c + Vector2(0, 1), 26, 12), GOLD)
	_fill([c + Vector2(-20, -8), c + Vector2(-6, -10), c + Vector2(-12, -2)], Color(1, 1, 1, 0.55))


## The day's activity badge: a blue shield with a gold rim and a small star on top.
func _shield() -> void:
	var outer := [Vector2(10, 14), Vector2(86, 14), Vector2(86, 58), Vector2(48, 92), Vector2(10, 58)]
	_poly(_round(outer, 6.0), GOLD, W)
	var inner := [Vector2(16, 20), Vector2(80, 20), Vector2(80, 56), Vector2(48, 84), Vector2(16, 56)]
	_fill(_round(inner, 4.0), Color(0.16, 0.32, 0.78))
	_fill([Vector2(16, 20), Vector2(80, 20), Vector2(80, 40), Vector2(16, 48)], Color(0.24, 0.44, 0.92))
	_fill([Vector2(20, 24), Vector2(46, 24), Vector2(20, 40)], Color(1, 1, 1, 0.18))
	_poly(star_points(Vector2(48, 13), 12, 5.5), GOLD, 3.0)


## The polygon with its corners cut by `r` (a cheap rounding).
static func _round(pts: Array, r: float) -> Array:
	var out := []
	var n := pts.size()
	for i in n:
		var p: Vector2 = pts[i]
		var a: Vector2 = pts[(i - 1 + n) % n]
		var b: Vector2 = pts[(i + 1) % n]
		out.append(p + (a - p).normalized() * minf(r, (a - p).length() / 2))
		out.append(p + (b - p).normalized() * minf(r, (b - p).length() / 2))
	return out


func _chest() -> void:
	if glow:
		_halo(Vector2(48, 54), 46)
	var body := tint
	var dark := tint.darkened(0.35)
	var light := tint.lightened(0.3)
	if opened:
		# The lid tipped back, the dark inside showing
		_poly([Vector2(18, 38), Vector2(78, 38), Vector2(84, 14), Vector2(12, 14)], dark)
		_fill([Vector2(20, 34), Vector2(76, 34), Vector2(80, 18), Vector2(16, 18)], body)
		_rect(Rect2(14, 42, 68, 42), body, 8)
		_fill([Vector2(18, 42), Vector2(78, 42), Vector2(78, 52), Vector2(18, 52)], Color(0.06, 0.05, 0.1))
		_sparkle(Vector2(36, 34), 6.0)
		_sparkle(Vector2(62, 30), 8.0)
		_bands(52)
		_check(Vector2(70, 72))
		return
	_rect(Rect2(14, 46, 68, 38), body, 8)
	_fill([Vector2(18, 74), Vector2(78, 74), Vector2(78, 80), Vector2(18, 80)], dark)
	_rect(Rect2(10, 24, 76, 26), light, 12)
	_fill([Vector2(16, 30), Vector2(50, 30), Vector2(50, 34), Vector2(16, 34)], Color(1, 1, 1, 0.3))
	_bands(24)
	# The lock
	_rect(Rect2(40, 40, 16, 18), GOLD, 4, 3.0)
	draw_circle(Vector2(48, 47), 2.6, OUTLINE, true, -1.0, true)
	draw_line(Vector2(48, 48), Vector2(48, 53), OUTLINE, 2.4, true)


## The two gold straps over the lid and the body, from y `top` down.
func _bands(top: float) -> void:
	for x in [24.0, 66.0]:
		_fill([Vector2(x, top + 2), Vector2(x + 6, top + 2), Vector2(x + 6, 82), Vector2(x, 82)], GOLD)
		draw_line(Vector2(x + 1.5, top + 4), Vector2(x + 1.5, 80), GOLD_LIGHT, 1.6, true)


func _check(c: Vector2) -> void:
	draw_circle(c, 17 + W, OUTLINE, true, -1.0, true)
	draw_circle(c, 17, GREEN, true, -1.0, true)
	draw_circle(c + Vector2(-4, -5), 8, Color(1, 1, 1, 0.18), true, -1.0, true)
	_stroke([c + Vector2(-9, 0), c + Vector2(-3, 7), c + Vector2(9, -7)], Color.WHITE, 5.5, 0.0)


## The lobby button: a clipboard with three lines, the first two ticked.
func _board() -> void:
	_rect(Rect2(18, 16, 60, 74), Color(0.62, 0.4, 0.22), 8)
	_rect(Rect2(24, 24, 48, 60), Color(0.98, 0.97, 0.92), 4, 0.0)
	_rect(Rect2(34, 9, 28, 14), Color(0.75, 0.78, 0.86), 5, 3.0)
	for i in 3:
		var y := 38.0 + i * 15.0
		draw_line(Vector2(44, y), Vector2(66, y), Color(0.55, 0.58, 0.68), 4.0, true)
		if i < 2:
			_stroke([Vector2(29, y - 1), Vector2(33, y + 3), Vector2(40, y - 5)], GREEN, 4.0, 0.0)
		else:
			draw_rect(Rect2(29, y - 5, 10, 10), Color(0.55, 0.58, 0.68), false, 2.0)
