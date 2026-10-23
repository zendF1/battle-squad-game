extends Node2D
## Tanko's Địa chấn liên hoàn shell (bomb_chain.gd): a dirt-wrapped boulder tumbling along the
## server path, drawn in code (original art, outlined cartoon style): a lumpy grey-brown stone
## shaded from the upper left, cracks, clods of earth caked on it and a few pebbles stuck in the
## dirt; behind it a trail of dirt crumbs falling off and dust puffs. ShotPlayer moves it and
## feeds the path's tangent (set_tangent()); it tumbles forward along its flight. The trail
## particles live in a fixed pool (global positions, the oldest reused). Visual only.

const UnitShell := preload("res://match/views/unit_shell.gd")

const OUT := Color(0.12, 0.08, 0.05)
const STONE := Color(0.55, 0.5, 0.44)
const STONE_LIT := Color(0.74, 0.69, 0.6)
const STONE_DARK := Color(0.36, 0.32, 0.28)
const DIRT := Color(0.47, 0.32, 0.18)
const DIRT_DARK := Color(0.33, 0.22, 0.12)
const DUST := Color(0.66, 0.57, 0.45)
const CRUMBS := [Color(0.45, 0.31, 0.18), Color(0.36, 0.25, 0.15), Color(0.56, 0.42, 0.27), Color(0.5, 0.47, 0.42)]
const POOL := 26
const EVERY := 6.0 # px of flight between two trail particles
const GRAVITY := 900.0 # the crumbs fall
const SPIN := 7.0 # rad/s tumbling at a normal shot's speed (faster flights tumble faster)
## The boulder's radius against a player character's shell (UnitShell.player_shell_px()): the bomb
## chain's bombs were 1.4 × a shell.
const SIZE_K := 0.8

var heading := Vector2.ZERO
var radius := 12.0
var _dir := Vector2.RIGHT
var _tangent := Vector2.ZERO
var _angle := 0.0
var _t := 0.0
var _last := Vector2.INF
var _since := 0.0
var _seed := 0.0
var _shape := PackedVector2Array() # the stone's outline, unit radius
var _pool: Array = [] # [global position, velocity, age, life, size, kind (0 crumb, 1 dust), colour]
var _next := 0


func _init() -> void:
	_seed = randf() * 100.0
	radius = UnitShell.player_shell_px() * SIZE_K
	for i in 14:
		var a := TAU * i / 14.0
		var r := 1.0 + 0.13 * sin(a * 3.0 + _seed) + 0.08 * sin(a * 5.0 + _seed * 1.7)
		_shape.append(Vector2(cos(a), sin(a) * 0.92) * r)
	for i in POOL:
		_pool.append([Vector2.ZERO, Vector2.ZERO, 1.0, 0.0, 1.0, 0, Color.WHITE])


func _ready() -> void:
	if heading.length_squared() > 0.0:
		_dir = heading.normalized()


## The path's tangent (any length): it tumbles along it.
func set_tangent(v: Vector2) -> void:
	if v.length_squared() > 0.0:
		_tangent = v
		_dir = v.normalized()


## Its outline in its own frame (unit radius; tests).
func shape() -> PackedVector2Array:
	return _shape


## Trail particles alive (tests).
func trail_alive() -> int:
	var n := 0
	for q in _pool:
		if q[2] < q[3]:
			n += 1
	return n


func _process(delta: float) -> void:
	_t += delta
	var speed := _tangent.length()
	_angle += signf(_dir.x if absf(_dir.x) > 0.05 else 1.0) * SPIN * clampf(speed / 700.0, 0.4, 1.6) * delta
	if _last != Vector2.INF:
		_since += global_position.distance_to(_last)
	_last = global_position
	while _since >= EVERY:
		_since -= EVERY
		_emit()
	for q in _pool:
		if q[2] >= q[3]:
			continue
		q[2] += delta
		if q[5] == 0:
			q[1].y += GRAVITY * delta
		else:
			q[1] *= 1.0 - 2.2 * delta
		q[0] += q[1] * delta
	queue_redraw()


