extends Button
## The lobby's rank chip beside the player block: the grade's insignia, "Binh nhì 2" in its
## group's colour and the division's points "45/100" ("4.230 điểm" at the ladder top)
## (PlayerState.my_rank(); "Xếp hạng" / "Đang tải..." until it loads). A tap opens the rank popup
## (popup()): the insignia big, the grade, the division's bar and points, "Dự kiến: Thiếu tướng"
## for a general candidate, "Hạng #N" in the season, wins and losses, the season's name and end
## date, and what the grade earns at season end (GET /gamedata seasonRewards).

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Modal := preload("res://ui/modal.gd")
const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const SeasonRewardModel := preload("res://screens/ranked/season_reward_model.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")

## Where the popup opens (the screen root).
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


## The rank popup (also loads the rank again).
func popup() -> Modal:
	PlayerState.load_rank()
	return open_popup(host if host != null else get_tree().current_scene, PlayerState.my_rank())


static func open_popup(on: Control, data: Dictionary) -> Modal:
	var r := RankModel.from_me(data)
	var m := Modal.new()
	m.open(on, "Xếp hạng", 680)
	m.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := Ui.hbox(28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.body.add_child(row)
	var badge := GradeBadge.make(r["grade"] if not data.is_empty() else "", r["division"], 150)
	row.add_child(badge)
	var col := Ui.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	if data.is_empty():
		col.add_child(LobbyUi.text("Chưa tải được hạng", 30, Color.WHITE, true))
		col.add_child(LobbyUi.text("Thử lại sau giây lát", 22, Ui.TEXT_DIM))
	else:
		var rank: Array = [r["grade"], r["division"]]
		col.add_child(LobbyUi.text(RankModel.label(r["grade"], r["division"]), 40, GradeBadge.text_color(r["grade"]), true))
		if RankModel.at_top(rank):
			col.add_child(LobbyUi.text(RankModel.points_text(r["points"]), 28, Color.WHITE, true))
		else:
			var bar_row := Ui.hbox(10)
			col.add_child(bar_row)
			var bar := Ui.bar(RankModel.progress(r["points"], rank), 14)
			bar.custom_minimum_size = Vector2(200, 14)
			bar.size_flags_vertical = SIZE_SHRINK_CENTER
			bar.add_theme_stylebox_override("fill", LobbyUi.box(GradeBadge.colors(r["grade"])[1], 7, 0))
			bar.add_theme_stylebox_override("background", LobbyUi.box(Color(0, 0, 0, 0.45), 7, 0, Color(1, 1, 1, 0.15), 1))
			bar_row.add_child(bar)
			bar_row.add_child(LobbyUi.text(RankModel.progress_text(r["points"], rank), 24, Color.WHITE, true))
		var candidate := RankModel.candidate_text(r["candidate"])
		if candidate != "":
			col.add_child(LobbyUi.text(candidate, 26, GradeBadge.text_color(r["candidate"]), true))
		col.add_child(LobbyUi.text(RankModel.position_text(r["rankPos"]), 26, LobbyUi.GOLD, true))
		col.add_child(LobbyUi.text(RankModel.record_text(r), 22, Color(0.8, 0.88, 1.0)))
		col.add_child(LobbyUi.text(RankModel.season_text(r, Time.get_time_zone_from_system().bias), 22, Ui.TEXT_DIM))
		var season_end := SeasonRewardModel.preview_text(r["candidate"] if r["candidate"] != "" else r["grade"])
		if season_end != "":
			var l := LobbyUi.text(season_end, 21, Color(0.85, 0.92, 1.0))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			m.body.add_child(l)
	m.add_close_x()
	return m
