extends "res://tests/test_case.gd"
## The chat and friends screens built headless over a fake Router.social: the chat popup's three
## equal tabs, the locked guild tab, the friends list → DM, one card height on every tab; the player
## card's actions; the friends page's tabs and row actions; the Kết bạn button's states.

const Social := preload("res://screens/social/social.gd")
const ChatPopup := preload("res://screens/social/chat_popup.gd")
const PlayerCard := preload("res://screens/social/player_card.gd")
const FriendsPage := preload("res://screens/social/friends_page.gd")
const FriendButton := preload("res://screens/social/friend_button.gd")
const FriendsModel := preload("res://screens/social/friends_model.gd")


class NoApi:
	extends RefCounted
	func get_json(_p: String) -> Dictionary:
		return {"ok": false, "status": 0, "code": "NETWORK_ERROR", "message": "offline", "data": null}
	func post_json(_p: String, _b: Variant = {}) -> Dictionary:
		return get_json("")
	func request(_m: int, _p: String, _b: Variant = null) -> Dictionary:
		return get_json("")


const LIST := {
	"friends": [{"playerId": "a1", "displayName": "SấmSét", "nickname": "Bạn thân", "level": 12, "characterId": "rookie"}],
	"incoming": [{"playerId": "d4", "displayName": "Mây", "level": 7, "characterId": "tide"}],
	"outgoing": [{"playerId": "o5", "displayName": "Đá", "level": 1, "characterId": ""}],
}

var _old_social: Node
var _old_player := ""
var _host: Control


func _setup(guild: String = "") -> Node:
	_old_social = Router.social
	_old_player = Session.player_id
	Session.player_id = "me"
	var s: Node = Social.new()
	s.api = NoApi.new()
	s._check_player()
	s.friends = FriendsModel.parse(LIST)
	s.friends_loaded = true
	s.set_guild(guild)
	s.take("world", [{"id": 1, "channel": "world", "playerId": "p2", "displayName": "Hai", "level": 3, "characterId": "", "text": "chào"},
		{"id": 2, "channel": "world", "playerId": "me", "displayName": "Tôi", "level": 9, "characterId": "rookie", "text": "hi"}])
	Router.social = s
	_host = Control.new()
	_host.size = Vector2(1600, 900)
	return s


func _teardown(s: Node) -> void:
	Router.social = _old_social
	Session.player_id = _old_player
	_host.free()
	s.free()


static func _visible_named(n: Node, prefix: String) -> Array:
	return n.find_children(prefix + "*", "", true, false).filter(func(c): return c is CanvasItem and c.visible)


func test_chat_popup_tabs() -> void:
	var s := _setup()
	var p = ChatPopup.open_on(_host, ChatPopup.TAB_WORLD)
	eq(p._tabs.size(), 3, "three tabs")
	for b in p._tabs:
		check(b.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "equal tabs")
	eq(p._list.get_child_count(), 2, "the world's two messages")
	check(p._input_row.visible, "an input under a conversation")
	eq(p.input.max_length, 500, "the game data's limit")
	var world_h: float = p._stack.custom_minimum_size.y + p.INPUT_H + p.GAP
	p.show_tab(ChatPopup.TAB_GUILD)
	check(p._locked.visible, "no guild: the lock picture")
	check(not p._input_row.visible, "nothing to type into")
	eq(p._stack.custom_minimum_size.y, world_h, "the list takes the input's room: one card height")
	p.show_tab(ChatPopup.TAB_FRIENDS)
	eq(p._list.get_child_count(), 1, "the friends")
	eq(str(p._list.get_child(0).name), "Friend_a1", "a friend row")
	p.show_dm(s.friends["friends"][0])
	check(p._dm_bar.visible, "the DM's bar")
	eq(p._dm_name.text, "Bạn thân", "the nickname first")
	eq(p.conversation(), ["dm", "a1"], "the DM's conversation")
	eq(p._stack.custom_minimum_size.y + p.BAR_H + p.GAP + p.INPUT_H + p.GAP, world_h, "the bar takes list room: same height")
	_teardown(s)


func test_chat_popup_guild_tab_with_a_guild() -> void:
	var s := _setup("g-1")
	var p = ChatPopup.open_on(_host, ChatPopup.TAB_GUILD)
	check(not p._locked.visible, "in a guild: its conversation")
	eq(p.conversation(), ["guild", "g-1"], "the guild's id as target")
	_teardown(s)


func test_player_card_actions() -> void:
	var s := _setup()
	var stranger = PlayerCard.open_for(_host, {"playerId": "p2", "displayName": "Hai", "level": 3, "characterId": ""})
	stranger.befriend._ready()
	check(stranger.befriend.visible, "Kết bạn for a stranger")
	check(not stranger.message_button.visible, "no DM without friendship")
	check(not stranger.guild_button.visible, "no guild hook: no invite")
	var friend = PlayerCard.open_for(_host, {"playerId": "a1", "displayName": "SấmSét", "level": 12, "characterId": ""})
	friend.befriend._ready()
	check(not friend.befriend.visible, "a friend: no Kết bạn")
	check(friend.message_button.visible, "Nhắn tin")
	s.set_guild_invite(func(_i: String, _n: String) -> void: pass)
	check(friend.guild_button.visible, "the guild page's hook: Mời vào guild")
	_teardown(s)


func test_friend_button_states() -> void:
	var s := _setup()
	var cases := {"p9": [true, false, "request"], "o5": [true, true, ""], "d4": [true, false, "accept"], "a1": [false, true, ""], "me": [false, true, ""]}
	for id in cases:
		var b: Button = FriendButton.make({"playerId": id}, 56)
		_host.add_child(b)
		b._ready()
		eq([b.visible, b.disabled, b.state["action"]], cases[id], "the button for " + id)
	_teardown(s)


func test_friends_page() -> void:
	var s := _setup()
	var page = FriendsPage.new()
	_host.add_child(page)
	page._ready()
	eq(page._tabs.map(func(b): return b.text), ["Bạn bè (1)", "Lời mời (1)", "Đã gửi (1)"], "tabs with their counts")
	var row: Node = page._list.get_child(0)
	eq(row.find_child("Actions", true, false).get_children().map(func(c): return str(c.name)), ["Nhắn tin", "Đổi biệt danh", "Xoá bạn"], "a friend's actions")
	check(row.find_child("RealName", true, false) != null, "their name under the nickname")
	s.set_guild_invite(func(_i: String, _n: String) -> void: pass)
	row = page._list.get_child(0)
	check(row.find_child("Actions", true, false).has_node("Mời vào guild"), "the guild hook adds Mời vào guild")
	page.show_tab(FriendsModel.TAB_INCOMING)
	eq(page._list.get_child(0).find_child("Actions", true, false).get_children().map(func(c): return str(c.name)), ["Đồng ý", "Từ chối"], "a request to me")
	page.show_tab(FriendsModel.TAB_OUTGOING)
	eq(page._list.get_child(0).find_child("Actions", true, false).get_children().map(func(c): return str(c.name)), ["Huỷ lời mời"], "my request")
	_teardown(s)
