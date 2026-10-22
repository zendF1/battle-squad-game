extends "res://ui/modal.gd"
## "Mời đồng đội" (the "+" of the Home teammate slot): a name search (ListOnlinePlayers {query},
## DEBOUNCE after the last key) over a scrolling list of the online players (OnlinePlayers through
## Router.party): head, name, "Lv.N", tier badge and a "Mời" button, off with "Bận" / "Đang trận"
## for a busy player and "Đã mời (12s)" counting down once invited (PartyModel.row_button()). It
## asks for the list on opening and every REFRESH_SEC while open, and closes itself once a
## teammate joined.

const PartyModel := preload("res://screens/home/party_model.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")
const TierBadge := preload("res://screens/ranked/tier_badge.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")

const DEBOUNCE := 0.4
const REFRESH_SEC := 5.0
const LIST_H := 430
const EMPTY := "Chưa có ai khác đang online"
const NOT_FOUND := "Không tìm thấy người chơi"

var party # Router.party (screens/home/party.gd)
var search: LineEdit
var _list: VBoxContainer
var _empty: Label
var _invite_buttons := {} # playerId -> its "Mời" Button
var _debounce := -1.0
var _refresh := REFRESH_SEC
var _tick := 0.0


## Opens over `host` for `p` (Router.party) and asks for the list.
func open_for(host: Node, p) -> void:
	party = p
	open(host, "Mời đồng đội", 780)
	add_close_x()
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Tìm theo tên người chơi"
	search.clear_button_enabled = true
	search.custom_minimum_size.y = 64
	search.add_theme_font_size_override("font_size", 26)
	search.text_changed.connect(func(_t: String) -> void: _debounce = DEBOUNCE)
	body.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, LIST_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = Ui.vbox(10)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_empty = Ui.label("Đang tải...", 24)
	_empty.add_theme_color_override("font_color", Ui.TEXT_DIM)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_empty)
	party.players_changed.connect(_render)
	party.changed.connect(_on_party_changed)
	_render()
	party.list("")


func _process(delta: float) -> void:
	if party == null:
		return
	if _debounce >= 0.0:
		_debounce -= delta
		if _debounce < 0.0:
			_refresh = REFRESH_SEC
			party.list(search.text)
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


## The rows of the last OnlinePlayers.
func _render() -> void:
	if _list == null:
		return
	Ui.clear(_list)
	_invite_buttons.clear()
	for p in party.model.players:
		_list.add_child(_row(p))
	var none: bool = party.model.players.is_empty()
	_empty.visible = none
	_empty.text = NOT_FOUND if search.text.strip_edges() != "" else EMPTY
	_render_buttons()


func _row(p: Dictionary) -> Control:
	var panel := LobbyUi.panel(12, 16, Color(1, 1, 1, 0.06))
	var row := Ui.hbox(14)
	panel.add_child(row)
	row.add_child(HeadIcon.make(str(p["characterId"]), str(p["displayName"]), 60))
	var col := Ui.vbox(2)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var name_label := LobbyUi.text(str(p["displayName"]), 26, Color.WHITE, true)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_label)
	var line := Ui.hbox(8)
	col.add_child(line)
	var level := int(p["level"])
	var lv := LobbyUi.text("Lv.%d" % level if level > 0 else "", 21, LobbyUi.GOLD, true)
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(lv)
	line.add_child(TierBadge.make(str(p["tier"]), int(p["division"]), 28))
	var rank := LobbyUi.text(RankModel.label(str(p["tier"]), int(p["division"])), 20, Ui.TEXT_DIM)
	rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(rank)
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
