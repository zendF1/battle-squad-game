extends "res://tests/test_case.gd"

const ShopModel := preload("res://screens/home/shop_model.gd")

const OFFERS := [
	{"offerId": "o_medkit", "itemId": "medkit", "offerType": "item", "priceCurrency": "coin", "priceAmount": 300, "quantity": 3, "isActive": true},
	{"offerId": "o_flora_gem", "itemId": "flora", "offerType": "character_unlock", "priceCurrency": "gem", "priceAmount": 300, "quantity": 1, "limitPerPlayer": 1, "isActive": true},
	{"offerId": "o_tanko_coin", "itemId": "tanko", "offerType": "character_unlock", "priceCurrency": "coin", "priceAmount": 5000, "quantity": 1, "limitPerPlayer": 1, "isActive": true},
	{"offerId": "o_off", "itemId": "teleport", "offerType": "item", "priceCurrency": "coin", "priceAmount": 400, "quantity": 3, "isActive": false},
	{"offerId": "o_flora_coin", "itemId": "flora", "offerType": "character_unlock", "priceCurrency": "coin", "priceAmount": 5000, "quantity": 1, "limitPerPlayer": 1, "isActive": true},
	{"offerId": "o_ltd", "itemId": "air_strike", "offerType": "item", "priceCurrency": "gem", "priceAmount": 50, "quantity": 1, "limitPerPlayer": 3},
]


func test_parse_and_split() -> void:
	var offers := ShopModel.parse_offers(OFFERS)
	eq(offers.size(), 5, "inactive dropped")
	eq(ShopModel.parse_offers(null), [], "null is empty")
	var items := ShopModel.item_offers(offers)
	eq(items.map(func(o): return o["offerId"]), ["o_medkit", "o_ltd"], "items")
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
	eq(ShopModel.price_text(OFFERS[2]), "💰 5.000", "coin price")
	eq(ShopModel.price_text(OFFERS[1]), "💎 300", "gem price")
	eq(ShopModel.confirm_text(OFFERS[0]), "Hộp cứu thương x3 với giá 300 xu?", "item confirm")
	eq(ShopModel.confirm_text(OFFERS[1]), "Flora x1 với giá 300 kim cương?", "gem confirm")


func test_products() -> void:
	var products := ShopModel.parse_products([
		{"productId": "gems_550", "gemAmount": 500, "bonusGemAmount": 50, "priceUsd": 4.99, "isActive": true},
		{"productId": "gems_100", "gemAmount": 100, "bonusGemAmount": 0, "priceUsd": 0.99, "isActive": true},
		{"productId": "old", "gemAmount": 1, "isActive": false}])
	eq(products.size(), 2, "inactive dropped")
	eq(ShopModel.product_title(products[0]), "500 💎", "title")
	eq(ShopModel.product_bonus(products[0]), "+50 thưởng", "bonus")
	eq(ShopModel.product_bonus(products[1]), "", "no bonus")
	eq(ShopModel.product_price(products[0]), "$4.99", "price")
	eq(ShopModel.product_title({"gemAmount": 1200}), "1.200 💎", "thousands")


func test_iap_platform() -> void:
	eq(ShopModel.iap_platform("iOS"), "ios", "iOS")
	eq(ShopModel.iap_platform("Android"), "android", "Android")
	eq(ShopModel.iap_platform("macOS"), "android", "desktop tests as android")
