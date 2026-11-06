extends "res://tests/test_case.gd"
## UpgradeModel and the upgraded stats of EquipmentModel: the server's chance formula with its
## cap, "Tự chọn", the waste warning, the fail rule text, the stats after an upgrade (parity with
## internal/game/battlestats), the milestone colours, the stones and merging.

const U := preload("res://screens/home/upgrade_model.gd")
const M := preload("res://screens/home/equipment_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")

## The seeded config_upgrade_rates and config_stones (migrations 010 / 021).
const RATES := [
	[0, 1, 1, 80, 0], [1, 2, 2, 76, 1], [2, 3, 6, 72, 2], [3, 4, 18, 68, 3], [4, 5, 40, 64, 4], [5, 6, 80, 60, 5],
	[6, 7, 180, 56, 6], [7, 8, 500, 52, 6], [8, 9, 1200, 45, 6], [9, 10, 3000, 40, 6], [10, 11, 6000, 35, 10],
	[11, 12, 15000, 30, 10], [12, 13, 25000, 25, 10], [13, 14, 50000, 20, 10], [14, 15, 80000, 15, 14], [15, 16, 200000, 10, 14],
]
const STONE_PRICES := [[100, 0], [250, 0], [700, 0], [2000, 0], [5500, 0], [15000, 0], [0, 50], [0, 140], [0, 400], [0, 1100], [0, 0], [0, 0]]


## The contract's table, as tests/fixtures/gamedata.json sends it.
const TABLE := [1, 1.1, 1.2, 1.3, 1.5, 1.75, 2, 2.4, 2.8, 3.3, 4, 4.6, 5.2, 6, 7, 8.5, 10]


## The game data of a server that sends no upgradeMultipliers.
static func older_server() -> void:
	var d: Dictionary = M.GameData.data.duplicate(true)
	d["version"] = "older"
	d["equipment"].erase("upgradeMultipliers")
	M.GameData.take(d, "", false)


static func catalog(extra: Dictionary = {}) -> Dictionary:
	var rates: Array = []
	for r in RATES:
		rates.append({"fromLevel": r[0], "toLevel": r[1], "upgradeCost": r[2], "maxPercent": float(r[3]), "failResetTo": r[4]})
	var stones: Array = []
	for i in 12:
		stones.append({"stoneLevel": i + 1, "power": int(pow(3, i)), "priceCoin": STONE_PRICES[i][0], "priceGem": STONE_PRICES[i][1],
			"source": "merge_only" if i >= 10 else ("gem_shop" if i >= 6 else "coin_shop")})
	var data := {"items": [
		{"itemId": "normal_armor_lv10", "name": "Iron Vest", "slot": "armor", "category": "normal", "requiredLevel": 10,
			"statHp": 100.0, "statDefense": 10.0, "statCrit": 2.0, "priceCoin": 400.0, "isActive": true},
	], "upgradeRates": rates, "stones": stones}
	data.merge(extra, true)
	return M.parse_catalog(data)


func test_milestone_colours() -> void:
	var sky := U.milestone_color(6)
	var orange := U.milestone_color(10)
	var purple := U.milestone_color(14)
	var red := U.milestone_color(16)
	var green := U.milestone_color(1)
	eq(U.color_tier(0), 0, "no aura at +0")
	eq(U.milestone_color(0), Color.WHITE, "normal name at +0")
	eq(U.frame_tint(0), Color.WHITE, "plain frame at +0")
	for lv in [1, 2, 3, 4, 5]:
		eq(U.color_tier(lv), 1, "+%d the green tier" % lv)
		eq(U.milestone_color(lv), green, "+%d green" % lv)
		check(U.frame_tint(lv) != Color.WHITE, "tinted frame at +%d" % lv)
		check(not U.is_milestone(lv), "+%d is no milestone" % lv)
	near(green.r, 46.0 / 255.0, 0.01, "green #2EE66B r")
	near(green.g, 230.0 / 255.0, 0.01, "green #2EE66B g")
	near(green.b, 107.0 / 255.0, 0.01, "green #2EE66B b")
	check(green.g > 0.85 and green.r < 0.3 and green.b < 0.5, "green is green, not sky blue")
	eq(U.color_tier(6), 2, "+6 sky blue tier")
	eq(U.TIER_WORDS[1], "xanh lá", "green word")
	for lv in [6, 7, 8, 9]:
		eq(U.milestone_color(lv), sky, "+%d sky blue" % lv)
	for lv in [10, 11, 12, 13]:
		eq(U.milestone_color(lv), orange, "+%d orange" % lv)
	for lv in [14, 15]:
		eq(U.milestone_color(lv), purple, "+%d purple" % lv)
	eq(U.color_tier(16), 5, "+16 the highest tier")
	eq([6, 10, 14, 16].map(func(l): return U.is_milestone(l)), [true, true, true, true], "the milestones")
	check(not U.is_milestone(0) and not U.is_milestone(7), "not milestones")
	check(sky.b > sky.r and sky.b > 0.9, "sky blue is blue")
	check(orange.r > 0.9 and orange.g > orange.b, "orange")
	check(purple.r > purple.g and purple.b > purple.g, "purple")
	check(red.r > 0.9 and red.g < 0.4 and red.b < 0.4, "red")
	eq(U.name_color({"upgradeLevel": 10}), orange, "name colour from the piece")
	eq(U.name_color({}), Color.WHITE, "a piece without a level")
	eq([U.next_milestone(0), U.next_milestone(6), U.next_milestone(9), U.next_milestone(15), U.next_milestone(16)], [6, 10, 10, 16, -1], "next milestones")


func test_milestone_texts() -> void:
	var c := catalog()
	eq(U.milestone_text(c, 6), "+6: ×2 chỉ số, hào quang xanh da trời", "the +6 milestone")
	eq(U.milestone_text(c, 16), "+16: ×10 chỉ số, hào quang đỏ", "the +16 milestone")
	eq(U.milestone_text(c, 7), "", "not a milestone")
	older_server()
	eq(U.milestone_text(catalog(), 6), "+6: +10% chỉ số, hào quang xanh da trời", "an older server's own bonus")


