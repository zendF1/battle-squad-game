extends Node
## One Quick Play request at a time (moved from Home; the Loadout screen owns it).
##
## A request stays pending until it is resolved. The server handles a client's messages in
## order and always answers QuickPlay with MatchStarted or RoomError, so a late answer is still
## accepted: the server really did put the player in that match. The only other way a request
## ends is a disconnect, after which the server drops the room (and the outbox drops an unsent
## QuickPlay). Retrying earlier could create a second room, and leaving the screen while it is
## pending would lose the answer, so the owner keeps the player here while `pending`.

signal changed # pending, status or the connection changed
signal refused(code: String) # a RoomError ended the request (its code, "" if none)

const ErrorText := preload("res://screens/home/error_text.gd")

const SLOW_NOTICE_SEC := 10.0

var pending := false
var status := ""

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_slow)
	add_child(_timer)
	GameSocket.connected.connect(_on_connected)
	GameSocket.disconnected.connect(_on_disconnected)
	GameSocket.event_received.connect(_on_event)


## A QuickPlay sent while offline would sit in an outbox that may never flush.
func can_request() -> bool:
	return not pending and GameSocket.is_open()


func request(payload: Dictionary) -> bool:
	if not can_request():
		return false
	pending = true
	status = "Đang tạo trận..."
	_timer.start(SLOW_NOTICE_SEC)
	GameSocket.send("QuickPlay", payload)
	changed.emit()
	return true


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
			GameSocket.hold() # TurnStarted follows immediately; Match releases it
			if data is Dictionary:
				Router.match_snapshot = data
			Router.go(Router.MATCH)
		"RoomError":
			# Any code ends the request: LOADOUT_INVALID (character/items refused, English
			# message, shown in Vietnamese by ErrorText.room_error), MATCH_START_FAILED (after a
			# RoomUpdated from the join), a server error.
			if pending:
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
	status = message
	changed.emit()


static func error_code(data: Variant) -> String:
	if data is Dictionary:
		if data.get("error") is Dictionary:
			return str(data["error"].get("code", ""))
		return str(data.get("code", ""))
	return ""
