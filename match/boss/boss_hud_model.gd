extends RefCounted
## The boss fight's HUD state without UI (match/boss/boss_hud.gd draws it): which boss, its HP and
## max HP, whether it is shielded (a minion alive: it takes shieldedDamageFactor of the damage),
## the round (boss turns begun) and the turn limit; built from MatchStarted / MatchStateSync
## (boss {bossId, playerId, round, turnLimit}, bossShielded, the boss's BattlePlayerState) and
## kept by the events: TurnStarted round, BossShieldChanged, the boss's damage / die / PlayerDamaged
## (set_hp(), kill()). Names and numbers are the server's (the game data's boss name, else the
## state's displayName); only the wording ("Vòng 3/15") is the client's.

const GameData := preload("res://autoload/game_data_model.gd")
const Fmt := preload("res://core/fmt.gd")

var active := false # a boss match
var boss_id := ""
var player_id := ""
var name := ""
var hp := 0
var max_hp := 1
var shielded := false
var boss_round := 0
var turn_limit := 0
var alive := true


static func _num(v: Variant, fallback: int = 0) -> int:
	return int(v) if v is int or v is float else fallback


## Rebuilds from a MatchStarted / MatchStateSync; false (inactive) when it has no boss block.
func load_snapshot(snap: Variant) -> bool:
	active = false
	if not snap is Dictionary or not snap.get("boss") is Dictionary:
		return false
	var b: Dictionary = snap["boss"]
	boss_id = str(b.get("bossId", ""))
	player_id = str(b.get("playerId", ""))
	boss_round = maxi(_num(b.get("round")), 0)
	turn_limit = maxi(_num(b.get("turnLimit"), _num(GameData.boss(boss_id).get("turnLimit"))), 0)
	shielded = snap.get("bossShielded") == true
	var players = snap.get("players")
	var p: Dictionary = players.get(player_id, {}) if players is Dictionary and players.get(player_id) is Dictionary else {}
	if player_id == "" and players is Dictionary: # an older payload: the role tells
		for id in players:
			if players[id] is Dictionary and str(players[id].get("role", "")) == "boss":
				player_id = id
				p = players[id]
	var gd_boss := GameData.boss(boss_id)
	max_hp = maxi(_num(p.get("maxHp"), _num(gd_boss.get("hp"), 1)), 1)
	hp = clampi(_num(p.get("hp"), max_hp), 0, max_hp)
	alive = p.get("isAlive") != false and hp > 0
	name = str(gd_boss.get("name", "")) if str(gd_boss.get("name", "")) != "" else str(p.get("displayName", boss_id))
	active = true
	return true


## TurnStarted (boss mode): its round.
func on_turn_started(d: Variant) -> void:
	if active and d is Dictionary and (d.get("round") is int or d.get("round") is float):
		boss_round = maxi(int(d["round"]), 0)


## BossShieldChanged {bossId, playerId, shielded}: true when it changed.
func on_shield(d: Variant) -> bool:
	if not active or not d is Dictionary:
		return false
	var pid := str(d.get("playerId", player_id))
	if pid != player_id and pid != "":
		return false
	var now: bool = d.get("shielded") == true
	if now == shielded:
		return false
	shielded = now
	return true


## A player's HP changed (a damage event, PlayerDamaged): kept when it is the boss's; true then.
func set_hp(id: String, value: int) -> bool:
	if not active or id != player_id:
		return false
	hp = clampi(value, 0, max_hp)
	return true


## A player died: the boss's death drops the shield too.
func kill(id: String) -> bool:
	if not active or id != player_id:
		return false
	alive = false
	hp = 0
	shielded = false
	return true


## The bar's fill, 0..1.
func ratio() -> float:
	return clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)


## "8.400 / 12.000".
func hp_text() -> String:
	return "%s / %s" % [Fmt.thousands(hp), Fmt.thousands(max_hp)]


## "Vòng 3/15" ("Vòng 3" without a limit); round 0 (before the boss's first turn) shows 1.
func round_text() -> String:
	var r := maxi(boss_round, 1)
	return "Vòng %d/%d" % [mini(r, turn_limit), turn_limit] if turn_limit > 0 else "Vòng %d" % r


## The rounds left before the boss escapes (0 on the last).
func rounds_left() -> int:
	return maxi(turn_limit - maxi(boss_round, 1), 0)


## Everything the HUD shows: {active, boss_id, name, hp, max_hp, ratio, hp_text, shielded, round,
## turn_limit, round_text, alive}.
func state() -> Dictionary:
	return {"active": active, "boss_id": boss_id, "name": name, "hp": hp, "max_hp": max_hp, "ratio": ratio(), "hp_text": hp_text(),
		"shielded": shielded, "round": boss_round, "turn_limit": turn_limit, "round_text": round_text(), "alive": alive}
