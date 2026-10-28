extends RefCounted
## A ShotResolved event's ground path ([{x, y}] from `from` to `to`: the crab's walk `move`, the
## boulder's `roll`, the root drag's `pull`; server boss_v5.go) played at the server's constant
## speed: the event starts at its `t`, lasts `duration` s (= path length / speed), and the mover is
## at the point that far along the path's length at time t (so the boulder reaches a member at the
## damage event's own t). Pure: the views ask it for a position every frame.

var points := PackedVector2Array()
var start := 0.0 # s since the shot (the event's t)
var duration := 0.0
var _lengths := PackedFloat32Array() # the length along the path to each point
var _total := 0.0


## The motion of a path event ({t, duration, path, from, to}); a missing path goes straight from
## `from` to `to`.
func _init(e: Dictionary = {}) -> void:
	points = event_points(e)
	start = float(e.get("t", 0.0))
	duration = maxf(float(e.get("duration", 0.0)), 0.0)
	_measure()


## The event's path as points, else [from, to], else [].
static func event_points(e: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var path = e.get("path")
	if path is Array:
		for p in path:
			if p is Dictionary and (p.get("x") is int or p.get("x") is float) and (p.get("y") is int or p.get("y") is float):
				out.append(Vector2(float(p["x"]), float(p["y"])))
	if out.is_empty():
		for key in ["from", "to"]:
			var p = e.get(key)
			if p is Dictionary:
				out.append(Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))))
	return out


func _measure() -> void:
	_lengths.resize(points.size())
	_total = 0.0
	for i in points.size():
		if i > 0:
			_total += points[i].distance_to(points[i - 1])
		_lengths[i] = _total


## The path's length (px).
func length() -> float:
	return _total


## When the mover arrives (s since the shot).
func end_time() -> float:
	return start + duration


## How far along the path (px) the mover is at shot time t: 0 before start, the whole length
## after the end.
func distance_at(t: float) -> float:
	if duration <= 0.0:
		return _total if t >= start else 0.0
	return _total * clampf((t - start) / duration, 0.0, 1.0)


## Where the mover is at shot time t.
func position_at(t: float) -> Vector2:
	return point_at(distance_at(t))


## The point `d` px along the path.
func point_at(d: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if d <= 0.0 or points.size() == 1:
		return points[0]
	for i in range(1, points.size()):
		if d <= _lengths[i]:
			var seg := _lengths[i] - _lengths[i - 1]
			var k := (d - _lengths[i - 1]) / seg if seg > 0.0 else 1.0
			return points[i - 1].lerp(points[i], k)
	return points[-1]


## The direction the mover heads at shot time t (unit vector; ZERO for a path of one point).
func heading_at(t: float) -> Vector2:
	if points.size() < 2:
		return Vector2.ZERO
	var d := clampf(distance_at(t), 0.0, _total)
	for i in range(1, points.size()):
		if d <= _lengths[i] and points[i] != points[i - 1]:
			return (points[i] - points[i - 1]).normalized()
	return (points[-1] - points[-2]).normalized()


## When (s since the shot) the mover first reaches x along the path; -1 when it never does.
func time_at_x(x: float) -> float:
	if points.is_empty():
		return -1.0
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		if (a.x - x) * (b.x - x) <= 0.0 and a.x != b.x:
			var k := (x - a.x) / (b.x - a.x)
			var d := _lengths[i - 1] + (_lengths[i] - _lengths[i - 1]) * k
			return start + (d / _total * duration if _total > 0.0 else 0.0)
	return start if is_equal_approx(points[0].x, x) else -1.0