func test_milestone_rows() -> void:
	var c := catalog()
	var rows := U.milestone_rows(c, 3)
	eq(rows.map(func(r): return r["level"]), [6, 10, 14, 16], "the four milestones")
	eq(rows.map(func(r): return r["reached"]), [false, false, false, false], "none reached at +3")
	eq(rows.map(func(r): return r["bonus_text"]), ["×2 chỉ số", "×4 chỉ số", "×7 chỉ số", "×10 chỉ số"], "what the table gives, not the milestone bonus")
	eq(rows.map(func(r): return r["aura"]), ["Hào quang xanh da trời", "Hào quang cam", "Hào quang tím", "Hào quang đỏ"], "aura names")
	eq(rows.map(func(r): return r["color"]), [U.milestone_color(6), U.milestone_color(10), U.milestone_color(14), U.milestone_color(16)], "colours")
	eq(U.milestone_rows(c, 10).map(func(r): return r["reached"]), [true, true, false, false], "+10 reaches +6 and +10")
	eq(U.milestone_rows(c, 13).map(func(r): return r["reached"]), [true, true, false, false], "+13")
	eq(U.milestone_rows(c, 16).map(func(r): return r["reached"]), [true, true, true, true], "+16 reaches all")
	var custom := catalog({"upgradeMilestones": [{"level": 6, "bonus": 0.15}, {"level": 10, "bonus": 0.25}, {"level": 14, "bonus": 0.5}, {"level": 16, "bonus": 1.2}]})
	eq(U.milestone_rows(custom, 0)[0]["bonus_text"], "×2 chỉ số", "the catalog's old bonus means nothing on the table")
	eq(U.milestone_rows(catalog({"upgradeMultipliers": [1, 1, 1, 1, 1, 1, 1.25]}), 0)[0]["bonus_text"], "×1,25 chỉ số", "the catalog's table")
	eq(U.milestone_rows(null, 6)[0]["bonus_text"], "×2 chỉ số", "the game data's table before the catalog loads")
	check(U.UNREACHED_ALPHA > 0.3 and U.UNREACHED_ALPHA < 0.5, "unreached rows dimmed to ~0.4")


func test_milestone_rows_of_an_older_server() -> void:
	older_server()
	var rows := U.milestone_rows(catalog(), 3)
	eq(rows.map(func(r): return r["bonus_text"]), ["+10% chỉ số", "+20% chỉ số", "+40% chỉ số", "+100% chỉ số"], "bonuses")
	var custom := catalog({"upgradeMilestones": [{"level": 6, "bonus": 0.15}, {"level": 10, "bonus": 0.25}, {"level": 14, "bonus": 0.5}, {"level": 16, "bonus": 1.2}]})
	eq(U.milestone_rows(custom, 0).map(func(r): return r["bonus_text"]), ["+15% chỉ số", "+25% chỉ số", "+50% chỉ số", "+120% chỉ số"], "the catalog's bonuses")
	eq(U.milestone_rows(null, 6)[0]["bonus_text"], "+10% chỉ số", "defaults before the catalog loads")


func test_percent_and_cap() -> void:
	# internal/api/equipment/logic_test.go TestCalculateUpgradePercent cases.
	near(U.percent(1, 1, 80), 80.0, 1e-9, "1 power at cost 1 caps at 80")
	near(U.percent(1, 2, 76), 50.0, 1e-9, "half power")
	near(U.percent(6, 18, 68), 33.333333333333336, 1e-12, "below the cap, same float")
	near(U.percent(81, 180, 56), 45.0, 1e-9, "+6→+7 with one level-5 stone")
	near(U.percent(243, 180, 56), 56.0, 1e-9, "+6→+7 with one level-6 stone caps")
	eq(U.percent(10, 0, 50), 0.0, "no cost")
	var c := catalog()
	var ch := U.chance(c, 8, {6: 1, 4: 3})
	eq(ch["power"], 324, "243 + 3 × 27")
	near(ch["percent"], 27.0, 1e-9, "324 × 100 / 1200")
	eq(ch["max"], 45.0, "+8 max")
	eq(ch["wasted"], false, "below the cap")
	eq(U.bp_text(ch["bp"]), "27%", "the chance shown")
	eq(U.bp_text(ch["max_bp"]), "45%", "its maximum")
	ch = U.chance(c, 8, {7: 1})
	eq(ch["percent"], 45.0, "729 × 100 / 1200 = 60.75 capped at 45")
	check(ch["wasted"], "above the cap is waste")
	eq(U.chance(c, 4, {4: 1, 1: 0, 2: -3})["power"], 27, "zero and negative quantities count 0")
	eq(U.chance(c, 16, {1: 5})["max"], 0.0, "no rate at +16")


func test_needed_power() -> void:
	eq(U.needed_power(180, 56), 101, "100.8 → 101")
	eq(U.needed_power(1, 80), 1, "+0")
	eq(U.needed_power(1200, 45), 540, "+8")
	eq(U.needed_power(200000, 10), 20000, "+15")
	check(U.percent(U.needed_power(3000, 40), 3000, 40) >= 40.0, "the needed power reaches the cap")
	check(U.percent(U.needed_power(3000, 40) - 1, 3000, 40) < 40.0, "one less does not")


func test_auto_pick() -> void:
	var c := catalog()
	# +6→+7 needs 101: lv5 (81) + 3 × lv3 (9) = 108, or lv5 + lv4 = 108; never more.
	var pick := U.auto_pick(c, 6, {5: 3, 4: 5, 3: 5})
	eq(U.total_power(c, pick), 108, "least power reaching 101")
	check(U.chance(c, 6, pick)["percent"] >= 56.0, "reaches the cap")
	check(not U.chance(c, 6, pick)["wasted"] or U.chance(c, 6, pick)["raw"] - 56.0 < 5.0, "barely above")
	# +0→+1 needs 1: one level-1 stone, not the big one.
	eq(U.auto_pick(c, 0, {1: 4, 6: 1}), {1: 1}, "cheapest single stone")
	# Only a big stone: it is picked (the only way to reach the cap).
	eq(U.auto_pick(c, 0, {6: 2}), {6: 1}, "one big stone when nothing smaller")
	# Not enough: everything.
	eq(U.auto_pick(c, 9, {5: 2, 3: 1}), {5: 2, 3: 1}, "all of them when short")
	# +8 needs 540: 2 × lv6 + 4 × lv2 = 498 is short, so the level-7 stone (729), and the extra
	# stone makes the smaller ones unnecessary.
	eq(U.auto_pick(c, 8, {6: 2, 7: 1, 2: 4}), {7: 1}, "the level-7 stone alone")
	# 2 × lv6 (486) + one lv5 (81) = 567 beats the level-7 stone.
	eq(U.auto_pick(c, 8, {6: 2, 5: 1, 7: 1}), {6: 2, 5: 1}, "smaller stones when they reach the cap")
	eq(U.auto_pick(c, 16, {1: 5}), {}, "nothing at +16")
	eq(U.auto_pick(c, 3, {}), {}, "no stones")
	eq(U.request_stones({4: 3, 1: 0, 2: 1}), [{"stoneLevel": 2, "quantity": 1}, {"stoneLevel": 4, "quantity": 3}], "request body, ascending, zeros left out")


