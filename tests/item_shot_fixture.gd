extends RefCounted
## ShotResolved payloads of the five shot items in the shapes of the server contract
## (battle-squad docs/contracts/boss-tiers-items.md §3), flown on a real server flight: the rain
## skill's flare from tests/fixtures/skill_shots.json (rookie on grassland_valley, landing by e2).
## The fan's side shells re-fly that flight's start turned by the spread under the same
## acceleration, landing on the fixture's terrain. For tests and smoke runs only.

const FIXTURE := "res://tests/fixtures/skill_shots.json"
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")

const DT := 0.06


## The rain case: {mapId, shooter, players, terrain, terrainAfter, shot}.
static func base() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))["rain"]


## A MatchState-like snapshot of the fixture (rookie's turn).
static func snapshot() -> Dictionary:
	var b := base()
	return {"players": b["players"], "terrain": b["terrain"], "currentPlayerId": "rookie", "turnIndex": 3, "mapId": b["mapId"],
		"wind": {"direction": 0, "strength": 0}, "turnTimeLeft": 20}


static func flight() -> Array:
	return base()["shot"]["projectiles"][0]["path"].duplicate(true)


static func _end(path: Array) -> Dictionary:
	return path[-1]["position"]


static func _shift(path: Array, dt: float) -> Array:
	var out := path.duplicate(true)
	for s in out:
		s["time"] = float(s["time"]) + dt
	return out


## The flight's start velocity turned by `deg` (positive: higher), flown under the flight's own
## acceleration until it meets the fixture's terrain.
static func fan_path(deg: float) -> Array:
	var path := flight()
	var mask := TerrainMask.new()
	mask.load_snapshot(base()["terrain"])
	var p0 := Vector2(float(path[0]["position"]["x"]), float(path[0]["position"]["y"]))
	var v0 := Vector2(float(path[0]["velocity"]["x"]), float(path[0]["velocity"]["y"]))
	var v1 := Vector2(float(path[1]["velocity"]["x"]), float(path[1]["velocity"]["y"]))
	var acc := (v1 - v0) / (float(path[1]["time"]) - float(path[0]["time"]))
	var v := v0.rotated(-deg_to_rad(deg))
	var p := p0
	var out: Array = [{"position": {"x": p.x, "y": p.y}, "velocity": {"x": v.x, "y": v.y}, "time": 0.0}]
	var t := 0.0
	for i in 200:
		v += acc * DT
		p += v * DT
		t += DT
		out.append({"position": {"x": p.x, "y": p.y}, "velocity": {"x": v.x, "y": v.y}, "time": t})
		if p.y >= mask.height or (t > 0.2 and mask.is_solid(p.x, p.y)):
			break
	return out


static func _projectile(id: String, path: Array, extra: Dictionary = {}) -> Dictionary:
	var p := {"projectileId": id, "ownerPlayerId": "rookie", "path": path, "explosionPoint": _end(path), "explosionRadius": 40,
		"craterRadius": 18}
	p.merge(extra, true)
	return p


static func _explode(id: String, path: Array, version: int) -> Dictionary:
	return {"t": float(path[-1]["time"]), "type": "explode", "projectileId": id, "position": _end(path), "radius": 18,
		"crater": "bowl", "terrainVersion": version}


static func _damage(t: float, id: String, pid: String, amount: int, hp: int) -> Dictionary:
	var d := {"t": t, "type": "damage", "playerId": id, "amount": amount, "hp": hp, "cause": "explosion"}
	if pid != "":
		d["projectileId"] = pid
	return d


static func poison() -> Dictionary:
	var path := flight()
	var t := float(path[-1]["time"])
	return {"shooterId": "rookie", "actionMode": "item", "itemId": "poison_bomb", "projectiles": [_projectile("a1", path)],
		"events": [_explode("a1", path, 1), _damage(t, "e2", "a1", 410, 840),
			{"t": t, "type": "status", "playerId": "e2", "effectId": "poison", "turns": 2}], "duration": t}


