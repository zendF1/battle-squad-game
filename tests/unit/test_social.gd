extends "res://tests/test_case.gd"
## screens/social/social.gd (Router.social) against a fake API: chat polls with cursors and dedup,
## sending, the guild's id, the friends actions and the guild invite hook; the match chat
## (match/match_chat.gd) over a fake socket.

const Social := preload("res://screens/social/social.gd")
const ChatModel := preload("res://screens/social/chat_model.gd")
const FriendsModel := preload("res://screens/social/friends_model.gd")
const MatchChat := preload("res://match/match_chat.gd")
const Hud := preload("res://match/hud.gd")


## Answers by "METHOD path" (the query left out unless given), records every call.
class FakeApi:
	extends RefCounted
	var answers := {}
	var calls: Array = []

	func _answer(key: String, path: String) -> Dictionary:
		for k in [key + " " + path, key + " " + path.split("?")[0]]:
			if answers.has(k):
				var a = answers[k]
				return a.pop_front() if a is Array else a
		return {"ok": false, "status": 0, "code": "NETWORK_ERROR", "message": "offline", "data": null}

	func get_json(path: String) -> Dictionary:
		calls.append(["GET", path, null])
		return _answer("GET", path)

	func post_json(path: String, body: Variant = {}) -> Dictionary:
		calls.append(["POST", path, body])
		return _answer("POST", path)

	func request(method: int, path: String, body: Variant = null) -> Dictionary:
		var m: String = {HTTPClient.METHOD_DELETE: "DELETE", HTTPClient.METHOD_PUT: "PUT"}.get(method, "?")
		calls.append([m, path, body])
		return _answer(m, path)


class FakeSocket:
	extends RefCounted
	var sent: Array = []

	func send(event: String, data: Variant = {}) -> void:
		sent.append([event, data])


static func ok(data: Variant) -> Dictionary:
	return {"ok": true, "status": 200, "code": "", "message": "", "data": data}


static func fail(status: int, code: String) -> Dictionary:
	return {"ok": false, "status": status, "code": code, "message": code, "data": null}


static func msg(id: int, who: String = "p2", text: String = "hi", channel: String = "world") -> Dictionary:
	return {"id": id, "channel": channel, "scope": channel, "playerId": who, "displayName": "Tên " + who,
		"level": 5, "characterId": "rookie", "text": text, "createdAt": "2026-10-30T00:00:00Z"}


var _old_player := ""


func _social(api: FakeApi) -> Node:
	_old_player = Session.player_id
	Session.player_id = "me"
	var s: Node = Social.new()
	s.api = api
	return s


func _done(s: Node) -> void:
	Session.player_id = _old_player
	s.free()


func test_poll_uses_the_cursor_and_dedupes() -> void:
	var api := FakeApi.new()
	api.answers["GET /chat/world/messages"] = ok({"messages": [msg(1), msg(2)]})
	api.answers["GET /chat/world/messages?after=2"] = ok({"messages": [msg(2), msg(5)]})
	var s := _social(api)
	var changed: Array = []
	s.feed_changed.connect(func(k: String) -> void: changed.append(k))
	s.poll("world")
	eq(api.calls[0][1], "/chat/world/messages", "the first poll: the newest page")
	s.poll("world")
	eq(api.calls.size(), 1, "a timed poll within pollSec of the last: dropped")
	s.poll("world", "", true)
	eq(api.calls[1][1], "/chat/world/messages?after=2", "then after the cursor")
	eq(s.messages("world").map(func(m): return m["id"]), [1, 2, 5], "deduplicated by id")
	eq(changed, ["world", "world"], "each new message told")
	_done(s)


func test_backoff_after_429() -> void:
	var api := FakeApi.new()
	api.answers["GET /chat/world/messages"] = fail(429, "CHAT_RATE_LIMITED")
	var s := _social(api)
	s.poll("world", "", true)
	s.poll("world", "", true)
	eq(api.calls.size(), 1, "even an opening poll waits out the backoff")
	check(s.feed_error("world") == "Gửi chậm lại chút nhé" or s.feed_error("world") != "", "the error kept")
	_done(s)


