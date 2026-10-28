extends "res://tests/test_case.gd"
## The leaderboard's looks and the player showcase (the server's docs/contracts/leaderboard-showcase.md):
## an entry's characterId / look, the figure's gun and back aura from a look, the podium's figures
## and taps, the list heads, GET /players/{id}/showcase parsing (stats, points, gear, gems, the owned
## characters), PlayerState.fetch_showcase(), and the popup's gear, stats and switcher.

const LeaderboardModel := preload("res://screens/home/leaderboard_model.gd")
const LeaderboardPage := preload("res://screens/home/leaderboard_page.gd")
const LeaderboardPlace := preload("res://screens/home/leaderboard_place.gd")
const ShowcaseModel := preload("res://screens/home/showcase_model.gd")
const ShowcasePopup := preload("res://screens/home/showcase_popup.gd")
const PlayerFigure := preload("res://screens/home/player_figure.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const PlayerStateScript := preload("res://autoload/player_state.gd")


static func _look(c: String, weapon: String, lv: int) -> Dictionary:
	return {"characterId": c, "weaponItemId": weapon, "weaponUpgradeLevel": lv}


static func _row(pos: int, id: String, c: String, weapon: String = "", lv: int = 0, extra: Dictionary = {}) -> Dictionary:
	var r := {"pos": pos, "playerId": id, "displayName": "P" + id, "level": 40, "rankBadge": "", "grade": "binh_nhi",
		"gradeDivision": 3, "rankPoints": 100, "power": 90000 - pos, "powerCharacterId": c, "characterId": c,
		"look": _look(c, weapon, lv)}
	r.merge(extra, true)
	return r


static func _board() -> Dictionary:
	return {"type": "power", "total": 4, "entries": [
		_row(1, "a", "spark", "crafted_weapon_diamond", 16),
		_row(2, "b", "flora", "flora_weapon_lv30", 6),
		_row(3, "c", "tanko"),
		_row(4, "me", "tide", "", 0, {"powerCharacterId": ""}),
	], "me": _row(4, "me", "tide", "", 0, {"powerCharacterId": ""})}


static func _showcase() -> Dictionary:
	return {"playerId": "a", "displayName": "Bão Lửa", "level": 80, "rankBadge": "dai_ta", "grade": "dai_ta", "gradeDivision": 1,
		"rankPoints": 4180, "power": 714502, "powerCharacterId": "spark",
		"equippedTitle": {"id": "grandmaster", "name": "Đại cao thủ", "rarity": "red"},
		"character": {"characterId": "spark", "level": 80, "power": 714502, "look": _look("spark", "crafted_weapon_diamond", 16),
			"equipment": [
				{"equipmentId": "w1", "itemId": "crafted_weapon_diamond", "name": "Diamond Blaster", "slot": "weapon",
					"category": "crafted", "tier": "diamond", "upgradeLevel": 16,
					"gems": [{"slotIndex": 2, "gemType": "critical", "gemLevel": 8}, {"slotIndex": 1, "gemType": "damage", "gemLevel": 10}]},
				{"equipmentId": "a1", "itemId": "normal_armor_lv40", "name": "Dragon Vest", "slot": "armor",
					"category": "normal", "upgradeLevel": 0, "gems": []},
				"junk", {"slot": "boots"}, # not pieces: skipped
			],
			"statPoints": {"hp": 120, "damage": 80, "mobility": 0, "defense": 37, "skillPower": 5, "terrainDamage": 2},
			"stats": {"maxHp": 2630, "defense": 224, "damageBonus": 900, "moveEnergy": 100, "skillPowerBonus": 15,
				"terrainDamageBonus": 8, "critChance": 12, "weaponDamage": 180}},
		"characters": [{"characterId": "rookie", "level": 41, "power": 98110}, {"characterId": "spark", "level": 80, "power": 714502}]}


func test_entry_character_and_look() -> void:
	var p := LeaderboardModel.parse(_board())
	var top: Dictionary = p["entries"][0]
	eq(top["character"], "spark", "characterId")
	eq(top["look"]["weaponItemId"], "crafted_weapon_diamond", "look kept")
	eq(LeaderboardModel.head_character(top), "spark", "the head is the server's character")
	eq(LeaderboardModel.head_character(p["me"]), "tide", "characterId even without a power character")
	var old := LeaderboardModel.entry({"playerId": "x", "powerCharacterId": "flora"})
	eq(old["character"], "flora", "an older server: the power character")
	eq(old["look"], {}, "no look")
	eq(LeaderboardModel.head_character(LeaderboardModel.entry({"playerId": "y"}), "rookie"), "rookie", "nothing: the fallback")


func test_look_gun_and_aura() -> void:
	var p := LeaderboardModel.parse(_board())
	var top := LeaderboardModel.look(p["entries"][0])
	eq(top["character_id"], "spark", "character")
	eq(top["gun"], EquipmentModel.gun("crafted_weapon_diamond"), "the worn weapon's gun")
	eq(top["gun"]["tier"], "diamond", "diamond")
	eq(top["aura_level"], mini(16, GameData.max_upgrade_level()), "the weapon's level: its back aura")
	var bare := LeaderboardModel.look(p["entries"][2])
	eq(bare["gun"], EquipmentModel.gun("", {}, "tanko"), "no weapon: the character's basic gun")
	eq(bare["aura_level"], 0, "no aura")
	var other := LeaderboardModel.look(LeaderboardModel.entry(_row(1, "z", "rookie", "", 0, {"look": _look("spark", "crafted_weapon_gold", 9)})))
	eq(other["gun"], EquipmentModel.gun("", {}, "rookie"), "a look of another character is not used")
	eq(LeaderboardModel.look({}), {}, "an empty place: nothing")


func test_figure_shows_a_look() -> void:
	var f = PlayerFigure.make({}, 0.5)
	f.size = Vector2(200, 220)
	f._ready()
	f.show_look(LeaderboardModel.look(LeaderboardModel.entry(_row(1, "a", "spark", "crafted_weapon_diamond", 16))))
	eq(f.view().character_id, "spark", "the character")
	eq(f.view().gun, EquipmentModel.gun("crafted_weapon_diamond"), "their gun, not mine")
	check(f.view().aura_level >= 14 and f.view().back_aura, "their weapon's back aura")
	eq(f.gun_stand().gun(), {"kind": "blaster", "tier": "diamond"}, "the gun rests beside the feet")
	f.show_look({})
	check(not f.view().visible and not f.gun_stand().visible, "an empty look: nothing")
	f.free()


func test_podium_figures_and_taps() -> void:
	PlayerState.leaderboards["power"] = LeaderboardModel.parse(_board())
	PlayerState._leaderboard_player = Session.player_id
	PlayerState._leaderboard_msec["power"] = Time.get_ticks_msec()
	var page = LeaderboardPage.new()
	page.size = Vector2(1568, 780)
	page._ready()
	page.show_tab(2)
	var podium: HBoxContainer = page._podium
	eq(podium.get_children().map(func(c): return c.figure().look().get("character_id", "")), ["flora", "spark", "tanko"],
		"each place's character, 2nd / 1st / 3rd")
	var first = podium.get_child(1)
	var side_l = podium.get_child(0)
	var side_r = podium.get_child(2)
	check(first.figure().figure_scale > side_l.figure().figure_scale, "1st stands taller")
	eq(side_l.figure().figure_scale, side_r.figure().figure_scale, "2nd and 3rd mirrored")
	eq(side_l.custom_minimum_size, side_r.custom_minimum_size, "2nd and 3rd the same size")
	check(first.get_node("Step").custom_minimum_size.y > side_l.get_node("Step").custom_minimum_size.y, "1st on the higher step")
	var tapped := []
	first.tapped.connect(func(e): tapped.append(e["player_id"]))
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(50, 50)
	first._gui_input(down)
	var up := down.duplicate()
	up.pressed = false
	first._gui_input(up)
	eq(tapped, ["a"], "a tap on a place")
	var head = page._list.get_child(0).find_child("Head", true, false)
	eq(head.character_id, "tide", "the list head is the server's character")
	var pinned_head = page._pinned.find_child("Head", true, false)
	eq(pinned_head.character_id, "tide", "my pinned head too")
	page.free()
	PlayerState.leaderboards.clear()
	PlayerState._leaderboard_msec.clear()


func test_empty_place() -> void:
	var p = LeaderboardPlace.make(3, {}, "power", false)
	eq(p.figure().look(), {}, "no figure")
	eq(p.mouse_filter, Control.MOUSE_FILTER_IGNORE, "nothing to tap")
	p.free()


func test_showcase_path() -> void:
	eq(ShowcaseModel.path("c3"), "/players/c3/showcase", "the power character")
	eq(ShowcaseModel.path("c3", "rookie"), "/players/c3/showcase?characterId=rookie", "another one")


func test_parse_showcase() -> void:
	var s := ShowcaseModel.parse(_showcase())
	eq(s["player_id"], "a", "player")
	eq(s["name"], "Bão Lửa", "name")
	eq(s["level"], 80, "level")
	eq([s["grade"], s["division"]], ["dai_ta", 1], "grade")
	eq(s["power"], 714502, "power")
	var c: Dictionary = s["character"]
	eq(c["id"], "spark", "the shown character")
	eq(c["power"], 714502, "its power")
	eq(c["equipment"].keys(), ["weapon", "armor"], "the pieces by slot, junk skipped")
	eq(c["points"], {"hp": 120, "damage": 80, "mobility": 0, "defense": 37, "skillPower": 5, "terrainDamage": 2}, "allocated points")
	eq(s["characters"].map(func(o): return o["id"]), ["rookie", "spark"], "owned, in the server's order")
	eq(ShowcaseModel.parse({"playerId": "a"}), {}, "no character: malformed")
	eq(ShowcaseModel.parse(null), {}, "null")
	var lone := _showcase()
	lone.erase("characters")
	eq(ShowcaseModel.parse(lone)["characters"].map(func(o): return o["id"]), ["spark"], "the shown one is always in the list")


func test_stat_cells() -> void:
	var c: Dictionary = ShowcaseModel.parse(_showcase())["character"]
	var cells := ShowcaseModel.stat_cells(c)
	eq(cells.map(func(x): return x["glyph"]), ["heart", "sword", "shield", "boot", "magic", "terrain"], "the pictures")
	eq(cells.map(func(x): return x["value"]), ["2.630", "1.080", "224", "100", "+15%", "+8%"], "the server's final stats")
	eq(cells.map(func(x): return x["points"]), [120, 80, 37, 0, 5, 2], "the allocated points")
	eq(ShowcaseModel.crit_text(c), "12%", "crit")
	var plain := c.duplicate(true)
	plain["stats"] = {}
	eq(ShowcaseModel.stat_cells(plain), [], "no stats: no cells")


func test_gems_and_upgrade() -> void:
	var c: Dictionary = ShowcaseModel.parse(_showcase())["character"]
	var gems := ShowcaseModel.gems(c["equipment"]["weapon"])
	eq(gems.map(func(g): return [g["type"], g["level"]]), [["damage", 10], ["critical", 8]], "in socket order")
	eq(gems[0]["color"], ShowcaseModel.GEM_COLORS["damage"], "coloured by type")
	eq(ShowcaseModel.gems(c["equipment"]["armor"]), [], "none")
	eq(ShowcaseModel.gems({"gems": [{"gemType": "??", "gemLevel": 2}]})[0]["color"], ShowcaseModel.GEM_UNKNOWN, "unknown type")
	eq(ShowcaseModel.upgrade_text(c["equipment"]["weapon"]), "+16", "+N")
	eq(ShowcaseModel.upgrade_text(c["equipment"]["armor"]), "", "+0: nothing")


class FakeApi:
	extends RefCounted
	var gets: Array = []
	var answer: Dictionary = {}

	func get_json(path: String) -> Dictionary:
		gets.append(path)
		return answer


func test_fetch_showcase() -> void:
	var api := FakeApi.new()
	var s = PlayerStateScript.new()
	s.api = api
	api.answer = {"ok": true, "status": 200, "code": "", "message": "", "data": _showcase()}
	var res: Dictionary = await s.fetch_showcase("a", "spark")
	eq(api.gets, ["/players/a/showcase?characterId=spark"], "asked")
	eq(res["showcase"]["character"]["id"], "spark", "parsed")
	api.answer = {"ok": false, "status": 404, "code": "PLAYER_NOT_FOUND", "message": "Player not found", "data": null}
	res = await s.fetch_showcase("x")
	check(str(res.get("error", "")) != "", "not found is told")
	api.answer = {"ok": true, "status": 200, "code": "", "message": "", "data": {"playerId": "a"}}
	res = await s.fetch_showcase("a")
	check(res.has("error"), "malformed is an error")
	s.free()


func test_popup_shows_the_showcase() -> void:
	var host := Control.new()
	var m = ShowcasePopup.new()
	m.player_id = "a"
	m.open(host, "Bão Lửa", ShowcasePopup.WIDTH)
	m.add_close_x()
	m._build()
	m.show_showcase(ShowcaseModel.parse(_showcase()))
	eq(m._gear.get_child_count(), EquipmentModel.slots().size(), "every slot")
	var weapon: Control = m._gear.find_child("Slot_weapon", true, false)
	eq(weapon.find_children("Gem*", "", true, false).size(), 2, "the weapon's two gems")
	check(weapon.find_child("Plus", true, false) != null, "its +N")
	var armor: Control = m._gear.find_child("Slot_armor", true, false)
	check(armor.find_child("Plus", true, false) == null, "+0: no pill")
	eq(m._stats.find_child("StatGrid", true, false).get_child_count(), 6, "six stats")
	check(m._stats.find_child("Crit", true, false) != null, "the crit chance")
	eq(m._figure.look()["character_id"], "spark", "the figure")
	eq(m._power.value, 714502, "its power")
	eq(m._switcher.get_child_count(), 2, "a head per owned character")
	check(m._switcher.visible, "shown with several")
	eq(m.title.text, "Bão Lửa", "the name")
	var gear_w: float = m._gear.get_parent().custom_minimum_size.x
	eq(gear_w, m._stats.get_parent().custom_minimum_size.x, "the gear and the stats columns mirrored")
	host.free()


func test_new_glyphs() -> void:
	for k in ["boot", "magic", "terrain", "crit", "gem"]:
		check(k in GlyphIcon.KINDS, "%s is a glyph" % k)
