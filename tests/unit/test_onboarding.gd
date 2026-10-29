extends "res://tests/test_case.gd"
## The first-login pick (screens/onboarding.gd, onboarding_model.gd): who goes through it, the
## starters from the game data, wrap-around, the name rule, the dice's suggestion, the refusals; the
## screen built without a tree (mirrored arrows, the dots, the card, the start button and hint);
## the shared character card; the lobby's start character from the profile.

const Model := preload("res://screens/onboarding_model.gd")
const Onboarding := preload("res://screens/onboarding.gd")
const CharacterCard := preload("res://screens/home/character_card.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const TEST_SETTINGS := "user://test_onboarding_loadout.cfg"


func test_who_goes_through_onboarding() -> void:
	check(Model.needs_onboarding({"onboarded": false}), "onboarded false: the pick")
	check(not Model.needs_onboarding({"onboarded": true}), "onboarded: the lobby")
	check(not Model.needs_onboarding({"displayName": "A"}), "an older server without the field: the lobby")
	check(not Model.needs_onboarding({"onboarded": null}), "null: the lobby")
	check(not Model.needs_onboarding({}), "no profile: the lobby")
	check(not Model.needs_onboarding(null), "nothing: the lobby")


func test_starters_come_from_the_game_data() -> void:
	eq(GameData.starter_character_ids(), ["rookie", "tanko", "spark", "flora", "tide"], "the fixture's starterCharacterIds")
	eq(Model.starters(), ["rookie", "tanko", "spark", "flora", "tide"], "in display order")
	var d: Dictionary = GameData.data.duplicate(true)
	d["version"] = "edited"
	d["starterCharacterIds"] = ["spark", "ghost", "tanko", "spark"]
	GameData.take(d, "", false)
	eq(Model.starters(), ["spark", "tanko"], "an admin edit: its order, unknown ids and repeats left out")
	d["version"] = "older"
	d.erase("starterCharacterIds")
	GameData.take(d, "", false)
	eq(Model.starters(), GameData.character_ids(), "an older server: every character")


func test_first_and_cycle() -> void:
	var ids := ["rookie", "tanko", "spark"]
	eq(Model.first(ids, {"currentCharacterId": "spark"}), "spark", "the profile's main character")
	eq(Model.first(ids, {"currentCharacterId": "nova"}), "rookie", "not a starter: the first")
	eq(Model.first(ids, {}), "rookie", "none: the first")
	eq(Model.first([], {}), "", "no starters")
	eq(Model.cycle(ids, "rookie", 1), "tanko", "next")
	eq(Model.cycle(ids, "spark", 1), "rookie", "wraps forward")
	eq(Model.cycle(ids, "rookie", -1), "spark", "wraps back")
	eq(Model.cycle(ids, "nova", 1), "tanko", "unknown counts as the first")
	eq(Model.cycle([], "rookie", 1), "rookie", "no starters")


func test_name_rule() -> void:
	eq(Model.name_problem("BãoThép07"), "", "a fine name")
	check(Model.name_problem("   ") != "", "blank")
	check(Model.name_problem("") != "", "empty")
	eq(Model.name_problem("  " + "a".repeat(20) + "  "), "", "20 letters, trimmed")
	check(Model.name_problem("a".repeat(21)) != "", "21 letters")
	eq(Model.name_problem("Phượng".repeat(3)), "", "Vietnamese letters count once each")


func test_suggestion() -> void:
	eq(Model.suggestion({"ok": true, "status": 200, "data": {"name": "SấmSét99"}}), "SấmSét99", "the name")
	eq(Model.suggestion({"ok": true, "status": 200, "data": {"name": " SóiĐêm "}}), "SóiĐêm", "trimmed")
	eq(Model.suggestion({"ok": true, "status": 200, "data": {"name": "x".repeat(21)}}), "", "too long: none")
	eq(Model.suggestion({"ok": true, "status": 200, "data": {}}), "", "no name")
	eq(Model.suggestion({"ok": false, "status": 503, "code": "NAME_SUGGESTION_UNAVAILABLE", "data": null}), "", "unavailable")


func test_scramble() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := Model.scramble(9, rng)
	eq(s.length(), 9, "as long as asked")
	for ch in s:
		check(Model.SCRAMBLE.contains(ch), "a scramble letter: %s" % ch)
	check(Model.scramble(9, rng) != s, "changes each time")


func test_refusals() -> void:
	var taken := Model.error({"ok": false, "status": 409, "code": "PLAYER_NAME_TAKEN", "message": "taken"})
	eq(taken["action"], Model.SHAKE_NAME, "name taken: the field shakes")
	check(taken["text"] != "", "with a hint")
	eq(Model.error({"ok": false, "status": 400, "code": "PLAYER_UPDATE_FAILED", "message": "display name is too long"})["action"],
		Model.SHAKE_NAME, "a refused name shakes")
	eq(Model.error({"ok": false, "status": 409, "code": "ONBOARDING_DONE", "message": ""})["action"], Model.GO_LOBBY, "already done: the lobby")
	eq(Model.error({"ok": false, "status": 400, "code": "ONBOARDING_BAD_CHARACTER", "message": ""})["action"], Model.SHOW_HINT, "bad character: a hint")
	var offline := Model.error({"ok": false, "status": 0, "code": "NETWORK_ERROR", "message": "x"})
	eq(offline["action"], Model.SHOW_HINT, "offline: a hint")
	eq(offline["text"], Model.ErrorText.OFFLINE, "the offline text")


func test_dice_glyph() -> void:
	check(GlyphIcon.KINDS.has("dice"), "the dice is a glyph")


func test_card_shows_info() -> void:
	var info := {"name": "Tanko", "role": "", "skill": "Bom nặng", "owned": false, "level": 0,
		"stats": [["Máu", "1.650"], ["Sát thương", "420"], ["Phòng thủ", "60"]], "power": -1}
	var lobby_card = CharacterCard.make()
	lobby_card.show_character("tanko", info)
	check(lobby_card.buy.visible, "the lobby's card: buy a character not owned")
	eq(lobby_card.values.map(func(l: Label) -> String: return l.text), ["1.650", "420", "60"], "heart / sword / shield values")
	eq(lobby_card.skill.skill_id, GameData.character_skill_id("tanko"), "the character's skill")
	eq(lobby_card.chain.visible, true, "the element chain")
	var pick = CharacterCard.make(false, false)
	pick.show_character("tanko", info)
	check(not pick.buy.visible, "the pick's card: no buy")
	check(not pick.power.visible, "the pick's card: no power")
	info["owned"] = true
	info["power"] = 1200
	lobby_card.show_character("tanko", info)
	check(not lobby_card.buy.visible, "owned: no buy")
	check(lobby_card.power.visible, "owned: its power")
	lobby_card.free()
	pick.free()


func _screen() -> Control:
	var s = Onboarding.new()
	s.settings_path = TEST_SETTINGS
	s.build()
	return s


func test_screen_layout() -> void:
	var s := _screen()
	var stage: HBoxContainer = s.get_node("Column").find_child("Stage", true, false)
	eq(stage.get_child_count(), 3, "◀, the figure, ▶")
	var left: Button = stage.get_child(0)
	var right: Button = stage.get_child(2)
	eq(left.name, "ArrowLeft", "◀ first")
	eq(right.name, "ArrowRight", "▶ last")
	eq(left.custom_minimum_size, right.custom_minimum_size, "mirrored arrows")
	eq(stage.alignment, BoxContainer.ALIGNMENT_CENTER, "the figure dead centre")
	eq(s.character_id(), "rookie", "the first starter")
	var name_label: Label = s.find_child("CharacterName", true, false)
	eq(name_label.text, GameData.character_name("rookie"), "its name from the game data")
	var dots: Control = s.find_child("Dots", true, false)
	eq(dots.custom_minimum_size.x, 5.0 * Onboarding.DOT * 2, "a dot per starter")
	check(s.find_child("InfoCard", true, false) != null, "the lobby's character card")
	s.free()


func test_screen_cycles_and_wraps() -> void:
	var s := _screen()
	s.cycle(1)
	eq(s.character_id(), "tanko", "▶")
	var name_label: Label = s.find_child("CharacterName", true, false)
	eq(name_label.text, GameData.character_name("tanko"), "the name follows")
	s.cycle(-1)
	s.cycle(-1)
	eq(s.character_id(), "tide", "◀ from the first wraps to the last")
	s.free()


func test_screen_name_rule() -> void:
	var s := _screen()
	var field: LineEdit = s.find_child("Name", true, false)
	var start: Button = s.find_child("Start", true, false)
	var hint: Label = s.find_child("Hint", true, false)
	eq(field.max_length, Model.ErrorText.MAX_NAME, "no more than the rule's letters")
	field.text = "   "
	s._render_name()
	check(start.disabled, "blank: Bắt đầu disabled")
	check(hint.text != "", "blank: the reason")
	field.text = "BãoThép07"
	s._render_name()
	check(not start.disabled, "a fine name: Bắt đầu")
	eq(hint.text, "", "no hint when not needed")
	eq(s.name_text(), "BãoThép07", "the name sent")
	s.free()


func test_lobby_start_character() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	eq(LoadoutModel.start_character(TEST_SETTINGS, {"currentCharacterId": "spark"}), "spark", "nothing saved: the profile's main character")
	eq(LoadoutModel.start_character(TEST_SETTINGS, {"currentCharacterId": "nova"}), "", "unknown: none")
	eq(LoadoutModel.start_character(TEST_SETTINGS, {}), "", "no profile field: none")
	var m := LoadoutModel.new()
	m.select_character("flora")
	m.remember(TEST_SETTINGS)
	eq(LoadoutModel.start_character(TEST_SETTINGS, {"currentCharacterId": "spark"}), "flora", "saved on the device wins")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
