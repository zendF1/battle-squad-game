extends "res://tests/test_case.gd"
## The chibi bone rigs (Rookie, Spark, Tanko, Flora) in the match (scenes/character/character.gd match_rig, set by
## match/views/player_view.gd): which views use it, the muzzle on the rig's gun, the head over the
## tube aiming high, the events driving it.

const CharacterScene := preload("res://scenes/character/character.tscn")
const PlayerView := preload("res://match/views/player_view.gd")
const CharRig := preload("res://scenes/character/rig/char_rig.gd")
const Art := preload("res://ui/art.gd")

const DT := 1.0 / 60.0
## The characters drawn by a chibi bone rig in the match (assets/characters/<id>/rig/rig.json).
const RIGGED := ["rookie", "spark", "tanko", "flora"]


## A match-sized character not in the tree (_ready by hand, stepped by _step()).
func _character(id: String, match_rig: bool, holder: Node2D) -> Node2D:
	var c: Node2D = CharacterScene.instantiate()
	c.scale = Vector2.ONE * (PlayerView.ART_SCALE / Art.PX_PER_UNIT)
	c.holster = true
	c.idle_gun = true
	c.match_rig = match_rig
	c.character_id = id
	holder.add_child(c)
	c._ready()
	return c


func _step(c: Node2D, sec: float) -> void:
	var t := 0.0
	while t < sec - 1e-9:
		c._process(DT)
		if c.rig() != null:
			c.rig().advance(DT)
		t += DT


func _player(id: String, character: String) -> Dictionary:
	return {"playerId": id, "displayName": id, "teamId": 1, "characterId": character, "hp": 1000, "maxHp": 1000,
		"isAlive": true, "position": {"x": 300.0, "y": 900.0}, "skillEnergy": 0, "items": [], "statusEffects": [],
		"moveEnergy": 100, "maxMoveEnergy": 100}


## The rig's gun tip in global px, from its own gun sprite (not the pose's muzzle); the transforms
## chained by hand (out of the tree a child's global transform is not refreshed).
func _gun_tip(c: Node2D) -> Vector2:
	var r = c.rig()
	var fig: Node2D = r.get_node("Figure")
	var parts: Node2D = fig.get_node("Parts")
	var gun: Sprite2D = parts.get_node("Gun")
	var xf: Transform2D = c.get_parent().transform * c.transform * r.transform * fig.transform * parts.transform * gun.transform
	return xf * Vector2(r.model.gun["muzzle"])


func test_only_rigged_characters_in_the_match_use_the_rig() -> void:
	var holder := Node2D.new()
	for id in RIGGED:
		check(CharRig.available(id), "%s has a rig" % id)
		var m := _character(id, true, holder)
		check(m.rig() != null and not m.get_node("Flip").visible, "%s, match view: the rig, its old frames hidden" % id)
		var l := _character(id, false, holder)
		check(l.rig() == null and l.get_node("Flip").visible, "%s outside the match (the default): the old art" % id)
	var rookie := _character("rookie", true, holder)
	check(rookie.rig() != null, "Rookie, match view: the rig")
	check(not rookie.get_node("Flip").visible, "its old frames hidden")
	check(rookie.holds_gun(), "it holds its gun")
	var lobby := _character("rookie", false, holder)
	check(lobby.rig() == null and lobby.get_node("Flip").visible, "Rookie outside the match (the default): the old art")
	for id in Art.CHARACTERS:
		if RIGGED.has(id):
			continue
		var other := _character(id, true, holder)
		check(other.rig() == null and other.get_node("Flip").visible, "%s, match view: the old art" % id)
	var full: Node2D = CharacterScene.instantiate()
	full.lobby_full = true
	full.match_rig = true
	holder.add_child(full)
	full._ready()
	check(full.rig() == null, "a full-body lobby picture never the rig")
	rookie.match_rig = false
	rookie._apply_frames() # out of the tree the setters wait for _ready
	check(rookie.rig() == null and rookie.get_node("Flip").visible, "switched off: back to the frames")
	rookie.match_rig = true
	rookie.character_id = "tide"
	rookie._apply_frames()
	check(rookie.rig() == null, "a character without a rig: no rig")
	rookie.character_id = "tanko"
	rookie._apply_frames()
	check(rookie.rig() != null and rookie.rig().character_id == "tanko", "Tanko: his own rig")
	rookie.character_id = "flora"
	rookie._apply_frames()
	check(rookie.rig() != null and rookie.rig().character_id == "flora", "Flora: her own rig")
	rookie.character_id = "spark"
	rookie._apply_frames()
	check(rookie.rig() != null and rookie.rig().character_id == "spark", "Spark: his own rig")
	rookie.character_id = "rookie"
	rookie._apply_frames()
	check(rookie.rig() != null, "back to Rookie: the rig again")
	check(not FileAccess.get_file_as_string("res://ui/character_view.gd").contains("match_rig"), "the lobby / screens' view never sets match_rig")
	holder.free()


