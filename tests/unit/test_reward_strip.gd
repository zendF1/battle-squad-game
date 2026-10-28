extends "res://tests/test_case.gd"
## ui/reward_strip.gd and ResultModel.reward_tiles(): the reward tiles (icon + count, no names),
## all one size, centred while they fit, scrolling sideways (clamped) when they overflow; the boss
## result's rewards card uses them.

const BossFixture := preload("res://tests/boss_fixture.gd")
const ResultModel := preload("res://match/result_model.gd")
const BossResultModel := preload("res://match/boss/boss_result_model.gd")
const BossResultScreen := preload("res://match/boss/boss_result_screen.gd")
const RewardStrip := preload("res://ui/reward_strip.gd")


static func _reward() -> Dictionary:
	return BossResultModel.reward({"expGained": 393, "coinGained": 1200, "bonusRun": true, "bonusRunsLeft": 1,
		"stones": [{"level": 3, "qty": 1}, {"level": 1, "qty": 2}],
		"chests": [{"chestId": "stone_chest", "quantity": 3}],
		"items": [{"itemId": "medkit", "quantity": 2}, {"itemId": "teleport", "quantity": 1}]}, "")


func test_tiles_in_order() -> void:
	BossFixture.take()
	var tiles := ResultModel.reward_tiles(_reward())
	eq(tiles.map(func(t): return [t["kind"], t["id"], t["qty"]]),
		[["coin", "coin", 1200], ["stone", "stone_1", 2], ["stone", "stone_3", 1], ["chest", "stone_chest", 3],
		["item", "medkit", 2], ["item", "teleport", 1]], "coins, stones (lowest first), chests, items")
	eq(tiles[2]["level"], 3, "a stone's level")
	check(str(tiles[4]["name"]) != "" and str(tiles[4]["name"]) != "medkit", "the item's name (tooltip) from the game data")
	eq(ResultModel.reward_tiles(BossResultModel.reward({"expGained": 5}, "")), [], "nothing won: no tiles")
	eq(ResultModel.reward_tiles(BossResultModel.reward(null, "")), [], "not granted: no tiles")
	eq([ResultModel.tile_qty_text(3), ResultModel.tile_qty_text(1200)], ["×3", "×1.200"], "counts")


func test_fits_centred() -> void:
	BossFixture.take()
	var s: Control = RewardStrip.new()
	s.size = Vector2(1000, 130)
	s.set_tiles(ResultModel.reward_tiles(_reward()))
	var w: float = s.content_width()
	eq(w, 6 * RewardStrip.TILE.x + 5 * RewardStrip.GAP, "six tiles and their gaps")
	check(s.fits(), "fits")
	var row: Control = s.get_node("Row")
	near(row.position.x, (1000.0 - w) / 2.0, 0.01, "centred")
	s.scroll = 200.0
	eq(s.scroll, 0.0, "a row that fits does not scroll")
	var sizes := {}
	var ys := {}
	for c in row.get_children():
		sizes[c.size] = true
		ys[c.position.y] = true
		var labels := _labels(c)
		eq(labels.size(), 1, "%s: the count only (no name)" % c.name)
		check(labels.size() == 1 and labels[0].begins_with("×"), "%s: ×N" % c.name)
	eq(sizes.keys(), [RewardStrip.TILE], "one tile size")
	eq(ys.size(), 1, "one row, no wrapping")
	check(row.get_node("Tile_stone_3").find_child("Level", true, false) != null, "a stone's level badge")
	eq(s.qty_label("coin").text, "×1.200", "the coin count")
	check(s.qty_label("gem") == null, "no such tile")
	s.free()


func test_overflow_scrolls() -> void:
	BossFixture.take()
	var s: Control = RewardStrip.new()
	s.size = Vector2(300, 130)
	s.set_tiles(ResultModel.reward_tiles(_reward()))
	check(not s.fits(), "too wide")
	var row: Control = s.get_node("Row")
	eq(row.position.x, 0.0, "starts at the left")
	for c in row.get_children():
		eq(c.size, RewardStrip.TILE, "%s: not shrunk" % c.name)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	s._gui_input(wheel)
	eq(s.scroll, RewardStrip.WHEEL_STEP, "the wheel scrolls right")
	eq(row.position.x, -RewardStrip.WHEEL_STEP, "the row moves left")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	s._gui_input(press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(-100, 0)
	s._gui_input(drag)
	eq(s.scroll, RewardStrip.WHEEL_STEP + 100.0, "a drag to the left scrolls right")
	s.scroll = 99999.0
	eq(s.scroll, s.content_width() - 300.0, "clamped at the end")
	s.scroll = -50.0
	eq(s.scroll, 0.0, "clamped at the start")
	eq(s.edge_alpha(0.0), 1.0, "a tile fully shown: opaque")
	eq(s.edge_alpha(300.0), RewardStrip.EDGE_ALPHA, "a tile past the edge: faded")
	check(s.edge_alpha(-RewardStrip.TILE.x / 2.0) < 1.0, "half out: fading")
	s.free()


func test_boss_result_card_uses_the_strip() -> void:
	BossFixture.take()
	var info := BossResultModel.info({"winningTeam": 1, "result": "boss_defeated", "boss": {"bossId": "steel_robot",
		"round": 5, "turnLimit": 20, "bossHp": 0, "bossMaxHp": 19000, "bossDamage": {"me": 9000}}},
		{"me": {"playerId": "me", "teamId": 1, "characterId": "rookie", "displayName": "Tôi"}}, "me", "",
		{"expGained": 10, "coinGained": 1200, "bonusRun": true, "bonusRunsLeft": 2,
		"chests": [{"chestId": "stone_chest", "quantity": 3}], "items": [{"itemId": "medkit", "quantity": 2}]})
	var s: Control = BossResultScreen.new()
	s.setup(info)
	var bottom: Control = s._build_bottom()
	var strip = bottom.find_child("Items", true, false)
	check(strip != null and strip.get_script() == RewardStrip, "the reward strip")
	if strip != null:
		eq(strip.tiles.map(func(t): return t["kind"]), ["coin", "chest", "item"], "coin, chest, item tiles")
	var texts := _all_labels(bottom)
	var medkit_name := BossResultModel.item_name("medkit")
	check(not texts.any(func(t): return medkit_name in t), "no item names")
	check(not texts.any(func(t): return "Sát thương boss" in t), "no damage line (the podium shows it)")
	check(not texts.any(func(t): return " xu" in t), "the coins as a tile, no \"xu\"")
	bottom.free()
	s.free()


## A tile's labels, its stone level badge left out.
static func _labels(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Label:
			out.append(c.text)
		elif c.name != "Level":
			out.append_array(_labels(c))
	return out


static func _all_labels(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Label:
			out.append(c.text)
		out.append_array(_all_labels(c))
	return out
