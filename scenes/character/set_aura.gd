extends Node2D
## The 6-piece set aura: a character wearing all six pieces of one tier index stands in a ring of
## light in that set's colour (ui/gear_glyphs.gd SET_COLORS: 1 silver, 2 steel blue, 3 mithril
## cyan, 4 dragon red), drawn in code: a glowing ellipse on the ground round the feet, a soft
## column of light rising from it and motes drifting up through it. The node's origin is the
## feet; `width` is the ring's width and `height` the figure's height (the column's), both in
## this node's px. `index` 0 hides it (and stops processing). Behind the figure: the owner adds
## it before the body (lobby stage, Nhân vật, the leaderboard showcase: ui/character_view.gd;
## the match: match/views/player_view.gd).

const GearGlyphs := preload("res://ui/gear_glyphs.gd")

const MOTES := 14
const MOTE_SEC := 2.4 # one mote's rise
const PULSE_SEC := 2.2

var index := 0:
	set(v):
		index = v
		visible = v > 0
		set_process(v > 0)
		queue_redraw()
var width := 120.0:
	set(v):
		width = v
		queue_redraw()
var height := 160.0:
	set(v):
		height = v
		queue_redraw()

var _t := 0.0


func _init() -> void:
	visible = false
	set_process(false)


## The colour drawn (white when hidden).
func color() -> Color:
	return GearGlyphs.set_color(index)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if index <= 0:
		return
	var c := color()
	var pulse := 0.85 + 0.15 * sin(_t * TAU / PULSE_SEC)
	var rx := width * 0.5
	var ry := maxf(width * 0.13, 4.0)
	# the column of light: brightest at the ring, fading out upward (and a brighter core)
	for layer in [[1.0, 0.34], [0.62, 0.3], [0.3, 0.26]]:
		var w: float = rx * layer[0]
		var a: float = layer[1] * pulse
		draw_polygon(PackedVector2Array([Vector2(-w, 0), Vector2(w, 0), Vector2(w * 0.6, -height), Vector2(-w * 0.6, -height)]),
			PackedColorArray([Color(c, a), Color(c, a), Color(c, 0.0), Color(c, 0.0)]))
	# the ground ring: a soft glow, then the bright rim
	_ellipse(Vector2.ZERO, rx * 1.25, ry * 1.6, Color(c, 0.22 * pulse))
	_ellipse(Vector2.ZERO, rx, ry, Color(c, 0.38 * pulse))
	_ellipse_line(Vector2.ZERO, rx, ry, Color(c.lightened(0.45), pulse), maxf(3.0, width * 0.05))
	_ellipse_line(Vector2.ZERO, rx * 0.7, ry * 0.7, Color(c.lightened(0.6), 0.6 * pulse), maxf(1.5, width * 0.018))
	# a ripple running out of the ring, fading
	var q := fposmod(_t / PULSE_SEC, 1.0)
	_ellipse_line(Vector2.ZERO, rx * (1.0 + 0.45 * q), ry * (1.0 + 0.45 * q), Color(c.lightened(0.3), 0.7 * (1.0 - q)), maxf(2.0, width * 0.03))
	# motes rising through the column
	for i in MOTES:
		var phase := fposmod(_t / MOTE_SEC + float(i) / MOTES, 1.0)
		var x := sin(float(i) * 2.39996) * rx * 0.8
		var y := -phase * height
		var a := sin(phase * PI)
		draw_circle(Vector2(x + sin(_t * 2.0 + i) * rx * 0.06, y), maxf(2.0, width * 0.028), Color(c.lightened(0.5), a))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(c + Vector2(cos(TAU * i / 32.0) * rx, sin(TAU * i / 32.0) * ry))
	draw_colored_polygon(pts, col)


func _ellipse_line(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(c + Vector2(cos(TAU * i / 32.0) * rx, sin(TAU * i / 32.0) * ry))
	draw_polyline(pts, col, w, true)
