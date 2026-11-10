extends Button
## "Kết bạn" for a player shown somewhere (the online players list, a leaderboard showcase, a match
## result's row, the chat player card): the add-friend picture (social_glyphs.gd) on a round green
## button, or with `wide` the picture and the words. It follows my relation to them
## (Router.social, FriendsModel.friend_button()): hidden for a friend and for myself, "Đã gửi" off
## after my request, "Đồng ý" when they asked me. A press sends the request (or accepts) and
## toasts the result over `toast_host` (the screen when unset).

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const FriendsModel := preload("res://screens/social/friends_model.gd")
const SocialText := preload("res://screens/social/social_text.gd")
const SocialGlyphs := preload("res://screens/social/social_glyphs.gd")

const GREEN := Color(0.2, 0.62, 0.32)
const OFF := Color(0.3, 0.34, 0.45)

var player_id := ""
var entry := {} # {displayName, level, characterId}: shown in Đã gửi until the list reloads
var wide := false
var toast_host: Control
var state := {}
var _busy := false
var _glyph: Control


## A Kết bạn button for `p` ({playerId, displayName, level, characterId}), `px` high.
static func make(p: Dictionary, px: int = 56, is_wide: bool = false) -> Button:
	var b = load("res://screens/social/friend_button.gd").new()
	b.player_id = str(p.get("playerId", ""))
	b.entry = {"displayName": str(p.get("displayName", "")), "level": int(p.get("level", 0)),
		"characterId": str(p.get("characterId", ""))}
	b.wide = is_wide
	b.name = "Befriend_" + b.player_id
	b.custom_minimum_size = Vector2(px, px)
	return b


func _ready() -> void:
	focus_mode = FOCUS_NONE
	size_flags_vertical = SIZE_SHRINK_CENTER
	var px := custom_minimum_size.y
	if wide:
		SocialGlyphs.wide_button("add_friend", "Kết bạn", GREEN, int(px), self)
		_glyph = get_node("Content/Glyph")
	else:
		_glyph = SocialGlyphs.glyph("add_friend", int(px * (1.0 - 2.0 * SocialGlyphs.INSET)))
		_glyph.name = "Glyph"
		_glyph.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var inset := roundf(px * SocialGlyphs.INSET)
		_glyph.offset_left = inset
		_glyph.offset_top = inset
		_glyph.offset_right = -inset
		_glyph.offset_bottom = -inset
		add_child(_glyph)
	pressed.connect(_on_pressed)
	Router.social.friends_changed.connect(render)
	Router.social.need_friends()
	render()


## Shows the relation now.
func render() -> void:
	state = FriendsModel.friend_button(Router.social.relation(player_id))
	visible = state["visible"]
	disabled = state["disabled"] or _busy
	tooltip_text = state["tip"]
	if wide:
		SocialGlyphs.set_words(self, str(state["text"]))
	var bg := OFF if state["disabled"] else GREEN
	LobbyUi.style_button(self, bg, int(custom_minimum_size.y / 2), 0, Color(1, 1, 1, 0.85), 3)
	_glyph.modulate = Color(1, 1, 1, 0.6) if state["disabled"] else Color.WHITE


func _on_pressed() -> void:
	if _busy or state.get("action", "") == "":
		return
	_busy = true
	disabled = true
	var action: String = state["action"]
	var err: String
	if action == "accept":
		err = await Router.social.accept_friend(player_id)
	else:
		err = await Router.social.request_friend(player_id, entry)
	if not is_inside_tree():
		return
	_busy = false
	render()
	Ui.toast(toast_host if is_instance_valid(toast_host) else screen_root(self),
		err if err != "" else (SocialText.ACCEPTED if action == "accept" else SocialText.SENT))


## The outermost Control above `c` (the screen: a toast there shows over its dialogs).
static func screen_root(c: Control) -> Control:
	var at: Control = c
	while at.get_parent() is Control:
		at = at.get_parent()
	return at


## A round Kết bạn for `p` in a dialog's top-left corner (ui/modal.gd), mirroring its close X in
## the top-right one (add_close_x() first: the title already keeps clear of both corners).
static func corner(modal: Control, p: Dictionary) -> Button:
	var x: Button = modal.close_x
	var b := make(p, int(x.custom_minimum_size.y))
	b.set_anchors_preset(PRESET_TOP_LEFT)
	b.offset_left = -x.offset_right
	b.offset_right = b.offset_left + x.custom_minimum_size.x
	b.offset_top = x.offset_top
	b.offset_bottom = x.offset_bottom
	b.toast_host = modal
	x.get_parent().add_child(b)
	return b


## Kết bạn at the end of a centred `row` (a name row); with `balance` an empty block as wide at its
## start (shown while the button is), so what is between stays centred.
static func add_mirrored(row: HBoxContainer, p: Dictionary, px: int, balance: bool) -> Button:
	var b := make(p, px)
	row.add_child(b)
	if balance:
		var pad := Control.new()
		pad.name = "FriendPad"
		pad.custom_minimum_size = Vector2(px, px)
		pad.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(pad)
		row.move_child(pad, 0)
		b.visibility_changed.connect(func() -> void: pad.visible = b.visible)
	return b
