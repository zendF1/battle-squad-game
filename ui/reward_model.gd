extends RefCounted
## Rewards without UI, for the one reward effect (ui/reward_reveal.gd) and the reward tiles
## (ui/reward_strip.gd): every reward as a tile {kind, id, level, upgrade, locked, qty, name} —
## kind "coin", "gem" (locked: kim cương khoá), "stone" (level), "chest" (id), "item" (a battle
## item id), "equipment" (an item id of the catalog, upgrade +N), "character" (id); name is only
## the tooltip, never drawn. Built from every answer that grants something (POST /chests/open,
## milestone / daily reward lines, a season reward, a match's reward, a shop purchase), merged
## (same reward → one tile, the counts added) and ordered weakest first so the reveal ends on the
## best one. glow() is the light behind a tile: its colour (and a second one for the richest) and
## power 0..1 (brightness, rays, sparkles), by stone level, upgrade tier or kind.

const GameData := preload("res://autoload/game_data_model.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const Items := preload("res://match/items.gd")
const Fmt := preload("res://core/fmt.gd")

const KINDS := ["coin", "gem", "item", "stone", "chest", "equipment", "character"]

## The glow rungs, weakest first: plain, green, blue, purple, gold, red-gold.
const PLAIN := 0
const GREEN := 1
const BLUE := 2
const PURPLE := 3
const GOLD := 4
const RED_GOLD := 5
const RUNGS := [
	{"color": Color(0.72, 0.84, 1.0), "accent": Color(0.9, 0.95, 1.0), "power": 0.3},
	{"color": Color(0.3, 0.95, 0.5), "accent": Color(0.7, 1.0, 0.75), "power": 0.45},
	{"color": Color(0.32, 0.68, 1.0), "accent": Color(0.7, 0.9, 1.0), "power": 0.55},
	{"color": Color(0.72, 0.38, 1.0), "accent": Color(0.9, 0.72, 1.0), "power": 0.72},
	{"color": Color(1.0, 0.76, 0.2), "accent": Color(1.0, 0.95, 0.6), "power": 0.86},
	{"color": Color(1.0, 0.28, 0.14), "accent": Color(1.0, 0.82, 0.3), "power": 1.0},
]
## The rung of each stone level (index = level; past the end: the last): lv 5–6 gold, 7 and up
## red-gold.
const STONE_RUNGS := [PLAIN, PLAIN, PLAIN, GREEN, BLUE, GOLD, GOLD, RED_GOLD]
## The power of an equipment piece by its colour tier (UpgradeModel.color_tier: +0, +1, +6, +10,
## +14, +16); its colour is the tier's (UpgradeModel.TIER_COLORS), +16 red with gold.
const TIER_POWER := [0.3, 0.45, 0.55, 0.66, 0.8, 1.0]


static func _num(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


static func _str(v: Variant) -> String:
	return str(v) if v is String else ""


## One tile; qty below 1 is still a tile (merge() drops it).
static func tile(kind: String, id: String, qty: int, level: int = 0, upgrade: int = 0, locked: bool = false) -> Dictionary:
	var t := {"kind": kind, "id": id, "level": level, "upgrade": upgrade, "locked": locked, "qty": qty}
	t["name"] = name_of(t)
	return t


## The tooltip of a tile: "Xu", "Kim cương khoá", "Đá cấp 5", the chest's / item's / character's
## name from the game data, an equipment piece's id (the catalog names it: EquipmentModel).
static func name_of(t: Dictionary) -> String:
	match str(t.get("kind", "")):
		"coin": return "Xu"
		"gem": return "Kim cương khoá" if t.get("locked", false) else "Kim cương"
		"stone": return UpgradeModel.stone_name(int(t.get("level", 1)))
		"chest": return GameData.chest_name(str(t.get("id", "")))
		"item": return Items.label(str(t.get("id", "")))
		"character": return GameData.character_name(str(t.get("id", "")))
		"equipment":
			var up := int(t.get("upgrade", 0))
			return "%s +%d" % [str(t.get("id", "")), up] if up > 0 else str(t.get("id", ""))
	return str(t.get("id", ""))


## The key two tiles of one reward share.
static func key(t: Dictionary) -> String:
	return "%s|%s|%d|%d|%s" % [t.get("kind", ""), t.get("id", ""), int(t.get("level", 0)), int(t.get("upgrade", 0)), str(t.get("locked", false))]


## Tiles of the same reward merged (counts added, the first one's place), qty < 1 dropped, then
## ordered weakest first (sort()).
static func merge(tiles: Array) -> Array:
	var by := {}
	var out: Array = []
	for t in tiles:
		if not t is Dictionary or int(t.get("qty", 0)) <= 0 or not KINDS.has(str(t.get("kind", ""))):
			continue
		var k := key(t)
		if by.has(k):
			by[k]["qty"] = int(by[k]["qty"]) + int(t["qty"])
		else:
			var c: Dictionary = t.duplicate()
			for f in ["level", "upgrade"]:
				c[f] = int(c.get(f, 0))
			c["locked"] = bool(c.get("locked", false))
			if not c.has("name"):
				c["name"] = name_of(c)
			by[k] = c
			out.append(c)
	return sort(out)


## Weakest first: by glow power, then kind (KINDS), level / upgrade, id; the reveal ends on the
## best reward.
static func sort(tiles: Array) -> Array:
	var out := tiles.duplicate()
	out.sort_custom(func(a, b):
		var pa := float(glow(a)["power"])
		var pb := float(glow(b)["power"])
		if not is_equal_approx(pa, pb):
			return pa < pb
		var ka := KINDS.find(str(a["kind"]))
		var kb := KINDS.find(str(b["kind"]))
		if ka != kb:
			return ka < kb
		var la := int(a.get("level", 0)) + int(a.get("upgrade", 0))
		var lb := int(b.get("level", 0)) + int(b.get("upgrade", 0))
		if la != lb:
			return la < lb
		return str(a["id"]) < str(b["id"]))
	return out


# ── Glow ────────────────────────────────────────────────────────────────────

## The light behind a tile: {color, accent (the rays' second colour), power 0..1, rung (the
## RUNGS index nearest, for a chest's leaking light)}.
static func glow(t: Dictionary) -> Dictionary:
	match str(t.get("kind", "")):
		"coin":
			return _rung(GOLD, 0.36)
		"gem":
			return {"color": Color(0.5, 0.62, 1.0), "accent": Color(0.85, 0.75, 1.0), "power": 0.6, "rung": BLUE}
		"item":
			return {"color": Color(0.36, 0.92, 0.82), "accent": Color(0.8, 1.0, 0.95), "power": 0.42, "rung": GREEN}
		"stone":
			return _rung(stone_rung(int(t.get("level", 1))))
		"chest":
			var up := GameData.chest_upgrade_level(str(t.get("id", "")))
			return equipment_glow(up) if up > 0 else _rung(BLUE, 0.58)
		"equipment":
			return equipment_glow(int(t.get("upgrade", 0)))
		"character":
			return _rung(GOLD, 0.9)
	return _rung(PLAIN)


static func _rung(rung: int, power: float = -1.0) -> Dictionary:
	var r: Dictionary = RUNGS[clampi(rung, 0, RUNGS.size() - 1)]
	return {"color": r["color"], "accent": r["accent"], "power": r["power"] if power < 0.0 else power, "rung": rung}


## A stone level's rung (STONE_RUNGS).
static func stone_rung(level: int) -> int:
	return STONE_RUNGS[clampi(level, 0, STONE_RUNGS.size() - 1)]


## An equipment piece's glow at +`upgrade`: its upgrade colour (white at +0: the plain rung), the
## top tier red with gold rays.
static func equipment_glow(upgrade: int) -> Dictionary:
	var t := UpgradeModel.color_tier(upgrade)
	if t == 0:
		return _rung(PLAIN)
	var top := t >= UpgradeModel.TIER_COLORS.size() - 1
	var c: Color = UpgradeModel.TIER_COLORS[t]
	return {"color": RUNGS[RED_GOLD]["color"] if top else c, "accent": RUNGS[RED_GOLD]["accent"] if top else c.lightened(0.45),
		"power": TIER_POWER[mini(t, TIER_POWER.size() - 1)], "rung": RED_GOLD if top else mini(t, PURPLE)}


## The strongest glow among `tiles` (the chest's leaking light, the god rays); plain for none.
static func best_glow(tiles: Array) -> Dictionary:
	var best := _rung(PLAIN)
	for t in tiles:
		var g := glow(t)
		if float(g["power"]) > float(best["power"]):
			best = g
	return best


## "×3", "×1.200".
static func qty_text(qty: int) -> String:
	return "×%s" % Fmt.thousands(qty)


## The pause between two tiles flying out (s): shorter for many, so the whole row lands in about
## 1.5 s at most.
static func stagger(count: int) -> float:
	return clampf(1.5 / maxf(count, 1.0), 0.07, 0.16)


# ── From the answers that grant something ───────────────────────────────────

## ChestModel.parse_open() → the stones then the pieces (each piece one tile, the same item and
## level merged).
static func from_chest_open(result: Dictionary) -> Array:
	var out: Array = []
	for s in result.get("stones", []):
		if s is Dictionary:
			out.append(tile("stone", "stone_%d" % _num(s.get("level")), _num(s.get("qty")), _num(s.get("level"))))
	for e in result.get("equipment", []):
		if e is Dictionary and _str(e.get("itemId")) != "":
			out.append(tile("equipment", _str(e["itemId"]), 1, 0, _num(e.get("upgradeLevel"))))
	return merge(out)


## Reward lines (MilestoneModel.reward_lines / DailyModel.reward_lines) → tiles; a title is not a
## tile (the reveal shows its plate). The gem of a milestone / mission / season is locked gem.
static func from_lines(lines: Array) -> Array:
	var out: Array = []
	for l in lines:
		if not l is Dictionary:
			continue
		var qty := _num(l.get("qty"))
		match str(l.get("kind", "")):
			"coin": out.append(tile("coin", "coin", qty))
			"gem": out.append(tile("gem", "gem", qty, 0, 0, true))
			"stone": out.append(tile("stone", "stone_%d" % _num(l.get("level")), qty, _num(l.get("level"))))
			"item": out.append(tile("item", _str(l.get("id")), qty))
			"chest": out.append(tile("chest", _str(l.get("id")), qty))
	return merge(out)


## A season reward (SeasonRewardModel.parse_one) → its coin, locked gem and items.
static func from_season(r: Dictionary) -> Array:
	var out: Array = [tile("coin", "coin", _num(r.get("coin"))), tile("gem", "gem", _num(r.get("gem")), 0, 0, true)]
	for it in r.get("items", []):
		if not it is Dictionary:
			continue
		var kind := str(it.get("kind", ""))
		var qty := _num(it.get("qty"))
		if kind == "stone":
			out.append(tile("stone", "stone_%d" % _num(it.get("level")), qty, _num(it.get("level"))))
		elif kind in ["chest", "item"] and _str(it.get("id")) != "":
			out.append(tile(kind, _str(it["id"]), qty))
	return merge(out)


## A match's reward (ResultModel.reward_tiles' input, ResultModel.reward()) → its coins, stones,
## chests and items (EXP and rank points stay on the result screen).
static func from_match(reward: Dictionary) -> Array:
	var out: Array = []
	if not reward.get("ok", false):
		return out
	out.append(tile("coin", "coin", _num(reward.get("coin"))))
	for s in reward.get("stones", []):
		out.append(tile("stone", "stone_%d" % _num(s.get("level")), _num(s.get("qty")), _num(s.get("level"))))
	for c in reward.get("chests", []):
		out.append(tile("chest", _str(c.get("chestId")), _num(c.get("qty"))))
	for it in reward.get("items", []):
		out.append(tile("item", _str(it.get("itemId")), _num(it.get("qty"))))
	return merge(out)


## A shop offer bought `quantity` times (POST /shop/purchase's data: quantityGranted wins): a
## battle item ×(offer quantity × quantity), a coin pack's coins, a character.
static func from_offer(offer: Dictionary, quantity: int, data: Variant = null) -> Array:
	var id := _str(offer.get("itemId"))
	var granted := _num(offer.get("quantity")) * maxi(quantity, 1)
	if data is Dictionary and _num(data.get("quantityGranted")) > 0:
		granted = _num(data["quantityGranted"])
	match _str(offer.get("offerType")):
		"coin_pack":
			return merge([tile("coin", "coin", granted)])
		"character_unlock":
			return merge([tile("character", id, 1)])
	return merge([tile("item", id, maxi(granted, 1))]) if id != "" else []
