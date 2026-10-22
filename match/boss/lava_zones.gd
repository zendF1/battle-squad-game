extends RefCounted
## The boss's lava pools without UI (match/boss/lava_view.gd draws them): each a zone {zoneId,
## position, radius, damage, expires_round} that burns a party member standing in it at turn
## start and dries up after the boss's turn number expires_round. The server's lists are the truth:
## MatchStarted / MatchStateSync / TurnStarted lavaZones replace them (set_all(); a boss match's
## snapshot without the key has none); between them a fire bomb's ShotResolved lava event {zoneId,
## position, radius, amount, turns} adds one at once (add_event(), expiring turns rounds after the
## current one, as the server counts). expire(round) drops what the end of boss turn `round` dries.

var zones := {} # zoneId -> zone


static func _num(v: Variant, fallback: float = 0.0) -> float:
	return float(v) if v is int or v is float else fallback


static func _vec(v: Variant) -> Vector2:
	if v is Dictionary:
		return Vector2(_num(v.get("x")), _num(v.get("y")))
	return Vector2.ZERO


## A LavaZone payload → {zoneId, position: Vector2, radius, damage, expires_round}; {} without an id.
static func parse(z: Variant) -> Dictionary:
	if not z is Dictionary or str(z.get("zoneId", "")) == "":
		return {}
	return {"zoneId": str(z["zoneId"]), "position": _vec(z.get("position")), "radius": maxf(_num(z.get("radius")), 0.0),
		"damage": int(_num(z.get("damage"))), "expires_round": int(_num(z.get("expiresRound")))}


## Replaces the zones with a server list; returns {added: [ids], removed: [ids]} (kept ones in
## neither).
func set_all(list: Variant) -> Dictionary:
	var next := {}
	if list is Array:
		for z in list:
			var p := parse(z)
			if not p.is_empty():
				next[p["zoneId"]] = p
	var added: Array = []
	var removed: Array = []
	for id in next:
		if not zones.has(id):
			added.append(id)
	for id in zones:
		if not next.has(id):
			removed.append(id)
	zones = next
	added.sort()
	removed.sort()
	return {"added": added, "removed": removed}


## A ShotResolved lava event during boss turn `round`: the new zone ({} when it has no id or is
## already known).
func add_event(e: Variant, at_round: int) -> Dictionary:
	if not e is Dictionary:
		return {}
	var id := str(e.get("zoneId", ""))
	if id == "" or zones.has(id):
		return {}
	var z := {"zoneId": id, "position": _vec(e.get("position")), "radius": maxf(_num(e.get("radius")), 0.0),
		"damage": int(_num(e.get("amount"))), "expires_round": at_round + int(_num(e.get("turns"), 1.0))}
	zones[id] = z
	return z


## The end of boss turn `round`: the zones expiring by then dry up; returns their ids.
func expire(at_round: int) -> Array:
	var gone: Array = []
	for id in zones:
		if int(zones[id]["expires_round"]) <= at_round:
			gone.append(id)
	for id in gone:
		zones.erase(id)
	gone.sort()
	return gone


## The zone a party member at `feet` stands in ({} none), as the server checks it (|dx| ≤ radius,
## |dy| ≤ height_px).
func zone_at(feet: Vector2, height_px: float = 60.0) -> Dictionary:
	for id in zones:
		var z: Dictionary = zones[id]
		if absf(feet.x - z["position"].x) <= z["radius"] and absf(feet.y - z["position"].y) <= height_px:
			return z
	return {}


func ids() -> Array:
	var out := zones.keys()
	out.sort()
	return out
