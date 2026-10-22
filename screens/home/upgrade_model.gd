extends RefCounted
## Equipment upgrade (+N), upgrade stones and stone merging as the Nâng cấp page, the Shop's
## "Đá nâng cấp" and Túi đồ show them, without UI. Mirrors the server (internal/api/equipment,
## internal/game/battlestats):
## - success chance: stone percent = min(Σ power × quantity × 100 / (upgradeCost × m), maxPercent)
##   from the catalog's upgradeRates row of the current level (and its stones' powers), m =
##   weaponUpgradeCostMultiplier (the catalog's, else the game data's) for a weapon, 1 for the
##   other slots; every stone put in is consumed; a failure puts the piece
##   at failResetTo (the current level below +6, else the safe zone +6 / +10 / +14);
## - careful upgrade ("Nâng cấp cẩn thận"): pay the row's carefulGemCost gem (on success and on
##   failure) and the stone percent is multiplied by (1 + carefulBonusPercent / 100), rounded to 2
##   decimals, capped at 100 (+13→+14: 20% × 1.4 = 28%); a row with either value 0 (or missing)
##   has no careful;
## - stats after an upgrade: each stat × (1 + upgradeStepPerLevel × level + every reached
##   milestone bonus), rounded per item (crit stays a float) — EquipmentModel.upgraded();
## - merging: mergeMinCount–mergeMaxCount stones of one level (below maxStoneLevel) give one stone
##   of the next level with count × mergeRatePerItem % chance; every stone put in is consumed.
## The highest level, stone level, merge counts and rates are the game data's (GET /gamedata
## equipment) when the catalog does not send its own.
## The level colours a piece's aura, frame and name: +1..+5 green (the subtlest, no stat bonus),
## +6..+9 sky blue, +10..+13 orange, +14..+15 purple, +16 red (the highest); +0 the normal look.
## The stat-bonus milestones are the game data's equipment.milestones (+6 / +10 / +14 / +16).

const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const Fmt := preload("res://core/fmt.gd")
const GameData := preload("res://autoload/game_data_model.gd")

## Colour tiers: 0 at +0 (normal look), then 1 green from +1, then one per milestone (2 sky blue,
## 3 orange, 4 purple, 5 red; tier_from()).
const TIER_COLORS := [
	Color(1, 1, 1),
	Color(0.18, 0.9, 0.42), # green (#2EE66B, emerald, not the sky blue of +6)
	Color(0.36, 0.8, 1.0), # sky blue
	Color(1.0, 0.6, 0.16), # orange
	Color(0.66, 0.32, 1.0), # purple (violet, not lavender)
	Color(1.0, 0.1, 0.1), # red (#FF1A1A, no pink)
]
const TIER_WORDS := ["", "xanh lá", "xanh da trời", "cam", "tím", "đỏ"]
## How dim the piece popup draws a milestone not reached yet.
const UNREACHED_ALPHA := 0.4


# ── Limits (game data) ──────────────────────────────────────────────────────

## The highest +level (equipment.maxUpgradeLevel).
static func max_level() -> int:
	return GameData.max_upgrade_level()


## The highest stone level (equipment.maxStoneLevel): stones below it merge into the next.
static func stone_levels() -> int:
	return GameData.max_stone_level()


## A merge takes merge_min()..merge_max() stones of one level.
static func merge_min() -> int:
	return GameData.merge_min_count()


static func merge_max() -> int:
	return GameData.merge_max_count()


# ── Milestones ──────────────────────────────────────────────────────────────

## The stat-bonus milestone levels (equipment.milestones: +6, +10, +14, +16), index 0 unused.
static func milestone_from() -> Array:
	var out: Array = [0]
	for m in GameData.upgrade_milestones():
		out.append(int(m[0]))
	return out


## The first level of each colour tier: 0, 1, then the milestones.
static func tier_from() -> Array:
	return [0, 1] + milestone_from().slice(1)


## The colour tier of a level: 0 at +0, 1 for +1..+5, 2 for +6..+9, 3 for +10..+13, 4 for
## +14..+15, 5 for +16.
static func color_tier(level: int) -> int:
	var from := tier_from()
	for t in range(from.size() - 1, 0, -1):
		if level >= int(from[t]):
			return mini(t, TIER_COLORS.size() - 1)
	return 0


