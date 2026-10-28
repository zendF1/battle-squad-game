extends Node2D
## Khổng Lồ Đá's Động đất under one member (a global damage with no projectile): the ground at
## its feet splits in jagged glowing-amber cracks running out both ways, stone chips and dust
## jump up, then the cracks darken and fade. Origin at the feet. Drawn in code, freed when done.

const LIFE := 1.6
const CRACK := Color(0.2, 0.13, 0.08)
const GLOW := Color(1.0, 0.7, 0.3)
const DUST := Color(0.72, 0.6, 0.45)
const CHIP := Color(0.55, 0.45, 0.33)

var width := 120.0
var _t := 0.0
var _lines: Array = [] # each a PackedVector2Array
var _chips: Array = [] # [start, velocity, size, spin]
var _puffs: Array = [] # [offset, size]


func _init(span: float = 160.0, seed_value: int = 1) -> void:
	width = maxf(span, 60.0)
	z_index = 0 # on the ground layer (MarkView), over the terrain, under the players
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	for sgn in [-1.0, 1.0]:
		for branch in 2:
			var pts := PackedVector2Array([Vector2(sgn * rng.randf_range(0, 6), 0)])
			var x := 0.0
			var reach := width * (0.5 if branch == 0 else 0.3) * rng.randf_range(0.8, 1.1)
			while x < reach:
				x += rng.randf_range(8, 16)
				pts.append(Vector2(sgn * x, rng.randf_range(1, 9) + (8.0 if branch == 1 else 0.0)))
			_lines.append(pts)
	for i in 12:
		_chips.append([Vector2(rng.randf_range(-width * 0.3, width * 0.3), -2), Vector2(rng.randf_range(-90, 90), rng.randf_range(-330, -160)),
			rng.randf_range(3, 7), rng.randf_range(-8, 8)])
	for i in 9:
		_puffs.append([Vector2(rng.randf_range(-width * 0.5, width * 0.5), rng.randf_range(-8, 2)), rng.randf_range(20, 38)])


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var open := clampf(_t / 0.18, 0.0, 1.0)
	var fade := clampf(1.0 - (_t - 0.9) / 0.7, 0.0, 1.0)
	var glow := clampf(1.0 - _t / 0.8, 0.0, 1.0)
	for pts in _lines:
		var n := maxi(2, int(ceil(pts.size() * open)))
		var part: PackedVector2Array = pts.slice(0, n)
		if part.size() < 2:
			continue
		draw_polyline(part, Color(CRACK, 0.95 * fade), 9.0, true)
		if glow > 0.0:
			draw_polyline(part, Color(GLOW, 0.9 * glow), 3.5, true)
	for p in _puffs:
		var k := clampf(_t / 1.1, 0.0, 1.0)
		var r := float(p[1]) * (0.6 + 0.9 * k)
		draw_circle(p[0] + Vector2(0, -28.0 * k), r, Color(DUST, 0.55 * (1.0 - k)))
	for c in _chips:
		var p: Vector2 = c[0] + c[1] * _t + Vector2(0, 0.5 * 900.0 * _t * _t)
		if p.y > 6.0:
			continue
		var s := float(c[2])
		var rot := float(c[3]) * _t
		var pts := PackedVector2Array([Vector2(-s, -s * 0.6).rotated(rot), Vector2(s * 0.8, -s * 0.8).rotated(rot),
			Vector2(s, s * 0.5).rotated(rot), Vector2(-s * 0.6, s * 0.7).rotated(rot)])
		for i in pts.size():
			pts[i] += p
		draw_colored_polygon(pts, Color(CHIP, fade))