func test_fail_text_and_reasons() -> void:
	var c := catalog()
	eq(U.fail_text(c, 3), "Thất bại: giữ nguyên +3", "below +6 a failure keeps the level")
	eq(U.fail_text(c, 6), "Thất bại: giữ nguyên +6", "+6 → +7 keeps +6 (failResetTo 6)")
	eq(U.fail_text(c, 8), "Thất bại: về +6", "safe zone +6")
	eq(U.fail_text(c, 12), "Thất bại: về +10", "safe zone +10")
	eq(U.fail_text(c, 15), "Thất bại: về +14", "safe zone +14")
	eq(U.fail_text(c, 16), "", "no upgrade past +16")
	var piece := {"equipmentId": "e1", "itemId": "normal_armor_lv10", "upgradeLevel": 3}
	eq(U.blocked_reason(c, {}, {}, {}), "Chọn một trang bị", "no piece")
	eq(U.blocked_reason(c, {"upgradeLevel": 16}, {1: 1}, {1: 1}), "Đã đạt tối đa +16", "max")
	eq(U.blocked_reason(c, piece, {}, {}), "Chưa có đá nâng cấp", "no stones at all")
	eq(U.blocked_reason(c, piece, {}, {1: 2}), "Chưa chọn đá", "none picked")
	eq(U.blocked_reason(c, piece, {1: 3}, {1: 2}), "Không đủ đá cấp 1", "more than owned")
	eq(U.blocked_reason(c, piece, {1: 2}, {1: 2}), "", "ready")
	eq(U.blocked_reason({"items": {}}, piece, {1: 1}, {1: 1}), "Chưa có bảng nâng cấp cho +3", "no rates")


## The contract's section 3: base × m[L], rounded per piece and stat, crit left a decimal.
func test_upgraded_stats_use_the_table() -> void:
	eq(M.GameData.upgrade_multipliers(), TABLE.map(func(m): return float(m)), "the game data's table")
	var c := catalog()
	eq(c["upgradeMultipliers"], [], "this catalog sends none")
	eq(M.multipliers(c), M.GameData.upgrade_multipliers(), "then the game data's")
	for lv in TABLE.size():
		eq(M.upgrade_multiplier(lv, c), float(TABLE[lv]), "+%d is the table's entry, nothing added" % lv)
	eq(M.upgrade_multiplier(40, c), 10.0, "past the end: the last entry")
	# The worked example: 8 damage, statMultipliers.damage 5.
	var weapon := {"statDamage": 8.0}
	var mult := {"damage": 5}
	eq(M.upgraded(weapon, 6, c)["statDamage"], 16.0, "8 at +6 is 16 points")
	eq(M.upgraded(weapon, 10, c)["statDamage"], 32.0, "8 at +10 is 32 points")
	eq(M.stat_lines(M.upgraded(weapon, 6, c), mult)[0]["text"], "+16 điểm (+80)", "80 real damage at +6")
	eq(M.stat_lines(M.upgraded(weapon, 10, c), mult)[0]["text"], "+32 điểm (+160)", "160 real damage at +10")
	var item := {"statHp": 100.0, "statDamage": 10.0, "statDefense": 20.0, "statCrit": 2.0, "statMoveEnergy": 5.0}
	var up := M.upgraded(item, 5, c) # ×1.75
	eq([up["statHp"], up["statDamage"], up["statDefense"], up["statMoveEnergy"]], [175.0, 18.0, 35.0, 9.0], "+5 points, half away from zero")
	near(up["statCrit"], 3.5, 1e-9, "+5 crit unrounded")
	near(M.upgraded({"statCrit": 1.5}, 1, c)["statCrit"], 1.65, 1e-9, "crit stays a decimal")
	eq(M.upgraded({"statHp": 300.0}, 16, c)["statHp"], 3000.0, "+16 is ×10")
	eq(M.upgraded(item, 0, c), item, "+0 is the item")
	var p := M.piece_item(c, {"equipmentId": "e1", "itemId": "normal_armor_lv10", "upgradeLevel": 10})
	eq([p["statHp"], p["statDefense"]], [400.0, 40.0], "piece_item at +10")
	near(p["statCrit"], 8.0, 1e-9, "crit × 4")


func test_the_catalogs_table_wins() -> void:
	var c := catalog({"upgradeMultipliers": [1, 3, 9]})
	eq(c["upgradeMultipliers"], [1.0, 3.0, 9.0], "parsed")
	eq(M.upgrade_multiplier(2, c), 9.0, "the catalog's entry")
	eq(M.upgrade_multiplier(16, c), 9.0, "its last entry past its end")
	eq(M.upgrade_multiplier(2), 1.2, "without a catalog: the game data's")
	eq(M.upgrade_multiplier(2, null), 1.2, "before the catalog loads")
	eq(catalog({"upgradeMultipliers": [1, "x"]})["upgradeMultipliers"], [], "malformed: none")
	eq(catalog({"upgradeMultipliers": []})["upgradeMultipliers"], [], "empty: none")
	var edited: Dictionary = M.GameData.data.duplicate(true)
	edited["version"] = "edited"
	edited["equipment"]["upgradeMultipliers"] = [1, 1.5]
	M.GameData.take(edited, "", false)
	eq(M.upgrade_multiplier(1), 1.5, "an admin edit is followed, nothing hardcoded")


func test_multiplier_text() -> void:
	eq([M.multiplier_text(2.0), M.multiplier_text(10.0), M.multiplier_text(8.5), M.multiplier_text(1.75)],
		["×2", "×10", "×8,5", "×1,75"], "the table's values")


func test_passive_value() -> void:
	var c := catalog()
	near(M.passive_value(4.83, 16, c), 48.3, 1e-9, "× the table")
	near(M.passive_value(1.235, 5, c), 2.16, 1e-9, "2 decimals: 2.16125")
	near(M.passive_value(4.83, 0, c), 4.83, 1e-9, "+0 is the catalog's value")


## Parity with internal/game/battlestats/stats_test.go TestSumEquipment (DefaultMilestones), for a
## server that sends no table.
func test_older_server_keeps_the_old_formula() -> void:
	older_server()
	eq(M.GameData.upgrade_multipliers(), [], "no table")
	var c := catalog()
	var ms := M.default_milestones() # the game data's (equipment.milestones)
	eq(ms, [[6, 0.1], [10, 0.2], [14, 0.4], [16, 1.0]], "the server's milestones")
	var item := {"statHp": 100.0, "statDamage": 10.0, "statDefense": 20.0, "statCrit": 2.0, "statMoveEnergy": 5.0}
	var up := M.upgraded(item, 5, c) # ×1.10
	eq([up["statHp"], up["statDamage"], up["statDefense"], up["statMoveEnergy"]], [110.0, 11.0, 22.0, 6.0], "+5 points")
	near(up["statCrit"], 2.2, 1e-9, "+5 crit unrounded")
	eq(M.upgraded({"statHp": 100.0}, 10, c)["statHp"], 150.0, "+10: 1 + 0.20 + 0.10 + 0.20")
	eq(M.upgraded({"statHp": 100.0}, 16, c)["statHp"], 302.0, "+16: 1 + 0.32 + every milestone")
	eq(M.upgraded({"statHp": 20.0}, 7, c)["statHp"], 25.0, "20 × 1.24 = 24.8 → 25 (rounded per item)")
	eq(M.upgraded({"statHp": 20.0, "statDamage": 8.0, "statMoveEnergy": 5.0}, 5, c)["statHp"], 22.0, "hp 20 at +5 = 22 points")
	eq(M.upgraded({"statDamage": 25.0}, 2, c)["statDamage"], 26.0, "25 × 1.04 = 26")
	eq(M.upgraded({"statDamage": 25.0}, 1, c)["statDamage"], 26.0, "25 × 1.02 = 25.5 → 26 (half away from zero, like math.Round)")
	eq(M.upgraded(item, 0, c), item, "+0 is the item")
	near(M.upgrade_multiplier(14, c), 1.0 + 14 * 0.02 + 0.1 + 0.2 + 0.4, 1e-12, "+14 multiplier")
	eq(M.upgraded({"statDamage": 8.0}, 10, c)["statDamage"], 12.0, "the contract's old 12 points")
	var custom := catalog({"upgradeMilestones": [{"level": 6, "bonus": 0.15}, {"level": 10, "bonus": 0.2}, {"level": 14, "bonus": 0.4}, {"level": 16, "bonus": 1.0}]})
	eq(M.upgraded({"statHp": 100.0}, 6, custom)["statHp"], 127.0, "configured milestones")
	# A piece: its catalog item at its level.
	var piece := {"equipmentId": "e1", "itemId": "normal_armor_lv10", "upgradeLevel": 10}
	var p := M.piece_item(c, piece)
	eq([p["statHp"], p["statDefense"]], [150.0, 15.0], "piece_item at +10")
	near(p["statCrit"], 3.0, 1e-9, "crit × 1.5")
	eq(U.stat_steps(c, {"itemId": "normal_armor_lv10", "upgradeLevel": 5}, {"hp": 50})[0]["next"], "+122 điểm (+6.100)", "+6 hp: ×1.22")