func test_player_view_sets_the_rig() -> void:
	var holder := Node2D.new()
	var v: Node2D = PlayerView.new()
	holder.add_child(v)
	v.setup(_player("me", "rookie"), true, 1)
	v._sprite._ready()
	check(v._sprite.rig() != null, "a Rookie player in the match: the rig")
	var sv: Node2D = PlayerView.new()
	holder.add_child(sv)
	sv.setup(_player("e2", "spark"), false, 1)
	sv._sprite._ready()
	check(sv._sprite.rig() != null and sv._sprite.rig().character_id == "spark", "a Spark player in the match: his rig")
	var top: float = v._sprite.art_height() * v._sprite.scale.y
	near(v._sprite.rig().height() * v._sprite.rig().scale.y * v._sprite.scale.y, top, 0.01, "as tall as the old side view (labels keep their places)")
	var w: Node2D = PlayerView.new()
	holder.add_child(w)
	w.setup(_player("e1", "tanko"), false, 1)
	w._sprite._ready()
	check(w._sprite.rig() != null and w._sprite.rig().character_id == "tanko", "a Tanko player in the match: his rig")
	var t: Node2D = PlayerView.new()
	holder.add_child(t)
	t.setup(_player("e3", "tide"), false, 1)
	t._sprite._ready()
	check(t._sprite.rig() == null, "Tide in the match: its frames")
	holder.free()


func test_elevation_is_the_real_angle() -> void:
	const C := preload("res://scenes/character/character.gd")
	near(C.rig_elevation(37.0, 1), 37.0, 1e-6, "right: the angle itself, not snapped")
	near(C.rig_elevation(143.0, -1), 37.0, 1e-6, "left: mirrored")
	near(C.rig_elevation(-60.0, 1), -30.0, 1e-6, "lowest -30")
	near(C.rig_elevation(120.0, 1), 90.0, 1e-6, "behind and above: straight up")
	near(C.rig_elevation(200.0, 1), -30.0, 1e-6, "behind and below: forward down")


func test_muzzle_follows_the_rig_gun() -> void:
	for id in RIGGED:
		_muzzle_follows_the_rig_gun(id)


func _muzzle_follows_the_rig_gun(id: String) -> void:
	var holder := Node2D.new()
	holder.position = Vector2(400, 700)
	var c := _character(id, true, holder)
	_step(c, 0.5)
	check(not c.rig().motion.raise_target > 0.0, "idle: the gun down (slung)")
	c.aim(20.0)
	_step(c, 1.0)
	near(c.rig().motion.raised, 1.0, 1e-6, "aiming: the gun up")
	var low: Vector2 = c.muzzle_position()
	near(low.distance_to(_gun_tip(c)), 0.0, 0.05, "the muzzle is the rig gun's tip")
	c.aim(80.0)
	_step(c, 1.0)
	var high: Vector2 = c.muzzle_position()
	near(high.distance_to(_gun_tip(c)), 0.0, 0.05, "and stays on it aiming high")
	check(high.y < low.y - 5.0, "aiming higher lifts the muzzle (%s → %s)" % [low, high])
	near(c.fire_muzzle_position().distance_to(high), 0.0, 1.0, "the gun up and on the aim: the shot leaves from its muzzle")
	eq(c.shoot(), 0.0, "the gun up: fires at once")
	c.aim(30.0)
	c.face(-1.0)
	_step(c, 1.0)
	check(c.muzzle_position().x < c.global_position.x, "facing left: the muzzle on the left")
	near(c.muzzle_position().distance_to(_gun_tip(c)), 0.0, 0.05, "mirrored, still on the gun's tip")
	holder.free()


func test_shot_with_the_gun_down_waits_for_it() -> void:
	for id in RIGGED:
		_shot_with_the_gun_down_waits_for_it(id)


