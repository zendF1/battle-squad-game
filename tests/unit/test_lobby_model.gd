extends "res://tests/test_case.gd"

const LobbyModel := preload("res://screens/home/lobby_model.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const TMP := "user://test_lobby.cfg"

const STATS := {"maxHp": 1540, "defense": 56, "damageBonus": 30, "moveEnergy": 102, "skillPowerBonus": 0,
	"terrainDamageBonus": 0, "weaponDamage": 480}
const BASE_TANKO := {"maxHp": 1950, "defense": 80, "damageBonus": 0, "moveEnergy": 100, "skillPowerBonus": 0,
	"terrainDamageBonus": 0, "weaponDamage": 600}


func test_modes_and_their_quick_play_base() -> void:
	eq(LobbyModel.MODES.size(), 3, "three modes")
	eq(LobbyModel.MODES[0]["name"], "Luyện tập", "practice first")
	eq(LobbyModel.MODES[1]["name"], "Xếp hạng 2v2", "ranked second")
	eq(LobbyModel.MODES[1]["description"], "Ghép 2v2, tính điểm hạng", "ranked description")
	eq(LobbyModel.mode_base(0), {}, "practice target")
	eq(LobbyModel.mode_base(1), {"queue": "ranked_2v2"}, "ranked queue")
	eq(LobbyModel.mode_base(2), {"bot": "ai"}, "vs bot")
	var base := LobbyModel.mode_base(2)
	base["characterId"] = "x"
	eq(LobbyModel.mode_base(2), {"bot": "ai"}, "a copy")
	eq(LobbyModel.next_mode(0), 1, "next")
	eq(LobbyModel.next_mode(2), 0, "wraps")
	eq(LobbyModel.mode_index("bot"), 2, "by id")
	eq(LobbyModel.mode_index("ranked"), 1, "ranked by id")
	eq(LobbyModel.mode_index("arena"), 0, "unknown id is the first")
	eq(LobbyModel.mode_of_base({"bot": "ai"}), 2, "base of vs bot")
	eq(LobbyModel.mode_of_base({"queue": "ranked_2v2"}), 1, "base of ranked")
	eq(LobbyModel.mode_of_base({}), 0, "base of practice")
	eq(LobbyModel.mode_of_base({"bot": "other"}), 0, "unknown base is the first")


func test_ranked_base() -> void:
	check(LobbyModel.is_ranked(LobbyModel.mode_base(1)), "ranked")
	check(not LobbyModel.is_ranked(LobbyModel.mode_base(0)), "practice is not")
	check(not LobbyModel.is_ranked(LobbyModel.mode_base(2)), "vs bot is not")
	check(not LobbyModel.is_ranked({"queue": "other"}), "another queue is not")


func test_cycle_characters_wraps() -> void:
	eq(LobbyModel.cycle_character("rookie", 1), "tanko", "next")
	eq(LobbyModel.cycle_character("flora", 1), "rookie", "wraps forward")
	eq(LobbyModel.cycle_character("rookie", -1), "flora", "wraps back")
	eq(LobbyModel.cycle_character("spark", -1), "tanko", "previous")
	eq(LobbyModel.cycle_character("ghost", 1), "tanko", "unknown counts as the first")


func test_info_before_characters_load() -> void:
	var info := LobbyModel.character_info("rookie", null)
	eq(info["name"], "Rookie", "name")
	eq(info["role"], "Cân bằng", "role")
	eq(info["skill"], "Mưa tên lửa", "skill")
	eq(info["owned"], null, "unknown")
	eq(info["stats"], [], "no stats")
	eq(LobbyModel.level_text(info), "", "no level line")


func test_info_owned_and_not_owned() -> void:
	var entry := {"characterId": "rookie", "level": 3, "exp": 550, "stats": STATS}
	var data := {"characters": [entry], "baseStats": {"tanko": BASE_TANKO}}
	var info := LobbyModel.character_info("rookie", data)
	eq(info["owned"], true, "owned")
	eq(LobbyModel.level_text(info), "Lv.3", "level")
	eq(info["stats"], [["Máu", "1.540"], ["Sát thương", "510"], ["Phòng thủ", "56"]], "battle stats, damage = weapon + bonus")
	var tanko := LobbyModel.character_info("tanko", data)
	eq(tanko["owned"], false, "not owned")
	eq(LobbyModel.level_text(tanko), "Chưa sở hữu", "not owned line")
	eq(tanko["stats"], [["Máu", "1.950"], ["Sát thương", "600"], ["Phòng thủ", "80"]], "base stats")
	var geared := STATS.duplicate()
	geared.merge({"maxHp": 8068, "damageBonus": 1890}, true)
	eq(LobbyModel.stat_pairs(geared), [["Máu", "8.068"], ["Sát thương", "2.370"], ["Phòng thủ", "56"]], "thousands separator")
	var old := LobbyModel.character_info("rookie", {"characters": [{"characterId": "rookie", "level": 2}]})
	eq(old["stats"], [], "an older server without stats")
	eq(LobbyModel.level_text(old), "Lv.2", "level still shown")
	eq(LobbyModel.character_info("spark", {"characters": "bad"})["owned"], null, "malformed is unknown")


func test_mode_remembered_next_to_the_loadout() -> void:
	DirAccess.remove_absolute(TMP)
	eq(LobbyModel.restore_mode(TMP), 0, "no file")
	var m := LoadoutModel.new()
	m.select_character("spark")
	m.toggle_item("medkit")
	m.remember(TMP)
	LobbyModel.remember_mode(TMP, 1)
	eq(LobbyModel.restore_mode(TMP), 1, "mode restored")
	var back := LoadoutModel.new()
	back.restore(TMP)
	eq(back.character_id, "spark", "loadout character kept")
	eq(back.items, ["medkit"] as Array[String], "loadout items kept")
	back.select_character("flora")
	back.remember(TMP)
	eq(LobbyModel.restore_mode(TMP), 1, "the loadout save keeps the mode")
	var cfg := ConfigFile.new()
	cfg.load(TMP)
	cfg.set_value("lobby", "mode", "arena")
	cfg.save(TMP)
	eq(LobbyModel.restore_mode(TMP), 0, "unknown mode falls back")
	DirAccess.remove_absolute(TMP)
