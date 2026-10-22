extends "res://tests/test_case.gd"

const Trajectory := preload("res://match/aim/trajectory_predictor.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const FIXTURE := "res://tests/fixtures/terrain_parity.json"


func _flat(w: int, h: int, ground_y: int):
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


func test_first_step_matches_server_integration() -> void:
	# SimulateProjectile: v = power*9.6 = 96 up; v.y += 445*0.02 → -87.1; y += -87.1*0.02 = -1.742
	var pts := Trajectory.predict(Vector2.ZERO, 90.0, 10.0, 0, 0.0, null, 10)
	eq(pts[0], Vector2.ZERO, "starts at origin")
	near(pts[1].y, -1.742, 1e-6, "first step y")
	near(pts[1].x, 0.0, 1e-6, "first step x")


func test_wind_pushes_projectile() -> void:
	var calm := Trajectory.predict(Vector2.ZERO, 45.0, 50.0, 0, 0.0, null, 60)
	var windy := Trajectory.predict(Vector2.ZERO, 45.0, 50.0, 1, 2.0, null, 60)
	check(windy[-1].x > calm[-1].x, "right wind moves the end point right")


func test_stops_at_terrain() -> void:
	var m = _flat(400, 100, 60)
	var pts := Trajectory.predict(Vector2(100, 59), 45.0, 20.0, 0, 0.0, m, 500)
	check(m.is_solid(pts[-1].x, pts[-1].y), "last point is inside the ground")
	check(pts.size() < 500, "stopped before the point limit")


func test_thin_wall_inside_one_step_stops_preview() -> void:
	# 600 px/s moves 12 px per step: 100 → 112 (gravity adds 0.18 px down, so the segment is
	# 12.001 px → 4 samples). The server samples x = 103, 106, 109, 112 and hits the 2 px wall
	# at x = 108..109 on the 109 sample; checking only the step end (112) would fly through it.
	var m = _flat(400, 100, 90)
	for y in range(0, 90):
		m.solid[y * m.width + 108] = TerrainMask.SOLID
		m.solid[y * m.width + 109] = TerrainMask.SOLID
	var pts := Trajectory.simulate(100.0, 50.0, 600.0, 0.0, 0.0, m, 50)
	near(pts[-1].x, 109.0, 1e-3, "stops at the wall")
	eq(pts.size(), 2, "hit during the first step")


func test_matches_server_shots() -> void:
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var m := TerrainMask.new()
	m.load_snapshot(f["after"])
	var hits := 0
	var misses := 0
	for s in f["shots"]:
		if not s["hit"]:
			# No terrain hit: the flight ends by leaving the map or timing out, so no point
			# inside the map bounds after the origin may be solid (hits end on a solid point).
			misses += 1
			var flight := Trajectory.simulate(float(s["x"]), float(s["y"]), float(s["vx"]), float(s["vy"]),
				float(s["windForce"]), m, 100000)
			for i in range(1, flight.size()): # the origin stands on the ground, so skip it
				var p := flight[i]
				if p.y < m.height and p.x >= 0 and p.x < m.width:
					check(not m.is_solid(p.x, p.y), "miss from %s,%s crossed terrain at %s" % [s["x"], s["y"], p])
			continue
		hits += 1
		var pts := Trajectory.simulate(float(s["x"]), float(s["y"]), float(s["vx"]), float(s["vy"]),
			float(s["windForce"]), m, 100000)
		near(pts[-1].x, float(s["hitX"]), 1e-3, "hit x of shot from %s,%s" % [s["x"], s["y"]])
		near(pts[-1].y, float(s["hitY"]), 1e-3, "hit y of shot from %s,%s" % [s["x"], s["y"]])
	check(hits >= 30, "fixture has enough hitting shots (%d)" % hits)
	check(misses >= 10, "fixture has enough missing shots (%d)" % misses)


## shotOriginAt (shooting.go): every fixture shot's origin from its shooter's feet, including the
## lowered ones (a low ceiling, feet inside the ground).
func test_shot_origin_matches_server() -> void:
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var m := TerrainMask.new()
	m.load_snapshot(f["after"])
	var lowered := 0
	for s in f["shots"]:
		var feet := Vector2(float(s["feetX"]), float(s["feetY"]))
		var o := Trajectory.shot_origin(feet, m)
		near(o.x, float(s["x"]), 1e-6, "origin x from feet %s" % feet)
		near(o.y, float(s["y"]), 1e-6, "origin y from feet %s" % feet)
		if float(s["y"]) != feet.y - GameData.shot_origin_lift():
			lowered += 1
	check(lowered >= 1, "fixture has lowered origins (%d)" % lowered)
	var ceiling = _flat(50, 100, 90)
	for x in 50:
		ceiling.solid[70 * 50 + x] = TerrainMask.SOLID
	eq(Trajectory.shot_origin(Vector2(10, 90), ceiling), Vector2(10, 71), "under a ceiling 20 px up: the pixel below it")
	eq(Trajectory.shot_origin(Vector2(10, 95), ceiling), Vector2(10, 95), "feet inside the ground: the feet")
	eq(Trajectory.shot_origin(Vector2(-5, 10), ceiling), Vector2(-5, -10), "off the map is free")


func test_shot_origin_is_the_body_centre() -> void:
	eq(Trajectory.shot_origin(Vector2(100, 200)), Vector2(100, 180), "feet - (0, 20)")
	var text := FileAccess.get_file_as_string("res://match/aim/aim_input.gd")
	check(text.contains("var origin: Vector2 = Trajectory.shot_origin(shooter_pos, terrain)"), "the aid starts at the body centre")
	check(text.contains("AimAid.fly(origin,") and text.contains("Trajectory.simulate(origin.x, origin.y"), "both flights from it")
