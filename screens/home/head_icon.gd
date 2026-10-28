extends Control
## A character's head in a round frame: its match sprite's (Art.side_head()), or with `lobby` the
## head of the lobby picture (Art.lobby_head(): the avatars of the leaderboard and the profile,
## the side view's when it has no lobby picture); the player's initial without one. Sized by
## custom_minimum_size.

const Art := preload("res://ui/art.gd")

var character_id := "":
	set(v):
		character_id = v
		queue_redraw()
var initial := ""
var ring := Color(1, 1, 1, 0.85):
	set(v):
		ring = v
		queue_redraw()
## The lobby picture's head (Art.lobby_head()) instead of the match sprite's.
var lobby := false
## The ring's width (px).
var ring_width := 3.0


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
	draw_circle(c, r, ring, true, -1.0, true)
	var inner := r - ring_width
	draw_circle(c, inner, Color(0.1, 0.16, 0.34), true, -1.0, true)
	var head := {}
	if character_id != "":
		head = Art.lobby_head(character_id) if lobby else {}
		if head.is_empty():
			head = Art.side_head(character_id)
	if not head.is_empty():
		_draw_round(head["texture"], head["rect"], c, inner - 1.0)
	elif initial != "":
		draw_string(get_theme_default_font(), Vector2(0, c.y + r * 0.35), initial, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(r), Color.WHITE)


## The texture's `region` in a circle of radius `rad` round `c` (a polygon fan: uvs from the region).
func _draw_round(tex: Texture2D, region: Rect2, c: Vector2, rad: float) -> void:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var tsize := tex.get_size()
	for i in 48:
		var d := Vector2.from_angle(TAU * i / 48.0)
		pts.append(c + d * rad)
		uvs.append((region.position + region.size * (d * 0.5 + Vector2(0.5, 0.5))) / tsize)
	draw_colored_polygon(pts, Color.WHITE, uvs, tex)
