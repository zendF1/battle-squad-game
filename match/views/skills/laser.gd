extends "res://match/views/skills/skill_view.gd"
## Spark — Tia laze (server skill shock_field, effect laser): a straight beam (event beam: from,
## to, duration) through terrain to the map edge, no projectile; damage cause "laser"; every
## enemy hit is stunned. Aimed with a straight line in any direction (AIM_LINE).
## Visuals (laser_fx.gd, one per shot on the fx layer): the charge at the muzzle, the beam sweeping
## through the terrain to the map edge in the gun's tier colours, a flash, sparks and arcs on every
## enemy hit plus a small electric burst (ExplosionFx of the gun, no crater). The damage numbers,
## the stun popup and the "Choáng — mất lượt" banner on their next turn are match_screen's.

const LaserFx := preload("res://match/views/skills/laser_fx.gd")
const ExplosionFx := preload("res://match/views/explosion_fx.gd")
const BODY_LIFT := 20.0 # the body centre above the feet (the server's ShotOriginLift)
const BURST_RADIUS := 18.0 # the electric burst on a hit (visual only)

var _fx: Node2D = null
var _has_muzzle := false


func skill_id() -> String:
	return "shock_field"


func skill_name() -> String:
	return "Tia laze"


func aim_mode() -> String:
	return AIM_LINE


func describe(rank: int) -> String:
	return "Tia thẳng xuyên địa hình tới mép bản đồ, trúng mọi địch trên đường: %d%% sát thương, mỗi địch sau giảm 20%%; địch trúng bị choáng, mất lượt sau." % (150 + 10 * rank)


func begin(context: Dictionary) -> void:
	super.begin(context)
	_fx = null
	_has_muzzle = false
	var layer = ctx.get("layer")
	var timeline = ctx.get("timeline")
	if not layer is Node2D or timeline == null:
		return
	var beam := beam_event(timeline)
	if beam.is_empty():
		return # an old server: nothing to draw
	_fx = LaserFx.new()
	_fx.setup(beam, ctx.get("style", {}), ctx.get("terrain"))
	layer.add_child(_fx)


func process(t: float) -> void:
	if not _fx_alive():
		return
	if not _has_muzzle:
		_has_muzzle = true
		var view = ctx.get("views", {}).get(str(ctx.get("shooter", "")))
		if view != null and is_instance_valid(view) and view.has_method("fire_muzzle_position") and _fx.is_inside_tree():
			_fx.set_muzzle(_fx.get_parent().to_local(view.fire_muzzle_position()))
	_fx.sync(t)


## A laser hit: the flash, sparks and arcs at the victim, and the gun's electric burst.
func on_event(e: Dictionary) -> void:
	if not _fx_alive() or str(e.get("type", "")) != "damage" or str(e.get("cause", "")) != "laser":
		return
	var view = ctx.get("views", {}).get(str(e.get("playerId", "")))
	if view == null or not is_instance_valid(view):
		return
	var at: Vector2 = _fx.hit(view.position - Vector2(0, BODY_LIFT), float(e.get("t", 0.0)))
	var style: Dictionary = ctx.get("style", {})
	var burst := ExplosionFx.new()
	burst.radius = BURST_RADIUS
	burst.kind = str(style.get("kind", ""))
	burst.tier = str(style.get("tier", ""))
	burst.skill = true
	burst.position = at
	_fx.get_parent().add_child(burst)


func end() -> void:
	if _fx_alive():
		_fx.release()
	_fx = null


func _fx_alive() -> bool:
	return _fx != null and is_instance_valid(_fx)


## The timeline's beam event ({} none).
static func beam_event(timeline) -> Dictionary:
	for e in timeline.events:
		if str(e.get("type", "")) == "beam" and e.get("from") is Dictionary and e.get("to") is Dictionary:
			return e
	return {}


## The gun points along the beam.
func aim_angle(timeline) -> float:
	var e := beam_event(timeline)
	if e.is_empty():
		return NAN
	var d := Vector2(float(e["to"]["x"]) - float(e["from"]["x"]), float(e["to"]["y"]) - float(e["from"]["y"]))
	return rad_to_deg(atan2(-d.y, d.x)) if d.length() > 0.01 else NAN
