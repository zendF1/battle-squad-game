extends "res://tests/test_case.gd"
## screens/home/party_layout.gd (Home's teammate slots: one for 2v2, three for a boss) and the
## party model / mode switch for a party of four (party_model.gd capacity, mode_select_model.gd
## TOO_LARGE, PARTY_TOO_LARGE).

const BossFixture := preload("res://tests/boss_fixture.gd")
const PartyLayout := preload("res://screens/home/party_layout.gd")
const PartyModel := preload("res://screens/home/party_model.gd")
const ModeSelectModel := preload("res://screens/home/mode_select_model.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")

const ME := {"playerId": "me", "displayName": "Tôi", "characterId": "rookie", "ready": false}


static func _m(id: String, ready: bool = false) -> Dictionary:
	return {"playerId": id, "displayName": id, "characterId": "tanko", "ready": ready}


static func _lobby(members: Array, queue: String = "boss:steel_robot", host: String = "me") -> Dictionary:
	return {"lobbyId": "l1", "hostPlayerId": host, "status": "preparing", "queue": queue, "members": members}


func test_slot_counts() -> void:
	eq(PartyLayout.slots(1), [], "solo: none")
	eq(PartyLayout.slots(2).size(), 1, "2v2: one")
	eq(PartyLayout.slots(4).size(), 3, "a boss party: three")
	eq(PartyLayout.slots(3).size(), 2, "three: two")
	eq(PartyLayout.slots(2)[0]["scale"], 1.0, "the 2v2 slot keeps its size")


func test_four_fit_around_the_stage() -> void:
	var slots := PartyLayout.slots(4)
	eq(slots.map(func(s): return s["side"]), [1, -1, 1], "two right, one left")
	var spans: Array = slots.map(func(s): return PartyLayout.figure_span(s))
	for i in slots.size():
		check(slots[i]["scale"] < 1.0, "smaller than the 2v2 slot")
		var sp: Array = spans[i]
		check(sp[0] >= PartyLayout.STAGE_HALF or sp[1] <= -PartyLayout.STAGE_HALF, "clear of my stage: %s" % str(sp))
		for j in range(i + 1, slots.size()):
			var other: Array = spans[j]
			check(sp[1] <= other[0] or other[1] <= sp[0], "slots %d and %d do not overlap" % [i, j])
	check(absf(slots[0]["x"]) == absf(slots[1]["x"]), "the inner two mirror each other")


func test_fill_pads_with_plus() -> void:
	eq(PartyLayout.fill([_m("a")], 4), [_m("a"), {}, {}], "one teammate, two +")
	eq(PartyLayout.fill([], 2), [{}], "the 2v2 +")


func test_party_of_four() -> void:
	BossFixture.take()
	var p := PartyModel.new()
	p.me = "me"
	p.queue = "boss:steel_robot"
	eq(p.capacity(), 4, "a boss holds four")
	p.on_event("LobbyUpdated", _lobby([ME, _m("a")]), 0.0)
	check(p.in_party() and not p.is_full(), "two of four")
	eq(p.row_button({"playerId": "x", "status": "idle"}, 0.0), {"text": "Mời", "disabled": false}, "more may be invited")
	eq(p.invite("x", 0.0), [["send", "InviteToLobby", {"playerId": "x"}]], "invite the third")
	p.on_event("LobbyUpdated", _lobby([ME, _m("a", true), _m("b")]), 1.0)
	eq(p.teammates().map(func(m): return m["playerId"]), ["a", "b"], "the teammates in order")
	eq(p.start_button()["text"], PartyModel.WAIT_MATE, "waits for every teammate")
	p.on_event("LobbyUpdated", _lobby([ME, _m("a", true), _m("b", true), _m("c", true)]), 2.0)
	check(p.is_full(), "full at four")
	eq(p.start_button()["text"], PartyModel.START, "all ready")
	eq(p.invite("y", 3.0), [], "no more invites")
	eq(p.row_button({"playerId": "y", "status": "idle"}, 3.0)["disabled"], true, "Mời off")
	eq(p.kick(3.0, "b"), [["send", "KickMember", {"playerId": "b"}]], "kick the one chosen")
	eq(p.member_count(), 4, "four members")


func test_too_large_for_two() -> void:
	BossFixture.take()
	var boss := LobbyModel.index_of_queue("boss:steel_robot")
	var casual := LobbyModel.index_of_queue("casual_2v2")
	var crab := LobbyModel.index_of_queue("boss:lava_crab")
	eq(ModeSelectModel.switch_action(boss, casual, true, false, true, 3), ModeSelectModel.TOO_LARGE, "three to a 2v2")
	eq(ModeSelectModel.switch_action(boss, casual, true, false, true, 2), ModeSelectModel.SET_QUEUE, "two fit")
	eq(ModeSelectModel.switch_action(boss, crab, true, false, true, 4), ModeSelectModel.SET_QUEUE, "boss to boss")
	eq(ModeSelectModel.switch_action(casual, boss, true, false, true, 2), ModeSelectModel.SET_QUEUE, "2v2 to a boss")


func test_party_too_large_error() -> void:
	BossFixture.take()
	var p := PartyModel.new()
	p.me = "me"
	p.on_event("LobbyUpdated", _lobby([ME, _m("a"), _m("b")]), 0.0)
	p.select_queue("casual_2v2", 1.0)
	var out := p.on_event("LobbyError", {"error": {"code": "PARTY_TOO_LARGE", "message": "x"}}, 1.2)
	eq(out, [["toast", "Đội đông hơn số người của chế độ này"], ["queue_refused"], ["changed"]], "told, Home goes back")
	eq(p.lobby_queue(), "boss:steel_robot", "the lobby keeps its queue")
