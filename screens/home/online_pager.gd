extends HBoxContainer
## The pages of the online list (the invite popups: screens/home/invite_popup.gd,
## screens/guild/guild_invite_popup.gd): ◀, the page number, ▶, the two arrows the same size and
## gap each side so the number is dead centre. ◀ is on while the page is past the first, ▶ while
## the server says more follow (PartyModel.pager()); with one page only, the row keeps its place
## but shows nothing. A press emits `step` (-1 / +1).

signal step(dir: int)

const LobbyUi := preload("res://ui/lobby_ui.gd")

const ARROW := 56
const GAP := 18
const NUMBER_W := 88
const OFF_ALPHA := 0.35

var prev: Button
var next: Button
var number: Label


func _init() -> void:
	name = "Pager"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", GAP)
	prev = _arrow(-1)
	add_child(prev)
	var pill := PanelContainer.new()
	pill.name = "Page"
	pill.custom_minimum_size = Vector2(NUMBER_W, ARROW)
	pill.add_theme_stylebox_override("panel", LobbyUi.box(Color(1, 1, 1, 0.08), ARROW / 2, 0, Color(1, 1, 1, 0.18), 2))
	pill.size_flags_vertical = SIZE_SHRINK_CENTER
	number = LobbyUi.text("1", 28, LobbyUi.GOLD, true)
	number.name = "Number"
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(number)
	add_child(pill)
	next = _arrow(1)
	add_child(next)
	show_state({"prev": false, "next": false, "shown": false}, 1)


func _arrow(dir: int) -> Button:
	var b := LobbyUi.round_button("arrow_left" if dir < 0 else "arrow_right", ARROW, LobbyUi.ICON_COLORS["blue"], 0.5)
	b.name = "Prev" if dir < 0 else "Next"
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(func() -> void: step.emit(dir))
	return b


## state: PartyModel.pager(); page: the page shown.
func show_state(state: Dictionary, page: int) -> void:
	modulate.a = 1.0 if state.get("shown", false) else 0.0
	number.text = str(page)
	_set_on(prev, state.get("prev", false))
	_set_on(next, state.get("next", false))


static func _set_on(b: Button, on: bool) -> void:
	b.disabled = not on
	b.modulate.a = 1.0 if on else OFF_ALPHA
	b.mouse_default_cursor_shape = CURSOR_POINTING_HAND if on else CURSOR_ARROW
