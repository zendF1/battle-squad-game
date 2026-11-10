extends "res://ui/modal.gd"
## A small player card (a tap on a chat sender): their head, name and level centred, then one
## centred row of actions: Kết bạn (friend_button.gd, following the relation), Nhắn tin (only a
## friend: DMs need the friendship; message_pressed with their friend entry) and Mời vào guild (only
## while the guild page's hook accepts them: Router.social.can_invite_to_guild()). The X or a tap
## outside closes it.

signal message_pressed(friend: Dictionary)

const HeadIcon := preload("res://screens/home/head_icon.gd")
const FriendButton := preload("res://screens/social/friend_button.gd")
const FriendsModel := preload("res://screens/social/friends_model.gd")
const ChatModel := preload("res://screens/social/chat_model.gd")
const SocialGlyphs := preload("res://screens/social/social_glyphs.gd")

const WIDTH := 640
const BUTTON_H := 64

var player := {} # {playerId, displayName, level, characterId}
var befriend: Button
var message_button: Button
var guild_button: Button


## Opens over `host` for `p` ({playerId, displayName, level, characterId}).
static func open_for(host: Node, p: Dictionary):
	var m = load("res://screens/social/player_card.gd").new()
	m.name = "PlayerCard"
	m.player = p
	m.open(host, str(p.get("displayName", "")), WIDTH)
	m.add_close_x()
	m.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m._build()
	return m


func _build() -> void:
	var head := HeadIcon.make(str(player.get("characterId", "")), str(player.get("displayName", "")), 120)
	head.size_flags_horizontal = SIZE_SHRINK_CENTER
	head.lobby = true
	body.add_child(head)
	var lv := LobbyUi.text(ChatModel.level_text(int(player.get("level", 0))), 26, LobbyUi.GOLD, true)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.visible = lv.text != ""
	body.add_child(lv)
	var actions := row(0)
	actions.name = "Actions"
	befriend = FriendButton.make(player, BUTTON_H, true)
	befriend.toast_host = self
	actions.add_child(befriend)
	message_button = _action("chat", "Nhắn tin", LobbyUi.ICON_COLORS["blue"], func() -> void:
		var f := FriendsModel.friend(Router.social.friends, str(player["playerId"]))
		close()
		message_pressed.emit(f if not f.is_empty() else player))
	message_button.name = "Message"
	actions.add_child(message_button)
	guild_button = _action("banner", "Mời vào guild", LobbyUi.ICON_COLORS["purple"], func() -> void:
		Router.social.invite_to_guild(str(player["playerId"]), str(player.get("displayName", ""))))
	guild_button.name = "GuildInvite"
	actions.add_child(guild_button)
	Router.social.friends_changed.connect(render)
	Router.social.guild_invite_changed.connect(render)
	render()


## A wide action button: the picture of `kind` and the words.
func _action(kind: String, words: String, bg: Color, on_press: Callable) -> Button:
	var b := SocialGlyphs.wide_button(kind, words, bg, BUTTON_H)
	b.pressed.connect(on_press)
	return b


func render() -> void:
	var id := str(player.get("playerId", ""))
	message_button.visible = Router.social.relation(id) == FriendsModel.FRIEND
	guild_button.visible = Router.social.can_invite_to_guild(id)
