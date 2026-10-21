extends RefCounted
## A character skill's client side. One script per skill extends this (rain.gd, bomb_chain.gd,
## laser.gd, bloom.gd; match/skills.gd maps each character to its script):
## - what it is called and does (skill_id(), skill_name(), describe(rank): the skill slot, the
##   character pages and the shop);
## - how it is aimed (aim_mode(): AIM_ARC the slingshot with arc previews at preview_offsets(),
##   AIM_LINE a straight aim line to the map edge in any direction, AIM_NONE fired on tap);
## - its replay visuals: match_screen makes one instance per ShotResolved of the skill and calls
##   begin() before the replay, projectile_view() for every projectile ShotPlayer draws,
##   explosion() for every explode effect before it is shown, merges_damage() whether its hits
##   on a player add up into one running number (DamageTally), on_event() for every timeline
##   event after the default handling (HP, shield, effects, popups), process() every frame and
##   end() when the replay stops. aim_angle() is where the shooter points its gun when the shot
##   has no projectile (the laser's beam).
## Visual only: paths, damage, effects and timing all come from the server timeline; a skill
## view only draws them. The base class draws nothing extra: the default replay stays as is.

const AIM_ARC := "arc"
const AIM_LINE := "line"
const AIM_NONE := "none"

## The replay context from begin(): {layer: Node2D (the fx layer, layer coordinates = world),
## timeline: ShotTimeline, style: ShotLook.style_for() {kind, tier, skill, item}, views:
## {playerId: PlayerView}, players: {playerId: match player dict}, shooter: playerId}.
var ctx := {}


## The server skill id (config_skills.skill_id, ShotResolved.skillId).
func skill_id() -> String:
	return ""


## The Vietnamese name on the skill slot.
func skill_name() -> String:
	return ""


## How the skill is aimed: AIM_ARC, AIM_LINE or AIM_NONE.
func aim_mode() -> String:
	return AIM_ARC


## AIM_ARC: the preview arcs, degrees added to the aimed angle.
func preview_offsets() -> Array:
	return [0.0]


## A short description with the numbers at gun rank `rank` (0..4, match/skills.gd rank_of()).
func describe(_rank: int) -> String:
	return ""


func begin(context: Dictionary) -> void:
	ctx = context


## The view ShotPlayer draws for projectile i (timeline.projectiles[i], its "kind" names what it
## is: flare, missile, bomb, seed, "" a normal shell). Return `view` (already styled by the gun)
## changed, or another Node2D; ShotPlayer moves it along the path and frees it when it lands.
func projectile_view(_i: int, _projectile: Dictionary, view: Node2D) -> Node2D:
	return view


## True: the shot's hits on a player add up into one running number (DamageTally: the rain,
## the bomb chain) instead of a popup per hit.
func merges_damage() -> bool:
	return false


## An explode event's ExplosionFx before it is added (radius, kind, tier, skill already set).
func explosion(_event: Dictionary, _fx: Node2D) -> void:
	pass


## Any timeline event, after match_screen applied it.
func on_event(_event: Dictionary) -> void:
	pass


## Every frame of the replay; t is the replay time (seconds since the shot, the events' t).
func process(_t: float) -> void:
	pass


func end() -> void:
	pass


## The aim angle (degrees, Shoot convention) the shooter's gun shows for a shot without
## projectiles; NAN puts the gun away.
func aim_angle(_timeline) -> float:
	return NAN
