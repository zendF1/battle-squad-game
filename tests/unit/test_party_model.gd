extends "res://tests/test_case.gd"
## screens/home/party_model.gd: the ranked 2v2 party without UI: the lobby and my role, the
## invites both ways, the popup rows and the start button, and the actions each event asks for.

const PartyModel := preload("res://screens/home/party_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const HOST := {"playerId": "me", "displayName": "Tôi", "characterId": "rookie", "level": 7, "rating": 1050,
	"tier": "silver", "division": 2, "ready": false, "gun": {"kind": "bazooka", "tier": "iron"}}
const MATE := {"playerId": "p2", "displayName": "Bạn Hiền", "characterId": "tanko", "level": 5, "rating": 980,
	"tier": "bronze", "division": 1, "ready": false, "gun": {"kind": "cannon", "tier": "basic"}}


static func _party(me: String = "me") -> PartyModel:
	var p := PartyModel.new()
	p.me = me
	return p


static func _lobby(members: Array, host: String = "me", status: String = "preparing") -> Dictionary:
	return {"lobbyId": "l1", "hostPlayerId": host, "status": status, "members": members}


static func _err(code: String) -> Dictionary:
	return {"error": {"code": code, "message": code, "correlationId": "ws-error"}}


static func _with(m: Dictionary, key: String, value: Variant) -> Dictionary:
	var out := m.duplicate(true)
	out[key] = value
	return out


func test_parse_member() -> void:
	var m := PartyModel.parse_member(MATE)
	eq(m["playerId"], "p2", "id")
	eq(m["displayName"], "Bạn Hiền", "name")
	eq(m["level"], 5, "level")
	eq(m["gun"], {"kind": "cannon", "tier": "basic"}, "its gun")
	var bare := PartyModel.parse_member({"playerId": "p3", "characterId": "spark"})
	eq(bare["gun"]["tier"], "basic", "no gun sent: the basic gun")
	check(str(bare["gun"]["kind"]) != "", "of its character")
	eq(bare["level"], 0, "level unknown")
	check(not bare["ready"], "not ready")
	eq(PartyModel.parse_member({"displayName": "x"}), {}, "no id: not a member")


func test_host_alone_then_a_teammate_joins() -> void:
	var p := _party()
	eq(p.on_event("LobbyUpdated", _lobby([HOST]), 0.0), [["changed"]], "my lobby")
	check(p.is_host() and not p.in_party(), "host alone")
	check(p.my_ready(), "the host is always ready")
	eq(p.start_button(), {"text": "BẮT ĐẦU", "disabled": false, "action": "start"}, "alone: BẮT ĐẦU")
	p.on_event("LobbyUpdated", _lobby([HOST, MATE]), 1.0)
	check(p.in_party(), "two of us")
	eq(p.teammate()["playerId"], "p2", "the teammate is the other one")
	eq(p.start_button(), {"text": "Chờ đồng đội sẵn sàng", "disabled": true, "action": "start"}, "waits for the teammate")
	p.on_event("LobbyUpdated", _lobby([HOST, _with(MATE, "ready", true)]), 2.0)
	eq(p.start_button(), {"text": "BẮT ĐẦU", "disabled": false, "action": "start"}, "ready: the host may start")
	eq(p.on_event("QueueStarted", {"estimatedWait": 60}, 3.0), [], "the host's own queue is Matchmaking's")


func test_member_sees_the_host_and_readies() -> void:
	var p := _party("p2")
	p.on_event("LobbyUpdated", _lobby([HOST, MATE]), 0.0)
	check(p.is_member() and not p.is_host(), "member")
	eq(p.teammate()["playerId"], "me", "the host is my teammate (shown on the right)")
	eq(p.start_button()["text"], "SẴN SÀNG", "SẴN SÀNG")
	eq(p.start_button()["action"], "ready", "opens the Loadout")
	var loadout := {"characterId": "tanko", "items": ["medkit"]}
	eq(p.confirm_ready(loadout, 1.0), [["send", "UpdateLoadout", loadout], ["send", "SetReady", {"ready": true}]], "loadout, then ready")
	p.on_event("LobbyUpdated", _lobby([HOST, _with(MATE, "ready", true)]), 1.2)
	eq(p.start_button()["text"], "HUỶ SẴN SÀNG", "ready: HUỶ SẴN SÀNG")
	eq(p.set_ready(false, 2.0), [["send", "SetReady", {"ready": false}]], "unready")
	eq(p.on_event("QueueStarted", {"estimatedWait": 60}, 3.0), [["queue_started"]], "the host's queue takes me to Matchmaking")


