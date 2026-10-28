extends "res://tests/test_case.gd"
## The leaderboards (GET /leaderboard) and Lực chiến: parsing a board, the podium order, the
## values shown per board, the season chip, the power text, the power on the lobby / Nhân vật
## character info and the profile, PlayerState's board cache, and the page's podium and pinned row.

const LeaderboardModel := preload("res://screens/home/leaderboard_model.gd")
const LeaderboardPage := preload("res://screens/home/leaderboard_page.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const PowerTag := preload("res://ui/power_tag.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const PlayerStateScript := preload("res://autoload/player_state.gd")


static func _row(pos: int, id: String, extra: Dictionary = {}) -> Dictionary:
	var r := {"pos": pos, "playerId": id, "displayName": "P" + id, "level": 30 - pos, "rankBadge": "", "grade": "binh_nhi",
		"gradeDivision": 3, "rankPoints": 0, "power": 50000 - pos * 1000, "powerCharacterId": "rookie"}
	r.merge(extra, true)
	return r


static func _board() -> Dictionary:
	return {"type": "rank", "seasonId": "s1", "seasonName": "Mùa 1", "total": 120,
		"entries": [
			_row(1, "a", {"displayName": "Đại Ca", "level": 52, "rankBadge": "trung_ta", "grade": "dai_ta", "gradeDivision": 1,
				"rankPoints": 4230, "power": 98765, "powerCharacterId": "tanko",
				"equippedTitle": {"id": "smith", "name": "Thợ rèn lành nghề", "rarity": "blue"}}),
			_row(2, "b", {"grade": "thuong_ta", "gradeDivision": 2, "rankPoints": 3850}),
			_row(3, "c"),
			_row(4, "me", {"displayName": "Tôi"}),
			"junk", {"pos": 5}, # not rows: skipped
		],
		"me": _row(4, "me", {"displayName": "Tôi"})}


func test_parse_a_board() -> void:
	var p := LeaderboardModel.parse(_board())
	eq(p["type"], "rank", "type")
	eq(p["season_id"], "s1", "season id")
	eq(p["season_name"], "Mùa 1", "season name")
	eq(p["total"], 120, "total")
	eq(p["entries"].size(), 4, "rows without a player id are skipped")
	var top: Dictionary = p["entries"][0]
	eq(top["pos"], 1, "pos")
	eq(top["player_id"], "a", "player id")
	eq(top["name"], "Đại Ca", "name")
	eq(top["level"], 52, "level")
	eq(top["badge"], "trung_ta", "rankBadge")
	eq([top["grade"], top["division"]], ["dai_ta", 1], "grade and division")
	eq(top["points"], 4230, "rank points")
	eq(top["power"], 98765, "power")
	eq(top["power_character"], "tanko", "powerCharacterId")
	eq(top["title"]["name"], "Thợ rèn lành nghề", "equippedTitle")
	eq(p["me"]["player_id"], "me", "me")
	eq(p["me"]["pos"], 4, "my position")


func test_parse_edges() -> void:
	eq(LeaderboardModel.parse(null), {}, "null")
	eq(LeaderboardModel.parse({"type": "level"}), {}, "no entries")
	var p := LeaderboardModel.parse({"type": "level", "entries": [], "me": null})
	eq(p["entries"], [], "empty board")
	eq(p["me"], {}, "me null: not on the board")
	eq(p["total"], 0, "no total: the rows")
	eq(p["season_name"], "", "no season on the level board")
	var bare := LeaderboardModel.entry({"playerId": "x"})
	eq(bare["power"], -1, "no power: unknown")
	eq(bare["level"], 1, "no level: 1")
	eq(bare["badge"], "", "no badge")
	eq([bare["grade"], bare["division"]], ["binh_nhi", 3], "no grade: from 0 points")
	eq(LeaderboardModel.entry({"playerId": "x", "rankBadge": "wood"})["badge"], "", "an unknown badge is none")


func test_path_and_tabs() -> void:
	eq(LeaderboardModel.path("power"), "/leaderboard?type=power&limit=50&offset=0", "default page")
	eq(LeaderboardModel.path("level", 100, 50), "/leaderboard?type=level&limit=100&offset=50", "a later page")
	eq(LeaderboardModel.types(), ["level", "rank", "power"], "three boards in order")
	eq(LeaderboardModel.TABS.map(func(t): return t["name"]), ["Cấp độ", "Rank", "Lực chiến"], "short names")
	for t in LeaderboardModel.TABS:
		check(GlyphIcon.KINDS.has(t["glyph"]), "glyph %s drawn" % t["glyph"])
	check(GlyphIcon.KINDS.has("trophy"), "the lobby's trophy")


func test_podium_order() -> void:
	var rows: Array = LeaderboardModel.parse(_board())["entries"]
	var podium := LeaderboardModel.podium(rows)
	eq(podium.map(func(e): return e["player_id"]), ["b", "a", "c"], "2nd left, 1st centre, 3rd right")
	eq([LeaderboardModel.podium_place(0), LeaderboardModel.podium_place(1), LeaderboardModel.podium_place(2)], [2, 1, 3], "places")
	eq(LeaderboardModel.list_rows(rows).map(func(e): return e["pos"]), [4], "the list from the 4th")
	var two := LeaderboardModel.podium(rows.slice(0, 1))
	eq(two[1]["player_id"], "a", "one player: the centre")
	eq([two[0], two[2]], [{}, {}], "empty sides")
	eq(LeaderboardModel.list_rows(rows.slice(0, 2)), [], "no list under three")


func test_values_per_board() -> void:
	var top: Dictionary = LeaderboardModel.parse(_board())["entries"][0]
	eq(LeaderboardModel.value_text("level", top), "Lv.52", "level")
	eq(LeaderboardModel.value_text("rank", top), "Đại tá 1", "rank: the grade and division")
	eq(LeaderboardModel.sub_text("rank", top), "4.230 điểm", "rank: the points")
	eq(LeaderboardModel.value_text("power", top), "98.765", "power")
	eq(LeaderboardModel.sub_text("power", top), "", "no sub line off the rank board")
	eq(LeaderboardModel.value_text("level", {}), "", "empty place")
	eq(LeaderboardModel.pos_text(12), "#12", "position")
	eq(LeaderboardModel.pos_text(1234), "#1.234", "thousands")
	eq(LeaderboardModel.pos_text(0), "—", "no position")
	eq(LeaderboardModel.not_ranked_text("rank"), "Chưa đấu hạng mùa này", "no ranked match this season")
	eq(LeaderboardModel.not_ranked_text("power"), "Chưa có hạng", "not on a board")


func test_power_text() -> void:
	eq(LeaderboardModel.power_text(1050), "1.050", "thousands")
	eq(LeaderboardModel.power_text(98765), "98.765", "a strong loadout")
	eq(LeaderboardModel.power_text(0), "0", "zero")
	eq(LeaderboardModel.power_text(-1), "—", "unknown")
	var tag = PowerTag.make(30, 24)
	check(not tag.visible, "an unknown power hides the tag")
	tag.set_power(12345)
	check(tag.visible and tag.label.text == "12.345", "the number")
	tag.keep_unknown = true
	tag.set_power(-1)
	check(tag.visible and tag.label.text == "—", "kept with a dash")
	tag.free()


func test_season_chip() -> void:
	var p := LeaderboardModel.parse(_board())
	eq(LeaderboardModel.season_text(p, "2026-11-30T16:59:59Z", 420), "Mùa 1 · 30/11", "name and end day (UTC+7)")
	eq(LeaderboardModel.season_text(p, "", 0), "Mùa 1", "no end time: the name")
	p["season_ends_at"] = "2026-12-01T00:00:00Z"
	eq(LeaderboardModel.season_text(p, "2026-11-30T16:59:59Z", 0), "Mùa 1 · 01/12", "the board's own end time first")
	eq(LeaderboardModel.season_text({}, "", 0), "", "nothing")


func test_me_and_head() -> void:
	var rows: Array = LeaderboardModel.parse(_board())["entries"]
	check(LeaderboardModel.is_me(rows[3], "me"), "my row")
	check(not LeaderboardModel.is_me(rows[0], "me"), "another's")
	check(not LeaderboardModel.is_me(rows[0], ""), "signed out")
	check(not LeaderboardModel.is_me({}, "me"), "an empty place")
	eq(LeaderboardModel.head_character(rows[0], "spark"), "tanko", "the strongest character")
	eq(LeaderboardModel.head_character({"power_character": ""}, "spark"), "spark", "fallback")


func test_character_power() -> void:
	var data := {"characters": [{"characterId": "rookie", "level": 12, "power": 4321}, {"characterId": "tanko", "level": 3}]}
	eq(LobbyModel.character_info("rookie", data)["power"], 4321, "the server's power")
	eq(LobbyModel.character_info("tanko", data)["power"], -1, "an older server: unknown")
	eq(LobbyModel.character_info("spark", data)["power"], -1, "not owned: none")
	eq(LobbyModel.character_info("rookie", null)["power"], -1, "not loaded")


func test_profile_power() -> void:
	var s = PlayerStateScript.new()
	s.profile = {"playerId": "", "power": 56789, "powerCharacterId": "flora"}
	eq(s.power(), 56789, "power")
	eq(s.power_character(), "flora", "from which character")
	s.profile = {"playerId": ""}
	eq(s.power(), -1, "unknown")
	eq(s.power_character(), "", "unknown character")
	s.free()


class FakeApi:
	extends RefCounted
	var gets: Array = []
	var answer: Dictionary = {}

	func get_json(path: String) -> Dictionary:
		gets.append(path)
		return answer


func test_board_cache() -> void:
	var api := FakeApi.new()
	api.answer = {"ok": true, "status": 200, "code": "", "message": "", "data": _board()}
	var s = PlayerStateScript.new()
	s.api = api
	var seen := []
	s.leaderboard_changed.connect(func(t): seen.append([t, s.leaderboard_loading.get(t, false)]))
	s.load_leaderboard("rank")
	eq(api.gets, ["/leaderboard?type=rank&limit=50&offset=0"], "asked once")
	eq(seen, [["rank", true], ["rank", false]], "loading, then loaded")
	eq(s.my_leaderboard("rank")["entries"].size(), 4, "kept")
	s.load_leaderboard("rank")
	eq(api.gets.size(), 1, "a fresh answer is kept")
	s.load_leaderboard("rank", true)
	eq(api.gets.size(), 2, "forced")
	eq(s.my_leaderboard("power"), {}, "another board: none yet")
	api.answer = {"ok": false, "status": 0, "code": "NETWORK_ERROR", "message": "offline", "data": null}
	s.load_leaderboard("rank", true)
	check(str(s.leaderboard_errors.get("rank", "")) != "", "the failure is told")
	eq(s.my_leaderboard("rank")["entries"].size(), 4, "a failure keeps the last answer")
	api.answer = {"ok": true, "status": 200, "code": "", "message": "", "data": {"type": "power"}}
	s.load_leaderboard("power")
	eq(s.my_leaderboard("power"), {}, "malformed: nothing")
	check(str(s.leaderboard_errors.get("power", "")) != "", "malformed is an error")
	s.free()


func test_page_podium_and_pinned_row() -> void:
	PlayerState.leaderboards["power"] = LeaderboardModel.parse(_board())
	PlayerState._leaderboard_player = Session.player_id
	PlayerState._leaderboard_msec["power"] = Time.get_ticks_msec()
	var page = LeaderboardPage.new()
	page.size = Vector2(1568, 780)
	page._ready()
	page.show_tab(2)
	eq(page.board(), "power", "the Lực chiến tab")
	var podium: HBoxContainer = page._podium
	eq(podium.get_children().map(func(c): return c.place), [2, 1, 3], "mirrored podium")
	eq(podium.get_child(0).custom_minimum_size.x, podium.get_child(2).custom_minimum_size.x, "2nd and 3rd the same width")
	check(podium.get_child(1).custom_minimum_size.x > podium.get_child(0).custom_minimum_size.x, "1st bigger")
	eq(page._list.get_child_count(), 1, "the rows from the 4th")
	check(page._pinned.visible and page._pinned.get_child_count() == 1, "my row pinned")
	check(not page._season.visible, "no season chip off the rank board")
	PlayerState.leaderboards["rank"] = LeaderboardModel.parse(_board())
	PlayerState._leaderboard_msec["rank"] = Time.get_ticks_msec()
	page.show_tab(1)
	check(page._season.visible and page._season_text.text.begins_with("Mùa 1"), "the season chip on the rank board")
	page.free()
	PlayerState.leaderboards.clear()
	PlayerState._leaderboard_msec.clear()


func test_avatar_is_the_lobby_picture_head() -> void:
	var Art = load("res://ui/art.gd")
	for id in ["rookie", "tanko", "spark", "flora", "tide"]:
		var full: Dictionary = Art.lobby_full(id)
		var head: Dictionary = Art.lobby_head(id)
		check(not head.is_empty(), "%s has a head crop" % id)
		if head.is_empty():
			continue
		check(head["texture"] == full["texture"], "%s: from the lobby picture" % id)
		var r: Rect2 = head["rect"]
		check(is_equal_approx(r.size.x, r.size.y), "%s: square" % id)
		check(Rect2(Vector2.ZERO, Vector2(full["texture"].get_size())).encloses(r), "%s: inside the picture" % id)
		var bone: Dictionary = full["bones"].filter(func(b): return b["name"] == "head")[0]
		check(r.has_point(bone["at"].lerp(bone["tip"], 0.5)), "%s: the head's middle inside" % id)
		near(r.size.x, bone["at"].distance_to(bone["tip"]) * Art.LOBBY_HEAD_SIDE, 0.5, "%s: sized by the head bone" % id)
	eq(Art.lobby_head_of({}), {}, "no lobby picture: none")
	var tex := ImageTexture.create_from_image(Image.create(100, 200, false, Image.FORMAT_RGBA8))
	var edge: Dictionary = Art.lobby_head_of({"texture": tex, "bones": [{"name": "head", "at": Vector2(50, 40), "tip": Vector2(50, 0)}]})
	eq(edge["rect"].position.y, 0.0, "kept inside the picture at its top")
