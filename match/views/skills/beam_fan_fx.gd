extends Node2D
## Many boss beams at once (boss mode v3: Phù Thuỷ Băng's radial burst of 20 ice beams, Rô-bốt
## Thép's 5 parallel sweeping lasers), drawn by one node on the fx layer (layer = world
## coordinates), from the server timeline only (the beam events: from, to, t, duration; the hits'
## damage events and the stun / freeze status events):
## - charge (0 .. beam t): an orb grows at each beam start (one for a radial burst, at its centre)
##   in a pulsing glow; a radial burst also shows faint guide rays along the beams to come and a
##   ring closing in; parallel beams a thin line along each;
## - beams (beam t .. + duration): every front sweeps out from its start at sweep_speed (the laser
##   effect's sweepSpeed, as the server times the hits) to the map edge: a soft glow, the body and
##   a hot core, flickering; frost motes stream along them; a radial burst flashes a big halo and
##   a shockwave ring round its centre as the beams leave; they thin out over the last FADE s;
## - each player hit (hit()): a flash on its beam, sparks flying off; stunned / frozen (stun()):
##   stars (stun) or frost shards (freeze) circling over the head for STUN_SEC.
## Cheap at 20 beams: per beam three rects, one polyline crackle and a few motes, all computed from
## the time (no particle state, no per-frame allocation in the beam loop); one draw_multiline for
## every crackle. sync(t) drives it during the replay; after release() it runs on its own clock and
## frees itself.

const LaserFx := preload("res://match/views/skills/laser_fx.gd")
const BeamFan := preload("res://match/boss/beam_fan.gd")
const Art := preload("res://ui/art.gd")

const FADE := 0.25
const GLOW_W := 52.0
const BODY_W := 16.0
const CORE_W := 5.0
const MOTES := 5 # frost motes per beam
const MOTE_SPEED := 900.0 # px/s along the beam
const BOLT_POINTS := 14 # crackle points per beam
const BOLT_AMP := 7.0
const JITTER_HZ := 20.0
const HIT_LIFE := 0.6
const FLASH_SEC := 0.26
const SPARKS := 7
const STUN_SEC := 1.4
const STARS := 4
const HALO_R := 130.0 # px: a radial burst's halo round its centre
const ORB_R := 26.0
const RADIAL_GAP := 46.0 # px: a radial burst's beams are drawn from this far out (radial_gap's default)

var beams: Array = [] # BeamFan.beams()
var layout := {}
var colors := {}
var sweep_speed := 12000.0
var beam_t := 0.6
var beam_duration := 0.8
var centre := Vector2.ZERO # a radial burst's centre (the boss's body centre)
var radial_gap := RADIAL_GAP # px from a radial burst's centre to where its beams are drawn: the boss stays in sight
var muzzle: Variant = null # the shooter's muzzle (layer coordinates): a charge there too (parallel beams)

var _t := 0.0
var _released := false
var _glow: Texture2D
var _band: Texture2D
var _origins: Array = []
var _hits: Array = [] # {at, beam, t0, sparks: Array[Vector2]}
var _stuns: Array = [] # {view: Node2D, lift: float, t0, kind}
var _bolt_pts := PackedVector2Array()
var _bolt_cols := PackedColorArray()
var _bucket := -1


## From the beams (BeamFan.beams()), their colours (LaserFx.palette()) and the front's speed.
func setup(list: Array, palette: Dictionary, speed: float) -> void:
	beams = list
	layout = BeamFan.layout(list)
	colors = palette
	sweep_speed = speed if speed > 0.0 else 12000.0
	beam_t = 0.0
	beam_duration = 0.05
	if not list.is_empty():
		beam_t = float(list[0]["t"])
		for b in list:
			beam_t = minf(beam_t, float(b["t"]))
			beam_duration = maxf(beam_duration, float(b["duration"]))
	centre = layout.get("origin", Vector2.ZERO)
	_origins = BeamFan.origins(list)
	_glow = Art.tier_fx("glow")
	if _glow == null:
		_glow = Art.fx("muzzle")
	_band = LaserFx.band_texture()
	_bolt_pts.resize(list.size() * (BOLT_POINTS - 1) * 2)
	_bolt_cols.resize(list.size() * (BOLT_POINTS - 1))


func is_radial() -> bool:
	return str(layout.get("kind", "")) == BeamFan.RADIAL


func sync(t: float) -> void:
	_t = t
	queue_redraw()


func release() -> void:
	_released = true


func done_at() -> float:
	var end := beam_t + beam_duration
	for h in _hits:
		end = maxf(end, float(h["t0"]) + HIT_LIFE)
	for s in _stuns:
		end = maxf(end, float(s["t0"]) + STUN_SEC)
	return end


func _process(delta: float) -> void:
	if not _released:
		return
	_t += delta
	queue_redraw()
	if _t > done_at() + 0.05:
		queue_free()


