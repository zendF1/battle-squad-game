extends Control
## Home: the lobby (screens/home/lobby.gd) and two full-screen pages opened from it, "Hồ sơ"
## (Nhân vật / Kho đồ / Lịch sử) and "Shop" (Vật phẩm / Nhân vật / Kim cương). A page has a
## header with "← Sảnh", its title and the wallet pills; "← Sảnh", Esc (ui_cancel) and the
## Android back button return to the lobby. The pages are built with Home but hidden, and each
## loads its data the first time it is shown (the tabs' own lazy loading). The wallet "+"
## buttons open the Shop on Kim cương (💎) or Vật phẩm (💰).
## Each time Home is shown (first entry, back from Loadout or a match) the profile is refreshed in
## the background; the last known values show meanwhile. The cached characters are marked stale
## too (a match changes their EXP), so whatever shows them reloads them once.

const Backdrop := preload("res://ui/backdrop.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Modal := preload("res://ui/modal.gd")
const WalletPills := preload("res://ui/wallet_pills.gd")
const Lobby := preload("res://screens/home/lobby.gd")
const ProfileTab := preload("res://screens/home/profile_tab.gd")
const ShopTab := preload("res://screens/home/shop_tab.gd")

const LOBBY := 0
const PROFILE := 1
const SHOP := 2

var _lobby: Lobby
var _profile: ProfileTab
var _shop: ShopTab
var _pages := {} # PROFILE / SHOP -> the page (header + tab)
var _shown := LOBBY


func _ready() -> void:
	theme = LobbyUi.theme()
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	PlayerState.characters_stale = true
	_lobby = Lobby.new()
	_lobby.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_lobby)
	_lobby.open_profile.connect(open_profile)
	_lobby.open_shop.connect(open_shop)
	_connect_wallet(_lobby.wallet)

	_profile = ProfileTab.new()
	_profile.overlay = self
	_profile.open_shop_characters.connect(open_shop.bind(ShopTab.CHARACTERS))
	_shop = ShopTab.new()
	_shop.overlay = self
	_pages[PROFILE] = _build_page("Hồ sơ", _profile)
	_pages[SHOP] = _build_page("Shop", _shop)
	_show(LOBBY)
	PlayerState.refresh()


func _exit_tree() -> void:
	get_tree().quit_on_go_back = true


## A full-screen page: the backdrop without the ground, the header row, then `content`.
func _build_page(title: String, content: Control) -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	page.visible = false
	add_child(page)
	var bg := Backdrop.new()
	bg.ground = false
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	page.add_child(bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	page.add_child(col)
	var header := MarginContainer.new()
	for side in ["left", "right", "top"]:
		header.add_theme_constant_override("margin_" + side, 16)
	col.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	header.add_child(row)
	var back := LobbyUi.pill_button("←  Sảnh", 26, 64)
	LobbyUi.style_button(back, LobbyUi.PANEL, 32, 22, LobbyUi.PANEL_BORDER, 2)
	back.pressed.connect(_show.bind(LOBBY))
	row.add_child(back)
	var t := LobbyUi.text(title, 36, Color.WHITE, true)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(t)
	var wallet := WalletPills.new()
	row.add_child(wallet)
	_connect_wallet(wallet)
	content.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(content)
	return page


func _connect_wallet(wallet: WalletPills) -> void:
	wallet.gem_plus.connect(open_shop.bind(ShopTab.GEMS))
	wallet.coin_plus.connect(open_shop.bind(ShopTab.ITEMS))


func open_profile(section: int) -> void:
	_profile.show_section(section) # before showing: only that sub-tab loads
	_show(PROFILE)


func open_shop(section: int) -> void:
	_shop.show_section(section)
	_show(SHOP)


## Which screen shows: LOBBY, PROFILE or SHOP. Android back quits only from the lobby.
func _show(which: int) -> void:
	_shown = which
	for key in _pages:
		_pages[key].visible = key == which
	_lobby.visible = which == LOBBY
	get_tree().quit_on_go_back = which == LOBBY


func shown() -> int:
	return _shown


func _unhandled_input(event: InputEvent) -> void:
	if _shown != LOBBY and event.is_action_pressed("ui_cancel") and not _modal_open():
		get_viewport().set_input_as_handled()
		_show(LOBBY)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _shown != LOBBY and not _modal_open():
		_show(LOBBY)


func _modal_open() -> bool:
	for c in get_children():
		if c.get_script() == Modal and not c.is_queued_for_deletion():
			return true
	return false
