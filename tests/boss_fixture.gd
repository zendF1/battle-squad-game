extends RefCounted
## The boss mode's game data for tests and previews: tests/fixtures/boss_gamedata.json (the
## modes.lobby / modes.categories / modes.match entries and the bosses of GET /gamedata since the
## server's boss mode, migrations 044–046) merged over the game data in use.

const GameData := preload("res://autoload/game_data_model.gd")
const PATH := "res://tests/fixtures/boss_gamedata.json"


## The extra data: {categories, lobby, match, bosses}.
static func extra() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return d if d is Dictionary else {}


## The game data in use with the boss modes and bosses (modes.lobby replaced, the match modes
## added).
static func merged() -> Dictionary:
	var e := extra()
	var d: Dictionary = GameData.data.duplicate(true)
	d["version"] = "boss-fixture"
	var modes: Dictionary = d.get("modes", {})
	modes["categories"] = e.get("categories", [])
	modes["lobby"] = e.get("lobby", [])
	modes["match"] = modes.get("match", []) + e.get("match", [])
	d["modes"] = modes
	d["bosses"] = e.get("bosses", [])
	return d


## Takes merged() as the game data in use.
static func take() -> void:
	GameData.take(merged(), "", false)
