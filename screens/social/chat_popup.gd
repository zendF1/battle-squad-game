extends "res://ui/modal.gd"
## The chat popup (a tap on the lobby's chat box, Nhắn tin on a friend): three equal tabs, Thế giới
## / Bang hội / Bạn bè. Thế giới and Bang hội show their conversation (chat_row.gd: head, name,
## level, time, text; a tap on someone else's head or name opens their player card,
## player_card.gd); Bang hội without a guild shows the lock picture instead. Bạn bè lists the
## friends (head, nickname first, level); a tap opens the DM with that friend (a back arrow returns to
## the list). Under a conversation: the input (the game data's length limit) and the send button;
## Enter sends too. Only the conversation on screen polls, every GameData.chat_poll_sec() and at once
## when opened (Router.social: deduplicated by id, backing off after a 429) and scrolls to the newest line when it was at the bottom. Errors are short
## Vietnamese toasts (social_text.gd). The X or a tap outside closes it.

const ChatModel := preload("res://screens/social/chat_model.gd")
const FriendsModel := preload("res://screens/social/friends_model.gd")
const ChatRow := preload("res://screens/social/chat_row.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")
const SocialGlyphs := preload("res://screens/social/social_glyphs.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const WIDTH := 1080
const LIST_H := 440 # the list's height over the input (the card keeps one height on every tab)
const GAP := 12 # between the body's rows
const INPUT_H := 64
const BAR_H := 48 # the DM's back arrow, head and name
const TABS := ["Thế giới", "Bang hội", "Bạn bè"]
const TAB_WORLD := 0
const TAB_GUILD := 1
const TAB_FRIENDS := 2
const NO_GUILD := "Bạn chưa vào bang hội"
const NO_FRIENDS := "Chưa có bạn bè để nhắn tin"

var tab := TAB_WORLD
var dm := {} # the friend whose conversation shows on the Bạn bè tab; {} the friends list
var host_node: Node
var input: LineEdit
var send_button: Button
var _tabs: Array[Button] = []
var _scroll: ScrollContainer
var _list: VBoxContainer
var _dm_bar: HBoxContainer
var _dm_head: Control
var _dm_name: Label
var _locked: VBoxContainer
var _stack: Control
var _input_row: HBoxContainer
var _empty: Label
var _shown_key := "" # the conversation the list shows
var _shown_last := -1 # its last id rendered
var _wait := 0.0
var _sending := false


## Opens over `host` on tab `which`.
static func open_on(host: Node, which: int = TAB_WORLD):
	var p = load("res://screens/social/chat_popup.gd").new()
	p.name = "ChatPopup"
	p.host_node = host
	p.open(host, "Chat", WIDTH)
	p.add_close_x()
	p._build()
	p.show_tab(which)
	return p


## Opens over `host` on the DM with `friend` (a FriendsModel entry).
static func open_dm(host: Node, friend: Dictionary):
	var p = open_on(host, TAB_FRIENDS)
	p.show_dm(friend)
	return p


func _build() -> void:
	body.add_theme_constant_override("separation", GAP)
	var tabs := Ui.hbox(12)
	tabs.name = "Tabs"
	body.add_child(tabs)
	_tabs = Ui.tab_row(TABS, 26, show_tab, 60)
	for b in _tabs:
		tabs.add_child(b)
	_dm_bar = Ui.hbox(12)
	_dm_bar.name = "DmBar"
	body.add_child(_dm_bar)
	var back := LobbyUi.round_button("arrow_left", BAR_H, Color(0.05, 0.08, 0.2, 0.8), 0.5)
	back.name = "Back"
	back.tooltip_text = "Danh sách bạn bè"
	back.pressed.connect(func() -> void: show_dm({}))
	_dm_bar.add_child(back)
	_dm_head = HeadIcon.make("", "", BAR_H)
	_dm_bar.add_child(_dm_head)
	_dm_name = LobbyUi.text("", 26, Color.WHITE, true)
	_dm_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dm_bar.add_child(_dm_name)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", LobbyUi.box(Color(0, 0, 0, 0.28), 14, 10))
	body.add_child(frame)
	_stack = Control.new()
	_stack.custom_minimum_size = Vector2(0, LIST_H)
	frame.add_child(_stack)
	var stack := _stack
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stack.add_child(_scroll)
	_list = Ui.vbox(10)
	_list.name = "List"
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_empty = Ui.label("", 24)
	_empty.name = "Empty"
	_empty.add_theme_color_override("font_color", Ui.TEXT_DIM)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_empty.mouse_filter = MOUSE_FILTER_IGNORE
	stack.add_child(_empty)
	_locked = Ui.vbox(14)
	_locked.name = "Locked"
	_locked.alignment = BoxContainer.ALIGNMENT_CENTER
	_locked.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_locked.mouse_filter = MOUSE_FILTER_IGNORE
	_locked.add_child(SocialGlyphs.glyph("lock", 120))
	var why := Ui.label(NO_GUILD, 26)
	why.add_theme_color_override("font_color", Ui.TEXT_DIM)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_locked.add_child(why)
	stack.add_child(_locked)
	_input_row = Ui.hbox(12)
	_input_row.name = "InputRow"
	body.add_child(_input_row)
	input = LineEdit.new()
	input.name = "Input"
	input.placeholder_text = ChatModel.INPUT_HINT
	input.max_length = GameData.chat_max_length() # 0: no limit known
	input.custom_minimum_size.y = INPUT_H
	input.size_flags_horizontal = SIZE_EXPAND_FILL
	input.add_theme_font_size_override("font_size", 26)
	input.text_submitted.connect(func(_t: String) -> void: send())
	_input_row.add_child(input)
	send_button = LobbyUi.round_button("send", INPUT_H, LobbyUi.ICON_COLORS["blue"], 0.55)
	send_button.name = "Send"
	send_button.tooltip_text = "Gửi"
	send_button.pressed.connect(send)
	_input_row.add_child(send_button)
	Router.social.feed_changed.connect(_on_feed_changed)
	Router.social.friends_changed.connect(_on_friends_changed)
	Router.social.guild_changed.connect(render)
	Router.social.load_guild()


## Shows tab `which` (TAB_WORLD, TAB_GUILD, TAB_FRIENDS); Bạn bè opens on the list.
func show_tab(which: int) -> void:
	tab = clampi(which, 0, TABS.size() - 1)
	Ui.select_tab(_tabs, tab)
	dm = {}
	if tab == TAB_FRIENDS:
		Router.social.load_friends()
	render()
	_poll_now(true)


## The DM with `friend` on the Bạn bè tab ({} back to the list).
func show_dm(friend: Dictionary) -> void:
	tab = TAB_FRIENDS
	Ui.select_tab(_tabs, tab)
	dm = friend
	render()
	_poll_now(true)


## The conversation on screen: [channel, target]; [] none (the friends list, Bang hội without a guild).
func conversation() -> Array:
	match tab:
		TAB_WORLD:
			return [ChatModel.WORLD, ""]
		TAB_GUILD:
			return [ChatModel.GUILD, Router.social.guild_id] if Router.social.guild_id != "" else []
	return [ChatModel.DM, str(dm["playerId"])] if not dm.is_empty() else []


func render() -> void:
	if _list == null:
		return
	var conv := conversation()
	var friends_list := tab == TAB_FRIENDS and dm.is_empty()
	var locked := tab == TAB_GUILD and conv.is_empty()
	_locked.visible = locked
	_dm_bar.visible = tab == TAB_FRIENDS and not dm.is_empty()
	_input_row.visible = not conv.is_empty()
	# the list takes the room of what is hidden: the card's height stays
	_stack.custom_minimum_size.y = LIST_H + (0 if _input_row.visible else INPUT_H + GAP) - (BAR_H + GAP if _dm_bar.visible else 0)
	if _dm_bar.visible:
		_dm_head.initial = FriendsModel.shown_name(dm).left(1).to_upper()
		_dm_head.character_id = str(dm.get("characterId", "")) # (redraws)
		_dm_name.text = FriendsModel.shown_name(dm)
	if friends_list:
		_render_friends()
	elif locked:
		Ui.clear(_list)
		_shown_key = ""
		_empty.visible = false
	else:
		_render_messages(ChatModel.key(conv[0], conv[1]), true)


func _render_messages(feed_key: String, force: bool) -> void:
	var msgs: Array = Router.social.messages(feed_key)
	var last := ChatModel.last_id(msgs)
	if not force and feed_key == _shown_key and last == _shown_last:
		return
	var at_bottom := _scroll.scroll_vertical >= int(_scroll.get_v_scroll_bar().max_value - _scroll.size.y) - 8
	var fresh := feed_key != _shown_key
	_shown_key = feed_key
	_shown_last = last
	Ui.clear(_list)
	for m in msgs:
		_list.add_child(ChatRow.make(m, str(m["playerId"]) == Session.player_id, _open_card))
	var err: String = Router.social.feed_error(feed_key)
	_empty.visible = msgs.is_empty()
	_empty.text = err if err != "" else ChatModel.NO_MESSAGES
	if fresh or at_bottom:
		_scroll_to_end()


func _scroll_to_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _render_friends() -> void:
	_shown_key = ""
	Ui.clear(_list)
	var list: Array = Router.social.friends.get("friends", [])
	for f in list:
		_list.add_child(_friend_row(f))
	_empty.visible = list.is_empty()
	if Router.social.friends_loading and list.is_empty():
		_empty.text = "Đang tải..."
	else:
		_empty.text = Router.social.friends_error if Router.social.friends_error != "" else NO_FRIENDS


## A friend of the Bạn bè tab: head, nickname (or name), level, the chat picture; a tap opens the DM.
func _friend_row(f: Dictionary) -> Control:
	var b := Button.new()
	b.name = "Friend_" + str(f["playerId"])
	b.focus_mode = FOCUS_NONE
	LobbyUi.style_button(b, Color(1, 1, 1, 0.06), 12, 10)
	b.custom_minimum_size = Vector2(0, 76)
	b.pressed.connect(show_dm.bind(f))
	var row := Ui.hbox(14)
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(row)
	var head := HeadIcon.make(str(f.get("characterId", "")), FriendsModel.shown_name(f), 56)
	head.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(head)
	var n := LobbyUi.text(FriendsModel.shown_name(f), 26, Color.WHITE, true)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(n)
	var lv := LobbyUi.text(ChatModel.level_text(int(f.get("level", 0))), 20, LobbyUi.GOLD, true)
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv.mouse_filter = MOUSE_FILTER_IGNORE
	lv.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(lv)
	row.add_child(SocialGlyphs.glyph("chat", 44))
	return b


func _on_feed_changed(feed_key: String) -> void:
	if feed_key == _shown_key:
		_render_messages(feed_key, false)
		if Router.social.messages(feed_key).is_empty():
			_empty.text = Router.social.feed_error(feed_key) if Router.social.feed_error(feed_key) != "" else ChatModel.NO_MESSAGES


func _on_friends_changed() -> void:
	if tab == TAB_FRIENDS and dm.is_empty():
		_render_friends()


## The player card of a message's sender.
func _open_card(m: Dictionary) -> void:
	var Card = load("res://screens/social/player_card.gd")
	var card = Card.open_for(host_node if host_node != null else get_parent(),
		{"playerId": str(m["playerId"]), "displayName": ChatModel.sender_name(m), "level": int(m.get("level", 0)),
			"characterId": str(m.get("characterId", ""))})
	card.message_pressed.connect(func(friend: Dictionary) -> void: show_dm(friend))


func send() -> void:
	var conv := conversation()
	if conv.is_empty() or _sending:
		return
	var problem := ChatModel.text_problem(input.text, GameData.chat_max_length())
	if problem != "":
		Ui.toast(self, problem)
		return
	_sending = true
	send_button.disabled = true
	var err: String = await Router.social.send(conv[0], conv[1], input.text)
	if not is_inside_tree():
		return
	_sending = false
	send_button.disabled = false
	if err != "":
		Ui.toast(self, err)
		return
	input.clear()
	_scroll_to_end()


## Polls the open conversation (`now`: just opened, not held back by the last poll's spacing).
func _poll_now(now: bool = false) -> void:
	_wait = ChatModel.poll_interval(GameData.chat_poll_sec())
	if _wait <= 0.0:
		_wait = INF
	var conv := conversation()
	if not conv.is_empty():
		Router.social.poll(conv[0], conv[1], now)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_poll_now()
