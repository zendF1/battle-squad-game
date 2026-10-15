extends RefCounted
## The lobby's choices, without UI: the play modes ("Luyện tập", "Đấu với máy") and their
## QuickPlay base, cycling through the four characters, the info card text of a character from
## the PlayerState characters cache, and the remembered mode. The mode is kept in the same
## settings file as the Loadout choice (LoadoutModel.SETTINGS_PATH, section "lobby").

const LoadoutModel := preload("res://screens/loadout_model.gd")
const Skills := preload("res://match/skills.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const Progress := preload("res://screens/home/progress.gd")

const SECTION := "lobby"
const MODE_KEY := "mode"

## id: the remembered value; base: Router.quick_play_base for the Loadout.
const MODES := [
	{"id": "practice", "name": "Luyện tập", "description": "Tập bắn với bia đứng yên", "base": {}},
	{"id": "bot", "name": "Đấu với máy", "description": "Đấu 1v1 với máy biết bắn", "base": {"bot": "ai"}},
]


## The mode after `index`, wrapping around.
static func next_mode(index: int) -> int:
	return posmod(index + 1, MODES.size())


static func mode_index(id: String) -> int:
	for i in MODES.size():
		if MODES[i]["id"] == id:
			return i
	return 0


## A copy of the QuickPlay base of the mode at `index`.
static func mode_base(index: int) -> Dictionary:
	return MODES[clampi(index, 0, MODES.size() - 1)]["base"].duplicate()


## The mode whose QuickPlay base is `base` (the Loadout gets only the base); 0 when none matches.
static func mode_of_base(base: Dictionary) -> int:
	for i in MODES.size():
		if MODES[i]["base"] == base:
			return i
	return 0


## The character `delta` steps from `id` in LoadoutModel.CHARACTERS order, wrapping around; an
## unknown id counts as the first.
static func cycle_character(id: String, delta: int) -> String:
	var at := 0
	for i in LoadoutModel.CHARACTERS.size():
		if LoadoutModel.CHARACTERS[i]["id"] == id:
			at = i
	return LoadoutModel.CHARACTERS[posmod(at + delta, LoadoutModel.CHARACTERS.size())]["id"]


## The info card of a character from GET /player/characters data (null: not loaded yet):
## {name, role, skill, owned, level, stats}. owned is true / false, or null while unknown; level
## is 0 unless owned; stats is [[label, value], ...] (Máu, Sát thương, Phòng thủ) from the
## character's battle stats, or its base stats when not owned; [] when the server sent none.
static func character_info(id: String, data: Variant) -> Dictionary:
	var out := {"name": id, "role": "", "skill": "", "owned": null, "level": 0, "stats": []}
	for c in LoadoutModel.CHARACTERS:
		if c["id"] == id:
			out["name"] = c["name"]
			out["role"] = c["role"]
	out["skill"] = str(Skills.for_character(id).get("name", ""))
	if not data is Dictionary or not data.get("characters") is Array:
		return out
	var entry = null
	for c in data["characters"]:
		if c is Dictionary and str(c.get("characterId", "")) == id:
			entry = c
	out["owned"] = entry != null
	if entry != null:
		out["level"] = Progress.character(entry)["level"]
		out["stats"] = stat_pairs(BattleStats.of(entry))
	else:
		out["stats"] = stat_pairs(BattleStats.base_of(data, id))
	return out


## "Lv.3", "Chưa sở hữu", or "" while ownership is unknown.
static func level_text(info: Dictionary) -> String:
	if info["owned"] == null:
		return ""
	return "Lv.%d" % info["level"] if info["owned"] else LoadoutModel.NOT_OWNED


## A BattleStats stats object → [["Máu", "138"], ["Sát thương", "66"], ["Phòng thủ", "56"]]
## (damage is the weapon damage plus the bonus); [] for {}.
static func stat_pairs(stats: Dictionary) -> Array:
	if stats.is_empty():
		return []
	var dmg := int(stats["damageBonus"])
	var weapon = stats.get("weaponDamage")
	if weapon is int or weapon is float:
		dmg += int(weapon)
	return [["Máu", str(int(stats["maxHp"]))], ["Sát thương", str(dmg)], ["Phòng thủ", str(int(stats["defense"]))]]


## The remembered mode index (0 without a file or for an unknown id).
static func restore_mode(path: String) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return 0
	return mode_index(str(cfg.get_value(SECTION, MODE_KEY, "")))


## Saves the mode, keeping the rest of the file (the Loadout choice).
static func remember_mode(path: String, index: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path) # a missing file starts empty
	cfg.set_value(SECTION, MODE_KEY, MODES[clampi(index, 0, MODES.size() - 1)]["id"])
	cfg.save(path)
