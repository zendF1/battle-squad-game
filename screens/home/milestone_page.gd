extends Control
## "Mốc thưởng" (lobby button): one-time rewards for progress milestones, claimed by hand. Tabs
## Nhân vật / Nâng cấp / Chiến đấu / Xếp hạng, each with a red dot while it has a reward to take,
## and "Nhận tất cả" (off when nothing is claimable). A tab shows its sub-tracks (MilestoneModel
## .groups: "Cấp nhân vật"; "Cường hoá", "Vũ khí", "Bộ trang bị hoàn chỉnh"; "Số trận", "Số
## trận thắng", "Thắng với 1 nhân vật"; "Hạng cao nhất") as panels, each a horizontal path of
## nodes scrolled to the first one to take: the threshold ("Cấp 20", "+14", "Cả bộ +6", "Vàng"),
## the reward icons with their amounts, then "Nhận" (claimable: gold glow, bouncing, tap to
## claim), "Đã nhận" (dim, check) or the progress ("37/50", locked: grey); the weapon aura nodes
## add their description; a node giving a title is wider and shows the title's small plate over
## its other rewards (one row). A claim opens a popup listing what was received (a new title:
## its plate, "Danh hiệu mới: …" and "Đeo ngay"); the wallet and the stones update at once
## (PlayerState). Loads the list when shown; failures show inline with "Thử lại".

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const Modal := preload("res://ui/modal.gd")
const MilestoneModel := preload("res://screens/home/milestone_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const TitlePlate := preload("res://ui/title_plate.gd")
const ChestIcon := preload("res://ui/chest_icon.gd")

const NODE_W := 150
const WIDE_W := 196
const BOX := Vector2(132, 96)
const LINK_W := 34
const THRESHOLD_H := 26
const NODE_H := 196 # threshold, reward box, state line
const DESCRIPTION_H := 50
const NODE_TITLE_H := 36 # a title reward's plate in a node box
const TITLE_W := 236 # a node giving a title
const GOLD := Color(1.0, 0.8, 0.22)
const DIM := Color(0.8, 0.88, 1.0)
const RED := Color(0.93, 0.22, 0.25)
const GREY := Color(0.55, 0.58, 0.68)

## Where dialogs and toasts go (Home); defaults to this page.
var overlay: Control

var _tab := 0
var _armed := false
var _tabs: Array[Button]
var _dots: Array[Control] = []
var _claim_all: Button
var _status: LoadStatus
var _scroll: ScrollContainer
var _body: VBoxContainer
var _rendered_version := -1
var _rendered_tab := -1


func _ready() -> void:
	if overlay == null:
		overlay = self
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var col := Ui.vbox(12)
	margin.add_child(col)
	var top := Ui.hbox(8)
	col.add_child(top)
	var names: Array = MilestoneModel.TABS.map(func(t): return t[1])
	_tabs = Ui.tab_row(names, 24, show_tab)
	for b in _tabs:
		b.size_flags_horizontal = SIZE_FILL
		b.custom_minimum_size.x = 200
		top.add_child(b)
		var d := dot(14)
		b.add_child(d)
		d.set_anchors_preset(PRESET_TOP_RIGHT)
		d.offset_left = -26
		d.offset_right = -12
		d.offset_top = 10
		d.offset_bottom = 24
		_dots.append(d)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(spacer)
	_claim_all = Ui.button("Nhận tất cả", 24)
	LobbyUi.style_button(_claim_all, LobbyUi.ICON_COLORS["orange"], 14, 8)
	_claim_all.add_theme_font_override("font", LobbyUi.bold())
	_claim_all.custom_minimum_size = Vector2(220, 64)
	_claim_all.focus_mode = FOCUS_NONE
	_claim_all.pressed.connect(_claim_every)
	top.add_child(_claim_all)
	_status = LoadStatus.new()
	col.add_child(_status)
	_body = Ui.vbox(14)
	_scroll = Ui.scroll(_body)
	col.add_child(_scroll)

	PlayerState.milestones_changed.connect(_on_data_changed)
	visibility_changed.connect(_ensure_loaded)
	show_tab(0)
	_arm.call_deferred()


## Shows tab `index` (MilestoneModel.TABS).
func show_tab(index: int) -> void:
	_tab = clampi(index, 0, MilestoneModel.TABS.size() - 1)
	Ui.select_tab(_tabs, _tab)
	_render()


func _arm() -> void:
	_armed = true
	_ensure_loaded()


func _ensure_loaded() -> void:
	if not (_armed and is_visible_in_tree()):
		return
	PlayerState.need_milestones()
	_render()


## Deferred: a press inside a path must not free its own button mid-signal.
func _on_data_changed() -> void:
	if is_inside_tree():
		_render.call_deferred()


func _render() -> void:
	if _body == null:
		return
	var data = PlayerState.milestones
	if PlayerState.milestones_error != "" and data == null:
		_status.show_error(PlayerState.milestones_error, PlayerState.load_milestones)
	elif data == null:
		_status.show_loading()
	else:
		_status.clear()
	for i in _dots.size():
		_dots[i].visible = MilestoneModel.claimable_in(data, MilestoneModel.TABS[i][0]) > 0
	var total := MilestoneModel.claimable_total(data)
	_claim_all.disabled = total == 0 or PlayerState.milestone_busy != ""
	_claim_all.text = "Nhận tất cả (%d)" % total if total > 0 else "Nhận tất cả"
	if _rendered_version == PlayerState.milestones_version and _rendered_tab == _tab and _body.get_child_count() > 0:
		return # same data on screen: keep the paths where the player scrolled them
	var refocus := _rendered_tab != _tab
	var keep_v := _scroll.scroll_vertical
	_rendered_version = PlayerState.milestones_version
	_rendered_tab = _tab
	Ui.clear(_body)
	var paths: Array = []
	for g in MilestoneModel.groups(data, MilestoneModel.TABS[_tab][0]):
		paths.append(_build_group(g))
	_scroll_paths.call_deferred(paths, 0 if refocus else keep_v)


func _scroll_paths(paths: Array, v: int) -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = v
	for p in paths:
		var s: ScrollContainer = p[0]
		if is_instance_valid(s):
			s.scroll_horizontal = maxi(0, p[1] * (NODE_W + LINK_W) - (NODE_W + LINK_W))


## One sub-track: its title and hint, then the path of nodes. Returns [scroll, focus index].
func _build_group(g: Dictionary) -> Array:
	var panel := LobbyUi.panel(14)
	_body.add_child(panel)
	var col := Ui.vbox(8)
	panel.add_child(col)
	var head := Ui.hbox(14)
	col.add_child(head)
	var t := LobbyUi.text(g["title"], 28, Color.WHITE, true)
	head.add_child(t)
	if g["hint"] != "":
		var h := LobbyUi.text(g["hint"], 20, DIM)
		h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.size_flags_vertical = SIZE_SHRINK_CENTER
		head.add_child(h)
	var nodes: Array = g["nodes"]
	var reached := nodes.filter(func(n): return n["state"] != MilestoneModel.LOCKED).size()
	var count := LobbyUi.text("%d/%d" % [reached, nodes.size()], 20, DIM)
	count.size_flags_horizontal = SIZE_EXPAND_FILL
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(count)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	col.add_child(scroll)
	var path := Ui.hbox(0)
	scroll.add_child(path)
	var with_text := nodes.any(func(n): return n["description"] != "")
	var height := NODE_H + (DESCRIPTION_H if with_text else 0)
	scroll.custom_minimum_size.y = height
	for i in nodes.size():
		if i > 0:
			path.add_child(_link(nodes[i]["state"] != MilestoneModel.LOCKED))
		path.add_child(_node(nodes[i], height))
	return [scroll, MilestoneModel.focus_index(nodes)]


## The line between two nodes, gold when the next one is reached.
func _link(reached: bool) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(LINK_W, 0)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	var y := THRESHOLD_H + 6 + 4 + BOX.y / 2
	c.draw.connect(func():
		var color := GOLD if reached else Color(1, 1, 1, 0.18)
		c.draw_line(Vector2(-4, y), Vector2(LINK_W + 4, y), Color(0, 0, 0, 0.5), 9.0, true)
		c.draw_line(Vector2(-4, y), Vector2(LINK_W + 4, y), color, 5.0, true))
	return c


## A node: threshold, the reward box, the state line (and the description).
func _node(n: Dictionary, height: int) -> Control:
	var state: String = n["state"]
	var lines := MilestoneModel.reward_lines(n["rewards"])
	var titles := MilestoneModel.title_lines(lines)
	var w := TITLE_W if not titles.is_empty() else (WIDE_W if n["description"] != "" else NODE_W) # room for the plate / description
	var box_size := BOX if titles.is_empty() else Vector2(w - 12, BOX.y)
	var b := Button.new()
	b.flat = true
	b.focus_mode = FOCUS_NONE
	b.custom_minimum_size = Vector2(w, height)
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	b.pressed.connect(_on_node.bind(n))
	var col := Ui.vbox(6)
	col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(col)
	var th := LobbyUi.text(MilestoneModel.threshold(n), 24, GOLD if state == MilestoneModel.CLAIMABLE else Color.WHITE, true)
	th.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	th.custom_minimum_size.y = THRESHOLD_H
	col.add_child(th)
	var holder := Control.new() # not a container: the box bounces, the check sits on its corner
	holder.custom_minimum_size = Vector2(w, BOX.y + 8)
	col.add_child(holder)
	var box := PanelContainer.new()
	box.custom_minimum_size = box_size
	box.size = box_size
	box.position = Vector2((w - box_size.x) / 2, 4)
	box.add_theme_stylebox_override("panel", _box_style(state))
	holder.add_child(box)
	var rewards := Ui.vbox(2)
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(rewards)
	if not titles.is_empty():
		# The title's plate, then the other rewards in one row
		var plate := TitlePlate.new()
		plate.plate_height = NODE_TITLE_H
		plate.max_width = box_size.x - 10
		plate.shine = state != MilestoneModel.LOCKED
		plate.set_title(titles[0])
		plate.size_flags_horizontal = SIZE_SHRINK_CENTER
		rewards.add_child(plate)
		var row := Ui.hbox(10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		rewards.add_child(row)
		for line in MilestoneModel.other_lines(lines).slice(0, 2):
			var cell := Ui.hbox(4)
			cell.add_child(reward_icon_node(line, 30))
			var q := LobbyUi.text(line["short"], 19, Color.WHITE, true)
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cell.add_child(q)
			row.add_child(cell)
	else:
		var px := 44 if lines.size() <= 1 else 34
		for line in lines.slice(0, 3):
			var row := Ui.hbox(6)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(reward_icon_node(line, px))
			var q := LobbyUi.text(line["short"], 22 if lines.size() <= 1 else 20, Color.WHITE, true)
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(q)
			rewards.add_child(row)
	if state == MilestoneModel.CLAIMED:
		box.modulate = Color(1, 1, 1, 0.5)
		th.modulate = Color(1, 1, 1, 0.55)
		var check := LobbyUi.icon("check", 46)
		check.size = Vector2(46, 46)
		check.position = Vector2((w + box_size.x) / 2 - 34, -8)
		holder.add_child(check)
	elif state == MilestoneModel.LOCKED:
		box.modulate = Color(0.62, 0.64, 0.72)
	else:
		box.pivot_offset = box_size / 2
		var bounce := box.create_tween().set_loops()
		bounce.tween_property(box, "scale", Vector2(1.07, 1.07), 0.45).set_trans(Tween.TRANS_SINE)
		bounce.tween_property(box, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	var foot := _state_line(n)
	col.add_child(foot)
	if n["description"] != "":
		var d := LobbyUi.text(n["description"], 17, Color(0.85, 0.75, 1.0) if state != MilestoneModel.LOCKED else GREY)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = w
		col.add_child(d)
	for c in col.find_children("*", "Control", true, false):
		c.mouse_filter = MOUSE_FILTER_IGNORE
	return b


func _state_line(n: Dictionary) -> Control:
	var text := MilestoneModel.state_text(n)
	match n["state"]:
		MilestoneModel.CLAIMABLE:
			var pill := PanelContainer.new()
			pill.add_theme_stylebox_override("panel", LobbyUi.box(LobbyUi.GOLD, 16, 4))
			pill.custom_minimum_size = Vector2(NODE_W - 36, 34)
			pill.size_flags_horizontal = SIZE_SHRINK_CENTER
			var l := Ui.text(text, 22, LobbyUi.TEXT_DARK)
			l.add_theme_font_override("font", LobbyUi.bold())
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pill.add_child(l)
			return pill
		MilestoneModel.CLAIMED:
			var l := LobbyUi.text(text, 20, Color(0.6, 0.9, 0.65))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.custom_minimum_size.y = 34
			return l
	var l := LobbyUi.text(text, 21, GREY)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.y = 34
	return l


static func _box_style(state: String) -> StyleBoxFlat:
	var s := LobbyUi.box(Color(0.08, 0.1, 0.24, 0.92), 18, 6, Color(1, 1, 1, 0.16), 2)
	match state:
		MilestoneModel.CLAIMABLE:
			s.bg_color = Color(0.22, 0.16, 0.08, 0.95)
			s.border_color = GOLD
			s.set_border_width_all(3)
			s.shadow_color = Color(1.0, 0.75, 0.2, 0.55)
			s.shadow_size = 12
		MilestoneModel.CLAIMED:
			s.border_color = Color(0.45, 0.85, 0.5, 0.6)
		MilestoneModel.LOCKED:
			s.bg_color = Color(0.1, 0.11, 0.16, 0.9)
	return s


## The icon of a reward line as a control px wide: a chest's drawn icon (ui/chest_icon.gd), else
## reward_icon()'s texture.
static func reward_icon_node(line: Dictionary, px: int) -> Control:
	if str(line.get("kind", "")) == "chest":
		return ChestIcon.make(str(line.get("id", "")), px)
	return LobbyUi.icon(reward_icon(line), px)


## The icon of a reward line (MilestoneModel.reward_lines).
static func reward_icon(line: Dictionary) -> Texture2D:
	match str(line.get("kind", "")):
		"coin": return Art.icon("coin")
		"gem": return Art.icon("gem")
		"stone": return Art.stone_icon(int(line.get("level", 1)))
	return Art.item_icon(str(line.get("id", "")))


## A small red dot (a tab or button with a reward to take).
static func dot(diameter: int) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(diameter, diameter)
	p.size = Vector2(diameter, diameter)
	p.add_theme_stylebox_override("panel", LobbyUi.box(RED, diameter / 2, 0, Color(1, 1, 1, 0.9), 2))
	p.mouse_filter = MOUSE_FILTER_IGNORE
	return p


## A red count badge ("3", "9+") for the lobby button.
static func badge() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", LobbyUi.box(RED, 14, 2, Color(1, 1, 1, 0.95), 2))
	p.custom_minimum_size = Vector2(30, 30)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var l := LobbyUi.text("", 18, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 22
	p.add_child(l)
	return p


# ── Claiming ────────────────────────────────────────────────────────────────

func _on_node(n: Dictionary) -> void:
	match n["state"]:
		MilestoneModel.CLAIMABLE:
			_claim_one(n)
		MilestoneModel.CLAIMED:
			Ui.toast(overlay, "Đã nhận: %s" % MilestoneModel.title(n))
		_:
			var p := MilestoneModel.progress_text(n)
			Ui.toast(overlay, "Chưa đạt: %s%s" % [MilestoneModel.title(n), " (%s)" % p if p != "" else ""])


## The first claimable node of the shown tab, {} when none (the smoke driver).
func _first_claimable() -> Dictionary:
	for n in MilestoneModel.nodes(PlayerState.milestones, MilestoneModel.TABS[_tab][0]):
		if n["state"] == MilestoneModel.CLAIMABLE:
			return n
	return {}


func _claim_one(n: Dictionary) -> void:
	if n.is_empty() or PlayerState.milestone_busy != "":
		return
	var res: Dictionary = await PlayerState.claim_milestone(n["id"])
	_after_claim(res, MilestoneModel.title(n))


func _claim_every() -> void:
	if PlayerState.milestone_busy != "":
		return
	var res: Dictionary = await PlayerState.claim_all_milestones()
	var data: Dictionary = res.data if res.ok and res.data is Dictionary else {}
	var n: int = data.get("claimed", []).size() if data.get("claimed") is Array else 0
	_after_claim(res, "Đã nhận %d mốc thưởng" % n)


func _after_claim(res: Dictionary, heading: String) -> void:
	if not is_inside_tree():
		return
	if not res.ok:
		Ui.toast(overlay, ErrorText.milestone(res))
		return
	var data: Dictionary = res.data if res.data is Dictionary else {}
	var lines := MilestoneModel.reward_lines(MilestoneModel.parse_rewards(data.get("rewards")))
	if lines.is_empty():
		Ui.toast(overlay, "Không có mốc nào để nhận")
		return
	show_rewards(overlay, heading, lines)


## The "Nhận thưởng" popup: the heading, a new title's plate with "Danh hiệu mới: …" and
## "Đeo ngay" (each title), then one row per other reward (icon and text).
static func show_rewards(host: Control, heading: String, all_lines: Array) -> Modal:
	var m := Modal.new()
	m.open(host, "Nhận thưởng", 620)
	m.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var h := m.add_text(heading, 24)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_color_override("font_color", DIM)
	for t in MilestoneModel.title_lines(all_lines):
		m.body.add_child(_new_title_row(host, t))
	var lines := MilestoneModel.other_lines(all_lines)
	# Two columns when the list is long (a big claim-all)
	var columns := Ui.hbox(40)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	m.body.add_child(columns)
	var per_column := ceili(lines.size() / 2.0) if lines.size() > 5 else lines.size()
	var column: VBoxContainer = null
	for i in lines.size():
		if i % maxi(1, per_column) == 0:
			column = Ui.vbox(10)
			columns.add_child(column)
		var line: Dictionary = lines[i]
		var row := Ui.hbox(14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER if per_column == lines.size() else BoxContainer.ALIGNMENT_BEGIN
		row.add_child(reward_icon_node(line, 52))
		var l := LobbyUi.text(line["text"], 28, Color.WHITE, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		column.add_child(row)
	m.add_button("Tuyệt!", m.close)
	m.close_on_backdrop()
	return m


## A title the claim gave: its plate, "Danh hiệu mới: …" and "Đeo ngay" ("Đang đeo" once worn).
static func _new_title_row(host: Control, line: Dictionary) -> Control:
	var col := Ui.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var plate := TitlePlate.new()
	plate.plate_height = 64
	plate.max_width = 540
	plate.set_title({"id": line["id"], "name": line["name"], "rarity": line["rarity"]})
	plate.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(plate)
	var row := Ui.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var l := LobbyUi.text(line["text"], 26, GOLD, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var wear := Ui.button("Đeo ngay", 22)
	wear.custom_minimum_size = Vector2(150, 56)
	wear.focus_mode = FOCUS_NONE
	row.add_child(wear)
	var worn := func() -> void:
		wear.text = "Đang đeo"
		wear.disabled = true
	if PlayerState.equipped_title().get("id", "") == line["id"]:
		worn.call()
	wear.pressed.connect(func():
		if PlayerState.title_busy:
			return
		wear.disabled = true
		var res: Dictionary = await PlayerState.equip_title(line["id"])
		if not is_instance_valid(wear):
			return
		if res.ok:
			worn.call()
			Ui.toast(host, "Đã đeo danh hiệu: %s" % line["name"])
		else:
			wear.disabled = false
			Ui.toast(host, ErrorText.title(res)))
	return col
