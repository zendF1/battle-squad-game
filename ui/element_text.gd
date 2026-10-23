extends RefCounted
## The element (ngũ hành) lines the UI shows, built from the game data (GET /gamedata elements,
## characters[].element, bosses[].element): only the wording around the names is the client's.

const GameData := preload("res://autoload/game_data_model.gd")


## A character's / boss's element detail: "Hệ: Thủy — khắc Hỏa, bị Thổ khắc" (a part the game
## data does not give is left out); "" for no element.
static func detail_line(element_id: String) -> String:
	if element_id == "":
		return ""
	var out := "Hệ: %s" % GameData.element_name(element_id)
	var parts: Array = []
	var beats := GameData.element_beats(element_id)
	if beats != "":
		parts.append("khắc %s" % GameData.element_name(beats))
	var by := GameData.element_beaten_by(element_id)
	if by != "":
		parts.append("bị %s khắc" % GameData.element_name(by))
	if not parts.is_empty():
		out += " — " + ", ".join(parts)
	return out


## The characters a boss is weak to: "Khắc chế: Spark" (several joined by ", "); "" when the game
## data names none.
static func counter_hint(boss_id: String) -> String:
	var names: Array = GameData.boss_counters(boss_id).map(func(id): return GameData.character_name(str(id)))
	return "" if names.is_empty() else "Khắc chế: %s" % ", ".join(names)
