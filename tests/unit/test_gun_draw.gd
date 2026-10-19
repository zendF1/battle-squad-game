extends "res://tests/test_case.gd"
## The match's gun draw (scenes/character/gun_draw.gd) and how the character shows it.

const GunDraw := preload("res://scenes/character/gun_draw.gd")
const CharacterScene := preload("res://scenes/character/character.tscn")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")


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
## pose: Tanko's baked frames): no gun until aimed, walk holsters first, a shot from a holstered
## gun leaves from the drawn gun's muzzle.
func test_character_holster() -> void:
	var c: Node2D = CharacterScene.instantiate()
	c.character_id = "tanko"
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
	var anchor: Dictionary = preload("res://ui/art.gd").gun_anchor("tanko", "idle", 0)
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


## Out of the match (holster off) the gun is always in hand, as before.
func test_character_without_holster_keeps_the_gun() -> void:
	var c: Node2D = CharacterScene.instantiate()
	var holder := Node.new()
	holder.add_child(c)
	c._ready()
	check(c.holds_gun(), "gun in hand")
	eq(c.shoot(), 0.0, "fires at once")
	holder.free()


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
	for f in ["idle_0.png", "walk_0.png", "walk_3.png", "hand.png", "gun_anchors.json"]:
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
	for f in ["idle_0.png", "walk_0.png", "walk_3.png", "hand.png", "gun_anchors.json"]:
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


