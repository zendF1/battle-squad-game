extends "res://tests/test_case.gd"
## match_screen.gd: the result screen shows RESULT_DELAY_SEC after MatchEnded is applied (a Timer
## child, freed with the screen), the controls locked meanwhile; "Trận bị huỷ" shows at once.

const Hud := preload("res://match/hud.gd")
const MatchScreen := preload("res://match/match_screen.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const ResultScreen := preload("res://match/result_screen.gd")


## match_screen without its scene: my turn in a 1v1, its HUD built by hand.
func _screen() -> Node:
	var m = MatchScreen.new()
	m._me = "me"
	m._current = "me"
	m._players = {
		"me": {"playerId": "me", "characterId": "rookie", "isAlive": true, "skillEnergy": 0, "items": [],
			"statusEffects": [], "teamId": 1, "hp": 1000, "maxHp": 1000, "position": {"x": 100.0, "y": 500.0}},
		"bot": {"playerId": "bot", "characterId": "tanko", "isAlive": false, "skillEnergy": 0, "items": [],
			"statusEffects": [], "teamId": 2, "hp": 0, "maxHp": 1000, "position": {"x": 900.0, "y": 500.0}}}
	m._views = {} # no figures: the end only stops them
	m.send_hook = func(_event: String, _data: Dictionary) -> void: pass
	var h: Control = Hud.new()
	h._ready()
	var v: Control = h._portrait_art
	v._ready()
	v.character()._ready()
	m._hud = h
	m._aim = AimInput.new()
	m._shot_player = ShotPlayer.new()
	return m


func _free(m) -> void:
	m._hud.free()
	m._aim.free()
	m._shot_player.free()
	m.free()


static func _result_screens(m: Node) -> Array:
	var out: Array = []
	for c in m.get_children():
		if c is CanvasLayer:
			for s in c.get_children():
				if s is ResultScreen:
					out.append(s)
	return out


static func _delay(m: Node) -> Timer:
	return m.get_node_or_null("ResultDelay") as Timer


func test_result_waits_for_the_delay() -> void:
	var m = _screen()
	m._on_match_ended({"winningTeam": 1, "rewards": null})
	check(m._ended, "the match is over")
	check(not m._can_act(), "input locked during the wait")
	eq(_result_screens(m).size(), 0, "no result screen yet")
	var t := _delay(m)
	check(t != null, "a Timer child waits")
	if t != null:
		eq(t.wait_time, MatchScreen.RESULT_DELAY_SEC, "for the delay")
		eq(MatchScreen.RESULT_DELAY_SEC, 2.0, "2 s")
		check(t.one_shot and t.autostart, "once, started on entering the tree")
		t.timeout.emit()
		eq(_result_screens(m).size(), 1, "the result screen after the timer")
	_free(m)


func test_no_contest_shows_at_once() -> void:
	var m = _screen()
	m._on_match_ended({"result": "no_contest", "message": "Đối thủ rời trận"})
	check(_delay(m) == null, "no wait")
	eq(_result_screens(m).size(), 0, "the HUD's banner, not the result screen")
	_free(m)


func test_leaving_during_the_wait_frees_the_timer() -> void:
	var m = _screen()
	m._on_match_ended({"winningTeam": 2, "rewards": null})
	var t := _delay(m)
	check(t != null and t.get_parent() == m, "the timer belongs to the screen")
	_free(m) # the screen gone: its timer with it, nothing left to fire
	check(not is_instance_valid(t), "freed with the screen")
