extends RefCounted
## Ngọc khảm (socketable gems) without UI, for the piece popup's slots, Kho đồ › Ngọc, Shop › Ngọc
## and Nâng cấp › Ghép ngọc (the server's docs/contracts/gem-socket.md). In JSON "gem" alone
## (priceGem, gemBalance) is kim cương; a ngọc is gemType / gemLevel / gemId / gemSlots.
##
## Every number is the server's: the catalog's gems ([{gemType, gemLevel, statValue, priceCoin,
## priceGem}], EquipmentModel.parse_gem_rows()) give the stats, the prices, the types and levels
## that exist (the highest level is the merge cap); a piece's socket count is its catalog item's
## gemSlots; merges take the game data's mergeMinCount..mergeMaxCount gems at the catalog's
## mergeRatePerItem % each (UpgradeModel.merge_chance). An older server sends no catalog gems:
## has_catalog() is false, so no shop and no merge, the gems still show and socket.
##
## The owned gems (GET /player/gems: [{gemId, gemType, gemLevel, socketedIn?: {equipmentId,
## slotIndex}}]) parse to [{gemId, gemType, gemLevel, socketedIn: {} | {equipmentId, slotIndex}}];
## with_pieces() fills socketedIn from the pieces for an older server (its pieces only have
## gemSlot1 / gemSlot2, the gem ids). A piece's socketed gems: its `gems` ([{slotIndex, gemId,
## gemType, gemLevel}]), else gemSlot1 / gemSlot2 looked up in the owned gems.
##
## The look by type id (a visual mapping): each type its colour and its own cut (ui/gem_icon.gd),
## and the stat picture of what it gives (ui/glyph_icon.gd).

const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const Fmt := preload("res://core/fmt.gd")

## hp green, damage red, defense blue, critical yellow.
const COLORS := {
	"hp": Color(0.3, 0.9, 0.42), "damage": Color(1.0, 0.3, 0.28), "defense": Color(0.32, 0.6, 1.0),
	"critical": Color(1.0, 0.84, 0.2),
}
const UNKNOWN := Color(0.7, 0.75, 0.85)
## The stat picture of each type and the statMultipliers key its points convert by ("" = a percent).
const GLYPHS := {"hp": "heart", "damage": "sword", "defense": "shield", "critical": "crit"}
const POINTS := {"hp": "hp", "damage": "damage", "defense": "defense", "critical": ""}
## The order types show in when the catalog does not say (an older server).
const ORDER := ["hp", "damage", "defense", "critical"]


static func _num(v: Variant, fallback: int = 0) -> int:
	return int(v) if v is int or v is float else fallback


static func _str(v: Variant) -> String:
	return str(v) if v is String else ""


static func color(gem_type: String) -> Color:
	return COLORS.get(gem_type, UNKNOWN)


static func glyph(gem_type: String) -> String:
	return GLYPHS.get(gem_type, "gem")


# ── Catalog ─────────────────────────────────────────────────────────────────

## The catalog's gem rows ([] from an older server).
static func rows(catalog: Variant) -> Array:
	return catalog["gems"] if catalog is Dictionary and catalog.get("gems") is Array else []


## The server sends the gems (stats, prices): the shop and the merge can show.
static func has_catalog(catalog: Variant) -> bool:
	return not rows(catalog).is_empty()


static func row(catalog: Variant, gem_type: String, level: int) -> Dictionary:
	for r in rows(catalog):
		if r["gemType"] == gem_type and int(r["gemLevel"]) == level:
			return r
	return {}


## The types in the catalog's order (ORDER without a catalog).
static func types(catalog: Variant) -> Array:
	var out: Array = []
	for r in rows(catalog):
		if not out.has(r["gemType"]):
			out.append(r["gemType"])
	return out if not out.is_empty() else ORDER.duplicate()


## A type's levels in the catalog, ascending.
static func levels(catalog: Variant, gem_type: String) -> Array:
	var out: Array = []
	for r in rows(catalog):
		if r["gemType"] == gem_type and not out.has(int(r["gemLevel"])):
			out.append(int(r["gemLevel"]))
	out.sort()
	return out


## The highest level of a type (the merge cap); 0 without a catalog.
static func max_level(catalog: Variant, gem_type: String) -> int:
	var lv := levels(catalog, gem_type)
	return int(lv.back()) if not lv.is_empty() else 0


## {currency: "coin" | "gem", amount}: priceCoin first, else priceGem; amount 0 = not sold.
static func price(r: Dictionary) -> Dictionary:
	var coin := _num(r.get("priceCoin"))
	if coin > 0:
		return {"currency": "coin", "amount": coin}
	return {"currency": "gem", "amount": _num(r.get("priceGem"))}


static func buyable(r: Dictionary) -> bool:
	return not r.is_empty() and int(price(r)["amount"]) > 0


