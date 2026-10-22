extends "res://tests/test_case.gd"
## The match camera (match/camera/camera_model.gd), the off-screen markers' layout
## (match/views/offscreen_markers.gd), the aim under a moved camera (match/aim/aim_input.gd) and
## match_screen feeding the camera (turn pans, holds, the replay's shells).

const CameraModel := preload("res://match/camera/camera_model.gd")
const OffscreenMarkers := preload("res://match/views/offscreen_markers.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const AimAid := preload("res://match/aim/aim_aid.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const Hud := preload("res://match/hud.gd")
const SkyView := preload("res://match/views/sky_view.gd")
const MatchScreen := preload("res://match/match_screen.gd")

const MAP := Vector2(2400, 1120)
const VIEW := Vector2(1600, 900)
const DT := 1.0 / 60.0


func _cam(map: Vector2 = MAP, view: Vector2 = VIEW) -> CameraModel:
	var c := CameraModel.new()
	c.setup(map, view)
	return c


func _run(c: CameraModel, sec: float) -> void:
	var t := 0.0
	while t < sec - 1e-9:
		c.step(DT)
		t += DT


func _vnear(a: Vector2, b: Vector2, eps: float, msg: String) -> void:
	check(a.distance_to(b) <= eps, "%s: got %s, want %s (±%s)" % [msg, a, b, eps])


# ── Clamping and sizes ─────────────────────────────────────────────────────

func test_clamped_to_the_map() -> void:
	var c := _cam()
	eq(c.clamp_center(Vector2(-500, -500)), Vector2(800, 450), "top left corner")
	eq(c.clamp_center(Vector2(9000, 9000)), Vector2(1600, 670), "bottom right corner")
	eq(c.clamp_center(Vector2(1200, 500)), Vector2(1200, 500), "inside: unchanged")
	eq(c.clamp_center(Vector2(1200, -500), true), Vector2(1200, 450 - CameraModel.SKY_RISE), "a shot may rise SKY_RISE above the top")
	var r := c.view_rect()
	check(Rect2(Vector2.ZERO, MAP).encloses(r), "the view inside the map: %s" % r)


func test_small_map_is_centred_and_does_not_pan() -> void:
	var c := _cam(Vector2(1600, 900), Vector2(2000, 900))
	eq(c.center, Vector2(800, 450), "centred")
	c.manual_pan(Vector2(300, 200))
	eq(c.center, Vector2(800, 450), "no pan along a smaller (or equal) axis")
	c.start_shot()
	c.track(PackedVector2Array([Vector2(100, -400)]))
	_run(c, 1.0)
	eq(c.center, Vector2(800, 450), "not even after a shell")
	var low := _cam(Vector2(2400, 700), VIEW)
	eq(low.clamp_center(Vector2(300, 100)).y, 250.0, "a lower map sits on the view's bottom (sky above it)")
	eq(low.clamp_center(Vector2(300, 100)).x, 800.0, "and still pans in x")
	eq(c.min_zoom(), 1.0, "a map that fits: no zoom out")


func test_zoom_fits_the_map_and_keeps_the_anchor() -> void:
	var c := _cam()
	near(c.min_zoom(), minf(1600.0 / 2400.0, 900.0 / 1120.0), 1e-6, "down to the whole map fitting")
	c.center = Vector2(1200, 560)
	var anchor := Vector2(1200, 300) # screen px
	var world := c.center + (anchor - VIEW / 2.0) / c.zoom
	c.zoom_at(0.9, anchor)
	near(c.zoom, 0.9, 1e-6, "zoomed out")
	_vnear(c.center + (anchor - VIEW / 2.0) / c.zoom, world, 0.01, "the point under the pointer stays")
	c.zoom_at(0.01, anchor)
	near(c.zoom, c.min_zoom(), 1e-6, "clamped to the fit")
	near(c.view_rect().size.x, 2400.0, 0.5, "the whole width shows")
	eq(c.center.x, 1200.0, "centred: nothing left to pan in x")
	c.zoom_at(5.0, anchor)
	eq(c.zoom, 1.0, "never past 1")


# ── Modes ────────────────────────────────────────────────────────────────

func test_turn_pan_eases_then_follows() -> void:
	var c := _cam()
	c.snap(Vector2(800, 600))
	c.pan_to(Vector2(2000, 600))
	eq(c.mode, CameraModel.TURN, "turn mode")
	_run(c, CameraModel.PAN_SEC * 0.25)
	var quarter := c.center.x
	check(quarter > 800.0 and quarter < 1100.0, "eased in: slow at first (%f)" % quarter)
	_run(c, CameraModel.PAN_SEC * 0.25)
	near(c.center.x, 1200.0, 30.0, "half way at half time")
	_run(c, CameraModel.PAN_SEC * 0.5 + 0.02)
	near(c.center.x, 1600.0, 0.01, "there (clamped to the map's right) after PAN_SEC")
	c.retarget(Vector2(1000, 600))
	_run(c, 2.0)
	near(c.center.x, 1000.0, 1.0, "then follows its player walking")


func test_hold_then_pan() -> void:
	var c := _cam()
	c.snap(Vector2(900, 600))
	c.start_shot()
	c.hold(CameraModel.HOLD_SEC)
	c.pan_to(Vector2(1500, 600))
	eq(c.mode, CameraModel.SHOT, "the pan waits for the hold")
	_run(c, CameraModel.HOLD_SEC * 0.5)
	near(c.center.x, 900.0, 0.01, "still on the blast")
	_run(c, CameraModel.HOLD_SEC * 0.5 + DT)
	eq(c.mode, CameraModel.TURN, "the hold is over: the pan starts")
	_run(c, CameraModel.PAN_SEC + DT)
	near(c.center.x, 1500.0, 0.01, "and gets there")


func test_aim_follows_the_tip_keeping_the_shooter() -> void:
	var c := _cam()
	var shooter := Vector2(1200, 700)
	c.snap(shooter)
	c.start_aim(shooter, Vector2(1500, 600))
	eq(c.mode, CameraModel.AIM, "aim mode")
	_run(c, 3.0)
	_vnear(c.center, Vector2(1500, 600), 1.0, "heads for the guide's tip")
	c.aim_at(shooter, Vector2(2300, 400)) # far: the shooter would leave the view
	_run(c, 3.0)
	var r := c.view_rect().grow(-CameraModel.KEEP_MARGIN.x + 1.0)
	check(r.has_point(shooter), "the shooter stays KEEP_MARGIN inside the view: %s in %s" % [shooter, c.view_rect()])
	check(c.center.x > 1500.0, "still looking ahead (%f)" % c.center.x)
	var before := c.center
	c.release()
	eq(c.mode, CameraModel.IDLE, "released: idle")
	_run(c, 1.0)
	_vnear(c.center, before, 0.5, "stays where it is until the shot")
	c.aim_at(shooter, Vector2(800, 600))
	_vnear(c.target(), before, 0.5, "an aim update outside aim mode does nothing")


func test_shot_follows_the_box_of_the_shells() -> void:
	var c := _cam()
	c.snap(Vector2(800, 700))
	c.start_shot()
	eq(c.mode, CameraModel.SHOT, "shot mode")
	check(c.sky, "may rise above the map")
	c.track(PackedVector2Array([Vector2(1000, 400), Vector2(1400, 100), Vector2(1200, 250)]))
	_vnear(c.target(), Vector2(1200, 250), 0.01, "the middle of the shells' box")
	_run(c, 3.0)
	_vnear(c.center, Vector2(1200, 250), 1.0, "followed into the sky")
	check(c.view_rect().position.y < 0.0, "the view rose above the map's top")
	c.track(PackedVector2Array([Vector2(1200, -900)]))
	near(c.target().y, 450.0 - CameraModel.SKY_RISE, 0.01, "no higher than SKY_RISE over the map")
	var at := c.target()
	c.track(PackedVector2Array())
	_vnear(c.target(), at, 0.01, "no shells: stays")
	c.pan_to(Vector2(2000, 600))
	check(not c.sky, "the next pan is back inside the map")
	_run(c, CameraModel.PAN_SEC + DT)
	check(c.view_rect().position.y >= -0.01, "back under the map's top")


func test_manual_look_stays_until_the_next_take() -> void:
	var c := _cam()
	c.snap(Vector2(1200, 600))
	c.start_aim(Vector2(1200, 700), Vector2(1300, 600))
	c.manual_pan(Vector2(200, 0)) # the finger moves right: the view goes left
	eq(c.mode, CameraModel.MANUAL, "manual")
	near(c.center.x, 1000.0, 0.01, "the world follows the finger")
	c.aim_at(Vector2(1200, 700), Vector2(1800, 600))
	c.track(PackedVector2Array([Vector2(2000, 300)]))
	c.retarget(Vector2(2000, 300))
	_run(c, 1.0)
	near(c.center.x, 1000.0, 0.01, "updates do not move a manual look")
	c.start_aim(Vector2(1200, 700), Vector2(1300, 600))
	eq(c.mode, CameraModel.AIM, "a new aim drag takes it back")
	c.look_at(Vector2(2200, 600))
	eq(c.mode, CameraModel.MANUAL, "a marker tap: manual")
	_run(c, CameraModel.PAN_SEC + DT)
	near(c.center.x, 1600.0, 0.01, "panned there")
	c.start_shot()
	eq(c.mode, CameraModel.SHOT, "a shot takes it")
	c.pan_to(Vector2(800, 600))
	eq(c.mode, CameraModel.TURN, "a turn start takes it")


func test_column_scrolls_at_the_screen_sides() -> void:
	var c := _cam()
	c.snap(Vector2(1200, 600))
	c.start_aim(Vector2(1200, 700), c.center)
	c.column_scroll(VIEW.x * 0.6, 0.5)
	eq(c.center.x, 1200.0, "near the middle: no scroll (no runaway)")
	c.column_scroll(VIEW.x - 10.0, 0.25)
	check(c.center.x > 1300.0, "at the right side: scrolls right (%f)" % c.center.x)
	c.column_scroll(10.0, 5.0)
	eq(c.center.x, 800.0, "to the left end, clamped")


func test_shake_is_small_and_fades() -> void:
	var c := _cam()
	eq(c.shake_offset(), Vector2.ZERO, "none at first")
	c.shake(40.0)
	c.step(0.03)
	var o := c.shake_offset()
	check(o.length() > 0.1 and o.length() <= CameraModel.SHAKE_MAX * 2.0, "a small shake: %s" % o)
	var small := _cam()
	small.shake(5.0)
	var big := _cam()
	big.shake(500.0)
	check(small._shake < big._shake and big._shake <= CameraModel.SHAKE_MAX, "scaled by the blast, capped")
	_run(c, CameraModel.SHAKE_SEC)
	eq(c.shake_offset(), Vector2.ZERO, "gone after SHAKE_SEC")


func test_parallax_covers_every_position() -> void:
	var c := _cam()
	var travel := c.parallax_travel(0.3)
	near(travel.x, (2400.0 - 1600.0) * 0.3, 0.01, "a share of the centre's range in x")
	near(travel.y, (1120.0 + CameraModel.SKY_RISE - 900.0) * 0.3, 0.01, "and in y, the sky included")
	for p in [Vector2(0, 0), Vector2(5000, 5000), Vector2(1200, -400), Vector2(1200, 560)]:
		c.center = c.clamp_center(p, true)
		var off := c.parallax(0.3)
		check(off.x <= 0.0 and off.y <= 0.0 and off.x >= -travel.x - 0.01 and off.y >= -travel.y - 0.01,
			"at %s the layer (screen + travel) covers the screen: %s" % [c.center, off])
	c.center = c.clamp_center(Vector2(0, 9999))
	_vnear(c.parallax(0.3), Vector2(0, -travel.y), 0.01, "left bottom: the layer's left bottom")
	var small := _cam(Vector2(1600, 900), Vector2(2000, 900))
	eq(small.parallax_travel(0.3), Vector2.ZERO, "a map that fits: no travel")


# ── Off-screen markers ────────────────────────────────────────────────────────

func test_markers_for_players_off_screen() -> void:
	var screen := Vector2(1600, 900)
	var m := OffscreenMarkers.place({"a": Vector2(800, 400), "b": Vector2(2400, 500), "c": Vector2(-300, 50), "d": Vector2(700, -200)}, screen)
	eq(m.size(), 3, "only those off screen")
	var by := {}
	for e in m:
		by[e["id"]] = e
	check(not by.has("a"), "on screen: none")
	eq(by["b"]["at"], Vector2(1600 - OffscreenMarkers.EDGE, 500), "right edge, at its height")
	check(by["b"]["dir"].x > 0.99, "pointing right")
	eq(by["c"]["at"], Vector2(OffscreenMarkers.EDGE, OffscreenMarkers.TOP), "left edge, kept under the HUD's top row")
	check(by["c"]["dir"].x < 0.0 and by["c"]["dir"].y < 0.0, "pointing up-left")
	eq(by["d"]["at"], Vector2(700, OffscreenMarkers.TOP), "above: on the top inset")


func test_markers_avoid_hud_and_each_other() -> void:
	var screen := Vector2(1600, 900)
	var button := Rect2(1600 - 24 - 110, 450 - 55, 110, 110)
	var m := OffscreenMarkers.place({"b": Vector2(2000, 450)}, screen, [button])
	var at: Vector2 = m[0]["at"]
	check(not button.grow(OffscreenMarkers.RADIUS).has_point(at), "off the move button: %s" % at)
	var two := OffscreenMarkers.place({"x": Vector2(2000, 500), "y": Vector2(2100, 505)}, screen)
	check(two[0]["at"].distance_to(two[1]["at"]) >= OffscreenMarkers.RADIUS * 2.0, "stacked apart: %s %s" % [two[0]["at"], two[1]["at"]])
	var skill := Rect2(1600 - 24 - 132, 900 - 24 - 170, 132, 170)
	var low := OffscreenMarkers.place({"x": Vector2(2000, 820), "y": Vector2(2050, 840)}, screen, [skill])
	for e in low:
		check(not skill.grow(OffscreenMarkers.RADIUS).has_point(e["at"]), "%s off the skill slot: %s" % [e["id"], e["at"]])
	check(low[0]["at"].distance_to(low[1]["at"]) >= OffscreenMarkers.RADIUS * 2.0, "and apart: %s %s" % [low[0]["at"], low[1]["at"]])


# ── The aim under a moved camera ──────────────────────────────────────────────

func _flat(w: int = 2400, h: int = 1120, ground_y: int = 900):
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


func _press(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	return e


func _motion(at: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = at
	return e


func test_aim_is_screen_space_under_the_camera() -> void:
	var a = AimInput.new()
	a.terrain = _flat()
	a.shooter_pos = Vector2(1700, 900)
	a.enabled = true
	a.canvas = Transform2D(0.0, Vector2(-1000, -200)) # the camera moved right and down
	check(a._press_starts_drag(_press(Vector2(900, 300), true)), "a press starts the drag")
	a._drag_event(_motion(Vector2(1000, 400)))
	var angle: float = a._angle
	var power: float = a._power
	near(power, Vector2(100, 100).length() / 2.0, 1e-4, "power from the screen move")
	a.canvas = Transform2D(0.0, Vector2(-1300, -100)) # the camera follows the aim
	a._process(DT)
	near(a._angle, angle, 1e-6, "the camera moving does not change the angle")
	near(a._power, power, 1e-6, "nor the power")
	check(a.look_point() is Vector2, "the camera's look point while aiming")
	# The cancel ring is in the world: the shooter's body at screen (1700, 880) - (1300, 100).
	a._drag_event(_motion(Vector2(400, 780)))
	check(a._in_cancel, "the release point over the shooter on screen cancels")
	a.canvas = Transform2D(0.0, Vector2(-1000, -100))
	a._process(DT)
	check(not a._in_cancel, "the camera moved the shooter away: no longer in the cancel ring")
	a.cancel()
	check(not a.is_dragging(), "cancelled (a second finger)")
	# Column mode: the column is the pointer's world x, again when the camera moves.
	a.target_column = true
	a._press_starts_drag(_press(Vector2(500, 300), true))
	near(a._column_x, 1500.0, 1e-3, "pointer x + the camera's offset")
	a.canvas = Transform2D(0.0, Vector2(-1200, -100))
	a._process(DT)
	near(a._column_x, 1700.0, 1e-3, "the camera scrolled: the column follows")
	a.cancel()
	a.free()


func test_aim_arrow_relative_to_the_view_top() -> void:
	var origin := Vector2(300, 880)
	var v := AimAid.launch_velocity(75.0, 80.0)
	var at_map := AimAid.fly(origin, v, 0.0, _flat(), PackedVector2Array(), PackedFloat32Array())
	var risen := AimAid.fly(origin, v, 0.0, _flat(), PackedVector2Array(), PackedFloat32Array(), 0.0, 400.0)
	check(is_nan(float(at_map["high_x"])), "never above the map's top")
	check(not is_nan(float(risen["high_x"])), "but above a view whose top is at y 400")
	var sp := ShotPlayer.new()
	sp.layer = Node2D.new()
	sp.play(ShotTimeline.new({"duration": 2.0, "projectiles": [{"projectileId": "p", "path": [
		{"time": 0.0, "position": {"x": 100.0, "y": 300.0}, "velocity": {"x": 0.0, "y": 0.0}},
		{"time": 2.0, "position": {"x": 100.0, "y": 300.0}, "velocity": {"x": 0.0, "y": 0.0}}]}]}))
	sp._process(0.1)
	eq(sp.high_shells().size(), 0, "under the map's top")
	eq(sp.high_shells(400.0).size(), 1, "above a lower view top")
	eq(sp.live_positions().size(), 1, "the live shells the camera follows")
	_vnear(sp.live_positions()[0], Vector2(100, 300), 0.01, "where it is drawn")
	sp.stop()
	sp.layer.free()
	sp.free()


# ── match_screen feeding the camera ───────────────────────────────────────────

func _player(id: String, team: int, x: float) -> Dictionary:
	return {"playerId": id, "displayName": id, "teamId": team, "characterId": "rookie", "hp": 1000, "maxHp": 1000,
		"isAlive": true, "position": {"x": x, "y": 900.0}, "skillEnergy": 0, "items": [], "statusEffects": [],
		"moveEnergy": 100, "maxMoveEnergy": 100}


func _screen() -> Node2D:
	var m: Node2D = MatchScreen.new()
	m._me = "me"
	m._current = "me"
	m._players = {"me": _player("me", 1, 300.0), "e1": _player("e1", 2, 2100.0)}
	m._players_layer = Node2D.new()
	m._fx_layer = Node2D.new()
	m._sky = SkyView.new()
	for id in m._players:
		var v: Node2D = PlayerView.new()
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
	m._shot_player.finished.connect(m._on_shot_finished)
	m._cam.setup(MAP, VIEW)
	m._cam.snap(Vector2(300, 840))
	return m


func _free(m: Node2D) -> void:
	m._shot_player.stop()
	for n in [m._hud, m._aim, m._shot_player, m._players_layer, m._fx_layer, m._sky]:
		n.free()
	m.free()


func _frames(m: Node2D, sec: float) -> void:
	var t := 0.0
	while t < sec - 1e-9:
		m._shot_player._process(DT)
		m._track_camera(DT)
		m._cam.step(DT)
		t += DT


func test_screen_turn_start_pans_to_the_player() -> void:
	var m := _screen()
	m._apply("TurnStarted", {"currentPlayerId": "e1", "turnIndex": 1, "moveEnergy": 100})
	eq(m._cam.mode, CameraModel.TURN, "a turn start pans")
	_frames(m, CameraModel.PAN_SEC + 0.1)
	near(m._cam.center.x, 1600.0, 0.5, "onto the enemy (clamped to the map's right)")
	_free(m)


func test_screen_shot_follows_the_shell_holds_then_pans() -> void:
	var m := _screen()
	var shot := {"shooterId": "me", "actionMode": "weapon", "duration": 1.6,
		"projectiles": [{"projectileId": "p1", "explosionRadius": 40.0, "path": [
			{"time": 0.0, "position": {"x": 300.0, "y": 880.0}, "velocity": {"x": 1200.0, "y": -800.0}},
			{"time": 1.5, "position": {"x": 2100.0, "y": 880.0}, "velocity": {"x": 1200.0, "y": 800.0}}]}],
		"events": [{"t": 1.5, "type": "explode", "position": {"x": 2100.0, "y": 880.0}, "radius": 30.0, "projectileId": "p1"}]}
	m._mask = _flat()
	m._terrain_view = preload("res://match/terrain/terrain_view.gd").new()
	m._apply("ShotResolved", shot)
	eq(m._cam.mode, CameraModel.SHOT, "the replay takes the camera")
	_frames(m, 0.8)
	var shell: Vector2 = m._shot_player.live_positions()[0]
	check(m._cam.view_rect().has_point(shell), "the shell in view mid-flight: %s in %s" % [shell, m._cam.view_rect()])
	_frames(m, 0.75)
	check(m._cam.holding(), "the explosion holds the camera")
	m._on_event("TurnStarted", {"currentPlayerId": "e1", "turnIndex": 1, "moveEnergy": 100})
	_frames(m, 0.2)
	check(m._shot_player.is_playing() or m._cam.mode == CameraModel.SHOT, "the pan waits for the hold")
	_frames(m, CameraModel.HOLD_SEC + CameraModel.PAN_SEC + 0.3)
	eq(m._cam.mode, CameraModel.TURN, "then the next turn's pan")
	near(m._cam.center.x, 1600.0, 1.0, "onto its player")
	m._terrain_view.free()
	_free(m)


func test_screen_remote_aim_and_my_drag() -> void:
	var m := _screen()
	m._current = "e1"
	m._apply("PlayerAiming", {"playerId": "e1", "angle": 150.0, "durationMs": 1500})
	eq(m._cam.mode, CameraModel.AIM, "a remote aim takes the camera")
	m._cam.manual_pan(Vector2(50, 0))
	_frames(m, 0.5)
	eq(m._cam.mode, CameraModel.MANUAL, "a manual look stays during its sweep")
	m._current = "me"
	m._aim.terrain = _flat()
	m._aim.shooter_pos = Vector2(1300, 900)
	m._aim.enabled = true
	m._aim._press_starts_drag(_press(Vector2(800, 300), true))
	m._aim._drag_event(_motion(Vector2(700, 400)))
	_frames(m, 0.05)
	eq(m._cam.mode, CameraModel.AIM, "my drag takes it back to aim-follow")
	m._aim._drag_event(_press(Vector2(700, 400), false)) # released (fires: nothing listens here)
	_frames(m, 0.05)
	eq(m._cam.mode, CameraModel.IDLE, "released: stays until the shot")
	_free(m)


func test_marker_head_is_the_match_sprite() -> void:
	const Art := preload("res://ui/art.gd")
	for id in Art.CHARACTERS:
		var head := Art.side_head(id)
		check(not head.is_empty(), "%s: a head from its side view" % id)
		if head.is_empty():
			continue
		var side := Art.side_view(id)
		eq(head["texture"], (side["frames"] as SpriteFrames).get_frame_texture("idle", 0), "%s: the match sprite's idle frame, not portrait.png" % id)
		var r: Rect2 = head["rect"]
		var size: Vector2 = (head["texture"] as Texture2D).get_size()
		check(r.size.x > size.y * 0.25 and r.size.x < size.y * 0.6, "%s: a head-sized square (%s in %s)" % [id, r, size])
		check(r.position.y < size.y * 0.15 and r.get_center().x > 0.0 and r.get_center().x < size.x, "%s: at the top of the figure" % id)
	var m := OffscreenMarkers.new()
	m._ready()
	var head := Art.side_head("rookie")
	var right := m.head_uvs(head, false)
	var left := m.head_uvs(head, true)
	near(right[0].x + left[0].x, 2.0 * head["rect"].get_center().x / head["texture"].get_size().x, 1e-5, "mirrored to face a player on the left")
	m.free()
