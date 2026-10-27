extends "res://tests/test_case.gd"
## screens/home/mode_select_model.gd and the queue mapping of lobby_model.gd / rank_model.gd, on a
## copy of the fixture with the mode fields of GET /gamedata (modes.lobby category, icon,
## partySize, ranked; modes.categories) and the casual 2v2 mode, as the server sends them since
## 1d4e546 (migration 044).

const ModeSelectModel := preload("res://screens/home/mode_select_model.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const ResultModel := preload("res://match/result_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const LOBBY := [
	{"modeId": "casual", "name": "Đấu thường 2vs2", "description": "Ghép 2v2, không tính điểm hạng", "queue": "casual_2v2",
		"bot": "", "category": "pvp", "icon": "swords", "partySize": 2, "ranked": false},
	{"modeId": "ranked", "name": "Đấu hạng 2vs2", "description": "Ghép 2v2, tính điểm hạng", "queue": "ranked_2v2", "bot": "",
		"category": "pvp", "icon": "trophy", "partySize": 2, "ranked": true},
	{"modeId": "bot", "name": "Đấu máy", "description": "Đấu 1v1 với máy biết bắn", "queue": "", "bot": "ai",
		"category": "pvp", "icon": "robot", "partySize": 1, "ranked": false},
	{"modeId": "practice", "name": "Luyện tập", "description": "Tập bắn với bia đứng yên", "queue": "", "bot": "",
		"category": "pvp", "icon": "target", "partySize": 1, "ranked": false},
]
const CATEGORIES := [{"categoryId": "pvp", "name": "PvP"}, {"categoryId": "boss", "name": "Boss"}]


## The fixture with `lobby` and `categories` as modes.lobby / modes.categories.
static func _take(lobby: Array = LOBBY, categories: Array = CATEGORIES) -> void:
	var d: Dictionary = GameData.data.duplicate(true)
	d["version"] = "modes-%d-%d" % [lobby.hash(), categories.hash()]
	d["modes"]["lobby"] = lobby.duplicate(true)
	d["modes"]["categories"] = categories.duplicate(true)
	GameData.take(d, "", false)


func test_modes_carry_category_party_size_and_ranked() -> void:
	_take()
	var all := LobbyModel.modes()
	eq(all.map(func(m): return m["id"]), ["casual", "ranked", "bot", "practice"], "the game data's order")
	eq([all[0]["category"], all[0]["icon"], all[0]["party_size"], all[0]["ranked"], all[0]["queue"]],
		["pvp", "swords", 2, false, "casual_2v2"], "casual")
	eq([all[1]["party_size"], all[1]["ranked"]], [2, true], "ranked")
	eq([all[2]["party_size"], all[2]["base"]], [1, {"bot": "ai"}], "vs bot")
	eq([all[3]["party_size"], all[3]["base"]], [1, {}], "practice")
	check(LobbyModel.is_party(0) and LobbyModel.is_party(1), "the 2v2 modes are party modes")
	check(not LobbyModel.is_party(2) and not LobbyModel.is_party(3), "bot and practice are solo")


func test_queue_mapping() -> void:
	_take()
	eq([LobbyModel.index_of_queue("casual_2v2"), LobbyModel.index_of_queue("ranked_2v2"), LobbyModel.index_of_queue("koth"),
		LobbyModel.index_of_queue("")], [0, 1, -1, -1], "the mode of a queue")
	eq(LobbyModel.queue_name("casual_2v2"), "Đấu thường 2vs2", "a queue's name")
	eq(LobbyModel.queue_name("pvp_2v2"), "Đấu 2v2", "not a lobby queue: the match mode's name")
	check(LobbyModel.is_queue({"queue": "casual_2v2"}) and not LobbyModel.is_queue({"bot": "ai"}), "queue bases")
	check(LobbyModel.is_ranked({"queue": "ranked_2v2"}), "ranked base")
	check(not LobbyModel.is_ranked({"queue": "casual_2v2"}), "casual base is not ranked")
	check(RankModel.is_ranked_mode("ranked_2v2") and not RankModel.is_ranked_mode("casual_2v2"), "the ranked flag, not the id")
	check(RankModel.is_queue_mode("casual_2v2") and RankModel.is_queue_mode("ranked_2v2"), "both are queues")
	check(not RankModel.is_queue_mode("pvp_1v1") and not RankModel.is_queue_mode(""), "a Quick Play match is not")
	eq([ResultModel.again_text("casual_2v2", false), ResultModel.again_text("pvp_1v1", true), ResultModel.again_text("pvp_1v1", false)],
		["Chơi tiếp", "Chơi lại", ""], "casual plays on like ranked")
	eq(RankModel.result_of("casual_2v2", {"exp": 120, "coins": 50, "ratingChange": 0}), {}, "no rating row for casual (ratingChange 0, no rank fields)")
	eq(RankModel.result_of("casual_2v2", {"newRating": 1040, "ratingChange": 20}), {}, "never for casual")
	check(RankModel.result_of("ranked_2v2", {"newRating": 1040, "ratingChange": 20}).is_empty(), "the rating alone is never shown")
	check(not RankModel.result_of("ranked_2v2", {"grade": {"newPoints": 30, "pointsChange": 30}}).is_empty(), "ranked has one")


