extends "res://tests/test_case.gd"
## PlayerState.sell_equipment() / discard_equipment() against a fake REST client: the steps sent
## (Vứt takes a worn piece off first; selling never does, worn pieces are locked), how failures are reported, and what reloads afterwards.

const PlayerStateScript := preload("res://autoload/player_state.gd")


## Answers POST paths from `answers` (path → result, default ok) and records every call.
class FakeApi:
	extends RefCounted
	var calls: Array = [] # [method, path, body]
	var answers := {}

	func get_json(path: String) -> Dictionary:
		calls.append(["GET", path, null])
		match path:
			"/player/profile":
				return _ok({"playerId": "", "coin": 777, "gem": 5})
			"/player/equipment":
				return _ok([])
			"/player/characters":
				return _ok({"characters": []})
		return _ok({})

	func post_json(path: String, body: Variant = {}) -> Dictionary:
		calls.append(["POST", path, body])
		return answers.get(path, _ok(null))

	func posts() -> Array:
		return calls.filter(func(c): return c[0] == "POST").map(func(c): return c[1])

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
	s.profile = {"playerId": "", "coin": 100, "gem": 5}
	return s


func test_sell_unworn_sends_one_request_and_takes_the_balance() -> void:
	var api := FakeApi.new()
	api.answers["/player/equipment/sell"] = FakeApi._ok({"currency": "coin", "amount": 250, "balance": 350})
	var s = _state(api)
	var seen := []
	s.changed.connect(func(): seen.append(s.coin()))
	var res: Dictionary = await s.sell_equipment("e1")
	check(res.ok, "sold")
	eq(api.posts(), ["/player/equipment/sell"], "no unequip for an unworn piece")
	eq(api.calls.filter(func(c): return c[0] == "POST")[0][2], {"equipmentId": "e1"}, "body")
	eq(seen[0], 350, "the answer's balance is shown at once")
	check(api.gets().has("/player/profile"), "the wallet refreshes")
	check(api.gets().has("/player/equipment") and api.gets().has("/player/characters"), "pieces and characters reload")
	eq(s.equip_busy, "", "not busy afterwards")
	eq(res.get("unequipped"), false, "nothing half-done")
	s.free()


func test_sell_gem_balance() -> void:
	var api := FakeApi.new()
	api.answers["/player/equipment/sell"] = FakeApi._ok({"currency": "gem", "amount": 7, "balance": 12})
	var s = _state(api)
	var got := []
	s.changed.connect(func(): got.append([s.coin(), s.gem()]))
	await s.sell_equipment("e1")
	eq(got[0], [100, 12], "gem balance updated, coin untouched")
	s.free()


func test_worn_already_taken_off_counts_as_done() -> void:
	var api := FakeApi.new()
	api.answers["/player/equipment/unequip"] = FakeApi.fail(409, "EQUIP_NOT_EQUIPPED")
	var s = _state(api)
	var res: Dictionary = await s.discard_equipment("e1", true)
	check(res.ok, "thrown away")
	eq(api.posts(), ["/player/equipment/unequip", "/player/equipment/dismantle"], "dismantle after a NOT_EQUIPPED unequip")
	s.free()


func test_sell_refused_changes_nothing() -> void:
	for code in ["EQUIP_LOCKED", "EQUIP_NOT_SELLABLE"]:
		var api := FakeApi.new()
		api.answers["/player/equipment/sell"] = FakeApi.fail(409, code)
		var s = _state(api)
		var res: Dictionary = await s.sell_equipment("e1")
		check(not res.ok, "not sold")
		eq(res.code, code, "the sell's code")
		eq(api.posts(), ["/player/equipment/sell"], "selling never unequips")
		eq(res.get("unequipped"), false, "nothing half-done")
		eq(s.coin(), 100, "wallet untouched")
		check(not api.gets().has("/player/profile"), "no wallet refresh for a refused sell")
		check(api.gets().has("/player/equipment"), "pieces reload to show the truth")
		s.free()


func test_discard_worn_unequips_first() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	var res: Dictionary = await s.discard_equipment("e1", true)
	check(res.ok, "thrown away")
	eq(api.posts(), ["/player/equipment/unequip", "/player/equipment/dismantle"], "unequip, then dismantle")
	s.free()


func test_discard_fails_after_unequip_is_half_done() -> void:
	var api := FakeApi.new()
	api.answers["/player/equipment/dismantle"] = FakeApi.fail(409, "EQUIP_MODIFIED")
	var s = _state(api)
	var res: Dictionary = await s.discard_equipment("e1", true)
	check(not res.ok, "not thrown away")
	eq(res.get("unequipped"), true, "taken off but not thrown away")
	s.free()


func test_unequip_failure_stops_before_discarding() -> void:
	var api := FakeApi.new()
	api.answers["/player/equipment/unequip"] = FakeApi.fail(403, "EQUIP_NOT_OWNED")
	var s = _state(api)
	var res: Dictionary = await s.discard_equipment("e1", true)
	check(not res.ok, "refused")
	eq(api.posts(), ["/player/equipment/unequip"], "no dismantle after a failed unequip")
	eq(res.get("unequipped"), false, "nothing was done")
	s.free()


func test_discard_unworn_and_refused() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	var res: Dictionary = await s.discard_equipment("e1", false)
	check(res.ok, "thrown away")
	eq(api.posts(), ["/player/equipment/dismantle"], "dismantle only")
	check(not api.gets().has("/player/profile"), "discarding credits nothing: no wallet refresh")
	api.calls.clear()
	api.answers["/player/equipment/dismantle"] = FakeApi.fail(409, "EQUIP_EQUIPPED")
	res = await s.discard_equipment("e1", false)
	eq(res.code, "EQUIP_EQUIPPED", "worn meanwhile")
	eq(res.get("unequipped"), false, "single step: not half-done")
	s.free()


func test_busy_and_missing_id() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	s.equip_busy = "other"
	var res: Dictionary = await s.sell_equipment("e1")
	eq(res.code, "BUSY", "one action at a time")
	s.equip_busy = ""
	res = await s.discard_equipment("", false)
	eq(res.code, "NO_EQUIPMENT", "no id")
	eq(api.posts(), [], "nothing sent")
	s.free()
