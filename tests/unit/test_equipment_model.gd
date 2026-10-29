extends "res://tests/test_case.gd"

const M := preload("res://screens/home/equipment_model.gd")
const Art := preload("res://ui/art.gd")
const GameData := preload("res://autoload/game_data_model.gd")

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

const MULT := {"hp": 2, "damage": 5, "mobility": 1, "defense": 1, "skillPower": 1, "terrainDamage": 1} # server defaults

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
	eq(M.slots(), ["helmet", "armor", "gloves", "pants", "boots", "weapon"], "order (game data equipment.slots)")
	eq([M.slot_index("helmet"), M.slot_index("weapon"), M.slot_index("ring")], [0, 5, 6], "indexes; an unknown slot last")
	eq(M.slot_name("weapon"), "Vũ khí", "weapon")
	eq(M.slot_name("armor"), "Áo", "armor")
	eq(M.slot_name("helmet"), "Mũ", "helmet")
	eq(M.slot_name("pants"), "Quần", "pants")
	eq(M.slot_name("boots"), "Giày", "boots")
	eq(M.slot_name("gloves"), "Găng tay", "gloves")
	eq(M.slot_name("ring"), "ring", "unknown slot")


## The slot names and order, the item type words and the gun kinds are the game data's: an admin
## edit shows at once.
func test_texts_from_the_game_data() -> void:
	var d: Dictionary = GameData.data.duplicate(true)
	d["version"] = "edited"
	d["equipment"]["slots"] = [{"id": "weapon", "name": "Súng ống"}, {"id": "helmet", "name": "Nón"}]
	d["equipment"]["typeWords"].append({"word": "laser cannon", "name": "Pháo laze", "gunKind": "cannon"})
	d["equipment"]["typeWords"][0]["name"] = "Gươm"
	d["gunKinds"][1]["name"] = "Pháo"
	GameData.take(d, "", false)
	eq(M.slots(), ["weapon", "helmet"], "the game data's order")
	eq([M.slot_name("weapon"), M.slot_name("helmet"), M.slot_name("boots")], ["Súng ống", "Nón", "boots"], "its names; a slot it lacks raw")
	eq([M.display_name({"name": "Iron Sword"}), M.display_name({"name": "Gold Laser Cannon"})], ["Gươm Sắt", "Pháo laze Vàng"], "its type words")
	eq(M.weapon_kind({"slot": "weapon", "name": "Gold Laser Cannon"}), "cannon", "a new type word's gun kind")
	eq(M.gun_name("cannon"), "Pháo", "its gun kind names")


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
	# Iron Cap: +20 HP points = 20 × 2 HP.
	eq(M.stat_summary(M.item_of(c, "normal_helmet_lv10"), MULT), "Máu +20 điểm (+40) · Phòng thủ +2 điểm (+2)", "points and converted")
	eq(M.stat_summary(M.item_of(c, "normal_boots_lv20"), MULT), "Máu +20 điểm (+40) · Phòng thủ +2 điểm (+2) · Di chuyển +10 điểm (+10)", "move energy × mobility")
	eq(M.stat_summary({"statHp": 3020, "statDamage": 347}, MULT), "Máu +3.020 điểm (+6.040) · Sát thương +347 điểm (+1.735)", "thousands separator")
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
	eq(armor.map(func(d): return d["text"]), ["−300 (−150 điểm)", "−15 (−15 điểm)"], "removing a piece")
	eq(M.compare({"statHp": 3020}, {"statHp": 435}, MULT).map(func(d): return d["text"]), ["+5.170 (+2.585 điểm)"], "thousands separator")
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
	# Full Diamond +16 with the set: points × the server defaults (hp 2, damage 5, defense 1).
	var stats := {"fromEquipment": {"maxHp": 6040, "defense": 298, "damageBonus": 1735, "moveEnergy": 0, "critChance": 2.25},
		"equipmentPoints": {"hp": 3020, "damage": 347, "defense": 298, "mobility": 0, "crit": 2.25}}
	eq(M.bonus_lines(stats), ["Máu +3.020 điểm (+6.040)", "Sát thương +347 điểm (+1.735)", "Phòng thủ +298 điểm (+298)", "Chí mạng +2.3%"], "points and battle values")
	stats.erase("equipmentPoints")
	eq(M.bonus_lines(stats), ["Máu +6.040", "Sát thương +1.735", "Phòng thủ +298", "Chí mạng +2.3%"], "older server: battle values only")
	eq(M.bonus_lines({"fromEquipment": {"maxHp": 0}}), [], "nothing worn")
	eq(M.bonus_lines(null), [], "no stats")


