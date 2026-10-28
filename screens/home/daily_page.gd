extends Control
## "Nhiệm Vụ Ngày" (lobby button "Nhiệm vụ"): daily missions that give activity points (Năng
## động), the day's chests at 20..100 activity and the week's rewards at 150..600. The header
## (Home's) carries "Làm mới sau HH:MM:SS" to the day's reset (header_extra()).
## Left column: today's activity on a shield ("Đã mở 2/5 rương") and the week card ("Năng động
## tuần này 150", "Làm mới sau 3 ngày 05:12", its bar and the 4 weekly rewards as tiles).
## Right column: the chest track (5 chests over the activity bar, the thresholds on it: locked
## chests grey, a claimable one glowing and bouncing, a claimed one open with a green check),
## then the missions (claimable first, then in progress, then claimed): a star with "+N", the
## title, a bar "x/y" and the button: "Nhận" (gold) claims, "Đi ngay" (blue) emits `go` with the
## mission's goto (Home: play → the lobby's BẮT ĐẦU, shop → Shop, equipment → Nâng cấp), "Chưa
## xong" / "Đã nhận" are off. A claim flies "+N" to the shield while the number and the bars
## count up. A tap on a chest / weekly tile claims it when claimable ("Nhận được" popup, the
## milestone one) or shows what it gives. Failures toast the server's reason (ErrorText.mission)
## and the list reloads. Loads each time it is shown and again when the day turns.

signal go(target: String)

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const Modal := preload("res://ui/modal.gd")
const DailyModel := preload("res://screens/home/daily_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const MilestonePage := preload("res://screens/home/milestone_page.gd")
const MilestoneModel := preload("res://screens/home/milestone_model.gd")
const MissionArt := preload("res://screens/home/mission_art.gd")

const LEFT_W := 400
const CHEST := Vector2(104, 100)
const TRACK_H := 148
const BAR_Y := 112.0
const BAR_H := 20.0
const PILL := Vector2(64, 34)
const ROW_H := 104
const BUTTON := Vector2(210, 66)
const GOLD := Color(1.0, 0.8, 0.22)
const DIM := Color(0.8, 0.88, 1.0)
const GREY := Color(0.55, 0.58, 0.68)
const BLUE := Color(0.22, 0.52, 0.95)
const GREEN := Color(0.45, 0.88, 0.55)
const COUNT_UP := 0.9 # s, the number and the bars after a mission claim

## Where dialogs and toasts go (Home); defaults to this page.
var overlay: Control
## The clock the countdowns read (unix seconds); the preview pins it.
var now := func() -> int: return int(Time.get_unix_time_from_system())

var _armed := false
var _countdown: Label
var _countdown_box: Control
var _shield: Control
var _activity: Label
var _opened: Label
var _week_value: Label
var _week_countdown: Label
var _week_bar: ProgressBar
var _week_bar_text: Label
var _week_grid: GridContainer
var _track: Control
var _bar: ProgressBar
var _chests: Array = [] # [button, pill] per chest
var _status: LoadStatus
var _scroll: ScrollContainer
var _list: VBoxContainer
var _rendered_version := -1
var _shown_activity := 0.0
var _shown_weekly := 0.0
var _count_tween: Tween
var _animate_next := false
var _reset_asked := -1


func _init() -> void:
	_build_countdown()


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
	var left := Ui.vbox(14)
	left.custom_minimum_size.x = LEFT_W
	row.add_child(left)
	left.add_child(_build_day_card())
	left.add_child(_build_week_card())
	var right := Ui.vbox(12)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_build_track())
	_status = LoadStatus.new()
	right.add_child(_status)
	_list = Ui.vbox(10)
	_scroll = Ui.scroll(_list)
	right.add_child(_scroll)

	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_tick)
	add_child(tick)
	PlayerState.daily_changed.connect(_on_data_changed)
	visibility_changed.connect(_ensure_loaded)
	_render()
	_arm.call_deferred()


func _arm() -> void:
	_armed = true
	_ensure_loaded()


func _ensure_loaded() -> void:
	if not (_armed and is_visible_in_tree()):
		return
	PlayerState.load_daily()
	_render()