func _shot_with_the_gun_down_waits_for_it(id: String) -> void:
	var holder := Node2D.new()
	var c := _character(id, true, holder)
	_step(c, 0.3)
	c.aim(45.0) # the replay's aim right before the shot
	var wait: float = c.shoot()
	near(wait, float(preload("res://scenes/character/rig/rig_motion.gd").T["fastRaiseSec"]), 0.02, "a lead-in: the gun comes up fast")
	var target: Vector2 = c.fire_muzzle_position()
	_step(c, wait - DT * 0.5)
	check(c.rig().motion.shot_age > 1.0, "no recoil before it leaves")
	c._process(DT) # the shot leaves (its first instant: no kick yet)
	c.rig().refresh()
	check(c.rig().motion.shot_age < 0.01, "recoil as it leaves")
	near(c.muzzle_position().distance_to(target), 0.0, 0.5, "the muzzle is where the shot was told to start")
	_step(c, DT)
	_step(c, 0.2)
	check(c.rig().motion.raise_target > 0.0, "held up through the recoil")
	c.clear_aim()
	_step(c, 1.2)
	near(c.rig().motion.raised, 0.0, 1e-6, "then down again on the back")
	var before: float = c.rig().motion.shot_age
	c.shoot(false)
	check(c.rig().motion.shot_age < before and c.rig().motion.raise_target == 0.0, "a shot not from the gun: the body's recoil, the gun stays down")
	holder.free()


func test_events_drive_the_rig() -> void:
	for id in RIGGED:
		_events_drive_the_rig(id)


func _events_drive_the_rig(id: String) -> void:
	var holder := Node2D.new()
	var c := _character(id, true, holder)
	c.set_walking(true)
	_step(c, 0.3)
	check(c.rig().motion.walk > 0.9, "walking")
	c.aim(30.0)
	_step(c, 0.3)
	check(c.rig().motion.raise_target == 0.0, "no raise while walking")
	c.set_walking(false)
	_step(c, 0.5)
	check(c.rig().motion.walk == 0.0 and c.rig().motion.raised > 0.99, "stopped: the aim raises it")
	c.hurt()
	check(c.rig().motion.hurt_age < 0.01, "hurt knocks it back")
	_step(c, 0.05)
	check(c.rig().modulate.g < 0.9, "with the hurt flash on the rig")
	c.die()
	_step(c, 1.5)
	check(c.rig().motion.is_dead() and c.rig().motion.raised == 0.0, "dead: fallen, the gun down")
	check(c.rig().modulate.is_equal_approx(c.DEAD_TINT), "the dead grey")
	check(not c.holds_gun(), "no gun once dead")
	holder.free()


## The tube is drawn over the head at every aim (aiming high it covers the face), only the near arm
## over it, the far arm (upper arm, forearm, fist) behind it, holding it from behind.
func test_gun_over_the_head_at_every_aim() -> void:
	for id in RIGGED:
		_gun_over_the_head_at_every_aim(id)


func _gun_over_the_head_at_every_aim(id: String) -> void:
	var holder := Node2D.new()
	var c := _character(id, true, holder)
	var r = c.rig()
	var parts: Node2D = r.get_node("Figure/Parts")
	var gun := parts.get_node("Gun")
	for deg in [-30.0, 0.0, 30.0, 50.0, 60.0, 75.0, 90.0]:
		c.aim(deg)
		_step(c, 1.0)
		check(not r.head_over_gun() and gun.get_index() > parts.get_node("head").get_index(), "%s %d°: the tube over the head" % [id, deg])
		eq(parts.get_node("n_fist").get_index(), gun.get_index() + 1, "%s %d°: right under the near fist" % [id, deg])
		for far in ["f_fist", "f_fore", "f_upper"]:
			check(parts.get_node(far).get_index() < gun.get_index(), "%s %d°: %s behind the tube" % [id, deg, far])
		# the far fist still meets the tube (held from behind, not floating)
		var g: Transform2D = r.pose["gun"]
		var hold: Vector2 = r.model.gun["hold"]
		var off: Vector2 = g.affine_inverse() * (r.pose["hands"][1] as Vector2)
		check(absf(off.y - hold.y) < r.model.gun["size"].y * 0.5, "%s %d°: the far fist on the tube (%.1f texture px off its axis)" % [id, deg, off.y - hold.y])
	for nm in ["n_upper", "n_fore"]:
		check(parts.get_node(nm).get_index() > gun.get_index(), "%s: %s over the tube" % [id, nm])
	# 90°: in front of the face (covering it), tip over the hair, tail off the ground
	var eye: Vector2 = (r.pose["bones"]["head"] as Transform2D) * ((r.model.points["eye"] as Vector2) - r.model.rest["head"] if r.model.points.has("eye") else Vector2(12, -60))
	var axis_x: float = ((r.pose["gun"] as Transform2D) * Vector2(r.model.gun["hold"])).x
	check(absf(axis_x - eye.x) < 40.0, "%s 90°: the tube in front of the face (axis x %.1f, eye x %.1f)" % [id, axis_x, eye.x])
	near(r.model.gun["length"], float(c.rig_back(id, r.height())["length"]), 0.01, "%s: the gun as long as the carry scene's Preview" % id)
	check(r.pose["muzzle"].y < r.model.points["cap_top"].y, "%s straight up: the long tube's tip over the hair (%s)" % [id, r.pose["muzzle"]])
	var tail: Vector2 = (r.pose["gun"] as Transform2D) * Vector2(0.0, r.model.gun["hold"].y)
	check(tail.y < 0.0, "%s: and its tail off the ground (%s)" % [id, tail])
	holder.free()


