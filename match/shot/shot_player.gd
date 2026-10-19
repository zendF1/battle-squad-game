extends Node
## Replays one ShotResolved: moves projectile views along the server paths and emits each
## timeline event when its time comes. Driven by frame delta, so it is smooth at any FPS.
## `muzzle` (layer coordinates, set before play()) makes the projectiles that leave near it start
## drawn at the gun's muzzle and blend into the server path over SPAWN_BLEND seconds (visual
## only: the path and its events are unchanged). play(timeline, lead_in) holds the whole replay
## (projectiles hidden, no events) for lead_in seconds first, e.g. while the shooter draws its
## gun: everything shifts together, the timeline's order is unchanged.

signal event_due(event: Dictionary)
signal finished

const ProjectileView := preload("res://match/views/projectile_view.gd")
const SPAWN_BLEND := 0.15 # s
const SPAWN_NEAR := 90.0 # px: a path starting farther from the muzzle (air strike) is not moved

var layer: Node2D
## How this shot's projectiles look: ShotLook.style_for() {kind, tier, skill, item}; set before play().
var style := {}
## Where the shooter's gun muzzle is (layer coordinates), or null; used by the next play() only.
var muzzle: Variant = null

var _timeline
var _t := 0.0
var _views: Array = []
var _spawn_offsets: Array = [] # per projectile: muzzle - path start (or zero)


func is_playing() -> bool:
	return _timeline != null


func play(timeline, lead_in: float = 0.0) -> void:
	stop()
	_timeline = timeline
	_t = -maxf(0.0, lead_in)
	_spawn_offsets.clear()
	for i in timeline.projectiles.size():
		var offset := Vector2.ZERO
		if muzzle is Vector2:
			offset = muzzle - timeline.sample(i, 0.0)
			if offset.length() > SPAWN_NEAR:
				offset = Vector2.ZERO
		_spawn_offsets.append(offset)
		var view := ProjectileView.new()
		view.kind = str(style.get("kind", ""))
		view.tier = str(style.get("tier", ""))
		view.skill = bool(style.get("skill", false))
		view.item = str(style.get("item", ""))
		view.heading = timeline.start_velocity(i)
		view.position = timeline.sample(i, 0.0) + _spawn_offsets[i]
		view.visible = _t >= 0.0
		layer.add_child(view)
		_views.append(view)
	muzzle = null


## How far projectile i is drawn off its path at time t: the muzzle offset easing out.
func spawn_offset(i: int, t: float) -> Vector2:
	if i >= _spawn_offsets.size():
		return Vector2.ZERO
	var k := clampf(1.0 - t / SPAWN_BLEND, 0.0, 1.0)
	return _spawn_offsets[i] * k * k


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
	if _t < 0.0:
		return # the lead-in: the shooter is still drawing
	for i in _views.size():
		var view = _views[i]
		if view == null:
			continue
		view.visible = true
		if _t >= _timeline.projectile_end(i):
			view.queue_free()
			_views[i] = null
		else:
			view.position = _timeline.sample(i, _t) + spawn_offset(i, _t)
	var timeline = _timeline
	for event in timeline.pop_due(_t):
		event_due.emit(event)
		if _timeline != timeline:
			return # a handler stopped or replaced the replay
	if _t >= _timeline.duration:
		stop()
		finished.emit()