func test_poll_guild_and_dm_targets() -> void:
	var api := FakeApi.new()
	api.answers["GET /chat/dm/messages?target=Ab%2F1"] = ok({"messages": [msg(3, "Ab/1", "chào", "dm")]})
	api.answers["GET /chat/guild/messages?target=g-1"] = fail(403, "FORBIDDEN")
	var s := _social(api)
	s.set_guild("g-1")
	s.poll("dm", "Ab/1")
	eq(s.messages("dm:Ab/1").size(), 1, "the DM's conversation")
	s.poll("guild", "g-1")
	eq(s.guild_id, "", "a 403 on the guild's chat: no longer a member")
	check(s.feed_error("guild:g-1") != "", "its error kept")
	s.poll("guild", "")
	eq(api.calls.size(), 2, "no guild: no guild poll")
	_done(s)


func test_send() -> void:
	var api := FakeApi.new()
	api.answers["POST /chat/world/messages"] = [ok(msg(9, "me", "xin chào")), fail(429, "CHAT_RATE_LIMITED")]
	var s := _social(api)
	eq(s.send("world", "", "  xin chào "), "", "sent")
	eq(api.calls[0][2], {"text": "xin chào"}, "trimmed, no target for world")
	eq(s.messages("world")[-1]["id"], 9, "my message shows at once")
	eq(s.send("world", "", "lại"), "Gửi chậm lại chút nhé", "rate limited: a short toast")
	var before: int = api.calls.size()
	eq(s.send("world", "", "   "), ChatModel.EMPTY_TEXT, "nothing to send")
	eq(api.calls.size(), before, "not sent")
	var long := "x".repeat(GameData_max() + 1)
	eq(s.send("world", "", long), "Tối đa %d ký tự" % GameData_max(), "the game data's limit")
	_done(s)


static func GameData_max() -> int:
	return load("res://autoload/game_data_model.gd").chat_max_length()


func test_guild_id() -> void:
	var api := FakeApi.new()
	api.answers["GET /guilds/me"] = [ok({"id": "g-7", "name": "Rồng"}), fail(404, "NOT_FOUND")]
	var s := _social(api)
	s.load_guild()
	eq(s.guild_id, "g-7", "my guild")
	s.load_guild()
	eq(api.calls.size(), 1, "asked once")
	s.load_guild(true)
	eq(s.guild_id, "", "404: no guild")
	_done(s)


func test_friends_actions() -> void:
	var api := FakeApi.new()
	var list := {"friends": [{"playerId": "a1", "displayName": "A", "nickname": "", "level": 2, "characterId": ""}],
		"incoming": [{"playerId": "d4", "displayName": "D", "level": 7, "characterId": "tide"}], "outgoing": []}
	api.answers["GET /friends"] = ok(list)
	api.answers["POST /friends/requests"] = [ok({}), fail(409, "FRIEND_CONFLICT")]
	api.answers["POST /friends/requests/d4/accept"] = ok({})
	api.answers["DELETE /friends/a1"] = ok({})
	api.answers["PUT /friends/a1/nickname"] = [ok({}), fail(400, "BAD_REQUEST")]
	var s := _social(api)
	s.need_friends()
	eq(s.relation("a1"), FriendsModel.FRIEND, "loaded")
	s.need_friends()
	eq(api.calls.size(), 1, "loaded once")
	eq(s.request_friend("z9", {"displayName": "Z"}), "", "request sent")
	eq(api.calls[1], ["POST", "/friends/requests", {"playerId": "z9"}], "the body")
	eq(s.request_friend("z9"), "Đã là bạn hoặc đã có lời mời", "a conflict in Vietnamese")
	eq(s.accept_friend("d4"), "", "accepted")
	eq(s.set_nickname("a1", "  Bạn thân "), "", "renamed")
	eq(api.calls.filter(func(c): return c[0] == "PUT")[0][2], {"nickname": "Bạn thân"}, "trimmed")
	eq(s.set_nickname("a1", "x"), "Biệt danh không hợp lệ", "a refused nickname")
	eq(s.remove_friend("a1"), "", "removed")
	_done(s)


