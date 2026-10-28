extends Control
## "Chọn chế độ" (a Home page, opened by the lobby's mode card): one tab per section of
## ModeSelectModel.sections() (the game data's categories in order: PvP, Boss, ...), the tab row
## of the other Home pages (Ui.tab_row). A cards section (PvP) shows one big card per mode in its
## order: the icon on a round plate, the name, the description, the party badge ("2 người"), for a
## ranked mode the player's grade insignia and "Binh nhì 2 · 45/100"; the chosen mode framed and tagged
## "Đang chọn". A grid section (Boss) shows a grid of small cards, one per mode. A section without
## modes shows one disabled card: "Sắp ra mắt" and its line ("Phòng 4 người cùng đánh boss").
## The Boss section shows one card per boss mode (screens/home/boss_card_model.gd): the boss's
## figure (match/boss/boss_art_view.gd) on a glow of its colour, its name, "Lv đề xuất N", its
## description and "Lượt thưởng lớn: x/N" with "Làm mới lúc HH:MM" from GET /boss/runs (loaded
## when the tab shows, kept BOSS_RUNS_MAX_AGE_MSEC by PlayerState); the placeholder only without
## bosses.
## A tap emits chosen(index); Home goes back to the lobby, which switches to it (choose_mode()).
## Rebuilt by show_for() each time it opens, so a mode or category an admin added shows.

signal chosen(index: int)

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const ModeSelectModel := preload("res://screens/home/mode_select_model.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const BossCardModel := preload("res://screens/home/boss_card_model.gd")
const ElementBadge := preload("res://ui/element_badge.gd")
const ElementBackdrop := preload("res://ui/element_backdrop.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const BossArtView := preload("res://match/boss/boss_art_view.gd")

const CARD := Vector2(350, 520)
const SMALL := Vector2(300, 250)
const BOSS_CARD := Vector2(360, 500)
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
	var grid: bool = section["layout"] == ModeSelectModel.GRID
	if section["modes"].is_empty():
		flow.add_child(_soon_card(ModeSelectModel.placeholder(section["categoryId"]), grid))
		return
	if section["categoryId"] == BossCardModel.CATEGORY:
		var bias := int(Time.get_time_zone_from_system().get("bias", 0))
		for c in BossCardModel.cards(_current, PlayerState.my_boss_runs(), bias):
			flow.add_child(_boss_card(c))
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


## The player's grade insignia and "Binh nhì 2 · 45/100" ("Đang tải hạng..." until GET /rank/me).
func _rank_row() -> Control:
	var row := Ui.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var data := PlayerState.my_rank()
	var r := RankModel.from_me(data)
	var grade: String = r["grade"] if not data.is_empty() else ""
	row.add_child(GradeBadge.make(grade, r["division"], 40))
	var line := LobbyUi.text(RankModel.mode_line(r) if not data.is_empty() else "Đang tải hạng...", 22,
		GradeBadge.text_color(grade), true)
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


## The Boss section is shown.
func _on_boss_tab() -> bool:
	var sections := ModeSelectModel.sections(_current)
	return _tab < sections.size() and sections[_tab]["categoryId"] == BossCardModel.CATEGORY


## A boss card: the figure on its element's backdrop (ElementBackdrop; its colour's glow without one), the name, "Lv đề xuất N", the description, the
## big-reward runs left and when they refill; "Đang chọn" on the chosen one.
func _boss_card(c: Dictionary) -> Button:
	var parts := _card_button(BOSS_CARD, c["selected"])
	var b: Button = parts[0]
	var col: VBoxContainer = parts[1]
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 6)
	b.name = "Boss_%s" % c["id"]
	var art := BossArt.art_of(str(c["boss_id"]))
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(BOSS_CARD.x - 44, 210)
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	var tint := BossArt.accent(art)
	var element := str(c.get("element", ""))
	if element != "": # the boss's element behind the figure (ElementBackdrop), in place of the glow
		var back := ElementBackdrop.new()
		back.element_id = element
		back.radius = 16.0
		back.name = "ElementBackdrop"
		back.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		stage.add_child(back)
	var figure := BossArtView.make(art, stage.custom_minimum_size, -1, "portrait")
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
	col.add_child(stage)
	var boss_name := _centered(c["name"], 32, Color.WHITE, true)
	boss_name.autowrap_mode = TextServer.AUTOWRAP_OFF # sized by its text beside the element badge
	if str(c.get("element", "")) != "":
		ElementBadge.shrink_to_fit(boss_name, BOSS_CARD.x - 44 - 2 * (34 + 8))
	col.add_child(ElementBadge.name_row(boss_name, str(c.get("element", "")), 34, 8))
	var badges := Ui.hbox(8)
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.mouse_filter = MOUSE_FILTER_IGNORE
	if c["level_text"] != "":
		badges.add_child(_pill(c["level_text"], Color(tint.darkened(0.35), 0.95), Color.WHITE))
	if c["selected"]:
		badges.add_child(_pill("Đang chọn", LobbyUi.GOLD, LobbyUi.TEXT_DARK))
	col.add_child(badges)
	var desc := _centered(c["description"], 19, Color(0.75, 0.9, 1.0))
	desc.custom_minimum_size = Vector2(BOSS_CARD.x - 44, 0)
	desc.max_lines_visible = 3
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(desc)
	if c["runs_text"] != "":
		var runs := _centered(c["runs_text"], 22, LobbyUi.GOLD if int(c["runs_left"]) != 0 else Ui.TEXT_DIM, true)
		runs.name = "Runs"
		col.add_child(runs)
	if c["reset_text"] != "":
		col.add_child(_centered(c["reset_text"], 18, Ui.TEXT_DIM))
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