func test_invite_without_a_lobby_creates_it_first() -> void:
	var p := _party()
	eq(p.invite("p2", 0.0), [["send", "CreateLobby", {}]], "CreateLobby first")
	eq(p.on_event("LobbyUpdated", _lobby([HOST]), 0.2), [["changed"], ["send", "InviteToLobby", {"playerId": "p2"}]], "then the invite")
	eq(p.invite("p3", 1.0), [["send", "InviteToLobby", {"playerId": "p3"}]], "with a lobby: the invite at once")
	eq(p.invite("me", 1.0), [], "never myself")


func test_create_refused_leaves_and_asks_again_once() -> void:
	var p := _party()
	p.invite("p2", 0.0)
	eq(p.on_event("LobbyError", _err("ALREADY_IN_LOBBY"), 0.1), [["send", "LeaveLobby", {}], ["send", "CreateLobby", {}]], "leave the stale lobby, again")
	var out := p.on_event("LobbyError", _err("ALREADY_IN_LOBBY"), 0.2)
	eq(out, [["toast", ErrorText.lobby_error(_err("ALREADY_IN_LOBBY"))]], "a second refusal is shown")
	var q := _party()
	q.invite("p2", 0.0)
	eq(q.on_event("LobbyError", _err("IN_ROOM"), 0.1), [["send", "Leave", {}], ["send", "CreateLobby", {}]], "IN_ROOM: Leave the room")


func test_invite_sent_counts_down_on_the_row() -> void:
	var p := _party()
	p.on_event("LobbyUpdated", _lobby([HOST]), 0.0)
	p.on_event("OnlinePlayers", {"players": [
		{"playerId": "p2", "displayName": "Bạn Hiền", "level": 5, "tier": "bronze", "division": 1, "characterId": "tanko", "status": "idle"},
		{"playerId": "p3", "displayName": "Bận Rộn", "level": 9, "tier": "gold", "division": 3, "characterId": "spark", "status": "in_lobby"},
		{"playerId": "p4", "displayName": "Đang Đánh", "level": 2, "tier": "", "division": 0, "characterId": "flora", "status": "in_match"},
		{"playerId": "me", "displayName": "Tôi", "status": "idle"}]}, 0.0)
	eq(p.players.size(), 3, "rows, never me")
	eq(p.row_button(p.players[0], 0.0), {"text": "Mời", "disabled": false}, "idle: Mời")
	eq(p.row_button(p.players[1], 0.0), {"text": "Bận", "disabled": true}, "in a lobby: Bận")
	eq(p.row_button(p.players[2], 0.0), {"text": "Đang trận", "disabled": true}, "in a match: Đang trận")
	eq(p.on_event("InviteSent", {"playerId": "p2", "expiresInSec": 30}, 1.0), [["players"]], "sent")
	eq(p.row_button(p.players[0], 1.0), {"text": "Đã mời (30s)", "disabled": true}, "Đã mời (30s)")
	eq(p.row_button(p.players[0], 13.5), {"text": "Đã mời (18s)", "disabled": true}, "counting down")
	eq(p.tick(31.0), [["players"]], "past its time it drops")
	eq(p.row_button(p.players[0], 31.0)["text"], "Mời", "Mời again")


func test_invite_answers_for_the_inviter() -> void:
	var p := _party()
	p.on_event("LobbyUpdated", _lobby([HOST]), 0.0)
	p.on_event("InviteSent", {"playerId": "p2", "expiresInSec": 30}, 0.0)
	eq(p.on_event("InviteDeclined", {"playerId": "p2", "displayName": "Bạn Hiền"}, 2.0),
		[["toast", "Bạn Hiền đã từ chối lời mời"], ["players"]], "declined")
	eq(p.sent_left("p2", 2.0), 0, "no longer waiting")
	p.on_event("InviteSent", {"playerId": "p2", "expiresInSec": 30}, 3.0)
	eq(p.on_event("InviteExpired", {"playerId": "p2"}, 33.0), [["toast", "Lời mời đã hết hạn"], ["players"]], "expired")
	p.on_event("InviteSent", {"playerId": "p2", "expiresInSec": 30}, 40.0)
	p.on_event("LobbyUpdated", _lobby([HOST, MATE]), 41.0)
	eq(p.sent_left("p2", 41.0), 0, "joined: the invite is done")
	eq(p.row_button({"playerId": "p5", "status": "idle"}, 41.0), {"text": "Mời", "disabled": true}, "a full party invites no one")


