extends Control
## Small icons drawn in code (original art, in the style of the baked icons: bright flat shapes in
## a dark rounded outline) for the places that show a picture instead of a word: the stat icons
## (heart: Máu, sword: Sát thương, shield: Phòng thủ), the "i" disc of an info button, a clock
## (a refresh time), the arrows of the element chain (beats → / weak to ←), Lực chiến ("power": a
## lightning bolt on an orange burst), the leaderboard's tabs ("level": up chevrons on a blue disc,
## "insignia": a shoulder board with chevrons) and its lobby button ("trophy"); the showcase's other
## stats ("boot": Năng lượng di chuyển, "magic": Sức mạnh kỹ năng, "terrain": Phá địa hình, "crit":
## Chí mạng), the match's wind ("wind": three gusts curling at their ends), a socketed gem ("gem", in
## `tint`: ShowcaseModel.GEM_COLORS) and the loading screen's failure ("offline": wi-fi arcs crossed
## out in red; "retry": a white turning arrow on a blue disc, its button). Drawn on a 96 × 96
## canvas scaled into the control's square and centred (a single-focus picture). make() for a
## layout, info_button() for the round "i" button that opens a card's popup.

const LobbyUi := preload("res://ui/lobby_ui.gd")

const KINDS := ["heart", "sword", "shield", "info", "clock", "arrow", "power", "level", "insignia", "trophy",
	"boot", "magic", "terrain", "crit", "gem", "wind", "offline", "retry"]
const OUTLINE := Color(0.07, 0.07, 0.14)
const W := 5.0
const HEART := Color(1.0, 0.33, 0.4)
const STEEL := Color(0.86, 0.9, 0.98)
const STEEL_DARK := Color(0.55, 0.62, 0.74)
const GOLD := Color(1.0, 0.8, 0.22)
const SHIELD := Color(0.32, 0.62, 1.0)
const INFO := Color(0.25, 0.52, 0.95)
const GOLD_DARK := Color(0.86, 0.5, 0.1)
const BURST := Color(1.0, 0.45, 0.12)
const BURST_LIGHT := Color(1.0, 0.72, 0.22)
const BOLT := Color(1.0, 0.97, 0.62)
const LEVEL := Color(0.2, 0.52, 1.0)
const BOARD := Color(0.22, 0.42, 0.2)
const LEATHER := Color(0.62, 0.38, 0.2)
const LEATHER_DARK := Color(0.42, 0.24, 0.12)
const WING := Color(0.92, 0.97, 1.0)
const MAGIC := Color(0.72, 0.42, 1.0)
const MAGIC_LIGHT := Color(0.9, 0.78, 1.0)
const ROCK := Color(0.62, 0.48, 0.34)
const ROCK_DARK := Color(0.4, 0.3, 0.2)
const GRASS := Color(0.42, 0.78, 0.3)
const CRIT := Color(1.0, 0.3, 0.28)

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


