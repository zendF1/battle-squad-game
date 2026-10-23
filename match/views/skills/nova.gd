extends "res://match/views/skills/skill_view.gd"
## Tide — Nổ bông tuyết (server skill snow_nova, effect nova; its name and numbers are the game
## data's): fired on tap (aimKind none), no projectile. The server's timeline: a "nova" event
## {t (its castTime), playerId, position (Tide's body centre), radius, duration (radius /
## waveSpeed)}, then per enemy inside a damage (cause "nova") and a freeze status at
## t + distance / waveSpeed (and a die when it kills), so every hit lands as the ring reaches it.
## On top of the default replay (HP, the frozen crystal look from the status event, numbers):
## - NovaFx at her: the cast gathering snow, the big snowflake sigil flashing at t, the frost ring
##   expanding to the radius with ice shards on its front, snow drifting out, the ground in the
##   radius frosting over briefly;
## - a small burst of ice where each target is hit;
## - the camera frames the whole radius (frame_size()), back after the replay.
## Without a nova event (an older server) it draws the ring from Tide's position with the skill's
## params (radius, waveSpeed, castTime).

const NovaFx := preload("res://match/views/skills/nova_fx.gd")
const WaterSplash := preload("res://match/views/water_splash.gd")

var _fx: Node2D = null
var _nova := {} # the nova event (its fields read into the fx)


func begin(context: Dictionary) -> void:
	super(context)
	_nova = nova_of(ctx.get("timeline"))
	var centre := Vector2.ZERO
	if _nova.get("position") is Dictionary:
		centre = Vector2(float(_nova["position"].get("x", 0.0)), float(_nova["position"].get("y", 0.0)))
	else:
		var view = ctx.get("views", {}).get(ctx.get("shooter", ""))
		if view != null and is_instance_valid(view):
			centre = view.body_centre() if view.has_method("body_centre") else view.position
	_fx = NovaFx.new()
	_fx.position = centre
	_fx.radius = radius()
	_fx.t0 = t0()
	_fx.duration = ring_sec()
	_fx.cast_from = 0.0
	_fx.terrain = ctx.get("terrain")
	var layer = ctx.get("layer")
	if layer is Node:
		layer.add_child(_fx)


## The timeline's nova event ({} none).
static func nova_of(timeline) -> Dictionary:
	if timeline == null:
		return {}
	for e in timeline.events:
		if e is Dictionary and str(e.get("type", "")) == "nova":
			return e
	return {}


## The nova's radius: the event's, else the skill's param.
func radius() -> float:
	var r = _nova.get("radius")
	return float(r) if (r is int or r is float) and r > 0 else maxf(param("radius"), 1.0)


## When the nova goes off (replay s): the event's t, else the skill's castTime.
func t0() -> float:
	var t = _nova.get("t")
	return float(t) if t is int or t is float else maxf(param("castTime"), 0.0)


## How long the ring takes to reach the radius: the event's duration, else radius / waveSpeed.
func ring_sec() -> float:
	var d = _nova.get("duration")
	if (d is int or d is float) and d > 0:
		return float(d)
	var speed := param("waveSpeed")
	return radius() / speed if speed > 0.0 else 0.4


## The nova's centre on the fx layer (tests).
func centre() -> Vector2:
	return _fx.position if _fx != null and is_instance_valid(_fx) else Vector2.ZERO


## The fx node (tests).
func fx() -> Node2D:
	return _fx


func tracks_shells() -> bool:
	return false


## The whole radius in view: as wide as the ring, tall enough for most of it.
func frame_size() -> Vector2:
	return Vector2(radius() * 2.0, radius() * 1.2)


func process(t: float) -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.sync(t)


## A target hit by the ring: a burst of ice at its body.
func on_event(event: Dictionary) -> void:
	if str(event.get("type", "")) != "damage" or str(event.get("cause", "")) != "nova":
		return
	var view = ctx.get("views", {}).get(str(event.get("playerId", "")))
	var layer = ctx.get("layer")
	if view == null or not is_instance_valid(view) or not layer is Node:
		return
	var burst := WaterSplash.new()
	burst.big = true
	burst.radius = 26.0
	burst.position = view.position
	layer.add_child(burst)


func end() -> void:
	_fx = null # it plays out and frees itself
