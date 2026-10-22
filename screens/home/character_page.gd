extends Control
## "Nhân vật" (lobby "Nhân vật" and the avatar): the character's gear and stats, laid out like
## equipment_sc.png.
## - Left: six hexagon slots in a honeycomb (Mũ, Áo, Găng tay, Quần, Giày, Vũ khí): the worn
##   piece's icon with its milestone aura and tinted frame (no "+N"), or the slot's silhouette.
##   A tap on a worn piece filters the right panel to its slot and opens its popup; on an empty
##   slot it filters (again: all slots). Under them, what the gear adds to the battle stats.
## - Centre: the character on the pedestal with its name and level, ◀ ▶ / swipe cycle the four
##   characters and change the lobby's choice too (`selected`).
## - Right: tabs "Trang bị" (the owned pieces of the tapped slot, or all: worn ones first, each
##   with its change against the worn piece; pieces this character cannot wear dimmed with the
##   reason; a tap opens the piece popup: compare, Mặc / Tháo / Chuyển cho <nhân vật>) and
##   "Chỉ số" (stats_panel.gd: battle stats and point allocation).
## After an equip / unequip PlayerState reloads the gear and the characters, so the slots, the
## list and the stats update by themselves.

signal selected(character_id: String)
signal open_shop(section: int)

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const CharacterView := preload("res://ui/character_view.gd")
const PedestalGun := preload("res://screens/home/pedestal_gun.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const EquipmentUi := preload("res://screens/home/equipment_ui.gd")
const ShopTab := preload("res://screens/home/shop_tab.gd")
const StatsPanel := preload("res://screens/home/stats_panel.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const UpgradeAura := preload("res://screens/home/upgrade_aura.gd")

const SUB_TABS := ["Trang bị", "Chỉ số"]
const GEAR := 0
const STATS := 1

const MARGIN := 16
const RIGHT_W := 640
## A slot hexagon on screen (the 132x152 frame at 0.85) and the honeycomb steps.
const HEX := Vector2(112, 129)
const STEP := Vector2(118, 102)
## Slot -> honeycomb cell (column in steps, row): a zigzag like the reference screen.
const CELLS := {
	"helmet": Vector2(0.5, 0), "armor": Vector2(0, 1), "gloves": Vector2(1, 1),
	"pants": Vector2(0.5, 2), "weapon": Vector2(1.5, 2), "boots": Vector2(1, 3),
}
const SLOTS_W := 300
const STAGE := Vector2(560, 590)
const PEDESTAL_AT := 528.0
const SWIPE := 70.0

## Where dialogs and toasts go (Home); defaults to this page.
var overlay: Control

var _character := LoadoutModel.default_character()
var _slot := "" # the slot the list shows, "" = all
var _sub := GEAR
var _armed := false
var _drag_from := -1.0

var _slot_buttons := {} # slot -> Button
var _slot_frames := {} # slot -> TextureRect
var _slot_icons := {} # slot -> TextureRect
var _slot_names := {} # slot -> Label
var _slot_auras := {} # slot -> UpgradeAura on the hexagon of the worn piece
var _bonus: Label
var _art: CharacterView
var _gun_stand: PedestalGun
var _stage_name: Label
var _stage_level: Label
var _sub_tabs: Array[Button]
var _pages: Array[Control] = []
var _list_title: Label
var _list_all: Button
var _list_status: LoadStatus
var _list: VBoxContainer
var _stats: StatsPanel
var _arrows: Array[Button] = []


func _ready() -> void:
	if overlay == null:
		overlay = self
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_slots()
	_build_stage()
	_build_right()
	PlayerState.equipment_changed.connect(_on_data_changed)
	PlayerState.characters_changed.connect(_on_data_changed)
	visibility_changed.connect(_ensure_loaded)
	_show_sub(GEAR)
	_render()
	_arm.call_deferred()


func _arm() -> void:
	_armed = true
	_ensure_loaded()


func _ensure_loaded() -> void:
	if _armed and is_visible_in_tree():
		PlayerState.need_equipment()
		PlayerState.need_characters()
		_render()


## The character shown (Home passes the lobby's choice when opening the page).
func show_character(id: String) -> void:
	_character = id if LoadoutModel.is_character(id) else LoadoutModel.default_character()
	_render()


func character_id() -> String:
	return _character


## Shows "Trang bị" (GEAR) or "Chỉ số" (STATS).
func show_section(index: int) -> void:
	_show_sub(index)


func _show_sub(index: int) -> void:
	_sub = index
	for i in _pages.size():
		_pages[i].visible = i == index
	Ui.select_tab(_sub_tabs, index)


## Deferred: a press in the list must not free its own row mid-signal.
func _on_data_changed() -> void:
	if is_inside_tree():
		_render.call_deferred()


# ── Slots ───────────────────────────────────────────────────────────────────

func _build_slots() -> void:
	var box := Control.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(SLOTS_W, STEP.y * 3 + HEX.y)
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = MARGIN + 12
	box.offset_right = MARGIN + 12 + SLOTS_W
	box.offset_top = -(STEP.y * 3 + HEX.y) / 2 - 60
	box.offset_bottom = box.offset_top + STEP.y * 3 + HEX.y
	add_child(box)
	for slot in EquipmentModel.slots():
		var cell: Vector2 = CELLS[slot]
		var b := Button.new()
		b.flat = true
		b.focus_mode = FOCUS_NONE
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		b.position = Vector2(cell.x * STEP.x, cell.y * STEP.y)
		b.size = HEX
		b.custom_minimum_size = HEX
		b.pressed.connect(_on_slot.bind(slot))
		box.add_child(b)
		var frame := TextureRect.new()
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		frame.mouse_filter = MOUSE_FILTER_IGNORE
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		b.add_child(frame)
		var aura := UpgradeAura.new()
		aura.fit_frame(Rect2(Vector2.ZERO, HEX)) # on the hexagon's edge
		b.add_child(aura)
		_slot_auras[slot] = aura
		var icon := LobbyUi.icon(Art.equipment_slot_icon(slot), 70)
		icon.position = Vector2((HEX.x - 70) / 2, 20)
		icon.size = Vector2(70, 70)
		b.add_child(icon)
		var name_label := LobbyUi.text(EquipmentModel.slot_name(slot), 17, Color(0.8, 0.88, 1.0, 0.85), true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(0, 82)
		name_label.size = Vector2(HEX.x, 24)
		name_label.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(name_label)
		_slot_buttons[slot] = b
		_slot_frames[slot] = frame
		_slot_icons[slot] = icon
		_slot_names[slot] = name_label
	_bonus = LobbyUi.text("", 19, Color(0.75, 0.9, 1.0))
	_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bonus.anchor_top = 0.5
	_bonus.anchor_bottom = 0.5
	_bonus.offset_left = MARGIN + 12
	_bonus.offset_right = MARGIN + 12 + SLOTS_W
	_bonus.offset_top = box.offset_bottom + 18
	_bonus.offset_bottom = _bonus.offset_top + 90
	add_child(_bonus)


## A worn piece: the list shows its slot and its popup opens; an empty slot toggles the filter.
func _on_slot(slot: String) -> void:
	var piece: Dictionary = EquipmentModel.worn(PlayerState.equipment, _character).get(slot, {})
	if piece.is_empty():
		_filter("" if _slot == slot else slot)
		return
	_filter(slot)
	EquipmentUi.open_piece(overlay, piece, _character)


## The right panel's slot filter ("" = all slots), on the Trang bị tab.
func _filter(slot: String) -> void:
	_slot = slot
	_show_sub(GEAR)
	_render()


func _render_slots() -> void:
	var worn := EquipmentModel.worn(PlayerState.equipment, _character)
	for slot in EquipmentModel.slots():
		var piece: Dictionary = worn.get(slot, {})
		var filled := not piece.is_empty()
		var frame := "hex_selected" if slot == _slot else ("hex_filled" if filled else "hex_empty")
		_slot_frames[slot].texture = Art.equipment_frame(frame)
		var level := int(piece.get("upgradeLevel", 0)) if filled else 0
		_slot_frames[slot].self_modulate = UpgradeModel.frame_tint(level) if slot != _slot else Color.WHITE
		_slot_auras[slot].level = level
		var icon: TextureRect = _slot_icons[slot]
		if filled:
			var item := EquipmentModel.item_of_piece(PlayerState.catalog, piece)
			icon.texture = Art.equipment_icon(slot, EquipmentModel.tier(item), EquipmentModel.weapon_kind(item))
			icon.modulate = Color.WHITE
			icon.position = Vector2((HEX.x - 80) / 2, 20)
			icon.size = Vector2(80, 80)
		else:
			icon.texture = Art.equipment_slot_icon(slot)
			icon.modulate = Color(0.75, 0.85, 1.0, 0.3)
			icon.position = Vector2((HEX.x - 56) / 2, 26)
			icon.size = Vector2(56, 56)
		_slot_names[slot].visible = not filled
	var entry = EquipmentModel.character_entry(PlayerState.characters, _character)
	var lines := EquipmentModel.bonus_lines(BattleStats.of(entry)) if entry != null else []
	_bonus.text = ("Trang bị: " + " · ".join(lines)) if not lines.is_empty() else ""


# ── Stage ───────────────────────────────────────────────────────────────────

## Centred between the slots and the right panel.
func _build_stage() -> void:
	var area := Control.new()
	area.mouse_filter = MOUSE_FILTER_IGNORE
	area.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	area.offset_left = MARGIN + 12 + SLOTS_W
	area.offset_right = -(RIGHT_W + MARGIN)
	add_child(area)
	var stage := Control.new()
	stage.custom_minimum_size = STAGE
	stage.mouse_filter = MOUSE_FILTER_STOP
	stage.gui_input.connect(_on_stage_input)
	stage.anchor_left = 0.5
	stage.anchor_right = 0.5
	stage.anchor_top = 0.5
	stage.anchor_bottom = 0.5
	stage.offset_left = -STAGE.x / 2
	stage.offset_right = STAGE.x / 2
	stage.offset_top = -STAGE.y / 2 - 10
	stage.offset_bottom = STAGE.y / 2 - 10
	area.add_child(stage)
	var pedestal := Control.new()
	pedestal.mouse_filter = MOUSE_FILTER_IGNORE
	pedestal.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	pedestal.draw.connect(func(): pedestal.draw_texture(Art.env("pedestal"), Vector2(STAGE.x / 2, PEDESTAL_AT) - Art.PEDESTAL_CENTER))
	stage.add_child(pedestal)
	var head := Ui.vbox(0)
	head.mouse_filter = MOUSE_FILTER_IGNORE
	head.position = Vector2((STAGE.x - 400) / 2, 20)
	head.custom_minimum_size = Vector2(400, 0)
	stage.add_child(head)
	_stage_name = LobbyUi.text("", 44, Color.WHITE, true)
	_stage_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_stage_name)
	_stage_level = LobbyUi.text("", 24, LobbyUi.GOLD, true)
	_stage_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_stage_level)
	_art = CharacterView.new()
	_art.position = Vector2((STAGE.x - 375) / 2, 142)
	_art.size = Vector2(375, 400)
	_art.idle = true
	_art.back_aura = true # the worn weapon's +14 / +16 ring, behind the body and the pedestal gun
	stage.add_child(_art)
	_gun_stand = PedestalGun.new() # the full-body picture holds no gun: it rests beside it
	_gun_stand.size = PedestalGun.STAGE_RECT.size
	_gun_stand.position = PedestalGun.STAGE_RECT.position
	stage.add_child(_gun_stand)
	for side in [-1, 1]:
		var arrow := LobbyUi.round_button("arrow_left" if side < 0 else "arrow_right", 72, Color(0.05, 0.08, 0.2, 0.7), 0.5)
		arrow.position = Vector2(0 if side < 0 else STAGE.x - 72, 250)
		arrow.pressed.connect(_cycle.bind(side))
		stage.add_child(arrow)
		_arrows.append(arrow)


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = event.position.x
		elif _drag_from >= 0.0:
			var dx: float = event.position.x - _drag_from
			_drag_from = -1.0
			if absf(dx) >= SWIPE:
				_cycle(-1 if dx > 0 else 1)


## Not while an allocate / reset runs: its status note belongs to this character.
func _cycle(delta: int) -> void:
	if _stats.is_busy():
		return
	_character = LobbyModel.cycle_character(_character, delta)
	selected.emit(_character)
	_render()


func _render_stage() -> void:
	var info := LobbyModel.character_info(_character, PlayerState.characters)
	_art.character_id = _character
	_art.modulate = Color(0.72, 0.72, 0.8) if info["owned"] == false else Color.WHITE
	_stage_name.text = info["name"]
	_stage_level.text = LobbyModel.level_text(info)
	var g := EquipmentModel.worn_gun(PlayerState.equipment, PlayerState.catalog, _character)
	_gun_stand.set_gun(g["kind"], g["tier"])
	_gun_stand.modulate = _art.modulate
	_gun_stand.visible = not _art.holds_gun()


# ── Right panel ─────────────────────────────────────────────────────────────

func _build_right() -> void:
	var panel := LobbyUi.panel(18, 20)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -(RIGHT_W + MARGIN)
	panel.offset_right = -MARGIN
	panel.offset_top = 8
	panel.offset_bottom = -MARGIN
	add_child(panel)
	var col := Ui.vbox(12)
	panel.add_child(col)
	var tabs := Ui.hbox(8)
	col.add_child(tabs)
	_sub_tabs = Ui.tab_row(SUB_TABS, 24, _show_sub, 58)
	for b in _sub_tabs:
		tabs.add_child(b)
	var pages := Control.new()
	pages.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(pages)

	var gear := Ui.vbox(10)
	gear.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	pages.add_child(gear)
	_pages.append(gear)
	var head := Ui.hbox(10)
	gear.add_child(head)
	_list_title = LobbyUi.text("", 24, Color.WHITE, true)
	_list_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_list_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_list_title)
	_list_all = Ui.button("Tất cả", 20)
	_list_all.custom_minimum_size = Vector2(120, 46)
	_list_all.focus_mode = FOCUS_NONE
	_list_all.pressed.connect(func(): _filter(""))
	head.add_child(_list_all)
	_list_status = LoadStatus.new()
	gear.add_child(_list_status)
	_list = Ui.vbox(8)
	gear.add_child(Ui.scroll(_list))

	_stats = StatsPanel.new()
	_stats.overlay = overlay
	_stats.open_shop_characters.connect(func(): open_shop.emit(ShopTab.CHARACTERS))
	_stats.busy_changed.connect(func(busy: bool):
		for a in _arrows:
			a.disabled = busy)
	var stats_scroll := Ui.scroll(_stats)
	stats_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	pages.add_child(stats_scroll)
	_pages.append(stats_scroll)


