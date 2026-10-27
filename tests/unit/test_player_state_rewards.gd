extends "res://tests/test_case.gd"
## PlayerState's gems (locked + unlocked), badge, chests (GET /chests, POST /chests/open) and
## season rewards (GET /rank/season-rewards, POST /rank/season-rewards/claim) against a fake REST
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


func test_season_rewards_claim() -> void:
	var api := FakeApi.new()
	var row := {"seasonId": "s1", "seasonName": "Mùa 1", "grade": "trung_si", "division": 2, "rankPos": 57, "rankPoints": 1080,
		"coin": 5000, "gem": 20, "items": [{"kind": "chest", "id": "stone_chest", "qty": 2, "name": "Rương đá"}]}
	api.answers["/rank/season-rewards"] = FakeApi._ok({"rewards": [row]})
	var claimed := row.duplicate(true)
	claimed["wallet"] = {"coin": 5100, "gem": 50, "gemUnlocked": 12}
	api.answers["/rank/season-rewards/claim"] = FakeApi._ok(claimed)
	var s = _state(api)
	await s.load_season_rewards()
	eq(s.my_season_rewards().size(), 1, "one to claim")
	api.answers["/rank/season-rewards"] = FakeApi._ok({"rewards": []})
	var seen := []
	s.changed.connect(func(): seen.append([s.coin(), s.gem_locked(), s.gem_unlocked()]))
	var res: Dictionary = await s.claim_season_reward("s1")
	check(res.ok, "claimed")
	eq(api.posts()[0], ["/rank/season-rewards/claim", {"seasonId": "s1"}], "the request")
	check(not seen.is_empty() and seen[0] == [5100, 50, 12], "the answer's wallet at once: %s" % str(seen))
	check(api.gets().has("/player/profile"), "then the profile refreshes")
	eq(s.my_season_rewards(), [], "gone from the list")
	check(api.gets().has("/chests") or s.chests_stale, "the chests are out of date")
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


func test_chest_open_takes_remaining_and_season_not_found() -> void:
	var api := FakeApi.new()
	api.answers["/chests"] = FakeApi._ok({"chests": [{"chestId": "stone_chest", "quantity": 12}]})
	var s = _state(api)
	await s.load_chests()
	api.answers["/chests/open"] = FakeApi._ok({"chestId": "stone_chest", "opened": 10, "stones": [{"level": 5, "qty": 10}],
		"equipment": [], "remaining": 2})
	api.answers["/chests"] = FakeApi.fail(500, "INTERNAL") # the reload fails: the answer's count stays
	await s.open_chest("stone_chest", 10)
	eq(s.chests.map(func(c): return c["quantity"]), [2], "the answer's remaining at once")
	api.answers["/rank/season-rewards"] = FakeApi._ok({"rewards": [{"seasonId": "s9", "grade": "ha_si", "division": 1}]})
	await s.load_season_rewards()
	api.answers["/rank/season-rewards/claim"] = FakeApi.fail(404, "SEASON_REWARD_NOT_FOUND")
	api.answers["/rank/season-rewards"] = FakeApi.fail(500, "INTERNAL")
	await s.claim_season_reward("s9")
	eq(s.my_season_rewards(), [], "not found: nothing to claim, off the list")
	s.free()
