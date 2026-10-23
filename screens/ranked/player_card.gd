extends Control
## One tall card of the matchmaking screen. Empty (searching): a dark silhouette of a fighter,
## a big "?" and "Đang ghép..." with a light band sweeping over the card. Filled: the player's
## title plate (when known), the character's full-body picture breathing on a glowing floor,
## name, "Lv.N" (" · Máy" for a bot) and the tier badge with "Bạc II". The rim and the glow are
## the team's colour (blue mine, red the enemies'), gold for my own card with a "BẠN" tag at the
## bottom; the face is a rounded-rect shader (FACE_CODE). flip_to() turns
## the card edge-on, swaps the content and turns it back with a white flash.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const CharacterView := preload("res://ui/character_view.gd")
const Art := preload("res://ui/art.gd")
const TitlePlate := preload("res://ui/title_plate.gd")
const TierBadge := preload("res://screens/ranked/tier_badge.gd")
const MatchmakingModel := preload("res://screens/ranked/matchmaking_model.gd")
const ElementBadge := preload("res://ui/element_badge.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const SIZE := Vector2(268, 520)
const COMPACT_SIZE := Vector2(268, 432) # compact: no "BẠN" tag, no rank row
const ART_TOP := 46.0
const ART_H := 290.0
const BLUE := Color(0.36, 0.62, 1.0)
const RED := Color(1.0, 0.42, 0.42)
const GOLD := Color(1.0, 0.8, 0.22)
const BG := Color(0.05, 0.08, 0.2, 0.9)
const RADIUS := 22
const FLIP_SEC := 0.16

## The card's face: a rounded rect (so nothing shows past the corners) with the team's glow from
## the top and the sweeping light band of a searching card.
const FACE_CODE := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(268.0, 520.0);
uniform float radius = 22.0;
uniform vec4 bg : source_color = vec4(0.05, 0.08, 0.2, 0.9);
uniform vec4 rim : source_color = vec4(0.36, 0.62, 1.0, 1.0);
uniform float glow = 0.38;
uniform float shine_x = -1000.0;
varying vec2 local;
void vertex() {
	local = VERTEX;
}
float sd_round(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void fragment() {
	float d = sd_round(local - rect_size * 0.5, rect_size * 0.5, radius);
	float inside = 1.0 - smoothstep(-1.0, 0.5, d);
	vec3 c = mix(bg.rgb, rim.rgb, glow * (1.0 - smoothstep(0.0, rect_size.y * 0.55, local.y)));
	float x = local.x + (local.y - rect_size.y * 0.5) * 0.3;
	float band = 1.0 - smoothstep(0.0, 70.0, abs(x - shine_x));
	c += vec3(band * band * 0.14);
	COLOR = vec4(c, bg.a * inside);
}
"""

static var _face_shader: Shader

var enemy := false:
	set(v):
		enemy = v
		_restyle()
var mine := false: # my own card (gold rim, "BẠN")
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


## The card's size: COMPACT_SIZE when compact, else SIZE.
func _size() -> Vector2:
	return COMPACT_SIZE if compact else SIZE


func _ready() -> void:
	custom_minimum_size = _size()
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pivot_offset = _size() / 2.0
	if _face_shader == null:
		_face_shader = Shader.new()
		_face_shader.code = FACE_CODE
	_face = ColorRect.new()
	_face.size = _size()
	_face.mouse_filter = MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _face_shader
	mat.set_shader_parameter("rect_size", _size())
	mat.set_shader_parameter("radius", float(RADIUS))
	mat.set_shader_parameter("bg", BG)
	_face.material = mat
	add_child(_face)
	_floor = _layer(_draw_floor)
	_content = Control.new()
	_content.size = _size()
	_content.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_content)
	_rim_layer = _layer(_draw_rim)
	_restyle()
	_build()


func _layer(draw: Callable) -> Control:
	var c := Control.new()
	c.size = _size()
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.draw.connect(draw.bind(c))
	add_child(c)
	return c


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


func _rim() -> Color:
	if mine:
		return GOLD
	return RED if enemy else BLUE


func _restyle() -> void:
	if _face == null:
		return
	(_face.material as ShaderMaterial).set_shader_parameter("rim", _rim())
	_floor.queue_redraw()
	_rim_layer.queue_redraw()


## The floor light under the figure.
func _draw_floor(c: Control) -> void:
	var rim := _rim()
	var at := Vector2(_size().x / 2, ART_TOP + ART_H - 10)
	_ellipse(c, at, Vector2(_size().x * 0.4, 22), Color(rim, 0.28))
	_ellipse(c, at, Vector2(_size().x * 0.26, 12), Color(rim.lightened(0.4), 0.3))


## The team-coloured rim, and the white flash of a flip over everything.
func _draw_rim(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, _size())
	if _flash > 0.0:
		if _flash_box == null:
			_flash_box = _box(Color.WHITE, Color(0, 0, 0, 0), 0).duplicate()
		_flash_box.bg_color = Color(1, 1, 1, _flash * 0.75)
		c.draw_style_box(_flash_box, r)
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
	if not empty and title.size() > 0:
		var plate := TitlePlate.new()
		plate.plate_height = 34
		plate.max_width = _size().x - 20
		plate.set_title(title)
		plate.position = Vector2(0, 10)
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
	col.position = Vector2(10, ART_TOP + ART_H + 6)
	col.size = Vector2(_size().x - 20, 0)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	_content.add_child(col)
	if mine and not compact:
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", LobbyUi.box(GOLD, 14, 0, LobbyUi.GOLD_DARK, 2))
		tag.position = Vector2((_size().x - 84) / 2.0, _size().y - 46)
		tag.custom_minimum_size = Vector2(84, 32)
		tag.mouse_filter = MOUSE_FILTER_IGNORE
		var t := _label("BẠN", 20, LobbyUi.TEXT_DARK)
		t.add_theme_constant_override("outline_size", 0)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_child(t)
		_content.add_child(tag)
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
	var name_label := _label(str(_player["displayName"]), 28, GOLD.lightened(0.5) if mine else Color.WHITE)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var element := GameData.character_element(str(_player.get("characterId", "")))
	ElementBadge.fit_label(name_label, _size().x - 20 - (2 * (28 + 6) if element != "" else 0))
	col.add_child(ElementBadge.name_row(name_label, element, 28, 6))
	var lv := MatchmakingModel.level_text(_player)
	if lv != "":
		col.add_child(_label(lv, 22, LobbyUi.GOLD))
	var rank := "" if compact else MatchmakingModel.rank_text(_player)
	if rank != "":
		var row := Ui.hbox(6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(TierBadge.make(str(_player["tier"]), int(_player["division"]), 52))
		var rl := _label(rank, 24, TierBadge.COLORS.get(str(_player["tier"]), TierBadge.COLORS[""])[0])
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(rl)
		col.add_child(row)


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
