extends Control
## "Túi đồ": everything the player owns, in two tabs.
## - "Trang bị": the owned pieces (PlayerState.equipment + the catalog) as a grid of cards showing
##   only the icon and the name in the level colour inside the border aura, the card tinted in
##   that colour (worn pieces: green edge and a check badge), worn ones first then by required
##   level; slot filter chips on top. A tap opens the piece popup with everything else
##   (equipment_ui.gd) for the character chosen in the lobby: worn → Chuyển cho <nhân vật> /
##   Nâng cấp / Tháo, not worn → Mặc cho <nhân vật> / Bán / Vứt, closed by its X.
## - "Vật phẩm": the eight battle items with their GET /player/inventory counts.
## - "Nguyên liệu": the upgrade stones owned (PlayerState.stones): icon, level, power, count;
##   "Mua đá" (Shop → Đá nâng cấp) and "Ghép đá" (the Nâng cấp page's Ghép đá).
## - "Rương": the chests owned (PlayerState.chests, GET /chests): icon, name, count, the odds
##   (ChestModel.odds_text: the game data's) and "Mở" / "Mở 10" (POST /chests/open, one open at a
##   time); the result opens a popup listing the stones and pieces received.
## Each tab loads the first time it is shown; failures show inline with "Thử lại". Upgraded
## pieces show their milestone aura and their name in the milestone colour.

