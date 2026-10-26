extends RefCounted
## The boss fight's HUD state without UI (match/boss/boss_hud.gd draws it): which boss, its HP and
## max HP, whether it is shielded (a minion alive: it takes shieldedDamageFactor of the damage),
## the round (boss turns begun) and the turn limit; built from MatchStarted / MatchStateSync
## (boss {bossId, playerId, round, turnLimit}, bossShielded, the boss's BattlePlayerState) and
## kept by the events: TurnStarted round, BossShieldChanged, the boss's damage / die / PlayerDamaged
## (set_hp(), kill()). Names and numbers are the server's (the game data's boss name, else the
## state's displayName); only the wording ("Vòng 3/15") is the client's.
## Boss v4 (the minion auras): damageTakenFactor (what the boss's damage is multiplied by now),
## armorMinions (the living minions whose aura armours it: the stone totems' rune links and the
## plates on Khổng Lồ Đá), regenPct and regenMinions (the poison mushrooms healing Mộc Tinh at its turn
## start) from MatchStarted / MatchStateSync boss and every BossShieldChanged (which carries them
## all); between them a minion's death drops it from both lists at once (minion_died()) and a summon of
## a minion type with an aura adds it (minion_summoned()), so the links break / appear on their moment
## in the replay. armored(): the armour is up (any armour minion alive).

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
var damage_taken_factor := 1.0
var armor_minions: Array = [] # playerIds
var regen_pct := 0.0
var regen_minions: Array = [] # playerIds


static func _num(v: Variant, fallback: int = 0) -> int:
	return int(v) if v is int or v is float else fallback


static func _ids(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for id in v:
			if (id is String or id is StringName) and str(id) != "" and not out.has(str(id)):
				out.append(str(id))
	return out


## Reads the aura fields of a boss block / BossShieldChanged (a missing one keeps its value); true
## when one changed.
func _read_aura(d: Dictionary) -> bool:
	var before := [damage_taken_factor, armor_minions.duplicate(), regen_pct, regen_minions.duplicate()]
	if d.get("damageTakenFactor") is int or d.get("damageTakenFactor") is float:
		damage_taken_factor = float(d["damageTakenFactor"])
	if d.has("armorMinions"):
		armor_minions = _ids(d["armorMinions"])
	if d.get("regenPct") is int or d.get("regenPct") is float:
		regen_pct = float(d["regenPct"])
	if d.has("regenMinions"):
		regen_minions = _ids(d["regenMinions"])
	return before != [damage_taken_factor, armor_minions, regen_pct, regen_minions]


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
	damage_taken_factor = 1.0
	armor_minions = []
	regen_pct = 0.0
	regen_minions = []
	_read_aura(b)
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


## BossShieldChanged {bossId, playerId, shielded, damageTakenFactor, armorMinions, regenPct,
## regenMinions}: true when the shield or the aura changed.
func on_shield(d: Variant) -> bool:
	if not active or not d is Dictionary:
		return false
	var pid := str(d.get("playerId", player_id))
	if pid != player_id and pid != "":
		return false
	var changed := _read_aura(d)
	var now: bool = d.get("shielded") == true
	if now == shielded:
		return changed
	shielded = now
	return true


## The armour is up: at least one armour minion lives (Khổng Lồ Đá's totems).
func armored() -> bool:
	return active and alive and not armor_minions.is_empty()


## A minion died: off the aura lists at once (BossShieldChanged confirms it after the replay); true
## when it was on one.
func minion_died(id: String) -> bool:
	var was := armor_minions.has(id) or regen_minions.has(id)
	armor_minions.erase(id)
	regen_minions.erase(id)
	return was


## A minion of type `kind` (GET /gamedata bosses minions) was summoned: on the armour list when its
## type armours the boss (bossDamageTakenFactor), on the regen list when it heals it
## (bossRegenPctPerMinion); true when it went on one.
func minion_summoned(id: String, kind: Dictionary) -> bool:
	if not active or id == "":
		return false
	var on := false
	var f = kind.get("bossDamageTakenFactor")
	if (f is int or f is float) and float(f) > 0.0 and not armor_minions.has(id):
		armor_minions.append(id)
		on = true
	var r = kind.get("bossRegenPctPerMinion")
	if (r is int or r is float) and float(r) > 0.0 and not regen_minions.has(id):
		regen_minions.append(id)
		on = true
	return on


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
	armor_minions = []
	regen_minions = []
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


## Everything the HUD shows: {active, boss_id, name, hp, max_hp, ratio, hp_text, shielded, armored,
## round, turn_limit, round_text, alive}.
func state() -> Dictionary:
	return {"active": active, "boss_id": boss_id, "name": name, "hp": hp, "max_hp": max_hp, "ratio": ratio(), "hp_text": hp_text(),
		"shielded": shielded, "armored": armored(), "round": boss_round, "turn_limit": turn_limit, "round_text": round_text(),
		"alive": alive}
