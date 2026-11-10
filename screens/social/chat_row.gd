extends RefCounted
## One chat message in the chat popup: the sender's head (their current character, the initial
## without one) as a button that opens their player card, their name (mine in gold) with the level
## and the time beside it, the text under it (wrapped). Also the friend row of the Bạn bè tab.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")
const ChatModel := preload("res://screens/social/chat_model.gd")

const HEAD := 56


## A message row; `on_sender` (player id, the message) runs on a tap on the head or the name of
## someone else.
static func make(m: Dictionary, mine: bool, on_sender: Callable) -> Control:
	var row := Ui.hbox(12)
	row.name = "Msg_%d" % int(m["id"])
	var name_text := ChatModel.sender_name(m)
	var head := _tap(HeadIcon.make(str(m.get("characterId", "")), name_text, HEAD), not mine, func() -> void: on_sender.call(m))
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(head)
	var col := Ui.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var top := Ui.hbox(10)
	col.add_child(top)
	top.add_child(name_button(name_text, ChatModel.MY_NAME_COLOR if mine else ChatModel.NAME_COLOR, not mine,
		func() -> void: on_sender.call(m)))
	var lv := ChatModel.level_text(int(m.get("level", 0)))
	if lv != "":
		var l := LobbyUi.text(lv, 18, LobbyUi.GOLD, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		top.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var time := LobbyUi.text(ChatModel.clock(str(m.get("createdAt", ""))), 16, Ui.TEXT_DIM)
	time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(time)
	var text := LobbyUi.text(str(m["text"]), 22, Color.WHITE)
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 200
	col.add_child(text)
	return row


## The sender's name: a flat button (off for mine) in `color`, outlined like the lobby's text.
static func name_button(value: String, color: Color, active: bool, on_tap: Callable) -> Button:
	var b := Button.new()
	b.name = "Sender"
	b.text = value
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not active
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", LobbyUi.bold())
	b.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, color)
	b.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.08, 0.85))
	b.add_theme_constant_override("outline_size", 4)
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if active:
		b.pressed.connect(on_tap)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## `c` as a flat tap target running `on_tap` (when `active`; else `c` itself).
static func _tap(c: Control, active: bool, on_tap: Callable) -> Control:
	if not active:
		return c
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.custom_minimum_size = c.get_combined_minimum_size()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(c)
	b.pressed.connect(on_tap)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b