func _render_list() -> void:
	var error := PlayerState.catalog_error if PlayerState.catalog_error != "" else PlayerState.equipment_error
	if error != "":
		_list_status.show_error(error, PlayerState.retry_equipment)
	elif PlayerState.equipment == null or PlayerState.catalog == null:
		_list_status.show_loading()
	else:
		_list_status.clear()
	_list_title.text = "Tất cả trang bị" if _slot == "" else EquipmentModel.slot_name(_slot)
	_list_all.visible = _slot != ""
	Ui.clear(_list)
	if PlayerState.equipment == null:
		return
	var pieces := EquipmentModel.sort_for_character(EquipmentModel.filter_slot(PlayerState.equipment, _slot),
		PlayerState.catalog, _character, PlayerState.characters)
	if pieces.is_empty():
		_list.add_child(LobbyUi.text("Chưa có trang bị nào" if _slot == "" else "Chưa có %s nào" % EquipmentModel.slot_name(_slot).to_lower(), 22, Ui.TEXT_DIM))
		var shop := Ui.button("Mua ở Shop", 22)
		shop.custom_minimum_size = Vector2(240, 60)
		shop.focus_mode = FOCUS_NONE
		shop.size_flags_horizontal = SIZE_SHRINK_BEGIN
		shop.pressed.connect(func(): open_shop.emit(ShopTab.EQUIPMENT))
		_list.add_child(shop)
		return
	var worn := EquipmentModel.worn(PlayerState.equipment, _character)
	for p in pieces:
		_list.add_child(_row(p, worn))


