extends "res://tests/test_case.gd"

const ShotTimeline := preload("res://match/shot/shot_timeline.gd")


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
