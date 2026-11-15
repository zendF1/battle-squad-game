extends "res://tests/test_case.gd"
## match/views/player_view.gd: the run stops the moment a walk does. The local player let go of
## the move button (hold_walk(false)): the run frames go within a frame, the last px of the
## drawn walk ease in standing. Another player's walk (walk_to()): runs while it walks, stands
## as it eases into its end.

const PlayerView := preload("res://match/views/player_view.gd")
const MoveSync := preload("res://match/move/move_sync.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")

const DT := 1.0 / 60.0
## With run frames (assets/characters/<id>/rig/run.json) and without (the standing picture bobs).
const FRAMES := ["rookie", "spark", "tanko"]
const NO_FRAMES := ["flora", "tide"]
const GROUND := 400


func _flat():
	var m := TerrainMask.new()
	m.width = 1200
	m.height = 600
	m.solid.resize(m.width * m.height)
	m.solid.fill(0)
	for x in m.width:
		for y in range(GROUND, m.height):
			m.solid[y * m.width + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	return m


func _view(holder: Node2D, id: String, me: bool, terrain) -> Node2D:
	var v: Node2D = PlayerView.new()
	holder.add_child(v)
	v.setup({"playerId": "p_" + id, "displayName": id, "teamId": 1, "characterId": id, "hp": 1000, "maxHp": 1000,
		"isAlive": true, "position": {"x": 300.0, "y": float(GROUND)}, "skillEnergy": 0, "items": [],
		"statusEffects": [], "moveEnergy": 100, "maxMoveEnergy": 100}, me, 1)
	v._sprite._ready()
	v.walk.terrain = terrain
	return v


## One frame of the match: the view, its character, the rig (out of the tree: by hand).
func _frame(v: Node2D) -> void:
	v._process(DT)
	v._sprite._process(DT)
	if v._sprite.rig() != null:
		v._sprite.rig().advance(DT)


## The run shows: the run frames, or (none) the walk blend still in.
func _running(v: Node2D) -> bool:
	var r = v._sprite.rig()
	if r != null and r.has_run_frames():
		return r.run_frames_shown()
	return v._sprite.is_walking()


## Holds the move button sec seconds (MoveSync's prediction, followed as match_screen does), lets
## go; returns [s from release to the run gone, s to the target, the gap at release in px].
func _hold_and_release(v: Node2D, terrain, sec: float) -> Array:
	var m := MoveSync.new()
	m.terrain = terrain
	m.reset(v.position, 100)
	var gone := -1.0
	var there := -1.0
	var gap := 0.0
	var ran := false
	var n := int(round(sec / DT))
	for f in n + 60:
		var holding := f < n
		v.hold_walk(holding)
		if holding:
			m.hold(1, DT)
		m.update(f * DT, true)
		var ch: Dictionary = m.take_changes()
		if ch.has("position"):
			v.follow_walk(ch["position"])
		if f == n:
			gap = m.position.x - v.position.x
		_frame(v)
		ran = ran or (holding and _running(v))
		if not holding and gone < 0.0 and not _running(v):
			gone = (f - n + 1) * DT
		if not holding and there < 0.0 and absf(v.position.x - m.position.x) < 0.05:
			there = (f - n + 1) * DT
	check(ran, "%s: runs while the button is held" % v.display_name())
	return [gone, there, gap]


func test_local_release_stands_at_once() -> void:
	var holder := Node2D.new()
	var t = _flat()
	for id in FRAMES + NO_FRAMES:
		var v := _view(holder, id, true, t)
		var r := _hold_and_release(v, t, 1.0)
		check(r[2] > 2.0, "%s: the drawn walk trails the prediction at release (%.1f px)" % [id, r[2]])
		check(r[0] > 0.0 and r[0] <= 2.0 * DT + 1e-6, "%s: the run gone within 2 frames of the release (%.3f s)" % [id, r[0]])
		check(not v._sprite.is_walking() and v._walk_left == 0.0, "%s: standing" % id)
		check(r[1] > 0.0 and r[1] <= 0.4, "%s: the last px eased in, at the target in %.2f s" % [id, r[1]])
		if v._sprite.rig() != null:
			check(v._sprite.rig().motion.walk_target == 0.0, "%s: the rig told at once" % id)
	holder.free()


func test_local_release_then_a_correction_does_not_run() -> void:
	var holder := Node2D.new()
	var t = _flat()
	var v := _view(holder, "rookie", true, t)
	_hold_and_release(v, t, 0.5)
	v.follow_walk(v.position + Vector2(6, 0)) # the server's answer a few px on
	for f in 30:
		_frame(v)
		check(not _running(v), "a catch-up after the release stands (frame %d)" % f)
	near(v.position.x, v.walk.target().x, 0.05, "and gets there")
	v.hold_walk(true) # pressed again: the next walk runs
	var m := MoveSync.new()
	m.terrain = t
	m.reset(v.position, 100)
	var ran := false
	for f in 20:
		m.hold(-1, DT)
		v.follow_walk(m.position)
		_frame(v)
		ran = ran or _running(v)
	check(ran, "pressed again: runs")
	check(v._sprite.facing < 0, "facing the new way")
	holder.free()


func test_remote_walk_stands_when_it_ends() -> void:
	var holder := Node2D.new()
	var t = _flat()
	for id in FRAMES + NO_FRAMES:
		var v := _view(holder, id, false, t)
		v.walk_to(Vector2(390, GROUND), 1.0)
		var ran := false
		var gone := -1.0
		var there := -1.0
		for f in 120:
			_frame(v)
			ran = ran or _running(v)
			if ran and gone < 0.0 and not _running(v):
				gone = f * DT
			if there < 0.0 and not v.walk.active():
				there = f * DT
		check(ran, "%s: runs while it walks" % id)
		check(gone > 0.5 and there > 0.0 and gone <= there + 2.0 * DT, "%s: stands by the walk's end (run gone %.2f s, there %.2f s)" % [id, gone, there])
		check(absf(v.position.x - 390.0) < 1e-3 and not v._sprite.is_walking(), "%s: standing at the target" % id)
	holder.free()


func test_remote_sweep_waits_only_for_the_walk() -> void:
	var holder := Node2D.new()
	var t = _flat()
	var v := _view(holder, "rookie", false, t)
	v.walk_to(Vector2(360, GROUND), 1.0)
	v.aim_sweep(45.0, 1.0)
	var drew_at := -1.0
	for f in 120:
		_frame(v)
		if drew_at < 0.0 and v.gun_state() != "holstered":
			drew_at = f * DT
			check(not v.walk.striding(), "the gun out only once the walk stands")
	check(drew_at > 0.0, "the gun comes out after the walk")
	holder.free()