func _row(piece: Dictionary, worn: Dictionary) -> Control:
	var item := EquipmentModel.item_of_piece(PlayerState.catalog, piece)
	var who := EquipmentModel.wearer(piece)
	var mine := who == _character
	var check := EquipmentModel.can_wear(item, _character, PlayerState.characters)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 100)
	b.focus_mode = FOCUS_NONE
	if mine:
		LobbyUi.style_button(b, Color(0.12, 0.24, 0.42, 0.92), 14, 8, Color(0.35, 0.8, 0.45, 0.85), 2)
	else:
		LobbyUi.style_button(b, Color(0.08, 0.11, 0.26, 0.85), 14, 8, Color(1, 1, 1, 0.08), 2)
	b.pressed.connect(func(): EquipmentUi.open_piece(overlay, piece, _character))
	var row := Ui.hbox(14)
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.offset_top = 6
	row.offset_bottom = -10
	row.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := EquipmentUi.item_icon(item, piece, 74)
	icon.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(icon)
	var texts := Ui.vbox(2)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.custom_minimum_size.x = 210
	texts.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var title := LobbyUi.text(EquipmentModel.display_name(item), 24, UpgradeModel.name_color(piece), true)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = MOUSE_FILTER_IGNORE
	texts.add_child(title)
	var sub := LobbyUi.text("%s · %s" % [EquipmentModel.slot_name(str(item.get("slot", ""))), EquipmentModel.required_text(item)], 18, Color(0.8, 0.88, 1.0))
	sub.mouse_filter = MOUSE_FILTER_IGNORE
	texts.add_child(sub)
	if mine:
		texts.add_child(EquipmentUi.tag("Đang mặc", Color(0.2, 0.55, 0.3, 0.95), 17))
	elif who != "":
		texts.add_child(EquipmentUi.tag(EquipmentModel.worn_text(piece), Color(0.3, 0.32, 0.5, 0.95), 17))
	elif not check["ok"]:
		texts.add_child(EquipmentUi.tag(check["reason"], Color(0.6, 0.2, 0.2, 0.95), 17))
	var right := Ui.vbox(2)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(right)
	if mine:
		var stats := LobbyUi.text(EquipmentModel.stat_summary(EquipmentModel.piece_item(PlayerState.catalog, piece), EquipmentUi.multipliers()), 19, Color.WHITE)
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats.mouse_filter = MOUSE_FILTER_IGNORE
		right.add_child(stats)
	else:
		var current: Dictionary = worn.get(str(piece.get("slot", "")), {})
		var deltas := EquipmentUi.delta_row(EquipmentModel.piece_item(PlayerState.catalog, piece), EquipmentModel.piece_item(PlayerState.catalog, current) if not current.is_empty() else {})
		deltas.alignment = FlowContainer.ALIGNMENT_END
		right.add_child(deltas)
	if not mine and not check["ok"]:
		b.modulate = Color(1, 1, 1, 0.5)
	return b


# ── Everything ──────────────────────────────────────────────────────────────

func _render() -> void:
	if _art == null:
		return
	_render_slots()
	_render_stage()
	_render_list()
	_stats.show_character(_character)
