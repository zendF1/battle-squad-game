extends RefCounted
## Code-drawn effects (bake source only): the bomb (assets/fx/common/, an air strike's drop and
## the fallback projectile), the explosion frames, a smoke puff, a debris chunk, a muzzle/fuse
## flash, the character ground shadow, each gun kind's own shot (the bazooka's rocket with its
## exhaust puff and fire explosion, the cannon's iron ball, the shock rifle's plasma orb, the seed
## launcher's pod, the blaster's energy bolt: projectile, trail particle, impact frames) and the
## shared tier overlays (glow, sparkle, ember, coin, shard, shockwave ring, lens flare, ground
## cracks). tools/bake_art.gd saves them under assets/fx/<kind>/, assets/fx/common/ and
## assets/fx/tiers/ (the shadow under assets/characters/). The blaster's shot and the overlays
## are drawn white-ish: the game tints them with the gun tier's colours
## (match/views/shot_look.gd); the coin and the cracks keep their own colours.

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
## Per-gun shots (ui/art.gd SHOT_KINDS; the bazooka's impact is the explosion above): the
## projectile (flying towards +x, 2 px per world px), a trail particle and the impact frames.
const SHOT_PROJECTILE_SIZE := Vector2i(64, 64)
## The bazooka's rocket canvas (44 x 20 world px) and its layout, px from the canvas centre
## along the flight (+x): the exhaust flame ends near -40, the nozzle runs from ROCKET_NOZZLE_TO
## to ROCKET_NOZZLE_FROM, the olive body to ROCKET_COLLAR_FROM, then the collar, the warhead and
## its nose from ROCKET_NOSE_FROM to the tip.
const ROCKET_SIZE := Vector2i(88, 40)
const ROCKET_TIP := 40.0
const ROCKET_NOSE_FROM := 27.0
const ROCKET_COLLAR_FROM := 13.0
const ROCKET_NOZZLE_FROM := -17.0
const ROCKET_NOZZLE_TO := -23.0
## [base, light, dark] of the hug bazooka (assets/weapons/bazooka/hug_iron.png).
const ROCKET_OLIVE := [Color8(0x76, 0x88, 0x52), Color8(0xa1, 0xb4, 0x74), Color8(0x4b, 0x56, 0x38)]
const ROCKET_RED := [Color8(0xb9, 0x2c, 0x28), Color8(0xe2, 0x59, 0x52), Color8(0x82, 0x1c, 0x19)]
const ROCKET_STEEL := [Color8(0x4a, 0x4e, 0x55), Color8(0x7c, 0x82, 0x8c), Color8(0x2c, 0x2f, 0x35)]
const SHOT_TRAIL_SIZE := Vector2i(32, 32)
## The tier overlays (ui/art.gd TIER_FX) and their canvas sizes.
const TIER_FX_SIZES := {
	"glow": Vector2i(64, 64), "sparkle": Vector2i(32, 32), "ember": Vector2i(32, 32), "coin": Vector2i(32, 32),
	"shard": Vector2i(32, 32), "ring": Vector2i(256, 256), "flare": Vector2i(256, 256), "crack": Vector2i(256, 256),
}


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


# ── Per-gun shots ───────────────────────────────────────────────────────────

## The canvas of a gun kind's projectile: the bazooka's rocket is long and flat, the rest square.
static func shot_projectile_size(kind: String) -> Vector2i:
	return ROCKET_SIZE if kind == "bazooka" else SHOT_PROJECTILE_SIZE


