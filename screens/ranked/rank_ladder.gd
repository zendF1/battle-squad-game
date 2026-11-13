extends Control
## "Cấp bậc": the rank ladder, a full-screen layer opened by a tap on the player's rank (the Home
## rank chip, my card's insignia on the Matchmaking screen): open(host). The header has the back
## button ("Sảnh" from Home, "Quay lại" elsewhere; Esc and Android back too) and the title. Under
## it a row of every grade, lowest first (RankLadderModel.columns(): the ladder grades then the
## generals), scrolled by drag, mouse wheel or touchpad, never past the first or the last column
## (a small margin at each end; a row that fits sits centred). On open, and on every resize until
## the player scrolls, the player's grade sits dead centre (near the ends the row stops against the
## edge instead: RankLadderModel.centre_scroll()). Each column: the insignia with its grade's name
## on one short line under it (the current grade's in gold; grades not reached yet a little
## dimmer), its pill on the one shared track (the points that reach
## it; a general's crown and leaderboard positions "#2–3"), its win / loss points as ▲30 ▼5 (the
## ladder grades) and the tiles of its season reward (ui/reward_strip.gd). The track is filled up
## to the player's points (RankLadderModel.fill()), with a tag of the exact points over the fill's
## end. The current grade's column glows in its group's colour, the division's pips under its
## insignia; the reward column the season would give now (a general candidate's, else the current
## grade's) is framed in gold: no check marks, a season reward is for the final grade only. The
## bottom bar, centred: the season's name and time left, the current insignia small and the points.
## Everything from GET /gamedata and GET /rank/me (PlayerState.my_rank(), loaded again on open).

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const RewardStrip := preload("res://ui/reward_strip.gd")
const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const RankLadderModel := preload("res://screens/ranked/rank_ladder_model.gd")
const Fmt := preload("res://core/fmt.gd")

const NAME := "RankLadder"
const HEADER_H := 96.0
const BAR_H := 96.0
const COL_W := 320.0
const BADGE := 168.0
const NAME_Y := BADGE + 2.0 # the grade's name under its insignia
const NAME_H := 30.0
const PIPS_Y := 210.0
const TAG_Y := 234.0
const TAG_H := 38.0
const TRACK_Y := 304.0 # the track's centre line
const TRACK_H := 14.0
const PILL_H := 44.0
const CHIPS_Y := 340.0
const REWARDS_Y := 392.0
const TILE := Vector2(88, 96)
const TILE_ICON := 52
const TILE_GAP := 8.0
const REWARDS_H := TILE.y * 2 + TILE_GAP # two rows at most
const BLOCK_H := REWARDS_Y + REWARDS_H + 16.0
const WHEEL_STEP := 120.0
const MARGIN := 24.0 # the row's margin at each end of the view

const NAVY := Color(0.07, 0.1, 0.26, 0.92)
const NAVY_EDGE := Color(0.45, 0.58, 0.95, 0.55)
const GENERAL_TRACK := Color(0.22, 0.07, 0.12, 0.92)
const FILL := [Color(1.0, 0.93, 0.45), Color(1.0, 0.72, 0.16)]
const ME := Color(0.45, 0.9, 1.0)
const UP := Color(0.45, 0.95, 0.5)
const DOWN := Color(1.0, 0.45, 0.42)
const DIM := Color(0.62, 0.66, 0.78)

## The back button's text: "Sảnh" (Home) or "Quay lại".
var back_text := "Sảnh"
## Fixed rank data instead of PlayerState (previews, tests): a /rank/me answer, {} none.
var preview_rank := {}

var _cols: Array = []
var _rank := {} # RankModel.from_me(), {} before it loads
var _view: Control
var _content: Control
var _lights: Control
var _track: Control
var _bar: PanelContainer
var _season: Label
var _season_dot: Control
var _me_badge: Control
var _me_points: Label
var _scroll := 0.0
var _follow := true # keep the current grade dead centre (open, resizes) until the player scrolls
var _dragging := false
var _fill := -1.0
var _current := -1
var _reward := -1
var _prev_quit := true
var _rewards_h: Array = [] # per column: its reward tiles' height (0 none)


