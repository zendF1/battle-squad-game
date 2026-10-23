extends Node2D
## A boss's or minion's projectile in flight (boss mode v3: the server's projectile kind per boss
## skill and minion shot), drawn in code (original art, the bosses' outlined cartoon style), each
## kind with its own body and trail; ShotPlayer moves it along the server path and feeds the path's
## tangent (set_tangent()), which the pointed kinds follow exactly (no smoothing, no wobble).
## Sizes: a minion's shot is as big as a player character's shell (player_shell_px(): the mean
## longest side of the guns' shell pictures as ProjectileView draws them), a boss's BOSS_SIZE × it
## and drawn with more detail (shading, highlights, an outline, richer trails):
## - steel_shell (Rô-bốt Thép's shell rain): a steel shell with a shaded body, a highlight, two brass
##   bands with rivets, tail fins and a hot exhaust, pointing along its flight; smoke and sparks;
## - magma_bomb (Cua Dung Nham's fire bombs): a basalt crust shaded round, glowing cracks over a
##   molten core shining through, hot spots, lava drips falling off; embers and dark smoke;
## - ice_shard (Phù Thuỷ Băng's blizzard): one of her orbiting crystals (BossArt's shard shape) cut
##   in light and dark facets with an inner light, tumbling; frost and glints;
## - ice_spike (her ice spikes): a long faceted icicle with an inner light, pointing along its
##   flight; frost mist and glints;
## - drone_bolt (a drone's shot): an energy bolt stretched along its flight, a hot streak;
## - crab_spit (a crabling's shot): an orange glob, wobbling, dripping;
## - snowball (a snowman's shot): a shaded snowball rolling over, a powder trail.
## Any other kind is not this view: ShotPlayer keeps the gun's shell for it (is_kind()). The
## impact of each kind is UnitImpact's. Trail particles live in a fixed pool (global positions,
## oldest reused), so a long flight costs the same.

const Art := preload("res://ui/art.gd")
const ShotLook := preload("res://match/views/shot_look.gd")
const ProjectileView := preload("res://match/views/projectile_view.gd")

const STEEL_SHELL := "steel_shell"
const MAGMA_BOMB := "magma_bomb"
const ICE_SHARD := "ice_shard"
const ICE_SPIKE := "ice_spike"
const DRONE_BOLT := "drone_bolt"
const CRAB_SPIT := "crab_spit"
const SNOWBALL := "snowball"
const KINDS := [STEEL_SHELL, MAGMA_BOMB, ICE_SHARD, ICE_SPIKE, DRONE_BOLT, CRAB_SPIT, SNOWBALL]
const BOSS_KINDS := [STEEL_SHELL, MAGMA_BOMB, ICE_SHARD, ICE_SPIKE]
## The kinds drawn turned to their flight (the rest tumble or roll).
const POINTED := [STEEL_SHELL, ICE_SPIKE, DRONE_BOLT]
const BOSS_SIZE := 1.8 # a boss's projectile × a player's shell
const BOMB_PX := 2.0 # ProjectileView's picture px per world px
## Each body's longest side in its drawing frame (units), so it is drawn at its size.
const EXTENT := {STEEL_SHELL: 30.0, MAGMA_BOMB: 24.0, ICE_SHARD: 24.0, ICE_SPIKE: 38.0, DRONE_BOLT: 26.0, CRAB_SPIT: 16.0, SNOWBALL: 17.0}

const OUT := Color(0.08, 0.06, 0.12)
const POOL := 40
## kind -> its trail (sizes in px at a player shell's size; × the body's scale): every px between
## two particles, their life (s), size from / to, colour, drift (px/s: + down), glow; mix: the share
## of them drawn as the second look (look2: "smoke", "glint" or "spark").
const TRAILS := {
	STEEL_SHELL: {"every": 6.0, "life": 0.7, "r0": 3.5, "r1": 9.0, "color": Color(0.52, 0.54, 0.6, 0.8), "drift": -14.0,
		"mix": 0.25, "look2": "spark", "color2": Color(1.0, 0.8, 0.4)},
	MAGMA_BOMB: {"every": 5.0, "life": 0.7, "r0": 3.0, "r1": 1.0, "color": Color(1.0, 0.55, 0.12, 0.95), "drift": -34.0, "glow": true,
		"mix": 0.4, "look2": "smoke", "color2": Color(0.25, 0.18, 0.18, 0.55)},
	ICE_SHARD: {"every": 5.0, "life": 0.55, "r0": 3.0, "r1": 0.8, "color": Color(0.78, 0.95, 1.0, 0.9), "drift": 10.0, "glow": true,
		"mix": 0.3, "look2": "glint", "color2": Color(1, 1, 1)},
	ICE_SPIKE: {"every": 5.0, "life": 0.45, "r0": 2.6, "r1": 6.0, "color": Color(0.85, 0.96, 1.0, 0.45), "drift": 6.0,
		"mix": 0.3, "look2": "glint", "color2": Color(1, 1, 1)},
	DRONE_BOLT: {"every": 5.0, "life": 0.22, "r0": 3.0, "r1": 0.8, "color": Color(1.0, 0.42, 0.3, 0.9), "drift": 0.0, "glow": true},
	CRAB_SPIT: {"every": 7.0, "life": 0.4, "r0": 2.6, "r1": 0.8, "color": Color(1.0, 0.6, 0.2, 0.85), "drift": 60.0},
	SNOWBALL: {"every": 7.0, "life": 0.45, "r0": 2.0, "r1": 6.0, "color": Color(0.96, 0.98, 1.0, 0.6), "drift": 8.0},
}

