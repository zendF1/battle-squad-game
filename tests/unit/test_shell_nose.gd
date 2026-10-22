extends "res://tests/test_case.gd"
## The shell's nose in flight (playtest: "đạn của rookie bắn ra cứ lắc lắc cái đầu"): it turns
## smoothly and one way only along its arc. Paths are the server's: tests/fixtures/
## shot_path_wind.json is a real ShotResolved path (Rookie, wind, a terrain hit found between two
## steps), the others flown here exactly like shooting.go SimulateProjectile (semi-implicit Euler,
## 0.02 s steps, recorded when t - last >= 0.05, hits checked every 4 px along a step).

const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")

const FPS := 60.0
const MAX_JERK := 0.05 # degrees / frame²: how much the nose's turn per frame may change


static func _step(t: float, p: Vector2, v: Vector2) -> Dictionary:
	return {"time": t, "position": {"x": p.x, "y": p.y}, "velocity": {"x": v.x, "y": v.y}}


## shooting.go: from origin at angle (degrees, 0 right, 90 up) and power, wind acceleration
## wind_ax px/s², until the shell goes below floor_y (the hit point found every 4 px).
static func _server_path(origin: Vector2, angle: float, power: float, wind_ax: float, floor_y: float) -> Array:
	var v := Vector2(cos(deg_to_rad(angle)), -sin(deg_to_rad(angle))) * power * 9.6
	var p := origin
	var t := 0.0
	var last := -0.05
	var path: Array = []
	while t < 4.5:
		if t - last >= 0.05:
			path.append(_step(t, p, v))
			last = t
		var prev := p
		v += Vector2(wind_ax, 445.0) * 0.02
		p += v * 0.02
		t += 0.02
		var steps := maxi(1, ceili(prev.distance_to(p) / 4.0))
		for i in range(1, steps + 1):
			var q := prev.lerp(p, float(i) / steps)
			if q.y >= floor_y:
				path.append(_step(t, q, v))
				return path
	path.append(_step(t, p, v))
	return path


func _fixture() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/shot_path_wind.json"))


func _paths() -> Dictionary:
	var out := {"fixture": _fixture()}
	for c in [["slow right", 30.0, 45.0, 0.0], ["lob right, headwind", 55.0, 90.0, -100.0], ["left, tailwind", 125.0, 85.0, -67.0],
			["left, headwind", 140.0, 80.0, 134.0], ["flat fast", 15.0, 100.0, 0.0]]:
		out[c[0]] = _server_path(Vector2(1200, 800), c[1], c[2], c[3], 860.0)
	return out


static func _timeline(path: Array):
	return ShotTimeline.new({"shooterId": "p1", "duration": float(path[-1]["time"]) + 0.5,
		"projectiles": [{"projectileId": "p1", "path": path}], "events": []})


## Per-frame turns (degrees) of a list of angles (radians).
static func _turns(angles: Array) -> Array:
	var out: Array = []
	for i in range(1, angles.size()):
		out.append(rad_to_deg(wrapf(angles[i] - angles[i - 1], -PI, PI)))
	return out


## Checks turns go one way only and their change per frame stays under max_jerk.
func _check_smooth(turns: Array, max_jerk: float, label: String) -> void:
	var sign_seen := 0.0
	var reversed := 0
	var jerk := 0.0
	for i in turns.size():
		var d: float = turns[i]
		if absf(d) > 1e-4:
			if sign_seen != 0.0 and signf(d) != sign_seen:
				reversed += 1
			sign_seen = signf(d)
		if i > 0:
			jerk = maxf(jerk, absf(d - float(turns[i - 1])))
	eq(reversed, 0, "%s: the nose never turns back" % label)
	check(jerk < max_jerk, "%s: the turn per frame changes by at most %.2f° (%.3f°)" % [label, max_jerk, jerk])


## The path's own tangent (ShotTimeline.velocity()) at 60 and 144 fps: one way, no 17 Hz ripple
## at the samples (a Hermite curve on the recorded velocities: 0.2° .. 1.3° per frame, jerk ~0.8°).
func test_path_tangent_turns_smoothly_one_way() -> void:
	var paths := _paths()
	for key in paths:
		var path: Array = paths[key]
		var tl = _timeline(path)
		for fps in [FPS, 144.0]:
			var angles: Array = []
			var t := 0.0
			while t <= tl.arrival_time(0): # then it waits on the hit point for its explosion
				angles.append(tl.velocity(0, t).angle())
				t += 1.0 / fps
			_check_smooth(_turns(angles), MAX_JERK * pow(FPS / fps, 2.0) + 0.002, "%s at %d fps" % [key, fps])


## The arc passes through every recorded sample (sample() at a sample's time is its position) and
## stays between them on the server's own parabola.
func test_arc_goes_through_the_samples() -> void:
	var path: Array = _fixture()
	var tl = _timeline(path)
	for k in path.size():
		var p := Vector2(float(path[k]["position"]["x"]), float(path[k]["position"]["y"]))
		check(tl.sample(0, float(path[k]["time"])).distance_to(p) < 1e-3, "sample %d on its recorded position" % k)
	# Between two samples the server's own 0.02 s steps lie on the arc.
	var flown := _server_path(Vector2(300, 800), 50.0, 70.0, 40.0, 1e9)
	var tl2 = _timeline(flown)
	var v := Vector2(cos(deg_to_rad(50.0)), -sin(deg_to_rad(50.0))) * 70.0 * 9.6
	var p := Vector2(300, 800)
	for n in 60:
		v += Vector2(40.0, 445.0) * 0.02
		p += v * 0.02
		check(tl2.sample(0, (n + 1) * 0.02).distance_to(p) < 1e-3, "server step %d on the arc" % (n + 1))


