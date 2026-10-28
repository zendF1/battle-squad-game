extends Control
## "Hồ sơ": the player card (avatar letter, name + "Sửa", the worn title's plate, level, EXP) on
## the left and two sections on the right: "Lịch sử đấu" (GET /player/match-history, 20 per page,
## "Tải thêm" until a short page, loaded the first time the tab is shown) and "Danh hiệu" (GET
## /player/titles via PlayerState: "Không đeo", then the owned titles as plates, tap to wear, the
## worn one marked "Đang đeo"; then the locked ones dimmed with how to win them, "Đạt: Thắng 100
## trận"). Under the level, Lực chiến: my strongest character's head and the power (the profile's
## power + powerCharacterId, ui/power_tag.gd; hidden while unknown). Failures show inline with "Thử lại". A tap on the card's plate opens Danh hiệu. The
## characters (stats, points) are on the Nhân vật page, the items and gear in Kho đồ.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const Modal := preload("res://ui/modal.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const Progress := preload("res://screens/home/progress.gd")
const HistoryPager := preload("res://screens/home/history_pager.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const TitleModel := preload("res://screens/home/title_model.gd")
const TitlePlate := preload("res://ui/title_plate.gd")
const PowerTag := preload("res://ui/power_tag.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")

const SECTION_HISTORY := 0
const SECTION_TITLES := 1
const PICK_H := 52.0 # a title plate in the picker
const GOLD := Color(1.0, 0.8, 0.22)

## Where dialogs and toasts go (Home); defaults to this tab.
var overlay: Control

var _pager := HistoryPager.new(20)
var _history_started := false
var _armed := false # the history loads once Home has shown this tab

# Player card
var _avatar: PanelContainer
var _avatar_letter: Label
var _name: Label
var _level: Label
var _exp_bar: ProgressBar
var _exp_text: Label
var _power_row: HBoxContainer
var _power_head: Control
var _power: PowerTag

var _card_title: TitlePlate

# Sections
var _section := SECTION_HISTORY
var _section_tabs: Array[Button]
var _history_page: Control
var _titles_page: Control
var _titles_status: LoadStatus
var _titles_body: VBoxContainer
var _rendered_titles := -1

# Lịch sử
var _hist_status: LoadStatus
var _hist_rows: VBoxContainer
var _hist_more: Button
var _hist_empty: Label


func _ready() -> void:
	if overlay == null:
		overlay = self
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var row := Ui.hbox(16)
	margin.add_child(row)
	row.add_child(_build_player_card())

	var right := Ui.vbox(12)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(right)
	var tabs := Ui.hbox(10)
	right.add_child(tabs)
	_section_tabs = Ui.tab_row(["Lịch sử đấu", "Danh hiệu"], 24, show_section, 58)
	for b in _section_tabs:
		tabs.add_child(b)
	_history_page = _build_history_page()
	_history_page.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(_history_page)
	_titles_page = _build_titles_page()
	_titles_page.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(_titles_page)

	PlayerState.changed.connect(_render_player)
	PlayerState.titles_changed.connect(_on_titles_changed)
	visibility_changed.connect(_ensure_loaded)
	visibility_changed.connect(func() -> void:
		if _armed and is_visible_in_tree():
			PlayerState.refresh()) # Lực chiến: gear or stats may have changed it since
	_render_player()
	show_section(SECTION_HISTORY)
	_arm.call_deferred()


## Shows "Lịch sử đấu" (SECTION_HISTORY) or "Danh hiệu" (SECTION_TITLES).
func show_section(index: int) -> void:
	_section = clampi(index, SECTION_HISTORY, SECTION_TITLES)
	Ui.select_tab(_section_tabs, _section)
	_history_page.visible = _section == SECTION_HISTORY
	_titles_page.visible = _section == SECTION_TITLES
	_ensure_loaded()
	_render_titles()


## Deferred from _ready(): Home hides the pages it does not show right after adding them.
func _arm() -> void:
	_armed = true
	_ensure_loaded()


func _ensure_loaded() -> void:
	if not (_armed and is_visible_in_tree()):
		return
	PlayerState.need_titles() # the card's plate and the Danh hiệu section
	if _section == SECTION_HISTORY and not _history_started:
		_history_started = true
		_load_history()


# ── Player card ─────────────────────────────────────────────────────────────

func _build_player_card() -> Control:
	var card := Ui.card(Ui.CARD_BG, 24)
	card.custom_minimum_size.x = 380
	var col := Ui.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)
	var avatar_row := CenterContainer.new()
	col.add_child(avatar_row)
	_avatar = Ui.circle("?", 140)
	_avatar_letter = _avatar.get_child(0)
	avatar_row.add_child(_avatar)
	var name_row := Ui.hbox(12)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(name_row)
	_name = Ui.label("", 30)
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.custom_minimum_size.x = 120
	_name.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.add_child(_name)
	var edit := Ui.button("Sửa", 22)
	edit.custom_minimum_size = Vector2(96, 60)
	edit.focus_mode = FOCUS_NONE
	edit.pressed.connect(_open_rename)
	name_row.add_child(edit)
	var plate_button := Button.new() # the worn title; a tap opens Danh hiệu
	plate_button.flat = true
	plate_button.focus_mode = FOCUS_NONE
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		plate_button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	plate_button.pressed.connect(show_section.bind(SECTION_TITLES))
	col.add_child(plate_button)
	_card_title = TitlePlate.new()
	_card_title.plate_height = 48
	_card_title.max_width = 330
	_card_title.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	plate_button.add_child(_card_title)
	_card_title.minimum_size_changed.connect(func():
		plate_button.custom_minimum_size = _card_title.get_combined_minimum_size()
		plate_button.visible = _card_title.has_title())
	_level = Ui.label("", 26)
	var level_row := GlyphIcon.level_row(_level, 32)
	level_row.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(level_row)
	_exp_bar = Ui.bar(0.0, 18)
	col.add_child(_exp_bar)
	_exp_text = Ui.label("", 22)
	_exp_text.add_theme_color_override("font_color", Ui.TEXT_DIM)
	col.add_child(_exp_text)
	_power_row = Ui.hbox(12)
	_power_row.name = "PowerRow"
	_power_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_power_row)
	_power_head = HeadIcon.make("", "", 56)
	_power_head.lobby = true
	_power_head.size_flags_vertical = SIZE_SHRINK_CENTER
	_power_row.add_child(_power_head)
	_power = PowerTag.make(40, 32)
	_power_row.add_child(_power)
	return card


