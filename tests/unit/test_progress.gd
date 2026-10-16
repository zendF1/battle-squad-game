extends "res://tests/test_case.gd"

const Progress := preload("res://screens/home/progress.gd")


func test_player_exp_needs_level_times_100() -> void:
	var p := Progress.player(3, 120)
	eq(p["needed"], 300, "level 3 needs 300")
	eq(p["text"], "120 / 300", "text")
	near(p["ratio"], 0.4, 0.0001, "ratio")
	eq(Progress.player(1, 500)["current"], 100, "clamped to the level")
	eq(Progress.player(0, -5)["text"], "0 / 100", "bad values")


func test_character_curve_progress() -> void:
	var p := Progress.character({"level": 1, "exp": 50})
	eq(p["text"], "50 / 200", "L1 → L2")
	p = Progress.character({"level": 3, "exp": 550, "nextLevelExp": 700})
	eq(p["text"], "150 / 300", "L3 is 400..700")
	near(p["ratio"], 0.5, 0.0001, "ratio")
	p = Progress.character({"level": 9, "exp": 4600})
	eq(p["text"], "600 / 1200", "L9 is 4000..5200")
	eq(Progress.character({"level": 10, "exp": 5300})["text"], "100 / 1225", "L10 is 5200..6425")
	eq(Progress.character({"level": 40, "exp": 52825, "nextLevelExp": 54800, "isMaxLevel": false})["text"], "0 / 1975", "L40")


func test_character_threshold_default_table() -> void:
	eq(Progress.character_threshold(1), 0, "L1")
	eq(Progress.character_threshold(10), 5200, "L10")
	eq(Progress.character_threshold(11), 6425, "L11")
	eq(Progress.character_threshold(20), 18575, "L20")
	eq(Progress.character_threshold(40), 52825, "L40")
	eq(Progress.character_threshold(75), 136825, "L75")
	eq(Progress.character_threshold(80), 151325, "L80")


func test_character_next_level_exp_overrides_curve() -> void:
	eq(Progress.character({"level": 2, "exp": 300, "nextLevelExp": 500})["text"], "100 / 300", "server threshold")
	eq(Progress.character({"level": 2, "exp": 300, "nextLevelExp": null})["text"], "100 / 200", "null falls back to the curve")


func test_character_max_level() -> void:
	var p := Progress.character({"level": 10, "exp": 6000, "nextLevelExp": null, "isMaxLevel": true})
	check(p["is_max"], "max")
	eq(p["text"], "MAX", "text")
	eq(p["ratio"], 1.0, "full bar")
	check(not Progress.character({"level": 12, "exp": 7000, "isMaxLevel": false})["is_max"], "level 10 is no longer the cap")
	eq(Progress.character({"level": 12, "exp": 7000})["level"], 12, "level not clamped")
	check(Progress.character({"level": 80, "exp": 151325})["is_max"], "end of the default table is max")
	check(not Progress.character({"level": 80, "exp": 151325, "isMaxLevel": false})["is_max"], "server flag wins (longer table)")
	check(Progress.character({"level": 4, "exp": 800, "isMaxLevel": true})["is_max"], "server flag wins")
