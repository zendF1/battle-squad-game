extends Control
## "Chọn chế độ" (a Home page, opened by the lobby's mode card): one tab per section of
## ModeSelectModel.sections() (the game data's categories in order: PvP, Boss, ...), the tab row
## of the other Home pages (Ui.tab_row). Every card has the same frame and size (CARD) and the same
## layout: a picture at the same place, the name at the same place under it, an "i" button in the
## top-right corner that opens the popup with the rest (the description, the party size): no
## sentences on the face. A cards section (PvP) shows one card per mode in its order: the icon on a
## round plate (its colour by the card's order) and the name. The Boss section shows one card per
## boss mode (screens/home/boss_card_model.gd): the boss's figure (match/boss/boss_art_view.gd) on
## its element's backdrop, its name with its element badge, and under it a gift box with the
## big-reward runs left today ("×2", dimmed at 0) and a clock with the refill time, from GET
## /boss/runs (loaded when the tab shows, kept BOSS_RUNS_MAX_AGE_MSEC by PlayerState). The chosen
## mode's card has the selected frame. A section without modes shows one disabled card: "Sắp ra
## mắt" (its line in the "i" popup).
## A tap emits chosen(index); Home goes back to the lobby, which switches to it (choose_mode()).
## Rebuilt by show_for() each time it opens, so a mode or category an admin added shows.

