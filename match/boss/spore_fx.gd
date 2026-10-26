extends Node2D
## A cloud of poison spores (boss v4, Mộc Tinh's mushrooms), on the fx layer at its centre: puffy
## yellow-green cartoon puffs rolling out to `radius` (flattened a little along the ground), spores
## drifting in them, then thinning away. Modes: PUFF (a mushroom's turn, the spore event: the cloud
## rolls out to its auraRadius), BURST (its death blast: a hard pop of spores out to the blast's
## reach), TICK (a poison tick on a unit: a small puff of green bubbles and spores over the body).
## Stateless but for its age: every puff and spore comes from it (seeded); it frees itself.

const PUFF := "puff"
const BURST := "burst"
const TICK := "tick"
const SPORE := Color(0.82, 0.95, 0.35)
const CLOUD := Color(0.72, 0.88, 0.24)
const CLOUD_DARK := Color(0.46, 0.6, 0.12)
const LIFE := {PUFF: 1.5, BURST: 1.3, TICK: 0.8}
const REACH_SEC := {PUFF: 0.55, BURST: 0.3, TICK: 0.35} # s to roll out to the radius
const PUFFS := {PUFF: 16, BURST: 22, TICK: 6}
const DOTS := {PUFF: 30, BURST: 40, TICK: 10}

var mode := PUFF
var radius := 120.0
var _t := 0.0
var _seed := 0.0
static var _soft: GradientTexture2D


func _init(kind: String = PUFF, reach: float = 120.0) -> void:
	mode = kind if LIFE.has(kind) else PUFF
	radius = clampf(reach, 12.0, 400.0)
	_seed = randf() * 50.0
	z_index = 2


func age() -> float:
	return _t


func life() -> float:
	return float(LIFE[mode])


## How far the cloud has rolled out (0..1 of the radius) at age t.
static func reach_at(kind: String, t: float) -> float:
	var u := clampf(t / float(REACH_SEC.get(kind, 0.5)), 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


func _n(i: float, j: float) -> float:
	return fposmod(sin((i + _seed) * 12.9898 + j * 78.233) * 43758.5453, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if _t >= life():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var L := life()
	var out := reach_at(mode, _t)
	var fade := clampf((L - _t) / (L * 0.45), 0.0, 1.0)
	var flat := 0.62 if mode != TICK else 0.9
	if mode == BURST and _t < 0.18: # the pop
		var f := _t / 0.18
		_soft_at(Vector2.ZERO, radius * (0.35 + 0.5 * f), Color(1.0, 1.0, 0.7, 0.75 * (1.0 - f)))
	var n := int(PUFFS[mode])
	for i in n: # the puffs: soft blobs with a lighter top, rolling out
		var ang := TAU * _n(i, 1.0)
		var d := (0.25 + 0.75 * _n(i, 2.0)) * out
		var p := Vector2(cos(ang), sin(ang) * flat) * radius * d + Vector2(0, -radius * 0.18 * (1.0 - d * 0.5))
		p.y -= _t * 18.0 * _n(i, 3.0) # drifting up a little
		var r := radius * (0.16 + 0.14 * _n(i, 4.0)) * (0.55 + 0.55 * out)
		if mode == TICK:
			r *= 0.8
		var a := fade * (0.62 + 0.25 * _n(i, 5.0))
		draw_circle(p, r, Color(CLOUD_DARK, 0.4 * a))
		draw_circle(p + Vector2(-r * 0.12, -r * 0.16), r * 0.86, Color(CLOUD, 0.55 * a))
		draw_circle(p + Vector2(-r * 0.3, -r * 0.34), r * 0.4, Color(1.0, 1.0, 0.75, 0.32 * a))
		draw_arc(p, r, PI * 0.05, PI * 0.95, 10, Color(CLOUD_DARK, 0.5 * a), 1.6, true)
	var m := int(DOTS[mode])
	for i in m: # spores drifting in it
		var ang := TAU * _n(i, 7.0)
		var d := _n(i, 8.0) * out * 1.05
		var p := Vector2(cos(ang), sin(ang) * flat) * radius * d
		p += Vector2(sin(_t * 2.0 + i) * 6.0, -_t * (20.0 + 30.0 * _n(i, 9.0)))
		var tw := 0.5 + 0.5 * sin(_t * 9.0 + i * 1.7)
		draw_circle(p, 1.6 + 1.6 * _n(i, 10.0), Color(SPORE.lightened(0.2 * tw), (0.55 + 0.45 * tw) * fade))
	if mode == TICK: # bubbles popping
		for i in 5:
			var ph := clampf(_t / L * 1.3 - i * 0.12, 0.0, 1.0)
			if ph <= 0.0 or ph >= 1.0:
				continue
			var p := Vector2((_n(i, 11.0) - 0.5) * radius * 1.2, -radius * 0.2 - ph * radius * 0.9)
			draw_arc(p, 3.0 + 3.0 * ph, 0.0, TAU, 12, Color(SPORE, (1.0 - ph) * fade), 1.6, true)


func _soft_at(c: Vector2, r: float, col: Color) -> void:
	draw_texture_rect(soft_texture(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


static func soft_texture() -> GradientTexture2D:
	if _soft == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 64
		_soft.height = 64
	return _soft