func test_bonus_chips() -> void:
	var stats := {"fromEquipment": {"maxHp": 1232, "defense": 58, "damageBonus": 635, "moveEnergy": 20, "critChance": 17.1},
		"equipmentPoints": {"hp": 616, "damage": 127, "defense": 58, "mobility": 20, "crit": 17.1}}
	var chips := M.bonus_chips(stats)
	eq(chips.map(func(c): return c["glyph"]), ["heart", "sword", "shield", "crit", "boot"], "a picture per stat, in order")
	eq(chips.map(func(c): return c["value"]), ["+1.232", "+635", "+58", "+17.1%", "+20"], "the battle values")
	eq(chips[0]["line"], "Máu +616 điểm (+1.232)", "the words for the tooltip")
	eq(chips.map(func(c): return c["key"]), ["maxHp", "damageBonus", "defense", "critChance", "moveEnergy"], "the battle stat keys")
	eq(M.bonus_chips({"fromEquipment": {"maxHp": 0}}), [], "nothing worn")
	eq(M.bonus_chips(null), [], "no stats")


func test_gun_of_weapon_items() -> void:
	eq(M.gun("rookie_weapon_lv30"), {"kind": "bazooka", "tier": "mithril"}, "rookie lv30")
	eq(M.gun("tanko_weapon_lv10"), {"kind": "cannon", "tier": "iron"}, "tanko lv10")
	eq(M.gun("spark_weapon_lv40"), {"kind": "shock_rifle", "tier": "dragon"}, "spark lv40")
	eq(M.gun("flora_weapon_lv20"), {"kind": "seed_launcher", "tier": "steel"}, "flora lv20")
	eq(M.gun("crafted_weapon_gold"), {"kind": "blaster", "tier": "gold"}, "crafted gold")
	eq(M.gun("crafted_weapon_diamond"), {"kind": "blaster", "tier": "diamond"}, "crafted diamond")
	eq(M.gun("normal_weapon_lv10"), {"kind": "blaster", "tier": "iron"}, "generic lv10")
	eq(M.gun("", {}, "tanko"), {"kind": "cannon", "tier": "basic"}, "no weapon: the character's basic gun")
	eq(M.gun("", {}, "nope"), {"kind": "bazooka", "tier": "basic"}, "no weapon, unknown character")
	var item := {"itemId": "x", "slot": "weapon", "name": "Steel Seed Launcher", "category": "normal"}
	eq(M.gun("x", item), {"kind": "seed_launcher", "tier": "steel"}, "catalog entry by name")
	item = {"itemId": "y", "slot": "weapon", "name": "Titan Blaster", "category": "crafted", "tier": "titan"}
	eq(M.gun("y", item, "spark"), {"kind": "blaster", "tier": "titan"}, "catalog crafted entry")
	# Every weapon id the server seeds maps to a baked gun.
	var ids := ["normal_weapon_lv10", "normal_weapon_lv40", "crafted_weapon_silver", "crafted_weapon_titan"]
	for ch in ["rookie", "tanko", "spark", "flora"]:
		for lv in [10, 20, 30, 40]:
			ids.append("%s_weapon_lv%d" % [ch, lv])
	for id in ids:
		var g := M.gun(id)
		check(Art.GUN_KINDS.has(g["kind"]) and Art.GUN_TIERS[g["kind"]].has(g["tier"]), "%s → %s has a sprite" % [id, g])


func test_worn_gun() -> void:
	var owned := [
		{"equipmentId": "a", "itemId": "rookie_weapon_lv40", "slot": "weapon", "isEquipped": true, "equippedOn": "rookie"},
		{"equipmentId": "b", "itemId": "normal_helmet_lv10", "slot": "helmet", "isEquipped": true, "equippedOn": "tanko"},
		{"equipmentId": "c", "itemId": "crafted_weapon_gold", "slot": "weapon", "category": "crafted", "tier": "gold", "isEquipped": false},
	]
	eq(M.worn_gun(owned, null, "rookie"), {"kind": "bazooka", "tier": "dragon"}, "rookie wears a Dragon Bazooka")
	eq(M.worn_gun(owned, null, "tanko"), {"kind": "cannon", "tier": "basic"}, "tanko wears no weapon")
	eq(M.worn_gun(null, null, "spark"), {"kind": "shock_rifle", "tier": "basic"}, "pieces not loaded")
	owned[2]["isEquipped"] = true
	owned[2]["equippedOn"] = "tanko"
	eq(M.worn_gun(owned, null, "tanko"), {"kind": "blaster", "tier": "gold"}, "moved to tanko")


