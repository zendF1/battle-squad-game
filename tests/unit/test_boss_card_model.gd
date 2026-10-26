extends "res://tests/test_case.gd"
## screens/home/boss_card_model.gd: the Boss tab's cards from the game data's boss modes and
## bosses (tests/boss_fixture.gd) and GET /boss/runs; the placeholder only without bosses.

const BossFixture := preload("res://tests/boss_fixture.gd")
const BossCardModel := preload("res://screens/home/boss_card_model.gd")
const ModeSelectModel := preload("res://screens/home/mode_select_model.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const RUNS := {"day": "2026-10-22", "resetAt": "2026-10-22T17:00:00Z", "bosses": [
	{"bossId": "steel_robot", "dailyBonusRuns": 3, "runsToday": 1, "bonusRunsLeft": 2},
	{"bossId": "lava_crab", "dailyBonusRuns": 3, "runsToday": 0, "bonusRunsLeft": 3},
	{"bossId": "ice_witch", "dailyBonusRuns": 3, "runsToday": 4, "bonusRunsLeft": 0},
	{"bossId": "rock_giant", "dailyBonusRuns": 3, "runsToday": 2, "bonusRunsLeft": 1},
	{"bossId": "tree_spirit", "dailyBonusRuns": 3, "runsToday": 0, "bonusRunsLeft": 3}]}


func test_one_card_per_boss_mode_in_order() -> void:
	BossFixture.take()
	var cards := BossCardModel.cards(-1, RUNS, 420)
	eq(cards.map(func(c): return c["boss_id"]), ["steel_robot", "lava_crab", "ice_witch", "rock_giant", "tree_spirit"], "the game data's order")
	eq(cards.map(func(c): return c["name"]), ["Rô-bốt Thép", "Cua Dung Nham", "Phù Thuỷ Băng", "Khổng Lồ Đá", "Mộc Tinh"], "names from bosses")
	eq(cards.map(func(c): return c["level_text"]), ["Lv đề xuất 10", "Lv đề xuất 25", "Lv đề xuất 40", "Lv đề xuất 55", "Lv đề xuất 70"],
		"recommended levels")
	eq(cards.map(func(c): return c["element"]), ["metal", "fire", "water", "earth", "wood"], "their elements (the badges, the backdrops)")
	check(str(cards[0]["description"]).begins_with("Người khổng lồ cơ khí"), "the boss's description")
	eq(cards[0]["index"], LobbyModel.index_of_queue("boss:steel_robot"), "the mode a tap chooses")


func test_runs_left_and_reset_time() -> void:
	BossFixture.take()
	var cards := BossCardModel.cards(-1, RUNS, 420)
	eq(cards.map(func(c): return c["runs_text"]), ["Lượt thưởng lớn: 2/3", "Lượt thưởng lớn: 3/3", "Lượt thưởng lớn: 0/3",
		"Lượt thưởng lớn: 1/3", "Lượt thưởng lớn: 3/3"], "x/N")
	eq(cards[0]["reset_text"], "Làm mới lúc 00:00", "17:00 UTC in UTC+7")
	eq(BossCardModel.reset_text(RUNS, 0), "Làm mới lúc 17:00", "in UTC")
	var loading := BossCardModel.cards(-1, {}, 420)
	eq(loading[0]["runs_text"], BossCardModel.RUNS_LOADING, "not loaded yet")
	eq(loading[0]["runs_left"], -1, "unknown")
	eq(loading[0]["runs_max"], 3, "the game data's dailyBonusRuns")
	eq(loading[0]["reset_text"], "", "no reset time yet")


func test_selected_card() -> void:
	BossFixture.take()
	var i := LobbyModel.index_of_queue("boss:lava_crab")
	var cards := BossCardModel.cards(i, RUNS, 0)
	eq(cards.map(func(c): return c["selected"]), [false, true, false, false, false], "the chosen boss")


func test_boss_modes_join_by_mode_or_queue() -> void:
	BossFixture.take()
	var d: Dictionary = GameData.data.duplicate(true)
	for b in d["bosses"]:
		b["modeId"] = "" # an entry without its mode id: the queue tells
	d["version"] = "no-mode-ids"
	GameData.take(d, "", false)
	eq(BossCardModel.cards(-1, null, 0).map(func(c): return c["boss_id"]), ["steel_robot", "lava_crab", "ice_witch", "rock_giant", "tree_spirit"],
		"by queue")


func test_placeholder_only_without_bosses() -> void:
	BossFixture.take()
	var boss_section: Dictionary = ModeSelectModel.sections(0).filter(func(s): return s["categoryId"] == "boss")[0]
	eq(boss_section["modes"].size(), 5, "five boss modes: no placeholder")
	var d: Dictionary = GameData.data.duplicate(true)
	d["modes"]["lobby"] = d["modes"]["lobby"].filter(func(m): return m["category"] != "boss")
	d["bosses"] = []
	d["version"] = "no-bosses"
	GameData.take(d, "", false)
	boss_section = ModeSelectModel.sections(0).filter(func(s): return s["categoryId"] == "boss")[0]
	check(boss_section["modes"].is_empty(), "no boss modes: the placeholder shows")
	eq(BossCardModel.cards(0, RUNS, 0), [], "no cards")


func test_game_data_bosses() -> void:
	BossFixture.take()
	eq(GameData.boss_of_queue("boss:ice_witch")["name"], "Phù Thuỷ Băng", "by queue")
	eq(GameData.boss_of_mode("boss_lava_crab")["bossId"], "lava_crab", "by mode")
	check(GameData.is_boss_queue("boss:steel_robot") and not GameData.is_boss_queue("casual_2v2"), "boss queues")
	eq(GameData.boss_minion("steel_robot", "drone")["hp"], 650, "a minion")
	eq(GameData.boss_minion("", "snowman")["name"], "Người tuyết", "a minion of any boss")
	eq(GameData.boss_skill("", "fire_bombs")["kind"], "rain", "a boss skill")
	eq(GameData.body_size_of(GameData.boss("lava_crab")), 3.2, "body size")
	eq(GameData.body_size_of({}), 1.0, "none: a player's")
	eq(LobbyModel.mode(LobbyModel.index_of_queue("boss:steel_robot"))["party_size"], 4, "a party of four")