## The aura / frame / name colour of a level (white at +0).
static func milestone_color(level: int) -> Color:
	return TIER_COLORS[color_tier(level)]


## The hexagon frame tint of a piece at `level`: its colour mixed into white, plain white at +0.
static func frame_tint(level: int) -> Color:
	var t := color_tier(level)
	return Color.WHITE if t == 0 else Color.WHITE.lerp(TIER_COLORS[t], 0.6)


## The item name colour of a piece: its level colour, white at +0.
static func name_color(piece: Dictionary) -> Color:
	return milestone_color(int(piece.get("upgradeLevel", 0)))


## Whether `level` is a stat-bonus milestone (+6, +10, +14, +16).
static func is_milestone(level: int) -> bool:
	return level > 0 and milestone_from().has(level)


## The milestone level a piece at `level` reaches next (6, 10, 14, 16), or -1 past the last.
static func next_milestone(level: int) -> int:
	var from := milestone_from()
	for t in range(1, from.size()):
		if int(from[t]) > level:
			return int(from[t])
	return -1


## The catalog's milestone bonuses as [[level, bonus]...] ascending (EquipmentModel.milestones()).
static func milestone_bonus(catalog: Variant, level: int) -> float:
	for m in EquipmentModel.milestones(catalog):
		if int(m[0]) == level:
			return float(m[1])
	return 0.0


## "+6: +10% chỉ số, hào quang xanh da trời" (the milestone at `level`), "" when it is none.
static func milestone_text(catalog: Variant, level: int) -> String:
	if not is_milestone(level):
		return ""
	return "+%d: +%s chỉ số, hào quang %s" % [level, BattleStats.format_chance(milestone_bonus(catalog, level) * 100.0),
		TIER_WORDS[color_tier(level)]]


## The piece popup's "Mốc nâng cấp" rows for a piece at `level`, +6 / +10 / +14 / +16:
## [{level, tier, color, bonus (fraction), bonus_text "+10% chỉ số", aura "Hào quang xanh da
## trời", back_aura, reached}]; bonuses from the catalog's upgradeMilestones (defaults before it
## loads). back_aura: for a weapon, the ring its +14 / +16 adds behind the wearer's back
## (scenes/character/back_aura.gd), "· hào quang tím sau lưng" / "· hào quang đỏ sau lưng"; ""
## for the other rows and for armour.
static func milestone_rows(catalog: Variant, level: int, weapon: bool = false) -> Array:
	var out: Array = []
	var from := milestone_from()
	for t in range(1, from.size()):
		var lv: int = from[t]
		var bonus := milestone_bonus(catalog, lv)
		var tier := color_tier(lv)
		out.append({"level": lv, "tier": tier, "color": TIER_COLORS[tier], "bonus": bonus,
			"bonus_text": "+%s chỉ số" % BattleStats.format_chance(bonus * 100.0),
			"aura": "Hào quang " + TIER_WORDS[tier], "back_aura": back_aura_text(lv) if weapon else "",
			"reached": level >= lv})
	return out


## "· hào quang tím sau lưng" at +14, "· hào quang đỏ sau lưng" at +16 (a weapon's back aura), ""
## for the other milestones.
static func back_aura_text(milestone: int) -> String:
	match milestone:
		14:
			return "· hào quang tím sau lưng"
		16:
			return "· hào quang đỏ sau lưng"
	return ""


## "Cấp nâng cấp +7 / 16"
static func level_line(level: int) -> String:
	return "Cấp nâng cấp +%d / %d" % [clampi(level, 0, max_level()), max_level()]


## The share of a piece's stats the upgrade adds: "+24% từ nâng cấp" (upgrade multiplier − 1,
## milestones included), "" at +0.
static func upgrade_share_text(catalog: Variant, level: int) -> String:
	if level <= 0:
		return ""
	var pct := (EquipmentModel.upgrade_multiplier(level, EquipmentModel.milestones(catalog)) - 1.0) * 100.0
	return "+%s từ nâng cấp" % BattleStats.format_chance(pct)


# ── Rates and chance ────────────────────────────────────────────────────────