## Deferred: a press inside a row must not free its own button mid-signal.
func _on_data_changed() -> void:
	if is_inside_tree():
		_render.call_deferred()


## The header's countdown (Home puts it after the title): a pill "Làm mới sau 05:12:33".
func header_extra() -> Control:
	return _countdown_box


func _build_countdown() -> void:
	var holder := HBoxContainer.new()
	holder.size_flags_horizontal = SIZE_EXPAND_FILL
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	var pill := PanelContainer.new()
	pill.size_flags_vertical = SIZE_SHRINK_CENTER
	var style := LobbyUi.box(Color(0.03, 0.05, 0.14, 0.7), 22, 8, Color(1, 1, 1, 0.14), 2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	pill.add_theme_stylebox_override("panel", style)
	holder.add_child(pill)
	_countdown = LobbyUi.text("", 24, DIM, true)
	_countdown.custom_minimum_size.x = 250
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(_countdown)
	_countdown_box = holder
	pill.visible = false


# ── Left column ─────────────────────────────────────────────────────────────

func _build_day_card() -> Control:
	var card := LobbyUi.panel(16)
	var col := Ui.vbox(4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)
	var t := LobbyUi.text("Năng động ngày", 26, Color.WHITE, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	_shield = Control.new()
	_shield.custom_minimum_size = Vector2(LEFT_W - 32, 176)
	_shield.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(_shield)
	var art := MissionArt.make(MissionArt.Kind.SHIELD, Vector2(176, 176))
	art.position = Vector2((LEFT_W - 32 - 176) / 2.0, 0)
	_shield.add_child(art)
	_activity = LobbyUi.text("0", 68, GOLD, true)
	LobbyUi.outline(_activity, 10)
	_activity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_activity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_activity.position = Vector2(0, 44)
	_activity.size = Vector2(LEFT_W - 32, 96)
	_shield.add_child(_activity)
	_opened = LobbyUi.text("", 21, DIM)
	_opened.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_opened)
	return card


func _build_week_card() -> Control:
	var card := LobbyUi.panel(16)
	card.size_flags_vertical = SIZE_EXPAND_FILL
	var col := Ui.vbox(8)
	card.add_child(col)
	var head := Ui.hbox(8)
	col.add_child(head)
	var star := MissionArt.make(MissionArt.Kind.STAR, Vector2(40, 40))
	star.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(star)
	var t := LobbyUi.text("Năng động tuần này", 24, Color.WHITE, true)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = SIZE_EXPAND_FILL
	t.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(t)
	_week_value = LobbyUi.text("0", 40, GOLD, true)
	_week_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_week_value)
	_week_countdown = LobbyUi.text("", 19, DIM)
	col.add_child(_week_countdown)
	_week_bar = _bar_widget(18, GOLD)
	col.add_child(_week_bar)
	_week_bar_text = LobbyUi.text("", 16, Color.WHITE, true)
	_week_bar_text.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_week_bar_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_week_bar_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_week_bar.add_child(_week_bar_text)
	var gap := Control.new()
	gap.custom_minimum_size.y = 2
	col.add_child(gap)
	_week_grid = GridContainer.new()
	_week_grid.columns = 2
	_week_grid.add_theme_constant_override("h_separation", 12)
	_week_grid.add_theme_constant_override("v_separation", 12)
	col.add_child(_week_grid)
	return card


## A weekly reward: its threshold, the reward box (up to two reward lines), the state.
func _week_tile(c: Dictionary) -> Control:
	var state: String = c["state"]
	var w := (LEFT_W - 32 - 12) / 2
	var b := _flat_button(Vector2(w, 150))
	b.pressed.connect(_on_chest.bind(c["id"]))
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _tile_style(state))
	box.position = Vector2(6, 4)
	box.size = Vector2(w - 12, 108)
	box.pivot_offset = box.size / 2
	b.add_child(box)
	var rewards := Ui.vbox(2)
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(rewards)
	var lines := DailyModel.reward_lines(c["rewards"])
	for line in lines.slice(0, 2):
		var r := Ui.hbox(6)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_child(MilestonePage.reward_icon_node(line, 40 if lines.size() <= 1 else 34))
		var q := LobbyUi.text(line["short"], 22 if lines.size() <= 1 else 20, Color.WHITE, true)
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.add_child(q)
		rewards.add_child(r)
	var pill := _threshold_pill(c["threshold"], state)
	pill.position = Vector2((w - PILL.x) / 2, 112 - PILL.y / 2 + 6)
	b.add_child(pill)
	_decorate(box, state, Vector2(w - 12 - 30, -8), b)
	_mouse_ignore(b)
	return b