static var _player_px := -1.0

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
var _s := 1.0 # drawing units → px


static func is_kind(k: String) -> bool:
	return KINDS.has(k)


static func is_boss_kind(k: String) -> bool:
	return BOSS_KINDS.has(k)


## A player character's shell (px, its longest side as ProjectileView draws it): the mean over the
## guns' shell pictures (their drawn part / BOMB_PX × ShotLook.SHELL_SCALE); 22 without pictures.
static func player_shell_px() -> float:
	if _player_px > 0.0:
		return _player_px
	var total := 0.0
	var n := 0
	for k in ShotLook.KINDS:
		var tex: Texture2D = Art.shot(k, "projectile", null)
		if tex == null:
			continue
		var box: Vector2 = ProjectileView.base_content(tex)
		total += maxf(box.x, box.y) / BOMB_PX * ShotLook.SHELL_SCALE
		n += 1
	_player_px = total / n if n > 0 else 22.0
	return _player_px


## The drawn length (px) of a kind's body: a player shell's for a minion's, BOSS_SIZE × for a boss's.
static func size_px(k: String) -> float:
	return player_shell_px() * (BOSS_SIZE if is_boss_kind(k) else 1.0)


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
	_s = size_px(kind) / float(EXTENT.get(kind, 24.0))


## The body's drawn length now (px).
func drawn_px() -> float:
	return float(EXTENT.get(kind, 24.0)) * _s


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
	var every: float = float(spec["every"]) * maxf(_s * 0.8, 0.6)
	while _since >= every:
		_since -= every
		_pos[_next] = p - _dir * (_since + drawn_px() * 0.4)
		_age[_next] = 0.0
		_seed[_next] = randf()
		_next = (_next + 1) % POOL
	queue_redraw()


func _draw() -> void:
	_draw_trail()
	var rot := draw_angle()
	draw_set_transform(Vector2.ZERO, rot, Vector2(_s, _s))
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
			var f := 1.0 + 0.15 * sin(_t * 60.0)
			draw_set_transform(Vector2.ZERO, rot, Vector2(_s, _s * f))
			_drone_bolt()
		CRAB_SPIT:
			var w := 1.0 + 0.12 * sin(_t * 14.0)
			draw_set_transform(Vector2.ZERO, rot, Vector2(_s * w, _s * (2.0 - w)))
			_crab_spit()
		SNOWBALL:
			_snowball()
	draw_set_transform(Vector2.ZERO)
	if kind == MAGMA_BOMB:
		_drips()


func _draw_trail() -> void:
	var spec: Dictionary = TRAILS[kind]
	var life: float = float(spec["life"]) * maxf(trail_length, 0.2)
	var col: Color = spec["color"]
	var col2: Color = spec.get("color2", col)
	var mix := float(spec.get("mix", 0.0))
	var look2 := str(spec.get("look2", ""))
	var k_s := maxf(_s * 0.85, 0.7) # the trail grows with the body
	for i in POOL:
		var a := _age[i]
		if a >= life:
			continue
		var k := a / life
		var second := _seed[i] < mix
		var at := to_local(_pos[i]) + Vector2((_seed[i] - 0.5) * 8.0 * k_s, float(spec["drift"]) * a)
		var r := lerpf(float(spec["r0"]), float(spec["r1"]), k) * k_s
		if second:
			match look2:
				"smoke":
					draw_circle(at, r * 2.4 + 6.0 * k, Color(col2, col2.a * (1.0 - k)))
				"glint":
					var g := (4.0 + 3.0 * (1.0 - k)) * k_s * 0.7
					draw_line(at - Vector2(g, 0), at + Vector2(g, 0), Color(col2, 1.0 - k), 1.4, true)
					draw_line(at - Vector2(0, g), at + Vector2(0, g), Color(col2, 1.0 - k), 1.4, true)
				"spark":
					var v := Vector2.from_angle(_seed[i] * 40.0) * 26.0 * a
					draw_line(at + v, at + v * 1.4 + Vector2(0, 2), Color(col2, 1.0 - k), 1.6, true)
			continue
		if spec.get("glow", false):
			draw_circle(at, r * 2.0, Color(col, col.a * 0.25 * (1.0 - k)))
		draw_circle(at, r, Color(col, col.a * (1.0 - k)))


