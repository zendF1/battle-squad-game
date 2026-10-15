extends Control
## The lobby background: assets/env/lobby_bg.png (night sky, glows, stars) stretched over the
## rect and, with `ground`, assets/env/lobby_ground.png (a soft hill with the faint stage ovals)
## over its bottom part. The Home pages use it without the ground. Images via ui/art.gd.

const Art := preload("res://ui/art.gd")

@export var ground := true:
	set(value):
		ground = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_texture_rect(Art.env("lobby_bg"), Rect2(Vector2.ZERO, size), false)
	if ground:
		var top := size.y * Art.LOBBY_GROUND_FROM
		draw_texture_rect(Art.env("lobby_ground"), Rect2(0, top, size.x, size.y - top), false)