## Opens the ladder over `host` (the screen root) and asks for the rank again.
static func open(host: Control, back_label: String = "Sảnh") -> Control:
	var l: Control = load("res://screens/ranked/rank_ladder.gd").new()
	l.back_text = back_label
	host.add_child(l)
	return l


## The ladder open over `host`, null none.
static func find_in(host: Node) -> Control:
	var n := host.get_node_or_null(NAME) if host != null else null
	return n if n != null and not n.is_queued_for_deletion() else null


func _ready() -> void:
	name = NAME
	theme = LobbyUi.theme()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_prev_quit = get_tree().quit_on_go_back
	get_tree().quit_on_go_back = false # Android back closes the ladder
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	_build_view()
	_build_header()
	_build_bar()
	_cols = RankLadderModel.columns()
	if preview_rank.is_empty():
		PlayerState.rank_changed.connect(_render)
		PlayerState.load_rank()
	var tick := Timer.new() # the season's time left
	tick.wait_time = 30.0
	tick.autostart = true
	tick.timeout.connect(_render_bar)
	add_child(tick)
	_render()


func close() -> void:
	if is_queued_for_deletion():
		return
	if is_inside_tree():
		get_tree().quit_on_go_back = _prev_quit
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()


# ── Build ──────────────────────────────────────────────────────────────────

func _build_header() -> void:
	var header := MarginContainer.new()
	for side in ["left", "right", "top"]:
		header.add_theme_constant_override("margin_" + side, 16)
	header.anchor_right = 1
	header.offset_bottom = HEADER_H
	header.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(header)
	var row := Ui.hbox(20)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	header.add_child(row)
	var back := LobbyUi.pill_button(back_text, 26, 64, "back")
	back.name = "Back"
	LobbyUi.texture_button(back, "pill", 22, true)
	back.pressed.connect(close)
	row.add_child(back)
	var t := LobbyUi.text("Cấp bậc", 36, Color.WHITE, true)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)


func _build_view() -> void:
	_view = Control.new()
	_view.name = "Ladder"
	_view.clip_contents = true
	_view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_view.offset_top = HEADER_H
	_view.offset_bottom = -BAR_H
	_view.mouse_filter = MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	_view.resized.connect(_place)
	add_child(_view)
	_content = Control.new()
	_content.name = "Row"
	_content.mouse_filter = MOUSE_FILTER_IGNORE
	_view.add_child(_content)


func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.name = "SeasonBar"
	_bar.add_theme_stylebox_override("panel", LobbyUi.box(Color(0.03, 0.05, 0.15, 0.78), 30, 0, Color(1, 1, 1, 0.12), 2))
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1
	_bar.anchor_bottom = 1
	_bar.offset_top = -BAR_H + 14
	_bar.offset_bottom = -16
	_bar.grow_horizontal = GROW_DIRECTION_BOTH
	_bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_bar)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 26)
	pad.add_theme_constant_override("margin_right", 26)
	pad.mouse_filter = MOUSE_FILTER_IGNORE
	_bar.add_child(pad)
	var row := Ui.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	pad.add_child(row)
	_season = LobbyUi.text("", 24, Color(0.85, 0.92, 1.0), true)
	_season.name = "Season"
	_season.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_season)
	_season_dot = Control.new() # a small divider between the season and my rank
	_season_dot.custom_minimum_size = Vector2(14, 14)
	_season_dot.size_flags_vertical = SIZE_SHRINK_CENTER
	_season_dot.mouse_filter = MOUSE_FILTER_IGNORE
	_season_dot.draw.connect(func() -> void: _season_dot.draw_circle(Vector2(7, 7), 4.0, Color(1, 1, 1, 0.45)))
	row.add_child(_season_dot)
	_me_badge = GradeBadge.make("", 0, 50)
	_me_badge.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(_me_badge)
	_me_points = LobbyUi.text("", 26, Color.WHITE, true)
	_me_points.name = "MyPoints"
	_me_points.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_me_points)


