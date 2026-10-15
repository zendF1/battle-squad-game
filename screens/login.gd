extends Control
## Guest login (demo login_screen.dart). Google/Apple come with provider login later.

const Ui := preload("res://ui/ui.gd")

var _guest: Button
var _error: Label


func _ready() -> void:
	var col := Ui.center_column(self)
	col.add_child(Ui.label("BATTLE SQUAD", 64))
	_guest = Ui.button("Chơi với tư cách khách", 32)
	_guest.custom_minimum_size = Vector2(520, 96)
	_guest.pressed.connect(_on_guest)
	col.add_child(_guest)
	_error = Ui.label("", 24)
	_error.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
	col.add_child(_error)


func _on_guest() -> void:
	_guest.disabled = true
	_error.text = ""
	var res: Dictionary = await Api.request(HTTPClient.METHOD_POST, "/auth/guest-login",
		{"deviceInstallId": Session.ensure_device_id()}, false, false)
	var d = res.data if res.ok else null
	if d is Dictionary and str(d.get("accessToken", "")) != "" and str(d.get("playerId", "")) != "":
		Session.set_tokens(str(d["accessToken"]), str(d.get("refreshToken", "")), str(d["playerId"]), str(d.get("displayName", "")))
		GameSocket.open()
		Router.go(Router.HOME)
		return
	_error.text = res.message if not res.ok else "Phản hồi không hợp lệ từ server"
	_guest.disabled = false
