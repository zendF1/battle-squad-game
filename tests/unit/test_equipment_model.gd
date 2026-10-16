extends "res://tests/test_case.gd"

const M := preload("res://screens/home/equipment_model.gd")

## Design levels: normal 10/20/30/40, crafted 75 for diamond. Weapons are per character; the
## generic Iron/Mithril Blaster are retired (inactive) but owned pieces still need them.
const CATALOG := {
	"items": [
		{"itemId": "normal_weapon_lv10", "name": "Iron Blaster", "slot": "weapon", "category": "normal", "requiredLevel": 10, "gemSlots": 1,
			"statHp": 0, "statDamage": 8, "statDefense": 0, "statCrit": 0, "statMoveEnergy": 0, "priceCoin": 500, "priceGem": 0, "isActive": false},
		{"itemId": "normal_weapon_lv30", "name": "Mithril Blaster", "slot": "weapon", "category": "normal", "requiredLevel": 30, "gemSlots": 1,
			"statHp": 0, "statDamage": 25, "statDefense": 0, "statCrit": 2, "statMoveEnergy": 0, "priceCoin": 4000, "priceGem": 0, "isActive": false},
		{"itemId": "normal_armor_lv40", "name": "Dragon Vest", "slot": "armor", "category": "normal", "requiredLevel": 40, "gemSlots": 1,
			"statHp": 150, "statDamage": 0, "statDefense": 15, "statCrit": 0, "statMoveEnergy": 0, "priceCoin": 8000, "priceGem": 0, "isActive": true},
		{"itemId": "normal_helmet_lv10", "name": "Iron Cap", "slot": "helmet", "category": "normal", "requiredLevel": 10, "gemSlots": 1,
			"statHp": 20, "statDamage": 0, "statDefense": 2, "statCrit": 0, "statMoveEnergy": 0, "priceCoin": 0, "priceGem": 30, "isActive": true},
		{"itemId": "normal_boots_lv20", "name": "Steel Boots", "slot": "boots", "category": "normal", "requiredLevel": 20, "gemSlots": 1,
			"statHp": 20, "statDamage": 0, "statDefense": 2, "statCrit": 0, "statMoveEnergy": 10, "priceCoin": 800, "priceGem": 0, "isActive": false},
		{"itemId": "crafted_gloves_diamond", "name": "Diamond Gloves", "slot": "gloves", "category": "crafted", "tier": "diamond", "requiredLevel": 75,
			"statHp": 0, "statDamage": 24, "statDefense": 0, "statCrit": 16, "statMoveEnergy": 0, "priceCoin": 0, "priceGem": 0, "isActive": true},
		{"itemId": "tanko_weapon_lv10", "name": "Iron Cannon", "slot": "weapon", "category": "normal", "requiredLevel": 10, "characterId": "tanko",
			"statDamage": 8, "priceCoin": 500, "isActive": true},
		{"itemId": "rookie_weapon_lv20", "name": "Steel Bazooka", "slot": "weapon", "category": "normal", "requiredLevel": 20, "characterId": "rookie",
			"statDamage": 15, "statCrit": 1, "priceCoin": 1500, "isActive": true},
		"junk",
	],
	"upgradeRates": [{"fromLevel": 0, "toLevel": 1}],
}

const MULT := {"hp": 50, "damage": 5, "mobility": 3, "defense": 5, "skillPower": 5, "terrainDamage": 3}

const CHARS := {"characters": [
	{"characterId": "rookie", "level": 15},
	{"characterId": "tanko", "level": 40},
]}


