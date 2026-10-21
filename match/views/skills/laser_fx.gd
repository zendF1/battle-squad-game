extends Node2D
## Tia laze's replay drawing (laser.gd adds one per laser shot to the fx layer, layer = world
## coordinates). From the server timeline only (the beam event: from, to, t, duration; the laser
## damage events), in the shooter's gun colours (palette(): the shock rifle's tier shells, the
## crafted tiers and the Blaster from ShotLook):
## - charge (0 .. beam t): a hot energy orb grows at the muzzle in the beam's colours (body,
##   core, a white-hot centre; the tier's shell only faint inside it) in a pulsing glow, sparks and
##   a ring closing in on it; it stays over the beam's start while the beam lasts;
## - beam (beam t .. + duration): its front sweeps from the muzzle at SWEEP_SPEED (the server's
##   laserSweepSpeed, so the front reaches each enemy when its damage event comes) to the map
##   edge: a wide soft glow, the beam body and a hot core, flickering, with two crackling bolts
##   along it; it goes THROUGH the terrain (nothing is carved), a molten spot spitting sparks
##   where it enters and leaves the ground; it thins out over the last FADE s;
## - each enemy hit (hit()): a flash on the beam, sparks flying off and electric arcs around the
##   body for HIT_LIFE s (the damage number and the stun icon are match_screen's).
## Cheap: everything is computed from the time (no particle state); the crackle and the arcs are
## segment lists made once in setup() and refilled in place (one draw_multiline_colors each, no
## per-frame allocation); at most MAX_HITS hits and CROSS_MAX spots.
## sync(t) drives it during the replay; after release() it runs on its own clock and frees itself.

const ShotLook := preload("res://match/views/shot_look.gd")
const Art := preload("res://ui/art.gd")

const SWEEP_SPEED := 12000.0 # px/s, the server's laserSweepSpeed
const CHARGE_DEFAULT := 0.3 # s before the beam (server laserChargeTime) when the event has no t
const BEAM_DEFAULT := 0.6 # s the beam shows when the event has no duration
const FADE := 0.22 # s: the beam thins out at the end
const HIT_LIFE := 0.7 # s an enemy hit crackles
const FLASH_SEC := 0.28
const GLOW_W := 46.0 # px: the soft glow's width (the beam body 16, the core 5)
const BODY_W := 16.0
const CORE_W := 5.0
const BOLTS := 2 # crackling bolts along the beam
const BOLT_POINTS := 40
const BOLT_AMP := 11.0 # px off the beam
const JITTER_HZ := 22.0 # the bolts and arcs reshape this often
const MAX_HITS := 6
const ARCS := 3 # arcs around a hit body
const ARC_POINTS := 7
const ARC_RADIUS := 24.0
const SPARKS := 9 # sparks flying off a hit
const CROSS_MAX := 6 # terrain entry / exit spots
const CROSS_STEP := 3.0 # px: the beam is sampled this often for them
const CHARGE_SPARKS := 10
## The charge orb (_draw_orb()): ORB_MIN px across at the start of the charge, ORB_MIN +
## ORB_GROW at the beam (both × ShotLook.SHELL_SCALE, like the shells); its halo, core glow,
## white glow (half sizes) and solid white-hot centre
## (radius) as shares of that; its body's alpha and the tier shell's inside it.
const ORB_MIN := 12.0
const ORB_GROW := 30.0
const ORB_HALO := 1.3
const ORB_BODY := 0.95
const ORB_CORE := 0.6
const ORB_WHITE := 0.36
const ORB_HOT := 0.14
const SHELL_ALPHA := 0.25

## gun tier -> beam colours for the shock rifle, matched to its tier shells
## (assets/fx/shock_rifle/projectile_<tier>.png): glow (the wide halo), mid (the beam body),
## core (the hot centre), arc (the crackle, the arcs and the sparks).
const PALETTES := {
	"basic": {"glow": Color(0.25, 0.85, 1.0), "mid": Color(0.62, 0.97, 1.0), "core": Color(1, 1, 1), "arc": Color(1.0, 0.95, 0.45)},
	"iron": {"glow": Color(0.12, 0.88, 1.0), "mid": Color(0.55, 1.0, 1.0), "core": Color(1, 1, 1), "arc": Color(1.0, 0.88, 0.2)},
	"steel": {"glow": Color(0.62, 0.22, 1.0), "mid": Color(0.85, 0.62, 1.0), "core": Color(1.0, 0.96, 1.0), "arc": Color(1, 1, 1)},
	"mithril": {"glow": Color(0.5, 0.9, 1.0), "mid": Color(0.88, 1.0, 1.0), "core": Color(1, 1, 1), "arc": Color(0.95, 0.78, 0.42)},
	"dragon": {"glow": Color(0.88, 0.12, 0.03), "mid": Color(1.0, 0.52, 0.1), "core": Color(1.0, 0.94, 0.62), "arc": Color(1.0, 0.8, 0.22)},
}

