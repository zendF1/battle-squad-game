extends "res://tests/test_case.gd"
## Đĩa Bay Thép round 2 (server docs/contracts/ufo-skills.md, migration 113): the turret (TurretModel's
## angles, clamp, tips and plan; BossBody turning it, its states, its muzzle, the crash popping the
## cannon off), the laser one beam per member from the turned tip (TurretBeamsFx), the shell rain's
## signal flare then missiles, the blind bomb's flash flare and map flash, the white-out's clear circle
## round my own unit only. Shots: tests/fixtures/boss_ufo_shots.json (built to the contract).

const BossFixture := preload("res://tests/boss_fixture.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const TurretModel := preload("res://match/boss/turret_model.gd")
const TurretBeamsFx := preload("res://match/boss/turret_beams_fx.gd")
const BossBody := preload("res://match/boss/boss_body.gd")
const BossAnim := preload("res://match/boss/boss_anim.gd")
const BlindOverlay := preload("res://match/views/blind_overlay.gd")
const UnitShell := preload("res://match/views/unit_shell.gd")
const Skills := preload("res://match/skills.gd")
const BossGlobal := preload("res://match/views/skills/boss_global.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const SkyView := preload("res://match/views/sky_view.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const Hud := preload("res://match/hud.gd")
const MatchScreen := preload("res://match/match_screen.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const TerrainView := preload("res://match/terrain/terrain_view.gd")
const Art := preload("res://ui/art.gd")
const FIXTURE := "res://tests/fixtures/boss_ufo_shots.json"
const DT := 1.0 / 60.0


static func _fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


static func _turret_json() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/bosses/steel_robot/turret/turret.json"))


# ── Game data and fixtures ───────────────────────────────────────────────────

func test_game_data_113() -> void:
	BossFixture.take()
	var boss: Dictionary = {}
	for b in GameData.bosses():
		if b["bossId"] == "steel_robot":
			boss = b
	var t: Dictionary = boss.get("turret", {})
	var art := _turret_json()
	near(float(t["x"]), float(art["unit"]["mount"][0]) / 100.0 * PlayerView.BOSS_ART_PER_BODY, 0.002, "the server's pivot x is the art's")
	near(float(t["y"]), -float(art["unit"]["mount"][1]) / 100.0 * PlayerView.BOSS_ART_PER_BODY, 0.002, "y")
	near(float(t["reach"]), float(art["unit"]["tips"]["mid"][0]) / 100.0 * PlayerView.BOSS_ART_PER_BODY, 0.002, "reach: the mid tip")
	eq(GameData.boss_skill("steel_robot", "laser_beam")["pattern"], "each", "the laser: a beam per member")
	eq(GameData.boss_skill("steel_robot", "shell_barrage")["signalKind"], "signal_flare", "the rain's signal")
	eq(GameData.boss_skill("steel_robot", "shell_barrage")["projectileKind"], "saucer_missile", "its missiles")
	var blind := GameData.boss_skill("steel_robot", "blind_bomb")
	eq([blind["kind"], blind["signalKind"], blind["flash"], int(blind["damage"])], ["global", "flash_flare", true, 0], "the blind: a flash, no damage")
	for k in ["saucer_missile", "signal_flare", "flash_flare"]:
		check(UnitShell.is_boss_kind(k) and UnitShell.POINTED.has(k), "%s drawn by UnitShell along its flight" % k)


# ── The turret's geometry ────────────────────────────────────────────────────

func test_turret_angles() -> void:
	near(TurretModel.clamp_deg(45.0, 10.0, 120.0), 45.0, 1e-6, "inside the range")
	near(TurretModel.clamp_deg(-30.0, 10.0, 120.0), 10.0, 1e-6, "above the barrels' reach: the highest")
	near(TurretModel.clamp_deg(170.0, 10.0, 120.0), 120.0, 1e-6, "back under the hull: the lowest")
	near(TurretModel.clamp_deg(-150.0, 10.0, 120.0), 120.0, 1e-6, "behind and up: the nearer way round")
	near(TurretModel.aim_deg(Vector2.ZERO, Vector2(100, 100), 0.0, 10.0, 120.0), 45.0, 1e-4, "down forward 45°")
	near(TurretModel.aim_deg(Vector2.ZERO, Vector2(100, 100), -9.0, 10.0, 120.0), 54.0, 1e-4, "a frame tilted up 9° turns it 9° more")
	near(TurretModel.aim_deg(Vector2.ZERO, Vector2(100, 0), 0.0, 10.0, 120.0), 10.0, 1e-4, "level: clamped")
	near(TurretModel.world_deg(20.0, 1), 20.0, 1e-6, "facing right as drawn")
	near(TurretModel.world_deg(20.0, -1), 160.0, 1e-6, "facing left mirrored")
	var tip := TurretModel.tip(Vector2(35.09, -23.83), 20.0, Vector2(29.27, 0))
	check(tip.distance_to(Vector2(35.09 + 29.27 * cos(deg_to_rad(20.0)), -23.83 + 29.27 * sin(deg_to_rad(20.0)))) < 1e-3, "the tip on the aim")
	near(TurretModel.eased(10.0, 90.0, 0.0), 10.0, 1e-6, "a turn starts where it was")
	check(TurretModel.eased(10.0, 90.0, 0.5) > 50.0, "fast at first (ease out)")
	near(TurretModel.eased(10.0, 90.0, 1.0), 90.0, 1e-6, "and ends on the aim")


func test_turret_states() -> void:
	var cast := []
	for i in 6:
		cast.append(TurretModel.state_for("cast", i, 3, false))
	eq(cast, ["idle", "charge_0", "charge_0", "recoil_0", "recoil_1", "recoil_1"], "the cast charges, recoils on its peak, cools")
	var burst := []
	for i in 6:
		burst.append(TurretModel.state_for("burst", i, 2, false))
	eq(burst, ["charge_0", "charge_1", "hot", "hot", "hot", "hot"], "the burst charges then holds hot")
	eq(TurretModel.state_for("idle", 3, -1, true), "hot", "hot while its beams still fire")
	eq(TurretModel.state_for("fly", 1, -1, false), "idle", "else idle")
	eq(TurretModel.state_for("cast", 3, 3, false, {"idle": 1}), "idle", "a state without a picture: idle")


func test_turret_plan() -> void:
	var laser: Dictionary = _fixture()["laser_beam"]
	var plan := TurretModel.cues(laser["events"], [])
	var beams: Array = laser["events"].filter(func(e): return e["type"] == "beam")
	eq(plan["aims"].size(), 3, "an aim per beam")
	for k in 3:
		near(float(plan["aims"][k]["t"]), float(beams[k]["t"]), 1e-6, "in the beams' order")
		eq(plan["aims"][k]["at"], Vector2(beams[k]["to"]["x"], beams[k]["to"]["y"]), "onto the member")
	near(float(plan["hot_from"]), 0.6, 1e-6, "hot from the first beam")
	near(float(plan["hot_until"]), 0.6 + 0.7 + 0.28, 1e-6, "until the last ends")
	check(float(plan["rest"]) > float(plan["hot_until"]), "then rests")
	var none := TurretModel.cues([], [])
	eq([none["aims"], none["rest"]], [[], -1.0], "nothing to aim at: no plan")
	var hold := BossAnim.action_for("skill", "laser_beam", {"kind": "beam"}, laser["events"], [])
	eq(hold["anim"], "burst", "the laser bursts")
	near(float(hold["at"]) + float(hold["hold"]), 0.6 + 0.7 + 0.28, 1e-6, "its peak held over every beam")
	var witch := BossAnim.action_for("skill", "frost_beam", {"kind": "beam"}, [{"t": 0.6, "type": "beam", "duration": 0.5},
		{"t": 0.6, "type": "beam", "duration": 0.5}], [])
	near(float(witch["hold"]), 0.3, 1e-6, "beams all at once keep the old hold")


func test_body_turns_the_turret() -> void:
	var b := BossBody.new()
	b.setup("steel_robot", 174.0)
	check(b.has_turret(), "the saucer has its turret")
	var t := _turret_json()
	near(b.turret_angle(), float(t["rest"]), 1e-6, "at rest: 20°")
	var k := 174.0 / 240.0
	var mid := float(t["tips"]["mid"][0]) * k
	var d := b.muzzle_position() - b.turret_pivot()
	near(d.length(), mid, 0.01, "the muzzle is the mid tip, %f px from the pivot" % mid)
	near(rad_to_deg(d.angle()), 20.0, 0.01, "facing right: pointing down forward")
	var pivot := b.turret_pivot()
	near(pivot.x, float(t["mount"][0]) * k, 0.01, "the pivot on the mount")
	b.face(-1.0)
	d = b.muzzle_position() - b.turret_pivot()
	near(rad_to_deg(d.angle()), 160.0, 0.01, "facing left: mirrored")
	near(b.turret_pivot().x, -float(t["mount"][0]) * k, 0.01, "the mount mirrored too")
	b.face(1.0)
	var target := b.turret_pivot() + Vector2(200, 200)
	b.aim_turret_at(target)
	b._process(0.05)
	check(b.turret_angle() > 20.0 and b.turret_angle() < 45.0, "turning (%f)" % b.turret_angle())
	b._process(TurretModel.TURN_SEC)
	near(b.turret_angle(), 45.0, 0.5, "on the aim after TURN_SEC")
	var line := (target - b.turret_pivot()).normalized()
	var tip := b.muzzle_position() - b.turret_pivot()
	check(absf(line.cross(tip)) < 1.0, "the tip on the line from the pivot to the target")
	b.aim_turret_at(b.turret_pivot() + Vector2(300, -200)) # up forward: out of its reach
	b._process(0.5)
	near(b.turret_angle(), 10.0, 0.01, "clamped at its highest")
	b.aim_turret_at(b.turret_pivot() + Vector2(-300, 50)) # behind: clamped
	b._process(0.5)
	near(b.turret_angle(), 120.0, 0.01, "clamped at its lowest behind")
	var toward := b.tip_toward(b.turret_pivot() + Vector2(100, 100))
	near(rad_to_deg((toward - b.turret_pivot()).angle()), 45.0, 0.5, "tip_toward: where it will be")
	b.lean = 0.2
	var leaned := b.muzzle_position()
	b.lean = 0.0
	check(leaned.distance_to(b.muzzle_position()) > 3.0, "the tip follows the lean")
	b.free()


func test_body_plays_the_plan_and_states() -> void:
	var laser: Dictionary = _fixture()["laser_beam"]
	var b := BossBody.new()
	b.setup("steel_robot", 174.0)
	b.position = Vector2(1895, 455)
	b.face(-1.0)
	b.play_action(BossAnim.action_for("skill", "laser_beam", {"kind": "beam"}, laser["events"], []))
	b.play_turret(TurretModel.cues(laser["events"], []))
	var beams: Array = laser["events"].filter(func(e): return e["type"] == "beam")
	var t := 0.0
	var states := {}
	for k in beams.size():
		var at := float(beams[k]["t"])
		while t < at:
			b._process(DT)
			t += DT
			states[b.turret_state()] = true
		var to := Vector2(beams[k]["to"]["x"], beams[k]["to"]["y"])
		var line := (to - b.turret_pivot()).normalized()
		var tip := b.muzzle_position() - b.turret_pivot()
		check(absf(line.cross(tip.normalized())) < 0.05 or b.turret_angle() in [10.0, 120.0],
			"beam %d: the turret points at %s when it fires" % [k, beams[k]["targetId"]])
	eq(b.turret_state(), "hot", "hot while the beams fire")
	check(states.has("charge_0") or states.has("charge_1"), "it charged first")
	for i in 120:
		b._process(DT)
	near(b.turret_angle(), 20.0, 0.01, "back at rest after")
	eq(b.turret_state(), "idle", "and idle")
	b.free()


func test_cast_recoil_flashes_the_tips() -> void:
	var b := BossBody.new()
	b.setup("steel_robot", 174.0)
	b.play_action({"anim": "cast", "at": 0.3})
	var flashed := false
	for i in 40:
		b._process(DT)
		flashed = flashed or b._tip_flash > 0.0
	check(flashed, "a flash at the muzzles on the recoil")
	check(not b._tip_smoke.is_empty(), "smoke off them")
	b.free()
	var dome := BossBody.new() # Bom mù: its flare leaves from the dome, the turret stays still
	dome.setup("steel_robot", 174.0)
	dome.play_action({"anim": "cast", "at": 0.3})
	dome.play_turret(TurretModel.cues([], []))
	var states := {}
	for i in 40:
		dome._process(DT)
		states[dome.turret_state()] = true
	eq(states.keys(), ["idle"], "no recoil for a shot not from the turret")
	dome.free()


func test_crash_pops_the_cannon() -> void:
	var b := BossBody.new()
	b.setup("steel_robot", 240.0)
	b.die()
	b._process(0.2)
	check(b._cannon.is_empty(), "on its socket while it shakes")
	b._process(BossBody.CRASH_WOBBLE)
	check(not b._cannon.is_empty(), "popped off with the dome")
	var y: float = b._cannon["p"].y
	var rot: float = b._cannon["rot"]
	b._process(0.3)
	check(b._cannon["p"].y != y and b._cannon["rot"] != rot, "it tumbles away")
	b.free()


# ── The skills in a match ────────────────────────────────────────────────────

func test_laser_beams_from_the_tip_onto_each_member() -> void:
	var m := _screen()
	var shot: Dictionary = _fixture()["laser_beam"].duplicate(true)
	_run(m, DT) # the views settle (a first frame faces them by where they stand)
	m._on_event("ShotResolved", shot)
	var boss = m._views["boss_steel_robot"]
	eq(boss.facing(), -1, "the boss turns toward the party")
	var fx = m._skill_view.each_fx()
	check(fx is TurretBeamsFx, "one beam per member, one after another")
	check(m._skill_view.frames_map(), "the map framed")
	var beams: Array = shot["events"].filter(func(e): return e["type"] == "beam")
	var seen := {}
	var t := 0.0
	while t < float(shot["duration"]):
		_run(m, DT)
		t += DT
		var seg: Array = fx.segment_at(m._shot_player.time())
		if seg.is_empty():
			continue
		var i: int = fx.beam_at(m._shot_player.time())
		seen[i] = true
		# synced before the figure moved on this frame: within a frame's bob / turn
		var off := Vector2(seg[0]).distance_to(m._fx_layer.to_local(boss.muzzle_position()))
		check(off < 6.0, "beam %d leaves from the turret's tip (%.2f px)" % [i, off])
		eq(seg[1], Vector2(beams[i]["to"]["x"], beams[i]["to"]["y"]), "and ends on its member")
	eq(seen.keys().size(), 3, "every member's beam drawn")
	for id in ["p1", "me", "p2"]:
		check(int(m._players[id]["hp"]) < int(_fixture()["players"][id]["hp"]), "%s hit" % id)
	_free(m)


func test_rain_signal_then_missiles() -> void:
	var rain: Dictionary = _fixture()["shell_barrage"]
	var tl := ShotTimeline.new(rain)
	eq(tl.kind(0), "signal_flare", "the signal first")
	var flare := tl.events_of("flare")
	var start := tl.events_of("rain")
	check(not flare.is_empty() and not start.is_empty(), "flare and rain events")
	near(float(flare[0]["t"]), tl.projectile_end(0), 1e-3, "the flare event when it lands")
	near(float(start[0]["t"]) - float(flare[0]["t"]), 0.6, 1e-3, "the rain signalDelay later")
	for i in range(1, tl.projectiles.size()):
		check(tl.launch_time(i) >= float(start[0]["t"]) - 1e-6 and tl.kind(i) == "saucer_missile", "missile %d after the rain starts" % i)
	var m := _screen()
	_run(m, DT) # the views settle (a first frame faces them by where they stand)
	m._on_event("ShotResolved", rain.duplicate(true))
	var view = m._skill_view
	check(view.signalled(), "the boss rain knows its signal")
	check(not view.is_missile("a1") and view.is_missile("a2"), "the signal is not a shell")
	check(m._shot_player.muzzle == null, "the muzzle taken by play()")
	var boss = m._views["boss_steel_robot"]
	_run(m, 0.6 + DT)
	var first: Node2D = m._shot_player._views[0]
	check(first is UnitShell and first.kind == "signal_flare", "the signal flare drawn")
	check(first.position.distance_to(m._fx_layer.to_local(boss.muzzle_position())) < 30.0, "leaving from the turret's tip")
	_run(m, float(flare[0]["t"]) - 0.6)
	var st: Dictionary = view.fx_state()
	check(st["landed"] and st["column"], "it landed: the signal smoke rises")
	_run(m, 0.7)
	check(view.fx_state()["raining"], "then the missiles fall")
	check(m._shot_player._views[1] is UnitShell and m._shot_player._views[1].kind == "saucer_missile", "as saucer missiles")
	_free(m)


func test_blind_flash_and_my_circle() -> void:
	var m := _screen()
	var shot: Dictionary = _fixture()["blind_bomb"].duplicate(true)
	_run(m, DT) # the views settle (a first frame faces them by where they stand)
	m._on_event("ShotResolved", shot)
	check(m._skill_view is BossGlobal, "a global")
	var boss = m._views["boss_steel_robot"]
	var flare: Node2D = m._shot_player._views[0]
	check(flare is UnitShell and flare.kind == "flash_flare", "the flash flare")
	var top: Vector2 = boss.figure().top_position()
	check((flare.position + flare.lead).distance_to(top) < 1.0 and flare.lead.y < 0.0, "it leaves from the top of the craft")
	_run(m, 1.2 + DT)
	var flash = m._skill_view.flash()
	check(flash != null and flash.color.a > 0.9, "the whole screen flashes white")
	for id in ["p1", "me", "p2"]:
		check(m._players[id]["statusEffects"].any(func(e): return e["effectId"] == "blind"), "%s blinded" % id)
		eq(int(m._players[id]["hp"]), int(_fixture()["players"][id]["hp"]), "no damage on %s" % id)
	_run(m, 0.1)
	var o = m.blind_overlay()
	check(o.is_on(), "my white-out on")
	var me = m._views["me"]
	var c: Dictionary = o.clear()
	var h: float = me.head_lift() - 10.0
	check(Vector2(c["centre"]).distance_to(me.get_global_transform() * Vector2(0, -h * 0.5)) < 0.5, "round my unit")
	near(float(c["radius"]), BlindOverlay.CLEAR_BODIES * h, 0.01, "1.5 bodies")
	me.position += Vector2(120, 30)
	_run(m, DT)
	check(Vector2(o.clear()["centre"]).distance_to(me.get_global_transform() * Vector2(0, -h * 0.5)) < 0.5, "it follows my unit")
	var mate = m._views["p2"]
	check(Vector2(o.clear()["centre"]).distance_to(mate.get_global_transform() * Vector2(0, -h * 0.5)) > 100.0,
		"not my teammate's (one circle: mine)")
	_free(m)


func test_clear_circle_follows_the_camera() -> void:
	var at := BlindOverlay.clear_circle(Transform2D(0.0, Vector2(2, 2), 0.0, Vector2(300, 200)), 56.0)
	eq(at["centre"], Vector2(300, 200 - 56.0), "the figure's middle, zoomed")
	near(float(at["radius"]), 1.5 * 56.0 * 2.0, 1e-4, "the radius zoomed too")
	var o := BlindOverlay.new()
	o.set_clear(Vector2(10, 20), 30.0)
	eq(o.clear(), {"centre": Vector2(10, 20), "radius": 30.0}, "kept")
	o.free()
	var f := BossGlobal.FlashFx.new(1.2)
	f.step(0.05)
	near(f.color.a, 1.0, 1e-6, "full white at first")
	f.step(1.2)
	check(f.color.a < 0.01 and f.done(), "faded out")
	f.free()


# ── match_screen without its scene (like test_boss_v5.gd) ─────────────────────

static func _ground(w: int, h: int, top: int) -> TerrainMask:
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid.resize(w * h)
	m.solid.fill(0)
	for y in range(top, h):
		for x in w:
			m.solid[y * w + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	return m


func _screen() -> Node2D:
	BossFixture.take()
	var fx := _fixture()
	var m: Node2D = MatchScreen.new()
	var bid := "boss_steel_robot"
	m._me = "me"
	m._current = bid
	m._turn_index = 5
	m._players = {}
	for id in fx["players"]:
		var p: Dictionary = fx["players"][id].duplicate(true)
		p["statusEffects"] = []
		p["items"] = []
		p["skillEnergy"] = 0
		p["moveEnergy"] = 100
		p["maxMoveEnergy"] = 100
		m._players[id] = p
	m._mask = _ground(2400, 1120, 640)
	m._moves.terrain = m._mask
	m._terrain_view = TerrainView.new()
	m._players_layer = Node2D.new()
	m._fx_layer = Node2D.new()
	m._screen_fx = CanvasLayer.new()
	m._sky = SkyView.new()
	m._lava_view = preload("res://match/boss/lava_view.gd").new()
	m._blind = BlindOverlay.new()
	for id in m._players:
		var v: Node2D = PlayerView.new()
		v.walk.terrain = m._mask
		m._players_layer.add_child(v)
		v.setup(m._players[id], id == "me", 1)
		if not v.is_boss_side():
			v.get_child(1)._ready()
		m._views[id] = v
	m._hud = Hud.new()
	m._hud._ready()
	m._hud.boss_hud()._ready()
	m._aim = AimInput.new()
	m._shot_player = ShotPlayer.new()
	m._shot_player.layer = m._fx_layer
	m._shot_player.event_due.connect(m._on_shot_event)
	m._shot_player.fired.connect(m._on_shot_fired)
	m._shot_player.finished.connect(m._on_shot_finished)
	m.send_hook = func(_event: String, _data: Dictionary) -> void: pass
	m._load_boss({"boss": {"bossId": "steel_robot", "playerId": bid, "turnLimit": 20, "round": 3}, "players": m._players})
	return m


func _free(m: Node2D) -> void:
	m._shot_player.stop()
	for n in [m._hud, m._aim, m._shot_player, m._players_layer, m._fx_layer, m._sky, m._terrain_view, m._screen_fx, m._lava_view, m._blind]:
		if is_instance_valid(n):
			n.free()
	m.free()


func _run(m: Node2D, sec: float) -> void:
	var t := 0.0
	while t < sec - 1e-9:
		m._shot_player._process(DT)
		m._process(DT)
		for v in m._views.values():
			v._process(DT)
			if v.is_boss_side():
				v.figure()._process(DT)
		t += DT