## The catalog's upgradeRates row for upgrading from `level` ({fromLevel, toLevel, upgradeCost,
## maxPercent, failResetTo}), {} when there is none (max level or not loaded).
static func rate(catalog: Variant, level: int) -> Dictionary:
	if not catalog is Dictionary or not catalog.get("upgradeRates") is Array:
		return {}
	for r in catalog["upgradeRates"]:
		if r is Dictionary and int(r.get("fromLevel", -1)) == level:
			return r
	return {}


## The power of one stone of `stone_level` (the catalog's stones row; 0 when it has none).
static func power(catalog: Variant, stone_level: int) -> int:
	var s := stone(catalog, stone_level)
	if s.get("power") is int or s.get("power") is float:
		return int(s["power"])
	return 0


## The catalog's stones row of a level, {} when unknown.
static func stone(catalog: Variant, stone_level: int) -> Dictionary:
	if catalog is Dictionary and catalog.get("stones") is Array:
		for s in catalog["stones"]:
			if s is Dictionary and int(s.get("stoneLevel", 0)) == stone_level:
				return s
	return {}


## Σ power × quantity of picked ({stoneLevel: quantity}); zero and negative quantities count 0.
static func total_power(catalog: Variant, picked: Dictionary) -> int:
	var total := 0
	for lv in picked:
		if int(picked[lv]) > 0:
			total += power(catalog, int(lv)) * int(picked[lv])
	return total


## The chance before the cap: power × 100 / cost (0 without a cost). cost: the effective cost
## (upgradeCost × the slot's multiplier).
static func raw_percent(power_sum: int, cost: float) -> float:
	if cost <= 0.0:
		return 0.0
	return maxf(float(power_sum) * 100.0 / cost, 0.0)


## The success chance the server rolls without careful: min(power × 100 / cost, maxPercent).
static func percent(power_sum: int, cost: float, max_percent: float) -> float:
	return minf(raw_percent(power_sum, cost), max_percent)


## The catalog's weaponUpgradeCostMultiplier (the game data's when missing or below 1).
static func weapon_cost_multiplier(catalog: Variant) -> float:
	var v = catalog.get("weaponUpgradeCostMultiplier") if catalog is Dictionary else null
	if (v is int or v is float) and float(v) >= 1.0:
		return float(v)
	return GameData.weapon_upgrade_cost_multiplier()


## How many times upgradeCost a piece in `slot` needs: the weapon multiplier for "weapon", else 1.
static func cost_multiplier(catalog: Variant, slot: String) -> float:
	return weapon_cost_multiplier(catalog) if slot == "weapon" else 1.0


## The slot of a piece (its own, else its item's).
static func piece_slot(catalog: Variant, piece: Dictionary) -> String:
	var slot := str(piece.get("slot", ""))
	if slot == "":
		slot = str(EquipmentModel.item_of_piece(catalog, piece).get("slot", ""))
	return slot


## The careful upgrade of the step from `level`: {gem, bonus (relative %), offered}; the row's
## carefulGemCost / carefulBonusPercent (0 when the row lacks them: no careful); offered: a rate
## row with both > 0.
static func careful(catalog: Variant, level: int) -> Dictionary:
	var r := rate(catalog, level)
	var gem = r.get("carefulGemCost")
	var bonus = r.get("carefulBonusPercent")
	var g: int = int(gem) if gem is int or gem is float else 0
	var b: float = float(bonus) if bonus is int or bonus is float else 0.0
	return {"gem": g, "bonus": b, "offered": not r.is_empty() and g > 0 and b > 0.0}


## The careful percent of a stone percent: stone × (1 + bonus / 100) rounded to 2 decimals, capped
## at 100 (the server's CalculateFinalUpgradePercent).
static func careful_percent(stone_percent: float, bonus: float) -> float:
	if bonus <= 0.0:
		return minf(stone_percent, 100.0)
	return minf(round(stone_percent * (1.0 + bonus / 100.0) * 100.0) / 100.0, 100.0)


