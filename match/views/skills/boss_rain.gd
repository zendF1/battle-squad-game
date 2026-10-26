extends "res://match/views/skills/rain.gd"
## A boss's rain skill (GET /gamedata bosses skills kind "rain": Mưa đạn pháo, Bom lửa, Gai băng,
## Bão tuyết): no flare is fired; at the rain event (position: the target, radius: the spread) a
## red danger ring opens on the ground there with the signal smoke of the rain, then the shells
## (projectile kind "missile", in the boss's shot look) fall from the top of the map like Rookie's
## missiles, their hits counting up in one number per player; since boss mode v3 they are the
## boss's own projectiles (UnitShell: steel shells, magma bombs, the witch's ice shards and spikes). The name is the boss skill's
## (SkillView.skill_name()); damage, shells and lava come from the server timeline. The camera
## stays on the target's ground while they fall (tracks_shells()).
## Boss mode v3: a map-wide rain (its radius at least WIDE_SHARE of the map width: the witch's
## Bão tuyết, the crab's Bom lửa) has no single target: a small danger mark pulses where each
## shell will land (the server's explode positions) until it does, the camera frames the whole
## map (frames_map()), and the boss's storm (BossArt.STORM: snow for the witch, embers for the
## crab) blows across the screen while it plays (StormOverlay on the screen layer).

const StormOverlay := preload("res://match/boss/storm_overlay.gd")
const UnitShell := preload("res://match/views/unit_shell.gd")
const BossArt := preload("res://match/boss/boss_art.gd")

const WIDE_SHARE := 0.35

var _ring: Node2D = null
var _wide := false
var _storm: Node2D = null
var _marks: Node2D = null


## The camera looks at the target's ground, not at the shells high above it; a rain of one shell
## (boss v4: Khổng Lồ Đá's giant boulder, thrown up from its hands and falling on one member) is
## followed on its way.
func tracks_shells() -> bool:
	return _single


var _single := false


func begin(context: Dictionary) -> void:
	super.begin(context)
	_wide = false
	_storm = null
	_marks = null
	var timeline = ctx.get("timeline")
	_single = timeline != null and timeline.projectiles.size() == 1
	if timeline != null: # the boss's own shells (steel_shell, magma_bomb, ice_shard, ice_spike) are its rain's too
		for i in timeline.projectiles.size():
			if UnitShell.is_kind(timeline.kind(i)):
				_missile_ids[str(timeline.projectiles[i].get("projectileId", ""))] = true
	var terrain = ctx.get("terrain")
	var width := float(terrain.width) if terrain != null and "width" in terrain else 0.0
	if timeline != null:
		_wide = is_wide(timeline.events, width)


## A rain over most of the map: its rain event's radius is at least WIDE_SHARE of the map width.
static func is_wide(events: Array, map_width: float) -> bool:
	if map_width <= 0.0:
		return false
	for e in events:
		if e is Dictionary and str(e.get("type", "")) == "rain":
			var r = e.get("radius")
			return (r is int or r is float) and float(r) >= WIDE_SHARE * map_width
	return false


## A map-wide rain: the whole map is framed.
func frames_map() -> bool:
	return _wide


func wide() -> bool:
	return _wide


## The storm on screen (null none; tests, previews).
func storm() -> Node2D:
	return _storm


func on_event(event: Dictionary) -> void:
	if _wide:
		if str(event.get("type", "")) == "rain":
			_start_wide(float(event.get("t", 0.0)))
		return
	super.on_event(event)
	if str(event.get("type", "")) != "rain":
		return
	var p = event.get("position")
	if not p is Dictionary:
		return
	var at := Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
	if _fx != null and is_instance_valid(_fx):
		_fx.land(at)
	var layer = ctx.get("layer")
	if layer is Node2D:
		_ring = DangerRing.new()
		_ring.position = at
		_ring.radius = maxf(float(event.get("radius", 60.0)), 30.0)
		layer.add_child(_ring)


