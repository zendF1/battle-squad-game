extends "res://tests/test_case.gd"
## A remote player's visible aim (server PlayerAiming): the sweep curve (match/aim/aim_sweep.gd),
## PlayerView.aim_sweep() (the gun stepping between its snapped directions) and match_screen's
## handling of the event.

const AimSweep := preload("res://match/aim/aim_sweep.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const MatchScreen := preload("res://match/match_screen.gd")
const Art := preload("res://ui/art.gd")
const CodeDrawLook := preload("res://tests/fixtures/code_draw_look.gd")

const DT := 1.0 / 60.0


## The elevations of a sweep sampled every DT over duration.
func _samples(duration: float, to: float, wobble: float, lo: float = -90.0, hi: float = 90.0) -> Array:
	var out := []
	var t := 0.0
	while t <= duration + 1e-9:
		out.append(AimSweep.elevation(t, duration, 0.0, to, wobble, lo, hi))
		t += DT
	return out


func test_sweep_time_settles_before_the_shot() -> void:
	near(AimSweep.sweep_time(1.2), 1.0, 1e-6, "1.2 s aim: on the aim 0.2 s before")
	near(AimSweep.sweep_time(2.4), 2.2, 1e-6, "2.4 s aim")
	near(AimSweep.sweep_time(0.3), 0.18, 1e-6, "a short aim still sweeps over most of it")
	eq(AimSweep.sweep_time(0.0), 0.0, "no time: no sweep")
	eq(AimSweep.elevation(0.0, 0.0, 0.0, 40.0), 40.0, "no time: at the aim at once")


func test_sweep_swings_past_then_settles() -> void:
	for wobble in [0.0, 0.5, 1.0]:
		var s := _samples(1.8, 40.0, wobble)
		eq(s[0], 0.0, "starts level (wobble %s)" % wobble)
		eq(s[3], 0.0, "holds level while the gun comes up")
		var peak: float = s.max()
		check(peak > 40.0 + AimSweep.OVERSHOOT_MIN * 0.6 - 1e-3 and peak <= 40.0 + AimSweep.OVERSHOOT_MAX + 1e-3,
			"a small overshoot (peak %f, wobble %s)" % [peak, wobble])
		var peak_at: int = s.find(peak)
		check(peak_at * DT < 1.6 * 0.7, "the swing is ease-out: past the aim early (%f s)" % (peak_at * DT))
		var low_after: float = s.slice(peak_at).min()
		check(low_after < 40.0, "a correction back a hair short (%f)" % low_after)
		near(AimSweep.elevation(1.6, 1.8, 0.0, 40.0, wobble), 40.0, 1e-6, "on the aim 0.2 s before the shot")
		near(s[s.size() - 1], 40.0, 1e-6, "rests on the aim")
		for i in range(1, s.size()):
			check(absf(s[i] - s[i - 1]) < 6.0, "no jump at %d (%f → %f)" % [i, s[i - 1], s[i]])


func test_sweep_down_and_level_aims() -> void:
	var s := _samples(1.5, -20.0, 0.5)
	check(s.min() < -20.0, "a downward aim overshoots downwards")
	near(s[s.size() - 1], -20.0, 1e-6, "settles on it")
	var flat := _samples(1.5, 0.0, 0.5)
	check(flat.max() > 0.5, "a level aim still moves a little")
	near(flat[flat.size() - 1], 0.0, 1e-6, "and settles level")


func test_sweep_stays_within_reach() -> void:
	var s := _samples(2.0, 85.0, 1.0, -30.0, 60.0)
	check(s.max() <= 60.0 + 1e-6 and s.min() >= -30.0 - 1e-6, "within the pose's reach")
	near(s[s.size() - 1], 60.0, 1e-6, "an aim past the reach rests on its edge")
	var edge := _samples(2.0, 60.0, 1.0, -30.0, 60.0)
	check(edge.slice(int(0.5 / DT)).min() < 59.0, "at the edge it comes from the short side")
	near(edge[edge.size() - 1], 60.0, 1e-6, "then pushes onto it")


func test_angle_at_mirrors_for_the_left() -> void:
	near(AimSweep.angle_at(0.0, 1.5, 50.0, 1), 0.0, 1e-6, "right: level is 0")
	near(AimSweep.angle_at(1.5, 1.5, 50.0, 1), 50.0, 1e-6, "right: ends on the angle")
	near(AimSweep.angle_at(0.0, 1.5, 130.0, -1), 180.0, 1e-6, "left: level is 180")
	near(AimSweep.angle_at(1.5, 1.5, 130.0, -1), 130.0, 1e-6, "left: ends on the angle")
	near(AimSweep.angle_at(0.7, 1.5, 130.0, -1), 180.0 - AimSweep.angle_at(0.7, 1.5, 50.0, 1), 1e-6, "the same swing mirrored")


func _view(character: String, x: float = 100.0) -> Node2D:
	var holder := Node2D.new()
	var v: Node2D = PlayerView.new()
	holder.add_child(v)
	v.setup({"playerId": "bot", "teamId": 2, "characterId": character, "hp": 100, "maxHp": 100,
		"isAlive": true, "position": {"x": x, "y": 300.0}}, false, 1)
	v.get_child(1)._ready() # the character, not in the tree
	return v


func _drive(v: Node2D, sec: float) -> void:
	var t := 0.0
	while t < sec - 1e-9:
		v._process(DT)
		v.get_child(1)._process(DT)
		t += DT


## The code gun draw (a look without a drawn ready pose: tests/fixtures/code_draw_look.gd): faces
## the aim side, draws, swings onto the aim and holds it until the shot.
func test_view_sweep_draws_and_lands_on_the_aim() -> void:
	var restore: Callable = CodeDrawLook.install("spark")
	var v := _view("spark")
	var c: Node2D = v.get_child(1)
	v.face(1.0)
	v.aim_sweep(140.0, 1.5)
	eq(v.facing(), -1, "faces the aim side")
	check(v.is_sweeping(), "sweeping")
	_drive(v, 0.3)
	eq(v.gun_state(), "aiming", "the gun is out")
	_drive(v, 1.1)
	var gun: Node2D = c.get_node("Flip/Gun")
	var anchor: Dictionary = Art.gun_anchor("spark", "idle", 0)
	near(rad_to_deg(gun.rotation), float(anchor["angle"]) - 45.0, 0.01, "on the aim's direction (140: 45 above level, to the left)")
	_drive(v, 1.0)
	eq(v.gun_state(), "aiming", "held until the shot")
	near(v.shoot(), 0.0, 1e-9, "the shot leaves at once: the gun is out")
	check(not v.is_sweeping(), "the shot ends the sweep")
	v.get_parent().free()
	restore.call()


## Rookie's ready pose: the sweep steps the gun through its snapped directions (never in between)
## and ends straight up for an 85° aim (the scene's aim_up no longer limits it).
func test_view_sweep_rookie_ready_pose_steps_to_up() -> void:
	var v := _view("rookie")
	var c: Node2D = v.get_child(1)
	var gun: Node2D = c.get_node("Flip/Gun")
	v.aim_sweep(85.0, 1.2)
	eq(c.animation(), "draw", "the ready pose at once")
	eq(v.gun_state(), "aiming", "drawn at once")
	var seat := float(Art.gun_anchor("rookie", "draw", 0)["angle"])
	var seen := {}
	var t := 0.0
	while t < 1.2 - 1e-9:
		var up := seat - rad_to_deg(gun.rotation)
		var snapped := false
		for e in [-45.0, 0.0, 45.0, 90.0]:
			if absf(up - e) < 0.01:
				snapped = true
				seen[e] = true
		check(snapped, "a snapped direction at %f s (%f)" % [t, up])
		_drive(v, DT)
		t += DT
	check(seen.has(0.0) and seen.has(45.0) and seen.has(90.0), "steps level → 45 → up (%s)" % [seen.keys()])
	near(rad_to_deg(gun.rotation), seat - 90.0, 0.01, "rests straight up")
	v.get_parent().free()


## Below level on the left: the sweep ends on 225 (-45 to the left), no lower.
func test_view_sweep_down_left() -> void:
	var restore: Callable = CodeDrawLook.install("spark")
	var v := _view("spark")
	var c: Node2D = v.get_child(1)
	v.aim_sweep(240.0, 1.5)
	eq(v.facing(), -1, "faces left")
	_drive(v, 1.5)
	var anchor: Dictionary = Art.gun_anchor("spark", "idle", 0)
	near(rad_to_deg(c.get_node("Flip/Gun").rotation), float(anchor["angle"]) + 45.0, 0.01, "-45 to the left")
	v.get_parent().free()
	restore.call()


func test_view_sweep_ends_on_holster_or_death() -> void:
	var restore: Callable = CodeDrawLook.install("spark")
	var v := _view("spark")
	v.aim_sweep(60.0, 1.5)
	_drive(v, 0.5)
	v.clear_aim()
	check(not v.is_sweeping(), "a turn change ends it")
	_drive(v, 0.5)
	check(v.get_child(1).is_resting(), "and the gun goes back to the idle low carry")
	v.aim_sweep(60.0, 1.5)
	_drive(v, 0.3)
	v.set_dead()
	check(not v.is_sweeping(), "death ends it")
	eq(v.gun_state(), "holstered", "no gun on the body")
	v.aim_sweep(60.0, 1.5)
	check(not v.is_sweeping(), "the dead do not aim")
	v.get_parent().free()
	restore.call()


## match_screen without its scene: just the state PlayerAiming reads.
func _screen(view: Node2D) -> Node2D:
	var m: Node2D = MatchScreen.new()
	m._me = "me"
	m._current = "bot"
	m._players = {"me": {"isAlive": true}, "bot": {"isAlive": true}}
	m._views = {"bot": view}
	return m


func test_match_player_aiming() -> void:
	var v := _view("spark")
	var m := _screen(v)
	m._apply("PlayerAiming", {"playerId": "bot", "angle": 50.0, "durationMs": 1500})
	check(v.is_sweeping(), "the current bot aims")
	v.clear_aim()
	m._apply("PlayerAiming", {"playerId": "bot", "angle": 50.0, "durationMs": 1500, "receivedAt": Time.get_ticks_usec() - 1_400_000})
	check(not v.is_sweeping(), "held back by a replay until almost over: not shown")
	m._current = "me"
	m._apply("PlayerAiming", {"playerId": "bot", "angle": 50.0, "durationMs": 1500})
	check(not v.is_sweeping(), "not its turn")
	m._current = "bot"
	m._turn_resolved = true
	m._apply("PlayerAiming", {"playerId": "bot", "angle": 50.0, "durationMs": 1500})
	check(not v.is_sweeping(), "its shot already resolved")
	m._turn_resolved = false
	m._players["bot"]["isAlive"] = false
	m._apply("PlayerAiming", {"playerId": "bot", "angle": 50.0, "durationMs": 1500})
	check(not v.is_sweeping(), "dead")
	m._players["bot"]["isAlive"] = true
	m._apply("PlayerAiming", {"playerId": "ghost", "angle": 50.0, "durationMs": 1500})
	m._apply("PlayerAiming", "junk")
	check(not v.is_sweeping(), "unknown player or bad data: ignored")
	m._current = "me"
	m._views["me"] = _view("rookie")
	m._apply("PlayerAiming", {"playerId": "me", "angle": 50.0, "durationMs": 1500})
	check(not m._views["me"].is_sweeping(), "mine is aimed by my own drag")
	m._views["me"].get_parent().free()
	v.get_parent().free()
	m.free()
