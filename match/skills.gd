extends RefCounted
## Character skills: the game data (GET /gamedata skills, characters, skillEnergy, skillRanks;
## autoload/game_data_model.gd) says which skill a character has, its name, description, aim kind,
## tuning and the skill energy rules. A skill is used with Shoot {angle, power, actionMode:
## "skill"}: the server picks the skill from the character and accepts it only at full energy
## (skillEnergy.max). The client side of a skill (aim previews, replay visuals) is a SkillView
## script per effect type under match/views/skills/ (VIEWS); a skill of an effect type this client
## has no script for gets the base SkillView (default replay).
##
## for_character() gives the skill as a dict:
## - id: the server skillId (ShotResolved.skillId);
## - name: the Vietnamese button label;
## - aim: SkillView.AIM_ARC (slingshot + arcs), AIM_LINE (a straight line to the map edge) or
##   AIM_NONE (fired at once on tap): the skill's aimKind;
## - needs_aim: aim != AIM_NONE;
## - offsets: AIM_ARC preview arcs, in degrees added to the aimed angle.

const SkillView := preload("res://match/views/skills/skill_view.gd")
const GameData := preload("res://autoload/game_data_model.gd")

## Skill effect type (the game data's effectType) -> its client script (presentation only).
const VIEWS := {
	"missile_rain": preload("res://match/views/skills/rain.gd"),
	"bomb_chain": preload("res://match/views/skills/bomb_chain.gd"),
	"laser": preload("res://match/views/skills/laser.gd"),
	"bloom": preload("res://match/views/skills/bloom.gd"),
	"nova": preload("res://match/views/skills/nova.gd"),
}


## The skill of a character, or {} for a character with none (or unknown).
static func for_character(character_id: String) -> Dictionary:
	var view = view_for_character(character_id)
	if view == null:
		return {}
	var aim: String = view.aim_mode()
	return {"id": view.skill_id(), "name": view.skill_name(), "aim": aim, "needs_aim": aim != SkillView.AIM_NONE,
		"offsets": view.preview_offsets() if aim == SkillView.AIM_ARC else []}


## A new SkillView of a character's skill, null for a character with none.
static func view_for_character(character_id: String):
	var skill_id := GameData.character_skill_id(character_id)
	return view_for_skill(skill_id) if skill_id != "" else null


## A boss skill's kind (GET /gamedata bosses skills) -> its client script; summon has none (the
## base SkillView: match_screen adds the minions).
const BOSS_VIEWS := {
	"rain": preload("res://match/views/skills/boss_rain.gd"),
	"beam": preload("res://match/views/skills/boss_beam.gd"),
}


## A new SkillView for a server skill id: its effect type's script (a boss skill: its kind's), the
## base SkillView (default replay) for an unknown type.
static func view_for_skill(skill_id: String):
	var script = VIEWS.get(GameData.skill_effect_type(skill_id))
	if script == null and not GameData.has_skill(skill_id):
		script = BOSS_VIEWS.get(str(GameData.boss_skill("", skill_id).get("kind", "")))
	var view = script.new() if script != null else SkillView.new()
	return view.for_skill(skill_id)


## A character's skill described with the numbers at gun rank `rank` ("" when unknown).
static func describe(character_id: String, rank: int = 0) -> String:
	var view = view_for_character(character_id)
	return view.describe(GameData.clamp_skill_rank(rank)) if view != null else ""


## The skill rank of a match player: skillRank from the server, else read from the gun it
## brought (weaponItemId, skillRanks.byTierWord), the default for none and bots.
static func rank_of(player: Dictionary, _catalog: Variant = null) -> int:
	var v = player.get("skillRank")
	if v is int or v is float:
		return GameData.clamp_skill_rank(int(v))
	var weapon = player.get("weaponItemId")
	return GameData.skill_rank_of_weapon(str(weapon) if weapon is String else "")


## Full skill energy (skillEnergy.max): the skill can be used.
static func full_energy() -> int:
	return GameData.skill_energy_max()


static func is_ready(energy: int) -> bool:
	return energy >= full_energy()


## "Mưa tên lửa 40/100" while charging, "Mưa tên lửa" when ready (the button has the skill icon).
static func button_label(skill: Dictionary, energy: int) -> String:
	var skill_name := str(skill.get("name", ""))
	if is_ready(energy):
		return skill_name
	return "%s %d/%d" % [skill_name, clampi(energy, 0, full_energy()), full_energy()]


## The floating label of a ShotResolved "status" event: the effect's name ("" for an effect the
## game data does not know).
static func status_label(effect_id: String) -> String:
	return GameData.status_name(effect_id)
