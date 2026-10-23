extends "res://tests/test_case.gd"
## The match's gun draw (scenes/character/gun_draw.gd) and how the character shows it.

const GunDraw := preload("res://scenes/character/gun_draw.gd")
const CharacterScene := preload("res://scenes/character/character.tscn")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const CodeDrawLook := preload("res://tests/fixtures/code_draw_look.gd")


func _run(g, sec: float, step: float = 1.0 / 60.0) -> Array:
	var events := []
	var t := 0.0
	while t < sec - 1e-9:
		var e: String = g.update(step)
		if e != "":
			events.append(e)
		t += step
	return events


func test_starts_holstered() -> void:
	var g := GunDraw.new()
	eq(g.state_name(), "holstered", "default")
	check(not g.armed() and g.progress == 0.0, "no gun")
	eq(_run(g, 1.0), [], "nothing happens on its own")


func test_drag_start_draws_then_aims() -> void:
	var g := GunDraw.new()
	g.draw()
	eq(g.state_name(), "drawing", "drag start")
	check(g.armed(), "the gun shows while drawing")
	_run(g, 0.1)
	check(g.progress > 0.3 and g.progress < 0.7, "half way after 0.1 s (%f)" % g.progress)
	check(g.shown() > g.progress, "eased out: ahead of the linear progress")
	check(g.alpha() >= 1.0, "faded in by then")
	var events := _run(g, 0.15)
	eq(g.state_name(), "aiming", "out after drawSec")
	eq(events, ["drawn"], "one drawn event")
	g.draw()
	eq(g.state_name(), "aiming", "more aiming keeps it out")


func test_cancel_holsters_and_reverses_smoothly() -> void:
	var g := GunDraw.new()
	g.draw()
	_run(g, 0.11)
	var mid := g.progress
	g.holster()
	eq(g.state_name(), "holstering", "drag cancelled mid-draw")
	near(g.progress, mid, 1e-6, "no snap on the cancel")
	_run(g, 0.05)
	var lower := g.progress
	check(lower < mid and lower > 0.0, "going back from where it was")
	g.draw()
	eq(g.state_name(), "drawing", "a new drag during holstering reverses")
	near(g.progress, lower, 1e-6, "no snap on the reverse")
	_run(g, 0.3)
	eq(g.state_name(), "aiming", "out again")
	g.holster()
	var events := _run(g, 0.25)
	eq(g.state_name(), "holstered", "put away after holsterSec")
	eq(events, ["holstered"], "one holstered event")


func test_release_fires_then_holsters() -> void:
	var g := GunDraw.new()
	g.draw()
	_run(g, 0.3)
	near(g.fire(), 0.0, 1e-9, "the gun is out: fires at once")
	eq(g.state_name(), "firing", "firing")
	var events := _run(g, 0.3)
	eq(g.state_name(), "firing", "still out during the recoil")
	events += _run(g, 0.15)
	eq(g.state_name(), "holstering", "fireHoldSec later it goes away")
	events += _run(g, 0.25)
	eq(g.state_name(), "holstered", "and is holstered")
	eq(events, ["holstering", "holstered"], "events")


func test_remote_shot_draws_fast_then_fires() -> void:
	var g := GunDraw.new()
	var wait := g.fire()
	near(wait, float(GunDraw.TIMINGS["fastDrawSec"]), 1e-6, "a holstered gun fires after the fast draw")
	eq(g.state_name(), "drawing", "drawing first")
	check(g.fire_pending(), "fire pending")
	var events := _run(g, wait + 0.001, wait / 8.0 + 0.0001)
	eq(events, ["fire"], "fires when out")
	eq(g.state_name(), "firing", "then firing")
	# Half way through a normal draw (a release before the gun was out): the rest at the fast rate.
	var h := GunDraw.new()
	h.draw()
	_run(h, 0.11)
	var rest := h.fire()
	near(rest, (1.0 - h.progress) * float(GunDraw.TIMINGS["fastDrawSec"]), 1e-6, "the rest of the draw, fast")
	# A holster cancels a pending fire.
	var k := GunDraw.new()
	k.fire()
	k.holster()
	check(not k.fire_pending(), "cancelled")
	eq(_run(k, 0.5), ["holstered"], "no fire after a holster")


func test_timings_override() -> void:
	var g := GunDraw.new({"drawSec": 0.5, "carryOffset": [0.1, 0.2], "nope": 3})
	near(float(g.timings["drawSec"]), 0.5, 1e-9, "drawSec overridden")
	eq(g.timings["carryOffset"], [0.1, 0.2], "carryOffset overridden")
	check(not g.timings.has("nope"), "unknown keys ignored")
	near(float(g.timings["holsterSec"]), float(GunDraw.TIMINGS["holsterSec"]), 1e-9, "the rest default")
	var z := GunDraw.new({"drawSec": 0.0})
	z.draw()
	eq(z.state_name(), "aiming", "a zero draw is out at once")


func test_ready_pose() -> void:
	var C := load("res://scenes/character/character.gd")
	var t := GunDraw.TIMINGS
	var rest: Dictionary = C.ready_pose(0.0, t)
	near(rest["rot"], 0.0, 1e-9, "holstered: upright")
	eq(rest["scale"], Vector2.ONE, "holstered: no squash")
	var out: Dictionary = C.ready_pose(1.0, t)
	near(out["rot"], deg_to_rad(float(t["leanDeg"])), 1e-6, "out: leaning forward")
	check(out["scale"].y < 1.0, "out: a little crouched")
	check(C.ready_pose(0.5, t)["scale"].y < out["scale"].y, "the squash bump in the middle")


