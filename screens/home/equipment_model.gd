extends RefCounted
## Equipment as the Shop, Túi đồ, Nhân vật and Prep screens show it, without UI: the catalog
## (GET /equipment/catalog) and the owned pieces (GET /player/equipment) parsed, Vietnamese slot
## and item names, stat lines, the compare against the worn piece, the can-wear check and the
## orders the screens list them in.
##
## A catalog item: {itemId, name, slot, category: "normal" | "crafted", tier?, requiredLevel,
## characterId?, gemSlots, statHp, statDamage, statDefense, statCrit, statMoveEnergy, priceCoin,
## priceGem, isActive}. An owned piece: {equipmentId, itemId, slot, category, tier?,
## upgradeLevel, isEquipped, equippedOn? (characterId), ...}. A piece's stats are its item's
## upgraded like the server does (upgraded(): ×(1 + 0.02 × level + reached milestone bonuses),
## rounded per item; piece_item()); shop items are +0.
##
## Item stats are stat points, like the points a character allocates: each becomes battle stats
## through the GET /player/characters statMultipliers (hp → Máu, damage → Sát thương, defense →
## Phòng thủ, mobility → Di chuyển), so lines read "Máu +20 điểm (+40)". Crit is a percent
## with no multiplier. Without the multipliers (characters not loaded yet) lines show points only.

