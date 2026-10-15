extends "res://tests/test_case.gd"

const Status := preload("res://match/status_effects.gd")


func test_has_needs_turns_left() -> void:
	var effects := [{"effectId": "freeze", "durationTurn": 1}, {"effectId": "net", "durationTurn": 0}]
	check(Status.has(effects, "freeze"), "freeze active")
	check(not Status.has(effects, "net"), "net expired")
	check(not Status.has(null, "freeze"), "null list")


func test_marker_text() -> void:
	eq(Status.marker_text([{"effectId": "net", "durationTurn": 1}]), "Lưới", "net")
	eq(Status.marker_text([{"effectId": "freeze", "durationTurn": 1}, {"effectId": "power_shot", "durationTurn": 1}]), "Băng · x1.5", "two")
	eq(Status.marker_text([{"effectId": "heal", "durationTurn": 1}]), "", "heal shows nothing")
	eq(Status.marker_text([{"effectId": "net", "durationTurn": 0}]), "", "expired")
	eq(Status.marker_text([{"effectId": "drill_bomb", "durationTurn": 1}, {"effectId": "drill_bomb", "durationTurn": 2}]), "Khoan", "once")
	eq(Status.marker_text(null), "", "null")
	for id in ["spider_net", "freeze_bomb", "air_strike"]:
		check(Status.marker_text([{"effectId": id, "durationTurn": 1}]) != "", "armed marker " + id)


func test_apply_overrides_or_adds() -> void:
	var base := [{"effectId": "net", "durationTurn": 1, "value": 0.0}]
	var again := Status.apply(base, "net", 2)
	eq(again.size(), 1, "same effect merged")
	eq(again[0]["durationTurn"], 2, "duration overridden")
	eq(base[0]["durationTurn"], 1, "input untouched")
	var added := Status.apply(base, "freeze", 1)
	eq(added.size(), 2, "new effect added")
	eq(Status.apply(null, "freeze", 1), [{"effectId": "freeze", "durationTurn": 1}], "from null")


func test_tick_drops_expired() -> void:
	var effects := [{"effectId": "net", "durationTurn": 1}, {"effectId": "freeze", "durationTurn": 2}]
	eq(Status.tick(effects), [{"effectId": "freeze", "durationTurn": 1}], "one turn less")
	eq(effects[1]["durationTurn"], 2, "input untouched")
	eq(Status.tick(null), [], "null")
