extends "res://tests/test_case.gd"
## The client side of the server's security / settlement fixes (server
## docs/contracts/security-settlement.md): MatchEnded rewardSettlementStatus on both result
## models, the pending reward watch, QuickPlay from a lobby, the new room / lobby refusals in
## Vietnamese and LOBBY_NOT_FOUND as a closed lobby.

const ResultModel := preload("res://match/result_model.gd")
const BossResultModel := preload("res://match/boss/boss_result_model.gd")
const BossFixture := preload("res://tests/boss_fixture.gd")
const RewardWatch := preload("res://autoload/reward_watch_model.gd")
const QuickPlay := preload("res://screens/quick_play.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const PartyModel := preload("res://screens/home/party_model.gd")
const RankedFlow := preload("res://screens/ranked/ranked_flow.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const PlayerStateScript := preload("res://autoload/player_state.gd")

const HOST := {"playerId": "me", "displayName": "Tôi", "characterId": "rookie", "ready": true}
const MATE := {"playerId": "p2", "displayName": "Bạn", "characterId": "tanko", "ready": false}
const PLAYERS := {
	"me": {"playerId": "me", "displayName": "Tôi", "teamId": 1, "characterId": "rookie"},
	"boss_steel_robot": {"playerId": "boss_steel_robot", "teamId": 2, "role": "boss", "bossId": "steel_robot"}}


static func _err(code: String, message: String = "") -> Dictionary:
	return {"error": {"code": code, "message": message if message != "" else code, "correlationId": "ws-error"}}


static func _lobby(members: Array, host: String = "me") -> Dictionary:
	return {"lobbyId": "l1", "hostPlayerId": host, "status": "preparing", "members": members}


func test_settlement_status() -> void:
	eq(ResultModel.settlement_of({"rewardSettlementStatus": "pending"}), ResultModel.PENDING, "pending")
	eq(ResultModel.settlement_of({"rewardSettlementStatus": "failed"}), ResultModel.FAILED, "failed")
	eq(ResultModel.settlement_of({"rewardSettlementStatus": "completed"}), ResultModel.COMPLETED, "completed")
	eq(ResultModel.settlement_of({}), ResultModel.COMPLETED, "an older server: completed")
	eq(ResultModel.settlement_of({"rewardSettlementStatus": "weird"}), ResultModel.COMPLETED, "unknown: completed")
	eq(ResultModel.settlement_of(null), ResultModel.COMPLETED, "no payload")


func test_pending_rewards_are_on_their_way() -> void:
	var r := ResultModel.reward(null, "pvp_1v1", ResultModel.PENDING)
	check(not r["ok"] and r["pending"], "null while pending: on its way, not granted yet")
	eq([r["exp"], r["coin"], r["empty"]], [0, 0, false], "no +0, and the card stays")
	eq(ResultModel.reward_tiles(r), [], "no tiles")
	eq(ResultModel.level_ups(r, {"level": 3, "exp": 0}, "rookie", "R"), [], "no level popup")
	var failed := ResultModel.reward(null, "pvp_1v1", ResultModel.FAILED)
	check(not failed["ok"] and not failed["pending"], "failed: not granted")
	check(not ResultModel.reward(null, "pvp_1v1")["pending"], "no status, null: not granted")
	var sent := ResultModel.reward({"expGained": 40, "coinGained": 25}, "pvp_1v1", ResultModel.PENDING)
	check(sent["ok"] and not sent["pending"], "rewards present: shown whatever the status")
	eq([sent["exp"], sent["coin"]], [40, 25], "as sent")
	check(ResultModel.reward({"expGained": 1}, "pvp_1v1", ResultModel.FAILED)["ok"], "failed with rewards: shown")
	check(ResultModel.PENDING_TEXT != ResultModel.FAILED_TEXT, "pending is not the failed line")
	check(not ResultModel.PENDING_TEXT.contains("+0"), "no +0")


func test_boss_pending_rewards() -> void:
	BossFixture.take()
	var d := {"winningTeam": 1, "result": "boss_defeated", "rewardSettlementStatus": "pending", "rewards": null,
		"boss": {"bossId": "steel_robot", "bossHp": 0, "bossMaxHp": 12000, "bossDamage": {"me": 12000}}}
	var info := BossResultModel.info(d, PLAYERS, "me", "steel_robot", null)
	check(not info["reward"]["ok"] and info["reward"]["pending"], "on its way")
	eq(info["reward"]["items"], [], "no items")
	d["rewardSettlementStatus"] = "failed"
	check(not BossResultModel.info(d, PLAYERS, "me", "steel_robot", null)["reward"]["pending"], "failed: not granted")
	d.erase("rewardSettlementStatus")
	var granted := BossResultModel.info(d, PLAYERS, "me", "steel_robot", {"expGained": 10, "coinGained": 5})
	check(granted["reward"]["ok"] and not granted["reward"]["pending"], "an older server's rewards")


func test_reward_watch_lands_when_the_profile_moves() -> void:
	var w := RewardWatch.new()
	var before := {"playerId": "me", "coin": 100, "exp": 40, "level": 3, "gem": 1}
	w.start(before, "me")
	check(w.active, "watching")
	eq(w.next_delay(), RewardWatch.FIRST_SEC, "the first check soon")
	eq(w.on_profile(before, "me"), RewardWatch.WAIT, "nothing yet")
	eq(w.next_delay(), RewardWatch.EVERY_SEC, "then every 30 s")
	var gem_only := before.duplicate()
	gem_only["gem"] = 9
	eq(w.on_profile(gem_only, "me"), RewardWatch.WAIT, "only what a match reward moves counts")
	var exp_only := before.duplicate()
	exp_only["exp"] = 70
	eq(w.on_profile(exp_only, "me"), RewardWatch.LANDED, "exp moved: landed")
	check(not w.active, "the watch stops")
	eq(w.on_profile(exp_only, "me"), RewardWatch.GAVE_UP, "nothing after")


func test_reward_watch_gives_up() -> void:
	var w := RewardWatch.new()
	var p := {"playerId": "me", "coin": 100, "exp": 40, "level": 3}
	w.start(p, "me")
	var out := []
	for i in RewardWatch.MAX_CHECKS:
		out.append(w.on_profile(p, "me"))
	eq(out.count(RewardWatch.WAIT), RewardWatch.MAX_CHECKS - 1, "waits")
	eq(out[-1], RewardWatch.GAVE_UP, "the last check gives up")
	check(RewardWatch.FIRST_SEC + RewardWatch.EVERY_SEC * (RewardWatch.MAX_CHECKS - 1) <= 300.0, "a few minutes at most")
	var other := RewardWatch.new()
	other.start(p, "me")
	eq(other.on_profile({"playerId": "you", "coin": 5}, "you"), RewardWatch.GAVE_UP, "another account: stop")
	var unknown := RewardWatch.new()
	unknown.start({}, "me")
	eq(unknown.on_profile(p, "me"), RewardWatch.WAIT, "no cached profile: the first answer is the baseline")
	var moved := p.duplicate()
	moved["coin"] = 160
	eq(unknown.on_profile(moved, "me"), RewardWatch.LANDED, "then a change lands")
	eq(RewardWatch.snapshot({"playerId": "x", "coin": 1}, "me"), {}, "another account's profile")


class FakeApi:
	extends RefCounted
	var calls: Array = []

	func get_json(path: String) -> Dictionary:
		calls.append(path)
		return {"ok": true, "status": 200, "code": "", "message": "", "data": {}}


func test_reload_after_reward() -> void:
	var api := FakeApi.new()
	var s = PlayerStateScript.new()
	s.api = api
	s.characters_stale = false
	s.stones_stale = false
	s.chests_stale = false
	var dirty := []
	s.assets_dirty.connect(func(): dirty.append(true))
	s._reload_after_reward()
	check(s.characters_stale and s.stones_stale and s.chests_stale, "characters, stones and chests reload")
	eq(dirty.size(), 1, "the tabs reload the bag")
	for path in ["/rank/me", "/missions/daily"]:
		check(api.calls.has(path), "reloads %s" % path)
	check(not s.reward_watching(), "no watch without a pending reward")
	s.free()


func test_quick_play_from_a_lobby() -> void:
	eq(QuickPlay.before_request(false, false), QuickPlay.SEND, "no lobby: at once")
	eq(QuickPlay.before_request(true, false), QuickPlay.LEAVE_FIRST, "my lobby alone: leave it first")
	eq(QuickPlay.before_request(true, true), QuickPlay.IN_PARTY, "with a teammate: not alone")
	check(QuickPlay.PARTY_TEXT.contains("tổ đội"), "says why")
	var busy := "leave current room or lobby first"
	eq(QuickPlay.on_refusal("ROOM_CREATE_FAILED", busy, false), QuickPlay.RETRY, "still somewhere: leave and ask again")
	eq(QuickPlay.on_refusal("ROOM_CREATE_FAILED", busy, true), QuickPlay.FAIL, "only once")
	eq(QuickPlay.on_refusal("ROOM_JOIN_FAILED", "player already belongs to a room", false), QuickPlay.RETRY, "an old room still held")
	eq(QuickPlay.on_refusal("ROOM_REQUIRED", "You must join a room first", true), QuickPlay.IGNORE, "the retry's Leave answer")
	eq(QuickPlay.on_refusal("ROOM_REQUIRED", "You must join a room first", false), QuickPlay.FAIL, "not after a retry: an answer")
	eq(QuickPlay.on_refusal("LOADOUT_INVALID", "You do not own item: medkit", false), QuickPlay.FAIL, "other refusals end it")
	eq(QuickPlay.on_refusal("ROOM_CREATE_FAILED", "something else", false), QuickPlay.FAIL, "another create failure")
	eq(QuickPlay.error_message(_err("ROOM_CREATE_FAILED", busy)), busy, "the message")


func test_room_refusals_in_vietnamese() -> void:
	var cases := {
		"leave current room or lobby first": "ROOM_CREATE_FAILED",
		"room is closed": "ROOM_JOIN_FAILED",
		"player already belongs to a room": "ROOM_JOIN_FAILED",
		"leave lobby before joining a custom room": "ROOM_JOIN_FAILED",
		"client already belongs to a room": "ROOM_JOIN_FAILED",
	}
	for message in cases:
		var text := ErrorText.room_error(_err(cases[message], message))
		check(text != message and not text.is_empty(), "%s in Vietnamese: %s" % [message, text])
	eq(ErrorText.room_error(_err("ROOM_CREATE_FAILED", "leave current room or lobby first")), "Bạn vẫn đang ở trong một trận hoặc tổ đội", "busy")
	eq(ErrorText.room_error(_err("ROOM_CREATE_FAILED", "new reason")), "Không tạo được trận, hãy thử lại", "the code's text")
	for code in ["ROOM_CREATE_FAILED", "ROOM_JOIN_FAILED", "ROOM_NOT_FOUND", "ROOM_REQUIRED"]:
		check(ErrorText.ROOM.has(code), code)


func test_lobby_refusals_in_vietnamese() -> void:
	eq(ErrorText.lobby_error(_err("LOBBY_NOT_FOUND", "Lobby is closed")), "Tổ đội đã giải tán", "closed")
	eq(ErrorText.lobby_error(_err("PLAYER_BUSY", "The player is busy")), "Người chơi này đang bận", "the invitee is busy")
	eq(ErrorText.lobby_error(_err("PLAYER_BUSY", "player already belongs to a room")), "Bạn vẫn đang ở trong một trận khác", "I am busy")
	eq(ErrorText.lobby_error(_err("PLAYER_BUSY", "player already belongs to a lobby")), "Bạn vẫn đang ở trong một tổ đội khác", "in a lobby")
	eq(ErrorText.lobby_error(_err("LOBBY_CREATE_FAILED", "player already belongs to another lobby")), "Bạn vẫn đang ở trong một tổ đội khác", "create refused")


func test_party_lobby_not_found_is_a_closed_lobby() -> void:
	var p := PartyModel.new()
	p.me = "p2"
	p.on_event("LobbyUpdated", _lobby([HOST, MATE]), 0.0)
	p.set_ready(true, 1.0)
	eq(p.on_event("LobbyError", _err("LOBBY_NOT_FOUND", "Lobby not found"), 1.1), [["toast", "Tổ đội đã giải tán"], ["changed"]], "forgotten, told")
	check(not p.in_lobby(), "no lobby")
	var late := PartyModel.new()
	late.me = "p2"
	late.on_event("LobbyUpdated", _lobby([HOST, MATE]), 0.0)
	eq(late.on_event("LobbyError", _err("LOBBY_NOT_FOUND"), 60.0).size(), 2, "even long after a request")
	check(not late.in_lobby(), "forgotten")
	var accept := PartyModel.new()
	accept.me = "me"
	accept.on_event("LobbyUpdated", _lobby([HOST]), 0.0)
	accept.on_event("LobbyInvite", {"inviteId": "i1", "lobbyId": "l9", "from": {"playerId": "p9"}}, 0.0)
	accept.respond(true, 1.0)
	eq(accept.on_event("LobbyError", _err("LOBBY_NOT_FOUND", "Lobby is closed"), 1.1), [["toast", "Tổ đội đã giải tán"]], "the inviter's lobby closed")
	check(accept.in_lobby(), "my own lobby stays")
	var create := PartyModel.new()
	create.me = "me"
	create.invite("p2", 0.0)
	eq(create.on_event("LobbyError", _err("LOBBY_NOT_FOUND", "Lobby is closed"), 0.1), [["send", "CreateLobby", {}]], "my old lobby closing: ask again")


func test_ranked_lobby_not_found() -> void:
	var f := RankedFlow.new()
	f.start({"characterId": "rookie", "items": []})
	eq(f.on_event("LobbyError", _err("LOBBY_NOT_FOUND", "Lobby is closed")), [], "the old lobby closing: wait")
	eq(f.tick(RankedFlow.RETRY_SEC + 0.1).map(func(a): return a[1]), ["CreateLobby"], "then ask again")
	var g := RankedFlow.new()
	g.start({"characterId": "rookie", "items": []})
	g.on_event("LobbyUpdated", {"lobbyId": "l1"})
	var a := g.on_event("LobbyError", _err("LOBBY_NOT_FOUND"))
	eq(a.map(func(x): return x[0]), ["failed"], "closed under the queue: no LeaveLobby")
	eq(a[0][1], "Tổ đội đã giải tán", "says so")


func test_pending_glyphs() -> void:
	check(GlyphIcon.KINDS.has("hourglass"), "the hourglass")
	check(GlyphIcon.KINDS.has("check"), "the tick")
