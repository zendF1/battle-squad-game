extends Node2D
## Slingshot aiming (demo match_screen.dart): drag anywhere, release to fire. Dragging down-right
## shoots up-left. Releasing inside the cancel zone around the shooter cancels. Everything here
## is local; nothing touches the network until fire. The preview draws one arc per entry of
## preview_offsets (degrees added to the aimed angle), e.g. three for triple_shot.
##
## target_column (air_strike): no slingshot; while pressed, a vertical target line follows the
## pointer and the preview is the drop from the top of the map at that x (the server fires it at
## Items.TARGET_X_ANGLE / TARGET_X_POWER from y 0). Release emits fire_column(x); the cancel zone
## still cancels.

signal aim_changed(angle: float, power: float)
signal fire(angle: float, power: float)
signal fire_column(target_x: float)

const Trajectory := preload("res://match/aim/trajectory_predictor.gd")
const Items := preload("res://match/items.gd")
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
var preview_offsets: Array = [0.0]:
	set(value):
		preview_offsets = value
		_ensure_lines()
		if _dragging:
			_update(_pointer)

var target_column := false:
	set(value):
		if value != target_column:
			_reset() # a drag started in the other mode does not carry over
		target_column = value

var _dragging := false
var _start := Vector2.ZERO
var _angle := 0.0
var _power := 0.0
var _in_cancel := false
var _pointer := Vector2.ZERO
var _column_x := 0.0
var _lines: Array[Line2D] = [] # reused; grows to the largest preview_offsets seen


func _ready() -> void:
	_ensure_lines()


func _ensure_lines() -> void:
	if not is_inside_tree():
		return
	while _lines.size() < preview_offsets.size():
		var line := Line2D.new()
		line.width = 4.0
		line.default_color = Color(1, 1, 1, 0.55)
		add_child(line)
		_lines.append(line)


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
	_pointer = pointer
	_in_cancel = pointer.distance_to(shooter_pos + BODY_CENTER) <= CANCEL_RADIUS
	if target_column:
		_update_column(pointer)
		return
	var d := pointer - _start
	_angle = clampf(rad_to_deg(atan2(d.y, -d.x)), 0.0, 180.0)
	_power = clampf(d.length() / 2.0, 0.0, 100.0)
	for i in _lines.size():
		if i < preview_offsets.size():
			_lines[i].points = Trajectory.predict(shooter_pos, _angle + float(preview_offsets[i]), _power, wind_dir, wind_power, terrain)
		elif not _lines[i].points.is_empty():
			_lines[i].points = PackedVector2Array()
	queue_redraw()
	aim_changed.emit(_angle, _power)


func _update_column(pointer: Vector2) -> void:
	_column_x = pointer.x
	if terrain != null:
		_column_x = clampf(_column_x, 0.0, float(terrain.width)) # the server clamps it the same way
	for i in _lines.size():
		_lines[i].points = Trajectory.predict(Vector2(_column_x, 0.0), Items.TARGET_X_ANGLE, Items.TARGET_X_POWER,
			wind_dir, wind_power, terrain) if i == 0 else PackedVector2Array()
	queue_redraw()


func _release() -> void:
	if target_column:
		var x := _column_x
		var cancel := _in_cancel
		_reset()
		if not cancel:
			fire_column.emit(x)
		return
	var shoot := _power >= MIN_POWER and not _in_cancel
	var angle := _angle
	var power := _power
	_reset()
	if shoot:
		fire.emit(angle, power)


func _reset() -> void:
	_dragging = false
	_in_cancel = false
	for line in _lines:
		line.points = PackedVector2Array()
	queue_redraw()


func _draw() -> void:
	if not _dragging:
		return
	var c := shooter_pos + BODY_CENTER
	var color := Color(1, 0.3, 0.3, 0.9) if _in_cancel else Color(1, 1, 1, 0.5)
	draw_arc(c, CANCEL_RADIUS, 0.0, TAU, 48, color, 3.0)
	draw_line(c + Vector2(-14, -14), c + Vector2(14, 14), color, 3.0)
	draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), color, 3.0)
	if target_column and not _in_cancel:
		var bottom := float(terrain.height) if terrain != null else 2000.0
		draw_line(Vector2(_column_x, 0.0), Vector2(_column_x, bottom), Color(1, 0.85, 0.2, 0.8), 3.0)
