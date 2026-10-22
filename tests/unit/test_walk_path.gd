extends "res://tests/test_case.gd"
## match/move/walk_path.gd: how a walk is drawn (along the surface, smooth on pixel slopes, a
## ledge drop as a fall, a correction eased), and the WalkTo parity on a terrain-layer map.

const WalkPath := preload("res://match/move/walk_path.gd")
const MoveSync := preload("res://match/move/move_sync.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const GRASSLAND := "res://tests/fixtures/walk_grassland_valley.json"
const DT := 1.0 / 60.0


## A mask whose surface in column x is top.call(x).
func _mask(w: int, h: int, top: Callable):
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid.resize(w * h)
	m.solid.fill(0)
	for x in w:
		for y in range(int(top.call(x)), h):
			m.solid[y * w + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	return m


## A pixel slope: up 1 px every other column (the stairs WalkTo walks), then flat.
func _slope():
	return _mask(600, 400, func(x: int) -> int: return 300 - mini(x, 400) / 2)


## A ledge: ground at 200 up to x = 299, at 320 from x = 300 (a 120 px drop).
func _ledge():
	return _mask(600, 400, func(x: int) -> int: return 200 if x < 300 else 320)


func _walker(terrain, p: Vector2):
	var w := WalkPath.new()
	w.terrain = terrain
	w.reset(p)
	return w


## Second differences (per-frame jerk) of the drawn x and y over frames a..b.
func _jerk(frames: Array, a: int, b: int) -> Vector2:
	var m := Vector2.ZERO
	for i in range(maxi(a, 2), mini(b, frames.size())):
		var j: Vector2 = frames[i] - 2.0 * frames[i - 1] + frames[i - 2]
		m = Vector2(maxf(m.x, absf(j.x)), maxf(m.y, absf(j.y)))
	return m


func test_grassland_valley_walk_matches_server() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(GRASSLAND))
	var m := TerrainMask.new()
	check(m.load_snapshot(d["terrain"]), "loads the server's snapshot")
	var bad := 0
	for w in d["walks"]:
		if m.walk_to(float(w[0]), float(w[1]), float(w[2])) != Vector2(float(w[3]), float(w[4])):
			bad += 1
	eq(bad, 0, "every WalkTo of the fixture (%d) as the server" % d["walks"].size())


func test_held_walk_up_a_pixel_slope_is_smooth() -> void:
	# The prediction (MoveSync, 90 px/s in whole pixels: 1, 2, 1, 2 px a frame, y in 1 px stairs)
	# drawn as it was (raw) and through WalkPath.
	var t = _slope()
	var s := MoveSync.new()
	s.terrain = t
	s.reset(Vector2(20, 290), 100)
	var w = _walker(t, s.position)
	var raw: Array = []
	var drawn: Array = []
	for f in 120:
		s.hold(1, DT)
		w.follow(s.position)
		raw.append(s.position)
		drawn.append(w.step(DT))
	var rj := _jerk(raw, 30, 120)
	var dj := _jerk(drawn, 30, 120)
	check(rj.x >= 1.0 and rj.y >= 1.0, "the raw prediction stutters (%s)" % rj)
	check(dj.x <= 0.2, "drawn x: steady speed (jerk %.3f px/frame²)" % dj.x)
	check(dj.y <= 0.2, "drawn y: a straight slope, not 1 px stairs (jerk %.3f px/frame²)" % dj.y)
	var v: Vector2 = drawn[119] - drawn[118]
	near(v.length() / DT, 90.0 * sqrt(1.25), 4.0, "90 px/s along x, up the 1:2 slope")
	for f in range(30, 120):
		var p: Vector2 = drawn[f]
		var col := floori(p.x)
		var ground := lerpf(300.0 - col / 2, 300.0 - (col + 1) / 2, p.x - col)
		check(absf(p.y - ground) <= 0.75, "on the surface at frame %d (%.2f vs %.2f)" % [f, p.y, ground])
		if absf(p.y - ground) > 0.75:
			break


func test_drawn_ends_exactly_on_the_pixel() -> void:
	var t = _slope()
	var s := MoveSync.new()
	s.terrain = t
	s.reset(Vector2(20, 290), 100)
	var w = _walker(t, s.position)
	for f in 40:
		s.hold(1, DT)
		w.follow(s.position)
		w.step(DT)
	s.release()
	for f in 90:
		w.step(DT)
	eq(w.drawn, s.position, "stands on the server's pixel")
	check(not w.active(), "the walk is over")


func test_walk_off_a_ledge_falls_with_gravity() -> void:
	var t = _ledge()
	var w = _walker(t, Vector2(280, 200))
	w.walk(t.walk_to(280, 200, 330), 1.4)
	var frames: Array = []
	for f in 150:
		frames.append(w.step(DT))
	eq(w.drawn, Vector2(330, 320), "ends where WalkTo does")
	var max_dy := 0.0
	var fall_frames := 0
	for i in range(1, frames.size()):
		var a: Vector2 = frames[i - 1]
		var b: Vector2 = frames[i]
		max_dy = maxf(max_dy, b.y - a.y)
		check(b.y <= 320.0 + 1e-3, "never under the ground")
		if b.y > 200.0 and b.y < 320.0:
			fall_frames += 1
			check(b.x >= 299.0 and b.x <= 300.0, "falls straight down the edge (x %.2f)" % b.x)
	var fall := sqrt(2.0 * 120.0 / GameData.gravity())
	near(fall_frames * DT, fall, 2.5 * DT, "falls 120 px in sqrt(2·120 / gravity) = %.2f s" % fall)
	check(max_dy <= GameData.gravity() * fall * DT + 0.5, "accelerates: no jump (largest step %.1f px)" % max_dy)


func test_local_walk_off_a_ledge_falls_then_catches_up() -> void:
	var t = _ledge()
	var s := MoveSync.new()
	s.terrain = t
	s.reset(Vector2(270, 200), 100)
	var w = _walker(t, s.position)
	var frames: Array = []
	for f in 100:
		s.hold(1, DT)
		w.follow(s.position)
		frames.append(w.step(DT))
	s.release()
	for f in 120:
		frames.append(w.step(DT))
	var max_step := 0.0
	for i in range(1, frames.size()):
		max_step = maxf(max_step, (frames[i] - frames[i - 1]).length())
	check(max_step < 8.0, "no teleport down the ledge (largest step %.1f px)" % max_step)
	eq(w.drawn, s.position, "then walks on to the prediction")


func test_remote_walk_follows_the_surface_in_time() -> void:
	# A bot's 200 px walk over a hill (one PlayerMoved): not a straight line through it.
	var t = _mask(800, 400, func(x: int) -> int: return 300 - int(40.0 * sin(PI * clampf((x - 100) / 200.0, 0.0, 1.0))))
	var w = _walker(t, Vector2(100, 300))
	var to: Vector2 = t.walk_to(100, 300, 300)
	w.walk(to, 1.4)
	var t_end := -1.0
	var worst := 0.0
	for f in 120:
		var p: Vector2 = w.step(DT)
		var col := clampi(roundi(p.x), 0, 799)
		worst = maxf(worst, absf(p.y - t.get_landing_y(col, 0)))
		if t_end < 0.0 and p.distance_to(to) < 0.5:
			t_end = (f + 1) * DT
	check(worst <= 1.5, "on the hill all the way (off by %.2f px at most)" % worst)
	check(t_end > 0.0 and t_end <= 1.4, "there within the 1.4 s it was given (%.2f s)" % t_end)


func test_correction_eases_instead_of_jumping() -> void:
	# A target no walk reaches (a wall in the way: a teleport, a resync): eased over a few frames.
	var t = _mask(400, 400, func(x: int) -> int: return 300 if x < 200 else 100)
	var w = _walker(t, Vector2(150, 300))
	w.follow(Vector2(250, 100))
	eq(w.drawn, Vector2(150, 300), "still drawn where it was")
	var prev: Vector2 = w.drawn
	var frames := 0
	var close := -1
	while w.active() and frames < 120:
		var p: Vector2 = w.step(DT)
		check((p - prev).length() < 0.3 * 224.0, "no jump in one frame (%.1f px)" % (p - prev).length())
		prev = p
		frames += 1
		if close < 0 and p.distance_to(Vector2(250, 100)) < 0.5:
			close = frames
	eq(w.drawn, Vector2(250, 100), "ends on the corrected pixel")
	check(close > 3 and close <= 22, "eased over a few frames, there within 0.5 px in %d" % close)


func test_tween_takes_over_and_walk_starts_from_it() -> void:
	var t = _slope()
	var w = _walker(t, Vector2(20, 290))
	w.follow(Vector2(30, 285))
	w.step(DT)
	w.reset(Vector2(100, 250)) # a shot's knockback tween took the body there
	check(not w.active(), "a tween owns the body: the walk does not draw")
	eq(w.target(), Vector2(100, 250), "and the next walk starts from its end")


## The server's TestWalkToStopsAtBottomlessHole: 96 x 64 px, ground 16 px thick on columns 0-31
## and 64-95, a hole down to the bottom of the map on columns 32-63.
func _hole():
	return _mask(96, 64, func(x: int) -> int: return 48 if x < 32 or x >= 64 else 64)


func test_walk_into_a_bottomless_hole_stops_there() -> void:
	var t = _hole()
	eq(t.walk_to(8, 48, 88), Vector2(32, 64), "the walk ends in the hole's first column, y = the map height (server WalkTo)")
	eq(t.walk_to(32, 64, 60), Vector2(32, 64), "nothing walks on along the bottom")
	eq(t.walk_to(32, 64, 10), Vector2(32, 64), "nor back out")


func test_held_walk_into_the_hole_stops_at_its_edge() -> void:
	var t = _hole()
	var s := MoveSync.new()
	s.terrain = t
	s.reset(Vector2(8, 48), 100)
	for f in 90:
		s.hold(1, DT)
	eq(s.position, Vector2(32, 64), "the prediction stops where the server does")
	s.release()
	var cmd := s.update(10.0, true)
	eq(float(cmd.get("targetX", -1)), 32.0, "one Move to the hole")
	s.on_server_moved(Vector2(32, 64), s.energy, int(cmd.get("seq", 0)))
	for f in 30:
		s.hold(1, DT)
	eq(s.position, Vector2(32, 64), "the server's position: no walk along the bottom after it")


func test_walk_into_a_bottomless_hole_falls_past_the_bottom() -> void:
	var t = _hole()
	var w = _walker(t, Vector2(20, 48))
	w.walk(t.walk_to(20, 48, 88), 1.0)
	check(w.falls_out(), "the walk ends below the map")
	check(w.falling_out(), "and is drawn falling out")
	var frames: Array = []
	for f in 240:
		frames.append(w.step(DT))
		if not w.active():
			break
	check(not w.active() and not w.falling_out(), "the fall ends")
	eq(w.drawn, Vector2(32, 64 + WalkPath.OUT_DROP), "OUT_DROP px below the bottom: out of sight")
	var below := 0
	for i in range(1, frames.size()):
		var a: Vector2 = frames[i - 1]
		var b: Vector2 = frames[i]
		check(b.y >= a.y - 1e-3, "never rises")
		if a.y > 48.0:
			check(b.x >= 31.0 and b.x <= 32.0, "straight down the hole's edge (x %.2f)" % b.x)
			check(b.y - a.y >= 0.0, "on down")
		if b.y > 64.0:
			below += 1
	check(below > 3, "keeps falling past the bottom (%d frames below it)" % below)
	var fall := sqrt(2.0 * (16.0 + WalkPath.OUT_DROP) / GameData.gravity())
	var falling := 0
	for p in frames:
		if p.y > 48.0 and p.y < 64.0 + WalkPath.OUT_DROP:
			falling += 1
	near(falling * DT, fall, 2.5 * DT, "falls with gravity, %.2f s" % fall)


func test_local_walk_into_the_hole_falls_out() -> void:
	var t = _hole()
	var s := MoveSync.new()
	s.terrain = t
	s.reset(Vector2(8, 48), 100)
	var w = _walker(t, s.position)
	for f in 240:
		s.hold(1, DT)
		w.follow(s.position)
		w.step(DT)
	eq(w.drawn, Vector2(32, 64 + WalkPath.OUT_DROP), "the drawn body drops out of sight too")
	check(not w.falling_out(), "and the fall is over")
