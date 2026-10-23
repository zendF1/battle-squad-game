extends "res://tests/test_case.gd"

const Model := preload("res://screens/home/character_shop_model.gd")
const ShopModel := preload("res://screens/home/shop_model.gd")
const Art := preload("res://ui/art.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const OFFERS := [
	{"offerId": "unlock_tanko_coin", "itemId": "tanko", "offerType": "character_unlock", "priceCurrency": "coin", "priceAmount": 5000, "quantity": 1, "limitPerPlayer": 1},
	{"offerId": "unlock_tanko_gem", "itemId": "tanko", "offerType": "character_unlock", "priceCurrency": "gem", "priceAmount": 300, "quantity": 1, "limitPerPlayer": 1},
	{"offerId": "unlock_spark_gem", "itemId": "spark", "offerType": "character_unlock", "priceCurrency": "gem", "priceAmount": 300, "quantity": 1, "limitPerPlayer": 1},
	{"offerId": "medkit", "itemId": "flora", "offerType": "item", "priceCurrency": "coin", "priceAmount": 10, "quantity": 1},
]

## The server's baseStats (configs/characters.yaml + weapons.yaml after the character identities).
const DATA := {"characters": [], "baseStats": {
	"rookie": {"maxHp": 1500, "defense": 50, "damageBonus": 0, "moveEnergy": 100, "skillPowerBonus": 0, "terrainDamageBonus": 0, "weaponDamage": 480},
	"tanko": {"maxHp": 1650, "defense": 60, "damageBonus": 0, "moveEnergy": 80, "skillPowerBonus": 0, "terrainDamageBonus": 0, "weaponDamage": 420},
	"spark": {"maxHp": 1250, "defense": 30, "damageBonus": 0, "moveEnergy": 120, "skillPowerBonus": 0, "terrainDamageBonus": 0, "weaponDamage": 620},
	"flora": {"maxHp": 1900.0, "defense": 90.0, "damageBonus": 0.0, "moveEnergy": 100.0, "skillPowerBonus": 0.0, "terrainDamageBonus": 0.0, "weaponDamage": 380.0},
}}


func test_card_states() -> void:
	var owned := ["rookie", "spark"]
	eq(Model.card("rookie", null, null, null)["state"], Model.OWNED, "rookie owned by default, even unloaded")
	eq(Model.card("spark", OFFERS, [], owned)["state"], Model.OWNED, "owned beats an offer")
	var t := Model.card("tanko", OFFERS, [], owned)
	eq(t["state"], Model.BUY, "tanko on sale")
	eq(t["offers"].map(func(o): return o["offerId"]), ["unlock_tanko_coin", "unlock_tanko_gem"], "both offers, server order")
	eq(Model.card("flora", OFFERS, [], owned)["state"], Model.NOT_FOR_SALE, "an item offer is not an unlock")
	eq(Model.card("tanko", null, [], owned)["state"], Model.UNKNOWN, "offers not loaded")
	eq(Model.card("tanko", OFFERS, [], null)["state"], Model.UNKNOWN, "ownership not loaded")
	var used := Model.card("tanko", OFFERS, [{"offerId": "unlock_tanko_coin", "status": "completed"}], owned)
	eq(used["offers"].map(func(o): return o["offerId"]), ["unlock_tanko_gem"], "limit used up: dropped")
	eq(Model.card("tanko", OFFERS, null, owned)["offers"].size(), 2, "purchases unknown: no limit counted")
	var spent := [{"offerId": "unlock_tanko_coin", "status": "completed"}, {"offerId": "unlock_tanko_gem", "status": "completed"}]
	eq(Model.card("tanko", OFFERS, spent, owned)["state"], Model.NOT_FOR_SALE, "every offer used up")


func test_buy_button() -> void:
	var owned := ["rookie"]
	eq(Model.buy_button(Model.card("rookie", OFFERS, [], owned)), {"text": "Đã sở hữu", "icon": "", "enabled": false}, "owned")
	eq(Model.buy_button(Model.card("flora", OFFERS, [], owned)), {"text": "Chưa mở bán", "icon": "", "enabled": false}, "not for sale")
	eq(Model.buy_button(Model.card("tanko", OFFERS, [], owned)), {"text": "5.000", "icon": "coin", "enabled": true}, "first price")
	eq(Model.buy_button(Model.card("spark", OFFERS, [], owned)), {"text": "300", "icon": "gem", "enabled": true}, "gem price")
	eq(Model.buy_button(Model.card("tanko", null, [], owned))["enabled"], false, "unknown: disabled")
	eq(Model.other_prices(Model.card("tanko", OFFERS, [], owned)), [{"text": "300", "icon": "gem"}], "the other price")
	eq(Model.other_prices(Model.card("spark", OFFERS, [], owned)), [], "one offer: none")
	eq(Model.other_prices(Model.card("rookie", OFFERS, [], owned)), [], "owned: none")


func test_bar_ratio() -> void:
	near(Model.bar_ratio(1500, 1900), 1500.0 / 1900.0, 0.0001, "against the max")
	eq(Model.bar_ratio(1950, 1950), 1.0, "the max is full")
	eq(Model.bar_ratio(5, 0), 0.0, "no max")
	eq(Model.bar_ratio(-3, 10), 0.0, "never negative")


