extends "res://tests/test_case.gd"

const ChestModel := preload("res://screens/home/chest_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")


func test_game_data_chests() -> void:
	eq(GameData.chest_name("stone_chest"), "Rương đá", "name")
	eq(GameData.chest_name("mystery"), "mystery", "unknown: the id")
	eq(GameData.chest_kind("equip_chest_16"), "equipment", "kind")
	eq(GameData.chest_upgrade_level("equip_chest_14"), 14, "upgrade level")
	eq(GameData.chest_stones("stone_chest").size(), 3, "three rolls")


func test_odds_text() -> void:
	eq(ChestModel.odds_text("stone_chest"), "60% Đá 5 · 30% Đá 6 · 10% Đá 7", "the stone chest's odds")
	eq(ChestModel.odds_text("equip_chest_14"), "1 trang bị +14 ngẫu nhiên", "an equipment chest")
	eq(ChestModel.odds_text("mystery"), "", "unknown")
	var d: Dictionary = GameData.data.duplicate(true)
	d["chests"][0]["stones"] = [{"level": 3, "weight": 1}, {"level": 4, "weight": 2}, {"level": 9, "weight": 0}]
	d["version"] = "chest-odds"
	GameData.take(d, "", false)
	eq(ChestModel.odds_text("stone_chest"), "33% Đá 3 · 67% Đá 4", "weights as shares, zero weights left out")


func test_parse_owned() -> void:
	var owned = ChestModel.parse_owned({"chests": [{"chestId": "equip_chest_16", "quantity": 1}, {"chestId": "stone_chest", "quantity": 12},
		{"chestId": "zzz", "quantity": 2}, {"chestId": "equip_chest_14", "quantity": 0}, "junk", {"quantity": 3}]})
	eq(owned.map(func(c): return [c["chestId"], c["quantity"]]), [["stone_chest", 12], ["equip_chest_16", 1], ["zzz", 2]],
		"game data order, unknown last, none at 0")
	eq(owned[0]["name"], "Rương đá", "named")
	eq(ChestModel.parse_owned({"chests": []}), [], "none")
	eq(ChestModel.parse_owned({}), null, "not a chest list")
	eq(ChestModel.parse_owned(null), null, "no data")


func test_open_buttons() -> void:
	eq(ChestModel.open_buttons(0), [], "nothing to open")
	eq(ChestModel.open_buttons(1), [{"text": "Mở", "count": 1}], "one")
	eq(ChestModel.open_buttons(3), [{"text": "Mở", "count": 1}, {"text": "Mở 3", "count": 3}], "fewer than ten: all")
	eq(ChestModel.open_buttons(25)[1], {"text": "Mở 10", "count": 10}, "ten at most")


func test_parse_open_and_lines() -> void:
	var r := ChestModel.parse_open({"chestId": "stone_chest", "opened": 3, "stones": [{"level": 6, "qty": 1}, {"level": 5, "qty": 1},
		{"level": 5, "qty": 1}, {"level": 0, "qty": 4}], "equipment": []})
	eq(r["stones"], [{"level": 5, "qty": 2}, {"level": 6, "qty": 1}], "merged by level")
	eq(ChestModel.opened_text(r), "Mở 3 Rương đá", "heading")
	eq(ChestModel.open_lines(r, null).map(func(l): return l["text"]), ["2 × Đá cấp 5", "1 × Đá cấp 6"], "stone lines")
	var catalog := {"items": {"normal_armor_lv40": {"itemId": "normal_armor_lv40", "slot": "armor", "name": "Dragon Vest", "tier": "dragon"}}}
	var e := ChestModel.parse_open({"chestId": "equip_chest_14", "opened": 1,
		"equipment": [{"equipmentId": "e9", "itemId": "normal_armor_lv40", "upgradeLevel": 14}, {"itemId": "ghost_item", "upgradeLevel": 14}]})
	eq(e["equipment"].size(), 2, "pieces")
	var lines := ChestModel.open_lines(e, catalog)
	check(lines[0]["text"].ends_with("+14") and lines[0]["text"] != "normal_armor_lv40 +14", "a catalog piece: its name +14 (%s)" % lines[0]["text"])
	eq(lines[1]["text"], "ghost_item +14", "not in the catalog: its id")
	eq(ChestModel.parse_open(null), {}, "not an answer")


func test_match_chests() -> void:
	var c := ChestModel.match_chests([{"chestId": "stone_chest", "quantity": 2}, {"chestId": "stone_chest", "quantity": 0}, "x"])
	eq(c, [{"chestId": "stone_chest", "qty": 2, "name": "Rương đá", "text": "2 × Rương đá"}], "a bonus run's chests")
	eq(ChestModel.match_chests(null), [], "none")
	eq(ChestModel.count_text(1200), "×1.200", "count")
