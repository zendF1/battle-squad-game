extends Control
## Startup (demo splash_screen.dart): restore the saved session, then Home or Login.

const Ui := preload("res://ui/ui.gd")

var _status: Label
var _retry: Button


func _ready() -> void:
	var col := Ui.center_column(self)
	col.add_child(Ui.label("BATTLE SQUAD", 64))
	_status = Ui.label("", 28)
	col.add_child(_status)
	_retry = Ui.button("Thử lại")
	_retry.pressed.connect(_check_auth)
	col.add_child(_retry)
	_check_auth()


func _check_auth() -> void:
	_retry.visible = false
	_status.text = "Đang kết nối..."
	if not Session.has_token():
		Router.go(Router.LOGIN)
		return
	var res: Dictionary = await Api.get_json("/player/profile")
	if res.ok and res.data is Dictionary:
		Session.set_profile(str(res.data.get("playerId", "")), str(res.data.get("displayName", "")))
		GameSocket.open()
		Router.go(Router.HOME)
	elif res.status == 401:
		Session.clear_tokens()
		Router.go(Router.LOGIN)
	else:
		_status.text = "Không kết nối được server (%s)" % res.message
		_retry.visible = true
