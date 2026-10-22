extends RefCounted
## The aiming aid's math, no nodes (AimInput draws it). A shot is flown twice:
## - fly(): the EXACT flight, like the server's SimulateProjectile (shooting.go): the weapon's
##   wind (dir × power × windScale × windInfluence / projectileWeight), terrain (drilling
##   through `pierce` px of it), enemy bodies (the shell stops within playerHitRadius of a body
##   centre; allies never stop it), maxFlightSec s. Its end X and time T are never drawn;
## - the guide arc: the same exact flight (wind included), only its first arc_length(tier) px
##   (shorter the higher the local player's rank tier; the same length whatever the power, cut
##   short only where the flight itself ends), its end faded out.
## No landing marker (playtest: too easy to aim): what is shown from the exact flight is
## - the guide arc (above);
## - "Trúng!" (is_hit(): an animated bullseye on that enemy, aim_input.gd) when the exact path
##   comes within playerHitRadius + hit_tolerance(D, H) of an enemy body centre, D the horizontal
##   distance to its end, H the apex height above the origin.
## A shell flying above the view shows on its top edge in flight (high_shell_marker.gd).
## The laser (a straight beam) only gets the hit check: laser_hits(), the server's laserHits.
## Every number is the server's game data (aimAid, physics): tune them in the admin dashboard.

const GameData := preload("res://autoload/game_data_model.gd")

## The guide arc is solid to this part of its length, then fades out (presentation).
const ARC_FADE_FROM := 0.55

# The numbers come from the game data (GET /gamedata): the guide arc's length per rank tier
# (aimAid.guideArcLength / defaultTier), the "Trúng!" tolerance (aimAid.hitTolerance), the
# shell physics (physics: playerHitRadius, the body centre shotOriginLift, outOfBounds) and the
# laser's half width (the laser skill's params.halfWidth).


## The guide arc's length along the path (px) by the local player's rank tier (ratingToTier
## ids); the same for every power. No / an unknown rank counts as aimAid.defaultTier.
static func arc_length(tier: String) -> float:
	return GameData.guide_arc_length(tier)


## The body centre above the feet (px).
static func body_lift() -> float:
	return GameData.shot_origin_lift()


## A shell stops within this of an enemy body centre (px).
static func hit_radius() -> float:
	return GameData.player_hit_radius()


## The laser hits an enemy within this of its beam (px; the laser skill's halfWidth).
static func laser_half_width() -> float:
	return GameData.effect_param("laser", "halfWidth")


