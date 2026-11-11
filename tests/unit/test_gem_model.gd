extends "res://tests/test_case.gd"
## Ngọc khảm (screens/home/gem_model.gd, docs/contracts/gem-socket.md): the catalog's gems
## (tests/fixtures/gem_catalog.json: the server's default rows), prices, stats as one picture and
## number, the owned gems and where they sit (the new `socketedIn` / piece `gems`, and an older
## server's gemSlot1 / gemSlot2), the stacks, the merge rules; PlayerState's gem calls against a
## fake REST client (the old server's swap in two steps); the reward tile and the error texts.

const GemModel := preload("res://screens/home/gem_model.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const PlayerStateScript := preload("res://autoload/player_state.gd")
const IdempotencyKeys := preload("res://core/idempotency_keys.gd")
const FIXTURE := "res://tests/fixtures/gem_catalog.json"


static func catalog() -> Variant:
	return EquipmentModel.parse_catalog(JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))["data"])


func test_catalog_gems() -> void:
	var c = catalog()
	check(GemModel.has_catalog(c), "the catalog sends gems")
	eq(GemModel.types(c), ["hp", "damage", "defense", "critical"], "the server's type order")
	eq(GemModel.levels(c, "hp"), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "levels")
	eq(GemModel.max_level(c, "critical"), 10, "the merge cap is the catalog's highest level")
	eq(GemModel.price(GemModel.row(c, "hp", 2)), {"currency": "coin", "amount": 8000}, "coin price")
	eq(GemModel.price({"gemType": "damage", "gemLevel": 5, "priceCoin": 0, "priceGem": 60}), {"currency": "gem", "amount": 60}, "kim cương price")
	check(not GemModel.buyable(GemModel.row(c, "hp", 5)), "level 5 is merge only")
	var shop := GemModel.shop_rows(c)
	eq(shop.map(func(g): return g["gemType"]), ["hp", "damage", "defense", "critical"], "a row per type")
	eq(shop[0]["rows"].map(func(r): return r["gemLevel"]), [1, 2, 3, 4], "the levels sold: those with a price")
	var old = EquipmentModel.parse_catalog({"items": []})
	check(not GemModel.has_catalog(old) and not old.has("gems"), "an older server: no gems, no shop, no merge")
	eq(GemModel.types(old), GemModel.ORDER, "the gems still show by type")
	eq(EquipmentModel.parse_gem_rows([{"gemType": "hp"}, {"gemType": "", "gemLevel": 1}, 3, {"gemType": "hp", "gemLevel": 2, "statValue": 40}]),
		[{"gemType": "hp", "gemLevel": 2, "statValue": 40.0, "priceCoin": 0, "priceGem": 0}], "malformed rows dropped")


func test_affordable() -> void:
	var c = catalog()
	var r := GemModel.row(c, "hp", 3) # 32.000 coin
	check(GemModel.can_afford(r, 5, 160000, 0), "5 × 32.000 = 160.000 coin")
	check(not GemModel.can_afford(r, 5, 159999, 999999), "one short: off (kim cương does not pay a coin price)")
	check(GemModel.can_afford({"priceCoin": 0, "priceGem": 30}, 10, 0, 300), "10 × 30 kim cương")
	check(not GemModel.can_afford(GemModel.row(c, "hp", 8), 1, 9999999, 9999999), "not sold")


func test_stat_picture_and_number() -> void:
	var c = catalog()
	eq(GemModel.stat(c, "hp", 2, {}), {"glyph": "heart", "value": "+40", "color": GemModel.COLORS["hp"]}, "points without the multipliers")
	var mult := {"hp": 2, "damage": 1, "defense": 1, "mobility": 1}
	eq(GemModel.stat(c, "hp", 10, mult)["value"], "+1.320", "points through statMultipliers")
	eq(GemModel.stat(c, "critical", 4, mult)["value"], "+5%", "critical is a percent")
	eq(GemModel.stat(c, "damage", 1)["glyph"], "sword", "damage: the sword")
	eq(GemModel.stat(c, "defense", 1)["glyph"], "shield", "defense: the shield")
	eq(GemModel.stat(c, "hp", 11), {}, "a level the catalog does not know")
	check(GemModel.COLORS["hp"].g > GemModel.COLORS["hp"].r, "hp green")
	check(GemModel.COLORS["damage"].r > GemModel.COLORS["damage"].b, "damage red")
	check(GemModel.COLORS["defense"].b > GemModel.COLORS["defense"].r, "defense blue")
	check(GemModel.COLORS["critical"].r > 0.9 and GemModel.COLORS["critical"].g > 0.7, "critical yellow")


