extends "res://tests/test_case.gd"

const LoadoutModel := preload("res://screens/loadout_model.gd")
const TMP := "user://test_loadout.cfg"


func test_defaults_and_payload() -> void:
	var m := LoadoutModel.new()
	eq(m.payload({}), {"characterId": "rookie", "items": []}, "practice default")
	m.select_character("spark")
	m.toggle_item("medkit")
	m.toggle_item("air_strike")
	eq(m.payload({"bot": "ai"}), {"bot": "ai", "characterId": "spark", "items": ["medkit", "air_strike"]}, "vs bot")
	m.select_character("nobody")
	eq(m.character_id, "spark", "unknown character ignored")


func test_at_most_three_items() -> void:
	var m := LoadoutModel.new()
	check(m.toggle_item("medkit") and m.toggle_item("teleport") and m.toggle_item("power_shot"), "three picked")
	check(m.is_full(), "full")
	check(not m.toggle_item("drill_bomb"), "fourth refused")
	eq(m.items, ["medkit", "teleport", "power_shot"] as Array[String], "unchanged")
	check(m.toggle_item("teleport"), "drop")
	eq(m.items, ["medkit", "power_shot"] as Array[String], "dropped")
	check(not m.toggle_item("mystery"), "unknown item refused")


func test_slots_follow_the_pick_order() -> void:
	var m := LoadoutModel.new()
	eq(m.slots(), ["", "", ""] as Array[String], "three empty slots")
	m.toggle_item("freeze_bomb")
	m.toggle_item("medkit")
	eq(m.slots(), ["freeze_bomb", "medkit", ""] as Array[String], "filled in order")
	m.toggle_item("air_strike")
	m.toggle_item("freeze_bomb") # tapping a slot drops its item; the rest move up
	eq(m.slots(), ["medkit", "air_strike", ""] as Array[String], "dropped from the first slot")


func test_item_ownership_unknown_marks_nothing() -> void:
	var m := LoadoutModel.new()
	eq(m.item_note("medkit"), "", "item unknown")


func test_item_ownership_notes() -> void:
	var m := LoadoutModel.new()
	m.item_counts = LoadoutModel.parse_inventory([
		{"itemId": "medkit", "quantity": 3}, {"itemId": "medkit", "quantity": 2}, {"itemId": "teleport", "quantity": 0}])
	eq(m.item_note("medkit"), "x5", "rows summed")
	eq(m.item_note("teleport"), "Chưa sở hữu", "zero")
	eq(m.item_note("air_strike"), "Chưa sở hữu", "absent")


func test_parse_rejects_malformed() -> void:
	eq(LoadoutModel.parse_characters({"characters": [{"characterId": "tanko"}, {"level": 1}]}), ["tanko"], "owned ids")
	eq(LoadoutModel.parse_characters(null), null, "null characters")
	eq(LoadoutModel.parse_characters([]), null, "array is not the envelope")
	eq(LoadoutModel.parse_inventory({}), null, "dict is not the list")
	eq(LoadoutModel.parse_inventory([]), {}, "empty inventory")


func test_remember_and_restore() -> void:
	var m := LoadoutModel.new()
	m.select_character("flora")
	m.toggle_item("wind_stopper")
	m.toggle_item("medkit")
	m.remember(TMP)
	var back := LoadoutModel.new()
	back.restore(TMP)
	eq(back.character_id, "flora", "character restored")
	eq(back.items, ["wind_stopper", "medkit"] as Array[String], "items restored")
	var cfg := ConfigFile.new()
	cfg.set_value("loadout", "character_id", "ghost")
	cfg.set_value("loadout", "items", ["medkit", "medkit", "bogus", "teleport", "power_shot", "drill_bomb"])
	cfg.save(TMP)
	var cleaned := LoadoutModel.new()
	cleaned.restore(TMP)
	eq(cleaned.character_id, "rookie", "unknown character dropped")
	eq(cleaned.items, ["medkit", "teleport", "power_shot"] as Array[String], "deduped, known, at most three")
	DirAccess.remove_absolute(TMP)
	var missing := LoadoutModel.new()
	missing.restore(TMP)
	eq(missing.character_id, "rookie", "no file keeps defaults")


func test_item_with_none_left_cannot_be_picked() -> void:
	var m := LoadoutModel.new()
	check(m.owns("power_shot"), "counts unknown: the server decides")
	m.set_counts(LoadoutModel.parse_inventory([{"itemId": "medkit", "quantity": 2}, {"itemId": "teleport", "quantity": 0}]))
	check(m.owns("medkit"), "owned")
	check(not m.owns("teleport"), "zero")
	check(not m.owns("power_shot"), "absent")
	check(not m.toggle_item("power_shot"), "not owned refused")
	check(not m.toggle_item("teleport"), "used up refused")
	check(m.toggle_item("medkit"), "owned picked")
	eq(m.items, ["medkit"] as Array[String], "only the owned one")


