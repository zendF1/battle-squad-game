extends "res://tests/test_case.gd"
## Rookie's chibi bone rig in the match (scenes/character/character.gd match_rig, set by
## match/views/player_view.gd): which views use it, the muzzle on the rig's gun, the head over the
## tube aiming high, the events driving it.

const CharacterScene := preload("res://scenes/character/character.tscn")
const PlayerView := preload("res://match/views/player_view.gd")
const CharRig := preload("res://scenes/character/rig/char_rig.gd")
const Art := preload("res://ui/art.gd")

const DT := 1.0 / 60.0


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


func test_only_rookie_in_the_match_uses_the_rig() -> void:
	var holder := Node2D.new()
	check(CharRig.available("rookie"), "Rookie has a rig")
	var rookie := _character("rookie", true, holder)
	check(rookie.rig() != null, "Rookie, match view: the rig")
	check(not rookie.get_node("Flip").visible, "its old frames hidden")
	check(rookie.holds_gun(), "it holds its gun")
	var lobby := _character("rookie", false, holder)
	check(lobby.rig() == null and lobby.get_node("Flip").visible, "Rookie outside the match (the default): the old art")
	for id in Art.CHARACTERS:
		if id == "rookie":
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
	rookie.character_id = "spark"
	rookie._apply_frames()
	check(rookie.rig() == null, "another character: no rig")
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
	var top: float = v._sprite.art_height() * v._sprite.scale.y
	near(v._sprite.rig().height() * v._sprite.rig().scale.y * v._sprite.scale.y, top, 0.01, "as tall as the old side view (labels keep their places)")
	var w: Node2D = PlayerView.new()
	holder.add_child(w)
	w.setup(_player("e1", "tanko"), false, 1)
	w._sprite._ready()
	check(w._sprite.rig() == null, "Tanko in the match: its frames")
	holder.free()


func test_elevation_is_the_real_angle() -> void:
	const C := preload("res://scenes/character/character.gd")
	near(C.rig_elevation(37.0, 1), 37.0, 1e-6, "right: the angle itself, not snapped")
	near(C.rig_elevation(143.0, -1), 37.0, 1e-6, "left: mirrored")
	near(C.rig_elevation(-60.0, 1), -30.0, 1e-6, "lowest -30")
	near(C.rig_elevation(120.0, 1), 90.0, 1e-6, "behind and above: straight up")
	near(C.rig_elevation(200.0, 1), -30.0, 1e-6, "behind and below: forward down")


func test_muzzle_follows_the_rig_gun() -> void:
	var holder := Node2D.new()
	holder.position = Vector2(400, 700)
	var c := _character("rookie", true, holder)
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
	var holder := Node2D.new()
	var c := _character("rookie", true, holder)
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
	var holder := Node2D.new()
	var c := _character("rookie", true, holder)
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


func test_head_over_the_tube_aiming_high() -> void:
	var holder := Node2D.new()
	var c := _character("rookie", true, holder)
	var r = c.rig()
	var parts: Node2D = r.get_node("Figure/Parts")
	var gun := parts.get_node("Gun")
	for deg in [-30.0, 0.0, 30.0, 50.0]:
		c.aim(deg)
		_step(c, 1.0)
		check(not r.head_over_gun(), "%d°: the tube over the head (in front of the face)" % deg)
		check(parts.get_node("f_fist").get_index() == gun.get_index() + 1, "%d°: right under the far fist" % deg)
	for deg in [60.0, 75.0, 90.0]:
		c.aim(deg)
		_step(c, 1.0)
		check(r.head_over_gun(), "%d°: the head over the tube" % deg)
		eq(parts.get_node("head").get_index(), gun.get_index() + 1, "%d°: the tube right under the head" % deg)
	for fist in ["f_fist", "n_fist"]:
		check(parts.get_node(fist).get_index() > parts.get_node("head").get_index(), "%s still over the head and the tube" % fist)
	near(r.model.gun["length"], 0.708 * 1.3 * r.height(), 0.5, "the gun 3/4 × 1.3 of the hug size (about the ready pose's)")
	check(r.pose["muzzle"].y < r.model.points["cap_top"].y, "straight up: the long tube's tip over the cap (%s)" % r.pose["muzzle"])
	var tail: Vector2 = (r.pose["gun"] as Transform2D) * Vector2(0.0, r.model.gun["hold"].y)
	check(tail.y < 0.0, "and its tail off the ground (%s)" % tail)
	c.aim(20.0)
	_step(c, 1.0)
	check(not r.head_over_gun(), "back down: the tube in front again")
	holder.free()


func test_swapped_weapon_goes_through_the_socket() -> void:
	var holder := Node2D.new()
	var c := _character("rookie", true, holder)
	c.aim(30.0)
	_step(c, 1.0)
	var gun: Sprite2D = c.rig().get_node("Figure/Parts/Gun")
	for kind in Art.GUN_KINDS:
		c.set_weapon(kind, Art.GUN_BASIC)
		c._apply_gun() # out of the tree set_weapon() waits for _ready
		_step(c, 0.05)
		var art := Art.hug_gun(kind, Art.GUN_BASIC)
		check(gun.texture != null and gun.texture.get_size() == (art["texture"] as Texture2D).get_size(), "%s: its hug art on the rig's gun" % kind)
		near(c.rig().model.gun["length"], c.rig().model.GUN_LENGTH * c.rig().height(), 1e-3, "%s: the rig's gun length" % kind)
		near(c.muzzle_position().distance_to(_gun_tip(c)), 0.0, 0.05, "%s: the muzzle on its tip" % kind)
		eq(c.rig().gun_art.get("kind"), art["kind"], "%s: the rig holds that kind" % kind)
	holder.free()


func test_gun_slung_on_the_back_until_raised() -> void:
	var holder := Node2D.new()
	var c := _character("rookie", true, holder)
	var r = c.rig()
	var sling: Dictionary = c.rig_back("rookie", r.height())
	check(not sling.is_empty(), "the sling comes from Rookie's carry scene (carry.json back.scene)")
	near(float(r.model.back["deg"]), float(sling["deg"]), 1e-3, "set on the rig")
	check(float(sling["deg"]) < -110.0 and float(sling["deg"]) > -150.0, "diagonal: muzzle up and back over the shoulder (%.1f°)" % float(sling["deg"]))
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
