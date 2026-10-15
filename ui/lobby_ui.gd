extends RefCounted
## Builders for the lobby look (screens/home): translucent dark panels and pills, outlined text
## that reads on the night-sky backdrop, round icon buttons with a caption, and the big yellow
## start button.

const Ui := preload("res://ui/ui.gd")

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


## The Home theme: plain buttons (the Profile / Shop pages, dialogs) as rounded translucent blue.
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		var bg := Color(0.2, 0.34, 0.66, 0.9)
		_theme.set_stylebox("normal", "Button", box(bg, 14, 8, Color(1, 1, 1, 0.12), 2))
		_theme.set_stylebox("hover", "Button", box(bg.lightened(0.12), 14, 8, Color(1, 1, 1, 0.2), 2))
		_theme.set_stylebox("pressed", "Button", box(bg.darkened(0.2), 14, 8, Color(1, 1, 1, 0.12), 2))
		_theme.set_stylebox("hover_pressed", "Button", box(bg.darkened(0.15), 14, 8, Color(1, 1, 1, 0.12), 2))
		_theme.set_stylebox("disabled", "Button", box(Color(0.12, 0.15, 0.3, 0.6), 14, 8))
		_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
		_theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	return _theme


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


## A translucent dark rounded panel.
static func panel(padding: int = 16, radius: int = 18, bg: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
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


## A round button with an icon (emoji / symbol), a coloured fill and a light outline.
static func round_button(icon: String, diameter: int, bg: Color, font_size: int = 0) -> Button:
	var b := Button.new()
	b.text = icon
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.add_theme_font_size_override("font_size", font_size if font_size > 0 else int(diameter * 0.46))
	style_button(b, bg, diameter / 2, 0, Color(1, 1, 1, 0.85), 3)
	return b


## A round icon button with a small outlined caption under it (the right column).
static func icon_button(icon: String, caption: String, bg: Color, on_press: Callable, diameter: int = 76) -> VBoxContainer:
	var col := Ui.vbox(2)
	var b := round_button(icon, diameter, bg)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_press)
	col.add_child(b)
	var l := text(caption, 20, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return col


## A dark pill-shaped button with an icon and a label ("👤 Nhân vật").
static func pill_button(value: String, font_size: int = 24, height: int = 60) -> Button:
	var b := Button.new()
	b.text = value
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
	b.add_theme_stylebox_override("normal", _gold(GOLD, 8))
	b.add_theme_stylebox_override("hover", _gold(GOLD.lightened(0.15), 8))
	b.add_theme_stylebox_override("pressed", _gold(GOLD.darkened(0.08), 3))
	b.add_theme_stylebox_override("hover_pressed", _gold(GOLD.darkened(0.04), 3))
	b.add_theme_stylebox_override("disabled", _gold(Color(0.6, 0.55, 0.4), 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	return b


static func _gold(bg: Color, lip: int) -> StyleBoxFlat:
	var b := box(bg, 22, 10, GOLD_DARK, 3)
	b.border_width_bottom = lip
	b.shadow_color = Color(1.0, 0.7, 0.2, 0.35)
	b.shadow_size = 10
	return b
