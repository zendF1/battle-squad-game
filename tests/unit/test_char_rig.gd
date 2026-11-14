extends "res://tests/test_case.gd"
## The bone rigs (Rookie, Spark, Tanko; scenes/character/rig/; in matches: test_match_rig.gd): the two-bone IK, the rig data, the hands on the
## gun's tube at every aim, the feet planted, and no pops through the dev preview's whole sequence.

const IK := preload("res://scenes/character/rig/rig_ik.gd")
const RigModel := preload("res://scenes/character/rig/rig_model.gd")
const RigMotion := preload("res://scenes/character/rig/rig_motion.gd")
const Preview := preload("res://scenes/dev/rig_preview.gd")

const HUG := "res://assets/weapons/hug.json"
## The characters with a bone rig (assets/characters/<id>/rig/rig.json).
const RIGGED := ["rookie", "spark", "tanko"]


func _model(id: String) -> RigModel:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/%s/rig/rig.json" % id))
	var hug = JSON.parse_string(FileAccess.get_file_as_string(HUG))
	var m := RigModel.new()
	check(data is Dictionary and hug is Dictionary, "rig.json and hug.json parse")
	check(m.setup(data, hug["guns"]["bazooka"]["iron"]), "the rig sets up")
	return m


func test_ik_reaches_and_bends_to_its_side() -> void:
	var root := Vector2(0, 0)
	var target := Vector2(30, 20)
	var down := IK.middle(root, 25.0, 25.0, target, 1.0)
	var up := IK.middle(root, 25.0, 25.0, target, -1.0)
	near(down.distance_to(root), 25.0, 0.01, "first bone keeps its length")
	near(down.distance_to(target), 25.0, 0.01, "second bone keeps its length")
	check(down.y > up.y, "bend +1: clockwise of the line (below it, the target to the right)")
	near(IK.end_point(root, 25.0, 25.0, target, 1.0).distance_to(target), 0.0, 0.01, "reaches the target")
	var far := IK.end_point(root, 25.0, 25.0, Vector2(100, 0), 1.0)
	near(far.x, 50.0, 0.05, "out of reach: straight towards it")
	near(far.y, 0.0, 0.05, "out of reach: on the line")


func test_rig_data_is_complete() -> void:
	for id in RIGGED:
		_rig_data_is_complete(id)


func _rig_data_is_complete(id: String) -> void:
	var m := _model(id)
	eq(m.bone_names.size(), 15, "15 bones")
	eq(m.parts.size(), 14, "14 parts")
	for p in m.parts:
		check(m.rest.has(p["bone"]), "part %s rides a bone" % p["name"])
		check(FileAccess.file_exists("res://assets/characters/%s/rig/%s" % [id, p["png"]]), "%s: part %s has its png" % [id, p["name"]])
	check(m.parts.any(func(p): return p["name"] == m.gun_under), "the gun goes under a part that exists")
	near(m.gun["length"], m.height * RigModel.GUN_LENGTH, 0.01, "the gun is GUN_LENGTH of the height (3/4 × 1.3 of the hug size)")


func test_rest_pose_matches_the_picture() -> void:
	for id in RIGGED:
		_rest_pose_matches_the_picture(id)


func _rest_pose_matches_the_picture(id: String) -> void:
	var m := _model(id)
	var pose := m.solve({})
	for p in m.parts:
		var xf: Transform2D = m.part_transform(pose["bones"], p)
		var tol := 3.0 if p["bone"].ends_with("hip") or p["bone"].ends_with("knee") else 1.5
		check(xf.origin.distance_to(p["xf"].origin) < tol, "part %s at its rest place" % p["name"])
		near(xf.get_rotation(), p["xf"].get_rotation(), 0.12 if tol > 2.0 else 0.02, "part %s unturned" % p["name"])


func test_hands_on_the_tube_at_every_aim() -> void:
	for id in RIGGED:
		_hands_on_the_tube_at_every_aim(id)


