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
## The displayed state is the last server state plus every unanswered command replayed on top.
##
## PlayerMoved.seq answers every command up to that seq, because the server handles a
## connection's messages in order.
##
## After ACK_TIMEOUT of silence since the newest command left, the newest target is re-sent
## under a new seq. Older commands stay in the replay, so late answers line up instead of
## jumping. The re-send count is reset only once every command is answered: an answer to an
## older command does not prove the newer ones arrived. Silence after MAX_RETRIES re-sends does
## not prove the server rejected the move: it may have applied it and the answer is late.
## MoveSync then stops sending, keeps the prediction on screen and reports needs_resync(); the
## caller must not shoot, must send Reconnect (calling mark_resync_requested()) and must pass
## the MatchStateSync to apply_snapshot(), unless the answer to the newest command arrives first.

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
# Sent, unanswered: [{"seq": int, "target_x": float, "dir": int, "sent_at": float}], oldest first.
var _in_flight: Array = []
# Not sent yet: [{"target_x": float, "dir": int, "resend_of": int}]. resend_of is the in-flight
# seq a re-send repeats (0 for a new segment).
var _queued: Array = []
# Last seq sent when each outstanding Reconnect went out, oldest first. The server answers
# Reconnects in order, so the next MatchStateSync covers the commands up to the front entry.
var _resync_marks: Array[int] = []
var _base_pos := Vector2.ZERO # predicted state after the in-flight and queued commands
var _base_energy := 0
var _seg_dir := 0 # open segment: direction and requested distance from _base_pos
var _seg_px := 0
var _carry := 0.0
var _reported_pos := Vector2.INF # last values handed out by take_changes()
var _reported_energy := -1
var _lost := false # re-sends exhausted: the server state is unknown until resync


## Starts from an authoritative state (turn start) and forgets all pending commands.
## Outstanding resync marks are kept: a MatchStateSync still on its way answers a Reconnect
## sent earlier, and its mark (a seq below anything sent from now on) keeps the new commands
## in the replay.
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


## Call when a Reconnect is sent: records which commands its MatchStateSync will cover.
func mark_resync_requested() -> void:
	_resync_marks.append(_next_seq - 1)


## Applies a MatchStateSync during the turn. The snapshot covers the commands up to the seq
## recorded when its Reconnect went out (everything sent so far if none was recorded). Those
## are dropped; commands sent after the Reconnect are still ahead of the snapshot on the
## server, so they stay in flight and are replayed on top of it.
func apply_snapshot(pos: Vector2, move_energy: int) -> void:
	var covered := _next_seq - 1
	if not _resync_marks.is_empty():
		covered = _resync_marks.pop_front()
	_server_pos = pos
	_server_energy = move_energy
	_acked_seq = maxi(_acked_seq, covered)
	_answered(covered)
	_lost = false # anything still in flight was sent after the Reconnect: the server has it next
	_reported_pos = Vector2.INF
	_reported_energy = -1
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


## True while part of the walk (or a re-send) has not been sent yet.
func has_unsent() -> bool:
	return _seg_px > 0 or not _queued.is_empty()


## True when every command has been sent and answered: the shown position is the server's, so
## a Shoot fired now starts where the player sees the character.
func is_settled() -> bool:
	return not _lost and not has_unsent() and _in_flight.is_empty()


## True when re-sends ran out without an answer: the server's position is unknown. The caller
## must cancel any pending Shoot/EndTurn and request a MatchStateSync (see apply_snapshot).
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
	# Silence is timed from when the newest command left. While something is still unsent it
	# goes out next and becomes the newest, so no retry is spent on a re-send not sent yet.
	if not _in_flight.is_empty() and not has_unsent() and now - float(_in_flight[-1]["sent_at"]) > ACK_TIMEOUT:
		if _retries >= MAX_RETRIES:
			# Unknown, not rejected: the Move may have been applied with the answer still late.
			_lost = true
			return {}
		_retries += 1
		var last: Dictionary = _in_flight[-1]
		_queued.push_front({"target_x": last["target_x"], "dir": last["dir"], "resend_of": last["seq"]})
		_rebase()
	if not can_send:
		return {}
	if _queued.is_empty() and _seg_px > 0:
		_close_segment() # keep the server close behind a long hold
	if _queued.is_empty():
		return {}
	var q: Dictionary = _queued.pop_front()
	var seq := _next_seq
	_next_seq += 1
	_in_flight.append({"seq": seq, "target_x": q["target_x"], "dir": q["dir"], "sent_at": now})
	return {"direction": "right" if int(q["dir"]) > 0 else "left", "targetX": q["target_x"], "seq": seq}


## Applies the server's PlayerMoved for the local player. seq is the answered command (0 if
## the server did not send one: then the oldest in-flight command is assumed).
func on_server_moved(pos: Vector2, move_energy: int, seq: int) -> void:
	if seq > 0 and seq < _acked_seq:
		return # older than an answer already applied
	_server_pos = pos
	_server_energy = move_energy
	if seq > 0:
		_acked_seq = seq
		_answered(seq)
	elif not _in_flight.is_empty():
		_answered(int(_in_flight[0]["seq"]))
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


## The server state now includes every command up to seq.
func _answered(seq: int) -> void:
	while not _in_flight.is_empty() and int(_in_flight[0]["seq"]) <= seq:
		_in_flight.pop_front()
	# A re-send whose original is answered before it went out would only repeat it.
	_queued = _queued.filter(func(q: Dictionary) -> bool: return int(q["resend_of"]) == 0 or int(q["resend_of"]) > seq)
	if _in_flight.is_empty():
		_retries = 0 # every command is answered: the server state is known again
		_lost = false


func _close_segment() -> void:
	if _seg_px > 0:
		# The segment starts at _base_pos, so _seg_dir is its direction from where it starts.
		var r := simulate(_base_pos, _base_energy, _base_pos.x + _seg_dir * _seg_px)
		if r[0].x != _base_pos.x:
			_queued.append({"target_x": r[0].x, "dir": _seg_dir, "resend_of": 0})
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
	for q in _queued:
		var r := simulate(pos, e, float(q["target_x"]))
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
