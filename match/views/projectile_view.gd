extends Node2D
## A shell in flight (moved by shot_player.gd): a dark bomb with a highlight and a lit fuse,
## turned along its flight, and a short fading trail of its last positions. Placeholder art.

const TRAIL := 10 # positions kept for the trail
const RADIUS := 7.0

var _trail := PackedVector2Array() # global positions, oldest first
var _dir := Vector2.RIGHT
var _t := 0.0


func _ready() -> void:
	_trail.append(global_position)


func _process(delta: float) -> void:
	_t += delta
	var p := global_position
	if _trail.is_empty() or p.distance_squared_to(_trail[-1]) > 0.25:
		var v := p - _trail[-1] if not _trail.is_empty() else Vector2.ZERO
		if v.length_squared() > 0.01:
			_dir = v.normalized()
		_trail.append(p)
		if _trail.size() > TRAIL:
			_trail.remove_at(0)
	queue_redraw()


func _draw() -> void:
	var n := _trail.size()
	for i in range(1, n):
		var k := float(i) / n
		var a := _trail[i - 1] - global_position
		var b := _trail[i] - global_position
		draw_line(a, b, Color(1.0, 0.85, 0.55, 0.45 * k), 2.0 + 6.0 * k, true)
	# Bomb: dark ball, rim, highlight; the fuse trails behind the flight.
	var back := -_dir
	draw_line(back * RADIUS * 0.8, back * (RADIUS + 5.0), Color(0.5, 0.38, 0.25), 2.5)
	var spark := back * (RADIUS + 6.0)
	var flicker := 0.7 + 0.3 * sin(_t * 40.0)
	draw_circle(spark, 4.5 * flicker, Color(1.0, 0.6, 0.15, 0.6))
	draw_circle(spark, 2.2, Color(1.0, 0.95, 0.6))
	draw_circle(Vector2.ZERO, RADIUS + 1.5, Color(0.02, 0.02, 0.05))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.17, 0.18, 0.24))
	draw_circle(Vector2(-2.2, -2.4), RADIUS * 0.38, Color(1, 1, 1, 0.55))