func _render_player() -> void:
	_card_title.set_title(PlayerState.equipped_title())
	var plate_button := _card_title.get_parent() as Control
	plate_button.custom_minimum_size = _card_title.get_combined_minimum_size()
	plate_button.visible = _card_title.has_title()
	if _titles_page != null and _titles_page.visible:
		_render_titles(true) # the worn mark
	var display := PlayerState.display_name()
	_name.text = display
	_avatar_letter.text = display.substr(0, 1).to_upper() if display != "" else "?"
	_power.set_power(PlayerState.power())
	_power_head.character_id = PlayerState.power_character()
	_power_head.visible = PlayerState.power_character() != ""
	_power_row.visible = PlayerState.power() >= 0
	if PlayerState.is_loaded():
		var p := Progress.player(PlayerState.level(), PlayerState.player_exp())
		GlyphIcon.show_level(_level, str(PlayerState.level()))
		_exp_bar.value = p["ratio"]
		_exp_text.text = "EXP %s" % p["text"]
	else:
		GlyphIcon.show_level(_level, "—")
		_exp_bar.value = 0.0
		_exp_text.text = "Đang tải..." if PlayerState.loading else PlayerState.error


func _open_rename() -> void:
	var m := Modal.new()
	m.open(overlay, "Đổi tên")
	var input := LineEdit.new()
	input.text = PlayerState.display_name()
	input.max_length = ErrorText.MAX_NAME
	input.placeholder_text = "Tên hiển thị (tối đa %d ký tự)" % ErrorText.MAX_NAME
	input.add_theme_font_size_override("font_size", 28)
	input.custom_minimum_size.y = 76
	input.select_all_on_focus = true
	m.body.add_child(input)
	m.add_button("Huỷ", m.close)
	var save := m.add_button("Lưu", _save_name.bind(m, input))
	input.text_submitted.connect(func(_t): save.pressed.emit())
	input.grab_focus.call_deferred()


func _save_name(m: Modal, input: LineEdit) -> void:
	var problem := ErrorText.name_problem(input.text)
	if problem != "":
		m.set_message(problem)
		return
	var new_name := input.text.strip_edges()
	m.set_message("")
	m.set_busy(true)
	input.editable = false
	var res: Dictionary = await Api.request(HTTPClient.METHOD_PUT, "/player/profile", {"displayName": new_name})
	if not is_instance_valid(m):
		return
	if res.ok:
		m.close()
		PlayerState.renamed(new_name)
		Ui.toast(overlay, "Đã đổi tên")
		return
	m.set_message(ErrorText.rename(res))
	m.set_busy(false)
	input.editable = true



