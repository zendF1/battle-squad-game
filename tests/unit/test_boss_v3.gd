extends "res://tests/test_case.gd"
## Boss mode v3 on the client: the beam fan's geometry (BeamFan: the witch's 20 evenly spaced beams
## to the map bounds, the robot's parallel sweep), the multi-beam drawing (BeamFanFx: hits, stuns),
## the leapt snowman's warning (LeapWarning, the view's glow, match_screen's UnitJumped and turn
## ends), the leap itself (JumpModel: crouch, arc, squash and stretch), the ground shockwave
## (Shockwave), the map-wide rain and its storm, the camera framing the map, and the free summon
## that leaves the boss's turn open for its attack.

const BossFixture := preload("res://tests/boss_fixture.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const BeamFan := preload("res://match/boss/beam_fan.gd")
const BeamFanFx := preload("res://match/views/skills/beam_fan_fx.gd")
const BossBeam := preload("res://match/views/skills/boss_beam.gd")
const BossRain := preload("res://match/views/skills/boss_rain.gd")
const LeapWarning := preload("res://match/boss/leap_warning.gd")
const JumpModel := preload("res://match/boss/jump_model.gd")
const Shockwave := preload("res://match/boss/shockwave.gd")
const StormOverlay := preload("res://match/boss/storm_overlay.gd")
const BossBody := preload("res://match/boss/boss_body.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const SkyView := preload("res://match/views/sky_view.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const Hud := preload("res://match/hud.gd")
const MatchScreen := preload("res://match/match_screen.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const TerrainView := preload("res://match/terrain/terrain_view.gd")
const CameraModel := preload("res://match/camera/camera_model.gd")
const DT := 1.0 / 60.0
const MAP := Vector2(2400, 1120)


func _events(list: Array, t: float = 0.6) -> Array:
	var out: Array = []
	for b in list:
		out.append({"t": t, "type": "beam", "playerId": "boss_ice_witch", "from": {"x": b["from"].x, "y": b["from"].y},
			"to": {"x": b["to"].x, "y": b["to"].y}, "duration": 0.8})
	return out


func _on_bounds(p: Vector2) -> bool:
	return absf(p.x) < 0.01 or absf(p.x - MAP.x) < 0.01 or absf(p.y) < 0.01 or absf(p.y - MAP.y) < 0.01


# ── The beam fan ─────────────────────────────────────────────────────────────

func test_radial_fan_geometry() -> void:
	var centre := Vector2(1200, 380)
	var beams := BeamFan.beams(_events(BeamFan.radial(centre, 20, MAP)))
	eq(beams.size(), 20, "20 beams read from the events")
	var lay := BeamFan.layout(beams)
	eq(lay["kind"], BeamFan.RADIAL, "all from one point: a radial burst")
	eq(lay["origin"], centre, "her body centre")
	near(float(lay["spacing"]), 18.0, 0.01, "evenly spaced every 18°")
	var a := BeamFan.angles(beams)
	for i in a.size():
		near(float(a[i]), 18.0 * i, 0.01, "beam %d at %d°" % [i, 18 * i])
	for b in beams:
		check(_on_bounds(b["to"]), "every beam ends on the map bounds (%s)" % b["to"])
		near(b["dir"].length(), 1.0, 1e-4, "a unit direction")
	var r := BeamFan.bounds(beams)
	eq([r.position, r.end], [Vector2.ZERO, MAP], "the beams span the whole map")
	eq(BeamFan.origins(beams), [centre], "one charge, at her centre")
	var crooked := beams.duplicate(true)
	crooked[3]["dir"] = Vector2.from_angle(deg_to_rad(60.0))
	eq(BeamFan.even_spacing(crooked), -1.0, "one beam off its step: not even")


func test_ray_to_bounds() -> void:
	var o := Vector2(1200, 380)
	eq(BeamFan.ray_to_bounds(o, Vector2.RIGHT, MAP), Vector2(2400, 380), "right edge")
	eq(BeamFan.ray_to_bounds(o, Vector2.LEFT, MAP), Vector2(0, 380), "left edge")
	eq(BeamFan.ray_to_bounds(o, Vector2.UP, MAP), Vector2(1200, 0), "the top")
	eq(BeamFan.ray_to_bounds(o, Vector2.DOWN, MAP), Vector2(1200, 1120), "the bottom")
	var diag := BeamFan.ray_to_bounds(o, Vector2(1, 1), MAP)
	near(diag.x, 1200.0 + 740.0, 0.01, "45° down-right meets the bottom first")
	near(diag.y, 1120.0, 0.01, "at the bottom")
	var shallow := BeamFan.ray_to_bounds(Vector2(100, 1000), Vector2(1, -0.1), MAP)
	near(shallow.x, 2400.0, 0.01, "a shallow ray meets the right edge")


func test_parallel_sweep_and_nearest_beam() -> void:
	var list: Array = []
	for y in [520.0, 600.0, 680.0, 760.0, 840.0]:
		list.append({"t": 0.6, "type": "beam", "playerId": "boss_steel_robot", "from": {"x": 0, "y": y}, "to": {"x": 2400, "y": y}, "duration": 0.8})
	var beams := BeamFan.beams(list)
	var lay := BeamFan.layout(beams)
	eq(lay["kind"], BeamFan.PARALLEL, "5 horizontal beams side by side")
	eq(BeamFan.origins(beams).size(), 5, "five starts")
	eq(BeamFan.nearest_beam(beams, Vector2(900, 690)), 2, "a body at y 690 is on the third beam")
	eq(BeamFan.on_beam(beams[2], Vector2(900, 690)), Vector2(900, 680), "its flash on the beam")
	eq(BeamFan.layout(BeamFan.beams([list[0]]))["kind"], BeamFan.SINGLE, "one beam: the laser")
	eq(BeamFan.layout([])["kind"], "", "none")
	var mixed := BeamFan.beams([list[0], {"type": "beam", "from": {"x": 100, "y": 100}, "to": {"x": 900, "y": 900}}])
	eq(BeamFan.layout(mixed)["kind"], BeamFan.MULTI, "two unrelated beams")


func test_fan_fx_hits_and_stuns() -> void:
	var beams := BeamFan.beams(_events(BeamFan.radial(Vector2(1200, 380), 20, MAP)))
	var fx := BeamFanFx.new()
	fx.setup(beams, {"glow": Color.CYAN, "mid": Color.WHITE, "core": Color.WHITE, "arc": Color.WHITE}, 12000.0)
	check(fx.is_radial(), "a radial burst")
	near(fx.beam_t, 0.6, 1e-6, "the beams leave at their t")
	near(fx.front_at(0, 0.5), 0.0, 1e-6, "no beam during the charge")
	near(fx.front_at(0, 0.65), 600.0, 0.01, "the front sweeps at the laser's speed")
	near(fx.front_at(0, 2.0), 1200.0, 0.01, "to the edge and no further")
	var at := fx.hit(Vector2(1700, 390), 0.65)
	near(at.y, 380.0, 0.01, "the flash on the right-going beam")
	var body := Node2D.new()
	fx.stun(body, 90.0, 0.65, "stun")
	fx.stun(body, 90.0, 0.66, "stun")
	eq([fx.hit_count(), fx.stun_count()], [1, 1], "one hit, one stun (once per player)")
	check(fx.done_at() >= 0.65 + BeamFanFx.STUN_SEC, "it lasts until the stars stop")
	body.free()
	fx.free()


func test_boss_beam_view_picks_the_fan() -> void:
	BossFixture.take()
	var layer := Node2D.new()
	var many := ShotTimeline.new({"shooterId": "boss_ice_witch", "actionMode": "skill", "skillId": "frost_beam", "duration": 2.0,
		"projectiles": [], "events": _events(BeamFan.radial(Vector2(1200, 380), 20, MAP))})
	var v = BossBeam.new()
	v.begin({"layer": layer, "timeline": many, "style": {"kind": "shock_rifle", "tier": "iron"}, "views": {}, "players": {}, "shooter": "boss_ice_witch"})
	check(v.fan() != null and v.frames_map(), "20 beams: one fan drawing, the map framed")
	check(is_nan(v.aim_angle(many)), "no single direction to point")
	v.process(0.7)
	v.end()
	var one := ShotTimeline.new({"shooterId": "boss_ice_witch", "actionMode": "skill", "skillId": "frost_beam", "duration": 2.0,
		"projectiles": [], "events": _events([BeamFan.radial(Vector2(1200, 380), 20, MAP)[0]])})
	var v1 = BossBeam.new()
	v1.begin({"layer": layer, "timeline": one, "style": {}, "views": {}, "players": {}, "shooter": "boss_ice_witch"})
	check(v1.fan() == null and not v1.frames_map(), "one beam: the laser as before")
	near(v1.aim_angle(one), 0.0, 0.01, "pointing along it")
	v1.end()
	layer.free()


# ── The leapt warning ────────────────────────────────────────────────────────

func test_leap_warning_state() -> void:
	var w := LeapWarning.new()
	w.on_jump("s1", 7)
	check(w.warning("s1"), "leapt: about to blow up")
	check(not w.on_turn_end("s1", 7), "the turn it leapt in ending keeps it")
	check(w.warning("s1"), "still warning through the others' turns")
	check(not w.on_turn_end("p2", 8), "someone else's turn")
	w.on_jump("s1", 12) # its next turn: it leapt again (nobody near)
	check(not w.on_turn_end("s1", 12), "a new leap keeps it on")
	check(w.on_turn_end("s1", 17), "its next turn ended without a leap: spent")
	check(not w.warning("s1"), "off")
	w.on_state("s2", {"leapt": true, "isAlive": true}, 20, "p1")
	check(w.warning("s2"), "a snapshot's leapt")
	check(w.on_turn_end("s2", 23), "leapt before this client saw it: its next turn spends it")
	w.on_state("s3", {"leapt": true}, 30, "s3")
	check(not w.on_turn_end("s3", 30), "a snapshot in its own turn: leapt in this turn")
	w.on_state("s3", {"leapt": false}, 31, "p1")
	check(not w.warning("s3"), "the state says no more")
	w.on_jump("s4", 3)
	check(w.clear("s4") and not w.warning("s4"), "dead: cleared")
	w.on_jump("s5", 4)
	w.on_state("s5", {"hp": 10}, 5, "p1")
	check(not w.warning("s5"), "a full state without leapt (omitempty): not leapt")


func test_leapt_glow_pulses() -> void:
	var b := BossBody.new()
	b.setup("snowman", 60.0)
	b.leaper = true
	eq(b.leap_glow(), 0.0, "no glow before a leap")
	b.leap_warn = true
	var lo := 1.0
	var hi := 0.0
	for i in 60:
		b._process(BossBody.LEAP_PULSE_SEC / 60.0)
		lo = minf(lo, b.leap_glow())
		hi = maxf(hi, b.leap_glow())
	check(lo < 0.05 and hi > 0.95, "it pulses (%f..%f)" % [lo, hi])
	b.prime(0.3)
	eq(b.leap_glow(), 0.0, "blowing up: the prime's flash instead")
	b.vanish()
	eq(b.leap_glow(), 0.0, "gone")
	b.free()


# ── The leap ─────────────────────────────────────────────────────────────────

func test_jump_arc() -> void:
	var j := JumpModel.new(Vector2(400, 700), Vector2(1000, 600), 1.0, 120.0)
	eq(j.position_at(0.0), Vector2(400, 700), "starts at from")
	eq(j.position_at(JumpModel.CROUCH * 0.5), Vector2(400, 700), "crouching in place first")
	eq(j.position_at(1.0), Vector2(1000, 600), "lands on to")
	near(j.apex_y(), 480.0, 1e-4, "the apex 120 px above the higher end")
	var top := INF
	for i in 101:
		top = minf(top, j.position_at(i / 100.0).y)
	near(top, 480.0, 0.5, "the arc reaches the apex")
	var s0 := j.scale_at(JumpModel.CROUCH * 0.99)
	check(s0.x > 1.1 and s0.y < 0.9, "squashed in the crouch (%s)" % s0)
	var air := j.scale_at(JumpModel.CROUCH + 0.02)
	check(air.y > 1.1 and air.x < 1.0, "stretched at the take-off (%s)" % air)
	var apex_t := JumpModel.CROUCH + j.apex_share() * (1.0 - JumpModel.CROUCH)
	near(j.scale_at(apex_t).y, 1.0, 0.02, "round at the apex")
	check(JumpModel.land_scale(JumpModel.LAND_SEC * 0.5).y < 0.85, "the landing squash")
	eq(JumpModel.land_scale(JumpModel.LAND_SEC + 0.01), Vector2.ONE, "then upright")
	var e = JumpModel.from_event({"playerId": "s", "from": {"x": 1, "y": 2}, "to": {"x": 3, "y": 4}, "duration": 0.9, "height": 80})
	check(e != null and e.to == Vector2(3, 4) and e.height == 80.0 and e.duration == 0.9, "from a UnitJumped")
	check(JumpModel.from_event({"playerId": "s"}) == null, "without from / to: none")
	var steps := JumpModel.new(Vector2(0, 0), Vector2(300, 0), 0.5)
	for i in 40:
		steps.step(DT)
	check(steps.done() and steps.position_at(steps.t) == Vector2(300, 0), "step() lands")


func test_view_jump_and_leapt() -> void:
	BossFixture.take()
	var v := PlayerView.new()
	v.walk.terrain = _ground(1200, 900, 700)
	v.setup({"playerId": "minion_snowman_1", "teamId": 2, "role": "minion", "bossId": "ice_witch", "minionId": "snowman", "bodySize": 0.85,
		"hp": 900, "maxHp": 900, "position": {"x": 200, "y": 700}, "behavior": "leaper"}, false, 1)
	check(v.leaper and v.figure().leaper, "a leaper")
	v.jump(Vector2(200, 700), Vector2(800, 700), 1.0, 150.0)
	check(v.in_flight() and v.jumping(), "jumping (holds the events like a flight)")
	v._process(0.55)
	check(v.position.y < 600.0, "high in the air (%s)" % v.position)
	check(v.squash().y != 1.0, "squashed or stretched")
	check(v.ground_drop > 50.0, "its shadow on the ground below")
	v._process(0.46)
	check(not v.in_flight() and v.position == Vector2(800, 700), "landed on to")
	v._process(JumpModel.LAND_SEC * 0.5)
	check(v.squash().y < 1.0, "the landing squash (%s)" % v.squash())
	v._process(JumpModel.LAND_SEC)
	eq(v.squash(), Vector2.ONE, "upright again")
	v.set_leapt(true)
	check(v.leapt() and v.figure().leap_warn, "the warning glow on")
	v.set_leapt(false)
	check(not v.leapt(), "off")
	v.free()


# ── Shockwave, wide rain, storm, camera ──────────────────────────────────────

func _wave_events() -> Array:
	var out: Array = [{"t": 0.6, "type": "explode", "position": {"x": 1200, "y": 640}, "radius": 45, "crater": "bowl"}]
	for k in range(1, 9):
		out.append({"t": 0.6 + 0.08 * k, "type": "explode", "position": {"x": 1200 - 150 * k, "y": 760}, "radius": 18, "crater": "bowl"})
		out.append({"t": 0.6 + 0.08 * k, "type": "explode", "position": {"x": 1200 + 150 * k, "y": 760}, "radius": 18, "crater": "bowl"})
	out.append({"t": 0.9, "type": "damage", "playerId": "p1", "amount": 300, "hp": 1200, "cause": "explosion"})
	return out


func test_shockwave_detect() -> void:
	var events := _wave_events()
	var w := Shockwave.detect(events, true)
	eq(w["origin"], Vector2(1200, 640), "the slam at the boss")
	eq([w["left"].size(), w["right"].size()], [8, 8], "eight steps each way")
	eq(w["left"][0][0], Vector2(1050, 760), "the left side ordered outward")
	eq(w["right"][7][0], Vector2(2400, 760), "the right one reaches the edge")
	eq(Shockwave.reach(w), [0.0, 2400.0], "edge to edge")
	check(events[1].get(Shockwave.STEP_KEY, false) and not events[0].get(Shockwave.STEP_KEY, false), "the steps tagged, not the slam")
	eq(Shockwave.front(w, "right", 0.5), Vector2(1200, 640), "at the slam before it")
	eq(Shockwave.front(w, "right", 0.68), Vector2(1350, 760), "at a step when its explode comes")
	var mid := Shockwave.front(w, "left", 0.72)
	near(mid.x, 975.0, 0.01, "between the steps")
	near(Shockwave.end_time(w, "left"), 1.24, 1e-6, "the left edge at its last step")
	var shells: Array = [{"t": 0.9, "type": "explode", "position": {"x": 500, "y": 700}, "radius": 30, "projectileId": "p1"},
		{"t": 1.0, "type": "explode", "position": {"x": 900, "y": 700}, "radius": 30, "projectileId": "p2"}]
	eq(Shockwave.detect(shells), {}, "a rain's impacts are no wave")
	eq(Shockwave.detect([events[0]]), {}, "a lone slam is no wave")
	var back := _wave_events()
	back[1]["t"] = 0.1 # a step before the slam
	eq(Shockwave.detect(back), {}, "a step going back in time: no wave")


func test_wide_rain_and_storm() -> void:
	check(BossRain.is_wide([{"type": "rain", "position": {"x": 1200, "y": 560}, "radius": 1200, "count": 40}], 2400.0), "half the map wide")
	check(not BossRain.is_wide([{"type": "rain", "position": {"x": 1200, "y": 560}, "radius": 160, "count": 8}], 2400.0), "a target's spread")
	check(not BossRain.is_wide([], 2400.0), "no rain")
	var s := StormOverlay.new(StormOverlay.SNOW)
	eq(s.flake_count(), StormOverlay.SNOW_FLAKES, "a snowstorm's flakes")
	eq(s.strength(), 0.0, "fades in")
	s._process(StormOverlay.FADE_IN)
	near(s.strength(), 1.0, 1e-4, "full")
	s.release()
	s._process(StormOverlay.FADE_OUT * 0.5)
	check(s.strength() > 0.3 and s.strength() < 0.7, "fading out")
	s.free()
	eq(StormOverlay.new(StormOverlay.EMBER).flake_count(), StormOverlay.EMBER_FLAKES, "embers")


func test_wide_rain_view() -> void:
	BossFixture.take()
	var layer := Node2D.new()
	var screen := CanvasLayer.new()
	var events: Array = [{"t": 0.6, "type": "rain", "position": {"x": 1200, "y": 560}, "radius": 1200, "count": 3}]
	var projectiles: Array = []
	for i in 3:
		var x := 300.0 + 800.0 * i
		projectiles.append({"projectileId": "r%d" % i, "kind": "missile", "path": [
			{"time": 0.6 + 0.08 * i, "position": {"x": x, "y": -100.0}, "velocity": {"x": 0.0, "y": 900.0}},
			{"time": 1.4 + 0.08 * i, "position": {"x": x, "y": 700.0}, "velocity": {"x": 0.0, "y": 1100.0}}]})
		events.append({"t": 1.4 + 0.08 * i, "type": "explode", "position": {"x": x, "y": 700}, "radius": 30, "projectileId": "r%d" % i})
	var tl := ShotTimeline.new({"shooterId": "boss_ice_witch", "actionMode": "skill", "skillId": "blizzard", "duration": 2.0,
		"projectiles": projectiles, "events": events})
	var mask := _ground(2400, 1120, 700)
	var v = BossRain.new()
	v.begin({"layer": layer, "timeline": tl, "style": {}, "views": {}, "players": {"boss_ice_witch": {"role": "boss", "bossId": "ice_witch"}},
		"shooter": "boss_ice_witch", "terrain": mask, "screen": screen, "wind": -1})
	check(v.wide() and v.frames_map(), "a map-wide rain frames the map")
	v.on_event(events[0])
	check(v.storm() != null and v.storm().kind == StormOverlay.SNOW, "the witch's snowstorm over the screen")
	v.process(0.7)
	v.end()
	check(v.storm().is_released(), "it fades once the rain is over")
	layer.free()
	screen.free()


func test_camera_frames_the_map() -> void:
	var cam := CameraModel.new()
	cam.setup(MAP, Vector2(1600, 900))
	cam.snap(Vector2(400, 600))
	cam.frame_map()
	check(cam.framed() and cam.zooming(), "zooming out")
	for i in 60:
		cam.step(DT)
	near(cam.zoom, cam.min_zoom(), 1e-4, "the whole map fits")
	check(cam.view_rect().grow(1.0).encloses(Rect2(Vector2.ZERO, MAP)), "all of it in view: %s" % cam.view_rect())
	cam.unframe()
	for i in 60:
		cam.step(DT)
	near(cam.zoom, 1.0, 1e-4, "back to the zoom before")
	check(not cam.framed(), "done")
	cam.frame_map()
	cam.zoom_at(0.9, cam.view_size / 2.0)
	check(not cam.framed() and not cam.zooming(), "a manual zoom ends it")
	cam.unframe()
	near(cam.zoom, 0.9, 1e-4, "and stays")


# ── match_screen: summon + attack, UnitJumped, leapt through turns ───────────

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


func _p(id: String, team: int, x: float, extra: Dictionary = {}) -> Dictionary:
	var p := {"playerId": id, "displayName": id, "teamId": team, "characterId": "rookie", "hp": 1000, "maxHp": 1000,
		"isAlive": true, "position": {"x": x, "y": 700.0}, "skillEnergy": 0, "items": [], "statusEffects": [], "moveEnergy": 100,
		"maxMoveEnergy": 100}
	p.merge(extra, true)
	return p


func _screen() -> Node2D:
	BossFixture.take()
	var m: Node2D = MatchScreen.new()
	m._me = "me"
	m._current = "boss_ice_witch"
	m._turn_index = 5
	m._players = {"me": _p("me", 1, 300.0), "p2": _p("p2", 1, 900.0),
		"boss_ice_witch": _p("boss_ice_witch", 2, 1200.0, {"role": "boss", "bossId": "ice_witch", "bodySize": 2.8, "hp": 30000,
			"maxHp": 30000, "flying": true, "characterId": ""}),
		"minion_snowman_1": _p("minion_snowman_1", 2, 1500.0, {"role": "minion", "bossId": "ice_witch", "minionId": "snowman",
			"bodySize": 0.85, "behavior": "leaper", "characterId": ""})}
	m._boss.load_snapshot({"boss": {"bossId": "ice_witch", "playerId": "boss_ice_witch", "round": 3, "turnLimit": 30}, "players": m._players})
	m._mask = _ground(2400, 1120, 700)
	m._terrain_view = TerrainView.new()
	m._players_layer = Node2D.new()
	m._fx_layer = Node2D.new()
	m._screen_fx = CanvasLayer.new()
	m._sky = SkyView.new()
	m._lava_view = preload("res://match/boss/lava_view.gd").new()
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
	return m


func _free(m: Node2D) -> void:
	m._shot_player.stop()
	for n in [m._hud, m._aim, m._shot_player, m._players_layer, m._fx_layer, m._sky, m._terrain_view, m._screen_fx, m._lava_view]:
		n.free()
	m.free()


func _run(m: Node2D, sec: float) -> void:
	var t := 0.0
	while t < sec - 1e-9:
		m._shot_player._process(DT)
		for v in m._views.values():
			v._process(DT)
		m._process(DT)
		t += DT


func test_free_summon_then_attack() -> void:
	var m := _screen()
	var summon := {"shooterId": "boss_ice_witch", "actionMode": "summon", "projectiles": [], "duration": 1.0,
		"events": [{"t": 0.6, "type": "summon", "playerId": "minion_snowman_2", "minionId": "snowman", "position": {"x": 1700, "y": 700},
			"hp": 900, "maxHp": 900, "displayName": "Người tuyết", "teamId": 2, "bodySize": 0.85, "flying": false, "behavior": "leaper",
			"movement": "none"}]}
	m._on_event("ShotResolved", summon)
	check(not m._turn_resolved, "the summon leaves the boss's turn open")
	eq(m._hud.boss_hud()._skill_label.text, "Gọi người tuyết", "the summon's name (063: summon.name) under the boss bar")
	m._on_event("ActionSelected", {"playerId": "boss_ice_witch", "actionMode": "skill", "skillId": "ice_spikes"})
	eq(m._deferred.size(), 1, "the attack waits for the summon's replay")
	_run(m, 1.1)
	check(m._players.has("minion_snowman_2"), "the snowman is there")
	eq(m._deferred.size(), 0, "then it plays")
	eq(m._hud.boss_hud()._skill_label.text, str(GameData.boss_skill("ice_witch", "ice_spikes")["name"]), "the attack's skill name")
	m._on_event("ShotResolved", {"shooterId": "boss_ice_witch", "actionMode": "skill", "skillId": "ice_spikes", "projectiles": [],
		"duration": 0.5, "events": []})
	check(m._turn_resolved, "the attack resolves the turn")
	_free(m)


func test_frozen_boss_summons_only() -> void:
	var m := _screen()
	m._on_event("ActionSelected", {"playerId": "boss_ice_witch", "actionMode": "summon"})
	eq(m._hud.boss_hud()._skill_label.text, "Gọi người tuyết", "an ActionSelected summon names it too")
	m._on_event("ShotResolved", {"shooterId": "boss_ice_witch", "actionMode": "summon", "projectiles": [], "duration": 0.4, "events": []})
	_run(m, 0.5)
	m._on_event("TurnStarted", {"currentPlayerId": "me", "turnIndex": 6, "moveEnergy": 100})
	eq(m._current, "me", "no attack: the next turn")
	_free(m)


func test_unit_jumped_and_leapt_through_turns() -> void:
	var m := _screen()
	GameData.boss_minion("ice_witch", "snowman")["leapDetonateNextTurn"] = true # a leaper that blows up (the snowman before 063)
	m._apply("TurnStarted", {"currentPlayerId": "minion_snowman_1", "turnIndex": 6, "moveEnergy": 0})
	m._on_event("UnitJumped", {"playerId": "minion_snowman_1", "from": {"x": 1500, "y": 700}, "to": {"x": 950, "y": 700}, "duration": 0.9,
		"height": 160})
	var view = m._views["minion_snowman_1"]
	check(view.jumping() and m._flight_hold, "the leap is drawn, what follows waits")
	eq(m._players["minion_snowman_1"]["position"], {"x": 950.0, "y": 700.0}, "the server's position is to")
	check(m._players["minion_snowman_1"]["leapt"] and view.leapt(), "leapt: the warning glow")
	m._on_event("TurnStarted", {"currentPlayerId": "me", "turnIndex": 7, "moveEnergy": 100})
	eq(m._deferred.size(), 1, "my turn waits for the landing")
	_run(m, 1.0)
	eq(m._current, "me", "landed: my turn")
	check(view.leapt(), "its leap turn ended: still warning")
	m._apply("TurnStarted", {"currentPlayerId": "minion_snowman_1", "turnIndex": 8, "moveEnergy": 0})
	check(view.leapt(), "my turn ended: still warning")
	m._apply("TurnStarted", {"currentPlayerId": "p2", "turnIndex": 9, "moveEnergy": 100})
	check(not view.leapt() and not m._players["minion_snowman_1"]["leapt"], "its next turn ended without a leap (I moved away): off")
	m._on_event("UnitJumped", {"playerId": "minion_snowman_1", "from": {"x": 950, "y": 700}, "to": {"x": 880, "y": 700}, "duration": 0.5})
	_run(m, 0.6)
	check(view.leapt(), "leapt again")
	m._apply("ShotResolved", {"shooterId": "minion_snowman_1", "actionMode": "self_destruct", "projectiles": [], "duration": 1.0,
		"events": [{"t": 0.3, "type": "explode", "playerId": "minion_snowman_1", "position": {"x": 880, "y": 700}, "radius": 24,
			"crater": "bowl", "blastRadius": 140},
			{"t": 0.3, "type": "damage", "playerId": "p2", "amount": 450, "hp": 550, "cause": "self_destruct"},
			{"t": 0.3, "type": "die", "playerId": "minion_snowman_1", "cause": "self_destruct"}]})
	check(view.figure().priming(), "it swells before it blows up")
	_run(m, 0.5)
	check(view.vanished() and not view.leapt() and not m.leap_state().warning("minion_snowman_1"), "blown up as a minion: the warning gone")
	_free(m)


func test_snapshot_leapt() -> void:
	var m := _screen()
	var snap := {"currentPlayerId": "me", "turnIndex": 12, "players": m._players.duplicate(true),
		"boss": {"bossId": "ice_witch", "playerId": "boss_ice_witch", "round": 4, "turnLimit": 30}}
	snap["players"]["minion_snowman_1"]["leapt"] = true
	m._load_snapshot(snap, true)
	check(m._views["minion_snowman_1"].leapt(), "MatchStateSync's leapt: the glow")
	_free(m)


func test_shockwave_in_the_match() -> void:
	var m := _screen()
	m._players["boss_ice_witch"]["position"] = {"x": 1200.0, "y": 640.0}
	m._on_event("ShotResolved", {"shooterId": "boss_ice_witch", "actionMode": "skill", "skillId": "claw_slam", "projectiles": [],
		"duration": 1.6, "events": _wave_events()})
	check(m._wave_fx != null, "the ripple is drawn")
	check(m._cam.framed(), "the map framed for it")
	_run(m, 1.7)
	check(not m._cam.framed(), "back after the replay")
	_free(m)


# ── The bosses' and minions' own projectiles ─────────────────────────────────

const UnitShell := preload("res://match/views/unit_shell.gd")
const UnitImpact := preload("res://match/views/unit_impact.gd")
const ProjectileView := preload("res://match/views/projectile_view.gd")


func test_unit_shell_kinds() -> void:
	for k in ["steel_shell", "magma_bomb", "ice_shard", "ice_spike", "drone_bolt", "crab_spit", "snowball"]:
		check(UnitShell.is_kind(k), "%s has its own look" % k)
	check(not UnitShell.is_kind("missile") and not UnitShell.is_kind(""), "a missile / a normal shell: the gun's look")
	var spike := UnitShell.new("ice_spike")
	spike.set_tangent(Vector2(3, 4))
	near(spike.draw_angle(), Vector2(3, 4).angle(), 1e-6, "an icicle points exactly along the path's tangent")
	spike._process(0.016)
	near(spike.draw_angle(), Vector2(3, 4).angle(), 1e-6, "no wobble from frame to frame")
	spike.set_tangent(Vector2(-1, 0))
	near(absf(spike.draw_angle()), PI, 1e-6, "turned at once with the path")
	var shard := UnitShell.new("ice_shard")
	var a0: float = shard.draw_angle()
	shard._process(0.1)
	check(absf(shard.draw_angle() - a0) > 0.5, "a shard tumbles")
	check(not shard.pointed() and spike.pointed(), "only the pointed kinds follow the tangent")
	spike.free()
	shard.free()


func test_unit_shell_sizes() -> void:
	var player := UnitShell.player_shell_px()
	check(player > 12.0 and player < 40.0, "a player shell is %f px" % player)
	for k in ["drone_bolt", "crab_spit", "snowball"]:
		var v := UnitShell.new(k)
		v._ready()
		near(v.drawn_px(), player, 0.01, "a minion's %s is a player shell's size" % k)
		v.free()
	for k in ["steel_shell", "magma_bomb", "ice_shard", "ice_spike"]:
		var v := UnitShell.new(k)
		v._ready()
		near(v.drawn_px(), player * UnitShell.BOSS_SIZE, 0.01, "a boss's %s is %.1f × it" % [k, UnitShell.BOSS_SIZE])
		v.free()


func test_shot_player_uses_the_unit_kinds() -> void:
	var layer := Node2D.new()
	var sp := ShotPlayer.new()
	sp.layer = layer
	var path := [{"time": 0.0, "position": {"x": 0.0, "y": 0.0}, "velocity": {"x": 100.0, "y": 0.0}},
		{"time": 1.0, "position": {"x": 100.0, "y": 0.0}, "velocity": {"x": 100.0, "y": 0.0}}]
	var tl := ShotTimeline.new({"shooterId": "boss", "actionMode": "skill", "duration": 1.0, "events": [],
		"projectiles": [{"projectileId": "a", "kind": "magma_bomb", "path": path}, {"projectileId": "b", "kind": "future_kind", "path": path},
			{"projectileId": "c", "path": path}]})
	sp.play(tl)
	var views := layer.get_children()
	check(views[0] is UnitShell and views[0].kind == "magma_bomb", "a magma bomb is drawn as one")
	check(views[1] is ProjectileView and views[2] is ProjectileView, "an unknown kind and a normal shell: the gun's shell")
	eq([tl.kind_of("a"), tl.kind_of("c"), tl.kind_of("zz")], ["magma_bomb", "", ""], "kind_of() by projectileId")
	sp.stop()
	sp.free()
	layer.free()


func test_unit_impact_frees_itself() -> void:
	var hit := UnitImpact.new("snowball", 50.0)
	eq(hit.radius, 50.0, "as wide as the blast")
	hit._process(UnitImpact.LIFE * 0.5)
	check(not hit.is_queued_for_deletion(), "still bursting")
	hit._process(UnitImpact.LIFE)
	check(hit.is_queued_for_deletion(), "then gone")
	hit.free()


func test_witch_casts_her_shards() -> void:
	var b := BossBody.new()
	b.setup("ice_witch", 160.0)
	eq(int(b.shards()["n"]), BossBody.SHARDS, "three shards orbit her")
	b.cast_shards(0.6)
	b._process(0.45)
	check(b.casting_shards() and int(b.shards()["n"]) > BossBody.SHARDS, "they multiply as she casts (%d)" % int(b.shards()["n"]))
	var p0: float = b.shards()["phase"]
	b._process(0.1)
	check(float(b.shards()["phase"]) - p0 > BossBody.SHARD_SPIN * 0.1 * 3.0, "and spin up")
	b._process(0.1)
	check(not b.casting_shards() and float(b.shards()["size"]) < 0.2, "off they fly: gone")
	b._process(BossBody.SHARD_REGROW + 0.1)
	b.cast_shards(0.6, 1.0) # 40 shards leaving 0.08 s apart over a second
	b._process(0.7)
	check(b.casting_shards() and int(b.shards()["n"]) == BossBody.SHARDS_CAST, "whirling while they leave one after another")
	b._process(1.0)
	check(not b.casting_shards() and float(b.shards()["size"]) < 0.2, "the last one gone")
	b._process(BossBody.SHARD_REGROW * 0.5)
	near(float(b.shards()["size"]), 0.5, 0.12, "regrowing")
	b._process(BossBody.SHARD_REGROW)
	eq(float(b.shards()["size"]), 1.0, "back after about a second")
	b.free()
