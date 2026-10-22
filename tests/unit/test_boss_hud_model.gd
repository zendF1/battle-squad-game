extends "res://tests/test_case.gd"
## match/boss/boss_hud_model.gd: the boss bar's state from MatchStarted / MatchStateSync and the
## events (shield, round, HP, death), and match/boss/lava_zones.gd: the lava pools' lifetime.

const BossFixture := preload("res://tests/boss_fixture.gd")
const BossHudModel := preload("res://match/boss/boss_hud_model.gd")
const LavaZones := preload("res://match/boss/lava_zones.gd")

const SNAP := {"mode": "boss:steel_robot", "boss": {"bossId": "steel_robot", "playerId": "boss_steel_robot", "round": 0, "turnLimit": 15},
	"bossShielded": true, "players": {
		"boss_steel_robot": {"playerId": "boss_steel_robot", "displayName": "Rô-bốt Thép", "role": "boss", "bossId": "steel_robot",
			"hp": 12000, "maxHp": 12000, "isAlive": true, "teamId": 2},
		"minion_drone_1": {"playerId": "minion_drone_1", "role": "minion", "minionId": "drone", "hp": 650, "maxHp": 650, "isAlive": true}}}


func test_from_the_snapshot() -> void:
	BossFixture.take()
	var m := BossHudModel.new()
	check(m.load_snapshot(SNAP), "a boss match")
	var s := m.state()
	eq([s["name"], s["hp"], s["max_hp"], s["shielded"], s["turn_limit"]], ["Rô-bốt Thép", 12000, 12000, true, 15], "the boss")
	eq(s["hp_text"], "12.000 / 12.000", "HP numbers")
	eq(s["round_text"], "Vòng 1/15", "before its first turn: round 1")
	check(not BossHudModel.new().load_snapshot({"players": {}}), "no boss block: inactive")


func test_events() -> void:
	BossFixture.take()
	var m := BossHudModel.new()
	m.load_snapshot(SNAP)
	m.on_turn_started({"round": 3, "currentPlayerId": "p1"})
	eq(m.round_text(), "Vòng 3/15", "TurnStarted round")
	eq(m.rounds_left(), 12, "rounds left")
	check(not m.on_shield({"bossId": "steel_robot", "playerId": "boss_steel_robot", "shielded": true}), "no change")
	check(m.on_shield({"bossId": "steel_robot", "playerId": "boss_steel_robot", "shielded": false}), "the shield drops")
	check(not m.state()["shielded"], "unshielded")
	check(m.on_shield({"playerId": "boss_steel_robot", "shielded": true}), "a new minion: up again")
	check(not m.set_hp("minion_drone_1", 10), "a minion's HP is not the bar's")
	check(m.set_hp("boss_steel_robot", 8400), "the boss's")
	eq([m.hp_text(), m.ratio()], ["8.400 / 12.000", 0.7], "the bar")
	m.set_hp("boss_steel_robot", -50)
	eq(m.hp, 0, "never below 0")
	check(m.kill("boss_steel_robot"), "the boss died")
	check(not m.alive and not m.shielded, "dead, no shield")
	m.on_turn_started({"round": 20})
	eq(m.round_text(), "Vòng 15/15", "capped at the limit")


func test_sync_keeps_the_round() -> void:
	BossFixture.take()
	var snap: Dictionary = SNAP.duplicate(true)
	snap["boss"]["round"] = 7
	snap["bossShielded"] = false
	snap["players"]["boss_steel_robot"]["hp"] = 5000
	var m := BossHudModel.new()
	m.load_snapshot(snap)
	eq([m.boss_round, m.shielded, m.hp], [7, false, 5000], "the sync's state")


func test_lava_lifetime() -> void:
	var z := LavaZones.new()
	var first := z.set_all([{"zoneId": "lava_1", "position": {"x": 400, "y": 700}, "radius": 50, "damage": 150, "expiresRound": 4}])
	eq(first, {"added": ["lava_1"], "removed": []}, "MatchStarted's pool")
	var added := z.add_event({"type": "lava", "zoneId": "lava_2", "position": {"x": 600, "y": 720}, "radius": 50, "amount": 150, "turns": 2}, 3)
	eq(added["expires_round"], 5, "turns rounds after the boss's turn")
	eq(z.add_event({"zoneId": "lava_2", "turns": 2}, 3), {}, "known already")
	eq(z.ids(), ["lava_1", "lava_2"], "both burn")
	eq(z.zone_at(Vector2(430, 690))["zoneId"], "lava_1", "standing in it")
	eq(z.zone_at(Vector2(460, 700)), {}, "past its radius")
	eq(z.zone_at(Vector2(400, 600)), {}, "far above it")
	eq(z.expire(4), ["lava_1"], "the end of boss turn 4 dries the first")
	eq(z.ids(), ["lava_2"], "one left")
	var next := z.set_all([{"zoneId": "lava_3", "position": {"x": 1, "y": 1}, "radius": 50, "expiresRound": 7}])
	eq(next, {"added": ["lava_3"], "removed": ["lava_2"]}, "TurnStarted's list replaces them")
	eq(z.set_all(null), {"added": [], "removed": ["lava_3"]}, "a boss snapshot without the key: none")