static func _tile_style(state: String) -> StyleBoxFlat:
	var s := LobbyUi.box(Color(0.08, 0.1, 0.24, 0.92), 16, 6, Color(1, 1, 1, 0.16), 2)
	match state:
		DailyModel.CLAIMABLE:
			s.bg_color = Color(0.22, 0.16, 0.08, 0.95)
			s.border_color = GOLD
			s.set_border_width_all(3)
			s.shadow_color = Color(1.0, 0.75, 0.2, 0.55)
			s.shadow_size = 12
		DailyModel.CLAIMED:
			s.border_color = Color(0.45, 0.85, 0.5, 0.6)
		_:
			s.bg_color = Color(0.1, 0.11, 0.16, 0.9)
	return s


# ── Chest track ─────────────────────────────────────────────────────────────

func _build_track() -> Control:
	var card := LobbyUi.panel(14)
	_track = Control.new()
	_track.custom_minimum_size.y = TRACK_H
	_track.mouse_filter = MOUSE_FILTER_IGNORE
	_track.resized.connect(_layout_track)
	card.add_child(_track)
	_bar = _bar_widget(int(BAR_H), GOLD)
	_track.add_child(_bar)
	return card


## Places the bar and the chests: chest i over its threshold at (i + 1) / n of the bar.
func _layout_track() -> void:
	var x0 := 18.0
	var x1 := _track.size.x - CHEST.x / 2 - 4
	_bar.position = Vector2(x0, BAR_Y)
	_bar.size = Vector2(x1 - x0, BAR_H)
	for i in _chests.size():
		var x := x0 + DailyModel.marker_at(i, _chests.size()) * (x1 - x0)
		var b: Control = _chests[i][0]
		var pill: Control = _chests[i][1]
		b.position = Vector2(x - CHEST.x / 2, 0)
		pill.position = Vector2(x - PILL.x / 2, BAR_Y + BAR_H / 2 - PILL.y / 2)


func _render_track(chests: Array) -> void:
	for pair in _chests:
		for c in pair:
			c.queue_free()
	_chests.clear()
	for i in chests.size():
		var c: Dictionary = chests[i]
		var b := _flat_button(CHEST)
		b.pressed.connect(_on_chest.bind(c["id"]))
		if c["state"] == DailyModel.CLAIMABLE:
			var rays := MissionArt.make(MissionArt.Kind.RAYS, Vector2(170, 170))
			rays.position = (CHEST - rays.size) / 2 + Vector2(0, 4)
			rays.pivot_offset = rays.size / 2
			b.add_child(rays)
			rays.create_tween().set_loops().tween_property(rays, "rotation", TAU, 8.0).from(0.0)
		var art := MissionArt.make(MissionArt.Kind.CHEST, CHEST)
		art.tint = MissionArt.CHEST_TINTS[mini(i, MissionArt.CHEST_TINTS.size() - 1)]
		art.opened = c["state"] == DailyModel.CLAIMED
		art.glow = c["state"] == DailyModel.CLAIMABLE
		art.pivot_offset = CHEST / 2
		b.add_child(art)
		if c["state"] == DailyModel.LOCKED:
			art.modulate = Color(0.62, 0.64, 0.74)
		elif c["state"] == DailyModel.CLAIMABLE:
			_bounce(art)
		_track.add_child(b)
		var pill := _threshold_pill(c["threshold"], c["state"])
		_track.add_child(pill)
		_chests.append([b, pill])
	_layout_track()


## The threshold on a bar: a small dark pill, gold text once reached.
func _threshold_pill(threshold: int, state: String) -> Control:
	var reached := state != DailyModel.LOCKED
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", LobbyUi.box(Color(0.98, 0.78, 0.2) if reached else Color(0.09, 0.12, 0.3), 10, 0,
		Color(0.05, 0.05, 0.12, 0.9), 3))
	p.custom_minimum_size = PILL
	p.size = PILL
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var l := LobbyUi.text(str(threshold), 22, LobbyUi.TEXT_DARK if reached else Color.WHITE, true)
	if reached:
		l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


