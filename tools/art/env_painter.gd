extends RefCounted
## Code-drawn backgrounds (bake source only): the lobby night sky, its ground band and stage
## pedestal, the match day sky with sun and hills, and three clouds. Each painter draws onto ci
## in a canvas of the given size; tools/bake_art.gd saves the result under assets/env/.

const Art := preload("res://ui/art.gd")

# Lobby (was ui/backdrop.gd)
const LOBBY_TOP := Color(0.06, 0.08, 0.2)
const LOBBY_MID := Color(0.17, 0.13, 0.34)
const LOBBY_LOW := Color(0.1, 0.3, 0.42)
const LOBBY_GROUND := Color(0.14, 0.22, 0.36)
const STARS := 46
const GLOWS := [
	[Vector2(0.16, 0.3), 0.35, Color(0.45, 0.35, 0.95, 0.22)],
	[Vector2(0.84, 0.18), 0.3, Color(0.3, 0.75, 1.0, 0.16)],
	[Vector2(0.5, 0.5), 0.45, Color(0.6, 0.45, 1.0, 0.2)],
	[Vector2(0.94, 0.72), 0.25, Color(1.0, 0.6, 0.85, 0.12)],
]
## The lobby screen the backgrounds are designed for; lobby_ground.png is its bottom
## GROUND_FROM..1 part.
const LOBBY_SCREEN := Vector2(1600, 900)
const GROUND_FROM := Art.LOBBY_GROUND_FROM
## Pedestal ovals, bottom to top: [radii, colour, y offset] (centre at PEDESTAL_CENTER).
const PEDESTAL := [
	[Vector2(196, 50), Color(0.06, 0.1, 0.24, 0.9), 10.0],
	[Vector2(186, 44), Color(0.28, 0.46, 0.8), 4.0],
	[Vector2(178, 38), Color(0.55, 0.75, 1.0), 0.0],
	[Vector2(150, 28), Color(0.78, 0.9, 1.0, 0.55), 0.0],
]
const PEDESTAL_SIZE := Vector2i(400, 112)
const PEDESTAL_CENTER := Art.PEDESTAL_CENTER

# Match (was match/views/sky_view.gd)
const SKY_TOP := Color(0.36, 0.62, 0.93)
const SKY_LOW := Color(0.78, 0.9, 0.98)
const HILLS_FAR := Color(0.6, 0.76, 0.86)
const HILLS_NEAR := Color(0.5, 0.7, 0.68)
## sky_match.png covers this world span (the 1600x900 map plus a 600 px margin each side).
const SKY_SPAN := Rect2(-Art.SKY_MARGIN, 0, 1600 + 2 * Art.SKY_MARGIN, 900)
const CLOUD_SCALE := 2.0 # cloud px per world px at cloud scale 1
## Cloud blobs [offset, radius] (world px at scale 1): shade layer, then white layer.
const CLOUD_SHAPES := [
	[[[Vector2(-38, 6), 24.0], [Vector2(38, 6), 22.0], [Vector2(0, 8), 26.0]],
		[[Vector2(-34, 0), 22.0], [Vector2(-8, -14), 30.0], [Vector2(24, -6), 24.0], [Vector2(44, 4), 16.0], [Vector2(0, 4), 24.0]]],
	[[[Vector2(-30, 6), 20.0], [Vector2(28, 8), 20.0]],
		[[Vector2(-28, 2), 20.0], [Vector2(2, -8), 25.0], [Vector2(30, 2), 19.0], [Vector2(0, 6), 20.0]]],
	[[[Vector2(-50, 8), 18.0], [Vector2(0, 10), 22.0], [Vector2(50, 8), 18.0]],
		[[Vector2(-52, 4), 16.0], [Vector2(-24, -6), 22.0], [Vector2(6, -16), 27.0], [Vector2(36, -4), 21.0], [Vector2(58, 6), 14.0], [Vector2(0, 6), 22.0]]],
]
const CLOUD_SIZE := Vector2i(288, 160)

static var _glow: GradientTexture2D


