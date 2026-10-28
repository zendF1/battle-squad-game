extends RefCounted
## The end-of-match screen without UI (match/result_screen.gd): the outcome and its title, who
## stands where (the winners on the left, on the podium, the MVP on its top step; a draw puts my
## team left), the MVP, each player's labels (their badge: rankBadge), my rewards (EXP bar steps,
## coins with a ranked match's bonus, stones, chests, the level-up popup's stages, the rank points
## line) and the buttons' texts. A match that gives nothing (QuickPlay vs AI, practice: the server
## sends 0) shows no reward rows.

const RankModel := preload("res://screens/ranked/rank_model.gd")
const ChestModel := preload("res://screens/home/chest_model.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
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


## One player's labels: {playerId, displayName, characterId, teamId, isBot, mine, title, badge
## (rankBadge: the BattlePlayerState's, else the MatchFound entry's; "" none), level, damage}.
## `roster` is the MatchFound entry (MatchmakingModel.parse_player, {} if none: level and badge);
## for me `my_level` and `my_badge` (the profile's rankBadge) fill the gaps.
static func entry(id: String, p: Dictionary, roster: Dictionary, me: String, my_level: int, my_badge: String,
		damage: int) -> Dictionary:
	var mine := id == me
	var badge := RankModel.badge_of(p)
	if badge == "":
		badge = RankModel.badge_of(roster)
	var level := int(roster.get("level", 0))
	if mine:
		if badge == "":
			badge = my_badge if RankModel.grade_index(my_badge) >= 0 else ""
		if level <= 0:
			level = my_level
	var is_bot: bool = p.get("isBot") if p.get("isBot") is bool else id.begins_with("bot_")
	return {"playerId": id, "displayName": str(p.get("displayName", roster.get("displayName", id))),
		"characterId": str(p.get("characterId", roster.get("characterId", GameData.default_character_id()))), "teamId": int(p.get("teamId", 0)),
		"isBot": is_bot, "mine": mine, "title": TitleModel.from_player(p), "badge": badge,
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
## {ok, exp, coin (bonus included), bonus_coin (a ranked match's bonus, inside coin), stones
## [{level, qty}], chests [ChestModel.match_chests()], level_up, new_level, char_level_up,
## char_level, char_gained (levels), rank (RankModel.result_of), empty (granted but nothing: no
## reward rows)}.
static func reward(r: Variant, mode: String) -> Dictionary:
	if not r is Dictionary:
		return {"ok": false, "exp": 0, "coin": 0, "bonus_coin": 0, "stones": [], "chests": [], "level_up": false, "new_level": 0,
			"char_level_up": false, "char_level": 0, "char_gained": 0, "rank": {}, "empty": false}
	var out := {"ok": true, "exp": int(_num(r.get("expGained"))) if _num(r.get("expGained")) > 0 else 0,
		"coin": int(_num(r.get("coinGained"))) if _num(r.get("coinGained")) > 0 else 0,
		"bonus_coin": int(_num(r.get("bonusCoin"))) if _num(r.get("bonusCoin")) > 0 else 0,
		"stones": stones_of(r.get("stones")), "chests": ChestModel.match_chests(r.get("chests")),
		"level_up": r.get("levelUp") is bool and r["levelUp"], "new_level": maxi(0, int(_num(r.get("newLevel")))),
		"char_level_up": r.get("charLevelUp") is bool and r["charLevelUp"], "char_level": maxi(0, int(_num(r.get("charNewLevel")))),
		"char_gained": maxi(0, int(_num(r.get("charLevelsGained")))), "rank": RankModel.result_of(mode, r)}
	out["empty"] = out["exp"] == 0 and out["coin"] == 0 and out["stones"].is_empty() and out["chests"].is_empty() \
		and out["rank"].is_empty() and not out["level_up"] and not out["char_level_up"]
	return out


## A reward's stones ([{level, qty}]) merged by level, lowest first, qty > 0.
static func stones_of(v: Variant) -> Array:
	var by := {}
	if v is Array:
		for s in v:
			if s is Dictionary and _num(s.get("level")) >= 1 and _num(s.get("qty")) > 0:
				var lv := int(_num(s["level"]))
				by[lv] = int(by.get(lv, 0)) + int(_num(s["qty"]))
	var keys: Array = by.keys()
	keys.sort()
	return keys.map(func(lv): return {"level": lv, "qty": by[lv]})


## "(+150 thưởng xếp hạng)" for a ranked bonus inside the coins; "" none.
static func bonus_text(bonus: int) -> String:
	return "(+%s thưởng xếp hạng)" % Fmt.thousands(bonus) if bonus > 0 else ""


## "Đá cấp 3 ×2".
static func stone_text(s: Dictionary) -> String:
	return "%s ×%d" % [UpgradeModel.stone_name(int(s["level"])), int(s["qty"])]


## The levels a popup counts through from `from` to `to`, one per step: (3, 5) → [4, 5]; [] when
## `to` is not higher.
static func count_steps(from: int, to: int) -> Array:
	var out: Array = []
	for lv in range(from + 1, to + 1):
		out.append(lv)
	return out


## The level-up popup's stages, the player's level first, then my character's: [{kind: "player",
## from, to, steps (count_steps)}, {kind: "character", character_id, name, from, to, steps}]; []
## without a level up. `r` is reward(); `before` the cached profile's {level, exp} before the match
## ({} unknown). The new levels are MatchEnded's (newLevel, charNewLevel); the old player level is
## the profile's (one below the new one when unknown or stale), the old character level
## charNewLevel - charLevelsGained (one level when the server sent no count).
static func level_ups(r: Dictionary, before: Dictionary, character_id: String, char_name: String) -> Array:
	var out: Array = []
	if not r.get("ok", false):
		return out
	if r.get("level_up", false):
		var to := int(r.get("new_level", 0))
		var old := int(before.get("level", 0))
		if to <= 0 and old > 0:
			to = int(exp_steps(old, int(before.get("exp", 0)), int(r.get("exp", 0)))["level"])
		if to > 1:
			var from := old if old > 0 and old < to else to - 1
			out.append({"kind": "player", "from": from, "to": to, "steps": count_steps(from, to)})
	if r.get("char_level_up", false) and int(r.get("char_level", 0)) > 1:
		var to := int(r["char_level"])
		var gained := int(r.get("char_gained", 0))
		var from := clampi(to - (gained if gained > 0 else 1), 1, to - 1)
		out.append({"kind": "character", "character_id": character_id, "name": char_name, "from": from, "to": to,
			"steps": count_steps(from, to)})
	return out


## The winner standing on the podium's top step: the MVP when they won, else the winner who dealt
## the most damage (the first of `left` on a tie); "" with fewer than two winners or no damage.
static func podium_top(left: Array, mvp_id: String) -> String:
	if left.size() < 2:
		return ""
	var best := ""
	var best_damage := 0
	for e in left:
		if e["playerId"] == mvp_id:
			return mvp_id
		if int(e["damage"]) > best_damage:
			best = e["playerId"]
			best_damage = int(e["damage"])
	return best


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


## The second button: "Chơi tiếp" (a queue mode, ranked or casual: straight back into the
## queue), "Chơi lại" (a Quick Play match again), "" none.
static func again_text(mode: String, can_replay: bool) -> String:
	if RankModel.is_queue_mode(mode):
		return "Chơi tiếp"
	return "Chơi lại" if can_replay else ""


static func countdown_text(seconds: int) -> String:
	return "Tự động về sảnh sau %d giây" % maxi(seconds, 0)
