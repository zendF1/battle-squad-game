extends Node2D
## The chain's extras on the fx layer (bomb_chain.gd, Tanko's Địa chấn liên hoàn): every boulder's
## impact quakes the ground (quake()): cracks run out along the surface from both sides of the pit,
## stone spikes erupt round its rim and sink back, rocks and dust fly; for every explosion down the shaft a
## geyser out of the hole (dirt chunks and the gun tier's embers thrown up past its mouth, falling
## back; a column of dust rising up the shaft; dust rolling out over the rim), and a smoke puff at
## the muzzle as each later bomb leaves. One fixed pool of particles (MAX), reused: no per-frame
## allocations. finish() (the replay ended) frees it once the last particle is gone.
## Visual only.

const Art := preload("res://ui/art.gd")
const ShotLook := preload("res://match/views/shot_look.gd")

const MAX := 220 # particles in the pool
const GRAVITY := 1500.0 # px/s² for the chunks and embers: a quick geyser
const DUST_RISE := 0.35 # dust slows down by this share of its speed per second
## Particle kinds.
const CHUNK := 0
const EMBER := 1
const DUST := 2
const DIRT := [Color(0.42, 0.29, 0.17), Color(0.33, 0.22, 0.13), Color(0.55, 0.4, 0.24), Color(0.3, 0.33, 0.16)]

## ShotLook.style_for() of the shot: the embers take its tier's colour.
var style := {}

# The pool: one entry per particle, [kind, position, velocity, age, life, size, spin, color];
# a particle with age >= life is free.
var _pool: Array = []
var _next := 0 # where the search for a free slot starts
var _alive := 0
var _finishing := false
var _smoke: Texture2D
var _debris: Texture2D
var _glow: Texture2D
var _accent := Color(1.0, 0.6, 0.2)
var _rng := RandomNumberGenerator.new()
# The quakes' cracks [{pts: PackedVector2Array (along the surface), age, life}] and stone spikes
# [{base: Vector2 (on the surface), h, w, lean, age, delay, life}].
var _cracks: Array = []
var _spikes: Array = []


func _init() -> void:
	for i in MAX:
		_pool.append([CHUNK, Vector2.ZERO, Vector2.ZERO, 1.0, 0.0, 1.0, 0.0, Color.WHITE])


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	z_index = 3 # over the explosions and the players (bomb_chain.gd PLAYERS_Z)
	_smoke = Art.fx("smoke")
	_debris = Art.fx("debris")
	_glow = Art.tier_fx("glow")
	if _glow == null:
		_glow = Art.fx("muzzle")
	_accent = ShotLook.accent(ShotLook.known_kind(str(style.get("kind", ""))), ShotLook.known_tier(str(style.get("tier", ""))))
	_rng.randomize()


## How many particles are alive (tests).
func alive() -> int:
	return _alive


