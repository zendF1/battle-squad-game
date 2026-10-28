extends Node2D
## The nuke's blast over its explosion (Bom huỷ diệt), on the fx layer at the impact, drawn in
## code: a white flash, a fireball swelling and cooling from yellow-white to red, a shockwave
## running out along the ground, and the mushroom cloud: a narrowing stem rising from the fireball
## to RISE × the blast radius, the cap rolling out wide on top of it (a domed top with a hot core,
## a flat dark underside; cooling from orange to dusty grey-brown), a smoke ring round the stem
## under it; then it all drifts up a little and fades. `radius` is
## the blast's reach (the server's explosionRadius). Visual only; it frees itself.

const LIFE := 2.8
const FLASH_SEC := 0.25
const FIRE_SEC := 0.9
const WAVE_SEC := 0.7
const RISE_SEC := 1.1
const RISE := 2.2 # the cap's height × radius
const CAP_PUFFS := 14
const STEM_PUFFS := 10

var radius := 100.0

var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	z_index = 0 # over the players (the fx layer), under the damage numbers that come after it
	_seed = randf() * 100.0


func age() -> float:
	return _t


## The cap's centre height above the impact (px) at time t.
func cap_height(t: float) -> float:
	var k := clampf(t / RISE_SEC, 0.0, 1.0)
	return radius * RISE * (1.0 - (1.0 - k) * (1.0 - k)) + maxf(t - RISE_SEC, 0.0) * 18.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _heat(h: float) -> Color: # 1 white-hot .. 0 smoke
	var cols := [Color(0.35, 0.3, 0.3), Color(0.55, 0.22, 0.1), Color(0.95, 0.35, 0.08), Color(1.0, 0.7, 0.2), Color(1, 0.97, 0.85)]
	var x := clampf(h, 0.0, 1.0) * (cols.size() - 1)
	var i := mini(int(x), cols.size() - 2)
	return Color(cols[i]).lerp(cols[i + 1], x - i)


func _draw() -> void:
	var r := radius
	var fade := clampf((LIFE - _t) / 0.9, 0.0, 1.0)
	var cool := clampf(_t / 1.6, 0.0, 1.0) # 0 hot .. 1 smoke
	# shockwave along the ground
	if _t < WAVE_SEC:
		var k := _t / WAVE_SEC
		var wr := lerpf(r * 0.4, r * 3.2, 1.0 - (1.0 - k) * (1.0 - k))
		var pts := PackedVector2Array()
		for i in 49:
			var a := PI + PI * i / 48.0 # the upper half: over the ground
			pts.append(Vector2(cos(a) * wr, sin(a) * wr * 0.32))
		draw_polyline(pts, Color(1, 0.95, 0.85, 0.75 * (1.0 - k)), lerpf(10.0, 2.0, k), true)
	# the stem: a narrowing column of puffs from the fireball up to the cap
	var top := -cap_height(_t)
	var grow := minf(_t / 0.35, 1.0)
	for i in STEM_PUFFS:
		var f := float(i) / (STEM_PUFFS - 1)
		var y := lerpf(-r * 0.2, top + r * 0.2, f) * grow
		var w := r * lerpf(0.36, 0.2, f)
		var wob := sin(_seed + i * 1.7 + _t * 2.0) * r * 0.04
		draw_circle(Vector2(wob, y), w, Color(_heat(lerpf(0.75, 0.4, f) * (1.0 - cool)), 0.9 * fade), true, -1.0, true)
	var spread := minf(_t / (RISE_SEC * 0.8), 1.0)
	var cap_w := r * lerpf(0.5, 1.45, spread) # half width
	var cap_h := r * lerpf(0.3, 0.62, spread) # dome height
	# the ring of smoke round the stem under the cap
	if _t > 0.35:
		var rk := clampf((_t - 0.35) / 0.8, 0.0, 1.0)
		var ring := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			ring.append(Vector2(cos(a) * cap_w * lerpf(0.4, 0.8, rk), top + r * 0.75 + sin(a) * r * 0.12))
		draw_polyline(ring, Color(_heat(0.3 * (1.0 - cool)), 0.65 * fade), r * 0.12, true)
	# the cap's dark underside (a flat rim of puffs), then its dome, the hot core inside
	for i in CAP_PUFFS:
		var f := (i + 0.5) / CAP_PUFFS
		var x := lerpf(-cap_w, cap_w, f)
		var pr := r * lerpf(0.2, 0.3, spread) * (0.85 + 0.15 * sin(_seed + i * 2.1))
		draw_circle(Vector2(x * 0.92, top + r * 0.12), pr, Color(_heat(0.12 * (1.0 - cool)).darkened(0.25), 0.95 * fade), true, -1.0, true)
	for i in CAP_PUFFS:
		var a := PI + PI * (i + 0.5) / CAP_PUFFS
		var p := Vector2(cos(a) * cap_w, top + sin(a) * cap_h)
		var pr := r * lerpf(0.22, 0.36, spread) * (0.85 + 0.15 * sin(_seed * 2.0 + i * 2.3))
		draw_circle(p, pr, Color(_heat(lerpf(0.5, 0.25, absf(cos(a))) * (1.0 - cool)), 0.95 * fade), true, -1.0, true)
	draw_circle(Vector2(0, top - cap_h * 0.35), cap_w * 0.7, Color(_heat(0.45 * (1.0 - cool)), 0.95 * fade), true, -1.0, true)
	draw_circle(Vector2(0, top - cap_h * 0.3), cap_w * 0.38, Color(_heat(0.85 * (1.0 - cool)), 0.8 * fade * (1.0 - cool)), true, -1.0, true)
	# the fireball on the ground
	if _t < FIRE_SEC + 0.6:
		var k := clampf(_t / 0.3, 0.0, 1.0)
		var fr := r * lerpf(0.3, 0.95, k) * (1.0 - clampf((_t - FIRE_SEC) / 0.6, 0.0, 1.0) * 0.5)
		var heat := clampf(1.0 - _t / (FIRE_SEC + 0.6), 0.0, 1.0)
		draw_circle(Vector2(0, -fr * 0.35), fr, Color(_heat(heat), 0.9 * heat + 0.1), true, -1.0, true)
		draw_circle(Vector2(0, -fr * 0.35), fr * 0.55, Color(_heat(minf(heat + 0.25, 1.0)), heat), true, -1.0, true)
	# the flash
	if _t < FLASH_SEC:
		var k := _t / FLASH_SEC
		draw_circle(Vector2.ZERO, r * lerpf(0.8, 2.2, k), Color(1, 1, 0.95, 0.9 * (1.0 - k)), true, -1.0, true)
