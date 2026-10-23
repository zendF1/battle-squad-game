extends RefCounted
## A character skill's client side. One script per skill effect type extends this (rain.gd
## missile_rain, bomb_chain.gd bomb_chain, laser.gd laser, bloom.gd bloom, nova.gd nova; match/skills.gd maps a
## skill's effectType to its script, a skill of an unknown type gets this base view):
## - what it is called and does: the game data (GET /gamedata skills: skill_id(), skill_name(),
##   describe(rank) from its description template and per-rank values; param() its tuning);
## - how it is aimed (aim_mode(): the skill's aimKind, AIM_ARC the slingshot with arc previews at
##   preview_offsets(), AIM_LINE a straight aim line to the map edge in any direction, AIM_NONE
##   fired on tap);
## - its replay visuals: match_screen makes one instance per ShotResolved of the skill and calls
##   begin() before the replay, projectile_view() for every projectile ShotPlayer draws,
##   explosion() for every explode effect before it is shown, merges_damage() whether its hits
##   on a player add up into one running number (DamageTally), on_event() for every timeline
##   event after the default handling (HP, shield, effects, popups), process() every frame and
##   end() when the replay stops. aim_angle() is where the shooter points its gun when the shot
##   has no projectile (the laser's beam).
## Visual only: paths, damage, effects and timing all come from the server timeline; a skill
## view only draws them. The base class draws nothing extra: the default replay stays as is.

const GameData := preload("res://autoload/game_data_model.gd")

## The game data's aimKind values.
const AIM_ARC := "arc"
const AIM_LINE := "line"
const AIM_NONE := "none"

var _skill := "" # the server skill id this view is for (for_skill())

## The replay context from begin(): {layer: Node2D (the fx layer, layer coordinates = world),
## timeline: ShotTimeline, style: ShotLook.style_for() {kind, tier, skill, item}, views:
## {playerId: PlayerView}, players: {playerId: match player dict}, shooter: playerId, terrain:
## the TerrainMask, screen: a CanvasLayer over the world and under the HUD for screen overlays}.
var ctx := {}


## Sets the server skill id this view is for (match/skills.gd view_for_skill()); returns self.
func for_skill(skill_id_value: String):
	_skill = skill_id_value
	return self


## The server skill id (config_skills.skill_id, ShotResolved.skillId).
func skill_id() -> String:
	return _skill


## The Vietnamese name on the skill slot (a boss skill: its name in GET /gamedata bosses; "" when
## the game data does not know the skill).
func skill_name() -> String:
	var n := GameData.skill_name(_skill)
	return n if n != "" else str(GameData.boss_skill("", _skill).get("name", ""))


## How the skill is aimed: AIM_ARC, AIM_LINE or AIM_NONE (its aimKind).
func aim_mode() -> String:
	return GameData.skill_aim_kind(_skill)


## A tuning number of the skill (its params; 0 when absent).
func param(key: String) -> float:
	return GameData.skill_param(_skill, key)


## AIM_ARC: the preview arcs, degrees added to the aimed angle.
func preview_offsets() -> Array:
	return [0.0]


## A short description with the numbers at gun rank `rank` (match/skills.gd rank_of()): the
## skill's description template filled with that rank's values.
func describe(rank: int) -> String:
	return GameData.skill_describe(_skill, rank)


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


## True: the camera follows the replay's shells in flight; false (a boss's rain, its shells falling
## from above the map): it looks at the ground they fall on (the rain event's position).
func tracks_shells() -> bool:
	return true


## True (boss mode v3: a map-wide rain, many beams at once): the camera frames the whole map
## while the replay plays (match_screen zooms out, then back).
func frames_map() -> bool:
	return false


## A wide area the camera frames while the replay plays (world px; Tide's nova: its radius), the
## zoom back after it; ZERO none.
func frame_size() -> Vector2:
	return Vector2.ZERO


## The aim angle (degrees, Shoot convention) the shooter's gun shows for a shot without
## projectiles; NAN puts the gun away.
func aim_angle(_timeline) -> float:
	return NAN
