extends "res://tests/test_case.gd"
## Buying items by quantity (battle-squad docs/contracts/shop-quantity.md §1–2): unit offers with
## maxStack, the room left in the bag, the "Mua" dialog's count × preset (BuyQuantity and the
## dialog), POST /shop/purchase with quantity and its own key, SHOP_STACK_LIMIT.

const ShopModel := preload("res://screens/home/shop_model.gd")
const BuyQuantity := preload("res://screens/home/buy_quantity.gd")
const BuyQuantityDialog := preload("res://screens/home/buy_quantity_dialog.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const ApiResponse := preload("res://core/api_response.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const PlayerStateScript := preload("res://autoload/player_state.gd")
const IdempotencyKeys := preload("res://core/idempotency_keys.gd")

const UNIT := {"offerId": "item_drill_bomb", "itemId": "drill_bomb", "offerType": "item", "priceCurrency": "coin",
	"priceAmount": 150, "quantity": 1, "isActive": true, "maxStack": 99}


class FakeApi:
	extends RefCounted
	var calls: Array = []
	var answer := {"ok": true, "status": 200, "code": "", "message": "", "data": {"purchaseId": "pu1", "quantity": 20,
		"quantityGranted": 20, "priceAmount": 3000, "status": "completed", "createdAt": "2026-10-28T09:12:44Z"}}

	func get_json(path: String) -> Dictionary:
		calls.append(["GET", path, null])
		return {"ok": true, "status": 200, "code": "", "message": "", "data": {} if path == "/player/profile" else []}

	func post_json(path: String, body: Variant = {}) -> Dictionary:
		calls.append(["POST", path, body])
		return answer


func test_unit_offers() -> void:
	eq(GameData.max_item_stack(), 99, "itemRules.maxItemStack")
	eq(ShopModel.max_stack(UNIT), 99, "the offer's maxStack")
	var no_cap := UNIT.duplicate()
	no_cap.erase("maxStack")
	eq(ShopModel.max_stack(no_cap), 99, "else the game data's")
	check(ShopModel.sells_quantity(UNIT), "a unit item offer buys by quantity")
	var limited := UNIT.duplicate()
	limited["limitPerPlayer"] = 3
	check(not ShopModel.sells_quantity(limited), "a limited offer sells one")
	check(not ShopModel.sells_quantity({"offerId": "flora", "itemId": "flora", "offerType": "character_unlock", "priceAmount": 300}),
		"a character unlock sells one")
	check(not ShopModel.sells_quantity({"offerId": "coin_pack_10", "itemId": "coin", "offerType": "coin_pack", "priceAmount": 10}),
		"a coin pack sells one")
	eq([ShopModel.room(UNIT, 0), ShopModel.room(UNIT, 90), ShopModel.room(UNIT, 99), ShopModel.room(UNIT, 120), ShopModel.room(UNIT, -1)],
		[99, 9, 0, 0, 99], "the room left in the bag (unknown: as if empty)")
	var pack := UNIT.duplicate()
	pack["quantity"] = 3
	eq(ShopModel.room(pack, 90), 3, "a pack of 3: three more packs fit 9")
	eq([ShopModel.wallet_for(UNIT, 500, 40), ShopModel.wallet_for({"priceCurrency": "gem"}, 500, 40)], [500, 40], "the wallet in its currency")


func test_count_times_preset() -> void:
	var q := BuyQuantity.new(99, 150, 100000)
	eq([q.count, q.preset, q.total(), q.price()], [1, 1, 1, 150], "starts at one")
	check(not q.can_down(), "not below one")
	q.up()
	q.toggle(10)
	eq([q.count, q.preset, q.total(), q.price()], [2, 10, 20, 3000], "x10 with the count at 2 buys 20")
	q.toggle(10)
	eq([q.preset, q.total()], [1, 2], "tapping the chosen preset again: x1")
	q.toggle(5)
	q.toggle(3)
	eq([q.preset, q.total()], [3, 6], "switching presets keeps the count")
	for i in 40:
		q.up()
	eq([q.count, q.total()], [33, 99], "▲ stops at the room")
	check(not q.can_up(), "▲ off at the cap")
	q.toggle(10)
	eq([q.preset, q.count, q.total()], [10, 9, 90], "a bigger preset shrinks the count to fit")
	check(q.can_buy(), "buyable")


func test_room_caps_presets() -> void:
	var q := BuyQuantity.new(9, 150, -1)
	check(q.preset_allowed(3) and q.preset_allowed(5), "x3 and x5 fit 9")
	check(not q.preset_allowed(10), "x10 does not")
	q.toggle(10)
	eq(q.preset, 1, "an off preset is not picked")
	q.toggle(5)
	eq([q.count, q.total()], [1, 5], "x5 once")
	check(not q.can_up(), "twice would be 10")
	var full := BuyQuantity.new(0, 150, 1000)
	eq([full.count, full.total()], [0, 0], "a full bag: nothing")
	check(not full.can_buy() and not full.can_up() and not full.preset_allowed(3), "everything off")


func test_short_of_coins() -> void:
	var q := BuyQuantity.new(99, 150, 400)
	q.up()
	check(q.affordable() and q.can_buy(), "300 of 400")
	q.up()
	check(not q.affordable() and not q.can_buy(), "450 of 400: Mua off")
	check(q.can_up(), "▲ still works")
	check(BuyQuantity.new(99, 150, -1).affordable(), "unknown wallet: the server decides")


func test_dialog() -> void:
	var host := Control.new()
	var bought: Array = []
	var d = BuyQuantityDialog.new()
	d.open_for(host, UNIT, 90, 2000, func(total: int) -> void: bought.append(total))
	eq(d.title.text, "Bom khoan", "the item's name as the title")
	eq(d.owned_label.text, "90", "the bag's count")
	eq([d.count_label.text, d.total_label.text, d.price_label.text], ["1", "×1", "150"], "one to start")
	check(d.down_button.disabled and not d.up_button.disabled, "▼ off at one")
	check(d.preset_buttons[0].disabled == false and d.preset_buttons[2].disabled, "x10 does not fit the 9 left")
	d.preset_buttons[0].pressed.emit()
	d._on_step_down(1)
	d._on_step_up()
	eq([d.count_label.text, d.total_label.text, d.price_label.text], ["2", "×6", "900"], "x3 × 2")
	check(d.preset_buttons[0].button_pressed, "x3 lit")
	d._on_step_down(1)
	d._on_step_up()
	eq(d.count_label.text, "3", "x3 × 3 = 9 fits")
	check(d.up_button.disabled, "▲ off at the cap")
	check(not d.buy_button.disabled, "Mua on")
	d.preset_buttons[0].pressed.emit()
	eq(d.total_label.text, "×3", "x3 off again: x1")
	d.buy_button.pressed.emit()
	eq(bought, [3], "Mua buys the total")
	d.free()
	var poor = BuyQuantityDialog.new()
	poor.open_for(host, UNIT, 0, 100, func(_t: int) -> void: pass)
	check(poor.buy_button.disabled, "short of coins: Mua off")
	check(poor.price_label.get_theme_color("font_color") == BuyQuantityDialog.SHORT, "the price red")
	poor.free()
	host.free()


func test_hold_repeats() -> void:
	var host := Control.new()
	var d = BuyQuantityDialog.new()
	d.open_for(host, UNIT, 0, -1, func(_t: int) -> void: pass)
	d._on_step_down(1)
	for i in 5:
		d._on_hold_tick()
	eq(d.model.count, 7, "held ▲ keeps counting")
	d._on_step_up()
	d._on_hold_tick()
	eq(d.model.count, 7, "released: stops")
	d.free()
	host.free()


func test_purchase_sends_quantity_with_its_own_key() -> void:
	var api := FakeApi.new()
	var s = PlayerStateScript.new()
	s.api = api
	s.profile = {"playerId": "", "coin": 5000, "gem": 5}
	s.purchase_keys = IdempotencyKeys.new()
	var res: Dictionary = await s.buy("item_drill_bomb", 20)
	check(res.ok, "bought")
	var body: Dictionary = api.calls.filter(func(c): return c[0] == "POST")[0][2]
	eq([body["offerId"], body["quantity"]], ["item_drill_bomb", 20], "offer and quantity")
	check(str(body.get("idempotencyKey", "")) != "", "with a key")
	api.calls.clear()
	await s.buy("item_drill_bomb")
	body = api.calls.filter(func(c): return c[0] == "POST")[0][2]
	check(not body.has("quantity"), "one: no quantity (the server's default)")
	api.answer = {"ok": false, "status": 0, "code": "NETWORK_ERROR", "message": "", "data": null}
	await s.buy("item_drill_bomb", 20)
	await s.buy("item_drill_bomb", 5)
	var keys: Array = api.calls.filter(func(c): return c[0] == "POST").map(func(c): return c[2]["idempotencyKey"])
	check(keys[-1] != keys[-2], "another quantity: another key (the server refuses one key for two)")
	check(s.purchase_keys.has_key(s.key_target("item_drill_bomb_x20")), "the unanswered x20 keeps its key for the retry")
	s.free()


func test_stack_limit_error() -> void:
	var res := ApiResponse.parse(HTTPRequest.RESULT_SUCCESS, 400, JSON.stringify({"success": false, "error": {"code": "SHOP_STACK_LIMIT",
		"message": "stack", "details": {"itemId": "drill_bomb", "owned": 90, "maxStack": 99, "maxQuantity": 9}}}).to_utf8_buffer())
	eq([res.code, int(res.details["maxQuantity"])], ["SHOP_STACK_LIMIT", 9], "the error's details")
	eq(ErrorText.purchase(res, "coin"), "Kho đồ chỉ còn chỗ cho 9", "how many still fit")
	res.details["maxQuantity"] = 0
	eq(ErrorText.purchase(res, "coin"), "Kho đồ đã đầy vật phẩm này", "full")
	var plain := ApiResponse.parse(HTTPRequest.RESULT_SUCCESS, 409, JSON.stringify({"error": {"code": "X", "message": "m"}}).to_utf8_buffer())
	check(not plain.has("details"), "no details: none added")