func test_stat_steps() -> void:
	var c := catalog()
	var steps := U.stat_steps(c, {"itemId": "normal_armor_lv10", "upgradeLevel": 5}, {"hp": 50, "defense": 5})
	eq(steps.size(), 3, "hp, defense, crit")
	eq(steps[0]["label"], "Máu", "first stat")
	eq(steps[0]["now"], "+175 điểm (+8.750)", "+5 hp: ×1.75")
	eq(steps[0]["next"], "+200 điểm (+10.000)", "+6 hp: ×2")
	eq(steps[0]["delta"], "+25 điểm", "the change")
	eq([steps[0]["now_points"], steps[0]["now_battle"], steps[0]["next_points"], steps[0]["next_battle"]],
		["+175 điểm", "+8.750", "+200 điểm", "+10.000"], "points and battle values apart")
	eq([steps[2]["now_points"], steps[2]["now_battle"]], ["+3.5%", ""], "crit has no battle value")
	check(steps[0]["up"], "goes up")
	eq(steps[2]["delta"], "+0.5%", "crit 3.5 → 4")
	var maxed := U.stat_steps(c, {"itemId": "normal_armor_lv10", "upgradeLevel": 16})
	check(not maxed[0]["up"], "nothing after +16")


func test_contract_example_in_the_preview() -> void:
	var c := catalog({"items": [{"itemId": "w", "name": "Súng", "slot": "weapon", "statDamage": 8.0}]})
	var at6: Dictionary = U.preview(c, {"itemId": "w", "upgradeLevel": 6}, {"damage": 5})["rows"][0]
	eq([at6["now_points"], at6["now_battle"]], ["+16 điểm", "+80"], "16 points, 80 damage at +6")
	var at9: Dictionary = U.preview(c, {"itemId": "w", "upgradeLevel": 9}, {"damage": 5})["rows"][0]
	eq([at9["next_points"], at9["next_battle"]], ["+32 điểm", "+160"], "32 points, 160 damage at +10")


func test_passive_step() -> void:
	var item := {"itemId": "w", "name": "Súng", "slot": "weapon", "statDamage": 8.0, "passive": {"kind": "crit_damage", "value": 4.0}}
	var c := catalog({"items": [item]})
	var s := U.passive_step(c, {"itemId": "w", "slot": "weapon", "upgradeLevel": 5})
	eq([s["now_points"], s["next_points"], s["delta"]], ["+7%", "+8%", "+1%"], "the catalog's +0 value × the table")
	eq(s["glyph"], "crit_damage", "its picture")
	check(s["up"], "goes up")
	var own := U.passive_step(c, {"itemId": "w", "slot": "weapon", "upgradeLevel": 5, "passive": {"kind": "crit_damage", "value": 6.5}})
	eq(own["now_points"], "+6.5%", "now is the piece's own value, from the server")
	var top := U.passive_step(c, {"itemId": "w", "slot": "weapon", "upgradeLevel": 16})
	eq([top["now_points"], top["next_points"], top["delta"], top["up"]], ["+40%", "+40%", "", false], "nothing after +16")
	eq(U.passive_step(catalog(), {"itemId": "normal_armor_lv10", "upgradeLevel": 3}), {}, "no passive")
	var rows: Array = U.preview(c, {"itemId": "w", "slot": "weapon", "upgradeLevel": 5}, {"damage": 5})["rows"]
	eq(rows.map(func(r): return r["key"]), ["statDamage", "passive"], "the passive after the stats")
	var boots := catalog({"items": [{"itemId": "b", "slot": "boots", "statHp": 5.0, "passive": {"kind": "move_cost", "value": 2.0}}]})
	eq(U.passive_step(boots, {"itemId": "b", "slot": "boots", "upgradeLevel": 6})["now_points"], "−4%", "a passive that lowers")


func test_catalog_parse() -> void:
	var c := catalog({"mergeRatePerItem": 30, "upgradeMilestones": [{"level": 10, "bonus": 0.25}, {"level": 6, "bonus": 0.1}]})
	eq(c["upgradeMilestones"], [[6, 0.1], [10, 0.25]], "sorted milestones")
	eq(c["mergeRatePerItem"], 30.0, "merge rate kept")
	eq(catalog()["upgradeMilestones"], M.default_milestones(), "the game data's from an older server")
	eq(M.parse_milestones([{"level": "x"}]), M.default_milestones(), "malformed → the game data's")
	eq(M.milestones(null), M.default_milestones(), "before the catalog loads")


func test_stones() -> void:
	eq(U.parse_stones([{"stoneLevel": 1, "quantity": 3}, {"stoneLevel": 4.0, "quantity": 0}, {"stoneLevel": 13, "quantity": 2}, "x", {"stoneLevel": 1, "quantity": 2}]),
		{1: 5}, "owned levels only")
	eq(U.parse_stones(null), {}, "none")
	eq(U.parse_stones({"a": 1}), null, "malformed")
	eq(U.owned_levels({5: 1, 2: 3, 7: 0}), [2, 5], "ascending, empty left out")
	var c := catalog()
	eq(U.power(c, 7), 729, "catalog power")
	eq(U.power({}, 12), 0, "no catalog row: no power (the catalog is the only source)")
	eq(U.power({}, 13), 0, "unknown level")
	var rows := U.shop_stones(c)
	eq(rows.size(), 12, "12 levels")
	eq(rows[2], {"stoneLevel": 3, "power": 9, "currency": "coin", "price": 700, "buyable": true}, "level 3: coin")
	eq(rows[6]["currency"], "gem", "level 7: gem")
	eq(rows[6]["price"], 50, "50 gem")
	check(not rows[10]["buyable"] and not rows[11]["buyable"], "11 and 12 merge only")
	check(not U.shop_stones(null)[0]["buyable"], "nothing to buy before the catalog")
	eq(U.buy_confirm_text(rows[2], 5), "Mua 5 × Đá cấp 3 với giá 3.500 xu?", "confirm")
	eq(U.buy_confirm_text(rows[7], 2), "Mua 2 × Đá cấp 8 với giá 280 kim cương?", "gem confirm")


