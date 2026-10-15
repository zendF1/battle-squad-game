extends Control
## "Hồ sơ": the player card (avatar letter, name + "Sửa", level, EXP) on the left and "Lịch sử
## đấu" on the right: GET /player/match-history, 20 per page, "Tải thêm" until a short page,
## loaded the first time the tab is shown; a failure shows inline with "Thử lại". The
## characters (stats, points) are on the Nhân vật page, the items and gear in Túi đồ.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Modal := preload("res://ui/modal.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const Progress := preload("res://screens/home/progress.gd")
const HistoryPager := preload("res://screens/home/history_pager.gd")
const ErrorText := preload("res://screens/home/error_text.gd")

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
	right.add_child(LobbyUi.text("Lịch sử đấu", 28, Color.WHITE, true))
	var page := _build_history_page()
	page.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(page)

	PlayerState.changed.connect(_render_player)
	visibility_changed.connect(_ensure_loaded)
	_render_player()
	_arm.call_deferred()


## Deferred from _ready(): Home hides the pages it does not show right after adding them.
func _arm() -> void:
	_armed = true
	_ensure_loaded()


func _ensure_loaded() -> void:
	if _armed and is_visible_in_tree() and not _history_started:
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
	_level = Ui.label("", 26)
	col.add_child(_level)
	_exp_bar = Ui.bar(0.0, 18)
	col.add_child(_exp_bar)
	_exp_text = Ui.label("", 22)
	_exp_text.add_theme_color_override("font_color", Ui.TEXT_DIM)
	col.add_child(_exp_text)
	return card


func _render_player() -> void:
	var display := PlayerState.display_name()
	_name.text = display
	_avatar_letter.text = display.substr(0, 1).to_upper() if display != "" else "?"
	if PlayerState.is_loaded():
		var p := Progress.player(PlayerState.level(), PlayerState.player_exp())
		_level.text = "Cấp %d" % PlayerState.level()
		_exp_bar.value = p["ratio"]
		_exp_text.text = "EXP %s" % p["text"]
	else:
		_level.text = "Cấp —"
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
	var rating := Ui.text("Hạng %s" % t["rating"], 22)
	rating.custom_minimum_size.x = 110
	r.add_child(rating)
	r.add_child(Ui.text(t["date"], 22, Ui.TEXT_DIM))
	return card