var from := Vector2.ZERO # the server's beam start (the shooter's body centre)
var to := Vector2.ZERO # where it leaves the map
var dir := Vector2.RIGHT
var beam_t := CHARGE_DEFAULT
var beam_duration := BEAM_DEFAULT
var muzzle := Vector2.ZERO # where it is drawn from (the gun's muzzle once known, else from)
var colors := {}
var prismatic := false
## Where the beam goes into / out of the ground: distance along it from `from` (px).
var crossings := PackedFloat32Array()

var _t := 0.0
var _released := false
var _shell: Texture2D
var _glow: Texture2D
var _band: Texture2D
## The crackle along the beam: BOLTS bolts of BOLT_POINTS - 1 segments (point pairs) and colours.
var _bolt_pts := PackedVector2Array()
var _bolt_cols := PackedColorArray()
## The arcs around the hit bodies: MAX_HITS × ARCS arcs of ARC_POINTS - 1 segments.
var _arc_pts := PackedVector2Array()
var _arc_cols := PackedColorArray()
## Hits: {at (on the beam), body (centre), t0, sparks: Array[Vector2] directions}
var _hits: Array = []
var _bucket := -1 # the jitter bucket the point arrays were last filled for

static var _band_cache: GradientTexture2D


## From the beam event, the shot style ({kind, tier}) and the terrain mask before the shot (null:
## no ground spots).
func setup(beam: Dictionary, style: Dictionary, terrain = null) -> void:
	from = _vec(beam.get("from"), Vector2.ZERO)
	to = _vec(beam.get("to"), from + Vector2.RIGHT)
	dir = (to - from).normalized() if to.distance_to(from) > 0.01 else Vector2.RIGHT
	muzzle = from
	beam_t = float(beam.get("t", CHARGE_DEFAULT))
	beam_duration = maxf(0.05, float(beam.get("duration", BEAM_DEFAULT)))
	var kind := ShotLook.known_kind(str(style.get("kind", "shock_rifle")))
	var tier := ShotLook.known_tier(str(style.get("tier", "")))
	colors = palette(kind, tier)
	prismatic = bool(ShotLook.TIERS[tier]["prismatic"])
	_shell = Art.tier_projectile(kind, tier)
	if _shell == null:
		_shell = Art.shot(kind, "projectile", Art.fx("muzzle"))
	_glow = Art.tier_fx("glow")
	if _glow == null:
		_glow = Art.fx("muzzle")
	_band = band_texture()
	crossings = ground_crossings(from, to, terrain)
	_bolt_pts.resize(BOLTS * (BOLT_POINTS - 1) * 2)
	_bolt_cols.resize(BOLTS * (BOLT_POINTS - 1))
	_arc_pts.resize(MAX_HITS * ARCS * (ARC_POINTS - 1) * 2)
	_arc_cols.resize(MAX_HITS * ARCS * (ARC_POINTS - 1))
	_hits.clear()


## The beam colours of a gun kind × tier: the shock rifle's normal tiers from PALETTES, the rest
## (crafted tiers, the Blaster) from the shot accents.
static func palette(kind: String, tier: String) -> Dictionary:
	if kind == "shock_rifle" and PALETTES.has(tier):
		return PALETTES[tier]
	var a := ShotLook.accent(kind, tier)
	var a2 := ShotLook.accent2(kind, tier)
	return {"glow": a, "mid": a.lerp(Color.WHITE, 0.45), "core": Color(1, 1, 1), "arc": a2.lerp(Color.WHITE, 0.25)}


## Draw the beam from the gun's muzzle (layer coordinates) instead of the body centre.
func set_muzzle(p: Vector2) -> void:
	muzzle = p


## The replay time (s since the shot, the events' t).
func sync(t: float) -> void:
	_t = t
	queue_redraw()


## The replay is over: keep drawing on my own clock until the last hit stops crackling.
func release() -> void:
	_released = true


func is_released() -> bool:
	return _released


## When everything is drawn (s since the shot).
func done_at() -> float:
	var end := beam_t + beam_duration
	for h in _hits:
		end = maxf(end, float(h["t0"]) + HIT_LIFE)
	return end


