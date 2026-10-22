extends Control
## "Chọn chế độ" (a Home page, opened by the lobby's mode card): one tab per section of
## ModeSelectModel.sections() (the game data's categories in order: PvP, Boss, ...), the tab row
## of the other Home pages (Ui.tab_row). A cards section (PvP) shows one big card per mode in its
## order: the icon on a round plate, the name, the description, the party badge ("2 người"), for a
## ranked mode the player's tier badge and "Bạc II · 1.050 điểm"; the chosen mode framed and tagged
## "Đang chọn". A grid section (Boss) shows a grid of small cards, one per mode. A section without
## modes shows one disabled card: "Sắp ra mắt" and its line ("Phòng 4 người cùng đánh boss").
## A tap emits chosen(index); Home goes back to the lobby, which switches to it (choose_mode()).
## Rebuilt by show_for() each time it opens, so a mode or category an admin added shows.

signal chosen(index: int)

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const ModeSelectModel := preload("res://screens/home/mode_select_model.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const TierBadge := preload("res://screens/ranked/tier_badge.gd")

const CARD := Vector2(350, 520)
const SMALL := Vector2(300, 250)
const ICON := 132
const ICON_SMALL := 96
const PLATES := ["blue", "orange", "purple", "green", "red"] # the icon plate's colour by card order

var _current := 0
var _tab := 0
var _tab_row: HBoxContainer
var _tabs: Array[Button] = []
var _body: Control


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var col := Ui.vbox(18)
	margin.add_child(col)
	_tab_row = Ui.hbox(8)
	col.add_child(_tab_row)
	_body = Control.new()
	_body.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(_body)
	PlayerState.rank_changed.connect(func() -> void:
		if is_visible_in_tree():
			_render())
	_render()


## Opens on the tab of the mode at `current`, that card highlighted.
func show_for(current: int) -> void:
	_current = current
	_tab = ModeSelectModel.section_of(current)
	if is_inside_tree():
		_render()


func show_tab(index: int) -> void:
	_tab = index
	_render()


## The tab shown (tests, the smoke harness).
func tab() -> int:
	return _tab


func _render() -> void:
	if _body == null:
		return
	var sections := ModeSelectModel.sections(_current)
	_tab = clampi(_tab, 0, maxi(sections.size() - 1, 0))
	Ui.clear(_tab_row)
	_tabs = Ui.tab_row(sections.map(func(s): return s["name"]), 26, show_tab)
	for b in _tabs:
		_tab_row.add_child(b)
	Ui.select_tab(_tabs, _tab)
	Ui.clear(_body)
	if sections.is_empty():
		return
	var section: Dictionary = sections[_tab]
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var flow := HFlowContainer.new()
	flow.name = "Cards"
	flow.size_flags_horizontal = SIZE_EXPAND_FILL
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 24)
	flow.add_theme_constant_override("v_separation", 24)
	scroll.add_child(flow)
	var grid: bool = section["layout"] == ModeSelectModel.GRID
	if section["modes"].is_empty():
		flow.add_child(_soon_card(ModeSelectModel.placeholder(section["categoryId"]), grid))
		return
	var order := 0
	for c in section["modes"]:
		flow.add_child(_small_card(c, order) if grid else _big_card(c, order))
		order += 1


## A card button: the panel 9-patch (panel_selected for the chosen mode), the content in a
## column that ignores the mouse.
func _card_button(size_px: Vector2, selected: bool) -> Array:
	var b := Button.new()
	b.custom_minimum_size = size_px
	LobbyUi.texture_button(b, "panel_selected" if selected else "panel", 0, true)
	var col := Ui.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		col.set("offset_" + side, 22 * (1 if side in ["left", "top"] else -1))
	col.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(col)
	return [b, col]


## The icon on a round plate.
static func _plate(icon_name: String, px: int, color: Color) -> Control:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", LobbyUi.box(color, px / 2, 0, Color(1, 1, 1, 0.85), 3))
	plate.custom_minimum_size = Vector2(px, px)
	plate.size_flags_horizontal = SIZE_SHRINK_CENTER
	plate.mouse_filter = MOUSE_FILTER_IGNORE
	var icon := LobbyUi.icon(icon_name, int(px * 0.62))
	icon.size_flags_horizontal = SIZE_SHRINK_CENTER
	plate.add_child(icon)
	return plate