# ── Danh hiệu ───────────────────────────────────────────────────────────────

func _build_titles_page() -> Control:
	var col := Ui.vbox(12)
	_titles_status = LoadStatus.new()
	col.add_child(_titles_status)
	_titles_body = Ui.vbox(12)
	col.add_child(_titles_body)
	return Ui.scroll(col)


## Deferred: a press in the list must not free its own button mid-signal.
func _on_titles_changed() -> void:
	if is_inside_tree():
		_render_titles.call_deferred()


func _render_titles(force: bool = false) -> void:
	if _titles_body == null or not _titles_page.visible:
		return
	var data = PlayerState.titles
	if PlayerState.titles_error != "" and data == null:
		_titles_status.show_error(PlayerState.titles_error, PlayerState.load_titles)
	elif data == null:
		_titles_status.show_loading()
	else:
		_titles_status.clear()
	if data == null:
		Ui.clear(_titles_body)
		_rendered_titles = -1
		return
	var key := PlayerState.titles_version * 2 + (1 if PlayerState.title_busy else 0)
	if not force and key == _rendered_titles and _titles_body.get_child_count() > 0:
		return
	_rendered_titles = key
	Ui.clear(_titles_body)
	var worn_id := str(PlayerState.equipped_title().get("id", ""))
	var owned := TitleModel.owned(data)
	var locked := TitleModel.locked(data)
	_titles_body.add_child(_section_head("Đã có", "%d/%d" % [owned.size(), owned.size() + locked.size()]))
	var grid := _title_grid()
	_titles_body.add_child(grid)
	grid.add_child(_none_card(worn_id == ""))
	for t in owned:
		grid.add_child(_title_card(t, true, t["id"] == worn_id))
	if not locked.is_empty():
		_titles_body.add_child(_section_head("Chưa có", ""))
		var g2 := _title_grid()
		_titles_body.add_child(g2)
		for t in locked:
			g2.add_child(_title_card(t, false, false))


func _section_head(text: String, count: String) -> Control:
	var row := Ui.hbox(12)
	row.add_child(LobbyUi.text(text, 24, Color.WHITE, true))
	if count != "":
		var c := LobbyUi.text(count, 20, Ui.TEXT_DIM)
		c.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(c)
	return row


func _title_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	g.size_flags_horizontal = SIZE_EXPAND_FILL
	return g