signal chosen(index: int)

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const ModeSelectModel := preload("res://screens/home/mode_select_model.gd")
const BossCardModel := preload("res://screens/home/boss_card_model.gd")
const ElementBadge := preload("res://ui/element_badge.gd")
const ElementBackdrop := preload("res://ui/element_backdrop.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const BossArtView := preload("res://match/boss/boss_art_view.gd")

const GlyphIcon := preload("res://ui/glyph_icon.gd")
const Modal := preload("res://ui/modal.gd")

## Every card (PvP, Boss, the grid, the placeholder): one frame, one size, one layout.
const CARD := Vector2(340, 440)
const PAD := 22 # the card's inner margin
const PICTURE_TOP := 54.0 # the picture's top in the card
const PICTURE_H := 250.0 # the picture's box (a plate is centred in it)
const NAME_TOP := PICTURE_TOP + PICTURE_H + 14.0 # the name's row
const NAME_H := 56.0
const FOOT_TOP := NAME_TOP + NAME_H + 4.0 # the boss card's gift / clock row
const ICON := 156
const INFO := 46 # the "i" button
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
	PlayerState.boss_runs_changed.connect(func() -> void:
		if is_visible_in_tree() and _on_boss_tab():
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
	if section["categoryId"] == BossCardModel.CATEGORY:
		PlayerState.load_boss_runs() # a fresh answer re-renders
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
	if section["modes"].is_empty():
		flow.add_child(_soon_card(ModeSelectModel.placeholder(section["categoryId"])))
		return
	if section["categoryId"] == BossCardModel.CATEGORY:
		var bias := int(Time.get_time_zone_from_system().get("bias", 0))
		for c in BossCardModel.cards(_current, PlayerState.my_boss_runs(), bias):
			flow.add_child(_boss_card(c))
		return
	var order := 0
	for c in section["modes"]:
		flow.add_child(_mode_card(c, order))
		order += 1


## A card button of CARD size: the panel 9-patch (panel_selected for the chosen mode).
func _card_button(selected: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.focus_mode = FOCUS_NONE
	LobbyUi.texture_button(b, "panel_selected" if selected else "panel", 0, true)
	return b


## A child of a card at a fixed rect (x from the card's padding, full inner width).
static func _place(card: Control, c: Control, top: float, height: float) -> void:
	c.position = Vector2(PAD, top)
	c.size = Vector2(CARD.x - PAD * 2, height)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(c)


## The "i" button in a card's top-right corner, opening `on_press`'s popup.
static func _add_info(card: Control, button_name: String, on_press: Callable) -> Button:
	var info := GlyphIcon.info_button(on_press, INFO)
	info.name = button_name
	info.position = Vector2(CARD.x - INFO - 12, 12)
	card.add_child(info)
	return info


## The icon on a round plate of `px` (Mode Select's cards, the lobby's mode card).
static func plate(icon_name: String, px: int, color: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", LobbyUi.box(color, px / 2, 0, Color(1, 1, 1, 0.85), 3))
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_horizontal = SIZE_SHRINK_CENTER
	p.size_flags_vertical = SIZE_SHRINK_CENTER
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var icon := LobbyUi.icon(icon_name, int(px * 0.62))
	icon.size_flags_horizontal = SIZE_SHRINK_CENTER
	icon.size_flags_vertical = SIZE_SHRINK_CENTER
	p.add_child(icon)
	return p


## The plate colour of the card at `order` in its section.
static func plate_color(order: int) -> Color:
	return LobbyUi.ICON_COLORS[PLATES[order % PLATES.size()]]


static func _centered(text: String, font_size: int, color: Color, heavy: bool = false) -> Label:
	var l := LobbyUi.text(text, font_size, color, heavy)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l


## A name in the name row, shrunk to fit the card's width on one line.
static func _name_label(text: String, room: float) -> Label:
	var l := _centered(text, 34, Color.WHITE, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	ElementBadge.shrink_to_fit(l, room)
	return l


## A mode card: its icon on its plate, its name; "i": the description and the party size.
func _mode_card(c: Dictionary, order: int) -> Button:
	var b := _card_button(c["selected"])
	b.name = "Mode_%s" % c["id"]
	var pic := CenterContainer.new()
	pic.add_child(plate(c["icon"], ICON, plate_color(order)))
	_place(b, pic, PICTURE_TOP, PICTURE_H)
	_place(b, _name_label(c["name"], CARD.x - PAD * 2), NAME_TOP, NAME_H)
	_add_info(b, "Info_%s" % c["id"], func() -> void:
		show_info(self, c["name"], c["description"], int(c["party_size"]), plate(c["icon"], 96, plate_color(order))))
	b.pressed.connect(func() -> void: chosen.emit(int(c["index"])))
	return b


## The popup of a card's "i": its picture, its name as the title, the description, and the party
## size as people icons ("👤 ×2"); closed by its X or a tap outside.
static func show_info(host: Node, title: String, description: String, party_size: int, picture: Control = null) -> Modal:
	var m := Modal.new()
	m.name = "InfoPopup"
	m.open(host, title, 620)
	m.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_close_x()
	if picture != null:
		var holder := CenterContainer.new()
		holder.add_child(picture)
		m.body.add_child(holder)
	if description != "":
		var d := m.add_text(description, 24)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if party_size >= 1:
		var row := Ui.hbox(8)
		row.name = "PartySize"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(LobbyUi.icon("characters", 40))
		var n := LobbyUi.text("×%d" % party_size, 28, LobbyUi.GOLD, true)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(n)
		m.body.add_child(row)
	return m


## The Boss section is shown.
func _on_boss_tab() -> bool:
	var sections := ModeSelectModel.sections(_current)
	return _tab < sections.size() and sections[_tab]["categoryId"] == BossCardModel.CATEGORY


## A boss card: the figure on its element's backdrop (ElementBackdrop; its colour's glow without
## one) in the picture box, the name with its element badge in the name row, the gift box with the
## big-reward runs left and the clock with the refill time under it; "i": its description and party.
func _boss_card(c: Dictionary) -> Button:
	var b := _card_button(c["selected"])
	b.name = "Boss_%s" % c["id"]
	var art := BossArt.art_of(str(c["boss_id"]))
	var stage := Control.new()
	stage.name = "Stage"
	var stage_size := Vector2(CARD.x - PAD * 2, PICTURE_H)
	var tint := BossArt.accent(art)
	var element := str(c.get("element", ""))
	if element != "": # the boss's element behind the figure (ElementBackdrop), in place of the glow
		var back := ElementBackdrop.new()
		back.element_id = element
		back.radius = 16.0
		back.name = "ElementBackdrop"
		back.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		stage.add_child(back)
	var figure := BossArtView.make(art, stage_size, -1, "portrait")
	var drawn: bool = figure.picture_texture() != null # the drawn portrait floats: its glow round the middle, no shadow
	stage.draw.connect(func() -> void:
		var centre := Vector2(stage.size.x / 2.0, stage.size.y * (0.5 if drawn else 0.62))
		if element == "":
			for i in 5:
				stage.draw_circle(centre, stage.size.y * (0.52 - i * 0.08), Color(tint, 0.06 + i * 0.03))
		if drawn:
			return
		stage.draw_set_transform(Vector2(stage.size.x / 2.0, stage.size.y - 8), 0.0, Vector2(1.0, 0.22))
		stage.draw_circle(Vector2.ZERO, stage.size.x * 0.4, Color(0, 0, 0, 0.35))
		stage.draw_set_transform(Vector2.ZERO))
	figure.name = "Figure"
	stage.add_child(figure)
	_place(b, stage, PICTURE_TOP, PICTURE_H)
	var room := CARD.x - PAD * 2 - (2 * (34 + 8) if element != "" else 0)
	_place(b, ElementBadge.name_row(_name_label(c["name"], room), element, 34, 8), NAME_TOP, NAME_H)
	var foot := Ui.hbox(22)
	foot.name = "Foot"
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	if c["runs_text"] != "":
		var runs := _icon_count(LobbyUi.icon("milestone", 40), c["runs_text"], LobbyUi.GOLD)
		runs.name = "Runs"
		runs.modulate = Color(1, 1, 1, 0.45) if int(c["runs_left"]) == 0 else Color.WHITE
		foot.add_child(runs)
	if c["reset_text"] != "":
		var reset := _icon_count(GlyphIcon.make("clock", 30), c["reset_text"], Color(0.82, 0.88, 1.0))
		reset.name = "Reset"
		foot.add_child(reset)
	_place(b, foot, FOOT_TOP, CARD.y - FOOT_TOP - PAD)
	_add_info(b, "Info_%s" % c["id"], func() -> void:
		show_info(self, c["name"], c["description"], int(c["party_size"])))
	b.pressed.connect(func() -> void: chosen.emit(int(c["index"])))
	return b


## A picture with a number beside it ("🎁 ×2", "🕒 00:00").
static func _icon_count(icon: Control, text: String, color: Color) -> HBoxContainer:
	var row := Ui.hbox(6)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(icon)
	var l := LobbyUi.text(text, 26, color, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(l)
	return row


## A section without modes: one disabled card, "Sắp ra mắt"; its line in the "i" popup.
func _soon_card(p: Dictionary) -> Button:
	var b := _card_button(false)
	b.name = "ComingSoon"
	b.disabled = true
	var pic := CenterContainer.new()
	pic.modulate = Color(1, 1, 1, 0.75)
	pic.add_child(plate("unknown", ICON, Color(0.3, 0.32, 0.42)))
	_place(b, pic, PICTURE_TOP, PICTURE_H)
	var title := _name_label(p["title"], CARD.x - PAD * 2)
	title.add_theme_color_override("font_color", LobbyUi.GOLD)
	_place(b, title, NAME_TOP, NAME_H)
	_add_info(b, "Info_soon", func() -> void: show_info(self, p["title"], p["text"], 0))
	return b
