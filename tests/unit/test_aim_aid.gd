extends "res://tests/test_case.gd"
## The aiming aid (match/aim/aim_aid.gd, drawn by aim_input.gd), the in-flight top arrows
## (match/views/high_shell_marker.gd) and the move buttons on the screen's edges (match/hud.gd).

const AimAid := preload("res://match/aim/aim_aid.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const Trajectory := preload("res://match/aim/trajectory_predictor.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const HighShellMarker := preload("res://match/views/high_shell_marker.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const MatchScreen := preload("res://match/match_screen.gd")
const Hud := preload("res://match/hud.gd")

const GROUND := 700
const FEET := Vector2(200, GROUND) # the shooter, on the flat ground


func _flat(w: int = 1600, h: int = 900, ground_y: int = GROUND):
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


## An AimInput (not in the tree: no lines drawn, the aid still computed) from FEET on flat ground.
func _aim(terrain = null):
	var a = AimInput.new()
	a.terrain = terrain if terrain != null else _flat()
	a.shooter_pos = FEET
	a.enabled = true
	a._dragging = true
	a._start = Vector2(800, 300)
	return a


## Drags for a shot at angle (degrees, 90 up) and power.
func _drag(a, angle: float, power: float) -> void:
	var r := deg_to_rad(angle)
	a._update(a._start + Vector2(-cos(r), sin(r)) * power * 2.0)


func test_arc_fraction_by_tier() -> void:
	var want := {"bronze": 0.6, "silver": 0.5, "gold": 0.4, "platinum": 0.3, "diamond": 0.22, "master": 0.15}
	for tier in want:
		near(AimAid.arc_fraction(tier), want[tier], 1e-9, tier)
	near(AimAid.arc_fraction(""), 0.6, 1e-9, "no rank: bronze")
	near(AimAid.arc_fraction("legend"), 0.6, 1e-9, "unknown tier: bronze")


func test_guide_arc_follows_the_wind_and_is_shorter_by_rank() -> void:
	var a = _aim()
	a.wind_dir = 1
	a.wind_power = 4.0
	var lengths := {}
	for tier in ["", "bronze", "silver", "master"]:
		a.rank_tier = tier
		_drag(a, 55.0, 70.0)
		lengths[tier] = a.aid()["guide"].size() - 1 # steps of TIME_STEP
	var origin := Trajectory.shot_origin(FEET, a.terrain)
	var v := AimAid.launch_velocity(a._angle, a._power)
	var flight := AimAid.fly(origin, v, AimAid.wind_accel(1, 4.0), a.terrain, PackedVector2Array(), PackedFloat32Array())
	var steps: float = flight["time"] / Trajectory.TIME_STEP
	eq(lengths["bronze"], roundi(0.6 * steps), "bronze: 60 % of the exact flight")
	eq(lengths[""], lengths["bronze"], "no rank: as bronze")
	eq(lengths["silver"], roundi(0.5 * steps), "silver: 50 %")
	eq(lengths["master"], roundi(0.15 * steps), "master: 15 %")
	check(lengths["master"] < lengths["silver"] and lengths["silver"] < lengths["bronze"], "higher rank, shorter guide")
	var windy := Trajectory.simulate(origin.x, origin.y, v.x, v.y, AimAid.wind_accel(1, 4.0), a.terrain, lengths["bronze"] + 1)
	var calm := Trajectory.simulate(origin.x, origin.y, v.x, v.y, 0.0, a.terrain, lengths["bronze"] + 1)
	a.rank_tier = "bronze"
	_drag(a, 55.0, 70.0)
	eq(a.aid()["guide"], windy, "bronze guide = the start of the exact, windy flight")
	check(a.aid()["guide"] != calm, "the wind bends the guide")
	a.free()


func test_shown_point_formula() -> void:
	near(AimAid.shown_x(800.0, 2.0, 2.0), 788.0, 1e-9, "X − 3 × W × T")
	near(AimAid.shown_x(800.0, 4.0, 6.0), 740.0, 1e-9, "capped at 60 px")
	near(AimAid.shown_x(800.0, -4.0, 6.0), 860.0, 1e-9, "capped at 60 px the other way")
	# W > 0 blows right: a shot to the right (tailwind) shows short, one to the left (headwind) long
	var right_tail := AimAid.shown_x(800.0, 2.0, 2.0)
	check(absf(right_tail - 200.0) < 600.0, "tailwind right: shown nearer the shooter at 200")
	var left_head := AimAid.shown_x(800.0, 2.0, 2.0)
	check(absf(left_head - 1400.0) > 600.0, "headwind left: shown farther from the shooter at 1400")
	# W < 0 blows left: the other way round
	var right_head := AimAid.shown_x(800.0, -2.0, 2.0)
	near(right_head, 812.0, 1e-9, "headwind right: +12")
	check(absf(right_head - 200.0) > 600.0, "headwind right: farther")
	check(absf(right_head - 1400.0) < 600.0, "tailwind left: nearer the shooter at 1400")
	near(AimAid.shown_x(800.0, 0.0, 5.0), 800.0, 1e-9, "no wind: the exact x")
	var m = _flat()
	eq(AimAid.shown_point(Vector2(800, 690), 2.0, 2.0, m), Vector2(788, GROUND), "dropped onto the ground")
	eq(AimAid.shown_point(Vector2(20, 690), 4.0, 3.0, m), Vector2(0, GROUND), "clamped to the map")
	eq(AimAid.shown_point(Vector2(1580, 690), -4.0, 3.0, m), Vector2(1599, GROUND), "clamped right")
	# two levels in the column: the surface nearest the exact landing
	for y in range(300, 320):
		for x in range(700, 900):
			m.solid[y * m.width + x] = TerrainMask.SOLID
	eq(AimAid.surface_y(m, 760.0, 690.0), float(GROUND), "the lower ground for a low landing")
	eq(AimAid.surface_y(m, 760.0, 280.0), 300.0, "the ledge for a high one")
	eq(AimAid.surface_y(m, 760.0, 650.0), float(GROUND), "a landing under the ledge stays under it")


func test_shown_marker_from_the_exact_landing() -> void:
	var a = _aim()
	a.wind_dir = 1
	a.wind_power = 3.0
	a.wind_influence = 0.5 # Tanko's cannon: half the wind
	a.projectile_weight = 1.5
	_drag(a, 50.0, 60.0)
	var origin := Trajectory.shot_origin(FEET, a.terrain)
	var flight := AimAid.fly(origin, AimAid.launch_velocity(a._angle, a._power), 30.0 * 3.0 * 0.5 / 1.5, a.terrain,
		PackedVector2Array(), PackedFloat32Array())
	var mark: Dictionary = a.aid()["marks"][0]
	near(mark["point"].x, float(flight["end"].x) - minf(60.0, 3.0 * 3.0 * float(flight["time"])), 1e-3, "shown x from the weapon's exact flight")
	near(mark["point"].y, float(GROUND), 1e-6, "on the ground")
	check(not mark["hit"], "no enemy: no hit")
	_drag(a, 50.0, 3.0)
	eq(a.aid()["marks"].size(), 0, "no marker below MIN_POWER")
	a.free()


func test_hit_tolerance() -> void:
	near(AimAid.hit_tolerance(100.0, 50.0), 20.0 * (0.2 + 0.8 * 100.0 / 1200.0), 1e-9, "near and low: ~5.3 px")
	near(AimAid.hit_tolerance(-100.0, 50.0), AimAid.hit_tolerance(100.0, 50.0), 1e-9, "either side")
	near(AimAid.hit_tolerance(0.0, 0.0), 4.0, 1e-9, "point blank: 4 px")
	near(AimAid.hit_tolerance(600.0, 0.0), 12.0, 1e-9, "half the far distance: 12 px")
	near(AimAid.hit_tolerance(200.0, 350.0), 12.0, 1e-9, "or half the high apex")
	near(AimAid.hit_tolerance(1500.0, 100.0), 20.0, 1e-9, "far: capped at 20")
	near(AimAid.hit_tolerance(300.0, 900.0), 20.0, 1e-9, "high: capped at 20")
	near(AimAid.apex_height(90.0, 50.0), 300.0 * 300.0 / 400.0, 1e-6, "apex (power × 6 × sin a)² / 400")
	eq(AimAid.apex_height(-30.0, 50.0), 0.0, "shot down: no apex")


## The apex of the shot the aim is dragged for (no enemies), its tolerance r and the aim angle.
func _apex(a) -> Array:
	a.enemies = PackedVector2Array()
	_drag(a, 60.0, 70.0)
	var origin := Trajectory.shot_origin(FEET, a.terrain)
	var v := AimAid.launch_velocity(a._angle, a._power)
	var path := Trajectory.simulate(origin.x, origin.y, v.x, v.y, 0.0, a.terrain, 100000)
	var top := path[0]
	for p in path:
		if p.y < top.y:
			top = p
	var flight := AimAid.fly(origin, v, 0.0, a.terrain, PackedVector2Array(), PackedFloat32Array())
	var r := AimAid.hit_tolerance(flight["end"].x - origin.x, AimAid.apex_height(a._angle, a._power))
	return [top, r]


func test_hit_check_on_the_exact_path() -> void:
	var a = _aim()
	var apex_r := _apex(a)
	var top: Vector2 = apex_r[0]
	var r: float = apex_r[1]
	check(r > 10.0 and r < 20.0, "a mid shot's tolerance (%f)" % r)
	# an enemy whose body the shell's r circle touches at the apex (it passes over, unhit)
	a.enemies = PackedVector2Array([top - Vector2(0, AimAid.HIT_RADIUS + r - 1.0)])
	_drag(a, 60.0, 70.0)
	var aid: Dictionary = a.aid()
	eq(aid["hits"], [0], "touches: Trúng")
	check(aid["marks"][0]["hit"], "the marker shows it")
	a.enemies = PackedVector2Array([top - Vector2(0, AimAid.HIT_RADIUS + r + 1.0)])
	_drag(a, 60.0, 70.0)
	eq(a.aid()["hits"], [], "misses by r + 1: no hit")
	check(not a.aid()["marks"][0]["hit"], "neutral marker")
	# an enemy right on the path stops the shell there (the server's body hit)
	var on_path := top + Vector2(0, 5)
	a.enemies = PackedVector2Array([on_path])
	_drag(a, 60.0, 70.0)
	eq(a.aid()["hits"], [0], "on the path: hit")
	var origin := Trajectory.shot_origin(FEET, a.terrain)
	var flight := AimAid.fly(origin, AimAid.launch_velocity(a._angle, a._power), 0.0, a.terrain, a.enemies, PackedFloat32Array())
	eq(flight["hit"], 0, "the exact flight stops on the body")
	check(flight["end"].distance_to(on_path) <= AimAid.HIT_RADIUS + 1e-3, "at its hitbox")
	a.free()


func test_allies_are_never_hit() -> void:
	var a = _aim()
	var top: Vector2 = _apex(a)[0]
	var m = MatchScreen.new()
	m._me = "me"
	m._armed = "weapon"
	var feet := top + Vector2(0, AimAid.BODY_LIFT) # a body right on the path
	m._players = {
		"me": {"playerId": "me", "teamId": 1, "characterId": "spark", "isAlive": true, "position": {"x": FEET.x, "y": FEET.y}},
		"ally": {"playerId": "ally", "teamId": 1, "isAlive": true, "position": {"x": feet.x, "y": feet.y}},
		"dead": {"playerId": "dead", "teamId": 2, "isAlive": false, "position": {"x": feet.x, "y": feet.y}},
		"foe": {"playerId": "foe", "teamId": 2, "isAlive": true, "position": {"x": 1400.0, "y": float(GROUND)}},
	}
	m._aim = a
	m._set_aim_aid(m._players["me"])
	eq(a.enemies, PackedVector2Array([Vector2(1400, GROUND - 20)]), "only the alive enemy's body centre")
	near(a.wind_influence, 1.3, 1e-9, "Spark's orb: wind ×1.3")
	near(a.projectile_weight, 0.8, 1e-9, "weight 0.8")
	eq(a.pierce, 0.0, "no drill")
	_drag(a, 60.0, 70.0)
	eq(a.aid()["hits"], [], "an ally on the path: no Trúng")
	m._armed = "drill_bomb"
	m._set_aim_aid(m._players["me"])
	eq(a.pierce, 50.0, "the drill bomb drills 50 px")
	m.free()
	a.free()


func test_drill_flies_through_the_first_block() -> void:
	var m = _flat()
	for y in range(0, GROUND):
		for x in range(600, 620):
			m.solid[y * m.width + x] = TerrainMask.SOLID
	var origin := Vector2(200, 400)
	var v := AimAid.launch_velocity(0.0, 60.0)
	var plain := AimAid.fly(origin, v, 0.0, m, PackedVector2Array(), PackedFloat32Array())
	check(plain["end"].x >= 600.0 and plain["end"].x < 602.0, "stops on the wall")
	var drill := AimAid.fly(origin, v, 0.0, m, PackedVector2Array(), PackedFloat32Array(), 50.0)
	check(drill["end"].x > 620.0, "the drill goes through the 20 px wall")


func test_laser_hit_check() -> void:
	var a = _aim()
	a.line_mode = true
	var origin := Trajectory.shot_origin(FEET, a.terrain)
	a.enemies = PackedVector2Array([origin + Vector2(500, -30), origin + Vector2(900, 0), origin + Vector2(700, 60)])
	_drag(a, 0.0, 50.0) # level, to the right
	eq(a.aid()["hits"], [0, 1], "the beam crosses the enemies within 34 px of it")
	eq(a.aid()["marks"].size(), 0, "no landing marker for the beam")
	eq(AimAid.laser_hits(origin, origin + Vector2(1000, 0), PackedVector2Array([origin + Vector2(500, 34.5)])).size(), 0,
		"35 px off: missed")
	_drag(a, 0.0, 2.0)
	eq(a.aid()["hits"], [], "below MIN_POWER: nothing")
	a.free()


func test_super_high() -> void:
	check(AimAid.is_super_high(500.0, 90.0, 100.0), "apex 900 px over an origin at 500: above the screen")
	check(not AimAid.is_super_high(500.0, 90.0, 50.0), "apex 225 px: on screen")
	check(not AimAid.is_super_high(500.0, 20.0, 100.0), "a flat strong shot stays low")
	var a = _aim()
	_drag(a, 80.0, 95.0)
	check(a.aid()["marks"][0]["high"], "a steep strong lob: the ground arrow")
	_drag(a, 45.0, 50.0)
	check(not a.aid()["marks"][0]["high"], "a normal shot: none")
	a.free()


func test_top_arrows_follow_high_shells() -> void:
	var arrows := HighShellMarker.arrows(PackedVector2Array([Vector2(300, -120), Vector2(500, 40), Vector2(-50, -10)]), 1600.0)
	eq(arrows.size(), 2, "only the shells above the top")
	eq(arrows[0], {"x": 300.0, "height": 120.0}, "under the shell, its height")
	eq(arrows[1]["x"], HighShellMarker.EDGE, "kept inside the screen")
	eq(HighShellMarker.arrows(PackedVector2Array([Vector2(300, 10)]), 1600.0), [], "none on screen")
	# ShotPlayer: a shell flying up out of the screen and back
	for kind in ["", "flare", "bomb", "missile"]:
		var path := [
			{"position": {"x": 400.0, "y": 300.0}, "velocity": {"x": 0.0, "y": -800.0}, "time": 0.0},
			{"position": {"x": 400.0, "y": -100.0}, "velocity": {"x": 0.0, "y": 0.0}, "time": 1.0},
			{"position": {"x": 400.0, "y": 300.0}, "velocity": {"x": 0.0, "y": 800.0}, "time": 2.0}]
		var p := {"path": path}
		if kind != "":
			p["kind"] = kind
		var sp = ShotPlayer.new()
		var layer := Node2D.new()
		sp.layer = layer
		sp.play(ShotTimeline.new({"projectiles": [p], "duration": 2.5}))
		sp._process(0.1)
		eq(sp.high_shells().size(), 0, "%s: still on screen" % kind)
		sp._process(0.9)
		eq(sp.high_shells().size(), 0 if kind == "missile" else 1, "%s: above the top" % kind)
		sp._process(0.9)
		eq(sp.high_shells().size(), 0, "%s: back on screen" % kind)
		sp.stop()
		layer.free()
		sp.free()


## A HUD outside the tree (_ready by hand) with its skill, three items and the notice shown.
func _hud() -> Control:
	var h: Control = Hud.new()
	h._ready()
	h.set_actions({"name": "Mưa tên lửa"}, 100, true, "weapon", [{"id": "drill_bomb", "count": 1, "enabled": true},
		{"id": "medkit", "count": 2, "enabled": true}, {"id": "teleport", "count": 1, "enabled": true}])
	h.set_move_notice("Bị cầm chân")
	return h


## Where Godot puts an anchored control in `parent` (its anchors, offsets, grow directions and
## minimum size): the layout a frame would give it.
static func _anchored(c: Control, parent: Rect2) -> Rect2:
	var ps := parent.size
	var l := c.anchor_left * ps.x + c.offset_left
	var r := c.anchor_right * ps.x + c.offset_right
	var t := c.anchor_top * ps.y + c.offset_top
	var b := c.anchor_bottom * ps.y + c.offset_bottom
	var m := c.get_combined_minimum_size()
	var x := _grow(l, r, m.x, c.grow_horizontal)
	var y := _grow(t, b, m.y, c.grow_vertical)
	return Rect2(parent.position + Vector2(x.x, y.x), Vector2(x.y - x.x, y.y - y.x))


static func _grow(lo: float, hi: float, min_size: float, dir: int) -> Vector2:
	if hi - lo >= min_size:
		return Vector2(lo, hi)
	match dir:
		Control.GROW_DIRECTION_BEGIN:
			return Vector2(hi - min_size, hi)
		Control.GROW_DIRECTION_BOTH:
			var mid := (lo + hi) / 2.0
			return Vector2(mid - min_size / 2.0, mid + min_size / 2.0)
	return Vector2(lo, lo + min_size)


func test_move_buttons_on_the_screen_edges() -> void:
	var h := _hud()
	var left_col: VBoxContainer = h.get_node("MoveLeft")
	var left_button: Button = left_col.get_node("MoveLeftButton")
	var energy_panel: Control = left_col.get_node("Energy")
	eq(left_col.get_child(0), left_button, "◀ first in its column")
	eq(left_col.get_child(1), energy_panel, "the energy under it")
	for size in [Vector2(1600, 900), Vector2(1280, 720), Vector2(2000, 900)]:
		var screen := Rect2(Vector2.ZERO, size)
		var tag := "%dx%d" % [size.x, size.y]
		var bm := left_button.get_combined_minimum_size()
		var em := energy_panel.get_combined_minimum_size()
		# the column's width is its widest child's (outside the tree the VBox reports no minimum)
		var col := Rect2(_anchored(left_col, screen).position, Vector2(maxf(bm.x, em.x), 0))
		var left := Rect2(col.position + Vector2((col.size.x - bm.x) / 2.0, 0), bm) # VBox: shrink-centred
		var energy := Rect2(Vector2(col.position.x + (col.size.x - em.x) / 2.0, left.end.y + left_col.get_theme_constant("separation")), em)
		var right := _anchored(h.get_node("MoveRightButton"), screen)
		var notice := _anchored(h.get_node("MoveNotice"), screen)
		near(left.position.x, Hud.MARGIN + (col.size.x - bm.x) / 2.0, 0.5, tag + " ◀ on the left edge")
		check(col.position.x == Hud.MARGIN, tag + " its column at the margin")
		near(right.end.x, size.x - Hud.MARGIN, 0.5, tag + " ▶ on the right edge")
		near(left.get_center().y, size.y / 2.0, 0.5, tag + " ◀ vertically centred")
		near(right.get_center().y, size.y / 2.0, 0.5, tag + " ▶ vertically centred")
		near(left.size.x, Hud.MOVE_SIZE, 0.5, tag + " ◀ size")
		near(right.size.x, Hud.MOVE_SIZE, 0.5, tag + " ▶ size")
		check(energy.position.y - left.end.y <= 12.0, tag + " energy right under ◀")
		near(energy.get_center().x, left.get_center().x, 0.5, tag + " energy centred under ◀")
		check(notice.end.y <= left.position.y and left.position.y - notice.end.y <= 12.0, tag + " notice right over ◀")
		near(notice.position.x, Hud.MARGIN, 0.5, tag + " notice from the left margin")
		var others := {}
		for part in ["TopLeft", "TopCentre", "BottomCentre", "Skill", "Portrait"]:
			others[part] = _anchored(h.get_node(part), screen)
		var parts := {"left": left, "right": right, "energy": energy, "notice": notice}
		for part in parts:
			var r: Rect2 = parts[part]
			check(screen.encloses(r), "%s %s on screen (%s)" % [tag, part, r])
			for o in others:
				check(not r.intersects(others[o]), "%s %s clear of %s (%s vs %s)" % [tag, part, o, r, others[o]])
	h.free()


func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	return e


func _motion(at: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = at
	return e


## A drag is started by a press the GUI left (_unhandled_input); its moves and release are taken
## first (_input) wherever the pointer is, a move button under it included.
func test_drag_moves_and_release_are_taken_first() -> void:
	var a = AimInput.new()
	a.terrain = _flat()
	a.shooter_pos = Vector2(600, GROUND)
	a.enabled = true
	var fired := []
	a.fire.connect(func(angle: float, power: float) -> void: fired.append([angle, power]))
	check(a.has_method("_input") and a.has_method("_unhandled_input"), "both input hooks")
	var over := Vector2(1600 - Hud.MARGIN - Hud.MOVE_SIZE / 2.0, 450) # the ▶ button's centre
	check(not a._drag_event(_motion(over)), "no drag: a move is left to the GUI")
	check(a._press_starts_drag(_button(Vector2(1300, 300), true)), "a press on the field starts a drag")
	check(not a._press_starts_drag(_button(Vector2(1300, 300), true)), "a second press does not restart it")
	check(a._drag_event(_motion(over)), "a move over the button is taken by the drag")
	check(a._power > 50.0, "and aims (power %f)" % a._power)
	check(a._drag_event(_button(over, false)), "the release on the button is taken too")
	check(not a.is_dragging(), "the drag ended")
	eq(fired.size(), 1, "and fired")
	check(not a._drag_event(_button(over, false)), "a release with no drag is left to the GUI (the button's own)")
	a.enabled = false
	check(not a._press_starts_drag(_button(Vector2(1300, 300), true)), "aiming off: no drag")
	a.free()
