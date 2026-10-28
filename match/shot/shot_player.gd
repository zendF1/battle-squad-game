extends Node
## Replays one ShotResolved: moves projectile views along the server paths and emits each
## timeline event when its time comes. Driven by frame delta, so it is smooth at any FPS.
## `muzzle` (layer coordinates, set before play()) makes the projectiles that leave near it start
## drawn at the gun's muzzle and blend into the server path (spawn_offset(); visual only: the
## path and its events are unchanged). The nose always follows the server path's tangent, never
## the blend's own motion (that swung it by up to ~70° and back on a slow shot).
## play(timeline, lead_in) holds the whole replay (projectiles hidden, no events) for lead_in
## seconds first, e.g. while the shooter draws its gun: everything shifts together, the
## timeline's order is unchanged.
## A projectile leaving later (ShotTimeline.launch_time(), the bomb chain, the missiles) stays
## hidden until then; its muzzle blend starts when it leaves. A skill shot's `skill_view`
## (match/views/skills/skill_view.gd, set before play()) may restyle or replace each projectile
## view (projectile_view()) and draws its extras every frame (process()); end() when it stops.
## `fired` is emitted once per replay when the lead-in is over (the shot leaves the gun: replay
## time 0), before that frame's events.

signal event_due(event: Dictionary)
signal fired
signal finished

const ProjectileView := preload("res://match/views/projectile_view.gd")
const UnitShell := preload("res://match/views/unit_shell.gd")
## The muzzle blend: an ease with no jump in speed at either end, lasting long enough that it
## never takes more than SPAWN_MAX_DRAG of the shell's speed (the muzzle is ~30-40 px in front of
## the path's start: a short blend drew a slow shell going backwards), SPAWN_BLEND..SPAWN_BLEND_MAX
## s and at most SPAWN_FLIGHT_SHARE of the flight.
const SPAWN_BLEND := 0.15 # s
const SPAWN_BLEND_MAX := 0.4 # s
const SPAWN_MAX_DRAG := 0.35
const SPAWN_FLIGHT_SHARE := 0.5
const SPAWN_NEAR := 90.0 # px: a path starting farther from the muzzle (air strike) is not moved
const ARROW_KINDS := ["", "flare", "bomb", "signal"] # high_shells(): the kinds flying a normal arc (signal: the nuke / laser flare)

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
var _spawn_blends: Array = [] # per projectile: how long its muzzle blend lasts (s)
var _launch: Array = [] # per projectile: when it leaves
var _skill_view = null
var _fired := false


func is_playing() -> bool:
	return _timeline != null


## The replay time now (s since the shot; negative during the lead-in).
func time() -> float:
	return _t


func play(timeline, lead_in: float = 0.0) -> void:
	stop()
	_timeline = timeline
	_t = -maxf(0.0, lead_in)
	_fired = false
	_spawn_offsets.clear()
	_spawn_blends.clear()
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
		_spawn_blends.append(blend_time(offset, timeline.velocity(i, launch).length(), timeline.projectile_end(i) - launch))
		var view: Node2D
		var unit_kind: String = timeline.kind(i)
		if UnitShell.is_kind(unit_kind): # a boss's / minion's own projectile (boss mode v3)
			view = UnitShell.new(unit_kind)
		else:
			view = ProjectileView.new()
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


## How long a muzzle blend of `offset` lasts for a shell leaving at `speed` px/s that flies
## `flight` s: the ease's fastest rate (1.5 × offset / time) at most SPAWN_MAX_DRAG × speed.
static func blend_time(offset: Vector2, speed: float, flight: float) -> float:
	var t := SPAWN_BLEND
	if speed > 0.0:
		t = maxf(t, 1.5 * offset.length() / (SPAWN_MAX_DRAG * speed))
	return minf(minf(t, SPAWN_BLEND_MAX), maxf(flight * SPAWN_FLIGHT_SHARE, 1e-3))


## The blend's share of the offset left at s (0..1 of the blend): 1 → 0, flat at both ends.
static func blend_left(s: float) -> float:
	s = clampf(s, 0.0, 1.0)
	return 1.0 - s * s * (3.0 - 2.0 * s)


## How long projectile i's muzzle blend lasts (s).
func spawn_blend(i: int) -> float:
	return _spawn_blends[i] if i < _spawn_blends.size() else SPAWN_BLEND


## How far projectile i is drawn off its path at time t: the muzzle offset easing out from its
## launch.
func spawn_offset(i: int, t: float) -> Vector2:
	if i >= _spawn_offsets.size():
		return Vector2.ZERO
	return _spawn_offsets[i] * blend_left((t - launch_time(i)) / spawn_blend(i))


## Shells drawn above the view's top (y < top, world: the camera's view top) that fly like a
## normal shot (ARROW_KINDS: a normal shell, the flare, the bombs; not the rain's missiles dropping
## in from above): their positions, for the arrows at the top edge (HighShellMarker).
func high_shells(top: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in _high_indices(top):
		out.append(_views[i].position)
	return out


## Where the live projectiles are drawn now (launched, not yet ended): the camera follows them.
func live_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	if _timeline == null or _t < 0.0:
		return out
	for view in _views:
		if view != null and is_instance_valid(view) and view.visible:
			out.append(view.position)
	return out


## The velocities (px/s) of the high_shells(), in the same order: their arrows turn with them
## (up-slanted while rising, down-slanted while falling).
func high_shell_velocities(top: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in _high_indices(top):
		out.append(_timeline.velocity(i, _t))
	return out


func _high_indices(top: float = 0.0) -> PackedInt32Array:
	var out := PackedInt32Array()
	if _timeline == null:
		return out
	for i in _views.size():
		var view = _views[i]
		if view != null and is_instance_valid(view) and view.visible and view.position.y < top \
				and ARROW_KINDS.has(_timeline.kind(i)):
			out.append(i)
	return out


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
	var timeline = _timeline
	if not _fired:
		_fired = true
		fired.emit()
		if _timeline != timeline:
			return # a handler stopped or replaced the replay
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
				view.set_tangent(_timeline.velocity(i, _t)) # the nose follows the server path's curve
	if _skill_view != null:
		_skill_view.process(_t)
	for event in timeline.pop_due(_t):
		event_due.emit(event)
		if _timeline != timeline:
			return # a handler stopped or replaced the replay
	if _t >= _timeline.duration:
		stop()
		finished.emit()
