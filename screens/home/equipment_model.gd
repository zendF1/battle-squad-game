extends RefCounted
## Equipment as the Shop, Túi đồ, Nhân vật and Prep screens show it, without UI: the catalog
## (GET /equipment/catalog) and the owned pieces (GET /player/equipment) parsed, Vietnamese slot
## and item names, stat lines, the compare against the worn piece, the can-wear check and the
## orders the screens list them in.
##
## A catalog item: {itemId, name, slot, category: "normal" | "crafted", tier?, requiredLevel,
## characterId?, gemSlots, statHp, statDamage, statDefense, statCrit, statMoveEnergy, priceCoin,
## priceGem, isActive}. An owned piece: {equipmentId, itemId, slot, category, tier?,
## upgradeLevel, isEquipped, equippedOn? (characterId), ...}. Stats shown are the item's base
## stats; the upgrade bonus (×(1+0.02×level) and milestones) is applied by the server and only
## shown as the "+N" badge.
##
## Item stats are stat points, like the points a character allocates: each becomes battle stats
## through the GET /player/characters statMultipliers (hp → Máu, damage → Sát thương, defense →
## Phòng thủ, mobility → Di chuyển), so lines read "Máu +20 điểm (+1.000)". Crit is a percent
## with no multiplier. Without the multipliers (characters not loaded yet) lines show points only.

