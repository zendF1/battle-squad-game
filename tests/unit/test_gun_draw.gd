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


## The character with holster on (the match): no gun until aimed, walk holsters first, a shot
## from a holstered gun leaves from the drawn gun's muzzle.
func test_character_holster() -> void:
	var c: Node2D = CharacterScene.instantiate()
	c.character_id = "rookie"
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
	var anchor: Dictionary = Art_gun_anchor("idle")
	near(rad_to_deg(gun.rotation), float(anchor["angle"]) - 40.0, 0.01, "turned to the aim")
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


func Art_gun_anchor(anim: String) -> Dictionary:
	return preload("res://ui/art.gd").gun_anchor("rookie", anim, 0)


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
