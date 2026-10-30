extends Node
## One Quick Play request at a time (moved from Home; the Loadout screen owns it).
##
## A request stays pending until it is resolved. The server handles a client's messages in
## order and always answers QuickPlay with MatchStarted or RoomError, so a late answer is still
## accepted: the server really did put the player in that match. The only other way a request
## ends is a disconnect, after which the server drops the room (and the outbox drops an unsent
## QuickPlay). Retrying earlier could create a second room, and leaving the screen while it is
## pending would lose the answer, so the owner keeps the player here while `pending`.
##
## The server takes QuickPlay only from a connection in no room and no lobby (RoomError
## ROOM_CREATE_FAILED "leave current room or lobby first", docs/contracts/security-settlement.md).
## before_request(): a lobby of mine with nobody else in it (Router.party: an invite nobody took)
## is left first (LeaveLobby, then QuickPlay); with a teammate the request is refused here
## (PARTY_TEXT: the party plays together, the player leaves it on Home to play alone). A refusal
## because the server still has me somewhere (on_refusal(): a Leave / LeaveLobby still in flight,
## or a room / lobby this client never knew of) sends Leave and LeaveLobby and asks once more
## RETRY_SEC later; the ROOM_REQUIRED answering that Leave is not the answer to the request.

signal changed # pending, status or the connection changed
signal refused(code: String) # a RoomError ended the request (its code, "" if none)

const ErrorText := preload("res://screens/home/error_text.gd")

const SLOW_NOTICE_SEC := 10.0
const RETRY_SEC := 0.6
const PARTY_TEXT := "Đang ở trong tổ đội: rời đội để chơi một mình"

## before_request()
const SEND := "send"
const LEAVE_FIRST := "leave_first"
const IN_PARTY := "in_party"
## on_refusal()
const RETRY := "retry"
const IGNORE := "ignore"
const FAIL := "fail"

var pending := false
var status := ""

var _timer: Timer
var _retry_timer: Timer
var _retried := false
var _payload := {}


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_slow)
	add_child(_timer)
	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(_on_retry)
	add_child(_retry_timer)
	GameSocket.connected.connect(_on_connected)
	GameSocket.disconnected.connect(_on_disconnected)
	GameSocket.event_received.connect(_on_event)


## A QuickPlay sent while offline would sit in an outbox that may never flush.
func can_request() -> bool:
	return not pending and GameSocket.is_open()


## Sends QuickPlay; false when it was not sent (offline, already pending, or in a party: `status`
## says why).
func request(payload: Dictionary) -> bool:
	if not can_request():
		return false
	match before_request(_in_lobby(), _in_party()):
		IN_PARTY:
			status = PARTY_TEXT
			changed.emit()
			return false
		LEAVE_FIRST:
			Router.party.leave() # the server takes them in order: out of the lobby, then QuickPlay
	pending = true
	_retried = false
	_payload = payload.duplicate(true)
	status = "Đang tạo trận..."
	_timer.start(SLOW_NOTICE_SEC)
	GameSocket.send("QuickPlay", _payload)
	changed.emit()
	return true


## What request() does first, from Router.party: SEND, LEAVE_FIRST (a lobby with only me in it)
## or IN_PARTY (with a teammate: not sent).
static func before_request(in_lobby: bool, in_party: bool) -> String:
	if in_party:
		return IN_PARTY
	return LEAVE_FIRST if in_lobby else SEND


## A RoomError while my request is pending: RETRY (the server still has me in a room or lobby,
## the first time), IGNORE (ROOM_REQUIRED after the retry's Leave: its answer, not the request's)
## or FAIL (the request ends with the error).
static func on_refusal(code: String, message: String, retried: bool) -> String:
	if retried and code == "ROOM_REQUIRED":
		return IGNORE
	if not retried and still_somewhere(code, message):
		return RETRY
	return FAIL


## The refusal says I am still in a room or a lobby (the server's admission messages).
static func still_somewhere(code: String, message: String) -> bool:
	if not code in ["ROOM_CREATE_FAILED", "ROOM_JOIN_FAILED"]:
		return false
	return message == "leave current room or lobby first" or message.contains("already belongs to")


func _in_lobby() -> bool:
	return Router.party != null and Router.party.model.in_lobby()


func _in_party() -> bool:
	return Router.party != null and Router.party.model.in_party()


func _on_retry() -> void:
	if pending and GameSocket.is_open():
		GameSocket.send("QuickPlay", _payload)


func _on_slow() -> void:
	if pending:
		status = "Server phản hồi chậm, vẫn đang chờ..."
		changed.emit()


func _on_event(event: String, data: Variant) -> void:
	match event:
		"MatchStarted":
			# The only way into Match. Accepted even after the slow notice.
			pending = false
			_timer.stop()
			_retry_timer.stop()
			GameSocket.hold() # TurnStarted follows immediately; Match releases it
			if data is Dictionary:
				Router.match_snapshot = data
			Router.go(Router.MATCH)
		"RoomError":
			# Any code ends the request: LOADOUT_INVALID (character/items refused, English
			# message, shown in Vietnamese by ErrorText.room_error), MATCH_START_FAILED (after a
			# RoomUpdated from the join), a server error.
			if not pending:
				return
			match on_refusal(error_code(data), error_message(data), _retried):
				IGNORE:
					return
				RETRY:
					_retried = true
					if _in_party(): # a teammate joined meanwhile: the party plays together
						_resolve(PARTY_TEXT)
						refused.emit(error_code(data))
						return
					GameSocket.send("Leave", {}) # a room the server still has me in
					if Router.party != null:
						Router.party.leave() # LeaveLobby
					_retry_timer.start(RETRY_SEC)
					return
			_resolve("Không vào được trận: %s" % ErrorText.room_error(data))
			refused.emit(error_code(data))


## Back online: a resolution message from before the disconnect is stale.
func _on_connected() -> void:
	if not pending:
		status = ""
	changed.emit()


func _on_disconnected() -> void:
	if pending:
		_resolve("Mất kết nối, hãy thử lại khi online")
	else:
		changed.emit()


func _resolve(message: String) -> void:
	pending = false
	_timer.stop()
	_retry_timer.stop()
	status = message
	changed.emit()


static func error_message(data: Variant) -> String:
	if data is Dictionary:
		if data.get("error") is Dictionary:
			return str(data["error"].get("message", ""))
		return str(data.get("message", ""))
	return ""


static func error_code(data: Variant) -> String:
	if data is Dictionary:
		if data.get("error") is Dictionary:
			return str(data["error"].get("code", ""))
		return str(data.get("code", ""))
	return ""
