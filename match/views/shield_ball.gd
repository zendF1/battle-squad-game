extends Node2D
## A shield bubble: a round ball of light round a body, shaded like an energy sphere (faint in the
## middle, brighter toward the rim inside it, fading smoothly to nothing just past the edge: a soft
## radial falloff, no outline), a soft highlight spot, a glint gliding round the rim and a faint
## hex pattern fading out with the rest; it breathes (its size swells and shrinks a few percent,
## PULSE_SEC a cycle). draw_ball() paints one on any CanvasItem (the boss's shield, BossBody); as a
## node it is a player's shield (PlayerView: Flora's bloom overflow turned into shield): show()
## pops it in (from POP_FROM with an overshoot, fading in), hide() pops it out (swelling as it
## fades). Its tint is the caster's gun tier (tier_colour()). Visual only.

const EquipmentPainter := preload("res://tools/art/equipment_painter.gd")

const PULSE_SEC := 1.8 # one breath
const PULSE_AMP := 0.05 # ± of the radius
const POP_IN_SEC := 0.4
const POP_FROM := 0.6 # the scale it pops in from
const FADE_IN_SEC := 0.22
const POP_OUT_SEC := 0.3
const POP_OUT_TO := 1.25
const FALLOFF := 1.2 # the glow reaches this × the radius (fading to 0 there)
const TEX_SIZE := 128
## The tint of a shield without a known gun tier (a basic gun, a reconnect without the caster).
const DEFAULT_TINT := Color(0.55, 0.9, 1.0)

var radius := 34.0
var tint := DEFAULT_TINT
var _t := 0.0
var _on := false
var _anim := 0.0 # s into the pop in / out
var _popping_out := false

static var _ball_tex: Texture2D
static var _spot_tex: Texture2D


## The bubble's tint for a gun tier: the tier's main colour of the equipment palettes
## (EquipmentPainter.TIERS: dragon red, mithril teal, gold yellow...), lightened a little to glow;
## DEFAULT_TINT for the basic gun or an unknown tier.
static func tier_colour(tier: String) -> Color:
	var t = EquipmentPainter.TIERS.get(tier)
	if not t is Array:
		return DEFAULT_TINT
	return (t[0] as Color).lerp(t[1], 0.35)


## The breathing scale at time t (s): 1 ± PULSE_AMP on a slow sine.
static func pulse(t: float) -> float:
	return 1.0 + PULSE_AMP * sin(TAU * t / PULSE_SEC)


