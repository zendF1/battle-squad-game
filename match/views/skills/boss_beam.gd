extends "res://match/views/skills/laser.gd"
## A boss's beam skill (GET /gamedata bosses skills kind "beam": Tia laze nghiền, Tia băng): one
## beam event is the laser's visuals (laser_fx.gd: the charge at the boss's muzzle point, the beam
## sweeping through the terrain to the map edge in the boss's shot look, a burst on every player
## hit), its timing from the beam event (t, duration). Boss mode v3: a shot with many beams at
## once (the witch's radial burst of 20, the robot's 5 parallel sweeps; BeamFan) is drawn by one
## BeamFanFx: all of them together, a burst glow round a radial centre, a flash on each player hit
## (a stun / freeze shows on the body: PlayerView's StatusFx); the camera frames the whole map
## for it (frames_map()). Boss skills have no game data tuning of their own: the laser effect's
## (the first laser skill's params) is used.

const BeamFan := preload("res://match/boss/beam_fan.gd")
const BeamFanFx := preload("res://match/views/skills/beam_fan_fx.gd")
const ShotLook := preload("res://match/views/shot_look.gd")

var _fan: Node2D = null


func param(key: String) -> float:
	return GameData.effect_param("laser", key)


## The shot's beams (BeamFan.beams()).
func shot_beams(timeline) -> Array:
	return BeamFan.beams(timeline.events) if timeline != null else []


func begin(context: Dictionary) -> void:
	_fan = null
	var list := shot_beams(context.get("timeline"))
	if list.size() <= 1:
		super.begin(context)
		return
	ctx = context
	_fx = null
	var layer = ctx.get("layer")
	if not layer is Node2D:
		return
	var style: Dictionary = ctx.get("style", {})
	var kind := ShotLook.known_kind(str(style.get("kind", "shock_rifle")))
	var tier := ShotLook.known_tier(str(style.get("tier", "")))
	_fan = BeamFanFx.new()
	_fan.setup(list, LaserFx.palette(kind, tier), param("sweepSpeed"))
	layer.add_child(_fan)
	var view = ctx.get("views", {}).get(str(ctx.get("shooter", "")))
	if view != null and is_instance_valid(view) and view.has_method("fire_muzzle_position") and view.is_inside_tree():
		_fan.muzzle = layer.to_local(view.fire_muzzle_position())
	if view != null and is_instance_valid(view) and view.has_method("figure") and view.figure().has_method("art_height"):
		_fan.radial_gap = maxf(BeamFanFx.RADIAL_GAP, view.figure().art_height() * 0.6) # her figure clear of the beams


## Many beams reach every edge: the camera frames the whole map while they play.
func frames_map() -> bool:
	return _fan != null


## The multi-beam drawing (null for one beam).
func fan() -> Node2D:
	return _fan


func process(t: float) -> void:
	if _fan == null:
		super.process(t)
	elif is_instance_valid(_fan):
		_fan.sync(t)


## A beam hit: its flash (a stun / freeze on someone hit shows on its body: PlayerView's StatusFx).
func on_event(e: Dictionary) -> void:
	if _fan == null:
		super.on_event(e)
		return
	if not is_instance_valid(_fan):
		return
	var view = ctx.get("views", {}).get(str(e.get("playerId", "")))
	if view == null or not is_instance_valid(view):
		return
	match str(e.get("type", "")):
		"damage":
			var body: float = view.body_size if "body_size" in view else 1.0
			_fan.hit(view.position - Vector2(0, GameData.shot_origin_lift() * body), float(e.get("t", 0.0)))


func end() -> void:
	if _fan != null:
		if is_instance_valid(_fan):
			_fan.release()
		_fan = null
		return
	super.end()


## One beam: the gun points along it; a burst has no single direction (the figure stays).
func aim_angle(timeline) -> float:
	if shot_beams(timeline).size() > 1:
		return NAN
	return super.aim_angle(timeline)
