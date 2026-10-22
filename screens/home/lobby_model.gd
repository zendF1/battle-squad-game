extends RefCounted
## The lobby's choices, without UI: the play modes (the game data's modes.lobby: "Luyện tập",
## "Xếp hạng 2v2", "Đấu với máy") and their QuickPlay base (a mode with a queue: the queue,
## is_ranked(); with a bot: {"bot": it}; neither: practice), cycling through the game data's
## characters, the info card text of a character from the PlayerState characters cache, and the
## remembered mode. The mode is kept in the same
## settings file as the Loadout choice (LoadoutModel.SETTINGS_PATH, section "lobby").

const LoadoutModel := preload("res://screens/loadout_model.gd")
const Skills := preload("res://match/skills.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const Progress := preload("res://screens/home/progress.gd")
const Fmt := preload("res://core/fmt.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const SECTION := "lobby"
const MODE_KEY := "mode"

## The lobby modes in order: [{id, name, description, base}]. id: the remembered value; base:
## Router.quick_play_base for the Loadout. A queue mode's base is not a QuickPlay: {"queue": q}
## sends the Loadout to Matchmaking.
static func modes() -> Array:
	var out: Array = []
	for m in GameData.lobby_modes():
		var base := {}
		if str(m.get("queue", "")) != "":
			base = {"queue": str(m["queue"])}
		elif str(m.get("bot", "")) != "":
			base = {"bot": str(m["bot"])}
		out.append({"id": str(m.get("modeId", "")), "name": str(m.get("name", "")), "description": str(m.get("description", "")),
			"base": base})
	return out


## The mode at `index` (clamped); {id: "", name: "", description: "", base: {}} with none.
static func mode(index: int) -> Dictionary:
	var all := modes()
	if all.is_empty():
		return {"id": "", "name": "", "description": "", "base": {}}
	return all[clampi(index, 0, all.size() - 1)]


## The ranked mode's base (its queue is the game data's rank.rankedMode): the Loadout opens
## Matchmaking instead of sending QuickPlay.
static func is_ranked(base: Dictionary) -> bool:
	return str(base.get("queue", "")) != "" and str(base.get("queue", "")) == GameData.ranked_mode()


## The mode after `index`, wrapping around.
static func next_mode(index: int) -> int:
	return posmod(index + 1, maxi(modes().size(), 1))


static func mode_index(id: String) -> int:
	var all := modes()
	for i in all.size():
		if all[i]["id"] == id:
			return i
	return 0


## A copy of the QuickPlay base of the mode at `index`.
static func mode_base(index: int) -> Dictionary:
	return mode(index)["base"].duplicate()


## The mode whose QuickPlay base is `base` (the Loadout gets only the base); 0 when none matches.
static func mode_of_base(base: Dictionary) -> int:
	var all := modes()
	for i in all.size():
		if all[i]["base"] == base:
			return i
	return 0


## The character `delta` steps from `id` in the game data's character order, wrapping around;
## an unknown id counts as the first.
static func cycle_character(id: String, delta: int) -> String:
	var ids := LoadoutModel.character_ids()
	if ids.is_empty():
		return id
	var at := maxi(ids.find(id), 0)
	return str(ids[posmod(at + delta, ids.size())])


## The info card of a character from GET /player/characters data (null: not loaded yet):
## {name, role, skill, owned, level, stats}. owned is true / false, or null while unknown; level
## is 0 unless owned; stats is [[label, value], ...] (Máu, Sát thương, Phòng thủ) from the
## character's battle stats, or its base stats when not owned; [] when the server sent none.
static func character_info(id: String, data: Variant) -> Dictionary:
	var out := {"name": GameData.character_name(id), "role": GameData.character_role_name(id), "skill": "", "owned": null,
		"level": 0, "stats": []}
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


## A BattleStats stats object → [["Máu", "1.540"], ["Sát thương", "510"], ["Phòng thủ", "56"]]
## (damage is the weapon damage plus the bonus); [] for {}.
static func stat_pairs(stats: Dictionary) -> Array:
	if stats.is_empty():
		return []
	var dmg := int(stats["damageBonus"])
	var weapon = stats.get("weaponDamage")
	if weapon is int or weapon is float:
		dmg += int(weapon)
	return [["Máu", Fmt.thousands(int(stats["maxHp"]))], ["Sát thương", Fmt.thousands(dmg)],
		["Phòng thủ", Fmt.thousands(int(stats["defense"]))]]


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
	cfg.set_value(SECTION, MODE_KEY, mode(index)["id"])
	cfg.save(path)
