extends Control
## Small icons drawn in code (original art, in the style of the baked icons: bright flat shapes in
## a dark rounded outline) for the places that show a picture instead of a word: the stat icons
## (heart: Máu, sword: Sát thương, shield: Phòng thủ), the "i" disc of an info button, a clock
## (a refresh time) and the arrows of the element chain (beats → / weak to ←). Drawn on a 96 × 96
## canvas scaled into the control's square and centred (a single-focus picture). make() for a
## layout, info_button() for the round "i" button that opens a card's popup.

const LobbyUi := preload("res://ui/lobby_ui.gd")

const KINDS := ["heart", "sword", "shield", "info", "clock", "arrow"]
const OUTLINE := Color(0.07, 0.07, 0.14)
const W := 5.0
const HEART := Color(1.0, 0.33, 0.4)
const STEEL := Color(0.86, 0.9, 0.98)
const STEEL_DARK := Color(0.55, 0.62, 0.74)
const GOLD := Color(1.0, 0.8, 0.22)
const SHIELD := Color(0.32, 0.62, 1.0)
const INFO := Color(0.25, 0.52, 0.95)

@export var kind := "heart":
	set(v):
		kind = v
		queue_redraw()
## The arrow's colour (kind "arrow"; it points right, flip_h for left).
@export var tint := Color(0.5, 0.95, 0.5):
	set(v):
		tint = v
		queue_redraw()
@export var flip_h := false:
	set(v):
		flip_h = v
		queue_redraw()


## A `px` square icon of `kind` that ignores the mouse.
static func make(icon_kind: String, px: int, color: Color = Color(0.5, 0.95, 0.5), flipped: bool = false):
	var g = new()
	g.kind = icon_kind
	g.tint = color
	g.flip_h = flipped
	g.custom_minimum_size = Vector2(px, px)
	g.size = Vector2(px, px)
	g.mouse_filter = MOUSE_FILTER_IGNORE
	g.size_flags_horizontal = SIZE_SHRINK_CENTER
	g.size_flags_vertical = SIZE_SHRINK_CENTER
	return g


## The round "i" button of a card's top-right corner (its popup tells the rest): a flat button the
## size of `px` with the drawn "i" disc on it.
static func info_button(on_press: Callable, px: int = 44) -> Button:
	var b := Button.new()
	b.name = "Info"
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = FOCUS_NONE
	b.flat = true
	b.tooltip_text = "Thông tin"
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var g = make("info", px)
	g.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	b.add_child(g)
	b.button_down.connect(func() -> void: g.modulate = Color(0.8, 0.8, 0.8))
	b.button_up.connect(func() -> void: g.modulate = Color.WHITE)
	b.pressed.connect(on_press)
	return b


func _init() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := minf(size.x, size.y) / 96.0
	if s <= 0.0:
		return
	var at := (size - Vector2(96, 96) * s) / 2.0
	if flip_h:
		draw_set_transform(at + Vector2(96 * s, 0), 0.0, Vector2(-s, s))
	else:
		draw_set_transform(at, 0.0, Vector2(s, s))
	match kind:
		"heart": _heart()
		"sword": _sword()
		"shield": _shield()
		"info": _info()
		"clock": _clock()
		"arrow": _arrow()


func _poly(pts: PackedVector2Array, fill: Color, w: float = W) -> void:
	if w > 0.0:
		for o in Geometry2D.offset_polygon(pts, w, Geometry2D.JOIN_ROUND):
			draw_colored_polygon(o, OUTLINE)
	draw_colored_polygon(pts, fill)