## `label` with the "level" glyph before it, in a centred row (returned: add it where the label
## would go). show_level() sets the value; the glyph shows only for a number ("Chưa sở hữu" alone).
static func level_row(label: Label, px: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var g = make("level", px)
	g.name = "LevelGlyph"
	g.tooltip_text = "Cấp"
	g.mouse_filter = MOUSE_FILTER_PASS
	row.add_child(g)
	row.add_child(label)
	return row


static func show_level(label: Label, value: String) -> void:
	label.text = value
	var g = label.get_parent().get_node_or_null("LevelGlyph") if label.get_parent() != null else null
	if g != null:
		g.visible = value.is_valid_int()


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
		"power": _power()
		"level": _level()
		"insignia": _insignia()
		"trophy": _trophy()
		"boot": _boot()
		"magic": _magic()
		"terrain": _terrain()
		"crit": _crit()
		"gem": _gem()
		"wind": _wind()
		"offline": _offline()
		"retry": _retry()


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


static func _star(c: Vector2, outer: float, inner: float, points: int, rot: float = -PI / 2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points * 2:
		out.append(c + Vector2.from_angle(rot + PI * i / points) * (outer if i % 2 == 0 else inner))
	return out


func _power() -> void:
	_poly(_star(Vector2(48, 50), 42, 29, 10), BURST)
	draw_colored_polygon(_star(Vector2(48, 50), 32, 22, 10), BURST_LIGHT)
	_poly(PackedVector2Array([Vector2(52, 8), Vector2(26, 54), Vector2(45, 54), Vector2(36, 90), Vector2(72, 38),
		Vector2(53, 38), Vector2(66, 8)]), BOLT)
	draw_colored_polygon(PackedVector2Array([Vector2(52, 8), Vector2(58, 8), Vector2(36, 50), Vector2(30, 50)]), Color(1, 1, 1, 0.6))


func _level() -> void:
	draw_circle(Vector2(48, 48), 42, OUTLINE, true, -1.0, true)
	draw_circle(Vector2(48, 48), 37, LEVEL, true, -1.0, true)
	draw_arc(Vector2(48, 48), 31, PI * 1.1, PI * 1.6, 16, Color(1, 1, 1, 0.35), 4.0, true)
	_stroke(PackedVector2Array([Vector2(30, 52), Vector2(48, 34), Vector2(66, 52)]), GOLD, 10.0, 3.0)
	_stroke(PackedVector2Array([Vector2(30, 70), Vector2(48, 52), Vector2(66, 70)]), Color.WHITE, 10.0, 3.0)


func _insignia() -> void:
	var board := PackedVector2Array([Vector2(48, 6), Vector2(74, 22)])
	for i in 5:
		var a := PI * 0.5 * i / 4.0
		board.append(Vector2(68 + cos(a) * 6, 84 + sin(a) * 6))
	for i in 5:
		var a := PI * 0.5 + PI * 0.5 * i / 4.0
		board.append(Vector2(28 + cos(a) * 6, 84 + sin(a) * 6))
	board.append(Vector2(22, 22))
	_poly(board, BOARD)
	draw_colored_polygon(PackedVector2Array([Vector2(48, 12), Vector2(48, 86), Vector2(28, 86), Vector2(28, 26)]), Color(1, 1, 1, 0.1))
	for y in [80.0, 64.0]:
		_stroke(PackedVector2Array([Vector2(30, y), Vector2(48, y - 10), Vector2(66, y)]), GOLD, 8.0, 3.0)
	_poly(_star(Vector2(48, 34), 10, 4.5, 5), GOLD, 3.0)


func _trophy() -> void:
	_poly(PackedVector2Array([Vector2(26, 78), Vector2(70, 78), Vector2(72, 90), Vector2(24, 90)]), GOLD_DARK) # the plinth
	_poly(PackedVector2Array([Vector2(42, 56), Vector2(54, 56), Vector2(56, 70), Vector2(64, 72), Vector2(64, 80),
		Vector2(32, 80), Vector2(32, 72), Vector2(40, 70)]), GOLD) # the stem and the base
	for side in [-1.0, 1.0]: # the handles
		var pts := PackedVector2Array()
		for i in 9:
			var a := PI * 0.5 + PI * i / 8.0
			pts.append(Vector2(48 + side * 24, 34) + Vector2(cos(a) * -side, sin(a)) * 13.0)
		_stroke(pts, GOLD, 6.0)
	var bowl := PackedVector2Array([Vector2(22, 12), Vector2(74, 12)])
	for i in 13:
		var a := PI * i / 12.0
		bowl.append(Vector2(48 + cos(a) * 26, 30 + sin(a) * 30))
	_poly(bowl, GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(28, 16), Vector2(38, 16), Vector2(40, 50), Vector2(30, 40)]), Color(1, 1, 1, 0.4))
	draw_colored_polygon(_star(Vector2(50, 32), 10, 4.5, 5), Color(1.0, 0.98, 0.8))


func _boot() -> void:
	# a winged boot, toe to the right
	_poly(PackedVector2Array([Vector2(30, 16), Vector2(54, 16), Vector2(56, 56), Vector2(80, 64), Vector2(86, 74),
		Vector2(84, 84), Vector2(22, 84), Vector2(24, 60)]), LEATHER)
	draw_colored_polygon(PackedVector2Array([Vector2(22, 74), Vector2(84, 74), Vector2(84, 84), Vector2(22, 84)]), LEATHER_DARK)
	_stroke(PackedVector2Array([Vector2(28, 24), Vector2(54, 24)]), GOLD, 6.0, 0.0) # the cuff
	for i in 3: # the wing at the heel
		var y := 30.0 + i * 9.0
		_poly(PackedVector2Array([Vector2(28, y), Vector2(6, y - 8 + i * 2), Vector2(10, y + 2), Vector2(28, y + 7)]), WING, 3.0)


func _magic() -> void:
	# a four-point spark with two small ones: skill power
	_poly(_star(Vector2(44, 52), 38, 11, 4, 0.0), MAGIC)
	draw_colored_polygon(_star(Vector2(44, 52), 24, 7, 4, 0.0), MAGIC_LIGHT)
	_poly(_star(Vector2(78, 20), 14, 5, 4, 0.0), MAGIC_LIGHT, 3.0)
	_poly(_star(Vector2(80, 76), 9, 3.5, 4, 0.0), MAGIC_LIGHT, 3.0)


