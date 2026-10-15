extends Control
## "Shop": three sub-tabs.
## - "Vật phẩm": item offers (GET /shop/offers) with "Còn N lượt" from GET /shop/purchases;
## - "Nhân vật": character_unlock offers per character, "Đã sở hữu" from GET /player/characters;
## - "Kim cương": GET /iap/products, "Nạp" → POST /iap/verify with a mock purchase token.
## "Mua" asks "Xác nhận mua", then POST /shop/purchase {offerId, idempotencyKey}. The key (and
## the mock token) is reused until a definite answer (core/idempotency_keys.gd), so a retry
## after a network error or a 5xx can never charge twice. Requests never block the screen; one
## purchase runs at a time.

const Ui := preload("res://ui/ui.gd")
const Modal := preload("res://ui/modal.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const Skills := preload("res://match/skills.gd")
const Items := preload("res://match/items.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const ShopModel := preload("res://screens/home/shop_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const IdempotencyKeys := preload("res://core/idempotency_keys.gd")

const SUB_TABS := ["Vật phẩm", "Nhân vật", "Kim cương"]
const ITEMS := 0
const CHARACTERS := 1
const GEMS := 2
const SOURCES := {
	"offers": "/shop/offers",
	"purchases": "/shop/purchases",
	"characters": "/player/characters",
	"products": "/iap/products",
}
## The sources each sub-tab needs before it can show anything useful.
const NEEDS := [["offers", "purchases"], ["offers", "characters"], ["products"]]

## Where dialogs and toasts go (the Home shell); defaults to this tab.
var overlay: Control

var _data := {} # source -> parsed data (absent until loaded)
var _errors := {} # source -> Vietnamese message of the last failed load
var _gen := {} # source -> number of the latest request; older answers are dropped
var _busy := "" # offerId or productId being bought
var _stale := false
var _sub := ITEMS

var _sub_tabs: Array[Button]
var _load_status: LoadStatus
var _action_status: LoadStatus
var _pages: Array[Control] = []
var _flows: Array[HFlowContainer] = []


func _ready() -> void:
	if overlay == null:
		overlay = self
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var col := Ui.vbox(12)
	margin.add_child(col)
	var tabs := Ui.hbox(8)
	col.add_child(tabs)
	_sub_tabs = Ui.tab_row(SUB_TABS, 24, show_section)
	for b in _sub_tabs:
		tabs.add_child(b)
	_load_status = LoadStatus.new()
	col.add_child(_load_status)
	_action_status = LoadStatus.new()
	col.add_child(_action_status)
	var pages := Control.new()
	pages.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(pages)
	for i in SUB_TABS.size():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 14)
		flow.add_theme_constant_override("v_separation", 14)
		var page := Ui.scroll(flow)
		page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		pages.add_child(page)
		_pages.append(page)
		_flows.append(flow)

	PlayerState.assets_dirty.connect(_on_assets_dirty)
	visibility_changed.connect(_on_visibility_changed)
	show_section(ITEMS)
	for source in SOURCES:
		_load(source)


func show_section(index: int) -> void:
	_sub = index
	for i in _pages.size():
		_pages[i].visible = i == index
	Ui.select_tab(_sub_tabs, index)
	_render_status()


# ── Loading ─────────────────────────────────────────────────────────────────

func _load(source: String) -> void:
	_gen[source] = int(_gen.get(source, 0)) + 1
	var gen: int = _gen[source]
	_errors.erase(source)
	_render_status()
	var res: Dictionary = await Api.get_json(SOURCES[source])
	if not is_inside_tree() or gen != _gen[source]:
		return
	var parsed = _parse(source, res.data) if res.ok else null
	if parsed != null:
		_data[source] = parsed
	else:
		_errors[source] = ErrorText.load_failed(res) if not res.ok else "Dữ liệu cửa hàng không hợp lệ"
	_render()


static func _parse(source: String, data: Variant) -> Variant:
	match source:
		"offers":
			return ShopModel.parse_offers(data)
		"purchases":
			return ShopModel.parse_purchases(data)
		"characters":
			return LoadoutModel.parse_characters(data)
		"products":
			return ShopModel.parse_products(data)
	return null


func _reload_failed() -> void:
	for source in NEEDS[_sub]:
		if _errors.has(source):
			_load(source)


func _on_assets_dirty() -> void:
	_stale = true
	if is_visible_in_tree():
		_reload_assets()


func _on_visibility_changed() -> void:
	if is_visible_in_tree() and _stale:
		_reload_assets()


func _reload_assets() -> void:
	_stale = false
	for source in ["offers", "purchases", "characters"]:
		_load(source)


func _render_status() -> void:
	if _load_status == null:
		return
	for source in NEEDS[_sub]:
		if _errors.has(source):
			_load_status.show_error(_errors[source], _reload_failed)
			return
	for source in NEEDS[_sub]:
		if not _data.has(source):
			_load_status.show_loading()
			return
	_load_status.clear()


# ── Cards ───────────────────────────────────────────────────────────────────

func _render() -> void:
	_render_status()
	_render_cards()


func _render_items() -> void:
	var flow := _flows[ITEMS]
	Ui.clear(flow)
	if not _data.has("offers"):
		return
	var offers := ShopModel.item_offers(_data["offers"])
	if offers.is_empty():
		flow.add_child(_empty("Chưa có vật phẩm nào được bán"))
	for o in offers:
		var box := _card(flow, Vector2(300, 0))
		box.add_child(Ui.text(ShopModel.offer_name(o), 26))
		box.add_child(Ui.text("x%d" % int(o.get("quantity", 1)), 24, Ui.TONES["draw"]))
		box.add_child(Ui.text(ShopModel.price_text(o), 26))
		var left := ShopModel.UNLIMITED
		if _data.has("purchases"):
			left = ShopModel.remaining(o, _data["purchases"])
			var note := ShopModel.remaining_text(left)
			if note != "":
				box.add_child(Ui.text(note, 20, Ui.TEXT_DIM))
		var buy := _action_button("Mua")
		buy.disabled = _busy != "" or left == 0
		buy.pressed.connect(_on_buy.bind(o))
		box.add_child(buy)


func _render_characters() -> void:
	var flow := _flows[CHARACTERS]
	Ui.clear(flow)
	if not _data.has("offers"):
		return
	var groups := ShopModel.character_groups(_data["offers"])
	if groups.is_empty():
		flow.add_child(_empty("Chưa có nhân vật nào được bán"))
	var owned: Variant = _data.get("characters")
	for g in groups:
		var id: String = g["characterId"]
		var box := _card(flow, Vector2(360, 0))
		box.add_child(Ui.text(g["name"], 30))
		var role := ""
		for c in LoadoutModel.CHARACTERS:
			if c["id"] == id:
				role = c["role"]
		var skill := Skills.for_character(id)
		var sub := Ui.text("%s · Kỹ năng: %s" % [role, skill.get("name", "")] if not skill.is_empty() else role, 20, Ui.TEXT_DIM)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(sub)
		if owned is Array and owned.has(id):
			var have := _action_button("Đã sở hữu")
			have.disabled = true
			box.add_child(have)
			continue
		for o in g["offers"]:
			var buy := _action_button(ShopModel.price_text(o))
			var left := ShopModel.remaining(o, _data["purchases"]) if _data.has("purchases") else ShopModel.UNLIMITED
			buy.disabled = _busy != "" or left == 0
			buy.pressed.connect(_on_buy.bind(o))
			box.add_child(buy)


func _render_gems() -> void:
	var flow := _flows[GEMS]
	Ui.clear(flow)
	if not _data.has("products"):
		return
	if _data["products"].is_empty():
		flow.add_child(_empty("Chưa có gói kim cương nào"))
	for p in _data["products"]:
		var box := _card(flow, Vector2(300, 0))
		box.add_child(Ui.label(ShopModel.product_title(p), 34))
		var bonus := Ui.label(ShopModel.product_bonus(p), 22)
		bonus.add_theme_color_override("font_color", Ui.TONES["good"])
		bonus.custom_minimum_size.y = 30 # keeps the cards aligned without a bonus
		box.add_child(bonus)
		box.add_child(Ui.label(ShopModel.product_price(p), 26))
		var top_up := _action_button("Nạp")
		top_up.disabled = _busy != ""
		top_up.pressed.connect(_on_top_up.bind(p))
		box.add_child(top_up)


func _card(flow: HFlowContainer, min_size: Vector2) -> VBoxContainer:
	var card := Ui.card(Ui.CARD_BG, 18)
	card.custom_minimum_size = min_size
	flow.add_child(card)
	var box := Ui.vbox(8)
	card.add_child(box)
	return box


func _action_button(text_value: String) -> Button:
	var b := Ui.button(text_value, 24)
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = FOCUS_NONE
	return b


static func _empty(message: String) -> Label:
	var l := Ui.label(message, 24)
	l.add_theme_color_override("font_color", Ui.TEXT_DIM)
	return l


# ── Buying ──────────────────────────────────────────────────────────────────

func _on_buy(offer: Dictionary) -> void:
	if _busy != "":
		return
	var m := Modal.new()
	m.open(overlay, "Xác nhận mua")
	m.add_text(ShopModel.confirm_text(offer))
	m.add_button("Huỷ", m.close)
	m.add_button("Mua", _confirm_buy.bind(m, offer))


func _confirm_buy(m: Modal, offer: Dictionary) -> void:
	m.close()
	_purchase(offer)


func _purchase(offer: Dictionary) -> void:
	if _busy != "":
		return
	var offer_id := str(offer.get("offerId", ""))
	var target := PlayerState.key_target(offer_id)
	var body := {"offerId": offer_id, "idempotencyKey": PlayerState.purchase_keys.key_for(target)}
	_set_busy(offer_id)
	_action_status.show_loading("Đang mua %s..." % ShopModel.offer_name(offer))
	var res: Dictionary = await Api.post_json("/shop/purchase", body)
	PlayerState.purchase_keys.settle(target, res.status)
	if not is_inside_tree():
		return
	_set_busy("")
	if res.ok:
		_action_status.clear()
		Ui.toast(overlay, "Mua thành công!")
		PlayerState.assets_changed()
		return
	var retry := _purchase.bind(offer) if not IdempotencyKeys.is_definite(res.status) else Callable()
	_action_status.show_error(ErrorText.purchase(res, str(offer.get("priceCurrency", ""))), retry)


func _on_top_up(product: Dictionary) -> void:
	if _busy != "":
		return
	var product_id := str(product.get("productId", ""))
	var target := PlayerState.key_target(product_id)
	var body := {
		"productId": product_id,
		"platform": ShopModel.iap_platform(OS.get_name()),
		"purchaseToken": PlayerState.iap_tokens.key_for(target),
	}
	_set_busy(product_id)
	_action_status.show_loading("Đang nạp %s..." % ShopModel.product_title(product))
	var res: Dictionary = await Api.post_json("/iap/verify", body)
	PlayerState.iap_tokens.settle(target, res.status)
	if not is_inside_tree():
		return
	_set_busy("")
	if res.ok:
		_action_status.clear()
		var granted := int(res.data.get("gemGranted", 0)) if res.data is Dictionary else 0
		Ui.toast(overlay, "Nạp thành công! +%d 💎" % granted if granted > 0 else "Nạp thành công!")
		PlayerState.refresh()
		return
	var retry := _on_top_up.bind(product) if not IdempotencyKeys.is_definite(res.status) else Callable()
	_action_status.show_error(ErrorText.iap(res), retry)


## Deferred: the press that started a purchase must not free its own button mid-signal.
func _set_busy(id: String) -> void:
	_busy = id
	_render_cards.call_deferred()


func _render_cards() -> void:
	_render_items()
	_render_characters()
	_render_gems()
