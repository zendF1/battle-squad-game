extends RefCounted
## The aiming aid's math, no nodes (AimInput draws it). A shot is flown twice:
## - fly(): the EXACT flight, like the server's SimulateProjectile (shooting.go): the weapon's
##   wind (dir × power × WIND_SCALE × windInfluence / projectileWeight), terrain (drilling
##   through `pierce` px of it), enemy bodies (the shell stops within HIT_RADIUS of a body
##   centre; allies never stop it), MAX_FLIGHT s. Its end X and time T are never drawn;
## - the guide arc: the same exact flight (wind included), only the first arc_fraction(tier) of
##   T (shorter the higher the local player's rank tier), its end faded out.
## No landing marker (playtest: too easy to aim): what is shown from the exact flight is
## - the guide arc (above);
## - "Trúng!" (is_hit(): an animated bullseye on that enemy, aim_input.gd) when the exact path
##   comes within HIT_RADIUS + hit_tolerance(D, H) of an enemy body centre, D the horizontal
##   distance to its end, H the apex height above the origin.
## A shell flying above the screen shows on the top edge in flight (high_shell_marker.gd).
## The laser (a straight beam) only gets the hit check: laser_hits(), the server's laserHits.
## The coefficients are first guesses: tune them in playtests, all here.

const Trajectory := preload("res://match/aim/trajectory_predictor.gd")

# ── Tuning ──────────────────────────────────────────────────────────────────
## Part of the exact flight time the guide arc covers, by the rank tier
## (ratingToTier ids). No / an unknown rank counts as DEFAULT_TIER.
const ARC_FRACTION := {"bronze": 0.6, "silver": 0.5, "gold": 0.4, "platinum": 0.3, "diamond": 0.22, "master": 0.15}
const DEFAULT_TIER := "bronze"
const ARC_FADE_FROM := 0.55 # the arc is solid to this part of its length, then fades out
## The "Trúng!" tolerance r = TOL_MAX × min(1, TOL_MIN_PART + (1 − TOL_MIN_PART) ×
## max(D / TOL_FAR, H / TOL_HIGH)) px: near and low shots are judged tighter.
const TOL_MAX := 20.0
const TOL_MIN_PART := 0.2
const TOL_FAR := 1200.0
const TOL_HIGH := 700.0

# ── Server physics (gamedata.DefaultPhysics(), skill_laser.go) ──────────────
const HIT_RADIUS := 24.0 # PlayerHitRadius, from the body centre
const BODY_LIFT := 20.0 # the body centre above the feet (ShotOriginLift)
const LASER_HALF_WIDTH := 10.0 # laserHalfWidth
const SPEED_PER_POWER := Trajectory.SPEED_PER_POWER # launch speed px/s per power point
const OUT_LEFT := -100.0 # the flight ends past these (SimulateProjectile's out of bounds)
const OUT_RIGHT := 100.0
const OUT_BELOW := 50.0


static func arc_fraction(tier: String) -> float:
	return float(ARC_FRACTION.get(tier, ARC_FRACTION[DEFAULT_TIER]))


## The wind's acceleration on the shell (px/s²): dir × power × WIND_SCALE × influence / weight.
static func wind_accel(wind_dir: int, wind_power: float, influence: float = 1.0, weight: float = 1.0) -> float:
	return float(wind_dir) * wind_power * Trajectory.WIND_SCALE * influence / (weight if weight > 0.0 else 1.0)


## The launch velocity of a shot at angle (degrees, 90 up) and power.
static func launch_velocity(angle_deg: float, power: float) -> Vector2:
	var a := deg_to_rad(angle_deg)
	var s := power * SPEED_PER_POWER
	return Vector2(s * cos(a), -s * sin(a))


## H: the apex height above the origin (px), (power × SPEED_PER_POWER × sin a)² / (2 × gravity); 0 when shot
## level or down.
static func apex_height(angle_deg: float, power: float) -> float:
	var vy := power * SPEED_PER_POWER * sin(deg_to_rad(angle_deg))
	return vy * vy / (2.0 * Trajectory.GRAVITY) if vy > 0.0 else 0.0


## r: the "Trúng!" tolerance (px) for a shot landing d px away with an apex h px high.
static func hit_tolerance(d: float, h: float) -> float:
	return TOL_MAX * minf(1.0, TOL_MIN_PART + (1.0 - TOL_MIN_PART) * maxf(absf(d) / TOL_FAR, h / TOL_HIGH))


