extends RefCounted
## Read-only view of a ShotResolved payload (server: internal/game/match/model.go). Positions
## between recorded path samples follow the server's own constant-acceleration arc (_arc()), so
## the projectile curve and its tangent stay smooth at any frame rate. Path times are seconds
## since the shot: a projectile leaving later (bomb chain, missiles) starts at launch_time() > 0.
## Fields an older server does not send fall back: no kind = a normal shell, no launchDelay =
## its first path sample's time, no skillEnergies = {} (shooter_energy, from skillEnergy, then
## still says the shooter's), no itemId = "".

var shooter_id := ""
var action_mode := ""
var skill_id := ""
var item_id := "" # the shot item (actionMode "item"), "" for none
var projectiles: Array = []
var events: Array = []
var duration := 0.0
## {playerId: skill energy after the shot} (players hit by an enemy gained some); {} when absent.
var skill_energies := {}
## The shooter's skill energy after the shot (skillEnergy; 0 after a skill), -1 when absent.
var shooter_energy := -1

var _cursor := 0

const ARRIVE_NEAR := 1.0 # px: _arrival() flies on to the hit point only when it lands this close


func _init(payload: Dictionary) -> void:
	shooter_id = str(payload.get("shooterId", ""))
	action_mode = str(payload.get("actionMode", ""))
	skill_id = str(payload.get("skillId", "")) if payload.get("skillId") != null else ""
	item_id = str(payload.get("itemId", "")) if payload.get("itemId") is String else ""
	var p = payload.get("projectiles", [])
	projectiles = p if p is Array else []
	var e = payload.get("events", [])
	events = e if e is Array else []
	duration = float(payload.get("duration", 0.0))
	var energies = payload.get("skillEnergies")
	if energies is Dictionary:
		skill_energies = energies
	var mine = payload.get("skillEnergy")
	if mine is int or mine is float:
		shooter_energy = int(mine)


## What projectile i is (server ProjectileResult.kind): "flare", "missile", "bomb", "seed", or ""
## for a normal shell.
func kind(i: int) -> String:
	var k = projectiles[i].get("kind")
	return str(k) if k is String else ""


## When projectile i leaves (s since the shot): launchDelay, else its first path sample's time.
func launch_time(i: int) -> float:
	var d = projectiles[i].get("launchDelay")
	if d is float or d is int:
		return float(d)
	var path: Array = projectiles[i].get("path", [])
	return float(path[0]["time"]) if not path.is_empty() else 0.0


## The events of one type, in timeline order.
func events_of(type: String) -> Array:
	return events.filter(func(ev): return ev is Dictionary and str(ev.get("type", "")) == type)


## The blast (damage) radius of the projectile with this id, 0 when unknown. It can be larger
## than its explode event's radius, which is the crater.
func blast_radius(projectile_id: String) -> float:
	for p in projectiles:
		if str(p.get("projectileId", "")) == projectile_id:
			return float(p.get("explosionRadius", 0.0))
	return 0.0


func projectile_end(i: int) -> float:
	var path: Array = projectiles[i].get("path", [])
	return 0.0 if path.is_empty() else float(path[-1]["time"])


func sample(i: int, t: float) -> Vector2:
	var path: Array = projectiles[i].get("path", [])
	if path.is_empty():
		return Vector2.ZERO
	if t <= float(path[0]["time"]):
		return _vec(path[0]["position"])
	var k := _segment_at(path, t)
	if k < 0:
		return _vec(path[-1]["position"])
	var arc := _arc(path, k)
	var tau := t - float(path[k]["time"])
	if tau >= arc[3]:
		return arc[4] # arrived: it waits on the sample
	return arc[0] + arc[1] * tau + arc[2] * (0.5 * tau * tau)


## When projectile i reaches its last point (s since the shot): projectile_end(), or a little
## earlier when its flight ends on a hit found between two server steps (_arc()); it waits there.
func arrival_time(i: int) -> float:
	var path: Array = projectiles[i].get("path", [])
	if path.size() < 2:
		return projectile_end(i)
	return float(path[-2]["time"]) + float(_arc(path, path.size() - 2)[3])


