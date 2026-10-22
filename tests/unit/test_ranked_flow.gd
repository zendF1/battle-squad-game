extends "res://tests/test_case.gd"

const RankedFlow := preload("res://screens/ranked/ranked_flow.gd")

const LOADOUT := {"characterId": "spark", "items": ["medkit", "teleport"]}
const LOBBY := {"lobbyId": "l1", "hostPlayerId": "me", "status": "preparing", "members": []}


static func _sent(actions: Array) -> Array:
	return actions.filter(func(a): return a[0] == "send").map(func(a): return a[1])


static func _kinds(actions: Array) -> Array:
	return actions.map(func(a): return a[0] if a[0] != "send" else "send:" + a[1])


static func _err(code: String) -> Dictionary:
	return {"error": {"code": code, "message": code, "correlationId": "ws-error"}}


## A flow searching in the queue.
func _searching() -> RankedFlow:
	var f := RankedFlow.new()
	f.start(LOADOUT)
	f.on_event("LobbyUpdated", LOBBY)
	f.on_event("LobbyUpdated", LOBBY)
	f.on_event("QueueStarted", {"estimatedWait": 60})
	return f


func test_queue_steps_wait_for_each_answer() -> void:
	var f := RankedFlow.new()
	eq(f.start(LOADOUT), [["send", "CreateLobby", {}]], "create first")
	eq(f.on_event("QueueStarted", {}), [], "nothing before the lobby exists")
	eq(f.on_event("LobbyUpdated", LOBBY), [["send", "UpdateLoadout", {"characterId": "spark", "items": ["medkit", "teleport"]}]], "then the loadout")
	eq(f.on_event("LobbyUpdated", LOBBY), [["send", "StartQueue", {}]], "then the queue")
	eq(f.on_event("LobbyUpdated", {"status": "in_queue"}), [], "the queue's LobbyUpdated is not an answer")
	eq(f.on_event("QueueStarted", {"estimatedWait": 60}), [["searching"]], "searching")
	eq(f.tick(500.0), [], "no timeout while searching")
	var found := {"roomId": "r", "matchId": "m", "teams": []}
	eq(f.on_event("MatchFound", found), [["found", found]], "found")
	check(f.found(), "found")
	eq(f.cancel(), [], "too late to cancel")
	eq(f.on_event("MatchStarted", {"matchId": "m"}), [["started", {"matchId": "m"}]], "started")
	check(not f.busy(), "done")
	eq(f.on_event("MatchStarted", {}), [], "nothing after")


func test_loadout_is_a_copy() -> void:
	var items := ["medkit"]
	var f := RankedFlow.new()
	f.start({"characterId": "flora", "items": items})
	items.append("teleport")
	var a := f.on_event("LobbyUpdated", LOBBY)
	eq(a[0][2]["items"], ["medkit"], "the items at start")


func test_cancel_while_searching() -> void:
	var f := _searching()
	eq(f.cancel(), [["send", "CancelQueue", {}]], "cancel the queue")
	eq(_kinds(f.on_event("QueueCancelled", {"reason": "cancelled"})), ["send:LeaveLobby", "cancelled"], "then leave the lobby")


func test_cancel_without_answer_leaves_anyway() -> void:
	var f := _searching()
	f.cancel()
	eq(f.tick(1.0), [], "waiting")
	eq(_kinds(f.tick(RankedFlow.CANCEL_TIMEOUT)), ["send:LeaveLobby", "cancelled"], "leaves after the timeout")


func test_cancel_lost_the_race() -> void:
	var f := _searching()
	f.cancel()
	eq(_kinds(f.on_event("MatchFound", {})), ["found"], "the match goes on")


func test_cancel_while_creating_waits_for_the_lobby() -> void:
	var f := RankedFlow.new()
	f.start(LOADOUT)
	eq(f.cancel(), [], "nothing to leave yet")
	eq(_kinds(f.on_event("LobbyUpdated", LOBBY)), ["send:LeaveLobby", "cancelled"], "left once it exists")
	var g := RankedFlow.new()
	g.start(LOADOUT)
	g.cancel()
	eq(_kinds(g.tick(RankedFlow.STEP_TIMEOUT + 1)), ["cancelled"], "no lobby came: just go")


func test_cancel_in_loadout_and_queueing() -> void:
	var f := RankedFlow.new()
	f.start(LOADOUT)
	f.on_event("LobbyUpdated", LOBBY)
	eq(_kinds(f.cancel()), ["send:LeaveLobby", "cancelled"], "leave the lobby")
	var g := RankedFlow.new()
	g.start(LOADOUT)
	g.on_event("LobbyUpdated", LOBBY)
	g.on_event("LobbyUpdated", LOBBY)
	eq(_kinds(g.cancel()), ["send:CancelQueue"], "StartQueue went out: cancel it")


func test_already_in_a_lobby_leaves_and_retries() -> void:
	var f := RankedFlow.new()
	f.start(LOADOUT)
	eq(_sent(f.on_event("LobbyError", _err("ALREADY_IN_LOBBY"))), ["LeaveLobby"], "leave the old lobby")
	eq(f.tick(0.1), [], "waits a little")
	eq(_sent(f.tick(RankedFlow.RETRY_SEC)), ["CreateLobby"], "creates again")
	eq(_sent(f.on_event("LobbyError", _err("LOBBY_CREATE_FAILED"))), [], "the old one not gone yet")
	eq(_sent(f.tick(RankedFlow.RETRY_SEC)), ["CreateLobby"], "again")
	var a := f.on_event("LobbyError", _err("ALREADY_IN_LOBBY"))
	eq(_kinds(a), ["send:LeaveLobby", "failed"], "gives up after the retries")
	eq(a[1][1], "Bạn vẫn đang ở trong một tổ đội khác", "its message")


