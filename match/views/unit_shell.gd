extends Node2D
## A boss's or minion's projectile in flight (boss mode v3: the server's projectile kind per boss
## skill and minion shot), drawn in code (original art, the bosses' outlined cartoon style), each
## kind with its own body and trail; ShotPlayer moves it along the server path and feeds the path's
## tangent (set_tangent()), which the pointed kinds follow exactly (no smoothing, no wobble):
## - steel_shell (Rô-bốt Thép's shell rain): a pointed steel shell with a brass band, pointing along
##   its flight, a grey smoke trail;
## - magma_bomb (Cua Dung Nham's fire bombs): a glowing lava blob, dark crust with pulsing cracks,
##   lava drips falling off it and an ember trail;
## - ice_shard (Phù Thuỷ Băng's blizzard): one of her orbiting crystals (BossArt's shard shape),
##   tumbling, with a frost trail and glints;
## - ice_spike (her ice spikes): a long icicle pointing along its flight, a short frost trail;
## - drone_bolt (a drone's shot): an energy bolt stretched along its flight, a hot streak;
## - crab_spit (a crabling's shot): an orange glob, wobbling, dripping;
## - snowball (a snowman's shot): a shaded snowball rolling over, a powder trail.
## Any other kind is not this view: ShotPlayer keeps the gun's shell for it (is_kind()). The
## impact of each kind is UnitImpact's. Trail particles live in a fixed pool (global positions,
## oldest reused), so a long flight costs the same.

const STEEL_SHELL := "steel_shell"
const MAGMA_BOMB := "magma_bomb"
const ICE_SHARD := "ice_shard"
const ICE_SPIKE := "ice_spike"
const DRONE_BOLT := "drone_bolt"
const CRAB_SPIT := "crab_spit"
const SNOWBALL := "snowball"
const KINDS := [STEEL_SHELL, MAGMA_BOMB, ICE_SHARD, ICE_SPIKE, DRONE_BOLT, CRAB_SPIT, SNOWBALL]
## The kinds drawn turned to their flight (the rest tumble or roll).
const POINTED := [STEEL_SHELL, ICE_SPIKE, DRONE_BOLT]

const OUT := Color(0.08, 0.06, 0.12)
const POOL := 28
const SCALE := 1.35 # the bodies' size (units drawn in a ~24 px frame)
## kind -> its trail: every px between two particles, their life (s), size (px) from / to, colour,
## drift (px/s: + down), additive glow.
const TRAILS := {
	STEEL_SHELL: {"every": 9.0, "life": 0.55, "r0": 4.0, "r1": 11.0, "color": Color(0.62, 0.64, 0.7, 0.55), "drift": -12.0},
	MAGMA_BOMB: {"every": 7.0, "life": 0.6, "r0": 4.5, "r1": 1.5, "color": Color(1.0, 0.55, 0.12, 0.9), "drift": -30.0, "glow": true},
	ICE_SHARD: {"every": 7.0, "life": 0.5, "r0": 4.0, "r1": 1.0, "color": Color(0.78, 0.95, 1.0, 0.85), "drift": 10.0, "glow": true},
	ICE_SPIKE: {"every": 8.0, "life": 0.32, "r0": 3.0, "r1": 0.8, "color": Color(0.85, 0.97, 1.0, 0.8), "drift": 0.0, "glow": true},
	DRONE_BOLT: {"every": 5.0, "life": 0.22, "r0": 4.0, "r1": 1.0, "color": Color(1.0, 0.42, 0.3, 0.9), "drift": 0.0, "glow": true},
	CRAB_SPIT: {"every": 8.0, "life": 0.45, "r0": 3.5, "r1": 1.0, "color": Color(1.0, 0.6, 0.2, 0.85), "drift": 60.0},
	SNOWBALL: {"every": 8.0, "life": 0.5, "r0": 3.0, "r1": 9.0, "color": Color(0.96, 0.98, 1.0, 0.6), "drift": 8.0},
}

var kind := ICE_SHARD
var trail_length := 1.0 # the share of its trail kept (ShotPlayer's callers set it like a shell's)
var skill := false # unused (a gun shell's flag; kept so the callers can set it)
var heading := Vector2.ZERO

