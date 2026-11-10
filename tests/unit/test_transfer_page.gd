extends "res://tests/test_case.gd"
## The Nâng cấp page's Chuyển hoá tab (screens/home/transfer_page.gd) and the caps on the Nâng cấp
## tab, the list rows and the popup's level bar.

const UpgradePage := preload("res://screens/home/upgrade_page.gd")
const EquipmentUi := preload("res://screens/home/equipment_ui.gd")
const TransferModel := preload("res://screens/home/transfer_model.gd")
const Fixture := preload("res://tests/unit/test_transfer_model.gd")


func _open(owned: Array, locked: int = 370, transfer: bool = true) -> Control:
	PlayerState.catalog = Fixture.catalog(transfer)
	PlayerState.equipment = owned
	PlayerState.stones = {1: 10}
	PlayerState.equipment_stale = false
	PlayerState.stones_stale = false
	PlayerState.profile = {"coin": 900000, "gem": locked, "gemUnlocked": 5000}
	var page = UpgradePage.new()
	page.size = Vector2(1600, 760)
	Engine.get_main_loop().root.add_child(page)
	if not page.is_node_ready():
		page._ready()
	return page


func _close(page: Control) -> void:
	page.free()
	PlayerState.catalog = null
	PlayerState.equipment = null
	PlayerState.stones = null
	PlayerState.equipment_stale = true
	PlayerState.stones_stale = true
	PlayerState.profile = {}


static func _owned() -> Array:
	return [Fixture.piece("s", "armor_lv20", 10, 10), Fixture.piece("t", "armor_lv40", 0, 16), Fixture.piece("low", "armor_lv10", 0, 6)]


func test_tab_hidden_on_an_older_server() -> void:
	var page := _open(_owned(), 370, false)
	page._render()
	check(not page._sub_tabs[UpgradePage.TRANSFER].visible, "no transferGemCost: no Chuyển hoá")
	_close(page)
	page = _open(_owned())
	page._render()
	check(page._sub_tabs[UpgradePage.TRANSFER].visible, "the tab with a priced catalog")
	_close(page)


func test_pair_enough_locked_gem() -> void:
	var page := _open(_owned())
	page.select_transfer("s")
	var t = page._transfer
	t._on_target("t")
	t.render()
	eq(t._go_price.text, "250", "the source level's price")
	check(not t._go.disabled, "enough kim cương khoá")
	eq(t._reason.text, "", "nothing under the button")
	var levels: Node = t._grid.find_child("TargetLevels", true, false)
	eq(levels.get_children().filter(func(c): return c is Label).map(func(l): return l.text), ["+0", "+10"], "the target: +0 → +10")
	var src: Node = t._grid.find_child("SourceLevels", true, false)
	eq(src.get_children().filter(func(c): return c is Label).map(func(l): return l.text), ["+10", "+0"], "the source: +10 → +0")
	_close(page)


func test_pair_short_of_locked_gem() -> void:
	var page := _open(_owned(), 100) # 5000 unlocked kim cương never pay
	page.select_transfer("s")
	var t = page._transfer
	t._on_target("t")
	t.render()
	check(t._go.disabled, "off")
	eq(t._reason.text, "Thiếu kim cương khoá", "the reason")
	_close(page)


func test_low_cap_target_is_faded_and_not_picked() -> void:
	var page := _open(_owned())
	page.select_transfer("s")
	var t = page._transfer
	t._on_target("low")
	eq(t._target_id, "", "a Sắt piece cannot take +10")
	var row: Button = t._targets.find_child("Piece_low", true, false)
	check(row != null and row.tooltip_text == "Chỉ lên được +6", "faded, its cap in the tooltip")
	check(row.find_child("CapMark", true, false) != null, "its cap mark")
	eq(t._targets.get_child(0).name, "Piece_t", "the one that can first")
	_close(page)


func test_mirrored_columns() -> void:
	var page := _open(_owned())
	page.select_transfer("s")
	var t = page._transfer
	var a: Control = t._grid.find_child("SourceHex", true, false)
	var b: Control = t._grid.find_child("TargetHex", true, false)
	eq(a.custom_minimum_size, b.custom_minimum_size, "equal columns round the arrow")
	eq(t._grid.get_child(4).name, "Arrow", "the arrow in the middle column")
	_close(page)


func test_upgrade_tab_at_cap_points_to_transfer() -> void:
	var page := _open([Fixture.piece("i", "armor_lv10", 6, 6)])
	page.select_piece("i")
	page._render()
	check(page._go.disabled, "NÂNG CẤP off at the cap")
	eq(page._reason.text, "Đã đạt trần, hãy Chuyển hoá", "the hint")
	var note: Label = page._center.find_child("Note", true, false)
	eq(note.text, "Đã đạt trần +6", "the note")
	var go: Button = page._center.find_child("ToTransfer", true, false)
	check(go != null, "the way on")
	go.pressed.emit()
	eq(page._sub, UpgradePage.TRANSFER, "opens Chuyển hoá")
	eq(page._transfer._source_id, "i", "with the piece as the source")
	_close(page)


func test_cap_marks() -> void:
	PlayerState.catalog = Fixture.catalog()
	var bar := EquipmentUi.level_bar(3, 0.0, 6)
	eq(bar.get_meta("cap", -1), 6, "the bar knows its cap")
	eq(bar.tooltip_text, "Trần +6", "and says it")
	check(not EquipmentUi.level_bar(3, 0.0, -1).has_meta("cap"), "no cap: the old bar")
	var row := EquipmentUi.piece_row(Fixture.piece("i", "armor_lv10", 2, 6), false, func(): pass)
	check(row.find_child("CapMark", true, false) != null, "a list row shows the cap")
	var top := EquipmentUi.piece_row(Fixture.piece("d", "armor_lv40", 2, 16), false, func(): pass)
	check(top.find_child("CapMark", true, false) == null, "+16 is the bar's end: no mark")
	row.free()
	top.free()
	bar.free()
	PlayerState.catalog = null
