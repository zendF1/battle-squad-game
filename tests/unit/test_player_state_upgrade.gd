extends "res://tests/test_case.gd"
## PlayerState stones, buy_stones(), upgrade() and merge_stones() against a fake REST client: the
## requests sent, the idempotency key kept for a retry, the busy gates and what reloads afterwards.

const PlayerStateScript := preload("res://autoload/player_state.gd")
const IdempotencyKeys := preload("res://core/idempotency_keys.gd")


class FakeApi:
	extends RefCounted
	var calls: Array = [] # [method, path, body]
	var answers := {}
	var stones: Variant = [{"stoneLevel": 2, "quantity": 5}]

	func get_json(path: String) -> Dictionary:
		calls.append(["GET", path, null])
		match path:
			"/player/profile":
				return _ok({"playerId": "", "coin": 777, "gem": 5})
			"/player/equipment":
				return _ok([])
			"/player/characters":
				return _ok({"characters": []})
			"/player/stones":
				return answers.get(path, _ok(stones))
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
	s.equipment = []
	s.equipment_stale = false
	s.stones = {2: 5}
	s.stones_stale = false
	s.profile = {"playerId": "", "coin": 100, "gem": 5}
	s.stone_keys = IdempotencyKeys.new() # in memory: never the device's file
	return s


func test_stones_load_and_parse() -> void:
	var api := FakeApi.new()
	api.stones = [{"stoneLevel": 1, "quantity": 3}, {"stoneLevel": 7, "quantity": 1}]
	var s = _state(api)
	s.stones = null
	s.stones_stale = true
	var seen := []
	s.stones_changed.connect(func(): seen.append(s.stones_loading))
	s.need_stones()
	eq(s.stones, {1: 3, 7: 1}, "parsed")
	eq(s.stones_version, 1, "version bumped")
	check(s.stones_ready(), "ready after the load")
	eq(seen, [true, false], "loading, then loaded")
	api.calls.clear()
	s.need_stones()
	eq(api.gets(), [], "a fresh copy is not fetched again")
	s.free()


func test_stones_load_failure() -> void:
	var api := FakeApi.new()
	api.answers["/player/stones"] = FakeApi.fail(0, "")
	var s = _state(api)
	s.stones = null
	s.load_stones()
	eq(s.stones, null, "nothing loaded")
	check(s.stones_error != "", "error shown")
	check(not s.stones_ready(), "not ready")
	api.answers["/player/stones"] = FakeApi._ok({"bad": 1})
	s.load_stones()
	eq(s.stones_error, "Dữ liệu đá nâng cấp không hợp lệ", "malformed answer")
	s.free()


func test_buy_stones_sends_a_key_and_takes_the_balance() -> void:
	var api := FakeApi.new()
	api.answers["/shop/stones/buy"] = FakeApi._ok({"stoneLevel": 3, "quantity": 5, "currency": "coin", "amount": 3500, "balance": 50, "owned": 5, "replay": false})
	var s = _state(api)
	var coins := []
	s.changed.connect(func(): coins.append(s.coin()))
	var res: Dictionary = await s.buy_stones(3, 5)
	check(res.ok, "bought")
	eq(res.replay, false, "a new buy")
	var body: Dictionary = api.posts()[0][2]
	eq([api.posts()[0][1], body["stoneLevel"], body["quantity"]], ["/shop/stones/buy", 3, 5], "request")
	check(str(body.get("idempotencyKey", "")) != "", "with an idempotency key")
	eq(coins[0], 50, "the answer's balance at once")
	check(api.gets().has("/player/profile"), "the wallet refreshes")
	check(api.gets().has("/player/stones"), "the stones reload")
	eq(s.busy_id, "", "not busy afterwards")
	check(not s.stone_keys.has_key(s.key_target("stone_3_x5")), "a definite answer settles the key")
	s.free()


func test_buy_stones_retry_reuses_the_key_and_reports_the_replay() -> void:
	var api := FakeApi.new()
	api.answers["/shop/stones/buy"] = FakeApi.fail(0, "")
	var s = _state(api)
	var res: Dictionary = await s.buy_stones(7, 2)
	check(not res.ok, "no answer")
	var first: String = api.posts()[0][2]["idempotencyKey"]
	check(s.stone_keys.has_key(s.key_target("stone_7_x2")), "the key is kept for the retry")
	check(api.gets().has("/player/stones"), "the stones reload: it may have gone through")
	api.answers["/shop/stones/buy"] = FakeApi._ok({"stoneLevel": 7, "quantity": 2, "currency": "gem", "amount": 100, "balance": 1, "owned": 2, "replay": true})
	var gems := []
	s.changed.connect(func(): gems.append(s.gem()))
	res = await s.buy_stones(7, 2)
	eq(api.posts()[1][2]["idempotencyKey"], first, "the retry sends the same key")
	eq(res.replay, true, "the server's replay flag")
	eq(gems[0], 1, "the answer's gem balance at once (the refresh follows)")
	# Another quantity is another buy: a new key.
	await s.buy_stones(7, 5)
	check(api.posts()[2][2]["idempotencyKey"] != first, "a different buy, a different key")
	s.free()