static func _owned() -> Array:
	return [
		{"equipmentId": "e1", "itemId": "normal_weapon_lv10", "slot": "weapon", "category": "normal", "upgradeLevel": 0, "isEquipped": false},
		{"equipmentId": "e2", "itemId": "normal_armor_lv40", "slot": "armor", "category": "normal", "upgradeLevel": 3, "isEquipped": true, "equippedOn": "tanko"},
		{"equipmentId": "e3", "itemId": "normal_weapon_lv30", "slot": "weapon", "category": "normal", "upgradeLevel": 1, "isEquipped": true, "equippedOn": "rookie"},
		{"equipmentId": "e4", "itemId": "normal_helmet_lv10", "slot": "helmet", "category": "normal", "upgradeLevel": 0, "isEquipped": false},
		{"equipmentId": "e5", "itemId": "normal_weapon_lv10", "slot": "weapon", "category": "normal", "upgradeLevel": 2, "isEquipped": false},
	]


func test_parse_catalog() -> void:
	var c = M.parse_catalog(CATALOG)
	check(c is Dictionary, "parsed")
	eq(c["order"].size(), 8, "junk dropped")
	eq(M.item_of(c, "normal_weapon_lv10")["isActive"], false, "inactive kept for owned pieces")
	eq(c["upgradeRates"].size(), 1, "rates kept")
	eq(c["setBonuses"], [], "missing list is empty")
	eq(M.parse_catalog({"items": "x"}), null, "malformed")
	eq(M.parse_catalog(null), null, "null")
	eq(M.item_of(c, "normal_armor_lv40")["name"], "Dragon Vest", "item_of")
	eq(M.item_of(c, "nope"), {}, "unknown")
	eq(M.item_of(null, "normal_armor_lv40"), {}, "no catalog")


func test_parse_owned() -> void:
	eq(M.parse_owned(null), [], "null is empty")
	eq(M.parse_owned("x"), null, "malformed")
	eq(M.parse_owned([{"equipmentId": "a"}, {"itemId": "b"}, 3]).size(), 1, "only pieces with an id")


func test_slot_names_and_order() -> void:
	eq(M.SLOTS, ["helmet", "armor", "gloves", "pants", "boots", "weapon"], "order")
	eq(M.slot_name("weapon"), "Vũ khí", "weapon")
	eq(M.slot_name("armor"), "Áo", "armor")
	eq(M.slot_name("helmet"), "Mũ", "helmet")
	eq(M.slot_name("pants"), "Quần", "pants")
	eq(M.slot_name("boots"), "Giày", "boots")
	eq(M.slot_name("gloves"), "Găng tay", "gloves")
	eq(M.slot_name("ring"), "ring", "unknown slot")