## The chance of picked stones for a piece in `slot` at `level`: {percent (what the server rolls),
## stone (the stones' part, capped), max, raw, power, cost (effective: upgradeCost × mult), mult,
## wasted, careful (on and offered), bonus, gem}. wasted: the stones' chance is above the cap, the
## excess is lost. careful_on: the player turned careful on (ignored when the step has none).
static func chance(catalog: Variant, level: int, picked: Dictionary, slot: String = "", careful_on: bool = false) -> Dictionary:
	var r := rate(catalog, level)
	var mult := cost_multiplier(catalog, slot)
	var cost := float(r.get("upgradeCost", 0)) * mult
	var maxp := float(r.get("maxPercent", 0.0))
	var p := total_power(catalog, picked)
	var raw := raw_percent(p, cost)
	var stone_p := minf(raw, maxp)
	var cf := careful(catalog, level)
	var on: bool = careful_on and cf["offered"]
	return {"percent": careful_percent(stone_p, cf["bonus"]) if on else stone_p, "stone": stone_p, "max": maxp, "raw": raw,
		"power": p, "cost": cost, "mult": mult, "wasted": raw > maxp + 1e-9 and maxp > 0.0,
		"careful": on, "bonus": cf["bonus"], "gem": cf["gem"] if on else 0}


## The least power reaching the cap: the smallest whole p with p × 100 / cost ≥ maxPercent.
static func needed_power(cost: float, max_percent: float) -> int:
	if cost <= 0.0 or max_percent <= 0.0:
		return 0
	var p := int(ceil(max_percent * cost / 100.0 - 1e-9))
	while raw_percent(p, cost) < max_percent - 1e-9:
		p += 1
	return maxi(p, 1)


## "Tỉ lệ thành công 64% (tối đa 64%)"; careful: "Tỉ lệ thành công 28%" (the final chance only).
static func chance_text(c: Dictionary) -> String:
	if c.get("careful", false):
		return "Tỉ lệ thành công %s" % BattleStats.format_chance(c["percent"])
	return "Tỉ lệ thành công %s (tối đa %s)" % [BattleStats.format_chance(c["percent"]), BattleStats.format_chance(c["max"])]


## The careful upgrade confirmation: "Dùng 120 kim cương cho nâng cấp cẩn thận?" (the step's price).
static func careful_confirm_text(c: Dictionary) -> String:
	return "Dùng %s kim cương cho nâng cấp cẩn thận?" % Fmt.thousands(int(c["gem"]))


## "Tự chọn": the stones (from owned {stoneLevel: quantity}) with the least total power that still
## reaches the cap for a piece in `slot` at `level` (a weapon needs the multiplied power), as {stoneLevel: quantity}; every owned stone when even
## all of them do not reach it; {} at the max level or without stones.
static func auto_pick(catalog: Variant, level: int, owned: Dictionary, slot: String = "") -> Dictionary:
	var r := rate(catalog, level)
	var need := needed_power(float(r.get("upgradeCost", 0)) * cost_multiplier(catalog, slot), float(r.get("maxPercent", 0.0)))
	var levels: Array = []
	for lv in owned:
		if int(owned[lv]) > 0 and power(catalog, int(lv)) > 0:
			levels.append(int(lv))
	if need <= 0 or levels.is_empty():
		return {}
	levels.sort_custom(func(a, b): return power(catalog, a) > power(catalog, b))
	var all := {}
	for lv in levels:
		all[lv] = int(owned[lv])
	if total_power(catalog, all) <= need:
		return all
	# Greedy from the strongest stone down: as many as fit under the need.
	var pick := {}
	var left := need
	for lv in levels:
		var p := power(catalog, lv)
		var k := mini(int(owned[lv]), left / p)
		if k > 0:
			pick[lv] = k
			left -= k * p
	if left > 0:
		# One more stone: the weakest one left (any left stone is stronger than what is missing).
		for i in range(levels.size() - 1, -1, -1):
			var lv: int = levels[i]
			if int(pick.get(lv, 0)) < int(owned[lv]):
				pick[lv] = int(pick.get(lv, 0)) + 1
				break
	# Drop weak stones the extra one made unnecessary.
	for i in range(levels.size() - 1, -1, -1):
		var lv: int = levels[i]
		while int(pick.get(lv, 0)) > 0 and total_power(catalog, pick) - power(catalog, lv) >= need:
			pick[lv] = int(pick[lv]) - 1
	for lv in pick.keys():
		if int(pick[lv]) <= 0:
			pick.erase(lv)
	return pick


## The POST /player/equipment/upgrade stones of picked ({stoneLevel: quantity}), ascending level,
## zero quantities left out.
static func request_stones(picked: Dictionary) -> Array:
	var levels: Array = picked.keys().filter(func(lv): return int(picked[lv]) > 0)
	levels.sort()
	return levels.map(func(lv): return {"stoneLevel": int(lv), "quantity": int(picked[lv])})


