extends RefCounted
## One boss's bonus runs of the day as pictures, without UI (ui/boss_trail.gd draws it), from a GET
## /boss/runs bosses[] row or a boss MatchEnded rewards[id]: both carry rewardVersion,
## bonusRunsCompleted, bonusWins, perfectRequiredWins, perfectRewardEligible and
## perfectRewardGranted. Everything is read from the server, nothing is worked out here: the
## server alone decides whether the gold chest can still be earned. Rules 1 (an older server, a
## start day not reached, a result saved before the release: no rewardVersion or 0) has no trail.
## The server sends counts, not the order of the runs: the wins are drawn first, then the losses.

const GameData := preload("res://autoload/game_data_model.gd")
const Fmt := preload("res://core/fmt.gd")

## A pip.
const WIN := "win"
const LOSS := "loss"
const OPEN := "open"
## The gold chest: still reachable, lost for today (drawn grey), earned.
const GOAL := "goal"
const LOST := "lost"
const WON := "won"
## The picture when the game data does not name the gold chest.
const GOLD_CHEST := "stone_chest_gold"


static func _num(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


## The rules a row settled with: 1 or 2, a missing value or 0 is 1.
static func version_of(row: Variant) -> int:
	return maxi(_num(row.get("rewardVersion")), 1) if row is Dictionary else 1


## Milliseconds until a GET /boss/runs answer turns into yesterday's (its resetAt; `now`: unix
## seconds on arrival): rules and progress change at the reset, so it is not kept past it. -1
## without a reset ahead: a device clock already past resetAt must not read every fresh answer as
## expired, the age limit reloads it then.
static func reset_in_msec(runs: Variant, now: int) -> int:
	if not runs is Dictionary:
		return -1
	var unix := Fmt.unix_time(str(runs.get("resetAt", "")))
	return (unix - now) * 1000 if unix > now else -1


## The trail of a row: {pips: [WIN | LOSS | OPEN], wins, done, gold (GOAL | LOST | WON), gold_chest
## (the chest id to draw)}; {} under rules 1. boss_id: the row's boss when it does not name one.
static func of(row: Variant, boss_id: String = "") -> Dictionary:
	if version_of(row) < 2:
		return {}
	var id := str(row.get("bossId", boss_id)) if row.get("bossId") is String else boss_id
	var need := _num(row.get("perfectRequiredWins"))
	if need <= 0:
		need = int(rules(id).get("required", 0))
	if need <= 0:
		need = _num(row.get("dailyBonusRuns"))
	if need <= 0:
		return {}
	var wins := clampi(_num(row.get("bonusWins")), 0, need)
	var done := clampi(_num(row.get("bonusRunsCompleted")), wins, need)
	var pips: Array = []
	for i in need:
		pips.append(WIN if i < wins else (LOSS if i < done else OPEN))
	var gold := WON if row.get("perfectRewardGranted") == true else (GOAL if row.get("perfectRewardEligible") == true else LOST)
	return {"pips": pips, "wins": wins, "done": done, "gold": gold, "gold_chest": gold_chest(id)}


## The chest the wins lead to (the game data's perfect chests), GOLD_CHEST when it names none.
static func gold_chest(boss_id: String) -> String:
	var perfect: Array = rules(boss_id).get("perfect", [])
	return str(perfect[0]["chestId"]) if not perfect.is_empty() else GOLD_CHEST


## What a boss's runs give under rules 2, as the "i" popup draws it: {win, loss, perfect: [{chestId,
## qty}], required}; {} without the game data's chestsV2.
static func rules(boss_id: String) -> Dictionary:
	var v2 := GameData.boss_chests_v2(boss_id)
	if v2.is_empty():
		return {}
	var perfect: Dictionary = v2["perfect"] if v2.get("perfect") is Dictionary else {}
	return {"win": _chests(v2.get("winChests")), "loss": _chests(v2.get("lossChests")), "perfect": _chests(perfect.get("chests")),
		"required": _num(perfect.get("requiredWins"))}


static func _chests(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for c in v:
			if c is Dictionary and c.get("chestId") is String and _num(c.get("quantity")) > 0:
				out.append({"chestId": c["chestId"], "qty": _num(c["quantity"])})
	return out
