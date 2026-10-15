extends Control
## Home shell with the demo's five tabs (app_router.dart HomeShell). M1 implements
## Play → Quick Play (idle practice target) and Play vs bot (QuickPlay {"bot": "ai"}); both open
## the Loadout screen, which sends the request (screens/quick_play.gd). The other tabs arrive
## in M3/M4.

const Ui := preload("res://ui/ui.gd")
const TABS := ["Chơi", "Hồ sơ", "Cửa hàng", "Nhiệm vụ", "Xếp hạng"]

var _pages: Array[Control] = []
var _conn: Label


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Ui.label("Battle Squad  ·  %s" % Session.display_name, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	_conn = Ui.label("", 22)
	header.add_child(_conn)

	var pages := Control.new()
	pages.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(pages)
	for i in TABS.size():
		var page := Control.new()
		page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		page.visible = i == 0
		pages.add_child(page)
		_pages.append(page)
	_build_play_page(_pages[0])
	for i in range(1, TABS.size()):
		Ui.center_column(_pages[i]).add_child(Ui.label("%s — sắp có" % TABS[i], 32))

	var tabs := HBoxContainer.new()
	root.add_child(tabs)
	for i in TABS.size():
		var b := Ui.button(TABS[i], 26)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 90
		b.pressed.connect(_show_tab.bind(i))
		tabs.add_child(b)

	GameSocket.connected.connect(_update_conn)
	GameSocket.disconnected.connect(_update_conn)
	_update_conn()


func _build_play_page(page: Control) -> void:
	var col := Ui.center_column(page)
	var quick_play := Ui.button("Chơi nhanh (Luyện tập)", 34)
	quick_play.custom_minimum_size = Vector2(560, 110)
	quick_play.pressed.connect(_open_loadout.bind({}))
	col.add_child(quick_play)
	var vs_bot := Ui.button("Đấu với máy", 34)
	vs_bot.custom_minimum_size = Vector2(560, 110)
	vs_bot.pressed.connect(_open_loadout.bind({"bot": "ai"}))
	col.add_child(vs_bot)


func _show_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index


func _update_conn() -> void:
	_conn.text = "● Online" if GameSocket.is_open() else "○ Đang kết nối..."


func _open_loadout(base: Dictionary) -> void:
	Router.quick_play_base = base
	Router.go(Router.LOADOUT)