func _outlined(pts: PackedVector2Array, fill: Color, width: float = 2.0) -> void:
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, OUT, width / _s * 1.2, true)


# ── Boss projectiles (BOSS_SIZE, detailed) ───────────────────────────────────

func _steel_shell() -> void:
	# exhaust glow behind
	var flame := 0.75 + 0.25 * sin(_t * 50.0)
	draw_circle(Vector2(-17, 0), 6.0 * flame, Color(1.0, 0.55, 0.2, 0.35))
	draw_circle(Vector2(-16, 0), 3.4 * flame, Color(1.0, 0.85, 0.5, 0.95))
	# fins
	_outlined(PackedVector2Array([Vector2(-8, -5), Vector2(-15, -9), Vector2(-15, -5)]), Color(0.42, 0.45, 0.52))
	_outlined(PackedVector2Array([Vector2(-8, 5), Vector2(-15, 9), Vector2(-15, 5)]), Color(0.36, 0.38, 0.45))
	# the body: lit top, shaded bottom
	var body := PackedVector2Array([Vector2(15, 0), Vector2(9, -5.5), Vector2(-12, -5.5), Vector2(-14, -3.5), Vector2(-14, 3.5),
		Vector2(-12, 5.5), Vector2(9, 5.5)])
	_outlined(body, Color(0.6, 0.64, 0.72))
	draw_colored_polygon(PackedVector2Array([Vector2(14, 0.5), Vector2(9, 5.2), Vector2(-12, 5.2), Vector2(-13.6, 3.4), Vector2(-13.6, 0.5)]),
		Color(0.38, 0.41, 0.49))
	draw_colored_polygon(PackedVector2Array([Vector2(15, 0), Vector2(9, -5.5), Vector2(6, -5.5), Vector2(10, 0)]), Color(0.82, 0.85, 0.92))
	draw_line(Vector2(-11, -3.2), Vector2(8, -3.2), Color(0.95, 0.97, 1.0, 0.85), 1.4, true)
	# two brass bands with rivets
	for x in [-7.0, 1.0]:
		draw_rect(Rect2(x, -5.5, 3.0, 11.0), Color(0.82, 0.62, 0.26))
		draw_rect(Rect2(x, -5.5, 3.0, 3.0), Color(0.96, 0.8, 0.42))
		for y in [-3.0, 0.5, 3.6]:
			draw_circle(Vector2(x + 1.5, y), 0.75, Color(0.4, 0.28, 0.1))


func _magma_bomb() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	draw_circle(Vector2.ZERO, 18.0, Color(1.0, 0.4, 0.08, 0.18 + 0.1 * pulse))
	var blob := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		blob.append(Vector2.from_angle(a) * (11.0 + 1.4 * sin(a * 3.0 + _t * 7.0)))
	_outlined(blob, Color(0.36, 0.15, 0.1))
	# the molten core showing through, the crust shaded round
	draw_circle(Vector2(1, 1), 7.5, Color(1.0, 0.42, 0.08, 0.55 + 0.25 * pulse))
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -6), Vector2(-2, -9), Vector2(4, -8), Vector2(-1, -3), Vector2(-7, -1)]),
		Color(0.48, 0.24, 0.16))
	draw_colored_polygon(PackedVector2Array([Vector2(3, 7), Vector2(9, 3), Vector2(8, 8), Vector2(2, 10)]), Color(0.22, 0.08, 0.06))
	var crack := Color(1.0, 0.7 + 0.25 * pulse, 0.2)
	var hot := Color(1.0, 0.95, 0.6, 0.9)
	for line in [[Vector2(-8, -1), Vector2(-3, 2), Vector2(1, -1), Vector2(6, 3), Vector2(9, 1)],
			[Vector2(-4, 7), Vector2(-1, 3), Vector2(3, 6)], [Vector2(0, -9), Vector2(1, -4), Vector2(-2, -1)]]:
		var pts := PackedVector2Array(line)
		draw_polyline(pts, Color(crack, 0.45), 4.2, true)
		draw_polyline(pts, crack, 2.0, true)
		draw_polyline(pts, hot, 0.8, true)
	draw_circle(Vector2(-4, -6), 1.8, Color(1, 0.9, 0.6, 0.8))