static func _centered(text: String, font_size: int, color: Color, heavy: bool = false) -> Label:
	var l := LobbyUi.text(text, font_size, color, heavy)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l


## A small pill ("2 người", "Đang chọn").
static func _pill(text: String, bg: Color, fg: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", LobbyUi.box(bg, 14, 0))
	p.size_flags_horizontal = SIZE_SHRINK_CENTER
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var l := LobbyUi.text(text, 20, fg, true)
	l.custom_minimum_size = Vector2(0, 32)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.mouse_filter = MOUSE_FILTER_IGNORE
	m.add_child(l)
	p.add_child(m)
	return p


static func _plate_color(order: int) -> Color:
	return LobbyUi.ICON_COLORS[PLATES[order % PLATES.size()]]


## A PvP-style card: icon, name, description, the party badge, the rank line of a ranked mode.
func _big_card(c: Dictionary, order: int) -> Button:
	var parts := _card_button(CARD, c["selected"])
	var b: Button = parts[0]
	var col: VBoxContainer = parts[1]
	b.name = "Mode_%s" % c["id"]
	col.add_child(_plate(c["icon"], ICON, _plate_color(order)))
	col.add_child(_centered(c["name"], 34, Color.WHITE, true))
	var desc := _centered(c["description"], 22, Color(0.75, 0.9, 1.0))
	desc.custom_minimum_size.x = CARD.x - 44
	col.add_child(desc)
	var badges := Ui.hbox(8)
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.mouse_filter = MOUSE_FILTER_IGNORE
	if c["badge"] != "":
		badges.add_child(_pill(c["badge"], LobbyUi.ICON_COLORS["blue"], Color.WHITE))
	if c["selected"]:
		badges.add_child(_pill("Đang chọn", LobbyUi.GOLD, LobbyUi.TEXT_DARK))
	col.add_child(badges)
	if c["ranked"]:
		col.add_child(_rank_row())
	b.pressed.connect(func() -> void: chosen.emit(int(c["index"])))
	return b


## The player's tier badge and "Bạc II · 1.050 điểm" ("Đang tải hạng..." until GET /rank/me).
func _rank_row() -> Control:
	var row := Ui.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var data := PlayerState.my_rank()
	var r := RankModel.from_me(data)
	var tier: String = r["tier"] if not data.is_empty() else ""
	row.add_child(TierBadge.make(tier, r["division"], 40))
	var line := LobbyUi.text(RankModel.mode_line(r) if not data.is_empty() else "Đang tải hạng...", 22,
		TierBadge.COLORS[tier if TierBadge.COLORS.has(tier) else ""][0], true)
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(line)
	return row


## A boss-style card in the grid: icon and name, the party badge.
func _small_card(c: Dictionary, order: int) -> Button:
	var parts := _card_button(SMALL, c["selected"])
	var b: Button = parts[0]
	var col: VBoxContainer = parts[1]
	b.name = "Mode_%s" % c["id"]
	col.add_child(_plate(c["icon"], ICON_SMALL, _plate_color(order)))
	col.add_child(_centered(c["name"], 28, Color.WHITE, true))
	if c["badge"] != "":
		col.add_child(_pill(c["badge"], LobbyUi.ICON_COLORS["blue"], Color.WHITE))
	b.pressed.connect(func() -> void: chosen.emit(int(c["index"])))
	return b


## A section without modes: one disabled card.
func _soon_card(p: Dictionary, grid: bool) -> Button:
	var parts := _card_button(SMALL if grid else CARD, false)
	var b: Button = parts[0]
	var col: VBoxContainer = parts[1]
	b.name = "ComingSoon"
	b.disabled = true
	col.modulate = Color(1, 1, 1, 0.75)
	col.add_child(_plate("unknown", ICON_SMALL, Color(0.3, 0.32, 0.42)))
	col.add_child(_centered(p["title"], 30, LobbyUi.GOLD, true))
	var line := _centered(p["text"], 22, Color(0.8, 0.86, 1.0))
	line.custom_minimum_size.x = (SMALL.x if grid else CARD.x) - 44
	col.add_child(line)
	return b
