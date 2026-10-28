extends VBoxContainer
## One place of the leaderboard's podium (leaderboard_page.gd): the player's character standing on
## the step as on the lobby stage (player_figure.gd: their full-body picture, their weapon's back
## aura, their gun resting beside the feet; the look the server sends, LeaderboardModel.look()),
## then the step in the place's colour (gold, silver, bronze; my place ringed in light blue) with
## the name, the board's value as a picture and a number (level: "Lv.37"; rank: the grade's
## insignia and the points; power: the power glyph and the number) and the place's number big.
## 1st stands taller on the higher, wider step; 2nd and 3rd are the same (the podium is mirrored
## round the 1st). An empty place ({}) is a dim step with "—". A tap on a filled place emits
## `tapped` (the page opens the player's showcase).

signal tapped(entry: Dictionary)

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const PowerTag := preload("res://ui/power_tag.gd")
const PlayerFigure := preload("res://screens/home/player_figure.gd")
const LeaderboardModel := preload("res://screens/home/leaderboard_model.gd")

## The width of a place, the figure's size against the lobby stage's, the room it stands in and
## the step's height, per place (1st, 2nd / 3rd).
const WIDTH := {1: 250, 2: 216, 3: 216}
const FIGURE := {1: 0.92, 2: 0.76, 3: 0.76}
const FIGURE_H := {1: 390, 2: 322, 3: 322}
const STEP_H := {1: 196, 2: 156, 3: 156}
## Gold, silver, bronze: [light, main, dark].
const COLORS := {
	1: [Color(1.0, 0.92, 0.5), Color(1.0, 0.74, 0.18), Color(0.7, 0.44, 0.06)],
	2: [Color(0.95, 0.97, 1.0), Color(0.72, 0.78, 0.88), Color(0.4, 0.45, 0.56)],
	3: [Color(1.0, 0.8, 0.6), Color(0.85, 0.52, 0.28), Color(0.5, 0.27, 0.12)],
}
const ME := Color(0.4, 0.85, 1.0)
const TAP_SLOP := 14.0 # px a press may move and still be a tap

var place := 1
var entry := {}
var _figure: Control
var _press_at := Vector2.INF


## The podium place `p` (1, 2, 3) showing row `e` of board `type` ({} empty); `me` highlights it.
static func make(p: int, e: Dictionary, type: String, me: bool):
	var c = load("res://screens/home/leaderboard_place.gd").new()
	c.place = p
	c.name = "Place%d" % p
	c.entry = e
	c._build(e, type, me)
	return c


func _build(e: Dictionary, type: String, me: bool) -> void:
	add_theme_constant_override("separation", 0)
	alignment = ALIGNMENT_END
	custom_minimum_size.x = WIDTH[place]
	mouse_filter = MOUSE_FILTER_IGNORE if e.is_empty() else MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_ARROW if e.is_empty() else CURSOR_POINTING_HAND
	_figure = PlayerFigure.make(LeaderboardModel.look(e, PlayerState.catalog), FIGURE[place])
	_figure.name = "Figure"
	_figure.custom_minimum_size = Vector2(WIDTH[place], FIGURE_H[place])
	_figure.foot_margin = 4.0
	_figure.gun_scale = 0.8
	add_child(_figure)
	add_child(_step(e, type, me))
	if e.is_empty():
		modulate = Color(1, 1, 1, 0.5)


## The figure (tests).
func figure() -> Control:
	return _figure


## The step: the place's colour, the name, the value and the place's number.
func _step(e: Dictionary, type: String, me: bool) -> Control:
	var c: Array = COLORS[place]
	var step := PanelContainer.new()
	step.name = "Step"
	step.custom_minimum_size = Vector2(WIDTH[place], STEP_H[place])
	step.mouse_filter = MOUSE_FILTER_IGNORE
	var box := LobbyUi.box(Color(c[2].lerp(c[1], 0.35), 0.95), 10, 0)
	box.border_width_top = 5
	box.border_color = c[0]
	if me:
		box.set_border_width_all(4)
		box.border_width_top = 6
		box.border_color = ME
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = 6
	box.content_margin_top = 10
	box.content_margin_bottom = 4
	box.content_margin_left = 8
	box.content_margin_right = 8
	step.add_theme_stylebox_override("panel", box)
	var col := Ui.vbox(2)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	step.add_child(col)
	if e.is_empty():
		col.add_child(_centred(LobbyUi.text("—", 30, Color(1, 1, 1, 0.8), true)))
	else:
		var n := _centred(LobbyUi.text(str(e.get("name", "")), 23 if place == 1 else 21, ME if me else Color.WHITE, true))
		n.name = "Name"
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.custom_minimum_size.x = WIDTH[place] - 20
		col.add_child(n)
		col.add_child(_value(e, type))
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	var num := _centred(LobbyUi.text(str(place), 58 if place == 1 else 48, Color.WHITE, true))
	num.name = "Number"
	num.add_theme_color_override("font_outline_color", c[2])
	num.add_theme_constant_override("outline_size", 10)
	col.add_child(num)
	return step


## The board's value: a picture and a number.
func _value(e: Dictionary, type: String) -> Control:
	var row := Ui.hbox(6)
	row.name = "Value"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var big := 30 if place == 1 else 26
	match type:
		LeaderboardModel.RANK:
			var ins := GradeBadge.make(str(e["grade"]), int(e["division"]), big + 12)
			ins.size_flags_vertical = SIZE_SHRINK_CENTER
			ins.tooltip_text = LeaderboardModel.value_text(type, e)
			row.add_child(ins)
			var pts := LobbyUi.text(LeaderboardModel.power_text(int(e["points"])), big - 2, Color.WHITE, true)
			pts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(pts)
		LeaderboardModel.POWER:
			var tag = PowerTag.make(big + 4, big - 2)
			tag.keep_unknown = true
			tag.set_power(int(e["power"]))
			row.add_child(tag)
		_:
			row.add_child(LobbyUi.text(LeaderboardModel.value_text(type, e), big, LobbyUi.GOLD, true))
	return row


func _gui_input(event: InputEvent) -> void:
	if entry.is_empty() or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_press_at = event.position
	elif _press_at != Vector2.INF:
		if event.position.distance_to(_press_at) <= TAP_SLOP:
			tapped.emit(entry)
		_press_at = Vector2.INF


static func _centred(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l
