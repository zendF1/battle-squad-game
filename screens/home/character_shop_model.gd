extends RefCounted
## The Shop's "Nhân vật" tab as data: one card per character (the game data's character order)
## with its buy state, and the "Thông tin" popup: base stats with bars, weapon, skill and a
## short playstyle.
##
## Sources:
## - ownership: GET /player/characters (LoadoutModel.parse_characters); the default character
##   (the game data's defaultCharacterId) is always owned;
## - prices: the character_unlock offers of GET /shop/offers, minus the ones whose per-player
##   limit is used up (GET /shop/purchases);
## - base stats (máu, phòng thủ, sát thương vũ khí, năng lượng di chuyển): `baseStats` of GET
##   /player/characters, which the server sends for every character, owned or not;
## - the characters (order, name, role, playstyle), their starter weapon (explosion radius,
##   crater, wind) and skill (name, description, energy): the game data (GET /gamedata).

const LoadoutModel := preload("res://screens/loadout_model.gd")
const ShopModel := preload("res://screens/home/shop_model.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const Skills := preload("res://match/skills.gd")
const Art := preload("res://ui/art.gd")
const Fmt := preload("res://core/fmt.gd")
const GameData := preload("res://autoload/game_data_model.gd")

## Card states.
const OWNED := "owned"
const BUY := "buy"
const NOT_FOR_SALE := "not_for_sale"
const UNKNOWN := "unknown" # the offers or the owned characters are not loaded yet

const OWNED_TEXT := "Đã sở hữu"
const NOT_FOR_SALE_TEXT := "Chưa mở bán"
const BUY_TEXT := "Mua"

## Each character's colour (its body colour, tools/art/character_painter.gd LOOKS): the card's
## backdrop glow.
const TINTS := {
	"rookie": Color(0.25, 0.55, 1.0),
	"tanko": Color(0.42, 0.5, 0.3),
	"spark": Color(0.56, 0.36, 0.9),
	"flora": Color(0.3, 0.75, 0.5),
	"tide": Color(0.2, 0.7, 0.85),
}
const NEUTRAL_TINT := Color(0.35, 0.45, 0.7)

## The rows of the info popup: label, the baseStats field (or "explosionRadius" /
## "craterRadius": the character's weapon in the game data).
const STAT_ROWS := [
	{"key": "maxHp", "label": "Máu"},
	{"key": "weaponDamage", "label": "Sát thương"},
	{"key": "defense", "label": "Phòng thủ"},
	{"key": "moveEnergy", "label": "Năng lượng di chuyển"},
	{"key": "explosionRadius", "label": "Bán kính nổ"},
	{"key": "craterRadius", "label": "Phá địa hình"},
]


static func ids() -> Array:
	return LoadoutModel.character_ids()


static func character_name(id: String) -> String:
	return GameData.character_name(id)


static func role(id: String) -> String:
	return GameData.character_role_name(id)


static func tint(id: String) -> Color:
	return TINTS.get(id, NEUTRAL_TINT)


## The card of a character: {state, offers}. offers: its character_unlock offers still on sale
## for this player (server order), only for BUY. offers / purchases / owned are null while not
## loaded (purchases unknown: no limit is counted).
static func card(id: String, offers: Variant, purchases: Variant, owned: Variant) -> Dictionary:
	if id == LoadoutModel.default_character() or (owned is Array and owned.has(id)):
		return {"state": OWNED, "offers": []}
	if not offers is Array or not owned is Array:
		return {"state": UNKNOWN, "offers": []}
	var on_sale: Array = []
	for o in offers:
		if str(o.get("offerType", "")) != ShopModel.CHARACTER_UNLOCK or str(o.get("itemId", "")) != id:
			continue
		if purchases is Array and ShopModel.remaining(o, purchases) == 0:
			continue
		on_sale.append(o)
	return {"state": BUY if not on_sale.is_empty() else NOT_FOR_SALE, "offers": on_sale}


## The buy button: {text, icon ("" none, else "coin" / "gem"), enabled}: the first offer's price
## with its currency icon, "Đã sở hữu", "Chưa mở bán", or "Mua" (disabled) while unknown.
static func buy_button(c: Dictionary) -> Dictionary:
	match c["state"]:
		OWNED:
			return {"text": OWNED_TEXT, "icon": "", "enabled": false}
		NOT_FOR_SALE:
			return {"text": NOT_FOR_SALE_TEXT, "icon": "", "enabled": false}
		BUY:
			var o: Dictionary = c["offers"][0]
			return {"text": ShopModel.price_text(o), "icon": ShopModel.currency_icon(str(o.get("priceCurrency", ""))), "enabled": true}
	return {"text": BUY_TEXT, "icon": "", "enabled": false}


## The other prices of a BUY card ([{text, icon}], after the first one).
static func other_prices(c: Dictionary) -> Array:
	var out: Array = []
	if c["state"] != BUY:
		return out
	for o in c["offers"].slice(1):
		out.append({"text": ShopModel.price_text(o), "icon": ShopModel.currency_icon(str(o.get("priceCurrency", "")))})
	return out


## One stat of a character: baseStats (GET /player/characters data) for the server's fields,
## its weapon's (the game data) explosionRadius and craterRadius (px, rounded); null when unknown.
static func stat_value(data: Variant, id: String, key: String) -> Variant:
	var weapon := GameData.weapon_of_character(id)
	if key == "explosionRadius":
		return roundi(GameData.weapon_explosion_radius(GameData.character_weapon_id(id))) if not weapon.is_empty() else null
	if key == "craterRadius":
		return crater_radius(id) if not weapon.is_empty() else null
	var all = data.get("baseStats") if data is Dictionary else null
	var s = all.get(id) if all is Dictionary else null
	var v = s.get(key) if s is Dictionary else null
	return int(v) if v is int or v is float else null


## The crater radius (px) of the character's normal shot on normal ground, rounded: its weapon's
## craterRadius (the server's weaponCraterRadius, game data).
static func crater_radius(id: String) -> int:
	return roundi(GameData.weapon_crater_radius(GameData.character_weapon_id(id)))


## value / max as a bar length 0..1 (0 for no max).
static func bar_ratio(value: float, max_value: float) -> float:
	return clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0


## The stat rows of the info popup: [{key, label, value, text, ratio}], ratio against the
## highest value of that stat over all the characters. A stat the data lacks for this character
## is left out ([] when the base stats are not loaded: only the weapon rows would be left, so
## nothing is shown).
static func stat_rows(data: Variant, id: String) -> Array:
	var out: Array = []
	if BattleStats.base_of(data, id).is_empty():
		return out
	for r in STAT_ROWS:
		var v = stat_value(data, id, r["key"])
		if v == null:
			continue
		var top := 0
		for other in ids():
			var ov = stat_value(data, other, r["key"])
			if ov != null:
				top = maxi(top, int(ov))
		out.append({"key": r["key"], "label": r["label"], "value": int(v), "text": Fmt.thousands(int(v)),
			"ratio": bar_ratio(float(v), float(top))})
	return out


## How much the wind moves the character's shot (windInfluence / projectileWeight of its weapon;
## 1.0 for a weapon the game data does not know).
static func wind_factor(id: String) -> float:
	var weapon_id := GameData.character_weapon_id(id)
	if GameData.weapon(weapon_id).is_empty():
		return 1.0
	var weight := GameData.weapon_projectile_weight(weapon_id)
	return GameData.weapon_wind_influence(weapon_id) / weight if weight > 0.0 else 1.0


## "×0,3" (one decimal, Vietnamese comma).
static func factor_text(f: float) -> String:
	var t := "%.1f" % snappedf(f, 0.1)
	return "×" + t.replace(".", ",")


## Everything the info popup shows: {id, name, role, tint, weapon: {kind, tier, name, wind},
## skill: {name, text, energy}, playstyle}.
static func info(id: String) -> Dictionary:
	var kind := Art.character_gun(id)
	var skill := Skills.for_character(id)
	return {
		"id": id,
		"name": character_name(id),
		"role": role(id),
		"tint": tint(id),
		"weapon": {"kind": kind, "tier": Art.GUN_BASIC, "name": EquipmentModel.gun_name(kind),
			"wind": "Gió đẩy %s" % factor_text(wind_factor(id))},
		"skill": {"name": str(skill.get("name", "")), "text": Skills.describe(id, 0),
			"energy": "Cần %d năng lượng (+%d mỗi lượt, +%d khi bị trúng đòn)" % [GameData.skill_energy_max(),
				GameData.skill_energy_per_turn(), GameData.skill_energy_on_hit()]},
		"playstyle": GameData.character_playstyle(id),
	}