func test_display_names_and_tiers() -> void:
	eq(M.display_name({"name": "Iron Sword"}), "Kiếm Sắt", "iron sword")
	eq(M.display_name({"name": "Dragon Vest"}), "Áo giáp Rồng", "dragon vest")
	eq(M.display_name({"name": "Steel Cap"}), "Mũ Thép", "steel cap")
	eq(M.display_name({"name": "Mithril Pants"}), "Quần Mithril", "mithril pants")
	eq(M.display_name({"name": "Silver Boots"}), "Giày Bạc", "silver boots")
	eq(M.display_name({"name": "Gold Gloves"}), "Găng Vàng", "gold gloves")
	eq(M.display_name({"name": "Titan Vest"}), "Áo giáp Titan", "titan")
	eq(M.display_name({"name": "Diamond Sword"}), "Kiếm Kim cương", "diamond")
	eq(M.display_name({"name": "Tanko Hammer"}), "Tanko Hammer", "fallback to the server name")
	eq(M.display_name({"name": "Diamond Blaster"}), "Súng Kim cương", "crafted blaster")
	eq(M.display_name({"name": "Iron Bazooka"}), "Bazooka Sắt", "rookie gun")
	eq(M.display_name({"name": "Dragon Cannon"}), "Đại pháo Rồng", "tanko gun")
	eq(M.display_name({"name": "Steel Shock Rifle"}), "Súng điện Thép", "spark gun")
	eq(M.display_name({"name": "Mithril Seed Launcher"}), "Súng hạt Mithril", "flora gun")
	eq(M.display_name({"name": "Iron Blaster"}), "Súng Sắt", "generic blaster")
	eq(M.display_name({"name": "Iron Laser Cannon"}), "Iron Laser Cannon", "unknown type: server name")
	eq(M.display_name({"name": "Rookie Sword"}), "Rookie Sword", "old per-character name: server name")
	eq(M.display_name({"itemId": "x", "slot": "boots", "category": "crafted", "tier": "gold"}), "Giày Vàng", "no name: slot + tier")
	eq(M.tier({"itemId": "normal_weapon_lv10", "name": "Iron Sword"}), "iron", "tier from the name")
	eq(M.tier({"itemId": "normal_weapon_lv40", "name": "Kiếm"}), "dragon", "tier from the id suffix")
	eq(M.tier({"itemId": "rookie_weapon_lv20", "name": "Rookie Sword"}), "steel", "character weapon tier from the id suffix")
	eq(M.tier({"itemId": "spark_weapon_lv40", "name": "Dragon Shock Rifle"}), "dragon", "gun tier from the name")
	eq(M.weapon_kind({"slot": "weapon", "characterId": "rookie", "name": "x"}), "bazooka", "rookie: bazooka")
	eq(M.weapon_kind({"slot": "weapon", "characterId": "tanko"}), "cannon", "tanko: cannon")
	eq(M.weapon_kind({"slot": "weapon", "characterId": "spark"}), "rifle", "spark: rifle")
	eq(M.weapon_kind({"slot": "weapon", "name": "Gold Seed Launcher"}), "launcher", "kind from the name")
	eq(M.weapon_kind({"slot": "weapon", "name": "Iron Blaster"}), "", "blaster")
	eq(M.weapon_kind({"slot": "armor", "characterId": "rookie"}), "", "not a weapon")
	eq(M.tier({"itemId": "crafted_x", "tier": "Titan"}), "titan", "tier field")
	eq(M.tier({"itemId": "q", "category": "crafted"}), "silver", "crafted default")
	eq(M.tier({"itemId": "q"}), "iron", "normal default")
	eq(M.level_text({"upgradeLevel": 7}), "+7", "badge")
	eq(M.level_text({}), "+0", "new piece")


func test_stat_lines() -> void:
	var c = M.parse_catalog(CATALOG)
	var lines := M.stat_lines(M.item_of(c, "normal_weapon_lv30"), MULT)
	eq(lines.map(func(l): return [l["label"], l["text"]]), [["Sát thương", "+25 điểm (+125)"], ["Chí mạng", "+2%"]], "non-zero stats")
	eq(lines.map(func(l): return [l["value"], l["battle"]]), [[25.0, 125], [2.0, null]], "points and battle values; crit has no multiplier")
	# Iron Cap: +20 HP points = 20 × 50 HP.
	eq(M.stat_summary(M.item_of(c, "normal_helmet_lv10"), MULT), "Máu +20 điểm (+1.000) · Phòng thủ +2 điểm (+10)", "points and converted")
	eq(M.stat_summary(M.item_of(c, "normal_boots_lv20"), MULT), "Máu +20 điểm (+1.000) · Phòng thủ +2 điểm (+10) · Di chuyển +10 điểm (+30)", "move energy × mobility")
	eq(M.stat_summary(M.item_of(c, "normal_armor_lv40")), "Máu +150 điểm · Phòng thủ +15 điểm", "points only before the multipliers load")
	eq(M.stat_lines({}), [], "none")
	eq(M.stat_lines({"statCrit": 2.5}, MULT)[0]["text"], "+2.5%", "fractional crit")