## The character with holster on (the match) and the code draw (a look without a drawn ready
## pose: tests/fixtures/code_draw_look.gd, every character kneels on its own now): no gun until
## aimed, walk holsters first, a shot from a holstered gun leaves from the drawn gun's muzzle.
func test_character_holster() -> void:
	var restore: Callable = CodeDrawLook.install("spark")
	var c: Node2D = CharacterScene.instantiate()
	c.character_id = "spark"
	c.holster = true
	var holder := Node2D.new() # not in the tree: _ready by hand, _process driven below
	holder.add_child(c)
	c._ready()
	var gun: Node2D = c.get_node("Flip/Gun")
	var dt := 1.0 / 60.0
	check(not gun.visible and not c.holds_gun(), "holstered: no gun, no hand")
	eq(c.gun_state(), "holstered", "state")
	c.set_walking(true)
	eq(c.animation(), "walk", "walks holstered")
	c.aim(40.0)
	eq(c.gun_state(), "holstered", "no draw while walking")
	c.set_walking(false)
	c.draw_gun()
	eq(c.gun_state(), "drawing", "drag start draws")
	eq(c.animation(), "idle", "the armed hold: idle frame")
	check(gun.visible and gun.modulate.a < 1.0, "the gun shows, fading in")
	var start_scale := gun.scale.x
	for i in 20:
		c._process(dt)
	eq(c.gun_state(), "aiming", "out")
	near(gun.scale.x, 1.0, 1e-6, "full size once out (from %f)" % start_scale)
	check(start_scale < 1.0, "smaller in the low carry")
	c.aim(40.0)
	var anchor: Dictionary = preload("res://ui/art.gd").gun_anchor("spark", "idle", 0)
	near(rad_to_deg(gun.rotation), float(anchor["angle"]) - 45.0, 0.01, "turned to the aim, snapped to 45")
	c.aim(90.0)
	near(rad_to_deg(gun.rotation), float(anchor["angle"]) - 90.0, 0.01, "straight up")
	c.aim(-90.0)
	near(rad_to_deg(gun.rotation), float(anchor["angle"]) + 45.0, 0.01, "straight down shows -45")
	c.aim(40.0)
	c.set_walking(true)
	eq(c.gun_state(), "holstering", "walking with the gun out puts it away first")
	eq(c.animation(), "idle", "no walk swing until holstered")
	for i in 20:
		c._process(dt)
	eq(c.gun_state(), "holstered", "holstered")
	eq(c.animation(), "walk", "then walks")
	check(not gun.visible, "gun gone")
	c.set_walking(false)
	# A remote shot: holstered → drawn fast → fires.
	c.aim(30.0)
	var wait: float = c.shoot()
	near(wait, float(GunDraw.TIMINGS["fastDrawSec"]), 0.03, "waits for the fast draw")
	var predicted: Vector2 = c.fire_muzzle_position()
	c.set_walking(true) # a snap to the server's position must not cancel the shot
	c.set_walking(false)
	for i in 30:
		if c.gun_state() == "firing":
			break
		c._process(dt)
	eq(c.gun_state(), "firing", "fired once out")
	eq(c.animation(), "shoot", "the recoil plays")
	check(c.muzzle_position().distance_to(predicted) < 1.5, "the shot leaves where predicted: %s vs %s" % [c.muzzle_position(), predicted])
	c.clear_aim()
	eq(c.gun_state(), "holstering", "clear_aim puts it away")
	c.die()
	eq(c.gun_state(), "holstered", "dead: no gun")
	check(not gun.visible, "no gun on the body")
	holder.free()
	restore.call()


func test_rest_after_fire_stays_out() -> void:
	var g := GunDraw.new()
	g.rest = true
	g.set_out()
	eq(g.state_name(), "aiming", "set_out: out at once")
	eq(g.fire(), 0.0, "fires at once")
	var ev := _run(g, 1.0)
	eq(ev, ["rested"], "the fire hold ends in the rest, not a holster")
	eq(g.state_name(), "aiming", "still out")
	near(g.progress, 1.0, 1e-6, "all the way out")
	g.holster()
	eq(_run(g, 1.0), ["holstered"], "a walk still holsters it")


## idle_gun (the match): every real character stands on its idle animation (breathing) with the
## hug gun slung across its back (carry.json), behind the body, muzzle up and back over the
## shoulder, mirrored facing left; only aiming / shooting kneel on the ready pose with the gun in
## hand, with the muzzle of any aim as before; after the shot it stands again with the gun on its
## back; walking keeps it there riding the walk frames' bob.
func test_idle_gun_slung_on_the_back() -> void:
	var Art := preload("res://ui/art.gd")
	for id in ["rookie", "tanko", "spark", "flora"]:
		var c: Node2D = CharacterScene.instantiate()
		c.character_id = id
		c.holster = true
		c.idle_gun = true
		var holder := Node2D.new()
		holder.add_child(c)
		c._ready()
		var flip: Node2D = c.get_node("Flip")
		var sprite: AnimatedSprite2D = c.get_node("Flip/Sprite")
		var gun: Node2D = c.get_node("Flip/Gun")
		var arm: Sprite2D = c.get_node("Flip/ArmFront")
		var look: Dictionary = Art.character_look(id)
		var back: Dictionary = look["carry"]["back"]
		var k := float(look["scale"])
		var cp: Dictionary = Art.carry_pose(id)
		var csock: Transform2D = cp["socket"]
		var dt := 1.0 / 60.0
		var on_back := func(what: String) -> void:
			eq(c.carry_mode(), "back", "%s: %s: on the back" % [id, what])
			check(gun.visible and c.holds_gun(), "%s: %s: the gun shown" % [id, what])
			check(gun.get_index() < sprite.get_index(), "%s: %s: behind the body" % [id, what])
			check(not arm.visible, "%s: %s: no arm over it" % [id, what])
			var up: Vector2 = c.muzzle_position() - c.global_transform * flip.transform * gun.position
			check(up.y < 0.0 and signf(up.x) == -float(c.facing), "%s: %s: muzzle up and back (%s)" % [id, what, up])
			check(c.muzzle_position().y < c.global_position.y - 0.6 * c.art_height(), "%s: %s: up at the shoulders or above" % [id, what])
		check(c.is_resting(), "%s: rests at once" % id)
		eq(c.animation(), "idle", "%s: standing on the idle animation, not the ready pose" % id)
		eq(str(look["motions"]["idle"]), "breathe", "%s: which breathes" % id)
		on_back.call("idle")
		near(gun.rotation, csock.get_rotation(), 1e-4, "%s: at the carry socket's angle" % id)
		check(gun.position.distance_to(csock.origin) < 0.01, "%s: its hold on the carry socket" % id)
		near(gun.modulate.a, 1.0, 1e-6, "%s: fully shown" % id)
		var hug: Dictionary = Art.hug_gun(Art.character_gun(id), "basic")
		var gs: Sprite2D = c.get_node("Flip/Gun/Sprite")
		near(gs.scale.x * float(hug["size"].x), Art.gun_transform(Art.ready_pose(id), hug).x.length() * float(hug["size"].x), 0.01,
			"%s: the ready pose's size" % id)
		var m: Vector2 = c.muzzle_position() - c.global_position
		c.facing = -1
		c._apply_motion()
		c._update_gun()
		on_back.call("idle facing left")
		var ml: Vector2 = c.muzzle_position() - c.global_position
		check(absf(ml.x + m.x) < 0.05 and absf(ml.y - m.y) < 0.05, "%s: mirrored facing left (%s vs %s)" % [id, ml, m])
		c.facing = 1
		c._apply_motion()
		c._update_gun()
		# Aiming: kneels on the ready pose, the gun in hand on its socket as before.
		var sock: Transform2D = Art.ready_pose(id)["socket"]
		c.draw_gun()
		eq(c.animation(), "draw", "%s: a drag start kneels" % id)
		eq(c.carry_mode(), "", "%s: in hand on the ready pose" % id)
		check(c._swap_left > 0.0 and gun.modulate.a < 1.0, "%s: settling with a squash, the gun fading in" % id)
		near(rad_to_deg(gun.rotation), 0.0, 0.01, "%s: turned to level" % id)
		check(gun.position.distance_to(sock.origin) < 0.01 and gun.get_index() > sprite.get_index(), "%s: on its socket, in front" % id)
		check(arm.visible and arm.texture == look["ready"]["arm_front"], "%s: the ready pose's arm over it" % id)
		for i in 20:
			c._process(dt)
		near(gun.modulate.a, 1.0, 1e-6, "%s: fully shown once settled" % id)
		c.aim(45.0)
		near(rad_to_deg(gun.rotation), -45.0, 0.01, "%s: the aim turns it up" % id)
		var predicted: Vector2 = c.fire_muzzle_position()
		eq(c.shoot(), 0.0, "%s: out: fires at once" % id)
		check(c.muzzle_position().distance_to(predicted) < 0.5, "%s: the shot leaves the aimed muzzle" % id)
		check(not c.is_resting(), "%s: not resting while firing" % id)
		for i in 60:
			c._process(dt)
		check(c.is_resting(), "%s: back to rest after the shot" % id)
		eq(c.animation(), "idle", "%s: standing again" % id)
		on_back.call("after the shot")
		eq(c.gun_state(), "aiming", "%s: never holstered" % id)
		# A turn change while aiming: back to rest.
		c.aim(90.0)
		eq(c.animation(), "draw", "%s: kneels to aim" % id)
		c.clear_aim()
		check(c.is_resting() and c.animation() == "idle", "%s: clear_aim stands it up" % id)
		on_back.call("after clear_aim")
		# Walking: the draw holstered, still on the back, riding the walk.
		c.set_walking(true)
		for i in 5:
			c._process(dt)
		eq(c.gun_state(), "holstered", "%s: walks holstered" % id)
		eq(c.animation(), "walk", "%s: the walk plays" % id)
		on_back.call("walking")
		eq(back["bob"].size(), sprite.sprite_frames.get_frame_count("walk"), "%s: a bob per walk frame" % id)
		for f in [0, 3]:
			sprite.frame = f
			c._update_gun()
			var at: Vector2 = csock.origin + back["bob"][f] * k
			check(gun.position.distance_to(at) < 0.01, "%s: frame %d rides the bob" % [id, f])
			near(rad_to_deg(gun.rotation), rad_to_deg(csock.get_rotation()) + c.BACK_SWAY_DEG * sin(TAU * f / back["bob"].size()), 0.01,
				"%s: frame %d at the sling angle" % [id, f])
		c.facing = -1
		c._apply_motion()
		c._update_gun()
		on_back.call("walking left")
		c.facing = 1
		c._apply_motion()
		c.set_walking(false)
		for i in 5:
			c._process(dt)
		check(c.is_resting() and c.animation() == "idle", "%s: stands when it stops" % id)
		on_back.call("stopped")
		# A hurt while resting shows the idle frame: the gun stays on the back.
		c.hurt()
		eq([c.animation(), c.carry_mode()], ["hurt", "back"], "%s: hurt keeps the sling" % id)
		c.die()
		check(not c.is_resting() and not gun.visible and c.carry_mode() == "", "%s: dead: no gun" % id)
		holder.free()


