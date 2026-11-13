extends "res://tests/test_case.gd"
## Đĩa Bay Thép (steel_robot)'s drawn art: the frames made from its one concept picture
## (art_source/bosses/steel_robot/make_frames.py) and imported (tools/import_boss_frames.gd with
## background.key "alpha", parts), read by ui/art.gd; the importer's alpha key and parts.

const ImportBossFrames := preload("res://tools/import_boss_frames.gd")
const Art := preload("res://ui/art.gd")
const BossBody := preload("res://match/boss/boss_body.gd")
const BossArtView := preload("res://match/boss/boss_art_view.gd")
const BossArt := preload("res://match/boss/boss_art.gd")


func test_the_ufo_has_frames_pictures_and_parts() -> void:
	var side := Art.boss_side("steel_robot")
	check(not side.is_empty(), "assets/bosses/steel_robot/side/side.json loads")
	for anim in ["idle", "fly", "cast", "burst", "summon", "hurt"]:
		check(side["anims"].has(anim) and not side["anims"][anim]["frames"].is_empty(), "%s frames" % anim)
	check(bool(side["anims"]["idle"]["loop"]) and bool(side["anims"]["fly"]["loop"]), "idle and fly loop")
	eq([side["anims"]["cast"]["peak"], side["anims"]["burst"]["peak"], side["anims"]["summon"]["peak"]], [3, 2, 2], "the peaks")
	eq(side["height"], 240.0, "the body (dome top to the claw's bottom) 240 px")
	var png := Image.load_from_file(ProjectSettings.globalize_path("res://assets/bosses/steel_robot/side/hurt_0.png"))
	eq(Vector2(png.get_size()), side["size"], "every frame on the shared canvas")
	check(side["pivot"].y > side["height"], "the feet under the dome's top")
	check(Art.boss_picture("steel_robot", "portrait") != null and Art.boss_picture("steel_robot", "bust") != null, "portrait and bust")
	var parts = JSON.parse_string(FileAccess.get_file_as_string("res://assets/bosses/steel_robot/parts/parts.json"))
	check(parts is Dictionary and parts["parts"].has("hull") and parts["parts"].has("dome") and parts["parts"].has("cannon"),
		"the hull, the dome and the cannon parts")
	check(parts["parts"]["cannon"].get("pivot") is Array, "the cannon part turns round its hub")
	for p in ["hull", "dome", "cannon"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/bosses/steel_robot/parts/%s.png" % p))
		eq([img.get_width(), img.get_height()], [int(parts["parts"][p]["size"][0]), int(parts["parts"][p]["size"][1])], "%s size" % p)
	check(float(parts["parts"]["dome"]["at"][1]) < float(parts["parts"]["hull"]["at"][1]), "the dome over the hull")


func test_the_ufo_turret_turns_on_its_own() -> void:
	var t = JSON.parse_string(FileAccess.get_file_as_string("res://assets/bosses/steel_robot/turret/turret.json"))
	check(t is Dictionary, "assets/bosses/steel_robot/turret/turret.json loads")
	eq(t["frames"], ["idle", "charge_0", "charge_1", "hot", "recoil_0", "recoil_1"], "the turret's states")
	eq(t["states"]["charge"], ["charge_0", "charge_1"], "the states grouped")
	for f in t["frames"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/bosses/steel_robot/turret/%s.png" % f))
		eq([img.get_width(), img.get_height()], [int(t["size"][0]), int(t["size"][1])], "%s on the turret's canvas" % f)
	var pivot := Vector2(float(t["pivot"][0]), float(t["pivot"][1]))
	var idle := Image.load_from_file(ProjectSettings.globalize_path("res://assets/bosses/steel_robot/turret/idle.png"))
	check(idle.get_pixelv(Vector2i(pivot.round())).a > 0.9, "the pivot is on the hub")
	var mid := Vector2(float(t["tips"]["mid"][0]), float(t["tips"]["mid"][1]))
	near(mid.y, 0.0, 0.05, "the tips' middle on the line from the pivot (pointing right)")
	var upper := pivot + Vector2(float(t["tips"]["upper"][0]), float(t["tips"]["upper"][1]))
	var px := idle.get_pixelv(Vector2i(upper.round()))
	check(px.a > 0.9 and px.r > 0.85 and px.b < 0.5, "the upper tip on its glowing orange muzzle (%s)" % px)
	var unit_mount := Vector2(float(t["unit"]["mount"][0]), float(t["unit"]["mount"][1]))
	check(unit_mount.x > 30.0 and unit_mount.x < 40.0 and unit_mount.y < -18.0 and unit_mount.y > -30.0,
		"the mount under the hull's right side (unit frame %s)" % unit_mount)
	near(float(t["unit"]["tips"]["mid"][0]) * 2.4, float(t["tips"]["mid"][0]), 0.05, "unit frame = texture px / 2.4")
	check(float(t["range"][0]) < float(t["rest"]) and float(t["rest"]) < float(t["range"][1]), "it rests inside its range")
	for anim in Art.boss_side("steel_robot")["anims"]:
		eq(t["bodyFrames"][anim].size(), Art.boss_side("steel_robot")["anims"][anim]["frames"].size(), "a mount per %s frame" % anim)
	eq(t["bodyFrames"]["idle"][0][2], 0.0, "no turn on the idle frames")
	check(float(t["bodyFrames"]["hurt"][0][2]) < 0.0, "the hurt's nose-up tilt turns it up")
	var parts = JSON.parse_string(FileAccess.get_file_as_string("res://assets/bosses/steel_robot/parts/parts.json"))
	var cannon: Dictionary = parts["parts"]["cannon"]
	var at := Vector2(float(cannon["at"][0]), float(cannon["at"][1])) + Vector2(float(cannon["pivot"][0]), float(cannon["pivot"][1]))
	check(at.distance_to(Vector2(float(t["mount"][0]), float(t["mount"][1]))) < 1.0, "the cannon part's hub on the mount")


func test_the_ufo_body_draws_frames() -> void:
	var b := BossBody.new()
	b.setup("steel_robot", 150.0)
	check(b.has_frames() and b.anim() != null, "drawn from frames")
	eq(b.shown_frame()[0], "idle", "the idle frames")
	check(b.play_action({"anim": "summon", "at": 0.3}) > 0.3, "the summon plays")
	b.free()
	var bust = BossArtView.make("steel_robot", Vector2(70, 70), 1, "bust")
	check(bust.picture_texture() != null, "the HP bar's icon is the dome bust")
	bust.free()


func test_alpha_key_keeps_the_picture() -> void:
	var img := Image.create(20, 10, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(2, 2, 6, 6), Color(0.6, 0.62, 0.66, 1.0))
	img.set_pixel(15, 5, Color(1, 1, 1, 2.0 / 255.0)) # faint: cleared
	img.set_pixel(16, 5, Color(0.7, 0.9, 1.0, 0.5)) # a soft glow: kept
	var opts := ImportBossFrames.spec_cfg({"background": {"key": "alpha"}, "alphaCut": 6}, {})
	eq(ImportBossFrames.keyed(img, opts), 0, "nothing keyed")
	eq(img.get_pixel(4, 4).a, 1.0, "the body as it was")
	eq(img.get_pixel(15, 5).a, 0.0, "faint px cleared")
	check(img.get_pixel(16, 5).a > 0.4, "soft alpha kept")


func test_the_ufo_in_a_match_hovers_banks_and_trails() -> void:
	var t = JSON.parse_string(FileAccess.get_file_as_string("res://assets/bosses/steel_robot/turret/turret.json"))
	var rest := deg_to_rad(float(t["rest"]))
	var tip := Vector2(t["unit"]["mount"][0], t["unit"]["mount"][1]) + Vector2(float(t["unit"]["tips"]["mid"][0]), 0.0).rotated(rest)
	check(BossArt.MUZZLE["steel_robot"].distance_to(tip) < 0.2, "the muzzle: the turret's mid tip at rest (%s, %s)" % [BossArt.MUZZLE["steel_robot"], tip])
	near(BossArt.top("steel_robot"), 1.125, 0.001, "the antenna over the dome")
	check(BossArt.TRAIL.has("steel_robot") and BossArt.trail_from("steel_robot") < 0.05, "jet puffs under the claws")
	near(BossArt.trail_from("ice_witch"), BossArt.TRAIL_FROM_DEFAULT, 0.001, "the witch's trail where it was")
	check(BossArt.lean_scale("steel_robot") > 1.0 and BossArt.lean_scale("ice_witch") == 1.0, "the saucer banks harder")
	var b := BossBody.new()
	b.setup("steel_robot", 240.0)
	b.flying = true
	var ys := []
	for i in 30:
		b._process(0.05)
		ys.append(b._bob_px())
	check(ys.max() - ys.min() > 4.0, "a flying drawn boss bobs (%f..%f)" % [ys.min(), ys.max()])
	near(b.shield_ball().position.y, b._bob_px() - 120.0, 0.01, "the shield follows the bob")
	eq(b.shield_ball().tint, BossArt.accent("steel_robot"), "the shield in its own accent")
	var still := b.muzzle_position()
	b.lean = 0.2
	check(b.muzzle_position().distance_to(still) > 5.0, "the muzzle turns with the lean")
	b.free()
	var w := BossBody.new()
	w.setup("ice_witch", 162.4)
	eq(w.shield_ball().tint, BossArt.accent("ice_witch"), "the witch keeps her icy shield")
	w.free()


func test_the_ufo_crashes_instead_of_shattering() -> void:
	check(not Art.boss_parts("steel_robot").is_empty(), "its parts load")
	eq(Art.boss_parts("ice_witch"), {}, "none for the witch")
	var b := BossBody.new()
	b.setup("steel_robot", 240.0)
	b.flying = true
	b.die()
	eq(b.death_phase(), "wobble", "first it shakes")
	eq(b.shown_frame(), ["hurt", 0], "on its first hurt frame")
	b._process(0.3)
	eq(b.shatter_count(), 0, "no ice shards")
	check(b._cracks.is_empty(), "no cracks")
	check(not b._zaps.is_empty() or not b._smoke.is_empty(), "sparks and smoke")
	b._process(BossBody.CRASH_WOBBLE - 0.3 + 0.01)
	eq(b.death_phase(), "fall", "then it falls")
	check(not b._dome.is_empty(), "the dome popped off")
	var dome_y: float = b._dome["p"].y
	b._process(0.3)
	check(b._dome["p"].y != dome_y, "the dome flies")
	b._process(BossBody.CRASH_FALL)
	eq(b.death_phase(), "boom", "then it blows up")
	eq(b._debris.size(), BossBody.CRASH_DEBRIS, "steel debris")
	check(b._boom_at.y > -240.0 * 0.43 + 50.0, "lower than it flew")
	b._process(BossBody.CRASH_SEC)
	eq(b.death_phase(), "gone", "over")
	near(b.death_progress(), 1.0, 0.001, "done")
	b.free()
	var w := BossBody.new()
	w.setup("ice_witch", 162.4)
	w.die()
	eq(w.death_phase(), "crack", "the witch still cracks")
	w.free()
