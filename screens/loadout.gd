extends Control
## Loadout before Quick Play ("Chuẩn bị", opened by the lobby's "BẮT ĐẦU"): pick up to the mode's
## item count (its maxItems: 6 for a boss fight; the global itemRules.maxLoadout, 3, otherwise)
## items, then "Vào trận" sends QuickPlay {bot?, characterId, items} through the QuickPlay
## helper; on a queue mode (Đấu hạng, Đấu thường) "Tìm trận" opens Matchmaking on its queue
## (Router.queue) with {characterId, items} (Router.ranked_loadout) instead; the party's member (Router.party) gets "SẴN SÀNG" there, which
## sends UpdateLoadout {characterId, items} + SetReady true and goes back Home. The character is the one chosen in the lobby (saved in the shared settings file) and
## shows read-only on the left with its level; the mode ({} practice target, {"bot": "ai"}) is
## the lobby's, in Router.quick_play_base, named in the header. The picked items sit in the
## mode's slots above the item grid (one row; 6 slots in two rows of 3) (five per row, scrolling when the window is short); tapping a slot
## (or the picked item) drops it. Item ownership comes from GET /player/inventory (fetched on
## open, after assets change and after a refused QuickPlay): an item with none left is dimmed,
## tapping it shows a hint instead of picking it, and a saved pick of it is dropped
## (LoadoutModel.set_counts). A failed request only hides the "xN" notes, it never blocks
## playing; "Vào trận" fetches the counts once more first when they are still unknown. Drawn in
## the lobby look (backdrop, translucent panels, the yellow start button).

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const CharacterView := preload("res://ui/character_view.gd")
const ElementBadge := preload("res://ui/element_badge.gd")
const ElementChain := preload("res://ui/element_chain.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const PedestalGun := preload("res://screens/home/pedestal_gun.gd")
const Art := preload("res://ui/art.gd")
const Items := preload("res://match/items.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const PartyModel := preload("res://screens/home/party_model.gd")
const QuickPlay := preload("res://screens/quick_play.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const UpgradeAura := preload("res://screens/home/upgrade_aura.gd")
const TitlePlate := preload("res://ui/title_plate.gd")
const SETTINGS_PATH := LoadoutModel.SETTINGS_PATH

const MARGIN := 18
const CARD := Color(0.08, 0.12, 0.3, 0.72)
const CARD_PICKED := Color(0.2, 0.38, 0.75, 0.95)
const NOTE_OWNED := Color(0.45, 0.9, 0.55)
const ITEM_COLUMNS := 5
const SLOTS_ONE_ROW := 4 # item slots in one row at most; more take two rows (a boss fight's 6: 3 + 3)
const SLOT_H := 92
const SLOT_H_COMPACT := 72 # a slot's height in two rows
const ITEM_GAP := 12
## Card height: the rows share the scroll's height, between these (below the minimum it scrolls).
const ITEM_CARD_MIN := 104
const ITEM_CARD_MAX := 170
const HINT_SEC := 2.0 # the "Vật phẩm" header hint, then it fades
const DIM := Color(1, 1, 1, 0.45) # a card that cannot be picked
## The pedestal image (assets/env/pedestal.png) drawn at this scale under the character.
const PEDESTAL_SCALE := Vector2(0.66, 0.6)

var _model := LoadoutModel.new()
var _base: Dictionary = {}
var _quick_play: QuickPlay

# Character panel
var _art: CharacterView
var _char_name_row: HBoxContainer # the element badge before the name
var _char_element: ElementChain # beaten by → the element → beats, as badges
var _gun_stand: PedestalGun
var _char_title: TitlePlate # the worn title at the top of the panel (hidden without one)
var _char_top: Control # a little room above the art when there is no title
var _char_name: Label
var _char_level: Label
var _char_role: Label
var _char_skill: Label
var _char_stats: GridContainer
var _gear_frames := {} # slot -> TextureRect (the small hexagon)
var _gear_icons := {} # slot -> TextureRect
var _gear_auras := {} # slot -> UpgradeAura on the hexagon

var _slot_buttons: Array[Button] = []
var _slot_icons: Array[TextureRect] = []
var _slot_names: Array[Label] = []
var _item_buttons := {} # itemId -> Button
var _item_notes := {} # itemId -> Label ("x2" / "Chưa sở hữu")
var _item_checks := {} # itemId -> TextureRect (the check mark while picked)
var _count: Label
var _hint: Label # "Chưa sở hữu vật phẩm này" / items dropped, beside "Vật phẩm"
var _hint_tween: Tween
var _item_scroll: ScrollContainer
var _status: Label
var _conn: Label
var _back: Button
var _play: Button
var _inventory_seq := 0 # the latest GET /player/inventory; older answers are dropped
var _checking := false # "Vào trận" waits for the counts
var _member := false # the ranked party's member: "SẴN SÀNG" readies instead of queueing


func _ready() -> void:
	theme = LobbyUi.theme()
	_base = Router.quick_play_base.duplicate()
	_member = LobbyModel.is_queue(_base) and Router.party != null and Router.party.model.is_member()
	_model.set_max_items(LobbyModel.max_items(_base)) # the mode's item slots (6 in a boss fight)
	_model.restore(SETTINGS_PATH)
	_quick_play = QuickPlay.new()
	add_child(_quick_play)
	_quick_play.changed.connect(_refresh) # also on connect / disconnect

	var bg := Backdrop.new() # the night sky (Art.BG_HOME)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var col := Ui.vbox(16)
	margin.add_child(col)
	col.add_child(_build_header())
	var body := Ui.hbox(18)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(body)
	body.add_child(_build_character_panel())
	var right := Ui.vbox(16)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(_build_slots())
	var grid := _build_item_grid()
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(grid)
	_quick_play.refused.connect(_on_refused)
	PlayerState.assets_dirty.connect(_fetch_inventory) # a match or a purchase changed the counts
	right.add_child(_build_footer())

	PlayerState.characters_changed.connect(_render_character)
	PlayerState.changed.connect(_render_title)
	PlayerState.equipment_changed.connect(_render_gear)
	PlayerState.characters_changed.connect(_render_gear) # the stat multipliers of the tooltips
	PlayerState.need_characters()
	PlayerState.need_equipment()
	_render_character()
	_render_title()
	_render_gear()
	_refresh()
	_fetch_inventory()


func _render_title() -> void:
	_char_title.set_title(PlayerState.equipped_title())
	_char_top.visible = not _char_title.has_title()


# ── Layout ──────────────────────────────────────────────────────────────────

## "← Sảnh", the title, the connection state and the mode pill.
func _build_header() -> Control:
	var row := Ui.hbox(20)
	_back = LobbyUi.pill_button("Sảnh", 26, 64, "back")
	LobbyUi.texture_button(_back, "pill", 22, true)
	_back.pressed.connect(_on_back)
	row.add_child(_back)
	var title := LobbyUi.text("Chuẩn bị", 36, Color.WHITE, true)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(title)
	_conn = LobbyUi.text("", 22, Color.WHITE, true)
	_conn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_conn)
	var mode: Dictionary = LobbyModel.mode(LobbyModel.mode_of_base(_base))
	var pill := LobbyUi.panel(0, 32)
	pill.custom_minimum_size.y = 64
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 26)
	inner.add_theme_constant_override("margin_right", 26)
	pill.add_child(inner)
	var texts := Ui.hbox(14)
	inner.add_child(texts)
	LobbyUi.icon_text(texts, "battle", str(mode["name"]), 26, LobbyUi.GOLD, true, 32)
	var desc := LobbyUi.text(str(mode["description"]), 20, Color(0.75, 0.9, 1.0))
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texts.add_child(desc)
	row.add_child(pill)
	return row


## The lobby's character, read-only: the worn title on top (nothing without one), art on a
## small pedestal, name, level, role, skill and stats (once the characters cache is loaded).
func _build_character_panel() -> Control:
	var card := LobbyUi.panel(20, 22)
	card.custom_minimum_size.x = 380
	var col := Ui.vbox(6)
	card.add_child(col)
	_char_title = TitlePlate.new()
	_char_title.plate_height = 38
	_char_title.max_width = 336
	_char_title.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(_char_title)
	_char_top = Control.new()
	_char_top.custom_minimum_size.y = 10
	col.add_child(_char_top)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 260)
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	stage.draw.connect(_draw_pedestal.bind(stage))
	stage.resized.connect(stage.queue_redraw)
	col.add_child(stage)
	_art = CharacterView.new()
	_art.idle = true
	_art.anchor_left = 0.5
	_art.anchor_right = 0.5
	_art.offset_left = -112
	_art.offset_right = 112
	_art.offset_top = 0
	_art.offset_bottom = 246 # feet on the pedestal
	_art.back_aura = true # the worn weapon's +14 / +16 ring, behind the body and the pedestal gun
	stage.add_child(_art)
	_gun_stand = PedestalGun.new() # beside the full-body picture (it holds no gun), as on the lobby
	_gun_stand.scale = Vector2.ONE * GUN_STAND_SCALE
	_gun_stand.size = PedestalGun.STAGE_RECT.size
	stage.add_child(_gun_stand)
	stage.resized.connect(_place_gun_stand.bind(stage))
	_char_name = _centered(col, 36, Color.WHITE, true)
	col.remove_child(_char_name)
	_char_name_row = ElementBadge.name_row(_char_name, "", 36, 8)
	col.add_child(_char_name_row)
	_char_level = _centered(col, 24, LobbyUi.GOLD, true)
	_char_role = _centered(col, 22, Ui.TEXT_DIM)
	_char_element = ElementChain.make("", 34)
	_char_element.name = "ElementChain"
	col.add_child(_char_element)
	var skill_row := CenterContainer.new()
	col.add_child(skill_row)
	_char_skill = LobbyUi.icon_text(skill_row, "skill", "", 22, Color(0.75, 0.9, 1.0), false, 26)
	_char_stats = GridContainer.new()
	_char_stats.columns = 2
	_char_stats.add_theme_constant_override("h_separation", 16)
	_char_stats.add_theme_constant_override("v_separation", 2)
	var stats_box := MarginContainer.new()
	for side in ["left", "right", "top"]:
		stats_box.add_theme_constant_override("margin_" + side, 12 if side == "top" else 8)
	stats_box.add_child(_char_stats)
	col.add_child(stats_box)
	col.add_child(_build_gear_row())
	var filler := Control.new()
	filler.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(filler)
	_centered(col, 20, Ui.TEXT_DIM).text = "Đổi nhân vật ở Sảnh"
	return card