func test_in_a_room_leaves_it() -> void:
	var f := RankedFlow.new()
	f.start(LOADOUT)
	eq(_sent(f.on_event("LobbyError", _err("IN_ROOM"))), ["Leave"], "leave the room")
	eq(_sent(f.tick(1.0)), ["CreateLobby"], "creates again")


func test_stale_answers_are_ignored_while_creating() -> void:
	var f := RankedFlow.new()
	f.start(LOADOUT)
	eq(f.on_event("LobbyError", _err("LOBBY_REQUIRED")), [], "the last match's LeaveLobby answer")
	eq(_sent(f.on_event("LobbyUpdated", LOBBY)), ["UpdateLoadout"], "goes on")


func test_errors_go_home_with_a_message() -> void:
	var f := RankedFlow.new()
	f.start(LOADOUT)
	f.on_event("LobbyUpdated", LOBBY)
	var a := f.on_event("Error", {"code": "character_not_owned", "message": "character \"tanko\" not owned"})
	eq(_kinds(a), ["send:LeaveLobby", "failed"], "the lobby's own Error")
	eq(a[1][1], "Bạn chưa sở hữu nhân vật này", "in Vietnamese")
	var g := RankedFlow.new()
	g.start(LOADOUT)
	g.on_event("LobbyUpdated", LOBBY)
	g.on_event("LobbyUpdated", LOBBY)
	var b := g.on_event("LobbyError", _err("QUEUE_FAILED"))
	eq(b[1][1], "Không vào được hàng chờ, hãy thử lại", "queue failed")
	var h := _searching()
	eq(_kinds(h.on_event("QueueCancelled", {"reason": "teammate disconnected"})), ["send:LeaveLobby", "failed"], "queue dropped")
	var k := RankedFlow.new()
	k.start(LOADOUT)
	var c := k.on_event("LobbyError", {"error": {"code": "WEIRD", "message": "boom"}})
	eq(_kinds(c), ["failed"], "no lobby to leave")
	eq(c[0][1], "Lỗi ghép trận: boom", "unknown code shows the server message")


func test_timeouts() -> void:
	var f := RankedFlow.new()
	f.start(LOADOUT)
	eq(_kinds(f.tick(RankedFlow.STEP_TIMEOUT + 0.1)), ["failed"], "no lobby")
	var g := RankedFlow.new()
	g.start(LOADOUT)
	g.on_event("LobbyUpdated", LOBBY)
	eq(_kinds(g.tick(RankedFlow.STEP_TIMEOUT + 0.1)), ["send:LeaveLobby", "failed"], "no loadout answer")
	var h := _searching()
	h.on_event("MatchFound", {})
	eq(h.tick(RankedFlow.FOUND_TIMEOUT - 1), [], "waiting for the match")
	var a := h.tick(2.0)
	eq(_kinds(a), ["failed"], "the match never started")
	eq(a[0][1], RankedFlow.NOT_STARTED, "its message")


func test_disconnect() -> void:
	var f := _searching()
	var a := f.on_disconnected()
	eq(_kinds(a), ["failed"], "nothing to send: the server drops the queue")
	eq(a[0][1], RankedFlow.DISCONNECTED, "message")
	eq(RankedFlow.new().on_disconnected(), [], "idle")


func test_party_host_never_leaves_the_lobby() -> void:
	var f := RankedFlow.new()
	f.keep_lobby = true
	eq(f.start(LOADOUT), [["send", "CreateLobby", {}]], "CreateLobby returns the party's lobby")
	eq(f.on_event("LobbyError", _err("ALREADY_IN_LOBBY"), ), [], "not reopened since the match yet: no LeaveLobby")
	eq(f.tick(1.0), [["send", "CreateLobby", {}]], "asked again")
	f.on_event("LobbyUpdated", LOBBY)
	f.on_event("LobbyUpdated", LOBBY)
	eq(f.on_event("LobbyError", _err("MEMBER_NOT_READY")), [["failed", "Đồng đội chưa sẵn sàng"]], "an error: Home, the lobby kept")
	var g := RankedFlow.new()
	g.keep_lobby = true
	g.start(LOADOUT)
	g.on_event("LobbyUpdated", LOBBY)
	g.on_event("LobbyUpdated", LOBBY)
	g.on_event("QueueStarted", {})
	eq(g.cancel(), [["send", "CancelQueue", {}]], "the host cancels the queue")
	eq(g.on_event("QueueCancelled", {"reason": "cancelled"}), [["cancelled"]], "back Home in the party")


func test_party_member_searches_at_once() -> void:
	var f := RankedFlow.new()
	eq(f.start_member(), [["searching"]], "the host's queue is running")
	check(f.busy(), "searching")
	eq(f.on_event("QueueCancelled", {"reason": "cancelled"}), [["failed", RankedFlow.QUEUE_ENDED]], "the host cancelled: Home, still in the party")
	var g := RankedFlow.new()
	g.start_member()
	eq(g.cancel(), [["send", "LeaveLobby", {}], ["cancelled"]], "the member's cancel leaves the lobby")
	var h := RankedFlow.new()
	h.start_member()
	var found := {"roomId": "r", "matchId": "m", "teams": []}
	eq(h.on_event("MatchFound", found), [["found", found]], "MatchFound")
	eq(h.on_event("MatchStarted", {"roomId": "r"}), [["started", {"roomId": "r"}]], "the match")
