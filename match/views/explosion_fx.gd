extends Node2D
## Short flash at an explosion; frees itself.

var radius := 30.0


func _ready() -> void:
	scale = Vector2(0.3, 0.3)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.18)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	t.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.75, 0.3, 0.85))
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 0.95, 0.7, 0.95))
