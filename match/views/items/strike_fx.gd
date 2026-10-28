extends Node2D
## Where a nuke's / laser's signal landed (the strike event), on the fx layer at that point, from
## the event until the hit (`duration` s, the server's) and a moment after:
## - the flare burning on the ground (a flickering red light, sparks rising);
## - the target: a dashed red ring of the strike's `radius` (flattened on the ground) turning, a
##   crosshair, both pulsing faster as the hit nears;
## - nuke: a red guide line from the sky down onto the point, blinking faster;
## - laser: `beams` beams from the sky (beam_angles(): spread over the upper half, the outer ones
##   low), swinging in and converging on the point while they charge (thin and dim to thick and
##   bright), a glow growing on the point; hit(): they fire (thick white-hot cores in a magenta
##   glow) and fade.
## hit() is the explode; release() fades it out (the replay ended). It frees itself.

const NUKE := "nuke"
const LASER := "laser"
const RED := Color(1.0, 0.18, 0.2)
const MAGENTA := Color(1.0, 0.25, 0.75)
const BEAM_LEN := 1600.0
const SWING := 0.5 # rad a beam starts off its line
const FIRE_SEC := 0.45 # the beams' fire after the hit
const AFTER_SEC := 0.6 # the marker's fade after the hit
const FADE_SEC := 0.3

var kind := NUKE
var radius := 40.0
var beams := 5
var duration := 0.8

var _t := 0.0
var _hit_t := -1.0 # replay-local time of the hit, -1 before
var _fade := -1.0 # time release() started
var _sparks: Array = [] # [offset, age, velocity]


func _ready() -> void:
	z_index = 2


func hit() -> void:
	if _hit_t < 0.0:
		_hit_t = _t


func release() -> void:
	if _fade < 0.0:
		_fade = _t


## The beams' directions (rad, Godot's y down: the sky is negative), n of them spread evenly from
## low left to low right over the top.
static func beam_angles(n: int) -> Array:
	var out: Array = []
	n = maxi(n, 1)
	for i in n:
		var k := 0.5 if n == 1 else float(i) / (n - 1)
		out.append(deg_to_rad(lerpf(-155.0, -25.0, k)))
	return out


## How far the charge is (0 at the strike event .. 1 at the hit).
func charge() -> float:
	return clampf(_t / maxf(duration, 0.01), 0.0, 1.0)


func state() -> Dictionary:
	return {"kind": kind, "charge": charge(), "hit": _hit_t >= 0.0, "beams": beam_angles(beams).size() if kind == LASER else 0,
		"radius": radius}


func _process(delta: float) -> void:
	_t += delta
	if _hit_t < 0.0 and randf() < delta * 30.0:
		_sparks.append([Vector2(randf_range(-4, 4), -4), 0.0, Vector2(randf_range(-40, 40), randf_range(-140, -60))])
	for s in _sparks:
		s[1] += delta
		s[0] += s[2] * delta
		s[2].y += 200.0 * delta
	_sparks = _sparks.filter(func(s): return s[1] < 0.6)
	var end_at := INF
	if _hit_t >= 0.0:
		end_at = _hit_t + maxf(FIRE_SEC, AFTER_SEC)
	if _fade >= 0.0:
		end_at = minf(end_at, _fade + FADE_SEC)
	if _t >= end_at:
		queue_free()
		return
	queue_redraw()


func _alpha() -> float:
	var a := 1.0
	if _fade >= 0.0:
		a = minf(a, 1.0 - (_t - _fade) / FADE_SEC)
	if _hit_t >= 0.0:
		a = minf(a, 1.0 - (_t - _hit_t) / AFTER_SEC)
	return clampf(a, 0.0, 1.0)


