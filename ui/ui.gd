extends RefCounted
## Small builders for code-built UI.


static func label(text: String, font_size: int = 24) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	return l


static func button(text: String, font_size: int = 28) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(0, 72)
	return b


## Full-rect CenterContainer holding a VBoxContainer; returns the column.
static func center_column(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	center.add_child(col)
	return col


# ── Home shell builders ─────────────────────────────────────────────────────

const TEXT_DIM := Color(1, 1, 1, 0.55)
const TONES := {
	"win": Color(0.35, 0.85, 0.45),
	"loss": Color(1.0, 0.42, 0.42),
	"draw": Color(1.0, 0.75, 0.3),
	"good": Color(0.45, 0.9, 0.55),
	"error": Color(1.0, 0.45, 0.45),
}
# Translucent navy, so the Home backdrop shows through the cards.
const CARD_BG := Color(0.09, 0.11, 0.24, 0.82)
const CARD_SELECTED := Color(0.2, 0.32, 0.6, 0.92)
const TAB_BG := Color(0.07, 0.09, 0.2, 0.8)
const ACCENT := Color(0.24, 0.45, 0.75)


## A left-aligned label (the plain label() centers).
static func text(value: String, font_size: int = 22, color: Color = Color.WHITE) -> Label:
	var l := label(value, font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	return l


static func hbox(separation: int = 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func vbox(separation: int = 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


## A rounded card.
static func card(bg: Color = CARD_BG, padding: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(bg, 14, padding))
	return p


static func set_card_color(p: PanelContainer, bg: Color) -> void:
	var box: StyleBoxFlat = p.get_theme_stylebox("panel")
	box.bg_color = bg


## A circle with a centered letter (avatar).
static func circle(letter: String, diameter: int, bg: Color = Color(0.25, 0.45, 0.7)) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(diameter, diameter)
	p.add_theme_stylebox_override("panel", _box(bg, diameter / 2, 0))
	var l := label(letter, int(diameter * 0.5))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## A thin bar for EXP; ratio 0..1.
static func bar(ratio: float, height: int = 16) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.step = 0.0
	b.value = clampf(ratio, 0.0, 1.0)
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.12), height / 2, 0))
	b.add_theme_stylebox_override("fill", _box(Color(0.35, 0.7, 1.0), height / 2, 0))
	return b


## A vertical scroll area whose content fills its width.
static func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


## A row of toggle buttons that behave as tabs; `on_select(index)` runs on a press. Show the
## selection with select_tab() (set_pressed_no_signal does not release the group's other button).
static func tab_row(names: Array, font_size: int, on_select: Callable, min_height: int = 64) -> Array[Button]:
	var group := ButtonGroup.new()
	var out: Array[Button] = []
	for i in names.size():
		var b := button(str(names[i]), font_size)
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, min_height)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle_style(b, TAB_BG, ACCENT, 10)
		b.pressed.connect(on_select.bind(i))
		out.append(b)
	select_tab(out, 0)
	return out


static func select_tab(tabs: Array[Button], index: int) -> void:
	for i in tabs.size():
		tabs[i].set_pressed_no_signal(i == index)


## Flat colours for a toggle button: `off` normally, `on` while pressed, dimmed when disabled.
static func toggle_style(b: Button, off: Color, on: Color, radius: int = 14) -> void:
	b.add_theme_stylebox_override("normal", _box(off, radius, 8))
	b.add_theme_stylebox_override("hover", _box(off.lightened(0.08), radius, 8))
	b.add_theme_stylebox_override("pressed", _box(on, radius, 8))
	b.add_theme_stylebox_override("hover_pressed", _box(on.lightened(0.06), radius, 8))
	b.add_theme_stylebox_override("disabled", _box(off.darkened(0.25), radius, 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## A short message near the top of `host` that fades out; it replaces the one still showing.
static func toast(host: Control, message: String, seconds: float = 2.0) -> void:
	for c in host.get_children():
		if c.has_meta("toast"):
			c.queue_free()
	var p := card(Color(0.1, 0.12, 0.16, 0.95), 18)
	p.set_meta("toast", true)
	p.add_child(label(message, 26))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.position.y = 24
	host.add_child(p)
	var tween := p.create_tween()
	tween.tween_interval(seconds)
	tween.tween_property(p, "modulate:a", 0.0, 0.3)
	tween.tween_callback(p.queue_free)


static func _box(bg: Color, radius: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	return box