var _t := 0.0
var _dir := Vector2.RIGHT
var _tangent := Vector2.ZERO
var _last := Vector2.INF
var _since := 0.0
var _pos := PackedVector2Array() # trail particles: global position, age, seed
var _age := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _next := 0
var _spin := 0.0


static func is_kind(k: String) -> bool:
	return KINDS.has(k)


func _init(kind_id: String = ICE_SHARD) -> void:
	kind = kind_id
	_pos.resize(POOL)
	_age.resize(POOL)
	_seed.resize(POOL)
	_age.fill(99.0)
	_spin = randf() * TAU


func _ready() -> void:
	if heading.length_squared() > 0.0:
		_dir = heading.normalized()
	_last = global_position


## The flight direction from the server path: the pointed kinds face it exactly.
func set_tangent(v: Vector2) -> void:
	if v.length_squared() > 0.0:
		_tangent = v
		_dir = v.normalized()


func pointed() -> bool:
	return POINTED.has(kind)


## The drawn rotation (rad): along the flight for the pointed kinds, tumbling / rolling for the rest.
func draw_angle() -> float:
	if pointed():
		return _dir.angle()
	match kind:
		ICE_SHARD:
			return _spin + _t * 9.0
		SNOWBALL:
			return _spin + _t * 6.0 * signf(_dir.x if _dir.x != 0.0 else 1.0)
	return _spin + _t * 2.0


func _process(delta: float) -> void:
	_t += delta
	var p := global_position
	if _last == Vector2.INF:
		_last = p
	var step := p.distance_to(_last)
	if step > 0.01 and _tangent.length_squared() == 0.0:
		_dir = (p - _last) / step
	_last = p
	for i in POOL:
		_age[i] += delta
	var spec: Dictionary = TRAILS[kind]
	_since += step
	var every: float = spec["every"]
	while _since >= every:
		_since -= every
		_pos[_next] = p - _dir * _since
		_age[_next] = 0.0
		_seed[_next] = randf()
		_next = (_next + 1) % POOL
	queue_redraw()


func _draw() -> void:
	var spec: Dictionary = TRAILS[kind]
	var life: float = float(spec["life"]) * maxf(trail_length, 0.2)
	var col: Color = spec["color"]
	for i in POOL:
		var a := _age[i]
		if a >= life:
			continue
		var k := a / life
		var at := to_local(_pos[i]) + Vector2((_seed[i] - 0.5) * 6.0, float(spec["drift"]) * a)
		var r := lerpf(float(spec["r0"]), float(spec["r1"]), k)
		if spec.get("glow", false):
			draw_circle(at, r * 2.0, Color(col, col.a * 0.25 * (1.0 - k)))
		draw_circle(at, r, Color(col, col.a * (1.0 - k)))
	draw_set_transform(Vector2.ZERO, draw_angle(), Vector2(SCALE, SCALE))
	match kind:
		STEEL_SHELL:
			_steel_shell()
		MAGMA_BOMB:
			_magma_bomb()
		ICE_SHARD:
			_ice_shard()
		ICE_SPIKE:
			_ice_spike()
		DRONE_BOLT:
			_drone_bolt()
		CRAB_SPIT:
			_crab_spit()
		SNOWBALL:
			_snowball()
	draw_set_transform(Vector2.ZERO)
	if kind == MAGMA_BOMB:
		_drips()


func _outlined(pts: PackedVector2Array, fill: Color, width: float = 2.0) -> void:
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, OUT, width, true)


func _steel_shell() -> void:
	var body := PackedVector2Array([Vector2(13, 0), Vector2(7, -5), Vector2(-9, -5), Vector2(-11, -3), Vector2(-11, 3), Vector2(-9, 5), Vector2(7, 5)])
	_outlined(body, Color(0.62, 0.66, 0.74))
	draw_rect(Rect2(-4, -5, 3, 10), Color(0.85, 0.66, 0.28))
	draw_line(Vector2(-8, -2.5), Vector2(8, -2.5), Color(0.9, 0.93, 1.0, 0.8), 1.5, true)
	var flame := 0.7 + 0.3 * sin(_t * 50.0)
	draw_circle(Vector2(-13, 0), 3.5 * flame, Color(1.0, 0.7, 0.3, 0.9))