func _draw() -> void:
	var a := _alpha()
	var k := charge()
	var col := MAGENTA if kind == LASER else RED
	var pulse := 0.5 + 0.5 * sin(_t * lerpf(8.0, 30.0, k))
	if a > 0.0:
		if kind == NUKE:
			draw_line(Vector2(0, -BEAM_LEN), Vector2.ZERO, Color(col, (0.25 + 0.4 * pulse) * a), 3.0, true)
			draw_line(Vector2(0, -BEAM_LEN), Vector2.ZERO, Color(1, 0.8, 0.8, 0.5 * pulse * a), 1.0, true)
		# the danger area and its ring
		_ellipse_fill(radius, Color(col, (0.08 + 0.12 * pulse * k) * a))
		_dashed_ellipse(radius, _t * 1.2, Color(col, (0.65 + 0.35 * pulse) * a), 3.0)
		_dashed_ellipse(radius * 0.55, -_t * 1.8, Color(col, 0.5 * a), 2.0)
		for d in [Vector2.LEFT, Vector2.RIGHT]:
			draw_line(d * radius * 0.25, d * radius * 0.75, Color(col, 0.8 * a), 2.0, true)
		for d in [Vector2.UP, Vector2.DOWN]:
			draw_line(d * radius * 0.1, d * radius * 0.3, Color(col, 0.8 * a), 2.0, true)
		# the flare on the ground
		if _hit_t < 0.0:
			draw_circle(Vector2(0, -3), 12.0 + 6.0 * pulse, Color(RED, 0.3 * a), true, -1.0, true)
			draw_circle(Vector2(0, -3), 4.0, Color(1, 0.9, 0.7, a), true, -1.0, true)
			for s in _sparks:
				draw_circle(s[0], 1.8, Color(1.0, 0.7, 0.3, (1.0 - s[1] / 0.6) * a), true, -1.0, true)
	if kind == LASER:
		_draw_beams(k)


func _draw_beams(k: float) -> void:
	var fired := _hit_t >= 0.0
	var f := clampf((_t - _hit_t) / FIRE_SEC, 0.0, 1.0) if fired else 0.0
	if fired and f >= 1.0:
		return
	var fade := 1.0
	if _fade >= 0.0:
		fade = clampf(1.0 - (_t - _fade) / FADE_SEC, 0.0, 1.0)
	for base in beam_angles(beams):
		var ang: float = base + (0.0 if fired else SWING * (1.0 - k) * (1.0 - k) * (1.0 if base < -PI / 2 else -1.0))
		var from := Vector2.from_angle(ang) * BEAM_LEN
		if fired:
			var w := lerpf(18.0, 2.0, f)
			draw_line(from, Vector2.ZERO, Color(MAGENTA, 0.55 * (1.0 - f) * fade), w * 2.2, true)
			draw_line(from, Vector2.ZERO, Color(1, 0.9, 0.97, (1.0 - f) * fade), w * 0.6, true)
		else:
			draw_line(from, Vector2.ZERO, Color(MAGENTA, lerpf(0.2, 0.75, k) * fade), lerpf(1.5, 6.0, k), true)
			if k > 0.5:
				draw_line(from, Vector2.ZERO, Color(1, 0.9, 0.97, (k - 0.5) * 1.6 * fade), lerpf(0.5, 2.0, k), true)
	var glow := lerpf(8.0, radius * 0.8, k) if not fired else radius * (1.2 - 0.6 * f)
	draw_circle(Vector2.ZERO, glow, Color(MAGENTA, (0.35 if not fired else 0.6 * (1.0 - f)) * fade), true, -1.0, true)
	draw_circle(Vector2.ZERO, glow * 0.45, Color(1, 0.92, 0.98, (0.6 * k if not fired else 1.0 - f) * fade), true, -1.0, true)


func _ellipse_pts(r: float, n: int = 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(cos(t) * r, sin(t) * r * 0.38))
	return pts


func _ellipse_fill(r: float, c: Color) -> void:
	draw_colored_polygon(_ellipse_pts(r), c)


func _dashed_ellipse(r: float, turn: float, c: Color, w: float) -> void:
	var dashes := 16
	for i in dashes:
		var t0 := turn + TAU * i / dashes
		var t1 := t0 + TAU / dashes * 0.55
		var pts := PackedVector2Array()
		for s in 5:
			var t := lerpf(t0, t1, s / 4.0)
			pts.append(Vector2(cos(t) * r, sin(t) * r * 0.38))
		draw_polyline(pts, c, w, true)
