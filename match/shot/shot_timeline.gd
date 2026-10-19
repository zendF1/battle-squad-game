extends RefCounted
## Read-only view of a ShotResolved payload (server: internal/game/match/model.go). Positions
## between recorded path samples use cubic Hermite interpolation with the recorded velocities,
## so the projectile curve stays smooth at any frame rate.

var shooter_id := ""
var projectiles: Array = []
var events: Array = []
var duration := 0.0

var _cursor := 0


func _init(payload: Dictionary) -> void:
	shooter_id = str(payload.get("shooterId", ""))
	projectiles = payload.get("projectiles", [])
	events = payload.get("events", [])
	duration = float(payload.get("duration", 0.0))


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
	for k in range(path.size() - 1):
		var a: Dictionary = path[k]
		var b: Dictionary = path[k + 1]
		var ta := float(a["time"])
		var tb := float(b["time"])
		if t >= tb:
			continue
		var h := tb - ta
		if h <= 0.0:
			return _vec(b["position"])
		var s := (t - ta) / h
		var s2 := s * s
		var s3 := s2 * s
		return (2.0 * s3 - 3.0 * s2 + 1.0) * _vec(a["position"]) \
			+ (s3 - 2.0 * s2 + s) * h * _vec(a["velocity"]) \
			+ (-2.0 * s3 + 3.0 * s2) * _vec(b["position"]) \
			+ (s3 - s2) * h * _vec(b["velocity"])
	return _vec(path[-1]["position"])


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