# ── Mission rows ────────────────────────────────────────────────────────────

func _row(m: Dictionary) -> Control:
	var state: String = m["state"]
	var panel := PanelContainer.new()
	var style := LobbyUi.box(Color(0.06, 0.09, 0.24, 0.86), 16, 0, Color(1, 1, 1, 0.12), 2)
	style.content_margin_left = 14
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	if state == DailyModel.CLAIMABLE:
		style.bg_color = Color(0.16, 0.14, 0.2, 0.92)
		style.border_color = Color(GOLD, 0.85)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.y = ROW_H
	panel.mouse_filter = MOUSE_FILTER_PASS # a drag on a row scrolls the list
	var row := Ui.hbox(18)
	panel.add_child(row)
	# The star with the activity it gives
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(84, ROW_H - 16)
	badge.name = "Star"
	row.add_child(badge)
	var star := MissionArt.make(MissionArt.Kind.STAR, Vector2(62, 62))
	star.position = Vector2(11, 0)
	badge.add_child(star)
	var pts := LobbyUi.text("+%d" % m["activity"], 24, Color.WHITE, true)
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pts.position = Vector2(0, 54)
	pts.size = Vector2(84, 30)
	badge.add_child(pts)
	# Title and progress
	var mid := Ui.vbox(10)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(mid)
	var title := LobbyUi.text(m["title"], 27, Color.WHITE, true)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(title)
	var done := state != DailyModel.PROGRESS
	var bar := _bar_widget(24, Color(0.24, 0.66, 0.34) if done else Color(0.25, 0.6, 0.98))
	bar.value = DailyModel.progress_ratio(m)
	mid.add_child(bar)
	var p := LobbyUi.text(DailyModel.progress_text(m), 19, Color.WHITE, true)
	LobbyUi.outline(p, 5)
	p.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(p)
	row.add_child(_row_button(m, badge))
	if state == DailyModel.CLAIMED:
		for c in [badge, mid]:
			c.modulate = Color(1, 1, 1, 0.55)
	_mouse_ignore(panel)
	return panel


func _row_button(m: Dictionary, badge: Control) -> Control:
	var spec := DailyModel.button(m)
	var b := Button.new()
	b.text = spec["text"]
	b.custom_minimum_size = BUTTON
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_font_override("font", LobbyUi.bold())
	b.focus_mode = FOCUS_NONE
	match spec["action"]:
		DailyModel.ACTION_CLAIM:
			LobbyUi.style_button(b, GOLD, 16, 8, Color(0.55, 0.3, 0.05), 3)
			for s in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(s, LobbyUi.TEXT_DARK)
			b.add_theme_color_override("font_disabled_color", Color(LobbyUi.TEXT_DARK, 0.6))
			b.disabled = PlayerState.daily_busy != ""
			b.pressed.connect(_claim_mission.bind(m["id"], badge))
			b.resized.connect(func(): b.pivot_offset = b.size / 2)
			var pulse := b.create_tween().set_loops()
			pulse.tween_property(b, "scale", Vector2(1.05, 1.05), 0.55).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(b, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)
		DailyModel.ACTION_GO:
			LobbyUi.style_button(b, BLUE, 16, 8, Color(1, 1, 1, 0.35), 2)
			b.pressed.connect(func(): go.emit(m["goto"]))
		_:
			LobbyUi.style_button(b, Color(0.2, 0.23, 0.34), 16, 8)
			b.disabled = true
			b.add_theme_color_override("font_disabled_color", GREEN if m["state"] == DailyModel.CLAIMED else GREY)
			if m["state"] == DailyModel.CLAIMED:
				LobbyUi.set_icon(b, "check", 26)
				b.add_theme_constant_override("h_separation", 8)
	return b


# ── Shared bits ─────────────────────────────────────────────────────────────

