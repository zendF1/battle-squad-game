extends Node
## Replays one ShotResolved: moves projectile views along the server paths and emits each
## timeline event when its time comes. Driven by frame delta, so it is smooth at any FPS.
## `muzzle` (layer coordinates, set before play()) makes the projectiles that leave near it start
## drawn at the gun's muzzle and blend into the server path over SPAWN_BLEND seconds (visual
## only: the path and its events are unchanged). play(timeline, lead_in) holds the whole replay
## (projectiles hidden, no events) for lead_in seconds first, e.g. while the shooter draws its
## gun: everything shifts together, the timeline's order is unchanged.
## A projectile leaving later (ShotTimeline.launch_time(), the bomb chain, the missiles) stays
## hidden until then; its muzzle blend starts when it leaves. A skill shot's `skill_view`
## (match/views/skills/skill_view.gd, set before play()) may restyle or replace each projectile
## view (projectile_view()) and draws its extras every frame (process()); end() when it stops.

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
## The skill's SkillView for a skill shot (begun by the caller), or null; used by the next play().
var skill_view = null

var _timeline
var _t := 0.0
var _views: Array = []
var _spawn_offsets: Array = [] # per projectile: muzzle - path start (or zero)
var _launch: Array = [] # per projectile: when it leaves
var _skill_view = null


func is_playing() -> bool:
	return _timeline != null


func play(timeline, lead_in: float = 0.0) -> void:
	stop()
	_timeline = timeline
	_t = -maxf(0.0, lead_in)
	_spawn_offsets.clear()
	_launch.clear()
	_skill_view = skill_view
	skill_view = null
	for i in timeline.projectiles.size():
		var launch: float = timeline.launch_time(i)
		_launch.append(launch)
		var offset := Vector2.ZERO
		if muzzle is Vector2:
			offset = muzzle - timeline.sample(i, launch)
			if offset.length() > SPAWN_NEAR:
				offset = Vector2.ZERO
		_spawn_offsets.append(offset)
		var view: Node2D = ProjectileView.new()
		view.kind = str(style.get("kind", ""))
		view.tier = str(style.get("tier", ""))
		view.skill = bool(style.get("skill", false))
		view.item = str(style.get("item", ""))
		view.heading = timeline.start_velocity(i)
		if _skill_view != null:
			var other = _skill_view.projectile_view(i, timeline.projectiles[i], view)
			if other != view:
				view.free()
				view = other
		view.position = timeline.sample(i, launch) + _spawn_offsets[i]
		view.visible = _t >= launch
		layer.add_child(view)
		_views.append(view)
	muzzle = null


## When projectile i leaves (s since the shot).
func launch_time(i: int) -> float:
	return _launch[i] if i < _launch.size() else 0.0


## How far projectile i is drawn off its path at time t: the muzzle offset easing out from its
## launch.
func spawn_offset(i: int, t: float) -> Vector2:
	if i >= _spawn_offsets.size():
		return Vector2.ZERO
	t -= launch_time(i)
	var k := clampf(1.0 - t / SPAWN_BLEND, 0.0, 1.0)
	return _spawn_offsets[i] * k * k


## How fast projectile i's drawn offset changes at time t (px/s): the muzzle offset's ease.
func spawn_offset_rate(i: int, t: float) -> Vector2:
	t -= launch_time(i)
	if i >= _spawn_offsets.size() or t >= SPAWN_BLEND or t < 0.0:
		return Vector2.ZERO
	var k := clampf(1.0 - t / SPAWN_BLEND, 0.0, 1.0)
	return _spawn_offsets[i] * (-2.0 * k / SPAWN_BLEND)


## Drops the replay without emitting the remaining events (a full snapshot replaces it).
func stop() -> void:
	for view in _views:
		if is_instance_valid(view):
			view.queue_free()
	_views.clear()
	_timeline = null
	if _skill_view != null:
		var v = _skill_view
		_skill_view = null
		v.end()


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
		if _t < launch_time(i):
			continue # not launched yet
		view.visible = true
		if _t >= _timeline.projectile_end(i):
			view.queue_free()
			_views[i] = null
		else:
			view.position = _timeline.sample(i, _t) + spawn_offset(i, _t)
			if view.has_method("set_tangent"):
				view.set_tangent(_timeline.velocity(i, _t) + spawn_offset_rate(i, _t)) # the nose follows the curve
	if _skill_view != null:
		_skill_view.process(_t)
	var timeline = _timeline
	for event in timeline.pop_due(_t):
		event_due.emit(event)
		if _timeline != timeline:
			return # a handler stopped or replaced the replay
	if _t >= _timeline.duration:
		stop()
		finished.emit()
