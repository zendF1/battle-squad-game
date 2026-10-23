extends Node2D
## The boss's ground shockwave drawn (boss mode v3, Cua Dung Nham's Cú kẹp đập; Shockwave.detect()
## gives the slam and the steps), on the fx layer (world coordinates), from the server's explodes
## only: from the slam two ripples run along the ground surface to the map edges, each reaching a
## step when that step's explode comes (Shockwave.front()): a glowing crest riding the surface (in
## the boss's accent colour) with a dust skirt behind it and a scorched crack line left on the
## ground that cools off; at every step a dust burst (puffs rolling out, rock chips thrown up and
## falling back). Stateless per frame: everything comes from the time; at most a few hundred draws.
## sync(t) during the replay; after release() it runs on its own clock and frees itself.

const Shockwave := preload("res://match/boss/shockwave.gd")

const CREST_LEN := 150.0 # px of ground the crest covers behind its front
const CREST_H := 42.0 # px the crest rises at its top
const CREST_POINTS := 12
const CRACK_LIFE := 1.2 # s a crack line stays after the front passed
const DUST_LIFE := 0.9
const PUFFS := 8
const CHIPS := 6
const GRAVITY := 900.0
const DUST := Color(0.78, 0.68, 0.58)
const SLAM_SEC := 0.4 # the slam's ring opens this long
const SLAM_R := 190.0

var wave := {}
var terrain = null # the TerrainMask (the surface under the crest), null: the steps' heights
var accent := Color(1.0, 0.5, 0.15)

var _t := 0.0
var _released := false
var _bursts: Array = [] # [pos, t]


func setup(wave_value: Dictionary, terrain_mask = null, color: Color = Color(1.0, 0.5, 0.15)) -> void:
	wave = wave_value
	terrain = terrain_mask
	accent = color
	_bursts.clear()
	for side in ["left", "right"]:
		for item in wave.get(side, []):
			_bursts.append(item)


func sync(t: float) -> void:
	_t = t
	queue_redraw()


func release() -> void:
	_released = true


func done_at() -> float:
	return maxf(Shockwave.end_time(wave, "left"), Shockwave.end_time(wave, "right")) + maxf(DUST_LIFE, CRACK_LIFE)


func _process(delta: float) -> void:
	if not _released:
		return
	_t += delta
	queue_redraw()
	if _t > done_at() + 0.05:
		queue_free()


## The ground's surface y at x near y_hint (the terrain's, else the hint).
func surface_y(x: float, y_hint: float) -> float:
	if terrain != null and terrain.has_method("get_landing_y") and terrain.width > 0:
		var y: float = terrain.get_landing_y(clampf(x, 0.0, terrain.width - 1.0), maxf(y_hint - 80.0, 0.0))
		if absf(y - y_hint) < 160.0:
			return y
	return y_hint


func _draw() -> void:
	if wave.is_empty() or _t < float(wave.get("t0", 0.0)):
		return
	_draw_slam(_t - float(wave["t0"]))
	for side in ["left", "right"]:
		if wave.get(side, []).is_empty():
			continue
		_draw_side(side, -1.0 if side == "left" else 1.0)
	for b in _bursts:
		_draw_burst(b[0], _t - float(b[1]))