func test_counts_clean_a_saved_loadout() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("loadout", "character_id", "flora")
	cfg.set_value("loadout", "items", ["power_shot", "medkit", "spider_net"])
	cfg.save(TMP)
	var m := LoadoutModel.new()
	m.restore(TMP)
	eq(m.items, ["power_shot", "medkit", "spider_net"] as Array[String], "restored before the counts")
	eq(m.set_counts(null), [] as Array[String], "unknown counts drop nothing")
	var dropped := m.set_counts(LoadoutModel.parse_inventory([{"itemId": "medkit", "quantity": 1}, {"itemId": "spider_net", "quantity": 2}]))
	eq(dropped, ["power_shot"] as Array[String], "the unowned one dropped")
	eq(m.items, ["medkit", "spider_net"] as Array[String], "the rest kept in order")
	# A match used the last medkit: the next counts drop it too.
	eq(m.set_counts(LoadoutModel.parse_inventory([{"itemId": "spider_net", "quantity": 1}])), ["medkit"] as Array[String], "used up")
	eq(m.payload({}), {"characterId": "flora", "items": ["spider_net"]}, "payload")
	DirAccess.remove_absolute(TMP)


func test_payload_never_sends_an_item_with_none_left() -> void:
	var m := LoadoutModel.new()
	m.toggle_item("power_shot") # picked while the counts were unknown
	m.toggle_item("medkit")
	m.item_counts = {"medkit": 1} # set without set_counts: the payload still filters
	eq(m.payload({"bot": "ai"}), {"bot": "ai", "characterId": "rookie", "items": ["medkit"]}, "power_shot left out")


## The mode's item slots (modes.lobby maxItems: 6 for a boss fight), the global itemRules rule
## without it; a smaller mode drops the last picks; the Loadout's slot rows.
func test_mode_max_items() -> void:
	var LobbyModel := load("res://screens/home/lobby_model.gd")
	var Loadout := load("res://screens/loadout.gd")
	var BossFixture := load("res://tests/boss_fixture.gd")
	var GameData := load("res://autoload/game_data_model.gd")
	BossFixture.take() # the server's modes.lobby, maxItems 6 for a boss and 3 for the rest (85c3591)
	var boss := {"queue": "boss:lava_crab"}
	eq(LobbyModel.max_items(boss), 6, "a boss fight: 6")
	eq(LobbyModel.max_items({"queue": "nope"}), 3, "an unknown mode: the global rule")
	var old: Dictionary = GameData.data.duplicate(true)
	old["version"] = "no-max-items"
	for m in old["modes"]["lobby"]:
		m.erase("maxItems")
	GameData.take(old, "", false)
	eq(LobbyModel.max_items(boss), 3, "no maxItems (an older server): the global rule")
	BossFixture.take()
	eq(LobbyModel.max_items({"queue": "casual_2v2"}), 3, "PvP: 3")
	eq(LobbyModel.max_items({}), 3, "practice: 3")
	var m := LoadoutModel.new()
	m.set_max_items(LobbyModel.max_items(boss))
	for id in ["medkit", "teleport", "power_shot", "air_strike", "drill_bomb", "freeze_bomb"]:
		check(m.toggle_item(id), "%s picked" % id)
	check(m.is_full() and not m.toggle_item("spider_net"), "a seventh refused")
	eq(m.slots().size(), 6, "six slots")
	m.set_max_items(3)
	eq(m.items, ["medkit", "teleport", "power_shot"] as Array[String], "a 3-item mode: the first 3 shown")
	eq(m.payload({})["items"], ["medkit", "teleport", "power_shot"], "and sent")
	eq(m.hidden_items, ["air_strike", "drill_bomb", "freeze_bomb"] as Array[String], "the rest set aside")
	m.remember(TMP)
	var back := LoadoutModel.new()
	back.restore(TMP)
	eq(back.items.size(), 3, "restored for a 3-item mode: 3 shown")
	back.set_max_items(6)
	eq(back.items.size(), 6, "the saved loadout kept whole: 6 again in a boss mode")
	m.toggle_item("teleport")
	m.toggle_item("air_strike")
	eq([m.items, m.hidden_items], [["medkit", "power_shot", "air_strike"] as Array[String], ["drill_bomb", "freeze_bomb"] as Array[String]],
		"picking a set-aside item moves it into the slots")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	eq([Loadout.slot_rows(3), Loadout.slot_rows(4), Loadout.slot_rows(5), Loadout.slot_rows(6), Loadout.slot_rows(0)],
		[[3], [4], [3, 2], [3, 3], []], "slot rows: one row up to 4, then two")
