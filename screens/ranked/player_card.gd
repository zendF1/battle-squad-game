extends Control
## One tall card of the matchmaking screen. Empty (searching): a dark silhouette of a fighter,
## a big "?" and "Đang ghép..." with a light band sweeping over the card. Filled: the player's
## title plate (when known), the character's full-body picture breathing on a glowing floor,
## name and "Lv.N"; with a badge (rankBadge: last season's final grade) the badge's frame
## (grade_frame.gd, its medallion carrying the insignia) round the card says the rank, no words
## (on my own card a tap: rank_pressed). Without a badge
## the rim and the glow are the team's colour (blue mine, red the enemies'); a badge holder's card
## takes the grade's look (grade_look.gd: the tier's background with a spotlight, sparkles, the
## grade's dais under the figure) and keeps the team's colour as a band behind the name. With
## real frame art in the row (fit_art, set by the screen for every card when any card's badge has
## art): the art's outer bounds fit the card's own rect and everything else shrinks into its
## window (GradeFrame.fit(): the same size for every card of the row, mirrored sides alike); the
## face is a rounded-rect shader (GradeLook.FACE_CODE). flip_to() turns the card edge-on, swaps
## the content and turns it back with a white flash.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const CharacterView := preload("res://ui/character_view.gd")
const Art := preload("res://ui/art.gd")
const TitlePlate := preload("res://ui/title_plate.gd")
const GradeFrame := preload("res://screens/ranked/grade_frame.gd")
const GradeLook := preload("res://screens/ranked/grade_look.gd")
const GradePedestal := preload("res://screens/ranked/grade_pedestal.gd")
const MatchmakingModel := preload("res://screens/ranked/matchmaking_model.gd")
const ElementBadge := preload("res://ui/element_badge.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const SIZE := Vector2(268, 520)
const COMPACT_SIZE := Vector2(268, 448) # compact: a lower name, a smaller dais
const ART_TOP := 46.0
const ART_H := 290.0
const BLUE := Color(0.36, 0.62, 1.0)
const RED := Color(1.0, 0.42, 0.42)
const GOLD := Color(1.0, 0.8, 0.22)
const BG := Color(0.05, 0.08, 0.2, 0.9)
const RADIUS := 22
const FLIP_SEC := 0.16
const FRAME_OUT := 5.0 # the badge's frame sits this far outside the card's rim
const CREST := 40.0 # the badge on the code frame's medallion
const DAIS_RX := 94.0 # a badge holder's dais: its top face's half-width (wider than the shoulders)
const COMPACT_DAIS_RX := 74.0
const FEET_Y := ART_TOP + ART_H - 18.0 # the figure's feet: the dais's top face is centred here
const TITLE_DROP := 26.0 # the title plate under the badge frame's medallion (every card alike)
const TEAM_BAND := 40.0 # a badge holder's team colour: a band this tall behind the name

## A tap on the insignia of my own card (the Matchmaking screen opens the rank ladder).
signal rank_pressed

var enemy := false:
	set(v):
		enemy = v
		_restyle()
var mine := false: # my own card (the same frame as my team's, my name in yellow)
	set(v):
		mine = v
		_restyle()
## title {id, name, rarity} to show for the player, {} none (set before show_player()).
var title := {}
## A compact card (COMPACT_SIZE): character, name and level only (set before it enters the tree).
var compact := false

var _player := {}
var _face: ColorRect
var _floor: Control
var _content: Control
var _rim_layer: Control
var _shine_tween: Tween
var _flash := 0.0
var _flash_box: StyleBoxFlat
var _art: CharacterView
var _frame: GradeFrame
var _body: Control # everything but the flip: shrunk into the art's window when fit_art
## Real frame art somewhere in the row: this card shrinks into the window the art leaves in its rect.
var fit_art := false:
	set(v):
		fit_art = v
		_apply_fit()


## The card's size: COMPACT_SIZE when compact, else SIZE.
func _size() -> Vector2:
	return COMPACT_SIZE if compact else SIZE


func _ready() -> void:
	custom_minimum_size = _size()
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pivot_offset = _size() / 2.0
	_body = Control.new()
	_body.name = "Body"
	_body.size = _size()
	_body.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_body)
	_face = ColorRect.new()
	_face.size = _size()
	_face.mouse_filter = MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = GradeLook.face_shader()
	mat.set_shader_parameter("rect_size", _size())
	mat.set_shader_parameter("radius", float(RADIUS))
	mat.set_shader_parameter("bg", BG)
	_face.material = mat
	_body.add_child(_face)
	_floor = _layer(_draw_floor)
	_content = Control.new()
	_content.size = _size()
	_content.mouse_filter = MOUSE_FILTER_IGNORE
	_body.add_child(_content)
	_rim_layer = _layer(_draw_rim)
	_frame = GradeFrame.make("", RADIUS + FRAME_OUT, CREST)
	_frame.name = "Frame"
	_body.add_child(_frame)
	_apply_fit()
	_restyle()
	_build()


