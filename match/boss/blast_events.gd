extends RefCounted
## Which explode events of a ShotResolved are a minion's own blast (boss mode v2), so the replay
## draws them as that minion blowing up (its big burst, the body gone) instead of a shell's impact:
## - a detonation: ShotResolved {shooterId: minion, actionMode "self_destruct"}: its explode
##   (the first one without a projectileId) is the shooter's;
## - a death blast: a minion whose type explodes on death dies (die, any cause but its own
##   detonation or boss_defeated) and an explode without a projectileId follows at its position;
##   a minion burnt to death at its turn start blasts in a ShotResolved of its own (actionMode
##   death_blast, shooterId the minion).
## The server's blast explodes name their minion (playerId; radius the crater, blastRadius the
## damage reach): taken as they say, a detonation when it is the shooter's in a self_destruct
## shot. Without the playerId the position decides (an explode's cause is honoured too). Pure: tag() marks each such event with BLAST_KEY = {minion, kind}.

const GameData := preload("res://autoload/game_data_model.gd")

const SELF_DESTRUCT := "self_destruct"
const DEATH_BLAST := "death_blast"
const BOSS_DEFEATED := "boss_defeated"
const BLAST_KEY := "_blast"
const NEAR_PX := 60.0 # an explode this close to a dead minion's feet (plus its body) is its blast


## Marks the blasts among events (BLAST_KEY: {minion: playerId, kind: SELF_DESTRUCT /
## DEATH_BLAST}); returns how many. players: playerId → BattlePlayerState (the positions before the
## shot; falls and teleports in the events move them).
static func tag(events: Array, players: Dictionary, shooter: String, action_mode: String) -> int:
	var pos := {}
	for id in players:
		var p = players[id]
		if p is Dictionary and p.get("position") is Dictionary:
			pos[id] = _vec(p["position"])
	var dying: Array = [] # minions dead in this shot whose blast has not come yet
	var self_left := action_mode == SELF_DESTRUCT and _is_minion(players.get(shooter))
	var n := 0
	for e in events:
		if not e is Dictionary:
			continue
		var id := str(e.get("playerId", ""))
		match str(e.get("type", "")):
			"fall", "teleport":
				if e.get("to") is Dictionary:
					pos[id] = _vec(e["to"])
			"die":
				var cause := str(e.get("cause", ""))
				if _is_minion(players.get(id)) and cause != SELF_DESTRUCT and cause != BOSS_DEFEATED and not (action_mode == SELF_DESTRUCT and id == shooter):
					dying.append(id)
			"explode":
				var tag_of := _explicit(e, players, shooter, action_mode)
				if tag_of.is_empty() and self_left and not e.has("projectileId"):
					tag_of = {"minion": shooter, "kind": SELF_DESTRUCT}
				if tag_of.is_empty() and not e.has("projectileId") and e.get("position") is Dictionary:
					var at := _vec(e["position"])
					var best := ""
					var best_d := INF
					for m in dying:
						if not pos.has(m):
							continue
						var d: float = at.distance_to(pos[m])
						var reach := NEAR_PX + GameData.shot_origin_lift() * _body(players[m])
						if d <= reach and d < best_d:
							best = m
							best_d = d
					if best == "" and dying.size() == 1 and not pos.has(dying[0]):
						best = dying[0]
					if best != "":
						tag_of = {"minion": best, "kind": DEATH_BLAST}
				if tag_of.is_empty():
					continue
				if tag_of["kind"] == SELF_DESTRUCT:
					self_left = false
				dying.erase(tag_of["minion"])
				e[BLAST_KEY] = tag_of
				n += 1
	return n


## The blast an explode event names itself ({} none).
static func _explicit(e: Dictionary, players: Dictionary, shooter: String, action_mode: String) -> Dictionary:
	var cause := str(e.get("cause", ""))
	var id := str(e.get("playerId", ""))
	if id == "" and cause == SELF_DESTRUCT:
		id = shooter
	if id == "" or not _is_minion(players.get(id)):
		return {}
	if cause == SELF_DESTRUCT or cause == DEATH_BLAST:
		return {"minion": id, "kind": cause}
	return {"minion": id, "kind": SELF_DESTRUCT if id == shooter and action_mode == SELF_DESTRUCT else DEATH_BLAST}


## The blast of an explode event tagged by tag() ({} none).
static func blast_of(e: Dictionary) -> Dictionary:
	var b = e.get(BLAST_KEY)
	return b if b is Dictionary else {}


## The time (s) of the shot's detonation (the shooter's own blast), -1 when none.
static func detonation_time(events: Array) -> float:
	for e in events:
		if e is Dictionary and str(blast_of(e).get("kind", "")) == SELF_DESTRUCT:
			return float(e.get("t", 0.0))
	return -1.0


static func _is_minion(p: Variant) -> bool:
	return p is Dictionary and str(p.get("role", "")) == "minion"


static func _body(p: Dictionary) -> float:
	var v = p.get("bodySize")
	return float(v) if (v is int or v is float) and v > 0 else GameData.body_size_of(GameData.boss_unit(p))


static func _vec(d: Dictionary) -> Vector2:
	return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