func test_compare() -> void:
	var c = M.parse_catalog(CATALOG)
	var iron := M.item_of(c, "normal_weapon_lv10")
	var mithril := M.item_of(c, "normal_weapon_lv30")
	var up := M.compare(mithril, iron, MULT)
	eq(up.map(func(d): return [d["label"], d["text"], d["tone"]]), [["Sát thương", "+85 (+17 điểm)", "good"], ["Chí mạng", "+2%", "good"]], "upgrade")
	eq(up[0]["delta"], 17.0, "delta in points")
	var down := M.compare(iron, mithril, MULT)
	eq(down.map(func(d): return [d["text"], d["tone"]]), [["−85 (−17 điểm)", "loss"], ["−2%", "loss"]], "downgrade")
	var armor := M.compare({}, M.item_of(c, "normal_armor_lv40"), MULT)
	eq(armor.map(func(d): return d["text"]), ["−7.500 (−150 điểm)", "−75 (−15 điểm)"], "thousands separator")
	var empty := M.compare(iron, {}, MULT)
	eq(empty.map(func(d): return d["text"]), ["+40 (+8 điểm)"], "empty slot")
	eq(M.compare(mithril, iron).map(func(d): return d["text"]), ["+17 điểm", "+2%"], "points only before the multipliers load")
	eq(M.compare(iron, iron, MULT).map(func(d): return [d["text"], d["tone"]]), [["0", ""]], "same piece")


func test_wearer_and_worn() -> void:
	var owned := _owned()
	eq(M.wearer(owned[1]), "tanko", "worn")
	eq(M.wearer(owned[0]), "", "free")
	eq(M.wearer({"equippedOn": "rookie", "isEquipped": false}), "", "isEquipped false wins")
	var w := M.worn(owned, "rookie")
	eq(w.keys(), ["weapon"], "rookie wears a weapon")
	eq(w["weapon"]["equipmentId"], "e3", "the piece")
	eq(M.worn(null, "rookie"), {}, "not loaded")
	eq(M.worn_text(owned[1]), "Đang mặc · Tanko", "worn text")
	eq(M.worn_text(owned[0]), "", "free text")
	eq(M.owned_count(owned, "normal_weapon_lv10"), 2, "count")
	eq(M.owned_text(2), "Đã có 2", "owned text")
	eq(M.owned_text(0), "", "none owned")
	eq(M.find_piece(owned, "e4")["itemId"], "normal_helmet_lv10", "find")
	eq(M.filter_slot(owned, "weapon").size(), 3, "filter")
	eq(M.filter_slot(owned, "").size(), 5, "all")


func test_can_wear() -> void:
	var c = M.parse_catalog(CATALOG)
	eq(M.can_wear(M.item_of(c, "normal_weapon_lv30"), "rookie", CHARS), {"ok": false, "reason": "Cần Lv 30"}, "level")
	eq(M.can_wear(M.item_of(c, "normal_weapon_lv30"), "tanko", CHARS)["ok"], true, "level ok (retired generic weapon still wearable)")
	eq(M.can_wear(M.item_of(c, "tanko_weapon_lv10"), "rookie", CHARS), {"ok": false, "reason": "Chỉ cho Tanko"}, "restricted")
	eq(M.can_wear(M.item_of(c, "tanko_weapon_lv10"), "tanko", CHARS)["ok"], true, "restricted ok")
	eq(M.can_wear(M.item_of(c, "rookie_weapon_lv20"), "rookie", CHARS), {"ok": false, "reason": "Cần Lv 20"}, "own weapon, level")
	eq(M.can_wear(M.item_of(c, "normal_weapon_lv10"), "flora", CHARS), {"ok": false, "reason": "Chưa sở hữu nhân vật"}, "not owned")
	eq(M.can_wear(M.item_of(c, "normal_weapon_lv30"), "rookie", null)["ok"], true, "unknown: server decides")
	eq(M.required_text(M.item_of(c, "normal_armor_lv40")), "Lv 40", "required text")


func test_sort_bag() -> void:
	var c = M.parse_catalog(CATALOG)
	var ids := M.sort_bag(_owned(), c).map(func(p): return p["equipmentId"])
	# Worn first (Dragon Vest Lv40 armor, then Mithril Blaster Lv30), then by level, slot, upgrade.
	eq(ids, ["e2", "e3", "e4", "e5", "e1"], "bag order")
	eq(M.sort_bag(null, c), [], "not loaded")


