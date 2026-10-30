extends "res://ui/modal.gd"
## "Cài đặt" (the lobby's gear; spec ../battle-squad/docs/specs/2026-10-30-settings-account-link.md,
## "settings with a left menu"): a menu bar on the left (an icon and a short label per section, the
## shown one lit gold) and the shown section on the right. Sections are SECTIONS: a new one is one
## entry there plus its builder (a method returning the section's Control). Only sections with real
## settings are listed: the game has no sound or graphics settings yet.
##
## "Tài khoản" (_build_account()):
## - the player's name and short ID (the playerId's first 8 hex digits: what support asks for);
## - one white row per provider (AccountLink.PROVIDERS): its mark, its name and either the green tick
##   with "Đã liên kết", its "Liên kết" button, or "Sắp ra mắt" where this build cannot sign in with it
##   (Apple for now; Google without the system sheet). Google opens the sign-in sheet
##   (core/google_sign_in.gd) and links its id_token (POST /auth/link-provider); then the profile is
##   refreshed and the row flips to the tick (it pops in). A cancel shows nothing; a failure its short
##   toast (ui/provider_toast.gd) over the popup;
## - "Đăng xuất": a confirm (Logout.confirm_text(): a guest gets back in with "Chơi ngay" on this
##   device, a linked account with its provider), then core/logout.gd forgets the account here and the
##   login screen opens.

