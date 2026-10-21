extends "res://tests/test_case.gd"
## The match HUD (match/hud.gd): the turn portrait with the weapon's back aura, the skill and item
## slots, no end-turn / weapon buttons; the one-special-per-turn lock (match/action_lock.gd) and
## how match_screen.gd applies it.

const Hud := preload("res://match/hud.gd")
const ActionLock := preload("res://match/action_lock.gd")
const MatchScreen := preload("res://match/match_screen.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")


## Not in the tree: _ready by hand, the portrait's figure and its character too.
func _hud() -> Control:
	var h: Control = Hud.new()
	h._ready()
	var v: Control = h._portrait_art
	v._ready()
	v.character()._ready()
	return h


static func _buttons(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_buttons(c))
	return out


func test_lock_rules() -> void:
	eq(ActionLock.press("weapon", "skill"), "skill", "the normal shot arms the skill")
	eq(ActionLock.press("weapon", "drill_bomb"), "drill_bomb", "or a shot item")
	eq(ActionLock.press("skill", "skill"), "skill", "tapping it again: no going back")
	eq(ActionLock.press("skill", "drill_bomb"), "skill", "no switch to another special")
	eq(ActionLock.press("drill_bomb", "skill"), "drill_bomb", "nor from an item to the skill")
	check(ActionLock.slot_enabled("weapon", "skill", true), "nothing armed: on")
	check(ActionLock.slot_enabled("skill", "skill", true), "the armed one stays on (shown armed)")
	check(not ActionLock.slot_enabled("skill", "drill_bomb", true), "the others off")
	check(not ActionLock.slot_enabled("weapon", "skill", false), "its own rule still applies")
	check(not ActionLock.locked("weapon") and ActionLock.locked("teleport"), "locked once a special is armed")


func test_no_end_turn_or_weapon_button() -> void:
	var h := _hud()
	for s in ["end_turn_pressed", "weapon_pressed"]:
		check(not h.has_signal(s), "no %s" % s)
	var texts := _buttons(h).map(func(b): return b.text)
	check(not texts.has("Hết lượt") and not texts.has("Vũ khí"), "no Hết lượt / Vũ khí buttons: %s" % [texts])
	var leave: Button = h.find_child("Leave", true, false)
	check(leave != null and leave.custom_minimum_size.x >= 60, "Thoát is a round button in the corner")
	h.free()