const LoadoutModel := preload("res://screens/loadout_model.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const Fmt := preload("res://core/fmt.gd")

## Display order (the Nhân vật page's slots, filters, sorting).
const SLOTS := ["helmet", "armor", "gloves", "pants", "boots", "weapon"]
const SLOT_NAMES := {
	"weapon": "Vũ khí", "armor": "Áo", "helmet": "Mũ", "pants": "Quần", "boots": "Giày", "gloves": "Găng tay",
}
## Art tiers (ui/art.gd equipment icons): normal items by shop tier, crafted by their tier.
const NORMAL_TIERS := ["iron", "steel", "mithril", "dragon"]
const CRAFTED_TIERS := ["silver", "gold", "titan", "diamond"]
const TIER_WORDS := {
	"iron": "Sắt", "steel": "Thép", "mithril": "Mithril", "dragon": "Rồng",
	"silver": "Bạc", "gold": "Vàng", "titan": "Titan", "diamond": "Kim cương",
}
## Normal item ids end in lvN, the required level (10/20/30/40): the shop tier. Weapons are guns,
## per character (<character>_weapon_lvN, "Iron Bazooka"); the other slots are shared.
const ID_SUFFIX_TIERS := {"lv10": "iron", "lv20": "steel", "lv30": "mithril", "lv40": "dragon"}
## The type part of "<Tier> <Type>" server names (one or two words).
const TYPE_WORDS := {
	"sword": "Kiếm", "vest": "Áo giáp", "cap": "Mũ", "pants": "Quần", "boots": "Giày", "gloves": "Găng",
	"bazooka": "Bazooka", "cannon": "Đại pháo", "shock rifle": "Súng điện", "seed launcher": "Súng hạt", "blaster": "Súng",
}
## The gun each character fires (its weapons' icon); generic and crafted weapons are blasters ("").
const WEAPON_KINDS := {"rookie": "bazooka", "tanko": "cannon", "spark": "rifle", "flora": "launcher"}
const KIND_OF_TYPE := {"bazooka": "bazooka", "cannon": "cannon", "shock rifle": "rifle", "seed launcher": "launcher"}
## key: the catalog field; point: the statMultipliers / stats.equipmentPoints key ("" for crit);
## unit "%" for the crit chance; total: the stats.fromEquipment field.
const STATS := [
	{"key": "statHp", "label": "Máu", "unit": "", "point": "hp", "total": "maxHp"},
	{"key": "statDamage", "label": "Sát thương", "unit": "", "point": "damage", "total": "damageBonus"},
	{"key": "statDefense", "label": "Phòng thủ", "unit": "", "point": "defense", "total": "defense"},
	{"key": "statCrit", "label": "Chí mạng", "unit": "%", "point": "", "total": "critChance"},
	{"key": "statMoveEnergy", "label": "Di chuyển", "unit": "", "point": "mobility", "total": "moveEnergy"},
]
const MINUS := "−"


static func slot_name(slot: String) -> String:
	return str(SLOT_NAMES.get(slot, slot))


static func slot_index(slot: String) -> int:
	var i := SLOTS.find(slot)
	return i if i >= 0 else SLOTS.size()


static func character_name(id: String) -> String:
	for c in LoadoutModel.CHARACTERS:
		if c["id"] == id:
			return c["name"]
	return id


# ── Parsing ─────────────────────────────────────────────────────────────────

## The GET /equipment/catalog data → {items: {itemId: item}, order: [itemId...], upgradeRates,
## setBonuses, stones}, or null when it has no items array. Inactive items are kept (an owned
## piece still needs its name and stats) and flagged by isActive.
static func parse_catalog(data: Variant) -> Variant:
	if not data is Dictionary or not data.get("items") is Array:
		return null
	var items := {}
	var order: Array = []
	for it in data["items"]:
		if it is Dictionary and str(it.get("itemId", "")) != "" and not items.has(str(it["itemId"])):
			items[str(it["itemId"])] = it
			order.append(str(it["itemId"]))
	var out := {"items": items, "order": order}
	for k in ["upgradeRates", "setBonuses", "stones"]:
		out[k] = data[k] if data.get(k) is Array else []
	return out


## The GET /player/equipment data (a bare array, newest first) → the pieces, or null.
static func parse_owned(data: Variant) -> Variant:
	if data == null:
		return [] # an empty list may come back as null
	if not data is Array:
		return null
	return data.filter(func(p): return p is Dictionary and str(p.get("equipmentId", "")) != "")


## The catalog item, or {} when unknown (or the catalog is not loaded).
static func item_of(catalog: Variant, item_id: String) -> Dictionary:
	if catalog is Dictionary and catalog.get("items") is Dictionary:
		var it = catalog["items"].get(item_id)
		if it is Dictionary:
			return it
	return {}


## The catalog item of an owned piece, or a stand-in built from the piece ({itemId, slot,
## category, tier}) when the catalog does not know it.
static func item_of_piece(catalog: Variant, piece: Dictionary) -> Dictionary:
	var it := item_of(catalog, str(piece.get("itemId", "")))
	if not it.is_empty():
		return it
	var out := {"itemId": str(piece.get("itemId", "")), "name": "", "slot": str(piece.get("slot", "")),
		"category": str(piece.get("category", "normal")), "requiredLevel": 1}
	if piece.get("tier") != null:
		out["tier"] = piece["tier"]
	return out


# ── Names and art ───────────────────────────────────────────────────────────

## The art tier of an item: its tier, else the tier word of its name ("Iron Sword"), else the
## lvN suffix of its id; "iron" (normal) / "silver" (crafted) when none matches.
static func tier(item: Dictionary) -> String:
	var t = item.get("tier")
	if t != null and TIER_WORDS.has(str(t).to_lower()):
		return str(t).to_lower()
	var words := str(item.get("name", "")).to_lower().split(" ", false)
	if not words.is_empty() and TIER_WORDS.has(words[0]):
		return words[0]
	var id := str(item.get("itemId", ""))
	for suffix in ID_SUFFIX_TIERS:
		if id.ends_with("_" + suffix):
			return ID_SUFFIX_TIERS[suffix]
	return "silver" if str(item.get("category", "")) == "crafted" else "iron"


## "Bazooka Sắt", "Đại pháo Rồng", "Súng điện Thép", "Súng hạt Mithril", "Súng Kim cương",
## "Áo giáp Rồng" from "<Tier> <Type>"; the server name otherwise, or the slot name + tier word
## when it has none.
static func display_name(item: Dictionary) -> String:
	var name := str(item.get("name", "")).strip_edges()
	var words := name.to_lower().split(" ", false)
	if words.size() >= 2 and TIER_WORDS.has(words[0]):
		var type := " ".join(words.slice(1))
		if TYPE_WORDS.has(type):
			return "%s %s" % [TYPE_WORDS[type], TIER_WORDS[words[0]]]
	if name != "":
		return name
	var slot := str(item.get("slot", ""))
	if slot == "":
		return str(item.get("itemId", ""))
	return "%s %s" % [slot_name(slot), TIER_WORDS.get(tier(item), "")]


## The gun of a weapon for its icon: "bazooka", "cannon", "rifle", "launcher" (by characterId,
## else by the name's type), "" for a blaster or a non-weapon.
static func weapon_kind(item: Dictionary) -> String:
	if str(item.get("slot", "")) != "weapon":
		return ""
	var only = item.get("characterId")
	if only != null and WEAPON_KINDS.has(str(only)):
		return WEAPON_KINDS[str(only)]
	var words := str(item.get("name", "")).to_lower().split(" ", false)
	if words.size() >= 2:
		return str(KIND_OF_TYPE.get(" ".join(words.slice(1)), ""))
	return ""


## "+3" (the upgrade badge; "+0" for a new piece).
static func level_text(piece: Dictionary) -> String:
	return "+%d" % maxi(int(piece.get("upgradeLevel", 0)), 0)


# ── Stats ───────────────────────────────────────────────────────────────────

static func _num(item: Dictionary, key: String) -> float:
	var v = item.get(key)
	return float(v) if v is int or v is float else 0.0


static func _format(value: float, unit: String, signed: bool) -> String:
	var prefix := ""
	if signed:
		prefix = "+" if value >= 0 else MINUS
	if unit == "%":
		return prefix + BattleStats.format_chance(absf(value) if signed else value)
	return prefix + str(int(absf(value)) if signed else int(value))


## 1000 → "+1.000", -55 → "−55".
static func _signed(n: int) -> String:
	return ("+" if n >= 0 else MINUS) + Fmt.thousands(absi(n))


## What `points` of a stat are in battle (points × its multiplier), or null when the stat has no
## multiplier (crit) or `mult` (BattleStats.multipliers) does not know it.
static func converted(points: float, point: String, mult: Dictionary) -> Variant:
	if point == "" or not mult.has(point):
		return null
	return int(points) * int(mult[point])


## "+20 điểm (+1.000)", "+20 điểm" without the multiplier, "+2%" for crit.
static func points_text(points: float, s: Dictionary, mult: Dictionary) -> String:
	if s["unit"] == "%":
		return _format(points, "%", true)
	var t := "%s điểm" % _signed(int(points))
	var c = converted(points, s["point"], mult)
	return t if c == null else "%s (%s)" % [t, _signed(c)]


## The item's non-zero stats: [{key, label, value (points), battle (points × multiplier, or
## null), text: "+20 điểm (+1.000)" / "+20 điểm" / "+2%"}]. `mult`: BattleStats.multipliers.
static func stat_lines(item: Dictionary, mult: Dictionary = {}) -> Array:
	var out: Array = []
	for s in STATS:
		var v := _num(item, s["key"])
		if v != 0.0:
			out.append({"key": s["key"], "label": s["label"], "value": v, "battle": converted(v, s["point"], mult),
				"text": points_text(v, s, mult)})
	return out


## "Máu +30 điểm (+1.500) · Phòng thủ +3 điểm (+15)"
static func stat_summary(item: Dictionary, mult: Dictionary = {}) -> String:
	return " · ".join(stat_lines(item, mult).map(func(l): return "%s %s" % [l["label"], l["text"]]))


## Per-stat change from wearing `candidate` instead of `worn` ({} = the slot is empty), the
## stats either of them has: [{key, label, delta (points), text, tone: "good" | "loss" | ""}].
## text is the battle change with the points, "+850 (+17 điểm)" / "−1.000 (−20 điểm)"; "+17
## điểm" without the multiplier; "+2%" for crit; "0" when equal.
static func compare(candidate: Dictionary, worn: Dictionary, mult: Dictionary = {}) -> Array:
	var out: Array = []
	for s in STATS:
		var a := _num(candidate, s["key"])
		var b := _num(worn, s["key"])
		if a == 0.0 and b == 0.0:
			continue
		var d := a - b
		var text := "0"
		if d != 0.0:
			var c = converted(d, s["point"], mult)
			if s["unit"] == "%":
				text = _format(d, "%", true)
			elif c == null:
				text = "%s điểm" % _signed(int(d))
			else:
				text = "%s (%s điểm)" % [_signed(c), _signed(int(d))]
		out.append({"key": s["key"], "label": s["label"], "delta": d, "text": text,
			"tone": "good" if d > 0.0 else ("loss" if d < 0.0 else "")})
	return out


# ── Owned pieces ────────────────────────────────────────────────────────────

## Who wears the piece (characterId), or "".
static func wearer(piece: Dictionary) -> String:
	var on = piece.get("equippedOn")
	if on == null or not bool(piece.get("isEquipped", on != null)):
		return ""
	return str(on)


## What a character wears: slot -> piece.
static func worn(owned: Variant, character_id: String) -> Dictionary:
	var out := {}
	if not owned is Array:
		return out
	for p in owned:
		if wearer(p) == character_id and character_id != "":
			out[str(p.get("slot", ""))] = p
	return out


static func find_piece(owned: Variant, equipment_id: String) -> Dictionary:
	if owned is Array:
		for p in owned:
			if str(p.get("equipmentId", "")) == equipment_id:
				return p
	return {}


## How many pieces of an item the player owns.
static func owned_count(owned: Variant, item_id: String) -> int:
	if not owned is Array:
		return 0
	return owned.filter(func(p): return str(p.get("itemId", "")) == item_id).size()


## Pieces of one slot ("" = all).
static func filter_slot(pieces: Array, slot: String) -> Array:
	if slot == "":
		return pieces.duplicate()
	return pieces.filter(func(p): return str(p.get("slot", "")) == slot)


## The Túi đồ order: worn pieces first, then by required level (highest first), slot order,
## upgrade level (highest first), then the server's order (newest first).
static func sort_bag(owned: Variant, catalog: Variant) -> Array:
	if not owned is Array:
		return []
	var rows: Array = []
	for i in owned.size():
		var p: Dictionary = owned[i]
		var it := item_of_piece(catalog, p)
		rows.append([0 if wearer(p) != "" else 1, -int(it.get("requiredLevel", 1)), slot_index(str(p.get("slot", ""))),
			-int(p.get("upgradeLevel", 0)), i, p])
	rows.sort_custom(func(a, b):
		for k in 5:
			if a[k] != b[k]:
				return a[k] < b[k]
		return false)
	return rows.map(func(r): return r[5])


## The pieces a character may look at for a slot on the Nhân vật page ("" = all): the ones it
## wears first, then free ones, then the ones other characters wear; wearable before not.
static func sort_for_character(pieces: Array, catalog: Variant, character_id: String, characters: Variant) -> Array:
	var rows: Array = []
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		var it := item_of_piece(catalog, p)
		var who := wearer(p)
		var rank := 0 if who == character_id else (1 if who == "" else 2)
		var ok := 0 if can_wear(it, character_id, characters)["ok"] else 1
		rows.append([rank, ok, slot_index(str(p.get("slot", ""))), -int(it.get("requiredLevel", 1)), i, p])
	rows.sort_custom(func(a, b):
		for k in 5:
			if a[k] != b[k]:
				return a[k] < b[k]
		return false)
	return rows.map(func(r): return r[5])


# ── Wearing ─────────────────────────────────────────────────────────────────

## The GET /player/characters entry of a character, or null (not owned / not loaded).
static func character_entry(characters: Variant, id: String) -> Variant:
	if not characters is Dictionary or not characters.get("characters") is Array:
		return null
	for c in characters["characters"]:
		if c is Dictionary and str(c.get("characterId", "")) == id:
			return c
	return null


## Whether `character_id` can wear the item: {ok, reason}. reason (Vietnamese) when not:
## "Chưa sở hữu nhân vật", "Chỉ cho Tanko", "Cần Lv 20". Unknown characters data (not loaded)
## is ok: the server decides.
static func can_wear(item: Dictionary, character_id: String, characters: Variant) -> Dictionary:
	var only = item.get("characterId")
	if only != null and str(only) != "" and str(only) != character_id:
		return {"ok": false, "reason": "Chỉ cho %s" % character_name(str(only))}
	if not characters is Dictionary or not characters.get("characters") is Array:
		return {"ok": true, "reason": ""}
	var entry = character_entry(characters, character_id)
	if entry == null:
		return {"ok": false, "reason": "Chưa sở hữu nhân vật"}
	var need := int(item.get("requiredLevel", 1))
	if int(entry.get("level", 1)) < need:
		return {"ok": false, "reason": "Cần Lv %d" % need}
	return {"ok": true, "reason": ""}


## "Lv 20"
static func required_text(item: Dictionary) -> String:
	return "Lv %d" % maxi(int(item.get("requiredLevel", 1)), 1)


## "Đang mặc · Tanko" for a worn piece, "" otherwise.
static func worn_text(piece: Dictionary) -> String:
	var who := wearer(piece)
	return "Đang mặc · %s" % character_name(who) if who != "" else ""


## The equipment part of a character's battle stats (GET /player/characters stats) as short
## lines, zeros left out: the points (stats.equipmentPoints) with what they add in battle
## (stats.fromEquipment), ["Máu +80 điểm (+4.000)", "Sát thương +10 điểm (+50)", "Chí mạng
## +2%"]; only the battle value ("Máu +4.000") from a server without equipmentPoints.
static func bonus_lines(stats: Variant) -> Array:
	var fe = stats.get("fromEquipment") if stats is Dictionary else null
	var out: Array = []
	if not fe is Dictionary:
		return out
	var ep = stats.get("equipmentPoints")
	for s in STATS:
		var v = fe.get(s["total"])
		var battle := float(v) if v is int or v is float else 0.0
		var p = ep.get(s["point"] if s["point"] != "" else "crit") if ep is Dictionary else null
		if s["unit"] == "%":
			if battle != 0.0:
				out.append("%s %s" % [s["label"], _format(battle, "%", true)])
		elif p is int or p is float:
			if float(p) != 0.0:
				out.append("%s %s điểm (%s)" % [s["label"], _signed(int(p)), _signed(int(battle))])
		elif battle != 0.0:
			out.append("%s %s" % [s["label"], _signed(int(battle))])
	return out


# ── Shop ────────────────────────────────────────────────────────────────────

## Items the shop sells to `character_id`: active normal items with a price that are shared
## (no characterId) or that character's own (its weapons; other characters' are left out), of
## one slot ("" = all), in slot order then by required level.
static func shop_items(catalog: Variant, slot: String = "", character_id: String = "") -> Array:
	if not catalog is Dictionary:
		return []
	var rows: Array = []
	var order: Array = catalog.get("order", [])
	for i in order.size():
		var it := item_of(catalog, str(order[i]))
		if it.get("isActive", true) == false or str(it.get("category", "normal")) != "normal":
			continue
		if price(it)["amount"] <= 0:
			continue
		var only = it.get("characterId")
		if only != null and str(only) != "" and str(only) != character_id:
			continue
		if slot != "" and str(it.get("slot", "")) != slot:
			continue
		rows.append([slot_index(str(it.get("slot", ""))), int(it.get("requiredLevel", 1)), i, it])
	rows.sort_custom(func(a, b):
		for k in 3:
			if a[k] != b[k]:
				return a[k] < b[k]
		return false)
	return rows.map(func(r): return r[3])


## What buying costs: priceCoin, or priceGem when priceCoin is 0 → {currency, amount}.
static func price(item: Dictionary) -> Dictionary:
	var coin := int(_num(item, "priceCoin"))
	if coin > 0:
		return {"currency": "coin", "amount": coin}
	return {"currency": "gem", "amount": int(_num(item, "priceGem"))}


## "Mua Bazooka Sắt với giá 500 xu?"
static func confirm_text(item: Dictionary) -> String:
	var p := price(item)
	return "Mua %s với giá %s %s?" % [display_name(item), Fmt.thousands(p["amount"]), "kim cương" if p["currency"] == "gem" else "xu"]


## "Đã có 2", or "" when none is owned.
static func owned_text(n: int) -> String:
	return "Đã có %d" % n if n > 0 else ""
