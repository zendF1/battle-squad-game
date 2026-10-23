extends "res://tests/test_case.gd"
## Boss mode v2 on the client: the UnitFlew flight (FlightModel), the bomber's warning light
## (BomberModel: a red pulse, no prop), the units' flying / behavior / movement from the state or the game data, which
## explodes are a minion's own blast (BlastEvents), the summon event's full unit, and the views:
## a flier's flight and ground shadow, a bomber's warning, prime and vanish; match_screen holds the
## events after a flight until it lands.

const BossFixture := preload("res://tests/boss_fixture.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const FlightModel := preload("res://match/boss/flight_model.gd")
const BomberModel := preload("res://match/boss/bomber_model.gd")
const BlastEvents := preload("res://match/boss/blast_events.gd")
const BossBody := preload("res://match/boss/boss_body.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const MatchScreen := preload("res://match/match_screen.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const WalkPath := preload("res://match/move/walk_path.gd")
const Hud := preload("res://match/hud.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const DT := 1.0 / 60.0


func test_flight_interpolation() -> void:
	var f := FlightModel.new(Vector2(100, 300), Vector2(400, 300), 1.2)
	eq(f.position_at(0.0), Vector2(100, 300), "starts at from")
	eq(f.position_at(1.2), Vector2(400, 300), "ends at to")
	eq(f.position_at(5.0), Vector2(400, 300), "and stays there")
	near(f.position_at(0.6).x, 250.0, 0.01, "half way in x at half time")
	near(f.position_at(0.6).y, 300.0 - f.arc_height(), 0.01, "the arc's top in the middle")
	near(f.arc_height(), 300.0 * FlightModel.ARC_PER_PX, 0.01, "the arc grows with the distance")
	check(f.position_at(0.3).x - 100.0 < 75.0, "eased in: slower than linear at first")
	check(f.position_at(0.9).x - 100.0 > 225.0, "eased out: ahead of linear late")
	var long := FlightModel.new(Vector2(0, 0), Vector2(2000, 0), 3.0)
	eq(long.arc_height(), FlightModel.ARC_MAX, "a long flight's arc is capped")
	check(f.lean_at(0.6) > 0.0 and f.lean_at(0.6) <= FlightModel.LEAN_MAX + 0.001, "leans right flying right")
	near(f.lean_at(0.0), 0.0, 0.001, "no lean at rest")
	check(FlightModel.new(Vector2(400, 0), Vector2(100, 0), 1.0).lean_at(0.5) < 0.0, "leans left flying left")
	var stepped := FlightModel.new(Vector2(0, 0), Vector2(100, -50), 0.5)
	var p := Vector2.ZERO
	for i in 40:
		p = stepped.step(DT)
	check(stepped.done() and p == Vector2(100, -50), "step() lands on to")
	var e = FlightModel.from_event({"playerId": "d", "from": {"x": 10, "y": 20}, "to": {"x": 210, "y": 120}, "duration": 0.9})
	check(e != null and e.from == Vector2(10, 20) and e.to == Vector2(210, 120) and e.duration == 0.9, "from a UnitFlew")
	check(FlightModel.from_event({"playerId": "d"}) == null, "a UnitFlew without from / to: none")
	check(FlightModel.from_event({"from": {"x": 0, "y": 0}, "to": {"x": 5, "y": 0}}).done(), "no duration: a jump")


func test_bomber_warning() -> void:
	var targets: Array = [Vector2(500, 300), Vector2(160, 300)]
	near(BomberModel.nearest(Vector2(100, 300), targets), 60.0, 0.001, "the nearest player")
	check(BomberModel.warning(Vector2(100, 300), targets, 70.0), "within detonateRange: warning")
	check(not BomberModel.warning(Vector2(0, 300), targets, 70.0), "farther: none")
	check(not BomberModel.warning(Vector2(160, 300), targets, 0.0), "no range in the game data: never")
	check(not BomberModel.warning(Vector2(160, 300), [], 70.0), "nobody left: none")
	eq(BomberModel.pulse(1.0, false), 0.0, "no glow without the warning")
	var lo := 1.0
	var hi := 0.0
	for i in 60:
		var g := BomberModel.pulse(i / 60.0, true)
		lo = minf(lo, g)
		hi = maxf(hi, g)
	check(lo < 0.05 and hi > BomberModel.PULSE_MAX - 0.05, "the warning pulses red (%f..%f)" % [lo, hi])


func test_unit_kinds_from_state_and_game_data() -> void:
	BossFixture.take()
	check(GameData.unit_flying({"role": "boss", "bossId": "ice_witch"}), "the witch flies (game data)")
	check(not GameData.unit_flying({"role": "boss", "bossId": "steel_robot"}), "the robot stands")
	check(GameData.unit_flying({"role": "minion", "bossId": "steel_robot", "minionId": "drone"}), "a drone flies (movement fly)")
	check(not GameData.unit_flying({"role": "minion", "bossId": "lava_crab", "minionId": "crab"}), "a crabling walks")
	check(not GameData.unit_flying({"role": "boss", "bossId": "ice_witch", "flying": false}), "the state's flying wins")
	check(not GameData.unit_flying({"characterId": "rookie"}), "a player never")
	eq(GameData.unit_behavior({"role": "minion", "bossId": "lava_crab", "minionId": "crab"}), "bomber", "a crabling bombs")
	eq(GameData.unit_behavior({"role": "minion", "bossId": "ice_witch", "minionId": "snowman"}), "shooter", "a snowman shoots")
	eq(GameData.unit_behavior({"role": "minion", "minionId": "snowman", "behavior": "bomber"}), "bomber", "the state's behavior wins")
	eq(GameData.unit_movement({"role": "minion", "bossId": "lava_crab", "minionId": "crab"}), "walk", "walks")
	eq(GameData.unit_detonate_range({"role": "minion", "bossId": "steel_robot", "minionId": "drone"}), 70.0, "detonateRange")
	eq(GameData.unit_detonate_range({"characterId": "rookie"}), 0.0, "none for a player")
	check(GameData.unit_explodes_on_death({"role": "minion", "bossId": "ice_witch", "minionId": "snowman"}), "a snowman blasts when it dies")
	check(not GameData.unit_explodes_on_death({"role": "minion", "bossId": "steel_robot", "minionId": "drone"}), "a drone does not")
	eq(GameData.unit_explode_radius({"role": "minion", "bossId": "ice_witch", "minionId": "snowman"}), 140.0, "explodeRadius")
	eq(int(GameData.boss("ice_witch")["turnLimit"]), 30, "the witch's 30 turns")
	check(GameData.boss_hover("ice_witch").has("minX"), "her hover band")
	eq(GameData.boss_hover("steel_robot"), {}, "none on the ground")


func _players() -> Dictionary:
	return {"me": {"playerId": "me", "teamId": 1, "position": {"x": 300, "y": 500}},
		"minion_drone_1": {"playerId": "minion_drone_1", "teamId": 2, "role": "minion", "bossId": "steel_robot", "minionId": "drone",
			"bodySize": 0.7, "position": {"x": 320, "y": 440}},
		"minion_snowman_1": {"playerId": "minion_snowman_1", "teamId": 2, "role": "minion", "bossId": "ice_witch", "minionId": "snowman",
			"bodySize": 0.85, "position": {"x": 600, "y": 500}},
		"minion_snowman_2": {"playerId": "minion_snowman_2", "teamId": 2, "role": "minion", "bossId": "ice_witch", "minionId": "snowman",
			"bodySize": 0.85, "position": {"x": 680, "y": 500}},
		"boss_ice_witch": {"playerId": "boss_ice_witch", "teamId": 2, "role": "boss", "bossId": "ice_witch", "position": {"x": 1000, "y": 300}}}


func test_detonation_is_tagged() -> void:
	BossFixture.take()
	var events: Array = [{"t": 0.4, "type": "explode", "position": {"x": 320, "y": 440}, "radius": 80, "crater": 20},
		{"t": 0.4, "type": "damage", "playerId": "me", "amount": 750, "hp": 750, "cause": "self_destruct"},
		{"t": 0.4, "type": "die", "playerId": "minion_drone_1", "cause": "self_destruct"}]
	eq(BlastEvents.tag(events, _players(), "minion_drone_1", "self_destruct"), 1, "one blast")
	eq(BlastEvents.blast_of(events[0]), {"minion": "minion_drone_1", "kind": "self_destruct"}, "the drone's own")
	eq(BlastEvents.blast_of(events[2]), {}, "its die is no blast")
	near(BlastEvents.detonation_time(events), 0.4, 0.001, "when it blows up")
	var shell: Array = [{"t": 0.9, "type": "explode", "position": {"x": 320, "y": 440}, "radius": 30, "projectileId": "p1"}]
	eq(BlastEvents.tag(shell, _players(), "me", "weapon"), 0, "a shell's impact is not")
	eq(BlastEvents.detonation_time(shell), -1.0, "no detonation")


func test_death_blast_and_chain() -> void:
	BossFixture.take()
	var events: Array = [{"t": 0.8, "type": "explode", "position": {"x": 610, "y": 500}, "radius": 30, "projectileId": "p1"},
		{"t": 0.8, "type": "damage", "playerId": "minion_snowman_1", "amount": 900, "hp": 0, "cause": "explosion"},
		{"t": 0.8, "type": "die", "playerId": "minion_snowman_1"},
		{"t": 0.8, "type": "explode", "position": {"x": 600, "y": 500}, "radius": 80, "crater": 20},
		{"t": 0.8, "type": "damage", "playerId": "minion_snowman_2", "amount": 900, "hp": 0, "cause": "death_blast"},
		{"t": 0.8, "type": "die", "playerId": "minion_snowman_2"},
		{"t": 0.8, "type": "explode", "position": {"x": 680, "y": 500}, "radius": 80, "crater": 20}]
	eq(BlastEvents.tag(events, _players(), "me", "weapon"), 2, "the blast and its chain")
	eq(BlastEvents.blast_of(events[0]), {}, "my shell is a shell")
	eq(BlastEvents.blast_of(events[3]), {"minion": "minion_snowman_1", "kind": "death_blast"}, "the first snowman bursts")
	eq(BlastEvents.blast_of(events[6]), {"minion": "minion_snowman_2", "kind": "death_blast"}, "and the one it took with it")
	var with_boss: Array = [{"t": 0.5, "type": "die", "playerId": "boss_ice_witch"},
		{"t": 0.5, "type": "die", "playerId": "minion_snowman_1", "cause": "boss_defeated"},
		{"t": 0.6, "type": "explode", "position": {"x": 600, "y": 500}, "radius": 30, "projectileId": "p2"}]
	eq(BlastEvents.tag(with_boss, _players(), "me", "weapon"), 0, "minions dying with the boss do not blast")
	var named: Array = [{"t": 0.5, "type": "explode", "position": {"x": 0, "y": 0}, "radius": 80, "playerId": "minion_snowman_2", "cause": "death_blast"}]
	eq(BlastEvents.tag(named, _players(), "me", "weapon"), 1, "an explode naming its minion")
	eq(BlastEvents.blast_of(named[0])["minion"], "minion_snowman_2", "taken as it says")


## The server's own shape (f1e239f): the explode names its minion, radius the crater, blastRadius
## the reach; a burn death's blast in a ShotResolved of its own (actionMode death_blast).
func test_server_shaped_blasts() -> void:
	BossFixture.take()
	var det: Array = [{"t": 0.2, "type": "explode", "playerId": "minion_drone_1", "position": {"x": 320, "y": 440}, "radius": 20,
			"crater": "bowl", "terrainVersion": 5, "blastRadius": 80},
		{"t": 0.2, "type": "damage", "playerId": "me", "amount": 600, "hp": 900, "cause": "self_destruct"},
		{"t": 0.2, "type": "die", "playerId": "minion_drone_1", "cause": "self_destruct"}]
	eq(BlastEvents.tag(det, _players(), "minion_drone_1", "self_destruct"), 1, "the detonation")
	eq(BlastEvents.blast_of(det[0])["kind"], "self_destruct", "the shooter's own")
	var burn: Array = [{"t": 0.2, "type": "explode", "playerId": "minion_snowman_1", "position": {"x": 600, "y": 500}, "radius": 24,
		"crater": "bowl", "terrainVersion": 9, "blastRadius": 140}]
	BlastEvents.tag(burn, _players(), "minion_snowman_1", "death_blast")
	eq(BlastEvents.blast_of(burn[0]), {"minion": "minion_snowman_1", "kind": "death_blast"}, "a burn death's own blast")
	var chain: Array = [{"t": 0.8, "type": "die", "playerId": "minion_snowman_1"},
		{"t": 0.8, "type": "explode", "playerId": "minion_snowman_1", "position": {"x": 600, "y": 500}, "radius": 24, "crater": "bowl", "blastRadius": 140},
		{"t": 0.8, "type": "damage", "playerId": "minion_snowman_2", "amount": 270, "hp": 0, "cause": "death_blast"},
		{"t": 0.8, "type": "die", "playerId": "minion_snowman_2", "cause": "death_blast"},
		{"t": 0.8, "type": "explode", "playerId": "minion_snowman_2", "position": {"x": 680, "y": 500}, "radius": 24, "crater": "bowl", "blastRadius": 140}]
	eq(BlastEvents.tag(chain, _players(), "me", "weapon"), 2, "the chain")
	eq(BlastEvents.blast_of(chain[4])["minion"], "minion_snowman_2", "the second snowman's")


func test_summon_full_unit() -> void:
	BossFixture.take()
	var full := MatchScreen.summon_player({"type": "summon", "playerId": "minion_drone_3", "minionId": "drone", "position": {"x": 900, "y": 400},
		"hp": 500, "maxHp": 650, "displayName": "Drone Tấn Công", "teamId": 2, "bodySize": 0.8, "flying": true, "behavior": "bomber",
		"movement": "fly"}, "steel_robot", 2)
	eq(full["displayName"], "Drone Tấn Công", "the event's name")
	eq([full["hp"], full["maxHp"], full["bodySize"]], [500, 650, 0.8], "its hp, maxHp, bodySize")
	eq([full["flying"], full["behavior"], full["movement"]], [true, "bomber", "fly"], "how it moves and fights")
	eq([full["role"], full["bossId"], full["minionId"], full["teamId"]], ["minion", "steel_robot", "drone", 2], "a minion of the boss")
	var old := MatchScreen.summon_player({"type": "summon", "playerId": "minion_crab_3", "minionId": "crab", "position": {"x": 900, "y": 400},
		"hp": 800}, "lava_crab", 2)
	eq(old["displayName"], "Cua con", "an older event: the type's name")
	eq([old["maxHp"], old["bodySize"], old["behavior"], old["movement"], old["flying"]], [800, 0.75, "bomber", "walk", false], "and its type's rest")


func test_body_prime_vanish() -> void:
	var b := BossBody.new()
	b.setup("drone", 40.0)
	b.bomber = true
	b.prime(0.4)
	check(b.priming(), "about to blow up")
	b._process(0.2)
	check(b.scale.x > 1.0 and b.is_flashing(), "swelling and flashing")
	b._process(0.3)
	check(not b.priming(), "burnt down")
	b.vanish()
	check(b.vanished() and b.scale == Vector2.ONE, "gone at once")
	b.free()


func _ground(w: int, h: int, top: int) -> TerrainMask:
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid.resize(w * h)
	m.solid.fill(0)
	for x in w:
		for y in range(top, h):
			m.solid[y * w + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	return m


func test_flier_view() -> void:
	BossFixture.take()
	var v := PlayerView.new()
	v.walk.terrain = _ground(400, 300, 250)
	v.setup({"playerId": "minion_drone_1", "teamId": 2, "role": "minion", "bossId": "steel_robot", "minionId": "drone", "bodySize": 0.7,
		"hp": 650, "maxHp": 650, "position": {"x": 100, "y": 150}, "flying": true}, false, 1)
	check(v.flying and v.is_bomber(), "a flying bomber")
	check(v.figure().flying and v.figure().bomber, "its figure hovers, a bomber")
	v._process(DT)
	near(v.ground_drop, 100.0, 0.5, "its shadow on the ground 100 px below")
	v.set_warning(true)
	check(v.warning(), "the warning on")
	v.fly(Vector2(100, 150), Vector2(300, 120), 0.5)
	check(v.in_flight(), "flying")
	v._process(0.25)
	check(v.position.x > 120.0 and v.position.x < 280.0 and v.position.y < 135.0, "on the way, a little above the line")
	check(v.figure().lean > 0.0, "leaning into it")
	for i in 30:
		v._process(DT)
	check(not v.in_flight() and v.position == Vector2(300, 120), "landed on to")
	eq(v.figure().lean, 0.0, "upright again")
	v.vanish()
	check(v.vanished() and v.is_dead(), "blown up")
	v.free()


## A view with what match_screen asks of it for a flight.
class FakeView extends Node2D:
	var walk := WalkPath.new()
	var flown := []
	var left := 0.0
	var dead := false

	func fly(from: Vector2, to: Vector2, sec: float) -> void:
		flown.append([from, to, sec])
		position = from
		left = sec

	func in_flight() -> bool:
		return left > 0.0

	func step(dt: float) -> void:
		left = maxf(0.0, left - dt)

	func falling_out() -> bool:
		return false

	func walk_to(target: Vector2, _max_sec: float) -> void:
		position = target

	func move_to(target: Vector2, _sec: float, _a = 0, _b = 0) -> void:
		position = target

	func set_hp(_value: int, _max_value: int = -1) -> void:
		pass

	func set_shield(_value: int) -> void:
		pass

	func set_dead() -> void:
		dead = true

	func set_active(_on: bool) -> void:
		pass

	func clear_aim() -> void:
		pass


func test_flight_holds_the_events_after_it() -> void:
	var m = MatchScreen.new()
	m._me = "me"
	m._current = "minion_drone_1"
	m._mask = _ground(400, 300, 250)
	m._players = {"me": {"playerId": "me", "characterId": "rookie", "isAlive": true, "skillEnergy": 0, "items": [], "statusEffects": [],
			"teamId": 1, "hp": 1000, "maxHp": 1000, "position": {"x": 300.0, "y": 250.0}},
		"minion_drone_1": {"playerId": "minion_drone_1", "role": "minion", "minionId": "drone", "isAlive": true, "teamId": 2, "hp": 650,
			"maxHp": 650, "position": {"x": 50.0, "y": 150.0}, "flying": true, "statusEffects": [], "items": [], "skillEnergy": 0}}
	var drone := FakeView.new()
	var mine := FakeView.new()
	m._views = {"minion_drone_1": drone, "me": mine}
	m.send_hook = func(_event: String, _data: Dictionary) -> void: pass
	var h: Control = Hud.new()
	h._ready()
	h._portrait_art._ready()
	h._portrait_art.character()._ready()
	m._hud = h
	m._aim = AimInput.new()
	m._shot_player = ShotPlayer.new()
	m._fx_layer = Node2D.new()
	m._on_event("UnitFlew", {"playerId": "minion_drone_1", "from": {"x": 50, "y": 150}, "to": {"x": 250, "y": 160}, "duration": 0.9})
	eq(drone.flown.size(), 1, "the flight is drawn")
	eq(m._players["minion_drone_1"]["position"], {"x": 250.0, "y": 160.0}, "the server's position is to")
	m._on_event("PlayerDamaged", [{"playerId": "me", "damage": 75, "hp": 925, "shield": 0, "isAlive": true, "type": "lava"}])
	eq(m._deferred.size(), 1, "what came after waits for the landing")
	eq(int(m._players["me"]["hp"]), 1000, "not applied yet")
	drone.step(0.5)
	m._release_flight_hold()
	eq(m._deferred.size(), 1, "still flying")
	drone.step(0.5)
	m._release_flight_hold()
	eq(m._deferred.size(), 0, "landed: it plays")
	eq(int(m._players["me"]["hp"]), 925, "applied")
	m._on_event("UnitFlew", {"playerId": "nobody", "from": {"x": 0, "y": 0}, "to": {"x": 1, "y": 1}, "duration": 1.0})
	check(not m._flight_hold, "an unknown unit holds nothing")
	h.free()
	m._aim.free()
	m._shot_player.free()
	m._fx_layer.free()
	drone.free()
	mine.free()
	m.free()


func test_camera_rises_for_a_flier() -> void:
	var CameraModel = load("res://match/camera/camera_model.gd")
	var cam = CameraModel.new()
	cam.setup(Vector2(2400, 1120), Vector2(1600, 900))
	cam.sky_turn = true
	cam.pan_to(Vector2(1200, 120))
	for i in 120:
		cam.step(DT)
	check(cam.center.y < 450.0 - 1.0, "a flier's turn: the view rises above the map top (%f)" % cam.center.y)
	cam.sky_turn = false
	cam.pan_to(Vector2(1200, 120))
	for i in 120:
		cam.step(DT)
	near(cam.center.y, 450.0, 0.5, "a walker's turn stays inside the map")
