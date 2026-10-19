extends RefCounted
## Character skills (server configs/characters.yaml + skills.yaml; no API returns them). A skill
## is used with Shoot {angle, power, actionMode: "skill"}: the server picks the skill from the
## character and accepts it only at FULL_ENERGY.
##
## Each entry:
## - id: the server skillId (ShotResolved.skillId);
## - name: the Vietnamese button label;
## - needs_aim: false fires at once on tap (healing_bloom has no projectile);
## - offsets: preview arcs, in degrees added to the aimed angle (the server's projectile angles).

const FULL_ENERGY := 100
# healing_bloom ignores angle and power, but the server still requires valid values.
const NO_AIM_ANGLE := 90.0
const NO_AIM_POWER := 50.0

const BY_CHARACTER := {
	"rookie": {"id": "triple_shot", "name": "Bắn 3 tia", "needs_aim": true, "offsets": [-10.0, 0.0, 10.0]},
	"tanko": {"id": "heavy_bomb", "name": "Bom đào", "needs_aim": true, "offsets": [0.0]},
	"spark": {"id": "shock_field", "name": "Lưới điện", "needs_aim": true, "offsets": [0.0]},
	"flora": {"id": "healing_bloom", "name": "Hồi máu", "needs_aim": false, "offsets": []},
}

# Floating label for a ShotResolved "status" event; effects not listed show nothing.
const STATUS_LABELS := {
	"net": "Bị lưới",
	"freeze": "Bị đóng băng",
}


## The skill of a character, or {} for an unknown character.
static func for_character(character_id: String) -> Dictionary:
	return BY_CHARACTER.get(character_id, {})


static func is_ready(energy: int) -> bool:
	return energy >= FULL_ENERGY


## "Bắn 3 tia 40/100" while charging, "Bắn 3 tia" when ready (the button has the skill icon).
static func button_label(skill: Dictionary, energy: int) -> String:
	var skill_name := str(skill.get("name", ""))
	if is_ready(energy):
		return skill_name
	return "%s %d/%d" % [skill_name, clampi(energy, 0, FULL_ENERGY), FULL_ENERGY]


static func status_label(effect_id: String) -> String:
	return STATUS_LABELS.get(effect_id, "")
