extends "res://tests/test_case.gd"
## The spider net slows, never roots (server: TestSpiderNetSlowsWithoutRooting; status net
## blocksMove false, TurnStarted.moveEnergy 50 = the spider_net item value): a netted player's
## turn has the move buttons on, MoveSync starts from TurnStarted.moveEnergy and walks up to
## moveEnergy × pxPerEnergy px, the energy bar shows it of maxMoveEnergy. Driven through
## match_screen's own handlers with real views, HUD and ShotPlayer.

const PlayerView := preload("res://match/views/player_view.gd")
const SkyView := preload("res://match/views/sky_view.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const Hud := preload("res://match/hud.gd")
const MatchScreen := preload("res://match/match_screen.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const Status := preload("res://match/status_effects.gd")

const DT := 1.0 / 60.0


static func _flat(w: int, h: int, ground_y: int) -> TerrainMask:
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid.resize(w * h)
	m.solid.fill(0)
	for y in range(ground_y, h):
		for x in w:
			m.solid[y * w + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	return m


func _player(id: String, team: int, character: String, x: float) -> Dictionary:
	return {"playerId": id, "displayName": id, "teamId": team, "characterId": character, "hp": 1000, "maxHp": 1000,
		"isAlive": true, "position": {"x": x, "y": 500.0}, "skillEnergy": 0, "items": ["spider_net"],
		"statusEffects": [], "moveEnergy": 100, "maxMoveEnergy": 100}


func _screen() -> Node2D:
	var m: Node2D = MatchScreen.new()
	m._me = "me"
	m._current = "bot"
	m._turn_index = 1
	m._mask = _flat(1200, 700, 500)
	m._moves.terrain = m._mask
	m._players = {"me": _player("me", 1, "rookie", 300.0), "bot": _player("bot", 2, "tanko", 900.0)}
	m._players_layer = Node2D.new()
	m._fx_layer = Node2D.new()
	m._sky = SkyView.new()
	for id in m._players:
		var v: Node2D = PlayerView.new()
		v.walk.terrain = m._mask
		m._players_layer.add_child(v)
		v.setup(m._players[id], id == "me", 1)
		v.get_child(1)._ready()
		m._views[id] = v
	m._hud = Hud.new()
	m._hud._ready()
	m._aim = AimInput.new()
	m._shot_player = ShotPlayer.new()
	m._shot_player.layer = m._fx_layer
	m._shot_player.event_due.connect(m._on_shot_event)
	m._shot_player.fired.connect(m._on_shot_fired)
	m._shot_player.finished.connect(m._on_shot_finished)
	m.send_hook = func(_e: String, _d: Dictionary) -> void: pass
	return m


func _free(m: Node2D) -> void:
	m._shot_player.stop()
	m._hud.free()
	m._aim.free()
	m._shot_player.free()
	m._players_layer.free()
	m._fx_layer.free()
	m._sky.free()
	m.free()


## The bot's spider net shot hits me: ItemUsed, then ShotResolved with the net status on me.
func _net_me(m: Node2D) -> void:
	m._on_event("ItemUsed", {"playerId": "bot", "itemId": "spider_net", "players": {
		"bot": _player("bot", 2, "tanko", 900.0).merged({"items": [], "statusEffects": [{"effectId": "spider_net", "durationTurn": 1}]}),
		"me": _player("me", 1, "rookie", 300.0)}})
	m._on_event("ShotResolved", {"shooterId": "bot", "actionMode": "item", "itemId": "spider_net", "duration": 1.2,
		"projectiles": [{"projectileId": "p1", "path": [
			{"time": 0.0, "position": {"x": 900.0, "y": 480.0}, "velocity": {"x": -600.0, "y": -300.0}},
			{"time": 1.0, "position": {"x": 300.0, "y": 480.0}, "velocity": {"x": -600.0, "y": 300.0}}]}],
		"events": [{"t": 1.0, "type": "damage", "playerId": "me", "amount": 100, "hp": 900},
			{"t": 1.0, "type": "status", "playerId": "me", "effectId": "net", "turns": 1}]})
	m._on_event("TurnStarted", {"turnIndex": 2, "currentPlayerId": "me", "wind": {"direction": 0, "power": 0.0},
		"moveEnergy": 50, "maxMoveEnergy": 100, "skillEnergy": {"me": 10, "bot": 20}, "turnTimeLeft": 20})
	var guard := 0
	while m._shot_player.is_playing() and guard < 2000:
		m._shot_player._process(DT)
		guard += 1


func test_net_only_slows() -> void:
	check(not GameData.status_blocks_move("net"), "game data: net does not block moving")
	check(not Status.blocks_move([{"effectId": "net", "durationTurn": 1}]), "a netted list does not root")


func test_netted_turn_can_walk_half() -> void:
	var m := _screen()
	_net_me(m)
	check(Status.has(m._players["me"]["statusEffects"], "net"), "net on me after the replay")
	eq(m._current, "me", "my turn")
	check(m._can_act() and not m._is_rooted(), "I may act and am not rooted")
	var left: Button = m._hud._left
	var right: Button = m._hud._right
	check(not left.disabled and not right.disabled, "the move buttons are on")
	eq(m._moves.energy, 50, "MoveSync starts from TurnStarted.moveEnergy")
	eq([int(m._hud._energy.value), int(m._hud._energy.max_value)], [50, 100], "the bar: 50 of 100")
	m._hold_dir = 1
	for i in 120:
		m._process(DT)
	m._hold_dir = 0
	m._moves.release()
	near(m._moves.position.x - 300.0, 50.0 * GameData.px_per_energy(), 1.0, "walked moveEnergy × pxPerEnergy px")
	eq(m._moves.energy, 0, "all the energy spent")
	_free(m)