func test_owned_and_where_they_sit() -> void:
	var gems = GemModel.parse_owned([{"gemId": "g1", "gemType": "hp", "gemLevel": 3, "socketedIn": {"equipmentId": "e1", "slotIndex": 1}},
		{"gemId": "g2", "gemType": "hp", "gemLevel": 3}, {"gemId": "g3", "gemType": "damage", "gemLevel": 5}, {"gemType": "hp"}])
	eq(gems.size(), 3, "rows without an id dropped")
	eq(gems[0]["socketedIn"], {"equipmentId": "e1", "slotIndex": 1}, "the server says where")
	eq(gems[1]["socketedIn"], {}, "free")
	eq(GemModel.parse_owned(null), [], "none")
	eq(GemModel.parse_owned({"x": 1}), null, "malformed")
	# An older server: no socketedIn, the pieces hold the ids.
	var old = GemModel.parse_owned([{"gemId": "g1", "gemType": "hp", "gemLevel": 3}, {"gemId": "g2", "gemType": "hp", "gemLevel": 3}])
	var pieces := [{"equipmentId": "e9", "itemId": "crafted_armor_silver", "gemSlot2": "g2"}]
	var filled := GemModel.with_pieces(old, pieces)
	eq(filled[1]["socketedIn"], {"equipmentId": "e9", "slotIndex": 2}, "found in the piece's gemSlot2")
	eq(filled[0]["socketedIn"], {}, "still free")
	eq(old[1]["socketedIn"], {}, "a copy")
	eq(GemModel.piece_gems(pieces[0], filled), {2: {"gemId": "g2", "gemType": "hp", "gemLevel": 3}}, "the old piece's gem from the bag")
	check(not GemModel.swaps_in_one_call(pieces[0]), "an older server swaps in two steps")
	var new_piece := {"equipmentId": "e1", "gemSlot1": "g1", "gems": [{"slotIndex": 1, "gemId": "g1", "gemType": "damage", "gemLevel": 4}]}
	eq(GemModel.piece_gems(new_piece), {1: {"gemId": "g1", "gemType": "damage", "gemLevel": 4}}, "the piece's gems")
	check(GemModel.swaps_in_one_call(new_piece), "the new server swaps")
	eq(GemModel.piece_gems({"gems": []}), {}, "none socketed")
	var c = catalog()
	eq(GemModel.slot_count(c, {"itemId": "armor_lv10"}), 1, "a normal piece: the catalog's 1 socket")
	eq(GemModel.slot_count(c, {"itemId": "crafted_armor_silver"}), 2, "crafted: 2")
	eq(GemModel.slot_count(c, {"itemId": "nope"}), 0, "unknown: none")


func test_stacks() -> void:
	var c = catalog()
	var gems = GemModel.parse_owned([
		{"gemId": "a", "gemType": "damage", "gemLevel": 2}, {"gemId": "b", "gemType": "hp", "gemLevel": 2},
		{"gemId": "c", "gemType": "hp", "gemLevel": 2}, {"gemId": "d", "gemType": "critical", "gemLevel": 6},
		{"gemId": "e", "gemType": "hp", "gemLevel": 6, "socketedIn": {"equipmentId": "e1", "slotIndex": 1}}])
	var st := GemModel.free_stacks(gems, c)
	eq(st.map(func(s): return [s["gemType"], s["gemLevel"], s["count"]]), [["critical", 6, 1], ["hp", 2, 2], ["damage", 2, 1]],
		"grouped, highest level first, then the type order; socketed left out")
	eq(st[1]["ids"], ["b", "c"], "the ids")
	eq(GemModel.socketed(gems, c).map(func(g): return g["gemId"]), ["e"], "the socketed ones apart")
	eq(GemModel.free_count(gems, "hp", 6), 0, "a socketed gem is not free")
	eq(GemModel.free_id(gems, "hp", 2), "b", "a free one to socket")


