extends Node2D
## An explosion (placeholder art): a shock ring, a layered flash and fireballs, smoke puffs
## drifting up and a few debris dots thrown out with gravity. Set radius before adding it; it
## frees itself after LIFE seconds.

const LIFE := 1.1
const GRAVITY := 900.0

var radius := 30.0

var _t := 0.0
var _fire: Array = [] # [offset, size]
var _smoke: Array = [] # [offset, size, drift]
var _debris: Array = [] # [velocity, size, color]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 6:
		_fire.append([Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.2, 0.6), rng.randf_range(0.35, 0.6)])
	for i in 7:
		var off := Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.6, 0.1)) * radius
		_smoke.append([off, rng.randf_range(0.4, 0.7), Vector2(rng.randf_range(-20, 20), rng.randf_range(-70, -35))])
	var dirt := [Color(0.42, 0.28, 0.16), Color(0.3, 0.2, 0.12), Color(0.36, 0.6, 0.25)]
	for i in 12:
		var a := rng.randf_range(-PI * 0.95, -PI * 0.05) # mostly upward
		_debris.append([Vector2.from_angle(a) * rng.randf_range(180, 420), rng.randf_range(2.0, 4.0), dirt[i % dirt.size()]])


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _t
	# Smoke (behind the fire), from 0.1 s: grows, drifts up, fades.
	if t > 0.08:
		var s := (t - 0.08) / (LIFE - 0.08)
		for p in _smoke:
			var at: Vector2 = p[0] + p[2] * (t - 0.08)
			var r: float = radius * p[1] * (0.8 + s * 0.9)
			draw_circle(at, r, Color(0.32, 0.3, 0.32, 0.55 * (1.0 - s)))
			draw_circle(at + Vector2(-r * 0.25, -r * 0.25), r * 0.6, Color(0.5, 0.48, 0.5, 0.35 * (1.0 - s)))
	# Shock ring.
	if t < 0.32:
		var k := t / 0.32
		draw_arc(Vector2.ZERO, radius * (0.6 + k * 1.1), 0.0, TAU, 48, Color(1, 0.97, 0.85, 0.8 * (1.0 - k)), 6.0 * (1.0 - k) + 1.5, true)
	# Fireballs and flash: bigger than the crater, shrinking back as they fade.
	if t < 0.5:
		var k := t / 0.5
		var grow := 0.75 + 0.55 * ease(k, 0.25)
		var a := 1.0 - k * k
		draw_circle(Vector2.ZERO, radius * 1.25 * grow, Color(1.0, 0.5, 0.15, 0.35 * a))
		for p in _fire:
			draw_circle(p[0] * grow * 1.4, radius * p[1] * 1.3 * grow, Color(1.0, 0.42, 0.1, 0.9 * a))
		draw_circle(Vector2.ZERO, radius * 0.95 * grow, Color(1.0, 0.68, 0.2, 0.9 * a))
		draw_circle(Vector2.ZERO, radius * 0.6 * grow, Color(1.0, 0.92, 0.5, 0.95 * a))
		if t < 0.14:
			draw_circle(Vector2.ZERO, radius * 0.7, Color(1, 1, 0.92, 1.0 - t / 0.14))
	# Debris.
	for d in _debris:
		var v: Vector2 = d[0]
		var at := v * t + Vector2(0, 0.5 * GRAVITY * t * t)
		var a := clampf(1.0 - t / LIFE, 0.0, 1.0)
		draw_circle(at, d[1], Color(d[2], a))