func _stroke(pts: PackedVector2Array, color: Color, width: float, w: float = W) -> void:
	if w > 0.0:
		for o in Geometry2D.offset_polyline(pts, width / 2.0 + w, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			draw_colored_polygon(o, OUTLINE)
	for o in Geometry2D.offset_polyline(pts, width / 2.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
		draw_colored_polygon(o, color)


func _heart() -> void:
	var pts := PackedVector2Array()
	for i in 48:
		var t := TAU * i / 48.0
		# the classic heart curve, scaled into the canvas
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(Vector2(48, 46) + Vector2(x, y) * 2.3)
	_poly(pts, HEART)
	draw_colored_polygon(PackedVector2Array([Vector2(28, 30), Vector2(36, 24), Vector2(42, 30), Vector2(33, 38)]), Color(1, 1, 1, 0.55))


func _sword() -> void:
	# the blade from the bottom-left grip up to the top-right point
	_poly(PackedVector2Array([Vector2(30, 54), Vector2(69, 15), Vector2(86, 10), Vector2(81, 27), Vector2(42, 66)]), STEEL)
	draw_colored_polygon(PackedVector2Array([Vector2(36, 60), Vector2(75, 21), Vector2(81, 27), Vector2(42, 66)]), STEEL_DARK)
	_stroke(PackedVector2Array([Vector2(24, 48), Vector2(48, 72)]), GOLD, 11.0) # the guard
	_stroke(PackedVector2Array([Vector2(34, 62), Vector2(20, 76)]), Color(0.55, 0.32, 0.16), 11.0) # the grip
	draw_circle(Vector2(16, 80), 7.0 + W, OUTLINE, true, -1.0, true) # the pommel
	draw_circle(Vector2(16, 80), 7.0, GOLD, true, -1.0, true)


func _shield() -> void:
	var pts := PackedVector2Array([Vector2(48, 12), Vector2(78, 22), Vector2(76, 50)])
	for i in 9:
		var t := float(i) / 8.0
		pts.append(Vector2(lerpf(76, 48, t), 50 + 34 * sin(t * PI / 2.0)))
	for i in range(8, -1, -1):
		var t := float(i) / 8.0
		pts.append(Vector2(lerpf(20, 48, t), 50 + 34 * sin(t * PI / 2.0)))
	pts.append(Vector2(18, 22))
	var clean := PackedVector2Array()
	for p in pts:
		if clean.is_empty() or clean[clean.size() - 1].distance_to(p) > 0.5:
			clean.append(p)
	_poly(clean, SHIELD)
	draw_colored_polygon(PackedVector2Array([Vector2(48, 20), Vector2(70, 27), Vector2(68, 50), Vector2(48, 76)]), Color(1, 1, 1, 0.22))
	_stroke(PackedVector2Array([Vector2(48, 30), Vector2(48, 64)]), GOLD, 7.0, 0.0)
	_stroke(PackedVector2Array([Vector2(34, 44), Vector2(62, 44)]), GOLD, 7.0, 0.0)


func _info() -> void:
	draw_circle(Vector2(48, 48), 42, OUTLINE, true, -1.0, true)
	draw_circle(Vector2(48, 48), 37, INFO, true, -1.0, true)
	draw_arc(Vector2(48, 48), 31, PI * 1.1, PI * 1.6, 16, Color(1, 1, 1, 0.35), 4.0, true)
	draw_circle(Vector2(48, 28), 6.5, Color.WHITE, true, -1.0, true)
	_stroke(PackedVector2Array([Vector2(48, 42), Vector2(48, 68)]), Color.WHITE, 11.0, 0.0)


func _clock() -> void:
	draw_circle(Vector2(48, 48), 40, OUTLINE, true, -1.0, true)
	draw_circle(Vector2(48, 48), 35, Color(0.95, 0.96, 1.0), true, -1.0, true)
	for i in 12:
		var d := Vector2.from_angle(TAU * i / 12.0)
		draw_line(Vector2(48, 48) + d * 28, Vector2(48, 48) + d * (24 if i % 3 == 0 else 26), OUTLINE, 3.0, true)
	_stroke(PackedVector2Array([Vector2(48, 48), Vector2(48, 26)]), OUTLINE, 6.0, 0.0)
	_stroke(PackedVector2Array([Vector2(48, 48), Vector2(64, 56)]), OUTLINE, 6.0, 0.0)
	draw_circle(Vector2(48, 48), 5, GOLD, true, -1.0, true)


func _arrow() -> void:
	_poly(PackedVector2Array([Vector2(14, 40), Vector2(52, 40), Vector2(52, 24), Vector2(84, 48), Vector2(52, 72),
		Vector2(52, 56), Vector2(14, 56)]), tint)
