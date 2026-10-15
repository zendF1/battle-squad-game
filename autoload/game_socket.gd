extends Node
## WebSocket link to cmd/game (/ws?token=). Polled every frame; each server message is emitted
## as event_received(event, data). Messages sent while connecting wait in a small outbox; the
## outbox is dropped when a connection closes, because commands meant for the old connection
## (a QuickPlay, a Move) must not replay on the next one. Reconnects with backoff, reading the
## current token each time, refreshing it first when it expires within 30 s (and as a fallback
## every third failure); when the session is gone it stops and emits session_lost (Router sends
## the player to Login). hold()/release() buffer events across a scene change (MatchStarted is followed by
## TurnStarted in the same read).

signal connected
signal disconnected
signal session_lost
signal event_received(event: String, data: Variant)

const Envelope := preload("res://core/envelope.gd")
const Jwt := preload("res://core/jwt.gd")
const REFRESH_MARGIN_SEC := 30
const MAX_BACKOFF_SEC := 10.0
const MAX_OUTBOX := 32
const INBOUND_BUFFER := 4 * 1024 * 1024 # MatchStarted carries the whole terrain snapshot

var _ws := WebSocketPeer.new()
var _want_open := false
var _was_open := false
var _dialing := false
var _gen := 0 # bumped by every dial/close; a stale _redial coroutine sees it changed and stops
var _retry_in := -1.0
var _failures := 0
var _outbox: Array[String] = []
var _held := false
var _held_events: Array = []


func is_open() -> bool:
	return _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func open() -> void:
	if _want_open and (_dialing or _ws.get_ready_state() in [WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING]):
		return # already open or on its way
	_want_open = true
	_failures = 0
	_retry_in = -1.0
	if Jwt.expires_within(Session.access_token, REFRESH_MARGIN_SEC) and Session.refresh_token != "":
		_redial()
	else:
		_dial()


func close() -> void:
	_want_open = false
	_gen += 1
	_dialing = false
	_retry_in = -1.0
	_outbox.clear()
	_ws.close()


func send(event: String, data: Variant = {}) -> void:
	var text := Envelope.encode(event, data)
	if is_open():
		_ws.send_text(text)
	elif _want_open and _outbox.size() < MAX_OUTBOX:
		_outbox.append(text)


## Buffers incoming events until release(); used while switching to a scene that consumes them.
func hold() -> void:
	_held = true


func release() -> void:
	_held = false
	var events := _held_events
	_held_events = []
	for e in events:
		event_received.emit(e[0], e[1])


func _process(delta: float) -> void:
	if _retry_in >= 0.0:
		_retry_in -= delta
		if _retry_in < 0.0:
			_redial()
		return

	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				_failures = 0
				for text in _outbox:
					_ws.send_text(text)
				_outbox.clear()
				connected.emit()
			while _ws.get_available_packet_count() > 0:
				var msg := Envelope.decode(_ws.get_packet().get_string_from_utf8())
				if not msg.is_empty():
					_emit(msg["event"], msg["data"])
		WebSocketPeer.STATE_CLOSED:
			if _was_open:
				_was_open = false
				_outbox.clear()
				disconnected.emit()
			if _want_open and not _dialing and _retry_in < 0.0:
				_failures += 1
				_retry_in = minf(pow(2.0, _failures - 1), MAX_BACKOFF_SEC)


func _emit(event: String, data: Variant) -> void:
	if _held:
		_held_events.append([event, data])
	else:
		event_received.emit(event, data)


func _redial() -> void:
	_gen += 1
	var gen := _gen
	_dialing = true
	if Session.refresh_token != "" and ((_failures > 0 and _failures % 3 == 0) \
			or Jwt.expires_within(Session.access_token, REFRESH_MARGIN_SEC)):
		await Api.refresh_tokens()
	if gen != _gen:
		return # close() or a newer dial took over while the refresh was running
	_dialing = false
	if not Session.has_token():
		_want_open = false # refresh was rejected: the session is gone
		session_lost.emit()
		return
	if _want_open:
		_dial()


func _dial() -> void:
	_gen += 1
	# Never leave a previous peer behind: a second live socket would keep _was_open true, so
	# `connected` would not fire for the new one and its outbox would never flush.
	if _ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws.close()
	if _was_open:
		_was_open = false
		_outbox.clear()
		disconnected.emit()
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = INBOUND_BUFFER
	_ws.max_queued_packets = 4096
	var url := "%s/ws?token=%s" % [Config.ws_url, Session.access_token.uri_encode()]
	if _ws.connect_to_url(url) != OK:
		_failures += 1
		_retry_in = minf(pow(2.0, _failures - 1), MAX_BACKOFF_SEC)
