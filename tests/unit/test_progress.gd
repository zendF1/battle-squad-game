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


func test_character_next_level_exp_overrides_curve() -> void:
	eq(Progress.character({"level": 2, "exp": 300, "nextLevelExp": 500})["text"], "100 / 300", "server threshold")
	eq(Progress.character({"level": 2, "exp": 300, "nextLevelExp": null})["text"], "100 / 200", "null falls back to the curve")


func test_character_max_level() -> void:
	var p := Progress.character({"level": 10, "exp": 6000, "nextLevelExp": null, "isMaxLevel": true})
	check(p["is_max"], "max")
	eq(p["text"], "MAX", "text")
	eq(p["ratio"], 1.0, "full bar")
	check(Progress.character({"level": 12, "exp": 0})["is_max"], "past the curve is max")
	check(Progress.character({"level": 4, "exp": 800, "isMaxLevel": true})["is_max"], "server flag wins")
