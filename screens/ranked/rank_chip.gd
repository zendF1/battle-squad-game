extends Button
## The lobby's rank chip beside the player block: the grade's insignia, "Binh nhì 2" in its
## group's colour and the division's points "45/100" ("4.230 điểm" at the ladder top)
## (PlayerState.my_rank(); "Xếp hạng" / "Đang tải..." until it loads). A tap opens the rank ladder
## (popup(), rank_ladder.gd): every grade, the points that reach it, its season reward and where
## the player stands.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const RankLadder := preload("res://screens/ranked/rank_ladder.gd")

## Where the ladder opens (the screen root).
var host: Control

var _badge: GradeBadge
var _tier: Label
var _points: Label


func _ready() -> void:
	LobbyUi.style_button(self, Color(0.04, 0.06, 0.16, 0.62), 22, 6, Color(1, 1, 1, 0.12), 2)
	custom_minimum_size = Vector2(0, 80)
	var row := Ui.hbox(8)
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -16
	row.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(row)
	_badge = GradeBadge.make("", 0, 70)
	_badge.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(_badge)
	var col := Ui.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(col)
	_tier = LobbyUi.text("", 24, Color.WHITE, true)
	_tier.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(_tier)
	_points = LobbyUi.text("", 19, Color(0.8, 0.88, 1.0))
	_points.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(_points)
	pressed.connect(popup)
	PlayerState.rank_changed.connect(render)
	render()


func render() -> void:
	var data := PlayerState.my_rank()
	if data.is_empty():
		_badge.grade = ""
		_tier.text = "Xếp hạng"
		_tier.add_theme_color_override("font_color", Color.WHITE)
		_points.text = "Đang tải..."
	else:
		var r := RankModel.from_me(data)
		_badge.grade = r["grade"]
		_tier.text = RankModel.label(r["grade"], r["division"])
		_tier.add_theme_color_override("font_color", GradeBadge.text_color(r["grade"]))
		var rank: Array = [r["grade"], r["division"]]
		_points.text = RankModel.points_text(r["points"]) if RankModel.at_top(rank) \
			else "%s điểm" % RankModel.progress_text(r["points"], rank)
	# the row's width follows the texts
	custom_minimum_size.x = 70 + 8 + maxf(_tier.get_minimum_size().x, _points.get_minimum_size().x) + 32


## The rank ladder (rank_ladder.gd) over the host; it loads the rank again.
func popup() -> Control:
	return RankLadder.open(host if host != null else get_tree().current_scene)
