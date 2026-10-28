extends Button
## A login button (screens/login.gd): white and rounded, a thin navy edge and a soft shadow so it reads
## on the bright login picture, the provider's mark (ui/login_mark.gd) on the left and the dark heavy
## text centred (equal margins both sides). It squeezes while held and springs back on release.

const LobbyUi := preload("res://ui/lobby_ui.gd")
const LoginMark := preload("res://ui/login_mark.gd")

const SIZE := Vector2(400, 62)
const RADIUS := 16
const FONT_SIZE := 22
const MARK_PX := 34
const MARK_INSET := 16
const TEXT := Color(0.1, 0.11, 0.17)
const EDGE := Color(0.09, 0.14, 0.38, 0.35)
const SHADOW := Color(0.02, 0.05, 0.16, 0.3)
const PRESS_SCALE := 0.94

var provider: String
var mark: Control


func _init(provider_id: String = "guest", caption: String = "") -> void:
	provider = provider_id
	name = provider_id.capitalize()
	text = caption
	custom_minimum_size = SIZE
	focus_mode = FOCUS_NONE
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_font_override("font", LobbyUi.bold())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		add_theme_color_override(state, TEXT)
	add_theme_color_override("font_disabled_color", Color(TEXT, 0.45))
	add_theme_stylebox_override("normal", _box(Color.WHITE, 3))
	add_theme_stylebox_override("hover", _box(Color(0.96, 0.97, 1.0), 3))
	add_theme_stylebox_override("pressed", _box(Color(0.88, 0.9, 0.95), 1))
	add_theme_stylebox_override("hover_pressed", _box(Color(0.88, 0.9, 0.95), 1))
	add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.7), 3))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	mark = LoginMark.new(provider_id)
	mark.name = "Mark"
	mark.anchor_top = 0.5
	mark.anchor_bottom = 0.5
	mark.offset_left = MARK_INSET
	mark.offset_right = MARK_INSET + MARK_PX
	mark.offset_top = -MARK_PX / 2.0
	mark.offset_bottom = MARK_PX / 2.0
	add_child(mark)
	button_down.connect(_squeeze.bind(true))
	button_up.connect(_squeeze.bind(false))
	resized.connect(func() -> void: pivot_offset = size / 2.0)


func _squeeze(down: bool) -> void:
	var t := create_tween()
	if down:
		t.tween_property(self, "scale", Vector2.ONE * PRESS_SCALE, 0.07).set_ease(Tween.EASE_OUT)
	else:
		t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _box(bg: Color, shadow_y: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(RADIUS)
	b.anti_aliasing = true
	b.border_color = EDGE
	b.set_border_width_all(2)
	b.shadow_color = SHADOW
	b.shadow_size = 6
	b.shadow_offset = Vector2(0, shadow_y)
	var side := MARK_INSET + MARK_PX + 10
	b.content_margin_left = side
	b.content_margin_right = side
	b.content_margin_top = 4
	b.content_margin_bottom = 4
	return b
