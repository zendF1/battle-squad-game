extends RefCounted
## Predicts the local player's walk, so the character moves on the frame the button is held,
## and decides which Move commands to send.
##
## Each command is modelled exactly as the server's processMove handles it:
##   1. clamp the target to moveEnergy * 2 px from the server's position;
##   2. walk with Terrain.WalkTo;
##   3. charge round(|dx| * 0.5) energy, capped at what is left.
##
## The walk is cut into segments that each go in one direction. Each segment becomes one
## Move{targetX, seq}; its target is the segment's end, so the server walks exactly that far.
## The displayed state is the last PlayerMoved plus every unanswered command replayed on top.
##
## PlayerMoved.seq answers every command up to that seq, because the server handles a
## connection's messages in order.
##
## After ACK_TIMEOUT of silence, the newest target is re-sent under a new seq. Older commands
## stay in the replay, so late answers line up instead of jumping. Silence after MAX_RETRIES
## re-sends does not prove the server rejected the move: it may have applied it and the answer
## is late. MoveSync then stops sending, keeps the prediction on screen and reports
## needs_resync(); the caller must not shoot and must fetch a MatchStateSync (reset()), unless
## the answer to the newest command arrives first.

const SPEED := 90.0 # px/s while a move button is held
const PX_PER_ENERGY := 2.0 # server processMove: maxDist = moveEnergy * 2
const ENERGY_PER_PX := 0.5 # server processMove: cost = round(dist * 0.5)
const ACK_TIMEOUT := 1.0 # seconds of silence before the newest Move is re-sent
const MAX_RETRIES := 2

var terrain
var position := Vector2.ZERO # displayed (predicted) position
var energy := 0 # displayed (predicted) move energy

var _server_pos := Vector2.ZERO
var _server_energy := 0
var _acked_seq := 0
var _next_seq := 1
var _retries := 0
var _in_flight: Array = [] # [{"seq": int, "target_x": float, "sent_at": float}], oldest first
var _queued: Array[float] = [] # closed segment targets (and re-sends) not sent yet
var _base_pos := Vector2.ZERO # predicted state after the in-flight and queued commands
var _base_energy := 0
var _seg_dir := 0 # open segment: direction and requested distance from _base_pos
var _seg_px := 0
var _carry := 0.0
var _reported_pos := Vector2.INF # last values handed out by take_changes()
var _reported_energy := -1
var _lost := false # re-sends exhausted: the server state is unknown until resync


## Starts from an authoritative state (turn start) and forgets all pending commands.
func reset(pos: Vector2, move_energy: int) -> void:
	_server_pos = pos
	_server_energy = move_energy
	_reported_pos = Vector2.INF
	_reported_energy = -1
	_lost = false
	_in_flight.clear()
	_queued.clear()
	_retries = 0
	_seg_dir = 0
	_seg_px = 0
	_carry = 0.0
	_rebase()


## Holds a move button for dt seconds in dir (-1 left, 1 right).
func hold(dir: int, dt: float) -> void:
	_carry += SPEED * dt
	var whole := int(_carry)
	_carry -= whole
	walk_px(dir, whole)


## Extends the walk by px pixels in dir. A direction change closes the open segment first.
func walk_px(dir: int, px: int) -> void:
	if px <= 0:
		return
	if _seg_dir != 0 and dir != _seg_dir:
		_close_segment()
	_seg_dir = dir
	_seg_px = mini(_seg_px + px, int(_base_energy * PX_PER_ENERGY))
	_update_display()


## Ends the current walk. Its segment is sent on a later update().
func release() -> void:
	_close_segment()
	_carry = 0.0


## True while part of the walk has not been sent yet.
func has_unsent() -> bool:
	return _seg_px > 0 or not _queued.is_empty()


## True when every command has been sent and answered: the shown position is the server's, so
## a Shoot fired now starts where the player sees the character.
func is_settled() -> bool:
	return not _lost and not has_unsent() and _in_flight.is_empty()


## True when re-sends ran out without an answer: the server's position is unknown. The caller
## must cancel any pending Shoot/EndTurn and request a MatchStateSync, then call reset().
func needs_resync() -> bool:
	return _lost


