extends "res://tests/test_case.gd"
## TitleModel: GET /player/titles parsing, a title from the profile / a match player (fallback:
## none), owned / locked lists and the locked text.

const TitleModel := preload("res://screens/home/title_model.gd")


func test_parse_title_and_fallbacks() -> void:
	eq(TitleModel.parse_title({"id": "smith", "name": "Thợ rèn lành nghề", "rarity": "blue"}),
		{"id": "smith", "name": "Thợ rèn lành nghề", "rarity": "blue"}, "a title")
	eq(TitleModel.parse_title({"id": "x", "name": "X", "rarity": "gold"})["rarity"], "blue", "unknown rarity → blue")
	eq(TitleModel.parse_title({"id": "x", "name": "X"})["rarity"], "blue", "missing rarity → blue")
	for bad in [null, "smith", 3, {}, {"id": "x"}, {"id": "x", "name": ""}, {"id": "x", "name": null}, {"id": "x", "name": "  "}]:
		eq(TitleModel.parse_title(bad), {}, "no title from %s" % str(bad))


func test_player_payload() -> void:
	var p := {"playerId": "p1", "weaponUpgradeLevel": 14, "title": {"id": "grandmaster", "name": "Cao thủ", "rarity": "red"}}
	eq(TitleModel.from_player(p), {"id": "grandmaster", "name": "Cao thủ", "rarity": "red"}, "worn")
	eq(TitleModel.from_player({"playerId": "bot", "isBot": true}), {}, "a bot: none")
	eq(TitleModel.from_player({"title": null}), {}, "null: none")
	eq(TitleModel.from_player({"title": "Cao thủ"}), {}, "malformed: none")
	eq(TitleModel.from_player(null), {}, "no player")


func test_profile() -> void:
	eq(TitleModel.from_profile({"equippedTitle": {"id": "smith", "name": "Thợ rèn lành nghề", "rarity": "blue"}})["id"], "smith", "worn")
	eq(TitleModel.from_profile({"equippedTitle": null}), {}, "none")
	eq(TitleModel.from_profile({}), {}, "an old server")


func test_parse_list() -> void:
	var data := {"titles": [
		{"id": "veteran", "name": "Chiến binh kỳ cựu", "rarity": "blue", "description": "1 nhân vật đạt cấp 40", "owned": false, "obtainedAt": null},
		{"id": "smith", "name": "Thợ rèn lành nghề", "rarity": "blue", "description": "1 trang bị đạt +10", "owned": true, "obtainedAt": "2026-10-20T04:43:44Z"},
		{"id": "", "name": "No id", "rarity": "blue"},
		"junk",
		{"id": "sharpshooter", "name": "Xạ thủ bách chiến", "rarity": "orange", "description": "Thắng 100 trận", "owned": "yes"},
	], "equipped": {"id": "smith", "name": "Thợ rèn lành nghề", "rarity": "blue"}}
	var p = TitleModel.parse(data)
	eq(p["titles"].map(func(t): return t["id"]), ["veteran", "smith", "sharpshooter"], "valid titles in order")
	eq(TitleModel.owned(p).map(func(t): return t["id"]), ["smith"], "owned (a non-bool owned is not)")
	eq(TitleModel.locked(p).map(func(t): return t["id"]), ["veteran", "sharpshooter"], "locked")
	eq(TitleModel.equipped_id(p), "smith", "worn id")
	eq(TitleModel.find(p, "smith")["obtainedAt"], "2026-10-20T04:43:44Z", "obtained at")
	eq(TitleModel.find(p, "veteran")["obtainedAt"], "", "never obtained")
	eq(TitleModel.locked_text(TitleModel.find(p, "sharpshooter")), "Đạt: Thắng 100 trận", "locked text")
	eq(TitleModel.locked_text({"description": ""}), "Chưa mở", "no description")
	eq(TitleModel.equipped_id(TitleModel.parse({"titles": [], "equipped": null})), "", "none worn")
	eq(TitleModel.parse({"equipped": null}), null, "no list: malformed")
	eq(TitleModel.parse(null), null, "nothing: malformed")
	eq(TitleModel.owned(null), [], "not loaded")
