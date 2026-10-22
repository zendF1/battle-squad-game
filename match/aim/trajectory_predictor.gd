extends RefCounted
## Aim preview that uses the same integration and terrain collision as the server's
## SimulateProjectile (shooting.go), with the server's physics from the game data (GET /gamedata
## physics: gravity, speedPerPower, windScale, timeStep, maxFlightSec, collisionStepPx,
## shotOriginLift, outOfBounds; autoload/game_data_model.gd):
## - semi-implicit Euler steps of timeStep;
## - each step's segment is sampled every collisionStepPx or less, so thin walls and crater lips
##   stop the preview where they stop the shell.
## Players, drills, weapon weight and wind influence are not modelled (weight 1, influence 1),
## so the preview is a guide, not a promise. The aiming aid's exact flight (match/aim/aim_aid.gd
## fly()) adds them on the same integration; the guide arc drawn is simulate() with the weapon's wind.
## The server fires every shot from the shooter's body centre (shotOriginAt, shooting.go): its
## position (the feet) lifted by shotOriginLift px. Air strikes start at (targetX, 0) instead.
##
## The math uses GDScript floats (64-bit, like Go's float64). Vector2 (32-bit) is used only for
## the returned points.

const GameData := preload("res://autoload/game_data_model.gd")


## The shot origin relative to the feet: (0, −shotOriginLift), the body centre.
static func shot_offset() -> Vector2:
	return Vector2(0, -GameData.shot_origin_lift())


## Where the server starts a shot fired by a player standing at `feet`: feet - (0, shotOriginLift);
## under a low ceiling the highest free pixel above the feet (feet.y - 1, - 2, ... scanned up,
## stopping before the first solid one), the feet themselves when feet.y - 1 is solid. Off the
## map in x or above its top counts as free (TerrainMask.is_solid). terrain null: no ceiling.
static func shot_origin(feet: Vector2, terrain = null) -> Vector2:
	var lift := 0
	for k in range(1, int(GameData.shot_origin_lift()) + 1):
		if terrain != null and terrain.is_solid(feet.x, feet.y - k):
			break
		lift = k
	return Vector2(feet.x, feet.y - lift)


static func predict(origin: Vector2, angle_deg: float, power: float, wind_dir: int, wind_power: float, terrain, max_points: int = 90) -> PackedVector2Array:
	var a := deg_to_rad(angle_deg)
	var speed := power * GameData.speed_per_power()
	return simulate(origin.x, origin.y, speed * cos(a), -speed * sin(a), wind_dir * wind_power * GameData.wind_scale(), terrain, max_points)


## Integrates from (x, y) with velocity (vx, vy). The flight ends at whichever comes first:
## - the terrain hit point (the server's explosion point);
## - leaving the map bounds;
## - maxFlightSec seconds;
## - max_points points.
static func simulate(x: float, y: float, vx: float, vy: float, wind_force: float, terrain, max_points: int) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(x, y)])
	var dt := GameData.time_step()
	var max_flight := GameData.max_flight_sec()
	var gravity := GameData.gravity()
	var sample := GameData.collision_step_px()
	var out := GameData.out_of_bounds()
	var t := 0.0
	if dt <= 0.0:
		return pts
	while t < max_flight and pts.size() < max_points:
		var prev_x := x
		var prev_y := y
		vx += wind_force * dt
		vy += gravity * dt
		x += vx * dt
		y += vy * dt
		t += dt
		if terrain != null:
			var hit = _segment_hit(prev_x, prev_y, x, y, terrain, sample)
			if hit != null:
				pts.append(hit)
				return pts
		pts.append(Vector2(x, y))
		if terrain != null and (x < -out["left"] or x > terrain.width + out["right"] or y > terrain.height + out["below"]):
			break
	return pts


## The terrain part of checkSegmentCollisions: returns the first solid sample along
## (px, py) → (cx, cy), or null if there is none.
static func _segment_hit(px: float, py: float, cx: float, cy: float, terrain, sample: float):
	var dx := cx - px
	var dy := cy - py
	var steps := maxi(ceili(sqrt(dx * dx + dy * dy) / sample), 1) if sample > 0.0 else 1
	for i in range(1, steps + 1):
		var frac := float(i) / float(steps)
		var sx := px + dx * frac
		var sy := py + dy * frac
		if terrain.is_solid(sx, sy):
			return Vector2(sx, sy)
	return null