## Rookie's drawn ready pose: side.json draw = ready_0 (kneeling, the fists together on the chest,
## no gun), fire = it with the recoil, gunDraw all 0 s; the hug gun is placed in
## scenes/character/poses/rookie_ready.tscn. No hand cut-outs; the near arm (sleeve and both fists)
## cut from ready_0 into ready_arm_front.png on the same canvas, drawn over the gun.
func test_rookie_ready_pose_assets() -> void:
	var Art := preload("res://ui/art.gd")
	var dir := Art.side_dir("rookie")
	check(FileAccess.file_exists(dir + "ready_0.png"), "ready_0.png")
	check(not FileAccess.file_exists(dir + "ready_hand_front.png") and not FileAccess.file_exists(dir + "ready_hand_back.png"), "no hand PNGs")
	check(ResourceLoader.exists("res://scenes/character/poses/rookie_ready.tscn"), "the pose scene")
	var look := Art.side_view("rookie")
	check(bool(look["draw_frames"]) and bool(look["fire_frames"]), "draw and fire frames")
	eq(look["frames"].get_frame_count("draw"), 1, "one ready frame")
	eq(look["frames"].get_frame_count("fire"), 3, "three fire frames")
	eq(look["motions"]["fire"], "recoil", "the fire recoils")
	eq(look["ready"].keys(), ["anims", "scene", "arm_front"], "readyPose: anims, scene and the front arm, no hands")
	eq(look["ready"]["anims"], ["draw", "fire"], "readyPose anims")
	eq(look["ready"]["scene"], "res://scenes/character/poses/rookie_ready.tscn", "readyPose scene")
	check(look["ready"]["arm_front"] is Texture2D, "readyPose front arm")
	check(Art.side_paths("rookie").has(dir + "ready_arm_front.png"), "the front arm is one of the side view's files")
	for key in ["drawSec", "fastDrawSec", "holsterSec"]:
		near(float(look["gun_draw"].get(key, -1.0)), 0.0, 1e-9, "gunDraw %s 0" % key)
	for anim in ["draw", "fire"]:
		eq(look["anchors"].get(anim, []).size(), look["frames"].get_frame_count(anim), "%s anchors per frame" % anim)
	# The scene: one socket on the hug point, its Preview the iron hug bazooka at the weapons' scale.
	var rp := Art.ready_pose("rookie")
	for key in ["socket", "preview", "pivot", "length"]:
		check(rp.has(key), "ready_pose %s" % key)
	check(not rp.has("hands") and not rp.has("aim"), "no hands, no aim range")
	var meta := Art.hug_meta("bazooka", "iron")
	eq(rp["pivot"], meta["pivot"], "turned round the hug gun's hold")
	near(float(rp["length"]), float(meta["size"].x), 1e-6, "the hug gun's length")
	var root: Node = load("res://scenes/character/poses/rookie_ready.tscn").instantiate()
	var sock: Node2D = root.get_node("GunSocket")
	var preview: Sprite2D = root.get_node("GunSocket/Preview")
	check(rp["socket"].is_equal_approx(sock.transform), "the socket as placed")
	check(rp["preview"].is_equal_approx(preview.transform * Transform2D(0.0, preview.offset)), "the Preview as placed (its offset too)")
	root.free()
	# Same ground and body place as idle: the soles' row on the pivot row, one canvas.
	var idle := Image.load_from_file(ProjectSettings.globalize_path(dir + "idle_0.png"))
	var ready := Image.load_from_file(ProjectSettings.globalize_path(dir + "ready_0.png"))
	var pivot: Vector2 = look["pivot"]
	eq(ready.get_size(), idle.get_size(), "one canvas")
	near(float(_sole_row(ready)), float(_sole_row(idle)), 1.0, "on the idle's ground")
	near(float(_sole_row(ready)) + 1.0, pivot.y, 1.0, "soles on the pivot row")
	# As big as standing Rookie: the cap as wide (± 10 %), not as tall.
	near(float(_widest_top(ready)), float(_widest_top(idle)), _widest_top(idle) * 0.1, "the cap as wide as the idle's")
	# The hug point (the fallback seat, the socket) between the fists, at chest height.
	var grip: Vector2 = look["anchors"]["draw"][0]["grip"]
	check(grip.x > pivot.x + 5.0 and grip.y < pivot.y - 40.0, "the hug point on the chest (%s)" % grip)
	check(ready.get_pixelv(Vector2i(grip.round())).a > 0.9, "on the fists")
	var green := 0
	for y in ready.get_height():
		for x in ready.get_width():
			var c := ready.get_pixel(x, y)
			if c.a > 0.1 and c.g > 0.6 and c.g > maxf(c.r, c.b) + 0.3:
				green += 1
	eq(green, 0, "no green-screen pixels left")
	# The front arm: on ready_0's canvas, a part of it (every pixel it has, ready_0 has there), on
	# the fists (the hug point) and the near shoulder, not the head or the legs.
	var arm := Image.load_from_file(ProjectSettings.globalize_path(dir + "ready_arm_front.png"))
	eq(arm.get_size(), ready.get_size(), "front arm: ready_0's canvas")
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
	check(arm_px > 200 and arm_px < ready.get_used_rect().get_area() / 4, "front arm: a part of the body (%d px)" % arm_px)
	eq(outside, 0, "front arm: only where ready_0 is drawn")
	eq(green, 0, "front arm: no green-screen pixels")
	check(arm.get_pixelv(Vector2i(grip.round())).a > 0.9, "front arm: on the fists (the hug point)")
	var arm_rect := arm.get_used_rect()
	check(arm_rect.position.y > ready.get_used_rect().position.y + ready.get_used_rect().size.y * 0.3, "front arm: below the head")
	check(arm_rect.end.y < pivot.y - 20.0, "front arm: above the legs")
	check(arm_rect.position.x < grip.x - 20.0, "front arm: from the near shoulder (%s)" % arm_rect)
	# The pixels it has are ready_0's (same keying / cleanup).
	var same := 0
	var opaque := 0
	for y in arm.get_height():
		for x in arm.get_width():
			var a := arm.get_pixel(x, y)
			if a.a > 0.99:
				opaque += 1
				var b := ready.get_pixel(x, y)
				if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.05:
					same += 1
	check(opaque > 0 and same >= opaque * 0.95, "front arm: ready_0's colours (%d of %d)" % [same, opaque])


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
	var hug := Art.hug_gun("bazooka", "iron")
	eq(sprite.texture, hug["texture"], "the iron hug gun (no weapon: the starter's kind)")
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
	# The gun hugged: the weapon's hug art → its kind's in another tier → its gun sprite round its
	# centre, as long as the Preview's gun, its pivot on the hug point.
	var drawn := func() -> float: return sprite.transform.basis_xform(Vector2(sprite.texture.get_width(), 0.0)).length()
	var preview_xf: Transform2D = sock * rp["preview"]
	var hug_len := preview_xf.basis_xform(Vector2(float(rp["length"]), 0.0)).length()
	for kt in [["bazooka", "basic"], ["bazooka", "iron"], ["bazooka", "dragon"], ["blaster", "gold"], ["", ""]]:
		c.set_weapon(kt[0], kt[1])
		c._apply_gun() # out of the tree: set_weapon() only stores it
		c.draw_gun()
		c.aim(0.0)
		var want := Art.hug_gun(kt[0] if kt[0] != "" else "bazooka", kt[1] if kt[1] != "" else Art.GUN_BASIC)
		eq(sprite.texture, want["texture"], "%s %s: its pose gun" % kt)
		check(kt[0] == "blaster" or want["hug"], "%s %s: hug art" % kt)
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
