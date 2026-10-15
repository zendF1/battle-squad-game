extends Control
## Match HUD: turn, timer, wind, weapon/skill row, move buttons + energy, aim readout, end turn,
## result panel.
## Layout is containers only, so it adapts to wide phones (stretch aspect "expand").

signal move_pressed(dir: int)
signal move_released
signal end_turn_pressed
signal weapon_pressed
signal skill_pressed
signal leave_pressed

const Ui := preload("res://ui/ui.gd")

var _turn: Label
var _timer: Label
var _wind: Label
var _aim: Label
var _energy: ProgressBar
var _left: Button
var _right: Button
var _end_turn: Button
var _weapon: Button
var _skill: Button
var _result: Control
var _result_title: Label
var _result_detail: Label
var _time_left := 0.0
var _timer_running := true


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var rows: VBoxContainer = _ignore(VBoxContainer.new())
	margin.add_child(rows)

	var top: HBoxContainer = _ignore(HBoxContainer.new())
	rows.add_child(top)
	var leave := Ui.button("Thoát", 24)
	leave.custom_minimum_size = Vector2(120, 60)
	leave.pressed.connect(leave_pressed.emit)
	top.add_child(leave)
	_turn = _expand(Ui.label("", 30))
	top.add_child(_turn)
	_timer = Ui.label("", 40)
	top.add_child(_timer)
	_wind = _expand(Ui.label("", 30))
	top.add_child(_wind)

	rows.add_child(_expand_v(_ignore(Control.new())))

	# Weapon / skill: toggle buttons whose pressed look always shows the controller's mode
	# (set_actions), whatever a click did to them.
	var actions: HBoxContainer = _ignore(HBoxContainer.new())
	actions.add_theme_constant_override("separation", 16)
	actions.alignment = BoxContainer.ALIGNMENT_END
	rows.add_child(actions)
	_weapon = _mode_button("Vũ khí", weapon_pressed)
	actions.add_child(_weapon)
	_skill = _mode_button("", skill_pressed)
	_skill.visible = false
	actions.add_child(_skill)

	var bottom: HBoxContainer = _ignore(HBoxContainer.new())
	bottom.add_theme_constant_override("separation", 16)
	rows.add_child(bottom)
	_left = _hold_button("◀", -1)
	bottom.add_child(_left)
	_right = _hold_button("▶", 1)
	bottom.add_child(_right)
	_energy = ProgressBar.new()
	_energy.max_value = 100
	_energy.show_percentage = false
	_energy.custom_minimum_size = Vector2(240, 24)
	_energy.size_flags_vertical = SIZE_SHRINK_CENTER
	_energy.mouse_filter = MOUSE_FILTER_IGNORE
	bottom.add_child(_energy)
	_aim = _expand(Ui.label("", 30))
	_aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(_aim)
	_end_turn = Ui.button("Hết lượt", 28)
	_end_turn.custom_minimum_size = Vector2(200, 110)
	_end_turn.pressed.connect(end_turn_pressed.emit)
	bottom.add_child(_end_turn)

	_build_result_panel()


func _process(delta: float) -> void:
	if _timer_running:
		_time_left = maxf(0.0, _time_left - delta)
	_timer.text = "%d" % ceili(_time_left)


func set_turn(mine: bool, player_name: String) -> void:
	_turn.text = "Lượt của bạn" if mine else "Lượt của %s" % player_name


## Sets the turn clock from a server value and resumes the local countdown.
func set_time(seconds: int) -> void:
	_time_left = seconds
	_timer_running = true


## Freezes the countdown. The server stops TurnTimerTick while a shot resolves, and the next
## set_time() (TurnTimerTick or TurnStarted) resumes it.
func pause_timer() -> void:
	_timer_running = false


func set_wind(direction: int, power: float) -> void:
	var arrow := "→" if direction > 0 else ("←" if direction < 0 else "·")
	_wind.text = "Gió %s %.1f" % [arrow, power]


func set_energy(value: int) -> void:
	_energy.value = value


func set_aim(angle: float, power: float) -> void:
	_aim.text = "%d°  lực %d" % [roundi(angle), roundi(power)]


func set_controls_enabled(enabled: bool) -> void:
	_left.disabled = not enabled
	_right.disabled = not enabled
	_end_turn.disabled = not enabled
	if not enabled:
		_aim.text = ""


## The weapon/skill row. skill_label empty hides the skill button (unknown character). The
## label carries the energy, so it is shown even while both buttons are disabled.
func set_actions(skill_label: String, weapon_enabled: bool, skill_enabled: bool, armed: bool) -> void:
	_skill.visible = skill_label != ""
	_skill.text = skill_label
	_weapon.disabled = not weapon_enabled
	_skill.disabled = not skill_enabled
	_weapon.set_pressed_no_signal(not armed)
	_skill.set_pressed_no_signal(armed)


func show_result(title: String, detail: String) -> void:
	_result_title.text = title
	_result_detail.text = detail
	_result.visible = true


func _hold_button(text: String, dir: int) -> Button:
	var b := Ui.button(text, 40)
	b.custom_minimum_size = Vector2(120, 110)
	b.button_down.connect(move_pressed.emit.bind(dir))
	b.button_up.connect(move_released.emit)
	return b


func _mode_button(text: String, sig: Signal) -> Button:
	var b := Ui.button(text, 26)
	b.custom_minimum_size = Vector2(200, 72)
	b.toggle_mode = true
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(sig.emit)
	return b


func _build_result_panel() -> void:
	_result = CenterContainer.new()
	_result.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_result.visible = false
	add_child(_result)
	var panel := PanelContainer.new()
	_result.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	panel.add_child(col)
	_result_title = Ui.label("", 56)
	col.add_child(_result_title)
	_result_detail = Ui.label("", 28)
	col.add_child(_result_detail)
	var back := Ui.button("Về sảnh", 30)
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
