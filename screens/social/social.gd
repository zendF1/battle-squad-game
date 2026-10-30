extends Node
## Chat and friends state that outlives the scenes (Router.social): the REST conversations
## (ChatModel: Thế giới, Bang hội, a friend's DM), the friends list (FriendsModel), my guild's id
## (the Bang hội conversation's target) and the guild page's "Mời vào guild" hook. Requests go
## through `api` (the Api autoload; tests put a fake there). One request per conversation at a
## time: a poll asked while one runs is dropped (the next tick asks again). Another account signing
## in on the device drops everything held.
##
## Guild hook (feat/social-guild): set_guild_invite(action, allowed) with
## action: func(player_id: String, display_name: String) -> void (sends the guild invite, toasts)
## and allowed (optional): func(player_id: String) -> bool (I may invite and they are not in my
## guild). While an action is set, the friends rows and the chat player card show "Mời vào guild"
## for the players `allowed` accepts. set_guild(id) tells the chat my guild changed (created,
## joined, left: "" none) without waiting for its own GET /guilds/me.

signal friends_changed # the list, its loading or its error changed
signal feed_changed(key: String) # a conversation got messages (or its error changed)
signal guild_changed # my guild's id is known or changed
signal guild_invite_changed # the guild page set or cleared its hook

const ChatModel := preload("res://screens/social/chat_model.gd")
const FriendsModel := preload("res://screens/social/friends_model.gd")
const SocialText := preload("res://screens/social/social_text.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const GameData := preload("res://autoload/game_data_model.gd")

var api: Object = null # Api unless a test sets one

var friends := {} # FriendsModel.parse(); {} until loaded
var friends_loading := false
var friends_error := ""
var friends_loaded := false
var guild_id := "" # my guild ("" none)
var guild_known := false # GET /guilds/me answered (or set_guild() was called)

var guild_invite := Callable()
var guild_invite_allowed := Callable()

var _feeds := {} # key -> {messages: Array, error: String}
var _in_flight := {} # key -> true while its GET runs
var _next_ok := {} # key -> Time.get_ticks_msec() before which a timed poll is skipped
var _backoff := {} # key -> its backoff factor after a 429 (ChatModel.next_backoff())
var _player := ""
var _friends_asked := false
var _guild_asking := false


func _api() -> Object:
	return api if api != null else Api


## Drops what another account left (a new sign-in on this device).
func _check_player() -> void:
	if _player == Session.player_id:
		return
	_player = Session.player_id
	friends = {}
	friends_loaded = false
	friends_error = ""
	guild_id = ""
	guild_known = false
	_feeds.clear()


## Signed out (core/logout.gd): drops the conversations, the friends list, my guild's id and the
## polls' state, so the next sign-in starts empty (the guild page's hook stays: it is not the
## account's). No signal: the scene goes to Login.
func reset_account() -> void:
	_player = ""
	friends = {}
	friends_loading = false
	friends_loaded = false
	friends_error = ""
	guild_id = ""
	guild_known = false
	_feeds.clear()
	_in_flight.clear()
	_next_ok.clear()
	_backoff.clear()
	_friends_asked = false
	_guild_asking = false


# ── Guild hook ──────────────────────────────────────────────────────────────

## The guild page's "Mời vào guild" (see the file's header); Callable() clears it.
func set_guild_invite(action: Callable, allowed: Callable = Callable()) -> void:
	guild_invite = action
	guild_invite_allowed = allowed
	guild_invite_changed.emit()


## Shows "Mời vào guild" for `player_id`.
func can_invite_to_guild(player_id: String) -> bool:
	if not guild_invite.is_valid() or player_id == "" or player_id == Session.player_id:
		return false
	return not guild_invite_allowed.is_valid() or bool(guild_invite_allowed.call(player_id))


func invite_to_guild(player_id: String, display_name: String) -> void:
	if guild_invite.is_valid():
		guild_invite.call(player_id, display_name)


## My guild changed (the guild page: created, joined, left, kicked: "" none).
func set_guild(id: String) -> void:
	_check_player()
	guild_known = true
	if id == guild_id:
		return
	guild_id = id
	guild_changed.emit()


## Asks GET /guilds/me once (a 404: no guild); `force` asks again.
func load_guild(force: bool = false) -> void:
	_check_player()
	if _guild_asking or (guild_known and not force):
		return
	_guild_asking = true
	var res: Dictionary = await _api().get_json("/guilds/me")
	_guild_asking = false
	var id := guild_id
	if res.ok and res.data is Dictionary:
		id = str(res.data.get("id", ""))
	elif int(res.get("status", 0)) in [403, 404]:
		id = ""
	else:
		return # offline: keep what is known
	set_guild(id)


# ── Chat ────────────────────────────────────────────────────────────────────

## The messages of a conversation, oldest first.
func messages(feed_key: String) -> Array:
	_check_player()
	return _feeds.get(feed_key, {}).get("messages", [])


## The last error of a conversation's poll ("" none).
func feed_error(feed_key: String) -> String:
	return str(_feeds.get(feed_key, {}).get("error", ""))


## Asks the conversation's messages after its cursor (all retained, newest page, the first time).
## Dropped while one runs, within pollSec of the last one (`now` true: opening the conversation
## or after sending, not within a 429's backoff).
func poll(channel: String, target: String = "", now: bool = false) -> void:
	_check_player()
	var k := ChatModel.key(channel, target)
	if _in_flight.get(k, false):
		return
	if channel == ChatModel.GUILD and target == "":
		return
	var t := Time.get_ticks_msec()
	if t < int(_next_ok.get(k, 0)) and (not now or _backoff.has(k)):
		return
	_in_flight[k] = true
	var poll_ms := int(GameData.chat_poll_sec() * 1000.0)
	var player := _player
	var after := ChatModel.last_id(messages(k))
	var res: Dictionary = await _api().get_json(ChatModel.path(channel) + ChatModel.history_query(target, after))
	_in_flight.erase(k)
	if player != Session.player_id:
		return
	if int(res.get("status", 0)) == 429:
		_backoff[k] = ChatModel.next_backoff(float(_backoff.get(k, 0.0)))
		_next_ok[k] = Time.get_ticks_msec() + int(maxi(poll_ms, 1000) * float(_backoff[k]))
	else:
		_backoff.erase(k)
		_next_ok[k] = Time.get_ticks_msec() + poll_ms * 9 / 10
	if res.ok:
		take(k, ChatModel.parse_list(res.data))
		return
	if channel == ChatModel.GUILD and int(res.get("status", 0)) in [403, 404]:
		set_guild("") # no longer a member
	_feed(k)["error"] = SocialText.chat(res)
	feed_changed.emit(k)


## Adds messages to a conversation (a poll's, my sent one's).
func take(feed_key: String, list: Array) -> void:
	_check_player()
	var f := _feed(feed_key)
	var before: int = ChatModel.last_id(f["messages"])
	f["messages"] = ChatModel.merge(f["messages"], list)
	var had_error: bool = f["error"] != ""
	f["error"] = ""
	if ChatModel.last_id(f["messages"]) != before or had_error:
		feed_changed.emit(feed_key)


func _feed(feed_key: String) -> Dictionary:
	if not _feeds.has(feed_key):
		_feeds[feed_key] = {"messages": [], "error": ""}
	return _feeds[feed_key]


## Sends `text` to a conversation; "" when it went (the message is added), else the toast.
func send(channel: String, target: String, text: String) -> String:
	_check_player()
	var problem := ChatModel.text_problem(text, GameData.chat_max_length())
	if problem != "":
		return problem
	var res: Dictionary = await _api().post_json(ChatModel.path(channel), ChatModel.send_body(ChatModel.clean(text), target))
	if not res.ok:
		return SocialText.chat(res)
	var m := ChatModel.parse_message(res.data)
	if not m.is_empty():
		take(ChatModel.key(channel, target), [m])
	poll(channel, target, true) # what others sent meanwhile
	return ""


# ── Friends ─────────────────────────────────────────────────────────────────

## Loads the friends list once (the Kết bạn buttons need it).
func need_friends() -> void:
	_check_player()
	if not friends_loaded and not friends_loading:
		load_friends()


func load_friends() -> void:
	_check_player()
	if friends_loading:
		_friends_asked = true
		return
	friends_loading = true
	friends_error = ""
	friends_changed.emit()
	while true:
		_friends_asked = false
		var player := _player
		var res: Dictionary = await _api().get_json("/friends")
		if player != Session.player_id:
			break
		if _friends_asked:
			continue # a change was made meanwhile: ask again
		var parsed := FriendsModel.parse(res.data) if res.ok else {}
		if res.ok and not parsed.is_empty():
			friends = parsed
			friends_loaded = true
		else:
			friends_error = ErrorText.load_failed(res) if not res.ok else "Dữ liệu bạn bè không hợp lệ"
		break
	friends_loading = false
	friends_changed.emit()


## My relation to a player (FriendsModel.FRIEND, INCOMING, OUTGOING, NONE, SELF).
func relation(player_id: String) -> String:
	_check_player()
	return FriendsModel.relation(friends, player_id, Session.player_id)


## Kết bạn: "" when sent, else the toast. `entry` ({displayName, level, characterId}) shows in Đã
## gửi until the list reloads.
func request_friend(player_id: String, entry: Dictionary = {}) -> String:
	var res: Dictionary = await _api().post_json(FriendsModel.REQUESTS, {"playerId": player_id})
	if not res.ok:
		if str(res.get("code", "")) == "FRIEND_CONFLICT":
			load_friends() # they asked me meanwhile, or we already are: show it
		return SocialText.friend(res, "request")
	_changed(FriendsModel.moved(friends, player_id, FriendsModel.OUTGOING, entry))
	return ""


## Đồng ý: "" when we are friends, else the toast.
func accept_friend(player_id: String) -> String:
	var res: Dictionary = await _api().post_json(FriendsModel.accept_path(player_id), {})
	if not res.ok:
		load_friends()
		return SocialText.friend(res, "accept")
	_changed(FriendsModel.moved(friends, player_id, FriendsModel.FRIEND))
	return ""


## Xoá a friend, Từ chối a request to me, Huỷ my request: "" when done, else the toast.
func remove_friend(player_id: String) -> String:
	var res: Dictionary = await _api().request(HTTPClient.METHOD_DELETE, FriendsModel.friend_path(player_id))
	if not res.ok:
		return SocialText.friend(res, "remove")
	_changed(FriendsModel.moved(friends, player_id, FriendsModel.NONE))
	return ""


## Đổi biệt danh ("" resets it): "" when done, else the toast.
func set_nickname(player_id: String, nickname: String) -> String:
	var nick := nickname.strip_edges()
	var res: Dictionary = await _api().request(HTTPClient.METHOD_PUT, FriendsModel.nickname_path(player_id), {"nickname": nick})
	if not res.ok:
		return SocialText.friend(res, "nickname")
	_changed(FriendsModel.renamed(friends, player_id, nick))
	return ""


## Shows a local change at once, then the server's list.
func _changed(model: Dictionary) -> void:
	friends = model
	friends_changed.emit()
	load_friends()
