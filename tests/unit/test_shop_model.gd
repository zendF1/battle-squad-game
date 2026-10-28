extends "res://tests/test_case.gd"

const ShopModel := preload("res://screens/home/shop_model.gd")

const OFFERS := [
	{"offerId": "o_medkit", "itemId": "medkit", "offerType": "item", "priceCurrency": "coin", "priceAmount": 300, "quantity": 3, "isActive": true},
	{"offerId": "o_flora_gem", "itemId": "flora", "offerType": "character_unlock", "priceCurrency": "gem", "priceAmount": 300, "quantity": 1, "limitPerPlayer": 1, "isActive": true},
	{"offerId": "o_tanko_coin", "itemId": "tanko", "offerType": "character_unlock", "priceCurrency": "coin", "priceAmount": 5000, "quantity": 1, "limitPerPlayer": 1, "isActive": true},
	{"offerId": "o_off", "itemId": "teleport", "offerType": "item", "priceCurrency": "coin", "priceAmount": 400, "quantity": 3, "isActive": false},
	{"offerId": "o_flora_coin", "itemId": "flora", "offerType": "character_unlock", "priceCurrency": "coin", "priceAmount": 5000, "quantity": 1, "limitPerPlayer": 1, "isActive": true},
	{"offerId": "o_ltd", "itemId": "air_strike", "offerType": "item", "priceCurrency": "gem", "priceAmount": 50, "quantity": 1, "limitPerPlayer": 3},
	{"offerId": "coin_pack_50", "itemId": "coin", "offerType": "coin_pack", "priceCurrency": "gem", "priceAmount": 50, "quantity": 5000, "isActive": true},
	{"offerId": "coin_pack_10", "itemId": "coin", "offerType": "coin_pack", "priceCurrency": "gem", "priceAmount": 10, "quantity": 1000, "isActive": true},
	{"offerId": "coin_for_coin", "itemId": "coin", "offerType": "coin_pack", "priceCurrency": "coin", "priceAmount": 10, "quantity": 1000, "isActive": true},
]


func test_parse_and_split() -> void:
	var offers := ShopModel.parse_offers(OFFERS)
	eq(offers.size(), 8, "inactive dropped")
	eq(ShopModel.parse_offers(null), [], "null is empty")
	var items := ShopModel.item_offers(offers)
	eq(items.map(func(o): return o["offerId"]), ["o_medkit", "o_ltd"], "items (no coin packs)")
	eq(ShopModel.coin_packs(offers).map(func(o): return o["offerId"]), ["coin_pack_10", "coin_pack_50"], "gem-priced coin packs, cheapest first")
	eq(ShopModel.coin_packs(ShopModel.parse_offers(OFFERS.slice(0, 6))), [], "old server: no coin packs")
	var groups := ShopModel.character_groups(offers)
	eq(groups.map(func(g): return g["characterId"]), ["tanko", "flora"], "roster order")
	eq(groups[1]["offers"].map(func(o): return o["offerId"]), ["o_flora_gem", "o_flora_coin"], "both flora offers")
	eq(groups[1]["name"], "Flora", "name")


func test_remaining_limit() -> void:
	var purchases := ShopModel.parse_purchases([
		{"offerId": "o_ltd", "status": "completed"}, {"offerId": "o_ltd", "status": "refunded"},
		{"offerId": "o_ltd", "status": "completed"}, {"offerId": "o_medkit", "status": "completed"}, "junk"])
	eq(purchases.size(), 4, "junk dropped")
	eq(ShopModel.remaining(OFFERS[5], purchases), 1, "3 - 2 completed")
	eq(ShopModel.remaining(OFFERS[0], purchases), ShopModel.UNLIMITED, "no limit")
	eq(ShopModel.remaining(OFFERS[2], [{"offerId": "o_tanko_coin", "status": "completed"}, {"offerId": "o_tanko_coin", "status": "completed"}]), 0, "never below 0")
	eq(ShopModel.remaining_text(1), "Còn 1 lượt", "text")
	eq(ShopModel.remaining_text(0), "Đã hết lượt mua", "none left")
	eq(ShopModel.remaining_text(ShopModel.UNLIMITED), "", "unlimited")
	eq(ShopModel.parse_purchases(null), [], "null purchases")


