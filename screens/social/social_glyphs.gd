extends "res://ui/glyph_icon.gd"
## The social pictures, drawn in code in the style of ui/glyph_icon.gd (bright flat shapes in a dark
## rounded outline, a 96 × 96 canvas scaled into the control's square): "friends" (two people, the
## friends page's lobby button), "add_friend" (a person with a green plus: Kết bạn), "remove_friend"
## (a person with a red minus: Xoá bạn), "chat" (a white speech bubble with three dots: the match
## chat button, Nhắn tin), "lock" (a padlock: the Bang hội tab without a guild), "pen" (a pencil:
## Đổi biệt danh), "inbox" / "outbox" (a person with an arrow coming in / going out: the requests
## received / sent), "banner" (a purple pennant on a pole: Mời vào guild).

const SOCIAL_KINDS := ["friends", "add_friend", "remove_friend", "chat", "lock", "pen", "inbox", "outbox", "banner"]
const PERSON := Color(0.42, 0.72, 1.0)
const PERSON_BACK := Color(0.3, 0.5, 0.86)
const PLUS := Color(0.36, 0.86, 0.4)
const MINUS := Color(1.0, 0.36, 0.34)
const BUBBLE := Color(0.97, 0.98, 1.0)
const LOCK := Color(0.98, 0.78, 0.25)
const LOCK_DARK := Color(0.7, 0.72, 0.8)
const PENCIL := Color(1.0, 0.76, 0.24)
const BANNER := Color(0.62, 0.38, 0.92)
const INSET := 0.21 # the picture's margin inside a round button (the drawings reach the canvas' edge)


## A `px` square social picture of `kind` that ignores the mouse.
static func glyph(icon_kind: String, px: int) -> Control:
	var g = load("res://screens/social/social_glyphs.gd").new()
	g.kind = icon_kind
	g.custom_minimum_size = Vector2(px, px)
	g.size = Vector2(px, px)
	g.mouse_filter = MOUSE_FILTER_IGNORE
	g.size_flags_horizontal = SIZE_SHRINK_CENTER
	g.size_flags_vertical = SIZE_SHRINK_CENTER
	return g


