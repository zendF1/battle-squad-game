extends Control
## A modal dialog drawn over the whole screen: a dim backdrop that eats input and a centered
## card with a title, a body and a row of buttons (more rows on demand: add_button(..., row_index)).
## Built in code instead of AcceptDialog so it uses the phone-sized fonts. close() frees it.
## add_close_x() puts an X in the card's top-right corner (instead of a "Đóng" button) and lets a
## tap on the backdrop close the dialog too (close_on_backdrop(), also usable alone).

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")

## The card's padding; the close X's size and its gap to the title.
const PADDING := 28
const CLOSE_SIZE := 50
const CLOSE_GAP := 10

var title: Label
var body: VBoxContainer
var message: Label # an inline error/status line under the body
var _buttons: HBoxContainer # row 0
var _rows: VBoxContainer # row 0, then the rows add_button() / add_row_label() asked for
var close_x: Button # add_close_x(), null without it (not one of buttons())
var _card: PanelContainer
var backdrop: ColorRect # the dim behind the card
var _backdrop_close := Callable() # close_on_backdrop(): what a tap outside the card does
var _backdrop_down := false # a press began on the backdrop (its release closes)
var _busy := false


## Builds the dialog and adds it to `host` (the screen root): `var m := Modal.new(); m.open(...)`.
func open(host: Node, title_text: String, width: int = 720) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE # clicks outside the card reach the backdrop
	add_child(center)
	_card = Ui.card(Color(0.13, 0.15, 0.2), PADDING)
	_card.mouse_filter = MOUSE_FILTER_STOP # taps inside the card never reach the backdrop
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


## An X in the card's top-right corner, on the title's row, that closes the dialog (on_close,
## close() by default): a rounded-square button styled like the dialog's other buttons. The title
## keeps clear of it on both sides, so it stays centred. It is not one of buttons():
## lock_button() never locks it; set_busy() turns it off while a request runs, like the others.
func add_close_x(on_close: Callable = Callable()) -> Button:
	if close_x != null:
		return close_x
	# The X's distance from the card's top and right edges: centred on the title's row.
	var title_h := maxf(title.get_combined_minimum_size().y, float(CLOSE_SIZE) * 0.8)
	var inset := PADDING + (title_h - CLOSE_SIZE) / 2.0
	# The card lays its children over its content rect: a layer that lets clicks through holds the
	# X, anchored to its top-right and placed back over the padding into the corner.
	var layer := Control.new()
	layer.name = "CloseLayer"
	layer.mouse_filter = MOUSE_FILTER_IGNORE
	_card.add_child(layer)
	close_x = Button.new()
	close_x.name = "CloseX"
	close_x.tooltip_text = "Đóng"
	LobbyUi.texture_button(close_x, "button_navy", 0)
	LobbyUi.set_icon(close_x, "close", int(CLOSE_SIZE * 0.5))
	close_x.expand_icon = true # the icon fits the button (icon_max_width), not its 96 px
	close_x.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_x.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	close_x.custom_minimum_size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	close_x.set_anchors_preset(PRESET_TOP_RIGHT)
	close_x.offset_right = PADDING - inset
	close_x.offset_left = close_x.offset_right - CLOSE_SIZE
	close_x.offset_top = inset - PADDING
	close_x.offset_bottom = close_x.offset_top + CLOSE_SIZE
	close_x.pressed.connect(on_close if on_close.is_valid() else close)
	layer.add_child(close_x)
	close_on_backdrop(on_close)
	# Room for the X on both sides of the title (it stays centred, long titles wrap).
	var room := int(ceil(close_x.offset_right * -1.0 + CLOSE_SIZE + CLOSE_GAP))
	var holder := MarginContainer.new()
	holder.name = "TitleRoom"
	holder.add_theme_constant_override("margin_left", room)
	holder.add_theme_constant_override("margin_right", room)
	var col := title.get_parent()
	var at := title.get_index()
	col.remove_child(title)
	holder.add_child(title)
	col.add_child(holder)
	col.move_child(holder, at)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return close_x


## A tap on the backdrop (outside the card) closes the dialog: on_close, close() by default (a
## confirmation passes its Huỷ). Only a press that starts on the backdrop and is released there
## counts, so the click that opened the dialog never closes it; off while a request runs.
func close_on_backdrop(on_close: Callable = Callable()) -> void:
	_backdrop_close = on_close if on_close.is_valid() else close


func _on_backdrop_input(event: InputEvent) -> void:
	var down := false
	var up := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		down = event.pressed
		up = not event.pressed
	elif event is InputEventScreenTouch:
		down = event.pressed
		up = not event.pressed
	else:
		return
	if down:
		_backdrop_down = true
		return
	if up and _backdrop_down:
		_backdrop_down = false
		if _backdrop_close.is_valid() and not _busy and not is_queued_for_deletion():
			_backdrop_close.call()


func set_message(value: String) -> void:
	message.text = value
	message.visible = value != ""


## Disables every button while a request runs; afterwards each is enabled again unless it was
## locked (lock_button(): an action that is not possible).
func set_busy(busy: bool) -> void:
	_busy = busy
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