## The projectile of a gun kind ("bazooka", "cannon", "shock_rifle", "seed_launcher", "blaster"),
## centred, flying towards +x, on a shot_projectile_size(kind) canvas.
static func shot_projectile(ci: CanvasItem, size: Vector2, kind: String) -> void:
	var c := size / 2
	var glow := preload("res://tools/art/env_painter.gd").glow_texture()
	match kind:
		"bazooka":
			rocket(ci, size)
		"cannon": # a heavy iron cannonball (world radius 10)
			var r := 20.0
			ci.draw_circle(c, r + 2.5, OUTLINE, true, -1.0, true)
			ci.draw_circle(c, r, Color(0.2, 0.21, 0.24), true, -1.0, true)
			ci.draw_circle(c + Vector2(2, 3), r * 0.75, Color(0.13, 0.13, 0.16), true, -1.0, true)
			ci.draw_arc(c, r * 0.82, -0.9, 0.9, 16, Color(0.36, 0.37, 0.42), 3.0, true)
			for a in [-0.6, 0.0, 0.6]:
				ci.draw_circle(c + Vector2.from_angle(a) * r * 0.82, 2.0, Color(0.5, 0.5, 0.55), true, -1.0, true)
			ci.draw_circle(c + Vector2(-6, -7), r * 0.32, Color(1, 1, 1, 0.4), true, -1.0, true)
			ci.draw_circle(c + Vector2(-7.5, -8.5), r * 0.12, Color(1, 1, 1, 0.75), true, -1.0, true)
		"shock_rifle": # a plasma orb: cyan glow, bright core, crackling arcs
			ci.draw_texture_rect(glow, Rect2(Vector2.ZERO, size), false, Color(0.35, 0.9, 1.0, 0.85))
			ci.draw_circle(c, 13.0, Color(0.5, 0.95, 1.0), true, -1.0, true)
			ci.draw_circle(c, 8.0, Color(1.0, 0.98, 0.6), true, -1.0, true)
			ci.draw_circle(c, 4.0, Color(1, 1, 1), true, -1.0, true)
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			for j in 5:
				var a := TAU * j / 5.0 + rng.randf_range(-0.3, 0.3)
				var pts := PackedVector2Array([c + Vector2.from_angle(a) * 9.0])
				for k in 3:
					pts.append(c + Vector2.from_angle(a + rng.randf_range(-0.5, 0.5)) * (14.0 + k * 6.0))
				ci.draw_polyline(pts, Color(1.0, 1.0, 0.75, 0.95), 2.0, true)
		"seed_launcher": # a green seed pod with a cap and a leaf, like an acorn
			var leaf := PackedVector2Array([c + Vector2(-10, -8), c + Vector2(-22, -18), c + Vector2(-26, -6), c + Vector2(-14, -2)])
			ci.draw_colored_polygon(leaf, Color(0.3, 0.7, 0.3))
			var pod := PackedVector2Array()
			for n in 32:
				var a := TAU * n / 32.0
				pod.append(c + Vector2(cos(a) * 15.0, sin(a) * 11.0))
			var ring := pod.duplicate()
			ring.append(pod[0])
			ci.draw_colored_polygon(pod, Color(0.42, 0.78, 0.3))
			ci.draw_polyline(ring, OUTLINE, 3.0, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(4, -11), c + Vector2(13, -7), c + Vector2(17, 0), c + Vector2(13, 7), c + Vector2(4, 11)]), Color(0.55, 0.36, 0.2))
			ci.draw_line(c + Vector2(-12, 0), c + Vector2(2, 0), Color(0.25, 0.55, 0.22), 2.0, true)
			ci.draw_circle(c + Vector2(-5, -5), 3.5, Color(1, 1, 1, 0.55), true, -1.0, true)
		"blaster": # an energy bolt: a long soft streak, a capsule body and a white-hot head (white: tinted in game)
			for layer in [[17.0, 12.0, 0.2], [19.0, 8.5, 0.35]]:
				_capsule(ci, c + Vector2(-1, 0), layer[0], layer[1], Color(0.92, 0.92, 0.95, layer[2]))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-30, 0), c + Vector2(4, -5), c + Vector2(4, 5)]), Color(0.85, 0.85, 0.9, 0.4))
			_capsule(ci, c + Vector2(2, 0), 18.0, 5.5, Color(0.97, 0.97, 1.0))
			ci.draw_circle(c + Vector2(15, 0), 6.0, Color(1, 1, 1), true, -1.0, true)
			ci.draw_texture_rect(glow, Rect2(c + Vector2(15, 0) - Vector2(14, 14), Vector2(28, 28)), false, Color(1, 1, 1, 0.8))


