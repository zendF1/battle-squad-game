extends "res://tests/test_case.gd"
## PlayerState's gems (locked + unlocked), badge, chests (GET /chests, POST /chests/open) and
## mailbox (GET /mail, POST /mail/read, /mail/claim, /mail/claim-all, MailNew) against a fake REST
## client, with answers shaped like the contract (spec 4, 6, 8a).

const PlayerStateScript := preload("res://autoload/player_state.gd")


class FakeApi:
	extends RefCounted
	var calls: Array = [] # [method, path, body]
	var answers := {}

	func get_json(path: String) -> Dictionary:
		calls.append(["GET", path, null])
		if answers.has(path):
			return answers[path]
		match path:
			"/player/profile":
				return _ok({"playerId": "", "coin": 777, "gem": 5, "gemUnlocked": 40})
		return _ok({})

	func post_json(path: String, body: Variant = {}) -> Dictionary:
		calls.append(["POST", path, body])
		return answers.get(path, _ok(null))

	func posts() -> Array:
		return calls.filter(func(c): return c[0] == "POST").map(func(c): return [c[1], c[2]])

	func gets() -> Array:
		return calls.filter(func(c): return c[0] == "GET").map(func(c): return c[1])

	static func _ok(data: Variant) -> Dictionary:
		return {"ok": true, "status": 200, "code": "", "message": "", "data": data}

	static func fail(status: int, code: String) -> Dictionary:
		return {"ok": false, "status": status, "code": code, "message": code, "data": null}


func _state(api: FakeApi):
	var s = PlayerStateScript.new()
	s.api = api
	s.profile = {"playerId": "", "coin": 100, "gem": 30, "gemUnlocked": 12, "rankBadge": "dai_uy", "rankBadgeSeason": "s1"}
	return s


func test_gems_and_badge() -> void:
	var s = _state(FakeApi.new())
	eq([s.gem_locked(), s.gem_unlocked(), s.gem()], [30, 12, 42], "locked, unlocked, what can be paid")
	eq(s.rank_badge(), "dai_uy", "the profile's badge")
	s.profile.erase("gemUnlocked")
	eq(s.gem_unlocked(), 0, "an older server: no unlocked gem")
	s.profile.erase("rankBadge")
	eq(s.rank_badge(), "", "no badge")
	s.free()


func test_one_gem_balance_with_both_gems_waits_for_the_refresh() -> void:
	var api := FakeApi.new()
	api.answers["/player/equipment/sell"] = FakeApi._ok({"currency": "gem", "amount": 7, "balance": 99})
	var s = _state(api)
	s.equipment = []
	s.equipment_stale = false
	var seen := []
	s.changed.connect(func(): seen.append([s.gem_locked(), s.gem_unlocked()]))
	await s.sell_equipment("e1")
	check(not seen.has([99, 12]), "a gem balance is never put on the locked gem while unlocked gem is held")
	s.free()


func test_chests_load_and_open() -> void:
	var api := FakeApi.new()
	api.answers["/chests"] = FakeApi._ok({"chests": [{"chestId": "stone_chest", "quantity": 5}]})
	api.answers["/chests/open"] = FakeApi._ok({"chestId": "stone_chest", "opened": 2,
		"stones": [{"level": 5, "qty": 1}, {"level": 7, "qty": 1}], "equipment": []})
	var s = _state(api)
	await s.load_chests()
	eq(s.chests, [{"chestId": "stone_chest", "quantity": 5, "name": "Rương đá"}], "owned chests")
	var res: Dictionary = await s.open_chest("stone_chest", 2)
	check(res.ok, "opened")
	eq(api.posts()[0], ["/chests/open", {"chestId": "stone_chest", "count": 2}], "the request")
	eq(s.chest_busy, "", "not busy afterwards")
	check(api.gets().count("/chests") >= 2 and api.gets().has("/player/stones"), "chests and stones reload")
	s.free()


func test_chest_open_refused() -> void:
	var api := FakeApi.new()
	api.answers["/chests/open"] = FakeApi.fail(409, "CHEST_NOT_ENOUGH")
	var s = _state(api)
	var res: Dictionary = await s.open_chest("stone_chest", 10)
	eq(res.code, "CHEST_NOT_ENOUGH", "the refusal")
	check(api.gets().has("/chests"), "the chests reload whatever the answer")
	s.free()


const MAIL_ROW := {"mailId": "m1", "kind": "season_reward", "title": "Thưởng Mùa 1", "body": "",
	"meta": {"seasonId": "s1", "seasonName": "Mùa 1", "grade": "trung_si", "division": 2, "rankPos": 57, "rankPoints": 1080},
	"rewards": {"coin": 5000, "gem": 20, "items": [{"kind": "chest", "id": "stone_chest", "qty": 2, "name": "Rương đá"}]},
	"createdAt": "2026-11-13T00:05:00Z", "expiresAt": null, "readAt": null, "claimedAt": null}


func test_mail_claim() -> void:
	var api := FakeApi.new()
	api.answers["/mail"] = FakeApi._ok({"mails": [MAIL_ROW], "unclaimedCount": 1})
	var claimed := MAIL_ROW.duplicate(true)
	claimed["claimedAt"] = "2026-11-13T12:00:00Z"
	api.answers["/mail/claim"] = FakeApi._ok({"mail": claimed, "granted": MAIL_ROW["rewards"],
		"wallet": {"coin": 5100, "gem": 50, "gemUnlocked": 12}})
	var s = _state(api)
	await s.load_mail()
	eq(s.my_mail().size(), 1, "one mail")
	eq([s.mail_unclaimed(), s.mail_attention()], [1, 1], "one to claim")
	api.answers["/mail"] = FakeApi._ok({"mails": [claimed], "unclaimedCount": 0})
	var seen := []
	s.changed.connect(func(): seen.append([s.coin(), s.gem_locked(), s.gem_unlocked()]))
	var res: Dictionary = await s.claim_mail("m1")
	check(res.ok, "claimed")
	eq(api.posts()[0], ["/mail/claim", {"mailId": "m1"}], "the request")
	check(not seen.is_empty() and seen[0] == [5100, 50, 12], "the answer's wallet at once: %s" % str(seen))
	check(api.gets().has("/player/profile"), "then the profile refreshes")
	eq(s.mail_unclaimed(), 0, "nothing left to claim")
	check(s.chests_stale or api.gets().has("/chests"), "the chests are out of date")
	s.free()


