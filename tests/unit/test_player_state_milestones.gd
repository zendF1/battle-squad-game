extends "res://tests/test_case.gd"
## PlayerState milestones against a fake REST client: the list and the badge count, the "new
## milestone" signal, claim / claim-all requests and what they update, the busy gate.

const PlayerStateScript := preload("res://autoload/player_state.gd")


class FakeApi:
	extends RefCounted
	var calls: Array = [] # [method, path, body]
	var answers := {}
	var summary := 2
	var list := {"claimableCount": 2, "tracks": [{"track": "combat", "nodes": [
		{"id": "m10", "track": "combat", "target": "matches", "required": 10, "progress": 12, "state": "claimable", "rewards": {"coin": 1000}},
		{"id": "w5", "track": "combat", "target": "wins", "required": 5, "progress": 6, "state": "claimable",
			"rewards": {"coin": 1500, "items": [{"kind": "stone", "level": 7, "qty": 1}]}},
	]}]}

	func get_json(path: String) -> Dictionary:
		calls.append(["GET", path, null])
		match path:
			"/player/profile":
				return _ok({"playerId": "", "coin": 777, "gem": 5})
			"/milestones":
				return answers.get(path, _ok(list))
			"/milestones/summary":
				return _ok({"claimableCount": summary})
		return _ok({})

	func post_json(path: String, body: Variant = {}) -> Dictionary:
		calls.append(["POST", path, body])
		return answers.get(path, _ok(null))

	func posts() -> Array:
		return calls.filter(func(c): return c[0] == "POST")

	func gets() -> Array:
		return calls.filter(func(c): return c[0] == "GET").map(func(c): return c[1])

	static func _ok(data: Variant) -> Dictionary:
		return {"ok": true, "status": 200, "code": "", "message": "", "data": data}

	static func fail(status: int, code: String) -> Dictionary:
		return {"ok": false, "status": status, "code": code, "message": code, "data": null}


func _state(api: FakeApi):
	var s = PlayerStateScript.new()
	s.api = api
	s.profile = {"playerId": "", "coin": 100, "gem": 5}
	s.stones = {7: 2}
	s.stones_stale = false
	return s


func test_list_load_and_count() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	var seen := []
	s.milestones_changed.connect(func(): seen.append(s.milestones_loading))
	s.need_milestones()
	check(s.milestones != null, "loaded")
	eq(s.milestone_count, 2, "count from the list")
	eq(s.milestones_version, 1, "version")
	eq(seen, [true, false], "loading, then loaded")
	check(not s.take_new_milestones(), "the first count of the session is not new")
	api.calls.clear()
	s.need_milestones()
	eq(api.gets(), [], "a fresh copy is not fetched again")
	api.answers["/milestones"] = FakeApi.fail(0, "")
	s.load_milestones()
	check(s.milestones_error != "", "error kept")
	check(s.milestones != null, "the last list stays")
	s.free()


func test_summary_and_new_milestones() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	s.load_milestone_summary()
	eq(s.milestone_count, 2, "summary count")
	check(not s.take_new_milestones(), "first count")
	api.summary = 3
	s.need_milestones()
	s.load_milestone_summary()
	check(s.milestones_stale, "a count unlike the list's makes it stale")
	check(s.take_new_milestones(), "rose: new")
	check(not s.take_new_milestones(), "only once")
	api.summary = 1
	s.load_milestone_summary()
	check(not s.take_new_milestones(), "fell: not new")
	api.summary = 2
	s.load_milestone_summary()
	check(s.take_new_milestones(), "rose past the lower count")
	s.free()


func test_equipment_action_refreshes_the_badge() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	s.equipment = []
	s.equipment_stale = false
	s.milestones_stale = false
	await s.upgrade("e1", [{"stoneLevel": 7, "quantity": 1}])
	check(api.gets().has("/milestones/summary"), "summary after an upgrade")
	check(s.milestones_stale, "the list is stale")
	s.free()


func test_claim_updates_wallet_stones_and_list() -> void:
	var api := FakeApi.new()
	api.answers["/milestones/claim"] = FakeApi._ok({"claimed": ["w5"], "rewards": {"coin": 1500, "gem": 0,
		"items": [{"kind": "stone", "level": 7, "qty": 1}]}, "coin": 1600, "gem": 5,
		"stones": [{"stoneLevel": 7, "quantity": 3}], "claimableCount": 1})
	var s = _state(api)
	s.need_milestones()
	api.calls.clear()
	var res: Dictionary = await s.claim_milestone("w5")
	check(res.ok, "claimed")
	eq(api.posts(), [["POST", "/milestones/claim", {"id": "w5"}]], "request")
	eq(s.coin(), 777, "the wallet's refresh wins after the answer's balance")
	eq(s.stones, {7: 3}, "stones from the answer")
	eq(s.milestone_count, 2, "count from the reloaded list")
	check(api.gets().has("/milestones") and api.gets().has("/player/profile"), "list and wallet reload")
	eq(s.milestone_busy, "", "not busy afterwards")
	s.free()


func test_claim_answer_balance_shown_at_once() -> void:
	var api := FakeApi.new()
	api.answers["/milestones/claim"] = FakeApi._ok({"claimed": ["m10"], "rewards": {"coin": 1000}, "coin": 1100, "gem": 5,
		"stones": [], "claimableCount": 1})
	var s = _state(api)
	var coins := []
	s.changed.connect(func(): coins.append(s.coin()))
	await s.claim_milestone("m10")
	check(coins.size() > 0 and coins[0] == 1100, "the answer's coin shown first: %s" % str(coins))
	eq(s.stones, {}, "an empty stones answer empties the stones")
	s.free()


func test_claim_refusals_and_busy() -> void:
	var api := FakeApi.new()
	api.answers["/milestones/claim"] = FakeApi.fail(409, "MILESTONE_ALREADY_CLAIMED")
	var s = _state(api)
	var res: Dictionary = await s.claim_milestone("m10")
	eq(res.code, "MILESTONE_ALREADY_CLAIMED", "refused")
	check(api.gets().has("/milestones"), "the list reloads after a refusal")
	eq(s.stones, {7: 2}, "stones unchanged")
	s.milestone_busy = "all"
	api.calls.clear()
	eq((await s.claim_milestone("m10")).code, "BUSY", "one claim at a time")
	eq((await s.claim_all_milestones()).code, "BUSY", "claim-all too")
	eq(api.posts(), [], "nothing sent")
	s.milestone_busy = ""
	await s.claim_all_milestones()
	eq(api.posts()[0][1], "/milestones/claim-all", "claim-all path")
	s.free()
