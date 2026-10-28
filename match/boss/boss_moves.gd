extends RefCounted
## Boss v5's movers along a ShotResolved ground path, on the replay's own clock (ShotPlayer time):
## the crab walking to its pincer grab (`move`), the member the tree's roots drag (`pull`), the
## rolling boulder (`roll`). Each frame match_screen calls sync(t): a unit's view is put on the
## path point of that time (PlayerView.move_to(p, 0): its walk / tween / flight end, it faces
## and steps the way it goes), a free node (the boulder) is moved and turned as it rolls
## (set_roll(distance) when it has one). finish() puts everything on its path's end (the replay
## ended or was cut short) and forgets them. The server's state is already the outcome (the
## views' players are set to `to` when the event comes).

const PathMotion := preload("res://match/shot/path_motion.gd")

var _items: Array = [] # [{node, motion, offset}]


## Moves node along the path event e from its t for its duration; offset is added to every point
## (a body drawn off its feet).
func add(node: Node2D, e: Dictionary, offset: Vector2 = Vector2.ZERO) -> PathMotion:
	var m := PathMotion.new(e)
	if node == null or m.points.is_empty():
		return m
	for it in _items: # a second path for the same node replaces the first
		if it["node"] == node:
			_items.erase(it)
			break
	_items.append({"node": node, "motion": m, "offset": offset})
	_place(_items[-1], m.start)
	return m


func sync(t: float) -> void:
	for it in _items.duplicate():
		if not is_instance_valid(it["node"]):
			_items.erase(it)
			continue
		_place(it, t)


## Everything on its path's end; nothing left to move.
func finish() -> void:
	for it in _items:
		if is_instance_valid(it["node"]):
			_place(it, INF)
	_items.clear()


## The movers still on a path (tests).
func count() -> int:
	return _items.size()


func _place(it: Dictionary, t: float) -> void:
	var m: PathMotion = it["motion"]
	var node: Node2D = it["node"]
	var tt := m.end_time() if t == INF else t
	var p: Vector2 = m.position_at(tt) + it["offset"]
	if node.has_method("set_roll"):
		node.position = p
		node.set_roll(m.distance_at(tt), m.heading_at(tt))
	elif node.has_method("move_to"):
		if node.position != p:
			node.move_to(p, 0.0)
	else:
		node.position = p
