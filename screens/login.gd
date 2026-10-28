extends Control
## Guest login (demo login_screen.dart). Google/Apple come with provider login later.
## The login picture (Art.BG_LOGIN: the squad on a hill, framed so all five stay on screen), the logo
## where the loading screen had it (ui/brand.gd), the guest button and its error line under it.

const Art := preload("res://ui/art.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const Brand := preload("res://ui/brand.gd")
const Ui := preload("res://ui/ui.gd")

## The login picture's part kept on any screen: the five, head to feet (texture UV); the crop and the
## band a tall screen leaves go to the sky (align: the picture sits low).
const KEEP := Rect2(0.05, 0.33, 0.925, 0.635)
const ALIGN := Vector2(0.5, 0.8)
const BUTTON_SIZE := Vector2(520, 96)
## The button's centre and the error line's top: height shares of the screen.
const BUTTON_Y := 0.7
const ERROR_Y := 0.8

var _guest: Button
var _error: Label


func _ready() -> void:
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.top_shade = false
	bg.keep = KEEP
	bg.align = ALIGN
	bg.show_image(Art.BG_LOGIN, false)
	add_child(bg)
	Brand.add_logo(self)
	_guest = Ui.button("Chơi với tư cách khách", 32)
	_guest.name = "Guest"
	Brand.place(_guest, BUTTON_SIZE, BUTTON_Y)
	_guest.pressed.connect(_on_guest)
	add_child(_guest)
	_error = Ui.label("", 24)
	_error.name = "Error"
	_error.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
	_error.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12))
	_error.add_theme_constant_override("outline_size", 6)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Brand.place(_error, Vector2(900, 80), ERROR_Y)
	add_child(_error)


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