static func double() -> Dictionary:
	var a := flight()
	var b := _shift(flight(), 0.25)
	var ta := float(a[-1]["time"])
	var tb := float(b[-1]["time"])
	return {"shooterId": "rookie", "actionMode": "item", "itemId": "double_shot",
		"projectiles": [_projectile("b1", a), _projectile("b2", b, {"launchDelay": 0.25})],
		"events": [_explode("b1", a, 1), _damage(ta, "e2", "b1", 300, 950), _explode("b2", b, 2), _damage(tb, "e2", "b2", 290, 660)],
		"duration": tb}


static func triple() -> Dictionary:
	var paths := [fan_path(-5.0), flight(), fan_path(5.0)]
	var projectiles: Array = []
	var events: Array = []
	var order := [0, 1, 2]
	order.sort_custom(func(i, j): return float(paths[i][-1]["time"]) < float(paths[j][-1]["time"]))
	var v := 1
	for i in order:
		var id := "c%d" % (i + 1)
		events.append(_explode(id, paths[i], v))
		v += 1
	for i in paths.size():
		projectiles.append(_projectile("c%d" % (i + 1), paths[i]))
	var end := 0.0
	for p in paths:
		end = maxf(end, float(p[-1]["time"]))
	return {"shooterId": "rookie", "actionMode": "item", "itemId": "triple_shot", "projectiles": projectiles, "events": events,
		"duration": end}


## The nuke: the signal, the strike, the bomb falling from y startY at dropSpeed (0.05 s samples).
static func nuke() -> Dictionary:
	var sig := flight()
	var t0 := float(sig[-1]["time"])
	var at: Dictionary = _end(sig)
	var start := t0 + 0.5
	var fall: Array = []
	var y := -80.0
	var t := start
	while y < float(at["y"]):
		fall.append({"position": {"x": at["x"], "y": y}, "velocity": {"x": 0, "y": 1600}, "time": t})
		y += 1600.0 * 0.05
		t += 0.05
	t = start + (float(at["y"]) + 80.0) / 1600.0
	fall.append({"position": at, "velocity": {"x": 0, "y": 1600}, "time": t})
	return {"shooterId": "rookie", "actionMode": "item", "itemId": "nuke_bomb",
		"projectiles": [_projectile("n1", sig, {"kind": "signal", "explosionRadius": 0, "craterRadius": 0}),
			_projectile("n2", fall, {"kind": "nuke", "launchDelay": start, "explosionRadius": 100, "craterRadius": 45})],
		"events": [{"t": t0, "type": "strike", "kind": "nuke", "itemId": "nuke_bomb", "position": at, "radius": 100, "duration": t - t0},
			{"t": t, "type": "explode", "projectileId": "n2", "position": at, "radius": 45, "crater": "bowl", "terrainVersion": 1},
			_damage(t, "e2", "n2", 760, 490), _damage(t, "e1", "n2", 380, 1270)], "duration": t + 0.3}


static func laser() -> Dictionary:
	var sig := flight()
	var t0 := float(sig[-1]["time"])
	var at: Dictionary = _end(sig)
	return {"shooterId": "rookie", "actionMode": "item", "itemId": "laser_strike",
		"projectiles": [_projectile("l1", sig, {"kind": "signal", "explosionRadius": 0, "craterRadius": 0, "hitPlayerId": "e2"})],
		"events": [{"t": t0, "type": "strike", "kind": "laser", "itemId": "laser_strike", "position": at, "radius": 40, "beams": 5,
			"duration": 0.8},
			{"t": t0 + 0.8, "type": "explode", "position": at, "radius": 5.4, "crater": "bowl", "terrainVersion": 1},
			_damage(t0 + 0.8, "e2", "", 620, 630)], "duration": t0 + 0.8}