## The carry scenes (scenes/character/poses/<id>_carry.tscn, carry.json back.scene) are WYSIWYG:
## a locked root → CarrySocket (grouped) → Preview (the iron hug gun), Body (locked: the idle frame
## at the match's place and scale, after the socket: over the gun), WalkPreview (carry_walk.gd);
## the match draws the iron hug gun slung exactly as the Preview shows it (the same texture px →
## Flip transform), behind the body, mirrored facing left; another tier hangs at the same place on
## the socket at the same length; on every walk frame the WalkPreview's gun is the match's.
## The resource path a picture is drawn with: its own once the editor imported it, "" while only
## its PNG is read (a fresh file, Art._png_texture()).
static func _drawn(path: String) -> String:
	var imp := path + ".import"
	if not FileAccess.file_exists(imp):
		return path
	for line in FileAccess.get_file_as_string(imp).split("\n"):
		if line.begins_with("path="):
			return path if FileAccess.file_exists(line.trim_prefix("path=").trim_prefix("\"").trim_suffix("\"")) else ""
	return path


func test_carry_scenes_match_the_game() -> void:
	var Art := preload("res://ui/art.gd")
	var CarryWalk := load("res://scenes/character/poses/carry_walk.gd")
	for id in Art.CHARACTERS:
		var path := "res://scenes/character/poses/%s_carry.tscn" % id
		check(ResourceLoader.exists(path), path)
		if not ResourceLoader.exists(path):
			continue
		var root: Node2D = load(path).instantiate()
		check(root.get_meta("_edit_lock_", false), "%s: root locked" % id)
		eq(root.get_children().map(func(n): return str(n.name)), ["CarrySocket", "Body", "WalkPreview"], "%s: the gun before (behind) the body" % id)
		var sock: Node2D = root.get_node("CarrySocket")
		var pv: Sprite2D = root.get_node("CarrySocket/Preview")
		var body: Sprite2D = root.get_node("Body")
		var walk: Node2D = root.get_node("WalkPreview")
		check(sock.get_meta("_edit_group_", false), "%s: CarrySocket grouped (a click on the gun selects it)" % id)
		check(body.get_meta("_edit_lock_", false) and walk.get_meta("_edit_lock_", false), "%s: Body and WalkPreview locked" % id)
		eq(walk.get_script(), CarryWalk, "%s: WalkPreview plays the walk" % id)
		eq(str(walk.get("character_id")), id, "%s: WalkPreview's character" % id)
		var kind := Art.character_gun(id)
		var src: String = Art.PLACEHOLDER_SOURCE.get(id, id) # a placeholder's scene shows the art it recolours
		check(pv.texture != null and pv.texture.resource_path == Art.hug_gun_path(Art.character_gun(src), "iron"), "%s: Preview is the iron hug gun" % id)
		var look: Dictionary = Art.character_look(id)
		check(body.texture != null and body.texture.resource_path == Art.side_dir(src) + "idle_0.png", "%s: Body is idle_0" % id)
		var scene_gun: Transform2D = sock.transform * pv.transform * Transform2D(0.0, pv.offset)
		var scene_body: Transform2D = body.transform * Transform2D(0.0, body.offset)
		for tier in ["iron", "basic", "dragon"]:
			var c: Node2D = CharacterScene.instantiate()
			c.character_id = id
			c.holster = true
			c.idle_gun = true
			var holder := Node2D.new()
			holder.add_child(c)
			c.set_weapon(kind, tier) # stored: applied by _ready() (not in a tree)
			c._ready()
			var flip: Node2D = c.get_node("Flip")
			var sprite: AnimatedSprite2D = c.get_node("Flip/Sprite")
			var gun: Node2D = c.get_node("Flip/Gun")
			var gs: Sprite2D = c.get_node("Flip/Gun/Sprite")
			var hug: Dictionary = Art.hug_gun(kind, tier)
			for f in [1, -1]:
				c.facing = f
				c._apply_motion()
				c._update_gun()
				var what := "%s %s facing %s" % [id, tier, "right" if f > 0 else "left"]
				eq(c.carry_mode(), "back", "%s: slung" % what)
				check(flip.transform.is_equal_approx(Transform2D(0.0, Vector2(f, 1.0), 0.0, Vector2.ZERO)), "%s: Flip only mirrors at rest (%s)" % [what, flip.transform])
				check(gun.get_index() < sprite.get_index(), "%s: behind the body" % what)
				var game_gun: Transform2D = flip.transform * gun.transform * gs.transform * Transform2D(0.0, gs.offset)
				var game_body: Transform2D = flip.transform * sprite.transform * Transform2D(0.0, sprite.offset)
				var mirror := Transform2D(0.0, Vector2(f, 1.0), 0.0, Vector2.ZERO)
				check(_xf_close(game_body, mirror * scene_body, 0.02), "%s: the body where the scene's Body is" % what)
				if tier == "iron":
					# a placeholder's Preview is the art it recolours (same size): the match draws its own gun
					var want := pv.texture.resource_path if not Art.PLACEHOLDER_SOURCE.has(id) else _drawn(Art.hug_gun_path(kind, "iron"))
					eq(gs.texture.resource_path, want, "%s: the Preview's picture" % what)
					check(_xf_close(game_gun, mirror * scene_gun, 0.01), "%s: drawn exactly as the Preview (%s vs %s)" % [what, game_gun, mirror * scene_gun])
				else:
					eq(gs.texture.resource_path, _drawn(Art.hug_gun_path(kind, tier)), "%s: its own hug gun" % what)
					# Its hold (the same part of its length, on its muzzle row) on the socket's origin.
					var hold := Vector2(-pv.offset.x / pv.texture.get_width() * hug["size"].x, hug["muzzle"].y + (-pv.offset.y - Art.hug_meta(kind, "iron")["muzzle"].y))
					check((game_gun * hold).distance_to(mirror * sock.position) < 0.02, "%s: hung on the socket" % what)
					near(game_gun.x.length() * hug["size"].x, scene_gun.x.length() * pv.texture.get_width(), 0.02, "%s: as long as the Preview" % what)
			# Walking: the WalkPreview draws the gun as the match does on every walk frame.
			c.facing = 1
			c._apply_motion()
			c.set_walking(true)
			if tier == "iron":
				for i in sprite.sprite_frames.get_frame_count("walk"):
					sprite.frame = i
					c._update_gun()
					var game_gun: Transform2D = flip.transform * gun.transform * gs.transform * Transform2D(0.0, gs.offset)
					var shown = walk.gun_transform(i)
					check(shown is Transform2D and _xf_close(game_gun, shown, 0.01), "%s walk frame %d: WalkPreview = the match (%s vs %s)" % [id, i, game_gun, shown])
			holder.free()
		root.free()
	# The WalkPreview leaves out what is missing: no socket, no parent.
	var lone: Node2D = CarryWalk.new()
	check(lone.gun_transform(0) == null, "no parent: no gun")
	var bare := Node2D.new()
	bare.add_child(lone)
	check(lone.gun_transform(0) == null, "no CarrySocket: no gun")
	lone.character_id = "nope"
	eq(lone.walk()["stems"].size(), 8, "an unknown id reads Rookie's walk")
	bare.free()


