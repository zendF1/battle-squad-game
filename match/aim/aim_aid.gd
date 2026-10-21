extends RefCounted
## The aiming aid's math, no nodes (AimInput draws it). A shot is flown twice:
## - fly(): the EXACT flight, like the server's SimulateProjectile (shooting.go): the weapon's
##   wind (dir × power × WIND_SCALE × windInfluence / projectileWeight), terrain (drilling
##   through `pierce` px of it), enemy bodies (the shell stops within HIT_RADIUS of a body
##   centre; allies never stop it), MAX_FLIGHT s. Its end X and time T are never drawn as such;
## - the guide arc: the same exact flight (wind included), only the first arc_fraction(tier) of
##   T (shorter the higher the local player's rank tier), its end faded out.
## What is shown from X:
## - the landing marker at shown_x() = X.x − clamp(WIND_BIAS × W × T, ±MAX_BIAS) (W: the signed
##   wind dir × power, + blows right), dropped onto the ground (surface_y()): against the wind, so the wind must
##   still be read (a tailwind shows it short, a headwind long, whichever way the shot goes);
## - "Trúng!" (is_hit()) when the exact path comes within HIT_RADIUS + hit_tolerance(D, H) of an
##   enemy body centre, D the horizontal distance to X, H the apex height above the origin;
## - a down arrow on the marker when the apex is above the top of the screen (is_super_high()).
## The laser (a straight beam) only gets the hit check: laser_hits(), the server's laserHits.
## The coefficients are first guesses: tune them in playtests, all here.

const Trajectory := preload("res://match/aim/trajectory_predictor.gd")

# ── Tuning ──────────────────────────────────────────────────────────────────
## Part of the exact flight time the windless guide arc covers, by the rank tier
## (ratingToTier ids). No / an unknown rank counts as DEFAULT_TIER.
const ARC_FRACTION := {"bronze": 0.6, "silver": 0.5, "gold": 0.4, "platinum": 0.3, "diamond": 0.22, "master": 0.15}
const DEFAULT_TIER := "bronze"
const ARC_FADE_FROM := 0.55 # the arc is solid to this part of its length, then fades out
const WIND_BIAS := 2.0 # px per (wind × s) the landing marker is moved against the wind
const MAX_BIAS := 40.0 # px: the marker never strays further from the real landing
## The "Trúng!" tolerance r = TOL_MAX × min(1, TOL_MIN_PART + (1 − TOL_MIN_PART) ×
## max(D / TOL_FAR, H / TOL_HIGH)) px: near and low shots are judged tighter.
const TOL_MAX := 20.0
const TOL_MIN_PART := 0.2
const TOL_FAR := 1200.0
const TOL_HIGH := 700.0

# ── Server physics (getPhysics defaults, skill_laser.go) ────────────────────
const HIT_RADIUS := 24.0 # PlayerHitRadius, from the body centre
const BODY_LIFT := 20.0 # the body centre above the feet (ShotOriginLift)
const LASER_HALF_WIDTH := 10.0 # laserHalfWidth
const SPEED_PER_POWER := 6.0
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


## H: the apex height above the origin (px), (power × 6 × sin a)² / (2 × gravity); 0 when shot
## level or down.
static func apex_height(angle_deg: float, power: float) -> float:
	var vy := power * SPEED_PER_POWER * sin(deg_to_rad(angle_deg))
	return vy * vy / (2.0 * Trajectory.GRAVITY) if vy > 0.0 else 0.0


## The apex goes above the top of the screen (y < 0).
static func is_super_high(origin_y: float, angle_deg: float, power: float) -> bool:
	return origin_y - apex_height(angle_deg, power) < 0.0


static func shown_x(exact_x: float, wind: float, flight_time: float) -> float:
	return exact_x - clampf(WIND_BIAS * wind * flight_time, -MAX_BIAS, MAX_BIAS)


## r: the "Trúng!" tolerance (px) for a shot landing d px away with an apex h px high.
static func hit_tolerance(d: float, h: float) -> float:
	return TOL_MAX * minf(1.0, TOL_MIN_PART + (1.0 - TOL_MIN_PART) * maxf(absf(d) / TOL_FAR, h / TOL_HIGH))


## The ground under x nearest to near_y: of the column's surfaces (a solid pixel with air or the
## map top above it), the one closest to near_y; the map's bottom when the column has none.
static func surface_y(terrain, x: float, near_y: float) -> float:
	if terrain == null:
		return near_y
	var ix := clampi(roundi(x), 0, terrain.width - 1)
	var w: int = terrain.width
	var best := float(terrain.height)
	var best_d := INF
	var above_solid := false
	for y in terrain.height:
		var s: bool = terrain.solid[y * w + ix] != 0
		if s and not above_solid:
			var d := absf(float(y) - near_y)
			if d < best_d:
				best_d = d
				best = float(y)
		above_solid = s
	return best


## The landing marker: shown_x() clamped to the map, on the ground nearest the exact landing.
static func shown_point(exact: Vector2, wind: float, flight_time: float, terrain) -> Vector2:
	var x := shown_x(exact.x, wind, flight_time)
	if terrain == null:
		return Vector2(x, exact.y)
	x = clampf(x, 0.0, float(terrain.width - 1))
	return Vector2(x, surface_y(terrain, x, exact.y))


## The exact flight from origin with velocity v (SimulateProjectile's loop: semi-implicit Euler,
## each step sampled every SAMPLE_PX for enemy bodies then terrain). enemies: the alive enemies'
## body centres. near (resized to enemies.size()) gets each enemy's closest distance to the path
## flown. Returns {end: Vector2 (the explosion point, or where the flight stopped), time: s,
## landed: it exploded (terrain or a body), hit: the index of the enemy body it stopped on, -1}.
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
	while t < Trajectory.MAX_FLIGHT:
		var px := x
		var py := y
		vx += accel_x * dt
		vy += Trajectory.GRAVITY * dt
		x += vx * dt
		y += vy * dt
		t += dt
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
					return {"end": Vector2(sx, sy), "time": t, "landed": true, "hit": k}
			if terrain != null and terrain.is_solid(sx, sy):
				if drill_left > 0.0:
					inside = true
					drill_left -= step_len
					continue
				_near_segment(enemies, near, px, py, sx, sy)
				return {"end": Vector2(sx, sy), "time": t, "landed": true, "hit": -1}
			if inside:
				inside = false
				drill_left = 0.0
		_near_segment(enemies, near, px, py, x, y)
		if terrain != null and (x < OUT_LEFT or x > terrain.width + OUT_RIGHT or y > terrain.height + OUT_BELOW):
			break
	return {"end": Vector2(x, y), "time": t, "landed": false, "hit": -1}


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
