extends VBoxContainer
## "Chỉ số" of one character (the Nhân vật page's right panel): from the PlayerState characters
## cache, an owned character shows its level, unspent points, one row per stat with its
## allocated points, the pending allocation (− +) and the battle stat it gives (total, "→ new"
## preview, "(gốc, điểm, trang bị)" breakdown), "Cộng điểm", "Bỏ chọn" and "Tẩy điểm"; a
## character not owned shows its base stats and "Mua ở Shop". The battle stat lines are hidden
## when the server sends no `stats`. A pending stat draft survives a characters reload while that
## character's server state is unchanged; an allocate with no clear answer (no response, 5xx)
## reloads the characters and starts the draft over before another "Cộng điểm" is possible.

signal open_shop_characters
signal busy_changed(busy: bool) # an allocate / reset started or ended (the page locks ◀ ▶)

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Modal := preload("res://ui/modal.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const Progress := preload("res://screens/home/progress.gd")
const StatDraft := preload("res://screens/home/stat_draft.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const IdempotencyKeys := preload("res://core/idempotency_keys.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const UNCLEAR := "Không rõ kết quả, đã tải lại"
## The stat name column (fits "Năng lượng di chuyển" at 20 px).
const NAME_W := 216

## Where dialogs and toasts go (Home); defaults to this panel.
var overlay: Control

var _characters: Variant = null # characterId -> GET /player/characters entry, null until loaded
var _drafts := {} # characterId -> StatDraft
var _characters_version := -1 # PlayerState.characters_version shown
var _reset_cost := {} # StatDraft.reset_cost(): {} while unknown
var _selected := LoadoutModel.default_character()
var _busy := false # an allocate or reset request is running
## After an allocate that succeeded or got no clear answer: the character whose draft starts
## over once characters loaded after that point arrive, and the note shown then. Until then
## "Cộng điểm" stays disabled, so the same points are never sent twice.
var _reload_id := ""
var _reload_after := 0 # characters_version to exceed
var _reload_note := ""

var _status: LoadStatus
var _detail: Control
var _title: Label
var _points: Label
var _stat_value := {} # stat key -> Label
var _stat_pending := {} # stat key -> Label
var _stat_minus := {} # stat key -> Button
var _stat_plus := {} # stat key -> Button
var _stat_cells := {} # stat key -> its row (name + points, battle stat)
var _stat_points := {} # stat key -> the points, pending and − + of the row
var _bs_cells := {} # stat key -> the battle stat line (value, preview, breakdown)
var _bs_value := {} # stat key -> Label
var _bs_preview := {} # stat key -> Label
var _bs_detail := {} # stat key -> Label
var _crit_row: Control
var _crit_value: Label
var _crit_detail: Label
var _owned_actions: Control
var _buy: Button
var _allocate: Button
var _clear_draft: Button
var _reset: Button
var _detail_status: Label


func _ready() -> void:
	if overlay == null:
		overlay = self
	add_theme_constant_override("separation", 8)
	_status = LoadStatus.new()
	add_child(_status)
	_detail = Ui.vbox(8)
	add_child(_detail)
	var head := Ui.hbox(12)
	_detail.add_child(head)
	_title = LobbyUi.text("", 28, Color.WHITE, true)
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_title)
	_points = LobbyUi.text("", 24, Ui.TONES["draw"], true)
	head.add_child(_points)

	for s in BattleStats.ROWS:
		var key: String = s["point"]
		var cell := Ui.vbox(0)
		_detail.add_child(cell)
		_stat_cells[key] = cell
		var r := Ui.hbox(6)
		cell.add_child(r)
		var name_label := LobbyUi.text(s["label"], 20, Color(0.82, 0.9, 1.0))
		name_label.custom_minimum_size.x = NAME_W
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.add_child(name_label)
		var bs := _battle_cell()
		r.add_child(bs["box"])
		_bs_cells[key] = bs["box"]
		_bs_value[key] = bs["value"]
		_bs_preview[key] = bs["preview"]
		var points := Ui.hbox(4)
		r.add_child(points)
		_stat_points[key] = points
		_stat_value[key] = _num_label(Color.WHITE)
		points.add_child(_stat_value[key])
		_stat_pending[key] = _num_label(Ui.TONES["good"])
		points.add_child(_stat_pending[key])
		_stat_minus[key] = _small_button("−", _on_stat.bind(key, -1))
		points.add_child(_stat_minus[key])
		_stat_plus[key] = _small_button("+", _on_stat.bind(key, 1))
		points.add_child(_stat_plus[key])
		_bs_detail[key] = _detail_label()
		cell.add_child(_bs_detail[key])
	_crit_row = Ui.vbox(0)
	_detail.add_child(_crit_row)
	var crit_line := Ui.hbox(6)
	_crit_row.add_child(crit_line)
	var crit_name := LobbyUi.text(BattleStats.CRIT_LABEL, 20, Color(0.82, 0.9, 1.0))
	crit_name.custom_minimum_size.x = NAME_W
	crit_line.add_child(crit_name)
	_crit_value = LobbyUi.text("", 22, Color.WHITE, true)
	crit_line.add_child(_crit_value)
	_crit_detail = _detail_label()
	_crit_row.add_child(_crit_detail)

	var actions := Ui.hbox(8)
	_detail.add_child(actions)
	_owned_actions = Ui.hbox(8)
	_owned_actions.size_flags_horizontal = SIZE_EXPAND_FILL
	actions.add_child(_owned_actions)
	# The three share the row by their text widths (stretch ratios) and never push it wider
	# than the panel: a text that does not fit is cut with "…".
	_allocate = _action_button("", _on_allocate)
	_allocate.size_flags_stretch_ratio = 1.15
	_owned_actions.add_child(_allocate)
	_clear_draft = _action_button("Bỏ chọn", _on_clear_draft)
	_clear_draft.size_flags_stretch_ratio = 0.8
	_owned_actions.add_child(_clear_draft)
	_reset = _action_button("", _on_reset)
	_reset.size_flags_stretch_ratio = 1.4
	_owned_actions.add_child(_reset)
	_buy = _action_button("Mua ở Shop", func(): open_shop_characters.emit())
	LobbyUi.style_button(_buy, LobbyUi.ICON_COLORS["orange"], 14, 8)
	_buy.size_flags_horizontal = SIZE_EXPAND_FILL
	actions.add_child(_buy)
	_update_reset_text()

	_detail_status = Ui.text("", 22)
	_detail_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_status.visible = false
	_detail.add_child(_detail_status)

	PlayerState.characters_changed.connect(_on_characters_changed)
	PlayerState.assets_dirty.connect(_on_assets_dirty)
	_on_characters_changed()


## A reset fee paid or a purchase made: reload the characters while shown.
func _on_assets_dirty() -> void:
	if is_visible_in_tree():
		PlayerState.need_characters()


func _num_label(color: Color) -> Label:
	var l := LobbyUi.text("", 20, color, true)
	l.custom_minimum_size.x = 30
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _detail_label() -> Label:
	var l := Ui.text("", 18, Ui.TEXT_DIM)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


func _small_button(text_value: String, on_press: Callable) -> Button:
	var b := Ui.button(text_value, 24)
	b.custom_minimum_size = Vector2(42, 42)
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(on_press)
	return b


func _action_button(text_value: String, on_press: Callable) -> Button:
	var b := Ui.button(text_value, 20)
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(on_press)
	return b


## The battle stat: the value and the green "→ new" preview.
func _battle_cell() -> Dictionary:
	var box := Ui.hbox(4)
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	var value := LobbyUi.text("", 22, Color.WHITE, true)
	value.custom_minimum_size.x = 64
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(value)
	# Takes what the row has left; a preview too long for it is cut, never pushing the − + out.
	var preview := LobbyUi.text("", 20, Ui.TONES["good"], true)
	preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.size_flags_horizontal = SIZE_EXPAND_FILL
	preview.clip_text = true
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(preview)
	return {"box": box, "value": value, "preview": preview}


## The character shown (the one on the Nhân vật page's stage).
func show_character(id: String) -> void:
	if id != _selected and not _busy:
		_detail_status.text = "" # the last note was about the other character
		_detail_status.visible = false
	_selected = id
	_update_detail()


func is_busy() -> bool:
	return _busy


## PlayerState.characters_changed: loading / error state, and a new answer applied.
func _on_characters_changed() -> void:
	if PlayerState.characters_error != "":
		_status.show_error(PlayerState.characters_error, PlayerState.load_characters)
	elif PlayerState.characters_loading and PlayerState.characters == null:
		_status.show_loading()
	else:
		_status.clear()
	if PlayerState.characters == null or PlayerState.characters_version == _characters_version:
		_update_detail()
		return
	_characters_version = PlayerState.characters_version
	_characters = {}
	for c in PlayerState.characters["characters"]:
		if c is Dictionary and str(c.get("characterId", "")) != "":
			_characters[str(c["characterId"])] = c
	_reset_cost = StatDraft.reset_cost(PlayerState.characters)
	_update_reset_text()
	var drop := ""
	if _reload_id != "" and _characters_version > _reload_after:
		drop = _reload_id # its points are (or may be) spent: start that draft over
	_drafts = StatDraft.rebuild(_drafts, _characters, drop)
	_update_detail()
	if drop != "":
		_reload_id = ""
		_set_busy(false, _reload_note)


func _update_reset_text() -> void:
	var cost := StatDraft.cost_text(_reset_cost)
	_reset.text = "Tẩy điểm (%s)" % cost if cost != "" else "Tẩy điểm"


func _on_stat(key: String, delta: int) -> void:
	var draft: StatDraft = _drafts.get(_selected)
	if draft == null:
		return
	if delta > 0:
		draft.add(key)
	else:
		draft.remove(key)
	_update_detail()


func _on_clear_draft() -> void:
	var draft: StatDraft = _drafts.get(_selected)
	if draft != null:
		draft.clear()
	_update_detail()


## Updated in place. An owned character shows its points, pending allocation and battle stats;
## one not owned its base stats and "Mua ở Shop".
func _update_detail() -> void:
	if _detail == null:
		return
	var draft: StatDraft = _drafts.get(_selected)
	var owned := draft != null
	_detail.visible = owned or _characters is Dictionary
	if not _detail.visible:
		return
	var stats: Dictionary
	if owned:
		var entry: Dictionary = _characters[_selected]
		stats = BattleStats.of(entry)
		_title.text = "%s · Lv.%d" % [_display_name(_selected), Progress.character(entry)["level"]]
		_points.text = "Còn %d điểm" % draft.remaining()
	else:
		stats = BattleStats.base_of(PlayerState.characters, _selected)
		_title.text = "%s · Chưa sở hữu" % _display_name(_selected)
		_points.text = ""
	var pending := {}
	for s in BattleStats.ROWS:
		var key: String = s["point"]
		_stat_points[key].visible = owned
		if owned:
			_stat_value[key].text = str(draft.current[key])
			var n := draft.pending(key)
			pending[key] = n
			_stat_pending[key].text = "+%d" % n if n > 0 else ""
			_stat_minus[key].disabled = _busy or not draft.can_remove(key)
			_stat_plus[key].disabled = _busy or not draft.can_add(key)
	# Without stats (an older server) the table keeps only the points; a character not owned
	# without base stats shows just its name and "Mua ở Shop".
	var rows := BattleStats.rows(stats, pending, BattleStats.multipliers(PlayerState.characters))
	for r in rows:
		_bs_value[r["point"]].text = r["value"]
		_bs_preview[r["point"]].text = r["preview"]
		_bs_detail[r["point"]].text = r["detail"]
	for key in _bs_cells:
		_bs_cells[key].visible = not rows.is_empty()
		_bs_detail[key].visible = not rows.is_empty() and _bs_detail[key].text != ""
		_stat_cells[key].visible = owned or not rows.is_empty()
	var crit := BattleStats.crit(stats)
	_crit_row.visible = not crit.is_empty()
	if not crit.is_empty():
		_crit_value.text = crit["value"]
		_crit_detail.text = crit["detail"]
		_crit_detail.visible = crit["detail"] != ""
	_owned_actions.visible = owned
	_buy.visible = not owned
	_buy.disabled = _busy
	if not owned:
		return
	_allocate.text = "Cộng điểm (%d)" % draft.total_pending()
	_allocate.disabled = _busy or not draft.can_submit()
	_clear_draft.disabled = _busy or draft.total_pending() == 0
	_reset.disabled = _busy or not draft.has_allocated()


static func _display_name(id: String) -> String:
	return GameData.character_name(id)


func _on_allocate() -> void:
	var draft: StatDraft = _drafts.get(_selected)
	if draft == null or not draft.can_submit() or _busy:
		return
	_set_busy(true, "Đang cộng điểm...")
	var res: Dictionary = await Api.post_json("/player/character/allocate-stats", draft.payload())
	if not is_inside_tree():
		return
	if IdempotencyKeys.is_definite(res.status) and not res.ok:
		_set_busy(false, ErrorText.stats(res), true) # refused: nothing was spent
		return
	# Spent, or (no answer, 5xx) maybe spent: stay busy until a reload rebuilds the draft.
	_reload_id = draft.character_id
	_reload_after = PlayerState.characters_version
	_reload_note = "" if res.ok else UNCLEAR
	_set_busy(true, "" if res.ok else "Không rõ kết quả, đang tải lại...")
	if res.ok:
		Ui.toast(overlay, "Đã cộng điểm")
	PlayerState.load_characters()


func _on_reset() -> void:
	var id := _selected
	var m := Modal.new()
	m.open(overlay, "Tẩy điểm")
	var price := StatDraft.cost_text(_reset_cost)
	m.add_text("Tẩy toàn bộ điểm đã cộng của %s%s? Điểm sẽ được hoàn lại để cộng lại." % [_display_name(id),
		" với giá %s" % price if price != "" else ""])
	m.add_button("Huỷ", m.close)
	m.add_button("Tẩy điểm", _confirm_reset.bind(m, id))


func _confirm_reset(m: Modal, id: String) -> void:
	m.set_busy(true)
	m.set_message("")
	_set_busy(true, "")
	var res: Dictionary = await Api.post_json("/player/character/reset-stats", {"characterId": id})
	if not is_inside_tree():
		return
	_set_busy(false, "")
	if res.ok:
		if is_instance_valid(m):
			m.close()
		Ui.toast(overlay, "Đã tẩy điểm")
		PlayerState.assets_changed() # wallet (the fee) and the characters
		return
	if is_instance_valid(m):
		m.set_message(ErrorText.stats(res, str(_reset_cost.get("currency", ""))))
		m.set_busy(false)


func _set_busy(busy: bool, status: String, is_error: bool = false) -> void:
	var flipped := busy != _busy
	_busy = busy
	if flipped:
		busy_changed.emit(busy)
	_detail_status.text = status
	_detail_status.visible = status != ""
	if is_error:
		_detail_status.add_theme_color_override("font_color", Ui.TONES["error"])
	else:
		_detail_status.remove_theme_color_override("font_color")
	_update_detail()