## The bazooka's rocket, flying towards +x, its middle at the canvas centre, in the hug bazooka's
## colours (assets/weapons/bazooka/hug_iron.png): a red pointed warhead with two white stripes,
## a dark collar, a short olive body, three tail fins (top, bottom and the one facing us), a
## dark nozzle and a short exhaust flame behind it; thick dark outline, cel shading (light top
## band, dark bottom band). 2 px per world px.
static func rocket(ci: CanvasItem, size: Vector2) -> void:
	var c := size / 2
	var glow := preload("res://tools/art/env_painter.gd").glow_texture()
	var ow := 5.0 # outline width (both sides of the edge: about 2.5 px outside)
	# Profiles (half height at x, px from the middle): body, collar, warhead, nozzle.
	var body := func(_x: float) -> float: return 7.5
	var collar := func(_x: float) -> float: return 9.0
	var head := func(x: float) -> float:
		var t := clampf((x - ROCKET_NOSE_FROM) / (ROCKET_TIP - ROCKET_NOSE_FROM), 0.0, 1.0)
		return 9.5 * (1.0 - pow(t, 1.7)) + 0.8 * t
	var nozzle := func(x: float) -> float: return lerpf(5.5, 7.0, (ROCKET_NOZZLE_FROM - x) / (ROCKET_NOZZLE_FROM - ROCKET_NOZZLE_TO))
	var parts := [ # [from x, to x, profile, base, light, dark]
		[ROCKET_NOZZLE_TO, ROCKET_NOZZLE_FROM + 1.0, nozzle, ROCKET_STEEL[0], ROCKET_STEEL[1], ROCKET_STEEL[2]],
		[ROCKET_NOZZLE_FROM, ROCKET_COLLAR_FROM + 1.0, body, ROCKET_OLIVE[0], ROCKET_OLIVE[1], ROCKET_OLIVE[2]],
		[ROCKET_COLLAR_FROM + 3.5, ROCKET_TIP, head, ROCKET_RED[0], ROCKET_RED[1], ROCKET_RED[2]],
		[ROCKET_COLLAR_FROM, ROCKET_COLLAR_FROM + 3.5, collar, ROCKET_STEEL[0], ROCKET_STEEL[1], ROCKET_STEEL[2]],
	]
	var fin_top := PackedVector2Array([Vector2(-5, -7), Vector2(-13, -15), Vector2(-18.5, -15.5), Vector2(-16.5, -7)])
	var fin_bottom := PackedVector2Array()
	for p in fin_top:
		fin_bottom.append(Vector2(p.x, -p.y))
	var fin_mid := PackedVector2Array([Vector2(-7, -1.0), Vector2(-17.5, -2.2), Vector2(-17.5, 2.2), Vector2(-7, 1.0)])
	# The exhaust flame (behind everything, no outline): a soft glow, then orange, yellow, white.
	var nz := c + Vector2(ROCKET_NOZZLE_TO, 0)
	ci.draw_texture_rect(glow, Rect2(nz + Vector2(-17, -10), Vector2(24, 20)), false, Color(1.0, 0.6, 0.15, 0.75))
	for layer in [[16.0, 6.0, Color(1.0, 0.5, 0.12)], [11.5, 4.3, Color(1.0, 0.82, 0.25)], [6.5, 2.6, Color(1.0, 0.98, 0.8)]]:
		ci.draw_colored_polygon(_flame(nz + Vector2(1, 0), layer[0], layer[1]), layer[2])
	# One outline behind all the parts, so the joints show no inner gaps.
	for fin in [fin_top, fin_bottom]:
		_outline(ci, _at(c, fin), OUTLINE, ow)
	for p in parts:
		_outline(ci, _hull(c, p[0], p[1], p[2], -1.0, 1.0), OUTLINE, ow)
	for fin in [fin_top, fin_bottom]: # the side fins, darker olive with a light leading edge
		var f := _at(c, fin)
		ci.draw_colored_polygon(f, ROCKET_OLIVE[2])
		ci.draw_line(f[0].lerp(f[1], 0.15), f[1].lerp(f[2], 0.3), ROCKET_OLIVE[0], 2.0, true)
	for p in parts:
		ci.draw_colored_polygon(_hull(c, p[0], p[1], p[2], -1.0, 1.0), p[3])
		ci.draw_colored_polygon(_hull(c, p[0], p[1], p[2], -0.92, -0.38), p[4]) # light top band
		ci.draw_colored_polygon(_hull(c, p[0], p[1], p[2], 0.45, 1.0), p[5]) # dark bottom band
	# Two white stripes round the warhead, shaded like it.
	for x0 in [ROCKET_COLLAR_FROM + 5.5, ROCKET_COLLAR_FROM + 9.0]:
		ci.draw_colored_polygon(_hull(c, x0, x0 + 2.0, head, -1.0, 1.0), Color(1, 1, 1))
		ci.draw_colored_polygon(_hull(c, x0, x0 + 2.0, head, 0.45, 1.0), Color(0.82, 0.8, 0.86))
	ci.draw_circle(c + Vector2(ROCKET_TIP - 9.0, -4.2), 1.6, Color(1, 1, 1, 0.75), true, -1.0, true) # a glint
	# The fin facing us, over the body.
	var fm := _at(c, fin_mid)
	ci.draw_colored_polygon(fm, ROCKET_OLIVE[2])
	_outline(ci, fm, OUTLINE, 1.4)
	ci.draw_line(fm[0] + Vector2(-1, 0.3), fm[1] + Vector2(1, 0.6), ROCKET_OLIVE[1], 1.0, true)
	# Thin dark seams between the parts.
	for x in [ROCKET_NOZZLE_FROM, ROCKET_COLLAR_FROM, ROCKET_COLLAR_FROM + 3.5]:
		var r := 9.0 if x != ROCKET_NOZZLE_FROM else 7.5
		ci.draw_line(c + Vector2(x, -r), c + Vector2(x, r), OUTLINE, 1.5, true)


