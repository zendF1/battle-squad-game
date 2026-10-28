extends "res://tests/test_case.gd"
## The screen backgrounds: the mode → image mapping (screens/home/lobby_model.gd background(),
## stage_background(), background_of_queue()), the fallback to lobby_bg (ui/art.gd
## background_key()), the "cover" source rect and the blurred copy.

const BossFixture := preload("res://tests/boss_fixture.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const Art := preload("res://ui/art.gd")

const BOSSES := ["steel_robot", "lava_crab", "ice_witch", "rock_giant", "tree_spirit"]


func test_pvp_modes_take_the_pvp_image_boss_modes_their_boss() -> void:
	BossFixture.take()
	for name in ["Đấu thường 2vs2", "Đấu hạng 2vs2", "Đấu máy", "Luyện tập"]:
		var i := _index_of(name)
		check(i >= 0, "%s in the fixture" % name)
		eq(LobbyModel.background(i), Art.BG_PVP, name)
	for id in BOSSES:
		var i := LobbyModel.index_of_queue("boss:" + id)
		eq(LobbyModel.background(i), "matchmaking_boss_" + id, id)
		eq(Art.background_key(LobbyModel.background(i)), "matchmaking_boss_" + id, "%s has its image" % id)


func test_no_or_unknown_category_is_the_lobby_image() -> void:
	# tests/fixtures/gamedata.json: an older server, no categories
	for i in LobbyModel.modes().size():
		eq(LobbyModel.background(i), Art.BG_DEFAULT, "mode %d without a category" % i)
	eq(LobbyModel.background_of(LobbyModel.NONE), Art.BG_DEFAULT, "no mode")
	eq(LobbyModel.background_of({"id": "x", "category": "event", "queue": "x"}), Art.BG_DEFAULT, "an unknown category")


func test_a_boss_mode_without_a_boss_entry_uses_its_queue() -> void:
	BossFixture.take()
	var m := {"id": "boss_frost_dragon", "category": "boss", "queue": "boss:frost_dragon"}
	eq(LobbyModel.background_of(m), "matchmaking_boss_frost_dragon", "the id after boss:")
	eq(Art.background_key("matchmaking_boss_frost_dragon"), Art.BG_DEFAULT, "no art yet: lobby_bg")
	eq(LobbyModel.background_of({"id": "boss_x", "category": "boss", "queue": ""}), Art.BG_DEFAULT, "no boss at all")


func test_stage_shows_the_lobby_image_until_a_mode_is_picked() -> void:
	BossFixture.take()
	var witch := LobbyModel.index_of_queue("boss:ice_witch")
	var ranked := LobbyModel.index_of_queue("ranked_2v2")
	eq(LobbyModel.stage_background(witch, false), Art.BG_DEFAULT, "restored mode, not picked: lobby_bg")
	eq(LobbyModel.stage_background(ranked, false), Art.BG_DEFAULT, "restored PvP mode: lobby_bg")
	eq(LobbyModel.stage_background(witch, true), "matchmaking_boss_ice_witch", "picked: the boss's image")
	eq(LobbyModel.stage_background(ranked, true), Art.BG_PVP, "picked PvP: the PvP image")


func test_matchmaking_takes_the_queued_modes_image() -> void:
	BossFixture.take()
	eq(LobbyModel.background_of_queue("casual_2v2"), Art.BG_PVP, "casual")
	eq(LobbyModel.background_of_queue("ranked_2v2"), Art.BG_PVP, "ranked")
	eq(LobbyModel.background_of_queue("boss:lava_crab"), "matchmaking_boss_lava_crab", "a boss queue")
	eq(LobbyModel.background_of_queue("boss:frost_dragon"), "matchmaking_boss_frost_dragon", "a boss queue no mode joins")
	eq(LobbyModel.background_of_queue("pvp_1v1"), Art.BG_PVP, "a PvP queue no mode joins")
	eq(LobbyModel.background_of_queue(LobbyModel.mode(LobbyModel.index_of_queue("boss:ice_witch"))["queue"]),
		LobbyModel.stage_background(LobbyModel.index_of_queue("boss:ice_witch"), true), "the image the lobby showed")


func test_background_key_falls_back_to_the_lobby_image() -> void:
	for key in [Art.BG_DEFAULT, Art.BG_PVP, Art.BG_RESULT, Art.BG_HOME]:
		eq(Art.background_key(key), key, key)
		check(Art.has_png(Art.background_path(key)), "%s is in the project" % key)
	for key in ["", "matchmaking_boss_nobody", "../env/lobby_bg", "lobby_bg.png"]:
		eq(Art.background_key(key), Art.BG_DEFAULT, "'%s'" % key)
	for id in BOSSES:
		eq(Art.ENV.get(Art.boss_background(id)), Art.background_path(Art.boss_background(id)), "%s listed in ENV" % id)


func test_cover_source_keeps_the_aspect_and_centres() -> void:
	var tex := Vector2(1024, 434)
	# 16:9: the full height, the sides cut evenly
	var r := Art.cover_source(tex, Vector2(1600, 900))
	near(r.size.y, 434.0, 0.001, "16:9 full height")
	near(r.size.x, 1600.0 * 434.0 / 900.0, 0.001, "16:9 width at the rect's aspect")
	near(r.position.x, (1024.0 - r.size.x) / 2.0, 0.001, "16:9 centred")
	near(r.position.y, 0.0, 0.001, "16:9 from the top")
	# iPhone 19.5:9 on the 1600x900 base (stretch aspect expand): 1950x900
	r = Art.cover_source(tex, Vector2(1950, 900))
	near(r.size.x / r.size.y, 1950.0 / 900.0, 0.0001, "19.5:9 aspect kept")
	near(r.position.x * 2.0 + r.size.x, 1024.0, 0.001, "19.5:9 cut evenly")
	# wider than the image: the full width, top and bottom cut evenly
	r = Art.cover_source(tex, Vector2(3000, 900))
	near(r.size.x, 1024.0, 0.001, "wide: full width")
	near(r.size.y, 1024.0 * 900.0 / 3000.0, 0.001, "wide: height at the rect's aspect")
	near(r.position.y * 2.0 + r.size.y, 434.0, 0.001, "wide: cut evenly")
	# the same aspect: the whole image
	eq(Art.cover_source(tex, tex * 2.0), Rect2(Vector2.ZERO, tex), "same aspect: all of it")
	eq(Art.cover_source(tex, Vector2.ZERO), Rect2(Vector2.ZERO, tex), "an empty rect: all of it")


func test_blurred_copy_is_lightly_soft_and_keeps_the_aspect() -> void:
	var sharp := Art.background(Art.BG_PVP)
	var blur := Art.blurred_background(Art.BG_PVP)
	check(blur != sharp, "a separate texture")
	eq(blur.get_width(), Art.BLUR_KEEP, "kept width")
	near(float(blur.get_width()) / blur.get_height(), float(sharp.get_width()) / sharp.get_height(), 0.01, "same aspect")
	check(Art.blurred_background(Art.BG_PVP) == blur, "made once")
	var a := sharp.get_image()
	a.resize(blur.get_width(), blur.get_height(), Image.INTERPOLATE_BILINEAR)
	var rough := _roughness(blur.get_image())
	var sharp_rough := _roughness(a)
	check(rough < sharp_rough * 0.9, "smoother than the sharp image (%f / %f)" % [rough, sharp_rough])
	check(rough > sharp_rough * 0.3, "only lightly: the picture still reads (%f / %f)" % [rough, sharp_rough])
	check(Art.blurred_background("matchmaking_boss_nobody") == Art.blurred_background(Art.BG_DEFAULT), "fallback blurred too")


func test_gaussian_blur_spreads_evenly_and_keeps_flat_colour() -> void:
	var img := Image.create(21, 21, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	img.set_pixel(10, 10, Color.WHITE)
	var b := Art.gaussian_blur(img, 2.0)
	eq(b.get_size(), img.get_size(), "same size")
	check(b.get_pixel(10, 10).r < 0.2, "the peak spread out")
	near(b.get_pixel(8, 10).r, b.get_pixel(12, 10).r, 0.005, "left = right")
	near(b.get_pixel(10, 8).r, b.get_pixel(10, 12).r, 0.005, "up = down")
	near(b.get_pixel(8, 10).r, b.get_pixel(10, 8).r, 0.005, "horizontal = vertical")
	var flat := Image.create(9, 5, false, Image.FORMAT_RGB8)
	flat.fill(Color8(40, 120, 200))
	eq(Art.gaussian_blur(flat, 1.8).get_pixel(0, 0).to_rgba32(), Color8(40, 120, 200).to_rgba32(), "a flat colour stays (edges clamped)")


static func _index_of(mode_name: String) -> int:
	var all := LobbyModel.modes()
	for i in all.size():
		if all[i]["name"] == mode_name:
			return i
	return -1


## The mean colour difference between horizontal neighbours.
static func _roughness(img: Image) -> float:
	var total := 0.0
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(1, img.get_width()):
			var c := img.get_pixel(x, y)
			var p := img.get_pixel(x - 1, y)
			total += absf(c.r - p.r) + absf(c.g - p.g) + absf(c.b - p.b)
			n += 1
	return total / maxf(n, 1)