## The exact flight from origin with velocity v (SimulateProjectile's loop: semi-implicit Euler,
## each step sampled every SAMPLE_PX for enemy bodies then terrain). enemies: the alive enemies'
## body centres. near (resized to enemies.size()) gets each enemy's closest distance to the path
## flown. Returns {end: Vector2 (the explosion point, or where the flight stopped), time: s,
## landed: it exploded (terrain or a body), hit: the index of the enemy body it stopped on, -1,
## high_x: where a shell that rose above the top of the screen (y < 0) comes back into view, its
## last x up there if it never does, NAN if it never rose above; high_dir: the unit direction it
## flies there (coming back: down, slanted the way it falls), Vector2.ZERO with no high_x}.
static func fly(origin: Vector2, v: Vector2, accel_x: float, terrain, enemies: PackedVector2Array,
		near: PackedFloat32Array, pierce: float = 0.0) -> Dictionary:
	near.resize(enemies.size())
	near.fill(INF)
	var x := origin.x
	var y := origin.y
	var vx := v.x
	var vy := v.y
	var t := 0.0
	var dt := Trajectory.TIME_STEP
	var r2 := HIT_RADIUS * HIT_RADIUS
	var drill_left := pierce
	var inside := false
	var high_x := NAN # where a shell above the top of the screen comes back into view
	var high_v := Vector2.ZERO # its velocity there
	while t < Trajectory.MAX_FLIGHT:
		var px := x
		var py := y
		vx += accel_x * dt
		vy += Trajectory.GRAVITY * dt
		x += vx * dt
		y += vy * dt
		t += dt
		if y < 0.0:
			high_x = x
			high_v = Vector2(vx, vy)
		elif py < 0.0:
			high_x = px + (x - px) * (-py / (y - py))
			high_v = Vector2(vx, vy)
		var dx := x - px
		var dy := y - py
		var dist := sqrt(dx * dx + dy * dy)
		var steps := maxi(ceili(dist / Trajectory.SAMPLE_PX), 1)
		var step_len := dist / steps
		for i in range(1, steps + 1):
			var f := float(i) / float(steps)
			var sx := px + dx * f
			var sy := py + dy * f
			for k in enemies.size():
				var ex := sx - enemies[k].x
				var ey := sy - enemies[k].y
				if ex * ex + ey * ey <= r2:
					_near_segment(enemies, near, px, py, sx, sy)
					return {"end": Vector2(sx, sy), "time": t, "landed": true, "hit": k, "high_x": high_x, "high_dir": high_v.normalized()}
			if terrain != null and terrain.is_solid(sx, sy):
				if drill_left > 0.0:
					inside = true
					drill_left -= step_len
					continue
				_near_segment(enemies, near, px, py, sx, sy)
				return {"end": Vector2(sx, sy), "time": t, "landed": true, "hit": -1, "high_x": high_x, "high_dir": high_v.normalized()}
			if inside:
				inside = false
				drill_left = 0.0
		_near_segment(enemies, near, px, py, x, y)
		if terrain != null and (x < OUT_LEFT or x > terrain.width + OUT_RIGHT or y > terrain.height + OUT_BELOW):
			break
	return {"end": Vector2(x, y), "time": t, "landed": false, "hit": -1, "high_x": high_x, "high_dir": high_v.normalized()}


## Lowers each enemy's closest distance with the segment a → b.
static func _near_segment(enemies: PackedVector2Array, near: PackedFloat32Array, ax: float, ay: float, bx: float, by: float) -> void:
	var dx := bx - ax
	var dy := by - ay
	var len2 := dx * dx + dy * dy
	for k in enemies.size():
		var cx := enemies[k].x - ax
		var cy := enemies[k].y - ay
		var u := clampf((cx * dx + cy * dy) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
		var ox := cx - dx * u
		var oy := cy - dy * u
		var d := sqrt(ox * ox + oy * oy)
		if d < near[k]:
			near[k] = d


## "Trúng!": the path came within HIT_RADIUS + r of enemy k's body centre (near from fly()).
static func is_hit(near: PackedFloat32Array, k: int, r: float) -> bool:
	return k < near.size() and near[k] <= HIT_RADIUS + r


## The enemies (indices into the body centres) a laser beam origin → end crosses: the server's
## laserHits, a band LASER_HALF_WIDTH + HIT_RADIUS wide round the beam (through terrain).
static func laser_hits(origin: Vector2, end: Vector2, enemies: PackedVector2Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var d := end - origin
	var length := d.length()
	if length <= 0.0:
		return out
	var u := d / length
	var reach := LASER_HALF_WIDTH + HIT_RADIUS
	for k in enemies.size():
		var c := enemies[k] - origin
		var s := c.x * u.x + c.y * u.y
		if s < -reach or s > length + reach:
			continue
		if absf(c.x * u.y - c.y * u.x) > reach:
			continue
		out.append(k)
	return out
