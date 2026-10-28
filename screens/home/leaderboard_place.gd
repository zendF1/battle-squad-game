extends VBoxContainer
## One place of the leaderboard's podium (leaderboard_page.gd): the player's card in their badge's
## frame (grade_frame.gd, rankBadge; the plain frame without one) with the head of their strongest
## character's lobby picture (head_icon.gd lobby, Art.lobby_head()) ringed in the badge's frame
## colour (the place's colour without a badge), the name, and the board's value big
## (LeaderboardModel.value_text: "Lv.37"; the grade's insignia, "Đại tá 1" and the points; the power
## glyph and number), then the step with the place's number. 1st is the bigger card on the higher
## step; 2nd and 3rd are the same size (the podium is mirrored round the 1st). With real frame art
## (GradeFrame.has_art) the card's body shrinks into the art's window (GradeFrame.fit) like the
## matchmaking cards. An empty place ({}) is a dim card with "—".

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const GradeFrame := preload("res://screens/ranked/grade_frame.gd")
const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")
const PowerTag := preload("res://ui/power_tag.gd")
const LeaderboardModel := preload("res://screens/home/leaderboard_model.gd")

## The card and the step per place (1st, 2nd / 3rd).
const CARD := {1: Vector2(250, 384), 2: Vector2(216, 346), 3: Vector2(216, 346)}
const STEP_H := {1: 128, 2: 84, 3: 84}
const HEAD := {1: 150, 2: 128, 3: 128}
## Gold, silver, bronze: [light, main, dark].
const COLORS := {
	1: [Color(1.0, 0.92, 0.5), Color(1.0, 0.74, 0.18), Color(0.7, 0.44, 0.06)],
	2: [Color(0.95, 0.97, 1.0), Color(0.72, 0.78, 0.88), Color(0.4, 0.45, 0.56)],
	3: [Color(1.0, 0.8, 0.6), Color(0.85, 0.52, 0.28), Color(0.5, 0.27, 0.12)],
}
const BG := Color(0.06, 0.09, 0.22, 0.92)
const ME := Color(0.4, 0.85, 1.0)
const RADIUS := 18.0
const FRAME_OUT := 6.0

var place := 1
var _card: Control
var _body: Control
var _frame: GradeFrame
var _content: VBoxContainer


## The podium place `p` (1, 2, 3) showing row `e` of board `type` ({} empty); `me` highlights it.
static func make(p: int, e: Dictionary, type: String, me: bool):
	var c = load("res://screens/home/leaderboard_place.gd").new()
	c.place = p
	c.name = "Place%d" % p
	c._build(e, type, me)
	return c


func _build(e: Dictionary, type: String, me: bool) -> void:
	add_theme_constant_override("separation", 0)
	alignment = ALIGNMENT_END
	mouse_filter = MOUSE_FILTER_IGNORE
	var size_px: Vector2 = CARD[place]
	custom_minimum_size.x = size_px.x
	_card = Control.new()
	_card.name = "Card"
	_card.custom_minimum_size = size_px
	_card.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_card)
	_body = Control.new()
	_body.size = size_px
	_body.mouse_filter = MOUSE_FILTER_IGNORE
	_card.add_child(_body)
	var bg := Panel.new()
	bg.size = size_px
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	var c: Array = COLORS[place]
	bg.add_theme_stylebox_override("panel", LobbyUi.box(BG, int(RADIUS), 0, ME if me else Color(c[1], 0.55), 3 if me else 2))
	_body.add_child(bg)
	_content = Ui.vbox(4)
	_content.name = "Content"
	_content.alignment = ALIGNMENT_CENTER
	_content.position = Vector2(10, 30)
	_content.size = size_px - Vector2(20, 40)
	_content.mouse_filter = MOUSE_FILTER_IGNORE
	_body.add_child(_content)
	var badge := str(e.get("badge", ""))
	_frame = GradeFrame.make(badge, RADIUS + FRAME_OUT, 44.0, true)
	_frame.name = "Frame"
	_body.add_child(_frame)
	_fit(GradeFrame.has_art(badge))
	if e.is_empty():
		modulate = Color(1, 1, 1, 0.55)
		var head = HeadIcon.make("", "?", HEAD[place])
		head.ring = Color(c[1], 0.6)
		head.size_flags_horizontal = SIZE_SHRINK_CENTER
		_content.add_child(head)
		_content.add_child(_centred(LobbyUi.text("—", 30, Color(1, 1, 1, 0.7), true)))
	else:
		var head = HeadIcon.make(str(e.get("power_character", "")), str(e.get("name", "")), HEAD[place])
		head.name = "Head"
		head.lobby = true
		head.ring_width = 5.0
		head.ring = GradeBadge.colors(badge)[1] if badge != "" else c[1]
		head.size_flags_horizontal = SIZE_SHRINK_CENTER
		_content.add_child(head)
		var n := _centred(LobbyUi.text(str(e["name"]), 24 if place == 1 else 22, ME if me else Color.WHITE, true))
		n.name = "Name"
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.custom_minimum_size.x = size_px.x - 24
		_content.add_child(n)
		_content.add_child(_value(e, type))
	add_child(_step(c))


