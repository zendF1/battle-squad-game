extends Node2D
## A summoned minion's arrival: a bright ring bursting out, a flash and a few stars flying off in
## its colour, then gone (about LIFE s). Visual only.

const LIFE := 0.7
const STARS := 8

var color := Color(1.0, 0.8, 0.4)
var radius := 46.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var ease_k := 1.0 - pow(1.0 - k, 3.0)
	var fade := 1.0 - k
	draw_circle(Vector2.ZERO, radius * 0.6 * (1.0 - k), Color(1, 1, 1, 0.7 * fade))
	draw_arc(Vector2.ZERO, radius * ease_k, 0.0, TAU, 40, Color(color, fade), 6.0 * fade + 1.0, true)
	draw_arc(Vector2.ZERO, radius * 0.7 * ease_k, 0.0, TAU, 32, Color(1, 1, 1, 0.6 * fade), 3.0, true)
	for i in STARS:
		var a := TAU * i / STARS + 0.3
		var p := Vector2(cos(a), sin(a)) * radius * 1.3 * ease_k
		var s := 6.0 * fade
		var pts := PackedVector2Array()
		for j in 8:
			var b := TAU * j / 8.0
			pts.append(p + Vector2(cos(b), sin(b)) * (s if j % 2 == 0 else s * 0.4))
		draw_colored_polygon(pts, Color(color.lightened(0.4), fade))