signal open_shop(section: int)
signal open_upgrade(equipment_id: String, section: int)

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const Items := preload("res://match/items.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const EquipmentUi := preload("res://screens/home/equipment_ui.gd")
const ShopTab := preload("res://screens/home/shop_tab.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const UpgradeAura := preload("res://screens/home/upgrade_aura.gd")
const Fmt := preload("res://core/fmt.gd")
const ChestModel := preload("res://screens/home/chest_model.gd")
const ChestIcon := preload("res://ui/chest_icon.gd")
const Modal := preload("res://ui/modal.gd")

const SUB_TABS := ["Trang bị", "Vật phẩm", "Nguyên liệu", "Rương"]
const EQUIPMENT := 0
const ITEMS := 1
const MATERIALS := 2
const CHESTS := 3
## The Nâng cấp page's Ghép đá tab (upgrade_page.gd MERGE).
const UPGRADE_MERGE := 1
const CARD := Vector2(208, 196)

## Where dialogs and toasts go (Home); defaults to this page.
var overlay: Control
## Returns the characterId chosen in the lobby (the one "Mặc cho" dresses); Home sets it.
var lobby_character: Callable

var _sub := EQUIPMENT
var _slot := "" # "" = every slot
var _armed := false
var _inventory: Variant = null # itemId -> count, null until loaded
var _inv_stale := false
var _inv_loading := false
var _inv_gen := 0

var _sub_tabs: Array[Button]
var _pages: Array[Control] = []
var _chips: Array[Button]
var _gear_status: LoadStatus
var _gear_flow: HFlowContainer
var _gear_hint: Label
var _inv_status: LoadStatus
var _inv_flow: HFlowContainer
var _stone_status: LoadStatus
var _stone_flow: HFlowContainer
var _chest_status: LoadStatus
var _chest_flow: HFlowContainer


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
	var pages := Control.new()
	pages.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(pages)
	for builder in [_build_gear_page, _build_items_page, _build_stones_page, _build_chests_page]:
		var page: Control = builder.call()
		page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		pages.add_child(page)
		_pages.append(page)

	PlayerState.equipment_changed.connect(_on_equipment_changed)
	PlayerState.characters_changed.connect(_on_equipment_changed)
	PlayerState.assets_dirty.connect(_on_assets_dirty)
	PlayerState.stones_changed.connect(_on_stones_changed)
	PlayerState.chests_changed.connect(_on_chests_changed)
	visibility_changed.connect(_ensure_loaded)
	show_section(EQUIPMENT)
	_render_gear()
	_render_inventory()
	_render_stones()
	_render_chests()
	_arm.call_deferred()


func _who() -> String:
	return str(lobby_character.call()) if lobby_character.is_valid() else LoadoutModel.default_character()


func show_section(index: int) -> void:
	_sub = index
	for i in _pages.size():
		_pages[i].visible = i == index
	Ui.select_tab(_sub_tabs, index)
	_ensure_loaded()


func _arm() -> void:
	_armed = true
	_ensure_loaded()


func _ensure_loaded() -> void:
	if not (_armed and is_visible_in_tree()):
		return
	if _sub == EQUIPMENT:
		PlayerState.need_equipment()
		PlayerState.need_characters() # the can-wear check
		_render_gear() # the lobby character may have changed
	elif _sub == MATERIALS:
		PlayerState.need_stones()
	elif _sub == CHESTS:
		PlayerState.need_chests()
	elif (_inventory == null or _inv_stale) and not _inv_loading:
		_load_inventory()


func _on_assets_dirty() -> void:
	if _inventory != null:
		_inv_stale = true
	_ensure_loaded()


## Deferred: a press inside the grid must not free its own card mid-signal.
func _on_equipment_changed() -> void:
	if is_inside_tree():
		_render_gear.call_deferred()


# ── Trang bị ────────────────────────────────────────────────────────────────

func _build_gear_page() -> Control:
	var col := Ui.vbox(12)
	var chips := Ui.hbox(8)
	col.add_child(chips)
	_chips = EquipmentUi.slot_chips(_on_slot)
	for c in _chips:
		chips.add_child(c)
	_gear_hint = LobbyUi.text("", 20, Ui.TEXT_DIM)
	_gear_hint.size_flags_horizontal = SIZE_EXPAND_FILL
	_gear_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gear_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chips.add_child(_gear_hint)
	_gear_status = LoadStatus.new()
	col.add_child(_gear_status)
	_gear_flow = HFlowContainer.new()
	_gear_flow.add_theme_constant_override("h_separation", 14)
	_gear_flow.add_theme_constant_override("v_separation", 14)
	var scroll := Ui.scroll(_gear_flow)
	col.add_child(scroll)
	return col


func _on_slot(slot: String) -> void:
	_slot = slot
	_render_gear()


func _render_gear() -> void:
	if _gear_flow == null:
		return
	var error := PlayerState.catalog_error if PlayerState.catalog_error != "" else PlayerState.equipment_error
	if error != "":
		_gear_status.show_error(error, PlayerState.retry_equipment)
	elif PlayerState.equipment == null or PlayerState.catalog == null:
		_gear_status.show_loading()
	else:
		_gear_status.clear()
	EquipmentUi.select_chip(_chips, _slot)
	var who := _who()
	_gear_hint.text = "Chạm để mặc cho %s" % EquipmentModel.character_name(who)
	Ui.clear(_gear_flow)
	if PlayerState.equipment == null:
		return
	var pieces := EquipmentModel.filter_slot(EquipmentModel.sort_bag(PlayerState.equipment, PlayerState.catalog), _slot)
	if pieces.is_empty():
		var empty := Ui.vbox(12)
		empty.add_child(LobbyUi.text("Chưa có trang bị nào" if _slot == "" else "Chưa có %s nào" % EquipmentModel.slot_name(_slot).to_lower(), 24, Ui.TEXT_DIM))
		var shop := Ui.button("Mua ở Shop", 22)
		shop.custom_minimum_size = Vector2(240, 60)
		shop.focus_mode = FOCUS_NONE
		shop.size_flags_horizontal = SIZE_SHRINK_BEGIN
		shop.pressed.connect(func(): open_shop.emit(ShopTab.EQUIPMENT))
		empty.add_child(shop)
		_gear_flow.add_child(empty)
		return
	for p in pieces:
		_gear_flow.add_child(_gear_card(p))


## A piece card: only its icon and its name in the level colour, inside the border aura with the
## card tinted a deep shade of that colour (worn pieces: a green edge and a check badge in the
## top-left corner); everything else is in the popup a tap opens.
func _gear_card(piece: Dictionary) -> Control:
	var item := EquipmentModel.item_of_piece(PlayerState.catalog, piece)
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.focus_mode = FOCUS_NONE
	LobbyUi.style_button(b, Ui.CARD_BG, 16, 8, Color(1, 1, 1, 0.1), 2)
	if EquipmentModel.wearer(piece) != "":
		LobbyUi.style_button(b, Color(0.1, 0.2, 0.36, 0.9), 16, 8, Color(0.35, 0.8, 0.45, 0.8), 2)
	b.pressed.connect(func(): EquipmentUi.open_piece(overlay, piece, _who()))
	# The milestone aura runs round the card's border, inside it (the grid scrolls).
	b.add_child(UpgradeAura.inside(CARD, int(piece.get("upgradeLevel", 0)), 11.0, 11.0))
	var col := Ui.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 14
	col.offset_bottom = -16
	col.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := EquipmentUi.item_icon(item, {}, 112)
	icon.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(icon)
	var title := LobbyUi.text(EquipmentModel.display_name(item), 23, UpgradeModel.name_color(piece), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = MOUSE_FILTER_IGNORE
	LobbyUi.outline(title, 5) # readable over the aura's streaks
	col.add_child(title)
	if EquipmentModel.wearer(piece) != "":
		# Worn: a check badge in the top-left corner (the green edge alone is lost on a tinted card).
		var badge := EquipmentUi.worn_badge(30)
		badge.position = Vector2(8, 8)
		b.add_child(badge)
	return b


# ── Vật phẩm ────────────────────────────────────────────────────────────────

func _build_items_page() -> Control:
	var col := Ui.vbox(14)
	_inv_status = LoadStatus.new()
	col.add_child(_inv_status)
	_inv_flow = HFlowContainer.new()
	_inv_flow.add_theme_constant_override("h_separation", 12)
	_inv_flow.add_theme_constant_override("v_separation", 12)
	col.add_child(_inv_flow)
	return Ui.scroll(col)


func _load_inventory() -> void:
	_inv_gen += 1
	var gen := _inv_gen
	_inv_stale = false
	_inv_loading = true
	_inv_status.show_loading()
	var res: Dictionary = await Api.get_json("/player/inventory")
	if not is_inside_tree() or gen != _inv_gen:
		return
	_inv_loading = false
	var counts = LoadoutModel.parse_inventory(res.data) if res.ok else null
	if counts is Dictionary:
		_inventory = counts
		_inv_status.clear()
	else:
		_inv_status.show_error(ErrorText.load_failed(res) if not res.ok else "Dữ liệu kho đồ không hợp lệ", _load_inventory)
	_render_inventory()


func _render_inventory() -> void:
	Ui.clear(_inv_flow)
	for id in Items.order():
		var n := int(_inventory.get(id, 0)) if _inventory is Dictionary else -1
		var card := Ui.card(Ui.CARD_BG, 18)
		card.custom_minimum_size = Vector2(270, 120)
		var row := Ui.hbox(12)
		card.add_child(row)
		row.add_child(LobbyUi.icon(Art.item_icon(id), 64))
		var box := Ui.vbox(6)
		row.add_child(box)
		box.add_child(Ui.text(Items.label(id), 26))
		box.add_child(Ui.text("x%d" % n if n >= 0 else "x—", 26, Ui.TONES["draw"]))
		if n == 0:
			card.modulate = Color(1, 1, 1, 0.4)
		_inv_flow.add_child(card)


# ── Nguyên liệu ─────────────────────────────────────────────────────────────

func _build_stones_page() -> Control:
	var col := Ui.vbox(14)
	var top := Ui.hbox(12)
	col.add_child(top)
	var title := LobbyUi.text("Đá nâng cấp", 26, Color.WHITE, true)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	for spec in [["Ghép đá", func(): open_upgrade.emit("", UPGRADE_MERGE)], ["Mua đá", func(): open_shop.emit(ShopTab.STONES)]]:
		var b := Ui.button(spec[0], 22)
		b.custom_minimum_size = Vector2(180, 56)
		b.focus_mode = FOCUS_NONE
		b.pressed.connect(spec[1])
		top.add_child(b)
	_stone_status = LoadStatus.new()
	col.add_child(_stone_status)
	_stone_flow = HFlowContainer.new()
	_stone_flow.add_theme_constant_override("h_separation", 12)
	_stone_flow.add_theme_constant_override("v_separation", 12)
	col.add_child(_stone_flow)
	return Ui.scroll(col)


func _on_stones_changed() -> void:
	if is_inside_tree():
		_render_stones.call_deferred()


func _render_stones() -> void:
	if _stone_flow == null:
		return
	if PlayerState.stones_error != "":
		_stone_status.show_error(PlayerState.stones_error, PlayerState.load_stones)
	elif PlayerState.stones == null:
		_stone_status.show_loading()
	else:
		_stone_status.clear()
	Ui.clear(_stone_flow)
	if PlayerState.stones == null:
		return
	var levels := UpgradeModel.owned_levels(PlayerState.stones)
	if levels.is_empty():
		_stone_flow.add_child(LobbyUi.text("Chưa có đá nâng cấp — mua ở Shop → Đá nâng cấp", 24, Ui.TEXT_DIM))
		return
	for lv in levels:
		var card := Ui.card(Ui.CARD_BG, 16)
		card.custom_minimum_size = Vector2(270, 120)
		var row := Ui.hbox(12)
		card.add_child(row)
		row.add_child(LobbyUi.icon(Art.stone_icon(int(lv)), 80))
		var box := Ui.vbox(2)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(box)
		box.add_child(Ui.text(UpgradeModel.stone_name(int(lv)), 24))
		box.add_child(Ui.text("x%s" % Fmt.thousands(int(PlayerState.stones[lv])), 26, Ui.TONES["draw"]))
		box.add_child(Ui.text("Sức mạnh %s" % Fmt.thousands(UpgradeModel.power(PlayerState.catalog, int(lv))), 18, Ui.TEXT_DIM))
		_stone_flow.add_child(card)


# ── Rương ───────────────────────────────────────────────────────────────────

func _build_chests_page() -> Control:
	var col := Ui.vbox(14)
	_chest_status = LoadStatus.new()
	col.add_child(_chest_status)
	_chest_flow = HFlowContainer.new()
	_chest_flow.add_theme_constant_override("h_separation", 14)
	_chest_flow.add_theme_constant_override("v_separation", 14)
	col.add_child(_chest_flow)
	return Ui.scroll(col)


## Deferred: a press inside the list must not free its own card mid-signal.
func _on_chests_changed() -> void:
	if is_inside_tree():
		_render_chests.call_deferred()


func _render_chests() -> void:
	if _chest_flow == null:
		return
	if PlayerState.chests_error != "":
		_chest_status.show_error(PlayerState.chests_error, PlayerState.load_chests)
	elif PlayerState.chests == null:
		_chest_status.show_loading()
	else:
		_chest_status.clear()
	Ui.clear(_chest_flow)
	if not PlayerState.chests is Array:
		return
	if PlayerState.chests.is_empty():
		_chest_flow.add_child(LobbyUi.text("Chưa có rương nào — nhận rương từ Boss, thưởng mùa và mốc thưởng", 24, Ui.TEXT_DIM))
		return
	for c in PlayerState.chests:
		_chest_flow.add_child(_chest_card(c))


## A chest card: its icon, name and count, the odds under them, the open buttons on the right.
func _chest_card(c: Dictionary) -> Control:
	var card := Ui.card(Ui.CARD_BG, 16)
	card.name = "Chest_" + str(c["chestId"])
	card.custom_minimum_size = Vector2(660, 150)
	var row := Ui.hbox(16)
	card.add_child(row)
	var icon := ChestIcon.make(str(c["chestId"]), 104)
	icon.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(icon)
	var box := Ui.vbox(4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(box)
	var head := Ui.hbox(10)
	box.add_child(head)
	head.add_child(LobbyUi.text(str(c["name"]), 26, Color.WHITE, true))
	var count := LobbyUi.text(ChestModel.count_text(int(c["quantity"])), 26, Ui.TONES["draw"], true)
	count.name = "Count"
	head.add_child(count)
	var odds := LobbyUi.text(ChestModel.odds_text(str(c["chestId"])), 19, Ui.TEXT_DIM)
	odds.name = "Odds"
	odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(odds)
	var buttons := Ui.vbox(8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buttons)
	for spec in ChestModel.open_buttons(int(c["quantity"])):
		var b := Ui.button(str(spec["text"]), 22)
		b.name = "Open%d" % int(spec["count"])
		b.custom_minimum_size = Vector2(130, 54)
		b.focus_mode = FOCUS_NONE
		b.disabled = PlayerState.chest_busy != ""
		b.pressed.connect(_open_chest.bind(str(c["chestId"]), int(spec["count"])))
		buttons.add_child(b)
	return card


func _open_chest(chest_id: String, count: int) -> void:
	var res: Dictionary = await PlayerState.open_chest(chest_id, count)
	if not is_inside_tree():
		return
	if not res.ok:
		Ui.toast(overlay, ErrorText.chest(res))
		return
	var result := ChestModel.parse_open(res.data)
	if result.is_empty():
		return
	if str(result["chestId"]) == "":
		result["chestId"] = chest_id
	show_open_result(overlay, result)


## The "Mở rương" popup: "Mở 3 Rương đá", then one row per stone level and per piece (icon, text).
static func show_open_result(host: Control, result: Dictionary) -> Modal:
	var m := Modal.new()
	m.open(host, "Mở rương", 620)
	m.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var top := Ui.hbox(12)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	m.body.add_child(top)
	top.add_child(ChestIcon.make(str(result.get("chestId", "")), 72))
	var h := LobbyUi.text(ChestModel.opened_text(result), 26, Color(0.85, 0.92, 1.0), true)
	h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(h)
	var lines := ChestModel.open_lines(result, PlayerState.catalog)
	var columns := Ui.hbox(40)
	columns.name = "Lines"
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	m.body.add_child(columns)
	var per_column := ceili(lines.size() / 2.0) if lines.size() > 5 else lines.size()
	var column: VBoxContainer = null
	for i in lines.size():
		if i % maxi(1, per_column) == 0:
			column = Ui.vbox(10)
			columns.add_child(column)
		var line: Dictionary = lines[i]
		var r := Ui.hbox(12)
		if line["kind"] == "stone":
			r.add_child(LobbyUi.icon(Art.stone_icon(int(line["level"])), 52))
		else:
			var item := EquipmentModel.item_of(PlayerState.catalog, str(line["itemId"]))
			r.add_child(EquipmentUi.item_icon(item, {"upgradeLevel": int(line["upgradeLevel"])}, 52))
		var l := LobbyUi.text(str(line["text"]), 24, Color.WHITE, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.add_child(l)
		column.add_child(r)
	if lines.is_empty():
		var none := LobbyUi.text("Rương trống", 22, Ui.TEXT_DIM)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.body.add_child(none)
	m.add_button("Tuyệt!", m.close)
	return m
