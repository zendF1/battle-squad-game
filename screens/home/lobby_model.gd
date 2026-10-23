extends RefCounted
## The lobby's choices, without UI: the play modes (the game data's modes.lobby, in order: "Đấu
## thường 2vs2", "Đấu hạng 2vs2", "Đấu máy", "Luyện tập", ...) with their category, icon key, party
## size and ranked flag, and their QuickPlay base (a mode with a queue: {"queue": q}, which the
## Loadout sends to Matchmaking; with a bot: {"bot": it}; neither: practice); the queue mapping
## (the mode of a queue, its name, ranked or not); cycling through the game data's characters,
## the info card text of a character from the PlayerState characters cache, and the remembered
## mode. The mode is kept in the same settings file as the Loadout choice
## (LoadoutModel.SETTINGS_PATH, section "lobby").

const LoadoutModel := preload("res://screens/loadout_model.gd")
const Skills := preload("res://match/skills.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const Progress := preload("res://screens/home/progress.gd")
const Fmt := preload("res://core/fmt.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const SECTION := "lobby"
const MODE_KEY := "mode"

const NONE := {"id": "", "name": "", "description": "", "base": {}, "category": "", "icon": "", "party_size": 1,
	"ranked": false, "queue": "", "max_items": 0}


## The lobby modes in order: [{id, name, description, base, category, icon, party_size, ranked,
## queue, max_items}]. max_items: the items a player takes into it (the game data's maxItems: 6 for
## a boss; without it the global itemRules.maxLoadout). id: the remembered value; base: Router.quick_play_base for the Loadout. party_size: the
## game data's partySize (without it, an older server: matchmaking.teamSize for a queue mode, else
## 1); ranked: GameData.is_ranked_queue() of its queue.
static func modes() -> Array:
	var out: Array = []
	for m in GameData.lobby_modes():
		var queue := str(m.get("queue", "")) if m.get("queue") is String else ""
		var base := {}
		if queue != "":
			base = {"queue": queue}
		elif str(m.get("bot", "")) != "":
			base = {"bot": str(m["bot"])}
		var size = m.get("partySize")
		var party := int(size) if size is int or size is float else (GameData.team_size() if queue != "" else 1)
		var mi = m.get("maxItems")
		var max_items := int(mi) if (mi is int or mi is float) and mi > 0 else GameData.max_loadout()
		out.append({"id": str(m.get("modeId", "")), "name": str(m.get("name", "")), "description": str(m.get("description", "")),
			"base": base, "category": str(m.get("category", "")) if m.get("category") is String else "",
			"icon": str(m.get("icon", "")) if m.get("icon") is String else "", "party_size": maxi(party, 1),
			"ranked": GameData.is_ranked_queue(queue), "queue": queue, "max_items": max_items})
	return out


## The items a player takes into the mode of QuickPlay base `base` (its max_items); the global
## itemRules.maxLoadout when no mode has that base.
static func max_items(base: Dictionary) -> int:
	for m in modes():
		if m["base"] == base:
			return int(m["max_items"])
	return GameData.max_loadout()


## The mode at `index` (clamped); NONE with none.
static func mode(index: int) -> Dictionary:
	var all := modes()
	if all.is_empty():
		return NONE.duplicate(true)
	return all[clampi(index, 0, all.size() - 1)]


## A base that changes rating (its queue's mode is ranked): the mode card shows the rank line.
static func is_ranked(base: Dictionary) -> bool:
	return GameData.is_ranked_queue(str(base.get("queue", "")))


## A queue mode's base (ranked or casual): the Loadout opens Matchmaking instead of sending
## QuickPlay.
static func is_queue(base: Dictionary) -> bool:
	return str(base.get("queue", "")) != ""


## The mode at `index` plays with a teammate (party size 2 or more): the "+" slot, the party flow.
static func is_party(index: int) -> bool:
	return int(mode(index)["party_size"]) >= 2


## The index of the mode that joins `queue`; -1 without one.
static func index_of_queue(queue: String) -> int:
	if queue == "":
		return -1
	var all := modes()
	for i in all.size():
		if all[i]["queue"] == queue:
			return i
	return -1


## The name of the mode that joins `queue` ("Đấu thường 2vs2"); else the match mode's name (the
## id itself when unknown).
static func queue_name(queue: String) -> String:
	var i := index_of_queue(queue)
	return mode(i)["name"] if i >= 0 else GameData.match_mode_name(queue)


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
