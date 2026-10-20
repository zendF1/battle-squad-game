extends Control
## A modal dialog drawn over the whole screen: a dim backdrop that eats input and a centered
## card with a title, a body and a row of buttons (more rows on demand: add_button(..., row_index)).
## Built in code instead of AcceptDialog so it uses the phone-sized fonts. close() frees it.
## add_close_x() puts a round X in the card's top-left corner (instead of a "Đóng" button).

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")

## The card's padding and the close X's size and inset from the card's corner.
const PADDING := 28
const CLOSE_SIZE := 56
const CLOSE_INSET := 12

var title: Label
var body: VBoxContainer
var message: Label # an inline error/status line under the body
var _buttons: HBoxContainer # row 0
var _rows: VBoxContainer # row 0, then the rows add_button() / add_row_label() asked for
var close_x: Button # add_close_x(), null without it (not one of buttons())
var _card: PanelContainer


## Builds the dialog and adds it to `host` (the screen root): `var m := Modal.new(); m.open(...)`.
func open(host: Node, title_text: String, width: int = 720) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	_card = Ui.card(Color(0.13, 0.15, 0.2), PADDING)
	_card.custom_minimum_size.x = width
	center.add_child(_card)
	var col := Ui.vbox(18)
	_card.add_child(col)
	title = Ui.label(title_text, 32)
	col.add_child(title)
	body = Ui.vbox(14)
	col.add_child(body)
	message = Ui.label("", 22)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", Ui.TONES["error"])
	message.visible = false
	col.add_child(message)
	_rows = Ui.vbox(14)
	col.add_child(_rows)
	_buttons = row(0)
	host.add_child(self)


## A body paragraph.
func add_text(value: String, font_size: int = 26) -> Label:
	var l := Ui.label(value, font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(l)
	return l


## A button in row `row_index` (0 = the main row; the rows below are created when first used).
func add_button(text: String, on_press: Callable, row_index: int = 0) -> Button:
	var b := Ui.button(text, 28)
	b.custom_minimum_size = Vector2(240, 84)
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(on_press)
	row(row_index).add_child(b)
	return b


## A line of text among the buttons of row `row_index` (a reason next to them).
func add_row_label(value: String, row_index: int, font_size: int = 22) -> Label:
	var l := Ui.label(value, font_size)
	l.add_theme_color_override("font_color", Ui.TEXT_DIM)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row(row_index).add_child(l)
	return l


## Button row `row_index`, created (with the rows above it) when missing.
func row(row_index: int) -> HBoxContainer:
	while _rows.get_child_count() <= row_index:
		var r := Ui.hbox(20)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		_rows.add_child(r)
	return _rows.get_child(row_index)


## A round X in the card's top-left corner that closes the dialog (on_close, close() by default).
## It is not one of buttons(): lock_button() never locks it; set_busy() turns it off while a
## request runs, like the other buttons.
func add_close_x(on_close: Callable = Callable()) -> Button:
	if close_x != null:
		return close_x
	# The card lays its children over its content rect: a layer that lets clicks through holds the
	# X, placed back over the padding into the corner.
	var layer := Control.new()
	layer.name = "CloseLayer"
	layer.mouse_filter = MOUSE_FILTER_IGNORE
	_card.add_child(layer)
	close_x = LobbyUi.round_button("close", CLOSE_SIZE, Color(0.24, 0.28, 0.42), 0.5)
	close_x.name = "CloseX"
	close_x.expand_icon = true # the icon fits the circle (icon_max_width), not its 96 px
	close_x.tooltip_text = "Đóng"
	close_x.position = Vector2(CLOSE_INSET - PADDING, CLOSE_INSET - PADDING)
	close_x.size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	close_x.pressed.connect(on_close if on_close.is_valid() else close)
	layer.add_child(close_x)
	return close_x


func set_message(value: String) -> void:
	message.text = value
	message.visible = value != ""


## Disables every button while a request runs; afterwards each is enabled again unless it was
## locked (lock_button(): an action that is not possible).
func set_busy(busy: bool) -> void:
	for b in buttons():
		(b as Button).disabled = busy or b.get_meta("locked", false)
	if close_x != null:
		close_x.disabled = busy


## Keeps a button disabled, also after set_busy(false).
func lock_button(b: Button) -> void:
	b.set_meta("locked", true)
	b.disabled = true


## Every button, row by row.
func buttons() -> Array:
	var out: Array = []
	for r in _rows.get_children():
		out.append_array(r.get_children().filter(func(c): return c is Button))
	return out


func close() -> void:
	queue_free()