func test_guild_invite_hook() -> void:
	var s := _social(FakeApi.new())
	check(not s.can_invite_to_guild("p2"), "no guild page hook: no button")
	var invited: Array = []
	s.set_guild_invite(func(id: String, n: String) -> void: invited.append([id, n]), func(id: String) -> bool: return id != "member")
	check(s.can_invite_to_guild("p2"), "the hook accepts them")
	check(not s.can_invite_to_guild("member"), "already in my guild")
	check(not s.can_invite_to_guild("me"), "never myself")
	s.invite_to_guild("p2", "Hai")
	eq(invited, [["p2", "Hai"]], "the hook called")
	s.set_guild_invite(Callable())
	check(not s.can_invite_to_guild("p2"), "cleared")
	_done(s)


func test_another_account_drops_everything() -> void:
	var api := FakeApi.new()
	api.answers["GET /chat/world/messages"] = ok({"messages": [msg(1)]})
	var s := _social(api)
	s.poll("world")
	s.set_guild("g")
	Session.player_id = "other"
	eq(s.messages("world").size(), 0, "another player's lines gone")
	eq(s.guild_id, "", "and the guild")
	_done(s)


func test_match_chat() -> void:
	var socket := FakeSocket.new()
	var hud: Control = Hud.new()
	hud._ready()
	var chat: Node = MatchChat.new()
	chat.hud = hud
	chat.socket = socket
	chat.me = "me"
	chat.names = func() -> Dictionary: return MatchChat.names_of({"p3": {"displayName": "Rồng"}})
	chat._ready()
	eq(socket.sent, [["ChatHistory", {}]], "the history on entering")
	chat.on_event("ChatHistory", {"messages": [msg(4, "p3", "gl"), msg(2, "me", "hi")]})
	chat.on_event("ChatMessage", msg(4, "p3", "gl"))
	chat.on_event("ChatMessage", {"id": 6, "channel": "match", "playerId": "p3", "text": "gg"})
	var texts: Array = hud.chat_lines().map(func(l): return l["text"])
	eq(texts, ["[Hệ thống] Trận đấu bắt đầu!", "Tên me: hi", "Tên p3: gl", "Rồng: gg"],
		"in id order, once each, a name from the match without one")
	chat.on_event("MatchStateSync", {})
	eq(socket.sent[-1], ["ChatHistory", {"after": 6}], "a reconnect: after the last")
	hud.chat_send.emit("  chơi tiếp ")
	eq(socket.sent[-1], ["ChatSend", {"text": "chơi tiếp"}], "the HUD's text sent, trimmed")
	var n: int = socket.sent.size()
	hud.chat_send.emit("   ")
	eq(socket.sent.size(), n, "nothing to send")
	chat.on_event("ChatError", {"code": "CHAT_RATE_LIMITED"})
	var toasts := hud.get_children().filter(func(c): return c.has_meta("toast"))
	check(not toasts.is_empty() and (toasts[-1].get_child(0) as Label).text == "Gửi chậm lại chút nhé", "a short toast")
	chat.free()
	hud.free()


func test_hud_chat_input() -> void:
	var hud: Control = Hud.new()
	hud._ready()
	check(hud.chat_button != null, "the chat button")
	check(not hud.chat_input_open(), "closed at first")
	hud.toggle_chat_input()
	check(hud.chat_input_open(), "opened")
	eq(hud.chat_input.max_length, 500, "the game data's limit")
	var got: Array = []
	hud.chat_send.connect(func(t: String) -> void: got.append(t))
	hud.chat_input.text = "hello"
	hud._submit_chat()
	eq(got, ["hello"], "sent")
	check(not hud.chat_input_open(), "closed after sending")
	eq(hud.chat_input.text, "", "cleared")
	hud.free()