## A closed outline of a polygon.
static func _outline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var ring := pts.duplicate()
	ring.append(pts[0])
	ci.draw_polyline(ring, color, width, true)


## A polygon's points moved to c.
static func _at(c: Vector2, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p)
	return out


## The band v0..v1 (-1 top edge, 1 bottom edge) of a horizontal hull from x0 to x1 (px from c)
## whose half height at x is profile(x).
static func _hull(c: Vector2, x0: float, x1: float, profile: Callable, v0: float, v1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 12
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		pts.append(c + Vector2(x, v0 * float(profile.call(x))))
	for i in n + 1:
		var x := lerpf(x1, x0, float(i) / n)
		pts.append(c + Vector2(x, v1 * float(profile.call(x))))
	return pts


## A flame tongue from `base` back towards -x: `length` long, `r` half wide at the base.
static func _flame(base: Vector2, length: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := -PI / 2 + PI * i / 16.0 # top edge, the back point, bottom edge
		var k := maxf(0.0, cos(a))
		pts.append(base + Vector2(-length * pow(k, 0.6), sin(a) * r * (1.0 - 0.7 * k * k * k)))
	return pts


## A horizontal capsule centred at c: half length hl (to the cap centres), radius r.
static func _capsule(ci: CanvasItem, c: Vector2, hl: float, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17: # the front cap, then the back cap
		pts.append(c + Vector2(hl, 0) + Vector2.from_angle(-PI / 2 + PI * i / 16.0) * r)
	for i in 17:
		pts.append(c + Vector2(-hl, 0) + Vector2.from_angle(PI / 2 + PI * i / 16.0) * r)
	ci.draw_colored_polygon(pts, color)


## A trail particle: the bazooka a lumpy exhaust puff drawn white-grey (the game colours it from
## fire to smoke over its life), the cannon a grey smoke puff, the shock rifle a cyan spark, the
## seed launcher a petal, the blaster a white energy spark (tinted in game).
static func shot_trail(ci: CanvasItem, size: Vector2, kind: String) -> void:
	var c := size / 2
	var glow := preload("res://tools/art/env_painter.gd").glow_texture()
	match kind:
		"bazooka":
			for b in [[Vector2(0, 2), 13.0, 0.8], [Vector2(-5, -3), 9.5, 0.75], [Vector2(5, -2), 9.0, 0.7], [Vector2(1, -6), 8.0, 0.65]]:
				var r: float = b[1] * 1.2
				ci.draw_texture_rect(glow, Rect2(c + b[0] - Vector2(r, r), Vector2(r, r) * 2), false, Color(0.86, 0.86, 0.88, b[2]))
			ci.draw_texture_rect(glow, Rect2(c + Vector2(-8, -10), Vector2(13, 13)), false, Color(1, 1, 1, 0.7))
		"cannon":
			ci.draw_texture_rect(glow, Rect2(Vector2.ZERO, size), false, Color(0.75, 0.75, 0.78, 0.9))
			ci.draw_texture_rect(glow, Rect2(c - Vector2(9, 11), Vector2(16, 16)), false, Color(0.95, 0.95, 0.97, 0.6))
		"shock_rifle":
			ci.draw_texture_rect(glow, Rect2(Vector2.ZERO, size), false, Color(0.4, 0.9, 1.0, 0.8))
			ci.draw_colored_polygon(PackedVector2Array(_star4(c, 14.0, 3.0)), Color(0.85, 1.0, 1.0))
			ci.draw_circle(c, 3.0, Color(1, 1, 0.8), true, -1.0, true)
		"blaster":
			ci.draw_texture_rect(glow, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.7))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 0), c + Vector2(0, -3.5), c + Vector2(14, 0), c + Vector2(0, 3.5)]), Color(1, 1, 1))
			ci.draw_circle(c, 3.0, Color(1, 1, 1), true, -1.0, true)
		"seed_launcher":
			var petal := PackedVector2Array()
			for n in 24:
				var a := TAU * n / 24.0
				petal.append(c + Vector2(cos(a) * 11.0, sin(a) * 6.0).rotated(0.5))
			ci.draw_colored_polygon(petal, Color(1.0, 0.62, 0.78))
			ci.draw_line(c + Vector2(-7, -4), c + Vector2(7, 4), Color(1.0, 0.85, 0.9), 2.0, true)


