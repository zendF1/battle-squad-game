extends "res://ui/modal.gd"
## "Mời đồng đội" (the "+" of the Home teammate slot): two tabs drawn as pictures, Gợi ý (the
## suggestions: ListOnlinePlayers → OnlinePlayers, the default) and Bạn bè (my friends, offline
## ones too: ListFriends → Friends), the last one shown remembered for the session
## (PartyModel.invite_tab); a name search over the tab shown (DEBOUNCE after the last key) over a
## scrolling list of its players (through Router.party): head with its status mark
## (presence_glyphs.gd: online / in a party / in a match / offline, an offline row dimmed), the
## name (my nickname for a friend), "Lv.N", their badge (rankBadge, when they have one), Kết bạn (the
## add-friend picture, screens/social/friend_button.gd; hidden for a friend), Mời vào bang (the
## guild's invite picture, while Router.social.can_invite_to_guild() accepts them) and a "Mời" button, off
## for a player not online and free and "Đã mời (12s)" counting down once invited
## (PartyModel.row_button()). The server sends the list a page at a time: ◀ page ▶ under it
## (screens/home/online_pager.gd) steps through them, a new search or tab goes back to page 1. An
## empty list shows the tab's picture and a short line dead centre over the list. It asks for
## page 1 on opening and again for the page shown every REFRESH_SEC while open, and closes itself
## once the party is full.

const PartyModel := preload("res://screens/home/party_model.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")
const OnlinePager := preload("res://screens/home/online_pager.gd")
const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const FriendButton := preload("res://screens/social/friend_button.gd")
const GuildGlyphs := preload("res://ui/guild_glyphs.gd")
const PresenceGlyphs := preload("res://screens/home/presence_glyphs.gd")
const FriendsModel := preload("res://screens/social/friends_model.gd")

const DEBOUNCE := 0.4
const REFRESH_SEC := 5.0
const LIST_H := 430
const EMPTY := "Chưa có ai khác đang online"
const NOT_FOUND := "Không tìm thấy người chơi"
const LOADING := "Đang tải..."
## The tabs, in order: the list, its picture (presence_glyphs.gd) and its name (the tooltip).
const TABS := [
	{"tab": PartyModel.TAB_SUGGEST, "glyph": "suggest", "name": "Gợi ý"},
	{"tab": PartyModel.TAB_FRIENDS, "glyph": "friends", "name": "Bạn bè"},
]
const TAB_H := 64
const STATUS_PX := 28 # the status mark on a row's head
const EMPTY_PX := 110 # the empty list's picture
const OFFLINE_ALPHA := 0.5 # an offline row

var party # Router.party (screens/home/party.gd)
var search: LineEdit
var _list: VBoxContainer
var _scroll: ScrollContainer
var pager: OnlinePager
var _shown_page := 0 # the page the rows show (a new one scrolls back to the top)
var tabs: Array[Button] = []
var _empty: Control # the picture + line over the empty list
var _empty_glyph: Control
var _empty_text: Label
var _invite_buttons := {} # playerId -> its "Mời" Button
var _debounce := -1.0
var _refresh := REFRESH_SEC
var _tick := 0.0


## Opens over `host` for `p` (Router.party) and asks for the list.
func open_for(host: Node, p) -> void:
	party = p
	open(host, "Mời đồng đội", 780)
	add_close_x()
	var tab_row := Ui.hbox(12)
	tab_row.name = "Tabs"
	body.add_child(tab_row)
	tabs = Ui.tab_row(TABS.map(func(_t): return ""), 24, _on_tab, TAB_H)
	for i in tabs.size():
		_dress_tab(tabs[i], TABS[i])
		tab_row.add_child(tabs[i])
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Tìm theo tên người chơi"
	search.clear_button_enabled = true
	search.custom_minimum_size.y = 64
	search.add_theme_font_size_override("font_size", 26)
	search.text_changed.connect(func(_t: String) -> void: _debounce = DEBOUNCE)
	body.add_child(search)
	var stack := MarginContainer.new() # the list, the empty state over it
	stack.custom_minimum_size = Vector2(0, LIST_H)
	body.add_child(stack)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	_scroll = scroll
	_list = Ui.vbox(10)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var center := CenterContainer.new()
	center.name = "Empty"
	center.mouse_filter = MOUSE_FILTER_IGNORE
	stack.add_child(center)
	_empty = center
	var empty_col := Ui.vbox(14)
	empty_col.mouse_filter = MOUSE_FILTER_IGNORE
	center.add_child(empty_col)
	_empty_glyph = PresenceGlyphs.make_glyph("suggest", EMPTY_PX)
	_empty_glyph.modulate.a = 0.45
	empty_col.add_child(_empty_glyph)
	_empty_text = Ui.label(LOADING, 24)
	_empty_text.add_theme_color_override("font_color", Ui.TEXT_DIM)
	_empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_col.add_child(_empty_text)
	pager = OnlinePager.new()
	pager.step.connect(func(dir: int) -> void:
		_refresh = REFRESH_SEC
		party.list_page(dir))
	body.add_child(pager)
	party.players_changed.connect(_render)
	party.changed.connect(_on_party_changed)
	party.set_tab(party.model.invite_tab)
	Ui.select_tab(tabs, _tab_index(party.model.tab))
	_render()
	party.list("", 1)


## A tab pressed: its list from page 1 (the search kept).
func _on_tab(index: int) -> void:
	var t: String = TABS[index]["tab"]
	Ui.select_tab(tabs, index)
	party.model.invite_tab = t
	if t == party.model.tab:
		return
	_refresh = REFRESH_SEC
	_debounce = -1.0
	party.set_tab(t)
	party.list(search.text, 1)


