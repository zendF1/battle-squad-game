extends Control
## The matchmaking screen's "VS" emblem, drawn in code on a 200 × 200 canvas scaled to fit: gold
## rays turning slowly behind a round badge split blue (my team, left) and red (the enemies,
## right) by a lightning bolt, a gold rim, "VS" in heavy letters on top. `found` turns the rays
## faster and brighter; `flash` (0..1, tweened by the screen) washes it white.

const LobbyUi := preload("res://ui/lobby_ui.gd")

const OUTLINE := Color(0.07, 0.07, 0.14)
const BLUE := Color(0.22, 0.48, 0.98)
const BLUE_DARK := Color(0.1, 0.22, 0.6)
const RED := Color(0.95, 0.3, 0.32)
const RED_DARK := Color(0.55, 0.1, 0.16)
const GOLD := Color(1.0, 0.8, 0.22)
const GOLD_LIGHT := Color(1.0, 0.94, 0.62)
const GOLD_DARK := Color(0.8, 0.46, 0.08)
const RAYS := 16

var found := false:
	set(v):
		found = v
		queue_redraw()
var flash := 0.0:
	set(v):
		flash = v
		queue_redraw()

var _spin := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pivot_offset = size / 2.0


func _process(delta: float) -> void:
	_spin = fmod(_spin + delta * (1.6 if found else 0.35), TAU)
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y) / 200.0
	draw_set_transform((size - Vector2(200, 200) * s) / 2.0, 0.0, Vector2(s, s))
	var c := Vector2(100, 100)
	_rays(c, 98.0, 0.5 if found else 0.26)
	# the badge: rim, the two halves, the bolt between them
	draw_circle(c, 70, OUTLINE)
	draw_circle(c, 66, GOLD_DARK)
	draw_circle(c, 63, GOLD)
	draw_arc(c, 60, PI * 1.05, PI * 1.6, 24, GOLD_LIGHT, 3.0, true)
	draw_colored_polygon(_half(c, 56, true), BLUE)
	draw_colored_polygon(_half(c, 56, false), RED)
	draw_colored_polygon(_half(c, 40, true), Color(BLUE.lightened(0.2), 0.55))
	draw_colored_polygon(_half(c, 40, false), Color(RED.lightened(0.15), 0.5))
	_bolt(c)
	# VS
	var font := LobbyUi.bold()
	var fs := 66
	var text_size := font.get_string_size("VS", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := c + Vector2(-text_size.x / 2.0, text_size.y * 0.32)
	draw_string_outline(font, at + Vector2(0, 4), "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, OUTLINE)
	draw_string_outline(font, at, "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, OUTLINE)
	draw_string(font, at, "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD_LIGHT)
	if flash > 0.0:
		draw_circle(c, 72, Color(1, 1, 1, clampf(flash, 0.0, 1.0) * 0.85))


## A half disc cut along the bolt's slant (the left one is my team's).
func _half(c: Vector2, r: float, left: bool) -> PackedVector2Array:
	var tilt := 0.32 # the split leans like the bolt
	var top := -PI / 2 + tilt
	var pts := PackedVector2Array()
	var from := top if not left else top + PI
	for i in 33:
		pts.append(c + Vector2.from_angle(from + PI * i / 32.0) * r)
	return pts


func _bolt(c: Vector2) -> void:
	var pts := PackedVector2Array([c + Vector2(16, -66), c + Vector2(-14, 2), c + Vector2(2, 2), c + Vector2(-14, 66),
		c + Vector2(14, -6), c + Vector2(-2, -6)])
	for o in Geometry2D.offset_polygon(pts, 4.0, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(o, OUTLINE)
	draw_colored_polygon(pts, Color(1.0, 0.97, 0.8))


func _rays(c: Vector2, r: float, alpha: float) -> void:
	for i in RAYS:
		var a := _spin + TAU * i / RAYS
		var half := PI / RAYS * 0.45
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a - half) * r, c + Vector2.from_angle(a + half) * r])
		var cols := PackedColorArray([Color(GOLD, alpha), Color(GOLD, 0.0), Color(GOLD, 0.0)])
		draw_polygon(pts, cols)