# ── Render ─────────────────────────────────────────────────────────────────

func _render() -> void:
	if not is_inside_tree():
		return
	if _cols.is_empty(): # the game data came after the ladder opened
		_cols = RankLadderModel.columns()
	var data: Dictionary = preview_rank if not preview_rank.is_empty() else PlayerState.my_rank()
	_rank = RankModel.from_me(data) if not data.is_empty() else {}
	_current = RankLadderModel.current_index(_cols, _rank)
	_reward = RankLadderModel.reward_index(_cols, _rank)
	_fill = RankLadderModel.fill(_cols, _rank)
	_build_row()
	_render_bar()
	_place()
	_place.call_deferred() # again once the view has its laid-out size


func _render_bar() -> void:
	if _season == null:
		return
	_season.text = RankLadderModel.season_line(_rank, int(Time.get_unix_time_from_system())) if not _rank.is_empty() else ""
	_season.visible = _season.text != ""
	var known := not _rank.is_empty()
	_me_badge.visible = known
	_me_points.visible = known
	_season_dot.visible = known and _season.visible
	if known:
		_me_badge.grade = str(_rank["grade"])
		_me_badge.tooltip_text = RankModel.label(str(_rank["grade"]), int(_rank["division"]))
		_me_points.text = RankModel.points_text(int(_rank["points"]))
	_bar.visible = _season.visible or known
	var w := _bar.get_combined_minimum_size().x # centred, as wide as its texts
	_bar.offset_left = -w / 2.0
	_bar.offset_right = w / 2.0


func _build_row() -> void:
	for c in _content.get_children():
		c.queue_free()
	_rewards_h.clear()
	_rewards_h.resize(_cols.size())
	_rewards_h.fill(0.0)
	_content.size = Vector2(_cols.size() * COL_W, BLOCK_H)
	_lights = Control.new()
	_lights.name = "Lights"
	_lights.size = _content.size
	_lights.mouse_filter = MOUSE_FILTER_IGNORE
	_lights.draw.connect(_draw_lights)
	_content.add_child(_lights)
	_track = Control.new()
	_track.name = "Track"
	_track.position = Vector2(0, TRACK_Y - TRACK_H / 2.0)
	_track.size = Vector2(_content.size.x, TRACK_H)
	_track.mouse_filter = MOUSE_FILTER_IGNORE
	_track.draw.connect(_draw_track)
	_content.add_child(_track)
	for i in _cols.size():
		_build_column(i, _cols[i])
	if _fill >= 0.0:
		_content.add_child(_points_tag(int(_rank["points"])))


