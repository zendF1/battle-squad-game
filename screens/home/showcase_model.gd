extends RefCounted
## A player's showcase (a tap on a leaderboard podium place or row) without UI:
## GET /players/{playerId}/showcase?characterId= (the server's docs/contracts/leaderboard-showcase.md)
## → {playerId, displayName, level, rankBadge, grade, gradeDivision, rankPoints, power,
## powerCharacterId, equippedTitle?, character: {characterId, level, power, look, equipment:
## [piece {equipmentId, itemId, name, slot, category, tier?, upgradeLevel, gems: [{slotIndex,
## gemType, gemLevel}]}], statPoints {hp, damage, mobility, defense, skillPower, terrainDamage},
## stats (as GET /player/characters)}, characters: [{characterId, level, power}]}. Everything shown
## is the server's: the stats are its final numbers, never recomputed here.

const RankModel := preload("res://screens/ranked/rank_model.gd")
const TitleModel := preload("res://screens/home/title_model.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const Fmt := preload("res://core/fmt.gd")
const LeaderboardModel := preload("res://screens/home/leaderboard_model.gd")

## The stat cells in order: the stats key, the statPoints key and the picture (ui/glyph_icon.gd).
## Two columns of three, mirrored: Máu / Sát thương / Phòng thủ (the lobby card's three) left,
## the movement, skill and terrain ones right.
const STATS := [
	{"key": "maxHp", "point": "hp", "glyph": "heart"},
	{"key": "damageBonus", "point": "damage", "glyph": "sword"},
	{"key": "defense", "point": "defense", "glyph": "shield"},
	{"key": "moveEnergy", "point": "mobility", "glyph": "boot"},
	{"key": "skillPowerBonus", "point": "skillPower", "glyph": "magic"},
	{"key": "terrainDamageBonus", "point": "terrainDamage", "glyph": "terrain"},
]
## A socketed gem's colour by gemType (a visual mapping by id).
const GEM_COLORS := {
	"hp": Color(1.0, 0.32, 0.38), "damage": Color(1.0, 0.6, 0.15), "defense": Color(0.3, 0.6, 1.0),
	"critical": Color(0.78, 0.4, 1.0),
}
const GEM_UNKNOWN := Color(0.7, 0.75, 0.85)


## The request path: "/players/<id>/showcase" (their power character), "?characterId=<c>" for another.
static func path(player_id: String, character_id: String = "") -> String:
	var p := "/players/%s/showcase" % player_id.uri_encode()
	return p + ("?characterId=%s" % character_id.uri_encode() if character_id != "" else "")


static func _num(v: Variant, fallback: int = 0) -> int:
	return int(v) if v is int or v is float else fallback


static func _str(v: Variant) -> String:
	return str(v) if v is String else ""


## The response data → {player_id, name, level, badge, grade, division, points, power, title,
## character: character(), characters: [{id, level, power}]}; {} when malformed (no player id or
## no character).
static func parse(data: Variant) -> Dictionary:
	if not data is Dictionary or _str(data.get("playerId")) == "":
		return {}
	var c := character(data.get("character"))
	if c.is_empty():
		return {}
	var points := maxi(_num(data.get("rankPoints")), 0)
	var rank := RankModel._rank_of(data, "grade", "gradeDivision", points)
	var owned: Array = []
	if data.get("characters") is Array:
		for o in data["characters"]:
			if o is Dictionary and _str(o.get("characterId")) != "":
				owned.append({"id": str(o["characterId"]), "level": maxi(_num(o.get("level"), 1), 1), "power": _num(o.get("power"), -1)})
	if owned.filter(func(o): return o["id"] == c["id"]).is_empty():
		owned.append({"id": c["id"], "level": c["level"], "power": c["power"]})
	return {"player_id": str(data["playerId"]), "name": _str(data.get("displayName")),
		"level": maxi(_num(data.get("level"), 1), 1), "badge": RankModel.badge_of(data), "grade": rank[0],
		"division": rank[1], "points": points, "power": _num(data.get("power"), -1),
		"title": TitleModel.from_profile(data), "character": c, "characters": owned}


## The shown character → {id, level, power (-1 unknown), look (the server's), equipment (pieces
## by slot id), points (statPoints key -> int), stats (BattleStats.parse: {} without)}; {} without
## a characterId.
static func character(c: Variant) -> Dictionary:
	if not c is Dictionary or _str(c.get("characterId")) == "":
		return {}
	var by_slot := {}
	if c.get("equipment") is Array:
		for p in c["equipment"]:
			if p is Dictionary and _str(p.get("slot")) != "" and _str(p.get("itemId")) != "":
				by_slot[str(p["slot"])] = p
	var points := {}
	var sp = c.get("statPoints")
	for k in BattleStats.POINT_KEYS:
		points[k] = maxi(_num(sp.get(k)), 0) if sp is Dictionary else 0
	return {"id": str(c["characterId"]), "level": maxi(_num(c.get("level"), 1), 1), "power": _num(c.get("power"), -1),
		"look": c.get("look") if c.get("look") is Dictionary else {}, "equipment": by_slot, "points": points,
		"stats": BattleStats.parse(c.get("stats"))}


## The stat cells of a character(): [{key, glyph, value (the final stat as shown), points (the
## allocated points)}]; [] without stats. Damage is the weapon's plus the bonus (the lobby
## card's number); the percent stats keep their "%".
static func stat_cells(c: Dictionary) -> Array:
	var stats: Dictionary = c.get("stats", {})
	if stats.is_empty():
		return []
	var units := {}
	for r in BattleStats.ROWS:
		units[r["key"]] = r["unit"]
	var out := []
	for s in STATS:
		var key: String = s["key"]
		var value := ""
		if key == "damageBonus":
			var w = stats.get("weaponDamage")
			value = Fmt.thousands(int(stats[key]) + (int(w) if w is int or w is float else 0))
		else:
			value = BattleStats.format(int(stats[key]), "%" if units.get(key) == "%" else "")
		out.append({"key": key, "glyph": s["glyph"], "value": value, "points": int(c.get("points", {}).get(s["point"], 0))})
	return out


## The crit chance as shown ("12%"), "" when none.
static func crit_text(c: Dictionary) -> String:
	var row := BattleStats.crit(c.get("stats", {}))
	return str(row.get("value", ""))


## A piece's gems in socket order: [{type, level, color}].
static func gems(piece: Dictionary) -> Array:
	var out := []
	var raw = piece.get("gems")
	if not raw is Array:
		return out
	var sorted: Array = raw.filter(func(g): return g is Dictionary)
	sorted.sort_custom(func(a, b): return _num(a.get("slotIndex")) < _num(b.get("slotIndex")))
	for g in sorted:
		var t := _str(g.get("gemType"))
		out.append({"type": t, "level": maxi(_num(g.get("gemLevel"), 1), 1), "color": GEM_COLORS.get(t, GEM_UNKNOWN)})
	return out


## "+N" of a piece ("" at +0: nothing to tell).
static func upgrade_text(piece: Dictionary) -> String:
	var n := _num(piece.get("upgradeLevel"))
	return "+%d" % n if n > 0 else ""


## The figure (player_figure.gd) of the shown character.
static func look(c: Dictionary, catalog: Variant = null) -> Dictionary:
	return LeaderboardModel.look_of(str(c.get("id", "")), c.get("look", {}), catalog)
