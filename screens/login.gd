extends Control
## The login screen: the login picture (Art.BG_LOGIN: the squad on a hill, framed so all five stay on
## screen), the logo where the loading screen had it (ui/brand.gd), then, centred in the space under
## it, four same-size white login buttons (ui/login_button.gd: Apple, Google, Facebook, then the guest
## "Chơi ngay") and the terms tick (ui/consent_row.gd, remembered by core/consent.gd; its two links open
## the documents in game: ui/legal_popup.gd). A login works
## only once the tick is on; tapped without it, the tick shakes. Apple / Google / Facebook have no
## server login yet: each has its own _login_<provider>() that only shows "Sắp ra mắt" for now, where
## the provider's SDK sign-in plugs in later.

const Art := preload("res://ui/art.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const Brand := preload("res://ui/brand.gd")
const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const LoginButton := preload("res://ui/login_button.gd")
const LoginMark := preload("res://ui/login_mark.gd")
const ConsentRow := preload("res://ui/consent_row.gd")
const Consent := preload("res://core/consent.gd")
const LegalPopup := preload("res://ui/legal_popup.gd")

## The login picture's part kept on any screen: the five, head to feet (texture UV); the crop and the
## band a tall screen leaves go to the sky (align: the picture sits low).
const KEEP := Rect2(0.05, 0.33, 0.925, 0.635)
const ALIGN := Vector2(0.5, 0.8)
## The buttons, top to bottom: provider id (its mark and its _login_<id>() handler) and text.
const PROVIDERS := [
	["apple", "Đăng nhập với Apple"],
	["google", "Đăng nhập với Google"],
	["facebook", "Đăng nhập với Facebook"],
	["guest", "Chơi ngay"],
]
const BUTTON_GAP := 12
## The gap between the buttons and the tick.
const CONSENT_GAP := 18
## Space kept between the logo's bottom and the column.
const LOGO_GAP := 16
const TOAST_SEC := 1.8
## A failed login's message colour on the white toast.
const ERROR := Color(0.8, 0.14, 0.12)

var consent := Consent.new()
var _buttons: Array[Button] = []
var _consent_row: ConsentRow
var _busy := false


func _ready() -> void:
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.top_shade = false
	bg.keep = KEEP
	bg.align = ALIGN
	bg.show_image(Art.BG_LOGIN, false)
	add_child(bg)
	Brand.add_logo(self)
	# The space under the logo, its content centred.
	var area := CenterContainer.new()
	area.name = "Column"
	area.mouse_filter = MOUSE_FILTER_IGNORE
	area.anchor_left = 0.0
	area.anchor_right = 1.0
	area.anchor_top = Brand.LOGO_CENTER_Y
	area.anchor_bottom = 1.0
	area.offset_top = Brand.LOGO_HEIGHT / 2.0 + LOGO_GAP
	add_child(area)
	var col := Ui.vbox(BUTTON_GAP)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	area.add_child(col)
	for p in PROVIDERS:
		var b := LoginButton.new(p[0], p[1])
		b.pressed.connect(_press.bind(p[0]))
		col.add_child(b)
		_buttons.append(b)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, CONSENT_GAP - BUTTON_GAP)
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	_consent_row = ConsentRow.new(LoginButton.SIZE.x, consent.accepted, Config.terms_url, Config.privacy_url)
	_consent_row.toggled.connect(consent.set_accepted)
	_consent_row.link_pressed.connect(_show_legal)
	col.add_child(_consent_row)


## The terms of service / privacy policy in game, its browser button on the configured URL.
func _show_legal(doc_id: String) -> void:
	var showing := get_node_or_null("LegalPopup")
	if showing != null and not showing.is_queued_for_deletion():
		return
	LegalPopup.open(self, doc_id, _consent_row.url_for(doc_id))


## A login button tapped: the provider's login once the tick is on, else the tick shakes.
func _press(provider: String) -> void:
	if _busy:
		return
	if not consent.accepted:
		_consent_row.nudge()
		return
	call("_login_" + provider)


func _login_apple() -> void:
	_coming_soon("apple") # Sign in with Apple goes here, then its token to the server as _login_guest() does


func _login_google() -> void:
	_coming_soon("google") # Google Sign-In goes here


func _login_facebook() -> void:
	_coming_soon("facebook") # Facebook Login goes here


func _login_guest() -> void:
	_set_busy(true)
	var res: Dictionary = await Api.request(HTTPClient.METHOD_POST, "/auth/guest-login",
		{"deviceInstallId": Session.ensure_device_id()}, false, false)
	var d = res.data if res.ok else null
	if d is Dictionary and str(d.get("accessToken", "")) != "" and str(d.get("playerId", "")) != "":
		Session.set_tokens(str(d["accessToken"]), str(d.get("refreshToken", "")), str(d["playerId"]), str(d.get("displayName", "")))
		GameSocket.open()
		Router.go(Router.HOME)
		return
	_toast("guest", res.message if not res.ok else "Phản hồi không hợp lệ từ server", ERROR)
	_set_busy(false)


func _set_busy(on: bool) -> void:
	_busy = on
	for b in _buttons:
		b.disabled = on


func _coming_soon(provider: String) -> void:
	_toast(provider, "Sắp ra mắt", LoginButton.TEXT)


## A white card near the top: the provider's mark and a short message; it replaces the one showing.
func _toast(provider: String, message: String, color: Color) -> void:
	var old := get_node_or_null("Toast")
	if old != null:
		old.name = "OldToast"
		old.queue_free()
	var card := PanelContainer.new()
	card.name = "Toast"
	card.mouse_filter = MOUSE_FILTER_IGNORE
	var box := LobbyUi.box(Color.WHITE, 16, 14, LoginButton.EDGE, 2)
	box.content_margin_left = 20
	box.content_margin_right = 26
	box.shadow_color = LoginButton.SHADOW
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
	card.add_theme_stylebox_override("panel", box)
	var row := Ui.hbox(12)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var mark := LoginMark.new(provider)
	mark.custom_minimum_size = Vector2(34, 34)
	row.add_child(mark)
	var l := Ui.label(message, 24)
	l.add_theme_font_override("font", LobbyUi.bold())
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	card.add_child(row)
	card.set_anchors_preset(PRESET_CENTER_TOP)
	card.grow_horizontal = GROW_DIRECTION_BOTH
	card.position.y = 24
	add_child(card)
	card.modulate.a = 0.0
	var t := card.create_tween()
	t.tween_property(card, "modulate:a", 1.0, 0.15)
	t.tween_interval(TOAST_SEC)
	t.tween_property(card, "modulate:a", 0.0, 0.3)
	t.tween_callback(card.queue_free)
