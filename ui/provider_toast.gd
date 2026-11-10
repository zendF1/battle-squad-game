extends RefCounted
## The sign-in toast (the login screen, the settings popup's account linking): a white card near the
## top with the provider's mark (ui/login_mark.gd) and a short message; it replaces the one showing.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const LoginButton := preload("res://ui/login_button.gd")
const LoginMark := preload("res://ui/login_mark.gd")

const SECONDS := 1.8
## A failure's message colour on the white card.
const ERROR := Color(0.8, 0.14, 0.12)
const NAME := "Toast"


static func show(host: Control, provider: String, message: String, color: Color = LoginButton.TEXT) -> PanelContainer:
	var old := host.get_node_or_null(NAME)
	if old != null:
		old.name = "OldToast"
		old.queue_free()
	var card := PanelContainer.new()
	card.name = NAME
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := LobbyUi.box(Color.WHITE, 16, 14, LoginButton.EDGE, 2)
	box.content_margin_left = 20
	box.content_margin_right = 26
	box.shadow_color = LoginButton.SHADOW
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
	card.add_theme_stylebox_override("panel", box)
	var row := Ui.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := LoginMark.new(provider)
	mark.custom_minimum_size = Vector2(34, 34)
	row.add_child(mark)
	var l := Ui.label(message, 24)
	l.name = "Message"
	l.add_theme_font_override("font", LobbyUi.bold())
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	card.add_child(row)
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.position.y = 24
	host.add_child(card)
	card.modulate.a = 0.0
	var t := card.create_tween()
	t.tween_property(card, "modulate:a", 1.0, 0.15)
	t.tween_interval(SECONDS)
	t.tween_property(card, "modulate:a", 0.0, 0.3)
	t.tween_callback(card.queue_free)
	return card
