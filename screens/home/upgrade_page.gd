extends Control
## "Nâng cấp" (lobby shortcut, the piece popup's Nâng cấp, Kho đồ → Nguyên liệu → Ghép đá): two
## tabs.
## - "Nâng cấp": left, the owned pieces (slot chips, worn first, "+N" and the name in the
##   level colour, the aura from +1); centre, the selected piece's name, then the piece now and
##   after one more level side by side (UpgradeModel.preview: each on its hexagon with that
##   level's aura and tint, "+N" in its colour, its stats as points over the battle value, the
##   passive as its picture and value, the gains in green on the right; at +16 only the piece, centred, and "Đã đạt cấp tối đa"), what the
##   next level unlocks as pictures (GearModel.milestone_unlocks(): +10 bullet glow, +14 skill rank
##   up for a weapon, +16 the slot's awaken) and
##   what a failure does ("Thất bại: về +6" / "giữ nguyên +3"), all centred in the panel; right, the player's stones by level (icon, power, owned, − n +)
##   under "Đá nâng cấp" with "Tự chọn" (fills to the required power with the least stones,
##   UpgradeModel.auto_pick) / "Bỏ chọn" beside it, then the fill and the chance as separate things:
##   the gauge is the power loaded towards the required power C ("3.600 / 9.000", "Đã nạp 40%",
##   gold, green once full, orange with a whole stone to spare; the line under it warns of power
##   above C, the stones are still consumed) and never reads as the chance. The chance is the two
##   mirrored tiles under it: "Tỉ lệ thường" and "Tỉ lệ cẩn thận" with the maximum each reaches,
##   the one that will roll selected; tapping a tile picks it (one centred tile when the step has
##   no careful; "Thiếu kim cương" when the gems do not cover it; careful stays on between rolls
##   and turns off when another piece is picked). NÂNG CẤP is off with the reason under it (no
##   stones, stones too weak for even 0.01%, +16, not enough coin, not enough gems for careful, the
##   equipment or stones reloading; nothing under it when it can be pressed) and shows what the
##   attempt costs: coin icon + price (a weapon's is higher), then the careful gems. A careful
##   attempt, or one with a whole stone to spare, confirms first with a popup. The numbers are
##   UpgradeModel.chance(): the server's formula, also for an older catalog. The result plays on
##   the piece (success: flash, rings and sparkles, a bigger burst in the new colour when it reaches
##   a milestone; failure: red flash, shake, smoke) with a toast; the piece and the stones reload
##   (PlayerState).
## - "Ghép đá": pick a level (the stones with their owned ×N, the name only as the tooltip), ×2 /
##   ×3 / ×4 stones (the game data's merge counts), the stones ×N → the next one as pictures with
##   the chance (count × mergeRatePerItem %), GHÉP; the rules behind the "i"; the result animates on the new stone,
##   a success then plays the reward reveal of the new stone (ui/reward_reveal.gd). The stone
##   list shows each stone's icon (its look tells the level), the owned count by the bag icon and
##   its power by the upgrade arrow.
## - "Ghép ngọc" (shown when the catalog sends gems): the same layout for ngọc khảm: the four types
##   as their gems on top of the left panel, that type's levels below it (the gem, the free count),
##   the gem ×2 / ×3 / ×4 → the next level with the chance, GHÉP; a success plays the reward reveal
##   of the new gem, a failure the stones' failure effect. The highest level is the catalog's
##   (GemModel), the counts and the rate the game data's / catalog's.
## - "Chuyển hoá" (shown when the catalog prices transfers, TransferModel.offered()):
##   screens/home/transfer_page.gd, carry a level to another piece of the slot for kim cương khoá.
## Caps by tier (UpgradeModel.cap()): every list row shows the piece's cap mark (the padlock and
## "+6"); a piece at its cap shows alone in the centre with "Đã đạt trần +6", NÂNG CẤP is off and a
## Chuyển hoá button under the note opens that tab with the piece as the source.
## Loads the catalog, the pieces, the characters and the stones when shown; failures show inline
## with "Thử lại".

