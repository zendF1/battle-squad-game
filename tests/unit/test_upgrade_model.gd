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
	for lv in [0, 1, 5]:
		eq(U.milestone_tier(lv), 0, "no aura at +%d" % lv)
		eq(U.milestone_color(lv), Color.WHITE, "normal name at +%d" % lv)
		eq(U.frame_tint(lv), Color.WHITE, "plain frame at +%d" % lv)
	for lv in [6, 7, 8, 9]:
		eq(U.milestone_color(lv), sky, "+%d sky blue" % lv)
	for lv in [10, 11, 12, 13]:
		eq(U.milestone_color(lv), orange, "+%d orange" % lv)
	for lv in [14, 15]:
		eq(U.milestone_color(lv), purple, "+%d purple" % lv)
	eq(U.milestone_tier(16), 4, "+16 the highest tier")
	check(sky.b > sky.r and sky.b > 0.9, "sky blue is blue")
	check(orange.r > 0.9 and orange.g > orange.b, "orange")
	check(purple.r > purple.g and purple.b > purple.g, "purple")
	check(red.r > 0.9 and red.g < 0.4 and red.b < 0.4, "red")
	eq(U.name_color({"upgradeLevel": 10}), orange, "name colour from the piece")
	eq(U.name_color({}), Color.WHITE, "a piece without a level")
	eq([U.next_milestone(0), U.next_milestone(6), U.next_milestone(9), U.next_milestone(15), U.next_milestone(16)], [6, 10, 10, 16, -1], "next milestones")


func test_milestone_texts() -> void:
	var c := catalog()
	eq(U.milestone_text(c, 6), "+6: +10% chỉ số, hào quang xanh da trời", "the +6 milestone")
	eq(U.milestone_text(c, 16), "+16: +100% chỉ số, hào quang đỏ", "the +16 milestone")
	eq(U.milestone_text(c, 7), "", "not a milestone")
	eq(U.milestone_hint(c, 5), "Đạt mốc +6: +10% chỉ số, hào quang xanh da trời", "this upgrade reaches +6")
	eq(U.milestone_hint(c, 6), "Mốc tiếp theo +10: +20% chỉ số, hào quang cam", "the next one")
	eq(U.milestone_hint(c, 16), "", "nothing past +16")
	var custom := catalog({"upgradeMilestones": [{"level": 6, "bonus": 0.15}, {"level": 10, "bonus": 0.2}, {"level": 14, "bonus": 0.4}, {"level": 16, "bonus": 1.0}]})
	eq(U.milestone_text(custom, 6), "+6: +15% chỉ số, hào quang xanh da trời", "configured bonus")


func test_milestone_rows() -> void:
	var c := catalog()
	var rows := U.milestone_rows(c, 3)
	eq(rows.map(func(r): return r["level"]), [6, 10, 14, 16], "the four milestones")
	eq(rows.map(func(r): return r["reached"]), [false, false, false, false], "none reached at +3")
	eq(rows.map(func(r): return r["bonus_text"]), ["+10% chỉ số", "+20% chỉ số", "+40% chỉ số", "+100% chỉ số"], "bonuses")
	eq(rows.map(func(r): return r["aura"]), ["Hào quang xanh da trời", "Hào quang cam", "Hào quang tím", "Hào quang đỏ"], "aura names")
	eq(rows.map(func(r): return r["color"]), [U.milestone_color(6), U.milestone_color(10), U.milestone_color(14), U.milestone_color(16)], "colours")
	eq(U.milestone_rows(c, 10).map(func(r): return r["reached"]), [true, true, false, false], "+10 reaches +6 and +10")
	eq(U.milestone_rows(c, 13).map(func(r): return r["reached"]), [true, true, false, false], "+13")
	eq(U.milestone_rows(c, 16).map(func(r): return r["reached"]), [true, true, true, true], "+16 reaches all")
	var custom := catalog({"upgradeMilestones": [{"level": 6, "bonus": 0.15}, {"level": 10, "bonus": 0.25}, {"level": 14, "bonus": 0.5}, {"level": 16, "bonus": 1.2}]})
	eq(U.milestone_rows(custom, 0).map(func(r): return r["bonus_text"]), ["+15% chỉ số", "+25% chỉ số", "+50% chỉ số", "+120% chỉ số"], "the catalog's bonuses")
	eq(U.milestone_rows(null, 6)[0]["bonus_text"], "+10% chỉ số", "defaults before the catalog loads")
	check(U.UNREACHED_ALPHA > 0.3 and U.UNREACHED_ALPHA < 0.5, "unreached rows dimmed to ~0.4")


func test_popup_level_texts() -> void:
	eq(U.level_line(3), "Cấp nâng cấp +3 / 16", "+3")
	eq(U.level_line(0), "Cấp nâng cấp +0 / 16", "new piece")
	eq(U.level_line(16), "Cấp nâng cấp +16 / 16", "max")
	eq(U.level_line(20), "Cấp nâng cấp +16 / 16", "clamped")
	var c := catalog()
	eq(U.upgrade_share_text(c, 0), "", "nothing from +0")
	eq(U.upgrade_share_text(c, 3), "+6% từ nâng cấp", "+3: 3 × 2%")
	eq(U.upgrade_share_text(c, 10), "+50% từ nâng cấp", "+10: 20% + milestones 10% + 20%")
	eq(U.upgrade_share_text(c, 16), "+202% từ nâng cấp", "+16: 32% + 170%")


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
	eq(U.chance_text(ch), "Tỉ lệ thành công 27% (tối đa 45%)", "chance line")
	ch = U.chance(c, 8, {7: 1})
	eq(ch["percent"], 45.0, "729 × 100 / 1200 = 60.75 capped at 45")
	check(ch["wasted"], "above the cap is waste")
	eq(U.waste_text(ch), "Dư đá: 60.8% > tối đa 45%, phần dư bị mất", "waste warning")
	eq(U.waste_text(U.chance(c, 8, {6: 1})), "", "no warning below the cap")
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


