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
	eq(ChestModel.open_buttons(1), [{"text": "×1", "count": 1}], "one")
	eq(ChestModel.open_buttons(3), [{"text": "×1", "count": 1}, {"text": "×3", "count": 3}], "fewer than ten: all")
	eq(ChestModel.open_buttons(25)[1], {"text": "×10", "count": 10}, "ten at most")


func test_parse_open() -> void:
	var r := ChestModel.parse_open({"chestId": "stone_chest", "opened": 3, "stones": [{"level": 6, "qty": 1}, {"level": 5, "qty": 1},
		{"level": 5, "qty": 1}, {"level": 0, "qty": 4}], "equipment": []})
	eq(r["stones"], [{"level": 5, "qty": 2}, {"level": 6, "qty": 1}], "merged by level")
	var e := ChestModel.parse_open({"chestId": "equip_chest_14", "opened": 1,
		"equipment": [{"equipmentId": "e9", "itemId": "normal_armor_lv40", "upgradeLevel": 14}, {"itemId": "ghost_item", "upgradeLevel": 14}]})
	eq(e["equipment"].size(), 2, "pieces")
	eq(e["equipment"][0], {"equipmentId": "e9", "itemId": "normal_armor_lv40", "upgradeLevel": 14}, "a piece")
	eq(ChestModel.parse_open(null), {}, "not an answer")


func test_match_chests() -> void:
	var c := ChestModel.match_chests([{"chestId": "stone_chest", "quantity": 2}, {"chestId": "stone_chest", "quantity": 0}, "x"])
	eq(c, [{"chestId": "stone_chest", "qty": 2, "name": "Rương đá", "text": "2 × Rương đá"}], "a bonus run's chests")
	eq(ChestModel.match_chests(null), [], "none")
	eq(ChestModel.count_text(1200), "×1.200", "count")


func test_kho_do_tabs_by_kind() -> void:
	eq(ChestModel.tab_of("stone_chest"), ChestModel.TAB_MATERIALS, "a stone chest: Nguyên liệu, with the stones")
	eq(ChestModel.tab_of("equip_chest_14"), ChestModel.TAB_ITEMS, "an equipment chest: Vật phẩm")
	eq(ChestModel.tab_of("equip_chest_16"), ChestModel.TAB_ITEMS, "every equipment chest")
	eq(ChestModel.tab_of("mystery"), ChestModel.TAB_ITEMS, "an unknown chest: Vật phẩm")
	var owned = ChestModel.parse_owned({"chests": [{"chestId": "equip_chest_16", "quantity": 1}, {"chestId": "stone_chest", "quantity": 12},
		{"chestId": "equip_chest_14", "quantity": 2}, {"chestId": "zzz", "quantity": 1}]})
	var tabs := ChestModel.by_tab(owned)
	eq(tabs[ChestModel.TAB_MATERIALS].map(func(c): return c["chestId"]), ["stone_chest"], "materials: the stone chest")
	eq(tabs[ChestModel.TAB_ITEMS].map(func(c): return c["chestId"]), ["equip_chest_14", "equip_chest_16", "zzz"],
		"items: the equipment chests in the game data's order, the unknown last")
	eq(ChestModel.by_tab(null), {ChestModel.TAB_MATERIALS: [], ChestModel.TAB_ITEMS: []}, "not loaded: nothing in either")
	eq(ChestModel.by_tab([]), {ChestModel.TAB_MATERIALS: [], ChestModel.TAB_ITEMS: []}, "none owned")


func test_kho_do_tabs_follow_the_game_data_kind() -> void:
	var d: Dictionary = GameData.data.duplicate(true)
	d["chests"].append({"chestId": "gem_box", "name": "Hộp đá quý", "kind": "", "stones": [{"level": 9, "weight": 1}], "upgradeLevel": 0})
	d["chests"][1]["kind"] = "stone" # an admin turned it into a stone chest
	d["version"] = "chest-kinds"
	GameData.take(d, "", false)
	eq(ChestModel.tab_of("equip_chest_14"), ChestModel.TAB_MATERIALS, "the kind decides, not the id")
	eq(ChestModel.tab_of("gem_box"), ChestModel.TAB_MATERIALS, "no kind but stone rolls: with the stones")


func test_odds_as_pictures() -> void:
	eq(ChestModel.odds_parts("stone_chest"), [{"level": 5, "pct": 60}, {"level": 6, "pct": 30}, {"level": 7, "pct": 10}], "stone icons over shares")
	eq(ChestModel.odds_parts("equip_chest_14"), [{"upgrade": 14}], "a piece over +14")
	eq(ChestModel.odds_parts("mystery"), [], "unknown")