signal open_shop(section: int)

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const EquipmentUi := preload("res://screens/home/equipment_ui.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const UpgradeAura := preload("res://screens/home/upgrade_aura.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const Modal := preload("res://ui/modal.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const Fmt := preload("res://core/fmt.gd")
const RewardReveal := preload("res://ui/reward_reveal.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const GearModel := preload("res://screens/home/gear_model.gd")
const GearIcon := preload("res://ui/gear_icon.gd")
const GemModel := preload("res://screens/home/gem_model.gd")
const GemIcon := preload("res://ui/gem_icon.gd")
const TransferModel := preload("res://screens/home/transfer_model.gd")
const TransferPage := preload("res://screens/home/transfer_page.gd")

const SUB_TABS := ["Nâng cấp", "Ghép đá", "Ghép ngọc", "Chuyển hoá"]
const UPGRADE := 0
const MERGE := 1
const GEM_MERGE := 2
const TRANSFER := 3
## Shop sections of "Đá nâng cấp" and "Ngọc" (shop_tab.gd STONES / SOCKET_GEMS; not preloaded: the
## Shop preloads this page's neighbours).
const SHOP_STONES := 2
const SHOP_SOCKET_GEMS := 3

const LEFT_W := 430
const RIGHT_W := 480
## The hexagons of the piece now and after the upgrade, side by side, and their columns' width.
const FRAME := Vector2(136, 157)
const BIG_ICON := 96
const COL_W := 190
const DIM := Color(0.8, 0.88, 1.0)
const WARN := Color(1.0, 0.72, 0.3)
const BAD := Color(1.0, 0.45, 0.45)
const GOOD := Color(0.45, 0.9, 0.55)
## The careful chance tile's accent (the gem's cyan).
const GEM_CYAN := Color(0.3, 0.9, 1.0)
const CAREFUL_TITLE := "Nâng cấp cẩn thận"
const TILE_H := 96 # a chance tile
const TILE_BG := Color(0.08, 0.11, 0.26, 0.85)
const TILE_DIM := 0.62 # how a tile that will not roll shows

## Where dialogs and toasts go (Home); defaults to this page.
var overlay: Control

var _sub := UPGRADE
var _armed := false
var _slot := ""
var _piece_id := ""
var _picked := {} # stoneLevel -> quantity put in
var _acting := false # an upgrade or merge request (or its animation) runs
var _merge_level := 1
var _merge_count := UpgradeModel.merge_max()
var _careful := false # "Nâng cấp cẩn thận" on (kept between rolls, off for another piece)
var _scroll_to_selected := true # the next list render scrolls to the selected piece

var _sub_tabs: Array[Button]
var _pages: Array[Control] = []
var _status: LoadStatus
var _chips: Array[Button]
var _list: VBoxContainer
var _center: VBoxContainer
var _stone_list: VBoxContainer
var _fill_box: VBoxContainer # the gauge: P / C, the fill, the over-fill warning
var _fill_bar: ProgressBar
var _power_label: Label # "3.600 / 9.000"
var _fill_label: Label # "Đã nạp 40%": the fill, never the chance
var _over_label: Label
var _tiles: HBoxContainer # the two chance tiles, mirrored
var _normal_tile: Dictionary # {button, box, check, title, value, sub}
var _careful_tile: Dictionary
var _go_text: HBoxContainer # NÂNG CẤP [coin] 2.500 [gem] 120: the coin of a priced step, the gem when careful is on
var _go_coin: TextureRect
var _go_coin_price: Label
var _go_gem: TextureRect
var _go_price: Label
var _go: Button
var _reason: Label
var _auto: Button
var _clear: Button
# The big piece (centre), its aura and the effect layer over it.
var _frame: TextureRect
var _big_holder: Control
var _fx: Control
var _fx_t := 0.0
var _fx_kind := "" # "success", "milestone", "fail", "merge_ok", "merge_fail"
var _fx_color := Color.WHITE
var _fx_parts: Array = [] # [angle, speed, size] per particle, made when an effect starts
var _fx_text := "" # the word that pops over the piece ("THÀNH CÔNG", "THẤT BẠI", "ĐẠT MỐC +6")
# Merge tab
var _merge_levels: GridContainer
var _merge_from: TextureRect
var _merge_to: TextureRect
var _merge_times: Label
var _merge_to_holder: Control
var _merge_text: Label
var _merge_chance: Label
var _merge_count_tabs: Array[Button]
var _merge_go: Button
var _merge_reason: Label
var _merge_fx: Control
var _buy: Button # Mua đá / Mua ngọc
# Ghép ngọc tab
var _gem_type := ""
var _gem_level := 1
var _gem_count := UpgradeModel.merge_max()
var _gem_types: HBoxContainer
var _gem_levels: GridContainer
var _gem_from # ui/gem_icon.gd
var _gem_to # ui/gem_icon.gd
var _gem_times: Label
var _gem_to_holder: Control
var _gem_chance: Label
var _gem_count_tabs: Array[Button]
var _gem_go: Button
var _gem_reason: Label
var _gem_fx: Control
var _gem_acting := false
var _transfer: TransferPage # the Chuyển hoá tab


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
		b.size_flags_horizontal = SIZE_FILL
		b.custom_minimum_size.x = 220
		tabs.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var buy := _small_button("Mua đá", func(): open_shop.emit(SHOP_SOCKET_GEMS if _sub == GEM_MERGE else SHOP_STONES), 22)
	LobbyUi.style_button(buy, LobbyUi.ICON_COLORS["orange"], 14, 8)
	buy.add_theme_font_override("font", LobbyUi.bold())
	buy.custom_minimum_size = Vector2(180, 56)
	tabs.add_child(buy)
	_buy = buy
	_status = LoadStatus.new()
	col.add_child(_status)
	var pages := Control.new()
	pages.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(pages)
	for builder in [_build_upgrade_page, _build_merge_page, _build_gem_merge_page, _build_transfer_page]:
		var page: Control = builder.call()
		page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		pages.add_child(page)
		_pages.append(page)

	PlayerState.equipment_changed.connect(_on_data_changed)
	PlayerState.characters_changed.connect(_on_data_changed)
	PlayerState.stones_changed.connect(_on_data_changed)
	PlayerState.gems_changed.connect(_on_data_changed)
	PlayerState.changed.connect(_on_data_changed) # the gems the careful toggle needs
	visibility_changed.connect(_ensure_loaded)
	show_section(UPGRADE)
	_render.call_deferred()
	_arm.call_deferred()


func show_section(index: int) -> void:
	_sub = index
	if _buy != null:
		_buy.text = "Mua ngọc" if index == GEM_MERGE else "Mua đá"
	for i in _pages.size():
		_pages[i].visible = i == index
	Ui.select_tab(_sub_tabs, index)
	_render()


## Shows the Ghép ngọc tab on a gem type + level ("" keeps the current choice).
func select_gem(gem_type: String, gem_level: int) -> void:
	if gem_type != "":
		_gem_type = gem_type
		_gem_level = maxi(gem_level, 1)
	show_section(GEM_MERGE)
	_ensure_loaded()


## Shows the Chuyển hoá tab with a piece as the source ("" keeps the current choice).
func select_transfer(equipment_id: String) -> void:
	if _transfer != null:
		_transfer.select_source(equipment_id)
	show_section(TRANSFER)
	_ensure_loaded()


func _build_transfer_page() -> Control:
	_transfer = TransferPage.new()
	_transfer.overlay = overlay
	return _transfer


## Shows the Nâng cấp tab on a piece ("" keeps the current choice).
func select_piece(equipment_id: String) -> void:
	if equipment_id != "" and equipment_id != _piece_id:
		_piece_id = equipment_id
		_picked = {}
		_careful = false
		_slot = ""
	_scroll_to_selected = true
	show_section(UPGRADE)


func _arm() -> void:
	_armed = true
	_ensure_loaded()


func _ensure_loaded() -> void:
	if not (_armed and is_visible_in_tree()):
		return
	PlayerState.need_equipment()
	PlayerState.need_characters() # the stat multipliers
	PlayerState.need_stones()
	if _sub == GEM_MERGE:
		PlayerState.need_gems()
	_render()


## Deferred: a press inside a list must not free its own button mid-signal.
func _on_data_changed() -> void:
	if is_inside_tree():
		_render.call_deferred()


func _retry() -> void:
	PlayerState.retry_equipment()
	if PlayerState.stones_error != "":
		PlayerState.load_stones()
	if PlayerState.gems_error != "":
		PlayerState.load_gems()


func _owned() -> Dictionary:
	return PlayerState.stones if PlayerState.stones is Dictionary else {}


func _piece() -> Dictionary:
	return EquipmentModel.find_piece(PlayerState.equipment, _piece_id)


func _render() -> void:
	if _list == null:
		return
	var error := PlayerState.catalog_error if PlayerState.catalog_error != "" else PlayerState.equipment_error
	if error == "":
		error = PlayerState.stones_error
	if error == "" and _sub == GEM_MERGE:
		error = PlayerState.gems_error
	if _sub_tabs.size() > GEM_MERGE: # an older server's catalog has no gems: no Ghép ngọc
		_sub_tabs[GEM_MERGE].visible = PlayerState.catalog == null or GemModel.has_catalog(PlayerState.catalog) or _sub == GEM_MERGE
	if _sub_tabs.size() > TRANSFER: # an older server prices no transfer: no Chuyển hoá
		_sub_tabs[TRANSFER].visible = PlayerState.catalog == null or TransferModel.offered(PlayerState.catalog) or _sub == TRANSFER
	if _buy != null: # no gem shop on an older server; no stones to buy for a transfer
		_buy.visible = _sub != TRANSFER and (_sub != GEM_MERGE or PlayerState.catalog == null or GemModel.has_catalog(PlayerState.catalog))
	if error != "":
		_status.show_error(error, _retry)
	elif PlayerState.catalog == null or PlayerState.equipment == null or PlayerState.stones == null:
		_status.show_loading()
	else:
		_status.clear()
	_clamp_picked()
	if _sub == UPGRADE:
		_render_list()
		_render_center()
		_render_stones()
	elif _sub == MERGE:
		_render_merge()
	elif _sub == GEM_MERGE:
		_render_gem_merge()
	else:
		_transfer.overlay = overlay
		_transfer.render()


## Picked stones never exceed what is owned (after a reload).
func _clamp_picked() -> void:
	var owned := _owned()
	for lv in _picked.keys():
		_picked[lv] = mini(int(_picked[lv]), int(owned.get(lv, 0)))
		if int(_picked[lv]) <= 0:
			_picked.erase(lv)


static func _small_button(text_value: String, on_press: Callable, font_size: int = 20) -> Button:
	var b := Ui.button(text_value, font_size)
	b.custom_minimum_size = Vector2(0, 52)
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(on_press)
	return b


# ── Nâng cấp: left list ─────────────────────────────────────────────────────

func _build_upgrade_page() -> Control:
	var row := Ui.hbox(16)
	var left := LobbyUi.panel(14, 18)
	left.custom_minimum_size.x = LEFT_W
	row.add_child(left)
	var lcol := Ui.vbox(10)
	left.add_child(lcol)
	lcol.add_child(LobbyUi.text("Trang bị", 26, Color.WHITE, true))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	lcol.add_child(grid)
	_chips = EquipmentUi.slot_chips(_on_slot, 18, 40)
	for c in _chips:
		c.custom_minimum_size.x = 92
		grid.add_child(c)
	_list = Ui.vbox(8)
	lcol.add_child(Ui.scroll(_list))

	var center := LobbyUi.panel(18, 18)
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(center)
	_center = Ui.vbox(10)
	_center.alignment = BoxContainer.ALIGNMENT_CENTER # the content in the middle of the panel
	center.add_child(_center)
	_build_big_piece()

	var right := LobbyUi.panel(14, 18)
	right.custom_minimum_size.x = RIGHT_W
	row.add_child(right)
	var rcol := Ui.vbox(10)
	right.add_child(rcol)
	var head := Ui.hbox(8)
	rcol.add_child(head)
	var title := LobbyUi.text("Đá nâng cấp", 26, Color.WHITE, true)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	_auto = _small_button("Tự chọn", _on_auto, 18)
	_auto.custom_minimum_size = Vector2(112, 44)
	head.add_child(_auto)
	_clear = _small_button("Bỏ chọn", _on_clear, 18)
	_clear.custom_minimum_size = Vector2(112, 44)
	head.add_child(_clear)
	_stone_list = Ui.vbox(6)
	var scroll := Ui.scroll(_stone_list)
	rcol.add_child(scroll)
	rcol.add_child(_build_fill())
	rcol.add_child(_build_tiles())
	_go = LobbyUi.start_button("NÂNG CẤP")
	_go.custom_minimum_size = Vector2(0, 84)
	_go.add_theme_font_size_override("font_size", 34)
	_go.pressed.connect(_on_upgrade)
	rcol.add_child(_go)
	_go_text = Ui.hbox(10)
	_go_text.name = "GoPriced"
	_go_text.alignment = BoxContainer.ALIGNMENT_CENTER
	_go_text.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_go_text.offset_bottom = -6 # over the lip, like the button's own text
	_go_text.mouse_filter = MOUSE_FILTER_IGNORE
	var go_word := Ui.text("NÂNG CẤP", 28, LobbyUi.TEXT_DARK)
	go_word.add_theme_font_override("font", LobbyUi.bold())
	go_word.mouse_filter = MOUSE_FILTER_IGNORE
	_go_text.add_child(go_word)
	_go_coin = LobbyUi.icon("coin", 28)
	_go_text.add_child(_go_coin)
	_go_coin_price = Ui.text("", 25, LobbyUi.TEXT_DARK)
	_go_coin_price.add_theme_font_override("font", LobbyUi.bold())
	_go_coin_price.mouse_filter = MOUSE_FILTER_IGNORE
	_go_text.add_child(_go_coin_price)
	_go_gem = LobbyUi.icon("gem", 28)
	_go_text.add_child(_go_gem)
	_go_price = Ui.text("", 25, LobbyUi.TEXT_DARK)
	_go_price.add_theme_font_override("font", LobbyUi.bold())
	_go_price.mouse_filter = MOUSE_FILTER_IGNORE
	_go_text.add_child(_go_price)
	_go_text.visible = false
	_go.add_child(_go_text)
	_reason = LobbyUi.text("", 18, Ui.TEXT_DIM)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.custom_minimum_size.y = 24
	rcol.add_child(_reason)
	return row


## The gauge: the power line (P / C, the fill) over the bar, the over-fill warning under it.
func _build_fill() -> VBoxContainer:
	_fill_box = Ui.vbox(4)
	_fill_box.name = "Fill"
	var line := Ui.hbox(6)
	_fill_box.add_child(line)
	var icon := LobbyUi.icon("upgrade", 24)
	icon.size_flags_vertical = SIZE_SHRINK_CENTER
	line.add_child(icon)
	_power_label = LobbyUi.text("", 22, Color.WHITE, true)
	_power_label.name = "Power"
	_power_label.size_flags_horizontal = SIZE_EXPAND_FILL
	line.add_child(_power_label)
	_fill_label = LobbyUi.text("", 19, DIM, true)
	_fill_label.name = "FillText"
	_fill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(_fill_label)
	_fill_bar = Ui.bar(0.0, 18)
	_fill_bar.name = "FillBar"
	_fill_bar.add_theme_stylebox_override("background", LobbyUi.box(Color(0, 0, 0, 0.45), 9, 0, Color(1, 1, 1, 0.15), 1))
	_fill_box.add_child(_fill_bar)
	_over_label = LobbyUi.text("", 17, WARN, true)
	_over_label.name = "Over"
	_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_label.visible = false
	_fill_box.add_child(_over_label)
	return _fill_box


## The chance tiles: normal and careful, equal and mirrored around the centre; _render_tiles()
## fills them, a tap picks the one that rolls.
func _build_tiles() -> HBoxContainer:
	_tiles = Ui.hbox(10)
	_tiles.name = "Chances"
	_normal_tile = _chance_tile("Normal", "Tỉ lệ thường", _on_careful.bind(false))
	_tiles.add_child(_normal_tile["button"])
	_careful_tile = _chance_tile("Careful", "Tỉ lệ cẩn thận", _on_careful.bind(true))
	_tiles.add_child(_careful_tile["button"])
	return _tiles


## A chance tile: a radio box and its title over the chance, the maximum under it.
func _chance_tile(node_name: String, title_text: String, on_press: Callable) -> Dictionary:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(0, TILE_H)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(on_press)
	var col := Ui.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	col.offset_bottom = -6
	col.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(col)
	var top := Ui.hbox(6)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(top)
	var box := PanelContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(22, 22)
	box.size_flags_vertical = SIZE_SHRINK_CENTER
	box.mouse_filter = MOUSE_FILTER_IGNORE
	top.add_child(box)
	var check := LobbyUi.icon("check", 18)
	check.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(check)
	var title := LobbyUi.text(title_text, 18, Color.WHITE, true)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	top.add_child(title)
	var value := LobbyUi.text("", 32, Color.WHITE, true)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(value)
	var sub := LobbyUi.text("", 15, DIM)
	sub.name = "Sub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(sub)
	return {"button": b, "box": box, "check": check, "title": title, "value": value, "sub": sub}


func _on_careful(on: bool) -> void:
	if _acting or _careful == on:
		return
	_careful = on
	_render_chance()


## The player's gems, -1 before the profile loads (the server checks then).
func _gems() -> int:
	return PlayerState.gem() if not PlayerState.profile.is_empty() else -1


## The player's coin, -1 before the profile loads (the server checks then).
func _coins() -> int:
	return PlayerState.coin() if not PlayerState.profile.is_empty() else -1


func _on_slot(slot: String) -> void:
	_slot = slot
	_render_list()


func _render_list() -> void:
	EquipmentUi.select_chip(_chips, _slot)
	Ui.clear(_list)
	if PlayerState.equipment == null:
		return
	var all := EquipmentModel.sort_bag(PlayerState.equipment, PlayerState.catalog)
	if _piece().is_empty() and not all.is_empty():
		_piece_id = str(all[0].get("equipmentId", ""))
		_picked = {}
		_careful = false
	var pieces := EquipmentModel.filter_slot(all, _slot)
	if pieces.is_empty():
		_list.add_child(LobbyUi.text("Chưa có trang bị nào" if _slot == "" else "Chưa có %s nào" % EquipmentModel.slot_name(_slot).to_lower(), 22, Ui.TEXT_DIM))
		return
	var selected: Control = null
	for p in pieces:
		var row := _piece_row(p)
		_list.add_child(row)
		if str(p.get("equipmentId", "")) == _piece_id:
			selected = row
	if selected != null and _scroll_to_selected:
		_scroll_to_selected = false
		_ensure_visible.call_deferred(selected)


## Scrolls the piece list so `row` shows (after a selection from outside the list).
## Untyped: the row may be freed (the list re-rendered) before the deferred call lands.
func _ensure_visible(row: Variant) -> void:
	if not is_instance_valid(row):
		return
	for i in 2:
		await get_tree().process_frame # the list's layout first
	if is_instance_valid(row) and row.is_inside_tree():
		(_list.get_parent() as ScrollContainer).ensure_control_visible(row)


func _piece_row(piece: Dictionary) -> Control:
	var id := str(piece.get("equipmentId", ""))
	return EquipmentUi.piece_row(piece, id == _piece_id, _on_pick_piece.bind(id))




func _on_pick_piece(id: String) -> void:
	if _acting or id == _piece_id:
		return
	_piece_id = id
	_picked = {}
	_careful = false
	_render.call_deferred()


# ── Nâng cấp: centre ────────────────────────────────────────────────────────

func _build_big_piece() -> void:
	# The big piece is built once (its aura keeps animating); _render_center() fills it.
	_big_holder = Control.new()
	_big_holder.custom_minimum_size = FRAME
	_big_holder.size_flags_horizontal = SIZE_SHRINK_CENTER
	_big_holder.mouse_filter = MOUSE_FILTER_IGNORE
	_frame = TextureRect.new()
	_frame.texture = Art.equipment_frame("hex_filled")
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_frame.size = FRAME
	_frame.mouse_filter = MOUSE_FILTER_IGNORE
	_big_holder.add_child(_frame)
	_fx = Control.new()
	_fx.size = FRAME
	_fx.mouse_filter = MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx.bind(_fx))
	_big_holder.add_child(_fx)


func _render_center() -> void:
	# The big piece holder survives (its aura keeps animating, the effects play on it): take it
	# out of the old layout before that is freed.
	if _big_holder.get_parent() != null:
		_big_holder.get_parent().remove_child(_big_holder)
	Ui.clear(_center)
	var piece := _piece()
	# The icon inside the frame (rebuilt: another piece or level).
	for c in _frame.get_children():
		c.queue_free()
	if piece.is_empty():
		_frame.self_modulate = Color(1, 1, 1, 0.35)
		_center.add_child(_big_holder)
		var hint := LobbyUi.text("Chọn một trang bị bên trái" if PlayerState.equipment != null else "Đang tải...", 24, Ui.TEXT_DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_center.add_child(hint)
		return
	var item := EquipmentModel.item_of_piece(PlayerState.catalog, piece)
	var level := int(piece.get("upgradeLevel", 0))
	_frame.self_modulate = UpgradeModel.frame_tint(level)
	_frame.add_child(UpgradeAura.around_frame(FRAME, level)) # on the hexagon's edge
	var icon := EquipmentUi.item_icon(item, {}, BIG_ICON)
	icon.position = (FRAME - Vector2(BIG_ICON, BIG_ICON)) / 2.0 - Vector2(0, 4)
	_frame.add_child(icon)

	var name_label := LobbyUi.text(EquipmentModel.display_name(item), 34, UpgradeModel.name_color(piece), true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.add_child(name_label)
	var sub := "%s · %s" % [EquipmentModel.slot_name(str(item.get("slot", ""))), EquipmentModel.worn_text(piece) if EquipmentModel.wearer(piece) != "" else "Chưa mặc"]
	var sub_label := LobbyUi.text(sub, 19, DIM)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.add_child(sub_label)

	# The piece now | → | the piece after one more level (its next aura), each with its stats:
	# one grid so the stat rows line up (now, the stat name under the arrow, next). At +16 the one piece, its "+16"
	# and its stats are each centred in the panel.
	var view := UpgradeModel.preview(PlayerState.catalog, piece, EquipmentUi.multipliers())
	var cols: Array = view["columns"]
	if view["maxed"]:
		var holder := CenterContainer.new()
		holder.name = "MaxPiece"
		holder.add_child(_big_holder)
		_center.add_child(holder)
		var lv_row := Ui.hbox(14)
		lv_row.name = "MaxLevel"
		lv_row.alignment = BoxContainer.ALIGNMENT_CENTER
		var lv_max := LobbyUi.text("+%d" % int(cols[0]["level"]), 40, cols[0]["color"], true)
		lv_max.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv_row.add_child(lv_max)
		if view.get("capped", false): # the padlock: this is the tier's cap; "+6" stays dead centre
			var lock := EquipmentUi.cap_mark(UpgradeModel.cap(PlayerState.catalog, piece), true, 34, false)
			var balance := Control.new()
			balance.custom_minimum_size = lock.get_combined_minimum_size()
			lv_row.add_child(balance)
			lv_row.move_child(balance, 0)
			lv_row.add_child(lock)
		_center.add_child(lv_row)
		var stats := GridContainer.new()
		stats.name = "Preview"
		stats.columns = 2
		stats.add_theme_constant_override("h_separation", 16)
		stats.add_theme_constant_override("v_separation", 6)
		stats.size_flags_horizontal = SIZE_SHRINK_CENTER
		_center.add_child(stats)
		for r in view["rows"]:
			stats.add_child(_stat_label(r))
			stats.add_child(_stat_cell(r["now_points"], r["now_battle"], "", false))
	else:
		# now | label (the arrow over it) | next: symmetric, so the pair sits in the panel's middle.
		var grid := GridContainer.new()
		grid.name = "Preview"
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = SIZE_SHRINK_CENTER
		_center.add_child(grid)
		# Row 1: the hexagons.
		var now_holder := CenterContainer.new()
		now_holder.custom_minimum_size.x = COL_W
		now_holder.add_child(_big_holder)
		grid.add_child(now_holder)
		var arrow_box := CenterContainer.new()
		arrow_box.add_child(LobbyUi.icon("arrow_right", 36))
		grid.add_child(arrow_box)
		var next_holder := CenterContainer.new()
		next_holder.custom_minimum_size.x = COL_W
		next_holder.name = "NextPiece"
		next_holder.add_child(EquipmentUi.hex_frame(FRAME, int(cols[1]["level"]), EquipmentUi.item_icon(item, {}, BIG_ICON), 4))
		grid.add_child(next_holder)
		# Row 2: "+N" in each level's colour.
		for i in cols.size():
			if i == 1:
				grid.add_child(Control.new())
			var lv := LobbyUi.text("+%d" % int(cols[i]["level"]), 40, cols[i]["color"], true)
			lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lv.custom_minimum_size.x = COL_W
			grid.add_child(lv)
		# The stat rows: points with what they add in battle under them; the gains in green.
		for r in view["rows"]:
			grid.add_child(_stat_cell(r["now_points"], r["now_battle"]))
			grid.add_child(_stat_label(r))
			grid.add_child(_stat_cell(r["next_points"], r["next_battle"], r["delta"] if r["up"] else ""))
	if view["note"] != "":
		var note := LobbyUi.text(view["note"], 24, LobbyUi.GOLD, true)
		note.name = "Note"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_center.add_child(note)
	if view.get("capped", false) and TransferModel.offered(PlayerState.catalog):
		# At the tier's cap: the way on is Chuyển hoá to a higher tier piece.
		var go := _small_button("Chuyển hoá", select_transfer.bind(str(piece.get("equipmentId", ""))), 22)
		go.name = "ToTransfer"
		LobbyUi.style_button(go, LobbyUi.ICON_COLORS["orange"], 14, 8)
		go.add_theme_font_override("font", LobbyUi.bold())
		go.custom_minimum_size = Vector2(240, 56)
		go.size_flags_horizontal = SIZE_SHRINK_CENTER
		_center.add_child(go)
	# What the next level unlocks besides stats, as pictures (the weapon's +10 bullet glow and +14
	# skill rank up, the slot's +16 awaken), centred.
	if not view["maxed"]:
		var unlocks := GearModel.milestone_unlocks(int(cols[1]["level"]), str(item.get("slot", piece.get("slot", ""))))
		if not unlocks.is_empty():
			var row := Ui.hbox(14)
			row.name = "Unlocks"
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.mouse_filter = MOUSE_FILTER_IGNORE
			for k in unlocks:
				row.add_child(GearIcon.make(k, 56))
			_center.add_child(row)
	var fail: String = view["fail"]
	if fail != "":
		var reset := not fail.contains("giữ nguyên")
		var fl := LobbyUi.text(fail, 21, WARN if reset else DIM, reset)
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_center.add_child(fl)


## A preview row's name, the passive's picture in its place (UpgradeModel.passive_step()).
static func _stat_label(r: Dictionary) -> Control:
	if r.has("glyph"):
		var box := CenterContainer.new()
		box.name = "PassiveGlyph"
		box.mouse_filter = MOUSE_FILTER_IGNORE
		box.add_child(GearIcon.make(str(r["glyph"]), 36))
		return box
	var label := LobbyUi.text(r["label"], 21, DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = SIZE_FILL
	return label


## "+440 điểm" over a dim "+22.000" (the battle value, left out when unknown), centred in a
## column (column: false = as wide as its text); gain: the green "+2 điểm" after the battle value.
static func _stat_cell(points: String, battle: String, gain: String = "", column: bool = true) -> Control:
	var cell := Ui.vbox(0)
	if column:
		cell.custom_minimum_size.x = COL_W
	var pl := LobbyUi.text(points, 21, Color.WHITE, true)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(pl)
	if battle != "" or gain != "":
		var under := Ui.hbox(8)
		under.alignment = BoxContainer.ALIGNMENT_CENTER
		if battle != "":
			under.add_child(LobbyUi.text(battle, 16, Ui.TEXT_DIM))
		if gain != "":
			var g := LobbyUi.text(gain, 17, GOOD, true)
			g.name = "Gain"
			under.add_child(g)
		cell.add_child(under)
	return cell


# ── Nâng cấp: stones ────────────────────────────────────────────────────────

func _render_stones() -> void:
	Ui.clear(_stone_list)
	var owned := _owned()
	var levels := UpgradeModel.owned_levels(owned)
	if PlayerState.stones != null and levels.is_empty():
		var empty := Ui.vbox(10)
		empty.add_child(LobbyUi.text("Chưa có đá nâng cấp", 22, Ui.TEXT_DIM))
		var shop := _small_button("Mua đá ở Shop", func(): open_shop.emit(SHOP_STONES), 20)
		shop.size_flags_horizontal = SIZE_SHRINK_BEGIN
		shop.custom_minimum_size.x = 220
		empty.add_child(shop)
		_stone_list.add_child(empty)
	var piece := _piece()
	var usable := not piece.is_empty() and not UpgradeModel.rate(PlayerState.catalog, int(piece.get("upgradeLevel", 0))).is_empty() \
		and not UpgradeModel.at_tier_cap(PlayerState.catalog, piece)
	for lv in levels:
		_stone_list.add_child(_stone_row(int(lv), int(owned[lv]), usable))
	_render_chance()


## usable: the selected piece can be upgraded (otherwise the − + are off).
func _stone_row(stone_level: int, have: int, usable: bool) -> Control:
	var n := int(_picked.get(stone_level, 0))
	var card := PanelContainer.new()
	var bg := Color(0.16, 0.3, 0.56, 0.9) if n > 0 else Color(0.08, 0.11, 0.26, 0.85)
	card.add_theme_stylebox_override("panel", LobbyUi.box(bg, 12, 6, LobbyUi.GOLD if n > 0 else Color(1, 1, 1, 0.08), 2))
	var row := Ui.hbox(10)
	card.add_child(row)
	var stone_icon := LobbyUi.icon(Art.stone_icon(stone_level), 54)
	stone_icon.tooltip_text = UpgradeModel.stone_name(stone_level) # its look shows the level
	stone_icon.mouse_filter = MOUSE_FILTER_PASS
	row.add_child(stone_icon)
	var texts := Ui.vbox(2)
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	LobbyUi.icon_text(texts, "inventory", Fmt.thousands(have), 21, Color.WHITE, true, 22) # owned
	LobbyUi.icon_text(texts, "upgrade", Fmt.thousands(UpgradeModel.power(PlayerState.catalog, stone_level)), 17, DIM, true, 18) # power
	var minus := _step_button("−", _on_step.bind(stone_level, -1))
	minus.disabled = n <= 0 or _acting
	row.add_child(minus)
	var count := LobbyUi.text(str(n), 26, LobbyUi.GOLD if n > 0 else Ui.TEXT_DIM, true)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.custom_minimum_size.x = 44
	row.add_child(count)
	var plus := _step_button("+", _on_step.bind(stone_level, 1))
	plus.disabled = n >= have or _acting or not usable
	row.add_child(plus)
	return card


static func _step_button(text_value: String, on_press: Callable) -> Button:
	var b := Ui.button(text_value, 28)
	b.custom_minimum_size = Vector2(52, 52)
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(on_press)
	return b


func _on_step(stone_level: int, delta: int) -> void:
	var have := int(_owned().get(stone_level, 0))
	_picked[stone_level] = clampi(int(_picked.get(stone_level, 0)) + delta, 0, have)
	if int(_picked[stone_level]) == 0:
		_picked.erase(stone_level)
	_render_stones.call_deferred()


func _on_auto() -> void:
	var piece := _piece()
	if piece.is_empty() or _acting:
		return
	_picked = UpgradeModel.auto_pick(PlayerState.catalog, int(piece.get("upgradeLevel", 0)), _owned(),
		UpgradeModel.piece_slot(PlayerState.catalog, piece))
	_render_stones()


func _on_clear() -> void:
	_picked = {}
	_render_stones()


func _render_chance() -> void:
	var piece := _piece()
	var level := int(piece.get("upgradeLevel", 0))
	var c := _chance_of(piece)
	var rated := not piece.is_empty() and not UpgradeModel.rate(PlayerState.catalog, level).is_empty() \
		and not UpgradeModel.at_tier_cap(PlayerState.catalog, piece)
	_fill_box.visible = rated
	_tiles.visible = rated
	if rated:
		_render_fill(c)
		_render_tiles(c)
	var reason := _upgrade_reason(piece)
	_go.disabled = reason != ""
	var coin := int(c["coin"]) if rated else 0
	var priced: bool = c["careful"] or coin > 0
	_go.text = "" if priced else "NÂNG CẤP"
	_go_text.visible = priced
	_go_text.modulate = Color(1, 1, 1, 0.5 if _go.disabled else 1.0)
	_go_coin.visible = coin > 0
	_go_coin_price.visible = coin > 0
	_go_coin_price.text = Fmt.thousands(coin)
	_go_gem.visible = c["careful"]
	_go_price.visible = c["careful"]
	_go_price.text = Fmt.thousands(int(c["gem"]))
	_reason.text = reason
	_reason.visible = reason != "" # only why the button is off; the stone list takes the room
	_auto.disabled = piece.is_empty() or _owned().is_empty() or _acting or not rated
	_clear.disabled = _picked.is_empty() or _acting


## The chance of the picked stones for the selected piece, careful included when on.
func _chance_of(piece: Dictionary) -> Dictionary:
	return UpgradeModel.chance(PlayerState.catalog, int(piece.get("upgradeLevel", 0)), _picked,
		UpgradeModel.piece_slot(PlayerState.catalog, piece), _careful)


## The gauge: P / C, the fill, the bar gold while filling, green when full, orange with a whole
## stone to spare; the warning shows only above C.
func _render_fill(c: Dictionary) -> void:
	_power_label.text = UpgradeModel.power_text(c)
	_fill_label.text = UpgradeModel.fill_text(c)
	_fill_bar.value = float(c["fill"])
	var full := int(c["fill_bp"]) >= 10000
	var color: Color = WARN if c["spare"] else (GOOD if full else LobbyUi.GOLD)
	_fill_bar.add_theme_stylebox_override("fill", LobbyUi.box(color, 9, 0))
	_over_label.text = UpgradeModel.over_text(c)
	_over_label.add_theme_color_override("font_color", WARN if c["spare"] else DIM)
	_over_label.visible = c["wasted"]


## The two chance tiles; only the normal one, alone in the centre, when the step has no careful.
## Careful is greyed with "Thiếu kim cương" when the gems do not cover it, unless it is on (the
## other tile turns it off).
func _render_tiles(c: Dictionary) -> void:
	var offered: bool = c["offered"]
	var on: bool = c["careful"]
	_careful_tile["button"].visible = offered
	_normal_tile["box"].visible = offered
	_render_tile(_normal_tile, UpgradeModel.bp_text(int(c["stone_bp"])), "Tối đa %s" % UpgradeModel.bp_text(int(c["max_bp"])), not on, LobbyUi.GOLD)
	_normal_tile["button"].disabled = _acting
	if not offered:
		return
	var gems := _gems()
	var short := gems >= 0 and gems < int(UpgradeModel.careful(PlayerState.catalog, int(_piece().get("upgradeLevel", 0)))["gem"])
	_render_tile(_careful_tile, UpgradeModel.bp_text(int(c["careful_bp"])),
		"Thiếu kim cương" if short else "Tối đa %s" % UpgradeModel.bp_text(int(c["careful_max_bp"])), on, GEM_CYAN)
	_careful_tile["sub"].add_theme_color_override("font_color", BAD if short else DIM)
	_careful_tile["button"].disabled = _acting or (short and not on)


## One tile: selected = it is the chance that rolls (its accent on the border, the check in its
## box), the other one dimmed.
func _render_tile(t: Dictionary, value: String, sub: String, selected: bool, accent: Color) -> void:
	var b: Button = t["button"]
	LobbyUi.style_button(b, Color(accent.darkened(0.72), 0.95) if selected else TILE_BG, 12, 4, accent if selected else Color(1, 1, 1, 0.12), 2)
	var box: PanelContainer = t["box"]
	box.add_theme_stylebox_override("panel", LobbyUi.box(accent if selected else Color(0, 0, 0, 0.35), 6, 2, accent if selected else Color(1, 1, 1, 0.5), 2))
	(t["check"] as Control).modulate = Color(0.04, 0.1, 0.2) if selected else Color(1, 1, 1, 0)
	(t["value"] as Label).text = value
	(t["value"] as Label).add_theme_color_override("font_color", accent)
	(t["sub"] as Label).text = sub
	(t["sub"] as Label).add_theme_color_override("font_color", DIM)
	for key in ["title", "value", "sub"]:
		(t[key] as Control).modulate.a = 1.0 if selected else TILE_DIM


func _upgrade_reason(piece: Dictionary) -> String:
	if _acting:
		return "Đang nâng cấp..."
	if PlayerState.catalog == null or PlayerState.equipment == null:
		return "Đang tải..."
	if UpgradeModel.at_tier_cap(PlayerState.catalog, piece) and TransferModel.offered(PlayerState.catalog):
		return "Đã đạt trần, hãy Chuyển hoá"
	var why := UpgradeModel.blocked_reason(PlayerState.catalog, piece, _picked, _owned(), _careful, _gems(), _coins())
	if why != "":
		return why
	if not PlayerState.equipment_ready():
		return "Đang cập nhật trang bị..."
	if not PlayerState.stones_ready():
		return "Đang cập nhật đá..."
	return ""


func _on_upgrade() -> void:
	var piece := _piece()
	if _upgrade_reason(piece) != "":
		return
	var c := _chance_of(piece)
	if c["careful"] or c["spare"]:
		_confirm(c)
		return
	_run_upgrade(false)


## Careful costs gems and a spare stone is lost for nothing: a popup says so before the stones go.
func _confirm(c: Dictionary) -> void:
	var careful: bool = c["careful"]
	var m := Modal.new()
	m.open(overlay, CAREFUL_TITLE if careful else "Nâng cấp")
	if careful:
		m.add_text(UpgradeModel.careful_confirm_text(c), 24)
	if c["spare"]:
		var warn := m.add_text(UpgradeModel.over_text(c), 22)
		warn.add_theme_color_override("font_color", WARN)
	m.add_button("Huỷ", m.close)
	m.add_button("Nâng cấp", func():
		m.close()
		if _upgrade_reason(_piece()) == "":
			_run_upgrade(careful))


func _run_upgrade(careful: bool) -> void:
	var piece := _piece()
	var level := int(piece.get("upgradeLevel", 0))
	var item := EquipmentModel.item_of_piece(PlayerState.catalog, piece)
	var piece_name := EquipmentModel.display_name(item)
	_acting = true
	_render_chance()
	_render_stones()
	var res: Dictionary = await PlayerState.upgrade(_piece_id, UpgradeModel.request_stones(_picked), careful, level)
	if not is_inside_tree():
		return
	_picked = {}
	if not res.ok:
		_acting = false
		var msg := ErrorText.upgrade(res) if res.code != "BUSY" else "Đang xử lý việc khác, hãy đợi"
		Ui.toast(overlay, msg, 3.0)
		_render()
		return
	var data: Dictionary = res.data if res.data is Dictionary else {}
	var success := bool(data.get("success", false))
	var new_level := int(data.get("newLevel", level + 1 if success else level))
	var crossed := success and new_level > level and UpgradeModel.is_milestone(new_level)
	var cost := _spent_text(data)
	if success:
		_play_fx("milestone" if crossed else "success", UpgradeModel.milestone_color(new_level) if new_level >= 1 else LobbyUi.GOLD,
			null, "ĐẠT MỐC +%d!" % new_level if crossed else "THÀNH CÔNG!")
		if crossed:
			Ui.toast(overlay, "Đạt mốc +%d! %s +%d — hào quang %s%s" % [new_level, piece_name, new_level,
				UpgradeModel.TIER_WORDS[UpgradeModel.color_tier(new_level)], cost], 3.0)
		else:
			Ui.toast(overlay, "Nâng cấp thành công! %s +%d%s" % [piece_name, new_level, cost], 2.5)
	else:
		_play_fx("fail", BAD, null, "THẤT BẠI")
		_shake(_big_holder)
		Ui.toast(overlay, ("Thất bại — %s giữ nguyên +%d%s" if new_level == level else "Thất bại — %s về +%d%s") % [piece_name, new_level, cost], 3.0)
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree():
		return
	_acting = false
	_render()


## " (−2.500 xu, −120 kim cương)" from the upgrade's answer; "" when it spent nothing.
func _spent_text(data: Dictionary) -> String:
	var parts := PackedStringArray()
	for pair in [["coinSpent", "xu"], ["gemSpent", "kim cương"]]:
		var v = data.get(pair[0])
		if (v is int or v is float) and int(v) > 0:
			parts.append("−%s %s" % [Fmt.thousands(int(v)), pair[1]])
	return " (%s)" % ", ".join(parts) if not parts.is_empty() else ""


# ── Effects ─────────────────────────────────────────────────────────────────

## Starts a result effect on the big piece (or the merge result): a tween drives _fx_t 0 → 1 and
## redraws only while it runs.
func _play_fx(kind: String, color: Color, layer: Control = null, text_value: String = "") -> void:
	if layer == null:
		layer = _fx
	_fx_kind = kind
	_fx_color = color
	_fx_text = text_value
	_fx_parts.clear()
	var n := 34 if kind == "milestone" else (22 if kind in ["success", "merge_ok"] else 14)
	var rng := RandomNumberGenerator.new()
	for i in n:
		_fx_parts.append([rng.randf() * TAU, rng.randf_range(0.55, 1.0), rng.randf_range(3.0, 7.0)])
	var dur := 1.4 if kind == "milestone" else (1.1 if kind == "fail" else 0.95)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		_fx_t = t
		if is_instance_valid(layer):
			layer.queue_redraw(), 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		_fx_kind = ""
		if is_instance_valid(layer):
			layer.queue_redraw())
	if kind in ["success", "milestone"]:
		_big_holder.pivot_offset = FRAME / 2.0
		var pop := create_tween()
		pop.tween_property(_big_holder, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK)
		pop.tween_property(_big_holder, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE)


func _draw_fx(c: Control) -> void:
	if _fx_kind == "":
		return
	var t := _fx_t
	var center := c.size / 2.0 - Vector2(0, 6)
	var r := minf(c.size.x, c.size.y) * 0.5
	var fade := 1.0 - t
	match _fx_kind:
		"success", "milestone", "merge_ok":
			var big := _fx_kind == "milestone"
			# White flash, then rings in the colour.
			c.draw_circle(center, r * (0.5 + 0.6 * t), Color(1, 1, 1, 0.55 * maxf(0.0, 1.0 - t * 3.0)), true, -1.0, true)
			for k in (3 if big else 1):
				var tk := clampf(t * 1.25 - k * 0.15, 0.0, 1.0)
				if tk > 0.0:
					c.draw_arc(center, r * (0.35 + 1.0 * tk), 0, TAU, 48, Color(_fx_color, (1.0 - tk) * 0.9), (10.0 if big else 6.0) * (1.0 - tk) + 1.5, true)
			if big:
				for i in 16:
					var a := i * TAU / 16 + t * 0.8
					var d := Vector2.from_angle(a)
					var side := Vector2(-d.y, d.x) * 7.0 * fade
					var inner := center + d * r * 0.35
					var outer := center + d * r * (0.9 + 0.7 * t)
					c.draw_colored_polygon(PackedVector2Array([inner + side, outer, inner - side]), Color(_fx_color.lightened(0.3), 0.55 * fade))
			for p in _fx_parts:
				var pos: Vector2 = center + Vector2.from_angle(p[0]) * r * (0.25 + 1.1 * p[1] * t)
				var s: float = p[2] * (1.0 - t * 0.6)
				_spark(c, pos, s * (1.6 if big else 1.2), Color(_fx_color.lightened(0.45), fade))
		"fail", "merge_fail":
			c.draw_circle(center, r * 0.95, Color(1.0, 0.15, 0.15, 0.6 * maxf(0.0, 1.0 - t * 1.6)), true, -1.0, true)
			# Cracks from the centre, then grey smoke rising.
			var crack := Color(1.0, 0.35, 0.3, 0.9 * maxf(0.0, 1.0 - t * 1.4))
			for i in 7:
				var a := i * TAU / 7 + 0.4
				var mid := center + Vector2.from_angle(a + 0.25) * r * 0.35
				c.draw_polyline(PackedVector2Array([center, mid, center + Vector2.from_angle(a) * r * 0.75]), crack, 4.0, true)
			for p in _fx_parts:
				var pos: Vector2 = center + Vector2.from_angle(p[0]) * r * (0.2 + 0.8 * p[1] * t) + Vector2(0, -50.0 * t)
				c.draw_circle(pos, p[2] * (2.0 + 3.0 * t), Color(0.3, 0.3, 0.36, 0.65 * fade), true, -1.0, true)
	_draw_fx_text(c, center, t)


## The result word over the effect: pops in, rises a little, fades out.
func _draw_fx_text(c: Control, center: Vector2, t: float) -> void:
	if _fx_text == "":
		return
	var font := LobbyUi.bold()
	var fs := 40 if _fx_kind == "milestone" else 34
	var w := font.get_string_size(_fx_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pop := minf(t * 6.0, 1.0)
	var alpha := clampf((1.0 - t) * 2.5, 0.0, 1.0) * pop
	var at := center + Vector2(-w / 2.0, 12.0 - 40.0 * t)
	var col := Color.WHITE.lerp(_fx_color, 0.35) if _fx_kind != "fail" else Color(1.0, 0.5, 0.45)
	c.draw_string_outline(font, at, _fx_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.05, 0.03, 0.1, alpha))
	c.draw_string(font, at, _fx_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, alpha))


static func _spark(c: Control, at: Vector2, s: float, color: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 2), at + Vector2(s * 0.45, 0), at + Vector2(0, s * 2), at + Vector2(-s * 0.45, 0)]), color)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 2, 0), at + Vector2(0, s * 0.45), at + Vector2(s * 2, 0), at + Vector2(0, -s * 0.45)]), color)


