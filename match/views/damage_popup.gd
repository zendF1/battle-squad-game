extends Label
## Floating number above a player; set text and font color before adding it, frees itself.


func _ready() -> void:
	add_theme_font_size_override("font_size", 30)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size = Vector2(160, 40)
	position -= Vector2(80, 0)
	var t := create_tween()
	t.tween_property(self, "position:y", position.y - 60.0, 0.9)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.3)
	t.tween_callback(queue_free)