## The last sample is a hit found between two steps but stamped with the full step's time: the
## shell flies on at the speed it had (no braking) and waits on the hit point.
func test_last_segment_keeps_its_speed() -> void:
	var paths := _paths()
	for key in paths:
		var path: Array = paths[key]
		var tl = _timeline(path)
		var knot := float(path[-2]["time"])
		var before: float = tl.velocity(0, knot - 1e-4).length()
		var after: float = tl.velocity(0, knot + 1e-4).length()
		near(after / before, 1.0, 0.02, "%s: same speed into the last segment" % key)
		var hit := Vector2(float(path[-1]["position"]["x"]), float(path[-1]["position"]["y"]))
		check(tl.sample(0, float(path[-1]["time"])).distance_to(hit) < 1e-3, "%s: ends on the hit point" % key)
		check(tl.arrival_time(0) <= float(path[-1]["time"]) + 1e-9 and tl.arrival_time(0) > knot, "%s: gets there by the hit's time" % key)
		var gap: float = tl.sample(0, tl.arrival_time(0) - 1e-6).distance_to(hit)
		check(gap < 0.1, "%s: on the hit point when it arrives (%.3f px off)" % [key, gap])
		eq(tl.sample(0, tl.arrival_time(0) + 1e-6), hit, "%s: then waits there" % key)


## Replayed with the muzzle blend (the gun snaps to 45° steps, so its muzzle sits ~37 px ahead of
## the path's start and ~10 px off it), the drawn nose (ProjectileView.draw_angle()) turns one way
## and smoothly from the first frame, stays on the path's tangent, and the drawn shell never goes
## backwards (a 0.15 s blend whose rate fed the nose swung it by ~70° and back on a slow shot).
func test_drawn_nose_with_the_muzzle_blend() -> void:
	var paths := _paths()
	for key in paths:
		var path: Array = paths[key]
		var tl = _timeline(path)
		var start_v: Vector2 = tl.start_velocity(0)
		var dir := start_v.normalized()
		var side := Vector2(-dir.y, dir.x)
		for off in [dir * 37.0 + side * 10.0, dir * 37.0 - side * 10.0, Vector2(26.7, -27.2) * signf(dir.x)]:
			for kind_tier in [["bazooka", "basic"], ["bazooka", "dragon"]]:
				var label := "%s, offset %s, %s %s" % [key, off.round(), kind_tier[0], kind_tier[1]]
				var sp := ShotPlayer.new()
				var layer := Node2D.new()
				sp.layer = layer
				sp.style = {"kind": kind_tier[0], "tier": kind_tier[1], "skill": false, "item": ""}
				var muzzle: Vector2 = tl.sample(0, 0.0) + off
				sp.muzzle = muzzle
				sp.play(tl)
				var v: Node2D = layer.get_child(0)
				v._ready()
				near(v.position.distance_to(muzzle), 0.0, 1e-3, "%s: starts at the muzzle" % label)
				var angles: Array = [v.draw_angle()]
				var dt := 1.0 / FPS
				var t := 0.0
				var prev: Vector2 = v.position
				var backwards := 0
				var off_tangent := 0.0
				while t + dt < tl.arrival_time(0):
					t += dt
					sp._process(dt)
					v._process(dt)
					angles.append(v.draw_angle())
					var path_step: Vector2 = tl.sample(0, t) - tl.sample(0, t - dt)
					if (v.position - prev).dot(path_step) < 0.5 * path_step.length_squared():
						backwards += 1
					prev = v.position
					off_tangent = maxf(off_tangent, absf(wrapf(v.draw_angle() - tl.velocity(0, t).angle(), -PI, PI)))
				_check_smooth(_turns(angles), MAX_JERK, label)
				eq(backwards, 0, "%s: drawn at least half the path's speed, never backwards" % label)
				check(off_tangent < deg_to_rad(1.5), "%s: the nose on the path's tangent (%.2f°)" % [label, rad_to_deg(off_tangent)])
				check(sp.spawn_offset(0, t).length() < 1e-3, "%s: on the path by the end" % label)
				sp.stop()
				sp.free()
				layer.free()


## The muzzle blend lasts long enough to take at most SPAWN_MAX_DRAG of the shell's speed, between
## SPAWN_BLEND and SPAWN_BLEND_MAX and at most half the flight; its ease is flat at both ends.
func test_blend_time_bounds() -> void:
	near(ShotPlayer.blend_time(Vector2.ZERO, 500.0, 2.0), ShotPlayer.SPAWN_BLEND, 1e-9, "no offset: the short blend")
	near(ShotPlayer.blend_time(Vector2(38, 0), 960.0, 2.0), 1.5 * 38.0 / (ShotPlayer.SPAWN_MAX_DRAG * 960.0), 1e-6, "fast: as long as the drag limit needs")
	near(ShotPlayer.blend_time(Vector2(38, 0), 300.0, 2.0), ShotPlayer.SPAWN_BLEND_MAX, 1e-9, "slow: at most SPAWN_BLEND_MAX")
	near(ShotPlayer.blend_time(Vector2(38, 0), 300.0, 0.3), 0.15, 1e-9, "a short flight: half of it")
	near(ShotPlayer.blend_left(0.5), 0.5, 1e-9, "half way")
	near(ShotPlayer.blend_left(0.0), 1.0, 1e-9, "all of the offset at launch")
	near(ShotPlayer.blend_left(1.0), 0.0, 1e-9, "none at the end")