## An explosion at `at` deep in the hole whose mouth is at y `mouth_y`: dirt and embers thrown up
## out of it, dust rising up the shaft and rolling out over the rim. `radius` is its crater.
func geyser(at: Vector2, mouth_y: float, radius: float) -> void:
	var depth := maxf(0.0, at.y - mouth_y)
	var half := clampf(radius * 0.35, 10.0, 40.0) # the column stays inside the shaft
	for i in 22:
		var rise := depth + _rng.randf_range(50.0, 170.0) # how far above the explosion it flies
		var v := Vector2(_rng.randf_range(-70.0, 70.0), -sqrt(2.0 * GRAVITY * rise))
		_spawn(CHUNK, at + Vector2(_rng.randf_range(-half, half), _rng.randf_range(-10.0, 4.0)), v,
			minf(2.0 * -v.y / GRAVITY, 1.5), _rng.randf_range(3.0, 7.5), DIRT[i % DIRT.size()])
	for i in 10:
		var rise := depth + _rng.randf_range(90.0, 220.0)
		var v := Vector2(_rng.randf_range(-110.0, 110.0), -sqrt(2.0 * GRAVITY * rise))
		_spawn(EMBER, at + Vector2(_rng.randf_range(-half, half) * 0.6, 0.0), v, _rng.randf_range(0.7, 1.1),
			_rng.randf_range(2.5, 4.5), _accent if i % 2 == 0 else _accent.lightened(0.35))
	var puffs := clampi(int(depth / 28.0) + 3, 3, 12)
	for i in puffs: # a dust column up the shaft, the deeper ones later
		var k := float(i) / puffs
		var p := Vector2(at.x + _rng.randf_range(-half, half) * 0.5, at.y - depth * k)
		_spawn(DUST, p, Vector2(_rng.randf_range(-12.0, 12.0), -_rng.randf_range(160.0, 260.0)),
			_rng.randf_range(0.8, 1.2), _rng.randf_range(18.0, 28.0) + half * 0.4, Color(0.62, 0.52, 0.4, 0.75))
	for s in [-1.0, 1.0]: # dust rolling out over the rim
		for i in 3:
			var p := Vector2(at.x + s * _rng.randf_range(radius * 0.4, radius * 0.9), mouth_y - _rng.randf_range(0.0, 12.0))
			_spawn(DUST, p, Vector2(s * _rng.randf_range(70.0, 150.0), -_rng.randf_range(10.0, 40.0)),
				_rng.randf_range(0.8, 1.1), _rng.randf_range(16.0, 26.0), Color(0.66, 0.56, 0.44, 0.7))


const STONE := Color(0.6, 0.55, 0.48)
const STONE_LIT := Color(0.8, 0.75, 0.66)
const STONE_DARK := Color(0.38, 0.33, 0.28)
const STONE_INK := Color(0.12, 0.08, 0.05)
const ROCKS := [Color(0.52, 0.48, 0.42), Color(0.4, 0.36, 0.32), Color(0.62, 0.56, 0.48), Color(0.45, 0.31, 0.18)]
## A spike's rise, hold and sink (s): it erupts, stands, sinks back into the ground.
const SPIKE_RISE := 0.14
const SPIKE_HOLD := 0.38
const SPIKE_SINK := 0.42
const CRACK_LIFE := 1.5
const CRACK_GROW := 0.22
const QUAKE_ROCKS := 16
const QUAKE_DUST := 3 # each side
## Particles one quake throws (rocks and dust).
const QUAKE_PARTICLES := QUAKE_ROCKS + 2 * QUAKE_DUST


## A boulder's impact at `at` (its crater `crater` px, already carved; `surface(x)` the ground's top
## at x): cracks run out along the surface from both sides of the pit, stone spikes erupt round its
## rim (the first impact's the biggest) and sink back, rocks and dust fly out of it.
func quake(at: Vector2, crater: float, surface: Callable, index: int) -> void:
	var big := 1.0 if index == 0 else 0.8
	var rim := crater * 1.35 + 6.0
	for side in [-1.0, 1.0]:
		for j in 3:
			var x: float = at.x + side * (rim + j * maxf(crater * 0.5, 9.0) + _rng.randf_range(-3.0, 3.0))
			var y: float = surface.call(x)
			_spikes.append({"base": Vector2(x, y + 3.0), "h": _rng.randf_range(30.0, 46.0) * big * (1.0 - j * 0.18),
				"w": _rng.randf_range(10.0, 14.0) * big, "lean": side * _rng.randf_range(0.12, 0.38), "age": 0.0,
				"delay": j * 0.04 + _rng.randf_range(0.0, 0.03), "life": SPIKE_RISE + SPIKE_HOLD + SPIKE_SINK})
		for n in 2: # cracks outward along the ground
			var x0: float = at.x + side * (crater * 0.9 + 2.0)
			var pts := PackedVector2Array()
			var x := x0
			var reach := _rng.randf_range(60.0, 110.0) * big
			var step := reach / 7.0
			for k in 8:
				var y: float = surface.call(x)
				pts.append(Vector2(x, y + 2.0 + _rng.randf_range(0.0, 5.0) + n * 3.0))
				x += side * step * _rng.randf_range(0.7, 1.3)
			_cracks.append({"pts": pts, "age": 0.0, "life": CRACK_LIFE, "width": _rng.randf_range(2.0, 3.2) * big})
	for i in QUAKE_ROCKS: # rocks out of the pit
		var v := Vector2(_rng.randf_range(-260.0, 260.0), -_rng.randf_range(260.0, 620.0))
		_spawn(CHUNK, at + Vector2(_rng.randf_range(-crater, crater) * 0.5, -4.0), v, _rng.randf_range(0.7, 1.1),
			_rng.randf_range(3.5, 7.0) * big, ROCKS[i % ROCKS.size()])
	for side in [-1.0, 1.0]: # dust rolling over the ground
		for i in QUAKE_DUST:
			var x: float = at.x + side * _rng.randf_range(crater * 0.6, crater * 1.6)
			_spawn(DUST, Vector2(x, float(surface.call(x)) - _rng.randf_range(2.0, 12.0)), Vector2(side * _rng.randf_range(60.0, 140.0),
				-_rng.randf_range(15.0, 45.0)), _rng.randf_range(0.8, 1.2), _rng.randf_range(16.0, 26.0), Color(0.66, 0.56, 0.44, 0.72))


