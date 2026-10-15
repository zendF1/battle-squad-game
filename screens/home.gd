extends Control
## Home shell with the demo's five tabs (app_router.dart HomeShell). M1 implements
## Play → Quick Play; the other tabs arrive in M3/M4.
##
## A Quick Play request stays pending until it is resolved. The server handles a client's
## messages in order and always answers QuickPlay with MatchStarted or RoomError, so a late
## answer is still accepted: the server really did put the player in that match. The only other
## way a request ends is a disconnect, after which the server drops the room (and the outbox
## drops an unsent QuickPlay). Retrying earlier could create a second room.

const Ui := preload("res://ui/ui.gd")
const TABS := ["Chơi", "Hồ sơ", "Cửa hàng", "Nhiệm vụ", "Xếp hạng"]
const SLOW_NOTICE_SEC := 10.0

var _pages: Array[Control] = []
var _conn: Label
var _quick_play: Button
var _status: Label
var _timer: Timer
var _pending := false


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Ui.label("Battle Squad  ·  %s" % Session.display_name, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	_conn = Ui.label("", 22)
	header.add_child(_conn)

	var pages := Control.new()
	pages.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(pages)
	for i in TABS.size():
		var page := Control.new()
		page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		page.visible = i == 0
		pages.add_child(page)
		_pages.append(page)
	_build_play_page(_pages[0])
	for i in range(1, TABS.size()):
		Ui.center_column(_pages[i]).add_child(Ui.label("%s — sắp có" % TABS[i], 32))

	var tabs := HBoxContainer.new()
	root.add_child(tabs)
	for i in TABS.size():
		var b := Ui.button(TABS[i], 26)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 90
		b.pressed.connect(_show_tab.bind(i))
		tabs.add_child(b)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_slow)
	add_child(_timer)

	GameSocket.connected.connect(_update_conn)
	GameSocket.disconnected.connect(_on_disconnected)
	GameSocket.event_received.connect(_on_event)
	_update_conn()


func _build_play_page(page: Control) -> void:
	var col := Ui.center_column(page)
	_quick_play = Ui.button("Chơi nhanh (Luyện tập)", 34)
	_quick_play.custom_minimum_size = Vector2(560, 110)
	_quick_play.pressed.connect(_on_quick_play)
	col.add_child(_quick_play)
	_status = Ui.label("", 24)
	col.add_child(_status)


func _show_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index


func _update_conn() -> void:
	_conn.text = "● Online" if GameSocket.is_open() else "○ Đang kết nối..."


func _on_quick_play() -> void:
	if _pending:
		return
	_pending = true
	_quick_play.disabled = true
	_status.text = "Đang tạo trận..."
	_timer.start(SLOW_NOTICE_SEC)
	GameSocket.send("QuickPlay", {})


func _on_slow() -> void:
	if _pending:
		_status.text = "Server phản hồi chậm, vẫn đang chờ..."


func _on_event(event: String, data: Variant) -> void:
	match event:
		"MatchStarted":
			# The only way into Match. Accepted even after the slow notice.
			_pending = false
			_timer.stop()
			GameSocket.hold() # TurnStarted follows immediately; Match releases it
			Router.match_snapshot = data
			Router.go(Router.MATCH)
		"RoomError":
			if _pending:
				_resolve(_error_message(data))


func _on_disconnected() -> void:
	_update_conn()
	if _pending:
		_resolve("Mất kết nối, hãy thử lại khi online")


func _resolve(message: String) -> void:
	_pending = false
	_timer.stop()
	_status.text = message
	_quick_play.disabled = false


static func _error_message(data: Variant) -> String:
	if data is Dictionary:
		if data.get("error") is Dictionary:
			return str(data["error"].get("message", "Lỗi phòng"))
		return str(data.get("message", "Lỗi phòng"))
	return "Lỗi phòng"