func _shake(node: Control) -> void:
	var base := node.position
	var tw := create_tween()
	for i in 6:
		tw.tween_property(node, "position", base + Vector2(14 if i % 2 == 0 else -14, 0) * (1.0 - i / 6.0), 0.05)
	tw.tween_property(node, "position", base, 0.05)


# ── Ghép đá ─────────────────────────────────────────────────────────────────

func _build_merge_page() -> Control:
	var row := Ui.hbox(16)
	var left := LobbyUi.panel(14, 18)
	left.custom_minimum_size.x = 640
	row.add_child(left)
	var lcol := Ui.vbox(12)
	left.add_child(lcol)
	lcol.add_child(LobbyUi.text("Chọn cấp đá", 26, Color.WHITE, true))
	_merge_levels = GridContainer.new()
	_merge_levels.columns = 4
	_merge_levels.add_theme_constant_override("h_separation", 10)
	_merge_levels.add_theme_constant_override("v_separation", 10)
	lcol.add_child(Ui.scroll(_merge_levels))

	var right := LobbyUi.panel(24, 18)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(right)
	var rcol := Ui.vbox(18)
	rcol.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(rcol)
	# the rules (how many stones, a failure loses them) behind the "i", not on the page
	var top := Ui.hbox(0)
	top.alignment = BoxContainer.ALIGNMENT_END
	rcol.add_child(top)
	top.add_child(GlyphIcon.info_button(_show_merge_rules, 48))
	var formula := HBoxContainer.new()
	formula.alignment = BoxContainer.ALIGNMENT_CENTER
	formula.add_theme_constant_override("separation", 26)
	rcol.add_child(formula)
	_merge_from = LobbyUi.icon(Art.stone_icon(1), 120)
	formula.add_child(_merge_from)
	_merge_times = LobbyUi.text("×4", 40, LobbyUi.GOLD, true)
	_merge_times.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	formula.add_child(_merge_times)
	formula.add_child(LobbyUi.icon("arrow_right", 56))
	_merge_to_holder = Control.new()
	_merge_to_holder.custom_minimum_size = Vector2(150, 150)
	_merge_to_holder.size_flags_vertical = SIZE_SHRINK_CENTER
	formula.add_child(_merge_to_holder)
	_merge_to = LobbyUi.icon(Art.stone_icon(2), 150)
	_merge_to.size = Vector2(150, 150)
	_merge_to_holder.add_child(_merge_to)
	_merge_fx = Control.new()
	_merge_fx.size = Vector2(150, 150)
	_merge_fx.mouse_filter = MOUSE_FILTER_IGNORE
	_merge_fx.draw.connect(_draw_fx.bind(_merge_fx))
	_merge_to_holder.add_child(_merge_fx)
	_merge_text = LobbyUi.text("", 28, Color.WHITE, true)
	_merge_text.visible = false # the stones and the arrow say it: the line is only the tooltip
	rcol.add_child(_merge_text)
	var counts := HBoxContainer.new()
	counts.alignment = BoxContainer.ALIGNMENT_CENTER
	counts.add_theme_constant_override("separation", 10)
	rcol.add_child(counts)
	var count_names: Array = []
	for n in range(UpgradeModel.merge_min(), UpgradeModel.merge_max() + 1):
		count_names.append("×%d" % n)
	_merge_count_tabs = Ui.tab_row(count_names, 22, func(i: int):
		_merge_count = UpgradeModel.merge_min() + i
		_render_merge(), 56)
	for b in _merge_count_tabs:
		b.size_flags_horizontal = SIZE_FILL
		b.custom_minimum_size.x = 130
		counts.add_child(b)
	_merge_chance = LobbyUi.text("", 26, LobbyUi.GOLD, true)
	_merge_chance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rcol.add_child(_merge_chance)
	_merge_go = LobbyUi.start_button("GHÉP")
	_merge_go.custom_minimum_size = Vector2(360, 84)
	_merge_go.add_theme_font_size_override("font_size", 34)
	_merge_go.size_flags_horizontal = SIZE_SHRINK_CENTER
	_merge_go.pressed.connect(_on_merge)
	rcol.add_child(_merge_go)
	_merge_reason = LobbyUi.text("", 19, Ui.TEXT_DIM)
	_merge_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_merge_reason.custom_minimum_size.y = 26
	rcol.add_child(_merge_reason)
	return row