## Paints a bubble of `radius` px round `centre` on ci at time t (the breath, the glint, the hexes'
## shimmer), alpha 0..1, in tint; scale on top of the breath (a pop).
static func draw_ball(ci: CanvasItem, centre: Vector2, radius_px: float, t: float, alpha: float, tint_col: Color,
		scale: float = 1.0) -> void:
	if alpha <= 0.0 or radius_px <= 0.0:
		return
	var r := radius_px * pulse(t) * scale
	ci.draw_set_transform(centre, 0.0, Vector2.ONE)
	var reach := r * FALLOFF
	ci.draw_texture_rect(_ball(), Rect2(-reach, -reach, reach * 2.0, reach * 2.0), false, Color(tint_col.lightened(0.15), alpha))
	# the hexes, faint, fading out toward the rim like the glow
	var hex := r / 4.2
	for ring_i in 4:
		var ring := float(ring_i)
		var n := 1 if ring_i == 0 else ring_i * 6
		for i in n:
			var a: float = TAU * i / n + ring * 0.3
			var c: Vector2 = Vector2(cos(a), sin(a)) * ring * hex * 1.5
			var d := c.length() / r
			if d > 0.86:
				continue
			var shine := (0.18 + 0.22 * (0.5 + 0.5 * sin(t * 3.0 + c.x * 0.05 + c.y * 0.03))) * (1.0 - d * d)
			var pts := PackedVector2Array()
			for k in 7:
				var b := TAU * k / 6.0 + PI / 6.0
				pts.append(c + Vector2(cos(b), sin(b)) * hex * 0.82)
			ci.draw_polyline(pts, Color(tint_col.lightened(0.4), shine * alpha), maxf(1.0, r / 40.0), true)
	# the highlight spot, up and to the left, and a glint gliding round the rim
	var spot := r * 0.55
	var at := Vector2(-0.36, -0.42) * r
	ci.draw_texture_rect(_spot(), Rect2(at - Vector2(spot, spot) / 2.0, Vector2(spot, spot)), false, Color(1, 1, 1, 0.7 * alpha))
	ci.draw_texture_rect(_spot(), Rect2(at - Vector2(spot, spot) / 6.0, Vector2(spot, spot) / 3.0), false, Color(1, 1, 1, 0.5 * alpha))
	var g := fmod(t * 0.9, TAU)
	var glint := Vector2(cos(g), sin(g)) * r * 0.9
	var gs := r * 0.32
	ci.draw_texture_rect(_spot(), Rect2(glint - Vector2(gs, gs) / 2.0, Vector2(gs, gs)), false, Color(1, 1, 1, 0.3 * alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The ball's radial glow: faint inside, bright just inside the rim, nothing past FALLOFF.
static func _ball() -> Texture2D:
	if _ball_tex == null:
		var g := Gradient.new()
		var stops := [[0.0, 0.12], [0.45, 0.15], [0.68, 0.3], [0.79, 0.72], [0.833, 0.6], [0.9, 0.2], [1.0, 0.0]]
		g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
		g.colors = PackedColorArray(stops.map(func(s): return Color(1, 1, 1, s[1])))
		_ball_tex = _radial(g)
	return _ball_tex


## A soft white spot (the highlight, the glint).
static func _spot() -> Texture2D:
	if _spot_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_spot_tex = _radial(g)
	return _spot_tex


static func _radial(g: Gradient) -> Texture2D:
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = TEX_SIZE
	tex.height = TEX_SIZE
	return tex


# ── As a player's shield ────────────────────────────────────────────────────

func _ready() -> void:
	_t = randf() * PULSE_SEC


## Shows the bubble; animate: it pops in (else it is there at once, a snapshot's shield).
func show_ball(animate: bool = true) -> void:
	if _on and not _popping_out:
		return
	_on = true
	_popping_out = false
	_anim = 0.0 if animate else POP_IN_SEC
	queue_redraw()


## Takes it away; animate: it pops out (else gone at once).
func hide_ball(animate: bool = true) -> void:
	if not _on or _popping_out:
		return
	if animate:
		_popping_out = true
		_anim = 0.0
	else:
		_on = false
	queue_redraw()


## Shown (or popping out).
func is_on() -> bool:
	return _on


func popping_out() -> bool:
	return _popping_out


## (scale, alpha) of the pop now: the pop-in's overshoot from POP_FROM and its fade, the
## pop-out's swell and fade, else (1, 1).
func pop_state() -> Vector2:
	if _popping_out:
		var k := clampf(_anim / POP_OUT_SEC, 0.0, 1.0)
		return Vector2(lerpf(1.0, POP_OUT_TO, k), 1.0 - k * k)
	if _anim < POP_IN_SEC:
		var k := clampf(_anim / POP_IN_SEC, 0.0, 1.0)
		var s := 1.70158 # back-out: overshoots then settles on 1
		var back := 1.0 + (s + 1.0) * pow(k - 1.0, 3.0) + s * pow(k - 1.0, 2.0)
		return Vector2(lerpf(POP_FROM, 1.0, back), clampf(_anim / FADE_IN_SEC, 0.0, 1.0))
	return Vector2.ONE


func _process(delta: float) -> void:
	if not _on:
		return
	_t += delta
	_anim += delta
	if _popping_out and _anim >= POP_OUT_SEC:
		_on = false
		_popping_out = false
	queue_redraw()


func _draw() -> void:
	if not _on:
		return
	var p := pop_state()
	draw_ball(self, Vector2.ZERO, radius, _t, p.y, tint, p.x)