## The worn gear: one small hexagon per slot (EquipmentModel.slots() order), read-only.
func _build_gear_row() -> Control:
	var col := Ui.vbox(4)
	var tag := LobbyUi.text("Trang bị", 20, Ui.TEXT_DIM, true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var row := Ui.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for slot in EquipmentModel.slots():
		var frame := TextureRect.new()
		frame.texture = Art.equipment_frame("hex_empty")
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		frame.custom_minimum_size = Vector2(52, 60)
		frame.mouse_filter = MOUSE_FILTER_PASS # shows the tooltip
		frame.tooltip_text = EquipmentModel.slot_name(slot)
		row.add_child(frame)
		var aura := UpgradeAura.new()
		aura.fit_frame(Rect2(0, 0, 52, 60)) # on the hexagon's edge
		frame.add_child(aura)
		_gear_auras[slot] = aura
		var icon := LobbyUi.icon(Art.equipment_slot_icon(slot), 34)
		icon.position = Vector2(9, 13)
		icon.size = Vector2(34, 34)
		frame.add_child(icon)
		_gear_frames[slot] = frame
		_gear_icons[slot] = icon
	return col


func _render_gear() -> void:
	_render_gun()
	var worn := EquipmentModel.worn(PlayerState.equipment, _model.character_id)
	for slot in EquipmentModel.slots():
		var piece: Dictionary = worn.get(slot, {})
		var icon: TextureRect = _gear_icons[slot]
		var level := int(piece.get("upgradeLevel", 0)) if not piece.is_empty() else 0
		_gear_auras[slot].level = level
		_gear_frames[slot].self_modulate = UpgradeModel.frame_tint(level)
		if piece.is_empty():
			_gear_frames[slot].texture = Art.equipment_frame("hex_empty")
			icon.texture = Art.equipment_slot_icon(slot)
			icon.modulate = Color(0.75, 0.85, 1.0, 0.3)
			_gear_frames[slot].tooltip_text = EquipmentModel.slot_name(slot)
		else:
			var item := EquipmentModel.item_of_piece(PlayerState.catalog, piece)
			_gear_frames[slot].texture = Art.equipment_frame("hex_filled")
			icon.texture = Art.equipment_icon(slot, EquipmentModel.tier(item), EquipmentModel.weapon_kind(item))
			icon.modulate = Color.WHITE
			# "Bazooka Sắt" over "Sát thương +8 điểm (+40)" (points only until the characters load);
			# the aura and frame tint show the level.
			_gear_frames[slot].tooltip_text = EquipmentModel.piece_tooltip(PlayerState.catalog, piece, BattleStats.multipliers(PlayerState.characters))


static func _centered(parent: Control, font_size: int, color: Color, heavy: bool = false) -> Label:
	var l := LobbyUi.text("", font_size, color, heavy)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


## The lobby's gun stand scaled to this stage's character (224 px wide at 1.49 px per unit
## against the lobby's 375 at 2.5), at the same place relative to the feet.
const GUN_STAND_SCALE := 0.6
const ART_FEET_Y := 234.0 # the CharacterView's feet in the stage (246 - 8 units)


func _place_gun_stand(stage: Control) -> void:
	var feet := Vector2(stage.size.x / 2, ART_FEET_Y)
	_gun_stand.position = feet + (PedestalGun.STAGE_RECT.position - PedestalGun.FEET) * GUN_STAND_SCALE


## The worn weapon's gun beside the character, shown while the character holds none.
func _render_gun() -> void:
	if _gun_stand == null:
		return
	var id := _model.character_id
	var g := EquipmentModel.worn_gun(PlayerState.equipment, PlayerState.catalog, id)
	_gun_stand.set_gun(g["kind"], g["tier"])
	_gun_stand.modulate = _art.modulate
	_gun_stand.visible = not _art.holds_gun()


func _draw_pedestal(c: Control) -> void:
	var center := Vector2(c.size.x / 2, c.size.y - 22)
	var tex := Art.env("pedestal")
	c.draw_texture_rect(tex, Rect2(center - Art.PEDESTAL_CENTER * PEDESTAL_SCALE, tex.get_size() * PEDESTAL_SCALE), false)


## "Mang theo n/N" and the mode's N item slots (LoadoutModel.max_items), in the order picked: one
## row up to SLOTS_ONE_ROW, else two rows (6: 3 + 3), a shorter second row centred.
func _build_slots() -> Control:
	var card := LobbyUi.panel(18, 22)
	var col := Ui.vbox(10)
	card.add_child(col)
	var head := Ui.hbox(12)
	col.add_child(head)
	_count = LobbyUi.text("", 26, Color.WHITE, true)
	head.add_child(_count)
	var hint := LobbyUi.text("Nhấn ô để bỏ vật phẩm ra", 20, Ui.TEXT_DIM)
	hint.size_flags_horizontal = SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(hint)
	var rows := slot_rows(_model.max_items)
	var per_row: int = rows[0] if not rows.is_empty() else 0
	var i := 0
	for count in rows:
		var row := Ui.hbox(14)
		col.add_child(row)
		var pad: float = (per_row - int(count)) * 0.5
		if pad > 0.0:
			row.add_child(_slot_pad(pad))
		for k in count:
			row.add_child(_slot_button(i, rows.size() > 1))
			i += 1
		if pad > 0.0:
			row.add_child(_slot_pad(pad))
	return card


## The slots per row for n slots: one row up to SLOTS_ONE_ROW, else two (the first the longer).
static func slot_rows(n: int) -> Array:
	if n <= 0:
		return []
	if n <= SLOTS_ONE_ROW:
		return [n]
	var first := ceili(n / 2.0)
	return [first, n - first]


## Room beside a shorter row (ratio: in slots), so its slots are as wide as the row above.
func _slot_pad(ratio: float) -> Control:
	var c := Control.new()
	c.size_flags_horizontal = SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = ratio
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


func _slot_button(i: int, compact: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, SLOT_H_COMPACT if compact else SLOT_H)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.pressed.connect(_on_slot.bind(i))
	var line := Ui.hbox(12)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	b.add_child(line)
	var icon := LobbyUi.icon("plus", 38 if compact else 44)
	line.add_child(icon)
	var item_name := LobbyUi.text("", 22 if compact else 24, Color.WHITE, true)
	item_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(item_name)
	for c in [line, icon, item_name]:
		c.mouse_filter = MOUSE_FILTER_IGNORE
	_slot_buttons.append(b)
	_slot_icons.append(icon)
	_slot_names.append(item_name)
	return b


## The eight items, ITEM_COLUMNS per row in a vertical scroll (it only scrolls when the window
## is too short for the rows): icon, name and how many are left ("xN" / "Chưa sở hữu").
func _build_item_grid() -> Control:
	var card := LobbyUi.panel(18, 22)
	var col := Ui.vbox(10)
	card.add_child(col)
	var head := Ui.hbox(12)
	col.add_child(head)
	head.add_child(LobbyUi.text("Vật phẩm", 26, Color.WHITE, true))
	_hint = LobbyUi.text("", 22, Ui.TONES["draw"], true)
	_hint.size_flags_horizontal = SIZE_EXPAND_FILL
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_hint)
	var grid := GridContainer.new()
	grid.columns = ITEM_COLUMNS
	grid.add_theme_constant_override("h_separation", ITEM_GAP)
	grid.add_theme_constant_override("v_separation", ITEM_GAP)
	_item_scroll = Ui.scroll(grid)
	_item_scroll.custom_minimum_size.y = ITEM_CARD_MIN # one row at least
	_item_scroll.resized.connect(_fit_item_cards)
	col.add_child(_item_scroll)
	for id in Items.order():
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, ITEM_CARD_MIN)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.mouse_filter = MOUSE_FILTER_PASS # a drag over the cards scrolls the grid
		LobbyUi.style_button(b, CARD, 16, 8, Color(1, 1, 1, 0.12), 2)
		b.add_theme_stylebox_override("pressed", Art.ui_box("panel_selected", 8))
		b.add_theme_stylebox_override("hover_pressed", Art.ui_box("panel_selected", 8, Color(1.08, 1.08, 1.08)))
		b.pressed.connect(_on_item.bind(id))
		var inner := Ui.vbox(0)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		b.add_child(inner)
		var icon := LobbyUi.icon(Art.item_icon(id), 46)
		icon.size_flags_horizontal = SIZE_SHRINK_CENTER
		inner.add_child(icon)
		_centered(inner, 21, Color.WHITE, true).text = Items.label(id)
		var note := _centered(inner, 18, Ui.TEXT_DIM, true)
		var check := LobbyUi.icon("check", 30)
		check.position = Vector2(8, 6)
		check.size = Vector2(30, 30)
		b.add_child(check)
		for c in [inner, check] + inner.get_children():
			c.mouse_filter = MOUSE_FILTER_IGNORE
		grid.add_child(b)
		_item_buttons[id] = b
		_item_notes[id] = note
		_item_checks[id] = check
	return card


