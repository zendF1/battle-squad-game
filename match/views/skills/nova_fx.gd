extends Node2D
## Tide's Nổ bông tuyết on the fx layer (nova.gd), at the nova's centre (Tide's body centre),
## drawn in code, every part a function of the replay time (sync(t); it runs on by itself after
## the replay and frees itself at the end):
## - the cast (before the nova's t0, the server's castTime): snow motes spiralling in to her and a
##   cold glow gathering;
## - at t0 a big six-arm snowflake sigil flashes at her (popping in with an overshoot, turning
##   slowly, fading);
## - a frost ring expands to the radius at the wave's speed (radius / duration: each target is hit
##   as it reaches it), ice shards riding its front, a pale band of cold behind it;
## - snowflakes drift out and settle; the ground in the radius frosts over briefly (the terrain's
##   surface whitened), then thaws.

const ICE := Color(0.72, 0.9, 1.0)
const ICE_DEEP := Color(0.32, 0.62, 1.0)
const FROST := Color(0.94, 0.99, 1.0)
const INK := Color(0.1, 0.18, 0.42)
const SIGIL_SEC := 0.75 # the snowflake's flash
const SIGIL_R := 110.0 # its size (px)
const RING_FADE := 0.3 # s the ring fades after reaching the radius
const FROST_HOLD := 1.1 # s the ground stays frosted after the ring passed
const FROST_FADE := 0.6
const SNOW := 70
const SHARDS := 28
const MOTES := 26

## Set before adding it: the nova's t0 (replay s), radius (px), how long the ring takes to reach
## the radius (s), the cast's start (replay s, <= t0) and the terrain (TerrainMask, or null).
var t0 := 0.35
var radius := 500.0
var duration := 0.36
var cast_from := 0.0
var terrain = null

var _t := 0.0 # replay time now
var _synced := false
var _flakes: Array = [] # [angle, speed, size, spin, drift]
var _shards: Array = [] # [angle, size, spin, lag]
var _frost := PackedVector2Array() # the ground's surface across the radius (world px, local)


func _ready() -> void:
	z_index = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in SNOW:
		_flakes.append([rng.randf() * TAU, rng.randf_range(0.25, 1.0), rng.randf_range(2.0, 5.0), rng.randf_range(-3.0, 3.0), rng.randf_range(10.0, 40.0)])
	for i in SHARDS:
		_shards.append([TAU * i / SHARDS + rng.randf_range(-0.1, 0.1), rng.randf_range(7.0, 14.0), rng.randf_range(-6.0, 6.0), rng.randf_range(0.0, 0.12)])
	_sample_ground()


## The time the whole effect is over (replay s).
func end_time() -> float:
	return t0 + duration + maxf(RING_FADE, FROST_HOLD + FROST_FADE)


## The ring's radius at replay time t (0 before t0, the full radius once it reached it).
func ring_radius(t: float) -> float:
	if t < t0 or duration <= 0.0:
		return 0.0 if t < t0 else radius
	return minf(radius, radius * (t - t0) / duration)


## When the ring reaches a point `dist` px from the centre (replay s): t0 + dist / speed.
func reach_time(dist: float) -> float:
	return t0 + clampf(dist, 0.0, radius) / maxf(radius / maxf(duration, 1e-3), 1.0)


## The sigil's size share at t (0 before t0, popping in with an overshoot, 0 after SIGIL_SEC).
func sigil_k(t: float) -> float:
	var u := (t - t0) / SIGIL_SEC
	if u < 0.0 or u > 1.0:
		return 0.0
	var pop := clampf(u / 0.22, 0.0, 1.0)
	return (1.0 + 2.4 * pow(pop - 1.0, 3.0) + 1.4 * pow(pop - 1.0, 2.0)) * (1.0 - smoothstep(0.55, 1.0, u) * 0.25)


func sync(t: float) -> void:
	_t = t
	_synced = true
	queue_redraw()


func _process(delta: float) -> void:
	if not _synced:
		_t += delta # after the replay: on by itself
	_synced = false
	if _t > end_time():
		queue_free()
		return
	queue_redraw()


func _sample_ground() -> void:
	_frost = PackedVector2Array()
	if terrain == null or not terrain.has_method("get_landing_y"):
		return
	var n := 48
	for i in n + 1:
		var x := position.x + lerpf(-radius, radius, i / float(n))
		var y: float = terrain.get_landing_y(x, maxf(position.y - radius, 0.0))
		if absf(y - position.y) <= radius and terrain.height > 0 and y < terrain.height:
			_frost.append(Vector2(x, y) - position)
		else:
			_frost.append(Vector2(INF, INF))


func _draw() -> void:
	var t := _t
	var tau := t - t0
	if t < t0:
		_cast(t)
	var rr := ring_radius(t)
	if rr > 0.0:
		_ground_frost(t, rr)
		_ring(t, rr)
		_shards_at(t, rr)
		_snow(tau)
	var k := sigil_k(t)
	if k > 0.0:
		var a := 1.0 - smoothstep(0.45, 1.0, tau / SIGIL_SEC)
		_glow(Vector2.ZERO, SIGIL_R * 1.4 * k, Color(ICE, 0.35 * a))
		_snowflake(Vector2.ZERO, SIGIL_R * k, tau * 0.6, a)


