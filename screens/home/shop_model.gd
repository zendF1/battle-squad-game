extends RefCounted
## Shop data as the Shop tab shows it: GET /shop/offers split into items, character unlocks and
## coin packs (đổi kim cương ra xu), the per-player limit left from GET /shop/purchases, prices
## and confirm texts, GET /iap/products labels and the IAP platform.

const Fmt := preload("res://core/fmt.gd")
const Items := preload("res://match/items.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const CHARACTER_UNLOCK := "character_unlock"
const COIN_PACK := "coin_pack" # itemId "coin", paid in gem, grants `quantity` coin
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
	return offers.filter(func(o): return not (str(o.get("offerType", "")) in [CHARACTER_UNLOCK, COIN_PACK]))


## Coin packs paid in gem (the only kind the server sells), cheapest first.
static func coin_packs(offers: Array) -> Array:
	var out := offers.filter(_sellable_coin_pack)
	out.sort_custom(func(a, b): return int(a["priceAmount"]) < int(b["priceAmount"]))
	return out


static func _sellable_coin_pack(o: Dictionary) -> bool:
	return is_coin_pack(o) and str(o.get("priceCurrency", "")) == "gem" and int(o.get("priceAmount", 0)) > 0 and int(o.get("quantity", 0)) > 0


static func is_coin_pack(offer: Dictionary) -> bool:
	return str(offer.get("offerType", "")) == COIN_PACK


## Whole percent of extra coin over the base rate (the game data's economy.coinsPerGem; -1 reads
## it), rounded down, 0 at or below the base rate.
static func coin_pack_bonus_percent(offer: Dictionary, coins_per_gem: int = -1) -> int:
	var rate := coins_per_gem if coins_per_gem >= 0 else GameData.coins_per_gem()
	var base := int(offer.get("priceAmount", 0)) * rate
	if base <= 0:
		return 0
	return maxi(int(offer.get("quantity", 0)) * 100 / base - 100, 0)


## "+10%", or "" without a bonus.
static func coin_pack_bonus(offer: Dictionary) -> String:
	var pct := coin_pack_bonus_percent(offer)
	return "+%d%%" % pct if pct > 0 else ""


## "1.000": the coin a pack grants (shown with the coin icon).
static func coin_pack_amount(offer: Dictionary) -> String:
	return Fmt.thousands(int(offer.get("quantity", 0)))


## Whether `gem` pays for the pack.
static func can_afford(offer: Dictionary, gem: int) -> bool:
	return gem >= int(offer.get("priceAmount", 0))


## The coin pack card's button: "Đổi", or "Không đủ kim cương" when the known wallet is short.
static func coin_pack_button(offer: Dictionary, gem: int, wallet_known: bool) -> String:
	return "Không đủ kim cương" if wallet_known and not can_afford(offer, gem) else "Đổi"


## "Đổi thành công! +1.000 xu": granted is the answer's quantityGranted (the offer's quantity
## when the answer has none).
static func coin_pack_success(offer: Dictionary, data: Variant) -> String:
	var granted := int(offer.get("quantity", 0))
	if data is Dictionary and int(data.get("quantityGranted", 0)) > 0:
		granted = int(data["quantityGranted"])
	return "Đổi thành công! +%s xu" % Fmt.thousands(granted)


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
	for cid in LoadoutModel.character_ids():
		if by_id.has(cid):
			out.append({"characterId": cid, "name": GameData.character_name(cid), "offers": by_id[cid]})
			order.erase(cid)
	for id in order:
		out.append({"characterId": id, "name": GameData.character_name(id), "offers": by_id[id]})
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
	if is_coin_pack(offer):
		return "%s xu" % coin_pack_amount(offer)
	if str(offer.get("offerType", "")) == CHARACTER_UNLOCK:
		return GameData.character_name(id)
	return Items.label(id)


static func currency_word(currency: String) -> String:
	return "kim cương" if currency == "gem" else "xu"


## The icon name (ui/art.gd ICONS) of a currency: "gem" or "coin".
static func currency_icon(currency: String) -> String:
	return "gem" if currency == "gem" else "coin"


## "300", "1.000": the amount shown next to the currency_icon().
static func price_text(offer: Dictionary) -> String:
	return Fmt.thousands(int(offer.get("priceAmount", 0)))


## "Hộp cứu thương x3 với giá 300 xu?"; a coin pack: "Đổi 10 kim cương lấy 1.000 xu?"
static func confirm_text(offer: Dictionary) -> String:
	if is_coin_pack(offer):
		return "Đổi %s kim cương lấy %s xu?" % [Fmt.thousands(int(offer.get("priceAmount", 0))), coin_pack_amount(offer)]
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


## "100" (shown with the gem icon).
static func product_amount(p: Dictionary) -> String:
	return Fmt.thousands(int(p.get("gemAmount", 0)))


## "100 kim cương"
static func product_title(p: Dictionary) -> String:
	return "%s kim cương" % product_amount(p)


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
