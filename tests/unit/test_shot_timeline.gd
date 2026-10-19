extends "res://tests/test_case.gd"

const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")


func _step(t: float, x: float, y: float, vx: float, vy: float) -> Dictionary:
	return {"time": t, "position": {"x": x, "y": y}, "velocity": {"x": vx, "y": vy}}


func _timeline(path: Array):
	return ShotTimeline.new({
		"shooterId": "p1",
		"duration": 2.0,
		"projectiles": [{"projectileId": "a", "path": path}],
		"events": [
			{"t": 1.0, "type": "explode"},
			{"t": 1.0, "type": "damage"},
			{"t": 1.5, "type": "fall", "duration": 0.5},
		],
	})


func test_sample_interpolates_straight_flight() -> void:
	var tl = _timeline([_step(0, 0, 0, 10, 0), _step(1, 10, 0, 10, 0)])
	var p: Vector2 = tl.sample(0, 0.5)
	near(p.x, 5.0, 1e-6, "x at t=0.5")
	near(p.y, 0.0, 1e-6, "y at t=0.5")


func test_sample_follows_velocity_curve() -> void:
	# Up then down between two samples at the same point: Hermite puts the apex at -2.5.
	var tl = _timeline([_step(0, 0, 0, 0, -10), _step(1, 0, 0, 0, 10)])
	near(tl.sample(0, 0.5).y, -2.5, 1e-6, "apex")


func test_start_velocity() -> void:
	var tl = _timeline([_step(0, 0, 0, 30, -40), _step(1, 10, 0, 10, 0)])
	eq(tl.start_velocity(0), Vector2(30, -40), "the first step's velocity")
	eq(_timeline([]).start_velocity(0), Vector2.ZERO, "empty path")


func test_sample_clamps_outside_path() -> void:
	var tl = _timeline([_step(0, 0, 0, 10, 0), _step(1, 10, 0, 10, 0)])
	eq(tl.sample(0, -1.0), Vector2(0, 0), "before start")
	eq(tl.sample(0, 5.0), Vector2(10, 0), "after end")
	near(tl.projectile_end(0), 1.0, 1e-9, "projectile end")


func test_pop_due_returns_each_event_once_in_order() -> void:
	var tl = _timeline([_step(0, 0, 0, 10, 0), _step(1, 10, 0, 10, 0)])
	eq(tl.pop_due(0.5).size(), 0, "nothing before 1.0")
	var due: Array = tl.pop_due(1.0)
	eq(due.size(), 2, "two events at 1.0")
	eq(due[0]["type"], "explode", "explode first")
	eq(due[1]["type"], "damage", "damage second")
	eq(tl.pop_due(2.0).size(), 1, "fall at 1.5")
	eq(tl.pop_due(9.0).size(), 0, "nothing left")
	near(tl.duration, 2.0, 1e-9, "duration")


# ShotPlayer driven by hand (outside the tree): _process(delta) is its only clock.
func _player(payload: Dictionary) -> Array:
	var player = ShotPlayer.new()
	player.layer = Node2D.new()
	var seen := {"events": [], "finished": 0}
	player.event_due.connect(func(e: Dictionary) -> void: seen["events"].append(e["type"]))
	player.finished.connect(func() -> void: seen["finished"] += 1)
	player.play(ShotTimeline.new(payload))
	return [player, seen]


func _free(player) -> void:
	player.layer.free()
	player.free()


func test_heal_shot_without_projectiles_ends_on_first_frame() -> void:
	# healing_bloom: no projectiles, events at t=0, duration 0; TurnStarted follows at once.
	var r := _player({"shooterId": "p1", "actionMode": "skill", "duration": 0.0, "projectiles": [],
		"events": [{"t": 0.0, "type": "heal", "playerId": "p1", "amount": 30, "hp": 80},
			{"t": 0.0, "type": "status", "playerId": "p1", "effectId": "heal", "turns": 1}]})
	var player = r[0]
	var seen: Dictionary = r[1]
	check(player.is_playing(), "playing until the next frame")
	player._process(1.0 / 60.0)
	eq(seen["events"], ["heal", "status"], "events emitted")
	eq(seen["finished"], 1, "finished once")
	check(not player.is_playing(), "stopped")
	_free(player)


func test_multi_projectile_shot_moves_each_view_on_its_path() -> void:
	var proj := func(id: String, x: float, end: float) -> Dictionary:
		return {"projectileId": id, "path": [_step(0, 0, 0, x, 0), _step(end, x * end, 0, x, 0)]}
	var r := _player({"shooterId": "p1", "actionMode": "skill", "duration": 1.0,
		"projectiles": [proj.call("a", 10.0, 0.5), proj.call("b", 20.0, 1.0), proj.call("c", 30.0, 1.0)],
		"events": [{"t": 0.5, "type": "explode"}, {"t": 1.0, "type": "explode"}, {"t": 1.0, "type": "explode"}]})
	var player = r[0]
	var seen: Dictionary = r[1]
	eq(player.layer.get_child_count(), 3, "three projectile views")
	eq(player._views[1].heading, Vector2(20, 0), "a view faces its path's start velocity")
	player._process(0.25)
	eq(player._views[1].position, Vector2(5, 0), "second view on its own path")
	eq(player._views[2].position, Vector2(7.5, 0), "third view on its own path")
	player._process(0.3)
	check(player._views[0] == null, "first view gone after its flight")
	eq(seen["events"].size(), 1, "first explode")
	player._process(0.5)
	eq(seen["events"].size(), 3, "all explodes")
	eq(seen["finished"], 1, "finished")
	_free(player)
