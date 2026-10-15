extends RefCounted
## Builders for the lobby look (screens/home): translucent dark panels and pills, outlined text
## that reads on the night-sky backdrop, round icon buttons with a caption, and the big yellow
## start button. Panels, pills and the main buttons are 9-patch images from assets/ui/ and the
## icons images from assets/icons/ (ui/art.gd); other colours stay StyleBoxFlat.

const Ui := preload("res://ui/ui.gd")
const Art := preload("res://ui/art.gd")

const PANEL := Color(0.04, 0.06, 0.16, 0.62)
const PANEL_BORDER := Color(1, 1, 1, 0.1)
const GOLD := Color(1.0, 0.8, 0.22)
const GOLD_DARK := Color(0.85, 0.45, 0.08)
const TEXT_DARK := Color(0.24, 0.13, 0.02)
const ICON_COLORS := {
	"blue": Color(0.22, 0.48, 0.92),
	"orange": Color(0.95, 0.55, 0.18),
	"purple": Color(0.55, 0.36, 0.88),
	"green": Color(0.25, 0.68, 0.42),
}

static var _bold: FontVariation
static var _theme: Theme


## The default font, heavier (titles, the start button).
static func bold() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.7
	return _bold


## The Home theme: plain buttons (the Profile / Shop pages, dialogs) as rounded translucent blue
## (assets/ui/button_navy.png, button_disabled.png).
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		for state in BUTTON_STATES:
			_theme.set_stylebox(state, "Button", _state_box("button_navy", state, 8))
		_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
		_theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
		_theme.set_constant("icon_max_width", "Button", 36)
	return _theme


const BUTTON_STATES := ["normal", "hover", "pressed", "hover_pressed", "disabled"]
## How a 9-patch button looks per state: lighter on hover, darker while pressed.
const STATE_TINT := {"normal": Color(1, 1, 1), "hover": Color(1.15, 1.15, 1.15), "pressed": Color(0.8, 0.8, 0.82),
	"hover_pressed": Color(0.88, 0.88, 0.9)}


static func _state_box(box_name: String, state: String, padding: int) -> StyleBox:
	if state == "disabled":
		return Art.ui_box("button_disabled", padding)
	return Art.ui_box(box_name, padding, STATE_TINT[state])


## Styles b with a 9-patch from assets/ui/ (button_navy, button_orange, pill, panel ...): lighter
## on hover, darker while pressed, button_disabled when disabled (keep_disabled: the box itself,
## dimmed).
static func texture_button(b: Button, box_name: String, padding: int = 8, keep_disabled: bool = false) -> void:
	for state in BUTTON_STATES:
		b.add_theme_stylebox_override(state, _state_box(box_name, state, padding))
	if keep_disabled:
		b.add_theme_stylebox_override("disabled", Art.ui_box(box_name, padding, Color(1, 1, 1, 0.5)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE


## An icon image (assets/icons/<name>.png, or a texture) at size x size px.
static func icon(source: Variant, px: int = 32) -> TextureRect:
	var t := TextureRect.new()
	t.texture = source if source is Texture2D else Art.icon(str(source))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## An icon followed by an outlined label, added to parent in a row; returns the label.
static func icon_text(parent: Node, source: Variant, value: String, font_size: int = 22, color: Color = Color.WHITE,
		heavy: bool = false, px: int = 0) -> Label:
	var row := Ui.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon(source, px if px > 0 else int(font_size * 1.2)))
	var l := text(value, font_size, color, heavy)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	parent.add_child(row)
	return l


## Puts an icon (assets/icons/<name>.png) on a button, at most px wide.
static func set_icon(b: Button, icon_name: String, px: int = 32) -> void:
	b.icon = Art.icon(icon_name)
	b.add_theme_constant_override("icon_max_width", px)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## A left-aligned label with a dark outline.
static func text(value: String, font_size: int = 22, color: Color = Color.WHITE, heavy: bool = false) -> Label:
	var l := Ui.text(value, font_size, color)
	outline(l, maxi(4, font_size / 6))
	if heavy:
		l.add_theme_font_override("font", bold())
	return l


static func outline(l: Control, width: int = 4) -> void:
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.08, 0.85))
	l.add_theme_constant_override("outline_size", width)