func test_invitee_accepts_or_declines() -> void:
	var p := _party("p2")
	var inv := {"inviteId": "i1", "lobbyId": "l1", "mode": "ranked_2v2", "expiresInSec": 30,
		"from": {"playerId": "me", "displayName": "Tôi", "level": 7, "tier": "silver", "division": 2, "characterId": "rookie", "status": "idle"}}
	var out := p.on_event("LobbyInvite", inv, 10.0)
	eq(out.size(), 1, "one action")
	eq(out[0][0], "invite", "show it")
	eq(p.incoming["from"]["displayName"], "Tôi", "from the inviter")
	near(p.incoming_ratio(10.0), 1.0, 1e-6, "full bar")
	near(p.incoming_ratio(25.0), 0.5, 1e-6, "half way")
	eq(p.respond(true, 26.0), [["send", "RespondInvite", {"inviteId": "i1", "accept": true}], ["invite_closed"]], "accept")
	eq(p.respond(true, 26.0), [], "once")
	p.on_event("LobbyInvite", _with(inv, "inviteId", "i2"), 30.0)
	eq(p.respond(false, 31.0), [["send", "RespondInvite", {"inviteId": "i2", "accept": false}], ["invite_closed"]], "decline")
	p.on_event("LobbyInvite", _with(inv, "inviteId", "i3"), 40.0)
	eq(p.on_event("InviteExpired", {"inviteId": "other"}, 41.0), [], "another invite's expiry")
	eq(p.on_event("InviteExpired", {"inviteId": "i3"}, 42.0), [["invite_closed"]], "its expiry closes it")
	p.on_event("LobbyInvite", _with(inv, "inviteId", "i4"), 50.0)
	eq(p.tick(79.0), [], "still running")
	eq(p.tick(80.0), [["invite_closed"]], "closes at its time on its own")


func test_invite_lifetime_from_game_data_when_missing() -> void:
	var p := _party("p2")
	var inv := {"inviteId": "i1", "lobbyId": "l1", "mode": "ranked_2v2", "from": {"playerId": "me"}}
	p.on_event("LobbyInvite", inv, 0.0)
	eq(p.incoming["expiresInSec"], GameData.invite_timeout_sec(), "the game data's inviteTimeoutSec")


func test_kick_and_disband() -> void:
	var host := _party()
	host.on_event("LobbyUpdated", _lobby([HOST, MATE]), 0.0)
	eq(host.kick(1.0), [["send", "KickMember", {"playerId": "p2"}]], "the host kicks")
	var member := _party("p2")
	member.on_event("LobbyUpdated", _lobby([HOST, MATE]), 0.0)
	eq(member.kick(1.0), [], "a member cannot")
	eq(member.on_event("LobbyKicked", {"lobbyId": "l1"}, 2.0), [["toast", "Bạn đã bị mời ra khỏi đội"], ["changed"]], "kicked")
	check(not member.in_lobby(), "the slot goes back to +")
	member.on_event("LobbyUpdated", _lobby([HOST, MATE]), 3.0)
	eq(member.on_event("LobbyDisbanded", {"reason": "host_left"}, 4.0), [["toast", "Chủ phòng đã rời đội"], ["changed"]], "the host left")
	check(not member.in_lobby(), "gone")
	host.on_event("LobbyUpdated", _lobby([HOST]), 5.0)
	check(not host.in_party(), "the kicked one is gone for the host")


func test_leave_and_lobbies_of_others() -> void:
	var p := _party()
	eq(p.on_event("LobbyUpdated", _lobby([MATE], "p2"), 0.0), [], "a lobby I am not in is not mine")
	p.on_event("LobbyUpdated", _lobby([HOST, MATE]), 0.0)
	eq(p.leave(), [["send", "LeaveLobby", {}], ["changed"]], "LeaveLobby")
	check(not p.in_lobby(), "cleared")
	eq(p.leave(), [["send", "LeaveLobby", {}]], "always sent (a stale lobby on the server)")
	p.on_event("LobbyUpdated", _lobby([HOST, MATE]), 0.0)
	eq(p.on_disconnected(), [["changed"]], "the socket closed: no lobby")
	check(not p.in_lobby(), "cleared")


