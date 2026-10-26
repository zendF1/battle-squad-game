extends RefCounted
## The boss's eruption marks without UI (match/boss/mark_view.gd draws them; boss v4, Khổng Lồ Đá's
## Gai đá trồi): each mark {markId, playerId (the member it was put under), position (their feet at
## the cast; it does not follow them), radius, skill_id, round} waits on the ground until the start
## of its owner's next turn, when it erupts. The server's lists are the truth: MatchStarted /
## MatchStateSync boss.marks and TurnStarted marks replace them (set_all(); a boss snapshot without
## the key has none); between them the cast's ShotResolved mark events add one at once (add_event())
## and the turn start's eruption events take theirs away (erupt()). The boss's death clears them
## (clear(); the next MatchStateSync shows marks: []).

var marks := {} # markId -> mark


static func _num(v: Variant, fallback: float = 0.0) -> float:
	return float(v) if v is int or v is float else fallback


static func _vec(v: Variant) -> Vector2:
	if v is Dictionary:
		return Vector2(_num(v.get("x")), _num(v.get("y")))
	return Vector2.ZERO


## A mark payload (the state's or a mark event's) → {markId, playerId, position: Vector2, radius,
## skill_id, round}; {} without an id.
static func parse(m: Variant) -> Dictionary:
	if not m is Dictionary or str(m.get("markId", "")) == "":
		return {}
	return {"markId": str(m["markId"]), "playerId": str(m.get("playerId", "")), "position": _vec(m.get("position")),
		"radius": maxf(_num(m.get("radius")), 0.0), "skill_id": str(m.get("skillId", "")), "round": int(_num(m.get("round")))}


## Replaces the marks with a server list; returns {added: [ids], removed: [ids]} (kept ones in
## neither). Not a list (an older server, a payload without marks): nothing changes.
func set_all(list: Variant) -> Dictionary:
	if not list is Array:
		return {"added": [], "removed": []}
	var next := {}
	for m in list:
		var p := parse(m)
		if not p.is_empty():
			next[p["markId"]] = p
	var added: Array = []
	var removed: Array = []
	for id in next:
		if not marks.has(id):
			added.append(id)
	for id in marks:
		if not next.has(id):
			removed.append(id)
	marks = next
	added.sort()
	removed.sort()
	return {"added": added, "removed": removed}


## A mark event of the cast (boss round at_round): the new mark ({} without an id or already known).
func add_event(e: Variant, at_round: int = 0) -> Dictionary:
	var m := parse(e)
	if m.is_empty() or marks.has(m["markId"]):
		return {}
	if not (e.get("round") is int or e.get("round") is float):
		m["round"] = at_round
	marks[m["markId"]] = m
	return m


## An eruption event: its mark is gone; returns it ({} when it was not held).
func erupt(mark_id: String) -> Dictionary:
	var m: Dictionary = marks.get(mark_id, {})
	marks.erase(mark_id)
	return m


## Every mark gone (the boss died); returns their ids.
func clear() -> Array:
	var gone := ids()
	marks.clear()
	return gone


func has(mark_id: String) -> bool:
	return marks.has(mark_id)


func ids() -> Array:
	var out := marks.keys()
	out.sort()
	return out


func size() -> int:
	return marks.size()


## The mark a body at feet stands in ({} none): within its radius of the centre.
func mark_at(feet: Vector2) -> Dictionary:
	for id in ids():
		var m: Dictionary = marks[id]
		if feet.distance_to(m["position"]) <= float(m["radius"]):
			return m
	return {}
