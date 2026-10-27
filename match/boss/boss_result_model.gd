extends RefCounted
## The boss match's result without UI (match/boss/boss_result_screen.gd draws it), from its
## MatchEnded {winningTeam, result, boss {bossId, result, round, turnLimit, bossHp, bossMaxHp,
## bossDamage: {playerId: damage}}, rewards[me] {expGained, coinGained, ..., bossDamage,
## minionDamage, bonusRun, bonusRunsLeft, items: [{itemId, quantity}]}, mvpPlayerId}: the title
## of how it ended, the damage ranking of the party (bots too) on a podium (podium(): ranks 3, 1,
## 2, 4 left to right, #1 tallest), the MVP, the boss's HP left (in the subtitle of a loss), and my rewards with the run's table ("Lượt thưởng lớn" / "Thưởng thường") and the big
## runs left today. Item names come from the game data.

const ResultModel := preload("res://match/result_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const Fmt := preload("res://core/fmt.gd")

const DEFEATED := "boss_defeated"
const PARTY_DEFEATED := "party_defeated"
const ESCAPED := "boss_escaped"

## A win reads as any match's win (ResultModel.title_text(WIN): "CHIẾN THẮNG"); a loss says how.
const TITLES := {DEFEATED: "", PARTY_DEFEATED: "Cả đội đã gục", ESCAPED: "Boss đã trốn thoát"}
## The podium (the PvP result's, match/result_screen.gd): a step per party player, by rank
## (1 most damage to the boss) px tall, laid out left to right in PODIUM_ORDER (the tallest two in
## the middle); a fifth and later player (none in a 4-player party) stands at the ends on the
## lowest step.
const PODIUM_ORDER := [3, 1, 2, 4]
const STEP_HEIGHTS := [128.0, 100.0, 76.0, 58.0]
const BONUS := "Lượt thưởng lớn"
const NORMAL := "Thưởng thường"


static func _num(v: Variant, fallback: float = 0.0) -> float:
	return float(v) if v is int or v is float else fallback


## How the fight ended: MatchEnded result (else its boss block's), else from the winner: my team
## won → boss_defeated, else party_defeated.
static func result_of(d: Dictionary, my_team: int) -> String:
	for r in [d.get("result"), (d["boss"] as Dictionary).get("result") if d.get("boss") is Dictionary else null]:
		if r is String and TITLES.has(r):
			return r
	return DEFEATED if int(_num(d.get("winningTeam"))) == my_team and my_team > 0 else PARTY_DEFEATED


static func title_text(result: String) -> String:
	if result == DEFEATED:
		return ResultModel.title_text(ResultModel.WIN)
	return str(TITLES.get(result, TITLES[PARTY_DEFEATED]))


## The party's damage to the boss, most first: [{playerId, displayName, characterId, isBot, mine,
## damage, ratio (of the top damage, 0..1), mvp}]. Everyone of my team is listed (0 without an
## entry), then anyone else bossDamage names; ties keep me first, then by id.
static func ranking(d: Dictionary, players: Dictionary, me: String, mvp_id: String) -> Array:
	var raw = (d["boss"] as Dictionary).get("bossDamage") if d.get("boss") is Dictionary else null
	var dmg: Dictionary = raw if raw is Dictionary else {}
	var my_team := int(_num(players.get(me, {}).get("teamId"), 1))
	var ids: Array = []
	for id in players:
		var p = players[id]
		if p is Dictionary and int(_num(p.get("teamId"))) == my_team and str(p.get("role", "")) == "":
			ids.append(id)
	for id in dmg:
		if not ids.has(id) and str(players.get(id, {}).get("role", "")) == "":
			ids.append(id)
	var rows: Array = []
	for id in ids:
		var p: Dictionary = players.get(id, {}) if players.get(id) is Dictionary else {}
		var is_bot: bool = p.get("isBot") if p.get("isBot") is bool else str(id).begins_with("bot_")
		rows.append({"playerId": id, "displayName": str(p.get("displayName", str(id).left(8))),
			"characterId": str(p.get("characterId", GameData.default_character_id())), "isBot": is_bot, "mine": id == me,
			"damage": maxi(int(_num(dmg.get(id))), 0), "ratio": 0.0, "mvp": id == mvp_id})
	rows.sort_custom(func(a, b):
		if a["damage"] != b["damage"]:
			return a["damage"] > b["damage"]
		if a["mine"] != b["mine"]:
			return a["mine"]
		return str(a["playerId"]) < str(b["playerId"]))
	var top := float(rows[0]["damage"]) if not rows.is_empty() else 0.0
	for r in rows:
		r["ratio"] = clampf(float(r["damage"]) / top, 0.0, 1.0) if top > 0.0 else 0.0
	return rows


## The MVP: MatchEnded mvpPlayerId when it is in the party, else the one who dealt the boss the most
## (none at 0).
static func mvp_of(d: Dictionary, players: Dictionary, me: String) -> String:
	var rows := ranking(d, players, me, "")
	var id = d.get("mvpPlayerId")
	if id is String:
		for r in rows:
			if r["playerId"] == id:
				return id
	return str(rows[0]["playerId"]) if not rows.is_empty() and int(rows[0]["damage"]) > 0 else ""


## My rewards: ResultModel.reward() (ok, exp, coin, the level ups, chests: a bonus run's stone
## chests [{chestId, qty, name, text}]) plus boss_damage, minion_damage,
## bonus_run, bonus_left (-1 unknown), items [{itemId, qty, name}], badge (BONUS / NORMAL),
## left_text ("Còn 2 lượt thưởng lớn hôm nay"), damage_text ("Sát thương boss 9.000").
static func reward(r: Variant, mode: String) -> Dictionary:
	var out := ResultModel.reward(r, mode)
	out["rank"] = {}
	var d: Dictionary = r if r is Dictionary else {}
	out["boss_damage"] = maxi(int(_num(d.get("bossDamage"))), 0)
	out["minion_damage"] = maxi(int(_num(d.get("minionDamage"))), 0)
	out["bonus_run"] = d.get("bonusRun") == true
	out["bonus_left"] = int(_num(d.get("bonusRunsLeft"), -1.0))
	var items: Array = []
	if d.get("items") is Array:
		for it in d["items"]:
			if not it is Dictionary or str(it.get("itemId", "")) == "":
				continue
			var qty := int(_num(it.get("quantity"), _num(it.get("qty"), 1.0)))
			if qty <= 0:
				continue
			var id := str(it["itemId"])
			items.append({"itemId": id, "qty": qty, "name": item_name(id)})
	out["items"] = items
	out["badge"] = BONUS if out["bonus_run"] else NORMAL
	out["left_text"] = left_text(int(out["bonus_left"]))
	out["damage_text"] = "Sát thương boss %s" % Fmt.thousands(int(out["boss_damage"]))
	return out


## An item's Vietnamese name (the game data's items, else the id).
static func item_name(item_id: String) -> String:
	var n := GameData.item_name(item_id)
	return n if n != "" else item_id


## "Còn 2 lượt thưởng lớn hôm nay", "Hết lượt thưởng lớn hôm nay"; "" unknown.
static func left_text(left: int) -> String:
	if left < 0:
		return ""
	return "Còn %d lượt thưởng lớn hôm nay" % left if left > 0 else "Hết lượt thưởng lớn hôm nay"


## "Vòng 9/15" of the fight's boss block; "" without one.
static func round_text(d: Dictionary) -> String:
	if not d.get("boss") is Dictionary:
		return ""
	var b: Dictionary = d["boss"]
	var r := int(_num(b.get("round")))
	var limit := int(_num(b.get("turnLimit")))
	if r <= 0:
		return ""
	return "Vòng %d/%d" % [r, limit] if limit > 0 else "Vòng %d" % r


## The podium's steps left to right for a ranking (most damage first, ranking()): [{rank, step_h,
## entry}] in PODIUM_ORDER, the ranks the party has (3 players: 3, 1, 2; 2: 1, 2; 1: 1); 0 damage
## still gets its step.
static func podium(rows: Array) -> Array:
	var out: Array = []
	for rank in PODIUM_ORDER:
		if rank <= rows.size():
			out.append({"rank": rank, "step_h": step_height(rank), "entry": rows[rank - 1]})
	for i in range(PODIUM_ORDER.size(), rows.size()):
		var e := {"rank": i + 1, "step_h": step_height(i + 1), "entry": rows[i]}
		if i % 2 == 0:
			out.push_front(e)
		else:
			out.append(e)
	return out


## A rank's step height (px): STEP_HEIGHTS, the lowest past 4.
static func step_height(rank: int) -> float:
	return float(STEP_HEIGHTS[clampi(rank - 1, 0, STEP_HEIGHTS.size() - 1)])


## Under the title: "Cua Dung Nham · Vòng 9/15"; a loss adds the boss's HP left ("Máu boss còn
## 3.400 / 12.000").
static func subtitle(i: Dictionary) -> String:
	var boss: Dictionary = i.get("boss", {}) if i.get("boss") is Dictionary else {}
	var parts := PackedStringArray()
	for t in [str(boss.get("name", "")), str(i.get("round_text", ""))]:
		if t != "":
			parts.append(t)
	if str(i.get("outcome", "")) != ResultModel.WIN and str(boss.get("hp_text", "")) != "":
		parts.append("Máu boss còn %s" % boss["hp_text"])
	return " · ".join(parts)


## Everything the screen shows: {outcome (ResultModel WIN / LOSE), result, title, round_text,
## boss: {boss_id, name, art, hp, max_hp, ratio, hp_text}, ranking, podium, mvp, reward}. boss_id: the
## match's (the boss block's wins).
static func info(d: Dictionary, players: Dictionary, me: String, boss_id: String, my_reward: Variant) -> Dictionary:
	var my_team := int(_num(players.get(me, {}).get("teamId"), 1))
	var res := result_of(d, my_team)
	var b: Dictionary = d["boss"] if d.get("boss") is Dictionary else {}
	var bid := str(b.get("bossId", boss_id)) if str(b.get("bossId", "")) != "" else boss_id
	var gd_boss := GameData.boss(bid)
	var max_hp := maxi(int(_num(b.get("bossMaxHp"), _num(gd_boss.get("hp"), 1.0))), 1)
	var hp := clampi(int(_num(b.get("bossHp"))), 0, max_hp)
	var mvp := mvp_of(d, players, me)
	var rows := ranking(d, players, me, mvp)
	return {"outcome": ResultModel.WIN if res == DEFEATED else ResultModel.LOSE, "result": res, "title": title_text(res),
		"round_text": round_text(d),
		"boss": {"boss_id": bid, "name": GameData.boss_name(bid), "art": BossArt.art_of(bid), "hp": hp, "max_hp": max_hp,
			"ratio": float(hp) / float(max_hp), "hp_text": "%s / %s" % [Fmt.thousands(hp), Fmt.thousands(max_hp)]},
		"ranking": rows, "podium": podium(rows), "mvp": mvp, "reward": reward(my_reward, "")}