## The spikes and cracks shown now (tests).
func spikes() -> int:
	return _spikes.size()


func cracks() -> int:
	return _cracks.size()


## A spike's height share at its age: 0 before its delay, erupting with a small overshoot, standing,
## sinking back; 0 once it is gone.
static func spike_k(age: float, delay: float) -> float:
	var t := age - delay
	if t <= 0.0:
		return 0.0
	if t < SPIKE_RISE:
		var u := t / SPIKE_RISE
		return 1.0 + 2.7 * pow(u - 1.0, 3.0) + 1.7 * pow(u - 1.0, 2.0)
	t -= SPIKE_RISE
	if t < SPIKE_HOLD:
		return 1.0
	t -= SPIKE_HOLD
	return clampf(1.0 - t / SPIKE_SINK, 0.0, 1.0)


## Smoke at the muzzle as a later bomb leaves.
func puff(at: Vector2) -> void:
	for i in 4:
		_spawn(DUST, at + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-6.0, 6.0)),
			Vector2(_rng.randf_range(-40.0, 40.0), -_rng.randf_range(30.0, 70.0)), _rng.randf_range(0.5, 0.75),
			_rng.randf_range(10.0, 16.0), Color(0.78, 0.76, 0.74, 0.8))
	_spawn(EMBER, at, Vector2.ZERO, 0.12, 16.0, Color(1.0, 0.85, 0.5)) # the flash


## The replay is over: free this once the last particle is gone.
func finish() -> void:
	_finishing = true
	if _alive == 0 and _spikes.is_empty() and _cracks.is_empty():
		queue_free()


func _spawn(kind: int, at: Vector2, v: Vector2, life: float, size: float, color: Color) -> void:
	for n in MAX:
		var i := (_next + n) % MAX
		var q: Array = _pool[i]
		if q[3] < q[4]:
			continue
		q[0] = kind
		q[1] = at
		q[2] = v
		q[3] = 0.0
		q[4] = life
		q[5] = size
		q[6] = _rng.randf_range(-8.0, 8.0)
		q[7] = color
		_next = (i + 1) % MAX
		_alive += 1
		return
	# the pool is full: drop it


func _process(delta: float) -> void:
	for sp in _spikes:
		sp["age"] += delta
	_spikes = _spikes.filter(func(sp): return sp["age"] < sp["delay"] + sp["life"])
	for c in _cracks:
		c["age"] += delta
	_cracks = _cracks.filter(func(c): return c["age"] < c["life"])
	if _alive == 0:
		if _finishing and _spikes.is_empty() and _cracks.is_empty():
			queue_free()
		elif not _spikes.is_empty() or not _cracks.is_empty():
			queue_redraw()
		return
	for q in _pool:
		if q[3] >= q[4]:
			continue
		q[3] += delta
		if q[3] >= q[4]:
			_alive -= 1
			continue
		var v: Vector2 = q[2]
		if q[0] == DUST:
			v *= 1.0 - DUST_RISE * delta * 3.0
		else:
			v.y += GRAVITY * delta
		q[2] = v
		q[1] += v * delta
	queue_redraw()


