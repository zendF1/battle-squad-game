extends Node
## The live match's chat (contract: the server's docs/contracts/chat.md, WebSocket part): the HUD's
## chat_send → ChatSend {text} (checked first: empty, the game data's length limit); ChatMessage →
## a HUD line "Tên: tin nhắn" (mine in gold; the sender's name from the message, else the match's
## players); ChatHistory {after} on entering the match and after each MatchStateSync (a reconnect),
## its messages deduplicated by id like the pushed ones; ChatError → a short Vietnamese toast over
## the HUD (social_text.gd). Lines never repeat and come in id order.

const ChatModel := preload("res://screens/social/chat_model.gd")
const SocialText := preload("res://screens/social/social_text.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const Ui := preload("res://ui/ui.gd")

var hud: Control # match/hud.gd
## func() -> Dictionary: playerId -> displayName of the match's players (a message without a name).
var names := Callable()
var me := ""
var socket: Object = null # GameSocket unless a test sets one
var messages: Array = [] # the match's messages shown, oldest first
var _shown := {} # id -> true


func _socket() -> Object:
	return socket if socket != null else GameSocket


func _ready() -> void:
	name = "MatchChat"
	if me == "":
		me = Session.player_id
	if hud != null:
		hud.chat_send.connect(send)
	if socket == null:
		GameSocket.event_received.connect(on_event)
	request_history()


## ChatHistory after the last message shown (all retained, the newest page, the first time).
func request_history() -> void:
	var last := ChatModel.last_id(messages)
	_socket().send("ChatHistory", {"after": last} if last > 0 else {})


func on_event(event: String, data: Variant) -> void:
	match event:
		"ChatMessage":
			take([ChatModel.parse_message(data)])
		"ChatHistory":
			take(ChatModel.parse_list(data))
		"ChatError":
			var code := str(data.get("code", "")) if data is Dictionary else ""
			_toast(SocialText.chat_code(code))
		"MatchStateSync":
			request_history() # back after a drop: what was missed


## Shows the messages not shown yet, in id order.
func take(list: Array) -> void:
	var fresh: Array = []
	for m in list:
		if m is Dictionary and not m.is_empty() and not _shown.has(int(m["id"])):
			fresh.append(m)
	if fresh.is_empty():
		return
	fresh.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
	var who: Dictionary = names.call() if names.is_valid() else {}
	for m in fresh:
		_shown[int(m["id"])] = true
		if hud != null:
			hud.add_chat_line(ChatModel.match_line(m, who, me))
	messages = ChatModel.merge(messages, fresh)


## The HUD's chat_send: ChatSend, or the toast of what stops it.
func send(text: String) -> void:
	var problem := ChatModel.text_problem(text, GameData.chat_max_length())
	if problem != "":
		_toast(problem)
		return
	_socket().send("ChatSend", {"text": ChatModel.clean(text)})


func _toast(text: String) -> void:
	if hud != null:
		Ui.toast(hud, text)


## playerId -> displayName of a match's players (BattlePlayerState by id).
static func names_of(players: Dictionary) -> Dictionary:
	var out := {}
	for id in players:
		var p = players[id]
		if p is Dictionary and p.get("displayName") is String:
			out[str(id)] = str(p["displayName"])
	return out