## The rows share the scroll's height (ITEM_CARD_MIN..ITEM_CARD_MAX), so a short window
## scrolls and a tall one does not stretch the cards.
func _fit_item_cards() -> void:
	var rows := ceili(Items.order().size() / float(ITEM_COLUMNS))
	var h := floorf((_item_scroll.size.y - ITEM_GAP * (rows - 1)) / rows)
	h = clampf(h, ITEM_CARD_MIN, ITEM_CARD_MAX)
	for id in _item_buttons:
		_item_buttons[id].custom_minimum_size.y = h


## A short message beside "Vật phẩm" that fades out after HINT_SEC.
func _show_hint(message: String) -> void:
	if _hint_tween != null:
		_hint_tween.kill()
	_hint.text = message
	_hint.modulate.a = 1.0
	_hint_tween = _hint.create_tween()
	_hint_tween.tween_interval(HINT_SEC)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.3)


## The QuickPlay status (pending, slow, RoomError, disconnect) and "VÀO TRẬN".
func _build_footer() -> Control:
	var row := Ui.hbox(18)
	_status = LobbyUi.text("", 24, Color.WHITE, true)
	_status.size_flags_horizontal = SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_status)
	_play = LobbyUi.start_button(PartyModel.READY if _member else "TÌM TRẬN" if LobbyModel.is_queue(_base) else "VÀO TRẬN")
	_play.custom_minimum_size.x = 380
	_play.pressed.connect(_on_play)
	row.add_child(_play)
	return row


