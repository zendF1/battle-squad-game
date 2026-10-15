extends Control
## Match HUD: turn, timer, wind, weapon/skill/item row, move buttons + energy, aim readout, end turn,
## result panel. In the lobby look (ui/lobby_ui.gd): translucent navy panels, rounded buttons,
## yellow for the armed mode and for my turn. A turn change also shows a short centre banner.
## Layout is containers only, so it adapts to wide phones (stretch aspect "expand").

signal move_pressed(dir: int)
signal move_released
signal end_turn_pressed
signal weapon_pressed
signal skill_pressed
signal item_pressed(item_id: String)
signal leave_pressed

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")

const NAVY := Color(0.06, 0.09, 0.22, 0.78)
const MODE_BG := Color(0.13, 0.2, 0.42, 0.9)
const ENEMY_RED := Color(1.0, 0.42, 0.38)
const LOW_TIME := 5

var _turn: Label
var _turn_panel: PanelContainer
var _timer: Label
var _timer_panel: PanelContainer
var _wind: Label
var _wind_arrow: TextureRect
var _wind_bar: Control
var _aim: Label
var _aim_panel: PanelContainer
var _energy: ProgressBar
var _left: Button
var _right: Button
var _end_turn: Button
var _weapon: Button
var _skill: Button
var _actions: HBoxContainer
var _item_buttons: Array[Button] = [] # reused; one per item left in hand
var _result: Control
var _result_title: Label
var _result_detail: Label
var _banner: PanelContainer
var _banner_label: Label
var _banner_tween: Tween
var _time_left := 0.0
var _timer_running := true
var _wind_dir := 0
var _wind_power := 0.0
var _my_turn := false
var _low := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = LobbyUi.theme()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var rows: VBoxContainer = _ignore(VBoxContainer.new())
	rows.add_theme_constant_override("separation", 14)
	margin.add_child(rows)

	# Top: leave, turn pill, timer badge, wind panel.
	var top: HBoxContainer = _ignore(HBoxContainer.new())
	top.add_theme_constant_override("separation", 16)
	rows.add_child(top)
	var leave := LobbyUi.pill_button("Thoát", 24, 60, "close")
	leave.add_theme_stylebox_override("normal", LobbyUi.box(NAVY, 30, 18, LobbyUi.PANEL_BORDER, 2))
	leave.custom_minimum_size = Vector2(150, 60)
	leave.pressed.connect(leave_pressed.emit)
	top.add_child(leave)
	top.add_child(_expand(_ignore(Control.new())))
	_turn_panel = _ignore(PanelContainer.new())
	_turn_panel.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(_turn_panel)
	_turn = LobbyUi.text("", 30, Color.WHITE, true)
	_turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn.custom_minimum_size = Vector2(280, 0)
	_turn_panel.add_child(_turn)
	_timer_panel = _ignore(PanelContainer.new())
	_timer_panel.custom_minimum_size = Vector2(84, 84)
	top.add_child(_timer_panel)
	_timer = LobbyUi.text("", 40, Color.WHITE, true)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_panel.add_child(_timer)
	top.add_child(_expand(_ignore(Control.new())))
	var wind_panel: PanelContainer = _ignore(LobbyUi.panel(12, 18, NAVY))
	wind_panel.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(wind_panel)
	var wind_col := Ui.vbox(4)
	wind_col.mouse_filter = MOUSE_FILTER_IGNORE
	wind_panel.add_child(wind_col)
	var wind_row := Ui.hbox(8)
	wind_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wind_row.mouse_filter = MOUSE_FILTER_IGNORE
	wind_col.add_child(wind_row)
	wind_row.add_child(LobbyUi.text("Gió", 24, Color.WHITE, true))
	_wind_arrow = LobbyUi.icon("arrow_right", 26)
	wind_row.add_child(_wind_arrow)
	_wind = LobbyUi.text("", 24, Color.WHITE, true)
	wind_row.add_child(_wind)
	_wind_bar = _ignore(Control.new())
	_wind_bar.custom_minimum_size = Vector2(200, 14)
	_wind_bar.draw.connect(_draw_wind_bar)
	wind_col.add_child(_wind_bar)
	_set_turn_style(false)

	rows.add_child(_expand_v(_ignore(Control.new())))

	# Weapon / skill / items: toggle buttons whose pressed look always shows the controller's
	# mode (set_actions), whatever a click did to them.
	_actions = _ignore(HBoxContainer.new())
	_actions.add_theme_constant_override("separation", 14)
	_actions.alignment = BoxContainer.ALIGNMENT_END
	rows.add_child(_actions)
	_weapon = _mode_button("Vũ khí", "weapon")
	_weapon.pressed.connect(weapon_pressed.emit)
	_actions.add_child(_weapon)
	_skill = _mode_button("", "skill")
	_skill.pressed.connect(skill_pressed.emit)
	_skill.visible = false
	_actions.add_child(_skill)

	# Bottom: move buttons and energy, aim readout, end turn.
	var bottom: HBoxContainer = _ignore(HBoxContainer.new())
	bottom.add_theme_constant_override("separation", 16)
	rows.add_child(bottom)
	_left = _hold_button("arrow_left", -1)
	bottom.add_child(_left)
	_right = _hold_button("arrow_right", 1)
	bottom.add_child(_right)
	var energy_panel: PanelContainer = _ignore(LobbyUi.panel(12, 18, NAVY))
	energy_panel.size_flags_vertical = SIZE_SHRINK_CENTER
	bottom.add_child(energy_panel)
	var energy_row := Ui.hbox(10)
	energy_row.mouse_filter = MOUSE_FILTER_IGNORE
	energy_panel.add_child(energy_row)
	energy_row.add_child(LobbyUi.text("Thể lực", 20, Color(1, 1, 1, 0.8), true))
	_energy = ProgressBar.new()
	_energy.max_value = 100
	_energy.show_percentage = false
	_energy.custom_minimum_size = Vector2(220, 20)
	_energy.size_flags_vertical = SIZE_SHRINK_CENTER
	_energy.mouse_filter = MOUSE_FILTER_IGNORE
	_energy.add_theme_stylebox_override("background", LobbyUi.box(Color(0.02, 0.03, 0.1, 0.85), 10, 0, Color(1, 1, 1, 0.15), 2))
	_energy.add_theme_stylebox_override("fill", LobbyUi.box(Color(0.35, 0.85, 0.45), 10, 0))
	energy_row.add_child(_energy)
	bottom.add_child(_expand(_ignore(Control.new())))
	_aim_panel = _ignore(LobbyUi.panel(12, 18, NAVY))
	_aim_panel.size_flags_vertical = SIZE_SHRINK_CENTER
	bottom.add_child(_aim_panel)
	_aim = LobbyUi.text("", 28, Color.WHITE, true)
	_aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_aim_panel.add_child(_aim)
	_end_turn = Button.new()
	_end_turn.text = "Hết lượt"
	LobbyUi.set_icon(_end_turn, "end_turn", 34)
	_end_turn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_end_turn.add_theme_constant_override("h_separation", 10)
	_end_turn.add_theme_font_size_override("font_size", 30)
	_end_turn.add_theme_font_override("font", LobbyUi.bold())
	_end_turn.custom_minimum_size = Vector2(220, 110)
	LobbyUi.texture_button(_end_turn, "button_orange", 10)
	_end_turn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	_end_turn.pressed.connect(end_turn_pressed.emit)
	bottom.add_child(_end_turn)

	_build_banner()
	_build_result_panel()


