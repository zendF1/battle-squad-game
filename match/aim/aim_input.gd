extends Node2D
## Slingshot aiming (demo match_screen.dart): drag anywhere, release to fire. Dragging down-right
## shoots up-left. Releasing inside the cancel zone around the shooter cancels. Everything here
## is local; nothing touches the network until fire.

signal aim_changed(angle: float, power: float)
signal fire(angle: float, power: float)

const Trajectory := preload("res://match/aim/trajectory_predictor.gd")
const CANCEL_RADIUS := 60.0
const MIN_POWER := 5.0
const BODY_CENTER := Vector2(0, -20)

var enabled := false:
	set(value):
		enabled = value
		if not value:
			_reset()
var shooter_pos := Vector2.ZERO
var terrain
var wind_dir := 0
var wind_power := 0.0

var _dragging := false
var _start := Vector2.ZERO
var _angle := 0.0
var _power := 0.0
var _in_cancel := false
var _line: Line2D


func _ready() -> void:
	_line = Line2D.new()
	_line.width = 4.0
	_line.default_color = Color(1, 1, 1, 0.55)
	add_child(_line)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_start = get_global_mouse_position()
			_update(_start)
		elif _dragging:
			_release()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_update(get_global_mouse_position())
		get_viewport().set_input_as_handled()


func _update(pointer: Vector2) -> void:
	var d := pointer - _start
	_angle = clampf(rad_to_deg(atan2(d.y, -d.x)), 0.0, 180.0)
	_power = clampf(d.length() / 2.0, 0.0, 100.0)
	_in_cancel = pointer.distance_to(shooter_pos + BODY_CENTER) <= CANCEL_RADIUS
	_line.points = Trajectory.predict(shooter_pos, _angle, _power, wind_dir, wind_power, terrain)
	queue_redraw()
	aim_changed.emit(_angle, _power)


func _release() -> void:
	var shoot := _power >= MIN_POWER and not _in_cancel
	var angle := _angle
	var power := _power
	_reset()
	if shoot:
		fire.emit(angle, power)


func _reset() -> void:
	_dragging = false
	_in_cancel = false
	if _line:
		_line.points = PackedVector2Array()
	queue_redraw()


func _draw() -> void:
	if not _dragging:
		return
	var c := shooter_pos + BODY_CENTER
	var color := Color(1, 0.3, 0.3, 0.9) if _in_cancel else Color(1, 1, 1, 0.5)
	draw_arc(c, CANCEL_RADIUS, 0.0, TAU, 48, color, 3.0)
	draw_line(c + Vector2(-14, -14), c + Vector2(14, 14), color, 3.0)
	draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), color, 3.0)
