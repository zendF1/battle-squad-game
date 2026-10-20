extends "res://tests/test_case.gd"
## The equipment widgets without "+N" outside the piece popup: icons and hexagons carry the
## border aura only; the popup's milestone rows bright when reached, dimmed when not.

const EquipmentUi := preload("res://screens/home/equipment_ui.gd")
const UpgradeAura := preload("res://screens/home/upgrade_aura.gd")
const U := preload("res://screens/home/upgrade_model.gd")

const ITEM := {"itemId": "normal_armor_lv40", "slot": "armor", "name": "Dragon Vest", "tier": "dragon"}


static func labels(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Label:
			out.append(c)
		out.append_array(labels(c))
	return out


static func auras(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is UpgradeAura:
			out.append(c)
		out.append_array(auras(c))
	return out


func test_icons_have_no_badge() -> void:
	for lv in [0, 3, 6, 10, 16]:
		var icon := EquipmentUi.item_icon(ITEM, {"upgradeLevel": lv}, 74)
		eq(labels(icon).size(), 0, "no +N text on the icon at +%d" % lv)
		var a := auras(icon)
		eq(a.size(), 1 if lv >= 6 else 0, "border aura from +6 (+%d)" % lv)
		if lv >= 6:
			check(a[0].visible, "aura shown at +%d" % lv)
			eq(a[0].shape, UpgradeAura.Shape.RECT, "rounded square round the icon")
			eq(a[0].size, Vector2(74, 74), "kept inside the icon's box")
		icon.free()
	var hex := EquipmentUi.hex_frame(Vector2(132, 152), 14)
	var ha := auras(hex)
	eq(ha.size(), 1, "the hexagon has its aura")
	eq(ha[0].shape, UpgradeAura.Shape.HEX, "hexagon shape")
	check(ha[0].position.x < 0 and ha[0].size.x > 132, "the hexagon's glow spills round it")
	eq(labels(hex).size(), 0, "no text on the hexagon")
	hex.free()


func test_auras_share_materials() -> void:
	var a := UpgradeAura.inside(Vector2(232, 236), 16, 8.0, 13.0)
	var b := UpgradeAura.inside(Vector2(232, 236), 16, 8.0, 13.0)
	var c := UpgradeAura.inside(Vector2(232, 236), 6, 8.0, 13.0)
	check(a.material == b.material, "one material per tier and shape")
	check(a.material != c.material, "another tier, another material")
	var d := UpgradeAura.inside(Vector2(232, 236), 5)
	check(not d.visible, "hidden below +6")
	for n in [a, b, c, d]:
		n.free()


func test_milestone_list_rows() -> void:
	for lv in [3, 10, 16]:
		var col := EquipmentUi.milestone_list(null, lv)
		var rows := col.get_children().filter(func(r): return r.has_meta("reached"))
		eq(rows.size(), 4, "four milestone rows")
		for i in rows.size():
			var reached: bool = lv >= int(U.MILESTONE_FROM[i + 1])
			eq(rows[i].get_meta("reached"), reached, "+%d row %d reached" % [lv, i])
			near(rows[i].modulate.a, 1.0 if reached else U.UNREACHED_ALPHA, 0.001, "+%d row %d alpha" % [lv, i])
		var texts := labels(col).map(func(l): return l.text)
		check(texts.has("+6") and texts.has("+10% chỉ số") and texts.has("+100% chỉ số"), "level and bonus")
		check(not texts.any(func(t): return t.begins_with("Hào quang")), "no aura names")
		col.free()