func test_buy_stones_refused_and_busy() -> void:
	var api := FakeApi.new()
	api.answers["/shop/stones/buy"] = FakeApi.fail(400, "SHOP_INSUFFICIENT_BALANCE")
	var s = _state(api)
	var res: Dictionary = await s.buy_stones(6, 1)
	eq(res.code, "SHOP_INSUFFICIENT_BALANCE", "refused")
	eq(s.coin(), 100, "wallet untouched")
	check(not s.stone_keys.has_key(s.key_target("stone_6_x1")), "a refusal settles the key")
	check(not api.gets().has("/player/profile"), "nothing to refresh")
	s.busy_id = "other"
	res = await s.buy_stones(6, 1)
	eq(res.code, "BUSY", "one purchase at a time")
	eq(api.posts().size(), 1, "nothing sent while busy")
	s.free()


func test_upgrade_sends_the_stones_and_reloads() -> void:
	var api := FakeApi.new()
	api.answers["/player/equipment/upgrade"] = FakeApi._ok({"success": true, "newLevel": 4, "percent": 68.0, "equipmentId": "e1"})
	var s = _state(api)
	var stones := [{"stoneLevel": 4, "quantity": 1}]
	var res: Dictionary = await s.upgrade("e1", stones)
	check(res.ok, "upgraded")
	eq(res.data["newLevel"], 4, "the answer")
	eq(api.posts()[0][1], "/player/equipment/upgrade", "path")
	eq(api.posts()[0][2], {"equipmentId": "e1", "stones": stones}, "body")
	for path in ["/player/equipment", "/player/characters", "/player/stones"]:
		check(api.gets().has(path), "%s reloads" % path)
	eq([s.stone_busy, s.equip_busy], ["", ""], "not busy afterwards")
	s.free()


func test_upgrade_failure_still_reloads_the_stones() -> void:
	var api := FakeApi.new()
	api.answers["/player/equipment/upgrade"] = FakeApi.fail(400, "EQUIP_INSUFFICIENT_STONES")
	var s = _state(api)
	var res: Dictionary = await s.upgrade("e1", [{"stoneLevel": 2, "quantity": 9}])
	eq(res.code, "EQUIP_INSUFFICIENT_STONES", "refused")
	check(api.gets().has("/player/stones"), "stones reload to show the truth")
	check(api.gets().has("/player/equipment"), "pieces reload")
	s.free()


func test_upgrade_and_merge_busy_gates() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	s.stone_busy = "merge"
	eq((await s.upgrade("e1", [{"stoneLevel": 1, "quantity": 1}])).code, "BUSY", "a merge runs")
	eq((await s.merge_stones(1, 2)).code, "BUSY", "one stone action at a time")
	s.stone_busy = ""
	s.equip_busy = "e2"
	eq((await s.upgrade("e1", [{"stoneLevel": 1, "quantity": 1}])).code, "BUSY", "an equipment action runs")
	s.equip_busy = ""
	eq((await s.upgrade("", [])).code, "NO_EQUIPMENT", "no piece")
	eq(api.posts(), [], "nothing sent")
	eq(s.stone_busy, "", "gate left open")
	s.free()


func test_merge_stones() -> void:
	var api := FakeApi.new()
	api.answers["/merge/stone"] = FakeApi._ok({"success": true, "message": "ok"})
	var s = _state(api)
	var busy := []
	s.stones_changed.connect(func(): busy.append(s.stone_busy))
	var res: Dictionary = await s.merge_stones(2, 4)
	check(res.ok, "merged")
	eq(api.posts()[0][2], {"stoneLevel": 2, "count": 4}, "body")
	eq(busy[0], "merge", "busy while it runs")
	check(api.gets().has("/player/stones"), "stones reload")
	check(not api.gets().has("/player/equipment"), "the pieces are not touched")
	eq(s.stone_busy, "", "not busy afterwards")
	api.answers["/merge/stone"] = FakeApi.fail(400, "EQUIP_INSUFFICIENT_STONES")
	api.calls.clear()
	res = await s.merge_stones(2, 4)
	eq(res.code, "EQUIP_INSUFFICIENT_STONES", "refused")
	check(api.gets().has("/player/stones"), "reload after a refusal too")
	s.free()