func _bar_widget(height: int, fill: Color) -> ProgressBar:
	var b := Ui.bar(0.0, height)
	b.add_theme_stylebox_override("fill", LobbyUi.box(fill, height / 2, 0))
	b.add_theme_stylebox_override("background", LobbyUi.box(Color(0, 0, 0, 0.5), height / 2, 0, Color(1, 1, 1, 0.14), 1))
	b.mouse_filter = MOUSE_FILTER_IGNORE
	return b


static func _flat_button(px: Vector2) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = FOCUS_NONE
	b.custom_minimum_size = px
	b.size = px
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	return b


## A reward box by state: claimable bounces, claimed is dim with a check on its corner (at
## `check_at` in `holder`), locked is grey.
func _decorate(box: Control, state: String, check_at: Vector2, holder: Control) -> void:
	match state:
		DailyModel.CLAIMABLE:
			_bounce(box)
		DailyModel.CLAIMED:
			box.modulate = Color(1, 1, 1, 0.5)
			var check := LobbyUi.icon("check", 42)
			check.size = Vector2(42, 42)
			check.position = check_at
			holder.add_child(check)
		_:
			box.modulate = Color(0.74, 0.76, 0.84)


static func _bounce(c: Control) -> void:
	var t := c.create_tween().set_loops()
	t.tween_property(c, "scale", Vector2(1.08, 1.08), 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


static func _mouse_ignore(root: Control) -> void:
	for c in root.find_children("*", "Control", true, false):
		if not c is Button:
			c.mouse_filter = MOUSE_FILTER_IGNORE


# ── Render ──────────────────────────────────────────────────────────────────

func _render() -> void:
	if _list == null:
		return
	var data = PlayerState.daily
	if data == null and PlayerState.daily_error != "":
		_status.show_error(PlayerState.daily_error, PlayerState.load_daily)
	elif data == null:
		_status.show_loading()
	else:
		_status.clear()
	_tick()
	if data == null:
		_set_counts(0.0, 0.0)
		return
	var busy_changed := _rendered_version == PlayerState.daily_version
	var keep_v := _scroll.scroll_vertical
	if not busy_changed:
		_rendered_version = PlayerState.daily_version
		_render_track(data["chests"])
		Ui.clear(_week_grid)
		for c in data["weekly"]:
			_week_grid.add_child(_week_tile(c))
		var opened := (data["chests"] as Array).filter(func(c): return c["state"] == DailyModel.CLAIMED).size()
		_opened.text = "Đã mở %d/%d rương" % [opened, data["chests"].size()]
		var animate: bool = _animate_next and (data["activity"] > _shown_activity or data["weekly_activity"] > _shown_weekly)
		_animate_next = false
		if animate:
			_count_up(data["activity"], data["weekly_activity"])
		else:
			_set_counts(data["activity"], data["weekly_activity"])
	Ui.clear(_list)
	for m in DailyModel.sorted_missions(data["missions"]):
		_list.add_child(_row(m))
	_restore_scroll.call_deferred(keep_v)


func _restore_scroll(v: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = v


## The shield number, the weekly number and both bars at these (animated) values.
func _set_counts(day: float, week: float) -> void:
	_shown_activity = day
	_shown_weekly = week
	var data = PlayerState.daily
	_activity.text = str(roundi(day))
	_week_value.text = str(roundi(week))
	var chests: Array = data["chests"] if data is Dictionary else []
	var weekly: Array = data["weekly"] if data is Dictionary else []
	_bar.value = DailyModel.bar_fill(day, DailyModel.thresholds(chests))
	_week_bar.value = DailyModel.bar_fill(week, DailyModel.thresholds(weekly))
	var top: int = weekly[-1]["threshold"] if not weekly.is_empty() else 0
	_week_bar_text.text = "%d/%d" % [roundi(week), top] if top > 0 else ""


func _count_up(day: int, week: int) -> void:
	if _count_tween != null:
		_count_tween.kill()
	var from_day := _shown_activity
	var from_week := _shown_weekly
	_count_tween = create_tween()
	_count_tween.tween_method(func(k: float): _set_counts(lerpf(from_day, day, k), lerpf(from_week, week, k)), 0.0, 1.0, COUNT_UP) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_shield.pivot_offset = _shield.size / 2
	var pop := create_tween()
	pop.tween_property(_shield, "scale", Vector2(1.08, 1.08), 0.15).set_delay(COUNT_UP * 0.5)
	pop.tween_property(_shield, "scale", Vector2.ONE, 0.25)


## Once a second: the countdowns; at the day's reset the list reloads (once per reset).
func _tick() -> void:
	var data = PlayerState.daily
	if not data is Dictionary:
		_countdown.get_parent().visible = false
		_week_countdown.text = ""
		return
	var t: int = now.call()
	_countdown.text = DailyModel.day_countdown(data["day_reset"], t)
	_countdown.get_parent().visible = _countdown.text != ""
	_week_countdown.text = DailyModel.week_countdown(data["week_reset"], t)
	if data["day_reset"] > 0 and DailyModel.seconds_left(data["day_reset"], t) == 0 and _reset_asked != data["day_reset"] \
			and is_visible_in_tree():
		_reset_asked = data["day_reset"]
		PlayerState.load_daily()


# ── Claiming ────────────────────────────────────────────────────────────────

func _claim_mission(id: String, badge: Control) -> void:
	if PlayerState.daily_busy != "":
		return
	var from := badge.get_global_rect().get_center() if is_instance_valid(badge) else Vector2.ZERO
	_animate_next = true
	var res: Dictionary = await PlayerState.claim_mission(id)
	if not is_inside_tree():
		return
	if not res.ok:
		_animate_next = false
		Ui.toast(overlay, ErrorText.mission(res))
		return
	var gained := int(res.data.get("activity", 0)) if res.data is Dictionary else 0
	if gained > 0 and from != Vector2.ZERO:
		_fly_points(gained, from)


## "+N" flying from the mission's star to the shield.
func _fly_points(points: int, from: Vector2) -> void:
	var l := LobbyUi.text("+%d" % points, 40, GOLD, true)
	LobbyUi.outline(l, 8)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.top_level = true
	overlay.add_child(l)
	l.size = l.get_combined_minimum_size()
	l.global_position = from - l.size / 2
	var to := _shield.get_global_rect().get_center() - l.size / 2
	var t := l.create_tween()
	t.tween_property(l, "global_position", to, COUNT_UP * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(l, "scale", Vector2(1.3, 1.3), COUNT_UP * 0.7)
	t.tween_property(l, "modulate:a", 0.0, 0.2)
	t.tween_callback(l.queue_free)


func _on_chest(id: String) -> void:
	var c := DailyModel.chest(PlayerState.daily, id)
	if c.is_empty():
		return
	if c["state"] == DailyModel.CLAIMABLE:
		_claim_chest(c)
	else:
		_show_chest(c)


func _claim_chest(c: Dictionary) -> void:
	if PlayerState.daily_busy != "":
		return
	var res: Dictionary = await PlayerState.claim_chest(c["id"])
	if not is_inside_tree():
		return
	if not res.ok:
		Ui.toast(overlay, ErrorText.mission(res))
		return
	var data: Dictionary = res.data if res.data is Dictionary else {}
	var lines := DailyModel.reward_lines(MilestoneModel.parse_rewards(data.get("rewards")))
	if lines.is_empty():
		lines = DailyModel.reward_lines(c["rewards"])
	var m := MilestonePage.show_rewards(overlay, DailyModel.chest_title(c), lines)
	m.title.text = "Nhận được"


## What a chest gives (not claimable now): its rewards and why ("Cần 60 năng động").
func _show_chest(c: Dictionary) -> Modal:
	var data = PlayerState.daily
	var value: int = 0
	if data is Dictionary:
		value = data["weekly_activity"] if c["track"] == "weekly" else data["activity"]
	var m := Modal.new()
	m.open(overlay, DailyModel.chest_title(c), 520)
	m.add_close_x()
	var rows := Ui.vbox(10)
	m.body.add_child(rows)
	for line in DailyModel.reward_lines(c["rewards"]):
		var r := Ui.hbox(14)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_child(MilestonePage.reward_icon_node(line, 48))
		var l := LobbyUi.text(line["text"], 26, Color.WHITE, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.add_child(l)
		rows.add_child(r)
	var hint := m.add_text(DailyModel.chest_hint(c, value), 22)
	hint.add_theme_color_override("font_color", GREEN if c["state"] == DailyModel.CLAIMED else DIM)
	return m