## Lava drops falling off the bomb (below it, in world down).
func _drips() -> void:
	for i in 3:
		var k := fposmod(_t * 2.2 + i / 3.0, 1.0)
		var at := Vector2((-5.0 + 5.0 * i) * _s - _dir.x * 12.0 * k * _s, (10.0 + 30.0 * k * k) * _s)
		draw_circle(at, (2.6 * (1.0 - k) + 0.8) * _s, Color(1.0, 0.5 + 0.3 * (1.0 - k), 0.12, 1.0 - k))


func _ice_shard() -> void:
	var r := 12.0
	var inner := 0.6 + 0.4 * sin(_t * 7.0)
	draw_circle(Vector2.ZERO, 16.0, Color(0.6, 0.92, 1.0, 0.22))
	var top := Vector2(0, -r)
	var right := Vector2(r * 0.45, 0)
	var bottom := Vector2(0, r)
	var left := Vector2(-r * 0.45, 0)
	_outlined(PackedVector2Array([top, right, bottom, left]), Color(0.45, 0.85, 1.0))
	# facets: light upper left, darker lower right
	draw_colored_polygon(PackedVector2Array([top, Vector2(0, -1), left]), Color(0.8, 0.96, 1.0))
	draw_colored_polygon(PackedVector2Array([top, right, Vector2(0, -1)]), Color(0.55, 0.88, 1.0))
	draw_colored_polygon(PackedVector2Array([left, Vector2(0, -1), bottom]), Color(0.42, 0.78, 0.98))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -1), right, bottom]), Color(0.26, 0.6, 0.9))
	draw_circle(Vector2(0, -1), 3.2, Color(1, 1, 1, 0.55 * inner)) # the inner light
	draw_line(top, bottom, Color(1, 1, 1, 0.55), 1.0, true)
	draw_line(top + Vector2(-1, 2), top + Vector2(-3.5, 8), Color(1, 1, 1, 0.9), 1.2, true)


func _ice_spike() -> void:
	var inner := 0.6 + 0.4 * sin(_t * 8.0)
	draw_circle(Vector2(4, 0), 13.0, Color(0.6, 0.92, 1.0, 0.18))
	var tip := Vector2(23, 0)
	var pts := PackedVector2Array([tip, Vector2(-8, -6), Vector2(-13, -3.5), Vector2(-15, 0), Vector2(-13, 3.5), Vector2(-8, 6)])
	_outlined(pts, Color(0.55, 0.88, 1.0))
	# facets: the upper face lit, the lower one shaded, a ridge between
	draw_colored_polygon(PackedVector2Array([tip, Vector2(-8, -6), Vector2(-13, -3.5), Vector2(-15, 0)]), Color(0.78, 0.95, 1.0))
	draw_colored_polygon(PackedVector2Array([tip, Vector2(-15, 0), Vector2(-13, 3.5), Vector2(-8, 6)]), Color(0.36, 0.7, 0.95))
	draw_line(Vector2(-15, 0), tip, Color(1, 1, 1, 0.8), 1.1, true)
	draw_line(Vector2(-6, -1.2), Vector2(14, -0.4), Color(1, 1, 1, 0.45 * inner), 3.0, true) # the inner light
	for x in [-7.0, 1.0, 9.0]:
		draw_line(Vector2(x, -4.8 + x * 0.12), Vector2(x + 3.0, -1.0), Color(0.25, 0.55, 0.85, 0.6), 0.9, true)


# ── Minion projectiles (a player shell's size) ───────────────────────────────

func _drone_bolt() -> void:
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.3, 0.2, 0.25))
	draw_colored_polygon(_ellipse(Vector2(-2, 0), 13.0, 4.5), Color(1.0, 0.35, 0.25, 0.9))
	draw_colored_polygon(_ellipse(Vector2(1, 0), 8.0, 2.2), Color(1.0, 0.92, 0.7))


func _crab_spit() -> void:
	_outlined(_ellipse(Vector2.ZERO, 8.0, 7.0), Color(1.0, 0.55, 0.15))
	draw_circle(Vector2(-2.5, -2.5), 2.2, Color(1.0, 0.9, 0.6, 0.85))


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