func test_merge() -> void:
	var c := catalog()
	eq(U.merge_chance(c, 2), 50.0, "2 × 25%")
	eq(U.merge_chance(c, 4), 100.0, "4 × 25%")
	eq(U.merge_chance(catalog({"mergeRatePerItem": 30}), 4), 100.0, "capped at 100")
	eq(U.merge_chance(catalog({"mergeRatePerItem": 30}), 3), 90.0, "configured rate")
	eq(U.merge_chance(catalog({"mergeRatePerItem": -1}), 2), 50.0, "bad rate → 25")
	eq(U.merge_blocked(3, 4, {3: 4}), "", "ready")
	eq(U.merge_blocked(3, 4, {3: 3}), "Cần 4 viên, đang có 3", "short")
	eq(U.merge_blocked(3, 1, {3: 9}), "Bỏ vào 2–4 viên", "too few")
	eq(U.merge_blocked(3, 5, {3: 9}), "Bỏ vào 2–4 viên", "too many")
	eq(U.merge_blocked(12, 2, {12: 9}), "Đá cấp 12 là cao nhất", "max level")
	eq(U.merge_blocked(3, 2, null), "Cần 2 viên, đang có 0", "not loaded")
	eq(U.merge_text(3, 4), "4 × Đá cấp 3 → 1 × Đá cấp 4", "formula")


func test_error_texts() -> void:
	var fail := func(status: int, code: String) -> Dictionary: return {"ok": false, "status": status, "code": code, "message": code}
	eq(ErrorText.upgrade(fail.call(400, "EQUIP_INSUFFICIENT_STONES")), "Không đủ đá nâng cấp, hãy chọn lại", "upgrade stones")
	eq(ErrorText.upgrade(fail.call(400, "EQUIP_MAX_UPGRADE")), "Trang bị đã đạt +16, không nâng cấp thêm được", "max")
	eq(ErrorText.upgrade(fail.call(409, "EQUIP_MODIFIED")), "Trang bị vừa được nâng cấp ở nơi khác, hãy thử lại", "modified")
	eq(ErrorText.upgrade(fail.call(400, "EQUIP_NO_STONES")), "Chưa chọn đá nâng cấp", "no stones")
	eq(ErrorText.upgrade(fail.call(0, "")), ErrorText.OFFLINE, "offline")
	eq(ErrorText.upgrade(fail.call(500, "X")), "Nâng cấp thất bại: X", "unknown")
	eq(ErrorText.stone_buy(fail.call(400, "SHOP_INSUFFICIENT_BALANCE"), "gem"), "Không đủ kim cương", "balance")
	eq(ErrorText.stone_buy(fail.call(400, "BAD_REQUEST")), "Đá này không bán, chỉ ghép được", "merge only")
	eq(ErrorText.merge(fail.call(400, "EQUIP_INSUFFICIENT_STONES")), "Không đủ đá để ghép", "merge stones")
	eq(ErrorText.merge(fail.call(400, "MERGE_MAX_LEVEL")), "Đá cấp 12 là cao nhất, không ghép tiếp được", "merge max")


func test_preview_columns() -> void:
	var c := catalog()
	var p0 := U.preview(c, {"itemId": "normal_armor_lv10", "upgradeLevel": 0}, {"hp": 50, "defense": 5})
	check(not p0["maxed"], "+0 not maxed")
	eq(p0["columns"].map(func(col): return col["level"]), [0, 1], "+0 → +1")
	eq(p0["columns"][0]["color"], Color.WHITE, "+0 plain")
	eq(p0["columns"][1]["color"], U.milestone_color(1), "+1 green")
	eq(p0["fail"], "Thất bại: giữ nguyên +0", "the failure rule")
	eq(p0["note"], "", "no note")
	check(not p0["rows"].is_empty() and p0["rows"].any(func(r): return r["up"]), "stats with gains")
	var p5 := U.preview(c, {"itemId": "normal_armor_lv10", "upgradeLevel": 5})
	eq(p5["columns"].map(func(col): return col["level"]), [5, 6], "+5 → +6")
	eq(p5["columns"][1]["color"], U.milestone_color(6), "the next column takes the sky blue of +6")
	var p15 := U.preview(c, {"itemId": "normal_armor_lv10", "upgradeLevel": 15})
	eq(p15["columns"].map(func(col): return col["level"]), [15, 16], "+15 → +16")
	var p16 := U.preview(c, {"itemId": "normal_armor_lv10", "upgradeLevel": 16})
	check(p16["maxed"], "+16 maxed")
	eq(p16["columns"].map(func(col): return col["level"]), [16], "one column at +16")
	eq(p16["note"], "Đã đạt cấp tối đa", "max note")
	eq(p16["fail"], "", "no failure rule at +16")
	for p in [p0, p5, p15, p16]:
		check(p["columns"].all(func(col): return col.keys() == ["level", "color"]), "columns: hexagon level and colour only")
		var texts: Array = [p["fail"], p["note"]]
		check(not texts.any(func(t): return t.contains("Mốc") or t.contains("Đạt mốc") or t.contains("hào quang")), "no milestone text")


## The server's careful prices and bonuses (migration 025), per fromLevel.
const CAREFUL_GEM := [2, 2, 3, 5, 5, 10, 10, 10, 15, 20, 30, 60, 80, 120, 180, 250]
const CAREFUL_BONUS := [30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 40, 40, 40, 40, 50, 50]


## A catalog as the server sends it with migration 025 (careful per row, the weapon multiplier).
static func careful_catalog(mult: Variant = 3) -> Dictionary:
	var c := catalog()
	for r in c["upgradeRates"]:
		r["carefulGemCost"] = CAREFUL_GEM[int(r["fromLevel"])]
		r["carefulBonusPercent"] = float(CAREFUL_BONUS[int(r["fromLevel"])])
	if mult != null:
		c["weaponUpgradeCostMultiplier"] = float(mult)
	return c


## Parity with internal/api/equipment/logic_test.go TestCalculateFinalUpgradePercent.
func test_careful_percent_matches_the_server() -> void:
	eq(U.careful_percent(20.0, 40.0), 28.0, "+13→+14: 20% × 1.4")
	eq(U.careful_percent(40.0, 30.0), 52.0, "+9→+10: 40% × 1.3")
	eq(U.careful_percent(10.0, 50.0), 15.0, "+15→+16: 10% × 1.5")
	eq(U.careful_percent(10.0, 40.0), 14.0, "below the cap: 10% × 1.4")
	eq(U.careful_percent(100.0 / 3.0, 30.0), 43.33, "rounded to 2 decimals")
	eq(U.careful_percent(80.0, 30.0), 100.0, "capped at 100")
	eq(U.careful_percent(13.5, 30.0), 17.55, "weapon ×3 careful")
	eq(U.careful_percent(56.0, 30.0), 72.8, "+6→+7 capped stones × 1.3")
	eq(U.careful_percent(10.0, 0.0), 10.0, "no bonus")


