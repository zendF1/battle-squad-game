extends Node2D
## Rô-bốt Thép's Bom mù bursting over the party (ShotResolved airburst {position, radius}): a
## blinding white flash at the burst point, a white-blue shock ring opening to the burst's reach,
## light rays spinning out, and glittering motes drifting down over everyone it blinds. Drawn in
## code, timed from its own start (the event's t), freed when done. ScreenFlash (below): the whole
## screen goes white for a blink.

const LIFE := 1.4
const RAYS := 14
const MOTES := 46
const CORE := Color(1.0, 1.0, 1.0)
const GLOW := Color(0.75, 0.9, 1.0)
const RING := Color(0.86, 0.95, 1.0)
const RING_EDGE := Color(0.32, 0.56, 0.95) # the ring's outer line: it reads over a pale sky

var radius := 200.0
var _t := 0.0
var _motes: Array = [] # [start offset, velocity, size, phase]


func _init(reach: float = 200.0) -> void:
	radius = maxf(reach, 40.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in MOTES:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.1, 0.8) * radius
		_motes.append([Vector2.from_angle(a) * d * Vector2(1.0, 0.6), Vector2(rng.randf_range(-30, 30), rng.randf_range(40, 120)),
			rng.randf_range(2.0, 4.5), rng.randf() * TAU])
	z_index = 4


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


## 0..1 of its life (tests).
func progress() -> float:
	return clampf(_t / LIFE, 0.0, 1.0)


func _draw() -> void:
	var k := _t / LIFE
	# the shock ring opening to the reach
	var open := clampf(_t / 0.35, 0.0, 1.0)
	var ease_open := 1.0 - pow(1.0 - open, 3.0)
	var ring_a := clampf(1.0 - (_t - 0.2) / 0.6, 0.0, 1.0)
	if ring_a > 0.0:
		draw_arc(Vector2.ZERO, radius * ease_open + 4.0, 0.0, TAU, 72, Color(RING_EDGE, 0.75 * ring_a), 4.0, true)
		draw_arc(Vector2.ZERO, radius * ease_open, 0.0, TAU, 72, Color(RING, 0.9 * ring_a), 10.0 * (1.0 - 0.6 * open), true)
		draw_arc(Vector2.ZERO, radius * ease_open * 0.82, 0.0, TAU, 64, Color(GLOW, 0.4 * ring_a), 4.0, true)
	# the flash: a big soft white ball shrinking to a hot core
	var flash := clampf(1.0 - _t / 0.5, 0.0, 1.0)
	if flash > 0.0:
		for i in 6:
			var r := radius * (0.25 + 0.12 * i) * (0.7 + 0.3 * flash)
			draw_circle(Vector2.ZERO, r, Color(GLOW, 0.12 * flash))
		draw_circle(Vector2.ZERO, radius * 0.22 * (0.6 + 0.4 * flash) + 3.0, Color(RING_EDGE, 0.5 * flash))
		draw_circle(Vector2.ZERO, radius * 0.22 * (0.6 + 0.4 * flash), Color(CORE, 0.95 * flash))
	# the rays
	var ray_a := clampf(1.0 - (_t - 0.1) / 0.7, 0.0, 1.0)
	if ray_a > 0.0:
		for i in RAYS:
			var a := TAU * i / RAYS + _t * 1.6
			var len := radius * (0.55 + 0.35 * sin(i * 2.1)) * ease_open
			var dir := Vector2.from_angle(a)
			var side := dir.orthogonal() * (6.0 + 4.0 * sin(i * 1.3))
			var pts := PackedVector2Array([dir * radius * 0.12 + side, dir * len, dir * radius * 0.12 - side])
			draw_colored_polygon(pts, Color(CORE, 0.5 * ray_a))
	# the motes drifting down, twinkling
	var mote_a := clampf(1.0 - (k - 0.55) / 0.45, 0.0, 1.0) * clampf(_t / 0.15, 0.0, 1.0)
	if mote_a > 0.0:
		for m in _motes:
			var p: Vector2 = m[0] * (0.4 + 0.6 * ease_open) + m[1] * _t
			var tw := 0.6 + 0.4 * sin(_t * 9.0 + float(m[3]))
			draw_circle(p, float(m[2]), Color(CORE, mote_a * tw))
			draw_circle(p, float(m[2]) * 2.2, Color(GLOW, 0.25 * mote_a * tw))


## A white blink over the whole screen (a child of the screen CanvasLayer): full at once, gone
## in `sec`.
class ScreenFlash extends ColorRect:
	var sec := 0.35
	var peak := 0.75
	var _t := 0.0

	func _init(seconds: float = 0.35, strength: float = 0.75) -> void:
		sec = seconds
		peak = strength
		mouse_filter = MOUSE_FILTER_IGNORE
		set_anchors_preset(PRESET_FULL_RECT)
		color = Color(1, 1, 1, peak)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= sec:
			queue_free()
			return
		color.a = peak * (1.0 - _t / sec)