func _draw_side(side: String, sgn: float) -> void:
	var t0 := float(wave["t0"])
	var end := Shockwave.end_time(wave, side)
	var o: Vector2 = wave["origin"]
	var f := Shockwave.front(wave, side, _t)
	var alive := clampf(1.0 - (_t - end) / 0.35, 0.0, 1.0) # the crest dies at the edge
	# the crack line left on the ground: from the slam to the front, cooling off behind
	var n := 24
	var prev := Vector2.INF
	for i in n + 1:
		var x := lerpf(o.x, f.x, float(i) / n)
		var passed := _passed_at(side, x)
		var age := _t - passed
		if age < 0.0 or age > CRACK_LIFE:
			prev = Vector2.INF
			continue
		var p := Vector2(x, surface_y(x, lerpf(o.y, f.y, float(i) / n)))
		var heat := 1.0 - age / CRACK_LIFE
		if prev != Vector2.INF:
			draw_line(prev, p, Color(accent.lerp(Color(1, 0.9, 0.6), 0.3), 0.75 * heat), 2.0 + 3.0 * heat, true)
		prev = p
	if alive <= 0.0 or _t < t0:
		return
	# the crest: a glowing hump riding the surface behind the front, a dust skirt under it
	var crest := PackedVector2Array()
	for i in CREST_POINTS:
		var d := CREST_LEN * float(i) / (CREST_POINTS - 1)
		var x := f.x - sgn * d
		if sgn * (x - o.x) < 0.0:
			break
		var y := surface_y(x, f.y)
		var lift := CREST_H * sin(PI * sqrt(d / CREST_LEN)) * alive # its top a quarter behind the front
		crest.append(Vector2(x, y - lift))
	if crest.size() >= 2:
		draw_polyline(crest, Color(accent, 0.3 * alive), 24.0, true)
		draw_polyline(crest, Color(accent, 0.7 * alive), 11.0, true)
		draw_polyline(crest, Color(accent.lerp(Color.WHITE, 0.55), 0.95 * alive), 4.0, true)
		draw_circle(crest[0], 14.0 * alive, Color(accent.lerp(Color.WHITE, 0.4), 0.55 * alive))
	var fy := surface_y(f.x, f.y)
	for k in 4:
		var u := float(k) / 4.0
		var px := f.x - sgn * (20.0 + 70.0 * u)
		var r := (20.0 + 22.0 * u) * alive
		draw_circle(Vector2(px, surface_y(px, fy) - r * 0.4), r, Color(DUST, 0.45 * (1.0 - u) * alive))


## The slam at the boss's feet: a flat ring opening on the ground, a flash in the middle.
func _draw_slam(age: float) -> void:
	if age < 0.0 or age > SLAM_SEC:
		return
	var k := age / SLAM_SEC
	var o: Vector2 = wave["origin"]
	var r := SLAM_R * (1.0 - (1.0 - k) * (1.0 - k))
	draw_set_transform(o, 0.0, Vector2(1.0, 0.3))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(accent.lerp(Color.WHITE, 0.4), 0.9 * (1.0 - k)), 10.0 * (1.0 - k) + 2.0, true)
	draw_circle(Vector2.ZERO, r * 0.6, Color(accent, 0.25 * (1.0 - k)))
	draw_set_transform(Vector2.ZERO)


## When the front passed x on a side (the time between the steps around it).
func _passed_at(side: String, x: float) -> float:
	var pts: Array = [[wave["origin"], float(wave["t0"])]] + wave.get(side, [])
	for i in range(1, pts.size()):
		var a: Array = pts[i - 1]
		var b: Array = pts[i]
		var lo := minf(a[0].x, b[0].x)
		var hi := maxf(a[0].x, b[0].x)
		if x >= lo - 0.5 and x <= hi + 0.5:
			var span: float = b[0].x - a[0].x
			var k: float = (x - a[0].x) / span if absf(span) > 1e-3 else 1.0
			return lerpf(float(a[1]), float(b[1]), clampf(k, 0.0, 1.0))
	return float(wave["t0"])


## A step's dust burst age s after its explode: puffs rolling out low, chips thrown up.
func _draw_burst(at: Vector2, age: float) -> void:
	if age < 0.0 or age > DUST_LIFE:
		return
	var k := age / DUST_LIFE
	var life := 1.0 - k
	for i in PUFFS:
		var side := -1.0 if i % 2 == 0 else 1.0
		var spread := (0.3 + 0.7 * float(i) / PUFFS)
		var p := at + Vector2(side * spread * 70.0 * (1.0 - (1.0 - k) * (1.0 - k)), -10.0 - 26.0 * k * spread)
		draw_circle(p, (14.0 + 26.0 * k) * (0.7 + 0.3 * spread), Color(DUST, 0.6 * life))
	for i in CHIPS:
		var ang := -PI * 0.5 + (float(i) / (CHIPS - 1) - 0.5) * 1.6
		var v := Vector2.from_angle(ang) * (260.0 + 60.0 * float(i % 2))
		var p := at + v * age + Vector2(0, 0.5 * GRAVITY * age * age)
		var s := 6.0 + 1.5 * float(i % 3)
		draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Color(0.36, 0.28, 0.22, life))
