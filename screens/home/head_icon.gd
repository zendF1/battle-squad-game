extends Control
## A character's head (its match sprite's, Art.side_head()) in a round frame; the player's initial
## without one. Sized by custom_minimum_size.

const Art := preload("res://ui/art.gd")

var character_id := "":
	set(v):
		character_id = v
		queue_redraw()
var initial := ""
var ring := Color(1, 1, 1, 0.85)


static func make(character: String, letter: String, px: float) -> Control:
	var c = load("res://screens/home/head_icon.gd").new()
	c.character_id = character
	c.initial = letter.left(1).to_upper()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	draw_circle(c, r, ring)
	draw_circle(c, r - 3.0, Color(0.1, 0.16, 0.34))
	var head := Art.side_head(character_id) if character_id != "" else {}
	if not head.is_empty():
		var inner := r - 4.0
		draw_texture_rect_region(head["texture"], Rect2(c - Vector2(inner, inner), Vector2(inner, inner) * 2.0), head["rect"])
	elif initial != "":
		draw_string(get_theme_default_font(), Vector2(0, c.y + r * 0.35), initial, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(r), Color.WHITE)