func test_names_prices_confirm() -> void:
	eq(ShopModel.offer_name(OFFERS[0]), "Hộp cứu thương", "item label")
	eq(ShopModel.offer_name(OFFERS[2]), "Tanko", "character name")
	eq(ShopModel.price_text(OFFERS[2]), "5.000", "coin price")
	eq(ShopModel.currency_icon(str(OFFERS[2]["priceCurrency"])), "coin", "coin icon")
	eq(ShopModel.price_text(OFFERS[1]), "300", "gem price")
	eq(ShopModel.currency_icon(str(OFFERS[1]["priceCurrency"])), "gem", "gem icon")
	eq(ShopModel.confirm_text(OFFERS[0]), "Hộp cứu thương x3 với giá 300 xu?", "item confirm")
	eq(ShopModel.confirm_text(OFFERS[1]), "Flora x1 với giá 300 kim cương?", "gem confirm")


func test_products() -> void:
	var products := ShopModel.parse_products([
		{"productId": "gems_550", "gemAmount": 500, "bonusGemAmount": 50, "priceUsd": 4.99, "isActive": true},
		{"productId": "gems_100", "gemAmount": 100, "bonusGemAmount": 0, "priceUsd": 0.99, "isActive": true},
		{"productId": "old", "gemAmount": 1, "isActive": false}])
	eq(products.size(), 2, "inactive dropped")
	eq(ShopModel.product_title(products[0]), "500 kim cương", "title")
	eq(ShopModel.product_amount(products[0]), "500", "amount")
	eq(ShopModel.product_bonus(products[0]), "+50 thưởng", "bonus")
	eq(ShopModel.product_bonus(products[1]), "", "no bonus")
	eq(ShopModel.product_price(products[0]), "$4.99", "price")
	eq(ShopModel.product_title({"gemAmount": 1200}), "1.200 kim cương", "thousands")


func test_iap_platform() -> void:
	eq(ShopModel.iap_platform("iOS"), "ios", "iOS")
	eq(ShopModel.iap_platform("Android"), "android", "Android")
	eq(ShopModel.iap_platform("macOS"), "android", "desktop tests as android")


func test_coin_packs() -> void:
	var p10 := {"offerId": "coin_pack_10", "itemId": "coin", "offerType": "coin_pack", "priceCurrency": "gem", "priceAmount": 10, "quantity": 1000}
	var p500 := {"offerId": "coin_pack_500", "itemId": "coin", "offerType": "coin_pack", "priceCurrency": "gem", "priceAmount": 500, "quantity": 50000}
	var better := {"offerId": "x", "offerType": "coin_pack", "priceCurrency": "gem", "priceAmount": 50, "quantity": 5500}
	var odd := {"offerId": "y", "offerType": "coin_pack", "priceCurrency": "gem", "priceAmount": 3, "quantity": 359}
	var worse := {"offerId": "z", "offerType": "coin_pack", "priceCurrency": "gem", "priceAmount": 10, "quantity": 900}
	eq(ShopModel.coin_pack_bonus_percent(p10), 0, "base rate: no bonus")
	eq(ShopModel.coin_pack_bonus(p500), "", "base rate: no label")
	eq(ShopModel.coin_pack_bonus_percent(better), 10, "5500 for 50 = +10%")
	eq(ShopModel.coin_pack_bonus(better), "+10%", "label")
	eq(ShopModel.coin_pack_bonus_percent(odd), 19, "rounded down: 359 / 300 = +19.6%")
	eq(ShopModel.coin_pack_bonus_percent(worse), 0, "below the base rate: no bonus")
	eq(ShopModel.coin_pack_bonus_percent({"priceAmount": 0, "quantity": 10}), 0, "free pack: no division")
	eq(ShopModel.coin_pack_bonus_percent(p10, 20), 400, "other base rate")
	eq(ShopModel.coin_pack_amount(p500), "50.000", "amount")
	eq(ShopModel.offer_name(p10), "1.000 xu", "name")
	eq(ShopModel.confirm_text(p10), "Đổi 10 kim cương lấy 1.000 xu?", "confirm")
	eq(ShopModel.confirm_text(p500), "Đổi 500 kim cương lấy 50.000 xu?", "confirm thousands")
	eq(ShopModel.coin_pack_button(p10, 9, true), "Không đủ kim cương", "short")
	eq(ShopModel.coin_pack_button(p10, 10, true), "Đổi", "exact")
	eq(ShopModel.coin_pack_button(p10, 0, false), "Đổi", "wallet unknown: the server decides")
