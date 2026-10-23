extends RefCounted
## The beams of one boss shot (boss mode v3), pure geometry: a ShotResolved may carry many beam
## events at the same t, each {playerId, from, to, duration}:
## - Phù Thuỷ Băng's Tia băng: a radial burst, every beam from her body centre out to the map
##   bounds, evenly spaced (20 beams, every 18°);
## - Rô-bốt Thép's Tia laze nghiền: parallel horizontal beams across the whole map width.
## beams() reads them from the events, layout() says which shape they make (single / radial /
## parallel / multi) with the shared origin and the even spacing, ray_to_bounds() is where a ray
## from inside the map meets its bounds (the server's beamEnd), nearest_beam() the beam a hit body
## is on (its flash), bounds() the box the camera frames. Nothing is simulated here: the beams,
## their hits and timing are the server's.

const SINGLE := "single"
const RADIAL := "radial" # every beam from one point, outwards
const PARALLEL := "parallel" # every beam along one direction, side by side
const MULTI := "multi" # anything else with more than one beam

const SAME_PX := 6.0 # two beam starts this close are the same origin
const SAME_DEG := 2.0 # two directions this close are parallel / one step of an even fan


## The beam events of a timeline's events, in order: [{from, to, t, duration, dir, length}].
static func beams(events: Array) -> Array:
	var out: Array = []
	for e in events:
		if not e is Dictionary or str(e.get("type", "")) != "beam":
			continue
		if not e.get("from") is Dictionary or not e.get("to") is Dictionary:
			continue
		var a := _vec(e["from"])
		var b := _vec(e["to"])
		var d := b - a
		out.append({"from": a, "to": b, "t": _num(e.get("t"), 0.0), "duration": _num(e.get("duration"), 0.0),
			"dir": d.normalized() if d.length() > 0.01 else Vector2.RIGHT, "length": d.length()})
	return out


## The shape the beams make: {kind, count, origin (RADIAL: the shared start), spacing (degrees
## between neighbours when RADIAL and even, else -1), dir (PARALLEL: the shared direction)}.
static func layout(list: Array) -> Dictionary:
	var out := {"kind": SINGLE if list.size() == 1 else MULTI, "count": list.size(), "origin": Vector2.ZERO, "spacing": -1.0,
		"dir": Vector2.RIGHT}
	if list.is_empty():
		out["kind"] = ""
		return out
	out["origin"] = list[0]["from"]
	out["dir"] = list[0]["dir"]
	if list.size() == 1:
		return out
	var shared := true
	var parallel := true
	for b in list:
		if b["from"].distance_to(list[0]["from"]) > SAME_PX:
			shared = false
		if absf(rad_to_deg(b["dir"].angle_to(list[0]["dir"]))) > SAME_DEG:
			parallel = false
	if shared:
		out["kind"] = RADIAL
		out["spacing"] = even_spacing(list)
	elif parallel:
		out["kind"] = PARALLEL
	return out


## The beams' directions as angles (degrees 0..360, 0 right, 90 down: screen y), sorted.
static func angles(list: Array) -> Array:
	var out: Array = []
	for b in list:
		out.append(fposmod(rad_to_deg(b["dir"].angle()), 360.0))
	out.sort()
	return out


## The angle between neighbouring beams when they are evenly spaced all round (within SAME_DEG),
## else -1.
static func even_spacing(list: Array) -> float:
	var a := angles(list)
	if a.size() < 2:
		return -1.0
	var step := 360.0 / a.size()
	for i in a.size():
		var gap: float = (a[(i + 1) % a.size()] - a[i]) if i + 1 < a.size() else (a[0] + 360.0 - a[i])
		if absf(gap - step) > SAME_DEG:
			return -1.0
	return step


## Where a ray from origin (inside the map) along dir leaves the map rect (0,0)..size.
static func ray_to_bounds(origin: Vector2, dir: Vector2, size: Vector2) -> Vector2:
	var d := dir.normalized()
	var best := INF
	if d.x > 1e-6:
		best = minf(best, (size.x - origin.x) / d.x)
	elif d.x < -1e-6:
		best = minf(best, -origin.x / d.x)
	if d.y > 1e-6:
		best = minf(best, (size.y - origin.y) / d.y)
	elif d.y < -1e-6:
		best = minf(best, -origin.y / d.y)
	if best == INF:
		return origin
	return origin + d * maxf(best, 0.0)


## A radial burst of n beams from origin out to the map bounds, the first at start_deg (degrees,
## screen convention), evenly spaced: the shape the server sends (tests, previews).
static func radial(origin: Vector2, n: int, size: Vector2, start_deg: float = 0.0) -> Array:
	var out: Array = []
	for i in n:
		var d := Vector2.from_angle(deg_to_rad(start_deg + 360.0 * i / maxf(n, 1)))
		out.append({"from": origin, "to": ray_to_bounds(origin, d, size), "dir": d})
	return out


## The index of the beam nearest to p (its segment), -1 when none.
static func nearest_beam(list: Array, p: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in list.size():
		var b: Dictionary = list[i]
		var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, b["from"], b["to"]))
		if d < best_d:
			best_d = d
			best = i
	return best


## The point of beam b nearest to p.
static func on_beam(b: Dictionary, p: Vector2) -> Vector2:
	return Geometry2D.get_closest_point_to_segment(p, b["from"], b["to"])


## The box round every beam (the camera frames it).
static func bounds(list: Array) -> Rect2:
	if list.is_empty():
		return Rect2()
	var r := Rect2(list[0]["from"], Vector2.ZERO)
	for b in list:
		r = r.expand(b["from"]).expand(b["to"])
	return r


## Distinct beam starts (merged within SAME_PX): where the charges glow.
static func origins(list: Array) -> Array:
	var out: Array = []
	for b in list:
		var known := false
		for o in out:
			if o.distance_to(b["from"]) <= SAME_PX:
				known = true
				break
		if not known:
			out.append(b["from"])
	return out


static func _vec(d: Dictionary) -> Vector2:
	return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))


static func _num(v: Variant, fallback: float) -> float:
	return float(v) if v is int or v is float else fallback