## Aiming straight up the head tilts back (chin up) and the torso leans back a little, eased in with
## the aim, more for a moment at a steep shot, and back once the gun is down.
func test_head_tilts_back_aiming_up() -> void:
	for id in RIGGED:
		var holder := Node2D.new()
		var c := _character(id, true, holder)
		var r = c.rig()
		var angles := func() -> Array:
			return [(r.pose["bones"]["head"] as Transform2D).get_rotation(), (r.pose["bones"]["torso"] as Transform2D).get_rotation()]
		c.aim(0.0)
		_step(c, 1.0)
		var flat: Array = angles.call()
		c.aim(45.0)
		_step(c, 1.0)
		var mid: Array = angles.call()
		c.aim(90.0)
		_step(c, 0.05)
		var rising: Array = angles.call()
		_step(c, 1.5)
		var up: Array = angles.call()
		var head_back := rad_to_deg(float(flat[0]) - float(up[0]))
		var torso_back := rad_to_deg(float(flat[1]) - float(up[1]))
		check(head_back > 15.0 and head_back < 30.0, "%s: 90° tilts the head back (%.1f° from 0°)" % [id, head_back])
		check(torso_back > 4.0 and torso_back < 10.0, "%s: and leans the torso back (%.1f°)" % [id, torso_back])
		check(absf(rad_to_deg(float(mid[0]) - float(flat[0]))) < 4.0, "%s: little tilt up to 45°" % id)
		check(rad_to_deg(float(flat[0]) - float(rising[0])) < head_back * 0.6, "%s: eased in with the aim, not snapped" % id)
		c.shoot()
		_step(c, 0.06)
		check(float(r.sample["look_up"]) > 1.05, "%s: a steep shot throws it further back for a moment" % id)
		c.clear_aim()
		_step(c, 1.5)
		near(float(r.sample["look_up"]), 0.0, 1e-3, "%s: the gun down: the head back to rest" % id)
		holder.free()


func test_swapped_weapon_goes_through_the_socket() -> void:
	for id in RIGGED:
		_swapped_weapon_goes_through_the_socket(id)


func _swapped_weapon_goes_through_the_socket(id: String) -> void:
	var holder := Node2D.new()
	var c := _character(id, true, holder)
	c.aim(30.0)
	_step(c, 1.0)
	var gun: Sprite2D = c.rig().get_node("Figure/Parts/Gun")
	for kind in Art.GUN_KINDS:
		c.set_weapon(kind, Art.GUN_BASIC)
		c._apply_gun() # out of the tree set_weapon() waits for _ready
		_step(c, 0.05)
		var art := Art.hug_gun(kind, Art.GUN_BASIC)
		check(gun.texture != null and gun.texture.get_size() == (art["texture"] as Texture2D).get_size(), "%s: its hug art on the rig's gun" % kind)
		near(c.rig().model.gun["length"], c.rig().model.gun_length * c.rig().height(), 1e-3, "%s: the rig's gun length" % kind)
		near(c.rig().model.gun["length"], float(c.rig_back(id, c.rig().height())["length"]), 0.01, "%s %s: the carry scene's Preview length" % [id, kind])
		near(c.muzzle_position().distance_to(_gun_tip(c)), 0.0, 0.05, "%s: the muzzle on its tip" % kind)
		eq(c.rig().gun_art.get("kind"), art["kind"], "%s: the rig holds that kind" % kind)
	holder.free()


func test_gun_slung_on_the_back_until_raised() -> void:
	for id in RIGGED:
		_gun_slung_on_the_back_until_raised(id)


