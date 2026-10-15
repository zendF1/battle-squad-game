extends Control
## The lobby background, drawn in code: a night-sky gradient (deep blue → purple → teal), soft
## glow circles, small stars and, with `ground`, a lighter ground band with an oval stage at the
## bottom centre. It scales with its rect (any aspect). The Home pages use it without the floor.

const SKY_TOP := Color(0.06, 0.08, 0.2)
const SKY_MID := Color(0.17, 0.13, 0.34)
const SKY_LOW := Color(0.1, 0.3, 0.42)
const GROUND := Color(0.14, 0.22, 0.36)
const STARS := 46
const GLOWS := [
	[Vector2(0.16, 0.3), 0.35, Color(0.45, 0.35, 0.95, 0.22)],
	[Vector2(0.84, 0.18), 0.3, Color(0.3, 0.75, 1.0, 0.16)],
	[Vector2(0.5, 0.5), 0.45, Color(0.6, 0.45, 1.0, 0.2)],
	[Vector2(0.94, 0.72), 0.25, Color(1.0, 0.6, 0.85, 0.12)],
]

static var _glow: GradientTexture2D

@export var ground := true:
	set(value):
		ground = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	_band(0.0, h * 0.55, SKY_TOP, SKY_MID)
	_band(h * 0.55, h, SKY_MID, SKY_LOW)
	for g in GLOWS:
		var at: Vector2 = g[0] * size
		var r: float = g[1] * h
		draw_texture_rect(_glow_texture(), Rect2(at - Vector2(r, r), Vector2(r, r) * 2), false, g[2])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 # the same sky every frame
	for i in STARS:
		var p := Vector2(rng.randf() * w, rng.randf() * h * 0.62)
		var r := rng.randf_range(1.0, 2.6)
		draw_circle(p, r * 2.4, Color(1, 1, 1, 0.06))
		draw_circle(p, r, Color(1, 1, 1, rng.randf_range(0.35, 0.85)))
	if not ground:
		return
	# Ground: a wide soft hill, lighter towards the stage.
	var top := h * 0.7
	var hill := PackedVector2Array()
	var steps := 32
	for i in steps + 1:
		var x := w * i / steps
		var t := (float(i) / steps - 0.5) * 2.0
		hill.append(Vector2(x, top + t * t * h * 0.06))
	hill.append(Vector2(w, h))
	hill.append(Vector2(0, h))
	draw_colored_polygon(hill, GROUND)
	_oval(Vector2(w / 2, h * 0.86), Vector2(w * 0.32, h * 0.1), Color(0.35, 0.5, 0.75, 0.18))
	_oval(Vector2(w / 2, h * 0.86), Vector2(w * 0.2, h * 0.065), Color(0.45, 0.62, 0.9, 0.16))


## A soft white disc fading out to the edge, tinted per glow.
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


## A vertical gradient from `a` (at y0) to `b` (at y1) across the full width.
func _band(y0: float, y1: float, a: Color, b: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0, y1)])
	draw_polygon(pts, PackedColorArray([a, a, b, b]))


func _oval(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radii.y / radii.x))
	draw_circle(Vector2.ZERO, radii.x, color)
	draw_set_transform(Vector2.ZERO)
