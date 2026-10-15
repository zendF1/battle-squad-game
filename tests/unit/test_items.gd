extends "res://tests/test_case.gd"

const Items := preload("res://match/items.gd")


func test_every_server_item_has_a_label() -> void:
	eq(Items.ORDER.size(), 8, "eight items")
	for id in Items.ORDER:
		check(Items.is_known(id), "known " + id)
	eq(Items.label("medkit"), "Hộp cứu thương", "medkit")
	eq(Items.label("teleport"), "Dịch chuyển", "teleport")
	eq(Items.label("power_shot"), "Tăng lực", "power_shot")
	eq(Items.label("drill_bomb"), "Bom khoan", "drill_bomb")
	eq(Items.label("spider_net"), "Lưới nhện", "spider_net")
	eq(Items.label("freeze_bomb"), "Bom băng", "freeze_bomb")
	eq(Items.label("air_strike"), "Không kích", "air_strike")
	eq(Items.label("wind_stopper"), "Dừng gió", "wind_stopper")
	eq(Items.label("mystery"), "mystery", "unknown shows its id")


func test_only_medkit_and_wind_stopper_are_instant() -> void:
	# The server takes these through UseItem; every other item only through Shoot.
	for id in Items.ORDER:
		eq(Items.is_instant(id), id in ["medkit", "wind_stopper"], "instant " + id)
	check(not Items.is_instant("mystery"), "unknown is not instant")


func test_only_air_strike_needs_target_x() -> void:
	for id in Items.ORDER:
		eq(Items.needs_target_x(id), id == "air_strike", "needs_target_x " + id)


func test_hand_groups_remaining_items() -> void:
	eq(Items.hand(["medkit", "power_shot", "air_strike"]),
		[{"id": "medkit", "count": 1}, {"id": "power_shot", "count": 1}, {"id": "air_strike", "count": 1}], "three")
	eq(Items.hand(["medkit", "x", "medkit"]), [{"id": "medkit", "count": 2}], "duplicates counted, unknown dropped")
	eq(Items.hand([]), [], "empty")
	eq(Items.hand(null), [], "null (no items)")


func test_button_label() -> void:
	eq(Items.button_label("medkit", 1), "Hộp cứu thương", "one")
	eq(Items.button_label("medkit", 2), "Hộp cứu thương x2", "two")


func test_shot_payload() -> void:
	eq(Items.shot_payload("power_shot", 45.0, 60.0),
		{"angle": 45.0, "power": 60.0, "actionMode": "item", "itemId": "power_shot"}, "aimed item")
	var air := Items.shot_payload("air_strike", 45.0, 60.0, 812.5)
	eq(air, {"angle": 270.0, "power": 80.0, "actionMode": "item", "itemId": "air_strike", "targetX": 812.5}, "air strike column")
	check(Items.TARGET_X_POWER >= 0.0 and Items.TARGET_X_POWER <= 100.0, "air strike power in range")
