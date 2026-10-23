extends RefCounted
## Which leaping snowmen are about to blow up (boss mode v3), pure: a leaper (behavior "leaper")
## that jumped next to a party member (UnitJumped) carries `leapt: true` on its state until the
## end of its next turn, when it detonates if it is still near someone (the minion blast) or else
## leaps again. The client marks it from the UnitJumped at once, takes `leapt` from every state
## it gets (MatchStarted / MatchStateSync, ItemUsed players), and clears it when the turn after
## the leap ends without a new leap, or the snowman dies. warning(id): it glows and pulses.

var _leapt := {} # playerId -> the turn index it leapt in (-1: before what this client saw)


## UnitJumped for id during turn turn_index.
func on_jump(id: String, turn_index: int) -> void:
	if id != "":
		_leapt[id] = turn_index


## A full state of a player (its leapt field: the server leaves it out when false); turn_index /
## current: the state's turn and its player (a leaper whose own turn it is leapt in it).
func on_state(id: String, p: Variant, turn_index: int, current: String) -> void:
	if not p is Dictionary:
		return
	var v = p.get("leapt")
	if v != true or p.get("isAlive") == false:
		_leapt.erase(id)
	elif not _leapt.has(id):
		_leapt[id] = turn_index if id == current else -1


## The turn turn_index of player id ended (a new TurnStarted): its leap is spent unless it leapt
## in that very turn. Returns whether its warning went off.
func on_turn_end(id: String, turn_index: int) -> bool:
	if not _leapt.has(id) or int(_leapt[id]) == turn_index:
		return false
	_leapt.erase(id)
	return true


## It died (or blew up).
func clear(id: String) -> bool:
	return _leapt.erase(id)


func warning(id: String) -> bool:
	return _leapt.has(id)


func ids() -> Array:
	return _leapt.keys()
