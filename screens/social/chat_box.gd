extends Button
## The lobby's chat box (bottom left): the newest lines of Thế giới and Bang hội (only in a guild)
## as "[Thế giới] Tên: tin nhắn", and an input-looking row; a tap opens the chat popup
## (pressed: lobby.gd). It polls both conversations through Router.social every
## GameData.chat_poll_sec() × ChatModel.LOBBY_FACTOR while the lobby shows, × BACKGROUND_FACTOR
## behind a lobby page, not at all with the app in the background; Home leaving (a match) frees it,
## which stops it. Back on the lobby it polls at once.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const ChatModel := preload("res://screens/social/chat_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")

var lines: RichTextLabel
var _wait := 0.0 # seconds to the next poll
var _focused := true


static func make(width: int, height: int) -> Button:
	var b = load("res://screens/social/chat_box.gd").new()
	b.custom_minimum_size = Vector2(width, height)
	return b


func _ready() -> void:
	name = "ChatBox"
	LobbyUi.texture_button(self, "panel", 0, true)
	var col := Ui.vbox(2)
	col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	col.offset_left = 14
	col.offset_top = 10
	col.offset_right = -14
	col.offset_bottom = -10
	add_child(col)
	lines = RichTextLabel.new()
	lines.name = "Lines"
	lines.bbcode_enabled = true
	lines.scroll_active = false
	lines.autowrap_mode = TextServer.AUTOWRAP_OFF
	lines.clip_contents = true
	lines.size_flags_vertical = SIZE_EXPAND_FILL
	lines.add_theme_font_size_override("normal_font_size", 18)
	lines.add_theme_constant_override("line_separation", 0)
	lines.add_theme_constant_override("outline_size", 4)
	lines.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.08, 0.85))
	col.add_child(lines)
	var input := LobbyUi.panel(0, 14, Color(0, 0, 0, 0.35))
	input.custom_minimum_size.y = 40
	col.add_child(input)
	var row := Ui.hbox(8)
	input.add_child(row)
	var hint := LobbyUi.text(ChatModel.PLACEHOLDER, 19, Ui.TEXT_DIM)
	hint.size_flags_horizontal = SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 12)
	indent.size_flags_horizontal = SIZE_EXPAND_FILL
	indent.add_child(hint)
	row.add_child(indent)
	var send := LobbyUi.panel(0, 14, LobbyUi.ICON_COLORS["blue"])
	send.custom_minimum_size = Vector2(56, 40)
	var arrow := LobbyUi.icon("send", 28)
	arrow.size_flags_horizontal = SIZE_SHRINK_CENTER
	send.add_child(arrow)
	row.add_child(send)
	for c in [col, lines, input, row, indent, hint, send, arrow]:
		c.mouse_filter = MOUSE_FILTER_IGNORE
	Router.social.feed_changed.connect(func(_k: String) -> void: render())
	Router.social.guild_changed.connect(_on_guild_changed)
	Router.social.load_guild()
	render()


## The newest lines of the lobby's conversations.
func render() -> void:
	var convs: Array = [Router.social.messages(ChatModel.WORLD)]
	if Router.social.guild_id != "":
		convs.append(Router.social.messages(ChatModel.key(ChatModel.GUILD, Router.social.guild_id)))
	var shown := ChatModel.box_lines(convs, Session.player_id)
	if shown.is_empty():
		lines.text = "[color=#%s]%s[/color]" % [Ui.TEXT_DIM.to_html(), ChatModel.NO_MESSAGES]
	else:
		lines.text = "\n".join(shown.map(ChatModel.bbcode))


func _on_guild_changed() -> void:
	_wait = 0.0 # the guild's lines at once
	render()


## Seconds between polls now (0: no timed polling).
func interval() -> float:
	if not _focused:
		return 0.0
	return ChatModel.poll_interval(GameData.chat_poll_sec(),
		ChatModel.LOBBY_FACTOR if is_visible_in_tree() else ChatModel.BACKGROUND_FACTOR)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	var every := interval()
	_wait = every if every > 0.0 else INF
	poll_now()


func poll_now() -> void:
	Router.social.poll(ChatModel.WORLD)
	if Router.social.guild_id != "":
		Router.social.poll(ChatModel.GUILD, Router.social.guild_id)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_wait = 0.0
		NOTIFICATION_VISIBILITY_CHANGED:
			if is_visible_in_tree():
				_wait = 0.0 # back on the lobby: fresh lines at once