## The merge rules, behind the "i": how many stones go in, one stone of the next level comes out,
## a failure loses them all (the numbers are the game data's).
func _show_merge_rules() -> void:
	var m := Modal.new()
	m.open(overlay, "Ghép đá", 620)
	m.add_close_x()
	m.add_text("%d–%d viên cùng cấp → 1 viên cấp trên." % [UpgradeModel.merge_min(), UpgradeModel.merge_max()], 24)
	var warn := m.add_text("Thất bại: mất hết số đá đã bỏ vào.", 22)
	warn.add_theme_color_override("font_color", WARN)


func _render_merge() -> void:
	if _merge_levels == null:
		return
	var owned := _owned()
	Ui.clear(_merge_levels)
	for lv in range(1, UpgradeModel.stone_levels()):
		var have := int(owned.get(lv, 0))
		var b := Button.new()
		b.custom_minimum_size = Vector2(140, 150)
		b.focus_mode = FOCUS_NONE
		if lv == _merge_level:
			LobbyUi.style_button(b, Color(0.16, 0.3, 0.56, 0.95), 14, 6, LobbyUi.GOLD, 3)
		else:
			LobbyUi.style_button(b, Color(0.08, 0.11, 0.26, 0.85), 14, 6, Color(1, 1, 1, 0.08), 2)
		b.pressed.connect(func():
			_merge_level = lv
			_render_merge.call_deferred())
		var col := Ui.vbox(0)
		col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		col.offset_top = 8
		col.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(col)
		var icon := LobbyUi.icon(Art.stone_icon(lv), 72)
		icon.size_flags_horizontal = SIZE_SHRINK_CENTER
		col.add_child(icon)
		b.tooltip_text = UpgradeModel.stone_name(lv) # the stone's look shows its level
		var count := LobbyUi.text("×%s" % Fmt.thousands(have), 24, LobbyUi.GOLD if have >= UpgradeModel.merge_min() else Ui.TEXT_DIM, true)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.mouse_filter = MOUSE_FILTER_IGNORE
		col.add_child(count)
		if have < UpgradeModel.merge_min():
			b.modulate = Color(1, 1, 1, 0.55)
		_merge_levels.add_child(b)
	Ui.select_tab(_merge_count_tabs, _merge_count - UpgradeModel.merge_min())
	_merge_from.texture = Art.stone_icon(_merge_level)
	_merge_to.texture = Art.stone_icon(_merge_level + 1)
	_merge_text.text = UpgradeModel.merge_text(_merge_level, _merge_count)
	_merge_to_holder.tooltip_text = _merge_text.text
	_merge_times.text = "×%d" % _merge_count
	_merge_chance.text = "Tỉ lệ thành công %s" % BattleStats.format_chance(UpgradeModel.merge_chance(PlayerState.catalog, _merge_count))
	var reason := _merge_reason_text()
	_merge_go.disabled = reason != ""
	_merge_reason.text = reason