func test_errors_only_after_my_requests() -> void:
	var p := _party()
	p.on_event("LobbyUpdated", _lobby([HOST]), 0.0)
	eq(p.on_event("LobbyError", _err("PLAYER_BUSY"), 1.0), [], "not mine: Matchmaking / the match show theirs")
	p.invite("p2", 10.0)
	eq(p.on_event("LobbyError", _err("PLAYER_BUSY"), 10.3), [["toast", "Người chơi này đang bận"]], "mine: shown")
	var q := _party("p2")
	q.on_event("LobbyUpdated", _lobby([HOST, MATE]), 0.0)
	q.set_ready(true, 20.0)
	eq(q.on_event("LobbyError", _err("LOBBY_REQUIRED"), 20.1), [], "a late answer to a match's LeaveLobby")
	eq(q.on_event("LobbyError", _err("INVALID_STATUS"), 30.0), [], "out of the window")
	for code in ["LOBBY_FULL", "PLAYER_OFFLINE", "PLAYER_BUSY", "INVITE_PENDING", "INVITE_EXPIRED", "MEMBER_NOT_READY", "NOT_HOST"]:
		check(not ErrorText.lobby_error(_err(code)).begins_with("Lỗi ghép trận"), "%s in Vietnamese" % code)


func test_list_query() -> void:
	var p := _party()
	eq(p.list(""), [["send", "ListOnlinePlayers", {}]], "everyone")
	eq(p.list("  Hiền "), [["send", "ListOnlinePlayers", {"query": "Hiền"}]], "a name")


func test_invite_into_a_gone_lobby_creates_a_new_one() -> void:
	var p := _party()
	p.on_event("LobbyUpdated", _lobby([HOST]), 0.0)
	eq(p.invite("p2", 1.0), [["send", "InviteToLobby", {"playerId": "p2"}]], "invite")
	eq(p.on_event("LobbyError", _err("LOBBY_REQUIRED"), 1.1), [["changed"], ["send", "CreateLobby", {}]], "LOBBY_REQUIRED: a new lobby")
	check(not p.in_lobby(), "the old one forgotten")
	eq(p.on_event("LobbyUpdated", _with(_lobby([HOST]), "lobbyId", "l2"), 1.3),
		[["changed"], ["send", "InviteToLobby", {"playerId": "p2"}]], "then the invite again")
	eq(p.on_event("LobbyError", _err("LOBBY_REQUIRED"), 1.4), [["toast", ErrorText.lobby_error(_err("LOBBY_REQUIRED"))]], "only once")


func test_a_full_lobby_clears_my_other_invites() -> void:
	var p := _party()
	p.on_event("LobbyUpdated", _lobby([HOST]), 0.0)
	p.on_event("InviteSent", {"playerId": "p2", "expiresInSec": 30}, 0.0)
	p.on_event("InviteSent", {"playerId": "p3", "expiresInSec": 30}, 0.0)
	eq(p.on_event("LobbyUpdated", _lobby([HOST, MATE]), 1.0), [["changed"], ["players"]], "the rows redraw")
	eq(p.sent, {}, "no \"Đã mời\" left (the server cancelled them)")


func test_stage_character_goes_to_the_teammate() -> void:
	var p := _party()
	p.on_event("LobbyUpdated", _lobby([HOST]), 0.0)
	eq(p.set_character("spark", 1.0), [], "alone: nobody to show it to")
	p.on_event("LobbyUpdated", _lobby([HOST, MATE]), 1.0)
	eq(p.set_character("spark", 2.0), [["send", "UpdateLoadout", {"characterId": "spark"}]], "with a teammate: UpdateLoadout")
	eq(p.set_character("rookie", 2.0), [], "unchanged: nothing")
	p.on_event("LobbyUpdated", _lobby([HOST, MATE], "me", "in_queue"), 3.0)
	eq(p.set_character("spark", 3.0), [], "not while queued")