func test_careful_step_and_none() -> void:
	var c := careful_catalog()
	var old := catalog() # an older server: no careful fields, no weapon multiplier
	for lv in 16:
		var cf := U.careful(c, lv)
		eq([cf["gem"], cf["bonus"], cf["offered"]], [CAREFUL_GEM[lv], float(CAREFUL_BONUS[lv]), true], "+%d step" % lv)
		var fb := U.careful(old, lv)
		eq([fb["gem"], fb["bonus"], fb["offered"]], [0, 0.0, false], "+%d: a row without careful has none" % lv)
	eq(U.careful(c, 16)["offered"], false, "nothing at +16")
	eq(U.careful(null, 3)["offered"], false, "no catalog, no rate")
	c["upgradeRates"][13]["carefulGemCost"] = 0
	eq(U.careful(c, 13)["offered"], false, "price 0: not offered")
	c["upgradeRates"][12]["carefulBonusPercent"] = 0
	eq(U.careful(c, 12)["offered"], false, "bonus 0: not offered")
	eq(U.weapon_cost_multiplier(careful_catalog()), 3.0, "catalog multiplier")
	eq(U.weapon_cost_multiplier(careful_catalog(2)), 2.0, "configured")
	eq(U.weapon_cost_multiplier(old), 3.0, "the game data's (3)")
	eq(U.weapon_cost_multiplier(careful_catalog(0.5)), 3.0, "below 1 falls back")
	eq(M.parse_catalog({"items": [], "weaponUpgradeCostMultiplier": 2})["weaponUpgradeCostMultiplier"], 2.0, "parsed")
	eq(U.cost_multiplier(c, "weapon"), 3.0, "weapon ×3")
	eq(U.cost_multiplier(c, "armor"), 1.0, "armor ×1")
	eq(U.piece_slot(c, {"slot": "weapon"}), "weapon", "the piece's slot")
	eq(U.piece_slot(c, {"itemId": "normal_armor_lv10"}), "armor", "the item's slot")


func test_careful_chance() -> void:
	var c := careful_catalog()
	# +13→+14 with 2 × level 9 (13122): 26.2% capped at 20%
	var off := U.chance(c, 13, {9: 2}, "armor")
	eq([off["percent"], off["stone"], off["careful"], off["gem"]], [20.0, 20.0, false, 0], "careful off")
	eq([off["stone_bp"], off["careful_bp"], off["max_bp"], off["careful_max_bp"]], [2000, 2800, 2000, 2800], "both chances show, careful on or off")
	var on := U.chance(c, 13, {9: 2}, "armor", true)
	eq([on["percent"], on["stone"], on["careful"], on["gem"], on["bonus"]], [28.0, 20.0, true, 120, 40.0], "careful on")
	check(on["wasted"], "the stones still go above the cap")
	eq(on["bp"], 2800, "on: the final chance rolls")
	eq(U.careful_confirm_text(on), "Dùng 120 kim cương cho nâng cấp cẩn thận?", "confirmation: the price only")
	eq(U.chance(c, 15, {11: 1}, "armor", true)["percent"], 15.0, "+15→+16: 10% → 15%")
	eq(U.chance(c, 9, {9: 1}, "armor", true)["percent"], 52.0, "+9→+10: 40% → 52%")
	c["upgradeRates"][13]["carefulGemCost"] = 0
	var none := U.chance(c, 13, {9: 2}, "armor", true)
	eq([none["percent"], none["careful"], none["gem"]], [20.0, false, 0], "on but not offered: plain")


## Parity with internal/api/equipment/careful_integration_test.go TestWeaponUpgradeCostsTripleStonePower.
func test_weapon_costs_triple() -> void:
	var c := careful_catalog()
	near(U.chance(c, 8, {6: 2}, "armor")["percent"], 40.5, 1e-9, "armor: 486 × 100 / 1200")
	near(U.chance(c, 8, {6: 2}, "weapon")["percent"], 13.5, 1e-9, "weapon: 486 × 100 / 3600")
	eq(U.chance(c, 8, {6: 2}, "weapon")["cost"], 3600.0, "effective cost")
	eq(U.chance(c, 6, {6: 2}, "weapon", true)["percent"], 72.8, "weapon careful: 90 → max 56 × 1.3")
	eq(U.chance(c, 6, {6: 2}, "weapon", true)["gem"], 10, "the careful price is not multiplied")
	near(U.chance(careful_catalog(2), 8, {6: 2}, "weapon")["percent"], 20.25, 1e-9, "multiplier 2")
	check(not U.chance(c, 8, {7: 1}, "weapon")["wasted"], "729 is no waste for a weapon (20.25% < 45%)")
	check(U.chance(c, 8, {7: 1}, "armor")["wasted"], "but is for armor")
	# Tự chọn: a weapon at +8 needs 3600 × 45% = 1620 power
	eq(U.needed_power(3600.0, 45), 1620, "weapon +8 need")
	var pick := U.auto_pick(c, 8, {7: 3, 6: 2}, "weapon")
	check(U.total_power(c, pick) >= 1620, "reaches the weapon cap")
	eq(U.chance(c, 8, pick, "weapon")["percent"], 45.0, "at the cap")
	eq(U.auto_pick(c, 8, {7: 3, 6: 2}, "armor"), {7: 1}, "armor needs one level-7 stone")


func test_careful_blocked_reason() -> void:
	var c := careful_catalog()
	var piece := {"equipmentId": "e1", "itemId": "normal_armor_lv10", "upgradeLevel": 13}
	eq(U.blocked_reason(c, piece, {9: 2}, {9: 2}, true, 119), "Thiếu kim cương cho Nâng cấp cẩn thận (cần 120)", "short of gems")
	eq(U.blocked_reason(c, piece, {9: 2}, {9: 2}, true, 120), "", "exactly enough")
	eq(U.blocked_reason(c, piece, {9: 2}, {9: 2}, false, 0), "", "careful off: gems do not matter")
	eq(U.blocked_reason(c, piece, {9: 2}, {9: 2}, true, -1), "", "unknown balance: the server checks")
	eq(U.blocked_reason(c, piece, {}, {9: 2}, true, 0), "Chưa chọn đá", "stones first")
	eq(ErrorText.upgrade({"status": 400, "code": "EQUIP_CAREFUL_UNAVAILABLE"}), "Cấp này không có Nâng cấp cẩn thận", "unavailable")
	eq(ErrorText.upgrade({"status": 400, "code": "SHOP_INSUFFICIENT_BALANCE"}), "Không đủ kim cương cho Nâng cấp cẩn thận", "no gems")


