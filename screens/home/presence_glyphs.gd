extends "res://screens/social/social_glyphs.gd"
## The invite popup's pictures (screens/home/invite_popup.gd), in the style of ui/glyph_icon.gd on its
## 96 × 96 canvas: a player's status, the round mark on a row's head ("idle": a green dot, online
## and free; "in_lobby": two white people on a blue disc, in a party; "in_match": two crossed white
## swords on an orange disc; "offline": a grey dot), and the tabs ("suggest": a person with the
## green online dot, Gợi ý; the social "friends" picture for Bạn bè). Other kinds draw as
## social_glyphs.gd.

const PRESENCE_KINDS := ["idle", "in_lobby", "in_match", "offline", "suggest"]
const ONLINE := Color(0.3, 0.86, 0.42)
const LOBBY := Color(0.28, 0.56, 0.98)
const MATCH := Color(0.98, 0.5, 0.16)
const AWAY := Color(0.52, 0.55, 0.62)


## A `px` square picture of `kind` that ignores the mouse.
static func make_glyph(icon_kind: String, px: int) -> Control:
	var g = load("res://screens/home/presence_glyphs.gd").new()
	g.kind = icon_kind
	g.custom_minimum_size = Vector2(px, px)
	g.size = Vector2(px, px)
	g.mouse_filter = MOUSE_FILTER_IGNORE
	g.size_flags_horizontal = SIZE_SHRINK_CENTER
	g.size_flags_vertical = SIZE_SHRINK_CENTER
	return g


## The status mark of `status` (PartyModel's idle / in_lobby / in_match / offline; idle for any
## other), `px` square.
static func status_mark(status: String, px: int) -> Control:
	var g := make_glyph(status if status in ["idle", "in_lobby", "in_match", "offline"] else "idle", px)
	g.name = "Status"
	return g


func _draw() -> void:
	if not kind in PRESENCE_KINDS:
		super._draw()
		return
	var s := minf(size.x, size.y) / 96.0
	if s <= 0.0:
		return
	draw_set_transform((size - Vector2(96, 96) * s) / 2.0, 0.0, Vector2(s, s))
	match kind:
		"idle":
			_dot(ONLINE)
		"offline":
			_dot(AWAY)
		"in_lobby":
			_dot(LOBBY)
			_person(Vector2(11, -3), 0.46, Color(0.8, 0.87, 1.0))
			_person(Vector2(-9, 3), 0.52, Color.WHITE)
		"in_match":
			_dot(MATCH)
			_blade(false)
			_blade(true)
		"suggest":
			_person(Vector2(-8, 0), 0.95, PERSON)
			draw_circle(Vector2(70, 68), 16 + W, OUTLINE, true, -1.0, true)
			draw_circle(Vector2(70, 68), 16, ONLINE, true, -1.0, true)
			draw_circle(Vector2(65, 63), 5, Color(1, 1, 1, 0.5), true, -1.0, true)


## A round mark of `fill` filling the canvas, outlined, with a highlight.
func _dot(fill: Color) -> void:
	var c := Vector2(48, 48)
	draw_circle(c, 42, OUTLINE, true, -1.0, true)
	draw_circle(c, 42 - W, fill, true, -1.0, true)
	draw_circle(c + Vector2(-14, -16), 9, Color(1, 1, 1, 0.4), true, -1.0, true)


## One of the crossed swords: its blade from a bottom corner to the opposite top corner, a guard
## across it and a short grip (mirrored for the second one).
func _blade(mirror: bool) -> void:
	var f := func(p: Vector2) -> Vector2: return Vector2(96 - p.x, p.y) if mirror else p
	_stroke(PackedVector2Array([f.call(Vector2(34, 62)), f.call(Vector2(70, 26))]), Color.WHITE, 8.0, 0.0)
	_stroke(PackedVector2Array([f.call(Vector2(26, 56)), f.call(Vector2(40, 70))]), Color(1.0, 0.86, 0.4), 6.0, 0.0)
	_stroke(PackedVector2Array([f.call(Vector2(31, 65)), f.call(Vector2(24, 72))]), Color(0.45, 0.25, 0.12), 6.0, 0.0)
