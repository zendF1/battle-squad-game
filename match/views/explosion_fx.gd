extends Node2D
## An explosion: the burst frames (assets/fx/explosion_0..N.png: shock ring, fireballs, flash)
## scaled to the crater radius, smoke puffs (assets/fx/smoke.png) drifting up and fading, and
## debris chunks (assets/fx/debris.png, tinted dirt/grass) thrown out with gravity. Set radius
## before adding it; it frees itself after LIFE seconds. Images via ui/art.gd.

const Art := preload("res://ui/art.gd")

const LIFE := 1.1
const GRAVITY := 900.0
const BURST_SEC := 0.5 # the frames play over this time

var radius := 30.0

var _t := 0.0
var _smoke: Array = [] # [offset, size, drift, spin]
var _debris: Array = [] # [velocity, size, color, spin]
var _frames: Array[Texture2D] = []
var _smoke_tex: Texture2D
var _debris_tex: Texture2D


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for i in Art.EXPLOSION_FRAMES:
		_frames.append(Art.explosion(i))
	_smoke_tex = Art.fx("smoke")
	_debris_tex = Art.fx("debris")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 7:
		var off := Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.6, 0.1)) * radius
		_smoke.append([off, rng.randf_range(0.4, 0.7), Vector2(rng.randf_range(-20, 20), rng.randf_range(-70, -35)), rng.randf_range(-1.0, 1.0)])
	var dirt := [Color(0.42, 0.28, 0.16), Color(0.3, 0.2, 0.12), Color(0.36, 0.6, 0.25)]
	for i in 12:
		var a := rng.randf_range(-PI * 0.95, -PI * 0.05) # mostly upward
		_debris.append([Vector2.from_angle(a) * rng.randf_range(180, 420), rng.randf_range(2.0, 4.0), dirt[i % dirt.size()], rng.randf_range(-12.0, 12.0)])


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _t
	# Smoke (behind the fire), from 0.08 s: grows, drifts up, fades.
	if t > 0.08:
		var s := (t - 0.08) / (LIFE - 0.08)
		for p in _smoke:
			var at: Vector2 = p[0] + p[2] * (t - 0.08)
			var r: float = radius * p[1] * (0.8 + s * 0.9) * 1.25
			draw_set_transform(at, p[3] * s, Vector2.ONE)
			draw_texture_rect(_smoke_tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(0.55, 0.52, 0.55, 0.85 * (1.0 - s)))
		draw_set_transform(Vector2.ZERO)
	# The burst frames.
	if t < BURST_SEC and not _frames.is_empty():
		var i := mini(int(t / BURST_SEC * _frames.size()), _frames.size() - 1)
		var tex := _frames[i]
		var k := radius / Art.EXPLOSION_RADIUS
		var sz := tex.get_size() * k
		draw_texture_rect(tex, Rect2(-sz / 2, sz), false)
	# Debris.
	for d in _debris:
		var v: Vector2 = d[0]
		var at := v * t + Vector2(0, 0.5 * GRAVITY * t * t)
		var a := clampf(1.0 - t / LIFE, 0.0, 1.0)
		var r: float = d[1] * 1.4
		draw_set_transform(at, d[3] * t, Vector2.ONE)
		draw_texture_rect(_debris_tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(d[2], a))
		draw_set_transform(Vector2.ZERO)
