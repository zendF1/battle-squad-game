extends "res://tests/test_case.gd"
## Caps by tier (UpgradeModel.cap() and friends) and Chuyển hoá (TransferModel, ErrorText.transfer(),
## PlayerState.transfer_equipment()) against the contract ../battle-squad/docs/contracts/equip-transfer.md.

const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const TransferModel := preload("res://screens/home/transfer_model.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const PlayerStateScript := preload("res://autoload/player_state.gd")
const IdempotencyKeys := preload("res://core/idempotency_keys.gd")


## The contract's defaults: transferGemCost by toLevel, the caps on the items.
static func catalog(transfer: bool = true) -> Variant:
	var costs := [5, 10, 15, 25, 40, 60, 90, 130, 180, 250, 350, 480, 650, 900, 1200, 1600]
	var rows: Array = []
	for i in 16:
		var r := {"fromLevel": i, "toLevel": i + 1, "upgradeCost": 100, "maxPercent": 50, "failResetTo": i}
		if transfer:
			r["transferGemCost"] = costs[i]
		rows.append(r)
	var items := [{"itemId": "armor_lv10", "name": "Áo Sắt", "slot": "armor", "isActive": true, "maxUpgradeLevel": 6},
		{"itemId": "armor_lv20", "name": "Áo Thép", "slot": "armor", "isActive": true, "maxUpgradeLevel": 10},
		{"itemId": "armor_lv40", "name": "Áo Rồng", "slot": "armor", "isActive": true, "maxUpgradeLevel": 16},
		{"itemId": "helmet_lv20", "name": "Mũ Thép", "slot": "helmet", "isActive": true, "maxUpgradeLevel": 10}]
	return EquipmentModel.parse_catalog({"items": items, "upgradeRates": rows})


static func piece(id: String, item_id: String, level: int, cap: Variant = null) -> Dictionary:
	var p := {"equipmentId": id, "itemId": item_id, "slot": item_id.get_slice("_", 0), "upgradeLevel": level}
	if cap != null:
		p["maxUpgradeLevel"] = cap
	return p


func test_game_data_table() -> void:
	eq(GameData.max_upgrade_by_tier(), [16, 6, 10, 14, 16], "gear.maxUpgradeByTier of the fixture")


func test_cap_from_piece_item_table() -> void:
	var c = catalog()
	eq(UpgradeModel.cap(c, piece("a", "armor_lv10", 3, 6)), 6, "the piece's own")
	eq(UpgradeModel.cap(c, piece("a", "armor_lv20", 3)), 10, "else its item's")
	var unknown := {"equipmentId": "x", "itemId": "nope", "slot": "armor", "upgradeLevel": 2, "tierIndex": 3}
	eq(UpgradeModel.cap(c, unknown), 14, "else the game data's table at its tier index")
	eq(UpgradeModel.cap(c, {"itemId": "armor_lv10", "slot": "armor", "maxUpgradeLevel": 6}), 6, "a catalog item (the Shop)")
	eq(UpgradeModel.cap(c, piece("a", "armor_lv10", 3, 40)), UpgradeModel.max_level(), "never above the game's highest")


func test_older_server_has_no_cap() -> void:
	var data := {"version": "old-server", "equipment": GameData.section("equipment").duplicate(true)}
	GameData.reset("")
	GameData.take(GameData.parse(data), "", false) # no gear section: no table
	var c = EquipmentModel.parse_catalog({"items": [{"itemId": "armor_lv10", "slot": "armor"}], "upgradeRates": []})
	var p := piece("a", "armor_lv10", 8)
	check(not UpgradeModel.cap_known(c, p), "nothing tells the cap")
	eq(UpgradeModel.cap(c, p), UpgradeModel.max_level(), "the old +16")
	eq(UpgradeModel.shown_cap(c, p), -1, "no mark drawn")
	check(not UpgradeModel.at_tier_cap(c, p), "upgradable")
	eq(UpgradeModel.blocked_reason(c, p, {}, {}), "Chưa có bảng nâng cấp cho +8", "the old reasons")


func test_shown_cap_and_at_cap() -> void:
	var c = catalog()
	eq(UpgradeModel.shown_cap(c, piece("a", "armor_lv10", 2, 6)), 6, "below +16: drawn")
	eq(UpgradeModel.shown_cap(c, piece("a", "armor_lv40", 2, 16)), -1, "+16 is the bar's end")
	check(UpgradeModel.at_tier_cap(c, piece("a", "armor_lv10", 6, 6)), "at the cap")
	check(UpgradeModel.at_tier_cap(c, piece("a", "armor_lv10", 8, 6)), "above it (upgraded before the caps)")
	check(not UpgradeModel.at_tier_cap(c, piece("a", "armor_lv10", 5, 6)), "below it")
	check(not UpgradeModel.at_tier_cap(c, piece("a", "armor_lv40", 16, 16)), "+16 is the max, not a tier cap")


func test_upgrade_blocked_and_preview_at_cap() -> void:
	var c = catalog()
	var p := piece("a", "armor_lv10", 6, 6)
	eq(UpgradeModel.blocked_reason(c, p, {1: 1}, {1: 5}), "Đã đạt trần +6", "the button is off at the cap")
	var view := UpgradeModel.preview(c, p)
	check(view["maxed"] and view["capped"], "maxed by the cap")
	eq(view["columns"].size(), 1, "the piece alone")
	eq(view["note"], "Đã đạt trần +6", "the note")
	eq(view["fail"], "", "no failure line")
	var above := UpgradeModel.preview(c, piece("a", "armor_lv10", 8, 6))
	eq(int(above["columns"][0]["level"]), 8, "a piece above its cap keeps its level")
	var free := UpgradeModel.preview(c, piece("a", "armor_lv10", 5, 6))
	check(not free["maxed"] and not free["capped"], "below the cap: the next level")


func test_offered_and_cost() -> void:
	var c = catalog()
	check(TransferModel.offered(c), "rows carry transferGemCost")
	check(not TransferModel.offered(catalog(false)), "an older server: no tab")
	check(not TransferModel.offered(null), "no catalog yet")
	eq(TransferModel.cost(c, 10), 250, "the row whose toLevel is the source's level")
	eq(TransferModel.cost(c, 1), 5, "+1")
	eq(TransferModel.cost(c, 0), 0, "+0 is no source")
	eq(TransferModel.cost(catalog(false), 10), 0, "no price")


func test_sources_and_targets() -> void:
	var c = catalog()
	var owned := [piece("s", "armor_lv10", 8, 6), piece("t1", "armor_lv20", 0, 10), piece("t2", "armor_lv10", 0, 6),
		piece("t3", "armor_lv40", 9, 16), piece("h", "helmet_lv20", 0, 10), piece("z", "armor_lv20", 0, 10)]
	var src := TransferModel.sources(owned, c).map(func(p): return p["equipmentId"])
	check(src.has("s") and src.has("t3") and not src.has("t1"), "+1 and up only (%s)" % [src])
	var rows := TransferModel.targets(owned, c, owned[0])
	var ids := rows.map(func(r): return r["piece"]["equipmentId"])
	check(not ids.has("s"), "not itself")
	check(not ids.has("h"), "not another slot")
	check(not ids.has("t3"), "not one at or above the source's level")
	eq(rows.map(func(r): return r["ok"]), [true, true, false], "the ones that can first, the low cap last")
	eq(rows[2]["piece"]["equipmentId"], "t2", "the Sắt piece cannot hold +8")
	eq(int(rows[2]["cap"]), 6, "with its cap")
	eq(TransferModel.targets(owned, c, {}), [], "no source")


func test_blocked_reason_order() -> void:
	var c = catalog()
	var s := piece("s", "armor_lv20", 10, 10)
	var t := piece("t", "armor_lv40", 0, 16)
	eq(TransferModel.blocked_reason(c, {}, t), "Chọn món nguồn", "no source")
	eq(TransferModel.blocked_reason(c, s, {}), "Chọn món nhận", "no target")
	eq(TransferModel.blocked_reason(c, s, s), "Chọn hai món khác nhau", "the same piece")
	eq(TransferModel.blocked_reason(c, s, piece("h", "helmet_lv20", 0, 10)), "Hai món phải cùng loại", "another slot")
	eq(TransferModel.blocked_reason(c, s, piece("t", "armor_lv40", 10, 16)), "Món nguồn phải cao hơn món nhận", "not higher")
	eq(TransferModel.blocked_reason(c, s, piece("t", "armor_lv10", 0, 6)), "Món nhận chỉ lên được +6", "the target's cap")
	eq(TransferModel.blocked_reason(c, s, t, 249), TransferModel.SHORT, "kim cương khoá short")
	eq(TransferModel.blocked_reason(c, s, t, 250), "", "enough")
	eq(TransferModel.blocked_reason(c, s, t, -1), "", "the balance unknown: the server checks")
	var free = EquipmentModel.parse_catalog({"items": [], "upgradeRates": [{"fromLevel": 9, "toLevel": 10, "transferGemCost": 0}]})
	eq(TransferModel.blocked_reason(free, s, t, 9999), "+10 chưa chuyển hoá được", "price 0")


func test_after_and_parse() -> void:
	eq(TransferModel.after(piece("s", "armor_lv10", 8), piece("t", "armor_lv20", 2)), {"source": 2, "target": 8}, "the swap")
	var r := TransferModel.parse_result({"source": {"equipmentId": "s", "upgradeLevel": 0}, "target": {"equipmentId": "t", "upgradeLevel": 10},
		"gemSpent": 250, "gemBalance": 120, "gemUnlocked": 40, "replay": false})
	eq(int(r["target"]["upgradeLevel"]), 10, "the target after")
	eq([r["gem_spent"], r["gem_balance"], r["gem_unlocked"], r["replay"]], [250, 120, 40, false], "the numbers")
	var empty := TransferModel.parse_result(null)
	eq([empty["source"], empty["gem_balance"], empty["replay"]], [{}, -1, false], "a malformed answer")
	eq(TransferModel.confirm_text(1200), "Dùng 1.200 kim cương khoá?", "the confirmation")


func test_error_texts() -> void:
	eq(ErrorText.transfer({"status": 400, "code": "EQUIP_TRANSFER_TARGET_CAP", "details": {"maxUpgradeLevel": 6}}),
		"Món nhận chỉ lên được +6", "the cap from the details")
	eq(ErrorText.transfer({"status": 400, "code": "EQUIP_TRANSFER_INSUFFICIENT_GEM", "details": {"gemCost": 250, "gemBalance": 120}}),
		"Thiếu kim cương khoá", "short")
	eq(ErrorText.transfer({"status": 409, "code": "EQUIP_MODIFIED"}), "Trang bị vừa thay đổi, hãy thử lại", "modified")
	eq(ErrorText.transfer({"status": 0}), ErrorText.OFFLINE, "offline")
	eq(ErrorText.transfer({"status": 403, "code": "EQUIP_LOCKED"}), "Trang bị đang bị khoá", "other codes as EQUIP")
	eq(ErrorText.upgrade({"status": 400, "code": "EQUIP_TIER_MAX_UPGRADE", "details": {"maxUpgradeLevel": 10}}),
		"Đã đạt trần +10, hãy chuyển hoá sang món bậc cao hơn", "the upgrade at the tier's cap")


class FakeApi:
	extends RefCounted
	var calls: Array = []
	var answers := {}

	func get_json(path: String) -> Dictionary:
		calls.append(["GET", path, null])
		match path:
			"/player/profile":
				return _ok({"playerId": "", "coin": 10, "gem": 120, "gemUnlocked": 40})
			"/player/equipment":
				return _ok([])
			"/player/characters":
				return _ok({"characters": []})
		return _ok({})

	func post_json(path: String, body: Variant = {}) -> Dictionary:
		calls.append(["POST", path, body])
		return answers.get(path, _ok(null))

	func posts() -> Array:
		return calls.filter(func(c): return c[0] == "POST")

	static func _ok(data: Variant) -> Dictionary:
		return {"ok": true, "status": 200, "code": "", "message": "", "data": data}


func _state(api: FakeApi):
	var s = PlayerStateScript.new()
	s.api = api
	s.equipment = []
	s.equipment_stale = false
	s.profile = {"playerId": "", "coin": 10, "gem": 370, "gemUnlocked": 40}
	s.transfer_keys = IdempotencyKeys.new() # in memory: never the device's file
	return s


func test_player_state_transfer() -> void:
	var api := FakeApi.new()
	api.answers["/player/equipment/transfer"] = FakeApi._ok({"source": {"equipmentId": "s", "upgradeLevel": 0},
		"target": {"equipmentId": "t", "upgradeLevel": 10}, "gemSpent": 250, "gemBalance": 120, "gemUnlocked": 40, "replay": false})
	var s = _state(api)
	var res: Dictionary = await s.transfer_equipment("s", "t", 10, 0)
	check(res.ok, "done")
	var post: Array = api.posts()[0]
	eq(post[1], "/player/equipment/transfer", "the path")
	var body: Dictionary = post[2]
	eq([body["sourceEquipmentId"], body["targetEquipmentId"], body["expectedSourceLevel"], body["expectedTargetLevel"]],
		["s", "t", 10, 0], "the contract's fields")
	check(str(body["idempotencyKey"]).length() > 0 and str(body["idempotencyKey"]).length() <= 64, "a key")
	eq(s.gem_locked(), 120, "kim cương khoá from the answer")
	eq(s.gem_unlocked(), 40, "the unlocked one unchanged")
	eq(s.equip_busy, "", "released")
	s.free()


func test_player_state_transfer_keeps_key_without_answer() -> void:
	var api := FakeApi.new()
	api.answers["/player/equipment/transfer"] = {"ok": false, "status": 0, "code": "NETWORK_ERROR", "message": "", "data": null}
	var s = _state(api)
	await s.transfer_equipment("s", "t", 10, 0)
	api.answers["/player/equipment/transfer"] = {"ok": false, "status": 400, "code": "EQUIP_TRANSFER_INSUFFICIENT_GEM", "message": "", "data": null}
	await s.transfer_equipment("s", "t", 10, 0)
	var keys: Array = api.posts().map(func(c): return c[2]["idempotencyKey"])
	eq(keys[0], keys[1], "the retry sends the same key")
	await s.transfer_equipment("s", "t", 10, 0)
	check(api.posts()[2][2]["idempotencyKey"] != keys[0], "a refusal settles the key")
	check(api.calls.any(func(c): return c[0] == "GET" and c[1] == "/player/profile"), "the wallet's truth is reloaded")
	s.free()


func test_player_state_transfer_busy() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	s.equip_busy = "other"
	var res: Dictionary = await s.transfer_equipment("s", "t", 10, 0)
	eq(res.code, "BUSY", "one equipment action at a time")
	eq(api.posts(), [], "nothing sent")
	s.equip_busy = ""
	res = await s.transfer_equipment("s", "", 10, 0)
	eq(res.code, "NO_EQUIPMENT", "no target")
	s.free()
