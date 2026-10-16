extends Control
## Loadout before Quick Play ("Chuẩn bị", opened by the lobby's "BẮT ĐẦU"): pick up to three
## items, then "Vào trận" sends QuickPlay {bot?, characterId, items} through the QuickPlay
## helper. The character is the one chosen in the lobby (saved in the shared settings file) and
## shows read-only on the left with its level; the mode ({} practice target, {"bot": "ai"}) is
## the lobby's, in Router.quick_play_base, named in the header. The picked items sit in three
## slots above the item grid; tapping a slot (or the picked item) drops it. Item ownership comes
## from the API; a failed request only hides the "xN" notes, it never blocks playing. Drawn in
## the lobby look (backdrop, translucent panels, the yellow start button).

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const CharacterView := preload("res://ui/character_view.gd")
const Art := preload("res://ui/art.gd")
const Items := preload("res://match/items.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const QuickPlay := preload("res://screens/quick_play.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const SETTINGS_PATH := LoadoutModel.SETTINGS_PATH

const MARGIN := 18
const CARD := Color(0.08, 0.12, 0.3, 0.72)
const CARD_PICKED := Color(0.2, 0.38, 0.75, 0.95)
const NOTE_OWNED := Color(0.45, 0.9, 0.55)
## The pedestal image (assets/env/pedestal.png) drawn at this scale under the character.
const PEDESTAL_SCALE := Vector2(0.66, 0.6)

var _model := LoadoutModel.new()
var _base: Dictionary = {}
var _quick_play: QuickPlay

# Character panel
var _art: CharacterView
var _char_name: Label
var _char_level: Label
var _char_role: Label
var _char_skill: Label
var _char_stats: GridContainer
var _gear_frames := {} # slot -> TextureRect (the small hexagon)
var _gear_icons := {} # slot -> TextureRect

var _slot_buttons: Array[Button] = []
var _slot_icons: Array[TextureRect] = []
var _slot_names: Array[Label] = []
var _item_buttons := {} # itemId -> Button
var _item_notes := {} # itemId -> Label ("x2" / "Chưa sở hữu")
var _item_checks := {} # itemId -> TextureRect (the check mark while picked)
var _count: Label
var _status: Label
var _conn: Label
var _back: Button
var _play: Button


func _ready() -> void:
	theme = LobbyUi.theme()
	_base = Router.quick_play_base.duplicate()
	_model.restore(SETTINGS_PATH)
	_quick_play = QuickPlay.new()
	add_child(_quick_play)
	_quick_play.changed.connect(_refresh) # also on connect / disconnect

	var bg := Backdrop.new()
	bg.ground = false
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
	right.add_child(_build_footer())

	PlayerState.characters_changed.connect(_render_character)
	PlayerState.equipment_changed.connect(_render_gear)
	PlayerState.characters_changed.connect(_render_gear) # the stat multipliers of the tooltips
	PlayerState.need_characters()
	PlayerState.need_equipment()
	_render_character()
	_render_gear()
	_refresh()
	_fetch_inventory()


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
	var mode: Dictionary = LobbyModel.MODES[LobbyModel.mode_of_base(_base)]
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


## The lobby's character, read-only: art on a small pedestal, name, level, role, skill and
## stats (once the characters cache is loaded).
func _build_character_panel() -> Control:
	var card := LobbyUi.panel(20, 22)
	card.custom_minimum_size.x = 380
	var col := Ui.vbox(6)
	card.add_child(col)
	var tag := LobbyUi.text("Nhân vật", 22, Ui.TEXT_DIM, true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
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
	stage.add_child(_art)
	_char_name = _centered(col, 36, Color.WHITE, true)
	_char_level = _centered(col, 24, LobbyUi.GOLD, true)
	_char_role = _centered(col, 22, Ui.TEXT_DIM)
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


## The worn gear: one small hexagon per slot (EquipmentModel.SLOTS order), read-only.
func _build_gear_row() -> Control:
	var col := Ui.vbox(4)
	var tag := LobbyUi.text("Trang bị", 20, Ui.TEXT_DIM, true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var row := Ui.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for slot in EquipmentModel.SLOTS:
		var frame := TextureRect.new()
		frame.texture = Art.equipment_frame("hex_empty")
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		frame.custom_minimum_size = Vector2(52, 60)
		frame.mouse_filter = MOUSE_FILTER_PASS # shows the tooltip
		frame.tooltip_text = EquipmentModel.slot_name(slot)
		row.add_child(frame)
		var icon := LobbyUi.icon(Art.equipment_slot_icon(slot), 34)
		icon.position = Vector2(9, 13)
		icon.size = Vector2(34, 34)
		frame.add_child(icon)
		_gear_frames[slot] = frame
		_gear_icons[slot] = icon
	return col


func _render_gear() -> void:
	var worn := EquipmentModel.worn(PlayerState.equipment, _model.character_id)
	for slot in EquipmentModel.SLOTS:
		var piece: Dictionary = worn.get(slot, {})
		var icon: TextureRect = _gear_icons[slot]
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
			# "Bazooka Sắt +3" over "Sát thương +8 điểm (+40)" (points only until the characters load).
			var tip := "%s %s" % [EquipmentModel.display_name(item), EquipmentModel.level_text(piece)]
			var stats := EquipmentModel.stat_summary(item, BattleStats.multipliers(PlayerState.characters))
			_gear_frames[slot].tooltip_text = tip + ("\n" + stats if stats != "" else "")


static func _centered(parent: Control, font_size: int, color: Color, heavy: bool = false) -> Label:
	var l := LobbyUi.text("", font_size, color, heavy)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _draw_pedestal(c: Control) -> void:
	var center := Vector2(c.size.x / 2, c.size.y - 22)
	var tex := Art.env("pedestal")
	c.draw_texture_rect(tex, Rect2(center - Art.PEDESTAL_CENTER * PEDESTAL_SCALE, tex.get_size() * PEDESTAL_SCALE), false)


## "Mang theo n/3" and the three slots, in the order picked.
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
	var row := Ui.hbox(14)
	col.add_child(row)
	for i in Items.MAX_LOADOUT:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.pressed.connect(_on_slot.bind(i))
		var line := Ui.hbox(12)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		b.add_child(line)
		var icon := LobbyUi.icon("plus", 44)
		line.add_child(icon)
		var item_name := LobbyUi.text("", 24, Color.WHITE, true)
		item_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(item_name)
		for c in [line, icon, item_name]:
			c.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(b)
		_slot_buttons.append(b)
		_slot_icons.append(icon)
		_slot_names.append(item_name)
	return card


## The eight items, four per row: icon, name and how many are owned ("xN" / "Chưa sở hữu").
func _build_item_grid() -> Control:
	var card := LobbyUi.panel(18, 22)
	var col := Ui.vbox(10)
	card.add_child(col)
	col.add_child(LobbyUi.text("Vật phẩm", 26, Color.WHITE, true))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	col.add_child(grid)
	for id in Items.ORDER:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 116)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.size_flags_vertical = SIZE_EXPAND_FILL
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
		_centered(inner, 22, Color.WHITE, true).text = Items.label(id)
		var note := _centered(inner, 19, Ui.TEXT_DIM, true)
		var check := LobbyUi.icon("check", 34)
		check.position = Vector2(10, 8)
		check.size = Vector2(34, 34)
		b.add_child(check)
		for c in [inner, check] + inner.get_children():
			c.mouse_filter = MOUSE_FILTER_IGNORE
		grid.add_child(b)
		_item_buttons[id] = b
		_item_notes[id] = note
		_item_checks[id] = check
	return card


## The QuickPlay status (pending, slow, RoomError, disconnect) and "VÀO TRẬN".
func _build_footer() -> Control:
	var row := Ui.hbox(18)
	_status = LobbyUi.text("", 24, Color.WHITE, true)
	_status.size_flags_horizontal = SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_status)
	_play = LobbyUi.start_button("VÀO TRẬN")
	_play.custom_minimum_size.x = 380
	_play.pressed.connect(_on_play)
	row.add_child(_play)
	return row


# ── Data and actions ────────────────────────────────────────────────────────

func _fetch_inventory() -> void:
	var res: Dictionary = await Api.get_json("/player/inventory")
	if res.ok:
		_model.item_counts = LoadoutModel.parse_inventory(res.data)
		_refresh()


## A full loadout disables the other items, so a fourth cannot be picked.
func _on_item(id: String) -> void:
	_model.toggle_item(id)
	_model.remember(SETTINGS_PATH)
	_refresh()


func _on_slot(index: int) -> void:
	var id: String = _model.slots()[index]
	if id != "":
		_on_item(id)


func _on_play() -> void:
	_model.remember(SETTINGS_PATH)
	_quick_play.request(_model.payload(_base))


func _on_back() -> void:
	if _quick_play.pending:
		return
	Router.go(Router.HOME)


func _render_character() -> void:
	var info := LobbyModel.character_info(_model.character_id, PlayerState.characters)
	_art.character_id = _model.character_id
	_art.modulate = Color(0.72, 0.72, 0.8) if info["owned"] == false else Color.WHITE
	_char_name.text = info["name"]
	_char_level.text = LobbyModel.level_text(info)
	_char_role.text = info["role"]
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
		b.modulate = Color(1, 1, 1, 0.45) if b.disabled and not picked else Color.WHITE
	_count.text = "Mang theo  %d/%d" % [_model.items.size(), Items.MAX_LOADOUT]
	if GameSocket.is_open():
		_conn.text = "● Online"
		_conn.add_theme_color_override("font_color", Ui.TONES["good"])
	else:
		_conn.text = "○ Đang kết nối..."
		_conn.add_theme_color_override("font_color", Ui.TONES["draw"])
	_status.text = _quick_play.status
	_status.add_theme_color_override("font_color", Color.WHITE if locked else Ui.TONES["error"])
	_play.disabled = not _quick_play.can_request()
	_back.disabled = locked