func test_gun_names_and_player_gun() -> void:
	for kind in preload("res://ui/art.gd").GUN_KINDS:
		check(GameData.gun_kind_name(kind) != "", "gun %s has a name (game data gunKinds)" % kind)
	eq([M.gun_name("cannon"), M.gun_name("shock_rifle"), M.gun_name("laser_gun")], ["Đại pháo", "Súng điện", "Súng"], "gun names; an unknown kind: the blaster's")
	eq(M.player_gun({"characterId": "flora", "weaponItemId": "crafted_weapon_titan"}), {"kind": "blaster", "tier": "titan"}, "match player's weapon")
	eq(M.player_gun({"characterId": "flora", "weaponItemId": null}), {"kind": "seed_launcher", "tier": "basic"}, "bot: basic gun")
	eq(M.player_gun({"characterId": "spark"}), {"kind": "shock_rifle", "tier": "basic"}, "no weaponItemId")


func test_sell_rate_parsing() -> void:
	eq(M.parse_catalog(CATALOG)["sellRate"], 0.25, "missing sellRate (older server) → 0.25")
	var with_rate := CATALOG.duplicate()
	with_rate["sellRate"] = 0.4
	eq(M.parse_catalog(with_rate)["sellRate"], 0.4, "server rate kept")
	with_rate["sellRate"] = 1
	eq(M.parse_catalog(with_rate)["sellRate"], 1.0, "1 (int) is allowed")
	for bad in [0, 0.0, -0.5, 1.5, "0.3", null]:
		eq(M.parse_sell_rate(bad), 0.25, "invalid %s → 0.25" % str(bad))


func test_sell_price() -> void:
	var c = M.parse_catalog(CATALOG)
	eq(M.sell_price(M.item_of(c, "normal_armor_lv40"), c), {"currency": "coin", "amount": 2000}, "8000 × 0.25")
	eq(M.sell_price(M.item_of(c, "rookie_weapon_lv20"), c), {"currency": "coin", "amount": 375}, "1500 × 0.25")
	eq(M.sell_price({"priceCoin": 250}, c), {"currency": "coin", "amount": 62}, "62.5 rounds down")
	eq(M.sell_price({"priceCoin": 3}, c), {"currency": "coin", "amount": 0}, "0.75 rounds down to 0: not sellable")
	eq(M.sell_price(M.item_of(c, "normal_helmet_lv10"), c), {"currency": "gem", "amount": 7}, "gem-priced: 30 × 0.25 = 7.5 → 7 gem")
	eq(M.sell_price(M.item_of(c, "crafted_gloves_diamond"), c)["amount"], 0, "crafted costs nothing: 0")
	eq(M.sell_price(M.item_of_piece(c, {"itemId": "gone", "slot": "armor"}), c)["amount"], 0, "unknown item: 0")
	var rated := CATALOG.duplicate()
	rated["sellRate"] = 0.3
	eq(M.sell_price({"priceCoin": 1001}, M.parse_catalog(rated)), {"currency": "coin", "amount": 300}, "300.3 rounds down")
	rated["sellRate"] = 0.29
	eq(M.sell_price({"priceCoin": 100}, M.parse_catalog(rated))["amount"], 29, "float error does not drop a coin (server adds 1e-9 too)")
	eq(M.sell_price({"priceCoin": 1000}, null), {"currency": "coin", "amount": 250}, "no catalog: the default rate")
	eq(M.amount_text({"currency": "coin", "amount": 2500}), "2.500 xu", "coin text")
	eq(M.amount_text({"currency": "gem", "amount": 7}), "7 kim cương", "gem text")


func test_labels_have_no_level() -> void:
	var catalog := {"items": {"normal_armor_lv10": {"itemId": "normal_armor_lv10", "slot": "armor", "name": "Iron Vest", "statHp": 100.0}}}
	var piece := {"equipmentId": "a", "itemId": "normal_armor_lv10", "slot": "armor", "upgradeLevel": 10}
	var tip := M.piece_tooltip(catalog, piece)
	eq(tip.get_slice("\n", 0), "Áo giáp Sắt", "Prep tooltip: the name, no +N")
	check(not tip.contains("+10"), "no +N in the tooltip")
	check(tip.get_slice("\n", 1).begins_with("Máu +150 điểm"), "upgraded stats under it")
	eq(M.category_name({"category": "crafted"}), "Chế tạo", "crafted")
	eq(M.category_name({"category": "normal"}), "Thường", "normal")
	eq(M.category_name({}), "Thường", "no category")