func test_sort_for_character() -> void:
	var c = M.parse_catalog(CATALOG)
	var weapons := M.filter_slot(_owned(), "weapon")
	var ids := M.sort_for_character(weapons, c, "rookie", CHARS).map(func(p): return p["equipmentId"])
	eq(ids, ["e3", "e1", "e5"], "worn first, then free")
	ids = M.sort_for_character(_owned(), c, "tanko", CHARS).map(func(p): return p["equipmentId"])
	eq(ids[0], "e2", "tanko's own first")
	eq(ids[ids.size() - 1], "e3", "pieces of others last")


func test_shop_items_and_price() -> void:
	var c = M.parse_catalog(CATALOG)
	var ids := func(items: Array) -> Array: return items.map(func(i): return i["itemId"])
	eq(ids.call(M.shop_items(c)), ["normal_helmet_lv10", "normal_armor_lv40"], "shared: normal, active, priced, slot order")
	eq(ids.call(M.shop_items(c, "", "rookie")), ["normal_helmet_lv10", "normal_armor_lv40", "rookie_weapon_lv20"], "shared + rookie's weapons")
	eq(ids.call(M.shop_items(c, "", "tanko")), ["normal_helmet_lv10", "normal_armor_lv40", "tanko_weapon_lv10"], "shared + tanko's weapons")
	eq(ids.call(M.shop_items(c, "weapon", "rookie")), ["rookie_weapon_lv20"], "slot filter: no retired, no other character's")
	eq(M.shop_items(c, "weapon", "flora"), [], "no weapon for flora in this catalog")
	eq(M.shop_items(null), [], "no catalog")
	eq(M.price(M.item_of(c, "normal_weapon_lv10")), {"currency": "coin", "amount": 500}, "coin price")
	eq(M.price(M.item_of(c, "normal_helmet_lv10")), {"currency": "gem", "amount": 30}, "gem when coin is 0")
	eq(M.confirm_text(M.item_of(c, "normal_armor_lv40")), "Mua Áo giáp Rồng với giá 8.000 xu?", "confirm")
	eq(M.confirm_text(M.item_of(c, "rookie_weapon_lv20")), "Mua Bazooka Thép với giá 1.500 xu?", "confirm gun")
	eq(M.confirm_text(M.item_of(c, "normal_helmet_lv10")), "Mua Mũ Sắt với giá 30 kim cương?", "confirm gem")


func test_item_of_piece_fallback() -> void:
	var it := M.item_of_piece(null, {"itemId": "crafted_boots_gold", "slot": "boots", "category": "crafted", "tier": "gold"})
	eq(it["slot"], "boots", "slot from the piece")
	eq(M.tier(it), "gold", "tier from the piece")
	eq(M.display_name(it), "Giày Vàng", "name from slot + tier")


func test_bonus_lines() -> void:
	var stats := {"fromEquipment": {"maxHp": 4000, "defense": 40, "damageBonus": 50, "moveEnergy": 0, "critChance": 2.25},
		"equipmentPoints": {"hp": 80, "damage": 10, "defense": 8, "mobility": 0, "crit": 2.25}}
	eq(M.bonus_lines(stats), ["Máu +80 điểm (+4.000)", "Sát thương +10 điểm (+50)", "Phòng thủ +8 điểm (+40)", "Chí mạng +2.3%"], "points and battle values")
	stats.erase("equipmentPoints")
	eq(M.bonus_lines(stats), ["Máu +4.000", "Sát thương +50", "Phòng thủ +40", "Chí mạng +2.3%"], "older server: battle values only")
	eq(M.bonus_lines({"fromEquipment": {"maxHp": 0}}), [], "nothing worn")
	eq(M.bonus_lines(null), [], "no stats")