func _layer(draw: Callable) -> Control:
	var c := Control.new()
	c.size = _size()
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.draw.connect(draw.bind(c))
	_body.add_child(c)
	return c


## The body at full size with the code frame round it, or (fit_art) shrunk into the window the
## art leaves in the card's rect, the frame's window on it.
func _apply_fit() -> void:
	if _body == null:
		return
	var fc := GradeFrame.layout()
	if fit_art and not fc.is_empty():
		var f := GradeFrame.fit(fc, _size(), _size())
		_body.scale = Vector2.ONE * float(f["s"])
		_body.position = Rect2(f["card"]).position
		_frame.window_inset = 0.0
		_frame.position = Vector2.ZERO
		_frame.size = _size()
	else:
		_body.scale = Vector2.ONE
		_body.position = Vector2.ZERO
		_frame.window_inset = FRAME_OUT # the real art's window on the card itself
		_frame.position = -Vector2.ONE * FRAME_OUT
		_frame.size = _size() + Vector2.ONE * FRAME_OUT * 2.0


func player() -> Dictionary:
	return _player


## Shows `p` (a MatchmakingModel player; {} for the searching silhouette) at once.
func show_player(p: Dictionary) -> void:
	_player = p
	if is_node_ready():
		_build()


## Turns the card over onto `p`.
func flip_to(p: Dictionary) -> void:
	var t := create_tween()
	t.tween_property(self, "scale:x", 0.0, FLIP_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		show_player(p)
		_set_flash(1.0))
	t.tween_property(self, "scale:x", 1.0, FLIP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_set_flash, 1.0, 0.0, 0.45)


func _set_flash(v: float) -> void:
	_flash = v
	_rim_layer.queue_redraw()


## The team's frame: my card and my teammates' the same blue (only my name is yellow), the
## other team's red.
func _rim() -> Color:
	return RED if enemy else BLUE


func _restyle() -> void:
	if _face == null:
		return
	(_face.material as ShaderMaterial).set_shader_parameter("rim", _rim())
	_floor.queue_redraw()
	_rim_layer.queue_redraw()


## Under the figure: a badge holder's sparkles, the team's band behind the name and the grade's
## dais (grade_pedestal.gd); without a badge the team-coloured floor light.
func _draw_floor(c: Control) -> void:
	var rim := _rim()
	var at := Vector2(_size().x / 2, FEET_Y)
	var g := _badge()
	if GradeLook.tier_of(g) >= 0:
		GradeLook.draw_sparkles(c, Rect2(Vector2.ZERO, _size()), g)
		var y := ART_TOP + ART_H + 4.0 + _drop()
		var w := _size().x
		c.draw_polygon(PackedVector2Array([Vector2(0, y), Vector2(w / 2, y), Vector2(w, y), Vector2(w, y + TEAM_BAND),
			Vector2(w / 2, y + TEAM_BAND), Vector2(0, y + TEAM_BAND)]),
			PackedColorArray([Color(rim, 0.0), Color(rim, 0.6), Color(rim, 0.0), Color(rim, 0.0), Color(rim, 0.6), Color(rim, 0.0)]))
		GradePedestal.draw(c, at, COMPACT_DAIS_RX if compact else DAIS_RX, g)
		return
	_ellipse(c, at, Vector2(_size().x * 0.4, 22), Color(rim, 0.28))
	_ellipse(c, at, Vector2(_size().x * 0.26, 12), Color(rim.lightened(0.4), 0.3))


## The name and the level sit this much lower than the art's foot (clear of a badge holder's
## dais; less on a compact card). Every card alike, so a row's names line up.
func _drop() -> float:
	return 22.0 if compact else 58.0


## The shown player's badge ("" none or the searching card).
func _badge() -> String:
	return "" if _player.is_empty() else str(_player.get("rankBadge", ""))