## How far beam i's front is from its start at time t (px).
func front_at(i: int, t: float) -> float:
	var b: Dictionary = beams[i]
	return clampf((t - float(b["t"])) * sweep_speed, 0.0, float(b["length"]))


## A player hit at t0, its body centre at body: the flash on the nearest beam. Returns where.
func hit(body: Vector2, t0: float) -> Vector2:
	var i := BeamFan.nearest_beam(beams, body)
	var at: Vector2 = BeamFan.on_beam(beams[i], body) if i >= 0 else body
	var sparks: Array[Vector2] = []
	for s in SPARKS:
		sparks.append(Vector2.from_angle(TAU * s / SPARKS + _noise(s, _hits.size()) * 0.5) * (0.7 + 0.3 * absf(_noise(s, 5))))
	_hits.append({"at": at, "beam": i, "t0": t0, "sparks": sparks})
	return at


## A hit player is stunned / frozen (kind "stun" / "freeze"): stars or frost circling over its head
## (the view followed, lift px above its feet).
func stun(view: Node2D, lift: float, t0: float, kind: String) -> void:
	for s in _stuns:
		if s["view"] == view:
			return
	_stuns.append({"view": view, "lift": lift, "t0": t0, "kind": kind})


func hit_count() -> int:
	return _hits.size()


func stun_count() -> int:
	return _stuns.size()


static func _noise(i: float, j: float) -> float:
	return fposmod(sin(i * 12.9898 + j * 78.233) * 43758.5453, 1.0) * 2.0 - 1.0


func _color(key: String, alpha: float) -> Color:
	var c: Color = colors.get(key, Color.WHITE)
	return Color(c, clampf(alpha, 0.0, 1.0))


func _flicker(t: float, i: int) -> float:
	return 1.0 + 0.12 * sin(t * 67.0 + i * 1.7) + 0.06 * sin(t * 161.0 + i)


## Refills the crackles along every beam (no allocation).
func _refill(bucket: int, t: float) -> void:
	_bucket = bucket
	var n := 0
	for i in beams.size():
		var b: Dictionary = beams[i]
		var front := front_at(i, t)
		var dir: Vector2 = b["dir"]
		var ortho := dir.orthogonal()
		var gap := minf(radial_gap, front) if is_radial() else 0.0
		var prev: Vector2 = b["from"] + dir * gap
		for k in range(1, BOLT_POINTS):
			var u := float(k) / (BOLT_POINTS - 1)
			var off := 0.0 if k == BOLT_POINTS - 1 else _noise(k + 13.0 * i, bucket) * BOLT_AMP
			var p: Vector2 = b["from"] + dir * (gap + (front - gap) * u) + ortho * off
			_bolt_pts[n] = prev
			_bolt_pts[n + 1] = p
			n += 2
			prev = p


func _draw() -> void:
	var t := _t
	if t < 0.0 or beams.is_empty():
		return
	var local := t - beam_t
	var beam_end := beam_t + beam_duration
	var fade := clampf((beam_duration - local) / FADE, 0.0, 1.0) if local >= 0.0 else 1.0
	var charge := clampf(t / beam_t, 0.0, 1.0) if beam_t > 0.0 else 1.0
	if t < beam_end:
		_draw_charge(t, local, charge, fade)
	if local >= 0.0 and t < beam_end:
		_draw_beams(t, local, fade)
	_draw_hits(t)


## The charge at each start (and a radial burst's guide rays and closing ring), then the halo.
func _draw_charge(t: float, local: float, charge: float, fade: float) -> void:
	var pulse := 0.85 + 0.15 * sin(t * 18.0)
	var starts: Array = _origins.duplicate()
	if muzzle is Vector2 and not is_radial():
		starts.append(muzzle)
	for o in starts:
		var r := ORB_R * (0.4 + 0.6 * charge * charge) * pulse * (fade if local >= 0.0 else 1.0)
		var g := r * 3.2
		draw_texture_rect(_glow, Rect2(o - Vector2(g, g), Vector2(g, g) * 2), false, _color("glow", 0.6 * charge))
		draw_circle(o, r * 0.55, _color("mid", 0.85 * charge))
		draw_circle(o, r * 0.3, Color(1, 1, 1, charge))
	if local < 0.0:
		for i in beams.size():
			var b: Dictionary = beams[i]
			var reach := float(b["length"]) * charge * (0.35 if is_radial() else 1.0)
			draw_line(b["from"], b["from"] + b["dir"] * reach, _color("mid", 0.22 * charge), 2.0, true)
		if is_radial():
			var ring := 150.0 * (1.0 - fposmod(t * 2.6, 1.0)) + 20.0
			draw_arc(centre, ring, 0.0, TAU, 48, _color("mid", 0.55 * charge), 3.0, true)
	elif is_radial():
		# the burst: a big halo round her and a shockwave ring as the beams leave
		var k := clampf(local / 0.35, 0.0, 1.0)
		var h := HALO_R * (0.8 + 0.25 * sin(t * 9.0)) * (0.6 + 0.4 * fade)
		draw_texture_rect(_glow, Rect2(centre - Vector2(h, h), Vector2(h, h) * 2), false, _color("glow", 0.35 * fade))
		if k < 1.0:
			draw_arc(centre, 40.0 + 420.0 * k, 0.0, TAU, 64, _color("core", 0.8 * (1.0 - k)), 6.0 * (1.0 - k) + 1.0, true)