## The rows the shop sells, by type: [{gemType, rows: [row...]}] (types with none left out).
static func shop_rows(catalog: Variant) -> Array:
	var out: Array = []
	for t in types(catalog):
		var sold: Array = rows(catalog).filter(func(r): return r["gemType"] == t and buyable(r))
		if not sold.is_empty():
			out.append({"gemType": t, "rows": sold})
	return out


## Whether `quantity` of a row costs no more than the wallet (coin / kim cương the player can pay).
static func can_afford(r: Dictionary, quantity: int, coin: int, gem: int) -> bool:
	var p := price(r)
	var have := coin if p["currency"] == "coin" else gem
	return int(p["amount"]) > 0 and int(p["amount"]) * quantity <= have


## What a gem gives, as one picture and one number: {glyph, value: "+40" (the points through the
## statMultipliers when known, the points without), "+2%" for critical, color}; {} when the catalog
## does not know it.
static func stat(catalog: Variant, gem_type: String, level: int, mult: Dictionary = {}) -> Dictionary:
	var r := row(catalog, gem_type, level)
	if r.is_empty():
		return {}
	var v := float(r["statValue"])
	var point: String = POINTS.get(gem_type, "")
	var value := ""
	if point == "":
		value = "+" + BattleStats.format_chance(v)
	else:
		var c = EquipmentModel.converted(v, point, mult)
		value = "+" + Fmt.thousands(int(c) if c != null else int(v))
	return {"glyph": glyph(gem_type), "value": value, "color": color(gem_type)}


# ── Owned gems ──────────────────────────────────────────────────────────────

## GET /player/gems → [{gemId, gemType, gemLevel, socketedIn}] ([] for null), or null when malformed.
static func parse_owned(data: Variant) -> Variant:
	if data == null:
		return []
	if not data is Array:
		return null
	var out: Array = []
	for g in data:
		if not g is Dictionary or _str(g.get("gemId")) == "" or _str(g.get("gemType")) == "":
			continue
		var at := {}
		var s = g.get("socketedIn")
		if s is Dictionary and _str(s.get("equipmentId")) != "":
			at = {"equipmentId": str(s["equipmentId"]), "slotIndex": _num(s.get("slotIndex"), 1)}
		out.append({"gemId": str(g["gemId"]), "gemType": str(g["gemType"]), "gemLevel": maxi(_num(g.get("gemLevel"), 1), 1), "socketedIn": at})
	return out


## The gems with socketedIn filled from the pieces where the server left it out (an older server:
## a piece's gemSlot1 / gemSlot2 hold the gem ids). A copy.
static func with_pieces(gems: Variant, equipment: Variant) -> Array:
	var where := {}
	if equipment is Array:
		for p in equipment:
			if not p is Dictionary:
				continue
			for i in [1, 2]:
				var id := _str(p.get("gemSlot%d" % i))
				if id != "":
					where[id] = {"equipmentId": str(p.get("equipmentId", "")), "slotIndex": i}
			if p.get("gems") is Array:
				for g in p["gems"]:
					if g is Dictionary and _str(g.get("gemId")) != "":
						where[str(g["gemId"])] = {"equipmentId": str(p.get("equipmentId", "")), "slotIndex": _num(g.get("slotIndex"), 1)}
	var out: Array = []
	if not gems is Array:
		return out
	for g in gems:
		var c: Dictionary = g.duplicate()
		if (c["socketedIn"] as Dictionary).is_empty() and where.has(c["gemId"]):
			c["socketedIn"] = where[c["gemId"]]
		out.append(c)
	return out


static func find(gems: Variant, gem_id: String) -> Dictionary:
	if gems is Array:
		for g in gems:
			if g["gemId"] == gem_id:
				return g
	return {}


## The socket count of a piece (its catalog item's gemSlots; 0 unknown).
static func slot_count(catalog: Variant, piece: Dictionary) -> int:
	return maxi(_num(EquipmentModel.item_of_piece(catalog, piece).get("gemSlots")), 0)


## The server sends a piece's gems (and swaps a gem in one socket call): docs/contracts/gem-socket.md.
static func swaps_in_one_call(piece: Dictionary) -> bool:
	return piece.get("gems") is Array


## A piece's socketed gems: {slotIndex: {gemId, gemType, gemLevel}} (gemType "" and gemLevel 0
## while an older server's gem id is not among the loaded gems).
static func piece_gems(piece: Dictionary, gems: Variant = null) -> Dictionary:
	var out := {}
	if piece.get("gems") is Array:
		for g in piece["gems"]:
			if g is Dictionary and _num(g.get("slotIndex")) >= 1:
				out[_num(g["slotIndex"])] = {"gemId": _str(g.get("gemId")), "gemType": _str(g.get("gemType")),
					"gemLevel": maxi(_num(g.get("gemLevel"), 1), 1)}
		return out
	for i in [1, 2]:
		var id := _str(piece.get("gemSlot%d" % i))
		if id == "":
			continue
		var g := find(gems, id)
		out[i] = {"gemId": id, "gemType": str(g.get("gemType", "")), "gemLevel": int(g.get("gemLevel", 0))}
	return out


