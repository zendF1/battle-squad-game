extends Control
## "Shop": five sub-tabs.
## - "Vật phẩm": item offers (GET /shop/offers) with "Còn N lượt" from GET /shop/purchases;
## - "Trang bị": the equipment the catalog sells (PlayerState.catalog, active normal items with a
##   price): the gear shared by every character plus the weapons of the lobby's character only
##   ("Vũ khí của Rookie"), filtered by slot: icon, name, "Lv N", stats, price, "Đã có N"; "Mua" asks "Mua
##   <tên> với giá <giá>?", then PlayerState.buy_equipment() sends POST /shop/equipment/buy
##   {itemId, idempotencyKey} with the same key rules as the purchases below;
## - "Nhân vật": character_unlock offers per character, "Đã sở hữu" from GET /player/characters;
## - "Kim cương": GET /iap/products, "Nạp" → POST /iap/verify with a mock purchase token;
## - "Đổi xu": coin_pack offers (gem → coin): "10 [gem] → 1.000 [coin]", a bonus over the base
##   rate (ShopModel.COINS_PER_GEM) when there is one, "Đổi" ("Không đủ kim cương" and disabled
##   while the wallet is short) asks "Đổi 10 kim cương lấy 1.000 xu?" and buys the offer like
##   "Mua"; "Chưa có gói đổi" when the server sells none.
## "Mua" asks "Xác nhận mua", then PlayerState.buy() sends POST /shop/purchase {offerId,
## idempotencyKey}. The key (and the mock token) is reused until a definite answer
## (core/idempotency_keys.gd), so a retry after a network error or a 5xx can never charge twice;
## PlayerState settles it even when Home is freed mid-request. An answer replaying an earlier
## request shows "Giao dịch trước đã hoàn tất" instead of a new success. Each sub-tab loads its
## data the first time it is shown; owned characters come from the PlayerState cache shared with
## "Hồ sơ". Requests never block the screen; one purchase runs at a time.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const Modal := preload("res://ui/modal.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const Skills := preload("res://match/skills.gd")
const Items := preload("res://match/items.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const ShopModel := preload("res://screens/home/shop_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const IdempotencyKeys := preload("res://core/idempotency_keys.gd")
const Fmt := preload("res://core/fmt.gd")

const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const EquipmentUi := preload("res://screens/home/equipment_ui.gd")

const SUB_TABS := ["Vật phẩm", "Trang bị", "Nhân vật", "Kim cương", "Đổi xu"]
const ITEMS := 0
const EQUIPMENT := 1
const CHARACTERS := 2
const GEMS := 3
const EXCHANGE := 4
const SOURCES := {
	"offers": "/shop/offers",
	"purchases": "/shop/purchases",
	"products": "/iap/products",
}
## The sources each sub-tab needs ("characters", "equipment": the PlayerState caches).
const NEEDS := [["offers", "purchases"], ["equipment"], ["offers", "purchases", "characters"], ["products"], ["offers", "purchases"]]
const REPLAYED := "Giao dịch trước đã hoàn tất"

## Where dialogs and toasts go (the Home shell); defaults to this tab.
var overlay: Control
## The lobby's character (Home sets it): Trang bị sells its weapons.
var lobby_character: Callable

var _data := {} # source -> parsed data (absent until loaded)
var _errors := {} # source -> Vietnamese message of the last failed load
var _gen := {} # source -> number of the latest request; older answers are dropped
var _loading := {} # source -> true while its request runs
var _stale := {} # source -> true when the data shown predates an asset change
var _armed := false # loads start once Home has set which tab is shown
var _sub := ITEMS

var _sub_tabs: Array[Button]
var _load_status: LoadStatus
var _action_status: LoadStatus
var _pages: Array[Control] = []
var _flows: Array[HFlowContainer] = []
var _slot := "" # the Trang bị slot filter, "" = all
var _chips: Array[Button]
var _equipment_dirty := false # equipment changed while Trang bị was not shown
var _weapons_label: Label # "Vũ khí của Rookie"
var _equipment_character := "" # whose weapons the Trang bị cards show


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
		var page: Control = Ui.scroll(flow)
		if i == EQUIPMENT:
			var box := Ui.vbox(12)
			var chips := Ui.hbox(8)
			box.add_child(chips)
			_chips = EquipmentUi.slot_chips(_on_slot)
			for c in _chips:
				chips.add_child(c)
			var spacer := Control.new()
			spacer.size_flags_horizontal = SIZE_EXPAND_FILL
			chips.add_child(spacer)
			_weapons_label = Ui.text("", 22, Ui.TEXT_DIM)
			_weapons_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			chips.add_child(_weapons_label)
			box.add_child(page)
			page = box
		page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		pages.add_child(page)
		_pages.append(page)
		_flows.append(flow)

	PlayerState.assets_dirty.connect(_on_assets_dirty)
	PlayerState.characters_changed.connect(_on_characters_changed)
	PlayerState.busy_changed.connect(_on_busy_changed)
	PlayerState.equipment_changed.connect(_on_equipment_changed)
	PlayerState.changed.connect(_on_wallet_changed)
	visibility_changed.connect(_on_visibility_changed)
	_on_characters_changed() # whatever "Hồ sơ" or an earlier Home already loaded
	show_section(ITEMS)
	_arm.call_deferred()


## Only the Trang bị cards (and the load line) depend on the equipment; rendered when shown.
func _on_equipment_changed() -> void:
	if is_visible_in_tree() and _sub == EQUIPMENT:
		_render_status.call_deferred()
		_render_equipment.call_deferred()
	else:
		_equipment_dirty = true


## The "Đổi xu" buttons depend on the gem balance.
func _on_wallet_changed() -> void:
	_render_exchange.call_deferred()


func show_section(index: int) -> void:
	_sub = index
	if index == EQUIPMENT and (_equipment_dirty or _shop_character() != _equipment_character):
		_equipment_dirty = false
		_render_equipment()
	for i in _pages.size():
		_pages[i].visible = i == index
	Ui.select_tab(_sub_tabs, index)
	_render_status()
	_ensure_loaded()


## Loads what the shown sub-tab needs and has not got (or got before an asset change).
func _ensure_loaded() -> void:
	if _armed and is_visible_in_tree():
		_load_shown()


## Deferred from _ready(): Home hides the tabs it does not show right after adding them.
func _arm() -> void:
	_armed = true
	_ensure_loaded()


func _load_shown() -> void:
	for source in NEEDS[_sub]:
		if source == "characters":
			PlayerState.need_characters()
		elif source == "equipment":
			PlayerState.need_equipment()
		elif (not _data.has(source) or _stale.has(source)) and not _loading.has(source) and not _errors.has(source):
			_load(source)


# ── Loading ─────────────────────────────────────────────────────────────────

func _load(source: String) -> void:
	_gen[source] = int(_gen.get(source, 0)) + 1
	var gen: int = _gen[source]
	_errors.erase(source)
	_stale.erase(source)
	_loading[source] = true
	_render_status()
	var res: Dictionary = await Api.get_json(SOURCES[source])
	if not is_inside_tree() or gen != _gen[source]:
		return
	_loading.erase(source)
	var parsed = _parse(source, res.data) if res.ok else null
	if parsed != null:
		_data[source] = parsed
		if source == "purchases":
			PlayerState.note_purchases(parsed)
	else:
		_errors[source] = ErrorText.load_failed(res) if not res.ok else "Dữ liệu cửa hàng không hợp lệ"
	_render()


static func _parse(source: String, data: Variant) -> Variant:
	match source:
		"offers":
			return ShopModel.parse_offers(data)
		"purchases":
			return ShopModel.parse_purchases(data)
		"products":
			return ShopModel.parse_products(data)
	return null


func _reload_failed() -> void:
	for source in NEEDS[_sub]:
		if source == "characters":
			if PlayerState.characters_error != "":
				PlayerState.load_characters()
		elif source == "equipment":
			PlayerState.retry_equipment()
		elif _errors.has(source):
			_load(source)


func _on_assets_dirty() -> void:
	for source in ["offers", "purchases"]:
		if _data.has(source):
			_stale[source] = true
	_ensure_loaded()


func _on_visibility_changed() -> void:
	if is_visible_in_tree() and _sub == EQUIPMENT and (_equipment_dirty or _shop_character() != _equipment_character):
		_render_equipment()
	_ensure_loaded()


func _on_characters_changed() -> void:
	var owned = LoadoutModel.parse_characters(PlayerState.characters)
	if owned != null:
		_data["characters"] = owned
	_render()


func _render_status() -> void:
	if _load_status == null:
		return
	for source in NEEDS[_sub]:
		var error: String = _source_error(source)
		if error != "":
			_load_status.show_error(error, _reload_failed)
			return
	for source in NEEDS[_sub]:
		var missing := PlayerState.catalog == null or PlayerState.equipment == null if source == "equipment" else not _data.has(source)
		if missing:
			_load_status.show_loading()
			return
	_load_status.clear()


func _source_error(source: String) -> String:
	match source:
		"characters":
			return PlayerState.characters_error
		"equipment":
			return PlayerState.catalog_error if PlayerState.catalog_error != "" else PlayerState.equipment_error
	return _errors.get(source, "")


# ── Cards ───────────────────────────────────────────────────────────────────

func _render() -> void:
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
		var head := Ui.hbox(12)
		box.add_child(head)
		head.add_child(LobbyUi.icon(Art.item_icon(str(o.get("itemId", ""))), 56))
		var names := Ui.vbox(0)
		head.add_child(names)
		names.add_child(Ui.text(ShopModel.offer_name(o), 26))
		names.add_child(Ui.text("x%d" % int(o.get("quantity", 1)), 24, Ui.TONES["draw"]))
		_price(box, o)
		var left := ShopModel.remaining(o, _data["purchases"]) if _data.has("purchases") else ShopModel.UNLIMITED
		# The limit line is always reserved, so every card has the same height and the "Mua"
		# buttons line up.
		var note := Ui.text(ShopModel.remaining_text(left), 20, Ui.TEXT_DIM)
		note.custom_minimum_size.y = 28
		box.add_child(note)
		var buy := _action_button("Mua")
		buy.disabled = PlayerState.busy_id != "" or left == 0
		buy.pressed.connect(_on_buy.bind(o))
		box.add_child(buy)


func _on_slot(slot: String) -> void:
	_slot = slot
	_render_equipment()


## The lobby's character (Rookie when Home did not set it).
func _shop_character() -> String:
	return str(lobby_character.call()) if lobby_character.is_valid() else LoadoutModel.DEFAULT_CHARACTER


func _render_equipment() -> void:
	_equipment_dirty = false
	_equipment_character = _shop_character()
	if _weapons_label != null:
		_weapons_label.text = "Vũ khí của %s" % EquipmentModel.character_name(_equipment_character)
	var flow := _flows[EQUIPMENT]
	Ui.clear(flow)
	EquipmentUi.select_chip(_chips, _slot)
	if PlayerState.catalog == null:
		return
	var items := EquipmentModel.shop_items(PlayerState.catalog, _slot, _equipment_character)
	if items.is_empty():
		flow.add_child(_empty("Chưa có trang bị nào được bán"))
	for it in items:
		var box := _card(flow, Vector2(290, 0))
		var head := Ui.hbox(12)
		box.add_child(head)
		head.add_child(EquipmentUi.item_icon(it, {}, 76))
		var names := Ui.vbox(2)
		names.size_flags_horizontal = SIZE_EXPAND_FILL
		head.add_child(names)
		var title := Ui.text(EquipmentModel.display_name(it), 25)
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		names.add_child(title)
		names.add_child(Ui.text(EquipmentModel.slot_name(str(it.get("slot", ""))), 20, Ui.TEXT_DIM))
		names.add_child(Ui.text(EquipmentModel.required_text(it), 20, EquipmentUi.LEVEL))
		# Two stat lines are reserved, so the cards line up.
		var stats := Ui.vbox(0)
		stats.custom_minimum_size.y = 56
		box.add_child(stats)
		EquipmentUi.add_stat_lines(stats, it, 20)
		var p := EquipmentModel.price(it)
		LobbyUi.icon_text(box, ShopModel.currency_icon(p["currency"]), Fmt.thousands(p["amount"]), 26, Color.WHITE, false, 34)
		var note := Ui.text(EquipmentModel.owned_text(EquipmentModel.owned_count(PlayerState.equipment, str(it["itemId"]))), 20, Ui.TONES["good"])
		note.custom_minimum_size.y = 28
		box.add_child(note)
		var buy := _action_button("Mua")
		buy.disabled = PlayerState.busy_id != ""
		buy.pressed.connect(_on_buy_equipment.bind(it))
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
		var head := Ui.hbox(12)
		box.add_child(head)
		head.add_child(LobbyUi.icon(Art.portrait(id), 64))
		var title := Ui.text(g["name"], 30)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(title)
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
			LobbyUi.set_icon(buy, ShopModel.currency_icon(str(o.get("priceCurrency", ""))), 34)
			var left := ShopModel.remaining(o, _data["purchases"]) if _data.has("purchases") else ShopModel.UNLIMITED
			buy.disabled = PlayerState.busy_id != "" or left == 0
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
		var title_row := CenterContainer.new()
		box.add_child(title_row)
		LobbyUi.icon_text(title_row, "gem", ShopModel.product_amount(p), 34, Color.WHITE, false, 44)
		var bonus := Ui.label(ShopModel.product_bonus(p), 22)
		bonus.add_theme_color_override("font_color", Ui.TONES["good"])
		bonus.custom_minimum_size.y = 30 # keeps the cards aligned without a bonus
		box.add_child(bonus)
		box.add_child(Ui.label(ShopModel.product_price(p), 26))
		var top_up := _action_button("Nạp")
		top_up.disabled = PlayerState.busy_id != ""
		top_up.pressed.connect(_on_top_up.bind(p))
		box.add_child(top_up)


func _render_exchange() -> void:
	var flow := _flows[EXCHANGE]
	Ui.clear(flow)
	if not _data.has("offers"):
		return
	var packs := ShopModel.coin_packs(_data["offers"])
	if packs.is_empty():
		flow.add_child(_empty("Chưa có gói đổi"))
	for o in packs:
		# Wide enough for "500 → 50.000" and "Không đủ kim cương": every card the same width.
		var box := _card(flow, Vector2(340, 0))
		var rate := HBoxContainer.new()
		rate.alignment = BoxContainer.ALIGNMENT_CENTER
		rate.add_theme_constant_override("separation", 10)
		box.add_child(rate)
		LobbyUi.icon_text(rate, "gem", ShopModel.price_text(o), 30, Color.WHITE, false, 40)
		rate.add_child(LobbyUi.icon("arrow_right", 30))
		LobbyUi.icon_text(rate, "coin", ShopModel.coin_pack_amount(o), 30, Color.WHITE, false, 40)
		var bonus := Ui.label(ShopModel.coin_pack_bonus(o), 22)
		bonus.add_theme_color_override("font_color", Ui.TONES["good"])
		bonus.custom_minimum_size.y = 30 # keeps the cards aligned without a bonus
		box.add_child(bonus)
		var left := ShopModel.remaining(o, _data["purchases"]) if _data.has("purchases") else ShopModel.UNLIMITED
		if left != ShopModel.UNLIMITED: # the seeded packs have no limit; an admin may add one
			box.add_child(Ui.text(ShopModel.remaining_text(left), 20, Ui.TEXT_DIM))
		var wallet_known := PlayerState.is_loaded()
		var gem := PlayerState.gem() if wallet_known else 0
		var swap := _action_button(ShopModel.coin_pack_button(o, gem, wallet_known))
		swap.disabled = PlayerState.busy_id != "" or left == 0 or (wallet_known and not ShopModel.can_afford(o, gem))
		swap.pressed.connect(_on_buy.bind(o))
		box.add_child(swap)


## The price: the currency icon and the amount.
func _price(box: Control, offer: Dictionary) -> void:
	LobbyUi.icon_text(box, ShopModel.currency_icon(str(offer.get("priceCurrency", ""))), ShopModel.price_text(offer), 26, Color.WHITE, false, 34)


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
	if PlayerState.busy_id != "":
		return
	var swap := ShopModel.is_coin_pack(offer)
	var m := Modal.new()
	m.open(overlay, "Xác nhận đổi" if swap else "Xác nhận mua")
	m.add_text(ShopModel.confirm_text(offer))
	m.add_button("Huỷ", m.close)
	m.add_button("Đổi" if swap else "Mua", _confirm_buy.bind(m, offer))


func _confirm_buy(m: Modal, offer: Dictionary) -> void:
	m.close()
	_purchase(offer)


func _purchase(offer: Dictionary) -> void:
	if PlayerState.busy_id != "":
		return
	var swap := ShopModel.is_coin_pack(offer)
	_action_status.show_loading(("Đang đổi lấy %s..." if swap else "Đang mua %s...") % ShopModel.offer_name(offer))
	var res: Dictionary = await PlayerState.buy(str(offer.get("offerId", "")))
	if not is_inside_tree():
		return
	if res.code == "BUSY":
		_action_status.clear()
		return
	if res.ok:
		_action_status.clear()
		if res.replay:
			Ui.toast(overlay, REPLAYED)
		else:
			Ui.toast(overlay, ShopModel.coin_pack_success(offer, res.data) if swap else "Mua thành công!")
		return
	var retry := _purchase.bind(offer) if not IdempotencyKeys.is_definite(res.status) else Callable()
	_action_status.show_error(ErrorText.purchase(res, str(offer.get("priceCurrency", ""))), retry)


func _on_buy_equipment(item: Dictionary) -> void:
	if PlayerState.busy_id != "":
		return
	var m := Modal.new()
	m.open(overlay, "Xác nhận mua")
	m.add_text(EquipmentModel.confirm_text(item))
	m.add_button("Huỷ", m.close)
	m.add_button("Mua", func():
		m.close()
		_purchase_equipment(item))


func _purchase_equipment(item: Dictionary) -> void:
	if PlayerState.busy_id != "":
		return
	_action_status.show_loading("Đang mua %s..." % EquipmentModel.display_name(item))
	var res: Dictionary = await PlayerState.buy_equipment(str(item.get("itemId", "")))
	if not is_inside_tree():
		return
	if res.code == "BUSY":
		_action_status.clear()
		return
	if res.ok:
		_action_status.clear()
		Ui.toast(overlay, REPLAYED if res.replay else "Mua thành công!")
		return
	var retry := _purchase_equipment.bind(item) if not IdempotencyKeys.is_definite(res.status) else Callable()
	_action_status.show_error(ErrorText.equipment_buy(res, EquipmentModel.price(item)["currency"]), retry)


func _on_top_up(product: Dictionary) -> void:
	if PlayerState.busy_id != "":
		return
	_action_status.show_loading("Đang nạp %s..." % ShopModel.product_title(product))
	var res: Dictionary = await PlayerState.top_up(str(product.get("productId", "")), ShopModel.iap_platform(OS.get_name()))
	if not is_inside_tree():
		return
	if res.code == "BUSY":
		_action_status.clear()
		return
	if res.ok:
		_action_status.clear()
		var granted := int(res.data.get("gemGranted", 0)) if res.data is Dictionary else 0
		if res.replay:
			Ui.toast(overlay, REPLAYED)
		else:
			Ui.toast(overlay, "Nạp thành công! +%d kim cương" % granted if granted > 0 else "Nạp thành công!")
		return
	var retry := _on_top_up.bind(product) if not IdempotencyKeys.is_definite(res.status) else Callable()
	_action_status.show_error(ErrorText.iap(res), retry)


## Deferred: the press that started a purchase must not free its own button mid-signal.
func _on_busy_changed() -> void:
	_render_cards.call_deferred()


func _render_cards() -> void:
	_render_status()
	_render_items()
	_render_equipment()
	_render_characters()
	_render_gems()
	_render_exchange()
