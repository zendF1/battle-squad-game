extends Control
## The login screen: the login picture (Art.BG_LOGIN: the squad on a hill, framed so all five stay on
## screen), the logo where the loading screen had it (ui/brand.gd), then, centred in the space under
## it, four same-size white login buttons (ui/login_button.gd: Apple, Google, Facebook, then the guest
## "Chơi ngay") and the terms tick (ui/consent_row.gd, remembered by core/consent.gd; its two links open
## the documents in game: ui/legal_popup.gd). A login works
## only once the tick is on; tapped without it, the tick shakes. Apple / Google / Facebook have no
## server login yet: each has its own _login_<provider>() that only shows "Sắp ra mắt" for now, where
## the provider's SDK sign-in plugs in later. Signed in, a new account (profile onboarded false)
## picks its starter and name first (screens/onboarding.gd), others go to Home.

const Art := preload("res://ui/art.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const Brand := preload("res://ui/brand.gd")
const Ui := preload("res://ui/ui.gd")
const LoginButton := preload("res://ui/login_button.gd")
const ConsentRow := preload("res://ui/consent_row.gd")
const Consent := preload("res://core/consent.gd")
const LegalPopup := preload("res://ui/legal_popup.gd")
const ProviderToast := preload("res://ui/provider_toast.gd")
const GoogleSignIn := preload("res://core/google_sign_in.gd")
const AccountLink := preload("res://core/account_link.gd")

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
## A failed login's message colour on the white toast.
const ERROR := ProviderToast.ERROR

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


## Google: the system sign-in sheet (core/google_sign_in.gd), then POST /auth/provider-login with its
## id_token (core/account_link.gd): a linked guest account comes back, an unknown Google account starts
## a new one (onboarding). Cancelled: nothing; a failure: its short toast. "Sắp ra mắt" where this
## platform has no sheet or client ID (Windows, Linux).
func _login_google() -> void:
	if not GoogleSignIn.available():
		_coming_soon("google")
		return
	_set_busy(true)
	var r: Dictionary = await AccountLink.login_google(GoogleSignIn.for_platform(), Api)
	if r.get("ok", false):
		var d: Dictionary = r["data"]
		Session.set_tokens(str(d["accessToken"]), str(d.get("refreshToken", "")), str(d["playerId"]), str(d.get("displayName", "")))
		GameSocket.open()
		_enter()
		return
	var message := AccountLink.error_text(r)
	if message != "":
		_toast("google", message, ERROR)
	_set_busy(false)


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
		_enter()
		return
	_toast("guest", res.message if not res.ok else "Phản hồi không hợp lệ từ server", ERROR)
	_set_busy(false)


## Signed in: the profile decides between the first-login pick (screens/onboarding.gd) and Home;
## without it Home, which sends a profile still to onboard there once it loads.
func _enter() -> void:
	var res: Dictionary = await Api.get_json("/player/profile")
	if res.ok and res.data is Dictionary:
		PlayerState.apply(res.data)
		Router.go_signed_in(res.data)
	else:
		Router.go(Router.HOME)


func _set_busy(on: bool) -> void:
	_busy = on
	for b in _buttons:
		b.disabled = on


func _coming_soon(provider: String) -> void:
	_toast(provider, "Sắp ra mắt", LoginButton.TEXT)


## The white sign-in toast near the top (ui/provider_toast.gd).
func _toast(provider: String, message: String, color: Color) -> void:
	ProviderToast.show(self, provider, message, color)
