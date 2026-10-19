extends RefCounted
## The Shop's "Nhân vật" tab as data: one card per character (LoadoutModel.CHARACTERS order)
## with its buy state, and the "Thông tin" popup: base stats with bars, weapon, skill and a
## short playstyle.
##
## Sources:
## - ownership: GET /player/characters (LoadoutModel.parse_characters); Rookie is always owned;
## - prices: the character_unlock offers of GET /shop/offers, minus the ones whose per-player
##   limit is used up (GET /shop/purchases);
## - base stats (máu, phòng thủ, sát thương vũ khí, năng lượng di chuyển): `baseStats` of GET
##   /player/characters, which the server sends for every character, owned or not;
## - what no API sends (the weapon's explosion radius and wind, the skill's numbers): WEAPONS and
##   SKILL_INFO below, copied from the server's configs/weapons.yaml, configs/skills.yaml and
##   internal/game/match (match.go shootSkill / endTurn, status_effect.go). Keep them in step.

const LoadoutModel := preload("res://screens/loadout_model.gd")
const ShopModel := preload("res://screens/home/shop_model.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const Skills := preload("res://match/skills.gd")
const Art := preload("res://ui/art.gd")
const Fmt := preload("res://core/fmt.gd")

## Card states.
const OWNED := "owned"
const BUY := "buy"
const NOT_FOR_SALE := "not_for_sale"
const UNKNOWN := "unknown" # the offers or the owned characters are not loaded yet

const OWNED_TEXT := "Đã sở hữu"
const NOT_FOR_SALE_TEXT := "Chưa mở bán"
const BUY_TEXT := "Mua"

## Skill energy: a skill needs Skills.FULL_ENERGY, a player gains this much at the end of each
## of their turns (server match.go endTurn).
const SKILL_ENERGY_PER_TURN := 20

## Each character's colour (its body colour, tools/art/character_painter.gd LOOKS): the card's
## backdrop glow.
const TINTS := {
	"rookie": Color(0.25, 0.55, 1.0),
	"tanko": Color(0.42, 0.5, 0.3),
	"spark": Color(0.56, 0.36, 0.9),
	"flora": Color(0.3, 0.75, 0.5),
}
const NEUTRAL_TINT := Color(0.35, 0.45, 0.7)

## The starter weapon of each character (server configs/characters.yaml weaponId →
## configs/weapons.yaml): explosion radius (px) and how much the wind pushes the shot
## (windInfluence / projectileWeight, server match/shooting.go).
const WEAPONS := {
	"rookie": {"weaponId": "basic_rocket", "explosionRadius": 40, "windInfluence": 1.0, "projectileWeight": 1.0},
	"tanko": {"weaponId": "cannon_ball", "explosionRadius": 50, "windInfluence": 0.5, "projectileWeight": 1.5},
	"spark": {"weaponId": "electric_orb", "explosionRadius": 35, "windInfluence": 1.2, "projectileWeight": 0.8},
	"flora": {"weaponId": "seed_bomb", "explosionRadius": 40, "windInfluence": 1.0, "projectileWeight": 0.9},
}

## The skill's effect in words, with the server's numbers (configs/skills.yaml damageMultiplier;
## match.go: triple_shot ±10°, heavy_bomb radius ×1.5, healing_bloom 450 HP; status_effect.go:
## the net caps the move energy at 50 for one turn).
const SKILL_INFO := {
	"rookie": "Bắn 3 quả rocket một lúc, lệch nhau 10°, mỗi quả 125% sát thương.",
	"tanko": "Một quả bom lớn: 130% sát thương, vụ nổ rộng gấp 1,5 lần.",
	"spark": "Quả cầu điện 90% sát thương; trúng địch thì trùm lưới: lượt sau địch chỉ còn tối đa 50 năng lượng di chuyển.",
	"flora": "Không cần ngắm: hồi ngay 450 máu cho bản thân (tăng theo sức mạnh kỹ năng), rồi hết lượt.",
}

## "Lối chơi", written from the numbers above and the base stats.
const PLAYSTYLE := {
	"rookie": "Toàn diện và dễ chơi nhất: 1.500 máu, bazooka 480 sát thương, nổ rộng 40 và chịu gió bình thường. Hợp để tập căn góc và lực; khi đầy năng lượng, Bắn 3 tia phủ rộng cả vùng, khó né và dễ kết liễu đối thủ.",
	"tanko": "Trâu và đánh đau nhất: 1.950 máu, 80 phòng thủ, đại pháo 600 sát thương nổ rộng 50. Đạn nặng nên gió chỉ đẩy bằng 1/3 bình thường, vẫn bắn chuẩn khi trời gió lớn. Đứng vững ở tuyến đầu và để dành Bom lớn cho mục tiêu đứng sát nhau.",
	"spark": "Mỏng máu nhất (1.350 máu, 40 phòng thủ) nhưng giỏi khống chế. Đạn điện nhẹ, bị gió đẩy mạnh nhất (gấp 1,5 lần) nên cần tính gió kỹ. Dùng Lưới điện lên đối thủ nguy hiểm để họ không chạy thoát hay tìm được chỗ nấp ở lượt sau.",
	"flora": "Bền bỉ nhờ hồi máu: 1.425 máu và súng hạt 360 sát thương, nổ rộng 40. Sát thương thấp nhất nên hãy bắn chắc tay, tránh đấu máu sớm. Khi đầy năng lượng, Hồi máu trả lại 450 máu ngay lập tức để lật kèo trận dài.",
}

## The rows of the info popup: label, the baseStats field (or "explosionRadius": WEAPONS).
const STAT_ROWS := [
	{"key": "maxHp", "label": "Máu"},
	{"key": "weaponDamage", "label": "Sát thương"},
	{"key": "defense", "label": "Phòng thủ"},
	{"key": "moveEnergy", "label": "Năng lượng di chuyển"},
	{"key": "explosionRadius", "label": "Bán kính nổ"},
]


static func ids() -> Array:
	return LoadoutModel.CHARACTERS.map(func(c): return c["id"])


static func character_name(id: String) -> String:
	for c in LoadoutModel.CHARACTERS:
		if c["id"] == id:
			return c["name"]
	return id


static func role(id: String) -> String:
	for c in LoadoutModel.CHARACTERS:
		if c["id"] == id:
			return c["role"]
	return ""


static func tint(id: String) -> Color:
	return TINTS.get(id, NEUTRAL_TINT)


## The card of a character: {state, offers}. offers: its character_unlock offers still on sale
## for this player (server order), only for BUY. offers / purchases / owned are null while not
## loaded (purchases unknown: no limit is counted).
static func card(id: String, offers: Variant, purchases: Variant, owned: Variant) -> Dictionary:
	if id == LoadoutModel.DEFAULT_CHARACTER or (owned is Array and owned.has(id)):
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
## WEAPONS for explosionRadius; null when unknown.
static func stat_value(data: Variant, id: String, key: String) -> Variant:
	if key == "explosionRadius":
		return WEAPONS[id]["explosionRadius"] if WEAPONS.has(id) else null
	var all = data.get("baseStats") if data is Dictionary else null
	var s = all.get(id) if all is Dictionary else null
	var v = s.get(key) if s is Dictionary else null
	return int(v) if v is int or v is float else null


## value / max as a bar length 0..1 (0 for no max).
static func bar_ratio(value: float, max_value: float) -> float:
	return clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0


## The stat rows of the info popup: [{key, label, value, text, ratio}], ratio against the
## highest value of that stat over all the characters. A stat the data lacks for this character
## is left out ([] when the base stats are not loaded: only the explosion radius would be left,
## so nothing is shown).
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


## How much the wind moves the character's shot against Rookie's rocket (1.0).
static func wind_factor(id: String) -> float:
	var w: Dictionary = WEAPONS.get(id, {})
	var weight := float(w.get("projectileWeight", 1.0))
	return float(w.get("windInfluence", 1.0)) / weight if weight > 0.0 else 1.0


## "×0,3" (one decimal, Vietnamese comma).
static func factor_text(f: float) -> String:
	var t := "%.1f" % snappedf(f, 0.1)
	return "×" + t.replace(".", ",")


## Everything the info popup shows: {id, name, role, tint, weapon: {kind, tier, name, wind},
## skill: {name, text, energy}, playstyle}.
static func info(id: String) -> Dictionary:
	var kind := str(Art.CHARACTER_GUNS.get(id, Art.DEFAULT_GUN_KIND))
	var skill := Skills.for_character(id)
	return {
		"id": id,
		"name": character_name(id),
		"role": role(id),
		"tint": tint(id),
		"weapon": {"kind": kind, "tier": Art.GUN_BASIC, "name": str(EquipmentModel.GUN_NAMES.get(kind, EquipmentModel.GUN_NAMES["blaster"])),
			"wind": "Gió đẩy %s" % factor_text(wind_factor(id))},
		"skill": {"name": str(skill.get("name", "")), "text": str(SKILL_INFO.get(id, "")),
			"energy": "Cần %d năng lượng (+%d mỗi lượt)" % [Skills.FULL_ENERGY, SKILL_ENERGY_PER_TURN]},
		"playstyle": str(PLAYSTYLE.get(id, "")),
	}
