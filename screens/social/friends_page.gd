extends VBoxContainer
## The Bạn bè page (the lobby's friends button, a Home page): three equal tabs centred, Bạn bè /
## Lời mời (with the count waiting) / Đã gửi, over one centred list. A friend: head, my nickname
## for them first (their own name small under it), level, and round picture buttons: Nhắn tin (the
## chat popup on our DM), Đổi biệt danh (a field; empty resets it), Mời vào guild (only while the
## guild page's hook accepts them, Router.social.can_invite_to_guild()), Xoá (asks first). A request
## to me: Đồng ý / Từ chối; mine: Huỷ. Loaded each time the page shows (Router.social.load_friends());
## errors are short Vietnamese toasts (social_text.gd).

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Modal := preload("res://ui/modal.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")
const FriendsModel := preload("res://screens/social/friends_model.gd")
const ChatModel := preload("res://screens/social/chat_model.gd")
const SocialGlyphs := preload("res://screens/social/social_glyphs.gd")
const ChatPopup := preload("res://screens/social/chat_popup.gd")

const LIST_W := 1100
const ROW_H := 96
const ACTION := 62
const RED := Color(0.85, 0.27, 0.27)
const GREEN := Color(0.2, 0.62, 0.32)

var overlay: Control # where dialogs and toasts go (Home)
var tab := FriendsModel.TAB_FRIENDS
var _tabs: Array[Button] = []
var _list: VBoxContainer
var _empty: Label
var _busy := {} # playerId -> true while an action on them runs


func _ready() -> void:
	name = "FriendsPage"
	add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(margin)
	var center := HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(center)
	var col := Ui.vbox(14)
	col.custom_minimum_size.x = LIST_W
	center.add_child(col)
	var tabs := Ui.hbox(12)
	tabs.name = "Tabs"
	col.add_child(tabs)
	_tabs = Ui.tab_row(FriendsModel.TABS, 26, show_tab, 60)
	for b in _tabs:
		tabs.add_child(b)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", LobbyUi.box(Color(0.04, 0.06, 0.16, 0.62), 18, 14))
	frame.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(frame)
	var stack := Control.new()
	frame.add_child(stack)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stack.add_child(scroll)
	_list = Ui.vbox(10)
	_list.name = "List"
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_empty = Ui.label("", 26)
	_empty.name = "Empty"
	_empty.add_theme_color_override("font_color", Ui.TEXT_DIM)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_empty.mouse_filter = MOUSE_FILTER_IGNORE
	stack.add_child(_empty)
	Router.social.friends_changed.connect(render)
	Router.social.guild_invite_changed.connect(render)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			Router.social.load_friends())
	render()


## Shows tab `which` (FriendsModel.TAB_FRIENDS, TAB_INCOMING, TAB_OUTGOING).
func show_tab(which: int) -> void:
	tab = clampi(which, 0, FriendsModel.TABS.size() - 1)
	Ui.select_tab(_tabs, tab)
	render()


func render() -> void:
	if _list == null:
		return
	var model: Dictionary = Router.social.friends
	for i in _tabs.size():
		var n := FriendsModel.tab_entries(model, i).size()
		_tabs[i].text = FriendsModel.TABS[i] + (" (%d)" % n if n > 0 else "")
	Ui.clear(_list)
	var entries := FriendsModel.tab_entries(model, tab)
	for e in entries:
		_list.add_child(_row(e))
	_empty.visible = entries.is_empty()
	if Router.social.friends_loading and not Router.social.friends_loaded:
		_empty.text = "Đang tải..."
	elif Router.social.friends_error != "" and not Router.social.friends_loaded:
		_empty.text = Router.social.friends_error
	else:
		_empty.text = FriendsModel.EMPTY[tab]