func test_merge_rules() -> void:
	var c = catalog()
	var gems = GemModel.parse_owned([{"gemId": "a", "gemType": "hp", "gemLevel": 2}, {"gemId": "b", "gemType": "hp", "gemLevel": 2},
		{"gemId": "c", "gemType": "hp", "gemLevel": 2, "socketedIn": {"equipmentId": "e", "slotIndex": 1}}])
	eq(GemModel.merge_blocked(c, "hp", 2, 2, gems), "", "two free of the type and level")
	eq(GemModel.merge_blocked(c, "hp", 2, 3, gems), "Cần 3 viên, đang có 2", "the socketed one does not count")
	eq(GemModel.merge_blocked(c, "hp", 10, 2, gems), "Cấp cao nhất", "the catalog's top level")
	eq(GemModel.merge_blocked(c, "hp", 2, 9, gems), "Bỏ vào 2–4 viên", "the game data's counts")
	eq(GemModel.merge_blocked(EquipmentModel.parse_catalog({"items": []}), "hp", 2, 2, gems), "Chưa ghép được ngọc", "an older server")
	eq(GemModel.merge_choices(c, gems).size(), 36, "4 types × the 9 levels below the cap")
	eq(GemModel.parse_merge({"success": true, "percent": 50, "consumed": 2, "gem": {"gemId": "n", "gemType": "hp", "gemLevel": 3}}),
		{"success": true, "gem": {"gemType": "hp", "gemLevel": 3}, "consumed": 2}, "the new gem")
	eq(GemModel.parse_merge({"success": false, "message": "x"}), {"success": false, "gem": {}, "consumed": -1}, "an older server's failure")


func test_reward_tile_and_errors() -> void:
	var t := RewardModel.tile("socket_gem", "damage", 1, 4)
	eq(RewardModel.merge([t]).size(), 1, "a known reward kind")
	eq(RewardModel.glow(t)["color"], GemModel.COLORS["damage"], "glows in its type's colour")
	check(float(RewardModel.glow(RewardModel.tile("socket_gem", "hp", 1, 9))["power"]) > float(RewardModel.glow(t)["power"]), "higher = brighter")
	var fail := func(code: String) -> Dictionary: return {"ok": false, "status": 400, "code": code, "message": code}
	eq(ErrorText.gem_socket(fail.call("EQUIP_GEM_SOCKETED")), "Ngọc đang khảm ở món khác, hãy tháo ra trước", "socketed elsewhere")
	eq(ErrorText.gem_buy(fail.call("SHOP_GEM_NOT_FOR_SALE")), "Ngọc này không bán, chỉ ghép được", "not sold")
	eq(ErrorText.gem_merge(fail.call("MERGE_MAX_COUNT")), "Chỉ bỏ vào tối đa 4 viên", "the game data's count")
	eq(ErrorText.gem_merge(fail.call("EQUIP_GEM_NOT_OWNED")), "Không đủ ngọc để ghép", "the server's code for too few")


# ── PlayerState ─────────────────────────────────────────────────────────────

class FakeApi:
	extends RefCounted
	var calls: Array = []
	var answers := {}
	var gems: Variant = [{"gemId": "g1", "gemType": "hp", "gemLevel": 1}]

	func get_json(path: String) -> Dictionary:
		calls.append(["GET", path, null])
		match path:
			"/player/gems":
				return _ok(gems)
			"/player/equipment":
				return _ok([])
			"/player/characters":
				return _ok({"characters": []})
			"/player/profile":
				return _ok({"playerId": "", "coin": 100, "gem": 5})
		return _ok({})

	func post_json(path: String, body: Variant = {}) -> Dictionary:
		calls.append(["POST", path, body])
		return answers.get(path, _ok({"success": true}))

	func posts() -> Array:
		return calls.filter(func(c): return c[0] == "POST").map(func(c): return [c[1], c[2]])

	func gets() -> Array:
		return calls.filter(func(c): return c[0] == "GET").map(func(c): return c[1])

	static func _ok(data: Variant) -> Dictionary:
		return {"ok": true, "status": 200, "code": "", "message": "", "data": data}


func _state(api: FakeApi):
	var s = PlayerStateScript.new()
	s.api = api
	s.equipment = []
	s.equipment_stale = false
	s.profile = {"playerId": "", "coin": 1000, "gem": 5}
	s.gem_keys = IdempotencyKeys.new() # in memory: never the device's file
	return s