func _hands_on_the_tube_at_every_aim(id: String) -> void:
	var m := _model(id)
	for deg in range(-30, 91, 5):
		var pose := m.solve({"raise": 1.0, "aim": float(deg)})
		var dir: Vector2 = pose["dir"]
		near(rad_to_deg(dir.angle()), -float(deg), 0.01, "the gun points at the aim %d" % deg)
		for i in 2:
			var hand: Vector2 = pose["hands"][i]
			var grip: Vector2 = pose["grips"][i]
			check(hand.distance_to(grip) < 0.5, "hand %d on its grip at %d° (%.2f px off)" % [i, deg, hand.distance_to(grip)])
		var along: float = (pose["grips"][1] - pose["grips"][0]).dot(dir)
		check(along > 10.0, "the far hand further along the tube at %d°" % deg)
		# the muzzle never ends on the face (the eye ~ (12, -60) from the neck), but in the band where
		# the tube sweeps from in front of the face to beside the head (rig_model.gd AIM_PATH)
		var eye: Vector2 = pose["bones"]["head"] * (m.points["eye"] - m.rest["head"] if m.points.has("eye") else Vector2(12, -60))
		if deg < 66 or deg > 84:
			check(pose["muzzle"].distance_to(eye) > 30.0, "muzzle off the face at %d°" % deg)


func test_feet_stay_planted() -> void:
	for id in RIGGED:
		_feet_stay_planted(id)


func _feet_stay_planted(id: String) -> void:
	var m := _model(id)
	var mo := RigMotion.new()
	mo.raise_gun(true)
	mo.set_aim(30.0)
	for i in 60:
		mo.advance(1.0 / 60.0)
	mo.shoot()
	mo.hurt()
	for i in 30:
		mo.advance(1.0 / 60.0)
		var pose := m.solve(mo.sample())
		for side in ["n", "f"]:
			var a: Vector2 = pose["bones"][side + "_ankle"].origin
			check(a.distance_to(m.rest[side + "_ankle"]) < 0.5, "%s foot planted through the recoil and the hit" % side)


func test_walk_steps_and_returns_to_rest() -> void:
	for id in RIGGED:
		_walk_steps_and_returns_to_rest(id)


func _walk_steps_and_returns_to_rest(id: String) -> void:
	var m := _model(id)
	var mo := RigMotion.new()
	mo.set_walking(true)
	var lifted := 0.0
	var planted_ok := true
	for i in 120:
		mo.advance(1.0 / 60.0)
		var s := mo.sample()
		var pose := m.solve(s)
		for side in ["n", "f"]:
			var target: Vector2 = m.rest[side + "_ankle"] + s["foot_" + side]
			if pose["bones"][side + "_ankle"].origin.distance_to(target) > 0.5:
				planted_ok = false
			lifted = maxf(lifted, -float(s["foot_" + side].y))
	check(planted_ok, "the feet follow their steps")
	check(lifted > 5.0, "a foot lifts in its swing")
	mo.set_walking(false)
	for i in 30:
		mo.advance(1.0 / 60.0)
	var s := mo.sample()
	check(s["foot_n"].length() < 0.01 and s["foot_f"].length() < 0.01, "feet back home after the walk")


func test_motion_rules() -> void:
	var mo := RigMotion.new()
	mo.set_aim(200.0)
	eq(mo.aim_target, 90.0, "aim clamped to 90")
	mo.set_aim(-80.0)
	eq(mo.aim_target, -30.0, "aim clamped to -30")
	mo.raise_gun(true)
	mo.advance(float(RigMotion.T["raiseSec"]) + 0.01)
	near(mo.sample()["raise"], 1.0, 0.0001, "raised after raiseSec")
	mo.die()
	for i in 120:
		mo.advance(1.0 / 60.0)
	mo.raise_gun(true)
	mo.shoot()
	mo.advance(0.5)
	var s := mo.sample()
	near(s["raise"], 0.0, 0.0001, "the dead do not raise the gun")
	check(s["flash"] == 0.0, "nor shoot")
	near(s["fall_deg"], float(RigMotion.T["fallDeg"]), 0.01, "lies at the fall's angle")


