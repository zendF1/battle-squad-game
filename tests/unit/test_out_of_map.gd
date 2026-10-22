extends "res://tests/test_case.gd"
## match_screen.gd: a walk into a hole down to the bottom of the map (PlayerMoved outOfMap, then
## PlayerDamaged out_of_map in the same read): the death waits until the body has fallen out of
## sight, and what came after it (MatchEnded) waits behind it; a shot's fall out of the map drops
## past the bottom too.

const MatchScreen := preload("res://match/match_screen.gd")
const Hud := preload("res://match/hud.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const WalkPath := preload("res://match/move/walk_path.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const DT := 1.0 / 60.0


## A view with what match_screen asks of it: its WalkPath, HP and death.
class FakeView extends Node2D:
	var walk := WalkPath.new()
	var dead := false
	var hp := -1

	func walk_to(target: Vector2, max_sec: float) -> void:
		walk.walk(target, max_sec)

	func follow_walk(target: Vector2) -> void:
		walk.follow(target)

	func falling_out() -> bool:
		return walk.falling_out()

	func move_to(target: Vector2, _sec: float, _a = 0, _b = 0) -> void:
		walk.reset(target)
		position = target

	func set_hp(value: int, _max_value: int = -1) -> void:
		hp = value

	func set_shield(_value: int) -> void:
		pass

	func set_dead() -> void:
		dead = true

	func set_active(_on: bool) -> void:
		pass

	func clear_aim() -> void:
		pass

	func step(dt: float) -> void:
		if walk.active():
			position = walk.step(dt)


## 96 x 64 px, ground on columns 0-31 and 64-95, a hole to the bottom on 32-63.
static func _hole() -> TerrainMask:
	var m := TerrainMask.new()
	m.width = 96
	m.height = 64
	m.solid.resize(96 * 64)
	m.solid.fill(0)
	for x in 96:
		if x < 32 or x >= 64:
			for y in range(48, 64):
				m.solid[y * 96 + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	return m


func _screen() -> Node:
	var m = MatchScreen.new()
	m._me = "me"
	m._current = "bot"
	m._mask = _hole()
	m._players = {
		"me": {"playerId": "me", "characterId": "rookie", "isAlive": true, "skillEnergy": 0, "items": [],
			"statusEffects": [], "teamId": 1, "hp": 1000, "maxHp": 1000, "position": {"x": 80.0, "y": 48.0}},
		"bot": {"playerId": "bot", "characterId": "tanko", "isAlive": true, "skillEnergy": 0, "items": [],
			"statusEffects": [], "teamId": 2, "hp": 800, "maxHp": 1000, "position": {"x": 10.0, "y": 48.0}}}
	var bot := FakeView.new()
	bot.walk.terrain = m._mask
	bot.position = Vector2(10, 48)
	bot.walk.reset(bot.position)
	var mine := FakeView.new()
	mine.walk.terrain = m._mask
	mine.position = Vector2(80, 48)
	mine.walk.reset(mine.position)
	m._views = {"bot": bot, "me": mine}
	m.send_hook = func(_event: String, _data: Dictionary) -> void: pass
	var h: Control = Hud.new()
	h._ready()
	var v: Control = h._portrait_art
	v._ready()
	v.character()._ready()
	m._hud = h
	m._aim = AimInput.new()
	m._shot_player = ShotPlayer.new()
	m._fx_layer = Node2D.new()
	return m


func _free(m) -> void:
	m._hud.free()
	m._aim.free()
	m._shot_player.free()
	m._fx_layer.free()
	m._views["bot"].free()
	m._views["me"].free()
	m.free()


func test_death_waits_for_the_fall() -> void:
	var m = _screen()
	var bot: FakeView = m._views["bot"]
	m._on_event("PlayerMoved", {"playerId": "bot", "position": {"x": 32, "y": 64}, "moveEnergy": 70, "outOfMap": true})
	check(bot.falling_out(), "the walk falls out of the map")
	m._on_event("PlayerDamaged", [{"playerId": "bot", "damage": 800, "hp": 0, "shield": 0, "isAlive": false, "type": "out_of_map"}])
	m._on_event("MatchEnded", {"winningTeam": 1, "rewards": null})
	check(not bot.dead and bot.hp == -1, "no death while the body still walks and falls")
	eq(m._deferred.size(), 2, "the death and the end wait")
	check(not m._ended, "the match end waits behind the death")
	var frames := 0
	while bot.falling_out() and frames < 400:
		bot.step(DT)
		m._release_fall_hold()
		frames += 1
		if bot.falling_out():
			check(not bot.dead, "still falling: alive on screen")
	m._release_fall_hold()
	check(bot.position.y >= 64.0 + WalkPath.OUT_DROP - 0.01, "fallen out of sight")
	check(bot.dead and bot.hp == 0, "then the death plays")
	check(not m._players["bot"]["isAlive"], "dead in the state")
	check(m._ended, "then the match ends")
	check(m.get_node_or_null("ResultDelay") != null, "the result's 2 s count from there")
	eq(m._fx_layer.get_child_count(), 0, "no float text for the fall")
	_free(m)


func test_a_fallen_body_dies_at_once() -> void:
	var m = _screen()
	var bot: FakeView = m._views["bot"]
	bot.position = Vector2(32, 64 + WalkPath.OUT_DROP)
	bot.walk.reset(bot.position)
	m._on_event("PlayerDamaged", [{"playerId": "bot", "damage": 800, "hp": 0, "shield": 0, "isAlive": false, "type": "out_of_map"}])
	check(bot.dead, "below the map at its turn start: dies at once")
	eq(m._deferred.size(), 0, "nothing waits")
	_free(m)


func test_other_damage_does_not_wait() -> void:
	var m = _screen()
	var bot: FakeView = m._views["bot"]
	m._on_event("PlayerMoved", {"playerId": "bot", "position": {"x": 32, "y": 64}, "moveEnergy": 70, "outOfMap": true})
	m._on_event("PlayerDamaged", [{"playerId": "me", "damage": 75, "hp": 925, "shield": 0, "isAlive": true, "type": "lava"}])
	eq(m._deferred.size(), 0, "a lava tick on someone else is not held")
	check(not bot.dead, "the faller is untouched")
	_free(m)
