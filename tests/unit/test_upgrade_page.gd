extends "res://tests/test_case.gd"
## screens/home/upgrade_page.gd under formula 2: the fill and the chance are shown apart, a tile
## per chance, the warning of an over-fill, the widest price on the button.

const UpgradePage := preload("res://screens/home/upgrade_page.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")


## The contract's rates at the two steps the page is tried on.
static func _catalog(version: int = 2) -> Variant:
	var rows := [{"fromLevel": 9, "toLevel": 10, "upgradeCost": 3000, "maxPercent": 40, "failResetTo": 6, "carefulGemCost": 20,
		"carefulBonusPercent": 30, "coinCost": 4000, "maxPercentBp": 4000, "carefulBonusBp": 3000,
		"effectiveRequiredPower": {"weapon": 9000, "armor": 3000}},
		{"fromLevel": 15, "toLevel": 16, "upgradeCost": 200000, "maxPercent": 10, "failResetTo": 14, "carefulGemCost": 250,
		"carefulBonusPercent": 50, "coinCost": 50000, "maxPercentBp": 1000, "carefulBonusBp": 5000,
		"effectiveRequiredPower": {"weapon": 600000, "armor": 200000}},
		{"fromLevel": 14, "toLevel": 15, "upgradeCost": 80000, "maxPercent": 15, "failResetTo": 14, "coinCost": 0, "maxPercentBp": 1500,
		"carefulBonusBp": 0, "effectiveRequiredPower": {"weapon": 240000, "armor": 80000}}]
	var data := {"items": [{"itemId": "w", "name": "Súng", "slot": "weapon", "isActive": true}], "upgradeRates": rows,
		"weaponUpgradeCostMultiplier": 3, "stones": [{"stoneLevel": 1, "power": 1}, {"stoneLevel": 7, "power": 729}, {"stoneLevel": 12, "power": 177147}]}
	if version > 1:
		data["probabilityFormulaVersion"] = version
	return EquipmentModel.parse_catalog(data)


func _open(level: int, picked: Dictionary, careful: bool = false, catalog: Variant = null) -> Control:
	PlayerState.catalog = catalog if catalog != null else _catalog()
	PlayerState.equipment = [{"equipmentId": "e1", "itemId": "w", "slot": "weapon", "upgradeLevel": level}]
	PlayerState.stones = {1: 20000, 7: 40, 12: 9}
	PlayerState.equipment_stale = false
	PlayerState.stones_stale = false
	PlayerState.profile = {"coin": 900000, "gem": 5000}
	var page = UpgradePage.new()
	page.size = Vector2(1600, 760)
	Engine.get_main_loop().root.add_child(page)
	if not page.is_node_ready(): # the runner's root is not in the tree yet: build it by hand
		page._ready()
	page.select_piece("e1")
	page._picked = picked.duplicate()
	page._careful = careful
	page._render()
	return page


func _close(page: Control) -> void:
	page.free()
	PlayerState.catalog = null
	PlayerState.equipment = null
	PlayerState.stones = null
	PlayerState.equipment_stale = true
	PlayerState.stones_stale = true
	PlayerState.profile = {}


func test_fill_and_chance_shown_apart() -> void:
	var page := _open(9, {1: 3600})
	eq(page._power_label.text, "3.600 / 9.000", "P / C")
	eq(page._fill_label.text, "Đã nạp 40%", "the fill, in its own words")
	near(page._fill_bar.value, 0.4, 1e-9, "the gauge is the fill")
	eq(page._normal_tile["value"].text, "16%", "the normal chance: 40% filled is not 40% success")
	eq(page._careful_tile["value"].text, "20,8%", "the careful chance")
	eq(page._normal_tile["sub"].text, "Tối đa 40%", "the step's maximum")
	eq(page._careful_tile["sub"].text, "Tối đa 52%", "with careful")
	check(not page._over_label.visible, "no warning")
	check(not page._go.disabled, "under-filling can be tried")
	_close(page)


func test_never_rounded_up_to_the_cap() -> void:
	var page := _open(9, {1: 8999})
	eq(page._normal_tile["value"].text, "39,99%", "one power short")
	eq(page._careful_tile["value"].text, "51,98%", "careful")
	eq(page._fill_label.text, "Đã nạp 99,98%", "the fill floors too")
	_close(page)


func test_over_fill_warns_and_stays_allowed() -> void:
	var page := _open(9, {7: 16})
	eq(page._power_label.text, "11.664 / 9.000", "P above C")
	eq(page._fill_label.text, "Đã nạp 100%", "the fill stops at full")
	eq(page._normal_tile["value"].text, "40%", "the chance stops at the maximum")
	check(page._over_label.visible and page._over_label.text.contains("2.664"), "the warning")
	check(not page._go.disabled, "still allowed")
	_close(page)


func test_careful_tile_picks_the_roll() -> void:
	var page := _open(9, {1: 3600})
	page._careful_tile["button"].pressed.emit()
	check(page._careful, "the tile turns it on")
	check(page._chance_of(page._piece())["careful"], "the careful chance rolls")
	page._normal_tile["button"].pressed.emit()
	check(not page._careful, "the other tile turns it off")
	_close(page)


func test_one_centred_tile_without_careful() -> void:
	var page := _open(14, {1: 8000})
	check(page._careful_tile["button"].visible == false, "no careful on this step")
	check(page._normal_tile["button"].visible, "the normal chance alone")
	check(not page._normal_tile["box"].visible, "nothing to choose")
	_close(page)


func test_widest_price_fits_the_button() -> void:
	var page := _open(15, {12: 4}, true)
	eq(page._go_coin_price.text, "150.000", "a weapon pays three times")
	eq(page._go_price.text, "250", "the careful gems")
	check(page._go_text.get_combined_minimum_size().x <= UpgradePage.RIGHT_W - 28 - 40, "fits the button with its margins")
	_close(page)


func test_zero_chance_turns_the_button_off() -> void:
	var page := _open(15, {1: 2})
	eq(page._normal_tile["value"].text, "0%", "too weak")
	check(page._go.disabled, "the server would refuse it")
	eq(page._reason.text, "Đá quá yếu, hãy nạp thêm", "and the page says why")
	_close(page)


func test_older_catalog_keeps_working() -> void:
	var page := _open(9, {7: 2}, false, _catalog(1))
	eq(page._power_label.text, "1.458 / 3.600", "the power reaching the old cap")
	eq(page._normal_tile["value"].text, "16,2%", "formula 1")
	check(not page._go.disabled, "can be pressed")
	_close(page)
