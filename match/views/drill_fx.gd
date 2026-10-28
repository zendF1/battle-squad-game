extends Node2D
## The drill boring through the ground (a ShotResolved "drill" event, match_screen.gd _drill()):
## where the bit bites in, a burst of dirt clods and dust thrown back out of the hole; while it
## bores (its TunnelDig says where the bit is), hot grit sparking off the bit and spoil puffing
## out of the hole; where it stops, a smaller burst. The particles fall and fade, then it frees
## itself. The tunnel itself is the terrain mask's (opened by the TunnelDig); this only draws.

const Art := preload("res://ui/art.gd")

const DIRT := [Color(0.45, 0.32, 0.2), Color(0.56, 0.41, 0.26), Color(0.36, 0.26, 0.17)]
const DUST := Color(0.74, 0.64, 0.52)
const GRIT := Color(1.0, 0.8, 0.4)
const GRAVITY := 900.0 # px/s² on the clods and the grit
const EMIT_EVERY := 0.035 # s between the boring's puffs and grit
const LINGER := 1.3 # s the last particles may live after the bit stops

var dig # TunnelDig
var _t := 0.0
var _clods: Array = [] # [position, velocity, age, life, size, angle, spin, colour]
var _puffs: Array = [] # [position, velocity, age, life, size]
var _grit: Array = [] # [position, velocity, age, life]
var _since := 0.0
var _ended := false
var _smoke: Texture2D
var _rng := RandomNumberGenerator.new()


func _init(d = null) -> void:
	dig = d


func _ready() -> void:
	_rng.randomize()
	_smoke = Art.fx("smoke")
	if dig == null:
		queue_free()
		return
	burst(dig.entry(), -bore_dir(true), 1.0)


## The bore's direction at its start (or its end), down when the path is a single point.
func bore_dir(at_start: bool) -> Vector2:
	var p: PackedVector2Array = dig.path
	if p.size() < 2:
		return Vector2.DOWN
	var d := (p[mini(3, p.size() - 1)] - p[0]) if at_start else (p[-1] - p[maxi(p.size() - 4, 0)])
	return d.normalized() if d.length_squared() > 0.0 else Vector2.DOWN


## Clods and dust thrown out from `at` round `out` (a fan of ±70°), `amount` 1 = the full burst.
func burst(at: Vector2, out: Vector2, amount: float) -> void:
	var up := (out + Vector2.UP * 0.6).normalized()
	for i in int(14 * amount):
		var v := up.rotated(_rng.randf_range(-1.2, 1.2)) * _rng.randf_range(160.0, 380.0)
		_clods.append([at, v, 0.0, _rng.randf_range(0.5, 0.9), _rng.randf_range(2.5, 5.5), _rng.randf() * TAU,
			_rng.randf_range(-12.0, 12.0), DIRT[i % DIRT.size()]])
	for i in int(7 * amount):
		var v := up.rotated(_rng.randf_range(-0.9, 0.9)) * _rng.randf_range(30.0, 90.0)
		_puffs.append([at, v, 0.0, _rng.randf_range(0.6, 1.0), _rng.randf_range(16.0, 28.0) * (0.7 + 0.3 * amount)])


func _process(delta: float) -> void:
	_t += delta
	if not _ended:
		if _t < dig.duration:
			_since += delta
			while _since >= EMIT_EVERY:
				_since -= EMIT_EVERY
				_boring()
		else:
			_ended = true
			burst(dig.end(), bore_dir(false), 0.55)
	_step(delta)
	queue_redraw()
	if (_ended and _clods.is_empty() and _puffs.is_empty() and _grit.is_empty()) or _t > dig.duration + LINGER:
		queue_free()


## While it bores: grit off the bit (back along the bore, spread), spoil puffing out of the hole.
func _boring() -> void:
	var at: Vector2 = dig.head(_t)
	var back := -bore_dir(true)
	for i in 3:
		var v := back.rotated(_rng.randf_range(-1.1, 1.1)) * _rng.randf_range(140.0, 300.0)
		_grit.append([at, v, 0.0, _rng.randf_range(0.18, 0.32)])
	var up := (back + Vector2.UP * 0.8).normalized()
	_puffs.append([dig.entry(), up.rotated(_rng.randf_range(-0.6, 0.6)) * _rng.randf_range(40.0, 80.0), 0.0,
		_rng.randf_range(0.45, 0.7), _rng.randf_range(10.0, 18.0)])
	if _rng.randf() < 0.6:
		var v := up.rotated(_rng.randf_range(-0.8, 0.8)) * _rng.randf_range(120.0, 260.0)
		_clods.append([dig.entry(), v, 0.0, _rng.randf_range(0.4, 0.7), _rng.randf_range(2.0, 4.0), _rng.randf() * TAU,
			_rng.randf_range(-12.0, 12.0), DIRT[_rng.randi() % DIRT.size()]])


func _step(delta: float) -> void:
	for c in _clods:
		c[1] += Vector2(0.0, GRAVITY * delta)
		c[0] += c[1] * delta
		c[2] += delta
		c[5] += c[6] * delta
	for p in _puffs:
		p[1] *= 1.0 - minf(2.5 * delta, 1.0)
		p[0] += p[1] * delta
		p[2] += delta
	for g in _grit:
		g[1] += Vector2(0.0, GRAVITY * 0.5 * delta)
		g[0] += g[1] * delta
		g[2] += delta
	_clods = _clods.filter(func(c): return c[2] < c[3])
	_puffs = _puffs.filter(func(p): return p[2] < p[3])
	_grit = _grit.filter(func(g): return g[2] < g[3])


func _draw() -> void:
	for p in _puffs:
		var k: float = p[2] / p[3]
		var s: float = p[4] * (0.6 + 0.8 * k)
		var col := Color(DUST, 0.55 * (1.0 - k))
		if _smoke != null:
			draw_texture_rect(_smoke, Rect2(p[0] - Vector2(s, s), Vector2(s, s) * 2.0), false, col)
		else:
			draw_circle(p[0], s, col, true, -1.0, true)
	for c in _clods:
		var k: float = c[2] / c[3]
		var col: Color = c[7]
		col.a = 1.0 - k * k
		var r: float = c[4]
		var a: float = c[5]
		var pts := PackedVector2Array()
		for i in 4:
			pts.append(c[0] + Vector2.from_angle(a + TAU * i / 4.0) * r * (1.0 if i % 2 == 0 else 0.7))
		draw_colored_polygon(pts, col)
	for g in _grit:
		var k: float = g[2] / g[3]
		var tail: Vector2 = g[1] * 0.025
		draw_line(g[0] - tail, g[0], Color(GRIT, 1.0 - k), 2.0, true)