func _merge_reason_text() -> String:
	if _acting:
		return "Đang ghép..."
	if PlayerState.stones == null:
		return "Đang tải đá..."
	var why := UpgradeModel.merge_blocked(_merge_level, _merge_count, _owned())
	if why != "":
		return why
	if not PlayerState.stones_ready():
		return "Đang cập nhật đá..."
	return ""


func _on_merge() -> void:
	if _merge_reason_text() != "":
		return
	var lv := _merge_level
	var count := _merge_count
	_acting = true
	_render_merge()
	var res: Dictionary = await PlayerState.merge_stones(lv, count)
	if not is_inside_tree():
		return
	if not res.ok:
		_acting = false
		Ui.toast(overlay, ErrorText.merge(res) if res.code != "BUSY" else "Đang xử lý việc khác, hãy đợi", 3.0)
		_render()
		return
	var success: bool = res.data is Dictionary and bool(res.data.get("success", false))
	if success:
		_play_fx("merge_ok", Color(1.0, 0.85, 0.4), _merge_fx, "THÀNH CÔNG!")
	else:
		_play_fx("merge_fail", BAD, _merge_fx, "THẤT BẠI")
		_shake(_merge_to_holder)
		Ui.toast(overlay, "Ghép thất bại — mất %d × %s" % [count, UpgradeModel.stone_name(lv)], 3.0)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	if success: # the new stone bursts out of a gift box
		RewardReveal.open(overlay, [RewardModel.tile("stone", "stone_%d" % (lv + 1), 1, lv + 1)])
	_acting = false
	_render()


