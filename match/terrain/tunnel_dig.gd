extends RefCounted
## A ShotResolved "drill" event (battle-squad docs/contracts/shop-quantity.md §3): the drill bit
## enters the terrain at `position` at time `t` and bores along `path` (the tunnel's centre
## points, first = position, last = to) for `duration` s, a tunnel of `radius` px. The terrain
## mask takes the tunnel bit by bit as the bit bores (the points up to where it is now), so the
## tunnel opens behind it; the mask's version steps once, when it starts (the server counts the
## tunnel as one carve). finish() carves what is left (before the shell's explode, at the end of
## the replay).

const TerrainMask := preload("res://match/terrain/terrain_mask.gd")

var t := 0.0 # when the bit enters (s since the shot)
var duration := 0.0
var radius := 0.0
var path := PackedVector2Array()
var projectile_id := ""
var carved := 0 # points of `path` carved so far


## The dig of a drill event; null when it has no usable path (nor position / to).
static func from_event(e: Dictionary) -> Variant:
	var pts := PackedVector2Array()
	var raw = e.get("path")
	if raw is Array:
		for p in raw:
			if p is Dictionary and _num(p.get("x")) and _num(p.get("y")):
				pts.append(Vector2(float(p["x"]), float(p["y"])))
	if pts.is_empty(): # no path: from the entry to the end
		for key in ["position", "to"]:
			var p = e.get(key)
			if p is Dictionary and _num(p.get("x")) and _num(p.get("y")):
				pts.append(Vector2(float(p["x"]), float(p["y"])))
	if pts.is_empty():
		return null
	var dig = new()
	dig.path = pts
	dig.t = float(e.get("t", 0.0)) if _num(e.get("t")) else 0.0
	dig.duration = maxf(float(e.get("duration", 0.0)) if _num(e.get("duration")) else 0.0, 0.0)
	dig.radius = float(e.get("radius", 0.0)) if _num(e.get("radius")) else 0.0
	dig.projectile_id = str(e.get("projectileId", ""))
	return dig


static func _num(v: Variant) -> bool:
	return v is int or v is float


## Where the bit enters and where it stops.
func entry() -> Vector2:
	return path[0]


func end() -> Vector2:
	return path[-1]


## How many of the path's points the bit has reached `elapsed` s after it entered: the first at
## once, all of them at `duration` (at once without one).
func due(elapsed: float) -> int:
	var n := path.size()
	if duration <= 0.0 or elapsed >= duration:
		return n
	return clampi(int(ceil(maxf(elapsed, 0.0) / duration * n)), 1, n)


## Where the bit is `elapsed` s after it entered, along the path (the last point reached).
func head(elapsed: float) -> Vector2:
	return path[due(elapsed) - 1]


## The version step of the whole tunnel (TerrainMask.carve_tunnel()), then the first point.
func start(mask: TerrainMask) -> void:
	mask.version += 1
	advance(mask, 0.0)


## Carves the points reached `elapsed` s after the bit entered; whether any were carved.
func advance(mask: TerrainMask, elapsed: float) -> bool:
	var n := due(elapsed)
	if n <= carved:
		return false
	mask.carve_tunnel_points(path, radius, carved, n)
	carved = n
	return true


## Carves the rest of the tunnel; whether any was left.
func finish(mask: TerrainMask) -> bool:
	return advance(mask, INF)


func done() -> bool:
	return carved >= path.size()