## Every beam's glow, body and core; the crackles in one call; the frost motes.
func _draw_beams(t: float, _local: float, fade: float) -> void:
	var bucket := int(floor(t * JITTER_HZ))
	_refill(bucket, t)
	for i in beams.size():
		var b: Dictionary = beams[i]
		var front := front_at(i, t)
		if front <= 0.0:
			continue
		var w := _flicker(t, i) * (0.35 + 0.65 * fade)
		var gap := minf(radial_gap, front) if is_radial() else 0.0
		draw_set_transform(b["from"], b["dir"].angle())
		var gw := GLOW_W * w
		draw_texture_rect(_band, Rect2(gap, -gw / 2, front - gap, gw), false, _color("glow", 0.55 * fade))
		var bw := BODY_W * w
		draw_texture_rect(_band, Rect2(gap, -bw / 2, front - gap, bw), false, _color("mid", 0.95 * fade))
		draw_rect(Rect2(gap, -CORE_W * w / 2, front - gap, CORE_W * w), _color("core", fade))
		draw_set_transform(Vector2.ZERO)
		if front < float(b["length"]):
			var f := 20.0
			var tip: Vector2 = b["from"] + b["dir"] * front
			draw_texture_rect(_glow, Rect2(tip - Vector2(f, f), Vector2(f, f) * 2), false, _color("core", 0.9))
		# frost motes streaming out along it
		for m in MOTES:
			var s := fposmod(t * MOTE_SPEED + m * 397.0 + i * 131.0, maxf(front, 1.0))
			var p: Vector2 = b["from"] + b["dir"] * s + b["dir"].orthogonal() * (_noise(m, i) * 14.0)
			var mr := 2.5 + 1.5 * absf(_noise(m + 3.0, i))
			draw_circle(p, mr, _color("arc", 0.85 * fade))
	for j in _bolt_cols.size():
		_bolt_cols[j] = _color("arc", 0.7 * fade)
	draw_multiline_colors(_bolt_pts, _bolt_cols, 1.6, true)


## The hits' flashes and sparks; the stunned players' stars / frost over the head.
func _draw_hits(t: float) -> void:
	for h in _hits:
		var age := t - float(h["t0"])
		if age < 0.0 or age > HIT_LIFE:
			continue
		var life := 1.0 - age / HIT_LIFE
		var at: Vector2 = h["at"]
		if age < FLASH_SEC:
			var fk := age / FLASH_SEC
			var r := 18.0 + 50.0 * (1.0 - (1.0 - fk) * (1.0 - fk))
			draw_texture_rect(_glow, Rect2(at - Vector2(r, r), Vector2(r, r) * 2), false, _color("glow", 0.9 * (1.0 - fk)))
			draw_arc(at, r * 0.9, 0.0, TAU, 32, _color("arc", 0.8 * (1.0 - fk)), 3.0 * (1.0 - fk) + 1.0, true)
		for s in h["sparks"]:
			var v: Vector2 = s
			var d := 12.0 + 260.0 * age * (1.0 - 0.5 * age)
			var p0 := at + v * d + Vector2(0, 150.0 * age * age)
			draw_line(p0, p0 + v * (9.0 * life + 3.0), _color("arc", life), 2.0, true)
	for s in _stuns:
		var age := t - float(s["t0"])
		var view = s["view"]
		if age < 0.0 or age > STUN_SEC or not is_instance_valid(view):
			continue
		var a := clampf(age / 0.15, 0.0, 1.0) * clampf((STUN_SEC - age) / 0.3, 0.0, 1.0)
		var head: Vector2 = to_local(view.global_position) - Vector2(0, float(s["lift"]))
		var freeze := str(s["kind"]) == "freeze"
		for k in STARS:
			var ang := t * 5.0 + TAU * k / STARS
			var p := head + Vector2(cos(ang) * 30.0, sin(ang) * 9.0)
			if freeze:
				_shard(p, 9.0, ang, Color(0.8, 0.97, 1.0, a))
			else:
				_star(p, 9.5, ang, Color(1.0, 0.92, 0.35, a))


func _star(c: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(rot + TAU * i / 10.0 - PI / 2.0) * rr)
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.35, 0.2, 0.05, col.a), 1.4, true)


func _shard(c: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r).rotated(rot), c + Vector2(r * 0.45, 0).rotated(rot),
		c + Vector2(0, r).rotated(rot), c + Vector2(-r * 0.45, 0).rotated(rot)])
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.2, 0.45, 0.7, col.a), 1.2, true)
