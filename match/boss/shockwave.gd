extends RefCounted
## A boss's ground shockwave (boss mode v3: Cua Dung Nham's Cú kẹp đập), pure: the server sends
## an explode at the boss (the slam), then explodes stepping outward along the ground both ways to
## the map edges (about every 150 px, about 0.08 s apart). detect() finds them in a boss shot's
## events: the slam is the first explode without a projectileId (nor a minion's blast), the steps
## every later such explode, split into the left and right side and ordered outward; a wave needs
## at least MIN_STEPS steps moving away from the slam as time goes on. front() is where a side's
## ripple is at time t (along the steps, linearly between them), so the drawing reaches each step
## when its explode comes. Nothing is simulated: positions and times are the server's.

const BlastEvents := preload("res://match/boss/blast_events.gd")

const MIN_STEPS := 2
const STEP_KEY := "_wave_step" # set on a step's explode event (match_screen draws dust, not a blast)


## The wave in events ({} none): {origin: Vector2, t0, left: [[pos, t]...], right: [...]} with
## each side ordered outward. mark: tag every step's event with STEP_KEY.
static func detect(events: Array, mark: bool = false) -> Dictionary:
	var slam := {}
	var steps: Array = []
	for e in events:
		if not e is Dictionary or str(e.get("type", "")) != "explode" or e.has("projectileId") or not e.get("position") is Dictionary:
			continue
		if not BlastEvents.blast_of(e).is_empty():
			continue
		if slam.is_empty():
			slam = e
		else:
			steps.append(e)
	if slam.is_empty() or steps.size() < MIN_STEPS:
		return {}
	var o := _vec(slam["position"])
	var t0 := float(slam.get("t", 0.0))
	var left: Array = []
	var right: Array = []
	for e in steps:
		var p := _vec(e["position"])
		var item := [p, float(e.get("t", t0)), e]
		if p.x < o.x - 1.0:
			left.append(item)
		elif p.x > o.x + 1.0:
			right.append(item)
	left.sort_custom(func(a, b): return a[0].x > b[0].x)
	right.sort_custom(func(a, b): return a[0].x < b[0].x)
	if left.size() + right.size() < MIN_STEPS or not _outward(left, t0) or not _outward(right, t0):
		return {}
	if mark:
		for item in left + right:
			item[2][STEP_KEY] = true
	return {"origin": o, "t0": t0, "left": left.map(func(i): return [i[0], i[1]]), "right": right.map(func(i): return [i[0], i[1]])}


## A side's steps come later the farther out they are.
static func _outward(side: Array, t0: float) -> bool:
	var last := t0
	for item in side:
		if float(item[1]) + 1e-6 < last:
			return false
		last = float(item[1])
	return true


## Where a side's ripple front is at time t: the slam's point before t0, then along the steps
## (linear between their points and times), the last step's point after it.
static func front(wave: Dictionary, side: String, t: float) -> Vector2:
	var pts: Array = [[wave["origin"], float(wave["t0"])]] + wave.get(side, [])
	if t <= float(pts[0][1]):
		return pts[0][0]
	for i in range(1, pts.size()):
		var a: Array = pts[i - 1]
		var b: Array = pts[i]
		if t <= float(b[1]):
			var span := float(b[1]) - float(a[1])
			var k := (t - float(a[1])) / span if span > 1e-6 else 1.0
			return a[0].lerp(b[0], k)
	return pts[pts.size() - 1][0]


## When a side's front reaches its last step (the edge).
static func end_time(wave: Dictionary, side: String) -> float:
	var s: Array = wave.get(side, [])
	return float(s[s.size() - 1][1]) if not s.is_empty() else float(wave.get("t0", 0.0))


## How far the wave reaches on both sides: [leftmost x, rightmost x].
static func reach(wave: Dictionary) -> Array:
	var lo: float = wave["origin"].x
	var hi: float = wave["origin"].x
	for item in wave.get("left", []):
		lo = minf(lo, item[0].x)
	for item in wave.get("right", []):
		hi = maxf(hi, item[0].x)
	return [lo, hi]


static func _vec(d: Dictionary) -> Vector2:
	return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
