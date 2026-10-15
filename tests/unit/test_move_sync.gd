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
	s.reset(Vector2(120, 60), 90) # MatchStateSync
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