func _magma_bomb() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	draw_circle(Vector2.ZERO, 17.0, Color(1.0, 0.45, 0.1, 0.22 + 0.12 * pulse))
	var blob := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var r := 10.0 + 1.6 * sin(a * 3.0 + _t * 7.0)
		blob.append(Vector2.from_angle(a) * r)
	_outlined(blob, Color(0.32, 0.12, 0.08))
	var crack := Color(1.0, 0.62 + 0.25 * pulse, 0.15)
	draw_polyline(PackedVector2Array([Vector2(-6, -3), Vector2(-1, 1), Vector2(3, -2), Vector2(7, 2)]), crack, 2.2, true)
	draw_polyline(PackedVector2Array([Vector2(-3, 5), Vector2(1, 2), Vector2(4, 6)]), crack, 2.0, true)
	draw_circle(Vector2(-3, -5), 2.0, Color(1.0, 0.85, 0.4, 0.8))


## Lava drops falling off the bomb (below it, in world down).
func _drips() -> void:
	for i in 3:
		var k := fposmod(_t * 2.2 + i / 3.0, 1.0)
		var at := Vector2(-4.0 + 4.0 * i - _dir.x * 10.0 * k, 9.0 + 28.0 * k * k)
		draw_circle(at, 2.6 * (1.0 - k) + 0.8, Color(1.0, 0.5 + 0.3 * (1.0 - k), 0.12, 1.0 - k))


func _ice_shard() -> void:
	var r := 11.0
	draw_circle(Vector2.ZERO, 15.0, Color(0.6, 0.92, 1.0, 0.25))
	var pts := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.45, 0), Vector2(0, r), Vector2(-r * 0.45, 0)])
	_outlined(pts, Color(0.45, 0.88, 1.0))
	draw_line(pts[0], pts[2], Color(1, 1, 1, 0.7), 1.6, true)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r * 0.45, 0), Vector2(0, -r * 0.2)]), Color(1, 1, 1, 0.35))


func _ice_spike() -> void:
	var pts := PackedVector2Array([Vector2(22, 0), Vector2(-8, -5.5), Vector2(-12, -3), Vector2(-14, 0), Vector2(-12, 3), Vector2(-8, 5.5)])
	draw_circle(Vector2(4, 0), 12.0, Color(0.6, 0.92, 1.0, 0.2))
	_outlined(pts, Color(0.62, 0.92, 1.0))
	draw_line(Vector2(-10, -1.5), Vector2(19, -0.2), Color(1, 1, 1, 0.75), 1.6, true)
	for x in [-6.0, 2.0]:
		draw_line(Vector2(x, -4.5), Vector2(x + 3.0, -1.0), Color(0.3, 0.6, 0.85, 0.6), 1.0, true)


func _drone_bolt() -> void:
	var f := 1.0 + 0.15 * sin(_t * 60.0)
	draw_set_transform(Vector2.ZERO, draw_angle(), Vector2(SCALE, SCALE * f))
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.3, 0.2, 0.25))
	draw_colored_polygon(_ellipse(Vector2(-2, 0), 13.0, 4.5), Color(1.0, 0.35, 0.25, 0.9))
	draw_colored_polygon(_ellipse(Vector2(1, 0), 8.0, 2.2), Color(1.0, 0.92, 0.7))
	draw_set_transform(Vector2.ZERO, draw_angle(), Vector2(SCALE, SCALE))


func _crab_spit() -> void:
	var w := 1.0 + 0.12 * sin(_t * 14.0)
	draw_set_transform(Vector2.ZERO, draw_angle(), Vector2(SCALE * w, SCALE * (2.0 - w)))
	_outlined(_ellipse(Vector2.ZERO, 8.0, 7.0), Color(1.0, 0.55, 0.15))
	draw_circle(Vector2(-2.5, -2.5), 2.2, Color(1.0, 0.9, 0.6, 0.85))
	draw_set_transform(Vector2.ZERO, draw_angle(), Vector2(SCALE, SCALE))


func _snowball() -> void:
	_outlined(_ellipse(Vector2.ZERO, 8.5, 8.5), Color(0.96, 0.98, 1.0))
	draw_arc(Vector2.ZERO, 6.0, PI * 0.1, PI * 0.8, 10, Color(0.68, 0.8, 0.95), 2.6, true)
	draw_circle(Vector2(-2.5, -3), 1.6, Color(1, 1, 1))


static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
