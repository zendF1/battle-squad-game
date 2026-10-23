extends RefCounted
## A leaping snowman's jump (boss mode v3, server UnitJumped {playerId, from {x,y}, to {x,y},
## duration, height}: height is the arc's apex above the higher end; the server's position is
## `to`), pure: over the first CROUCH share of the duration the body crouches at `from` (squashed),
## then flies a ballistic arc (x linear in time, y a parabola through both ends whose top is
## `height` above the higher one) to `to`, stretched along the flight while fast; once it lands a
## LAND_SEC squash settles back. It answers what PlayerView asks of a flight (step(), done(), t,
## to, lean_at()) so the same hold and camera follow work for it.

const CROUCH := 0.14 # share of the duration crouching before the take-off
const LAND_SEC := 0.22 # s of the landing squash after it lands
const SQUASH := 0.26 # the crouch / landing squash (x wider, y shorter by this at the deepest)
const STRETCH := 0.2 # the stretch in the air at the fastest (y longer, x thinner)
const MIN_SEC := 0.05
const DEFAULT_HEIGHT := 90.0 # px when the event gives none

var from := Vector2.ZERO
var to := Vector2.ZERO
var duration := 0.0
var height := DEFAULT_HEIGHT
var t := 0.0


func _init(from_pos: Vector2 = Vector2.ZERO, to_pos: Vector2 = Vector2.ZERO, sec: float = 0.0, apex: float = DEFAULT_HEIGHT) -> void:
	from = from_pos
	to = to_pos
	duration = maxf(sec, 0.0)
	height = maxf(apex, 0.0)


## A jump from a UnitJumped payload (null without from / to).
static func from_event(e: Dictionary) -> Variant:
	if not e.get("from") is Dictionary or not e.get("to") is Dictionary:
		return null
	var a := Vector2(float(e["from"].get("x", 0.0)), float(e["from"].get("y", 0.0)))
	var b := Vector2(float(e["to"].get("x", 0.0)), float(e["to"].get("y", 0.0)))
	var d = e.get("duration")
	var h = e.get("height")
	return new(a, b, float(d) if d is int or d is float else 0.0, float(h) if h is int or h is float else DEFAULT_HEIGHT)


func step(delta: float) -> Vector2:
	t = minf(t + maxf(delta, 0.0), duration)
	return position_at(t)


func done() -> bool:
	return duration < MIN_SEC or t >= duration


## The air part of the jump at time s: 0 at the take-off, 1 on landing (linear in time; 0 while
## crouching).
func air(s: float) -> float:
	if duration < MIN_SEC:
		return 1.0
	var start := duration * CROUCH
	return clampf((s - start) / maxf(duration - start, 1e-3), 0.0, 1.0)


## The arc's top: `height` above the higher end (smaller y), screen y.
func apex_y() -> float:
	return minf(from.y, to.y) - height


## Where the body is at time s: at from while crouching, then on the parabola through from, the
## apex and to.
func position_at(s: float) -> Vector2:
	var u := air(s)
	var x := lerpf(from.x, to.x, u)
	# y(u) = a u^2 + b u + c with y(0) = from.y, y(1) = to.y and its minimum apex_y()
	return Vector2(x, _arc_y(u))


func _arc_y(u: float) -> float:
	var y0 := from.y
	var y1 := to.y
	var top := apex_y()
	# the vertex at u* where the parabola touches top: solve with h0 = y0 - top, h1 = y1 - top
	var h0 := maxf(y0 - top, 0.0)
	var h1 := maxf(y1 - top, 0.0)
	var r0 := sqrt(h0)
	var r1 := sqrt(h1)
	var us := r0 / (r0 + r1) if r0 + r1 > 1e-6 else 0.5
	var a := h0 / (us * us) if us > 1e-6 else h1 / maxf((1.0 - us) * (1.0 - us), 1e-6)
	return top + a * (u - us) * (u - us)


## The share of the air time at the apex (0..1).
func apex_share() -> float:
	var r0 := sqrt(maxf(from.y - apex_y(), 0.0))
	var r1 := sqrt(maxf(to.y - apex_y(), 0.0))
	return r0 / (r0 + r1) if r0 + r1 > 1e-6 else 0.5


## The body's squash and stretch at time s (a scale round its feet): crouching wider and
## shorter, stretched tall and thin while it flies fast (most at the take-off and the landing,
## round at the apex).
func scale_at(s: float) -> Vector2:
	if duration < MIN_SEC:
		return Vector2.ONE
	var start := duration * CROUCH
	if s < start:
		var k := sin(PI * clampf(s / maxf(start, 1e-3), 0.0, 1.0) * 0.5) # down into the crouch
		return Vector2(1.0 + SQUASH * k, 1.0 - SQUASH * k)
	var u := air(s)
	var speed := absf(u - apex_share()) / maxf(apex_share(), 1.0 - apex_share()) # 0 at the apex, 1 at the ends
	var k := STRETCH * speed
	return Vector2(1.0 - k * 0.6, 1.0 + k)


## The landing squash `since` s after it landed (ONE after LAND_SEC).
static func land_scale(since: float) -> Vector2:
	if since < 0.0 or since >= LAND_SEC:
		return Vector2.ONE
	var k := sin(PI * since / LAND_SEC) # in and back out
	return Vector2(1.0 + SQUASH * k, 1.0 - SQUASH * k)


## No lean: it jumps upright (PlayerView asks every flight).
func lean_at(_s: float) -> float:
	return 0.0