## The cast: motes spiralling in, a cold glow gathering.
func _cast(t: float) -> void:
	var span := maxf(t0 - cast_from, 0.05)
	var u := clampf((t - cast_from) / span, 0.0, 1.0)
	_glow(Vector2.ZERO, 30.0 + 60.0 * u, Color(ICE, 0.25 + 0.35 * u))
	for i in MOTES:
		var ang := TAU * i / MOTES + u * 3.0
		var d := lerpf(140.0, 8.0, fposmod(u + i / float(MOTES), 1.0))
		draw_circle(Vector2.from_angle(ang) * d, 2.4, Color(FROST, 0.85 * u))


func _ring(t: float, rr: float) -> void:
	var a := 1.0
	var reached := t0 + duration
	if t > reached:
		a = 1.0 - clampf((t - reached) / RING_FADE, 0.0, 1.0)
	if a <= 0.0:
		return
	# the band of cold behind the front
	for i in 5:
		var f := i / 4.0
		draw_arc(Vector2.ZERO, rr * (1.0 - 0.08 * f), 0.0, TAU, 96, Color(ICE, (0.22 - 0.04 * i) * a), 18.0 - 3.0 * i, true)
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 128, Color(ICE_DEEP, 0.55 * a), 9.0, true)
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 128, Color(FROST, 0.95 * a), 4.0, true)


func _shards_at(t: float, rr: float) -> void:
	var reached := t0 + duration
	var a := 1.0 - clampf((t - reached) / 0.45, 0.0, 1.0)
	if a <= 0.0:
		return
	for s in _shards:
		var r: float = rr * (1.0 - float(s[3]))
		var p := Vector2.from_angle(float(s[0])) * r
		var dir := Vector2.from_angle(float(s[0]) + float(s[2]) * (t - t0))
		var sz: float = s[1]
		var tip := p + dir * sz
		var tail := p - dir * sz * 0.6
		var side := dir.orthogonal() * sz * 0.32
		var pts := PackedVector2Array([tip, p + side, tail, p - side])
		draw_colored_polygon(pts, Color(FROST, 0.9 * a))
		pts.append(tip)
		draw_polyline(pts, Color(ICE_DEEP, 0.9 * a), 1.4, true)


func _snow(tau: float) -> void:
	var life := duration + FROST_HOLD + FROST_FADE
	var a := 1.0 - clampf(tau / life, 0.0, 1.0)
	if a <= 0.0:
		return
	for fl in _flakes:
		var d: float = minf(radius, radius * float(fl[1]) * minf(1.0, tau / maxf(duration, 0.05) * 1.1))
		var p := Vector2.from_angle(float(fl[0])) * d + Vector2(0, float(fl[4]) * tau)
		if terrain != null and terrain.has_method("is_solid") and terrain.is_solid(position.x + p.x, position.y + p.y):
			continue # settled on the ground (not drawn over the dirt)
		var sz: float = fl[2]
		var rot := float(fl[3]) * tau
		for j in 3:
			var v := Vector2.from_angle(rot + PI * j / 3.0) * sz
			draw_line(p - v, p + v, Color(FROST, 0.85 * a), 1.2, true)


func _ground_frost(t: float, rr: float) -> void:
	if _frost.size() < 2:
		return
	var a := 1.0
	var passed := t0 + duration + FROST_HOLD
	if t > passed:
		a = 1.0 - clampf((t - passed) / FROST_FADE, 0.0, 1.0)
	if a <= 0.0:
		return
	var seg := PackedVector2Array()
	for p in _frost:
		if p.x == INF or p.length() > rr:
			if seg.size() >= 2:
				_frost_seg(seg, a)
			seg = PackedVector2Array()
			continue
		seg.append(p)
	if seg.size() >= 2:
		_frost_seg(seg, a)


func _frost_seg(seg: PackedVector2Array, a: float) -> void:
	draw_polyline(seg, Color(ICE, 0.45 * a), 10.0, true)
	draw_polyline(seg, Color(FROST, 0.9 * a), 4.0, true)
	for i in range(0, seg.size(), 2): # little ice crystals on it
		var p := seg[i]
		draw_line(p, p + Vector2(-3, -7), Color(FROST, 0.8 * a), 1.4, true)
		draw_line(p, p + Vector2(3, -6), Color(FROST, 0.8 * a), 1.4, true)


func _glow(c: Vector2, r: float, col: Color) -> void:
	for i in 6:
		var f := 1.0 - i / 6.0
		draw_circle(c, r * f, Color(col, col.a * 0.3))


## A six-arm snowflake sigil of radius r, turned rot, faded a.
func _snowflake(c: Vector2, r: float, rot: float, a: float) -> void:
	var w := maxf(2.0, r * 0.06)
	for i in 6:
		var d := Vector2.from_angle(rot - PI / 2.0 + TAU * i / 6.0)
		var tip := c + d * r
		draw_line(c, tip, Color(ICE_DEEP, 0.7 * a), w * 2.6, true)
		draw_line(c, tip, Color(FROST, a), w, true)
		for f in [0.35, 0.6, 0.82]:
			var at: Vector2 = c + d * r * f
			var bl: float = r * (0.3 if f < 0.5 else (0.22 if f < 0.7 else 0.12))
			for side in [-1.0, 1.0]:
				var b := d.rotated(side * PI / 3.0) * bl
				draw_line(at, at + b, Color(ICE_DEEP, 0.6 * a), w * 1.8, true)
				draw_line(at, at + b, Color(FROST, a), w * 0.7, true)
	var hexa := PackedVector2Array()
	for i in 6:
		hexa.append(c + Vector2.from_angle(rot + TAU * i / 6.0) * r * 0.16)
	draw_colored_polygon(hexa, Color(FROST, a))
	hexa.append(hexa[0])
	draw_polyline(hexa, Color(ICE_DEEP, a), w, true)
