extends RefCounted
## Code-drawn effects (bake source only): the bomb, the explosion frames, a smoke puff, a debris
## chunk, a muzzle/fuse flash and the character ground shadow. tools/bake_art.gd saves them
## under assets/fx/ (the shadow under assets/characters/).

const OUTLINE := Color(0.02, 0.02, 0.05)
const BOMB_SIZE := Vector2i(48, 48)
## Bomb px per world px: the ball (world radius 7) is drawn at radius 14, centred.
const BOMB_SCALE := 2.0
const EXPLOSION_SIZE := Vector2i(256, 256)
## The crater radius the explosion frames are drawn for (px in the frame): the fire reaches
## about 2.1x this, so the frames fit a radius-60 explosion.
const EXPLOSION_RADIUS := preload("res://ui/art.gd").EXPLOSION_RADIUS
## Explosion frame i shows the effect at time EXPLOSION_TIMES[i] (s) of the old code animation.
const EXPLOSION_TIMES := [0.02, 0.08, 0.15, 0.23, 0.32, 0.42]
const EXPLOSION_SEC := 0.5
const SMOKE_SIZE := Vector2i(128, 128)
const DEBRIS_SIZE := Vector2i(24, 24)
const MUZZLE_SIZE := Vector2i(64, 64)
## The ground shadow, in character art units (drawn at the character PX_PER_UNIT).
const SHADOW_UNITS := Vector2(100, 24)


## The bomb, flying towards +x: dark ball, rim, highlight and the fuse trailing behind (-x).
static func bomb(ci: CanvasItem, size: Vector2) -> void:
	var c := size / 2
	var s := BOMB_SCALE
	var r := 7.0 * s
	# Fuse: a short curved cord behind, with its cap.
	var fuse := PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.3), c + Vector2(-r - 3, -r * 0.55), c + Vector2(-r - 7, -r * 0.35)])
	ci.draw_polyline(fuse, OUTLINE, 6.0, true)
	ci.draw_polyline(fuse, Color(0.62, 0.47, 0.3), 3.0, true)
	ci.draw_circle(c, r + 2.5, OUTLINE, true, -1.0, true)
	ci.draw_circle(c, r, Color(0.17, 0.18, 0.24), true, -1.0, true)
	ci.draw_circle(c + Vector2(1.5, 2), r * 0.72, Color(0.12, 0.12, 0.17), true, -1.0, true)
	# Cap where the fuse goes in.
	var cap := c + Vector2(-r * 0.72, -r * 0.42)
	ci.draw_set_transform(cap, -2.6, Vector2.ONE)
	ci.draw_rect(Rect2(-3.5, -4, 7, 8), Color(0.42, 0.44, 0.5))
	ci.draw_rect(Rect2(-3.5, -4, 7, 8), OUTLINE, false, 1.5)
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_circle(c + Vector2(-4.4, -4.8), r * 0.36, Color(1, 1, 1, 0.55), true, -1.0, true)
	ci.draw_circle(c + Vector2(-5.5, -6), r * 0.14, Color(1, 1, 1, 0.8), true, -1.0, true)


## Explosion frame i (EXPLOSION_TIMES): shock ring, layered fireballs and the white flash.
static func explosion(ci: CanvasItem, size: Vector2, i: int) -> void:
	var c := size / 2
	var radius := EXPLOSION_RADIUS
	var t: float = EXPLOSION_TIMES[i]
	var rng := RandomNumberGenerator.new()
	rng.seed = 23 # the same fireballs in every frame, so they grow coherently
	var fire: Array = []
	for j in 7:
		fire.append([Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.2, 0.6), rng.randf_range(0.35, 0.6)])
	if t < 0.32:
		var k := t / 0.32
		ci.draw_arc(c, radius * (0.6 + k * 1.1), 0.0, TAU, 96, Color(1, 0.97, 0.85, 0.8 * (1.0 - k)), 6.0 * (1.0 - k) + 1.5, true)
	var k := t / EXPLOSION_SEC
	var grow := 0.75 + 0.55 * ease(k, 0.25)
	var a := 1.0 - k * k
	ci.draw_circle(c, radius * 1.25 * grow, Color(1.0, 0.5, 0.15, 0.35 * a), true, -1.0, true)
	for p in fire:
		ci.draw_circle(c + p[0] * grow * 1.4, radius * p[1] * 1.3 * grow, Color(1.0, 0.42, 0.1, 0.9 * a), true, -1.0, true)
	for p in fire: # darker sooty cores late in the burst
		if k > 0.45:
			ci.draw_circle(c + p[0] * grow * 1.55, radius * p[1] * 0.5 * grow, Color(0.45, 0.2, 0.1, 0.5 * (k - 0.45)), true, -1.0, true)
	ci.draw_circle(c, radius * 0.95 * grow, Color(1.0, 0.68, 0.2, 0.9 * a), true, -1.0, true)
	ci.draw_circle(c, radius * 0.6 * grow, Color(1.0, 0.92, 0.5, 0.95 * a), true, -1.0, true)
	if t < 0.14:
		ci.draw_circle(c, radius * 0.7, Color(1, 1, 0.92, 1.0 - t / 0.14), true, -1.0, true)