## How far the beam's front is from the muzzle at time t (px; 0 before the beam).
func front_at(t: float) -> float:
	return clampf((t - beam_t) * SWEEP_SPEED, 0.0, length())


## The beam's drawn length: from the muzzle to the map edge along dir.
func length() -> float:
	return maxf(0.0, (to - muzzle).dot(dir))


## The point of the beam nearest to p.
func on_beam(p: Vector2) -> Vector2:
	return muzzle + dir * clampf((p - muzzle).dot(dir), 0.0, length())


## An enemy hit at time t0, its body centre at `body`. Returns where the flash is (on the beam).
func hit(body: Vector2, t0: float) -> Vector2:
	var at := on_beam(body)
	if _hits.size() >= MAX_HITS:
		return at
	var sparks: Array[Vector2] = []
	for s in SPARKS:
		var ang := TAU * s / SPARKS + _noise(s, _hits.size()) * 0.5
		sparks.append(Vector2.from_angle(ang) * (0.7 + 0.3 * absf(_noise(s, 7))))
	_hits.append({"at": at, "body": body, "t0": t0, "sparks": sparks})
	_bucket = -1
	return at


func hit_count() -> int:
	return _hits.size()


func _process(delta: float) -> void:
	if not _released:
		return
	_t += delta
	queue_redraw()
	if _t > done_at() + 0.05:
		queue_free()


## Along the beam from a to b (the server segment): where it goes into or out of the solid
## terrain, as distances from a; at most CROSS_MAX.
static func ground_crossings(a: Vector2, b: Vector2, terrain) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if terrain == null or not terrain.has_method("is_solid"):
		return out
	var d := b - a
	var n := int(d.length() / CROSS_STEP)
	if n <= 0:
		return out
	var was: bool = terrain.is_solid(a.x, a.y)
	for i in range(1, n + 1):
		var p := a + d * (float(i) / n)
		var now: bool = terrain.is_solid(p.x, p.y)
		if now != was:
			out.append(d.length() * float(i) / n)
			if out.size() >= CROSS_MAX:
				break
		was = now
	return out


## A soft band (transparent - white - transparent across), stretched along the beam.
static func band_texture() -> Texture2D:
	if _band_cache == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_band_cache = GradientTexture2D.new()
		_band_cache.gradient = g
		_band_cache.width = 4
		_band_cache.height = 64
		_band_cache.fill_from = Vector2(0.5, 0.0)
		_band_cache.fill_to = Vector2(0.5, 1.0)
	return _band_cache


## -1..1, the same for the same (i, j).
static func _noise(i: float, j: float) -> float:
	return fposmod(sin(i * 12.9898 + j * 78.233) * 43758.5453, 1.0) * 2.0 - 1.0


func _color(key: String, alpha: float, h: float = 0.0) -> Color:
	var c: Color = colors.get(key, Color.WHITE)
	if prismatic and key != "core":
		c = ShotLook.prism(_t * 1.2 + h).lerp(c, 0.35)
	return Color(c, clampf(alpha, 0.0, 1.0))


## The beam's flicker (width factor) at time t.
func _flicker(t: float) -> float:
	return 1.0 + 0.12 * sin(t * 71.0) + 0.07 * sin(t * 173.0)


## Point i of bolt b at jitter bucket `bucket`, the front `front` px out.
func _bolt_point(b: int, i: int, bucket: int, front: float) -> Vector2:
	var k := float(i) / (BOLT_POINTS - 1)
	var off := 0.0 if i == 0 or i == BOLT_POINTS - 1 else _noise(i + 31.0 * b, bucket) * BOLT_AMP
	return muzzle + dir * (front * k) + dir.orthogonal() * off


## Point i of arc a around body at jitter bucket `bucket`.
static func _arc_point(body: Vector2, a: int, i: int, bucket: int) -> Vector2:
	var a0 := TAU * _noise(a + 3.0, bucket)
	var a1 := a0 + 1.4 + 1.2 * absf(_noise(a + 9.0, bucket))
	var r := ARC_RADIUS * (0.75 + 0.35 * absf(_noise(i + 5.0 * a, bucket + 0.5)))
	return body + Vector2.from_angle(lerpf(a0, a1, float(i) / (ARC_POINTS - 1))) * r