const LoadoutModel := preload("res://screens/loadout_model.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const Fmt := preload("res://core/fmt.gd")
const Art := preload("res://ui/art.gd")

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
## The held gun sprite (ui/art.gd GUN_KINDS) of a weapon_kind() icon kind; "" (generic and
## crafted weapons) is the blaster.
const GUN_OF_KIND := {"bazooka": "bazooka", "cannon": "cannon", "rifle": "shock_rifle", "launcher": "seed_launcher", "": "blaster"}
## A gun kind's name (ui/art.gd GUN_KINDS), for the basic gun of a character with no weapon.
const GUN_NAMES := {"bazooka": "Bazooka", "cannon": "Đại pháo", "shock_rifle": "Súng điện", "seed_launcher": "Súng hạt", "blaster": "Súng"}
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
## Share of the buy price POST /player/equipment/sell gives back when the catalog has no sellRate.
const DEFAULT_SELL_RATE := 0.25


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
## setBonuses, stones, sellRate}, or null when it has no items array. Inactive items are kept (an
## owned piece still needs its name and stats) and flagged by isActive. sellRate: the share of the
## buy price selling gives back (DEFAULT_SELL_RATE when missing or outside (0, 1]).
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
	out["sellRate"] = parse_sell_rate(data.get("sellRate"))
	if data.get("mergeRatePerItem") is int or data.get("mergeRatePerItem") is float:
		out["mergeRatePerItem"] = float(data["mergeRatePerItem"])
	out["upgradeMilestones"] = parse_milestones(data.get("upgradeMilestones"))
	if data.get("weaponUpgradeCostMultiplier") is int or data.get("weaponUpgradeCostMultiplier") is float:
		out["weaponUpgradeCostMultiplier"] = float(data["weaponUpgradeCostMultiplier"])
	return out


## Milestone bonuses of the server's battlestats: from level 6, 10, 14, 16 on, item stats get
## a further +0.10, +0.20, +0.40, +1.00 (game_settings, sent as the catalog's upgradeMilestones).
const DEFAULT_MILESTONES := [[6, 0.10], [10, 0.20], [14, 0.40], [16, 1.00]]


## A catalog upgradeMilestones ([{level, bonus}]) → [[level, bonus]...] ascending;
## DEFAULT_MILESTONES when missing or malformed (an older server).
static func parse_milestones(v: Variant) -> Array:
	if not v is Array or v.is_empty():
		return DEFAULT_MILESTONES.duplicate(true)
	var out: Array = []
	for m in v:
		if not m is Dictionary or not (m.get("level") is int or m.get("level") is float) or not (m.get("bonus") is int or m.get("bonus") is float):
			return DEFAULT_MILESTONES.duplicate(true)
		out.append([int(m["level"]), float(m["bonus"])])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


## The milestone bonuses of a parsed catalog (DEFAULT_MILESTONES before it loads).
static func milestones(catalog: Variant) -> Array:
	if catalog is Dictionary and catalog.get("upgradeMilestones") is Array:
		return catalog["upgradeMilestones"]
	return DEFAULT_MILESTONES


## A catalog sellRate, DEFAULT_SELL_RATE when it is not a number in (0, 1] (an older server).
static func parse_sell_rate(v: Variant) -> float:
	if (v is int or v is float) and float(v) > 0.0 and float(v) <= 1.0:
		return float(v)
	return DEFAULT_SELL_RATE


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


## The gun a character holds (character.gd set_weapon()): {kind, tier} of the weapon item
## `item_id` (its catalog entry `item` when known, else read from the id:
## <character>_weapon_lvN → that character's gun in the lvN tier, crafted_weapon_<tier> and
## normal_weapon_lvN → the blaster), or the character's basic gun for "" (no weapon).
## rookie_weapon_lv30 → bazooka/mithril, crafted_weapon_gold → blaster/gold, normal_weapon_lv10 →
## blaster/iron, "" for Tanko → cannon/basic.
static func gun(item_id: String, item: Dictionary = {}, character_id: String = "") -> Dictionary:
	if item_id == "" and item.is_empty():
		return {"kind": str(Art.CHARACTER_GUNS.get(character_id, Art.DEFAULT_GUN_KIND)), "tier": Art.GUN_BASIC}
	var it := item if not item.is_empty() else weapon_from_id(item_id)
	return {"kind": str(GUN_OF_KIND.get(weapon_kind(it), "blaster")), "tier": tier(it)}


## The gun a match player brought: its weaponItemId (catalog for the entry; empty / missing for
## no weapon and for bots) → gun(), its character's basic gun when none.
static func player_gun(player: Dictionary, catalog: Variant = null) -> Dictionary:
	var weapon = player.get("weaponItemId")
	var weapon_id := str(weapon) if weapon is String else ""
	return gun(weapon_id, item_of(catalog, weapon_id) if weapon_id != "" else {}, str(player.get("characterId", "")))


## A stand-in catalog entry for a weapon id the catalog does not give: {itemId, slot, category,
## characterId?, tier?}.
static func weapon_from_id(item_id: String) -> Dictionary:
	var out := {"itemId": item_id, "slot": "weapon", "category": "normal"}
	if item_id.begins_with("crafted_"):
		out["category"] = "crafted"
		var t := item_id.get_slice("_", item_id.get_slice_count("_") - 1)
		if TIER_WORDS.has(t):
			out["tier"] = t
		return out
	var owner := item_id.get_slice("_", 0)
	if WEAPON_KINDS.has(owner) and item_id.begins_with(owner + "_weapon_"):
		out["characterId"] = owner
	return out


## The gun `character_id` holds outside a match: the weapon it wears among the owned pieces
## (catalog for its entry), its basic gun when none (or the pieces are not loaded).
static func worn_gun(owned: Variant, catalog: Variant, character_id: String) -> Dictionary:
	var piece: Dictionary = worn(owned, character_id).get("weapon", {})
	if piece.is_empty():
		return gun("", {}, character_id)
	return gun(str(piece.get("itemId", "")), item_of(catalog, str(piece.get("itemId", ""))), character_id)


## "+3" ("+0" for a new piece). Shown only in the piece popup and on the Nâng cấp page; elsewhere
## the milestone aura and name colour are the level cue.
static func level_text(piece: Dictionary) -> String:
	return "+%d" % maxi(int(piece.get("upgradeLevel", 0)), 0)


## "Thường" / "Chế tạo"
static func category_name(item: Dictionary) -> String:
	return "Chế tạo" if str(item.get("category", "")) == "crafted" else "Thường"


## The Prep gear row tooltip of a worn piece: its name (no "+N") over its upgraded stat summary
## ("Bazooka Sắt\nSát thương +8 điểm (+40)"; points only without `mult`).
static func piece_tooltip(catalog: Variant, piece: Dictionary, mult: Dictionary = {}) -> String:
	var tip := display_name(item_of_piece(catalog, piece))
	var stats := stat_summary(piece_item(catalog, piece), mult)
	return tip + ("\n" + stats if stats != "" else "")


# ── Stats ───────────────────────────────────────────────────────────────────

## The stat multiplier of an upgrade level: 1 + 0.02 × level + each reached milestone bonus, added
## in the server's order (battlestats upgradeMultiplier), so the float is the same.
static func upgrade_multiplier(level: int, ms: Array = DEFAULT_MILESTONES) -> float:
	var mul := 1.0 + float(level) * 0.02
	for m in ms:
		if level >= int(m[0]):
			mul += float(m[1])
	return mul


## A copy of `item` with its stats at upgrade `level` (battlestats SumEquipment per item): hp,
## damage, defense and move energy points × upgrade_multiplier(), rounded half away from zero;
## crit × the multiplier, unrounded.
static func upgraded(item: Dictionary, level: int, ms: Array = DEFAULT_MILESTONES) -> Dictionary:
	if level <= 0:
		return item
	var mul := upgrade_multiplier(level, ms)
	var out := item.duplicate()
	for s in STATS:
		var v := _num(item, s["key"])
		if v == 0.0:
			continue
		out[s["key"]] = v * mul if s["unit"] == "%" else float(roundi(v * mul))
	return out


## The catalog item of an owned piece with its upgraded stats (what it adds in battle).
static func piece_item(catalog: Variant, piece: Dictionary) -> Dictionary:
	return upgraded(item_of_piece(catalog, piece), int(piece.get("upgradeLevel", 0)), milestones(catalog))


static func _num(item: Dictionary, key: String) -> float:
	var v = item.get(key)
	return float(v) if v is int or v is float else 0.0


static func _format(value: float, unit: String, signed: bool) -> String:
	var prefix := ""
	if signed:
		prefix = "+" if value >= 0 else MINUS
	if unit == "%":
		return prefix + BattleStats.format_chance(absf(value) if signed else value)
	return prefix + Fmt.thousands(int(absf(value)) if signed else int(value))


## 1000 → "+1.000", -55 → "−55".
static func _signed(n: int) -> String:
	return ("+" if n >= 0 else MINUS) + Fmt.thousands(absi(n))


## What `points` of a stat are in battle (points × its multiplier), or null when the stat has no
## multiplier (crit) or `mult` (BattleStats.multipliers) does not know it.
static func converted(points: float, point: String, mult: Dictionary) -> Variant:
	if point == "" or not mult.has(point):
		return null
	return int(points) * int(mult[point])


## "+20 điểm (+40)", "+3.020 điểm (+6.040)", "+20 điểm" without the multiplier, "+2%" for crit.
static func points_text(points: float, s: Dictionary, mult: Dictionary) -> String:
	if s["unit"] == "%":
		return _format(points, "%", true)
	var t := "%s điểm" % _signed(int(points))
	var c = converted(points, s["point"], mult)
	return t if c == null else "%s (%s)" % [t, _signed(c)]


## The item's non-zero stats: [{key, label, value (points), battle (points × multiplier, or
## null), text: "+20 điểm (+40)" / "+20 điểm" / "+2%"}]. `mult`: BattleStats.multipliers.
static func stat_lines(item: Dictionary, mult: Dictionary = {}) -> Array:
	var out: Array = []
	for s in STATS:
		var v := _num(item, s["key"])
		if v != 0.0:
			out.append({"key": s["key"], "label": s["label"], "value": v, "battle": converted(v, s["point"], mult),
				"text": points_text(v, s, mult)})
	return out


## "Máu +30 điểm (+60) · Phòng thủ +3 điểm (+3)"
static func stat_summary(item: Dictionary, mult: Dictionary = {}) -> String:
	return " · ".join(stat_lines(item, mult).map(func(l): return "%s %s" % [l["label"], l["text"]]))


## Per-stat change from wearing `candidate` instead of `worn` ({} = the slot is empty), the
## stats either of them has: [{key, label, delta (points), text, tone: "good" | "loss" | ""}].
## text is the battle change with the points, "+85 (+17 điểm)" / "−6.040 (−3.020 điểm)"; "+17
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
## (stats.fromEquipment), ["Máu +80 điểm (+160)", "Sát thương +10 điểm (+50)", "Chí mạng
## +2%"]; only the battle value ("Máu +160") from a server without equipmentPoints.
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


## What selling an item gives back: floor(price × the catalog's sellRate) in the currency it costs
## ({currency, amount}, like price()); amount 0 when it cannot be sold (crafted or unknown items
## cost nothing, or the share rounds down to 0).
static func sell_price(item: Dictionary, catalog: Variant) -> Dictionary:
	var rate := parse_sell_rate(catalog.get("sellRate") if catalog is Dictionary else null)
	var p := price(item)
	# + 1e-9 like the server (equipment/logic.go), so 0.29 × 100 is 29, not 28.
	return {"currency": p["currency"], "amount": maxi(int(floor(float(p["amount"]) * rate + 1e-9)), 0)}


## "62 xu", "1.250 kim cương".
static func amount_text(p: Dictionary) -> String:
	return "%s %s" % [Fmt.thousands(int(p["amount"])), "kim cương" if p["currency"] == "gem" else "xu"]


## "Mua Bazooka Sắt với giá 500 xu?"
static func confirm_text(item: Dictionary) -> String:
	var p := price(item)
	return "Mua %s với giá %s %s?" % [display_name(item), Fmt.thousands(p["amount"]), "kim cương" if p["currency"] == "gem" else "xu"]


## "Đã có 2", or "" when none is owned.
static func owned_text(n: int) -> String:
	return "Đã có %d" % n if n > 0 else ""