func test_stat_rows() -> void:
	var rows := Model.stat_rows(DATA, "tanko")
	eq(rows.map(func(r): return r["key"]), ["maxHp", "weaponDamage", "defense", "moveEnergy", "explosionRadius", "craterRadius"], "rows")
	eq(rows.map(func(r): return r["value"]), [1650, 420, 60, 80, 60, 18], "tanko's server numbers")
	eq(rows[0]["text"], "1.650", "thousands")
	# Every bar is normalised to the best character at that stat
	near(rows[0]["ratio"], 1650.0 / 1900.0, 0.0001, "hp against flora")
	near(rows[1]["ratio"], 420.0 / 620.0, 0.0001, "damage against spark")
	near(rows[2]["ratio"], 60.0 / 90.0, 0.0001, "defense against flora")
	near(rows[3]["ratio"], 80.0 / 120.0, 0.0001, "move energy against spark")
	eq(rows[4]["ratio"], 1.0, "tanko has the widest blast")
	eq(rows[5]["ratio"], 1.0, "tanko digs the most")
	var spark := Model.stat_rows(DATA, "spark")
	eq(spark.map(func(r): return r["value"]), [1250, 620, 30, 120, 30, 12], "spark's server numbers")
	eq(spark[1]["ratio"], 1.0, "spark hits hardest")
	eq(spark[3]["ratio"], 1.0, "spark moves furthest")
	near(spark[5]["ratio"], 12.0 / 18.0, 0.0001, "crater against tanko")
	var flora := Model.stat_rows(DATA, "flora")
	eq(flora[0]["value"], 1900, "json floats as ints")
	eq([flora[0]["ratio"], flora[2]["ratio"]], [1.0, 1.0], "flora has the most hp and defense")
	eq(Model.stat_rows({"characters": []}, "tanko"), [], "no baseStats: nothing")
	eq(Model.stat_rows(null, "tanko"), [], "not loaded")


func test_crater_radius() -> void:
	eq(Model.ids().map(func(id): return Model.crater_radius(id)), [12, 18, 12, 14], "terrain damage × 0.6")
	eq(Model.crater_radius("nobody"), 0, "unknown")


## An admin edit of the game data shows in the shop with no client change: a new character with
## its own weapon and skill, a weapon's crater and wind.
func test_follows_the_game_data() -> void:
	var d: Dictionary = GameData.data.duplicate(true)
	d["version"] = "edited"
	d["weapons"][1]["craterRadius"] = 21.6
	d["weapons"][1]["windInfluence"] = 1.0
	d["characters"].append({"characterId": "nova", "name": "Nova", "role": "striker", "roleName": "Bắn tỉa", "playstyle": "Bắn xa.",
		"weaponId": "electric_orb", "skillId": "nova_beam", "gunKind": "", "hp": 1000})
	d["skills"].append({"skillId": "nova_beam", "characterId": "nova", "name": "Tia sao", "description": "Gây {firstPct}% sát thương.",
		"effectType": "laser", "aimKind": "line", "params": {}, "ranks": [{"rank": 0, "values": {"firstPct": 99}}]})
	GameData.take(d, "", false)
	eq(Model.crater_radius("tanko"), 22, "the crater rounded for display")
	eq(Model.info("tanko")["weapon"]["wind"], "Gió đẩy ×0,7", "the wind")
	eq(Model.ids()[-1], "nova", "a new character is listed")
	var nova := Model.info("nova")
	eq([nova["name"], nova["role"], nova["playstyle"]], ["Nova", "Bắn tỉa", "Bắn xa."], "its texts")
	eq(nova["weapon"]["kind"], Art.DEFAULT_GUN_KIND, "no gun kind: the generic gun")
	eq([nova["skill"]["name"], nova["skill"]["text"]], ["Tia sao", "Gây 99% sát thương."], "its skill")
	eq(Model.stat_value(DATA, "nova", "craterRadius"), 12, "its weapon's crater")


func test_data_for_every_character() -> void:
	eq(Model.ids(), ["rookie", "tanko", "spark", "flora"], "roster order")
	for id in Model.ids():
		var info := Model.info(id)
		check(info["name"] != id and info["role"] != "", "%s name and role" % id)
		check(Model.TINTS.has(id), "%s tint" % id)
		check(not GameData.weapon_of_character(id).is_empty(), "%s weapon" % id)
		eq(info["weapon"]["kind"], Art.character_gun(id), "%s gun kind" % id)
		check(info["weapon"]["name"] != "", "%s weapon name" % id)
		check(info["skill"]["name"] != "" and info["skill"]["text"] != "", "%s skill" % id)
		check(str(info["playstyle"]).length() > 60, "%s playstyle" % id)
		eq(Model.stat_rows(DATA, id).size(), 6, "%s stats" % id)
		var words := str(info["playstyle"]).replace(info["skill"]["name"], "") # a skill name is not a number
		check(RegEx.create_from_string("[0-9]").search(words) == null, "%s playstyle has no numbers" % id)
		check(Art.hug_gun(info["weapon"]["kind"], info["weapon"]["tier"])["hug"], "%s hug art" % id)
	eq(Model.ids().map(func(id): return Model.info(id)["role"]), ["Cân bằng", "Phá địa hình", "Sát thương", "Bền bỉ"], "roles")
	eq(Model.info("tanko")["weapon"]["name"], "Đại pháo", "weapon name")
	eq(Model.info("tanko")["weapon"]["wind"], "Gió đẩy ×0,3", "heavy shot")
	eq(Model.info("spark")["weapon"]["wind"], "Gió đẩy ×1,6", "light shot")
	eq(Model.info("tanko")["skill"]["name"], "Địa chấn liên hoàn", "bomb chain: the earth rework's name")
	check(Model.info("tanko")["skill"]["text"].contains("2 tảng") and Model.info("tanko")["skill"]["text"].contains("+1 mỗi cấp súng"),
		"bomb chain at rank 0: 2 bombs, +1 per gun rank")
	eq(Model.info("rookie")["skill"]["energy"], "Cần 100 năng lượng (+20 mỗi lượt, +10 khi bị trúng đòn)", "energy")
	eq(Model.tint("nobody"), Model.NEUTRAL_TINT, "unknown: neutral")