## The team-coloured rim, and the white flash of a flip over everything.
func _draw_rim(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, _size())
	if _flash > 0.0:
		if _flash_box == null:
			_flash_box = _box(Color.WHITE, Color(0, 0, 0, 0), 0).duplicate()
		_flash_box.bg_color = Color(1, 1, 1, _flash * 0.75)
		c.draw_style_box(_flash_box, r)
	if GradeLook.tier_of(_badge()) < 0: # a badge holder's team colour: the band behind the name
		c.draw_style_box(_box(Color(0, 0, 0, 0), _rim(), 4), r)


static func _ellipse(c: Control, at: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(at + Vector2(cos(TAU * i / 32.0) * radii.x, sin(TAU * i / 32.0) * radii.y))
	c.draw_colored_polygon(pts, color)


static var _boxes := {}


static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var key := [bg, border, width]
	if not _boxes.has(key):
		var b := StyleBoxFlat.new()
		b.bg_color = bg
		b.set_corner_radius_all(RADIUS)
		b.anti_aliasing = true
		b.corner_detail = 12
		if width > 0:
			b.border_color = border
			b.set_border_width_all(width)
			b.draw_center = false
		_boxes[key] = b
	return _boxes[key]


func _build() -> void:
	Ui.clear(_content)
	_art = null
	var empty := _player.is_empty()
	_set_shine(empty)
	_frame.grade = _badge()
	var face := _face.material as ShaderMaterial
	GradeLook.set_face(face, _badge())
	face.set_shader_parameter("foot_y", ART_TOP + ART_H + _drop())
	_floor.queue_redraw()
	_rim_layer.queue_redraw()
	# my own badge holder's card: a tap opens the rank ladder (the frame says the rank)
	var tap := mine and not compact and _badge() != ""
	mouse_filter = MOUSE_FILTER_STOP if tap else MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if tap else CURSOR_ARROW
	if not empty and title.size() > 0:
		var plate := TitlePlate.new()
		plate.plate_height = 34
		plate.max_width = _size().x - 20
		plate.set_title(title)
		plate.position = Vector2(0, 10 + TITLE_DROP)
		plate.size = Vector2(_size().x, 38)
		plate.mouse_filter = MOUSE_FILTER_IGNORE
		_content.add_child(plate)
	_art = CharacterView.new()
	_art.character_id = Art.DEFAULT_CHARACTER if empty else str(_player["characterId"])
	_art.idle = not empty
	_art.position = Vector2((_size().x - 250) / 2.0, ART_TOP)
	_art.size = Vector2(250, ART_H)
	if empty:
		_art.modulate = Color(0.02, 0.03, 0.1, 0.78) # a silhouette
	_content.add_child(_art)
	var col := Ui.vbox(2)
	col.position = Vector2(10, ART_TOP + ART_H + 6 + _drop())
	col.size = Vector2(_size().x - 20, 0)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	_content.add_child(col)
	if empty:
		var q := _label("?", 100, Color(1, 1, 1, 0.5))
		q.position = Vector2(0, ART_TOP + 70)
		q.size = Vector2(_size().x, 120)
		_content.add_child(q)
		var searching := _label("Đang ghép...", 26, Color(1, 1, 1, 0.62))
		col.add_child(searching)
		var pulse := searching.create_tween().set_loops()
		pulse.tween_property(searching, "modulate:a", 0.45, 0.8).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(searching, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
		return
	var name_label := _label(str(_player["displayName"]), 28, LobbyUi.GOLD if mine else Color.WHITE)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var element := GameData.character_element(str(_player.get("characterId", "")))
	ElementBadge.fit_label(name_label, _size().x - 20 - (2 * (28 + 6) if element != "" else 0))
	col.add_child(ElementBadge.name_row(name_label, element, 28, 6))
	var lv := MatchmakingModel.level_text(_player)
	if lv != "":
		col.add_child(_label(lv, 22, LobbyUi.GOLD))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		rank_pressed.emit()


func _label(value: String, font_size: int, color: Color) -> Label:
	var l := LobbyUi.text(value, font_size, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l


## The light band sweeping over a searching card (the face shader's shine_x).
func _set_shine(on: bool) -> void:
	if _shine_tween != null:
		_shine_tween.kill()
		_shine_tween = null
	var mat := _face.material as ShaderMaterial
	mat.set_shader_parameter("shine_x", -1000.0)
	if not on:
		return
	_shine_tween = create_tween().set_loops()
	_shine_tween.tween_method(func(x: float) -> void: mat.set_shader_parameter("shine_x", x), -160.0, _size().x + 160.0, 1.6) \
		.set_trans(Tween.TRANS_SINE)
	_shine_tween.tween_interval(0.5)