func _xf_close(a: Transform2D, b: Transform2D, eps: float) -> bool:
	return a.x.distance_to(b.x) < eps * 0.01 + 1e-4 and a.y.distance_to(b.y) < eps * 0.01 + 1e-4 and a.origin.distance_to(b.origin) < eps


## carry.json without a scene can still place the sling itself (at / angle / hold / scale), the
## walk bob kept.
func test_parse_carry_without_scene() -> void:
	var Art := preload("res://ui/art.gd")
	var path := "user://test_carry_%d.json" % Time.get_ticks_usec()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"back": {"at": [30, 84], "angle": -110, "hold": 0.2, "bob": [[1, 2]]}}')
	f.close()
	var b: Dictionary = Art.parse_carry(path)["back"]
	eq([b["scene"], b["at"], b["angle"], b["hold"], b["scale"], b["bob"]], ["", Vector2(30, 84), -110.0, 0.2, 1.0, [Vector2(1, 2)]], "the file's own placement")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"back": {"bob": [[1, 2]]}}')
	f.close()
	eq(Art.parse_carry(path), {}, "neither scene nor at: no back part")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## The stand / kneel squash never moves the shot: fire_muzzle_position() leaves it out and a firing
## gun has none.
func test_idle_gun_squash_keeps_the_muzzle() -> void:
	var c: Node2D = CharacterScene.instantiate()
	c.character_id = "rookie"
	c.holster = true
	c.idle_gun = true
	var holder := Node2D.new()
	holder.add_child(c)
	c._ready()
	c.aim(45.0)
	check(c._swap_left > 0.0, "kneeling down: squashing")
	var during: Vector2 = c.fire_muzzle_position()
	c._swap_left = 0.0
	check(c.fire_muzzle_position().distance_to(during) < 1e-3, "the predicted muzzle ignores it")
	c._swap_left = c.SWAP_SEC
	c.shoot()
	c._apply_motion()
	check(c.muzzle_position().distance_to(during) < 0.5, "a firing gun is not squashed")
	holder.free()


## The code draw (a look without a drawn ready pose, no carry.json): at rest the default sling on
## the back; aiming takes it in hand on the idle frame's anchor as before, clear_aim slings it again.
func test_idle_gun_code_hold() -> void:
	var restore: Callable = CodeDrawLook.install("spark")
	var c: Node2D = CharacterScene.instantiate()
	c.character_id = "spark"
	c.holster = true
	c.idle_gun = true
	var holder := Node2D.new()
	holder.add_child(c)
	c._ready()
	var gun: Node2D = c.get_node("Flip/Gun")
	var sprite: Node2D = c.get_node("Flip/Sprite")
	var anchor: Dictionary = preload("res://ui/art.gd").gun_anchor("spark", "idle", 0)
	check(c.is_resting() and c.holds_gun(), "the gun shown")
	eq([c.animation(), c.carry_mode()], ["idle", "back"], "standing, on the back")
	check(gun.get_index() < sprite.get_index(), "behind the body")
	c.aim(40.0)
	eq(c.carry_mode(), "", "aiming: in hand")
	near(rad_to_deg(gun.rotation), float(anchor["angle"]) - 45.0, 0.01, "the aim as before")
	near(gun.scale.x, 1.0, 1e-6, "full size")
	c.clear_aim()
	eq(c.carry_mode(), "back", "back on the back")
	c.set_walking(true)
	eq(c.gun_state(), "holstering", "walking holsters the draw")
	eq(c.carry_mode(), "back", "still on the back")
	holder.free()
	restore.call()


## Out of the match (holster off) a look without a drawn ready pose has the gun always in hand, as
## before (a character with one holds it only on that pose: every real one now).
func test_character_without_holster_keeps_the_gun() -> void:
	var restore: Callable = CodeDrawLook.install("spark")
	var c: Node2D = CharacterScene.instantiate()
	c.character_id = "spark"
	var holder := Node.new()
	holder.add_child(c)
	c._ready()
	check(c.holds_gun(), "gun in hand")
	eq(c.shoot(), 0.0, "fires at once")
	holder.free()
	restore.call()


