extends "res://match/views/skills/laser.gd"
## A boss's beam skill (GET /gamedata bosses skills kind "beam": Tia laze nghiền, Tia băng): one
## beam event is the laser's visuals (laser_fx.gd: the charge at the boss's muzzle point, the beam
## sweeping through the terrain to the map edge in the boss's shot look, a burst on every player
## hit), its timing from the beam event (t, duration). Boss mode v3: a shot with many beams at
## once (the witch's radial burst of 20, the saucer's 5 parallel sweeps; BeamFan) is drawn by one
## BeamFanFx: all of them together, a burst glow round a radial centre, a flash on each player hit
## (a stun / freeze shows on the body: PlayerView's StatusFx); the camera frames the whole map
## for it (frames_map()). Boss skills have no game data tuning of their own: the laser effect's
## (the first laser skill's params) is used.
## Boss v4: a beam that drains (its skill's drainPct, Mộc Tinh's Hút sinh lực) is drawn green-gold
## (DRAIN_PALETTE); match_screen draws the life flowing from the member it hits into the boss's heart
## (LifeStreamFx) and the heal on the boss.
## Round 2 (pattern "each", Đĩa Bay Thép's Tia laze nghiền): one beam per party member, one after
## another (each at its own t), from the turret straight onto that member: TurretBeamsFx draws each
## from the turret's turned tip (the boss's muzzle_position(), every frame: BossBody turns the turret
## onto each `to` first, match_screen's turret plan) to the member, with the impact flash on it; the
## camera frames the whole map.

const BeamFan := preload("res://match/boss/beam_fan.gd")
const BeamFanFx := preload("res://match/views/skills/beam_fan_fx.gd")
const ShotLook := preload("res://match/views/shot_look.gd")
const TurretBeamsFx := preload("res://match/boss/turret_beams_fx.gd")

const DRAIN_PALETTE := {"glow": Color(0.55, 1.0, 0.35), "mid": Color(0.86, 1.0, 0.55), "core": Color(1.0, 0.98, 0.82),
	"arc": Color(1.0, 0.84, 0.34)}

var _fan: Node2D = null
var _each: Node2D = null


## The beams go one per member, one after another (the skill's pattern "each", or beams at
## different moments).
static func is_each(skill: Dictionary, list: Array) -> bool:
	if str(skill.get("pattern", "")) == "each":
		return true
	var ts := {}
	for b in list:
		ts[snappedf(float(b.get("t", 0.0)), 0.001)] = true
	return ts.size() > 1


## The beams with their targets (BeamFan.beams() + the events' targetId as target).
static func each_beams(events: Array) -> Array:
	var list := BeamFan.beams(events)
	var k := 0
	for e in events:
		if e is Dictionary and str(e.get("type", "")) == "beam" and e.get("from") is Dictionary and e.get("to") is Dictionary:
			if k < list.size():
				list[k]["target"] = str(e.get("targetId", ""))
			k += 1
	return list


## The skill heals the boss by a share of its beam's damage (GET /gamedata bosses skills drainPct).
func drains() -> bool:
	var d = GameData.boss_skill("", _skill).get("drainPct")
	return (d is int or d is float) and float(d) > 0.0


func param(key: String) -> float:
	return GameData.effect_param("laser", key)


## The shot's beams (BeamFan.beams()).
func shot_beams(timeline) -> Array:
	return BeamFan.beams(timeline.events) if timeline != null else []


func begin(context: Dictionary) -> void:
	_fan = null
	_each = null
	var list := shot_beams(context.get("timeline"))
	if not list.is_empty() and is_each(GameData.boss_skill("", _skill), list):
		ctx = context
		_fx = null
		var each_layer = ctx.get("layer")
		if not each_layer is Node2D:
			return
		var look: Dictionary = ctx.get("style", {})
		_each = TurretBeamsFx.new()
		_each.setup(each_beams(ctx["timeline"].events), DRAIN_PALETTE if drains() else LaserFx.palette(ShotLook.known_kind(str(look.get("kind", "shock_rifle"))),
			ShotLook.known_tier(str(look.get("tier", "")))))
		each_layer.add_child(_each)
		return
	if list.size() <= 1:
		super.begin(context)
		if drains() and _fx != null:
			_fx.colors = DRAIN_PALETTE
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
	return _fan != null or _each != null


## The turret beams' drawing (null unless pattern each).
func each_fx() -> Node2D:
	return _each


## The multi-beam drawing (null for one beam).
func fan() -> Node2D:
	return _fan


func process(t: float) -> void:
	if _each != null:
		if is_instance_valid(_each):
			var layer = ctx.get("layer")
			var view = ctx.get("views", {}).get(str(ctx.get("shooter", "")))
			var tip: Vector2 = _each.tip
			if view != null and is_instance_valid(view) and view.has_method("muzzle_position") and layer is Node2D:
				tip = layer.to_local(view.muzzle_position())
			_each.sync(t, tip)
		return
	if _fan == null:
		super.process(t)
	elif is_instance_valid(_fan):
		_fan.sync(t)


## A beam hit: its flash (a stun / freeze on someone hit shows on its body: PlayerView's StatusFx).
func on_event(e: Dictionary) -> void:
	if _each != null:
		return # the impact is drawn with each beam; the numbers are match_screen's
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
	if _each != null:
		if is_instance_valid(_each):
			_each.release()
		_each = null
		return
	if _fan != null:
		if is_instance_valid(_fan):
			_fan.release()
		_fan = null
		return
	super.end()


## One beam: the gun points along it; a burst has no single direction (the figure stays).
func aim_angle(timeline) -> float:
	if shot_beams(timeline).size() > 1 or _each != null:
		return NAN
	return super.aim_angle(timeline)
