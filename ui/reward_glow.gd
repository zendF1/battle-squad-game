extends Control
## The light behind a reward tile (RewardModel.glow(): colour, accent, power 0..1), drawn in code
## round the control's centre and spilling past its edges: a soft radial glow pulsing gently,
## rays turning slowly behind it (more, longer and brighter with the power, the accent colour
## between them), a bright core and twinkling four-point sparkles (more with the power). land()
## plays a one-shot flash and an expanding ring (a tile landing in the reveal). Ignores the mouse.

## {color, accent, power} (RewardModel.glow()).
var glow := {"color": Color(0.72, 0.84, 1.0), "accent": Color(0.9, 0.95, 1.0), "power": 0.3}:
	set(v):
		glow = v
		queue_redraw()
## 0..1: the whole light fades in with it (the reveal tweens it).
var intro := 1.0:
	set(v):
		intro = v
		queue_redraw()
## 0..1: the landing flash and ring (land()).
var flash := 0.0:
	set(v):
		flash = v
		queue_redraw()
## How far the rays reach, in the control's half-size.
var reach := 1.25
## false: no animation (still pictures in tests).
var animate := true

var _t := 0.0
var _seed := 0.0

static var _radial: GradientTexture2D


static func make(g: Dictionary, px: Vector2) -> Control:
	var c = load("res://ui/reward_glow.gd").new()
	c.glow = g
	c.size = px
	c.custom_minimum_size = px
	return c


## A white radial gradient (centre opaque, edge clear), shared.
static func radial() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_radial = GradientTexture2D.new()
		_radial.gradient = g
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = 128
		_radial.height = 128
	return _radial


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_seed = randf() * TAU


func _ready() -> void:
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if animate and is_visible_in_tree():
		_t += delta
		queue_redraw()


## The landing: a flash and a ring that runs out and fades (0.5 s).
func land() -> void:
	flash = 1.0
	var tw := create_tween()
	tw.tween_property(self, "flash", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if intro <= 0.0:
		return
	var c := size / 2.0
	var half := minf(size.x, size.y) / 2.0
	var p := clampf(float(glow.get("power", 0.3)), 0.0, 1.0)
	var col: Color = glow.get("color", Color.WHITE)
	var acc: Color = glow.get("accent", col)
	var pulse := 1.0 + 0.07 * sin(_t * 2.4 + _seed)
	var a := intro
	# The rays, turning; alternate colour and accent, longer with the power.
	var n := 6 + int(round(p * 8.0))
	var ray_len := half * reach * (0.85 + 0.45 * p) * pulse
	var spin := _t * (0.35 + 0.25 * p) + _seed
	for i in n:
		var ang := spin + TAU * i / n
		var w := PI / n * (0.42 + 0.18 * p)
		var tint := col if i % 2 == 0 else acc
		var r := ray_len * (1.0 if i % 2 == 0 else 0.78)
		var pts := PackedVector2Array([c, c + Vector2.from_angle(ang - w) * r, c + Vector2.from_angle(ang + w) * r])
		var cols := PackedColorArray([Color(tint, (0.28 + 0.4 * p) * a), Color(tint, 0.0), Color(tint, 0.0)])
		draw_polygon(pts, cols)
	# The soft glow, then the bright core.
	var tex := radial()
	var g := half * (1.15 + 0.35 * p) * pulse
	draw_texture_rect(tex, Rect2(c - Vector2(g, g), Vector2(g, g) * 2.0), false, Color(col, (0.45 + 0.4 * p) * a))
	var k := half * (0.55 + 0.2 * p) * (2.0 - pulse)
	draw_texture_rect(tex, Rect2(c - Vector2(k, k), Vector2(k, k) * 2.0), false, Color(acc.lerp(Color.WHITE, 0.4), (0.35 + 0.35 * p) * a))
	# The sparkles: twinkling on a ring round the icon.
	var sparks := 1 + int(round(p * 4.0))
	for i in sparks:
		var ph := _t * (1.6 + 0.3 * i) + _seed * (i + 1)
		var tw := maxf(0.0, sin(ph))
		if tw <= 0.02:
			continue
		var ang := _seed * 3.0 + TAU * i / sparks + 0.4 * sin(_t * 0.3 + i)
		var at := c + Vector2.from_angle(ang) * half * (0.72 + 0.12 * sin(ph * 0.5))
		star(self, at, half * (0.1 + 0.07 * p) * tw, Color(acc.lerp(Color.WHITE, 0.6), a * tw))
	# The landing flash and its ring.
	if flash > 0.0:
		var rr := half * (0.6 + 1.1 * (1.0 - flash))
		draw_arc(c, rr, 0.0, TAU, 48, Color(acc.lerp(Color.WHITE, 0.5), flash * 0.9), 3.0 + 6.0 * flash, true)
		draw_texture_rect(tex, Rect2(c - Vector2(half, half) * 1.3, Vector2(half, half) * 2.6), false, Color(1, 1, 1, flash * 0.55))


## A four-point sparkle of radius `r` at `at` (shared with the reveal's particles).
static func star(ci: CanvasItem, at: Vector2, r: float, color: Color) -> void:
	if r <= 0.3:
		return
	var thin := r * 0.22
	var pts := PackedVector2Array([at + Vector2(0, -r), at + Vector2(thin, -thin), at + Vector2(r, 0), at + Vector2(thin, thin),
		at + Vector2(0, r), at + Vector2(-thin, thin), at + Vector2(-r, 0), at + Vector2(-thin, -thin)])
	ci.draw_colored_polygon(pts, color)