## The limits follow the game data: the highest level, the stone level, the merge counts, the
## milestones (their colour tiers) and the error texts that quote them.
func test_limits_from_the_game_data() -> void:
	eq([U.max_level(), U.stone_levels(), U.merge_min(), U.merge_max()], [16, 12, 2, 4], "the server's limits")
	eq(U.merge_blocked(12, 2, {}), "Đá cấp 12 là cao nhất", "top stone")
	var d: Dictionary = M.GameData.data.duplicate(true)
	d["version"] = "edited"
	d["equipment"]["maxUpgradeLevel"] = 20
	d["equipment"]["maxStoneLevel"] = 15
	d["equipment"]["mergeMinCount"] = 3
	d["equipment"]["mergeMaxCount"] = 5
	d["equipment"]["milestones"] = [{"level": 5, "bonus": 0.1}, {"level": 20, "bonus": 2.0}]
	d["equipment"].erase("upgradeMultipliers")
	M.GameData.take(d, "", false)
	eq(U.max_level(), 20, "the new top")
	eq(U.merge_blocked(3, 2, {}), "Bỏ vào 3–5 viên", "the new merge counts")
	eq(U.merge_blocked(15, 3, {}), "Đá cấp 15 là cao nhất", "the new top stone")
	eq(U.milestone_from(), [0, 5, 20], "the new milestones")
	eq([U.color_tier(4), U.color_tier(5), U.color_tier(19), U.color_tier(20)], [1, 2, 2, 3], "colour tiers follow them")
	check(U.is_milestone(5) and not U.is_milestone(6), "+5 is one now, +6 not")
	var fail := func(status: int, code: String) -> Dictionary: return {"ok": false, "status": status, "code": code, "message": ""}
	eq(ErrorText.upgrade(fail.call(400, "EQUIP_MAX_UPGRADE")), "Trang bị đã đạt +20, không nâng cấp thêm được", "quotes the top")
	eq(ErrorText.merge(fail.call(400, "MERGE_MIN_COUNT")), "Cần bỏ vào ít nhất 3 viên", "quotes the min")
	eq(ErrorText.merge(fail.call(400, "MERGE_MAX_COUNT")), "Chỉ bỏ vào tối đa 5 viên", "quotes the max")
	eq(ErrorText.merge(fail.call(400, "MERGE_MAX_LEVEL")), "Đá cấp 15 là cao nhất, không ghép tiếp được", "quotes the top stone")
	near(M.upgrade_multiplier(5), 1.0 + 5 * 0.02 + 0.1, 1e-12, "an older server: the new milestone in the multiplier")


func test_coin_cost_uses_the_weapon_multiplier() -> void:
	var c := careful_catalog()
	c["upgradeRates"] = c["upgradeRates"].duplicate(true)
	for r in c["upgradeRates"]:
		r["coinCost"] = 2500 if int(r["fromLevel"]) == 8 else 0
	eq(U.coin_cost(c, 8, "armor"), 2500, "armor pays the row")
	eq(U.coin_cost(c, 8, "weapon"), 7500, "a weapon pays the multiplier")
	eq(U.coin_cost(c, 7, "weapon"), 0, "a free step")
	eq(U.coin_cost(c, 16, "weapon"), 0, "no row at +16")
	eq(U.coin_cost(careful_catalog(1.5), 8, "weapon"), 0, "an older catalog has no coin")
	eq(U.mul_up(50, 1.1), 55, "no float rounding error")
	eq(U.mul_up(100, 1.1), 110, "no float rounding error")
	eq(U.mul_up(250, 1.1), 275, "exact")
	eq(U.mul_up(333, 1.5), 500, "rounds up")
	eq(U.chance(c, 8, {7: 1}, "weapon")["coin"], 7500, "chance carries it")


func test_coin_blocked_reason() -> void:
	var c := careful_catalog()
	c["upgradeRates"] = c["upgradeRates"].duplicate(true)
	for r in c["upgradeRates"]:
		r["coinCost"] = 2500
	var armor := {"upgradeLevel": 8, "slot": "armor"}
	var weapon := {"upgradeLevel": 8, "slot": "weapon"}
	eq(U.blocked_reason(c, armor, {7: 1}, {7: 1}, false, -1, 2500), "", "exactly enough")
	eq(U.blocked_reason(c, armor, {7: 1}, {7: 1}, false, -1, 2499), "Thiếu xu (cần 2.500)", "short")
	eq(U.blocked_reason(c, weapon, {7: 1}, {7: 1}, false, -1, 2500), "Thiếu xu (cần 7.500)", "a weapon costs more")
	eq(U.blocked_reason(c, weapon, {7: 1}, {7: 1}, false, -1, -1), "", "unknown balance: the server checks")
	eq(U.blocked_reason(c, weapon, {}, {7: 1}, false, -1, 0), "Chưa chọn đá", "stones first")
	eq(ErrorText.upgrade({"status": 400, "code": "EQUIP_INSUFFICIENT_COIN", "message": ""}), "Không đủ xu để nâng cấp", "error text")


# ── Formula 2: filling the required power reaches the maximum ───────────────

## A catalog of formula 2: the contract's row (+9→+10, C 3.000, weapon 9.000) and a row without the
## careful, stones of power 1, 81, 729, 1000.
static func v2_catalog(extra: Dictionary = {}) -> Dictionary:
	var data := {"items": [], "probabilityFormulaVersion": 2, "weaponUpgradeCostMultiplier": 3,
		"stones": [{"stoneLevel": 1, "power": 1}, {"stoneLevel": 5, "power": 81}, {"stoneLevel": 7, "power": 729}, {"stoneLevel": 8, "power": 1000}],
		"upgradeRates": [
			{"fromLevel": 9, "toLevel": 10, "upgradeCost": 3000, "maxPercent": 40, "failResetTo": 6, "carefulGemCost": 50,
				"carefulBonusPercent": 30, "coinCost": 2000, "maxPercentBp": 4000, "carefulBonusBp": 3000,
				"effectiveRequiredPower": {"weapon": 9000, "armor": 3000, "helmet": 3000, "pants": 3000, "boots": 3000, "gloves": 3000}},
			{"fromLevel": 10, "toLevel": 11, "upgradeCost": 10000, "maxPercent": 40, "failResetTo": 10, "coinCost": 0, "maxPercentBp": 4000,
				"carefulBonusBp": 0, "effectiveRequiredPower": {"weapon": 10000, "armor": 10000}},
			{"fromLevel": 11, "toLevel": 12, "upgradeCost": 3000, "maxPercent": 90, "failResetTo": 10, "carefulGemCost": 50,
				"carefulBonusPercent": 30, "maxPercentBp": 9000, "carefulBonusBp": 3000, "effectiveRequiredPower": {"armor": 3000}}]}
	data.merge(extra, true)
	return M.parse_catalog(data)


func test_formula_version() -> void:
	eq(U.formula_version(v2_catalog()), 2, "the catalog's version survives parsing")
	eq(U.formula_version(catalog()), 1, "an older catalog")
	eq(U.formula_version(null), 1, "not loaded")


func test_bp_text_never_rounds_up() -> void:
	eq(U.bp_text(1600), "16%", "whole")
	eq(U.bp_text(2080), "20,8%", "one decimal")
	eq(U.bp_text(3999), "39,99%", "two decimals")
	eq(U.bp_text(5198), "51,98%", "careful")
	eq(U.bp_text(5), "0,05%", "below one")
	eq(U.bp_text(0), "0%", "nothing")
	eq(U.bp_text(10000), "100%", "the top")


