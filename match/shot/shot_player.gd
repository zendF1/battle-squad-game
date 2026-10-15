extends Node
## Replays one ShotResolved: moves projectile views along the server paths and emits each
## timeline event when its time comes. Driven by frame delta, so it is smooth at any FPS.

signal event_due(event: Dictionary)
signal finished

const ProjectileView := preload("res://match/views/projectile_view.gd")

var layer: Node2D

var _timeline
var _t := 0.0
var _views: Array = []


func is_playing() -> bool:
	return _timeline != null


func play(timeline) -> void:
	stop()
	_timeline = timeline
	_t = 0.0
	for i in timeline.projectiles.size():
		var view := ProjectileView.new()
		view.position = timeline.sample(i, 0.0)
		layer.add_child(view)
		_views.append(view)


## Drops the replay without emitting the remaining events (a full snapshot replaces it).
func stop() -> void:
	for view in _views:
		if is_instance_valid(view):
			view.queue_free()
	_views.clear()
	_timeline = null


func _process(delta: float) -> void:
	if _timeline == null:
		return
	_t += delta
	for i in _views.size():
		var view = _views[i]
		if view == null:
			continue
		if _t >= _timeline.projectile_end(i):
			view.queue_free()
			_views[i] = null
		else:
			view.position = _timeline.sample(i, _t)
	for event in _timeline.pop_due(_t):
		event_due.emit(event)
		if _timeline == null:
			return
	if _t >= _timeline.duration:
		stop()
		finished.emit()