## The board's value, big.
func _value(e: Dictionary, type: String) -> Control:
	var col := Ui.vbox(0)
	col.name = "Value"
	col.alignment = ALIGNMENT_CENTER
	col.mouse_filter = MOUSE_FILTER_IGNORE
	var big := 34 if place == 1 else 30
	match type:
		LeaderboardModel.RANK:
			var ins := GradeBadge.make(str(e["grade"]), int(e["division"]), 54 if place == 1 else 48)
			ins.size_flags_horizontal = SIZE_SHRINK_CENTER
			col.add_child(ins)
			col.add_child(_centred(LobbyUi.text(LeaderboardModel.value_text(type, e), 24 if place == 1 else 22,
				GradeBadge.text_color(str(e["grade"])), true)))
			col.add_child(_centred(LobbyUi.text(LeaderboardModel.sub_text(type, e), 19, Color(0.8, 0.88, 1.0))))
		LeaderboardModel.POWER:
			var tag = PowerTag.make(big, big - 4)
			tag.keep_unknown = true
			tag.set_power(int(e["power"]))
			col.add_child(tag)
		_:
			col.add_child(_centred(LobbyUi.text(LeaderboardModel.value_text(type, e), big, LobbyUi.GOLD, true)))
	return col


## The step: the place's colour, its number big.
func _step(c: Array) -> Control:
	var step := PanelContainer.new()
	step.name = "Step"
	step.custom_minimum_size = Vector2(CARD[place].x, STEP_H[place])
	step.mouse_filter = MOUSE_FILTER_IGNORE
	var box := LobbyUi.box(Color(c[1], 0.92), 0, 0, Color(c[0], 0.9), 0)
	box.corner_radius_bottom_left = 10
	box.corner_radius_bottom_right = 10
	box.border_width_top = 4
	box.border_color = c[0]
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = 6
	step.add_theme_stylebox_override("panel", box)
	var n := LobbyUi.text(str(place), 58 if place == 1 else 48, Color.WHITE, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.add_theme_color_override("font_outline_color", c[2])
	n.add_theme_constant_override("outline_size", 10)
	step.add_child(n)
	return step


## The body at full size with the code frame round it, or (real art) shrunk into the art's window.
func _fit(art: bool) -> void:
	var size_px: Vector2 = CARD[place]
	var fc := GradeFrame.layout()
	if art and not fc.is_empty():
		var f := GradeFrame.fit(fc, size_px, size_px)
		_body.scale = Vector2.ONE * float(f["s"])
		_body.position = Rect2(f["card"]).position
		_frame.window_inset = 0.0
		_frame.position = Vector2.ZERO
		_frame.size = size_px
	else:
		_frame.window_inset = FRAME_OUT
		_frame.position = -Vector2.ONE * FRAME_OUT
		_frame.size = size_px + Vector2.ONE * FRAME_OUT * 2.0


static func _centred(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l