## The start of a path (points) up to `length` px along it, its last point interpolated; the
## whole path when it is shorter.
static func trim_to_length(points: PackedVector2Array, length: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.is_empty():
		return out
	out.append(points[0])
	var left := length
	for i in range(1, points.size()):
		var seg := points[i - 1].distance_to(points[i])
		if seg >= left:
			if left > 0.0:
				out.append(points[i - 1].lerp(points[i], left / seg))
			return out
		left -= seg
		out.append(points[i])
	return out


## The wind's acceleration on the shell (px/s²): dir × power × windScale × influence / weight.
static func wind_accel(wind_dir: int, wind_power: float, influence: float = 1.0, weight: float = 1.0) -> float:
	return float(wind_dir) * wind_power * GameData.wind_scale() * influence / (weight if weight > 0.0 else 1.0)


## The launch velocity of a shot at angle (degrees, 90 up) and power.
static func launch_velocity(angle_deg: float, power: float) -> Vector2:
	var a := deg_to_rad(angle_deg)
	var s := power * GameData.speed_per_power()
	return Vector2(s * cos(a), -s * sin(a))


## H: the apex height above the origin (px), (power × speedPerPower × sin a)² / (2 × gravity); 0
## when shot level or down.
static func apex_height(angle_deg: float, power: float) -> float:
	var vy := power * GameData.speed_per_power() * sin(deg_to_rad(angle_deg))
	var g := GameData.gravity()
	return vy * vy / (2.0 * g) if vy > 0.0 and g > 0.0 else 0.0


## r: the "Trúng!" tolerance (px) for a shot landing d px away with an apex h px high:
## max × min(1, minPart + (1 − minPart) × max(D / farPx, H / highPx)).
static func hit_tolerance(d: float, h: float) -> float:
	var t := GameData.hit_tolerance()
	var far: float = t["farPx"]
	var high: float = t["highPx"]
	var part := maxf(absf(d) / far if far > 0.0 else 1.0, h / high if high > 0.0 else 1.0)
	return t["max"] * minf(1.0, t["minPart"] + (1.0 - t["minPart"]) * part)


## The exact flight from origin with velocity v (SimulateProjectile's loop: semi-implicit Euler,
## each step sampled every collisionStepPx for enemy bodies then terrain). enemies: the alive enemies'
## body centres. near (resized to enemies.size()) gets each enemy's closest distance to the path
## flown. Returns {end: Vector2 (the explosion point, or where the flight stopped), time: s,
## landed: it exploded (terrain or a body), hit: the index of the enemy body it stopped on, -1,
## high_x: where a shell that rose above the view's top (y < top: the camera's view top, world y)
## comes back into view, its last x up there if it never does, NAN if it never rose above;
## high_dir: the unit direction it flies there (coming back: down, slanted the way it falls),
## Vector2.ZERO with no high_x}. radii: each enemy's hit radius (a boss's playerHitRadius ×
## bodySize); an enemy past its end has playerHitRadius.
static func fly(origin: Vector2, v: Vector2, accel_x: float, terrain, enemies: PackedVector2Array,
		near: PackedFloat32Array, pierce: float = 0.0, top: float = 0.0, radii: PackedFloat32Array = PackedFloat32Array()) -> Dictionary:
	near.resize(enemies.size())
	near.fill(INF)
	var x := origin.x
	var y := origin.y
	var vx := v.x
	var vy := v.y
	var t := 0.0
	var dt := GameData.time_step()
	var max_flight := GameData.max_flight_sec()
	var gravity := GameData.gravity()
	var sample := GameData.collision_step_px()
	var out := GameData.out_of_bounds()
	var hit_r := GameData.player_hit_radius()
	var r2 := hit_r * hit_r
	var drill_left := pierce
	var inside := false
	var high_x := NAN # where a shell above the top of the screen comes back into view
	var high_v := Vector2.ZERO # its velocity there
	if dt <= 0.0:
		return {"end": origin, "time": 0.0, "landed": false, "hit": -1, "high_x": NAN, "high_dir": Vector2.ZERO}
	while t < max_flight:
		var px := x
		var py := y
		vx += accel_x * dt
		vy += gravity * dt
		x += vx * dt
		y += vy * dt
		t += dt
		if y < top:
			high_x = x
			high_v = Vector2(vx, vy)
		elif py < top:
			high_x = px + (x - px) * ((top - py) / (y - py))
			high_v = Vector2(vx, vy)
		var dx := x - px
		var dy := y - py
		var dist := sqrt(dx * dx + dy * dy)
		var steps := maxi(ceili(dist / sample), 1) if sample > 0.0 else 1
		var step_len := dist / steps
		for i in range(1, steps + 1):
			var f := float(i) / float(steps)
			var sx := px + dx * f
			var sy := py + dy * f
			for k in enemies.size():
				var ex := sx - enemies[k].x
				var ey := sy - enemies[k].y
				var rk := radii[k] * radii[k] if k < radii.size() else r2
				if ex * ex + ey * ey <= rk:
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
		if terrain != null and (x < -out["left"] or x > terrain.width + out["right"] or y > terrain.height + out["below"]):
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


## "Trúng!": the path came within playerHitRadius (radii[k] when given: a boss's) + r of enemy k's
## body centre (near from fly()).
static func is_hit(near: PackedFloat32Array, k: int, r: float, radii: PackedFloat32Array = PackedFloat32Array()) -> bool:
	return k < near.size() and near[k] <= (radii[k] if k < radii.size() else hit_radius()) + r


## The enemies (indices into the body centres) a laser beam origin → end crosses: the server's
## laserHits, a band laser halfWidth + playerHitRadius wide round the beam (through terrain).
static func laser_hits(origin: Vector2, end: Vector2, enemies: PackedVector2Array, radii: PackedFloat32Array = PackedFloat32Array()) -> PackedInt32Array:
	var out := PackedInt32Array()
	var d := end - origin
	var length := d.length()
	if length <= 0.0:
		return out
	var u := d / length
	for k in enemies.size():
		var reach := laser_half_width() + (radii[k] if k < radii.size() else hit_radius())
		var c := enemies[k] - origin
		var s := c.x * u.x + c.y * u.y
		if s < -reach or s > length + reach:
			continue
		if absf(c.x * u.y - c.y * u.x) > reach:
			continue
		out.append(k)
	return out
