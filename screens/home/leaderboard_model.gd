extends RefCounted
## "Xếp hạng" (the leaderboards) without UI: GET /leaderboard?type=level|rank|power&limit&offset →
## {type, seasonId?, seasonName?, entries: [entry], me: entry | null, total}, entry {pos, playerId,
## displayName, level, rankBadge, grade, gradeDivision, rankPoints, power, powerCharacterId,
## equippedTitle?, characterId (the character drawn, never "" from a current server), look
## {characterId, weaponItemId, weaponUpgradeLevel} (what the lobby draws: the gun and the back aura;
## docs: the server's docs/contracts/leaderboard-showcase.md)}. The server orders and numbers the rows (pos); the client only shows them: the
## top three on the podium (2nd left, 1st centre, 3rd right), the rest in the list, the caller's
## own row (me) pinned under it. The sorted value is the big one: "Lv.37", "Đại tá 1" + "4.230
## điểm", the power number. Lực chiến (power) is always the server's number (GET /player/characters
## power, GET /player/profile power + powerCharacterId), never computed here.

const Fmt := preload("res://core/fmt.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const TitleModel := preload("res://screens/home/title_model.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")

const LEVEL := "level"
const RANK := "rank"
const POWER := "power"
## The tabs in order: the board, its short name and its glyph (ui/glyph_icon.gd).
const TABS := [
	{"type": LEVEL, "name": "Cấp độ", "glyph": "level"},
	{"type": RANK, "name": "Rank", "glyph": "insignia"},
	{"type": POWER, "name": "Lực chiến", "glyph": "power"},
]
const LIMIT := 50
const PODIUM := 3


static func types() -> Array:
	return TABS.map(func(t): return t["type"])


## The request path of a board ("/leaderboard?type=power&limit=50&offset=0").
static func path(type: String, limit: int = LIMIT, offset: int = 0) -> String:
	return "/leaderboard?type=%s&limit=%d&offset=%d" % [type, limit, offset]


static func _num(v: Variant, fallback: int = 0) -> int:
	return int(v) if v is int or v is float else fallback


static func _str(v: Variant) -> String:
	return str(v) if v is String else ""


## One row → {pos, player_id, name, level, badge (rankBadge, "" none or unknown), grade, division,
## points, power (-1 unknown), power_character, character (characterId, else power_character),
## look (the server's look {characterId, weaponItemId, weaponUpgradeLevel}, {} none), title
## ({id, name, rarity} or {})}; {} when it is not a row (no player id).
static func entry(e: Variant) -> Dictionary:
	if not e is Dictionary or _str(e.get("playerId")) == "":
		return {}
	var points := maxi(_num(e.get("rankPoints")), 0)
	var rank := RankModel._rank_of(e, "grade", "gradeDivision", points)
	return {"pos": _num(e.get("pos")), "player_id": _str(e["playerId"]), "name": _str(e.get("displayName")),
		"level": maxi(_num(e.get("level"), 1), 1), "badge": RankModel.badge_of(e), "grade": rank[0],
		"division": rank[1], "points": points, "power": _num(e.get("power"), -1),
		"power_character": _str(e.get("powerCharacterId")), "character": _character_of(e),
		"look": e.get("look") if e.get("look") is Dictionary else {}, "title": TitleModel.from_profile(e)}


## A row's characterId, else its powerCharacterId (an older server), else its look's character.
static func _character_of(e: Dictionary) -> String:
	for v in [e.get("characterId"), e.get("powerCharacterId")]:
		if _str(v) != "":
			return str(v)
	var look = e.get("look")
	return _str(look.get("characterId")) if look is Dictionary else ""


## A GET /leaderboard data → {type, season_id, season_name, season_ends_at, entries (rows in the
## server's order), me (the caller's row, {} when not on this board), total}; {} when malformed.
static func parse(data: Variant) -> Dictionary:
	if not data is Dictionary or not data.get("entries") is Array:
		return {}
	var rows: Array = []
	for e in data["entries"]:
		var r := entry(e)
		if not r.is_empty():
			rows.append(r)
	return {"type": _str(data.get("type")), "season_id": _str(data.get("seasonId")),
		"season_name": _str(data.get("seasonName")), "season_ends_at": _str(data.get("seasonEndsAt")),
		"entries": rows, "me": entry(data.get("me")), "total": maxi(_num(data.get("total"), rows.size()), 0)}


## The podium's three places left to right: [2nd, 1st, 3rd] ({} for a place nobody holds).
static func podium(entries: Array) -> Array:
	var at := func(i: int) -> Dictionary: return entries[i] if i < entries.size() else {}
	return [at.call(1), at.call(0), at.call(2)]


## The rows under the podium (4th on).
static func list_rows(entries: Array) -> Array:
	return entries.slice(PODIUM)


## The podium place shown at podium() index i: 2, 1, 3.
static func podium_place(i: int) -> int:
	return [2, 1, 3][clampi(i, 0, 2)]


## Lực chiến as shown: 12345 → "12.345"; "—" when unknown (an older server, a character not owned).
static func power_text(power: int) -> String:
	return Fmt.thousands(power) if power >= 0 else "—"


## A row's sorted value, the big text: level "Lv.37", rank "Đại tá 1", power "12.345".
static func value_text(type: String, e: Dictionary) -> String:
	if e.is_empty():
		return ""
	match type:
		LEVEL:
			return "Lv.%d" % int(e["level"])
		RANK:
			return RankModel.label(str(e["grade"]), int(e["division"]))
		POWER:
			return power_text(int(e["power"]))
	return ""


## The small line under the value: the rank's points ("4.230 điểm"); "" for the other boards.
static func sub_text(type: String, e: Dictionary) -> String:
	if type == RANK and not e.is_empty():
		return RankModel.points_text(int(e["points"]))
	return ""


## "#12" (a position), "—" unknown.
static func pos_text(pos: int) -> String:
	return "#%s" % Fmt.thousands(pos) if pos > 0 else "—"


## The pinned row when I am not on the board: "Chưa có hạng" (rank: no ranked match this season).
static func not_ranked_text(type: String) -> String:
	return "Chưa đấu hạng mùa này" if type == RANK else "Chưa có hạng"


## The rank tab's season chip: "Mùa 1 · 30/11" (the end date in the zone bias_minutes east of UTC);
## the name alone without a date, "" without either. `ends_at` falls back to the board's own.
static func season_text(parsed: Dictionary, ends_at: String, bias_minutes: int) -> String:
	var season_name := _str(parsed.get("season_name"))
	var end := _str(parsed.get("season_ends_at"))
	if end == "":
		end = ends_at
	var date := Fmt.short_date(end, bias_minutes).substr(0, 5)
	if season_name == "":
		return date
	return season_name if date == "" else "%s · %s" % [season_name, date]


## A row is the signed-in player's.
static func is_me(e: Dictionary, player_id: String) -> bool:
	return not e.is_empty() and player_id != "" and e["player_id"] == player_id


## The character whose head a row shows: the server's characterId (power_character from an
## older server), else `fallback`.
static func head_character(e: Dictionary, fallback: String = "") -> String:
	var c := _str(e.get("character"))
	if c == "":
		c = _str(e.get("power_character"))
	return c if c != "" else fallback


## What player_figure.gd draws for a row ({} for an empty place): {character_id, gun: {kind, tier}
## (the look's weaponItemId through the catalog, EquipmentModel.player_gun(); the character's basic
## gun without one), aura_level (weaponUpgradeLevel: the back aura)}. A look of another character
## than the row's is not used (the basic gun then).
static func look(e: Dictionary, catalog: Variant = null) -> Dictionary:
	var id := head_character(e)
	if e.is_empty() or id == "":
		return {}
	var raw = e.get("look")
	var lk: Dictionary = raw if raw is Dictionary and _str(raw.get("characterId")) in ["", id] else {}
	return look_of(id, lk, catalog)


## The figure of character `id` wearing look `lk` ({characterId, weaponItemId, weaponUpgradeLevel}).
static func look_of(id: String, lk: Dictionary, catalog: Variant = null) -> Dictionary:
	var player := lk.duplicate()
	player["characterId"] = id
	return {"character_id": id, "gun": EquipmentModel.player_gun(player, catalog),
		"aura_level": EquipmentModel.player_weapon_level(player)}
