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


func test_ownership_unknown_marks_nothing() -> void:
	var m := LoadoutModel.new()
	eq(m.character_note("tanko"), "", "character unknown")
	eq(m.item_note("medkit"), "", "item unknown")


func test_ownership_notes() -> void:
	var m := LoadoutModel.new()
	m.owned_characters = LoadoutModel.parse_characters({"characters": [{"characterId": "tanko", "level": 1}]})
	m.item_counts = LoadoutModel.parse_inventory([
		{"itemId": "medkit", "quantity": 3}, {"itemId": "medkit", "quantity": 2}, {"itemId": "teleport", "quantity": 0}])
	eq(m.character_note("rookie"), "", "rookie always owned")
	eq(m.character_note("tanko"), "", "owned")
	eq(m.character_note("flora"), "Chưa sở hữu", "not owned")
	eq(m.item_note("medkit"), "x5", "rows summed")
	eq(m.item_note("teleport"), "Chưa sở hữu", "zero")
	eq(m.item_note("air_strike"), "Chưa sở hữu", "absent")


func test_parse_rejects_malformed() -> void:
	eq(LoadoutModel.parse_characters(null), null, "null characters")
	eq(LoadoutModel.parse_characters([]), null, "array is not the envelope")
	eq(LoadoutModel.parse_inventory({}), null, "dict is not the list")
	eq(LoadoutModel.parse_inventory([]), {}, "empty inventory")


func test_character_detail() -> void:
	eq(LoadoutModel.character_detail("rookie"), "Cân bằng\nKỹ năng: Bắn 3 tia", "rookie")
	eq(LoadoutModel.character_detail("flora"), "Hỗ trợ\nKỹ năng: Hồi máu", "flora")


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
