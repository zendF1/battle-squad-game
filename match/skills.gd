extends RefCounted
## Character skills (server internal/game/match/skill_*.go, configs/skills.yaml; no API returns
## them). A skill is used with Shoot {angle, power, actionMode: "skill"}: the server picks the
## skill from the character and accepts it only at FULL_ENERGY. Each character's skill has its
## own script under match/views/skills/ (SkillView: name, description, aim mode, replay visuals).
##
## for_character() gives the skill as a dict:
## - id: the server skillId (ShotResolved.skillId);
## - name: the Vietnamese button label;
## - aim: SkillView.AIM_ARC (slingshot + arcs), AIM_LINE (a straight line to the map edge) or
##   AIM_NONE (fired at once on tap);
## - needs_aim: aim != AIM_NONE;
## - offsets: AIM_ARC preview arcs, in degrees added to the aimed angle.

const SkillView := preload("res://match/views/skills/skill_view.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")

const FULL_ENERGY := 100
## Skill energy a player gains at the end of each own turn, and when an enemy's action takes HP
## or shield from it (once per action).
const ENERGY_PER_TURN := 20
const ENERGY_ON_HIT := 10
# A skill without aim ignores angle and power, but the server still requires valid values.
const NO_AIM_ANGLE := 90.0
const NO_AIM_POWER := 50.0

## character -> its skill's script.
const SCRIPTS := {
	"rookie": preload("res://match/views/skills/rain.gd"),
	"tanko": preload("res://match/views/skills/bomb_chain.gd"),
	"spark": preload("res://match/views/skills/laser.gd"),
	"flora": preload("res://match/views/skills/bloom.gd"),
}

## Gun tier -> skill rank (server WeaponSkillRank): the normal tiers 1..4, the crafted Blaster
## tiers silver 2, gold 3, titan 4, diamond 4; basic (no weapon, bots) 0.
const TIER_RANKS := {"basic": 0, "iron": 1, "steel": 2, "mithril": 3, "dragon": 4,
	"silver": 2, "gold": 3, "titan": 4, "diamond": 4}

# Floating label for a ShotResolved "status" event; effects not listed show nothing.
const STATUS_LABELS := {
	"net": "Bị lưới",
	"freeze": "Bị đóng băng",
	"burn": "Bỏng",
	"root": "Bị cầm chân",
	"stun": "Choáng",
}


## The skill of a character, or {} for an unknown character.
static func for_character(character_id: String) -> Dictionary:
	var view = view_for_character(character_id)
	if view == null:
		return {}
	var aim: String = view.aim_mode()
	return {"id": view.skill_id(), "name": view.skill_name(), "aim": aim, "needs_aim": aim != SkillView.AIM_NONE,
		"offsets": view.preview_offsets() if aim == SkillView.AIM_ARC else []}


## A new SkillView of a character's skill, null for an unknown character.
static func view_for_character(character_id: String):
	var script = SCRIPTS.get(character_id)
	return script.new() if script != null else null


## A new SkillView for a server skill id, the base SkillView (default replay) when unknown.
static func view_for_skill(skill_id: String):
	for id in SCRIPTS:
		var view = SCRIPTS[id].new()
		if view.skill_id() == skill_id:
			return view
	return SkillView.new()


## A character's skill described with the numbers at gun rank `rank` ("" when unknown).
static func describe(character_id: String, rank: int = 0) -> String:
	var view = view_for_character(character_id)
	return view.describe(clampi(rank, 0, 4)) if view != null else ""


## The skill rank of a match player: skillRank from the server, else read from the gun it
## brought (weaponItemId → its tier, TIER_RANKS), 0 for none and bots.
static func rank_of(player: Dictionary, catalog: Variant = null) -> int:
	var v = player.get("skillRank")
	if v is int or v is float:
		return clampi(int(v), 0, 4)
	var weapon = player.get("weaponItemId")
	if not weapon is String or weapon == "":
		return 0
	return int(TIER_RANKS.get(str(EquipmentModel.player_gun(player, catalog)["tier"]), 0))


static func is_ready(energy: int) -> bool:
	return energy >= FULL_ENERGY


## "Mưa tên lửa 40/100" while charging, "Mưa tên lửa" when ready (the button has the skill icon).
static func button_label(skill: Dictionary, energy: int) -> String:
	var skill_name := str(skill.get("name", ""))
	if is_ready(energy):
		return skill_name
	return "%s %d/%d" % [skill_name, clampi(energy, 0, FULL_ENERGY), FULL_ENERGY]


static func status_label(effect_id: String) -> String:
	return STATUS_LABELS.get(effect_id, "")
