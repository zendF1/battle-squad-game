extends Label
## Floating number above a player; set text and font color before adding it, frees itself.
## Bold with a dark outline; it pops in, rises and fades.

const LobbyUi := preload("res://ui/lobby_ui.gd")


func _ready() -> void:
	add_theme_font_size_override("font_size", 34)
	add_theme_font_override("font", LobbyUi.bold())
	add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08, 0.95))
	add_theme_constant_override("outline_size", 9)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size = Vector2(200, 44)
	position -= Vector2(100, 0)
	pivot_offset = size / 2
	scale = Vector2(0.5, 0.5)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.1)
	t.parallel().tween_property(self, "position:y", position.y - 60.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.45)
	t.tween_callback(queue_free)
