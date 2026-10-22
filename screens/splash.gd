extends Control
## Startup (demo splash_screen.dart): the game data first (GET /gamedata, PlayerState.
## load_gamedata(): every rule and text the screens need; the cached copy when offline), then
## restore the saved session, then Home or Login. With no game data at all (a first launch with no
## network) it stays here on a retry screen.

const Ui := preload("res://ui/ui.gd")

var _status: Label
var _retry: Button


func _ready() -> void:
	var col := Ui.center_column(self)
	col.add_child(Ui.label("BATTLE SQUAD", 64))
	_status = Ui.label("", 28)
	col.add_child(_status)
	_retry = Ui.button("Thử lại")
	_retry.pressed.connect(_start)
	col.add_child(_retry)
	_start()


func _start() -> void:
	_retry.visible = false
	_status.text = "Đang tải dữ liệu trò chơi..."
	if not await PlayerState.load_gamedata():
		_status.text = "Không tải được dữ liệu trò chơi.\nHãy kiểm tra kết nối mạng rồi thử lại."
		_retry.visible = true
		return
	_check_auth()


func _check_auth() -> void:
	_retry.visible = false
	_status.text = "Đang kết nối..."
	if not Session.has_token():
		Router.go(Router.LOGIN)
		return
	var res: Dictionary = await Api.get_json("/player/profile")
	if res.ok and res.data is Dictionary:
		PlayerState.apply(res.data) # also updates Session's playerId / displayName
		GameSocket.open()
		Router.go(Router.HOME)
	elif res.status == 401:
		Session.clear_tokens()
		Router.go(Router.LOGIN)
	else:
		_status.text = "Không kết nối được server (%s)" % res.message
		_retry.visible = true
