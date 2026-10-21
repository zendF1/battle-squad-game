extends RefCounted
## Aim preview that uses the same integration and terrain collision as the server's
## SimulateProjectile (shooting.go), with the getPhysics() defaults:
## - semi-implicit Euler steps of TIME_STEP;
## - each step's segment is sampled every 4 px or less, so thin walls and crater lips stop the
##   preview where they stop the shell.
## Players, drills, weapon weight and wind influence are not modelled (weight 1, influence 1),
## so the preview is a guide, not a promise. The aiming aid's exact flight (match/aim/aim_aid.gd
## fly()) adds them on the same integration; the guide arc drawn is simulate() without wind.
##
## The math uses GDScript floats (64-bit, like Go's float64). Vector2 (32-bit) is used only for
## the returned points.

const TIME_STEP := 0.02
const GRAVITY := 200.0
const WIND_SCALE := 30.0
const MAX_FLIGHT := 6.0
const SAMPLE_PX := 4.0 # checkSegmentCollisions sub-step
## The server fires every shot from the shooter's body centre (shotOriginAt, shooting.go): its
## position (the feet) lifted by SHOT_LIFT px (PlayerHeight / 2). Air strikes start at
## (targetX, 0) instead.
const SHOT_LIFT := 20
const SHOT_ORIGIN := Vector2(0, -SHOT_LIFT)


## Where the server starts a shot fired by a player standing at `feet`: feet - (0, SHOT_LIFT);
## under a low ceiling the highest free pixel above the feet (feet.y - 1, - 2, ... scanned up,
## stopping before the first solid one), the feet themselves when feet.y - 1 is solid. Off the
## map in x or above its top counts as free (TerrainMask.is_solid). terrain null: no ceiling.
static func shot_origin(feet: Vector2, terrain = null) -> Vector2:
	var lift := 0
	for k in range(1, SHOT_LIFT + 1):
		if terrain != null and terrain.is_solid(feet.x, feet.y - k):
			break
		lift = k
	return Vector2(feet.x, feet.y - lift)


static func predict(origin: Vector2, angle_deg: float, power: float, wind_dir: int, wind_power: float, terrain, max_points: int = 90) -> PackedVector2Array:
	var a := deg_to_rad(angle_deg)
	var speed := power * 6.0
	return simulate(origin.x, origin.y, speed * cos(a), -speed * sin(a), wind_dir * wind_power * WIND_SCALE, terrain, max_points)


## Integrates from (x, y) with velocity (vx, vy). The flight ends at whichever comes first:
## - the terrain hit point (the server's explosion point);
## - leaving the map bounds;
## - MAX_FLIGHT seconds;
## - max_points points.
static func simulate(x: float, y: float, vx: float, vy: float, wind_force: float, terrain, max_points: int) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(x, y)])
	var t := 0.0
	while t < MAX_FLIGHT and pts.size() < max_points:
		var prev_x := x
		var prev_y := y
		vx += wind_force * TIME_STEP
		vy += GRAVITY * TIME_STEP
		x += vx * TIME_STEP
		y += vy * TIME_STEP
		t += TIME_STEP
		if terrain != null:
			var hit = _segment_hit(prev_x, prev_y, x, y, terrain)
			if hit != null:
				pts.append(hit)
				return pts
		pts.append(Vector2(x, y))
		if terrain != null and (x < -100.0 or x > terrain.width + 100.0 or y > terrain.height + 50.0):
			break
	return pts


## The terrain part of checkSegmentCollisions: returns the first solid sample along
## (px, py) → (cx, cy), or null if there is none.
static func _segment_hit(px: float, py: float, cx: float, cy: float, terrain):
	var dx := cx - px
	var dy := cy - py
	var steps := maxi(ceili(sqrt(dx * dx + dy * dy) / SAMPLE_PX), 1)
	for i in range(1, steps + 1):
		var frac := float(i) / float(steps)
		var sx := px + dx * frac
		var sy := py + dy * frac
		if terrain.is_solid(sx, sy):
			return Vector2(sx, sy)
	return null