func test_ranked_flag_decides_not_the_id() -> void:
	var lobby: Array = LOBBY.duplicate(true)
	lobby[0]["ranked"] = true # an admin made casual count
	lobby[1]["ranked"] = false
	_take(lobby)
	check(RankModel.is_ranked_mode("casual_2v2"), "casual ranked by its flag")
	check(not RankModel.is_ranked_mode("ranked_2v2"), "ranked_2v2 not ranked by its flag")


func test_an_older_server_without_the_new_fields() -> void:
	# The fixture: modes.lobby {modeId, name, description, queue, bot}, no categories.
	var all := LobbyModel.modes()
	eq(all.map(func(m): return m["party_size"]), [1, 2, 1], "a queue mode plays matchmaking.teamSize")
	check(RankModel.is_ranked_mode("ranked_2v2"), "rank.rankedMode is ranked")
	var sections := ModeSelectModel.sections(0)
	eq(sections.size(), 1, "one section")
	eq(sections[0]["modes"].size(), 3, "every mode in it")


func test_sections_by_category_in_order() -> void:
	_take()
	var sections := ModeSelectModel.sections(1)
	eq(sections.map(func(s): return s["name"]), ["PvP", "Boss"], "the categories in order")
	eq(sections[0]["modes"].map(func(c): return c["name"]), ["Đấu thường 2vs2", "Đấu hạng 2vs2", "Đấu máy", "Luyện tập"],
		"PvP's four modes in order")
	eq(sections[0]["layout"], ModeSelectModel.CARDS, "PvP: big cards")
	eq(sections[1]["layout"], ModeSelectModel.GRID, "Boss: a grid")
	eq(sections[1]["modes"], [], "no boss yet")
	eq(ModeSelectModel.placeholder("boss"), {"title": "Sắp ra mắt", "text": "Phòng 4 người cùng đánh boss"}, "the boss placeholder")
	eq(ModeSelectModel.placeholder("arena")["title"], "Sắp ra mắt", "any empty category")
	eq(ModeSelectModel.section_of(2), 0, "bot is on PvP")


func test_cards() -> void:
	_take()
	var casual := ModeSelectModel.card(0, 1)
	eq([casual["name"], casual["description"], casual["badge"], casual["ranked"], casual["selected"]],
		["Đấu thường 2vs2", "Ghép 2v2, không tính điểm hạng", "2 người", false, false], "casual's card")
	eq(casual["icon"], "battle", "the icon key mapped")
	var ranked := ModeSelectModel.card(1, 1)
	check(ranked["ranked"] and ranked["selected"], "ranked, the chosen one")
	eq(ModeSelectModel.card(3, 1)["badge"], "", "solo: no party badge")
	eq([ModeSelectModel.icon_of("swords"), ModeSelectModel.icon_of("trophy"), ModeSelectModel.icon_of("robot"),
		ModeSelectModel.icon_of("target")], ["battle", "upgrade", "weapon", "power_shot"], "the server's icon keys")
	eq([ModeSelectModel.icon_of("practice"), ModeSelectModel.icon_of(""), ModeSelectModel.icon_of("dragon")],
		["power_shot", ModeSelectModel.FALLBACK_ICON, ModeSelectModel.FALLBACK_ICON], "unknown icon keys fall back")


func test_new_modes_and_categories_from_the_data() -> void:
	var lobby: Array = LOBBY.duplicate(true)
	lobby.append({"modeId": "dragon", "name": "Rồng lửa", "description": "", "queue": "boss_dragon", "category": "boss",
		"icon": "dragon", "partySize": 4, "ranked": false})
	lobby.append({"modeId": "koth", "name": "Vua đồi", "description": "", "queue": "koth", "category": "event", "partySize": 2})
	lobby.append({"modeId": "old", "name": "Cũ", "queue": "", "category": "pvp", "enabled": false})
	_take(lobby, CATEGORIES + [{"categoryId": "arena", "name": "Đấu trường"}])
	var sections := ModeSelectModel.sections(0)
	eq(sections.map(func(s): return s["categoryId"]), ["pvp", "boss", "arena", "event"], "data categories, then one a mode names")
	eq(sections[0]["modes"].size(), 4, "a disabled mode is hidden")
	eq(sections[1]["modes"].map(func(c): return c["badge"]), ["4 người"], "a boss button")
	eq(sections[2]["modes"], [], "an empty category: the placeholder")
	eq(sections[3]["name"], "event", "a category the list lacks: its id")


func test_switch_action() -> void:
	_take()
	eq(ModeSelectModel.switch_action(0, 0, false, false, false), ModeSelectModel.NOTHING, "the same mode")
	eq(ModeSelectModel.switch_action(0, 9, false, false, false), ModeSelectModel.NOTHING, "no such mode")
	eq(ModeSelectModel.switch_action(0, 2, false, false, false), ModeSelectModel.SWITCH, "no lobby: switch")
	eq(ModeSelectModel.switch_action(0, 1, true, false, true), ModeSelectModel.SET_QUEUE, "casual → ranked in a party: SetLobbyQueue")
	eq(ModeSelectModel.switch_action(1, 0, true, false, false), ModeSelectModel.SET_QUEUE, "ranked → casual alone in my lobby")
	eq(ModeSelectModel.switch_action(1, 2, true, false, true), ModeSelectModel.CONFIRM_LEAVE, "to vs bot with a teammate: Rời đội?")
	eq(ModeSelectModel.switch_action(1, 3, true, false, false), ModeSelectModel.LEAVE, "to practice alone: leave")
	eq(ModeSelectModel.switch_action(1, 0, true, true, true), ModeSelectModel.LOCKED, "the member cannot")
