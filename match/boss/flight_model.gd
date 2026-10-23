extends RefCounted
## A flying unit's flight (server UnitFlew {playerId, from {x,y}, to {x,y}, duration}: a drone or
## the witch moving through the air, the server's position is `to`): drawn from → to over
## duration with an ease in and out and a slight arc up in the middle (ARC_PER_PX of the distance,
## at most ARC_MAX px), so it glides rather than slides. Pure: step() / position_at() / lean_at()
## give where the body is and how it leans into the flight (radians, the side it flies to).

const ARC_PER_PX := 0.12
const ARC_MAX := 46.0
const LEAN_MAX := 0.22 # rad, at the fastest point of the flight
const MIN_SEC := 0.05

var from := Vector2.ZERO
var to := Vector2.ZERO
var duration := 0.0
var t := 0.0


func _init(from_pos: Vector2 = Vector2.ZERO, to_pos: Vector2 = Vector2.ZERO, sec: float = 0.0) -> void:
	from = from_pos
	to = to_pos
	duration = maxf(sec, 0.0)


## A flight from a UnitFlew payload (null without from / to); no duration: a jump.
static func from_event(e: Dictionary) -> Variant:
	if not e.get("from") is Dictionary or not e.get("to") is Dictionary:
		return null
	var a := Vector2(float(e["from"].get("x", 0.0)), float(e["from"].get("y", 0.0)))
	var b := Vector2(float(e["to"].get("x", 0.0)), float(e["to"].get("y", 0.0)))
	var d = e.get("duration")
	return new(a, b, float(d) if d is int or d is float else 0.0)


## Advances the flight by delta s; returns the position now.
func step(delta: float) -> Vector2:
	t = minf(t + maxf(delta, 0.0), duration)
	return position_at(t)


func done() -> bool:
	return duration < MIN_SEC or t >= duration


## The share of the way covered at time s (0..1, eased in and out).
func progress(s: float) -> float:
	if duration < MIN_SEC:
		return 1.0
	var k := clampf(s / duration, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## The arc's height (px) over the straight line in the middle of the flight.
func arc_height() -> float:
	return minf(from.distance_to(to) * ARC_PER_PX, ARC_MAX)


## Where the body is at time s: on the eased line from → to, lifted by the arc (0 at both ends).
func position_at(s: float) -> Vector2:
	var p := progress(s)
	return from.lerp(to, p) + Vector2(0, -arc_height() * 4.0 * p * (1.0 - p))


## The lean into the flight at time s (radians: positive leaning right, flying right), strongest
## at the fastest point, 0 at both ends.
func lean_at(s: float) -> float:
	if duration < MIN_SEC or absf(to.x - from.x) < 1.0:
		return 0.0
	var k := clampf(s / duration, 0.0, 1.0)
	var speed := 6.0 * k * (1.0 - k) / 1.5 # the eased speed, 1 at the middle
	return signf(to.x - from.x) * LEAN_MAX * speed * clampf(absf(to.x - from.x) / 160.0, 0.0, 1.0)