## "Thất bại: giữ nguyên +3" (failResetTo is the current level) or "Thất bại: về +6".
static func fail_text(catalog: Variant, level: int) -> String:
	var r := rate(catalog, level)
	if r.is_empty():
		return ""
	var to := int(r.get("failResetTo", level))
	return "Thất bại: giữ nguyên +%d" % level if to == level else "Thất bại: về +%d" % to


## Why the Nâng cấp button is off ("" when it can be pressed): no piece, max level, no rate, no
## stones picked, more picked than owned; with careful on (and offered for the step) fewer gems
## than its price (`gem_balance`, -1 = unknown: not checked).
static func blocked_reason(catalog: Variant, piece: Dictionary, picked: Dictionary, owned: Dictionary,
		careful_on: bool = false, gem_balance: int = -1) -> String:
	if piece.is_empty():
		return "Chọn một trang bị"
	var level := int(piece.get("upgradeLevel", 0))
	if level >= max_level():
		return "Đã đạt tối đa +%d" % max_level()
	if rate(catalog, level).is_empty():
		return "Chưa có bảng nâng cấp cho +%d" % level
	if total_power(catalog, picked) <= 0:
		return "Chưa chọn đá" if not owned.is_empty() else "Chưa có đá nâng cấp"
	for lv in picked:
		if int(picked[lv]) > int(owned.get(lv, 0)):
			return "Không đủ đá cấp %d" % int(lv)
	if careful_on and gem_balance >= 0:
		var cf := careful(catalog, level)
		if cf["offered"] and gem_balance < int(cf["gem"]):
			return "Thiếu kim cương cho Nâng cấp cẩn thận (cần %s)" % Fmt.thousands(int(cf["gem"]))
	return ""


# ── Stats ───────────────────────────────────────────────────────────────────

## The piece's stats now and after one more level: [{key, label, now, next (the stat line texts,
## "+110 điểm (+5.500)"), now_points / next_points ("+110 điểm", "+2.2%"), now_battle /
## next_battle (what they add in battle, "+5.500"; "" without the multiplier or for crit), delta
## ("+12 điểm" / "+0.2%"), up (bool)}], the stats the item has. `mult`: BattleStats.multipliers.
static func stat_steps(catalog: Variant, piece: Dictionary, mult: Dictionary = {}) -> Array:
	var item := EquipmentModel.item_of_piece(catalog, piece)
	var level := int(piece.get("upgradeLevel", 0))
	var now := EquipmentModel.upgraded(item, level, EquipmentModel.milestones(catalog))
	var next := EquipmentModel.upgraded(item, mini(level + 1, max_level()), EquipmentModel.milestones(catalog))
	var out: Array = []
	var after := {}
	for l in EquipmentModel.stat_lines(next, mult):
		after[l["key"]] = l
	for l in EquipmentModel.stat_lines(now, mult):
		var n: Dictionary = after.get(l["key"], l)
		var s: Dictionary = EquipmentModel.STATS.filter(func(x): return x["key"] == l["key"])[0]
		var d := float(n["value"]) - float(l["value"])
		var delta := ""
		if s["unit"] == "%":
			delta = "+" + BattleStats.format_chance(d)
		else:
			delta = "+%s điểm" % Fmt.thousands(int(d))
		out.append({"key": l["key"], "label": l["label"], "now": l["text"], "next": n["text"], "delta": delta, "up": d > 1e-9,
			"now_points": _points(float(l["value"]), s["unit"]), "next_points": _points(float(n["value"]), s["unit"]),
			"now_battle": _battle(l["battle"]), "next_battle": _battle(n["battle"])})
	return out


## The Nâng cấp page's centre: the piece now and after one more level side by side.
## {maxed, columns: [{level, color}] (now, then next unless at +16), rows: stat_steps(), fail:
## fail_text() ("" at +16), note: "Đã đạt cấp tối đa" at +16 else ""}. No milestone text: the
## next column's aura shows it.
static func preview(catalog: Variant, piece: Dictionary, mult: Dictionary = {}) -> Dictionary:
	var level := clampi(int(piece.get("upgradeLevel", 0)), 0, max_level())
	var maxed := level >= max_level()
	var columns: Array = [{"level": level, "color": milestone_color(level)}]
	if not maxed:
		columns.append({"level": level + 1, "color": milestone_color(level + 1)})
	return {"maxed": maxed, "columns": columns, "rows": stat_steps(catalog, piece, mult),
		"fail": "" if maxed else fail_text(catalog, level), "note": "Đã đạt cấp tối đa" if maxed else ""}


