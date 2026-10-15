extends "res://tests/test_case.gd"

const MoveSync := preload("res://match/move/move_sync.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const FIXTURE := "res://tests/fixtures/terrain_parity.json"


func _flat(w: int, h: int, ground_y: int):
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid.resize(w * h)
	m.solid.fill(0)
	for y in range(ground_y, h):
		for x in w:
			m.solid[y * w + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	return m


func _sync(x: float, energy: int):
	var s := MoveSync.new()
	s.terrain = _flat(400, 100, 60)
	s.reset(Vector2(x, 60), energy)
	return s


## Sends A (→130) then B (←120), like walking right 30 px and back 10 px.
func _send_right_then_left(s) -> void:
	s.walk_px(1, 30)
	s.walk_px(-1, 10)
	s.release()
	eq(s.update(0.0, true), {"direction": "right", "targetX": 130.0, "seq": 1}, "A")
	eq(s.update(0.3, true), {"direction": "left", "targetX": 120.0, "seq": 2}, "B")


func test_walk_shows_immediately() -> void:
	var s = _sync(100, 100)
	s.walk_px(1, 45)
	eq(s.position, Vector2(145, 60), "moved before any server answer")
	eq(s.energy, 77, "100 - round(45 * 0.5)")


func test_hold_converts_time_to_pixels() -> void:
	var s = _sync(100, 100)
	s.hold(1, 0.25) # 22.5 px: 22 now, 0.5 carried
	s.hold(1, 0.25) # 22.5 + 0.5 → 23
	eq(s.position.x, 145.0, "90 px/s for 0.5 s")


func test_energy_rounds_per_command_like_server() -> void:
	var s = _sync(100, 100)
	var targets := []
	var now := 0.0
	for px in [22, 23, 22, 23]:
		s.walk_px(1, px)
		s.release()
		targets.append(s.update(now, true).get("targetX"))
		now += 0.3
	eq(targets, [122.0, 145.0, 167.0, 190.0], "one command per segment")
	eq(s.energy, 54, "server cost 11 + 12 + 11 + 12 (not round(90 * 0.5) = 45)")
	eq(s.position, Vector2(190, 60), "position")


func test_direction_change_splits_commands() -> void:
	var s = _sync(100, 100)
	_send_right_then_left(s)
	eq(s.position, Vector2(120, 60), "net position")
	eq(s.energy, 80, "15 for the right leg + 5 for the left leg, as the server charges")
	eq(s.update(0.6, true), {}, "nothing left to send")


func test_nothing_sent_while_rate_limited() -> void:
	var s = _sync(100, 100)
	s.walk_px(1, 20)
	eq(s.update(0.0, false), {}, "caller's rate limit is running")
	check(s.has_unsent(), "walk still pending")
	eq(s.update(0.1, true).get("targetX"), 120.0, "sent once allowed")
	check(not s.has_unsent(), "nothing pending")


func test_ack_rebases_on_server_state() -> void:
	var s = _sync(100, 100)
	s.walk_px(1, 40)
	s.release()
	eq(s.update(0.0, true).get("seq"), 1, "command sent")
	s.walk_px(1, 20) # still walking on top of the unacknowledged command
	s.on_server_moved(Vector2(138, 60), 79, 1) # server ended 2 px short
	eq(s.position, Vector2(158, 60), "open walk replayed from the server position")
	eq(s.energy, 69, "79 - round(20 * 0.5)")


func test_late_answers_after_resend_do_not_jump() -> void:
	var s = _sync(100, 100)
	_send_right_then_left(s)
	var resend: Dictionary = s.update(1.5, true)
	eq([resend.get("targetX"), resend.get("seq")], [120.0, 3], "B's target re-sent under a new seq after 1 s of silence")
	eq(s.energy, 80, "re-send keeps A and B in the replay: energy unchanged")
	s.on_server_moved(Vector2(130, 60), 85, 1) # late answer to A
	eq(s.position, Vector2(120, 60), "no jump back to 130")
	eq(s.energy, 80, "energy after late A")
	s.on_server_moved(Vector2(120, 60), 80, 2) # late answer to B
	s.on_server_moved(Vector2(120, 60), 80, 3) # answer to the re-send
	eq(s.position, Vector2(120, 60), "settled")
	eq(s.energy, 80, "settled energy")


func test_resend_answer_shows_state_when_originals_were_dropped() -> void:
	var s = _sync(100, 100)
	_send_right_then_left(s)
	s.update(1.5, true) # re-send seq 3
	s.on_server_moved(Vector2(120, 60), 90, 3) # A and B never arrived; server walked 100 → 120
	eq(s.position, Vector2(120, 60), "server position")
	eq(s.energy, 90, "server charged only the re-send")


func _silence_until_resync(s) -> void:
	s.walk_px(1, 20)
	s.release()
	eq(s.update(0.0, true).get("seq"), 1, "sent")
	eq(s.update(1.1, true).get("seq"), 2, "re-send 1")
	eq(s.update(2.2, true).get("seq"), 3, "re-send 2")
	eq(s.update(3.3, true), {}, "no more re-sends")


func test_silence_after_resends_needs_resync_not_rollback() -> void:
	# No answer is not proof of rejection: the server may have walked to 120 and only the
	# answers are late. The state is unknown, so nothing may be fired from a guessed position.
	var s = _sync(100, 100)
	_silence_until_resync(s)
	check(s.needs_resync(), "server state unknown")
	check(not s.is_settled(), "Shoot must not go out")
	eq(s.position, Vector2(120, 60), "no rollback to the last confirmed 100")
	eq(s.update(9.0, true), {}, "nothing is sent while waiting for a resync")
	s.apply_snapshot(Vector2(120, 60), 90, 3) # MatchStateSync, lastMoveSeq 3
	check(not s.needs_resync(), "resynced")
	check(s.is_settled(), "Shoot may go out after the snapshot")


func test_late_answer_to_newest_command_ends_resync() -> void:
	var s = _sync(100, 100)
	_silence_until_resync(s)
	s.on_server_moved(Vector2(120, 60), 90, 3) # the newest re-send's answer finally arrives
	check(not s.needs_resync(), "state known again")
	check(s.is_settled(), "nothing left in flight")
	eq(s.position, Vector2(120, 60), "server position")


func test_unanswered_move_blocks_commit_until_resolved() -> void:
	# The last Move is dropped by the server's rate limit. A Shoot sent now would fire from the
	# server's old position while the client shows (and previews from) the predicted one.
	var s = _sync(100, 100)
	s.walk_px(1, 20)
	s.release()
	eq(s.update(0.0, true).get("seq"), 1, "sent, then dropped by the server")
	check(not s.has_unsent(), "everything is sent...")
	check(not s.is_settled(), "...but not answered: Shoot must wait")
	eq(s.update(0.3, true), {}, "nothing new to send at 0.3 s")
	check(not s.is_settled(), "still waiting at 0.3 s")
	eq(s.update(1.1, true).get("seq"), 2, "re-sent after 1 s of silence")
	s.on_server_moved(Vector2(120, 60), 90, 2)
	check(s.is_settled(), "answered: Shoot may go out")
	eq(s.position, Vector2(120, 60), "shown position is the server's")


func test_changes_report_energy_even_when_position_is_unchanged() -> void:
	var s = _sync(100, 100)
	_send_right_then_left(s)
	eq(s.take_changes(), {"position": Vector2(120, 60), "energy": 80}, "first report")
	s.update(1.5, true) # re-send of B
	eq(s.take_changes(), {}, "re-send changes nothing visible")
	s.on_server_moved(Vector2(120, 60), 90, 3) # A and B were dropped: same spot, more energy
	eq(s.take_changes(), {"energy": 90}, "energy-only correction still reaches the HUD")


func test_simulate_matches_server_process_move() -> void:
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var s := MoveSync.new()
	s.terrain = TerrainMask.new()
	s.terrain.load_snapshot(f["after"])
	for seq in f["moves"]:
		var pos := Vector2(float(seq["startX"]), float(seq["startY"]))
		var energy := int(seq["energy"])
		for step in seq["steps"]:
			var r: Array = s.simulate(pos, energy, float(step["targetX"]))
			pos = r[0]
			energy = r[1]
			eq(pos, Vector2(float(step["x"]), float(step["y"])), "position after Move to %s" % step["targetX"])
			eq(energy, int(step["energy"]), "energy after Move to %s" % step["targetX"])


## Fake server for the loop tests: processMove, the 150 ms action rate limit, fixed one-way
## latencies and in-order delivery.
class FakeNet:
	var s
	var up := 0.0
	var down := 0.0
	var srv_pos := Vector2.ZERO
	var srv_energy := 0
	var last_action := -100.0
	var to_server: Array = [] # [arrive_at, cmd]
	var to_client: Array = [] # [arrive_at, pos, energy, seq]

	func send(now: float, cmd: Dictionary) -> void:
		to_server.append([now + up, cmd])

	func step(now: float) -> void:
		while not to_server.is_empty() and to_server[0][0] <= now:
			var m: Array = to_server.pop_front()
			if m[0] - last_action < 0.15:
				continue # dropped by the rate limit, no answer
			last_action = m[0]
			var r: Array = s.simulate(srv_pos, srv_energy, float(m[1]["targetX"]))
			srv_pos = r[0]
			srv_energy = r[1]
			to_client.append([m[0] + down, srv_pos, srv_energy, int(m[1]["seq"])])
		while not to_client.is_empty() and to_client[0][0] <= now:
			var a: Array = to_client.pop_front()
			s.on_server_moved(a[1], a[2], a[3])


## Mimics match_screen._process: hold right until hold_until, send at most every 250 ms.
## Returns the time MoveSync first settled or lost track after the release (-1 if never).
func _run_until_resolved(s, net, t_end: float, hold_until: float) -> float:
	var now := 0.0
	var dt := 1.0 / 60.0
	var since_action := 10.0
	var released := false
	while now < t_end:
		since_action += dt
		if now < hold_until:
			s.hold(1, dt)
		elif not released:
			s.release()
			released = true
		var cmd: Dictionary = s.update(now, since_action >= 0.25)
		if not cmd.is_empty():
			net.send(now, cmd)
			since_action = 0.0
		net.step(now)
		if released and (s.is_settled() or s.needs_resync()):
			return now
		now += dt
	return -1.0


func test_rtt_longer_than_ack_timeout_still_resolves() -> void:
	# With a 1.2 s round trip every newest command times out before its answer. Answers to
	# older commands must not reset the re-send count, or Shoot waits for the whole turn.
	var s = _sync(100, 100)
	var net := FakeNet.new()
	net.s = s
	net.up = 0.6
	net.down = 0.6
	net.srv_pos = Vector2(100, 60)
	net.srv_energy = 100
	var at := _run_until_resolved(s, net, 15.0, 0.3)
	check(at >= 0.0 and at <= 4.0, "settled or needs_resync within 4 s (got %.2f)" % at)


func test_older_answer_keeps_retry_count() -> void:
	var s = _sync(100, 100)
	_send_right_then_left(s) # seq 1 at 0.0, seq 2 at 0.3
	eq(s.update(1.4, true).get("seq"), 3, "re-send 1 of B")
	s.on_server_moved(Vector2(130, 60), 85, 1) # only A answered
	eq(s.update(2.5, true).get("seq"), 4, "re-send 2")
	eq(s.update(3.6, true), {}, "no third re-send")
	check(s.needs_resync(), "lost although A was answered in between")


func _lose(s) -> void:
	_silence_until_resync(s) # seq 1..3 for 100 → 120, all unanswered; the controller sends Reconnect


func test_snapshot_older_than_a_newer_move_keeps_it_in_the_replay() -> void:
	var s = _sync(100, 100)
	_lose(s)
	s.on_server_moved(Vector2(120, 60), 90, 3) # late answer to the newest re-send unlocks
	check(s.is_settled(), "unlocked by the late answer")
	s.walk_px(1, 30)
	s.release()
	eq(s.update(3.6, true).get("seq"), 4, "seq 4 sent after the Reconnect")
	s.apply_snapshot(Vector2(120, 60), 90, 3) # taken before the server saw seq 4
	eq(s.position, Vector2(150, 60), "seq 4 replayed on top of the snapshot")
	eq(s.energy, 75, "90 - round(30 * 0.5)")
	check(not s.is_settled(), "seq 4 still unanswered: Shoot must wait")
	s.on_server_moved(Vector2(150, 60), 75, 4)
	check(s.is_settled(), "settled after seq 4's answer")


func test_snapshot_after_late_ack_unlock_changes_nothing() -> void:
	var s = _sync(100, 100)
	_lose(s)
	s.on_server_moved(Vector2(120, 60), 90, 3)
	s.take_changes()
	s.apply_snapshot(Vector2(120, 60), 90, 3)
	check(s.is_settled(), "still settled")
	eq(s.position, Vector2(120, 60), "snapshot position")
	eq(s.take_changes(), {"position": Vector2(120, 60), "energy": 90}, "re-reported for the rebuilt view")


func test_two_outstanding_resyncs_each_cover_their_own_commands() -> void:
	var s = _sync(100, 100)
	_lose(s) # and a second Reconnect after RESYNC_RETRY
	s.apply_snapshot(Vector2(120, 60), 90, 3) # answer to the first Reconnect
	check(s.is_settled(), "unlocked by the first snapshot")
	s.walk_px(-1, 10)
	s.release()
	eq(s.update(7.0, true), {"direction": "left", "targetX": 110.0, "seq": 4}, "seq 4 after both Reconnects")
	s.apply_snapshot(Vector2(120, 60), 90, 3) # answer to the second Reconnect, taken before seq 4
	eq(s.position, Vector2(110, 60), "seq 4 kept in the replay")
	check(not s.is_settled(), "seq 4 still unanswered")


func test_snapshot_drops_covered_commands_and_replays_newer_ones() -> void:
	var s = _sync(100, 100)
	_send_right_then_left(s) # seq 1 → 130, seq 2 → 120
	s.apply_snapshot(Vector2(130, 60), 85, 1) # the server had taken seq 1 only
	eq(s.position, Vector2(120, 60), "seq 2 replayed on the snapshot")
	eq(s.energy, 80, "85 - round(10 * 0.5)")
	check(not s.is_settled(), "seq 2 still unanswered")
	s.on_server_moved(Vector2(130, 60), 85, 1) # a late answer to a covered command
	eq(s.position, Vector2(120, 60), "ignored: no jump")
	s.on_server_moved(Vector2(120, 60), 80, 2)
	check(s.is_settled(), "settled by seq 2's answer")


func test_snapshot_covering_the_newest_command_settles() -> void:
	var s = _sync(100, 100)
	s.walk_px(1, 20)
	s.release()
	s.update(0.0, true)
	s.apply_snapshot(Vector2(118, 60), 91, 1) # e.g. after a terrain version mismatch
	check(s.is_settled(), "nothing left in flight")
	eq(s.position, Vector2(118, 60), "snapshot position")


func test_snapshot_seq_from_an_earlier_client_covers_nothing() -> void:
	# A restarted client numbers from 1 again while the server still holds seq 8 from before.
	var s = _sync(100, 100)
	s.walk_px(1, 20)
	s.release()
	s.update(0.0, true) # seq 1, not yet taken by the server
	s.apply_snapshot(Vector2(100, 60), 100, 8)
	check(not s.is_settled(), "seq 1 still in flight")
	s.on_server_moved(Vector2(120, 60), 90, 1)
	check(s.is_settled(), "its answer is not ignored")
	eq(s.position, Vector2(120, 60), "server position")


func test_snapshot_counts_a_dropped_move() -> void:
	# The server took seq 1 but dropped it (rate limit): no PlayerMoved will ever answer it.
	var s = _sync(100, 100)
	s.walk_px(1, 20)
	s.release()
	s.update(0.0, true)
	s.update(1.1, false) # its re-send is queued
	s.apply_snapshot(Vector2(100, 60), 100, 1)
	check(s.is_settled(), "dropped Move left the replay, and so did its queued re-send")
	eq(s.position, Vector2(100, 60), "server position: the Move did nothing")
	eq(s.energy, 100, "nothing charged")
	eq(s.update(1.5, true), {}, "nothing re-sent")


func test_snapshot_without_last_move_seq_keeps_commands_in_flight() -> void:
	# An older server sends no lastMoveSeq: the snapshot may or may not include seq 1.
	var s = _sync(100, 100)
	s.walk_px(1, 20)
	s.release()
	s.update(0.0, true)
	s.apply_snapshot(Vector2(100, 60), 100)
	check(not s.is_settled(), "seq 1 still needs its answer: Shoot waits")
	eq(s.position, Vector2(120, 60), "seq 1 replayed on the snapshot")
	s.on_server_moved(Vector2(120, 60), 90, 1)
	check(s.is_settled(), "settled by the answer")


func test_snapshot_without_last_move_seq_keeps_the_lost_state() -> void:
	var s = _sync(100, 100)
	_lose(s)
	s.apply_snapshot(Vector2(120, 60), 90)
	check(s.needs_resync(), "still unknown which Moves the snapshot shows")
	s.on_server_moved(Vector2(120, 60), 90, 3)
	check(s.is_settled(), "a late answer still ends it")


func test_resend_keeps_the_original_direction() -> void:
	var s = _sync(100, 100)
	_send_right_then_left(s)
	eq(s.update(1.5, true), {"direction": "left", "targetX": 120.0, "seq": 3}, "re-send of the left leg")


func test_queued_resend_spends_no_retry_until_sent() -> void:
	var s = _sync(100, 100)
	s.walk_px(1, 20)
	s.release()
	s.update(0.0, true)
	eq(s.update(1.1, false), {}, "re-send queued, rate limited")
	s.update(2.2, false)
	s.update(3.3, false)
	check(not s.needs_resync(), "only one command ever left: not lost")
	eq(s.update(3.4, true).get("seq"), 2, "re-send leaves at 3.4")
	eq(s.update(4.3, true), {}, "silence is timed from 3.4, not from when it was queued")
	eq(s.update(4.5, true).get("seq"), 3, "second re-send after 1 s of silence")


func test_queued_resend_dropped_when_original_answered() -> void:
	var s = _sync(100, 100)
	s.walk_px(1, 20)
	s.release()
	s.update(0.0, true)
	s.update(1.1, false) # re-send of seq 1 queued
	check(s.has_unsent(), "re-send waiting")
	s.on_server_moved(Vector2(120, 60), 90, 1)
	check(not s.has_unsent(), "re-send dropped: its original is answered")
	check(s.is_settled(), "settled")
	eq(s.update(1.5, true), {}, "nothing sent")


func test_answer_older_than_applied_one_is_ignored() -> void:
	var s = _sync(100, 100)
	s.walk_px(1, 20)
	s.release()
	s.update(0.0, true)
	s.walk_px(1, 20)
	s.release()
	s.update(0.3, true)
	s.on_server_moved(Vector2(140, 60), 80, 2)
	s.on_server_moved(Vector2(120, 60), 90, 1)
	eq(s.position, Vector2(140, 60), "seq 1 after seq 2 ignored")
	eq(s.energy, 80, "energy from seq 2")


func test_answer_without_seq_takes_the_oldest_command() -> void:
	var s = _sync(100, 100)
	s.walk_px(1, 20)
	s.release()
	s.update(0.0, true)
	s.walk_px(1, 20)
	s.release()
	s.update(0.3, true)
	s.on_server_moved(Vector2(120, 60), 90, 0)
	eq(s.position, Vector2(140, 60), "second command replayed on the first's answer")
	check(not s.is_settled(), "one still in flight")
	s.on_server_moved(Vector2(140, 60), 80, 0)
	check(s.is_settled(), "settled")


func test_energy_runs_out_mid_segment() -> void:
	var s = _sync(100, 10)
	s.walk_px(1, 50)
	eq(s.position, Vector2(120, 60), "capped at moveEnergy * 2")
	eq(s.energy, 0, "all energy spent")
	s.release()
	eq(s.update(0.0, true).get("targetX"), 120.0, "target is the capped end")
	s.walk_px(1, 5)
	eq(s.update(0.3, true), {}, "nothing more to send at energy 0")
	s.on_server_moved(Vector2(118, 60), 1, 1) # server ended 2 px short with 1 left
	s.walk_px(1, 5)
	eq(s.position, Vector2(120, 60), "open walk re-capped by the server's energy 1")


func test_reset_forgets_commands_in_flight() -> void:
	var s = _sync(100, 100)
	_send_right_then_left(s)
	s.update(1.5, true) # re-send in flight too
	s.reset(Vector2(200, 60), 50) # TurnStarted
	check(s.is_settled(), "nothing in flight after reset")
	eq(s.position, Vector2(200, 60), "turn start position")
	eq(s.energy, 50, "turn start energy")
	eq(s.update(9.0, true), {}, "no re-send of the old turn's commands")
	s.walk_px(1, 10)
	s.release()
	eq(s.update(9.3, true).get("seq"), 4, "seqs keep counting up")