func _build_column(i: int, col: Dictionary) -> void:
	var x := i * COL_W
	var cx := x + COL_W / 2.0
	var grade := str(col["grade"])
	var badge := GradeBadge.make(grade, 0, BADGE)
	badge.name = "Badge_%s" % grade
	badge.position = Vector2(cx - BADGE / 2.0, 0)
	badge.mouse_filter = MOUSE_FILTER_PASS # a drag still scrolls the row
	var dim := _current >= 0 and i > _fill + 0.0001 and i != _current # not reached yet
	if dim:
		badge.modulate = DIM
	_content.add_child(badge)
	var title := LobbyUi.text(str(col["name"]), 24, LobbyUi.GOLD if i == _current else Color(0.9, 0.93, 1.0), true)
	title.name = "Name_%s" % grade
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = MOUSE_FILTER_IGNORE
	title.position = Vector2(x + 8, NAME_Y)
	title.size = Vector2(COL_W - 16, NAME_H)
	if dim:
		title.modulate = DIM
	_content.add_child(title)
	var pill := _pill(i, col)
	_content.add_child(pill)
	pill.reset_size()
	pill.position = Vector2(cx - pill.size.x / 2.0, TRACK_Y - pill.size.y / 2.0)
	if not col["general"] and (int(col["win"]) > 0 or int(col["loss"]) > 0):
		var chips := _chips(int(col["win"]), int(col["loss"]))
		_content.add_child(chips)
		chips.reset_size()
		chips.position = Vector2(cx - chips.size.x / 2.0, CHIPS_Y)
	var tiles: Array = col["tiles"]
	if not tiles.is_empty():
		var strip := RewardStrip.new()
		strip.name = "Rewards_%s" % grade
		strip.tile_size = TILE
		strip.icon_px = TILE_ICON
		strip.gap = TILE_GAP
		strip.max_rows = 2
		strip.mouse_filter = MOUSE_FILTER_PASS # the row scrolls on a drag over the tiles
		strip.position = Vector2(x + 10, REWARDS_Y)
		strip.size = Vector2(COL_W - 20, REWARDS_H)
		_content.add_child(strip)
		strip.set_tiles(tiles)
		strip.size = Vector2(COL_W - 20, strip.content_height())
		_rewards_h[i] = strip.size.y


