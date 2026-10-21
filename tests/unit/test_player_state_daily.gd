extends "res://tests/test_case.gd"
## PlayerState daily missions against a fake REST client: the load and the claimable count, a
## mission claim taking the answer's state, a chest claim refreshing the wallet / stones /
## inventory, a refusal reloading the list, the busy gate.

const PlayerStateScript := preload("res://autoload/player_state.gd")


static func _state_data(activity: int, play_state: String, chest_state: String) -> Dictionary:
	return {"day": "2026-10-21", "dayResetAt": "2026-10-21T17:00:00Z", "week": "2026-W43", "weekResetAt": "2026-10-26T17:00:00Z",
		"activity": activity, "weeklyActivity": activity,
		"missions": [{"id": "daily_play_3", "title": "Chơi 3 trận đấu", "target": "play_match", "required": 3, "progress": 3,
			"activity": 20, "goto": "play", "state": play_state}],
		"chests": [{"id": "chest_d20", "track": "daily", "threshold": 20, "state": chest_state, "rewards": {"coin": 300}}],
		"weekly": []}


class FakeApi:
	extends RefCounted
	var calls: Array = []
	var answers := {}
	var daily: Dictionary

	func get_json(path: String) -> Dictionary:
		calls.append(["GET", path, null])
		match path:
			"/player/profile":
				return _ok({"playerId": "", "coin": 999, "gem": 5})
			"/missions/daily":
				return answers.get(path, _ok(daily))
		return _ok([])

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
	return s


func test_load_and_count() -> void:
	var api := FakeApi.new()
	api.daily = _state_data(0, "claimable", "locked")
	var s = _state(api)
	var seen := []
	s.daily_changed.connect(func(): seen.append(s.daily_loading))
	eq(s.daily_claimable(), 0, "nothing before the load")
	s.load_daily()
	check(s.daily != null, "loaded")
	eq(s.daily_claimable(), 1, "one mission to claim")
	eq(seen, [true, false], "loading, then loaded")
	api.answers["/missions/daily"] = FakeApi.fail(0, "")
	s.load_daily()
	eq(s.daily_error, "Không kết nối được server, hãy thử lại", "offline error")
	check(s.daily != null, "the last list stays")


func test_claim_mission_takes_the_state() -> void:
	var api := FakeApi.new()
	api.daily = _state_data(0, "claimable", "locked")
	var s = _state(api)
	s.load_daily()
	api.calls.clear()
	api.answers["/missions/claim"] = FakeApi._ok({"activity": 20, "state": _state_data(20, "claimed", "claimable")})
	var res: Dictionary = await s.claim_mission("daily_play_3")
	check(res.ok, "ok")
	eq(api.posts(), [["POST", "/missions/claim", {"missionId": "daily_play_3"}]], "the request")
	eq(api.gets(), [], "the answer's state is used, no reload")
	eq(s.daily["activity"], 20, "new activity")
	eq(s.daily_claimable(), 1, "the chest is claimable now")
	eq(s.daily_busy, "", "not busy afterwards")


func test_claim_refused_reloads() -> void:
	var api := FakeApi.new()
	api.daily = _state_data(0, "claimable", "locked")
	var s = _state(api)
	s.load_daily()
	api.calls.clear()
	api.answers["/missions/claim"] = FakeApi.fail(409, "MISSION_ALREADY_CLAIMED")
	api.daily = _state_data(20, "claimed", "claimable")
	var res: Dictionary = await s.claim_mission("daily_play_3")
	check(not res.ok, "refused")
	eq(api.gets(), ["/missions/daily"], "the list reloads")
	eq(s.daily["activity"], 20, "the truth from the reload")


func test_claim_chest_refreshes_the_wallet_and_assets() -> void:
	var api := FakeApi.new()
	api.daily = _state_data(20, "claimed", "claimable")
	var s = _state(api)
	s.load_daily()
	api.calls.clear()
	api.answers["/missions/chests/claim"] = FakeApi._ok({"rewards": {"coin": 300, "items": [{"kind": "stone", "level": 1, "qty": 3}]},
		"state": _state_data(20, "claimed", "claimed")})
	var res: Dictionary = await s.claim_chest("chest_d20")
	check(res.ok, "ok")
	eq(api.posts(), [["POST", "/missions/chests/claim", {"chestId": "chest_d20"}]], "the request")
	check(api.gets().has("/player/profile"), "wallet refreshed")
	check(api.gets().has("/player/stones"), "stones reloaded")
	eq(s.profile["coin"], 999, "wallet from the refresh")
	eq(s.daily_claimable(), 0, "nothing left")
	var dirty := []
	s.assets_dirty.connect(func(): dirty.append(true))
	api.answers["/missions/chests/claim"] = FakeApi._ok({"rewards": {"items": [{"kind": "item", "id": "medkit", "qty": 2}]},
		"state": _state_data(20, "claimed", "claimed")})
	await s.claim_chest("chest_d20")
	eq(dirty, [true], "an item reward marks the inventory dirty")


func test_busy_gate() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	s.daily_busy = "other"
	var res: Dictionary = await s.claim_mission("x")
	eq(res.code, "BUSY", "busy")
	eq(api.posts(), [], "nothing sent")