## Returns what changed since the last call, as {"position": Vector2} and/or {"energy": int}.
## The two are reported separately: an answer may fix the energy without moving the character.
func take_changes() -> Dictionary:
	var out := {}
	if position != _reported_pos:
		_reported_pos = position
		out["position"] = position
	if energy != _reported_energy:
		_reported_energy = energy
		out["energy"] = energy
	return out


## Call every frame. Returns the Move to send now as {"direction", "targetX", "seq"}, or {}.
## can_send is false while the caller's action rate limit is still running.
func update(now: float, can_send: bool) -> Dictionary:
	if _lost:
		return {}
	if not _in_flight.is_empty() and now - float(_in_flight[-1]["sent_at"]) > ACK_TIMEOUT:
		if _retries >= MAX_RETRIES:
			# Unknown, not rejected: the Move may have been applied with the answer still late.
			_lost = true
			return {}
		else:
			_retries += 1
			_in_flight[-1]["sent_at"] = now # one re-send per silence window
			_queued.push_front(float(_in_flight[-1]["target_x"]))
			_rebase()
	if not can_send:
		return {}
	if _queued.is_empty() and _seg_px > 0:
		_close_segment() # keep the server close behind a long hold
	if _queued.is_empty():
		return {}
	var prev_x := _server_pos.x if _in_flight.is_empty() else float(_in_flight[-1]["target_x"])
	var target: float = _queued.pop_front()
	var seq := _next_seq
	_next_seq += 1
	_in_flight.append({"seq": seq, "target_x": target, "sent_at": now})
	return {"direction": "right" if target >= prev_x else "left", "targetX": target, "seq": seq}


## Applies the server's PlayerMoved for the local player. seq is the answered command (0 if
## the server did not send one: then the oldest in-flight command is assumed).
func on_server_moved(pos: Vector2, move_energy: int, seq: int) -> void:
	if seq > 0 and seq < _acked_seq:
		return # older than an answer already applied
	_server_pos = pos
	_server_energy = move_energy
	if seq > 0:
		_acked_seq = seq
		while not _in_flight.is_empty() and int(_in_flight[0]["seq"]) <= seq:
			_in_flight.pop_front()
		_retries = 0
	elif not _in_flight.is_empty():
		_in_flight.pop_front()
	if _in_flight.is_empty():
		_lost = false # the newest command is answered: the server state is known again
	_rebase()


## processMove for one Move{targetX} from (pos, move_energy). Returns [end_pos, energy_left].
func simulate(pos: Vector2, move_energy: int, target_x: float) -> Array:
	var max_dist := move_energy * PX_PER_ENERGY
	var target := target_x
	if absf(target - pos.x) > max_dist:
		target = pos.x + max_dist if target > pos.x else pos.x - max_dist
	var end: Vector2 = terrain.walk_to(pos.x, pos.y, target)
	var cost := mini(roundi(absf(end.x - pos.x) * ENERGY_PER_PX), move_energy)
	return [end, move_energy - cost]


func _close_segment() -> void:
	if _seg_px > 0:
		var r := simulate(_base_pos, _base_energy, _base_pos.x + _seg_dir * _seg_px)
		if r[0].x != _base_pos.x:
			_queued.append(r[0].x)
			_base_pos = r[0]
			_base_energy = r[1]
	_seg_dir = 0
	_seg_px = 0
	_update_display()


func _rebase() -> void:
	var pos := _server_pos
	var e := _server_energy
	for c in _in_flight:
		var r := simulate(pos, e, float(c["target_x"]))
		pos = r[0]
		e = r[1]
	for t in _queued:
		var r := simulate(pos, e, t)
		pos = r[0]
		e = r[1]
	_base_pos = pos
	_base_energy = e
	_seg_px = mini(_seg_px, int(_base_energy * PX_PER_ENERGY))
	_update_display()


func _update_display() -> void:
	if _seg_px > 0:
		var r := simulate(_base_pos, _base_energy, _base_pos.x + _seg_dir * _seg_px)
		position = r[0]
		energy = r[1]
	else:
		position = _base_pos
		energy = _base_energy
