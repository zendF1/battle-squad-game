extends Node2D
## What a minion blowing up adds over its ExplosionFx burst (match_screen._unit_blast(): a bomber's
## detonation, a snowman's death blast): a white flash, a shockwave ring running out to the blast's
## radius (so the reach shows), and its debris: hot shrapnel streaks and dark smoke, or for an icy
## blast (icy) ice shards tumbling out, frost mist and snow glints. Visual only; set radius, icy and
## color before adding it. It frees itself when done.

const LIFE := 1.2
const FLASH_SEC := 0.14
const WAVE_SEC := 0.45
const GRAVITY := 700.0
const BITS := 16

var radius := 80.0
var icy := false
var color := Color(1.0, 0.55, 0.2)

var _t := 0.0
var _bits: Array = [] # [{p, v, rot, spin, size}]
var _puffs: Array = [] # [{p, v, size}]


func _ready() -> void:
	var r := maxf(radius, 20.0)
	for i in BITS:
		var a := -PI * randf_range(0.05, 0.95) if i % 3 != 0 else randf_range(0.0, TAU)
		var speed := r * randf_range(3.0, 6.0)
		_bits.append({"p": Vector2.ZERO, "v": Vector2(cos(a), sin(a)) * speed, "rot": randf() * TAU,
			"spin": randf_range(-12.0, 12.0), "size": randf_range(0.06, 0.12) * r})
	for i in 8:
		var a := TAU * i / 8.0 + randf_range(-0.3, 0.3)
		_puffs.append({"p": Vector2(cos(a), sin(a) * 0.5) * r * 0.25, "v": Vector2(cos(a) * r * 0.6, -r * randf_range(0.3, 0.8)),
			"size": randf_range(0.22, 0.34) * r})


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	for b in _bits:
		b["v"] = b["v"] + Vector2(0, GRAVITY * delta)
		b["p"] = b["p"] + b["v"] * delta
		b["rot"] = float(b["rot"]) + float(b["spin"]) * delta
	for p in _puffs:
		p["p"] = p["p"] + p["v"] * delta
		p["v"] = p["v"] * maxf(0.0, 1.0 - delta * 2.5)
	queue_redraw()


func _draw() -> void:
	var r := maxf(radius, 20.0)
	var k := _t / LIFE
	# smoke / frost mist under everything
	for p in _puffs:
		var grow := 1.0 + k * 1.2
		var col := Color(0.88, 0.96, 1.0, 0.45 * (1.0 - k)) if icy else Color(0.18, 0.16, 0.16, 0.5 * (1.0 - k))
		draw_circle(p["p"], float(p["size"]) * grow, col)
	# the flash
	if _t < FLASH_SEC:
		var f := 1.0 - _t / FLASH_SEC
		draw_circle(Vector2.ZERO, r * (0.5 + 0.3 * (1.0 - f)), Color(1, 1, 1, 0.85 * f))
		draw_circle(Vector2.ZERO, r * 0.9, Color(color.lightened(0.4), 0.35 * f))
	# the shockwave out to the blast radius
	if _t < WAVE_SEC + 0.25:
		var w := clampf(_t / WAVE_SEC, 0.0, 1.0)
		var ease_w := 1.0 - (1.0 - w) * (1.0 - w)
		var fade := 1.0 - clampf((_t - WAVE_SEC * 0.6) / 0.4, 0.0, 1.0)
		var wave_col := Color(0.8, 0.96, 1.0) if icy else color.lightened(0.25)
		draw_arc(Vector2.ZERO, r * (0.25 + 0.75 * ease_w), 0.0, TAU, 48, Color(wave_col, 0.9 * fade), maxf(2.0, r * 0.12 * (1.0 - w)), true)
		draw_arc(Vector2.ZERO, r * (0.2 + 0.6 * ease_w), 0.0, TAU, 40, Color(1, 1, 1, 0.4 * fade), 2.0, true)
	# the debris
	for b in _bits:
		var fade := 1.0 - k
		var at: Vector2 = b["p"]
		var s := float(b["size"])
		if icy:
			var rot := float(b["rot"])
			var pts := PackedVector2Array([at + Vector2(0, -s).rotated(rot), at + Vector2(s * 0.45, 0).rotated(rot),
				at + Vector2(0, s).rotated(rot), at + Vector2(-s * 0.45, 0).rotated(rot)])
			draw_colored_polygon(pts, Color(0.6, 0.92, 1.0, fade))
			draw_line(pts[0], pts[2], Color(1, 1, 1, 0.8 * fade), 1.2, true)
		else:
			var tail: Vector2 = at - (b["v"] as Vector2).normalized() * s * 2.2
			draw_line(tail, at, Color(1.0, 0.75, 0.3, fade), maxf(1.5, s * 0.35), true)
			draw_circle(at, maxf(1.0, s * 0.25), Color(1.0, 0.95, 0.7, fade))
	if icy: # snow glints
		for i in 10:
			var a := TAU * i / 10.0 + _t * 1.5
			var at := Vector2(cos(a), sin(a) * 0.7) * r * (0.3 + k * 0.9)
			var g := 3.0 * (1.0 - k)
			draw_line(at - Vector2(g, 0), at + Vector2(g, 0), Color(1, 1, 1, 0.9 * (1.0 - k)), 1.4, true)
			draw_line(at - Vector2(0, g), at + Vector2(0, g), Color(1, 1, 1, 0.9 * (1.0 - k)), 1.4, true)


func elapsed() -> float:
	return _t