func _process(delta: float) -> void:
	if _timer_running:
		_time_left = maxf(0.0, _time_left - delta)
	_timer.text = "%d" % ceili(_time_left)
	var low := _timer_running and ceili(_time_left) <= LOW_TIME
	if low != _low:
		_low = low
		_timer.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if low else Color.WHITE)
	_aim_panel.visible = _aim.text != ""


func set_turn(mine: bool, player_name: String) -> void:
	var text := "Lượt của bạn" if mine else "Lượt của %s" % player_name
	var changed := text != _turn.text
	_turn.text = text
	_my_turn = mine
	_set_turn_style(mine)
	if changed:
		_announce(text, mine)


## Sets the turn clock from a server value and resumes the local countdown.
func set_time(seconds: int) -> void:
	_time_left = seconds
	_timer_running = true


## Freezes the countdown. The server stops TurnTimerTick while a shot resolves, and the next
## set_time() (TurnTimerTick or TurnStarted) resumes it.
func pause_timer() -> void:
	_timer_running = false


## No wind (power 0, e.g. while a wind_stopper lasts) reads "Gió: tắt".
func set_wind(direction: int, power: float) -> void:
	_wind_dir = direction
	_wind_power = power
	_wind_bar.queue_redraw()
	_wind_arrow.visible = power > 0.0 and direction != 0
	if power <= 0.0:
		_wind.text = "tắt"
		return
	_wind_arrow.texture = Art.icon("arrow_right" if direction > 0 else "arrow_left")
	_wind.text = "%.1f" % power


