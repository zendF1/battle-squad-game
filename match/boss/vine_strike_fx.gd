extends Node2D
## Mộc Tinh's Roi dây leo under one party member (boss v4, a ground_strike event: position its feet,
## radius its reach), on the fx layer at the feet: the soil bursts open and thorny vines whip up out
## of it (StatusFx.draw_vines(), the vines look's code, thorny), overshooting, lashing from side to
## side while they stand, then sinking back into the ground; clods of earth and leaves fly. The root
## a hit may get is the status's own look on the body after it. Visual only; frees itself.

const StatusFx := preload("res://match/views/status_fx.gd")

const RISE := 0.16
const HOLD := 0.55
const SINK := 0.35
const LIFE := RISE + HOLD + SINK
const CLODS := 12
const LEAVES := 6
const GRAVITY := 900.0

var radius := 60.0
var _t := 0.0
var _seed := 0.0
var _bits: Array = [] # [{p, v, r, leaf, spin}]


func _init(reach: float = 60.0) -> void:
	radius = clampf(reach, 24.0, 160.0)
	_seed = randf() * 10.0
	z_index = 3 # over the players: the vines wrap round them
	for i in CLODS + LEAVES:
		var leaf := i >= CLODS
		var ang := randf_range(-PI * 0.9, -PI * 0.1)
		_bits.append({"p": Vector2(randf_range(-0.6, 0.6) * radius, -3.0), "v": Vector2.from_angle(ang) * randf_range(160.0, 380.0),
			"r": randf_range(2.5, 5.0) if not leaf else randf_range(3.5, 5.5), "leaf": leaf, "spin": randf_range(-8.0, 8.0)})


func age() -> float:
	return _t


## How far the vines stand now (0..1): bursting up with an overshoot, standing, sinking back.
static func grow_at(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t < RISE:
		var u := t / RISE
		return 1.0 + 2.4 * pow(u - 1.0, 3.0) + 1.4 * pow(u - 1.0, 2.0)
	if t < RISE + HOLD:
		return 1.0
	return clampf(1.0 - (t - RISE - HOLD) / SINK, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE + 0.3:
		queue_free()
		return
	for b in _bits:
		b["v"] = Vector2(b["v"]) + Vector2(0, GRAVITY * (0.35 if b["leaf"] else 1.0) * delta)
		if b["leaf"]:
			b["v"] = Vector2(b["v"]) * (1.0 - 2.0 * delta)
		b["p"] = Vector2(b["p"]) + Vector2(b["v"]) * delta
	queue_redraw()


func _draw() -> void:
	var g := grow_at(_t)
	var a := clampf((LIFE + 0.3 - _t) / 0.3, 0.0, 1.0)
	# the soil torn open
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, radius * (0.55 + 0.25 * minf(_t / RISE, 1.0)), Color(0.3, 0.2, 0.1, 0.75 * a))
	draw_circle(Vector2.ZERO, radius * 0.4, Color(0.18, 0.11, 0.05, 0.6 * a))
	draw_set_transform(Vector2.ZERO)
	if g > 0.0:
		var lash := sin(_t * 9.0) * 0.18 * (1.0 if _t > RISE else _t / RISE)
		var h := radius * 3.4
		var w := radius * 1.05
		StatusFx.draw_vines(self, h, w, g, a, false, true, lash, _seed)
		StatusFx.draw_vines(self, h, w, g, a, true, true, lash, _seed)
	for b in _bits:
		var k := clampf(_t / 0.9, 0.0, 1.0)
		var fade := (1.0 - k) * a
		if fade <= 0.0:
			continue
		var p: Vector2 = b["p"]
		if b["leaf"]:
			var rot := float(b["spin"]) * _t
			var r: float = b["r"]
			var pts := PackedVector2Array()
			for i in 8:
				var ang := TAU * i / 8.0
				pts.append(p + Vector2(cos(ang) * r, sin(ang) * r * 0.45).rotated(rot))
			draw_colored_polygon(pts, Color(StatusFx.LEAF, fade))
		else:
			draw_circle(p, b["r"], Color(0.34, 0.22, 0.12, fade))
			draw_circle(p + Vector2(-0.8, -0.8), float(b["r"]) * 0.4, Color(0.52, 0.38, 0.22, fade))