func test_player_state_gems() -> void:
	var api := FakeApi.new()
	var s = _state(api)
	s.need_gems()
	eq(s.gem_list().size(), 1, "loaded")
	check(s.gems_ready(), "ready")
	# New server: a filled socket swaps in one call.
	api.calls.clear()
	var piece := {"equipmentId": "e1", "gems": [{"slotIndex": 1, "gemId": "old", "gemType": "hp", "gemLevel": 1}]}
	var res: Dictionary = await s.socket_gem(piece, 1, "g1")
	check(res.ok, "socketed")
	eq(api.posts(), [["/player/equipment/socket", {"equipmentId": "e1", "slotIndex": 1, "gemId": "g1"}]], "one call")
	check(api.gets().has("/player/gems") and api.gets().has("/player/equipment") and api.gets().has("/player/characters"),
		"the gems, the pieces and the characters reload")
	# Older server: take the old gem out first.
	api.calls.clear()
	res = await s.socket_gem({"equipmentId": "e1", "gemSlot1": "old"}, 1, "g1")
	eq(api.posts().map(func(p): return p[0]), ["/player/equipment/unsocket", "/player/equipment/socket"], "two steps")
	api.calls.clear()
	res = await s.unsocket_gem("e1", 2)
	eq(api.posts(), [["/player/equipment/unsocket", {"equipmentId": "e1", "slotIndex": 2}]], "unsocket")
	api.calls.clear()
	res = await s.merge_gems("hp", 2, 3)
	eq(api.posts(), [["/merge/gem", {"gemType": "hp", "gemLevel": 2, "count": 3}]], "merge")
	eq(s.gem_busy, "", "free again")
	check(api.gets().has("/player/gems"), "the gems reload")
	api.calls.clear()
	api.answers["/shop/gems/buy"] = FakeApi._ok({"gemType": "hp", "gemLevel": 2, "quantity": 5, "currency": "coin", "amount": 2000,
		"balance": 13400, "gemUnlocked": 50, "owned": 7, "replay": false})
	var seen := []
	s.changed.connect(func(): seen.append([s.profile.get("coin"), s.profile.get("gemUnlocked")]))
	res = await s.buy_gems("hp", 2, 5)
	check(res.ok and not res.replay, "bought")
	var body: Dictionary = api.posts()[0][1]
	eq([body["gemType"], body["gemLevel"], body["quantity"]], ["hp", 2, 5], "the request")
	check(str(body.get("idempotencyKey", "")) != "", "with a key")
	check(seen.has([13400, 50]), "the wallet takes the answer's balances at once (then the refresh): %s" % [seen])
	check(api.gets().has("/player/gems"), "the gems reload")
	s.free()


# ── Screens ─────────────────────────────────────────────────────────────────

func _with_catalog(gems: Variant) -> void:
	PlayerState.catalog = catalog()
	PlayerState.characters = null
	PlayerState.gems = gems
	PlayerState.gems_stale = gems == null
	PlayerState.equipment = []
	PlayerState.equipment_stale = false


func _reset() -> void:
	PlayerState.catalog = null
	PlayerState.gems = null
	PlayerState.gems_stale = true
	PlayerState.equipment = null
	PlayerState.equipment_stale = true
	PlayerState.profile = {}


func test_piece_popup_sockets_mirrored() -> void:
	_with_catalog([])
	var EquipmentUi = load("res://screens/home/equipment_ui.gd")
	var piece := {"equipmentId": "e1", "itemId": "crafted_armor_silver", "gems": [{"slotIndex": 1, "gemId": "g", "gemType": "hp", "gemLevel": 4}]}
	var row: HBoxContainer = EquipmentUi.gem_row(null, null, piece, GemModel.slot_count(PlayerState.catalog, piece), "rookie")
	eq(row.get_child_count(), 2, "a cell per catalog socket")
	eq(row.alignment, BoxContainer.ALIGNMENT_CENTER, "round the centre")
	var a: Control = row.get_child(0)
	var b: Control = row.get_child(1)
	eq(a.custom_minimum_size.x, b.custom_minimum_size.x, "equal cells: mirrored")
	check(a.find_child("Unsocket", true, false) != null, "a filled socket can be emptied")
	check(b.find_child("Unsocket", true, false) == null and b.find_child("Plus", true, false) != null, "an empty socket: a +")
	var value: Label = a.find_child("GemStat", true, false).get_child(1)
	eq(value.text, "+110", "what it gives (points, the multipliers not loaded)")
	row.free()
	_reset()


