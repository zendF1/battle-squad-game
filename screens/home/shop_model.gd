extends RefCounted
## Shop data as the Shop tab shows it: GET /shop/offers split into items and character unlocks,
## the per-player limit left from GET /shop/purchases, prices and confirm texts, GET /iap/products
## labels and the IAP platform.

const Fmt := preload("res://core/fmt.gd")
const Items := preload("res://match/items.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")

const CHARACTER_UNLOCK := "character_unlock"
const UNLIMITED := -1


## Active offers from the GET /shop/offers data (a bare array; null when empty).
static func parse_offers(data: Variant) -> Array:
	var out: Array = []
	if not data is Array:
		return out
	for o in data:
		if o is Dictionary and str(o.get("offerId", "")) != "" and o.get("isActive", true) != false:
			out.append(o)
	return out


## Item and bundle offers, in the server's order.
static func item_offers(offers: Array) -> Array:
	return offers.filter(func(o): return str(o.get("offerType", "")) != CHARACTER_UNLOCK)


## Character unlock offers grouped per character, known characters first in roster order:
## [{characterId, name, offers: [...]}].
static func character_groups(offers: Array) -> Array:
	var by_id := {}
	var order: Array = []
	for o in offers:
		if str(o.get("offerType", "")) != CHARACTER_UNLOCK:
			continue
		var id := str(o.get("itemId", ""))
		if not by_id.has(id):
			by_id[id] = []
			order.append(id)
		by_id[id].append(o)
	var out: Array = []
	for c in LoadoutModel.CHARACTERS:
		if by_id.has(c["id"]):
			out.append({"characterId": c["id"], "name": c["name"], "offers": by_id[c["id"]]})
			order.erase(c["id"])
	for id in order:
		out.append({"characterId": id, "name": id, "offers": by_id[id]})
	return out


## Purchases from the GET /shop/purchases data.
static func parse_purchases(data: Variant) -> Array:
	return (data as Array).filter(func(p): return p is Dictionary) if data is Array else []


## How many more times this player may buy the offer: limitPerPlayer minus completed purchases
## of it, or UNLIMITED without a limit.
static func remaining(offer: Dictionary, purchases: Array) -> int:
	var limit = offer.get("limitPerPlayer")
	if limit == null:
		return UNLIMITED
	var used := 0
	for p in purchases:
		if str(p.get("offerId", "")) == str(offer.get("offerId", "")) and str(p.get("status", "completed")) == "completed":
			used += 1
	return maxi(int(limit) - used, 0)


## "Còn 2 lượt", "Đã hết lượt mua", or "" without a limit.
static func remaining_text(n: int) -> String:
	if n == UNLIMITED:
		return ""
	return "Còn %d lượt" % n if n > 0 else "Đã hết lượt mua"


static func offer_name(offer: Dictionary) -> String:
	var id := str(offer.get("itemId", ""))
	if str(offer.get("offerType", "")) == CHARACTER_UNLOCK:
		for c in LoadoutModel.CHARACTERS:
			if c["id"] == id:
				return c["name"]
		return id
	return Items.label(id)


static func currency_word(currency: String) -> String:
	return "kim cương" if currency == "gem" else "xu"


static func currency_icon(currency: String) -> String:
	return "💎" if currency == "gem" else "💰"


## "💰 300", "💎 1.000".
static func price_text(offer: Dictionary) -> String:
	return "%s %s" % [currency_icon(str(offer.get("priceCurrency", ""))), Fmt.thousands(int(offer.get("priceAmount", 0)))]


## "Hộp cứu thương x3 với giá 300 xu?"
static func confirm_text(offer: Dictionary) -> String:
	return "%s x%d với giá %s %s?" % [offer_name(offer), maxi(int(offer.get("quantity", 1)), 1),
		Fmt.thousands(int(offer.get("priceAmount", 0))), currency_word(str(offer.get("priceCurrency", "")))]


## Active products from the GET /iap/products data.
static func parse_products(data: Variant) -> Array:
	var out: Array = []
	if not data is Array:
		return out
	for p in data:
		if p is Dictionary and str(p.get("productId", "")) != "" and p.get("isActive", true) != false:
			out.append(p)
	return out


## "100 💎"
static func product_title(p: Dictionary) -> String:
	return "%s 💎" % Fmt.thousands(int(p.get("gemAmount", 0)))


## "+50 thưởng", or "" without a bonus.
static func product_bonus(p: Dictionary) -> String:
	var bonus := int(p.get("bonusGemAmount", 0))
	return "+%s thưởng" % Fmt.thousands(bonus) if bonus > 0 else ""


## "$4.99"
static func product_price(p: Dictionary) -> String:
	return "$%.2f" % float(p.get("priceUsd", 0.0))


## The POST /iap/verify platform for OS.get_name(): ios on iOS, android elsewhere (desktop
## builds test against the mock store as android).
static func iap_platform(os_name: String) -> String:
	return "ios" if os_name == "iOS" else "android"