## Projectile i's velocity at time t (px/s): the derivative of sample()'s arc, so the path's
## tangent (zero outside the path). It changes linearly in time inside a segment, so the
## direction turns one way only (no wobble at the samples).
func velocity(i: int, t: float) -> Vector2:
	var path: Array = projectiles[i].get("path", [])
	if path.size() < 2 or t < float(path[0]["time"]) or t > float(path[-1]["time"]):
		return Vector2.ZERO
	var k := _segment_at(path, t)
	if k < 0:
		k = path.size() - 2
	var arc := _arc(path, k)
	return arc[1] + arc[2] * minf(maxf(t - float(path[k]["time"]), 0.0), arc[3])


## The segment [k, k + 1] holding time t (t < path[k + 1].time; the last one includes its
## end), -1 past the end.
static func _segment_at(path: Array, t: float) -> int:
	for k in range(path.size() - 1):
		if t < float(path[k + 1]["time"]):
			return k
	return path.size() - 2 if path.size() >= 2 and t <= float(path[-1]["time"]) else -1


## Segment k as the server flies it: constant acceleration (gravity + wind) between two recorded
## samples, [start, start velocity, acceleration, span s, end]. The server integrates with
## semi-implicit Euler (velocity first, then position) and records the velocity of the step
## that arrived, which lags the true tangent by half a step; its positions still lie exactly on
## the parabola p_a + u·τ + acc·τ²/2 through both samples, acc = (v_b - v_a) / h and
## u = (p_b - p_a) / h - acc·h / 2, so that curve is the server's own (a Hermite curve on the
## recorded velocities bends to them and back at every sample: a 17 Hz wobble of the tangent).
## The last segment ends on a hit found between two steps but stamped with the full step's time
## (shooting.go checkSegmentCollisions): it is flown on at the velocity the shell arrived with
## (_arrival()) and reaches the hit point early (span < h), then stays there; samples without a
## velocity fly straight.
static func _arc(path: Array, k: int) -> Array:
	var a: Dictionary = path[k]
	var b: Dictionary = path[k + 1]
	var pa := _vec(a["position"])
	var pb := _vec(b["position"])
	var h := float(b["time"]) - float(a["time"])
	if h <= 0.0:
		return [pb, Vector2.ZERO, Vector2.ZERO, 0.0, pb]
	var acc := Vector2.ZERO
	if a.get("velocity") is Dictionary and b.get("velocity") is Dictionary:
		acc = (_vec(b["velocity"]) - _vec(a["velocity"])) / h
	if k == path.size() - 2 and k >= 1:
		var arrival := _arrival(path, k, pa, pb, acc, h)
		if not arrival.is_empty():
			return [pa, arrival[1], acc, arrival[0], pb]
	return [pa, (pb - pa) / h - acc * (0.5 * h), acc, h, pb]


## The last segment flown on at the velocity the shell had at its start (the end of the segment
## before), [span, that velocity]: span the root of acc·ĉ/2·τ² + s0·τ = |chord| along the chord ĉ
## (s0 the speed along it), when it is shorter than h and lands within ARRIVE_NEAR px of the
## hit; [] otherwise (the segment is fitted to its two samples).
static func _arrival(path: Array, k: int, pa: Vector2, pb: Vector2, acc: Vector2, h: float) -> Array:
	var chord := pb - pa
	var length := chord.length()
	if length < 1e-6:
		return []
	var before := _arc(path, k - 1)
	var u: Vector2 = before[1] + before[2] * before[3]
	var dir := chord / length
	var s0 := u.dot(dir)
	var ac := acc.dot(dir)
	if s0 <= 0.0:
		return []
	var tau := length / s0
	if absf(ac) > 1e-6:
		var disc := s0 * s0 + 2.0 * ac * length
		if disc < 0.0:
			return []
		tau = (sqrt(disc) - s0) / ac
	if tau <= 0.0 or tau >= h:
		return []
	if (pa + u * tau + acc * (0.5 * tau * tau)).distance_to(pb) > ARRIVE_NEAR:
		return []
	return [tau, u]


## Projectile i's velocity where its path starts (px/s), zero for an empty path.
func start_velocity(i: int) -> Vector2:
	var path: Array = projectiles[i].get("path", [])
	var v = path[0].get("velocity") if not path.is_empty() else null
	return _vec(v) if v is Dictionary and v.has("x") and v.has("y") else Vector2.ZERO


## Returns the events with t <= time that were not returned before, in timeline order.
func pop_due(time: float) -> Array:
	var due := []
	while _cursor < events.size() and float(events[_cursor]["t"]) <= time:
		due.append(events[_cursor])
		_cursor += 1
	return due


static func _vec(d: Dictionary) -> Vector2:
	return Vector2(float(d["x"]), float(d["y"]))