func test_shot_player_lead_in_holds_the_replay() -> void:
	var v := {"x": 200, "y": 0}
	var data := {"duration": 0.6, "projectiles": [{"path": [{"time": 0.0, "position": {"x": 0, "y": 0}, "velocity": v},
		{"time": 0.5, "position": {"x": 100, "y": 0}, "velocity": v}]}],
		"events": [{"t": 0.0, "type": "explode", "position": {"x": 0, "y": 0}, "radius": 10}]}
	var tl := ShotTimeline.new(data)
	var sp := ShotPlayer.new()
	var layer := Node2D.new()
	sp.layer = layer
	var due := []
	sp.event_due.connect(func(e: Dictionary) -> void: due.append(e))
	sp.play(tl, 0.12)
	check(sp.is_playing(), "playing")
	check(layer.get_child_count() == 1 and not layer.get_child(0).visible, "projectile hidden during the lead-in")
	sp._process(0.1)
	eq(due.size(), 0, "no events during the lead-in")
	sp._process(0.03)
	eq(due.size(), 1, "then the timeline from its start")
	check(layer.get_child(0).visible, "projectile shown")
	sp.stop()
	sp.free()
	layer.free()



## The hook for drawn draw frames: side.json anims.draw is loaded as the "draw" animation and the
## character shows it by the draw's progress (held on the last frame while aiming).
func test_drawn_draw_frames() -> void:
	var Art := preload("res://ui/art.gd")
	var src := ProjectSettings.globalize_path(Art.side_dir("rookie"))
	var dir := OS.get_temp_dir().path_join("bsq_draw_test_%d/" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src + "side.json"))
	for f in ["idle_0.png", "walk_0.png", "walk_3.png", "gun_anchors.json"]:
		DirAccess.copy_absolute(src + f, dir + f)
	for anim in data["anims"]:
		data["anims"][anim]["frames"] = ["idle_0"] if anim != "walk" else ["walk_0", "walk_3", "walk_0", "walk_3"]
	data["anims"]["draw"] = {"frames": ["idle_0", "walk_3", "walk_0"]}
	data["anims"].erase("fire")
	data.erase("overGun")
	data["readyPose"].erase("armFront") # its PNG is not copied
	data["gunDraw"] = {"drawSec": 0.3}
	var fa := FileAccess.open(dir + "side.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(data))
	fa.close()
	var look := Art.parse_side(dir)
	check(not look.is_empty(), "side view with draw frames loads")
	check(bool(look.get("draw_frames", false)), "draw frames found")
	eq(look["frames"].get_frame_count("draw"), 3, "three draw frames")
	near(float(look["gun_draw"]["drawSec"]), 0.3, 1e-9, "gunDraw overrides read")
	# A broken set (a missing PNG) is skipped: the side view still loads, no draw frames.
	var dir2 := dir.trim_suffix("/") + "_broken/"
	DirAccess.make_dir_recursive_absolute(dir2)
	for f in ["idle_0.png", "walk_0.png", "walk_3.png", "gun_anchors.json"]:
		DirAccess.copy_absolute(src + f, dir2 + f)
	data["anims"]["draw"] = {"frames": ["idle_0", "nope"]}
	fa = FileAccess.open(dir2 + "side.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(data))
	fa.close()
	var broken := Art.parse_side(dir2)
	check(not broken.is_empty() and not bool(broken["draw_frames"]), "broken draw set skipped")
	# The character on that look: the draw frames by progress, the last one held while aiming.
	var c: Node2D = CharacterScene.instantiate()
	c.holster = true
	var holder := Node2D.new()
	holder.add_child(c)
	c._ready()
	c._look = look
	c._gun_draw = GunDraw.new(look["gun_draw"])
	var sprite: AnimatedSprite2D = c.get_node("Flip/Sprite")
	sprite.sprite_frames = look["frames"]
	c.play("idle")
	c.draw_gun()
	eq(c.animation(), "draw", "drawing shows the draw frames")
	eq(sprite.frame, 0, "from frame 0")
	for i in 10:
		c._process(0.02)
	check(sprite.frame >= 1, "advanced with the draw (%d)" % sprite.frame)
	for i in 20:
		c._process(0.02)
	eq(c.gun_state(), "aiming", "out")
	eq(sprite.frame, 2, "the last frame held while aiming")
	c.clear_aim()
	for i in 20:
		c._process(0.02)
	eq(c.animation(), "idle", "holstered: back to idle")
	holder.free()
	for d in [dir, dir2]:
		for f in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d + f)
		DirAccess.remove_absolute(d)


## The drawn ready poses of Rookie, Flora, Tanko and Spark: side.json draw = ready_0 (kneeling, the fists
## together on the chest, no gun), fire = it with the recoil, gunDraw all 0 s; the hug gun is placed
## in scenes/character/poses/<id>_ready.tscn (the Preview: the character's iron hug gun). No hand cut-outs; the near arm (sleeve and both fists)
## cut from ready_0 into ready_arm_front.png on the same canvas, drawn over the gun.
func test_ready_pose_assets() -> void:
	for id in ["rookie", "flora", "tanko", "spark"]:
		_check_ready_pose_assets(id)


func _check_ready_pose_assets(id: String) -> void:
	var Art := preload("res://ui/art.gd")
	var dir := Art.side_dir(id)
	check(FileAccess.file_exists(dir + "ready_0.png"), "%s ready_0.png" % id)
	check(not FileAccess.file_exists(dir + "ready_hand_front.png") and not FileAccess.file_exists(dir + "ready_hand_back.png"), "%s no hand PNGs" % id)
	check(ResourceLoader.exists("res://scenes/character/poses/%s_ready.tscn" % id), "%s the pose scene" % id)
	var look := Art.side_view(id)
	check(bool(look["draw_frames"]) and bool(look["fire_frames"]), "%s draw and fire frames" % id)
	eq(look["frames"].get_frame_count("draw"), 1, "%s one ready frame" % id)
	eq(look["frames"].get_frame_count("fire"), 3, "%s three fire frames" % id)
	eq(look["motions"]["fire"], "recoil", "%s the fire recoils" % id)
	eq(look["ready"].keys(), ["anims", "scene", "arm_front"], "%s readyPose: anims, scene and the front arm, no hands" % id)
	eq(look["ready"]["anims"], ["draw", "fire"], "%s readyPose anims" % id)
	eq(look["ready"]["scene"], "res://scenes/character/poses/%s_ready.tscn" % id, "%s readyPose scene" % id)
	check(look["ready"]["arm_front"] is Texture2D, "%s readyPose front arm" % id)
	check(Art.side_paths(id).has(dir + "ready_arm_front.png"), "%s the front arm is one of the side view's files" % id)
	for key in ["drawSec", "fastDrawSec", "holsterSec"]:
		near(float(look["gun_draw"].get(key, -1.0)), 0.0, 1e-9, "%s gunDraw %s 0" % [id, key])
	for anim in ["draw", "fire"]:
		eq(look["anchors"].get(anim, []).size(), look["frames"].get_frame_count(anim), "%s %s anchors per frame" % [id, anim])
	# The scene: one socket on the hug point, its Preview the iron hug bazooka at the weapons' scale.
	var rp := Art.ready_pose(id)
	for key in ["socket", "preview", "pivot", "length"]:
		check(rp.has(key), "%s ready_pose %s" % [id, key])
	check(not rp.has("hands") and not rp.has("aim"), "%s no hands, no aim range" % id)
	var meta := Art.hug_gun(Art.character_gun(id), "iron")
	eq(rp["pivot"], meta["pivot"], "%s turned round the hug gun's hold" % id)
	near(float(rp["length"]), float(meta["size"].x), 1e-6, "%s the hug gun's length" % id)
	var root: Node = load("res://scenes/character/poses/%s_ready.tscn" % id).instantiate()
	var sock: Node2D = root.get_node("GunSocket")
	var preview: Sprite2D = root.get_node("GunSocket/Preview")
	check(rp["socket"].is_equal_approx(sock.transform), "%s the socket as placed" % id)
	check(rp["preview"].is_equal_approx(preview.transform * Transform2D(0.0, preview.offset)), "%s the Preview as placed (its offset too)" % id)
	root.free()
	# Same ground and body place as idle: the soles' row on the pivot row, one canvas.
	var idle := Image.load_from_file(ProjectSettings.globalize_path(dir + "idle_0.png"))
	var ready := Image.load_from_file(ProjectSettings.globalize_path(dir + "ready_0.png"))
	var pivot: Vector2 = look["pivot"]
	eq(ready.get_size(), idle.get_size(), "%s one canvas" % id)
	near(float(_sole_row(ready)), float(_sole_row(idle)), 1.0, "%s on the idle's ground" % id)
	near(float(_sole_row(ready)) + 1.0, pivot.y, 1.0, "%s soles on the pivot row" % id)
	# As big as standing Rookie: the cap as wide (± 10 %), not as tall.
	near(float(_widest_top(ready)), float(_widest_top(idle)), _widest_top(idle) * 0.1, "%s the cap as wide as the idle's" % id)
	# The hug point (the fallback seat, the socket) between the fists, at chest height.
	var grip: Vector2 = look["anchors"]["draw"][0]["grip"]
	check(grip.x > pivot.x + 5.0 and grip.y < pivot.y - 40.0, "%s the hug point on the chest (%s)" % [id, grip])
	check(ready.get_pixelv(Vector2i(grip.round())).a > 0.9, "%s on the fists" % id)
	var green := 0
	for y in ready.get_height():
		for x in ready.get_width():
			var c := ready.get_pixel(x, y)
			if c.a > 0.1 and c.g > 0.6 and c.g > maxf(c.r, c.b) + 0.3:
				green += 1
	eq(green, 0, "%s no green-screen pixels left" % id)
	# The front arm: on ready_0's canvas, a part of it (every pixel it has, ready_0 has there), on
	# the fists (the hug point) and the near shoulder, not the head or the legs.
	var arm := Image.load_from_file(ProjectSettings.globalize_path(dir + "ready_arm_front.png"))
	eq(arm.get_size(), ready.get_size(), "%s front arm: ready_0's canvas" % id)
	var arm_px := 0
	var outside := 0
	for y in arm.get_height():
		for x in arm.get_width():
			var a := arm.get_pixel(x, y)
			if a.a > 0.1:
				arm_px += 1
				var c := a.a > 0.9 and ready.get_pixel(x, y).a > 0.9
				if not c and a.a > 0.9:
					outside += 1
				if a.g > 0.6 and a.g > maxf(a.r, a.b) + 0.3:
					green += 1
	check(arm_px > 200 and arm_px < ready.get_used_rect().get_area() / 4, "%s front arm: a part of the body (%d px)" % [id, arm_px])
	eq(outside, 0, "%s front arm: only where ready_0 is drawn" % id)
	eq(green, 0, "%s front arm: no green-screen pixels" % id)
	check(arm.get_pixelv(Vector2i(grip.round())).a > 0.9, "%s front arm: on the fists (the hug point)" % id)
	var arm_rect := arm.get_used_rect()
	check(arm_rect.position.y > ready.get_used_rect().position.y + ready.get_used_rect().size.y * 0.3, "%s front arm: below the head" % id)
	check(arm_rect.end.y < pivot.y - 20.0, "%s front arm: above the legs" % id)
	check(arm_rect.position.x < grip.x - 20.0, "%s front arm: from the near shoulder (%s)" % [id, arm_rect])
	# The pixels it has are ready_0's (same keying / cleanup); the resample differs a little next to
	# the cut (a thin arm has more of its pixels there: Flora's), never by much.
	var same := 0
	var far := 0
	var opaque := 0
	for y in arm.get_height():
		for x in arm.get_width():
			var a := arm.get_pixel(x, y)
			if a.a > 0.99:
				opaque += 1
				var b := ready.get_pixel(x, y)
				var d := absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
				if d < 0.05:
					same += 1
				if d > 0.3:
					far += 1
	check(opaque > 0 and same >= opaque * 0.85, "%s front arm: ready_0's colours (%d of %d)" % [id, same, opaque])
	eq(far, 0, "%s front arm: no colour far from ready_0's" % id)


## In the match Rookie switches to the ready pose at once, hugging the gun over the fists, turned
## round the hug point to the snapped directions (mirrored to the left), fires from it with a kick
## back along the gun and is back to idle (gun away) after the shot or a cancel.
func test_rookie_ready_switches_at_once() -> void:
	var Art := preload("res://ui/art.gd")
	var c: Node2D = CharacterScene.instantiate()
	c.character_id = "rookie"
	c.holster = true
	var holder := Node2D.new()
	holder.add_child(c)
	c._ready()
	var flip: Node2D = c.get_node("Flip")
	var gun: Node2D = c.get_node("Flip/Gun")
	var sprite: Sprite2D = c.get_node("Flip/Gun/Sprite")
	var hand: Sprite2D = c.get_node("Flip/Gun/Hand")
	var dt := 1.0 / 60.0
	check(c.get_node_or_null("Flip/ReadyHands") == null, "no ready hands node")
	eq(c.animation(), "idle", "idle")
	check(not gun.visible, "no gun")
	c.draw_gun()
	eq(c.gun_state(), "aiming", "drawn at once: no drawing state")
	eq(c.animation(), "draw", "the ready frame")
	check(gun.visible and is_equal_approx(gun.modulate.a, 1.0), "the gun out")
	check(not hand.visible, "no grip hand: the gun covers the fists")
	var arm: Sprite2D = c.get_node("Flip/ArmFront")
	var body: AnimatedSprite2D = c.get_node("Flip/Sprite")
	check(arm.visible and arm.texture == Art.side_view("rookie")["ready"]["arm_front"], "the front arm shown")
	eq(arm.get_index(), flip.get_child_count() - 1, "the front arm over everything")
	eq(gun.get_index(), flip.get_child_count() - 2, "the gun in front of the body, under the front arm")
	check(gun.get_index() > body.get_index(), "the gun over the body")
	check(arm.transform.is_equal_approx(body.transform) and arm.offset == body.offset and not arm.centered and not body.centered, "the front arm at the body's place")
	var hug := Art.hug_gun("bazooka", Art.GUN_BASIC)
	check(hug["hug"] and hug["tier"] == Art.GUN_BASIC, "the starter bazooka has its own hug art")
	eq(sprite.texture, hug["texture"], "the basic hug gun (no weapon: the starter bazooka)")
	eq([hug["pivot"], hug["size"]], [Art.hug_meta("bazooka", "iron")["pivot"], Art.hug_meta("bazooka", "iron")["size"]], "the iron gun's shape: drawn where the Preview's iron gun is")
	var rp := Art.ready_pose("rookie")
	var sock: Transform2D = rp["socket"]
	check(gun.position.distance_to(sock.origin) < 0.01, "the gun on its socket")
	# WYSIWYG: at level, facing right, drawn exactly as the Preview in the scene.
	c.aim(0.0)
	check((flip.transform * gun.transform * sprite.transform).is_equal_approx(sock * rp["preview"]), "drawn as the Preview shows it")
	var rel: Vector2 = (gun.transform * sprite.transform * hug["muzzle"]) - sock.origin # the muzzle from the hug point at 0°
	check(rel.x > 50.0 and absf(rel.y) < 1.0, "level: the muzzle ahead, on the hug point's height (%s)" % rel)
	# 4 directions × 2 sides: the hold stays on the hug point, the muzzle turns round it.
	for f in [1, -1]:
		c.facing = f
		c._apply_motion()
		for e in [-45.0, 0.0, 45.0, 90.0]:
			c.aim(e if f > 0 else 180.0 - e)
			var to_flip := flip.transform * gun.transform * sprite.transform
			var pivot_at: Vector2 = to_flip * hug["pivot"]
			var want_pivot := flip.transform * sock.origin
			check(pivot_at.distance_to(want_pivot) < 0.01, "side %d at %d: the hold on the hug point (%s vs %s)" % [f, e, pivot_at, want_pivot])
			var want := flip.transform * (sock.origin + rel.rotated(deg_to_rad(-e)))
			check(c.muzzle_position().distance_to(want) < 0.05, "side %d at %d: the muzzle at %s (%s)" % [f, e, want, c.muzzle_position()])
			near(rad_to_deg(gun.rotation), -e, 0.01, "side %d at %d: the socket turned" % [f, e])
			check(to_flip.y.y > 0.0 or e == 90.0, "side %d at %d: not upside down" % [f, e])
			check(arm.visible and arm.get_index() == flip.get_child_count() - 1 and gun.get_index() == arm.get_index() - 1, "side %d at %d: the front arm over the gun" % [f, e])
			check(arm.get_parent() == flip and signf(flip.transform.determinant()) == float(f), "side %d at %d: the arm mirrored with the body" % [f, e])
	c.facing = 1
	c._apply_motion()
	c.aim(85.0)
	near(rad_to_deg(gun.rotation), -90.0, 0.01, "85 snaps straight up")
	c.aim(-80.0)
	near(rad_to_deg(gun.rotation), 45.0, 0.01, "and down to -45, no lower")
	c.aim(10.0)
	near(rad_to_deg(gun.rotation), 0.0, 0.01, "10 snaps level")
	var predicted: Vector2 = c.fire_muzzle_position()
	near(c.shoot(), 0.0, 1e-9, "fires at once")
	eq(c.gun_state(), "firing", "firing")
	eq(c.animation(), "fire", "the recoil on the ready frame")
	check(arm.visible and arm.get_index() == flip.get_child_count() - 1, "firing: the front arm over the gun")
	check(c.get_node("Flip/Gun/Flash").visible, "muzzle flash")
	check(c.muzzle_position().distance_to(predicted) < 0.5, "leaves where predicted")
	near(rad_to_deg(gun.rotation), 0.0, 0.01, "no turn kick: still level")
	var kick: float = sprite.transform.basis_xform(Vector2(float(hug["size"].x), 0.0)).length() * c.HUG_KICK
	near(gun.position.x, sock.origin.x - kick, 0.01, "kicked back along the gun by %f" % kick)
	near(gun.position.y, sock.origin.y, 0.01, "along its axis")
	check((c.get_node("Flip/Gun/Flash") as Node2D).position.distance_to(sprite.transform * hug["muzzle"]) < 0.01, "the flash at the gun's muzzle")
	for i in 20:
		c._process(dt)
	eq(c.gun_state(), "firing", "held after the recoil")
	for i in 10:
		c._process(dt)
	eq(c.gun_state(), "holstered", "away after fireHoldSec")
	eq(c.animation(), "idle", "back to idle at once")
	check(not gun.visible, "gun gone")
	check(not arm.visible, "idle: no front arm layer (the body's own)")
	# A drag cancelled: back to idle at once.
	c.draw_gun()
	c.clear_aim()
	eq(c.gun_state(), "holstered", "cancel: put away at once")
	eq(c.animation(), "idle", "cancel: idle at once")
	check(not gun.visible, "cancel: no gun")
	# A remote / bot shot: no lead-in, fires from the ready pose and goes back.
	c.aim(20.0)
	c.clear_aim()
	near(c.shoot(), 0.0, 1e-9, "a remote shot leaves at once")
	eq(c.animation(), "fire", "from the ready pose")
	for i in 30:
		c._process(dt)
	eq(c.animation(), "idle", "then idle")
	# Hit just after a shot (the gun still out): put away, never held outside the ready pose; the
	# bazooka has no held sprite, so even the sprite behind it is the hug art.
	c.shoot()
	check(gun.visible, "firing: hugged")
	c.play("hurt")
	check(not gun.visible and not c.holds_gun() and not arm.visible, "hurt just after the shot: the gun put away")
	eq(sprite.texture, hug["texture"], "never the old held bazooka")
	check(Art.gun("bazooka", Art.GUN_BASIC)["hug"], "the bazooka's gun is its hug art")
	c.play("idle")
	for i in 30:
		c._process(dt)
	eq(c.gun_state(), "holstered", "then away")
	# The gun hugged: the weapon's hug art (every bazooka tier has its own) → its kind's in another
	# tier → its gun sprite round its centre, as long as the Preview's gun, its pivot on the hug point.
	var drawn := func() -> float: return sprite.transform.basis_xform(Vector2(sprite.texture.get_width(), 0.0)).length()
	var preview_xf: Transform2D = sock * rp["preview"]
	var hug_len := preview_xf.basis_xform(Vector2(float(rp["length"]), 0.0)).length()
	for kt in [["bazooka", "basic"], ["bazooka", "iron"], ["bazooka", "steel"], ["bazooka", "mithril"], ["bazooka", "dragon"], ["blaster", "gold"], ["", ""]]:
		c.set_weapon(kt[0], kt[1])
		c._apply_gun() # out of the tree: set_weapon() only stores it
		c.draw_gun()
		c.aim(0.0)
		var want := Art.hug_gun(kt[0] if kt[0] != "" else "bazooka", kt[1] if kt[1] != "" else Art.GUN_BASIC)
		eq(sprite.texture, want["texture"], "%s %s: its pose gun" % kt)
		check(kt[0] == "blaster" or want["hug"], "%s %s: hug art" % kt)
		check(kt[0] != "bazooka" or want["tier"] == kt[1], "%s %s: its own tier's" % kt)
		near(drawn.call(), hug_len, 0.05, "%s %s: as long as the Preview's gun" % kt)
		check((gun.transform * sprite.transform * want["pivot"]).distance_to(sock.origin) < 0.01, "%s %s: its pivot on the hug point" % kt)
		var m: Vector2 = c.muzzle_position()
		check(m.x > gun.global_position.x + 10.0, "%s %s: the muzzle ahead" % kt)
		c.clear_aim()
	c.set_weapon("blaster", "gold")
	c._apply_gun()
	c.draw_gun()
	eq(sprite.texture, Art.gun("blaster", "gold")["texture"], "no blaster hug art: the blaster sprite")
	c.clear_aim()
	check(not gun.visible, "put away")
	holder.free()


## Flora, Tanko and Spark kneel on their ready pose too: Tanko hugs his hug cannon, Flora her hug
## seed launcher, Spark his hug shock rifle, round its hold (every tier its own hug art); that point on the
## hug point at every direction (drawn as the pose scene's Preview shows its iron one), the muzzle
## flash at the gun's muzzle, the front arm over it, idle again after.
func test_flora_tanko_spark_hug_their_gun() -> void:
	var Art := preload("res://ui/art.gd")
	for id in ["flora", "tanko", "spark"]:
		var kind := Art.character_gun(id)
		var c: Node2D = CharacterScene.instantiate()
		c.character_id = id
		c.holster = true
		var holder := Node2D.new()
		holder.add_child(c)
		c._ready()
		var flip: Node2D = c.get_node("Flip")
		var gun: Node2D = c.get_node("Flip/Gun")
		var sprite: Sprite2D = c.get_node("Flip/Gun/Sprite")
		var arm: Sprite2D = c.get_node("Flip/ArmFront")
		c.set_weapon(kind, "iron")
		c._apply_gun()
		c.draw_gun()
		eq(c.animation(), "draw", "%s the ready frame" % id)
		var hug := Art.hug_gun(kind, "iron")
		check(hug["hug"], "%s %s: its hug art" % [id, kind])
		eq(sprite.texture, hug["texture"], "%s hugs the iron %s" % [id, kind])
		check(not c.get_node("Flip/Gun/Hand").visible, "%s no grip hand" % id)
		check(arm.visible and arm.texture == Art.side_view(id)["ready"]["arm_front"] and arm.get_index() == gun.get_index() + 1, "%s the front arm over the gun" % id)
		var rp := Art.ready_pose(id)
		c.aim(0.0)
		check((flip.transform * gun.transform * sprite.transform).is_equal_approx(rp["socket"] * rp["preview"]), "%s drawn as the Preview shows it" % id)
		for f in [1, -1]:
			c.facing = f
			c._apply_motion()
			for e in [-45.0, 0.0, 45.0, 90.0]:
				c.aim(e if f > 0 else 180.0 - e)
				var centre: Vector2 = flip.transform * gun.transform * sprite.transform * hug["pivot"]
				check(centre.distance_to(flip.transform * rp["socket"].origin) < 0.01, "%s side %d at %d: the hold / centre on the hug point" % [id, f, e])
				check(c.muzzle_position().distance_to(c.global_position) > 10.0, "%s side %d at %d: a muzzle" % [id, f, e])
				if hug["hug"]:
					var muzzle: Vector2 = c.global_transform * (flip.transform * gun.transform * sprite.transform * hug["muzzle"])
					check(c.muzzle_position().distance_to(muzzle) < 0.01, "%s side %d at %d: the flash at the hug gun's muzzle" % [id, f, e])
		# every tier its own hug art, as long, its hold on the hug point, the flash at its muzzle
		c.facing = 1
		c._apply_motion()
		for tier in Art.GUN_TIERS[kind]:
			c.set_weapon(kind, tier)
			c._apply_gun()
			c.aim(0.0)
			var want := Art.hug_gun(kind, tier)
			check(want["hug"] and want["tier"] == tier and sprite.texture == want["texture"], "%s %s %s: its hug art" % [id, tier, kind])
			near(sprite.transform.basis_xform(Vector2(float(want["size"].x), 0.0)).length(), rp["preview"].basis_xform(Vector2(float(rp["length"]), 0.0)).length(), 0.05, "%s %s %s: as long as the Preview's" % [id, tier, kind])
			check((gun.transform * sprite.transform * want["pivot"]).distance_to(rp["socket"].origin) < 0.01, "%s %s %s: its hold on the hug point" % [id, tier, kind])
			var muzzle: Vector2 = c.global_transform * (flip.transform * gun.transform * sprite.transform * want["muzzle"])
			check(c.muzzle_position().distance_to(muzzle) < 0.01, "%s %s %s: the flash at its muzzle" % [id, tier, kind])
		c.clear_aim()
		eq(c.animation(), "idle", "%s idle again" % id)
		check(not gun.visible and not arm.visible, "%s gun and front arm away" % id)
		holder.free()


## The widest row in the top fifth of the figure (the cap's brim), px.
func _widest_top(img: Image) -> int:
	var used := img.get_used_rect()
	var best := 0
	for y in range(used.position.y, used.position.y + used.size.y / 5):
		var x0 := -1
		var x1 := -1
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				if x0 < 0:
					x0 = x
				x1 = x
		best = maxi(best, x1 - x0 + 1 if x0 >= 0 else 0)
	return best


## The lowest row with a mostly opaque pixel (the soles).
func _sole_row(img: Image) -> int:
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				return y
	return -1


## Each character's carry.json (ui/art.gd parse_carry()): its carry scene (back.scene:
## scenes/character/poses/<id>_carry.tscn) and the bob one per walk frame (tools/carry_bob.gd),
## listed with the side view's files; the scene's socket (ui/art.gd carry_pose()) holds the gun on
## the idle frame's back half, muzzle up and back, low on the gun.
func test_carry_assets() -> void:
	var Art := preload("res://ui/art.gd")
	for id in Art.CHARACTERS:
		var look: Dictionary = Art.character_look(id)
		var carry: Dictionary = look["carry"]
		check(carry.has("back") and not carry.has("hand"), "%s: the back sling only" % id)
		var back: Dictionary = carry["back"]
		eq(back["scene"], "res://scenes/character/poses/%s_carry.tscn" % id, "%s: its carry scene" % id)
		check(not back.has("at"), "%s: the placement is the scene's, not the file's" % id)
		var cp: Dictionary = Art.carry_pose(id)
		check(not cp.is_empty(), "%s: the carry scene loads" % id)
		var sock: Transform2D = cp["socket"]
		var k := float(look["scale"])
		var at: Vector2 = sock.origin / k + look["pivot"]
		var size: Vector2 = look["size"]
		check(at.x > 0.0 and at.y > 0.0 and at.x < float(look["pivot"].x) and at.y < size.y, "%s: on the back half of the frame (%s)" % [id, at])
		var deg := rad_to_deg(sock.get_rotation())
		check(deg < -90.0 and deg > -180.0, "%s: muzzle up and back (%s)" % [id, deg])
		var hold: Vector2 = cp["hold"]
		check(hold.x > 0.0 and hold.x < 0.5 * float(cp["length"]), "%s: hung low on the gun" % id)
		check(cp["texture"] != null and cp["texture"].resource_path == Art.hug_gun_path(Art.character_gun(Art.PLACEHOLDER_SOURCE.get(id, id)), "iron"),
			"%s: the Preview is its iron hug gun" % id)
		eq(back["bob"].size(), look["frames"].get_frame_count("walk"), "%s: a bob per walk frame" % id)
		check(Art.side_paths(id).has(Art.side_dir(id) + "carry.json"), "%s: carry.json among the side view's files" % id)
