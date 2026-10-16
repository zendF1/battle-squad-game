extends Node2D
## An explosion, drawn the way the shooter's gun hits (STYLES, by `kind`; the same kinds as
## projectile_view.gd): the burst frames scaled to the crater radius, smoke puffs drifting up and
## fading, and bits thrown out with gravity.
## - rookie: the explosion (assets/fx/explosion_0..N.png), grey smoke, dirt debris;
## - tanko: a bigger heavy blast (assets/fx/tanko/impact_*), dark smoke, more debris;
## - spark: an electric burst (cyan flash, lightning arcs) with sparks flying out;
## - flora: a green flash with petals and leaves flying out.
## Images via ui/art.gd (a missing per-kind file falls back to the rookie one). There is no camera
## hook in the match, so the heavy blast does not shake the screen. Visuals only: the crater and
## the radius come from the server. Set radius and kind before adding it; it frees itself after
## LIFE seconds.

const Art := preload("res://ui/art.gd")

const LIFE := 1.1
const GRAVITY := 900.0
const BURST_SEC := 0.5 # the frames play over this time
const DIRT := [Color(0.42, 0.28, 0.16), Color(0.3, 0.2, 0.12), Color(0.36, 0.6, 0.25)]

## kind -> look: scale (of the burst frames), smoke (puff count, colour), bits (count, speed
## range, size, gravity factor, colours; "trail" uses the kind's trail particle as the bit image).
const STYLES := {
	"rookie": {"scale": 1.0, "smoke": 7, "smoke_color": Color(0.55, 0.52, 0.55, 0.85), "bits": 12,
		"speed": [180.0, 420.0], "bit_size": [2.0, 4.0], "gravity": 1.0, "colors": DIRT, "bit_image": "debris"},
	"tanko": {"scale": 1.2, "smoke": 11, "smoke_color": Color(0.38, 0.36, 0.38, 0.9), "bits": 24,
		"speed": [220.0, 520.0], "bit_size": [2.5, 5.0], "gravity": 1.0, "colors": DIRT, "bit_image": "debris"},
	"spark": {"scale": 1.0, "smoke": 2, "smoke_color": Color(0.55, 0.8, 0.95, 0.5), "bits": 16,
		"speed": [200.0, 480.0], "bit_size": [3.0, 5.0], "gravity": 0.25,
		"colors": [Color(1.0, 1.0, 0.7), Color(0.6, 0.95, 1.0)], "bit_image": "trail"},
	"flora": {"scale": 1.0, "smoke": 3, "smoke_color": Color(0.6, 0.85, 0.55, 0.55), "bits": 16,
		"speed": [140.0, 360.0], "bit_size": [4.0, 6.0], "gravity": 0.35,
		"colors": [Color(1, 1, 1), Color(0.65, 1.0, 0.6), Color(1.0, 0.9, 0.6)], "bit_image": "trail"},
}

var radius := 30.0
var kind := "rookie"

var _style: Dictionary
var _t := 0.0
var _smoke: Array = [] # [offset, size, drift, spin]
var _debris: Array = [] # [velocity, size, color, spin]
var _frames: Array[Texture2D] = []
var _smoke_tex: Texture2D
var _debris_tex: Texture2D


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not STYLES.has(kind):
		kind = "rookie"
	_style = STYLES[kind]
	for i in Art.EXPLOSION_FRAMES:
		_frames.append(Art.shot(kind, "impact_%d" % i, Art.explosion(i)))
	_smoke_tex = Art.fx("smoke")
	_debris_tex = Art.fx("debris") if _style["bit_image"] == "debris" else Art.shot(kind, "trail", Art.fx("debris"))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in int(_style["smoke"]):
		var off := Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.6, 0.1)) * radius
		_smoke.append([off, rng.randf_range(0.4, 0.7), Vector2(rng.randf_range(-20, 20), rng.randf_range(-70, -35)), rng.randf_range(-1.0, 1.0)])
	var colors: Array = _style["colors"]
	var speed: Array = _style["speed"]
	var bit: Array = _style["bit_size"]
	for i in int(_style["bits"]):
		var a := rng.randf_range(-PI * 0.95, -PI * 0.05) # mostly upward
		_debris.append([Vector2.from_angle(a) * rng.randf_range(speed[0], speed[1]), rng.randf_range(bit[0], bit[1]), colors[i % colors.size()], rng.randf_range(-12.0, 12.0)])


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
		var sc: Color = _style["smoke_color"]
		for p in _smoke:
			var at: Vector2 = p[0] + p[2] * (t - 0.08)
			var r: float = radius * p[1] * (0.8 + s * 0.9) * 1.25
			draw_set_transform(at, p[3] * s, Vector2.ONE)
			draw_texture_rect(_smoke_tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(sc, sc.a * (1.0 - s)))
		draw_set_transform(Vector2.ZERO)
	# The burst frames.
	if t < BURST_SEC and not _frames.is_empty():
		var i := mini(int(t / BURST_SEC * _frames.size()), _frames.size() - 1)
		var tex := _frames[i]
		var k := radius / Art.EXPLOSION_RADIUS * float(_style["scale"])
		var sz := tex.get_size() * k
		draw_texture_rect(tex, Rect2(-sz / 2, sz), false)
	# Debris / sparks / petals.
	var g := GRAVITY * float(_style["gravity"])
	for d in _debris:
		var v: Vector2 = d[0]
		var at := v * t + Vector2(0, 0.5 * g * t * t)
		var a := clampf(1.0 - t / LIFE, 0.0, 1.0)
		var r: float = d[1] * 1.4
		draw_set_transform(at, d[3] * t, Vector2.ONE)
		draw_texture_rect(_debris_tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(d[2], a))
		draw_set_transform(Vector2.ZERO)