func _emit() -> void:
	var back := -_dir
	var side := _dir.orthogonal()
	var crumb := randf() < 0.62
	var q: Array = _pool[_next]
	_next = (_next + 1) % POOL
	var at := global_position + back * radius * 0.7 + side * randf_range(-0.7, 0.7) * radius
	q[0] = at
	if crumb:
		q[1] = back * randf_range(20.0, 70.0) + side * randf_range(-50.0, 50.0) + Vector2(0, -randf_range(0.0, 60.0))
		q[3] = randf_range(0.45, 0.8)
		q[4] = randf_range(1.6, 3.2) * radius / 12.0
		q[5] = 0
		q[6] = CRUMBS[randi() % CRUMBS.size()]
	else:
		q[1] = back * randf_range(10.0, 40.0) + Vector2(0, -randf_range(5.0, 20.0))
		q[3] = randf_range(0.5, 0.85)
		q[4] = randf_range(4.0, 7.0) * radius / 12.0
		q[5] = 1
		q[6] = DUST
	q[2] = 0.0


func _draw() -> void:
	# the trail, in global positions
	for q in _pool:
		if q[2] >= q[3]:
			continue
		var f: float = q[2] / q[3]
		var p: Vector2 = q[0] - global_position
		var col: Color = q[6]
		if q[5] == 0:
			var s: float = q[4]
			draw_set_transform(p, q[2] * 9.0, Vector2.ONE)
			draw_rect(Rect2(-s, -s * 0.8, s * 2.0, s * 1.6), Color(col, 1.0 - f * f))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_circle(p, float(q[4]) * (0.6 + 1.4 * f), Color(col, 0.42 * (1.0 - f)))
	var r := radius
	var rot := _angle
	var pts := PackedVector2Array()
	for v in _shape:
		pts.append(v.rotated(rot) * r)
	var ring := pts.duplicate()
	ring.append(pts[0])
	# body: dark base, then the lit stone offset to the upper left (the light stays fixed)
	draw_colored_polygon(pts, STONE_DARK)
	var lit := PackedVector2Array()
	for v in pts:
		lit.append(v * 0.84 + Vector2(-0.12, -0.14) * r)
	draw_colored_polygon(lit, STONE)
	draw_circle(Vector2(-0.34, -0.36) * r, r * 0.26, Color(STONE_LIT, 0.9))
	# clods of earth caked on it (they turn with it)
	for c in [[0.5, 0.38, 0.46], [2.4, 0.42, 0.4], [4.3, 0.36, 0.34]]:
		var at := Vector2.from_angle(float(c[0]) + rot) * r * float(c[1]) * 1.4
		var cr := r * float(c[2])
		var clod := PackedVector2Array()
		for i in 9:
			var a := TAU * i / 9.0
			clod.append(at + Vector2(cos(a), sin(a)) * cr * (0.85 + 0.2 * sin(a * 3.0 + float(c[0]))))
		draw_colored_polygon(clod, DIRT)
		draw_circle(at + Vector2(0.2, 0.25) * cr, cr * 0.45, DIRT_DARK)
	# pebbles in the dirt
	for c in [[1.1, 0.62], [3.3, 0.58], [5.4, 0.66]]:
		draw_circle(Vector2.from_angle(float(c[0]) + rot) * r * float(c[1]), r * 0.11, STONE_LIT)
	# a crack across the stone
	var a0 := rot + 0.9
	draw_polyline(PackedVector2Array([Vector2.from_angle(a0) * r * 0.85, Vector2.from_angle(a0 + 0.5) * r * 0.25,
		Vector2.from_angle(a0 + 2.6) * r * 0.15, Vector2.from_angle(a0 + 2.9) * r * 0.6]), Color(OUT, 0.7), maxf(1.0, r * 0.08), true)
	draw_polyline(ring, OUT, maxf(1.5, r * 0.13), true)