static func _tab_index(t: String) -> int:
	for i in TABS.size():
		if TABS[i]["tab"] == t:
			return i
	return 0


## A tab button: its picture alone, centred (the name as its tooltip).
func _dress_tab(b: Button, t: Dictionary) -> void:
	b.name = "Tab_" + str(t["tab"])
	b.tooltip_text = str(t["name"])
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(center)
	center.add_child(PresenceGlyphs.make_glyph(str(t["glyph"]), int(TAB_H * 0.75)))


func _process(delta: float) -> void:
	if party == null:
		return
	if _debounce >= 0.0:
		_debounce -= delta
		if _debounce < 0.0:
			_refresh = REFRESH_SEC
			party.list(search.text, 1) # a new search starts at page 1
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH_SEC
		party.list(search.text)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		_render_buttons()


func _on_party_changed() -> void:
	if party.model.is_full():
		close() # the party is full
	else:
		_render_buttons()


## The rows of the tab's last answer.
func _render() -> void:
	if _list == null:
		return
	Ui.clear(_list)
	_invite_buttons.clear()
	for p in party.model.players:
		_list.add_child(_row(p))
	var none: bool = party.model.players.is_empty()
	var friends: bool = party.model.tab == PartyModel.TAB_FRIENDS
	var empty := empty_state(friends, party.model.loaded, search.text)
	_empty.visible = none
	_empty_glyph.kind = empty["glyph"]
	_empty_glyph.visible = empty["glyph"] != ""
	_empty_text.text = empty["text"]
	pager.show_state(party.model.pager(), party.model.page)
	if party.model.page != _shown_page:
		_shown_page = party.model.page
		_scroll.scroll_vertical = 0
	_render_buttons()


## The empty list's {glyph ("" none), text}: loading, nothing found for the search, or the tab's
## empty line under its picture.
static func empty_state(friends: bool, loaded: bool, query: String) -> Dictionary:
	if not loaded:
		return {"glyph": "", "text": LOADING}
	var glyph := "friends" if friends else "suggest"
	if query.strip_edges() != "":
		return {"glyph": glyph, "text": NOT_FOUND}
	return {"glyph": glyph, "text": FriendsModel.EMPTY[FriendsModel.TAB_FRIENDS] if friends else EMPTY}


func _row(p: Dictionary) -> Control:
	var panel := LobbyUi.panel(12, 16, Color(1, 1, 1, 0.06))
	panel.name = "Row_" + str(p["playerId"])
	var status := str(p.get("status", PartyModel.IDLE))
	if status == PartyModel.OFFLINE:
		panel.modulate.a = OFFLINE_ALPHA
	var row := Ui.hbox(14)
	panel.add_child(row)
	var shown := PartyModel.shown_name(p)
	var head := HeadIcon.make(str(p["characterId"]), shown, 60)
	var mark := PresenceGlyphs.status_mark(status, STATUS_PX)
	mark.position = Vector2(60 - STATUS_PX + 4, 60 - STATUS_PX + 4) # on the head's bottom-right rim
	head.add_child(mark)
	row.add_child(head)
	var col := Ui.vbox(2)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var name_label := LobbyUi.text(shown, 26, Color.WHITE, true)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_label)
	var line := Ui.hbox(8)
	col.add_child(line)
	var level := int(p["level"])
	var lv := LobbyUi.text("Lv.%d" % level if level > 0 else "", 21, LobbyUi.GOLD, true)
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(lv)
	if str(p.get("rankBadge", "")) != "":
		line.add_child(GradeBadge.make(str(p["rankBadge"]), 0, 30))
		var rank := LobbyUi.text(RankModel.grade_name(str(p["rankBadge"])), 20, GradeBadge.text_color(str(p["rankBadge"])))
		rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(rank)
	if party.model.tab != PartyModel.TAB_FRIENDS: # Bạn bè: all of them are friends already
		row.add_child(FriendButton.make(p, 60))
	if Router.social.can_invite_to_guild(str(p["playerId"])): # Mời vào bang (the guild's hook)
		row.add_child(guild_button(p, 60))
	var b := Ui.button("Mời", 24)
	b.name = "Invite_" + str(p["playerId"])
	b.custom_minimum_size = Vector2(190, 64)
	b.focus_mode = FOCUS_NONE
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: party.invite(str(p["playerId"])))
	row.add_child(b)
	_invite_buttons[str(p["playerId"])] = b
	return panel


## Each row's button from the model now (the countdowns, a busy player).
func _render_buttons() -> void:
	var now: float = party.now()
	for p in party.model.players:
		var b: Button = _invite_buttons.get(str(p["playerId"]))
		if b == null:
			continue
		var state: Dictionary = party.model.row_button(p, now)
		b.text = state["text"]
		b.disabled = state["disabled"]


## "Mời vào bang": a round button with the guild invite picture; sends Router.social's guild invite
## (autoload/guild_state.gd) and turns off once sent.
static func guild_button(p: Dictionary, px: int) -> Button:
	var b := Button.new()
	b.name = "GuildInvite_" + str(p["playerId"])
	b.tooltip_text = "Mời vào bang"
	b.focus_mode = FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	LobbyUi.style_button(b, LobbyUi.ICON_COLORS["purple"], px / 2, 0, Color(1, 1, 1, 0.85), 3)
	var g := GuildGlyphs.make("invite", int(px * 0.62))
	g.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var inset := roundf(px * 0.19)
	g.offset_left = inset
	g.offset_top = inset
	g.offset_right = -inset
	g.offset_bottom = -inset
	b.add_child(g)
	b.pressed.connect(func() -> void:
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.45)
		Router.social.invite_to_guild(str(p["playerId"]), str(p.get("displayName", ""))))
	return b