func _terrain() -> void:
	# a ground block with grass on top, cracked through by a bolt of impact
	_poly(PackedVector2Array([Vector2(8, 40), Vector2(30, 30), Vector2(52, 38), Vector2(72, 28), Vector2(88, 36),
		Vector2(88, 86), Vector2(8, 86)]), ROCK)
	draw_colored_polygon(PackedVector2Array([Vector2(8, 40), Vector2(30, 30), Vector2(52, 38), Vector2(72, 28),
		Vector2(88, 36), Vector2(88, 46), Vector2(72, 38), Vector2(52, 48), Vector2(30, 40), Vector2(8, 50)]), GRASS)
	draw_colored_polygon(PackedVector2Array([Vector2(8, 70), Vector2(88, 66), Vector2(88, 86), Vector2(8, 86)]), ROCK_DARK)
	_stroke(PackedVector2Array([Vector2(50, 40), Vector2(42, 56), Vector2(54, 64), Vector2(44, 84)]), OUTLINE, 6.0, 0.0)
	_poly(_star(Vector2(50, 18), 16, 7, 6), GOLD, 3.0)


func _crit() -> void:
	# a red target with a cross-hair
	draw_circle(Vector2(48, 48), 40, OUTLINE, true, -1.0, true)
	draw_circle(Vector2(48, 48), 35, CRIT, true, -1.0, true)
	draw_circle(Vector2(48, 48), 25, Color.WHITE, true, -1.0, true)
	draw_circle(Vector2(48, 48), 15, CRIT, true, -1.0, true)
	draw_circle(Vector2(48, 48), 6, Color.WHITE, true, -1.0, true)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_stroke(PackedVector2Array([Vector2(48, 48) + d * 30, Vector2(48, 48) + d * 46]), OUTLINE, 6.0, 0.0)


func _gem() -> void:
	# a cut gem in `tint`: the table on top, the facets down to the point
	var crown := PackedVector2Array([Vector2(28, 18), Vector2(68, 18), Vector2(88, 40), Vector2(48, 88), Vector2(8, 40)])
	_poly(crown, tint)
	draw_colored_polygon(PackedVector2Array([Vector2(28, 18), Vector2(68, 18), Vector2(60, 40), Vector2(36, 40)]), tint.lightened(0.45))
	draw_colored_polygon(PackedVector2Array([Vector2(8, 40), Vector2(36, 40), Vector2(48, 88)]), tint.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(60, 40), Vector2(88, 40), Vector2(48, 88)]), tint.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([Vector2(32, 22), Vector2(42, 22), Vector2(36, 34)]), Color(1, 1, 1, 0.7))


## Three gusts, the middle one longest, each curling up at its end.
func _wind() -> void:
	for g in [[30.0, 18.0, 66.0], [50.0, 10.0, 80.0], [70.0, 22.0, 60.0]]:
		var y: float = g[0]
		var x0: float = g[1]
		var x1: float = g[2]
		var pts := PackedVector2Array()
		for i in 9:
			pts.append(Vector2(lerpf(x0, x1, i / 8.0), y + sin(i / 8.0 * PI) * -3.0))
		for i in range(1, 10):
			var a := PI / 2 - TAU * 0.75 * i / 9.0
			pts.append(Vector2(x1, y - 8.0) + Vector2(cos(a), -sin(a)) * 8.0 * (1.0 - i / 14.0))
		_stroke(pts, WING, 7.0)


func _offline() -> void:
	var c := Vector2(48, 70)
	for r in [50.0, 34.0, 18.0]:
		var pts := PackedVector2Array()
		for i in 13:
			pts.append(c + Vector2.from_angle(lerpf(PI * 1.25, PI * 1.75, i / 12.0)) * r)
		_stroke(pts, STEEL, 7.0)
	draw_circle(c, 9.0, OUTLINE, true, -1.0, true)
	draw_circle(c, 5.0, STEEL, true, -1.0, true)
	_stroke(PackedVector2Array([Vector2(20, 20), Vector2(76, 76)]), CRIT, 9.0)


func _retry() -> void:
	draw_circle(Vector2(48, 48), 42, OUTLINE, true, -1.0, true)
	draw_circle(Vector2(48, 48), 37, INFO, true, -1.0, true)
	draw_arc(Vector2(48, 48), 31, PI * 1.1, PI * 1.6, 16, Color(1, 1, 1, 0.35), 4.0, true)
	var pts := PackedVector2Array()
	for i in 17:
		pts.append(Vector2(48, 50) + Vector2.from_angle(lerpf(-PI * 0.35, PI * 1.25, i / 16.0)) * 20.0)
	_stroke(pts, Color.WHITE, 8.0, 0.0)
	var tip := Vector2(48, 50) + Vector2.from_angle(-PI * 0.35) * 20.0
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-13, -4), tip + Vector2(9, -13), tip + Vector2(6, 11)]), Color.WHITE)