# ── Ghép ngọc ───────────────────────────────────────────────────────────────

func _build_gem_merge_page() -> Control:
	var row := Ui.hbox(16)
	var left := LobbyUi.panel(14, 18)
	left.custom_minimum_size.x = 640
	row.add_child(left)
	var lcol := Ui.vbox(12)
	left.add_child(lcol)
	_gem_types = Ui.hbox(10) # the same gap as the levels' grid
	_gem_types.name = "GemTypes"
	_gem_types.alignment = BoxContainer.ALIGNMENT_BEGIN # over the levels' four columns
	lcol.add_child(_gem_types)
	_gem_levels = GridContainer.new()
	_gem_levels.name = "GemLevels"
	_gem_levels.columns = 4
	_gem_levels.add_theme_constant_override("h_separation", 10)
	_gem_levels.add_theme_constant_override("v_separation", 10)
	lcol.add_child(Ui.scroll(_gem_levels))

	var right := LobbyUi.panel(24, 18)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(right)
	var rcol := Ui.vbox(18)
	rcol.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(rcol)
	var top := Ui.hbox(0)
	top.alignment = BoxContainer.ALIGNMENT_END
	rcol.add_child(top)
	top.add_child(GlyphIcon.info_button(_show_gem_merge_rules, 48))
	var formula := HBoxContainer.new()
	formula.name = "GemFormula"
	formula.alignment = BoxContainer.ALIGNMENT_CENTER
	formula.add_theme_constant_override("separation", 26)
	rcol.add_child(formula)
	_gem_from = GemIcon.make("hp", 1, 120)
	formula.add_child(_gem_from)
	_gem_times = LobbyUi.text("×4", 40, LobbyUi.GOLD, true)
	_gem_times.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	formula.add_child(_gem_times)
	formula.add_child(LobbyUi.icon("arrow_right", 56))
	_gem_to_holder = Control.new()
	_gem_to_holder.custom_minimum_size = Vector2(150, 150)
	_gem_to_holder.size_flags_vertical = SIZE_SHRINK_CENTER
	formula.add_child(_gem_to_holder)
	_gem_to = GemIcon.make("hp", 2, 150)
	_gem_to.position = Vector2.ZERO
	_gem_to_holder.add_child(_gem_to)
	_gem_fx = Control.new()
	_gem_fx.size = Vector2(150, 150)
	_gem_fx.mouse_filter = MOUSE_FILTER_IGNORE
	_gem_fx.draw.connect(_draw_fx.bind(_gem_fx))
	_gem_to_holder.add_child(_gem_fx)
	var counts := HBoxContainer.new()
	counts.alignment = BoxContainer.ALIGNMENT_CENTER
	counts.add_theme_constant_override("separation", 10)
	rcol.add_child(counts)
	var count_names: Array = []
	for n in range(UpgradeModel.merge_min(), UpgradeModel.merge_max() + 1):
		count_names.append("×%d" % n)
	_gem_count_tabs = Ui.tab_row(count_names, 22, func(i: int):
		_gem_count = UpgradeModel.merge_min() + i
		_render_gem_merge(), 56)
	for b in _gem_count_tabs:
		b.size_flags_horizontal = SIZE_FILL
		b.custom_minimum_size.x = 130
		counts.add_child(b)
	_gem_chance = LobbyUi.text("", 26, LobbyUi.GOLD, true)
	_gem_chance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rcol.add_child(_gem_chance)
	_gem_go = LobbyUi.start_button("GHÉP")
	_gem_go.name = "GemMergeGo"
	_gem_go.custom_minimum_size = Vector2(360, 84)
	_gem_go.add_theme_font_size_override("font_size", 34)
	_gem_go.size_flags_horizontal = SIZE_SHRINK_CENTER
	_gem_go.pressed.connect(_on_gem_merge)
	rcol.add_child(_gem_go)
	_gem_reason = LobbyUi.text("", 19, Ui.TEXT_DIM)
	_gem_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gem_reason.custom_minimum_size.y = 26
	rcol.add_child(_gem_reason)
	return row