## A soft grey smoke puff (white-ish: the game tints and fades it).
static func smoke(ci: CanvasItem, size: Vector2) -> void:
	var c := size / 2
	var glow := preload("res://tools/art/env_painter.gd").glow_texture()
	var blobs := [[Vector2(0, 6), 46.0, 0.75], [Vector2(-18, -8), 32.0, 0.7], [Vector2(20, -4), 30.0, 0.65], [Vector2(2, -20), 28.0, 0.6]]
	for b in blobs:
		var r: float = b[1] * 1.3
		ci.draw_texture_rect(glow, Rect2(c + b[0] - Vector2(r, r), Vector2(r, r) * 2), false, Color(0.62, 0.6, 0.63, b[2]))
	ci.draw_texture_rect(glow, Rect2(c + Vector2(-26, -34), Vector2(40, 40)), false, Color(0.92, 0.9, 0.92, 0.55))


## A dirt chunk, light grey (the game tints it with the dirt colours).
static func debris(ci: CanvasItem, size: Vector2) -> void:
	var c := size / 2
	var pts := PackedVector2Array([c + Vector2(-8, -3), c + Vector2(-3, -8), c + Vector2(5, -7), c + Vector2(9, -1), c + Vector2(6, 7), c + Vector2(-4, 8), c + Vector2(-9, 3)])
	ci.draw_colored_polygon(pts, Color(0.95, 0.95, 0.95))
	var close := pts.duplicate()
	close.append(pts[0])
	ci.draw_polyline(close, Color(0.45, 0.45, 0.45), 2.0, true)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -3), c + Vector2(-2, -6), c + Vector2(3, -5), c + Vector2(-1, -1)]), Color(1, 1, 1))


## A flash: a warm glow with an eight-point star (the fuse spark, muzzle flashes).
static func muzzle(ci: CanvasItem, size: Vector2) -> void:
	var c := size / 2
	var glow := preload("res://tools/art/env_painter.gd").glow_texture()
	ci.draw_texture_rect(glow, Rect2(Vector2.ZERO, size), false, Color(1.0, 0.62, 0.15, 0.75))
	var star := PackedVector2Array()
	for j in 16:
		var r := 28.0 if j % 2 == 0 else 9.0
		if j % 4 == 2:
			r = 18.0
		star.append(c + Vector2.from_angle(TAU * j / 16.0 - PI / 2) * r)
	ci.draw_colored_polygon(star, Color(1.0, 0.85, 0.35))
	ci.draw_circle(c, 9.0, Color(1.0, 0.97, 0.75), true, -1.0, true)
	ci.draw_circle(c, 5.0, Color(1, 1, 1), true, -1.0, true)


## The soft oval shadow under a character, px_per_unit px per art unit.
static func shadow(ci: CanvasItem, size: Vector2) -> void:
	var c := size / 2
	var r := size / 2 - Vector2(2, 2)
	for j in 4: # a slightly darker core
		var k := 1.0 - j * 0.12
		var pts := PackedVector2Array()
		for n in 64:
			pts.append(c + Vector2.from_angle(TAU * n / 64.0) * r * k)
		ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.12 if j > 0 else 0.16))