# ── Data and actions ────────────────────────────────────────────────────────

## GET /player/inventory → the counts; a picked item with none left is dropped (and the
## saved choice with it). Returns the dropped ids ([] also when the request failed).
func _fetch_inventory() -> Array[String]:
	_inventory_seq += 1
	var seq := _inventory_seq
	var res: Dictionary = await Api.get_json("/player/inventory")
	if seq != _inventory_seq or not is_inside_tree():
		return [] as Array[String]
	if not res.ok:
		return [] as Array[String]
	var dropped := _model.set_counts(LoadoutModel.parse_inventory(res.data))
	if not dropped.is_empty():
		_model.remember(SETTINGS_PATH)
		var names := PackedStringArray()
		for id in dropped:
			names.append(Items.label(id))
		_show_hint("Đã bỏ %s: không còn trong kho" % ", ".join(names))
	_refresh()
	return dropped


## The server refused the items: the counts shown may be stale.
func _on_refused(code: String) -> void:
	if code == "LOADOUT_INVALID":
		_fetch_inventory()


## A full loadout disables the other items, so a fourth cannot be picked; an item with none
## left only shows a hint.
func _on_item(id: String) -> void:
	if not _model.items.has(id) and not _model.owns(id):
		_show_hint(LoadoutModel.NOT_OWNED_HINT)
	else:
		_model.toggle_item(id)
		_model.remember(SETTINGS_PATH)
	_refresh()