static func _type_rank(gem_type: String, catalog: Variant) -> int:
	var i := types(catalog).find(gem_type)
	return i if i >= 0 else 99


## The free (not socketed) gems grouped by type + level: [{gemType, gemLevel, count, ids}], the
## highest level first, then the type order.
static func free_stacks(gems: Variant, catalog: Variant = null) -> Array:
	var by := {}
	var out: Array = []
	if gems is Array:
		for g in gems:
			if not (g["socketedIn"] as Dictionary).is_empty():
				continue
			var k := "%s|%d" % [g["gemType"], int(g["gemLevel"])]
			if not by.has(k):
				by[k] = {"gemType": g["gemType"], "gemLevel": int(g["gemLevel"]), "count": 0, "ids": []}
				out.append(by[k])
			by[k]["count"] += 1
			by[k]["ids"].append(g["gemId"])
	out.sort_custom(func(a, b):
		if a["gemLevel"] != b["gemLevel"]:
			return a["gemLevel"] > b["gemLevel"]
		return _type_rank(a["gemType"], catalog) < _type_rank(b["gemType"], catalog))
	return out


## The socketed gems, the highest level first: [{gemId, gemType, gemLevel, socketedIn}].
static func socketed(gems: Variant, catalog: Variant = null) -> Array:
	var out: Array = []
	if gems is Array:
		out = gems.filter(func(g): return not (g["socketedIn"] as Dictionary).is_empty())
	out.sort_custom(func(a, b):
		if a["gemLevel"] != b["gemLevel"]:
			return a["gemLevel"] > b["gemLevel"]
		return _type_rank(a["gemType"], catalog) < _type_rank(b["gemType"], catalog))
	return out


static func free_count(gems: Variant, gem_type: String, level: int) -> int:
	var n := 0
	if gems is Array:
		for g in gems:
			if g["gemType"] == gem_type and int(g["gemLevel"]) == level and (g["socketedIn"] as Dictionary).is_empty():
				n += 1
	return n


## A free gem of the type + level ("" none).
static func free_id(gems: Variant, gem_type: String, level: int) -> String:
	if gems is Array:
		for g in gems:
			if g["gemType"] == gem_type and int(g["gemLevel"]) == level and (g["socketedIn"] as Dictionary).is_empty():
				return g["gemId"]
	return ""


# ── Merge ───────────────────────────────────────────────────────────────────

## Whether a gem of the level can merge into the next (the catalog has a higher level of its type).
static func can_merge(catalog: Variant, gem_type: String, level: int) -> bool:
	return level >= 1 and level < max_level(catalog, gem_type)


## Why "GHÉP" is off ("" when it can be pressed).
static func merge_blocked(catalog: Variant, gem_type: String, level: int, count: int, gems: Variant) -> String:
	if not has_catalog(catalog):
		return "Chưa ghép được ngọc"
	if gem_type == "" or level < 1:
		return "Chọn một viên ngọc"
	if not can_merge(catalog, gem_type, level):
		return "Cấp cao nhất"
	if count < UpgradeModel.merge_min() or count > UpgradeModel.merge_max():
		return "Bỏ vào %d–%d viên" % [UpgradeModel.merge_min(), UpgradeModel.merge_max()]
	var have := free_count(gems, gem_type, level)
	if have < count:
		return "Cần %d viên, đang có %d" % [count, have]
	return ""


## POST /merge/gem's answer → {success, gem: {gemType, gemLevel} ({} on a failure or from an older
## server), consumed (-1 unknown)}.
static func parse_merge(data: Variant) -> Dictionary:
	var d: Dictionary = data if data is Dictionary else {}
	var gem := {}
	var g = d.get("gem")
	if g is Dictionary and _str(g.get("gemType")) != "":
		gem = {"gemType": str(g["gemType"]), "gemLevel": maxi(_num(g.get("gemLevel"), 1), 1)}
	return {"success": bool(d.get("success", false)), "gem": gem, "consumed": _num(d.get("consumed"), -1)}


## The gem types / levels the merge page lists: the owned free stacks that can merge, then every
## other catalog level below the cap (none owned), for each type in order. [{gemType, gemLevel, count}]
static func merge_choices(catalog: Variant, gems: Variant) -> Array:
	var out: Array = []
	for t in types(catalog):
		for lv in levels(catalog, t):
			if can_merge(catalog, t, lv):
				out.append({"gemType": t, "gemLevel": lv, "count": free_count(gems, t, lv)})
	return out