## A grade's pill on the track: a ladder grade's points, a general's crown and positions. Lit gold
## once the fill reached it.
func _pill(i: int, col: Dictionary) -> PanelContainer:
	var lit := RankLadderModel.reached(i, _fill)
	var general: bool = col["general"]
	var p := PanelContainer.new()
	p.name = "Pill_%s" % str(col["grade"])
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var border := Color(1.0, 0.94, 0.6) if lit else (Color(1.0, 0.62, 0.3, 0.8) if general else NAVY_EDGE)
	var border_w := 2
	if i == _reward and general:
		border = LobbyUi.GOLD
		border_w = 4
	var fill_c: Color = FILL[1] if lit else (GENERAL_TRACK if general else NAVY)
	var box := LobbyUi.box(fill_c, int(PILL_H / 2.0), 0, border, border_w)
	box.content_margin_left = 18
	box.content_margin_right = 18
	p.add_theme_stylebox_override("panel", box)
	p.custom_minimum_size = Vector2(96, PILL_H)
	var row := Ui.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(row)
	if general:
		var crown := Control.new()
		crown.name = "Crown"
		crown.custom_minimum_size = Vector2(26, 20)
		crown.size_flags_vertical = SIZE_SHRINK_CENTER
		crown.mouse_filter = MOUSE_FILTER_IGNORE
		crown.draw.connect(_draw_crown.bind(crown, lit))
		row.add_child(crown)
	var l := LobbyUi.text(RankLadderModel.pill_text(col), 24, LobbyUi.TEXT_DARK if lit else Color.WHITE, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if lit:
		l.add_theme_constant_override("outline_size", 0)
	row.add_child(l)
	return p


## ▲30 ▼5: what a ranked win / loss changes in this grade.
func _chips(win: int, loss: int) -> HBoxContainer:
	var row := Ui.hbox(14)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	for part in [[true, win], [false, loss]]:
		if int(part[1]) <= 0:
			continue
		var one := Ui.hbox(4)
		one.mouse_filter = MOUSE_FILTER_IGNORE
		var tri := Control.new()
		tri.custom_minimum_size = Vector2(16, 14)
		tri.size_flags_vertical = SIZE_SHRINK_CENTER
		tri.mouse_filter = MOUSE_FILTER_IGNORE
		var up: bool = part[0]
		tri.draw.connect(func() -> void:
			var pts := PackedVector2Array([Vector2(0, 14), Vector2(16, 14), Vector2(8, 0)]) if up \
				else PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(8, 14)])
			tri.draw_colored_polygon(pts, UP if up else DOWN))
		one.add_child(tri)
		var l := LobbyUi.text(str(part[1]), 22, UP if up else DOWN, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		one.add_child(l)
		row.add_child(one)
	return row


## My exact points over the fill's end, its arrow pointing at the track.
func _points_tag(points: int) -> Control:
	var tag := Control.new()
	tag.name = "PointsTag"
	tag.mouse_filter = MOUSE_FILTER_IGNORE
	var l := LobbyUi.text(Fmt.thousands(points), 22, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var w := maxf(l.get_minimum_size().x + 26.0, 70.0)
	tag.size = Vector2(w, TAG_H + 10.0)
	l.position = Vector2.ZERO
	l.size = Vector2(w, TAG_H)
	tag.draw.connect(func() -> void:
		tag.draw_style_box(LobbyUi.box(Color(0.04, 0.2, 0.32, 0.95), int(TAG_H / 2.0), 0, ME, 2), Rect2(0, 0, w, TAG_H))
		tag.draw_colored_polygon(PackedVector2Array([Vector2(w / 2.0 - 8, TAG_H - 1), Vector2(w / 2.0 + 8, TAG_H - 1),
			Vector2(w / 2.0, TAG_H + 9)]), ME))
	tag.add_child(l)
	tag.position = Vector2(_fill_x() - w / 2.0, TAG_Y)
	return tag


func _fill_x() -> float:
	return _fill * COL_W + COL_W / 2.0


# ── Draw ───────────────────────────────────────────────────────────────────

## Behind the columns: the current grade's light (a soft column and a glow in its group's colour
## behind the insignia, the division's pips under it) and the gold frame of the reward column.
func _draw_lights() -> void:
	if _current >= 0:
		var x := _current * COL_W
		var c: Color = GradeBadge.colors(str(_cols[_current]["grade"]))[1]
		_lights.draw_style_box(LobbyUi.box(Color(c, 0.1), 26, 0, Color(c, 0.45), 2),
			Rect2(x + 4, -4, COL_W - 8, _column_bottom(_current) + 4))
		var centre := Vector2(x + COL_W / 2.0, BADGE / 2.0)
		for k in 8:
			var t := float(k) / 8.0
			_lights.draw_circle(centre, BADGE * (0.62 - 0.32 * t), Color(c, 0.06 + 0.05 * t))
		var p := RankLadderModel.pips(_rank)
		var total: int = p[1]
		for k in total:
			var px := x + COL_W / 2.0 + (k - (total - 1) / 2.0) * 22.0
			var d := PackedVector2Array([Vector2(px, PIPS_Y), Vector2(px + 7, PIPS_Y + 8), Vector2(px, PIPS_Y + 16), Vector2(px - 7, PIPS_Y + 8)])
			var on: bool = k < int(p[0])
			_lights.draw_colored_polygon(d, LobbyUi.GOLD if on else Color(0.08, 0.1, 0.2, 0.9))
			d.append(d[0])
			_lights.draw_polyline(d, Color(1.0, 0.94, 0.6) if on else Color(1, 1, 1, 0.35), 2.0, true)
	if _reward >= 0:
		var rx := _reward * COL_W
		_lights.draw_style_box(LobbyUi.box(Color(1.0, 0.8, 0.22, 0.14), 20, 0, Color(LobbyUi.GOLD, 0.95), 3),
			Rect2(rx + 6, REWARDS_Y - 10, COL_W - 12, _column_bottom(_reward) - REWARDS_Y + 10))


## Where a column's content ends: under its reward tiles (the chips without any).
func _column_bottom(i: int) -> float:
	var h: float = _rewards_h[i] if i >= 0 and i < _rewards_h.size() else 0.0
	return REWARDS_Y + h + 10.0 if h > 0.0 else CHIPS_Y + 40.0


## The shared track: navy under the ladder grades, dark red under the generals, gold up to the
## fill.
func _draw_track() -> void:
	if _cols.is_empty():
		return
	var x0 := COL_W / 2.0 - 70.0
	var x1 := (_cols.size() - 1) * COL_W + COL_W / 2.0 + 70.0
	var first_general := _cols.size()
	for i in _cols.size():
		if _cols[i]["general"]:
			first_general = i
			break
	var split := clampf((first_general - 0.5) * COL_W + COL_W / 2.0, x0, x1)
	var r := int(TRACK_H / 2.0)
	_track.draw_style_box(LobbyUi.box(NAVY, r, 0, NAVY_EDGE, 2), Rect2(x0, 0, split - x0 + r, TRACK_H))
	if split < x1:
		_track.draw_style_box(LobbyUi.box(GENERAL_TRACK, r, 0, Color(1.0, 0.5, 0.3, 0.5), 2), Rect2(split - r, 0, x1 - split + r, TRACK_H))
	if _fill >= 0.0:
		var fx := _fill_x()
		var fill := StyleBoxFlat.new()
		fill.bg_color = FILL[1]
		fill.set_corner_radius_all(r)
		fill.border_color = FILL[0]
		fill.border_width_top = 3
		_track.draw_style_box(fill, Rect2(x0, 0, fx - x0, TRACK_H))


func _draw_crown(c: Control, lit: bool) -> void:
	var w := c.size.x
	var h := c.size.y
	var pts := PackedVector2Array([Vector2(1, h - 3), Vector2(2, 4), Vector2(w * 0.3, h * 0.5), Vector2(w / 2.0, 0),
		Vector2(w * 0.7, h * 0.5), Vector2(w - 2, 4), Vector2(w - 1, h - 3)])
	var gold := Color(0.55, 0.1, 0.06) if lit else LobbyUi.GOLD
	c.draw_colored_polygon(pts, gold)
	c.draw_rect(Rect2(1, h - 4, w - 2, 4), gold)
	var line := pts.duplicate()
	line.append(pts[0])
	c.draw_polyline(line, Color(0.1, 0.04, 0.02, 0.9), 1.5, true)


# ── Scroll ─────────────────────────────────────────────────────────────────

## Puts the row in the view: the current grade dead centre while following (RankLadderModel
## clamps it so the row never scrolls past its ends), else the player's scroll clamped to the row
## (a resize can shorten it); a row narrower than the view sits centred.
func _place() -> void:
	if _content == null or _view == null or not is_instance_valid(_content):
		return
	var view_w := _view.size.x
	var n := _cols.size()
	if _follow and _current >= 0:
		_scroll = RankLadderModel.centre_scroll(_current, n, COL_W, MARGIN, view_w)
	var most := RankLadderModel.max_scroll(n, COL_W, MARGIN, view_w)
	_scroll = clampf(_scroll, 0.0, most)
	var x := MARGIN - _scroll if most > 0.0 else (view_w - n * COL_W) / 2.0
	_content.position = Vector2(roundf(x), roundf(maxf((_view.size.y - BLOCK_H) / 2.0, 0.0)))


func scroll_by(dx: float) -> void:
	_follow = false
	_scroll += dx
	_place()


## The column at the centre now (previews, tests).
func centred_index() -> int:
	return RankLadderModel.centred_index(_scroll, _cols.size(), COL_W, MARGIN, _view.size.x if _view != null else 0.0)


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.pressed:
			var step := WHEEL_STEP * maxf(mb.factor, 1.0)
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
					scroll_by(step)
					_view.accept_event()
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
					scroll_by(-step)
					_view.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		scroll_by(-(event as InputEventMouseMotion).relative.x)
		_view.accept_event()
	elif event is InputEventScreenDrag and not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true):
		scroll_by(-(event as InputEventScreenDrag).relative.x)
		_view.accept_event()
	elif event is InputEventPanGesture:
		scroll_by(((event as InputEventPanGesture).delta.x + (event as InputEventPanGesture).delta.y) * 20.0)
		_view.accept_event()
