extends Control
## A modal dialog drawn over the whole screen: a dim backdrop that eats input and a centered
## card with a title, a body and a row of buttons. Built in code instead of AcceptDialog so it
## uses the phone-sized fonts. close() frees it.

const Ui := preload("res://ui/ui.gd")

var body: VBoxContainer
var message: Label # an inline error/status line under the body
var _buttons: HBoxContainer


## Builds the dialog and adds it to `host` (the screen root): `var m := Modal.new(); m.open(...)`.
func open(host: Node, title: String, width: int = 720) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var card := Ui.card(Color(0.13, 0.15, 0.2), 28)
	card.custom_minimum_size.x = width
	center.add_child(card)
	var col := Ui.vbox(18)
	card.add_child(col)
	col.add_child(Ui.label(title, 32))
	body = Ui.vbox(14)
	col.add_child(body)
	message = Ui.label("", 22)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", Ui.TONES["error"])
	message.visible = false
	col.add_child(message)
	_buttons = Ui.hbox(20)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_buttons)
	host.add_child(self)


## A body paragraph.
func add_text(value: String, font_size: int = 26) -> Label:
	var l := Ui.label(value, font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(l)
	return l


func add_button(text: String, on_press: Callable) -> Button:
	var b := Ui.button(text, 28)
	b.custom_minimum_size = Vector2(240, 84)
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(on_press)
	_buttons.add_child(b)
	return b


func set_message(value: String) -> void:
	message.text = value
	message.visible = value != ""


## Disables or enables every button (while the request runs).
func set_busy(busy: bool) -> void:
	for b in _buttons.get_children():
		(b as Button).disabled = busy


func close() -> void:
	queue_free()