func set_energy(value: int) -> void:
	_energy.value = value


func set_aim(angle: float, power: float) -> void:
	_aim.text = "%d°  lực %d" % [roundi(angle), roundi(power)]


func set_column(x: float) -> void:
	_aim.text = "Không kích x=%d" % roundi(x)


func set_controls_enabled(enabled: bool) -> void:
	_left.disabled = not enabled
	_right.disabled = not enabled
	_end_turn.disabled = not enabled
	if not enabled:
		_aim.text = ""


## The weapon/skill/item row. skill_label empty hides the skill button (unknown character). The
## label carries the energy, so it is shown even while every button is disabled. armed is
## "weapon", "skill" or the armed item id. items: [{"id", "label", "enabled"}], the items left.
func set_actions(skill_label: String, weapon_enabled: bool, skill_enabled: bool, armed: String, items: Array = []) -> void:
	_skill.visible = skill_label != ""
	_skill.text = skill_label
	_weapon.disabled = not weapon_enabled
	_skill.disabled = not skill_enabled
	_weapon.set_pressed_no_signal(armed == "weapon")
	_skill.set_pressed_no_signal(armed == "skill")
	while _item_buttons.size() < items.size():
		var b := _mode_button("", "unknown")
		b.pressed.connect(func() -> void: item_pressed.emit(str(b.get_meta("item_id", ""))))
		_actions.add_child(b)
		_item_buttons.append(b)
	for i in _item_buttons.size():
		var b := _item_buttons[i]
		b.visible = i < items.size()
		if not b.visible:
			continue
		var it: Dictionary = items[i]
		if b.get_meta("item_id", "") != it["id"]:
			b.icon = Art.item_icon(str(it["id"]))
		b.set_meta("item_id", it["id"])
		b.text = str(it["label"])
		b.disabled = not bool(it["enabled"])
		b.set_pressed_no_signal(armed == it["id"])


func show_result(title: String, detail: String) -> void:
	_result_title.text = title
	_result_detail.text = detail
	_result.visible = true


func _hold_button(icon_name: String, dir: int) -> Button:
	var b := LobbyUi.round_button(icon_name, 110, Color(0.2, 0.34, 0.66, 0.9), 0.42)
	b.add_theme_stylebox_override("disabled", LobbyUi.box(Color(0.12, 0.15, 0.3, 0.55), 55, 0, Color(1, 1, 1, 0.25), 3))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.button_down.connect(move_pressed.emit.bind(dir))
	b.button_up.connect(move_released.emit)
	return b


## A toggle with an icon: navy normally, gold with dark text while it is the armed mode.
func _mode_button(text: String, icon_name: String) -> Button:
	var b := Button.new()
	b.text = text
	LobbyUi.set_icon(b, icon_name, 38)
	b.add_theme_constant_override("h_separation", 8)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_font_override("font", LobbyUi.bold())
	b.custom_minimum_size = Vector2(200, 72)
	b.toggle_mode = true
	LobbyUi.style_button(b, MODE_BG, 18, 10, Color(1, 1, 1, 0.18), 2)
	var gold := LobbyUi.box(LobbyUi.GOLD, 18, 10, LobbyUi.GOLD_DARK, 3)
	gold.border_width_bottom = 6
	b.add_theme_stylebox_override("pressed", gold)
	var gold_hover: StyleBoxFlat = gold.duplicate()
	gold_hover.bg_color = LobbyUi.GOLD.lightened(0.12)
	b.add_theme_stylebox_override("hover_pressed", gold_hover)
	b.add_theme_stylebox_override("disabled", LobbyUi.box(Color(0.1, 0.13, 0.26, 0.55), 18, 10, Color(1, 1, 1, 0.08), 2))
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, LobbyUi.TEXT_DARK)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	return b