## The night sky: gradient, soft glows, stars (no ground).
static func lobby_sky(ci: CanvasItem, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	_band(ci, size, 0.0, h * 0.55, LOBBY_TOP, LOBBY_MID)
	_band(ci, size, h * 0.55, h, LOBBY_MID, LOBBY_LOW)
	for g in GLOWS:
		var at: Vector2 = g[0] * size
		var r: float = g[1] * h
		ci.draw_texture_rect(glow_texture(), Rect2(at - Vector2(r, r), Vector2(r, r) * 2), false, g[2])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in STARS:
		var p := Vector2(rng.randf() * w, rng.randf() * h * 0.62)
		var r := rng.randf_range(1.0, 2.6)
		ci.draw_circle(p, r * 2.4, Color(1, 1, 1, 0.06), true, -1.0, true)
		ci.draw_circle(p, r, Color(1, 1, 1, rng.randf_range(0.35, 0.85)), true, -1.0, true)


## The lobby ground: a wide soft hill and the faint stage ovals, transparent above the hill. The
## canvas is the bottom (1 - GROUND_FROM) of the lobby screen.
static func lobby_ground(ci: CanvasItem, size: Vector2) -> void:
	var w := size.x
	var h := size.y / (1.0 - GROUND_FROM) # the full screen height
	ci.draw_set_transform(Vector2(0, -h * GROUND_FROM))
	var top := h * 0.7
	var hill := PackedVector2Array()
	var steps := 64
	for i in steps + 1:
		var x := w * i / steps
		var t := (float(i) / steps - 0.5) * 2.0
		hill.append(Vector2(x, top + t * t * h * 0.06))
	hill.append(Vector2(w, h))
	hill.append(Vector2(0, h))
	ci.draw_colored_polygon(hill, LOBBY_GROUND)
	_oval(ci, Vector2(w / 2, h * 0.86), Vector2(w * 0.32, h * 0.1), Color(0.35, 0.5, 0.75, 0.18))
	_oval(ci, Vector2(w / 2, h * 0.86), Vector2(w * 0.2, h * 0.065), Color(0.45, 0.62, 0.9, 0.16))
	ci.draw_set_transform(Vector2.ZERO)


## The stage pedestal: four ovals, a dark base under light rims.
static func pedestal(ci: CanvasItem, _size: Vector2) -> void:
	for layer in PEDESTAL:
		var r: Vector2 = layer[0]
		_oval(ci, PEDESTAL_CENTER + Vector2(0, layer[2]), r, layer[1])
	# A soft highlight across the top face.
	_oval(ci, PEDESTAL_CENTER + Vector2(0, -8), Vector2(110, 14), Color(1, 1, 1, 0.12))


## The day sky over SKY_SPAN: gradient, sun glow, two bands of distant hills.
static func match_sky(ci: CanvasItem, size: Vector2) -> void:
	var k := size / SKY_SPAN.size
	ci.draw_set_transform(-SKY_SPAN.position * k, 0.0, k)
	var x0 := SKY_SPAN.position.x
	var x1 := SKY_SPAN.end.x
	var h := SKY_SPAN.size.y
	var pts := PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(x0, h)])
	ci.draw_polygon(pts, PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	var sun := Vector2(1600 * 0.8, h * 0.16)
	ci.draw_texture_rect(glow_texture(), Rect2(sun - Vector2(220, 220), Vector2(440, 440)), false, Color(1, 0.96, 0.75, 0.55))
	ci.draw_circle(sun, 46.0, Color(1, 0.97, 0.82, 0.95), true, -1.0, true)
	ci.draw_circle(sun, 38.0, Color(1, 1, 0.92, 0.6), true, -1.0, true)
	_hills(ci, x0, x1, h, h * 0.5, h * 0.07, 0.0021, 1.3, HILLS_FAR)
	_hills(ci, x0, x1, h, h * 0.6, h * 0.06, 0.0034, 4.1, HILLS_NEAR)
	ci.draw_set_transform(Vector2.ZERO)


## Cloud `variant` (0..2) at CLOUD_SCALE, centred in the canvas.
static func cloud(ci: CanvasItem, size: Vector2, variant: int) -> void:
	var shape: Array = CLOUD_SHAPES[variant % CLOUD_SHAPES.size()]
	var at := size / 2 + Vector2(0, 8)
	var s := CLOUD_SCALE
	var shade := Color(0.84, 0.9, 0.98, 0.92)
	var white := Color(1, 1, 1, 0.97)
	for b in shape[0]:
		ci.draw_circle(at + b[0] * s + Vector2(0, 5 * s), b[1] * s, shade, true, -1.0, true)
	for b in shape[1]:
		ci.draw_circle(at + b[0] * s, b[1] * s, white, true, -1.0, true)
	# A light top sheen on the biggest blob.
	var top: Array = shape[1][2] if shape[1].size() > 2 else shape[1][0]
	ci.draw_circle(at + top[0] * s + Vector2(-4, -6) * s, top[1] * s * 0.45, Color(1, 1, 1, 0.5), true, -1.0, true)


## A soft white disc fading out to the edge.
static func glow_texture() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 256
		_glow.height = 256
	return _glow


static func _hills(ci: CanvasItem, x0: float, x1: float, h: float, base: float, amp: float, freq: float, phase: float, color: Color) -> void:
	var poly := PackedVector2Array()
	var steps := 128
	for i in steps + 1:
		var x := lerpf(x0, x1, float(i) / steps)
		poly.append(Vector2(x, base - amp * (sin(x * freq + phase) * 0.7 + sin(x * freq * 2.7 + phase * 2.0) * 0.3)))
	poly.append(Vector2(x1, h))
	poly.append(Vector2(x0, h))
	ci.draw_colored_polygon(poly, color)


static func _band(ci: CanvasItem, size: Vector2, y0: float, y1: float, a: Color, b: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0, y1)])
	ci.draw_polygon(pts, PackedColorArray([a, a, b, b]))


static func _oval(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 96:
		pts.append(center + Vector2.from_angle(TAU * i / 96.0) * radii)
	ci.draw_colored_polygon(pts, color)
