extends "res://tests/test_case.gd"
## screens/home/mode_select.gd: every card the same (frame, size, picture and name at the same
## place, an "i" button top-right), no sentences on the face (no description, no "2 người", no
## rank line, no recommended level), the rest in the "i" popup; the boss cards' gift box with the
## runs left. The game data of tests/boss_fixture.gd (PvP: casual, ranked, bot, practice; five bosses).

const BossFixture := preload("res://tests/boss_fixture.gd")
const ModeSelect := preload("res://screens/home/mode_select.gd")
const ModeSelectModel := preload("res://screens/home/mode_select_model.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")


## No network: the boss tab asks for GET /boss/runs.
class NoApi:
	extends RefCounted
	func get_json(_path: String) -> Dictionary:
		return {"ok": false, "status": 0, "code": "NETWORK_ERROR", "message": "offline", "data": null}


func _open(tab: int) -> Control:
	PlayerState.api = NoApi.new()
	var page = ModeSelect.new()
	page.size = Vector2(1600, 760)
	Engine.get_main_loop().root.add_child(page)
	if not page.is_node_ready(): # the runner's root is not in the tree yet: build it by hand
		page._ready()
	page.show_for(LobbyModel.index_of_queue("ranked_2v2"))
	page.show_tab(tab)
	return page


## The texts of every Label under `n`.
static func _texts(n: Node) -> Array:
	var out: Array = []
	for c in n.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	return out


## [position, size] of every direct child of a card but its "i" button, in order.
static func _layout(card: Control) -> Array:
	var out: Array = []
	for c in card.get_children():
		if c is Control and not str(c.name).begins_with("Info"):
			out.append([c.position, c.size])
	return out


func test_four_identical_pvp_cards_with_an_info_button() -> void:
	BossFixture.take()
	var page := _open(0)
	var ids := ["casual", "ranked", "bot", "practice"]
	var cards: Array = ids.map(func(id): return page.find_child("Mode_" + id, true, false))
	check(cards.all(func(c): return c != null), "a card per PvP mode")
	if not cards.all(func(c): return c != null):
		page.free()
		return
	for c in cards:
		eq(c.custom_minimum_size, ModeSelect.CARD, "%s: the one card size" % c.name)
		eq(_layout(c), _layout(cards[0]), "%s: the picture and the name where the first card has them" % c.name)
		var info: Button = c.find_child("Info_" + str(c.name).trim_prefix("Mode_"), false, false)
		check(info != null, "%s: an \"i\" button" % c.name)
		if info != null:
			eq(info.position, Vector2(ModeSelect.CARD.x - ModeSelect.INFO - 12, 12), "%s: top-right" % c.name)
	eq(_texts(cards[1]), ["Đấu hạng 2vs2"], "the face: the name only (no description, no party chip, no rank line)")
	eq(_texts(cards[0]), ["Đấu thường 2vs2"], "casual: the name only")
	page.free()
	PlayerState.api = null


func test_info_popup_tells_the_rest() -> void:
	BossFixture.take()
	var page := _open(0)
	var info: Button = page.find_child("Info_ranked", true, false)
	info.pressed.emit()
	var popup: Node = page.find_child("InfoPopup", true, false)
	check(popup != null, "the popup opened")
	if popup != null:
		var texts := _texts(popup)
		check(texts.has("Đấu hạng 2vs2"), "its name as the title")
		check(texts.has("Ghép 2v2, tính điểm hạng"), "the game data's description")
		check(texts.has("×2"), "the party size")
	page.free()
	PlayerState.api = null


func test_boss_cards_gift_box_and_no_recommended_level() -> void:
	BossFixture.take()
	PlayerState.boss_runs = {}
	var page := _open(1)
	var cards: Array = page.find_children("Boss_*", "Button", true, false)
	eq(cards.size(), 5, "a card per boss")
	for c in cards:
		eq(c.custom_minimum_size, ModeSelect.CARD, "%s: the same card size as PvP" % c.name)
		eq(_layout(c).slice(0, 2), _layout(cards[0]).slice(0, 2), "%s: the figure and the name in the same place" % c.name)
		check(not _texts(c).any(func(t): return "đề xuất" in t or "Lượt thưởng" in t), "%s: no level, no sentence" % c.name)
		check(c.find_child("Info_*", false, false) != null, "%s: an \"i\" button" % c.name)
	var runs: Node = cards[0].find_child("Runs", true, false)
	check(runs != null, "the gift box row (runs not loaded yet)")
	if runs != null:
		eq(_texts(runs), ["×…"], "unknown runs")
	page.free()
	PlayerState.api = null
