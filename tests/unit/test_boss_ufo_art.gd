extends "res://tests/test_case.gd"
## Đĩa Bay Thép (steel_robot)'s drawn art: the frames made from its one concept picture
## (art_source/bosses/steel_robot/make_frames.py) and imported (tools/import_boss_frames.gd with
## background.key "alpha", parts), read by ui/art.gd; the importer's alpha key and parts.

const ImportBossFrames := preload("res://tools/import_boss_frames.gd")
const Art := preload("res://ui/art.gd")
const BossBody := preload("res://match/boss/boss_body.gd")
const BossArtView := preload("res://match/boss/boss_art_view.gd")


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
	check(parts is Dictionary and parts["parts"].has("hull") and parts["parts"].has("dome"), "the hull and the dome parts")
	for p in ["hull", "dome"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/bosses/steel_robot/parts/%s.png" % p))
		eq([img.get_width(), img.get_height()], [int(parts["parts"][p]["size"][0]), int(parts["parts"][p]["size"][1])], "%s size" % p)
	check(float(parts["parts"]["dome"]["at"][1]) < float(parts["parts"]["hull"]["at"][1]), "the dome over the hull")


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
