extends Node2D
## The nuke falling from the sky (projectile kind "nuke", Bom huỷ diệt): a fat yellow bomb, nose
## along its flight (down), grey tail fins, the black radiation sign on it, a hot glow on its nose
## and a smoke trail. ShotPlayer moves it along the server path. Visual only.

const TRAIL_EVERY := 10.0
const PUFF_LIFE := 0.6
const MAX_PUFFS := 40
const BODY := Color(0.99, 0.82, 0.12)
const FIN := Color(0.42, 0.44, 0.52)
const OUTLINE := Color(0.07, 0.07, 0.12)
const SIZE := 1.6 # × the drawing below (about 26 × 40 units)

var heading := Vector2.DOWN

var _dir := Vector2.DOWN
var _t := 0.0
var _last := Vector2.INF
var _since := 0.0
var _puffs: Array = [] # [global position, age]


func _ready() -> void:
	z_index = 1
	if heading.length_squared() > 0.0:
		_dir = heading.normalized()


func set_tangent(v: Vector2) -> void:
	if v.length_squared() > 1.0:
		_dir = v.normalized()


func _process(delta: float) -> void:
	_t += delta
	var g := global_position
	if _last != Vector2.INF:
		_since += g.distance_to(_last)
		while _since >= TRAIL_EVERY:
			_since -= TRAIL_EVERY
			_puffs.append([g - _dir * 30.0 * SIZE + Vector2(randf_range(-6, 6), 0), 0.0])
			if _puffs.size() > MAX_PUFFS:
				_puffs.pop_front()
	_last = g
	for q in _puffs:
		q[1] += delta
	while not _puffs.is_empty() and _puffs[0][1] >= PUFF_LIFE:
		_puffs.pop_front()
	queue_redraw()


func _draw() -> void:
	for q in _puffs:
		var f: float = q[1] / PUFF_LIFE
		draw_circle(to_local(q[0]), lerpf(8.0, 20.0, f), Color(0.75, 0.75, 0.78, 0.4 * (1.0 - f)), true, -1.0, true)
	draw_circle(_dir * 22.0 * SIZE, 18.0 * SIZE, Color(1.0, 0.55, 0.15, 0.18 + 0.08 * sin(_t * 30.0)), true, -1.0, true)
	# the drawing points along +y (nose down), turned to the flight
	draw_set_transform(Vector2.ZERO, _dir.angle() - PI / 2, Vector2(SIZE, SIZE))
	_poly([Vector2(-12, -26), Vector2(12, -26), Vector2(8, -12), Vector2(-8, -12)], FIN)
	_poly([Vector2(-3, -30), Vector2(3, -30), Vector2(3, -12), Vector2(-3, -12)], FIN.lightened(0.15))
	var body := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		body.append(Vector2(cos(a) * 13.0, sin(a) * (20.0 if sin(a) > 0 else 16.0)) + Vector2(0, 2))
	_poly(body, BODY)
	draw_arc(Vector2(-4, -4), 8.0, PI * 1.05, PI * 1.5, 8, Color(1, 1, 1, 0.7), 2.5, true)
	var s := Vector2(0, 4)
	draw_circle(s, 2.2, OUTLINE, true, -1.0, true)
	for i in 3:
		var a0 := PI / 2 + TAU * i / 3.0 - PI / 6
		var pts := PackedVector2Array()
		for k in 7:
			pts.append(s + Vector2.from_angle(lerpf(a0, a0 + PI / 3, k / 6.0)) * 9.0)
		for k in 5:
			pts.append(s + Vector2.from_angle(lerpf(a0 + PI / 3, a0, k / 4.0)) * 3.8)
		draw_colored_polygon(pts, OUTLINE)
	draw_set_transform(Vector2.ZERO)


func _poly(pts: Variant, fill: Color) -> void:
	var packed := PackedVector2Array(pts)
	for o in Geometry2D.offset_polygon(packed, 2.0, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(o, OUTLINE)
	draw_colored_polygon(packed, fill)