func test_lying_on_the_ground() -> void:
	for id in RIGGED:
		_lying_on_the_ground(id)


func _lying_on_the_ground(id: String) -> void:
	var m := _model(id)
	var mo := RigMotion.new()
	mo.die()
	mo.advance(3.0)
	var pose := m.solve(mo.sample())
	var fig: Transform2D = pose["figure"]
	var low := -INF
	for pair in [["head", "head_back"], ["head", "cap_back"], ["head", "cap_top"], ["torso", "back"]]:
		var q: Vector2 = fig * (pose["bones"][pair[0]] * (m.points[pair[1]] - m.rest[pair[0]]))
		low = maxf(low, q.y)
	check(low <= 0.01 and low > -2.0, "%s: lies on the ground: its lowest outline point within 2 px of it (%.2f)" % [id, low])


## The dev preview's whole sequence at 60 fps: no joint ever jumps (a pop); the gun's muzzle (at the
## end of the long tube) and the fall (the head swinging down fastest) allowed more.
func test_no_pops_through_the_preview_sequence() -> void:
	for id in RIGGED:
		_no_pops_through_the_preview_sequence(id)


func _no_pops_through_the_preview_sequence(id: String) -> void:
	var m := _model(id)
	var mo := RigMotion.new()
	var seq: Array = Preview.SEQUENCE
	var k := 0
	var t := 0.0
	var dt := 1.0 / 60.0
	var last := {}
	var worst := 0.0
	var worst_fall := 0.0
	var worst_muzzle := 0.0
	var worst_swap := 0.0 # the gun swinging between the back sling and the hands (fast by design)
	while t < float(seq[seq.size() - 1][0]):
		while k < seq.size() and float(seq[k][0]) <= t:
			var step: Array = seq[k]
			match str(step[1]):
				"aim":
					mo.set_aim(step[2])
				"raise":
					mo.raise_gun(step[2])
				"shoot":
					mo.shoot()
				"hurt":
					mo.hurt()
				"walk":
					mo.set_walking(step[2])
				"die":
					mo.die()
			k += 1
		mo.advance(dt)
		t += dt
		var pose := m.solve(mo.sample())
		var fig: Transform2D = pose["figure"]
		var pts := {}
		for nm in m.bone_names:
			pts[nm] = fig * pose["bones"][nm].origin
		pts["muzzle"] = pose["muzzle"]
		if not last.is_empty():
			for nm in pts:
				var d: float = pts[nm].distance_to(last[nm])
				if mo.is_dead():
					worst_fall = maxf(worst_fall, d)
				elif mo.raised > 0.0 and mo.raised < 1.0:
					worst_swap = maxf(worst_swap, d)
				elif nm == "muzzle":
					worst_muzzle = maxf(worst_muzzle, d)
				else:
					worst = maxf(worst, d)
		last = pts
	# 18 rig px a frame: the far elbow while the aim sweeps 60° .. 80° at full speed (the far hand
	# sliding down the tube); a pop (an IK flip, a snapped pose) is 40+
	# the limits in Rookie's rig px (329.5 tall), scaled to this rig's height
	var u: float = m.height / 329.5
	check(worst < 18.0 * u, "%s: no joint moves more than 18 rig px in a frame alive (worst %.1f)" % [id, worst])
	check(worst_muzzle < 26.0 * u, "%s: the muzzle (the end of the long tube) under 26 (worst %.1f)" % [id, worst_muzzle])
	# the swap (raiseSec 0.25 s): the tube swings ~300 px off the shoulder; an IK flip would be 40+ on a joint
	check(worst_swap < 45.0 * u, "%s: the swap between back and hands: under 45 a frame, muzzle included (worst %.1f)" % [id, worst_swap])
	# (and the fall by its angle: a rig lying further back falls faster over the same time)
	check(worst_fall < 30.0 * u * m.fall_deg / float(RigMotion.T["fallDeg"]), "%s: falling: under 30 rig px a frame (worst %.1f)" % [id, worst_fall])
