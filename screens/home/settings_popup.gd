extends "res://ui/modal.gd"
## "Cài đặt" (the lobby's gear, spec 2026-10-30-settings-account-link). One section for now,
## "Liên kết tài khoản", drawn from the profile's linkedProviders (core/account_link.gd):
## - a guest: one short line (linking keeps the progress on another device) over the login screen's
##   white buttons (ui/login_button.gd) for Apple and Google, centred in one column. Google opens the
##   system sign-in sheet (core/google_sign_in.gd) and links its id_token (POST /auth/link-provider);
##   Apple, and Google where this platform has no sheet, say "Sắp ra mắt".
## - linked: each linked provider's mark on a white disc with the green tick, centred; no button.
## After a link the profile is refreshed and the section flips to linked (the tick pops in). A cancel
## shows nothing; a failure its short toast (ui/provider_toast.gd) over the popup.

const AccountLink := preload("res://core/account_link.gd")
const GoogleSignIn := preload("res://core/google_sign_in.gd")
const LoginButton := preload("res://ui/login_button.gd")
const LoginMark := preload("res://ui/login_mark.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const ProviderToast := preload("res://ui/provider_toast.gd")

const WIDTH := 640
const BADGE := 112 # the linked provider's white disc
const TICK := 46
const HINT := "Liên kết để giữ tiến trình khi đổi máy"

## The section's content (rebuilt by render()).
var section: VBoxContainer
var _linking := false
var _was_guest := true


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
	var head := LobbyUi.text("Liên kết tài khoản", 26, LobbyUi.GOLD, true)
	head.name = "LinkHeader"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(head)
	section = Ui.vbox(14)
	section.name = "LinkSection"
	body.add_child(section)
	PlayerState.changed.connect(_on_profile)
	render(PlayerState.profile)


func _on_profile() -> void:
	render(PlayerState.profile)


## Draws the section for `profile`: the link buttons for a guest, the linked marks otherwise.
func render(profile: Variant) -> void:
	Ui.clear(section)
	var linked := AccountLink.linked_providers(profile)
	if linked.is_empty():
		_was_guest = true
		var hint := Ui.label(HINT, 22)
		hint.name = "Hint"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", Ui.TEXT_DIM)
		section.add_child(hint)
		for p in AccountLink.PROVIDERS:
			var b := LoginButton.new(p, "Liên kết với " + p.capitalize())
			b.name = "Link_" + p
			b.size_flags_horizontal = SIZE_SHRINK_CENTER
			b.disabled = _linking
			b.pressed.connect(_press.bind(p))
			section.add_child(b)
		return
	var row := Ui.hbox(28)
	row.name = "Linked"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_child(row)
	for p in linked:
		var badge := _linked_badge(p)
		row.add_child(badge)
		if _was_guest and is_inside_tree():
			_pop(badge.get_node("Tick"))
	_was_guest = false


## A provider's mark on a white disc, the green tick on its lower right.
func _linked_badge(provider: String) -> Control:
	var holder := Control.new()
	holder.name = "Linked_" + provider
	holder.custom_minimum_size = Vector2(BADGE, BADGE)
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	var disc := Panel.new()
	disc.mouse_filter = MOUSE_FILTER_IGNORE
	disc.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var box := LobbyUi.box(Color.WHITE, BADGE / 2, 0, LoginButton.EDGE, 3)
	box.shadow_color = LoginButton.SHADOW
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	disc.add_theme_stylebox_override("panel", box)
	holder.add_child(disc)
	var mark := LoginMark.new(provider)
	mark.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var inset := BADGE * 0.22
	mark.offset_left = inset
	mark.offset_top = inset
	mark.offset_right = -inset
	mark.offset_bottom = -inset
	holder.add_child(mark)
	var tick = GlyphIcon.make("check", TICK)
	tick.name = "Tick"
	tick.position = Vector2(BADGE - TICK + 6, BADGE - TICK + 6)
	tick.pivot_offset = Vector2(TICK, TICK) / 2.0
	holder.add_child(tick)
	return holder


func _pop(c: Control) -> void:
	c.scale = Vector2.ZERO
	var t := c.create_tween()
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
		PlayerState.apply(p) # flips the section now (changed → render)
		PlayerState.refresh()
		return
	var message := AccountLink.error_text(r)
	if message != "":
		ProviderToast.show(self, provider, message, ProviderToast.ERROR)


## While the sheet and the requests run: the buttons and the close X are off.
func _set_linking(on: bool) -> void:
	_linking = on
	set_busy(on)
	for c in section.get_children():
		if c is Button:
			c.disabled = on