func test_spec_example_c_10000() -> void:
	var c := v2_catalog()
	var cases := [[1, 400, "4%"], [4, 1600, "16%"], [5, 2000, "20%"], [10, 4000, "40%"], [12, 4000, "40%"]]
	for k in cases:
		var ch := U.chance(c, 10, {8: k[0]}, "armor")
		eq(ch["bp"], k[1], "%d × 1.000 power" % k[0])
		eq(U.bp_text(ch["stone_bp"]), k[2], "%d stones shown" % k[0])
	near(U.chance(c, 10, {8: 4}, "armor")["percent"], 16.0, 1e-9, "percent: bp / 100, like the server's answer")
	var almost := U.chance(c, 10, {8: 9, 5: 12, 1: 27}, "armor")
	eq(almost["power"], 9999, "one short of C")
	eq(U.bp_text(almost["bp"]), "39,99%", "never rounded up to the cap")
	eq(almost["fill_bp"], 9999, "the fill stays under 100% too")
	eq(U.fill_text(almost), "Đã nạp 99,99%", "the fill label")


func test_contract_table_c_9000() -> void:
	var c := v2_catalog()
	# P, fill, normal, careful
	for k in [[900, 1000, 400, 520], [3600, 4000, 1600, 2080], [8999, 9998, 3999, 5198], [9000, 10000, 4000, 5200], [12000, 10000, 4000, 5200]]:
		var ch := U.chance(c, 9, {1: k[0]}, "weapon")
		eq(ch["required"], 9000, "C: effectiveRequiredPower, the multiplier not applied again")
		eq([ch["fill_bp"], ch["stone_bp"], ch["careful_bp"]], [k[1], k[2], k[3]], "P = %d" % k[0])
		eq(U.chance(c, 9, {1: k[0]}, "weapon", true)["bp"], k[3], "careful rolls the careful chance, P = %d" % k[0])
	eq(U.chance(c, 9, {1: 3600}, "armor")["required"], 3000, "the other slots are not multiplied")


func test_fill_is_not_the_chance() -> void:
	var ch := U.chance(v2_catalog(), 10, {8: 4}, "armor")
	eq(U.power_text(ch), "4.000 / 10.000", "P / C")
	eq(U.fill_text(ch), "Đã nạp 40%", "40% filled, in its own words")
	eq(U.bp_text(ch["bp"]), "16%", "16% success")
	near(ch["fill"], 0.4, 1e-9, "the gauge")
	eq(ch["over"], 0, "nothing over")
	eq(U.over_text(ch), "", "no warning")
	check(not ch["wasted"], "no waste")


func test_over_fill_warns() -> void:
	var c := v2_catalog()
	var ch := U.chance(c, 10, {8: 12}, "armor")
	eq(ch["over"], 2000, "2.000 over C")
	check(ch["wasted"] and ch["spare"], "two whole stones add nothing")
	eq(U.over_text(ch), "Thừa 2.000 sức mạnh, đá thừa vẫn mất", "the warning")
	eq(U.fill_text(ch), "Đã nạp 100%", "the fill stops at full")
	var tight := U.chance(c, 9, {8: 3, 5: 1}, "armor")
	eq(tight["over"], 81, "3.081 of 3.000")
	check(tight["wasted"] and tight["spare"], "the level-5 stone is spare")
	var chunky := U.chance(c, 9, {8: 2, 7: 2}, "armor")
	eq(chunky["over"], 458, "3.458 of 3.000")
	check(chunky["wasted"] and not chunky["spare"], "above C, but no stone can go")
	check(not U.chance(c, 10, {8: 10}, "armor")["wasted"], "exactly full")


func test_final_chance_capped_at_100() -> void:
	var ch := U.chance(v2_catalog(), 11, {8: 3}, "armor", true)
	eq([ch["stone_bp"], ch["bp"], ch["careful_max_bp"]], [9000, 10000, 10000], "90% × 1.3 caps at 100")


func test_no_careful_on_the_step() -> void:
	var ch := U.chance(v2_catalog(), 10, {8: 4}, "armor", true)
	eq([ch["careful"], ch["offered"], ch["bp"], ch["careful_bp"], ch["careful_max_bp"]], [false, false, 1600, 1600, 4000], "the plain chance")


func test_v2_rows_without_the_new_fields() -> void:
	var c: Variant = M.parse_catalog({"items": [], "probabilityFormulaVersion": 2, "weaponUpgradeCostMultiplier": 3, "stones": [{"stoneLevel": 1, "power": 1}],
		"upgradeRates": [{"fromLevel": 1, "toLevel": 2, "upgradeCost": 100, "maxPercent": 40, "carefulGemCost": 5, "carefulBonusPercent": 30}]})
	var ch: Dictionary = U.chance(c, 1, {1: 150}, "weapon", true)
	eq([ch["required"], ch["stone_bp"], ch["bp"]], [300, 2000, 2600], "upgradeCost × the slot, maxPercent × 100")


func test_auto_pick_fills_c() -> void:
	var c := v2_catalog()
	eq(U.auto_pick(c, 10, {8: 12}, "armor"), {8: 10}, "ten of twelve fill 10.000, not four")
	var pick := U.auto_pick(c, 9, {8: 12, 5: 50}, "weapon")
	eq(pick, {8: 9}, "the weapon's own C")
	eq(U.auto_pick(c, 9, {8: 2, 5: 200}, "armor"), {8: 3 - 1, 5: 13}, "smaller stones top it up")
	eq(U.chance(c, 9, U.auto_pick(c, 9, {8: 2, 5: 200}, "armor"), "armor")["bp"], 4000, "reaches the maximum")
	eq(U.auto_pick(c, 10, {8: 3}, "armor"), {8: 3}, "all of them when short")


func test_zero_chance_is_blocked() -> void:
	var c := v2_catalog()
	var piece := {"upgradeLevel": 10, "slot": "armor"}
	eq(U.chance(c, 10, {1: 2}, "armor")["bp"], 0, "2 × 4000 / 10000 floors to 0")
	eq(U.blocked_reason(c, piece, {1: 2}, {1: 2}), "Đá quá yếu, hãy nạp thêm", "the server would refuse it")
	eq(U.chance(c, 10, {1: 3}, "armor")["bp"], 1, "3 power: 0.01%")
	eq(U.blocked_reason(c, piece, {1: 3}, {1: 3}), "", "0.01% can be tried")
	eq(U.bp_text(1), "0,01%", "shown")


func test_error_texts_of_formula_2() -> void:
	var fail := func(code: String) -> Dictionary: return {"ok": false, "status": 400, "code": code, "message": "x"}
	eq(ErrorText.upgrade(fail.call("EQUIP_UPGRADE_CHANCE_ZERO")), "Đá quá yếu, hãy nạp thêm", "chance zero")
	check(not ErrorText.upgrade(fail.call("EQUIP_UPGRADE_CONFIG_INVALID")).contains("x"), "the generic text, not the server's")
