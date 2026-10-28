extends "res://tests/test_case.gd"
## ui/reward_model.gd (tiles from every granting answer, merged, weakest first, the glow by stone
## level / upgrade tier / kind), ui/reward_strip.gd's rows and glow tiles, ui/reward_reveal.gd's
## phases (drop → shake → burst → fly → show → collect) and skipping ahead.

const BossFixture := preload("res://tests/boss_fixture.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const RewardStrip := preload("res://ui/reward_strip.gd")
const RewardReveal := preload("res://ui/reward_reveal.gd")
const RewardBox := preload("res://ui/reward_box.gd")
const ChestModel := preload("res://screens/home/chest_model.gd")
const MilestoneModel := preload("res://screens/home/milestone_model.gd")
const SeasonRewardModel := preload("res://screens/ranked/season_reward_model.gd")
const ResultModel := preload("res://match/result_model.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")


static func _ids(tiles: Array) -> Array:
	return tiles.map(func(t): return [t["kind"], t["id"], int(t["qty"])])


func test_merge_and_order() -> void:
	BossFixture.take()
	var tiles := RewardModel.merge([RewardModel.tile("stone", "stone_6", 2, 6), RewardModel.tile("coin", "coin", 100),
		RewardModel.tile("stone", "stone_5", 3, 5), RewardModel.tile("stone", "stone_6", 1, 6), RewardModel.tile("item", "medkit", 0),
		RewardModel.tile("stone", "stone_7", 1, 7), {"kind": "nonsense", "id": "x", "qty": 3}])
	eq(_ids(tiles), [["coin", "coin", 100], ["stone", "stone_5", 3], ["stone", "stone_6", 3], ["stone", "stone_7", 1]],
		"merged by reward, nothing empty or unknown, weakest first (the best last)")
	check(tiles.all(func(t): return t.has("name") and str(t["name"]) != ""), "each has a tooltip name")
	eq(RewardModel.qty_text(1200), "×1.200", "counts")


func test_glow_by_level_and_tier() -> void:
	BossFixture.take()
	var g5 := RewardModel.glow(RewardModel.tile("stone", "stone_5", 1, 5))
	var g6 := RewardModel.glow(RewardModel.tile("stone", "stone_6", 1, 6))
	var g7 := RewardModel.glow(RewardModel.tile("stone", "stone_7", 1, 7))
	var g1 := RewardModel.glow(RewardModel.tile("stone", "stone_1", 1, 1))
	eq([g5["rung"], g6["rung"]], [RewardModel.GOLD, RewardModel.GOLD], "stone lv 5–6: gold")
	eq(g7["rung"], RewardModel.RED_GOLD, "lv 7: red-gold")
	check(float(g1["power"]) < float(g5["power"]) and float(g5["power"]) < float(g7["power"]), "higher = brighter")
	var e16 := RewardModel.glow(RewardModel.tile("equipment", "x", 1, 0, 16))
	var e14 := RewardModel.glow(RewardModel.tile("equipment", "x", 1, 0, 14))
	var e0 := RewardModel.glow(RewardModel.tile("equipment", "x", 1, 0, 0))
	eq(e16["rung"], RewardModel.RED_GOLD, "+16 red-gold")
	eq(e16["accent"], RewardModel.RUNGS[RewardModel.RED_GOLD]["accent"], "+16 gold rays")
	eq(e14["color"], UpgradeModel.milestone_color(14), "+14 in its upgrade colour")
	check(float(e0["power"]) < float(e14["power"]) and float(e14["power"]) < float(e16["power"]), "+0 < +14 < +16")
	check(float(RewardModel.glow(RewardModel.tile("coin", "coin", 9))["power"]) < float(g5["power"]), "coins glow less than good stones")
	var eq16 := RewardModel.glow(RewardModel.tile("chest", "equip_chest_16", 1))
	eq(eq16["rung"], RewardModel.RED_GOLD, "the +16 chest glows like its pieces")
	eq(RewardModel.best_glow([RewardModel.tile("coin", "coin", 5), RewardModel.tile("stone", "stone_7", 1, 7)])["rung"],
		RewardModel.RED_GOLD, "the best glow")


func test_from_chest_open() -> void:
	BossFixture.take()
	var result := ChestModel.parse_open({"chestId": "stone_chest", "opened": 10,
		"stones": [{"level": 6, "qty": 3}, {"level": 5, "qty": 6}, {"level": 7, "qty": 1}]})
	eq(_ids(RewardModel.from_chest_open(result)), [["stone", "stone_5", 6], ["stone", "stone_6", 3], ["stone", "stone_7", 1]],
		"10 stone chests: one tile per stone level")
	var eq_result := ChestModel.parse_open({"chestId": "equip_chest_16", "opened": 3, "stones": [],
		"equipment": [{"equipmentId": "a", "itemId": "normal_helmet_lv20", "upgradeLevel": 16},
			{"equipmentId": "b", "itemId": "normal_armor_lv20", "upgradeLevel": 16},
			{"equipmentId": "c", "itemId": "normal_helmet_lv20", "upgradeLevel": 16}]})
	var tiles := RewardModel.from_chest_open(eq_result)
	eq(_ids(tiles), [["equipment", "normal_armor_lv20", 1], ["equipment", "normal_helmet_lv20", 2]], "pieces, the same one merged")
	eq(tiles[0]["upgrade"], 16, "the piece's +level")


func test_from_lines_season_match_offer() -> void:
	BossFixture.take()
	var lines := MilestoneModel.reward_lines(MilestoneModel.parse_rewards({"coin": 500, "gem": 20,
		"items": [{"kind": "stone", "level": 4, "qty": 2}, {"kind": "chest", "id": "stone_chest", "qty": 1},
			{"kind": "title", "id": "t1", "name": "Lão làng", "rarity": "epic"}]}))
	var tiles := RewardModel.from_lines(lines)
	eq(tiles.map(func(t): return t["kind"]).filter(func(k): return k == "title"), [], "no title tile (its plate shows)")
	var gem: Array = tiles.filter(func(t): return t["kind"] == "gem")
	check(gem.size() == 1 and gem[0]["locked"], "a milestone's gem is locked gem")
	eq(tiles.size(), 4, "coin, gem, stone, chest")
	var season := SeasonRewardModel.parse_one({"seasonId": "s1", "grade": "dai_tuong", "coin": 2000, "gem": 15,
		"items": [{"kind": "chest", "id": "equip_chest_16", "qty": 1}, {"kind": "chest", "id": "stone_chest", "qty": 25}]})
	var st := RewardModel.from_season(season)
	eq(st.back()["id"], "equip_chest_16", "the +16 chest last (the best)")
	eq(st.size(), 4, "coin, gem, two chests")
	var match_tiles := RewardModel.from_match(ResultModel.reward({"coinGained": 120, "stones": [{"level": 2, "qty": 1}],
		"chests": [{"chestId": "stone_chest", "quantity": 1}]}, "ranked_1v1"))
	eq(match_tiles.map(func(t): return t["kind"]), ["stone", "coin", "chest"], "a match: its stone, coin and chest, weakest first")
	eq(RewardModel.from_match(ResultModel.reward(null, "")), [], "nothing granted: nothing")
	eq(_ids(RewardModel.from_offer({"offerType": "item", "itemId": "medkit", "quantity": 1}, 5)), [["item", "medkit", 5]], "an item ×5")
	eq(_ids(RewardModel.from_offer({"offerType": "coin_pack", "itemId": "coin", "quantity": 1000}, 1, {"quantityGranted": 1100})),
		[["coin", "coin", 1100]], "a coin pack: what the server granted")
	eq(_ids(RewardModel.from_offer({"offerType": "character_unlock", "itemId": "tanko", "quantity": 1}, 1)), [["character", "tanko", 1]],
		"a character")


func test_stagger_shrinks_for_many() -> void:
	check(RewardModel.stagger(3) > RewardModel.stagger(20), "shorter steps for many")
	check(RewardModel.stagger(20) * 20 <= 1.5 + 0.001, "twenty land within 1.5 s")


func test_strip_rows() -> void:
	eq(RewardStrip.layout(3, 1000, 100, 10, 3), [3], "fits: one row")
	eq(RewardStrip.layout(8, 560, 100, 10, 3), [4, 4], "five fit: two rows spread evenly")
	eq(RewardStrip.layout(11, 560, 100, 10, 3), [4, 4, 3], "the first rows one more")
	eq(RewardStrip.layout(40, 560, 100, 10, 3), [14, 13, 13], "too many: three rows, scrolling")
	eq(RewardStrip.layout(12, 560, 100, 10, 1), [12], "one row allowed: one row")
	eq(RewardStrip.layout(0, 560, 100, 10, 3), [], "none")
	BossFixture.take()
	var s: Control = RewardStrip.new()
	s.tile_size = Vector2(100, 120)
	s.gap = 10.0
	s.max_rows = 3
	s.size = Vector2(560, 400)
	var many: Array = []
	for lv in range(1, 12):
		many.append(RewardModel.tile("stone", "stone_%d" % lv, lv, lv))
	s.set_tiles(many)
	var row: Control = s.get_node("Row")
	eq(row.get_child(0).position.y, 0.0, "row 1")
	eq(row.get_child(4).position.y, 130.0, "row 2")
	eq(row.get_child(8).position.y, 260.0, "row 3")
	near(row.get_child(8).position.x, 55.0, 0.01, "the shorter row centred")
	check(s.fits(), "fits in three rows")
	check(s.glow_node(0) != null, "each tile glows")
	eq(RewardStrip.count_text(RewardModel.tile("equipment", "x", 1, 0, 16)), "+16", "a piece: its +level, no ×1")
	eq(RewardStrip.count_text(RewardModel.tile("character", "tanko", 1)), "", "a character: no count")
	s.free()


func test_reveal_phases_and_skip() -> void:
	BossFixture.take()
	var host := Control.new()
	host.size = Vector2(1600, 900)
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var tiles := [RewardModel.tile("stone", "stone_5", 6, 5), RewardModel.tile("stone", "stone_7", 1, 7)]
	var r: Control = RewardReveal.open(host, tiles, {"chest_id": "stone_chest", "count": 10})
	if r.box == null:
		r._ready() # the runner's _initialize does not send READY yet
	eq(r.phase, RewardReveal.DROP, "drops in first")
	eq(r.box.chest_id, "stone_chest", "the chest opened")
	check(r._count_label.visible and r._count_label.text == "×10", "×10 under the chest")
	eq(r.best["rung"], RewardModel.RED_GOLD, "the light of the best reward")
	check(not r.strip.visible, "no tiles before the burst")
	r._process(RewardReveal.DROP_SEC + 0.01)
	eq(r.phase, RewardReveal.SHAKE, "then shakes")
	r._process(RewardReveal.SHAKE_SEC * 0.6)
	check(r.box.leak > 0.3, "light leaks while it shakes")
	r.skip()
	eq(r.phase, RewardReveal.BURST, "a tap: bursts open")
	r._process(RewardReveal.BURST_SEC + 0.01)
	eq(r.phase, RewardReveal.FLY, "the tiles fly")
	check(r.strip.visible, "tiles shown")
	r.skip()
	eq(r.phase, RewardReveal.SHOW, "a tap: every tile lands")
	eq(r.strip.tiles.map(func(t): return t["id"]), ["stone_5", "stone_7"], "weakest first")
	var labels: Array = []
	for n in r.strip.find_children("*", "Label", true, false):
		labels.append((n as Label).text)
	eq(labels, ["×6", "×1"], "icon + ×N only, no names")
	r.skip()
	eq(r.phase, RewardReveal.COLLECT, "a tap: collect")
	r._finish()
	eq(r.phase, RewardReveal.DONE, "done")
	host.free()


func test_gift_box_for_other_rewards() -> void:
	var b: Control = RewardBox.make("", 100)
	check(b.is_gift(), "no chest: a gift box")
	b.free()
	var c: Control = RewardBox.make("equip_chest_16", 100)
	check(not c.is_gift(), "a chest")
	c.free()
