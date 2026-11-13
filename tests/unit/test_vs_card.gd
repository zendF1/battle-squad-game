extends "res://tests/test_case.gd"
## The matchmaking / VS card (screens/ranked/player_card.gd): the frame says the rank (no grade
## name under the name), a bot reads like a player, my badge holder's card opens the ladder.

const PlayerCard := preload("res://screens/ranked/player_card.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")


func _card(p: Dictionary, mine: bool) -> Control:
	var card = PlayerCard.new()
	card.mine = mine
	card._ready() # not in the tree: built by hand
	card.show_player(p)
	card._build()
	return card


func _texts(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_texts(c, out)
	return out


func test_no_rank_words_no_bot_words() -> void:
	var p := {"playerId": "u_6fae", "displayName": "MâyTrắng", "characterId": "tide", "isBot": true, "level": 41,
		"rankBadge": "thuong_tuong", "titleId": "", "teamId": 2}
	var card := _card(p, false)
	var texts := _texts(card)
	check(texts.has("MâyTrắng") and texts.has("Lv.41"), "name and level shown: %s" % [texts])
	check(not texts.has(RankModel.grade_name("thuong_tuong")), "no grade name: the frame says it")
	check(texts.all(func(t: String) -> bool: return not t.contains("Máy") and not t.contains("Bot")), "nothing says bot")
	eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE, "another player's card takes no tap")
	card.free()


func test_my_badge_card_opens_the_ladder() -> void:
	var p := {"playerId": "me", "displayName": "Tôi", "characterId": "rookie", "isBot": false, "level": 9,
		"rankBadge": "hoc_vien", "titleId": "", "teamId": 1}
	var card := _card(p, true)
	eq(card.mouse_filter, Control.MOUSE_FILTER_STOP, "my badge card is tappable")
	var hits := [0]
	card.rank_pressed.connect(func() -> void: hits[0] += 1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	card._gui_input(up)
	eq(hits[0], 1, "a tap: rank_pressed")
	card.free()
	p["rankBadge"] = ""
	var plain := _card(p, true)
	eq(plain.mouse_filter, Control.MOUSE_FILTER_IGNORE, "no badge: nothing to open")
	plain.free()


func test_dais_wider_than_before() -> void:
	check(PlayerCard.DAIS_RX >= 66.0 * 1.3, "the dais is clearly bigger (top face about the shoulders' width or more)")
	check(PlayerCard.FEET_Y < PlayerCard.ART_TOP + PlayerCard.ART_H, "the dais's top face sits on the figure's feet")