static func _points(v: float, unit: String) -> String:
	return "+" + BattleStats.format_chance(v) if unit == "%" else "+%s điểm" % Fmt.thousands(int(v))


static func _battle(v: Variant) -> String:
	return "+" + Fmt.thousands(int(v)) if v is int or v is float else ""


# ── Stones ──────────────────────────────────────────────────────────────────

## GET /player/stones ([{stoneLevel, quantity}]; null when empty) → {stoneLevel: quantity} of the
## owned levels, or null when malformed.
static func parse_stones(data: Variant) -> Variant:
	if data == null:
		return {}
	if not data is Array:
		return null
	var out := {}
	for s in data:
		if s is Dictionary and (s.get("stoneLevel") is int or s.get("stoneLevel") is float):
			var lv := int(s["stoneLevel"])
			var q := int(s.get("quantity", 0))
			if lv >= 1 and lv <= stone_levels() and q > 0:
				out[lv] = int(out.get(lv, 0)) + q
	return out


## The owned levels, ascending.
static func owned_levels(owned: Variant) -> Array:
	if not owned is Dictionary:
		return []
	var out: Array = owned.keys().filter(func(lv): return int(owned[lv]) > 0)
	out.sort()
	return out


## "Đá cấp 3"
static func stone_name(stone_level: int) -> String:
	return "Đá cấp %d" % stone_level


## The shop's stones, levels 1..12: [{stoneLevel, power, currency, price, buyable}] (buyable:
## sold for coin or gem; levels 11–12 are merge only).
static func shop_stones(catalog: Variant) -> Array:
	var out: Array = []
	for lv in range(1, stone_levels() + 1):
		var s := stone(catalog, lv)
		var coin := int(s.get("priceCoin", 0))
		var gem := int(s.get("priceGem", 0))
		var currency := "coin" if coin > 0 else "gem"
		var price := coin if coin > 0 else gem
		out.append({"stoneLevel": lv, "power": power(catalog, lv), "currency": currency, "price": price,
			"buyable": not s.is_empty() and str(s.get("source", "")) != "merge_only" and price > 0})
	return out


## "Mua 5 × Đá cấp 3 với giá 3.500 xu?"
static func buy_confirm_text(row: Dictionary, quantity: int) -> String:
	return "Mua %d × %s với giá %s %s?" % [quantity, stone_name(int(row["stoneLevel"])), Fmt.thousands(int(row["price"]) * quantity),
		"kim cương" if row["currency"] == "gem" else "xu"]


# ── Merge ───────────────────────────────────────────────────────────────────

## The catalog's mergeRatePerItem (the game data's when missing or not positive).
static func merge_rate(catalog: Variant) -> float:
	var v = catalog.get("mergeRatePerItem") if catalog is Dictionary else null
	if (v is int or v is float) and float(v) > 0.0:
		return float(v)
	return GameData.merge_rate_per_item()


## The success chance of merging `count` stones (capped at 100).
static func merge_chance(catalog: Variant, count: int) -> float:
	return minf(float(count) * merge_rate(catalog), 100.0)


## Why "Ghép" is off ("" when it can be pressed).
static func merge_blocked(stone_level: int, count: int, owned: Variant) -> String:
	if stone_level < 1 or stone_level >= stone_levels():
		return "Đá cấp %d là cao nhất" % stone_levels() if stone_level >= stone_levels() else "Chọn một cấp đá"
	if count < merge_min() or count > merge_max():
		return "Bỏ vào %d–%d viên" % [merge_min(), merge_max()]
	var have := int(owned.get(stone_level, 0)) if owned is Dictionary else 0
	if have < count:
		return "Cần %d viên, đang có %d" % [count, have]
	return ""


## "4 × Đá cấp 3 → 1 × Đá cấp 4"
static func merge_text(stone_level: int, count: int) -> String:
	return "%d × %s → 1 × %s" % [count, stone_name(stone_level), stone_name(stone_level + 1)]
