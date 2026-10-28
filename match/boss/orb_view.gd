extends Node2D
## Rô-bốt Thép's energy orb (projectile kind "orb", Bom mù) in flight: a white-hot core in a
## pulsing pale-blue halo, little electric arcs crackling round it, and a trail of fading glow
## motes; ShotPlayer moves it along the server path (no turning: it is round). Drawn in code.

const RADIUS := 17.0
const TRAIL := 16
const CORE := Color(1.0, 1.0, 1.0)
const HALO := Color(0.62, 0.86, 1.0)
const ARC := Color(0.85, 0.95, 1.0)

var _t := 0.0
var _trail: Array = [] # [global position, age]
var _since := 0.0


func _ready() -> void:
	z_index = 3


## ShotPlayer feeds the path's tangent; the orb is round, nothing turns.
func set_tangent(_v: Vector2) -> void:
	pass


func _process(delta: float) -> void:
	_t += delta
	_since += delta
	for p in _trail:
		p[1] = float(p[1]) + delta
	while not _trail.is_empty() and float(_trail[0][1]) > 0.45:
		_trail.pop_front()
	if _since >= 0.025 and is_inside_tree():
		_since = 0.0
		_trail.append([global_position, 0.0])
		if _trail.size() > TRAIL:
			_trail.pop_front()
	queue_redraw()


func _draw() -> void:
	for p in _trail:
		var k := 1.0 - float(p[1]) / 0.45
		var at: Vector2 = to_local(p[0])
		draw_circle(at, RADIUS * (0.25 + 0.55 * k), Color(HALO, 0.28 * k))
	var pulse := 0.5 + 0.5 * sin(_t * 14.0)
	for i in 4:
		draw_circle(Vector2.ZERO, RADIUS * (1.9 - 0.25 * i) * (0.95 + 0.08 * pulse), Color(HALO, 0.1 + 0.05 * i))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.78, 0.92, 1.0, 0.95))
	draw_circle(Vector2(-RADIUS * 0.22, -RADIUS * 0.22), RADIUS * 0.62, CORE)
	for i in 3:
		var a := _t * 7.0 + TAU * i / 3.0 + sin(_t * 23.0 + i) * 0.6
		var pts := PackedVector2Array()
		for j in 5:
			var r := RADIUS * (1.0 + 0.22 * j)
			var jit := sin(_t * 41.0 + i * 3.0 + j * 2.0) * 0.28
			pts.append(Vector2.from_angle(a + jit + j * 0.18) * r)
		draw_polyline(pts, Color(ARC, 0.85), 2.0, true)
