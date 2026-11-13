extends Node2D
## A turret's beams one after another (round 2, Đĩa Bay Thép's Tia laze nghiền, beam pattern
## "each": one beam event per party member, the turret swinging onto each in turn). From the server
## timeline only (each beam: to = the member's body centre, t, duration); the start is the turret's
## turned tip now (`tip`, layer coordinates, set every frame by boss_beam.gd from the boss's
## muzzle_position()), so the beam leaves from the bright dot between the barrels and stops on the
## member, straight through the terrain (nothing carved):
## - charge (CHARGE_SEC before each beam): a hot dot swells at the tip;
## - the beam (t .. t + duration): a soft glow, the body and a white core, flickering, two crackling
##   bolts along it, in the boss's shot colours (LaserFx.palette()); it snaps on and thins out over
##   its last FADE s;
## - the impact on the member (from t, HIT_LIFE s): a white-hot flash, a star and a ring opening.
## sync(t, tip) drives it during the replay; after release() it runs on its own clock and frees
## itself. Cheap: computed from the time, no particle state.

const CHARGE_SEC := 0.22
const FADE := 0.08
const HIT_LIFE := 0.45
const GLOW_W := 34.0
const BODY_W := 12.0
const CORE_W := 4.0
const BOLT_POINTS := 14
const BOLT_AMP := 7.0
const JITTER_HZ := 24.0

var beams: Array = [] # [{to: Vector2, t, duration, target}]
var palette := {"glow": Color(1.0, 0.45, 0.2), "mid": Color(1.0, 0.75, 0.55), "core": Color(1, 1, 1), "arc": Color(1.0, 0.9, 0.6)}
var tip := Vector2.ZERO
var _t := 0.0
var _released := false


## The beams (BeamFan.beams(): {to, t, duration, …}; the events' targetId kept as target).
func setup(list: Array, colours: Dictionary = {}) -> void:
	beams = []
	for b in list:
		beams.append({"to": b.get("to", Vector2.ZERO), "t": float(b.get("t", 0.0)), "duration": maxf(float(b.get("duration", 0.0)), 0.05),
			"target": str(b.get("target", ""))})
	if not colours.is_empty():
		palette = colours
	if not list.is_empty() and list[0].get("from") is Vector2:
		tip = list[0]["from"] # the pivot until the turret's tip is known


## The replay time and the turret's tip now (layer coordinates).
func sync(t: float, tip_at: Vector2) -> void:
	_t = t
	tip = tip_at
	queue_redraw()


func release() -> void:
	_released = true


## When everything is drawn (s since the shot).
func done_at() -> float:
	var end := 0.0
	for b in beams:
		end = maxf(end, float(b["t"]) + maxf(float(b["duration"]), HIT_LIFE))
	return end


## The beam shown at t (its index), -1 none.
func beam_at(t: float) -> int:
	for i in beams.size():
		var b: Dictionary = beams[i]
		if t >= float(b["t"]) and t < float(b["t"]) + float(b["duration"]):
			return i
	return -1


## The beam's segment at t: [from (the tip), to] ([] none shown).
func segment_at(t: float) -> Array:
	var i := beam_at(t)
	return [] if i < 0 else [tip, beams[i]["to"]]


func _process(delta: float) -> void:
	if not _released:
		return
	_t += delta
	queue_redraw()
	if _t >= done_at() + 0.1:
		queue_free()


func _draw() -> void:
	var bucket := int(floor(_t * JITTER_HZ))
	for i in beams.size():
		var b: Dictionary = beams[i]
		var local := _t - float(b["t"])
		var dur := float(b["duration"])
		if local > -CHARGE_SEC and local < 0.0: # the tip heats up
			var k := 1.0 - (-local / CHARGE_SEC)
			_glow(tip, 8.0 + 16.0 * k, Color(palette["glow"], 0.5 * k))
			draw_circle(tip, 2.0 + 4.0 * k, Color(palette["core"], 0.6 + 0.4 * k))
		if local >= 0.0 and local < dur:
			var a := clampf((dur - local) / FADE, 0.0, 1.0)
			_beam(tip, b["to"], a, i, bucket)
		if local >= 0.0 and local < HIT_LIFE:
			_impact(b["to"], local / HIT_LIFE, i)


func _beam(from: Vector2, to: Vector2, a: float, i: int, bucket: int) -> void:
	var flick := 0.85 + 0.15 * sin(_t * 70.0 + i)
	var thin := 0.35 + 0.65 * a
	draw_line(from, to, Color(palette["glow"], 0.35 * a), GLOW_W * thin * flick, true)
	draw_line(from, to, Color(palette["mid"], 0.85 * a), BODY_W * thin * flick, true)
	draw_line(from, to, Color(palette["core"], a), CORE_W * thin, true)
	var d := to - from
	var n := Vector2(-d.y, d.x).normalized() if d.length() > 0.01 else Vector2.UP
	for bolt in 2:
		var pts := PackedVector2Array()
		for j in BOLT_POINTS + 1:
			var u := float(j) / BOLT_POINTS
			var off := 0.0 if j == 0 or j == BOLT_POINTS else (_noise(bucket + bolt * 31, j + i * 7) - 0.5) * 2.0 * BOLT_AMP
			pts.append(from + d * u + n * off)
		draw_polyline(pts, Color(palette["arc"], 0.8 * a), 1.6, true)
	# the bright dot at the tip
	_glow(from, 18.0 * flick, Color(palette["glow"], 0.7 * a))
	draw_circle(from, 6.0 * thin, Color(palette["core"], a))


func _impact(at: Vector2, k: float, i: int) -> void:
	var life := 1.0 - k
	_glow(at, 26.0 + 30.0 * k, Color(palette["glow"], 0.7 * life))
	draw_circle(at, 10.0 * life + 2.0, Color(palette["core"], life))
	draw_arc(at, 12.0 + 40.0 * k, 0.0, TAU, 32, Color(palette["mid"], 0.8 * life), 3.0 * life + 1.0, true)
	var r := 22.0 * (0.6 + 0.4 * life)
	for s in 4:
		var dir := Vector2.from_angle(PI * 0.25 + s * PI * 0.5 + i)
		draw_line(at - dir * r, at + dir * r, Color(palette["core"], 0.9 * life), 2.5, true)


func _glow(c: Vector2, r: float, col: Color) -> void:
	for j in 3:
		var f := 1.0 - j * 0.3
		draw_circle(c, r * f, Color(col, col.a * 0.35))


static func _noise(i: float, j: float) -> float:
	return fposmod(sin(i * 12.9898 + j * 78.233) * 43758.5453, 1.0)