## A picker card: a flat button with the plate (or "Không đeo") and a line under it.
func _card(worn: bool, on_press: Callable) -> Array:
	var b := Button.new()
	b.focus_mode = FOCUS_NONE
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, PICK_H + 52)
	var bg := LobbyUi.box(Color(0.06, 0.08, 0.2, 0.8), 14, 6, GOLD if worn else Color(1, 1, 1, 0.12), 3 if worn else 1)
	b.add_theme_stylebox_override("normal", bg)
	b.add_theme_stylebox_override("hover", LobbyUi.box(Color(0.1, 0.13, 0.28, 0.85), 14, 6, GOLD if worn else Color(1, 1, 1, 0.22), 3 if worn else 1))
	b.add_theme_stylebox_override("pressed", bg)
	b.add_theme_stylebox_override("disabled", bg)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(on_press)
	var col := Ui.vbox(4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	col.offset_top = 6
	col.offset_bottom = -6
	col.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(col)
	return [b, col]


func _foot(col: Control, text: String, color: Color) -> Label:
	var l := LobbyUi.text(text, 19, color, color == GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(l)
	return l


func _none_card(worn: bool) -> Control:
	var parts := _card(worn, _wear.bind(null, ""))
	var col: VBoxContainer = parts[1]
	var none := LobbyUi.text("Không đeo", 26, Color.WHITE if worn else Ui.TEXT_DIM, true)
	none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	none.custom_minimum_size.y = PICK_H
	none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	none.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(none)
	_foot(col, "✓ Đang chọn" if worn else "Tháo danh hiệu", GOLD if worn else Ui.TEXT_DIM)
	return parts[0]


func _title_card(t: Dictionary, owned: bool, worn: bool) -> Control:
	var parts := _card(worn, _wear.bind(t["id"], t["name"]) if owned else _locked_tap.bind(t))
	var col: VBoxContainer = parts[1]
	var plate := TitlePlate.new()
	plate.plate_height = PICK_H
	plate.max_width = 380
	plate.shine = owned
	plate.set_title(t)
	plate.size_flags_horizontal = SIZE_SHRINK_CENTER
	if not owned:
		plate.modulate = Color(0.45, 0.47, 0.55, 0.85) # dimmed
	col.add_child(plate)
	if worn:
		_foot(col, "✓ Đang đeo", GOLD)
	elif owned:
		_foot(col, "Chạm để đeo", Color(0.75, 0.88, 1.0))
	else:
		_foot(col, TitleModel.locked_text(t), Color(0.62, 0.64, 0.72))
	return parts[0]


func _locked_tap(t: Dictionary) -> void:
	Ui.toast(overlay, "Chưa có: %s" % TitleModel.locked_text(t))


func _wear(id: Variant, title_name: String) -> void:
	var worn_id := str(PlayerState.equipped_title().get("id", ""))
	if (id == null and worn_id == "") or (id != null and str(id) == worn_id):
		return # already so
	if PlayerState.title_busy:
		Ui.toast(overlay, ErrorText.TITLE["BUSY"])
		return
	var res: Dictionary = await PlayerState.equip_title(id)
	if not is_inside_tree():
		return
	if res.ok:
		Ui.toast(overlay, "Đã đeo danh hiệu: %s" % title_name if id != null else "Đã tháo danh hiệu")
	else:
		Ui.toast(overlay, ErrorText.title(res))


# ── Lịch sử ─────────────────────────────────────────────────────────────────

func _build_history_page() -> Control:
	var col := Ui.vbox(10)
	_hist_rows = Ui.vbox(8)
	col.add_child(_hist_rows)
	_hist_empty = Ui.label("Chưa có trận nào", 24)
	_hist_empty.add_theme_color_override("font_color", Ui.TEXT_DIM)
	_hist_empty.visible = false
	col.add_child(_hist_empty)
	_hist_status = LoadStatus.new()
	col.add_child(_hist_status)
	_hist_more = Ui.button("Tải thêm", 24)
	_hist_more.custom_minimum_size = Vector2(260, 68)
	_hist_more.size_flags_horizontal = SIZE_SHRINK_CENTER
	_hist_more.visible = false
	_hist_more.pressed.connect(_load_history)
	col.add_child(_hist_more)
	return Ui.scroll(col)


func _load_history() -> void:
	var path := _pager.begin()
	if path == "":
		return
	_hist_more.disabled = true
	_hist_status.show_loading()
	var res: Dictionary = await Api.get_json(path)
	if not is_inside_tree():
		return
	var before := _pager.rows.size()
	_pager.finish(res, ErrorText.load_failed(res))
	if _pager.error != "":
		_hist_status.show_error(_pager.error, _load_history)
	else:
		_hist_status.clear()
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	for i in range(before, _pager.rows.size()):
		_hist_rows.add_child(_history_row(HistoryPager.row_text(_pager.rows[i], bias)))
	_hist_empty.visible = _pager.done and _pager.rows.is_empty()
	_hist_more.visible = not _pager.done and _pager.error == "" and not _pager.rows.is_empty()
	_hist_more.disabled = false


func _history_row(t: Dictionary) -> Control:
	var card := Ui.card(Ui.CARD_BG, 14)
	var r := Ui.hbox(18)
	card.add_child(r)
	var result := Ui.text(t["result"], 26, Ui.TONES[t["tone"]])
	result.custom_minimum_size.x = 90
	r.add_child(result)
	var where := Ui.text("%s · %s" % [t["mode"], t["map"]], 22)
	where.size_flags_horizontal = SIZE_EXPAND_FILL
	where.clip_text = true
	where.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	r.add_child(where)
	r.add_child(Ui.text(t["exp"], 22, Ui.TONES["good"]))
	r.add_child(Ui.text(t["coin"], 22, Ui.TONES["draw"]))
	# a ranked match's rank points; the column kept on every row, so the dates line up
	var change := int(t.get("points_change", 0))
	var points := Ui.text(t["points"], 22, Ui.TONES["good"] if change > 0 else (Ui.TONES["error"] if change < 0 else Color.WHITE))
	points.name = "Points"
	points.custom_minimum_size.x = 200
	r.add_child(points)
	r.add_child(Ui.text(t["date"], 22, Ui.TEXT_DIM))
	return card