func test_mail_read_claim_all_and_errors() -> void:
	var api := FakeApi.new()
	var second := MAIL_ROW.duplicate(true)
	second["mailId"] = "m2"
	api.answers["/mail"] = FakeApi._ok({"mails": [MAIL_ROW, second], "unclaimedCount": 2})
	var s = _state(api)
	await s.load_mail()
	await s.mark_mail_read("m1")
	eq(api.posts()[0], ["/mail/read", {"mailId": "m1"}], "read posted")
	check(s.my_mail()[0]["readAt"] != "" or s.my_mail()[1]["readAt"] != "", "marked read at once")
	api.answers["/mail/claim-all"] = FakeApi._ok({"claimed": ["m1", "m2"], "granted": {"coin": 10000}, "wallet": {"coin": 10100}})
	api.answers["/mail"] = FakeApi.fail(500, "INTERNAL") # the reload fails: the answer stays
	var coins := []
	s.changed.connect(func(): coins.append(s.coin()))
	var res: Dictionary = await s.claim_all_mail()
	check(res.ok, "claimed all")
	eq(s.mail_unclaimed(), 0, "all claimed at once")
	check(not coins.is_empty() and coins[0] == 10100, "the wallet at once: %s" % str(coins))
	api.answers["/mail/claim"] = FakeApi.fail(404, "MAIL_NOT_FOUND")
	await s.claim_mail("m2")
	eq(s.my_mail().map(func(m): return m["mailId"]), ["m1"], "not found: off the list")
	api.answers["/mail"] = FakeApi.fail(404, "NOT_FOUND")
	await s.load_mail()
	check(not s.mail_available, "a server without a mailbox")
	s.free()


func test_mail_new_reloads() -> void:
	var api := FakeApi.new()
	api.answers["/mail"] = FakeApi._ok({"mails": [MAIL_ROW], "unclaimedCount": 1})
	var s = _state(api)
	s.on_socket_event("MailNew", {"unclaimedCount": 1})
	check(api.gets().has("/mail"), "MailNew loads the mailbox")
	s.on_socket_event("ChatMessage", {})
	eq(api.gets().filter(func(g): return g == "/mail").size(), 1, "other events do not")
	s.free()

func test_gem_answers_carry_both_gems() -> void:
	var api := FakeApi.new()
	api.answers["/shop/stones/buy"] = FakeApi._ok({"stoneLevel": 5, "quantity": 1, "currency": "gem", "balance": 4, "gemUnlocked": 3, "replay": false})
	var s = _state(api)
	var seen := []
	s.changed.connect(func(): seen.append([s.gem_locked(), s.gem_unlocked()]))
	await s.buy_stones(5, 1)
	check(seen.has([4, 3]), "stone buy: balance is the locked gem left, gemUnlocked next to it (%s)" % str(seen))
	s.free()


func test_sell_and_milestone_and_upgrade_gems() -> void:
	var api := FakeApi.new()
	api.answers["/player/equipment/sell"] = FakeApi._ok({"currency": "gem", "amount": 7, "balance": 37, "gemUnlocked": 12, "stones": []})
	api.answers["/milestones/claim"] = FakeApi._ok({"coin": 100, "gem": 60, "gemUnlocked": 12, "rewards": {"gem": 23}})
	api.answers["/player/equipment/upgrade"] = FakeApi._ok({"success": true, "newLevel": 6, "careful": true, "gemSpent": 20,
		"gemBalance": 40, "gemUnlocked": 0})
	var s = _state(api)
	s.equipment = []
	s.equipment_stale = false
	var seen := []
	s.changed.connect(func(): seen.append([s.gem_locked(), s.gem_unlocked()]))
	await s.sell_equipment("e1")
	check(seen.has([37, 12]), "sell: both gems (%s)" % str(seen))
	seen.clear()
	await s.claim_milestone("ms_grade_ha_si")
	check(seen.has([60, 12]), "milestone claim: gem and gemUnlocked (%s)" % str(seen))
	seen.clear()
	s.profile["gemUnlocked"] = 30
	s.stones = {5: 3}
	s.stones_stale = false
	await s.upgrade("e1", [5], true)
	check(seen.has([40, 0]), "careful upgrade: gemBalance and gemUnlocked (%s)" % str(seen))
	s.free()


func test_chest_open_takes_remaining() -> void:
	var api := FakeApi.new()
	api.answers["/chests"] = FakeApi._ok({"chests": [{"chestId": "stone_chest", "quantity": 12}]})
	var s = _state(api)
	await s.load_chests()
	api.answers["/chests/open"] = FakeApi._ok({"chestId": "stone_chest", "opened": 10, "stones": [{"level": 5, "qty": 10}],
		"equipment": [], "remaining": 2})
	api.answers["/chests"] = FakeApi.fail(500, "INTERNAL") # the reload fails: the answer's count stays
	await s.open_chest("stone_chest", 10)
	eq(s.chests.map(func(c): return c["quantity"]), [2], "the answer's remaining at once")
	s.free()