## The rules behind the "i" (the counts are the game data's).
func _show_gem_merge_rules() -> void:
	var m := Modal.new()
	m.open(overlay, "Ghép ngọc", 620)
	m.add_close_x()
	m.add_text("%d–%d viên cùng loại, cùng cấp → 1 viên cấp trên." % [UpgradeModel.merge_min(), UpgradeModel.merge_max()], 24)
	m.add_text("Ngọc đang khảm không ghép được.", 22)
	var warn := m.add_text("Thất bại: mất hết số ngọc đã bỏ vào.", 22)
	warn.add_theme_color_override("font_color", WARN)


func _render_gem_merge() -> void:
	if _gem_levels == null:
		return
	var catalog = PlayerState.catalog
	var types := GemModel.types(catalog)
	if _gem_type == "" or not types.has(_gem_type):
		_gem_type = str(types[0]) if not types.is_empty() else ""
	var owned := PlayerState.gem_list()
	var choices := GemModel.merge_choices(catalog, owned)
	var mine: Array = choices.filter(func(c): return c["gemType"] == _gem_type)
	if not mine.is_empty() and mine.filter(func(c): return int(c["gemLevel"]) == _gem_level).is_empty():
		_gem_level = int(mine[0]["gemLevel"])
	Ui.clear(_gem_types)
	for t in types:
		var b := Button.new()
		b.name = "Type_" + str(t)
		b.custom_minimum_size = Vector2(140, 96)
		b.focus_mode = FOCUS_NONE
		var picked: bool = t == _gem_type
		LobbyUi.style_button(b, Color(0.16, 0.3, 0.56, 0.95) if picked else Color(0.08, 0.11, 0.26, 0.85), 14, 6,
			GemModel.color(t) if picked else Color(1, 1, 1, 0.08), 3 if picked else 2)
		var icon := GemIcon.make(str(t), 1, 72, false)
		icon.position = (b.custom_minimum_size - icon.size) / 2.0
		b.add_child(icon)
		b.pressed.connect(func():
			_gem_type = str(t)
			_render_gem_merge.call_deferred())
		_gem_types.add_child(b)
	Ui.clear(_gem_levels)
	for c in mine:
		var lv := int(c["gemLevel"])
		var have := int(c["count"])
		var b := Button.new()
		b.name = "Level_%d" % lv
		b.custom_minimum_size = Vector2(140, 150)
		b.focus_mode = FOCUS_NONE
		if lv == _gem_level:
			LobbyUi.style_button(b, Color(0.16, 0.3, 0.56, 0.95), 14, 6, LobbyUi.GOLD, 3)
		else:
			LobbyUi.style_button(b, Color(0.08, 0.11, 0.26, 0.85), 14, 6, Color(1, 1, 1, 0.08), 2)
		b.pressed.connect(func():
			_gem_level = lv
			_render_gem_merge.call_deferred())
		var col := Ui.vbox(0)
		col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		col.offset_top = 8
		col.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(col)
		col.add_child(GemIcon.make(_gem_type, lv, 80))
		var count := LobbyUi.text("×%s" % Fmt.thousands(have), 24, LobbyUi.GOLD if have >= UpgradeModel.merge_min() else Ui.TEXT_DIM, true)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.mouse_filter = MOUSE_FILTER_IGNORE
		col.add_child(count)
		if have < UpgradeModel.merge_min():
			b.modulate = Color(1, 1, 1, 0.55)
		_gem_levels.add_child(b)
	Ui.select_tab(_gem_count_tabs, _gem_count - UpgradeModel.merge_min())
	for g in [_gem_from, _gem_to]:
		g.gem_type = _gem_type
		var top := GemModel.max_level(catalog, _gem_type)
		g.glow_top = top if top > 1 else 10
	_gem_from.level = _gem_level
	_gem_to.level = _gem_level + 1
	_gem_times.text = "×%d" % _gem_count
	_gem_chance.text = "Tỉ lệ thành công %s" % BattleStats.format_chance(UpgradeModel.merge_chance(catalog, _gem_count))
	var reason := _gem_reason_text()
	_gem_go.disabled = reason != ""
	_gem_reason.text = reason


