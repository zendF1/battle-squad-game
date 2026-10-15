extends Control
## "Hồ sơ": the player card (avatar letter, name + "Sửa", level, EXP) on the left and three
## sub-tabs on the right:
## - "Nhân vật": the four characters from GET /player/characters (owned: level, EXP, unspent
##   points, one row per stat with its allocated points, the pending allocation and the battle
##   stat it gives — total, "→ new" preview, "(gốc, điểm, trang bị)" breakdown — "Cộng điểm",
##   "Tẩy điểm"; not owned: base stats and "Mua ở Shop"). The battle stat lines are hidden
##   when the server sends no `stats`;
## - "Kho đồ": the eight battle items with their GET /player/inventory counts;
## - "Lịch sử": GET /player/match-history, 20 per page, "Tải thêm" until a short page.
## Each sub-tab loads the first time it is shown; characters come from the PlayerState cache
## shared with the Shop. Every request runs in the background; failures show inline with
## "Thử lại". A pending stat draft survives a characters reload while that character's server
## state is unchanged; an allocate with no clear answer (no response, 5xx) reloads the
## characters and starts the draft over before another "Cộng điểm" is possible.

signal open_shop_characters

const Ui := preload("res://ui/ui.gd")
const Modal := preload("res://ui/modal.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const Items := preload("res://match/items.gd")
const Skills := preload("res://match/skills.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const Progress := preload("res://screens/home/progress.gd")
const StatDraft := preload("res://screens/home/stat_draft.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const HistoryPager := preload("res://screens/home/history_pager.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const IdempotencyKeys := preload("res://core/idempotency_keys.gd")

const UNCLEAR := "Không rõ kết quả, đã tải lại"
const SUB_TABS := ["Nhân vật", "Kho đồ", "Lịch sử"]
const CHARACTERS := 0
const INVENTORY := 1
const HISTORY := 2

## Where dialogs and toasts go (Home); defaults to this tab.
var overlay: Control

var _characters: Variant = null # characterId -> GET /player/characters entry, null until loaded
var _inventory: Variant = null # itemId -> count, null until loaded
var _drafts := {} # characterId -> StatDraft
var _characters_version := -1 # PlayerState.characters_version shown
var _reset_cost := StatDraft.DEFAULT_RESET_COST.duplicate()
var _selected := LoadoutModel.DEFAULT_CHARACTER
var _picked := false # the player chose _selected (kept across reloads even when not owned)
var _inv_stale := false
var _inv_loading := false
var _busy := false # an allocate or reset request is running
## After an allocate that succeeded or got no clear answer: the character whose draft starts
## over once characters loaded after that point arrive, and the note shown then. Until then
## "Cộng điểm" stays disabled, so the same points are never sent twice.
var _reload_id := ""
var _reload_after := 0 # characters_version to exceed
var _reload_note := ""
var _pager := HistoryPager.new(20)
var _history_started := false
var _armed := false # loads start once Home has set which tab is shown
var _sub := 0
var _gen := {} # "inventory" -> latest request number; older answers are dropped

# Player card
var _avatar: PanelContainer
var _avatar_letter: Label
var _name: Label
var _level: Label
var _exp_bar: ProgressBar
var _exp_text: Label

var _sub_tabs: Array[Button]
var _pages: Array[Control] = []

# Nhân vật
var _char_status: LoadStatus
var _cards_row: HBoxContainer
var _card_buttons := {} # characterId -> Button
var _detail: PanelContainer
var _detail_title: Label
var _detail_points: Label
var _stat_value := {} # stat key -> Label
var _stat_pending := {} # stat key -> Label
var _stat_minus := {} # stat key -> Button
var _stat_plus := {} # stat key -> Button
var _stat_cells := {} # stat key -> its grid cell (name + points, battle stat)
var _stat_points := {} # stat key -> the points, pending and − + of the cell
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

# Kho đồ
var _inv_status: LoadStatus
var _inv_flow: HFlowContainer

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
	var tabs := Ui.hbox(8)
	right.add_child(tabs)
	_sub_tabs = Ui.tab_row(SUB_TABS, 24, _show_sub)
	for b in _sub_tabs:
		tabs.add_child(b)
	var pages := Control.new()
	pages.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(pages)
	for builder in [_build_characters_page, _build_inventory_page, _build_history_page]:
		var page: Control = builder.call()
		page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		pages.add_child(page)
		_pages.append(page)
	_show_sub(0)

	PlayerState.changed.connect(_render_player)
	PlayerState.assets_dirty.connect(_on_assets_dirty)
	PlayerState.characters_changed.connect(_on_characters_changed)
	visibility_changed.connect(_on_visibility_changed)
	_render_player()
	_on_characters_changed() # whatever the Shop or an earlier Home already loaded
	_render_inventory()
	_arm.call_deferred()


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


# ── Sub-tabs ────────────────────────────────────────────────────────────────

## Shows a sub-tab (CHARACTERS, INVENTORY, HISTORY); it loads once this tab is visible.
func show_section(index: int) -> void:
	_show_sub(index)


func _show_sub(index: int) -> void:
	_sub = index
	for i in _pages.size():
		_pages[i].visible = i == index
	Ui.select_tab(_sub_tabs, index)
	_ensure_loaded()


## Loads what the shown sub-tab needs and has not got (or got before an asset change).
func _ensure_loaded() -> void:
	if _armed and is_visible_in_tree():
		_load_shown()


## Deferred from _ready(): Home hides the tabs it does not show right after adding them.
func _arm() -> void:
	_armed = true
	_ensure_loaded()


func _load_shown() -> void:
	match _sub:
		0:
			PlayerState.need_characters()
		1:
			if (_inventory == null or _inv_stale) and not _inv_loading:
				_load_inventory()
		2:
			if not _history_started:
				_history_started = true
				_load_history()


func _on_assets_dirty() -> void:
	if _inventory != null:
		_inv_stale = true
	_ensure_loaded()


func _on_visibility_changed() -> void:
	_ensure_loaded()


# ── Nhân vật ────────────────────────────────────────────────────────────────

func _build_characters_page() -> Control:
	var col := Ui.vbox(14)
	_char_status = LoadStatus.new()
	col.add_child(_char_status)
	_cards_row = Ui.hbox(12)
	col.add_child(_cards_row)
	_detail = Ui.card(Ui.CARD_BG, 16)
	col.add_child(_detail)
	var d := Ui.vbox(8)
	_detail.add_child(d)
	# Title, points left and the actions on one line, so the stats fit above the fold.
	var head := Ui.hbox(12)
	d.add_child(head)
	_detail_title = Ui.text("", 28)
	_detail_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_detail_title.clip_text = true
	_detail_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_detail_title)
	_detail_points = Ui.text("", 24, Ui.TONES["draw"])
	head.add_child(_detail_points)
	_owned_actions = Ui.hbox(12)
	head.add_child(_owned_actions)
	_allocate = Ui.button("", 24)
	_allocate.custom_minimum_size = Vector2(220, 60)
	_allocate.pressed.connect(_on_allocate)
	_owned_actions.add_child(_allocate)
	_clear_draft = Ui.button("Bỏ chọn", 24)
	_clear_draft.custom_minimum_size = Vector2(130, 60)
	_clear_draft.pressed.connect(_on_clear_draft)
	_owned_actions.add_child(_clear_draft)
	_reset = Ui.button("Tẩy điểm (%s)" % StatDraft.cost_text(_reset_cost), 24)
	_reset.custom_minimum_size = Vector2(220, 60)
	_reset.pressed.connect(_on_reset)
	_owned_actions.add_child(_reset)
	_buy = Ui.button("Mua ở Shop", 24)
	_buy.custom_minimum_size = Vector2(220, 60)
	_buy.focus_mode = FOCUS_NONE
	_buy.pressed.connect(func(): open_shop_characters.emit())
	head.add_child(_buy)

	# "Chỉ số": per stat, the name with its points (allocated, pending, − +) and below it the
	# battle stat (total, green "→ new" preview, muted breakdown).
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	d.add_child(grid)
	for s in BattleStats.ROWS:
		var key: String = s["point"]
		var cell := Ui.vbox(2)
		cell.size_flags_horizontal = SIZE_EXPAND_FILL
		grid.add_child(cell)
		_stat_cells[key] = cell
		var r := Ui.hbox(10)
		cell.add_child(r)
		var name_label := Ui.text(s["label"], 24)
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		r.add_child(name_label)
		var points := Ui.hbox(10)
		r.add_child(points)
		_stat_points[key] = points
		_stat_value[key] = Ui.label("0", 24)
		_stat_value[key].custom_minimum_size.x = 44
		points.add_child(_stat_value[key])
		_stat_pending[key] = Ui.label("", 24)
		_stat_pending[key].custom_minimum_size.x = 44
		_stat_pending[key].add_theme_color_override("font_color", Ui.TONES["good"])
		points.add_child(_stat_pending[key])
		_stat_minus[key] = _small_button("−", _on_stat.bind(key, -1))
		points.add_child(_stat_minus[key])
		_stat_plus[key] = _small_button("+", _on_stat.bind(key, 1))
		points.add_child(_stat_plus[key])
		var bs := _battle_cell()
		cell.add_child(bs["box"])
		_bs_cells[key] = bs["box"]
		_bs_value[key] = bs["value"]
		_bs_preview[key] = bs["preview"]
		_bs_detail[key] = bs["detail"]
	_crit_row = Ui.vbox(2)
	_crit_row.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_child(_crit_row)
	_crit_row.add_child(Ui.text(BattleStats.CRIT_LABEL, 24))
	var crit := _battle_cell()
	_crit_row.add_child(crit["box"])
	_crit_value = crit["value"]
	_crit_detail = crit["detail"]

	_detail_status = Ui.text("", 22)
	_detail_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_status.visible = false
	d.add_child(_detail_status)
	return Ui.scroll(col)


func _small_button(text_value: String, on_press: Callable) -> Button:
	var b := Ui.button(text_value, 30)
	b.custom_minimum_size = Vector2(64, 56)
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(on_press)
	return b


## A battle stat cell: the value, the green "→ new" preview and the muted breakdown.
func _battle_cell() -> Dictionary:
	var box := Ui.hbox(10)
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	var value := Ui.text("", 26)
	value.custom_minimum_size.x = 70
	box.add_child(value)
	var preview := Ui.text("", 26, Ui.TONES["good"])
	box.add_child(preview)
	var detail := Ui.text("", 20, Ui.TEXT_DIM)
	detail.size_flags_horizontal = SIZE_EXPAND_FILL
	detail.clip_text = true
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(detail)
	return {"box": box, "value": value, "preview": preview, "detail": detail}


## PlayerState.characters_changed: loading / error state, and a new answer applied.
func _on_characters_changed() -> void:
	if PlayerState.characters_error != "":
		_char_status.show_error(PlayerState.characters_error, PlayerState.load_characters)
	elif PlayerState.characters_loading:
		_char_status.show_loading()
	else:
		_char_status.clear()
	if PlayerState.characters == null or PlayerState.characters_version == _characters_version:
		return
	_characters_version = PlayerState.characters_version
	_characters = {}
	for c in PlayerState.characters["characters"]:
		if c is Dictionary and str(c.get("characterId", "")) != "":
			_characters[str(c["characterId"])] = c
	_reset_cost = StatDraft.reset_cost(PlayerState.characters)
	_reset.text = "Tẩy điểm (%s)" % StatDraft.cost_text(_reset_cost)
	var drop := ""
	if _reload_id != "" and _characters_version > _reload_after:
		drop = _reload_id # its points are (or may be) spent: start that draft over
	_drafts = StatDraft.rebuild(_drafts, _characters, drop)
	if not _characters.has(_selected) and not _picked and not _characters.is_empty():
		_selected = _first_owned()
	_render_characters()
	if drop != "":
		_reload_id = ""
		_set_busy(false, _reload_note)


func _next_gen(source: String) -> int:
	_gen[source] = int(_gen.get(source, 0)) + 1
	return _gen[source]


func _first_owned() -> String:
	for c in LoadoutModel.CHARACTERS:
		if _characters.has(c["id"]):
			return c["id"]
	return LoadoutModel.DEFAULT_CHARACTER


## Rebuilds the four cards (only after a load, never from a card's own press).
func _render_characters() -> void:
	Ui.clear(_cards_row)
	_card_buttons.clear()
	var group := ButtonGroup.new()
	for c in LoadoutModel.CHARACTERS:
		var id: String = c["id"]
		var owned: bool = _characters is Dictionary and _characters.has(id)
		var card := Button.new()
		card.toggle_mode = true
		card.button_group = group
		card.focus_mode = FOCUS_NONE
		card.custom_minimum_size = Vector2(0, 208)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		card.disabled = _busy
		Ui.toggle_style(card, Ui.CARD_BG, Ui.CARD_SELECTED)
		card.pressed.connect(_on_select.bind(id))
		_cards_row.add_child(card)
		_card_buttons[id] = card
		var box := Ui.vbox(6)
		box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		box.offset_left = 14
		box.offset_right = -14
		box.offset_top = 10
		box.offset_bottom = -10
		box.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_child(box)
		var dim := Color.WHITE if owned else Ui.TEXT_DIM
		box.add_child(_ignore(Ui.text(c["name"], 28, dim)))
		var skill := Skills.for_character(id)
		var sub := Ui.text("%s · %s" % [c["role"], skill.get("name", "")], 20, Ui.TEXT_DIM)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(_ignore(sub))
		if owned:
			var entry: Dictionary = _characters[id]
			var p := Progress.character(entry)
			var line := Ui.hbox(8)
			line.mouse_filter = MOUSE_FILTER_IGNORE
			box.add_child(line)
			var lv := Ui.text("Lv.%d" % p["level"], 24)
			lv.size_flags_horizontal = SIZE_EXPAND_FILL
			line.add_child(_ignore(lv))
			var points := int(entry.get("statPoints", 0))
			if points > 0:
				line.add_child(_ignore(Ui.text("%d điểm" % points, 22, Ui.TONES["draw"])))
			box.add_child(_ignore(Ui.bar(p["ratio"], 12)))
			box.add_child(_ignore(Ui.text("MAX" if p["is_max"] else "EXP %s" % p["text"], 20, Ui.TEXT_DIM)))
		elif _characters is Dictionary:
			var line := BattleStats.card_line(BattleStats.base_of(PlayerState.characters, id))
			if line != "":
				box.add_child(_ignore(Ui.text(line, 18, Ui.TEXT_DIM)))
			var buy := Ui.button("Mua ở Shop", 22)
			buy.custom_minimum_size = Vector2(0, 48)
			buy.focus_mode = FOCUS_NONE
			buy.pressed.connect(func(): open_shop_characters.emit())
			box.add_child(buy)
	for id in _card_buttons:
		_card_buttons[id].set_pressed_no_signal(id == _selected)
	_update_detail()


static func _ignore(c: Control) -> Control:
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


func _on_select(id: String) -> void:
	_selected = id
	_picked = true
	_detail_status.text = ""
	_detail_status.visible = false
	_update_detail()


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


## The selected character's stat panel; updated in place. An owned character shows its points,
## pending allocation and battle stats; one not owned shows its base stats and "Mua ở Shop".
func _update_detail() -> void:
	var draft: StatDraft = _drafts.get(_selected)
	var owned := draft != null
	_detail.visible = owned or _characters is Dictionary
	if not _detail.visible:
		return
	var stats: Dictionary
	if owned:
		var entry: Dictionary = _characters[_selected]
		stats = BattleStats.of(entry)
		_detail_title.text = "%s · Lv.%d" % [_display_name(_selected), Progress.character(entry)["level"]]
		_detail_points.text = "Còn %d điểm" % draft.remaining()
	else:
		stats = BattleStats.base_of(PlayerState.characters, _selected)
		_detail_title.text = "%s · Chưa sở hữu" % _display_name(_selected)
		_detail_points.text = ""
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
		_stat_cells[key].visible = owned or not rows.is_empty()
	var crit := BattleStats.crit(stats)
	_crit_row.visible = not crit.is_empty()
	if not crit.is_empty():
		_crit_value.text = crit["value"]
		_crit_detail.text = crit["detail"]
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
	for c in LoadoutModel.CHARACTERS:
		if c["id"] == id:
			return c["name"]
	return id


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
	m.add_text("Tẩy toàn bộ điểm đã cộng của %s với giá %s? Điểm sẽ được hoàn lại để cộng lại." % [_display_name(id), StatDraft.cost_text(_reset_cost)])
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
		PlayerState.assets_changed() # wallet (the fee) and, via assets_dirty, the characters
		return
	if is_instance_valid(m):
		m.set_message(ErrorText.stats(res, str(_reset_cost["currency"])))
		m.set_busy(false)


func _set_busy(busy: bool, status: String, is_error: bool = false) -> void:
	_busy = busy
	_detail_status.text = status
	_detail_status.visible = status != ""
	if is_error:
		_detail_status.add_theme_color_override("font_color", Ui.TONES["error"])
	else:
		_detail_status.remove_theme_color_override("font_color")
	for id in _card_buttons:
		_card_buttons[id].disabled = busy
	_update_detail()


# ── Kho đồ ──────────────────────────────────────────────────────────────────

func _build_inventory_page() -> Control:
	var col := Ui.vbox(14)
	_inv_status = LoadStatus.new()
	col.add_child(_inv_status)
	_inv_flow = HFlowContainer.new()
	_inv_flow.add_theme_constant_override("h_separation", 12)
	_inv_flow.add_theme_constant_override("v_separation", 12)
	col.add_child(_inv_flow)
	return Ui.scroll(col)


func _load_inventory() -> void:
	var gen := _next_gen("inventory")
	_inv_stale = false
	_inv_loading = true
	_inv_status.show_loading()
	var res: Dictionary = await Api.get_json("/player/inventory")
	if not is_inside_tree() or gen != _gen["inventory"]:
		return
	_inv_loading = false
	var counts = LoadoutModel.parse_inventory(res.data) if res.ok else null
	if counts is Dictionary:
		_inventory = counts
		_inv_status.clear()
	else:
		_inv_status.show_error(ErrorText.load_failed(res) if not res.ok else "Dữ liệu kho đồ không hợp lệ", _load_inventory)
	_render_inventory()


func _render_inventory() -> void:
	Ui.clear(_inv_flow)
	for id in Items.ORDER:
		var n := int(_inventory.get(id, 0)) if _inventory is Dictionary else -1
		var card := Ui.card(Ui.CARD_BG, 18)
		card.custom_minimum_size = Vector2(270, 120)
		var box := Ui.vbox(6)
		card.add_child(box)
		box.add_child(Ui.text(Items.label(id), 26))
		box.add_child(Ui.text("x%d" % n if n >= 0 else "x—", 26, Ui.TONES["draw"]))
		if n == 0:
			card.modulate = Color(1, 1, 1, 0.4)
		_inv_flow.add_child(card)


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