func _draw() -> void:
	for c in _cracks:
		_draw_crack(c)
	for sp in _spikes:
		_draw_spike(sp)
	for q in _pool:
		if q[3] >= q[4]:
			continue
		var f: float = q[3] / q[4]
		var at: Vector2 = q[1]
		var col: Color = q[7]
		var size: float = q[5]
		match int(q[0]):
			DUST:
				if _smoke == null:
					continue
				var r := size * (0.7 + 1.1 * f)
				draw_texture_rect(_smoke, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col, col.a * (1.0 - f) * minf(1.0, f * 6.0)))
			EMBER:
				var r := size * (1.0 - 0.5 * f)
				if _glow != null:
					draw_texture_rect(_glow, Rect2(at - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false, Color(col, 0.55 * (1.0 - f)))
				draw_circle(at, r * 0.5, Color(col.lightened(0.4), 1.0 - f))
			_:
				var a := 1.0 - maxf(0.0, f - 0.75) / 0.25
				if _debris != null:
					draw_set_transform(at, q[6] * q[3], Vector2.ONE)
					draw_texture_rect(_debris, Rect2(-Vector2(size, size), Vector2(size, size) * 2.0), false, Color(col, a))
					draw_set_transform(Vector2.ZERO)
				else:
					draw_circle(at, size * 0.6, Color(col, a))


## A crack: a dark jagged line spreading out from the pit, then fading.
func _draw_crack(c: Dictionary) -> void:
	var age: float = c["age"]
	var grow := clampf(age / CRACK_GROW, 0.0, 1.0)
	var a := 1.0 - clampf((age - c["life"] * 0.55) / (c["life"] * 0.45), 0.0, 1.0)
	var pts: PackedVector2Array = c["pts"]
	var n := maxi(2, int(ceil(pts.size() * grow)))
	var shown := pts.slice(0, n)
	var w: float = c["width"]
	draw_polyline(shown, Color(STONE_INK, 0.85 * a), w, true)
	if shown.size() >= 3:
		var mid := shown[shown.size() / 2]
		draw_line(mid, mid + Vector2(0, 7.0), Color(STONE_INK, 0.7 * a), w * 0.6, true)


## A stone spike erupting from the ground at its base: a leaning faceted prism, lit on its left,
## shaded on its right, an ink outline, a little dirt heaped round its foot.
func _draw_spike(sp: Dictionary) -> void:
	var k := spike_k(sp["age"], sp["delay"])
	if k <= 0.0:
		return
	var base: Vector2 = sp["base"]
	var h: float = sp["h"] * k
	var w: float = sp["w"]
	var tip := base + Vector2(sp["lean"] * h, -h)
	var left := base + Vector2(-w, 0)
	var right := base + Vector2(w, 0)
	var mid := base + Vector2(w * 0.15, 0)
	draw_colored_polygon(PackedVector2Array([left, tip, mid]), STONE_LIT)
	draw_colored_polygon(PackedVector2Array([mid, tip, right]), STONE_DARK)
	draw_colored_polygon(PackedVector2Array([left.lerp(tip, 0.25), tip, mid.lerp(tip, 0.3)]), STONE)
	draw_polyline(PackedVector2Array([left, tip, right]), STONE_INK, 2.0, true)
	draw_line(mid, tip, Color(STONE_INK, 0.6), 1.2, true)
	# dirt heaped at the foot
	draw_set_transform(base + Vector2(0, 1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, w * 1.25, Color(0.4, 0.28, 0.16, 0.95))
	draw_set_transform(Vector2.ZERO)
