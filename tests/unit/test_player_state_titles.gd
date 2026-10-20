extends "res://tests/test_case.gd"
## PlayerState titles against a fake REST client: the list, the worn title from the profile,
## equip / unequip requests and what they update, a refusal, the busy gate, and a milestone
## claim giving a title making the list stale.

const PlayerStateScript := preload("res://autoload/player_state.gd")

const SMITH := {"id": "smith", "name": "Thợ rèn lành nghề", "rarity": "blue"}
const OLD_HAND := {"id": "old_hand", "name": "Lão làng", "rarity": "orange"}


class FakeApi:
	extends RefCounted
	var calls: Array = []
	var answers := {}
	var equipped: Variant = {"id": "smith", "name": "Thợ rèn lành nghề", "rarity": "blue"}

	func get_json(path: String) -> Dictionary:
		calls.append(["GET", path, null])
		match path:
			"/player/profile":
				return _ok({"playerId": "", "coin": 1, "gem": 1, "equippedTitle": equipped})
			"/player/titles":
				return answers.get(path, _ok({"titles": [
					{"id": "smith", "name": "Thợ rèn lành nghề", "rarity": "blue", "description": "1 trang bị đạt +10", "owned": true, "obtainedAt": "2026-10-20T04:43:44Z"},
					{"id": "old_hand", "name": "Lão làng", "rarity": "orange", "description": "Chơi 1000 trận", "owned": true, "obtainedAt": "2026-10-20T04:43:44Z"},
					{"id": "grandmaster", "name": "Cao thủ", "rarity": "red", "description": "Lần đầu đạt hạng Cao thủ", "owned": false, "obtainedAt": null},
				], "equipped": equipped}))
		return _ok({})

	func post_json(path: String, body: Variant = {}) -> Dictionary:
		calls.append(["POST", path, body])
		if answers.has(path):
			return answers[path]
		if path == "/player/titles/equip":
			var id = body.get("titleId")
			equipped = null
			for t in [{"id": "smith", "name": "Thợ rèn lành nghề", "rarity": "blue"}, {"id": "old_hand", "name": "Lão làng", "rarity": "orange"}]:
				if t["id"] == id:
					equipped = t
			return _ok({"equipped": equipped})
		return _ok(null)

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
	s.profile = {"playerId": "", "coin": 100, "gem": 5, "equippedTitle": SMITH.duplicate()}
	return s


func test_worn_title_from_the_profile() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	eq(s.equipped_title(), SMITH, "worn")
	s.profile = {"playerId": "", "equippedTitle": null}
	eq(s.equipped_title(), {}, "none")
	s.profile = {}
	eq(s.equipped_title(), {}, "not loaded")
	s.free()


func test_list_load() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	var seen := []
	s.titles_changed.connect(func(): seen.append(s.titles_loading))
	s.need_titles()
	check(s.titles != null, "loaded")
	eq(s.titles["titles"].size(), 3, "three titles")
	eq(s.titles_version, 1, "version")
	eq(seen, [true, false], "loading, then loaded")
	api.calls.clear()
	s.need_titles()
	eq(api.gets(), [], "a fresh copy is not fetched again")
	api.answers["/player/titles"] = FakeApi.fail(0, "")
	s.load_titles()
	check(s.titles_error != "", "error kept")
	check(s.titles != null, "the last list stays")
	s.free()


func test_equip_and_unequip() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	s.need_titles()
	api.calls.clear()
	var changed := [0]
	s.changed.connect(func(): changed[0] += 1)
	var res: Dictionary = await s.equip_title("old_hand")
	check(res.ok, "equipped")
	eq(api.posts(), [["POST", "/player/titles/equip", {"titleId": "old_hand"}]], "request")
	eq(s.equipped_title(), OLD_HAND, "the profile takes the answer")
	check(changed[0] > 0, "the profile changed signal")
	eq(s.titles["equipped"], OLD_HAND, "the list's worn title")
	check(api.gets().has("/player/titles"), "the list reloads")
	check(not s.title_busy, "not busy afterwards")
	api.calls.clear()
	res = await s.equip_title(null)
	check(res.ok, "unequipped")
	eq(api.posts(), [["POST", "/player/titles/equip", {"titleId": null}]], "null takes it off")
	eq(s.equipped_title(), {}, "none worn")
	api.calls.clear()
	await s.equip_title("")
	eq(api.posts()[0][2], {"titleId": null}, "an empty id is null too")
	s.free()


func test_refusal_changes_nothing() -> void:
	var api := FakeApi.new()
	api.answers["/player/titles/equip"] = FakeApi.fail(403, "TITLE_NOT_OWNED")
	var s = _state(api)
	var res: Dictionary = await s.equip_title("grandmaster")
	check(not res.ok, "refused")
	eq(res.code, "TITLE_NOT_OWNED", "code")
	eq(s.equipped_title(), SMITH, "still the old title")
	check(api.gets().has("/player/titles"), "the list reloads after a refusal")
	check(not s.title_busy, "not busy")
	s.free()


func test_busy_gate() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	s.title_busy = true
	var res: Dictionary = await s.equip_title("old_hand")
	eq(res.code, "BUSY", "one at a time")
	eq(api.posts(), [], "nothing sent")
	s.free()


func test_claim_with_a_title_reloads_the_list() -> void:
	var api := FakeApi.new()
	api.answers["/milestones/claim"] = FakeApi._ok({"claimed": ["ms_matches_1000"], "rewards": {"coin": 0, "gem": 200,
		"items": [{"kind": "title", "id": "old_hand", "name": "Lão làng", "rarity": "orange"}]}, "coin": 1, "gem": 205,
		"stones": [], "claimableCount": 0})
	var s = _state(api)
	s.need_titles()
	api.calls.clear()
	await s.claim_milestone("ms_matches_1000")
	check(api.gets().has("/player/titles"), "the title list reloads")
	s.free()
	var s2 = _state(api)
	await s2.claim_milestone("ms_matches_1000")
	check(s2.titles_stale, "not loaded yet: stale")
	s2.free()