## A translucent dark rounded panel (assets/ui/panel.png); another bg colour is a flat box.
static func panel(padding: int = 16, radius: int = 18, bg: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	if bg == PANEL:
		p.add_theme_stylebox_override("panel", Art.ui_box("panel", padding))
	else:
		p.add_theme_stylebox_override("panel", box(bg, radius, padding, PANEL_BORDER, 2))
	return p


static func box(bg: Color, radius: int, padding: int, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(padding)
	b.anti_aliasing = true
	if border_width > 0:
		b.border_color = border
		b.set_border_width_all(border_width)
	return b


## Flat styles for a button: normal, hover (lighter), pressed (darker), disabled (dim).
static func style_button(b: Button, bg: Color, radius: int, padding: int = 8, border: Color = Color.TRANSPARENT, border_width: int = 0) -> void:
	b.add_theme_stylebox_override("normal", box(bg, radius, padding, border, border_width))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.12), radius, padding, border, border_width))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.2), radius, padding, border, border_width))
	b.add_theme_stylebox_override("hover_pressed", box(bg.darkened(0.15), radius, padding, border, border_width))
	b.add_theme_stylebox_override("disabled", box(Color(bg, bg.a * 0.5), radius, padding, border, border_width))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE


## A round button with an icon (assets/icons/<icon_name>.png), a coloured fill and a light
## outline. icon_scale: the icon's width as a part of the diameter.
static func round_button(icon_name: String, diameter: int, bg: Color, icon_scale: float = 0.55) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	set_icon(b, icon_name, int(diameter * icon_scale))
	b.set_meta("icon_name", icon_name)
	style_button(b, bg, diameter / 2, 0, Color(1, 1, 1, 0.85), 3)
	return b


## A round icon button with a small outlined caption under it (the right column).
static func icon_button(icon_name: String, caption: String, bg: Color, on_press: Callable, diameter: int = 76) -> VBoxContainer:
	var col := Ui.vbox(2)
	var b := round_button(icon_name, diameter, bg, 0.62)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_press)
	col.add_child(b)
	var l := text(caption, 20, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return col


## A pill-shaped button with an optional icon (assets/icons/<icon_name>.png) and a label,
## transparent until hovered.
static func pill_button(value: String, font_size: int = 24, height: int = 60, icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = value
	if icon_name != "":
		set_icon(b, icon_name, int(font_size * 1.1))
		b.add_theme_constant_override("h_separation", 10)
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_font_override("font", bold())
	style_button(b, Color(1, 1, 1, 0.0), height / 2, 18)
	b.add_theme_stylebox_override("hover", box(Color(1, 1, 1, 0.1), height / 2, 18))
	b.add_theme_stylebox_override("pressed", box(Color(1, 1, 1, 0.18), height / 2, 18))
	return b


## The big yellow start button: dark heavy text, a darker orange lip at the bottom.
static func start_button(value: String) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size = Vector2(0, 96)
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_font_override("font", bold())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, TEXT_DARK)
	b.add_theme_color_override("font_disabled_color", Color(TEXT_DARK, 0.5))
	b.add_theme_stylebox_override("normal", _gold("button_primary", Color.WHITE))
	b.add_theme_stylebox_override("hover", _gold("button_primary", Color(1.1, 1.1, 1.1)))
	b.add_theme_stylebox_override("pressed", _gold("button_primary_pressed", Color.WHITE))
	b.add_theme_stylebox_override("hover_pressed", _gold("button_primary_pressed", Color(1.05, 1.05, 1.05)))
	b.add_theme_stylebox_override("disabled", _gold("button_primary", Color(0.62, 0.6, 0.55)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	return b


## The gold 9-patch (assets/ui/button_primary*.png); the text sits a little higher than the lip.
static func _gold(box_name: String, tint: Color) -> StyleBoxTexture:
	var b := Art.ui_box(box_name, 10, tint)
	b.content_margin_bottom = 14 if box_name == "button_primary" else 9
	b.content_margin_top = 10 if box_name == "button_primary" else 15
	return b
