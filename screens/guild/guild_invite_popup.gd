extends "res://ui/modal.gd"
## "Mời vào bang" (the guild page's Mời, leader / deputy): a name search over the online players
## (the party's ListOnlinePlayers / OnlinePlayers through Router.party, like the teammate invite
## popup screens/home/invite_popup.gd), my guild's members left out; each row has head, name,
## "Lv.N" and "Mời", which sends POST /guilds/{id}/invite (GuildState.invite()) and turns into
## "Đã mời" once sent. Refreshed every REFRESH_SEC while open.

const GuildModel := preload("res://screens/guild/guild_model.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")

const DEBOUNCE := 0.4
const REFRESH_SEC := 5.0
const LIST_H := 430
const EMPTY := "Chưa có ai khác đang online"
const NOT_FOUND := "Không tìm thấy người chơi"

var party # Router.party (screens/home/party.gd)
var search: LineEdit
var _list: VBoxContainer
var _empty: Label
var _sent := {} # playerId -> true once invited
var _debounce := -1.0
var _refresh := REFRESH_SEC


## Opens over `host` for `p` (Router.party) and asks for the list.
func open_for(host: Node, p) -> void:
	party = p
	open(host, "Mời vào bang", 780)
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


## The online players who are not in my guild yet.
static func rows(players: Array, guild: Dictionary) -> Array:
	var members := {}
	for m in guild.get("members", []):
		members[m["player_id"]] = true
	return players.filter(func(p): return not members.has(str(p.get("playerId", ""))))


func _render() -> void:
	if _list == null:
		return
	Ui.clear(_list)
	var shown := rows(party.model.players, GuildState.guild)
	for p in shown:
		_list.add_child(_row(p))
	_empty.visible = shown.is_empty()
	_empty.text = NOT_FOUND if search.text.strip_edges() != "" else EMPTY


func _row(p: Dictionary) -> Control:
	var id := str(p["playerId"])
	var panel := LobbyUi.panel(12, 16, Color(1, 1, 1, 0.06))
	var row := Ui.hbox(14)
	panel.add_child(row)
	var head = HeadIcon.make(str(p["characterId"]), str(p["displayName"]), 60)
	row.add_child(head)
	var name_label := LobbyUi.text(str(p["displayName"]), 26, Color.WHITE, true)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(name_label)
	var level := int(p["level"])
	var lv := LobbyUi.text("Lv.%d" % level if level > 0 else "", 22, LobbyUi.GOLD, true)
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lv)
	var b := Ui.button("Đã mời" if _sent.has(id) else "Mời", 24)
	b.name = "Invite_" + id
	b.custom_minimum_size = Vector2(170, 64)
	b.focus_mode = FOCUS_NONE
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	b.disabled = _sent.has(id)
	b.pressed.connect(func() -> void: _invite(id, b))
	row.add_child(b)
	return panel


func _invite(id: String, b: Button) -> void:
	b.disabled = true
	var res: Dictionary = await GuildState.invite(id)
	if not is_instance_valid(b):
		return
	if res.ok:
		_sent[id] = true
		b.text = "Đã mời"
	else:
		b.disabled = false
		set_message(GuildModel.error_text(res, "invite"))
