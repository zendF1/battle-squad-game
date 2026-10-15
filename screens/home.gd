extends Control
## Home shell: one top bar with the player (avatar letter, name, "Lv N"), the tabs "Chơi",
## "Hồ sơ", "Shop", and the wallet ("💰 1.250", "💎 300") from the shared PlayerState. Each
## time Home is shown (first entry, back from Loadout or a match) the profile is refreshed in
## the background; the bar shows the last known values meanwhile. The cached characters are
## marked stale too (a match changes their EXP), so the tab showing them reloads them once.

const Ui := preload("res://ui/ui.gd")
const Fmt := preload("res://core/fmt.gd")
const PlayTab := preload("res://screens/home/play_tab.gd")
const ProfileTab := preload("res://screens/home/profile_tab.gd")
const ShopTab := preload("res://screens/home/shop_tab.gd")

const TABS := ["Chơi", "Hồ sơ", "Shop"]
const PLAY := 0
const PROFILE := 1
const SHOP := 2

var _pages: Array[Control] = []
var _tab_buttons: Array[Button]
var _avatar_letter: Label
var _name: Label
var _level: Label
var _coin: Label
var _gem: Label
var _retry: Button
var _profile: ProfileTab
var _shop: ShopTab


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.13)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var root := Ui.vbox(0)
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(root)
	root.add_child(_build_top_bar())

	PlayerState.characters_stale = true
	var pages := Control.new()
	pages.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(pages)
	var play := PlayTab.new()
	_profile = ProfileTab.new()
	_profile.overlay = self
	_profile.open_shop_characters.connect(_open_shop_characters)
	_shop = ShopTab.new()
	_shop.overlay = self
	for page: Control in [play, _profile, _shop]:
		page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		pages.add_child(page)
		_pages.append(page)
	_show_tab(PLAY)

	PlayerState.changed.connect(_render_wallet)
	_render_wallet()
	PlayerState.refresh()


func _build_top_bar() -> Control:
	var bar := Ui.card(Color(0.13, 0.15, 0.2), 10)
	var row := Ui.hbox(14)
	bar.add_child(row)
	var avatar := Ui.circle("?", 60)
	_avatar_letter = avatar.get_child(0)
	row.add_child(avatar)
	var who := Ui.vbox(0)
	who.custom_minimum_size.x = 220
	row.add_child(who)
	_name = Ui.text("", 24)
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.add_child(_name)
	_level = Ui.text("", 20, Ui.TEXT_DIM)
	who.add_child(_level)

	var tabs := Ui.hbox(8)
	tabs.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(tabs)
	_tab_buttons = Ui.tab_row(TABS, 26, _show_tab, 68)
	for b in _tab_buttons:
		tabs.add_child(b)

	_coin = Ui.text("", 26)
	_coin.custom_minimum_size.x = 150
	row.add_child(_coin)
	_gem = Ui.text("", 26)
	_gem.custom_minimum_size.x = 130
	row.add_child(_gem)
	_retry = Ui.button("Thử lại", 20)
	_retry.custom_minimum_size = Vector2(120, 56)
	_retry.focus_mode = FOCUS_NONE
	_retry.pressed.connect(PlayerState.refresh)
	row.add_child(_retry)
	return bar


func _show_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
	Ui.select_tab(_tab_buttons, index)


func _open_shop_characters() -> void:
	_show_tab(SHOP)
	_shop.show_section(ShopTab.CHARACTERS)


func _render_wallet() -> void:
	var display := PlayerState.display_name()
	_name.text = display
	_avatar_letter.text = display.substr(0, 1).to_upper() if display != "" else "?"
	if PlayerState.is_loaded():
		_level.text = "Lv %d" % PlayerState.level()
		_coin.text = "💰 %s" % Fmt.thousands(PlayerState.coin())
		_gem.text = "💎 %s" % Fmt.thousands(PlayerState.gem())
	else:
		_level.text = "Đang tải..." if PlayerState.loading else PlayerState.error
		_coin.text = "💰 —"
		_gem.text = "💎 —"
	# Stale values stay on screen; a failed refresh only adds the retry.
	_retry.visible = PlayerState.error != "" and not PlayerState.loading
