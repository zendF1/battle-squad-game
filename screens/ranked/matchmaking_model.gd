extends RefCounted
## The matchmaking screen without UI: the four card slots (my team on the left, me first; the
## enemies on the right) from a MatchFound payload ({roomId, matchId, mapId, mode, teams:
## [{teamId, players: [{playerId, displayName, characterId, isBot, level, rating, tier,
## division, titleId}]}]}) or, from a server that sends no teams, from MatchStarted's players;
## the order the cards flip in; and my own card while searching.

const RankModel := preload("res://screens/ranked/rank_model.gd")

const SLOTS := 4
const TEAM_SIZE := 2
## Seconds between two cards flipping, and how long "Tìm thấy trận!" shows at least before the
## match (counted from MatchFound).
const FLIP_GAP := 0.45
const REVEAL_SEC := 2.6


static func _num(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float else fallback


static func _str(v: Variant, fallback: String = "") -> String:
	return str(v) if v is String and str(v) != "" else fallback


## A card's player: {playerId, displayName, characterId, isBot, level (0 unknown), rating (-1
## unknown), tier ("" unknown), division, titleId}; {} for anything that is not a player.
static func parse_player(p: Variant) -> Dictionary:
	if not p is Dictionary or _str(p.get("playerId")) == "":
		return {}
	var id := _str(p.get("playerId"))
	var is_bot: bool = p.get("isBot") if p.get("isBot") is bool else id.begins_with("bot_")
	var rating := _num(p.get("rating"), -1)
	var tier := _str(p.get("tier"))
	var division := _num(p.get("division"), 0)
	if RankModel.tier_index(tier) < 0:
		tier = ""
		if rating >= 0:
			var r := RankModel.of_rating(rating)
			tier = r[0]
			division = r[1]
	return {"playerId": id, "displayName": _str(p.get("displayName"), "Bot" if is_bot else id.left(8)),
		"characterId": _str(p.get("characterId"), "rookie"), "isBot": is_bot, "level": _num(p.get("level"), 0),
		"rating": rating, "tier": tier, "division": clampi(division, 0, 3), "titleId": _str(p.get("titleId")),
		"teamId": _num(p.get("teamId"), 0)}


## MatchFound's teams as {teamId: [player, ...]}; {} when it has none (an older server).
static func teams_of_found(data: Variant) -> Dictionary:
	var out := {}
	if not data is Dictionary or not data.get("teams") is Array:
		return out
	for t in data["teams"]:
		if not t is Dictionary or not t.get("players") is Array:
			continue
		var team := _num(t.get("teamId"), 0)
		var players: Array = []
		for p in t["players"]:
			var parsed := parse_player(p)
			if not parsed.is_empty():
				parsed["teamId"] = team
				players.append(parsed)
		out[team] = players
	return out


## MatchStarted's players ({playerId: BattlePlayerState}) as teams, in turn order when given.
static func teams_of_started(data: Variant) -> Dictionary:
	var out := {}
	if not data is Dictionary or not data.get("players") is Dictionary:
		return out
	var ids: Array = data["players"].keys()
	ids.sort()
	for p in ids:
		var parsed := parse_player(data["players"][p])
		if parsed.is_empty():
			continue
		if not out.has(parsed["teamId"]):
			out[parsed["teamId"]] = []
		out[parsed["teamId"]].append(parsed)
	return out


## The four slots, left to right: my team (me first, then my teammate), then the other team;
## an empty slot is {}. Without me in any team the first team is mine.
static func slots(teams: Dictionary, me: String) -> Array:
	var mine := -1
	for team in teams:
		for p in teams[team]:
			if p["playerId"] == me:
				mine = team
	var keys: Array = teams.keys()
	keys.sort()
	if mine < 0 and not keys.is_empty():
		mine = keys[0]
	var left: Array = teams.get(mine, []).duplicate()
	left.sort_custom(func(a, b): return a["playerId"] == me and b["playerId"] != me)
	var right: Array = []
	for team in keys:
		if team != mine:
			right.append_array(teams[team])
	return _pad(left) + _pad(right)


static func _pad(players: Array) -> Array:
	var out: Array = players.slice(0, TEAM_SIZE)
	while out.size() < TEAM_SIZE:
		out.append({})
	return out


## The slots that flip at MatchFound, in order: every filled slot but mine (slot 0 is mine
## while searching), left to right.
static func reveal_order(found_slots: Array, me: String) -> Array:
	var out: Array = []
	for i in found_slots.size():
		var p: Dictionary = found_slots[i]
		if not p.is_empty() and p["playerId"] != me:
			out.append(i)
	return out


## My card while searching: name, character and level from the profile, the rank from GET
## /rank/me (PlayerState.my_rank(), {} when not loaded: the defaults).
static func my_player(me: String, display_name: String, character_id: String, level: int, rank_data: Variant) -> Dictionary:
	var rank := RankModel.from_me(rank_data)
	return {"playerId": me, "displayName": display_name, "characterId": character_id, "isBot": false,
		"level": level, "rating": rank["rating"], "tier": rank["tier"], "division": rank["division"], "titleId": "", "teamId": 0}


## The line under a card's name: "Lv.40" (with " · Máy" for a bot); "" with neither.
static func level_text(p: Dictionary) -> String:
	var parts := PackedStringArray()
	if int(p.get("level", 0)) > 0:
		parts.append("Lv.%d" % p["level"])
	if p.get("isBot", false):
		parts.append("Máy")
	return " · ".join(parts)


## The rank line of a card: "Bạc II" (or "" when unknown).
static func rank_text(p: Dictionary) -> String:
	var tier := str(p.get("tier", ""))
	return RankModel.label(tier, int(p.get("division", 0))) if tier != "" else ""