## Refills the crackle and arc segments in place (no allocation).
func _refill(bucket: int, front: float) -> void:
	_bucket = bucket
	var n := 0
	for b in BOLTS:
		var prev := _bolt_point(b, 0, bucket, front)
		for i in range(1, BOLT_POINTS):
			var p := _bolt_point(b, i, bucket, front)
			_bolt_pts[n] = prev
			_bolt_pts[n + 1] = p
			n += 2
			prev = p
	n = 0
	for hi in _hits.size():
		var body: Vector2 = _hits[hi]["body"]
		for a in ARCS:
			var prev := _arc_point(body, a + 7 * hi, 0, bucket)
			for i in range(1, ARC_POINTS):
				var p := _arc_point(body, a + 7 * hi, i, bucket)
				_arc_pts[n] = prev
				_arc_pts[n + 1] = p
				n += 2
				prev = p


func _draw() -> void:
	var t := _t
	if t < 0.0:
		return
	var beam_end_t := beam_t + beam_duration
	var local := t - beam_t
	var fade := clampf((beam_duration - local) / FADE, 0.0, 1.0) if local >= 0.0 else 1.0
	var bucket := int(floor(t * JITTER_HZ))
	var front := front_at(t)
	if bucket != _bucket:
		_refill(bucket, front)
	elif local >= 0.0 and front < length():
		_refill(bucket, front) # the front is still moving: the bolts follow it
	var fl := _flicker(t)
	# Charge: the halo grows at the muzzle, sparks and a ring close in (the orb itself is drawn
	# over the beam, _draw_orb()).
	if t < beam_end_t:
		var k := charge_k(t)
		var g := orb_size(t) * 2.4
		draw_texture_rect(_glow, Rect2(muzzle - Vector2(g, g), Vector2(g, g) * 2), false, _color("glow", 0.75 * k))
		if local < 0.0:
			for i in CHARGE_SPARKS:
				var ang := TAU * i / CHARGE_SPARKS + i * 1.7
				var f := fposmod(t * 2.8 + i * 0.37, 1.0)
				var r := 54.0 * (1.0 - f) + 8.0
				var u := Vector2.from_angle(ang)
				draw_line(muzzle + u * r, muzzle + u * (r + 9.0 + 6.0 * f), _color("arc", f * k, i * 0.1), 2.0, true)
			var ring := 46.0 * (1.0 - fposmod(t * 3.2, 1.0)) + 6.0
			draw_arc(muzzle, ring, 0.0, TAU, 32, _color("mid", 0.5 * k), 2.0, true)
	# The beam.
	if local >= 0.0 and t < beam_end_t and front > 0.0:
		var w := fl * (0.35 + 0.65 * fade)
		draw_set_transform(muzzle, dir.angle())
		var gw := GLOW_W * w
		draw_texture_rect(_band, Rect2(0, -gw / 2, front, gw), false, _color("glow", 0.6 * fade))
		var bw := BODY_W * w
		draw_texture_rect(_band, Rect2(0, -bw / 2, front, bw), false, _color("mid", 0.95 * fade, 0.3))
		draw_rect(Rect2(0, -CORE_W * w / 2, front, CORE_W * w), _color("core", fade))
		draw_set_transform(Vector2.ZERO)
		var per := BOLT_POINTS - 1
		for j in _bolt_cols.size():
			var b := floori(float(j) / per)
			_bolt_cols[j] = _color("arc", (0.95 - 0.35 * b) * fade, b * 0.5)
		draw_multiline_colors(_bolt_pts, _bolt_cols, 2.0, true)
		if front < length(): # the sweeping front
			var f := 26.0 * fl
			var tip := muzzle + dir * front
			draw_texture_rect(_glow, Rect2(tip - Vector2(f, f), Vector2(f, f) * 2), false, _color("core", 0.9))
		# Through the ground: a molten spot where the beam goes in and comes out, spitting sparks.
		var offset := (muzzle - from).dot(dir)
		for c in crossings.size():
			var s := crossings[c] - offset
			if s <= 0.0 or s > front:
				continue
			var p := muzzle + dir * s
			var gs := 20.0 * fl * (0.5 + 0.5 * fade)
			draw_texture_rect(_glow, Rect2(p - Vector2(gs, gs), Vector2(gs, gs) * 2), false, _color("mid", 0.85 * fade))
			for i in 4:
				var u := Vector2.from_angle(dir.angle() + PI * 0.5 * (1.0 if i % 2 == 0 else -1.0) + _noise(i + c * 4.0, bucket) * 0.9)
				var sl := 8.0 + 10.0 * absf(_noise(i + 2.0, bucket + c))
				draw_line(p + u * 6.0, p + u * (6.0 + sl), _color("arc", fade), 2.0, true)
	if t < beam_end_t:
		_draw_orb(t)
	# The hits: a flash, sparks flying off, arcs crackling around the body.
	var per_hit := ARCS * (ARC_POINTS - 1)
	var any := false
	for j in _arc_cols.size():
		var hi := floori(float(j) / per_hit)
		var a := 0.0
		if hi < _hits.size():
			var age := t - float(_hits[hi]["t0"])
			if age >= 0.0 and age <= HIT_LIFE:
				a = (1.0 - age / HIT_LIFE) * (0.6 + 0.4 * absf(_noise(age * 30.0 + floorf(float(j) / (ARC_POINTS - 1)), 1.0)))
				any = true
		_arc_cols[j] = _color("arc", a)
	if any:
		draw_multiline_colors(_arc_pts, _arc_cols, 2.0, true)
	for h in _hits:
		var age := t - float(h["t0"])
		if age < 0.0 or age > HIT_LIFE:
			continue
		var life := 1.0 - age / HIT_LIFE
		var at: Vector2 = h["at"]
		if age < FLASH_SEC:
			var fk := age / FLASH_SEC
			var r := 20.0 + 56.0 * (1.0 - (1.0 - fk) * (1.0 - fk))
			draw_texture_rect(_glow, Rect2(at - Vector2(r, r), Vector2(r, r) * 2), false, _color("glow", 0.9 * (1.0 - fk)))
			draw_texture_rect(_glow, Rect2(at - Vector2(r, r) * 0.5, Vector2(r, r)), false, _color("core", 1.0 - fk))
			draw_arc(at, r * 0.9, 0.0, TAU, 32, _color("arc", 0.8 * (1.0 - fk)), 3.0 * (1.0 - fk) + 1.0, true)
		for s in h["sparks"]:
			var v: Vector2 = s
			var d := 14.0 + 300.0 * age * (1.0 - 0.5 * age)
			var p0 := at + v * d + Vector2(0, 160.0 * age * age)
			draw_line(p0, p0 + v * (10.0 * life + 3.0), _color("arc", life), 2.0, true)