static func _star4(c: Vector2, outer: float, inner: float) -> Array:
	var out := []
	for i in 8:
		out.append(c + Vector2.from_angle(PI * i / 4.0 - PI / 2) * (outer if i % 2 == 0 else inner))
	return out


## Impact frame i (EXPLOSION_TIMES) of a gun kind, drawn for a radius-60 crater like explosion():
## the cannon a heavy dark-orange blast with soot, the shock rifle an electric burst (cyan flash,
## lightning arcs, sparks), the seed launcher a green flash with petals and leaves flying out, the
## blaster an energy burst (white: tinted in game; a flash, a hard ring, radial streaks, motes).
static func shot_impact(ci: CanvasItem, size: Vector2, kind: String, i: int) -> void:
	var c := size / 2
	var radius := EXPLOSION_RADIUS
	var t: float = EXPLOSION_TIMES[i]
	var k := t / EXPLOSION_SEC
	var a := 1.0 - k * k
	var grow := 0.75 + 0.55 * ease(k, 0.25)
	var rng := RandomNumberGenerator.new()
	match kind:
		"cannon":
			rng.seed = 31
			if t < 0.32:
				var q := t / 0.32
				ci.draw_arc(c, radius * (0.6 + q * 1.3), 0.0, TAU, 96, Color(1, 0.9, 0.7, 0.85 * (1.0 - q)), 9.0 * (1.0 - q) + 2.0, true)
			ci.draw_circle(c, radius * 1.3 * grow, Color(0.9, 0.35, 0.1, 0.4 * a), true, -1.0, true)
			for j in 9:
				var off := Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.2, 0.65)
				ci.draw_circle(c + off * grow * 1.4, radius * rng.randf_range(0.35, 0.6) * 1.3 * grow, Color(0.95, 0.33, 0.08, 0.9 * a), true, -1.0, true)
			rng.seed = 32
			for j in 8: # heavy soot
				var off := Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.3, 0.8)
				ci.draw_circle(c + off * grow * 1.5, radius * rng.randf_range(0.25, 0.4) * grow, Color(0.2, 0.15, 0.13, 0.75 * k * a + 0.1 * a), true, -1.0, true)
			ci.draw_circle(c, radius * 0.9 * grow, Color(1.0, 0.6, 0.18, 0.9 * a), true, -1.0, true)
			ci.draw_circle(c, radius * 0.5 * grow, Color(1.0, 0.88, 0.45, 0.95 * a), true, -1.0, true)
			if t < 0.14:
				ci.draw_circle(c, radius * 0.75, Color(1, 0.97, 0.88, 1.0 - t / 0.14), true, -1.0, true)
		"shock_rifle":
			var glow := preload("res://tools/art/env_painter.gd").glow_texture()
			var gr := radius * 2.0 * grow
			ci.draw_texture_rect(glow, Rect2(c - Vector2(gr, gr), Vector2(gr, gr) * 2), false, Color(0.35, 0.9, 1.0, 0.8 * a))
			if t < 0.32:
				var q := t / 0.32
				ci.draw_arc(c, radius * (0.5 + q * 1.2), 0.0, TAU, 96, Color(0.7, 1.0, 1.0, 0.9 * (1.0 - q)), 5.0 * (1.0 - q) + 1.5, true)
			rng.seed = 41 + i # the bolts flicker from frame to frame
			for j in 7:
				var ang := TAU * j / 7.0 + rng.randf_range(-0.3, 0.3)
				var reach := radius * rng.randf_range(0.9, 1.6) * grow
				var pts := PackedVector2Array([c])
				for n in 5:
					var d := reach * (n + 1) / 5.0
					pts.append(c + Vector2.from_angle(ang + rng.randf_range(-0.35, 0.35)) * d)
				ci.draw_polyline(pts, Color(0.55, 0.95, 1.0, 0.9 * a), 7.0, true)
				ci.draw_polyline(pts, Color(1.0, 1.0, 0.85, a), 2.5, true)
			for j in 14:
				var p := c + Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.4, 1.7) * grow
				ci.draw_circle(p, rng.randf_range(2.0, 4.0), Color(1.0, 1.0, 0.7, a), true, -1.0, true)
			ci.draw_circle(c, radius * 0.45 * grow, Color(0.75, 1.0, 1.0, 0.9 * a), true, -1.0, true)
			if t < 0.14:
				ci.draw_circle(c, radius * 0.7, Color(0.9, 1, 1, 1.0 - t / 0.14), true, -1.0, true)
		"blaster":
			var glow := preload("res://tools/art/env_painter.gd").glow_texture()
			var gr := radius * 1.9 * grow
			ci.draw_texture_rect(glow, Rect2(c - Vector2(gr, gr), Vector2(gr, gr) * 2), false, Color(0.9, 0.9, 0.95, 0.7 * a))
			var q := ease(k, 0.35)
			ci.draw_arc(c, radius * (0.45 + q * 1.25), 0.0, TAU, 96, Color(1, 1, 1, 0.95 * (1.0 - k)), 8.0 * (1.0 - k) + 2.0, true)
			ci.draw_arc(c, radius * (0.3 + q * 0.9), 0.0, TAU, 96, Color(0.85, 0.85, 0.9, 0.6 * (1.0 - k)), 3.0, true)
			rng.seed = 61
			for j in 12: # radial streaks
				var ang := TAU * j / 12.0 + rng.randf_range(-0.12, 0.12)
				var r0 := radius * (0.25 + 0.8 * q)
				var r1 := r0 + radius * rng.randf_range(0.35, 0.7) * (1.0 - 0.5 * k)
				ci.draw_line(c + Vector2.from_angle(ang) * r0, c + Vector2.from_angle(ang) * r1, Color(1, 1, 1, 0.9 * a), 3.0 * (1.0 - k) + 1.0, true)
			for j in 16: # motes
				var p := c + Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.5, 1.6) * grow
				ci.draw_circle(p, rng.randf_range(2.0, 4.0), Color(1, 1, 1, a), true, -1.0, true)
			ci.draw_circle(c, radius * 0.5 * grow * (1.0 - 0.4 * k), Color(1, 1, 1, 0.85 * a), true, -1.0, true)
			if t < 0.14:
				ci.draw_circle(c, radius * 0.75, Color(1, 1, 1, 1.0 - t / 0.14), true, -1.0, true)
		"seed_launcher":
			var glow := preload("res://tools/art/env_painter.gd").glow_texture()
			var gr := radius * 1.8 * grow
			ci.draw_texture_rect(glow, Rect2(c - Vector2(gr, gr), Vector2(gr, gr) * 2), false, Color(0.5, 1.0, 0.45, 0.75 * a))
			if t < 0.32:
				var q := t / 0.32
				ci.draw_arc(c, radius * (0.5 + q * 1.1), 0.0, TAU, 96, Color(0.85, 1.0, 0.75, 0.85 * (1.0 - q)), 5.0 * (1.0 - q) + 1.5, true)
			rng.seed = 51 # the same petals in every frame, flying out
			for j in 16:
				var ang := rng.randf() * TAU
				var d := radius * rng.randf_range(0.3, 1.0) * (0.4 + 1.3 * ease(k, 0.4))
				var spin := rng.randf_range(-6.0, 6.0) * t
				var col := Color(1.0, 0.62, 0.78) if j % 3 == 0 else (Color(0.4, 0.8, 0.3) if j % 3 == 1 else Color(1.0, 0.9, 0.4))
				var at := c + Vector2.from_angle(ang) * d
				var petal := PackedVector2Array()
				for n in 16:
					var e := TAU * n / 16.0
					petal.append(at + Vector2(cos(e) * 14.0, sin(e) * 7.5).rotated(ang + spin))
				ci.draw_colored_polygon(petal, Color(col, a))
			ci.draw_circle(c, radius * 0.5 * grow, Color(0.8, 1.0, 0.6, 0.85 * a), true, -1.0, true)
			if t < 0.14:
				ci.draw_circle(c, radius * 0.65, Color(0.95, 1, 0.9, 1.0 - t / 0.14), true, -1.0, true)


