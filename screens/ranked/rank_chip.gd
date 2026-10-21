extends Button
## The lobby's rank chip beside the player block: the tier badge, "Bạc II" in the tier's colour
## and "1.050 điểm" (PlayerState.my_rank(); "Xếp hạng" / "Đang tải..." until it loads). A tap
## opens the rank popup (popup()): the badge big, the tier, the points, "Hạng #N" in the season,
## the season's name and end date, wins and losses.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Modal := preload("res://ui/modal.gd")
const TierBadge := preload("res://screens/ranked/tier_badge.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")

## Where the popup opens (the screen root).
var host: Control

var _badge: TierBadge
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
	_badge = TierBadge.make("", 3, 70)
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
		_badge.tier = ""
		_tier.text = "Xếp hạng"
		_tier.add_theme_color_override("font_color", Color.WHITE)
		_points.text = "Đang tải..."
	else:
		var r := RankModel.from_me(data)
		_badge.tier = r["tier"]
		_badge.division = r["division"]
		_tier.text = RankModel.label(r["tier"], r["division"])
		_tier.add_theme_color_override("font_color", TierBadge.COLORS[r["tier"]][0])
		_points.text = RankModel.points_text(r["rating"])
	# the row's width follows the texts
	custom_minimum_size.x = 70 + 8 + maxf(_tier.get_minimum_size().x, _points.get_minimum_size().x) + 32


## The rank popup (also loads the rank again).
func popup() -> Modal:
	PlayerState.load_rank()
	return open_popup(host if host != null else get_tree().current_scene, PlayerState.my_rank())


static func open_popup(on: Control, data: Dictionary) -> Modal:
	var r := RankModel.from_me(data)
	var m := Modal.new()
	m.open(on, "Xếp hạng", 640)
	m.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := Ui.hbox(28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.body.add_child(row)
	var badge := TierBadge.make(r["tier"] if not data.is_empty() else "", r["division"], 150)
	row.add_child(badge)
	var col := Ui.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	if data.is_empty():
		col.add_child(LobbyUi.text("Chưa tải được hạng", 30, Color.WHITE, true))
		col.add_child(LobbyUi.text("Thử lại sau giây lát", 22, Ui.TEXT_DIM))
	else:
		col.add_child(LobbyUi.text(RankModel.label(r["tier"], r["division"]), 40, TierBadge.COLORS[r["tier"]][0], true))
		col.add_child(LobbyUi.text(RankModel.points_text(r["rating"]), 30, Color.WHITE, true))
		col.add_child(LobbyUi.text(RankModel.position_text(r["rankPos"]), 26, LobbyUi.GOLD, true))
		col.add_child(LobbyUi.text(RankModel.record_text(r), 22, Color(0.8, 0.88, 1.0)))
		col.add_child(LobbyUi.text(RankModel.season_text(r, Time.get_time_zone_from_system().bias), 22, Ui.TEXT_DIM))
	m.add_close_x()
	return m
