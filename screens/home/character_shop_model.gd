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
## - what no API sends (the weapon's explosion radius, crater and wind, the skill's numbers): WEAPONS and
##   the skill's describe() (match/views/skills/), copied from the server's configs/weapons.yaml and
##   internal/game/match (skill_*.go). Keep them in step.

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

## Skill energy: a skill needs Skills.FULL_ENERGY, a player gains Skills.ENERGY_PER_TURN at the end
## of each of their turns and Skills.ENERGY_ON_HIT when an enemy hits them.
const SKILL_ENERGY_PER_TURN := Skills.ENERGY_PER_TURN

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
## configs/weapons.yaml): explosion radius (px, the damage area), terrain damage (the crater:
## radius terrainDamage × CRATER_PX_PER_TERRAIN_DAMAGE, server match/damage.go) and how much the
## wind pushes the shot (windInfluence / projectileWeight, server match/shooting.go).
const WEAPONS := {
	"rookie": {"weaponId": "basic_rocket", "explosionRadius": 40, "terrainDamage": 50, "windInfluence": 1.0, "projectileWeight": 1.0},
	"tanko": {"weaponId": "cannon_ball", "explosionRadius": 60, "terrainDamage": 130, "windInfluence": 0.5, "projectileWeight": 1.5},
	"spark": {"weaponId": "electric_orb", "explosionRadius": 30, "terrainDamage": 25, "windInfluence": 1.3, "projectileWeight": 0.8},
	"flora": {"weaponId": "seed_bomb", "explosionRadius": 40, "terrainDamage": 30, "windInfluence": 1.0, "projectileWeight": 0.9},
}

## Server match.craterPxPerTerrainDamage: crater radius (px) per point of weapon terrain damage.
const CRATER_PX_PER_TERRAIN_DAMAGE := 0.8

## "Lối chơi": what the character is good at, how to play it and its weakness (no numbers: the
## stat rows show them).
const PLAYSTYLE := {
	"rookie": "Không nổi bật hẳn mặt nào nhưng cũng chẳng có điểm yếu rõ ràng: máu, sát thương và tầm di chuyển đều vừa phải, đạn chịu gió bình thường. Hợp để tập căn góc và lực; khi đầy năng lượng, Mưa tên lửa trút xuống cả một vùng quanh pháo hiệu, khó né và đốt máu đối thủ ở lượt sau. Đổi lại, Rookie đánh không đau bằng Spark và không lì bằng Flora.",
	"tanko": "Chuyên phá địa hình: đại pháo khoét hố sâu hơn hẳn mọi người, phá chỗ nấp và đào đất ngay dưới chân đối thủ. Đạn nặng ít bị gió đẩy nên vẫn bắn chuẩn khi trời gió lớn; để dành Bom liên hoàn bắn thẳng vào địch: từng quả đào sâu thêm, địch rơi xuống đáy hố, trúng tiếp và bị cầm chân. Bù lại mỗi phát gây ít sát thương và Tanko đi được ngắn nhất, khó thoát khỏi chỗ đứng xấu.",
	"spark": "Đánh đau nhất: chỉ vài phát trúng là hạ được đối thủ, còn Tia laze xuyên địa hình, trúng mọi địch trên đường và làm họ mất lượt sau. Spark chạy xa nhất nên dễ đổi chỗ tìm góc bắn hoặc né khỏi tầm ngắm. Điểm yếu là máu và phòng thủ mỏng nhất, đạn nhẹ bị gió đẩy mạnh nên phải tính gió thật kỹ.",
	"flora": "Lì đòn nhất: máu và phòng thủ cao nhất, lại có Hoa hồi xuân hồi máu cả đội, máu dư thành khiên, nên càng đánh lâu càng có lợi. Hãy đứng vững, bắn chắc tay và kéo trận dài để đối thủ cạn máu trước. Bù lại sát thương thấp và đạn gần như không khoét đất, nên khó kết thúc trận nhanh.",
}

## The rows of the info popup: label, the baseStats field (or "explosionRadius" /
## "craterRadius": WEAPONS).
const STAT_ROWS := [
	{"key": "maxHp", "label": "Máu"},
	{"key": "weaponDamage", "label": "Sát thương"},
	{"key": "defense", "label": "Phòng thủ"},
	{"key": "moveEnergy", "label": "Năng lượng di chuyển"},
	{"key": "explosionRadius", "label": "Bán kính nổ"},
	{"key": "craterRadius", "label": "Phá địa hình"},
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
## WEAPONS for explosionRadius and craterRadius (px, rounded); null when unknown.
static func stat_value(data: Variant, id: String, key: String) -> Variant:
	if key == "explosionRadius":
		return WEAPONS[id]["explosionRadius"] if WEAPONS.has(id) else null
	if key == "craterRadius":
		return crater_radius(id) if WEAPONS.has(id) else null
	var all = data.get("baseStats") if data is Dictionary else null
	var s = all.get(id) if all is Dictionary else null
	var v = s.get(key) if s is Dictionary else null
	return int(v) if v is int or v is float else null


## The crater radius (px) of the character's normal shot on normal ground (server
## match.weaponCraterRadius: the blast radius for a weapon without terrain damage).
static func crater_radius(id: String) -> int:
	var w: Dictionary = WEAPONS.get(id, {})
	var td := float(w.get("terrainDamage", 0))
	return roundi(td * CRATER_PX_PER_TERRAIN_DAMAGE) if td > 0.0 else int(w.get("explosionRadius", 0))


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
		"skill": {"name": str(skill.get("name", "")), "text": Skills.describe(id, 0),
			"energy": "Cần %d năng lượng (+%d mỗi lượt, +%d khi bị trúng đòn)" % [Skills.FULL_ENERGY, SKILL_ENERGY_PER_TURN, Skills.ENERGY_ON_HIT]},
		"playstyle": str(PLAYSTYLE.get(id, "")),
	}