# ── Tier overlays (assets/fx/tiers/) ────────────────────────────────────────

## A tier overlay (ui/art.gd TIER_FX) on a TIER_FX_SIZES canvas, centred.
static func tier_fx(ci: CanvasItem, size: Vector2, fx_name: String) -> void:
	var c := size / 2
	var glow := preload("res://tools/art/env_painter.gd").glow_texture()
	match fx_name:
		"glow": # a soft round glow, white
			ci.draw_texture_rect(glow, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.95))
			ci.draw_texture_rect(glow, Rect2(c - size / 4, size / 2), false, Color(1, 1, 1, 0.6))
		"sparkle": # a four-point star with a soft halo
			ci.draw_texture_rect(glow, Rect2(c - size * 0.4, size * 0.8), false, Color(1, 1, 1, 0.55))
			ci.draw_colored_polygon(PackedVector2Array(_star4(c, size.x * 0.48, size.x * 0.07)), Color(1, 1, 1))
			ci.draw_colored_polygon(PackedVector2Array(_star4(c, size.x * 0.24, size.x * 0.05)), Color(1, 1, 1))
			ci.draw_circle(c, 2.5, Color(1, 1, 1), true, -1.0, true)
		"ember": # a hot ember: a bright core in a soft, slightly stretched glow
			ci.draw_set_transform(c, 0.0, Vector2(1.0, 0.75))
			ci.draw_texture_rect(glow, Rect2(-size / 2, size), false, Color(1, 1, 1, 0.8))
			ci.draw_set_transform(Vector2.ZERO)
			ci.draw_circle(c, 5.0, Color(1, 1, 1), true, -1.0, true)
			ci.draw_circle(c + Vector2(-3, 1), 3.0, Color(1, 1, 1, 0.8), true, -1.0, true)
		"coin": # a gold coin seen a little from the side, with a rim and a shine
			var pts := _ellipse(c, Vector2(10, 14), 32)
			ci.draw_colored_polygon(_ellipse(c + Vector2(2, 0), Vector2(10, 14), 32), Color(0.62, 0.38, 0.05))
			ci.draw_colored_polygon(pts, Color(1.0, 0.78, 0.2))
			ci.draw_colored_polygon(_ellipse(c, Vector2(6.5, 10), 32), Color(1.0, 0.88, 0.4))
			var ring := pts.duplicate()
			ring.append(pts[0])
			ci.draw_polyline(ring, Color(0.45, 0.25, 0.02), 1.5, true)
			ci.draw_rect(Rect2(c + Vector2(-1.5, -5), Vector2(3, 10)), Color(0.85, 0.55, 0.1))
			ci.draw_circle(c + Vector2(-4, -6), 2.2, Color(1, 1, 0.9), true, -1.0, true)
		"shard": # a crystal shard: a long diamond with light and dark facets
			var tip := c + Vector2(13, -3)
			var tail := c + Vector2(-13, 3)
			var top := c + Vector2(-1, -7)
			var bot := c + Vector2(2, 6)
			ci.draw_colored_polygon(PackedVector2Array([tail, top, tip]), Color(1, 1, 1))
			ci.draw_colored_polygon(PackedVector2Array([tail, tip, bot]), Color(0.78, 0.84, 0.92))
			ci.draw_line(tail, tip, Color(1, 1, 1, 0.9), 1.0, true)
			ci.draw_polyline(PackedVector2Array([tail, top, tip, bot, tail]), Color(0.6, 0.68, 0.8), 1.2, true)
		"ring": # a shockwave ring: a bright band with soft edges at 0.86 of the half size
			var r := size.x * 0.43
			for j in 7:
				var d := (j - 3) * 3.0
				ci.draw_arc(c, r + d, 0.0, TAU, 128, Color(1, 1, 1, 0.9 * (1.0 - absf(j - 3) / 3.5)), 3.4, true)
			ci.draw_arc(c, r - 12.0, 0.0, TAU, 128, Color(1, 1, 1, 0.12), 10.0, true)
		"flare": # a lens-flare burst: a long horizontal streak, a shorter vertical one, a star, ghost rings
			ci.draw_texture_rect(glow, Rect2(c - Vector2(44, 44), Vector2(88, 88)), false, Color(1, 1, 1, 0.9))
			for j in 3:
				var h := 7.0 - j * 2.0
				ci.draw_set_transform(c, 0.0, Vector2(1.0, h / size.x))
				ci.draw_texture_rect(glow, Rect2(-size / 2, size), false, Color(1, 1, 1, 0.6))
			ci.draw_set_transform(c, 0.0, Vector2(4.0 / size.x * 1.5, 0.55))
			ci.draw_texture_rect(glow, Rect2(-size / 2, size), false, Color(1, 1, 1, 0.5))
			ci.draw_set_transform(Vector2.ZERO)
			ci.draw_colored_polygon(PackedVector2Array(_star4(c, 40.0, 4.0)), Color(1, 1, 1, 0.9))
			ci.draw_arc(c, 62.0, 0.0, TAU, 96, Color(1, 1, 1, 0.18), 3.0, true)
			ci.draw_arc(c + Vector2(70, 0), 14.0, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 2.0, true)
			ci.draw_circle(c, 9.0, Color(1, 1, 1), true, -1.0, true)
		"crack": # ground cracks radiating out of a crater (transparent middle), dark with a light edge
			var rng := RandomNumberGenerator.new()
			rng.seed = 71
			for j in 11:
				var ang := TAU * j / 11.0 + rng.randf_range(-0.2, 0.2)
				var p := c + Vector2.from_angle(ang) * size.x * 0.22
				var pts := PackedVector2Array([p])
				var reach := size.x * rng.randf_range(0.4, 0.49)
				for n in 5:
					ang += rng.randf_range(-0.35, 0.35)
					p = c + Vector2.from_angle(ang) * lerpf(size.x * 0.22, reach, (n + 1) / 5.0)
					pts.append(p)
				ci.draw_polyline(pts, Color(0.95, 0.85, 0.65, 0.35), 5.0, true)
				ci.draw_polyline(pts, Color(0.12, 0.08, 0.06, 0.95), 3.0, true)
				if j % 2 == 0: # a branch
					var b := PackedVector2Array([pts[2], pts[2] + Vector2.from_angle(ang + 0.7) * size.x * 0.1])
					ci.draw_polyline(b, Color(0.12, 0.08, 0.06, 0.85), 2.0, true)


static func _ellipse(c: Vector2, r: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out