## A round button (LobbyUi.round_button()'s look, fill `bg`) with the picture of `kind` on it and
## `tip` as its tooltip.
static func round_button(icon_kind: String, diameter: int, bg: Color, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.tooltip_text = tip
	LobbyUi.style_button(b, bg, diameter / 2, 0, Color(1, 1, 1, 0.85), 3)
	var g := glyph(icon_kind, int(diameter * (1.0 - 2.0 * INSET)))
	g.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var inset := roundf(diameter * INSET)
	g.offset_left = inset
	g.offset_top = inset
	g.offset_right = -inset
	g.offset_bottom = -inset
	g.name = "Glyph"
	b.add_child(g)
	return b


## A pill button with the picture of `kind` and `words` side by side, centred, `h` high (fill `bg`);
## set_words() changes the words (the width follows).
## (`onto`: built on that button instead of a new one.)
static func wide_button(kind: String, words: String, bg: Color, h: int, onto: Button = null) -> Button:
	var b := onto if onto != null else Button.new()
	b.focus_mode = FOCUS_NONE
	b.custom_minimum_size.y = h
	LobbyUi.style_button(b, bg, h / 2, 0, Color(1, 1, 1, 0.85), 3)
	var row := HBoxContainer.new()
	row.name = "Content"
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(row)
	var g := glyph(kind, int(h * 0.66))
	g.name = "Glyph"
	row.add_child(g)
	var l := LobbyUi.text(words, int(h * 0.4), Color.WHITE, true)
	l.name = "Words"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(l)
	row.minimum_size_changed.connect(_fit.bind(b)) # the words' size is known once in the tree
	set_words(b, words)
	return b


static func set_words(b: Button, words: String) -> void:
	var row: HBoxContainer = b.get_node("Content")
	(row.get_node("Words") as Label).text = words
	_fit(b)


static func _fit(b: Button) -> void:
	var row: HBoxContainer = b.get_node("Content")
	b.custom_minimum_size.x = row.get_combined_minimum_size().x + b.custom_minimum_size.y * 0.8


func _draw() -> void:
	if not kind in SOCIAL_KINDS:
		super._draw()
		return
	var s := minf(size.x, size.y) / 96.0
	if s <= 0.0:
		return
	draw_set_transform((size - Vector2(96, 96) * s) / 2.0, 0.0, Vector2(s, s))
	match kind:
		"friends":
			_person(Vector2(16, -4), 0.78, PERSON_BACK)
			_person(Vector2(-12, 8), 0.86, PERSON)
		"add_friend":
			_person(Vector2(-8, 0), 0.95, PERSON)
			_disc_sign(Vector2(70, 66), PLUS, true)
		"remove_friend":
			_person(Vector2(-8, 0), 0.95, PERSON)
			_disc_sign(Vector2(70, 66), MINUS, false)
		"chat":
			_bubble()
		"lock":
			_lock()
		"pen":
			_pen()
		"inbox":
			_person(Vector2(10, 0), 0.9, PERSON)
			_stroke(PackedVector2Array([Vector2(8, 30), Vector2(30, 30)]), PLUS, 8.0)
			_poly(PackedVector2Array([Vector2(26, 18), Vector2(40, 30), Vector2(26, 42)]), PLUS)
		"banner":
			_banner()
		"outbox":
			_person(Vector2(-10, 0), 0.9, PERSON)
			_stroke(PackedVector2Array([Vector2(62, 30), Vector2(80, 30)]), LOCK, 8.0)
			_poly(PackedVector2Array([Vector2(78, 18), Vector2(92, 30), Vector2(78, 42)]), LOCK)


## A person (head over rounded shoulders) of `fill`, moved by `off`, scaled by `k` round the
## canvas centre.
func _person(off: Vector2, k: float, fill: Color) -> void:
	var c := Vector2(48, 48)
	var shoulders := PackedVector2Array()
	for i in 17:
		var t := PI + PI * i / 16.0
		shoulders.append(c + (Vector2(48, 84) + Vector2(cos(t) * 30, sin(t) * 26) - c) * k + off)
	_poly(shoulders, fill)
	var head := c + (Vector2(48, 36) - c) * k + off
	draw_circle(head, 18 * k + W, OUTLINE, true, -1.0, true)
	draw_circle(head, 18 * k, fill, true, -1.0, true)
	draw_circle(head + Vector2(-6, -7) * k, 5 * k, Color(1, 1, 1, 0.45), true, -1.0, true)


## A small disc of `fill` with a white plus (or minus) on it.
func _disc_sign(c: Vector2, fill: Color, plus: bool) -> void:
	draw_circle(c, 20 + W, OUTLINE, true, -1.0, true)
	draw_circle(c, 20, fill, true, -1.0, true)
	_stroke(PackedVector2Array([c - Vector2(10, 0), c + Vector2(10, 0)]), Color.WHITE, 7.0, 0.0)
	if plus:
		_stroke(PackedVector2Array([c - Vector2(0, 10), c + Vector2(0, 10)]), Color.WHITE, 7.0, 0.0)


func _bubble() -> void:
	var body := _rounded(Rect2(10, 14, 76, 56), 20)
	_poly(body, BUBBLE)
	_poly(PackedVector2Array([Vector2(26, 64), Vector2(44, 64), Vector2(20, 84)]), BUBBLE)
	draw_colored_polygon(body, BUBBLE) # over the tail's outline
	for x in [32.0, 48.0, 64.0]:
		draw_circle(Vector2(x, 42), 6.0, OUTLINE, true, -1.0, true)


func _lock() -> void:
	draw_arc(Vector2(48, 40), 20, PI, TAU, 16, OUTLINE, 18.0, true)
	draw_arc(Vector2(48, 40), 20, PI, TAU, 16, LOCK_DARK, 8.0, true)
	_stroke(PackedVector2Array([Vector2(28, 40), Vector2(28, 46)]), LOCK_DARK, 8.0)
	_stroke(PackedVector2Array([Vector2(68, 40), Vector2(68, 46)]), LOCK_DARK, 8.0)
	_poly(_rounded(Rect2(20, 44, 56, 42), 10), LOCK)
	draw_circle(Vector2(48, 60), 6.0, OUTLINE, true, -1.0, true)
	_stroke(PackedVector2Array([Vector2(48, 62), Vector2(48, 74)]), OUTLINE, 5.0, 0.0)


func _pen() -> void:
	_poly(PackedVector2Array([Vector2(22, 66), Vector2(64, 24), Vector2(76, 36), Vector2(34, 78)]), PENCIL)
	_poly(PackedVector2Array([Vector2(64, 24), Vector2(72, 16), Vector2(84, 28), Vector2(76, 36)]), MINUS)
	_poly(PackedVector2Array([Vector2(22, 66), Vector2(34, 78), Vector2(16, 84)]), Color(0.96, 0.86, 0.7))
	draw_colored_polygon(PackedVector2Array([Vector2(16, 84), Vector2(19, 75), Vector2(25, 81)]), OUTLINE)


func _banner() -> void:
	_stroke(PackedVector2Array([Vector2(24, 12), Vector2(24, 86)]), Color(0.86, 0.7, 0.45), 7.0)
	_poly(PackedVector2Array([Vector2(28, 14), Vector2(80, 14), Vector2(80, 58), Vector2(54, 48), Vector2(28, 58)]), BANNER)
	_poly(_star_points(Vector2(54, 32), 11, 5), LOCK, 0.0)
	draw_circle(Vector2(24, 12), 6.0 + W, OUTLINE, true, -1.0, true)
	draw_circle(Vector2(24, 12), 6.0, LOCK, true, -1.0, true)


static func _star_points(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := -PI / 2.0 + PI * i / n
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	return pts