## The marks where every shell lands, and the boss's storm over the screen.
func _start_wide(t0: float) -> void:
	var shooter: Dictionary = ctx.get("players", {}).get(str(ctx.get("shooter", "")), {})
	var storm_kind := str(BossArt.STORM.get(BossArt.art_of(str(shooter.get("bossId", ""))), ""))
	var layer = ctx.get("layer")
	var timeline = ctx.get("timeline")
	if layer is Node2D and timeline != null:
		_marks = LandingMarks.new()
		_marks.icy = storm_kind == StormOverlay.SNOW
		for e in timeline.events:
			if e is Dictionary and str(e.get("type", "")) == "explode" and is_missile(str(e.get("projectileId", ""))) \
					and e.get("position") is Dictionary:
				_marks.add(Vector2(float(e["position"].get("x", 0.0)), float(e["position"].get("y", 0.0))), t0, float(e.get("t", t0)))
		layer.add_child(_marks)
	var screen = ctx.get("screen")
	if storm_kind != "" and screen is Node:
		_storm = StormOverlay.new(storm_kind)
		_storm.wind = -1.0 if float(ctx.get("wind", -1.0)) < 0.0 else 1.0
		screen.add_child(_storm)


func process(t: float) -> void:
	super.process(t)
	if _marks != null and is_instance_valid(_marks):
		_marks.sync(t)


func end() -> void:
	super.end()
	if _storm != null and is_instance_valid(_storm):
		_storm.release()
	if _marks != null and is_instance_valid(_marks):
		_marks.queue_free()
	_marks = null


## The ground ring under a boss's rain: it opens, pulses red while the shells fall, then fades.
class DangerRing extends Node2D:
	const LIFE := 2.2
	var radius := 80.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var open := minf(_t / 0.25, 1.0)
		var fade := 1.0 - clampf((_t - (LIFE - 0.5)) / 0.5, 0.0, 1.0)
		var pulse := 0.6 + 0.4 * sin(_t * 12.0)
		var r := radius * open
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.15, 0.1, 0.16 * fade))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.25, 0.15, 0.9 * fade * pulse), 5.0, true)
		draw_arc(Vector2.ZERO, r * 0.55, 0.0, TAU, 40, Color(1.0, 0.5, 0.3, 0.6 * fade), 3.0, true)
		draw_set_transform(Vector2.ZERO)
		var s := 10.0 * open
		draw_line(Vector2(-s, 0), Vector2(s, 0), Color(1, 0.9, 0.8, 0.9 * fade), 3.0, true)
		draw_line(Vector2(0, -s * 0.6), Vector2(0, s * 0.6), Color(1, 0.9, 0.8, 0.9 * fade), 3.0, true)


## Where each shell of a map-wide rain lands: a small flat ring pulsing on the ground from the
## rain's start until its shell hits there (red, or ice blue for a snowstorm). One node for all.
class LandingMarks extends Node2D:
	const R := 32.0
	var icy := false
	var marks: Array = [] # [at, t_show, t_hit]
	var _t := 0.0

	func add(at: Vector2, t_show: float, t_hit: float) -> void:
		marks.append([at, t_show, t_hit])

	func sync(t: float) -> void:
		_t = t
		queue_redraw()

	## The marks still waiting for their shell at time t.
	func shown(t: float) -> int:
		var n := 0
		for m in marks:
			if t >= float(m[1]) and t < float(m[2]):
				n += 1
		return n

	func _draw() -> void:
		var col := Color(0.12, 0.42, 1.0) if icy else Color(1.0, 0.2, 0.12)
		for m in marks:
			var left := float(m[2]) - _t
			if _t < float(m[1]) or left < 0.0:
				continue
			var open := clampf((_t - float(m[1])) / 0.2, 0.0, 1.0)
			var near := clampf(1.0 - left / 1.2, 0.0, 1.0) # brighter and tighter as it comes
			var pulse := 0.7 + 0.3 * sin(_t * 14.0 + float(m[0].x) * 0.01)
			var at: Vector2 = m[0]
			var r := R * open * (1.0 - 0.25 * near)
			draw_set_transform(at, 0.0, Vector2(1.0, 0.34))
			draw_circle(Vector2.ZERO, r, Color(col, (0.18 + 0.22 * near) * open))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(col, (0.65 + 0.35 * near) * pulse * open), 5.0, true)
			draw_arc(Vector2.ZERO, r * 0.5, 0.0, TAU, 20, Color(1, 1, 1, 0.8 * near * open), 3.0, true)
			draw_set_transform(Vector2.ZERO)
