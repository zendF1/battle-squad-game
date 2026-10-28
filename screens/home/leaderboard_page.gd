extends Control
## "Xếp hạng" (a Home page, the lobby's trophy shortcut): three tabs with a picture and a short name
## (LeaderboardModel.TABS: Cấp độ, Rank, Lực chiến), the podium on the left (2nd, 1st, 3rd:
## leaderboard_place.gd, each player's character standing on their step as on the lobby stage; on
## the Rank tab the season's name and end date as a chip over it), the rows from the 4th in a list
## on the right (position, the head of the lobby picture of the player's character (the server's
## characterId) ringed in their badge's frame colour, name with the badge's insignia, the board's
## value with its picture) and my own row pinned under the list (highlighted; "Chưa có hạng" when I
## am not on that board). A tap on a podium place or a row (mine too) opens that player's showcase
## (showcase_popup.gd). The boards come from GET /leaderboard through PlayerState
## (load_leaderboard: loaded when the tab shows, kept a minute), the order and positions are the
## server's; the equipment catalog (the guns of the looks) is asked for when the page shows.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const PowerTag := preload("res://ui/power_tag.gd")
const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")
const LeaderboardModel := preload("res://screens/home/leaderboard_model.gd")
const LeaderboardPlace := preload("res://screens/home/leaderboard_place.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const ShowcasePopup := preload("res://screens/home/showcase_popup.gd")

const PODIUM_W := 800
const ROW_H := 76
const ME := Color(0.4, 0.85, 1.0)
const ROW_BG := Color(0.06, 0.09, 0.22, 0.8)
const ME_BG := Color(0.1, 0.24, 0.42, 0.95)

## The lobby's character: my head when the board does not say my strongest.
var lobby_character := Callable()
## Where the showcase opens (Home); defaults to this page.
var overlay: Control

var _tab := 0
var _armed := false
var _tabs: Array[Button] = []
var _season: PanelContainer
var _season_text: Label
var _podium: HBoxContainer
var _status: LoadStatus
var _list: VBoxContainer
var _pinned: PanelContainer
var _had_catalog := false
var _press_at := Vector2.INF


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var col := Ui.vbox(14)
	margin.add_child(col)
	var tab_row := Ui.hbox(8)
	col.add_child(tab_row)
	_tabs = Ui.tab_row(LeaderboardModel.TABS.map(func(_t): return ""), 26, show_tab, 64)
	for i in _tabs.size():
		_dress_tab(_tabs[i], LeaderboardModel.TABS[i])
		tab_row.add_child(_tabs[i])
	var body := Ui.hbox(16)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(body)
	body.add_child(_build_podium())
	body.add_child(_build_list())
	PlayerState.leaderboard_changed.connect(func(type: String) -> void:
		if type == board() and is_inside_tree():
			_render.call_deferred())
	PlayerState.changed.connect(func() -> void:
		if is_visible_in_tree():
			_render_pinned())
	PlayerState.equipment_changed.connect(func() -> void:
		if PlayerState.catalog != null and not _had_catalog: # the looks' guns can be told now
			_had_catalog = true
			if is_visible_in_tree():
				_render.call_deferred())
	_had_catalog = PlayerState.catalog != null
	visibility_changed.connect(_ensure_loaded)
	Ui.select_tab(_tabs, _tab)
	_render()
	_arm.call_deferred()


## Deferred from _ready(): Home hides the pages it does not show right after adding them.
func _arm() -> void:
	_armed = true
	_ensure_loaded()


func _ensure_loaded() -> void:
	if _armed and is_visible_in_tree():
		PlayerState.load_leaderboard(board())
		PlayerState.need_equipment()
		_render()


## Shows tab `index` (LeaderboardModel.TABS) and loads its board.
func show_tab(index: int) -> void:
	_tab = clampi(index, 0, LeaderboardModel.TABS.size() - 1)
	Ui.select_tab(_tabs, _tab)
	_ensure_loaded()
	_render()


func tab() -> int:
	return _tab


## The board shown ("level", "rank", "power").
func board() -> String:
	return LeaderboardModel.TABS[_tab]["type"]


## A tab button: its glyph and short name centred on it.
func _dress_tab(b: Button, t: Dictionary) -> void:
	b.name = "Tab_" + str(t["type"])
	b.tooltip_text = t["name"]
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(center)
	var row := Ui.hbox(10)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	center.add_child(row)
	row.add_child(GlyphIcon.make(str(t["glyph"]), 42))
	var l := LobbyUi.text(str(t["name"]), 26, Color.WHITE, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(l)


# ── Podium ──────────────────────────────────────────────────────────────────

func _build_podium() -> Control:
	var panel := LobbyUi.panel(18, 20)
	panel.name = "PodiumPanel"
	panel.custom_minimum_size.x = PODIUM_W
	var col := Ui.vbox(0)
	panel.add_child(col)
	var chip_row := CenterContainer.new()
	chip_row.custom_minimum_size.y = 52
	col.add_child(chip_row)
	_season = LobbyUi.panel(0, 22, Color(0.04, 0.06, 0.16, 0.85))
	_season.name = "SeasonChip"
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 4)
	_season.add_child(pad)
	var season_row := Ui.hbox(8)
	pad.add_child(season_row)
	season_row.add_child(GlyphIcon.make("clock", 30))
	_season_text = LobbyUi.text("", 21, Color(0.85, 0.92, 1.0), true)
	_season_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	season_row.add_child(_season_text)
	chip_row.add_child(_season)
	_podium = Ui.hbox(22)
	_podium.name = "Podium"
	_podium.alignment = BoxContainer.ALIGNMENT_CENTER
	_podium.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(_podium)
	return panel


func _render_podium(parsed: Dictionary) -> void:
	Ui.clear(_podium)
	var places := LeaderboardModel.podium(parsed.get("entries", []))
	for i in places.size():
		var e: Dictionary = places[i]
		var place = LeaderboardPlace.make(LeaderboardModel.podium_place(i), e, board(),
			LeaderboardModel.is_me(e, Session.player_id))
		place.tapped.connect(open_showcase)
		_podium.add_child(place)
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var ends := str(PlayerState.my_rank().get("season", {}).get("endsAt", "")) if PlayerState.my_rank().get("season") is Dictionary else ""
	_season_text.text = LeaderboardModel.season_text(parsed, ends, bias)
	_season.visible = board() == LeaderboardModel.RANK and _season_text.text != ""


# ── List ────────────────────────────────────────────────────────────────────

func _build_list() -> Control:
	var panel := LobbyUi.panel(18, 20)
	panel.name = "ListPanel"
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var col := Ui.vbox(10)
	panel.add_child(col)
	_status = LoadStatus.new()
	col.add_child(_status)
	_list = Ui.vbox(8)
	_list.name = "Rows"
	var scroll := Ui.scroll(_list)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # rows as wide as the pinned one
	col.add_child(scroll)
	_pinned = PanelContainer.new()
	_pinned.name = "Pinned"
	col.add_child(_pinned)
	return panel


func _render() -> void:
	if _list == null:
		return
	var type := board()
	var parsed := PlayerState.my_leaderboard(type)
	var error := str(PlayerState.leaderboard_errors.get(type, ""))
	if parsed.is_empty() and error != "":
		_status.show_error(error, func() -> void: PlayerState.load_leaderboard(type, true))
	elif parsed.is_empty():
		_status.show_loading()
	else:
		_status.clear()
	_render_podium(parsed)
	Ui.clear(_list)
	var rows := LeaderboardModel.list_rows(parsed.get("entries", []))
	for e in rows:
		_list.add_child(_row(e, type, LeaderboardModel.is_me(e, Session.player_id)))
	if not parsed.is_empty() and parsed.get("entries", []).is_empty():
		var l := LobbyUi.text("Chưa có ai", 24, Ui.TEXT_DIM, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(l)
	_render_pinned()


## My row under the list: the board's `me`, else my name with "Chưa có hạng".
func _render_pinned() -> void:
	if _pinned == null:
		return
	for c in _pinned.get_children():
		_pinned.remove_child(c)
		c.queue_free()
	var type := board()
	var parsed := PlayerState.my_leaderboard(type)
	_pinned.visible = not parsed.is_empty()
	if parsed.is_empty():
		return
	var me: Dictionary = parsed["me"]
	var fallback := str(lobby_character.call()) if lobby_character.is_valid() else LoadoutModel.default_character()
	var mine := PlayerState.power_character()
	if mine != "":
		fallback = mine
	if me.is_empty():
		me = {"pos": 0, "player_id": Session.player_id, "name": PlayerState.display_name(), "level": PlayerState.level(),
			"badge": PlayerState.rank_badge(), "character": fallback, "unranked": true}
	elif LeaderboardModel.head_character(me) == "":
		me["character"] = fallback
	_pinned.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_pinned.add_child(_row(me, type, true))


## An avatar's ring: the badge's frame colour (rankBadge), a light grey without one.
static func ring_color(badge: String) -> Color:
	return GradeBadge.colors(badge)[1] if badge != "" else Color(0.85, 0.88, 0.95)


## Opens the showcase of row `e` (a podium place or a list row).
func open_showcase(e: Dictionary) -> Control:
	if e.is_empty() or str(e.get("player_id", "")) == "":
		return null
	return ShowcasePopup.show_player(overlay if overlay != null else self, e)


## A tap on a row (a press released near where it began: a drag scrolls the list).
func _on_row_input(event: InputEvent, e: Dictionary) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_press_at = event.global_position
	elif _press_at != Vector2.INF:
		if event.global_position.distance_to(_press_at) <= LeaderboardPlace.TAP_SLOP:
			open_showcase(e)
		_press_at = Vector2.INF


## A list row: position, head (the lobby picture's, Art.lobby_head()), name with the badge's insignia, the board's value with its picture.
func _row(e: Dictionary, type: String, me: bool) -> Control:
	var row := PanelContainer.new()
	row.name = "Row%d" % int(e.get("pos", 0))
	row.custom_minimum_size.y = ROW_H
	row.mouse_filter = MOUSE_FILTER_PASS # a drag still scrolls the list
	row.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	row.gui_input.connect(_on_row_input.bind(e))
	var bg := LobbyUi.box(ME_BG if me else ROW_BG, 14, 8, ME if me else Color(1, 1, 1, 0.08), 3 if me else 1)
	bg.content_margin_right = 22
	row.add_theme_stylebox_override("panel", bg)
	var h := Ui.hbox(12)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(h)
	var pos := LobbyUi.text(LeaderboardModel.pos_text(int(e.get("pos", 0))), 26, ME if me else Color.WHITE, true)
	pos.name = "Pos"
	pos.custom_minimum_size.x = 84
	pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(pos)
	var head = HeadIcon.make(LeaderboardModel.head_character(e), str(e.get("name", "")), 62)
	head.name = "Head"
	head.lobby = true
	head.ring_width = 4.0
	head.ring = ring_color(str(e.get("badge", "")))
	head.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(head)
	var name_row := Ui.hbox(8)
	name_row.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_child(name_row)
	var n := LobbyUi.text(str(e.get("name", "")), 24, ME if me else Color.WHITE, true)
	n.name = "Name"
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.size_flags_horizontal = SIZE_EXPAND_FILL
	n.mouse_filter = MOUSE_FILTER_IGNORE
	var badge := str(e.get("badge", ""))
	if badge != "":
		var b := GradeBadge.make(badge, 0, 40)
		b.size_flags_vertical = SIZE_SHRINK_CENTER
		b.tooltip_text = "Cấp bậc mùa trước"
		name_row.add_child(b)
	else: # the names line up with or without a badge
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(40, 40)
		gap.mouse_filter = MOUSE_FILTER_IGNORE
		name_row.add_child(gap)
	name_row.add_child(n)
	if e.get("unranked", false):
		var l := LobbyUi.text(LeaderboardModel.not_ranked_text(type), 21, Ui.TEXT_DIM, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
	else:
		h.add_child(_row_value(e, type))
	return row


## The value at the row's end, right-aligned: "Lv.37"; the insignia, "Đại tá 1" and the points;
## the power glyph and number.
func _row_value(e: Dictionary, type: String) -> Control:
	var box := Ui.hbox(8)
	box.name = "Value"
	box.alignment = BoxContainer.ALIGNMENT_END
	box.custom_minimum_size.x = 200
	box.mouse_filter = MOUSE_FILTER_IGNORE
	match type:
		LeaderboardModel.RANK:
			var ins := GradeBadge.make(str(e["grade"]), int(e["division"]), 46)
			ins.size_flags_vertical = SIZE_SHRINK_CENTER
			box.add_child(ins)
			var col := Ui.vbox(0)
			col.alignment = BoxContainer.ALIGNMENT_CENTER
			col.mouse_filter = MOUSE_FILTER_IGNORE
			box.add_child(col)
			col.add_child(LobbyUi.text(LeaderboardModel.value_text(type, e), 22, GradeBadge.text_color(str(e["grade"])), true))
			col.add_child(LobbyUi.text(LeaderboardModel.sub_text(type, e), 18, Color(0.8, 0.88, 1.0)))
		LeaderboardModel.POWER:
			var tag = PowerTag.make(34, 26)
			tag.keep_unknown = true
			tag.set_power(int(e["power"]))
			box.add_child(tag)
		_:
			var l := LobbyUi.text(LeaderboardModel.value_text(type, e), 28, LobbyUi.GOLD, true)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			box.add_child(l)
	return box
