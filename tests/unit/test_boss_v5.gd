extends "res://tests/test_case.gd"
## Boss v5 / items and status (server feat/visual-ui-boss-skills, migration 063): the lost turn's
## countdown (TurnStarted skipAfter: SkipCountdown, the ring over the unit and on my HUD, no text),
## the blind white-out (BlindOverlay.wanted(), the blindfold on the unit), the new ShotResolved
## events replayed on the timeline's clock (PathMotion; move + pincer, airburst, global, roll,
## pull: the fixture tests/fixtures/boss_v5_shots.json recorded from the server), the new skill
## views, the snowman's single leap, the freeze bomb factor and the boss result's gift box.

const BossFixture := preload("res://tests/boss_fixture.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const SkipCountdown := preload("res://match/skip_countdown.gd")
const CountdownRing := preload("res://match/views/countdown_ring.gd")
const BlindOverlay := preload("res://match/views/blind_overlay.gd")
const PathMotion := preload("res://match/shot/path_motion.gd")
const BossMoves := preload("res://match/boss/boss_moves.gd")
const AirburstFx := preload("res://match/boss/airburst_fx.gd")
const PincerFx := preload("res://match/boss/pincer_fx.gd")
const GroundCrackFx := preload("res://match/boss/ground_crack_fx.gd")
const RollingBoulderView := preload("res://match/boss/rolling_boulder_view.gd")
const RootDragFx := preload("res://match/boss/root_drag_fx.gd")
const OrbView := preload("res://match/boss/orb_view.gd")
const UnitImpact := preload("res://match/views/unit_impact.gd")
const StatusLook := preload("res://match/views/status_look.gd")
const Skills := preload("res://match/skills.gd")
const BossAirburst := preload("res://match/views/skills/boss_airburst.gd")
const BossGlobal := preload("res://match/views/skills/boss_global.gd")
const BossRoll := preload("res://match/views/skills/boss_roll.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const SkyView := preload("res://match/views/sky_view.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const Hud := preload("res://match/hud.gd")
const MatchScreen := preload("res://match/match_screen.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const TerrainView := preload("res://match/terrain/terrain_view.gd")
const BossResultModel := preload("res://match/boss/boss_result_model.gd")
const BossResultScreen := preload("res://match/boss/boss_result_screen.gd")
const FIXTURE := "res://tests/fixtures/boss_v5_shots.json"
const DT := 1.0 / 60.0


static func _fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


static func _event(shot: Dictionary, type: String) -> Dictionary:
	for e in shot["events"]:
		if str(e.get("type", "")) == type:
			return e
	return {}


static func _events(shot: Dictionary, type: String) -> Array:
	return shot["events"].filter(func(e): return str(e.get("type", "")) == type)


# ── Game data ────────────────────────────────────────────────────────────────

func test_game_data_063() -> void:
	near(GameData.freeze_bomb_damage_factor(), 0.5, 1e-9, "itemRules.freezeBombDamageFactor")
	GameData.data["itemRules"].erase("freezeBombDamageFactor")
	near(GameData.freeze_bomb_damage_factor(), 1.0, 1e-9, "an older server: full damage")
	eq([GameData.status_name("blind"), GameData.status_bad("blind"), GameData.status_blocks_move("blind")], ["Mù", true, false], "status blind")
	near(GameData.skip_turn_delay_sec(), 5.0, 1e-9, "timings.skipTurnDelaySec")
	BossFixture.take()
	for b in GameData.bosses():
		eq(int(b["turnLimit"]), 20, "%s: 20 turns" % b["bossId"])
		eq(b["summon"]["rounds"], [0.0, 10.0, 15.0], "%s: waves at rounds 0, 10, 15" % b["bossId"])
	eq(GameData.boss_skill("steel_robot", "blind_bomb")["kind"], "airburst", "Bom mù")
	eq([GameData.boss_skill("lava_crab", "pincer")["moveRange"], GameData.boss_skill("lava_crab", "pincer")["reach"]], [600.0, 60.0], "Kẹp càng")
	check(not GameData.minion_leap_detonates("ice_witch", "snowman"), "the snowman leaps once and does not blow up")
	check(GameData.minion_leap_detonates("ice_witch", "nobody"), "unknown: the old behaviour")


func test_skill_views_by_kind() -> void:
	BossFixture.take()
	check(Skills.view_for_skill("blind_bomb") is BossAirburst, "airburst")
	check(Skills.view_for_skill("blizzard") is BossGlobal and Skills.view_for_skill("earthquake") is BossGlobal
		and Skills.view_for_skill("poison_thorns") is BossGlobal, "global")
	check(Skills.view_for_skill("rolling_boulder") is BossRoll, "roll")
	var g = Skills.view_for_skill("earthquake")
	check(g.frames_map() and not g.tracks_shells(), "a global frames the whole map")
	var shot: Dictionary = _fixture()["blind_bomb"]["shot"]
	var plain := Node2D.new()
	var orb: Node2D = Skills.view_for_skill("blind_bomb").projectile_view(0, shot["projectiles"][0], plain)
	check(orb is OrbView, "the orb flies as the energy orb")
	orb.free()
	var roll: Dictionary = _fixture()["rolling_boulder"]["shot"]
	var boulder: Node2D = Skills.view_for_skill("rolling_boulder").projectile_view(0, roll["projectiles"][0], plain)
	check(boulder is RollingBoulderView, "the throw is the boulder")
	near(boulder.radius, float(_event(roll, "roll")["radius"]), 1e-6, "as big as it rolls")
	boulder.free()
	plain.free()


# ── Lost turn countdown ──────────────────────────────────────────────────────

func test_countdown_model() -> void:
	var ts: Dictionary = _fixture()["frozen_turn"]["turnStarted"]
	eq([ts["skipped"], ts["skipAfter"]], ["freeze", 5.0], "the server's frozen TurnStarted")
	var c := SkipCountdown.new()
	check(c.start(ts, "freeze"), "starts")
	eq([c.effect, c.player_id, c.number()], ["freeze", "boss_steel_robot", 5], "5 first")
	near(c.fraction(), 1.0, 1e-6, "the ring full")
	var seen: Array = []
	for i in 600:
		if c.active() and (seen.is_empty() or seen[-1] != c.number()):
			seen.append(c.number())
		c.step(0.01)
	eq(seen, [5, 4, 3, 2, 1], "5…1")
	check(not c.active() and c.number() == 0, "over after skipAfter")
	check(c.start(ts, "freeze", 2.5), "held back 2.5 s by a replay")
	eq(c.number(), 3, "counts from its arrival")
	near(c.fraction(), 0.5, 1e-6, "half the ring")
	check(not c.start(ts, "freeze", 6.0), "arrived after it ended: nothing")
	var old := ts.duplicate()
	old.erase("skipAfter")
	check(not c.start(old, "freeze") and not c.active(), "an older server (no skipAfter): no countdown")
	check(not c.start(ts, ""), "not skipped: none")


func test_countdown_ring_draws_the_number() -> void:
	var r := CountdownRing.new()
	r.show_time("stun", 3, 0.6)
	eq([r.visible, r.number, r.effect], [true, 3, "stun"], "shown")
	check(CountdownRing.color_of("freeze") != CountdownRing.color_of("stun"), "the effect's colour")
	r.show_time("stun", 0, 0.0)
	check(not r.visible, "0 hides it")
	r.free()


## The whole HUD and the unit carry no "mất lượt" text; the ring counts over the frozen unit (the
## boss) and, for my own lost turn, dead centre on the HUD.
func test_screen_countdown() -> void:
	var m := _screen("steel_robot", "blind_bomb")
	var bid := "boss_steel_robot"
	m._players[bid]["statusEffects"] = [{"effectId": "freeze", "durationTurn": 1}]
	var ts: Dictionary = _fixture()["frozen_turn"]["turnStarted"].duplicate(true)
	ts["turnIndex"] = 9
	m._on_event("TurnStarted", ts)
	var st: Dictionary = m.countdown_state()
	eq([st["active"], st["effect"], st["player"], st["number"], st["unit_ring"]], [true, "freeze", bid, 5, true], "the ring over the boss")
	eq(m._hud.countdown()["visible"], false, "not my turn: nothing on my HUD")
	check(not _texts(m._hud).any(func(t): return "mất lượt" in t), "no lost-turn text")
	for i in 130:
		m._process(DT)
	eq(m.countdown_state()["number"], 3, "about 2 s later: 3")
	# my own frozen turn
	m._players["me"]["statusEffects"] = [{"effectId": "stun", "durationTurn": 1}]
	m._on_event("TurnStarted", {"turnIndex": 10, "currentPlayerId": "me", "moveEnergy": 0, "maxMoveEnergy": 100,
		"wind": {"direction": 1, "power": 1.0}, "skipped": "stun", "skipAfter": 5})
	var hc: Dictionary = m._hud.countdown()
	eq([hc["visible"], hc["effect"], hc["number"]], [true, "stun", 5], "my lost turn: the ring dead centre on the HUD")
	check(m.countdown_state()["unit_ring"], "and over me")
	check(not m._can_act(), "no actions")
	# the next turn: gone
	m._on_event("TurnStarted", {"turnIndex": 11, "currentPlayerId": "p1", "moveEnergy": 100, "wind": {"direction": 1, "power": 1.0}})
	eq([m.countdown_state()["active"], m.countdown_state()["unit_ring"], m._hud.countdown()["visible"]], [false, false, false], "a normal turn: no countdown")
	_free(m)


func test_summon_named_by_the_kit() -> void:
	var m := _screen("rock_giant", "earthquake")
	eq(m._summon_name(), "Dựng trụ đá", "summon.name")
	GameData.boss("rock_giant")["summon"].erase("name")
	eq(m._summon_name(), "Triệu hồi", "an older server: the generic word")
	_free(m)


func test_countdown_centred_on_hud() -> void:
	var h: Control = Hud.new()
	h._ready()
	var holder: Control = h.find_child("SkipCountdown", true, false)
	check(holder != null, "the holder")
	eq([holder.anchor_left, holder.anchor_right], [0.5, 0.5], "horizontally dead centre")
	near(holder.anchor_top, Hud.COUNTDOWN_Y, 1e-5, "under the turn banner")
	near(holder.anchor_bottom, Hud.COUNTDOWN_Y, 1e-5, "a point anchor")
	h.free()


# ── Blind ────────────────────────────────────────────────────────────────────

func test_blind_overlay_state() -> void:
	var blind := [{"effectId": "blind", "durationTurn": 1}]
	check(BlindOverlay.wanted(true, blind, false), "my turn, blinded, aiming: white-out")
	check(not BlindOverlay.wanted(false, blind, false), "another's turn: none")
	check(not BlindOverlay.wanted(true, blind, true), "my shot answered: it lifts for the replay")
	check(not BlindOverlay.wanted(true, [{"effectId": "blind", "durationTurn": 0}], false), "expired")
	check(not BlindOverlay.wanted(true, [], false), "not blind")
	var o := BlindOverlay.new()
	o.set_on(true)
	o.step(BlindOverlay.FADE_IN / 2.0)
	check(o.visible and o.shown > 0.4 and o.shown < 0.6, "fading in")
	o.step(1.0)
	near(o.shown, 1.0, 1e-6, "full")
	check(BlindOverlay.CENTRE_ALPHA > 0.85 and BlindOverlay.EDGE_ALPHA < BlindOverlay.CENTRE_ALPHA, "strong, a little thinner at the edges")
	check(o.mouse_filter == Control.MOUSE_FILTER_IGNORE, "taps go through")
	o.set_on(false)
	o.step(1.0)
	check(not o.visible, "gone")
	o.free()
	eq(StatusLook.looks_of(blind).keys(), ["blind"], "teammates see the blindfold on the unit")


## The robot's blind bomb on me: my next turn is whited out until my shot is answered.
func test_screen_blind() -> void:
	var m := _screen("steel_robot", "blind_bomb")
	var shot: Dictionary = _fixture()["blind_bomb"]["shot"].duplicate(true)
	for e in shot["events"]:
		if e.get("playerId") == "p0":
			e["playerId"] = "me"
	m._on_event("ShotResolved", shot)
	_run(m, float(shot["duration"]) + 0.2)
	check(not m._shot_player.is_playing(), "replayed")
	check(m._players["me"]["statusEffects"].any(func(e): return e["effectId"] == "blind"), "blind on me")
	check(m._views["me"].status_looks().has("blind"), "the blindfold on my unit")
	check(_fx(m, AirburstFx).size() == 1, "the burst drawn")
	m._process(DT)
	check(not m.blind_overlay().is_on(), "not my turn yet: no white-out")
	m._on_event("TurnStarted", {"turnIndex": 6, "currentPlayerId": "me", "moveEnergy": 100, "maxMoveEnergy": 100,
		"wind": {"direction": 1, "power": 1.0}})
	m._process(DT)
	check(m.blind_overlay().is_on(), "my turn: white-out")
	check(m._can_act(), "I still play (purely visual)")
	m._turn_resolved = true
	m._process(DT)
	check(not m.blind_overlay().is_on(), "my shot answered: lifted")
	_free(m)


# ── Paths on the timeline's clock ────────────────────────────────────────────

func test_path_motion_timing() -> void:
	var mv: Dictionary = _event(_fixture()["pincer"]["shot"], "move")
	var m := PathMotion.new(mv)
	near(m.start, float(mv["t"]), 1e-9, "starts at the event's t")
	near(m.end_time(), float(mv["t"]) + float(mv["duration"]), 1e-9, "ends duration later")
	eq(m.position_at(0.0), Vector2(mv["from"]["x"], mv["from"]["y"]), "at from before")
	eq(m.position_at(99.0), Vector2(mv["to"]["x"], mv["to"]["y"]), "at to after")
	var last := INF
	for i in 21:
		var x := m.position_at(m.start + m.duration * i / 20.0).x
		check(x <= last + 1e-6, "the crab walks one way (left)")
		last = x
	near(m.distance_at(m.start + m.duration / 2.0), m.length() / 2.0, 1e-3, "constant speed along the path")
	eq(PathMotion.new({"t": 1.0, "duration": 1.0, "from": {"x": 0, "y": 0}, "to": {"x": 100, "y": 0}}).position_at(1.5),
		Vector2(50, 0), "no path: from → to")


## The boulder reaches each member at its damage event's t (server: roll.t + distance / speed).
func test_roll_damage_on_the_path_clock() -> void:
	var fx: Dictionary = _fixture()["rolling_boulder"]
	var roll: Dictionary = _event(fx["shot"], "roll")
	var m := PathMotion.new(roll)
	near(m.start, float(fx["shot"]["projectiles"][0]["path"][-1]["time"]), 1e-6, "the roll starts where the throw lands")
	for d in _events(fx["shot"], "damage"):
		var x := float(fx["players"][d["playerId"]]["position"]["x"])
		near(m.time_at_x(x), float(d["t"]), 0.05, "%s crushed when the boulder gets there" % d["playerId"])


func test_boss_moves_drive_nodes() -> void:
	var mv: Dictionary = _event(_fixture()["pincer"]["shot"], "move")
	var moves := BossMoves.new()
	var n := Node2D.new()
	var motion = moves.add(n, mv)
	eq(n.position, motion.points[0], "on the path's start")
	moves.sync(motion.start + motion.duration / 2.0)
	eq(n.position, motion.position_at(motion.start + motion.duration / 2.0), "midway")
	moves.finish()
	eq([n.position, moves.count()], [motion.points[-1], 0], "finish: on the end")
	var b := RollingBoulderView.new(60.0)
	var roll: Dictionary = _event(_fixture()["rolling_boulder"]["shot"], "roll")
	var rm = moves.add(b, roll)
	moves.sync(rm.end_time())
	near(absf(b.spin()), rm.length() / 60.0, 1e-3, "it turns by the distance over its radius")
	check(b.spin() < 0.0, "rolling left: anticlockwise")
	n.free()
	b.free()


# ── Replays through match_screen ─────────────────────────────────────────────

func test_screen_pincer() -> void:
	var m := _screen("lava_crab", "pincer")
	var shot: Dictionary = _fixture()["pincer"]["shot"]
	var mv := _event(shot, "move")
	var crab: Node2D = m._views["boss_lava_crab"]
	m._on_event("ShotResolved", shot)
	_run(m, float(mv["t"]) + float(mv["duration"]) * 0.5)
	var motion := PathMotion.new(mv)
	check(crab.position.distance_to(motion.position_at(m._shot_player.time())) < 1.0, "the crab walks the path on the replay's clock")
	eq(m._players["boss_lava_crab"]["position"], {"x": float(mv["to"]["x"]), "y": float(mv["to"]["y"])}, "its state is the outcome")
	eq(_fx(m, PincerFx).size(), 0, "no grab yet")
	_run(m, float(mv["duration"]) * 0.5 + 0.05)
	eq(_fx(m, PincerFx).size(), 1, "the claw snaps at the pincer event")
	check(crab.position.distance_to(motion.points[-1]) < 1.0, "the crab beside its target")
	_run(m, 1.0)
	check(not m._shot_player.is_playing() and m.boss_moves().count() == 0, "done")
	eq(crab.position, motion.points[-1], "stays at to")
	_free(m)


func test_screen_root_drag() -> void:
	var m := _screen("tree_spirit", "root_drag")
	var shot: Dictionary = _fixture()["root_drag"]["shot"]
	var pull := _event(shot, "pull")
	var who: Node2D = m._views[pull["playerId"]]
	m._on_event("ShotResolved", shot)
	_run(m, float(pull["t"]) + 0.05)
	eq(_children_of(m.mark_view(), RootDragFx).size(), 1, "the roots drag")
	_run(m, float(pull["duration"]) * 0.5)
	check(who.position.distance_to(PathMotion.new(pull).position_at(m._shot_player.time())) < 1.0, "pulled along the path")
	_run(m, float(shot["duration"]))
	eq(who.position, PathMotion.new(pull).points[-1], "left where the server put it")
	eq(m._players[pull["playerId"]]["position"], {"x": float(pull["to"]["x"]), "y": float(pull["to"]["y"])}, "its state")
	_free(m)


func test_screen_earthquake_and_blizzard() -> void:
	var m := _screen("rock_giant", "earthquake")
	var shot: Dictionary = _fixture()["earthquake"]["shot"]
	m._on_event("ShotResolved", shot)
	_run(m, 0.65)
	check(m._quake_until > m._clock, "the camera shakes for the quake")
	_run(m, 0.4)
	eq(_children_of(m.mark_view(), GroundCrackFx).size(), _events(shot, "damage").size(), "the ground splits under every member hit")
	_run(m, 2.0)
	check(m._quake_until < 0.0, "over with the replay")
	_free(m)
	var w := _screen("ice_witch", "blizzard")
	var bz: Dictionary = _fixture()["blizzard"]["shot"]
	w._on_event("ShotResolved", bz)
	_run(w, 0.7)
	check(w._skill_view is BossGlobal and w._skill_view.storm() != null, "the snowstorm over the screen")
	_run(w, float(bz["duration"]))
	eq(_fx(w, UnitImpact).size(), bz["projectiles"].size(), "a shard bursts on every member")
	_free(w)


func test_screen_roll() -> void:
	var m := _screen("rock_giant", "rolling_boulder")
	var shot: Dictionary = _fixture()["rolling_boulder"]["shot"]
	var roll := _event(shot, "roll")
	m._on_event("ShotResolved", shot)
	_run(m, float(roll["t"]) + float(roll["duration"]) * 0.5)
	var rolling := _fx(m, RollingBoulderView).filter(func(b): return b.on_ground)
	eq(rolling.size(), 1, "rolling along the ground")
	check(rolling[0].position.distance_to(PathMotion.new(roll).position_at(m._shot_player.time())) < 1.0, "on the path's clock")
	_run(m, float(shot["duration"]))
	check(not m._shot_player.is_playing(), "done")
	_free(m)


func test_snowman_leaps_without_warning() -> void:
	var m := _screen("ice_witch", "blizzard")
	m._players["minion_snowman_1"] = {"playerId": "minion_snowman_1", "teamId": 2, "role": "minion", "bossId": "ice_witch",
		"minionId": "snowman", "bodySize": 0.85, "hp": 900, "maxHp": 900, "isAlive": true, "position": {"x": 900.0, "y": 700.0},
		"statusEffects": [], "items": [], "characterId": ""}
	var v: Node2D = PlayerView.new()
	v.walk.terrain = m._mask
	m._players_layer.add_child(v)
	v.setup(m._players["minion_snowman_1"], false, 1)
	m._views["minion_snowman_1"] = v
	m._on_event("UnitJumped", {"playerId": "minion_snowman_1", "from": {"x": 900, "y": 700}, "to": {"x": 600, "y": 700},
		"duration": 0.6, "height": 120})
	check(not m.leap_state().warning("minion_snowman_1") and not v.leapt(), "063: no fuse warning after its leap")
	_free(m)


# ── Boss result ──────────────────────────────────────────────────────────────

func test_boss_result_gift() -> void:
	BossFixture.take()
	var info := BossResultModel.info({"winningTeam": 1, "result": "boss_defeated", "boss": {"bossId": "steel_robot", "round": 9,
		"turnLimit": 20, "bossHp": 0, "bossMaxHp": 19000, "bossDamage": {"me": 9000}}},
		{"me": {"playerId": "me", "teamId": 1, "characterId": "rookie", "displayName": "Tôi"}}, "me", "",
		{"expGained": 10, "coinGained": 20, "bonusRun": true, "bonusRunsLeft": 2})
	var s: Control = BossResultScreen.new()
	s.setup(info)
	var bottom: Control = s._build_bottom()
	var gift: Node = bottom.find_child("RunGift", true, false)
	check(gift != null, "the gift box")
	var count: Label = bottom.find_child("RunsLeft", true, false)
	eq(count.text if count != null else "", "×2", "the big runs left")
	check(not _texts(bottom).any(func(t): return "Lượt thưởng" in t or "lượt thưởng" in t or "Thưởng thường" in t), "no run sentence")
	bottom.free()
	s.free()


# ── Harness ──────────────────────────────────────────────────────────────────

static func _texts(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Label:
			out.append(c.text)
		out.append_array(_texts(c))
	return out


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


## match_screen without its scene (real views, HUD, ShotPlayer, driven by hand) with the units of
## the fixture's case `case_id` (me = its p0 when there is one, else a member far off).
func _screen(boss: String, case_id: String) -> Node2D:
	BossFixture.take()
	var fx: Dictionary = _fixture()[case_id]
	var m: Node2D = MatchScreen.new()
	var bid := "boss_" + boss
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
	if not m._players.has("me"):
		m._players["me"] = {"playerId": "me", "teamId": 1, "characterId": "rookie", "hp": 1000, "maxHp": 1000, "isAlive": true,
			"position": {"x": 60.0, "y": 600.0}, "statusEffects": [], "items": [], "skillEnergy": 0, "moveEnergy": 100, "maxMoveEnergy": 100}
	m._mask = _ground(2400, 1120, 1000)
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
	m._load_boss({"boss": {"bossId": boss, "playerId": bid, "turnLimit": 20, "round": 3}, "players": m._players})
	return m


func _free(m: Node2D) -> void:
	m._shot_player.stop()
	for n in [m._hud, m._aim, m._shot_player, m._players_layer, m._fx_layer, m._sky, m._terrain_view, m._screen_fx, m._lava_view, m._blind]:
		if is_instance_valid(n):
			n.free()
	m.free()


## Runs the replay (and the views, the screen's frame) for sec s.
func _run(m: Node2D, sec: float) -> void:
	var t := 0.0
	while t < sec - 1e-9:
		m._shot_player._process(DT)
		m._process(DT)
		for v in m._views.values():
			v._process(DT)
		t += DT


static func _fx(m: Node2D, script: Script) -> Array:
	return _children_of(m._fx_layer, script)


static func _children_of(n: Node, script: Script) -> Array:
	return n.get_children().filter(func(c): return c.get_script() == script and not c.is_queued_for_deletion())