## Parity with internal/game/battlestats/stats_test.go TestSumEquipment (DefaultMilestones).
func test_upgraded_stats_match_the_server() -> void:
	var ms := M.DEFAULT_MILESTONES
	var item := {"statHp": 100.0, "statDamage": 10.0, "statDefense": 20.0, "statCrit": 2.0, "statMoveEnergy": 5.0}
	var up := M.upgraded(item, 5, ms) # ×1.10
	eq([up["statHp"], up["statDamage"], up["statDefense"], up["statMoveEnergy"]], [110.0, 11.0, 22.0, 6.0], "+5 points")
	near(up["statCrit"], 2.2, 1e-9, "+5 crit unrounded")
	eq(M.upgraded({"statHp": 100.0}, 10, ms)["statHp"], 150.0, "+10: 1 + 0.20 + 0.10 + 0.20")
	eq(M.upgraded({"statHp": 100.0}, 16, ms)["statHp"], 302.0, "+16: 1 + 0.32 + every milestone")
	eq(M.upgraded({"statHp": 20.0}, 7, ms)["statHp"], 25.0, "20 × 1.24 = 24.8 → 25 (rounded per item)")
	eq(M.upgraded({"statHp": 20.0, "statDamage": 8.0, "statMoveEnergy": 5.0}, 5, ms)["statHp"], 22.0, "hp 20 at +5 = 22 points")
	eq(M.upgraded({"statDamage": 25.0}, 2, ms)["statDamage"], 26.0, "25 × 1.04 = 26")
	eq(M.upgraded({"statDamage": 25.0}, 1, ms)["statDamage"], 26.0, "25 × 1.02 = 25.5 → 26 (half away from zero, like math.Round)")
	eq(M.upgraded(item, 0, ms), item, "+0 is the item")
	near(M.upgrade_multiplier(14, ms), 1.0 + 14 * 0.02 + 0.1 + 0.2 + 0.4, 1e-12, "+14 multiplier")
	eq(M.upgraded({"statHp": 100.0}, 6, [[6, 0.15], [10, 0.2], [14, 0.4], [16, 1.0]])["statHp"], 127.0, "configured milestones")
	# A piece: its catalog item at its level.
	var c := catalog()
	var piece := {"equipmentId": "e1", "itemId": "normal_armor_lv10", "upgradeLevel": 10}
	var p := M.piece_item(c, piece)
	eq([p["statHp"], p["statDefense"]], [150.0, 15.0], "piece_item at +10")
	near(p["statCrit"], 3.0, 1e-9, "crit × 1.5")


func test_stat_steps() -> void:
	var c := catalog()
	var steps := U.stat_steps(c, {"itemId": "normal_armor_lv10", "upgradeLevel": 5}, {"hp": 50, "defense": 5})
	eq(steps.size(), 3, "hp, defense, crit")
	eq(steps[0]["label"], "Máu", "first stat")
	eq(steps[0]["now"], "+110 điểm (+5.500)", "+5 hp")
	eq(steps[0]["next"], "+122 điểm (+6.100)", "+6 hp: ×1.22")
	eq(steps[0]["delta"], "+12 điểm", "the change")
	eq([steps[0]["now_points"], steps[0]["now_battle"], steps[0]["next_points"], steps[0]["next_battle"]],
		["+110 điểm", "+5.500", "+122 điểm", "+6.100"], "points and battle values apart")
	eq([steps[2]["now_points"], steps[2]["now_battle"]], ["+2.2%", ""], "crit has no battle value")
	check(steps[0]["up"], "goes up")
	eq(steps[2]["delta"], "+0.2%", "crit 2.2 → 2.44, shown to 0.1")
	var maxed := U.stat_steps(c, {"itemId": "normal_armor_lv10", "upgradeLevel": 16})
	check(not maxed[0]["up"], "nothing after +16")


func test_catalog_parse() -> void:
	var c := catalog({"mergeRatePerItem": 30, "upgradeMilestones": [{"level": 10, "bonus": 0.25}, {"level": 6, "bonus": 0.1}]})
	eq(c["upgradeMilestones"], [[6, 0.1], [10, 0.25]], "sorted milestones")
	eq(c["mergeRatePerItem"], 30.0, "merge rate kept")
	eq(catalog()["upgradeMilestones"], M.DEFAULT_MILESTONES, "defaults from an older server")
	eq(M.parse_milestones([{"level": "x"}]), M.DEFAULT_MILESTONES, "malformed → defaults")
	eq(M.milestones(null), M.DEFAULT_MILESTONES, "before the catalog loads")


func test_stones() -> void:
	eq(U.parse_stones([{"stoneLevel": 1, "quantity": 3}, {"stoneLevel": 4.0, "quantity": 0}, {"stoneLevel": 13, "quantity": 2}, "x", {"stoneLevel": 1, "quantity": 2}]),
		{1: 5}, "owned levels only")
	eq(U.parse_stones(null), {}, "none")
	eq(U.parse_stones({"a": 1}), null, "malformed")
	eq(U.owned_levels({5: 1, 2: 3, 7: 0}), [2, 5], "ascending, empty left out")
	var c := catalog()
	eq(U.power(c, 7), 729, "catalog power")
	eq(U.power({}, 12), 177147, "seeded power")
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
