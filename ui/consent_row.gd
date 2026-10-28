extends Control
## The terms tick under the login buttons (screens/login.gd): a white check box and "Tôi đồng ý với
## Điều khoản dịch vụ và Chính sách bảo mật", the two names links to `terms_url` / `privacy_url`
## (Config). nudge() shakes the row and flashes the box red: a login tapped while it is not ticked.
## The row is `width` wide (the buttons' width), the text wrapping beside the box.

signal toggled(on: bool)

const LobbyUi := preload("res://ui/lobby_ui.gd")

const BOX_PX := 32
const HIT_PX := 48
const GAP := 6
const FONT_SIZE := 20
const LINK := Color(1.0, 0.86, 0.3)
const NAVY := Color(0.09, 0.14, 0.38)
const CHECK := Color(0.2, 0.68, 0.32)
const ALERT := Color(1.0, 0.25, 0.2)

var accepted := false
var terms_url := ""
var privacy_url := ""
## 0..1: how red the box is (nudge()).
var alert := 0.0:
	set(value):
		alert = value
		if _box != null:
			_box.queue_redraw()

var _row: HBoxContainer
var _box: Button
var _text: RichTextLabel
var _shake: Tween


func _init(width: float = 400.0, on: bool = false, terms: String = "", privacy: String = "") -> void:
	accepted = on
	terms_url = terms
	privacy_url = privacy
	name = "Consent"
	mouse_filter = MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", GAP)
	_row.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_row)
	_box = Button.new()
	_box.name = "Box"
	_box.toggle_mode = true
	_box.button_pressed = on
	_box.focus_mode = FOCUS_NONE
	_box.custom_minimum_size = Vector2(HIT_PX, HIT_PX)
	_box.size_flags_vertical = SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		_box.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_box.draw.connect(_draw_box)
	_box.toggled.connect(_on_toggled)
	_row.add_child(_box)
	_text = RichTextLabel.new()
	_text.name = "Text"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(width - HIT_PX - GAP, 0)
	_text.size_flags_vertical = SIZE_SHRINK_CENTER
	_text.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_text.add_theme_font_override("normal_font", LobbyUi.bold())
	_text.add_theme_color_override("default_color", Color.WHITE)
	_text.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.14, 0.9))
	_text.add_theme_constant_override("outline_size", 5)
	_text.text = "Tôi đồng ý với %s và %s" % [_link("terms", "Điều khoản dịch vụ"), _link("privacy", "Chính sách bảo mật")]
	_text.meta_clicked.connect(_on_link)
	_row.add_child(_text)
	_row.resized.connect(_fit)
	_fit()


func _ready() -> void:
	_fit()


static func _link(meta: String, label: String) -> String:
	return "[url=%s][color=#%s]%s[/color][/url]" % [meta, LINK.to_html(false), label]


## The URL a link opens ("terms" / "privacy").
func url_for(meta: String) -> String:
	return terms_url if meta == "terms" else privacy_url


func set_accepted(on: bool) -> void:
	_box.button_pressed = on


## Shakes the row and flashes the box red.
func nudge() -> void:
	if _shake != null and _shake.is_valid():
		_shake.kill()
	_shake = create_tween()
	for dx in [-14.0, 12.0, -9.0, 6.0, -3.0, 0.0]:
		_shake.tween_property(_row, "position:x", dx, 0.05)
	alert = 1.0
	var flash := create_tween()
	flash.tween_interval(0.5)
	flash.tween_property(self, "alert", 0.0, 0.6)


func _fit() -> void:
	var min_size := _row.get_combined_minimum_size()
	custom_minimum_size = min_size
	_row.size = min_size


func _on_toggled(on: bool) -> void:
	accepted = on
	_box.queue_redraw()
	if on:
		alert = 0.0
	toggled.emit(on)


func _on_link(meta: Variant) -> void:
	var url := url_for(str(meta))
	if url != "":
		OS.shell_open(url)


func _draw_box() -> void:
	var r := Rect2((_box.size - Vector2(BOX_PX, BOX_PX)) / 2.0, Vector2(BOX_PX, BOX_PX))
	if alert > 0.0:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(ALERT, 0.45 * alert)
		glow.set_corner_radius_all(12)
		glow.anti_aliasing = true
		_box.draw_style_box(glow, r.grow(7))
	var b := StyleBoxFlat.new()
	b.bg_color = Color.WHITE
	b.set_corner_radius_all(8)
	b.anti_aliasing = true
	b.border_color = NAVY.lerp(ALERT, alert)
	b.set_border_width_all(3)
	b.shadow_color = Color(0.02, 0.05, 0.16, 0.3)
	b.shadow_size = 4
	b.shadow_offset = Vector2(0, 2)
	_box.draw_style_box(b, r)
	if accepted:
		var p := r.position
		var k := BOX_PX
		var tick := PackedVector2Array([p + Vector2(0.22, 0.52) * k, p + Vector2(0.42, 0.72) * k, p + Vector2(0.8, 0.28) * k])
		_box.draw_polyline(tick, CHECK, 5.0, true)
