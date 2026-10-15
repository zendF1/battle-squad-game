extends Control
## The match background behind the terrain (placeholder art, drawn in code): a day-sky gradient,
## a sun glow, two bands of soft distant hills and puffy clouds drifting slowly with the wind.
## Its rect is the map; it also paints a margin past the right and left edges, so a viewport
## wider than the map (stretch "expand") shows sky there, not the clear colour.

const SKY_TOP := Color(0.36, 0.62, 0.93)
const SKY_LOW := Color(0.78, 0.9, 0.98)
const HILLS_FAR := Color(0.6, 0.76, 0.86)
const HILLS_NEAR := Color(0.5, 0.7, 0.68)
const MARGIN := 600.0
const CLOUDS := 8

## Wind of the current turn: the clouds drift its way, faster with more power.
var wind_dir := 0
var wind_power := 0.0

var _clouds: Array = [] # [position, scale, speed factor]
var _drift := 0.0

static var _glow: GradientTexture2D


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 # the same sky every match
	for i in CLOUDS:
		_clouds.append([Vector2(rng.randf(), rng.randf_range(0.14, 0.4)), rng.randf_range(0.7, 1.4), rng.randf_range(0.6, 1.2)])
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_drift += delta * (6.0 + 10.0 * wind_power) * signf(wind_dir if wind_dir != 0 else 1)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var x0 := -MARGIN
	var x1 := w + MARGIN
	var pts := PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(x0, h)])
	draw_polygon(pts, PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	# Sun glow, upper right.
	var sun := Vector2(w * 0.8, h * 0.16)
	draw_texture_rect(_glow_texture(), Rect2(sun - Vector2(220, 220), Vector2(440, 440)), false, Color(1, 0.96, 0.75, 0.55))
	draw_circle(sun, 46.0, Color(1, 0.97, 0.82, 0.95))
	# Distant hills: two soft bands (slow sines), the nearer one darker.
	_hills(x0, x1, h * 0.5, h * 0.07, 0.0021, 1.3, HILLS_FAR)
	_hills(x0, x1, h * 0.6, h * 0.06, 0.0034, 4.1, HILLS_NEAR)
	# Clouds wrap around the painted width.
	var span := x1 - x0
	for c in _clouds:
		var p: Vector2 = c[0]
		var x := fposmod(p.x * span + _drift * float(c[2]), span) + x0
		_cloud(Vector2(x, p.y * h), float(c[1]))


func _hills(x0: float, x1: float, base: float, amp: float, freq: float, phase: float, color: Color) -> void:
	var poly := PackedVector2Array()
	var steps := 64
	for i in steps + 1:
		var x := lerpf(x0, x1, float(i) / steps)
		poly.append(Vector2(x, base - amp * (sin(x * freq + phase) * 0.7 + sin(x * freq * 2.7 + phase * 2.0) * 0.3)))
	poly.append(Vector2(x1, size.y))
	poly.append(Vector2(x0, size.y))
	draw_colored_polygon(poly, color)


func _cloud(at: Vector2, s: float) -> void:
	var shade := Color(0.86, 0.91, 0.98, 0.9)
	var white := Color(1, 1, 1, 0.95)
	for b in [[Vector2(-38, 6), 24.0], [Vector2(38, 6), 22.0], [Vector2(0, 8), 26.0]]:
		draw_circle(at + b[0] * s + Vector2(0, 4 * s), b[1] * s, shade)
	for b in [[Vector2(-34, 0), 22.0], [Vector2(-8, -14), 30.0], [Vector2(24, -6), 24.0], [Vector2(44, 4), 16.0], [Vector2(0, 4), 24.0]]:
		draw_circle(at + b[0] * s, b[1] * s, white)


static func _glow_texture() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	return _glow