## How far the charge has come at time t (0..1, 1 from the beam on).
func charge_k(t: float) -> float:
	return clampf(t / beam_t, 0.0, 1.0) if beam_t > 0.0 else 1.0


## The charge orb's size at time t (px): it grows over the charge, flickers, and shrinks with the
## beam over its last FADE s.
func orb_size(t: float) -> float:
	var local := t - beam_t
	var fade := clampf((beam_duration - local) / FADE, 0.0, 1.0) if local >= 0.0 else 1.0
	var k := charge_k(t)
	return (ORB_MIN + ORB_GROW * k * k) * ShotLook.SHELL_SCALE * _flicker(t) * fade


## The charge orb's body colour: between the beam's glow and body colours.
func orb_body(alpha: float) -> Color:
	return _color("glow", alpha, 0.3).lerp(_color("mid", alpha, 0.3), 0.5)


## The charge orb at the muzzle, over the beam's start: a hot energy ball in the beam's colours
## (a soft halo, orb_body() with a bright rim in the core colour, a core glow, a white-hot centre)
## with the tier's shell only faint in it (SHELL_ALPHA, turning), so no tier reads as a dark ball.
func _draw_orb(t: float) -> void:
	var orb := orb_size(t)
	if orb <= 0.0:
		return
	var k := charge_k(t)
	var r := orb * 0.5
	var halo := orb * ORB_HALO
	draw_texture_rect(_glow, Rect2(muzzle - Vector2(halo, halo), Vector2(halo, halo) * 2), false, _color("glow", 0.8 * k))
	draw_circle(muzzle, r, orb_body(ORB_BODY * k))
	draw_set_transform(muzzle, t * 7.0)
	draw_texture_rect(_shell, Rect2(-Vector2(orb, orb) / 2, Vector2(orb, orb)), false, Color(1, 1, 1, SHELL_ALPHA * k))
	draw_set_transform(Vector2.ZERO)
	draw_arc(muzzle, r, 0.0, TAU, 32, _color("core", 0.9 * k), 2.0, true)
	var c := orb * ORB_CORE
	draw_texture_rect(_glow, Rect2(muzzle - Vector2(c, c), Vector2(c, c) * 2), false, _color("core", k))
	var w := orb * ORB_WHITE
	draw_texture_rect(_glow, Rect2(muzzle - Vector2(w, w), Vector2(w, w) * 2), false, Color(1, 1, 1, k))
	draw_circle(muzzle, orb * ORB_HOT, Color(1, 1, 1, k))


static func _vec(v, fallback: Vector2) -> Vector2:
	if v is Dictionary and v.has("x") and v.has("y"):
		return Vector2(float(v["x"]), float(v["y"]))
	return fallback
