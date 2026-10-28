extends Node2D
## The nuke's / laser's signal in flight (projectile kind "signal"): a small flare canister (red
## with a white band, a laser's magenta) turned to its flight, its cap blinking with a light, and
## a trail of red sparks and smoke behind it. ShotPlayer moves it along the server path
## (set_tangent() the path's tangent). Visual only.

const TRAIL_EVERY := 7.0 # px flown between two trail puffs
const PUFF_LIFE := 0.7
const MAX_PUFFS := 48
const RED := Color(1.0, 0.2, 0.15)
const MAGENTA := Color(1.0, 0.25, 0.75)

var heading := Vector2.ZERO
var laser := false

var _dir := Vector2.RIGHT
var _t := 0.0
var _last := Vector2.INF
var _since := 0.0
var _puffs: Array = [] # [global position, age, drift]


func _ready() -> void:
	z_index = 1
	if heading.length_squared() > 0.0:
		_dir = heading.normalized()


func set_tangent(v: Vector2) -> void:
	if v.length_squared() > 1.0:
		_dir = v.normalized()


func color() -> Color:
	return MAGENTA if laser else RED


func _process(delta: float) -> void:
	_t += delta
	var g := global_position
	if _last != Vector2.INF:
		_since += g.distance_to(_last)
		while _since >= TRAIL_EVERY:
			_since -= TRAIL_EVERY
			_puffs.append([g, 0.0, Vector2(randf_range(-12, 12), randf_range(-26, -8))])
			if _puffs.size() > MAX_PUFFS:
				_puffs.pop_front()
	_last = g
	for q in _puffs:
		q[1] += delta
		q[0] += q[2] * delta
	while not _puffs.is_empty() and _puffs[0][1] >= PUFF_LIFE:
		_puffs.pop_front()
	queue_redraw()


func _draw() -> void:
	var c := color()
	for q in _puffs:
		var f: float = q[1] / PUFF_LIFE
		var p: Vector2 = to_local(q[0])
		draw_circle(p, lerpf(3.0, 9.0, f), Color(0.55, 0.5, 0.5, 0.35 * (1.0 - f)), true, -1.0, true)
		if f < 0.4:
			draw_circle(p, lerpf(2.6, 1.0, f / 0.4), Color(c.lightened(0.4), 1.0 - f / 0.4), true, -1.0, true)
	var blink := 0.5 + 0.5 * sin(_t * 26.0)
	draw_circle(_dir * 7.0, 13.0 + 5.0 * blink, Color(c, 0.22 + 0.2 * blink), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, _dir.angle(), Vector2.ONE)
	var outline := Color(0.08, 0.06, 0.1)
	draw_rect(Rect2(-9, -4.5, 16, 9), outline)
	draw_rect(Rect2(-8, -3.5, 14, 7), c)
	draw_rect(Rect2(-3, -3.5, 3, 7), Color(0.96, 0.96, 1.0))
	draw_circle(Vector2(7, 0), 4.0, outline, true, -1.0, true)
	draw_circle(Vector2(7, 0), 3.0, Color(1.0, 0.95, 0.7).lerp(c, 1.0 - blink), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