func _gem_reason_text() -> String:
	if _gem_acting:
		return "Đang ghép..."
	if PlayerState.catalog == null or PlayerState.gems == null:
		return "Đang tải ngọc..."
	var why := GemModel.merge_blocked(PlayerState.catalog, _gem_type, _gem_level, _gem_count, PlayerState.gem_list())
	if why != "":
		return why
	if not PlayerState.gems_ready():
		return "Đang cập nhật ngọc..."
	return ""


func _on_gem_merge() -> void:
	if _gem_reason_text() != "":
		return
	var t := _gem_type
	var lv := _gem_level
	var count := _gem_count
	_gem_acting = true
	_render_gem_merge()
	var res: Dictionary = await PlayerState.merge_gems(t, lv, count)
	if not is_inside_tree():
		return
	if not res.ok:
		_gem_acting = false
		Ui.toast(overlay, ErrorText.gem_merge(res) if res.code != "BUSY" else "Đang xử lý việc khác, hãy đợi", 3.0)
		_render()
		return
	var result := GemModel.parse_merge(res.data)
	if result["success"]:
		_play_fx("merge_ok", GemModel.color(t).lightened(0.3), _gem_fx, "THÀNH CÔNG!")
	else:
		_play_fx("merge_fail", BAD, _gem_fx, "THẤT BẠI")
		_shake(_gem_to_holder)
		var lost := int(result["consumed"]) if int(result["consumed"]) > 0 else count
		Ui.toast(overlay, "Ghép thất bại — mất %d viên ngọc" % lost, 3.0)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	if result["success"]: # the new gem bursts out of a gift box
		var gem: Dictionary = result["gem"]
		var gt := str(gem.get("gemType", t))
		var gl := int(gem.get("gemLevel", lv + 1))
		RewardReveal.open(overlay, [RewardModel.tile("socket_gem", gt, 1, gl)])
	_gem_acting = false
	_render()