const AccountLink := preload("res://core/account_link.gd")
const GoogleSignIn := preload("res://core/google_sign_in.gd")
const Logout := preload("res://core/logout.gd")
const Modal := preload("res://ui/modal.gd")
const LoginButton := preload("res://ui/login_button.gd")
const LoginMark := preload("res://ui/login_mark.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const SocialGlyphs := preload("res://screens/social/social_glyphs.gd")
const ProviderToast := preload("res://ui/provider_toast.gd")

## The menu, top to bottom: id, its picture (screens/social/social_glyphs.gd, which also draws
## ui/glyph_icon.gd's kinds), its short label and its builder.
const SECTIONS := [
	{"id": "account", "icon": "person", "label": "Tài khoản", "build": "_build_account"},
]

const WIDTH := 980
const MENU_W := 220
const MENU_H := 64
const MENU_ICON := 34
const GAP := 24 # between the menu, the divider and the section
const CONTENT_W := 640
const ROW := Vector2(540, 76) # a provider row
const MARK_PX := 36
const TICK := 34
const LOGOUT := Vector2(260, 64)
const CONFIRM_WIDTH := 720
const LINKED_GREEN := Color(0.13, 0.52, 0.2)
const LOGOUT_RED := Color(0.78, 0.2, 0.22)

## The menu's buttons (Menu_<id>), the section's holder and the shown section.
var menu: VBoxContainer
var content: VBoxContainer
var section: Control
var current := ""
## The profile the account section shows (PlayerState.profile; tests set it through render()).
var profile: Variant = {}
## Whether this build can sign in with a provider (AccountLink.can_sign_in; tests swap it).
var sign_in_ready: Callable = func(p: String) -> bool: return AccountLink.can_sign_in(p)
## What the confirm's "Đăng xuất" does (tests swap it).
var logout_action: Callable = _logout
var _linking := false
var _just_linked := ""


static func open_on(host: Node):
	var p = load("res://screens/home/settings_popup.gd").new()
	p.name = "SettingsPopup"
	p.open_for(host)
	return p


func open_for(host: Node) -> void:
	open(host, "Cài đặt", WIDTH)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_close_x()
	_rows.visible = false # no button row: the card's padding stays even top and bottom
	var layout := Ui.hbox(GAP)
	layout.name = "Layout"
	body.add_child(layout)
	menu = Ui.vbox(10)
	menu.name = "Menu"
	menu.custom_minimum_size.x = MENU_W
	layout.add_child(menu)
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.color = Color(1, 1, 1, 0.12)
	divider.custom_minimum_size = Vector2(2, 0)
	divider.mouse_filter = MOUSE_FILTER_IGNORE
	layout.add_child(divider)
	content = Ui.vbox(0)
	content.name = "Content"
	content.custom_minimum_size.x = CONTENT_W
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	layout.add_child(content)
	for s in SECTIONS:
		menu.add_child(_menu_button(s))
	profile = PlayerState.profile
	PlayerState.changed.connect(_on_profile)
	select(SECTIONS[0]["id"])


func _on_profile() -> void:
	render(PlayerState.profile)


## Shows section `id` (lit in the menu); an unknown id is ignored.
func select(id: String) -> void:
	for s in SECTIONS:
		if s["id"] == id:
			current = id
			_style_menu()
			_rebuild()
			return


## The shown section again for `p` (the account section reads it).
func render(p: Variant) -> void:
	profile = p
	_rebuild()


func _rebuild() -> void:
	Ui.clear(content)
	section = null
	for s in SECTIONS:
		if s["id"] == current:
			section = call(s["build"])
			content.add_child(section)


# ── Menu ────────────────────────────────────────────────────────────────────

func _menu_button(s: Dictionary) -> Button:
	var b := Button.new()
	b.name = "Menu_" + str(s["id"])
	b.custom_minimum_size = Vector2(MENU_W, MENU_H)
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(select.bind(str(s["id"])))
	var row := Ui.hbox(12)
	row.name = "Row"
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -12
	b.add_child(row)
	var icon := SocialGlyphs.glyph(str(s["icon"]), MENU_ICON)
	icon.name = "Icon"
	row.add_child(icon)
	var l := LobbyUi.text(str(s["label"]), 24, Color.WHITE, true)
	l.name = "Label"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = SIZE_FILL
	row.add_child(l)
	return b


## The shown section's button gold with dark text; the others a faint fill with white text.
func _style_menu() -> void:
	for s in SECTIONS:
		var b: Button = menu.get_node("Menu_" + str(s["id"]))
		var on: bool = s["id"] == current
		b.set_meta("selected", on)
		LobbyUi.style_button(b, LobbyUi.GOLD if on else Color(1, 1, 1, 0.06), 16, 0)
		var l: Label = b.get_node("Row/Label")
		l.add_theme_color_override("font_color", LobbyUi.TEXT_DARK if on else Color.WHITE)
		l.add_theme_constant_override("outline_size", 0 if on else 4)


# ── Tài khoản ───────────────────────────────────────────────────────────────

## The player's name and short ID, a row per provider, then "Đăng xuất".
func _build_account() -> Control:
	var col := Ui.vbox(12)
	col.name = "Account"
	var who := LobbyUi.text(_display_name(), 30, Color.WHITE, true)
	who.name = "PlayerName"
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(who)
	var sid := short_id(_player_id())
	if sid != "":
		var id_line := Ui.label("ID: " + sid, 20)
		id_line.name = "PlayerId"
		id_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		id_line.add_theme_color_override("font_color", Ui.TEXT_DIM)
		col.add_child(id_line)
	col.add_child(_gap(6))
	var rows := Ui.vbox(12)
	rows.name = "Providers"
	for p in AccountLink.PROVIDERS:
		rows.add_child(_provider_row(p))
	col.add_child(rows)
	col.add_child(_gap(10))
	var out := Button.new()
	out.name = "Logout"
	out.text = "Đăng xuất"
	out.custom_minimum_size = LOGOUT
	out.size_flags_horizontal = SIZE_SHRINK_CENTER
	out.add_theme_font_size_override("font_size", 24)
	out.add_theme_font_override("font", LobbyUi.bold())
	LobbyUi.style_button(out, LOGOUT_RED, 18, 12, Color(1, 1, 1, 0.25), 2)
	out.disabled = _linking
	out.pressed.connect(confirm_logout)
	col.add_child(out)
	_just_linked = ""
	return col


static func _gap(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = px
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


## The playerId's first 8 hex digits, upper case ("" none): the ID support asks for.
static func short_id(player_id: String) -> String:
	return player_id.replace("-", "").left(8).to_upper()


func _display_name() -> String:
	var v = profile.get("displayName") if profile is Dictionary else null
	return v if v is String and v != "" else Session.display_name


func _player_id() -> String:
	var v = profile.get("playerId") if profile is Dictionary else null
	return v if v is String and v != "" else Session.player_id


## A white row: the provider's mark and name, then its tick, its link button or "Sắp ra mắt".
func _provider_row(provider: String) -> PanelContainer:
	var state := AccountLink.row_state(provider, profile, bool(sign_in_ready.call(provider)))
	var row := PanelContainer.new()
	row.name = "Row_" + provider
	row.set_meta("state", state)
	row.custom_minimum_size = ROW
	row.size_flags_horizontal = SIZE_SHRINK_CENTER
	var box := LobbyUi.box(Color.WHITE, 16, 0, LoginButton.EDGE, 3)
	box.content_margin_left = 20
	box.content_margin_right = 14
	box.shadow_color = LoginButton.SHADOW
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	row.add_theme_stylebox_override("panel", box)
	var h := Ui.hbox(14)
	row.add_child(h)
	var mark := LoginMark.new(provider)
	mark.name = "Mark"
	mark.custom_minimum_size = Vector2(MARK_PX, MARK_PX)
	mark.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(mark)
	var n := Ui.label(AccountLink.provider_name(provider), 24)
	n.name = "Name"
	n.add_theme_font_override("font", LobbyUi.bold())
	n.add_theme_color_override("font_color", LoginButton.TEXT)
	n.size_flags_horizontal = SIZE_EXPAND_FILL
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(n)
	match state:
		AccountLink.LINKED:
			var done := Ui.hbox(8)
			done.name = "Linked"
			done.size_flags_vertical = SIZE_SHRINK_CENTER
			var tick = GlyphIcon.make("check", TICK)
			tick.name = "Tick"
			tick.pivot_offset = Vector2(TICK, TICK) / 2.0
			done.add_child(tick)
			var l := Ui.label("Đã liên kết", 22)
			l.add_theme_font_override("font", LobbyUi.bold())
			l.add_theme_color_override("font_color", LINKED_GREEN)
			done.add_child(l)
			h.add_child(done)
			if provider == _just_linked:
				_pop(tick)
		AccountLink.LINK:
			var b := Button.new()
			b.name = "Link"
			b.text = "Liên kết"
			b.custom_minimum_size = Vector2(150, 50)
			b.size_flags_vertical = SIZE_SHRINK_CENTER
			b.add_theme_font_size_override("font_size", 22)
			b.add_theme_font_override("font", LobbyUi.bold())
			LobbyUi.style_button(b, LobbyUi.GOLD, 14, 10)
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(c, LobbyUi.TEXT_DARK)
			b.add_theme_color_override("font_disabled_color", Color(LobbyUi.TEXT_DARK, 0.5))
			b.disabled = _linking
			b.pressed.connect(_press.bind(provider))
			h.add_child(b)
		_:
			var l := Ui.label("Sắp ra mắt", 20)
			l.name = "Soon"
			l.add_theme_color_override("font_color", Color(LoginButton.TEXT, 0.45))
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			h.add_child(l)
	return row


func _pop(c: Control) -> void:
	c.scale = Vector2.ZERO
	var t := create_tween()
	t.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _press(provider: String) -> void:
	if _linking:
		return
	if provider != "google" or not GoogleSignIn.available():
		ProviderToast.show(self, provider, "Sắp ra mắt")
		return
	_set_linking(true)
	var r: Dictionary = await AccountLink.link_google(GoogleSignIn.for_platform(), Api)
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	_set_linking(false)
	if r.get("ok", false):
		var p: Dictionary = PlayerState.profile.duplicate()
		p["linkedProviders"] = r.get("linked_providers", ["google"])
		_just_linked = provider
		PlayerState.apply(p) # flips the row now (changed → render)
		PlayerState.refresh()
		return
	var message := AccountLink.error_text(r)
	if message != "":
		ProviderToast.show(self, provider, message, ProviderToast.ERROR)


## While the sheet and the requests run: the buttons, the logout and the close X are off.
func _set_linking(on: bool) -> void:
	_linking = on
	set_busy(on)
	if section != null:
		for b in section.find_children("*", "Button", true, false):
			b.disabled = on


# ── Đăng xuất ───────────────────────────────────────────────────────────────

## The confirm over the popup: how to get back in (Logout.confirm_text()), "Ở lại" | "Đăng xuất".
func confirm_logout() -> Control:
	var host: Node = get_parent() if get_parent() != null else self
	var showing := host.get_node_or_null("ConfirmLogout")
	if showing != null and not showing.is_queued_for_deletion():
		return showing
	var m := Modal.new()
	m.name = "ConfirmLogout"
	m.open(host, "Đăng xuất?", CONFIRM_WIDTH)
	m.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var why := m.add_text(Logout.confirm_text(profile), 24)
	why.name = "Why"
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_button("Ở lại", m.close)
	var go := m.add_button("Đăng xuất", func() -> void:
		m.set_busy(true)
		logout_action.call())
	go.name = "LogoutButton"
	LobbyUi.style_button(go, LOGOUT_RED, 14, 8)
	return m


## Logs out (core/logout.gd) and opens the login screen.
func _logout() -> void:
	Logout.new().run()
	Router.go(Router.LOGIN)
