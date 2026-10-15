extends HBoxContainer
## Inline load state for a section: "Đang tải..." while a request runs, the error with a
## "Thử lại" button when it failed, hidden otherwise. Never blocks the rest of the screen.

const Ui := preload("res://ui/ui.gd")

var _label: Label
var _retry: Button
var _on_retry := Callable()


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 16)
	_label = Ui.label("", 22)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(_label)
	_retry = Ui.button("Thử lại", 22)
	_retry.custom_minimum_size = Vector2(160, 60)
	_retry.focus_mode = FOCUS_NONE
	_retry.pressed.connect(_retry_pressed)
	add_child(_retry)
	clear()


func show_loading(value: String = "Đang tải...") -> void:
	visible = true
	_label.text = value
	_label.remove_theme_color_override("font_color")
	_retry.visible = false


func show_error(value: String, on_retry: Callable) -> void:
	visible = true
	_label.text = value
	_label.add_theme_color_override("font_color", Ui.TONES["error"])
	_on_retry = on_retry
	_retry.visible = on_retry.is_valid()


func clear() -> void:
	visible = false
	_label.text = ""
	_retry.visible = false


func text() -> String:
	return _label.text if visible else ""


func _retry_pressed() -> void:
	if _on_retry.is_valid():
		_on_retry.call()