func test_shop_gem_cards() -> void:
	_with_catalog([])
	PlayerState.profile = {"coin": 10000, "gem": 0}
	var ShopTab = load("res://screens/home/shop_tab.gd")
	eq(ShopTab.SUB_TABS[ShopTab.SOCKET_GEMS], "Ngọc", "Shop › Ngọc")
	var shop: Control = ShopTab.new()
	shop.size = Vector2(1600, 800)
	(Engine.get_main_loop() as SceneTree).root.add_child(shop)
	if not shop.is_node_ready():
		shop._ready()
	shop._render_gem_shop()
	var page: Control = shop._flows[ShopTab.SOCKET_GEMS]
	eq(page.get_child_count(), 4, "a row per type")
	var hp1: Node = page.find_child("Gem_hp_1", true, false)
	var hp3: Node = page.find_child("Gem_hp_3", true, false)
	check(hp1 != null and hp3 != null, "cards by type + level")
	check(page.find_child("Gem_hp_4", true, false) != null, "every priced level")
	check(page.find_child("Gem_hp_5", true, false) == null and page.find_child("Gem_hp_7", true, false) == null, "merge-only levels are not sold")
	check(not (hp1.find_child("Buy", true, false) as Button).disabled, "2.000 coin: affordable")
	check((hp3.find_child("Buy", true, false) as Button).disabled, "32.000 coin with 10.000: off")
	check(shop._sub_tabs[ShopTab.SOCKET_GEMS].visible, "shown with catalog gems")
	PlayerState.catalog = EquipmentModel.parse_catalog({"items": []})
	shop._show_gem_tab()
	check(not shop._sub_tabs[ShopTab.SOCKET_GEMS].visible, "an older server: hidden")
	shop.free()
	_reset()


func test_level_as_upgrade_aura_step() -> void:
	var steps: Array = []
	for lv in range(1, 11):
		steps.append(GemModel.aura_step(lv, 10))
	eq(steps[0], {"tier": 1, "lite": true}, "level 1: the lighter green, near plain")
	eq(steps[1], {"tier": 1, "lite": false}, "level 2: the full green")
	eq(steps[9], {"tier": 5, "lite": false}, "level 10: the full red, the strongest")
	eq(steps.map(func(st): return st["tier"]), [1, 1, 2, 2, 3, 3, 4, 4, 5, 5], "the aura's colour tiers in order")
	for i in range(1, steps.size()):
		check(steps[i] != steps[i - 1], "level %d differs from level %d" % [i + 1, i])
	eq(GemModel.aura_step(0, 10)["tier"], 0, "no level: no aura")
	eq(GemModel.aura_step(12, 10), {"tier": 5, "lite": false}, "above the top: the strongest")
	eq(GemModel.aura_step(1, 1), {"tier": 1, "lite": true}, "a single level: the lightest")
	var six: Array = []
	for lv in range(1, 7):
		six.append(GemModel.aura_step(lv, 6))
	eq(six[0], {"tier": 1, "lite": true}, "fewer levels: still the lightest first")
	eq(six[5], {"tier": 5, "lite": false}, "and the strongest last")
	for i in range(1, six.size()):
		check(six[i] != six[i - 1], "six levels: %d differs from %d" % [i + 1, i])


func test_gem_icon_draws_level_with_upgrade_aura() -> void:
	_with_catalog([])
	var GemIcon = load("res://ui/gem_icon.gd")
	var UpgradeAura = load("res://screens/home/upgrade_aura.gd")
	var g1: Control = GemIcon.make("hp", 1, 80)
	var g10: Control = GemIcon.make("damage", 10, 80)
	var a1 = g1.aura_node()
	var a10 = g10.aura_node()
	check(a1 != null and a1.get_script() == UpgradeAura, "the piece's upgrade aura")
	check(a1.show_behind_parent, "behind the gem")
	eq(a1.size, Vector2(80, 80), "on the gem's square")
	check(a1.visible and a10.visible, "shown from level 1")
	eq([a1.shown_tier(), a1.step_lite], [1, true], "level 1: the lighter green")
	eq([a10.shown_tier(), a10.step_lite], [5, false], "level 10: the full red")
	check(a1.material != a10.material, "each step its own look")
	eq(float(a1.material.get_shader_parameter("fill")), 0.0, "the lighter step: no fill")
	check(float(a10.material.get_shader_parameter("fill")) > 0.5, "the full step: its tier's fill")
	check(float(a1.material.get_shader_parameter("strength")) < float(UpgradeAura.LOOKS[1]["strength"]), "the lighter step: dimmer")
	check(GemIcon.make("hp", 4, 80).aura_node().material == GemIcon.make("defense", 4, 64).aura_node().material, "one shared material per step")
	g1.level = 2
	eq([a1.shown_tier(), a1.step_lite], [1, false], "follows the level")
	g1.size = Vector2(120, 120)
	g1.resized.emit() # the test tree does not lay out
	eq(a1.size, Vector2(120, 120), "follows the size")
	var picker: Control = GemIcon.make("hp", 1, 72, false)
	check(picker.aura_node() == null, "a type picker: the plain gem")
	check(g1.find_children("*", "Label", true, false).is_empty(), "no level number")
	for n in [g1, g10, picker]:
		n.free()
	_reset()
