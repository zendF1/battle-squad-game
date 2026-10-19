extends "res://tests/test_case.gd"

const Model := preload("res://screens/home/character_shop_model.gd")
const ShopModel := preload("res://screens/home/shop_model.gd")
const Art := preload("res://ui/art.gd")

const OFFERS := [
	{"offerId": "unlock_tanko_coin", "itemId": "tanko", "offerType": "character_unlock", "priceCurrency": "coin", "priceAmount": 5000, "quantity": 1, "limitPerPlayer": 1},
	{"offerId": "unlock_tanko_gem", "itemId": "tanko", "offerType": "character_unlock", "priceCurrency": "gem", "priceAmount": 300, "quantity": 1, "limitPerPlayer": 1},
	{"offerId": "unlock_spark_gem", "itemId": "spark", "offerType": "character_unlock", "priceCurrency": "gem", "priceAmount": 300, "quantity": 1, "limitPerPlayer": 1},
	{"offerId": "medkit", "itemId": "flora", "offerType": "item", "priceCurrency": "coin", "priceAmount": 10, "quantity": 1},
]

## The server's baseStats (configs/characters.yaml + weapons.yaml after the big-number balance).
const DATA := {"characters": [], "baseStats": {
	"rookie": {"maxHp": 1500, "defense": 50, "damageBonus": 0, "moveEnergy": 100, "skillPowerBonus": 0, "terrainDamageBonus": 0, "weaponDamage": 480},
	"tanko": {"maxHp": 1950, "defense": 80, "damageBonus": 0, "moveEnergy": 100, "skillPowerBonus": 0, "terrainDamageBonus": 0, "weaponDamage": 600},
	"spark": {"maxHp": 1350, "defense": 40, "damageBonus": 0, "moveEnergy": 100, "skillPowerBonus": 0, "terrainDamageBonus": 0, "weaponDamage": 440},
	"flora": {"maxHp": 1425.0, "defense": 50.0, "damageBonus": 0.0, "moveEnergy": 100.0, "skillPowerBonus": 0.0, "terrainDamageBonus": 0.0, "weaponDamage": 360.0},
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
	near(Model.bar_ratio(1500, 1950), 1500.0 / 1950.0, 0.0001, "against the max")
	eq(Model.bar_ratio(1950, 1950), 1.0, "the max is full")
	eq(Model.bar_ratio(5, 0), 0.0, "no max")
	eq(Model.bar_ratio(-3, 10), 0.0, "never negative")


func test_stat_rows() -> void:
	var rows := Model.stat_rows(DATA, "tanko")
	eq(rows.map(func(r): return r["key"]), ["maxHp", "weaponDamage", "defense", "moveEnergy", "explosionRadius"], "rows")
	eq(rows.map(func(r): return r["value"]), [1950, 600, 80, 100, 50], "tanko's server numbers")
	eq(rows.map(func(r): return r["ratio"]), [1.0, 1.0, 1.0, 1.0, 1.0], "tanko tops every stat")
	eq(rows[0]["text"], "1.950", "thousands")
	var spark := Model.stat_rows(DATA, "spark")
	near(spark[0]["ratio"], 1350.0 / 1950.0, 0.0001, "hp against tanko")
	near(spark[1]["ratio"], 440.0 / 600.0, 0.0001, "damage against tanko")
	near(spark[2]["ratio"], 40.0 / 80.0, 0.0001, "defense against tanko")
	near(spark[4]["ratio"], 35.0 / 50.0, 0.0001, "radius against tanko")
	eq(Model.stat_rows(DATA, "flora")[0]["value"], 1425, "json floats as ints")
	eq(Model.stat_rows({"characters": []}, "tanko"), [], "no baseStats: nothing")
	eq(Model.stat_rows(null, "tanko"), [], "not loaded")


func test_data_for_every_character() -> void:
	eq(Model.ids(), ["rookie", "tanko", "spark", "flora"], "roster order")
	for id in Model.ids():
		var info := Model.info(id)
		check(info["name"] != id and info["role"] != "", "%s name and role" % id)
		check(Model.TINTS.has(id), "%s tint" % id)
		check(Model.WEAPONS.has(id), "%s weapon" % id)
		eq(info["weapon"]["kind"], Art.CHARACTER_GUNS[id], "%s gun kind" % id)
		check(info["weapon"]["name"] != "", "%s weapon name" % id)
		check(info["skill"]["name"] != "" and info["skill"]["text"] != "", "%s skill" % id)
		check(str(info["playstyle"]).length() > 60, "%s playstyle" % id)
		eq(Model.stat_rows(DATA, id).size(), 5, "%s stats" % id)
		check(Art.hug_gun(info["weapon"]["kind"], info["weapon"]["tier"])["hug"], "%s hug art" % id)
	eq(Model.info("tanko")["role"], "Pháo thủ hạng nặng", "role")
	eq(Model.info("tanko")["weapon"]["name"], "Đại pháo", "weapon name")
	eq(Model.info("tanko")["weapon"]["wind"], "Gió đẩy ×0,3", "heavy shot")
	eq(Model.info("spark")["weapon"]["wind"], "Gió đẩy ×1,5", "light shot")
	eq(Model.info("rookie")["skill"]["energy"], "Cần 100 năng lượng (+20 mỗi lượt)", "energy")
	eq(Model.tint("nobody"), Model.NEUTRAL_TINT, "unknown: neutral")