func _on_slot(index: int) -> void:
	var id: String = _model.slots()[index]
	if id != "":
		_on_item(id)


## Counts still unknown (the request failed): fetched once more first, so an item with none
## left is not sent. When that drops an item the player sees it and presses again.
func _on_play() -> void:
	if _checking:
		return
	if _model.item_counts == null and not _model.items.is_empty():
		_checking = true
		_refresh()
		var dropped := await _fetch_inventory()
		if not is_inside_tree():
			return
		_checking = false
		_refresh()
		if not dropped.is_empty():
			return
	_model.remember(SETTINGS_PATH)
	if _member:
		Router.ranked_loadout = _model.payload({})
		Router.party.confirm_ready(Router.ranked_loadout) # my character and items, then ready
		Router.go(Router.HOME)
		return
	if LobbyModel.is_queue(_base):
		Router.ranked_loadout = _model.payload({}) # {characterId, items}: Matchmaking queues with it
		Router.queue = str(_base["queue"])
		Router.go(Router.MATCHMAKING)
		return
	Router.last_quick_play = _model.payload(_base)
	_quick_play.request(Router.last_quick_play)


func _on_back() -> void:
	if _quick_play.pending:
		return
	Router.go(Router.HOME)


func _render_character() -> void:
	var info := LobbyModel.character_info(_model.character_id, PlayerState.characters)
	_art.character_id = _model.character_id
	_art.modulate = Color(0.72, 0.72, 0.8) if info["owned"] == false else Color.WHITE
	_render_gun()
	_char_name.text = info["name"]
	ElementBadge.set_row_element(_char_name_row, GameData.character_element(_model.character_id))
	_char_level.text = LobbyModel.level_text(info)
	_char_role.text = info["role"]
	_char_element.set_element(GameData.character_element(_model.character_id))
	_char_skill.text = "Kỹ năng: %s" % info["skill"] if info["skill"] != "" else ""
	_char_skill.get_parent().visible = info["skill"] != ""
	Ui.clear(_char_stats)
	for pair in info["stats"]:
		var key := LobbyUi.text(pair[0], 22, Ui.TEXT_DIM)
		key.size_flags_horizontal = SIZE_EXPAND_FILL
		_char_stats.add_child(key)
		var value := LobbyUi.text(pair[1], 22, Color.WHITE, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_char_stats.add_child(value)


## The buttons' pressed look always shows the model, whatever a click did to them.
func _refresh() -> void:
	var locked := _quick_play.pending
	var slots := _model.slots()
	for i in slots.size():
		var id := slots[i]
		var filled := id != ""
		_slot_icons[i].texture = Art.item_icon(id) if filled else Art.icon("plus")
		_slot_names[i].text = Items.label(id) if filled else "Trống"
		var dim := Color.WHITE if filled else Color(1, 1, 1, 0.45)
		_slot_icons[i].modulate = dim
		_slot_names[i].modulate = dim
		var b := _slot_buttons[i]
		if filled:
			LobbyUi.texture_button(b, "panel_selected", 8, true)
		else:
			LobbyUi.style_button(b, Color(0, 0, 0, 0.3), 16, 8, Color(1, 1, 1, 0.22), 2)
			b.add_theme_stylebox_override("disabled", LobbyUi.box(Color(0, 0, 0, 0.3), 16, 8, Color(1, 1, 1, 0.22), 2))
		b.disabled = locked or not filled
	for id in _item_buttons:
		var b: Button = _item_buttons[id]
		var note := _model.item_note(id)
		var label: Label = _item_notes[id]
		label.text = note
		label.add_theme_color_override("font_color", NOTE_OWNED if note.begins_with("x") else Ui.TEXT_DIM)
		var picked := _model.items.has(id)
		b.set_pressed_no_signal(picked)
		_item_checks[id].visible = picked
		b.disabled = locked or (_model.is_full() and not picked)
		# Not disabled when none is left: the tap shows why it cannot be picked.
		b.modulate = DIM if not picked and (b.disabled or not _model.owns(id)) else Color.WHITE
	_count.text = "Mang theo  %d/%d" % [_model.items.size(), _model.max_items]
	if GameSocket.is_open():
		_conn.text = "● Online"
		_conn.add_theme_color_override("font_color", Ui.TONES["good"])
	else:
		_conn.text = "○ Đang kết nối..."
		_conn.add_theme_color_override("font_color", Ui.TONES["draw"])
	_status.text = _quick_play.status
	_status.add_theme_color_override("font_color", Color.WHITE if locked else Ui.TONES["error"])
	_play.disabled = _checking or not _quick_play.can_request()
	_back.disabled = locked