## Top left: only the chat lines, plain text over the sky: no panel, no input row, nothing to tap.
func test_chat_is_plain_text() -> void:
	var h := _hud()
	var lines: VBoxContainer = h.find_child("ChatLines", true, false)
	check(lines != null, "the chat lines")
	eq(h.chat_lines().map(func(l): return l["text"]), ["[Hệ thống] Trận đấu bắt đầu!"], "the system line")
	check(h.find_child("Chat", true, false) == null, "no chat box button")
	for n in _all(lines):
		check(not (n is PanelContainer or n is Button or n is LineEdit), "no frame / input in the chat: %s" % n)
		eq((n as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "taps go through")
	var l: RichTextLabel = lines.get_child(0)
	check(l.get_theme_constant("outline_size") >= 4, "outlined over the sky")
	check(l.get_theme_color("font_shadow_color").a > 0.0, "and shadowed")
	for i in 7:
		h.add_chat_line({"channel": "Thế giới", "name": "A", "text": "tin %d" % i})
	var shown: Array = h.chat_lines()
	eq(shown.size(), Hud.CHAT_LINES, "the oldest lines go")
	eq(shown[-1]["text"], "[Thế giới] A: tin 6", "the newest last")
	near(shown[-1]["alpha"], 1.0, 1e-6, "the newest fully shown")
	check(shown[0]["alpha"] < shown[-2]["alpha"] and shown[-2]["alpha"] < 1.0, "the older ones fade")
	check(shown[0]["alpha"] >= Hud.CHAT_MIN_ALPHA - 1e-4, "still readable")
	h.free()


static func _all(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out


func test_turn_portrait() -> void:
	var h := _hud()
	eq(h.portrait()["visible"], false, "hidden before a turn")
	h.set_turn(true, "Smoke", {"playerId": "me", "characterId": "rookie", "weaponUpgradeLevel": 16, "isBot": false})
	var p: Dictionary = h.portrait()
	check(p["visible"], "shown")
	eq([p["character"], p["aura"]], ["rookie", "red"], "my figure, my +16 red aura")
	eq(h.turn_text(), "Lượt của bạn", "the banner text")
	h.set_turn(false, "Đối thủ", {"playerId": "p2", "characterId": "spark", "weaponUpgradeLevel": 14}, false)
	p = h.portrait()
	eq([p["character"], p["aura"]], ["spark", "purple"], "the opponent's turn: its figure and +14 aura")
	h.set_turn(false, "Bot", {"playerId": "bot_1", "characterId": "tanko", "weaponUpgradeLevel": 16, "isBot": true}, false)
	eq(h.portrait()["aura"], "", "bots: no aura")
	h.set_turn(false, "Cũ", {"playerId": "p3", "characterId": "flora"}, false)
	eq([h.portrait()["character"], h.portrait()["aura"]], ["flora", ""], "an older server (no weaponUpgradeLevel): no aura")
	eq(Hud.portrait_level({"weaponUpgradeLevel": 15}), 15, "the level")
	eq(Hud.portrait_level({"weaponUpgradeLevel": 16, "isBot": true}), 0, "a bot")
	h.free()


## The portrait is only the figure: no card / background, no name, no title plate (titles stay
## over each sprite's name), and it stays clear of the timer and the wind.
func test_turn_portrait_is_frameless() -> void:
	var h := _hud()
	var red := {"id": "grandmaster", "name": "Cao thủ", "rarity": "red"}
	h.set_turn(true, "Smoke", {"playerId": "me", "characterId": "rookie", "title": red})
	var node: Control = h.portrait()["node"]
	check(not (node is PanelContainer), "no card")
	eq(node.get_children().map(func(c): return str(c.name)), ["Figure"], "only the figure in it")
	for n in _all(node):
		check(not (n is Label or n is RichTextLabel or n is PanelContainer), "no name / frame: %s" % n)
		check(not n.has_method("set_title"), "no title plate")
	check(node.custom_minimum_size.x <= Hud.PORTRAIT_ART.x + 0.01, "the figure's box")
	# At the smallest viewport the portrait's left edge stays right of the wind panel.
	var vw := 1600.0
	var centre: Control = h.find_child("TopCentre", true, false)
	var centre_right := vw / 2.0 + centre.get_combined_minimum_size().x / 2.0
	check(vw - Hud.MARGIN - Hud.PORTRAIT_ART.x - Hud.PORTRAIT_SLIDE > centre_right, "clear of the wind / timer even sliding in")
	h.free()


func test_slots() -> void:
	var h := _hud()
	var rookie := {"id": "triple_shot", "name": "Bắn 3 tia", "needs_aim": true, "offsets": [-10.0, 0.0, 10.0]}
	var items := [{"id": "medkit", "count": 2, "name": "Hộp cứu thương", "enabled": true},
		{"id": "drill_bomb", "count": 1, "name": "Bom khoan", "enabled": true}]
	h.set_actions(rookie, 40, false, "weapon", items)
	var s: Dictionary = h.slots()
	check(s["skill"]["visible"] and s["skill"]["disabled"] and not s["skill"]["armed"], "charging: shown, off")
	near(s["skill"]["ring"], 0.4, 1e-6, "the ring at 40/100")
	eq(s["skill"]["name"], "Bắn 3 tia", "its name")
	eq(s["skill"]["picture"], "triple_shot", "the skill's own picture, not the lightning icon")
	check(h._skill.icon == null, "no lightning icon on the slot")
	eq(s["items"].map(func(i): return [i["id"], i["count"], i["disabled"], i["armed"]]),
		[["medkit", "x2", false, false], ["drill_bomb", "x1", false, false]], "the items with their counts")
	h.set_actions(rookie, 100, true, "skill", [items[0], {"id": "drill_bomb", "count": 1, "name": "Bom khoan", "enabled": false}])
	s = h.slots()
	check(not s["skill"]["disabled"] and s["skill"]["armed"], "charged and armed")
	near(s["skill"]["ring"], 1.0, 1e-6, "full ring")
	check(s["items"][1]["disabled"] and not s["items"][1]["armed"], "the shot item off while the skill is armed")
	check(not s["items"][0]["disabled"], "the instant item stays usable")
	h.set_actions({"id": "mystery", "name": "?"}, 0, false, "weapon", [])
	eq(h.slots()["skill"]["picture"], "", "an unknown skill: no picture")
	check(h._skill.icon != null, "an unknown skill keeps the lightning icon")
	h.set_actions({}, 0, false, "weapon", [])
	check(not h.slots()["skill"]["visible"] and h.slots()["items"].is_empty(), "unknown character, no items: nothing")
	h.free()


## match_screen without its scene: my turn, a skill and items in hand.
func _screen() -> Node:
	var m = MatchScreen.new()
	m._me = "me"
	m._current = "me"
	m._players = {"me": {"playerId": "me", "characterId": "rookie", "isAlive": true, "skillEnergy": 100,
		"items": ["drill_bomb", "medkit", "teleport"], "statusEffects": []}}
	var view := Node2D.new()
	m._views = {"me": view}
	m._hud = _hud()
	m._aim = AimInput.new()
	m._shot_player = ShotPlayer.new()
	return m


func _free(m) -> void:
	m._hud.free()
	m._aim.free()
	m._shot_player.free()
	m._views["me"].free()
	m.free()


func test_screen_keeps_the_special() -> void:
	var m = _screen()
	m._refresh_controls()
	var s: Dictionary = m._hud.slots()
	check(not s["skill"]["disabled"], "charged skill on")
	eq(s["items"].map(func(i): return i["disabled"]), [false, false, false], "all items on")
	m._on_item_pressed("drill_bomb")
	eq(m._armed, "drill_bomb", "the shot item armed")
	m._on_item_pressed("drill_bomb")
	eq(m._armed, "drill_bomb", "tapping it again keeps it (no normal shot back)")
	m._on_item_pressed("teleport")
	eq(m._armed, "drill_bomb", "no switch to another shot item")
	m._on_skill_pressed()
	eq(m._armed, "drill_bomb", "nor to the skill")
	s = m._hud.slots()
	check(s["skill"]["disabled"], "the skill slot off")
	var by_id := {}
	for i in s["items"]:
		by_id[i["id"]] = i
	check(by_id["drill_bomb"]["armed"] and not by_id["drill_bomb"]["disabled"], "the armed item shown armed")
	check(by_id["teleport"]["disabled"], "the other shot item off")
	check(not by_id["medkit"]["disabled"], "the instant item still usable")
	# A new turn starts on the normal shot again.
	check(FileAccess.get_file_as_string("res://match/match_screen.gd").contains("_armed = WEAPON # every turn starts with the weapon"), "a new turn resets it")
	m._armed = "weapon" # what _set_current does on a new turn
	m._on_skill_pressed()
	eq(m._armed, "skill", "the skill armed")
	m._on_skill_pressed()
	eq(m._armed, "skill", "tapping the skill again keeps it")
	m._on_item_pressed("teleport")
	eq(m._armed, "skill", "no item after the skill")
	_free(m)