func _gun_slung_on_the_back_until_raised(id: String) -> void:
	var holder := Node2D.new()
	var c := _character(id, true, holder)
	var r = c.rig()
	var sling: Dictionary = c.rig_back(id, r.height())
	check(not sling.is_empty(), "%s: the sling comes from the carry scene (carry.json back.scene)" % id)
	near(float(r.model.back["deg"]), float(sling["deg"]), 1e-3, "set on the rig")
	check(float(sling["deg"]) < -95.0 and float(sling["deg"]) > -165.0, "%s: diagonal: muzzle up and back over the shoulder (%.1f°)" % [id, float(sling["deg"])])
	_step(c, 0.5)
	check(r.back_gun_shown() and not r.hand_gun_shown(), "idle: on the back")
	var parts: Node2D = r.get_node("Figure/Parts")
	eq(parts.get_node("BackGun").get_index(), 0, "behind the whole body")
	var gun: Sprite2D = parts.get_node("BackGun")
	var torso := r.pose["bones"]["torso"] as Transform2D
	var rel := torso.affine_inverse() * gun.transform
	_step(c, 1.3) # breathing
	var torso2 := r.pose["bones"]["torso"] as Transform2D
	check(not torso2.is_equal_approx(torso), "the torso moved (breath)")
	check((torso2.affine_inverse() * gun.transform).is_equal_approx(rel), "the sling rides the torso bone")
	c.set_walking(true)
	_step(c, 0.4)
	check(r.back_gun_shown() and not r.hand_gun_shown(), "walking: on the back")
	check((r.pose["bones"]["torso"].affine_inverse() * gun.transform).is_equal_approx(rel), "bobbing with the torso while walking")
	c.set_walking(false)
	c.hurt()
	_step(c, 0.1)
	check(r.back_gun_shown(), "hurt: still on the back")
	_step(c, 0.6)
	c.draw_gun()
	_step(c, 0.05)
	check(r.motion.raised > 0.0 and r.motion.raised < 1.0, "drawing: on its way")
	var mid_rot: float = (r.pose["gun"] as Transform2D).get_rotation()
	var back_rot := (torso2 * rel).get_rotation()
	check(absf(angle_difference(mid_rot, back_rot)) > 0.05, "swinging off the shoulder (not a cut)")
	_step(c, 0.5)
	check(r.hand_gun_shown() and not r.back_gun_shown(), "raised: in the hands, none on the back")
	c.clear_aim()
	_step(c, 0.8)
	check(r.back_gun_shown() and not r.hand_gun_shown(), "put away: back on the back")
	c.face(-1.0)
	_step(c, 0.05)
	check(c.rig().transform.x.x < 0.0 and r.back_gun_shown(), "mirrored with the facing (the sling with it)")
	c.die()
	_step(c, 1.5)
	check(not r.back_gun_shown() and not r.hand_gun_shown(), "dead: the gun gone (faded out with the fall)")
	holder.free()


## The carry scene's Preview scale is the rig's gun length, slung and held (character.gd rig_back()):
## scaling it in the scene scales the gun and moves the muzzle; the rest of the sling stays.
func test_carry_scene_gun_scale_sets_the_rig_gun() -> void:
	for id in RIGGED:
		var path := str(Art.character_look(id)["carry"]["back"]["scene"])
		var saved: Dictionary = Art.carry_pose(id)
		var holder := Node2D.new()
		var c := _character(id, true, holder)
		c.aim(45.0)
		_step(c, 1.0)
		var length: float = c.rig().model.gun["length"]
		var tip: Vector2 = c.rig().muzzle_position()
		var deg := float(c.rig().model.back["deg"])
		# the same scene with its Preview 1.25 × bigger
		var root: Node2D = load(path).instantiate()
		var pv: Sprite2D = root.get_node("CarrySocket/Preview")
		pv.scale *= 1.25
		var preview := pv.transform * Transform2D(0.0, pv.offset)
		var big := saved.duplicate()
		big["preview"] = preview
		big["hold"] = preview.affine_inverse() * Vector2.ZERO
		root.free()
		Art._carry_poses[path] = big
		var b := _character(id, true, holder)
		b.aim(45.0)
		_step(b, 1.0)
		near(b.rig().model.gun["length"], length * 1.25, 0.01, "%s: the held gun 1.25 × longer" % id)
		check(b.rig().muzzle_position().distance_to(tip) > 5.0, "%s: its muzzle moved (%s → %s)" % [id, tip, b.rig().muzzle_position()])
		near(float(b.rig().model.back["deg"]), deg, 1e-3, "%s: the sling's angle unchanged" % id)
		Art._carry_poses[path] = saved
		holder.free()