func _row(e: Dictionary) -> Control:
	var id := str(e["playerId"])
	var panel := PanelContainer.new()
	panel.name = "Row_" + id
	panel.add_theme_stylebox_override("panel", LobbyUi.box(Color(1, 1, 1, 0.06), 14, 10))
	panel.custom_minimum_size.y = ROW_H
	var row := Ui.hbox(16)
	panel.add_child(row)
	var head := HeadIcon.make(str(e.get("characterId", "")), FriendsModel.shown_name(e), 72)
	head.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(head)
	var names := Ui.vbox(0)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(names)
	var top := Ui.hbox(12)
	names.add_child(top)
	var shown := LobbyUi.text(FriendsModel.shown_name(e), 28, Color.WHITE, true)
	shown.name = "Name"
	top.add_child(shown)
	var lv := LobbyUi.text(ChatModel.level_text(int(e.get("level", 0))), 22, LobbyUi.GOLD, true)
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(lv)
	var real := FriendsModel.real_name(e)
	if real != "":
		var r := LobbyUi.text(real, 20, Ui.TEXT_DIM)
		r.name = "RealName"
		names.add_child(r)
	var actions := Ui.hbox(12)
	actions.name = "Actions"
	actions.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(actions)
	match tab:
		FriendsModel.TAB_FRIENDS:
			actions.add_child(_glyph_button("chat", "Nhắn tin", LobbyUi.ICON_COLORS["blue"], _message.bind(e)))
			actions.add_child(_glyph_button("pen", "Đổi biệt danh", LobbyUi.ICON_COLORS["purple"], _rename.bind(e)))
			if Router.social.can_invite_to_guild(id):
				actions.add_child(_glyph_button("banner", "Mời vào guild", LobbyUi.ICON_COLORS["orange"],
					func() -> void: Router.social.invite_to_guild(id, str(e.get("displayName", "")))))
			actions.add_child(_glyph_button("remove_friend", "Xoá bạn", RED, _confirm_remove.bind(e)))
		FriendsModel.TAB_INCOMING:
			actions.add_child(_icon_button("check", "Đồng ý", GREEN, _accept.bind(e)))
			actions.add_child(_icon_button("close", "Từ chối", RED, _remove.bind(e, "")))
		FriendsModel.TAB_OUTGOING:
			actions.add_child(_icon_button("close", "Huỷ lời mời", Color(0.36, 0.4, 0.52), _remove.bind(e, "")))
	for b in actions.get_children():
		(b as Button).disabled = _busy.has(id)
	return panel


func _glyph_button(kind: String, tip: String, bg: Color, on_press: Callable) -> Button:
	var b := SocialGlyphs.round_button(kind, ACTION, bg, tip)
	b.name = tip
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(on_press)
	return b


func _icon_button(icon_name: String, tip: String, bg: Color, on_press: Callable) -> Button:
	var b := LobbyUi.round_button(icon_name, ACTION, bg, 0.5)
	b.name = tip
	b.tooltip_text = tip
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(on_press)
	return b


func _host() -> Control:
	return overlay if overlay != null else self


func _message(e: Dictionary) -> void:
	ChatPopup.open_dm(_host(), e)


## Runs an action on `e` (a Router.social call returning "" or the toast), its row's buttons off
## meanwhile; `done` toasts on success ("" nothing).
func _run(e: Dictionary, call: Callable, done: String) -> void:
	var id := str(e["playerId"])
	if _busy.has(id):
		return
	_busy[id] = true
	render()
	var err: String = await call.call()
	_busy.erase(id)
	if not is_inside_tree():
		return
	render()
	if err != "" or done != "":
		Ui.toast(_host(), err if err != "" else done)


func _accept(e: Dictionary) -> void:
	_run(e, func(): return await Router.social.accept_friend(str(e["playerId"])), "Đã thành bạn bè")


func _remove(e: Dictionary, done: String) -> void:
	_run(e, func(): return await Router.social.remove_friend(str(e["playerId"])), done)


func _confirm_remove(e: Dictionary) -> void:
	var m := Modal.new()
	m.name = "ConfirmRemove"
	m.open(_host(), "Xoá bạn?", 640)
	m.add_text("%s sẽ không còn trong danh sách bạn bè của bạn." % FriendsModel.shown_name(e))
	m.add_button("Giữ lại", m.close)
	var go := m.add_button("Xoá", func() -> void:
		m.close()
		_remove(e, "Đã xoá bạn"))
	go.name = "ConfirmRemoveButton"


## Đổi biệt danh: a field with the current nickname (empty resets it to their name).
func _rename(e: Dictionary) -> void:
	var m := Modal.new()
	m.name = "Rename"
	m.open(_host(), "Đổi biệt danh", 680)
	m.add_close_x()
	var field := LineEdit.new()
	field.name = "Nickname"
	field.text = str(e.get("nickname", ""))
	field.placeholder_text = str(e.get("displayName", ""))
	field.custom_minimum_size.y = 64
	field.add_theme_font_size_override("font_size", 26)
	m.body.add_child(field)
	var save := func() -> void:
		m.set_busy(true)
		var err: String = await Router.social.set_nickname(str(e["playerId"]), field.text)
		if not is_instance_valid(m) or m.is_queued_for_deletion():
			return
		m.set_busy(false)
		if err != "":
			m.set_message(err)
			return
		m.close()
	field.text_submitted.connect(func(_t: String) -> void: save.call())
	m.add_button("Lưu", save).name = "Save"