func _set_turn_style(mine: bool) -> void:
	if mine:
		var box := LobbyUi.box(LobbyUi.GOLD, 26, 12, LobbyUi.GOLD_DARK, 3)
		box.border_width_bottom = 6
		box.content_margin_left = 26
		box.content_margin_right = 26
		_turn_panel.add_theme_stylebox_override("panel", box)
		_turn.add_theme_color_override("font_color", LobbyUi.TEXT_DARK)
		_turn.add_theme_constant_override("outline_size", 0)
	else:
		var box := LobbyUi.box(NAVY, 26, 12, Color(ENEMY_RED, 0.7), 3)
		box.content_margin_left = 26
		box.content_margin_right = 26
		_turn_panel.add_theme_stylebox_override("panel", box)
		_turn.add_theme_color_override("font_color", Color.WHITE)
		_turn.add_theme_constant_override("outline_size", 5)
	var badge := LobbyUi.box(NAVY, 42, 0, LobbyUi.GOLD if mine else Color(1, 1, 1, 0.3), 4)
	_timer_panel.add_theme_stylebox_override("panel", badge)


## Wind strength (power up to about 5) as a bar growing from the centre the way it blows.
func _draw_wind_bar() -> void:
	var s := _wind_bar.size
	var back := Rect2(Vector2.ZERO, s)
	_wind_bar.draw_style_box(LobbyUi.box(Color(0.02, 0.03, 0.1, 0.8), 7, 0), back)
	var mid := s.x / 2
	_wind_bar.draw_rect(Rect2(mid - 1, 1, 2, s.y - 2), Color(1, 1, 1, 0.5))
	if _wind_power <= 0.0 or _wind_dir == 0:
		return
	var bar_len := clampf(_wind_power / 5.0, 0.05, 1.0) * (mid - 3)
	var x := mid if _wind_dir > 0 else mid - bar_len
	_wind_bar.draw_rect(Rect2(x, 3, bar_len, s.y - 6), Color(0.45, 0.85, 1.0))


func _build_banner() -> void:
	var center := CenterContainer.new() # upper half: the players stand lower
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.anchor_bottom = 0.55
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	_banner = _ignore(PanelContainer.new())
	_banner.modulate.a = 0.0
	center.add_child(_banner)
	_banner_label = LobbyUi.text("", 56, Color.WHITE, true)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_label)


## The centre banner: pops in, holds, fades out.
func _announce(text: String, mine: bool) -> void:
	if _banner == null:
		return
	_banner_label.text = text
	var box := LobbyUi.box(LobbyUi.GOLD if mine else Color(0.05, 0.07, 0.18, 0.85), 30, 22,
		LobbyUi.GOLD_DARK if mine else Color(ENEMY_RED, 0.8), 4)
	box.content_margin_left = 60
	box.content_margin_right = 60
	if mine:
		box.border_width_bottom = 8
	_banner.add_theme_stylebox_override("panel", box)
	_banner_label.add_theme_color_override("font_color", LobbyUi.TEXT_DARK if mine else Color.WHITE)
	_banner_label.add_theme_constant_override("outline_size", 0 if mine else 9)
	if _banner_tween:
		_banner_tween.kill()
	_banner.pivot_offset = _banner.size / 2
	_banner.scale = Vector2(0.7, 0.7)
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(0.9)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.35)


func _build_result_panel() -> void:
	_result = _ignore(Control.new())
	_result.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_result.visible = false
	add_child(_result)
	var dim: ColorRect = _ignore(ColorRect.new())
	dim.color = Color(0.02, 0.03, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_result.add_child(dim)
	var center: CenterContainer = _ignore(CenterContainer.new())
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_result.add_child(center)
	var panel := LobbyUi.panel(40, 28, Color(0.06, 0.09, 0.22, 0.92))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	panel.add_child(col)
	_result_title = LobbyUi.text("", 60, LobbyUi.GOLD, true)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_result_title)
	_result_detail = LobbyUi.text("", 28)
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_result_detail)
	var back := LobbyUi.start_button("Về sảnh")
	back.custom_minimum_size = Vector2(360, 90)
	back.pressed.connect(leave_pressed.emit)
	col.add_child(back)


static func _ignore(c):
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


static func _expand(c):
	c.size_flags_horizontal = SIZE_EXPAND_FILL
	return c


static func _expand_v(c):
	c.size_flags_vertical = SIZE_EXPAND_FILL
	return c
