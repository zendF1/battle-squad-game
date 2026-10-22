extends RefCounted
## The end-of-match screen without UI (match/result_screen.gd): the outcome and its title, who
## stands where (the winners on the left, on the podium; a draw puts my team left), the MVP, each
## player's labels, my rewards (EXP bar steps, coins, level ups, the ranked rating line) and the
## buttons' texts.

const RankModel := preload("res://screens/ranked/rank_model.gd")
const TitleModel := preload("res://screens/home/title_model.gd")
const Fmt := preload("res://core/fmt.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const WIN := "win"
const LOSE := "lose"
const DRAW := "draw"
const AUTO_EXIT_SEC := 20


static func outcome(my_team: int, winning_team: int) -> String:
	if winning_team == 0:
		return DRAW
	return WIN if winning_team == my_team else LOSE


static func title_text(result: String) -> String:
	match result:
		WIN: return "CHIẾN THẮNG"
		LOSE: return "THẤT BẠI"
	return "HOÀ"


## The players' ids as {left, right}: the winning team left (a draw: my team), each side with me
## first, then by id.
static func sides(players: Dictionary, me: String, winning_team: int) -> Dictionary:
	var my_team := int(players.get(me, {}).get("teamId", 1))
	var left_team := winning_team if winning_team != 0 else my_team
	var left: Array = []
	var right: Array = []
	var ids: Array = players.keys()
	ids.sort()
	for id in ids:
		if int(players[id].get("teamId", 0)) == left_team:
			left.append(id)
		else:
			right.append(id)
	for side in [left, right]:
		if side.has(me):
			side.erase(me)
			side.push_front(me)
	return {"left": left, "right": right}


static func _num(v: Variant) -> float:
	return float(v) if v is int or v is float else -1.0


## The MVP: MatchEnded's mvpPlayerId when it is a player of the match, else the most damage dealt
## (MatchEnded's stats[id].damageDealt, else `tally` {id: damage} counted by the client); the first
## in `order` wins a tie; "" when nobody dealt any.
static func mvp(players: Dictionary, order: Array, stats: Variant, mvp_id: Variant, tally: Dictionary) -> String:
	if mvp_id is String and players.has(mvp_id):
		return mvp_id
	var best := ""
	var best_damage := 0.0
	for id in order:
		var d := -1.0
		if stats is Dictionary and stats.get(id) is Dictionary:
			d = _num(stats[id].get("damageDealt"))
		if d < 0.0:
			d = _num(tally.get(id, 0))
		if d > best_damage:
			best = id
			best_damage = d
	return best


## The damage a player dealt, from MatchEnded's stats or the client's tally; -1 when unknown.
static func damage_of(id: String, stats: Variant, tally: Dictionary) -> int:
	if stats is Dictionary and stats.get(id) is Dictionary:
		var d := _num(stats[id].get("damageDealt"))
		if d >= 0.0:
			return int(d)
	return int(tally[id]) if tally.has(id) else -1


## One player's labels: {playerId, displayName, characterId, teamId, isBot, mine, title, tier,
## division, level, damage}. `roster` is the MatchFound entry (MatchmakingModel.parse_player, {} if
## none: level and rank); for me `my_level` and `my_rank` (GET /rank/me, {} unknown) fill the gaps.
static func entry(id: String, p: Dictionary, roster: Dictionary, me: String, my_level: int, my_rank: Dictionary,
		damage: int) -> Dictionary:
	var mine := id == me
	var tier := str(roster.get("tier", ""))
	var division := int(roster.get("division", 0))
	var level := int(roster.get("level", 0))
	if mine:
		if tier == "" and not my_rank.is_empty():
			var r := RankModel.from_me(my_rank)
			tier = r["tier"]
			division = r["division"]
		if level <= 0:
			level = my_level
	var is_bot: bool = p.get("isBot") if p.get("isBot") is bool else id.begins_with("bot_")
	return {"playerId": id, "displayName": str(p.get("displayName", roster.get("displayName", id))),
		"characterId": str(p.get("characterId", roster.get("characterId", GameData.default_character_id()))), "teamId": int(p.get("teamId", 0)),
		"isBot": is_bot, "mine": mine, "title": TitleModel.from_player(p), "tier": tier, "division": division,
		"level": level, "damage": damage}


## "Lv.40" (" · Máy" for a bot), "" without a level (a Quick Play bot: its name says it).
static func level_text(e: Dictionary) -> String:
	if int(e["level"]) <= 0:
		return ""
	return "Lv.%d · Máy" % e["level"] if e["isBot"] else "Lv.%d" % e["level"]


## "Sát thương 1.240", "" when unknown.
static func damage_text(damage: int) -> String:
	return "Sát thương %s" % Fmt.thousands(damage) if damage >= 0 else ""


## My rewards from MatchEnded.rewards[me] (null: granting failed) for a match in `mode`:
## {ok, exp, coin, level_up, new_level, char_level_up, char_level, rank (RankModel.result_of)}.
static func reward(r: Variant, mode: String) -> Dictionary:
	if not r is Dictionary:
		return {"ok": false, "exp": 0, "coin": 0, "level_up": false, "new_level": 0, "char_level_up": false,
			"char_level": 0, "rank": {}}
	return {"ok": true, "exp": int(_num(r.get("expGained"))) if _num(r.get("expGained")) > 0 else 0,
		"coin": int(_num(r.get("coinGained"))) if _num(r.get("coinGained")) > 0 else 0,
		"level_up": r.get("levelUp") is bool and r["levelUp"], "new_level": maxi(0, int(_num(r.get("newLevel")))),
		"char_level_up": r.get("charLevelUp") is bool and r["charLevelUp"], "char_level": maxi(0, int(_num(r.get("charNewLevel")))),
		"rank": RankModel.result_of(mode, r)}


## The EXP bar from (level, exp within it) plus `gained` (a level needs level × expPerLevel, as
## screens/home/progress.gd): {from, to (ratios), levels (levels gained), level (the new one)}.
## `to` is in the last level reached.
static func exp_steps(level: int, level_exp: int, gained: int) -> Dictionary:
	var per := GameData.player_exp_per_level()
	var lv := maxi(level, 1)
	if per <= 0:
		return {"from": 0.0, "to": 0.0, "levels": 0, "level": lv}
	var e := clampi(level_exp, 0, lv * per)
	var from := float(e) / (lv * per)
	var left := maxi(gained, 0)
	var levels := 0
	while e + left >= lv * per and levels < 100:
		left -= lv * per - e
		lv += 1
		levels += 1
		e = 0
	e += left
	return {"from": from, "to": float(e) / (lv * per), "levels": levels, "level": lv}


## The second button: "Chơi tiếp" (ranked: straight back into the queue), "Chơi lại" (a Quick
## Play match again), "" none.
static func again_text(mode: String, can_replay: bool) -> String:
	if RankModel.is_ranked_mode(mode):
		return "Chơi tiếp"
	return "Chơi lại" if can_replay else ""


static func countdown_text(seconds: int) -> String:
	return "Tự động về sảnh sau %d giây" % maxi(seconds, 0)
