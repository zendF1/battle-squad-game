extends "res://tests/test_case.gd"
## The equipment widgets without "+N" outside the piece popup: icons and hexagons carry the
## border aura only (from +1, green up to +5); the popup's milestone rows bright when reached,
## dimmed when not; the popup's button sets and the sell reason.

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
	for lv in [0, 1, 3, 5, 6, 10, 16]:
		var icon := EquipmentUi.item_icon(ITEM, {"upgradeLevel": lv}, 74)
		eq(labels(icon).size(), 0, "no +N text on the icon at +%d" % lv)
		var a := auras(icon)
		eq(a.size(), 1 if lv >= 1 else 0, "border aura from +1 (+%d)" % lv)
		if lv >= 1:
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
	var d := UpgradeAura.inside(Vector2(232, 236), 0)
	check(not d.visible, "hidden at +0")
	var g := UpgradeAura.inside(Vector2(232, 236), 3, 8.0, 13.0)
	var g5 := UpgradeAura.inside(Vector2(232, 236), 5, 8.0, 13.0)
	check(g.visible, "shown at +3")
	check(g.material == g5.material, "+1..+5 share the green material")
	check(g.material != c.material, "green is not the +6 sky blue")
	eq(g.material.get_shader_parameter("tint"), U.milestone_color(3), "green tint")
	check(float(g.material.get_shader_parameter("streaks")) <= 1.0, "at most one streak")
	check(float(g.material.get_shader_parameter("speed")) < float(c.material.get_shader_parameter("speed")), "slower than sky blue")
	check(float(g.material.get_shader_parameter("strength")) < float(c.material.get_shader_parameter("strength")), "the subtlest")
	for n in [a, b, c, d, g, g5]:
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


func test_piece_actions() -> void:
	eq(EquipmentUi.piece_actions("rookie", "spark"), ["move", "upgrade", "unequip"], "worn by another: Chuyển cho, Nâng cấp, Tháo")
	eq(EquipmentUi.piece_actions("spark", "spark"), ["upgrade", "unequip"], "worn by this one: Nâng cấp, Tháo")
	eq(EquipmentUi.piece_actions("", "spark"), ["equip", "sell", "discard"], "not worn: Mặc cho, Bán, Vứt")
	eq(EquipmentUi.piece_actions("rookie", "spark", false), ["move", "unequip"], "no Nâng cấp page")
	for who in ["rookie", "spark"]:
		var acts := EquipmentUi.piece_actions(who, "spark")
		check(not acts.has("sell") and not acts.has("discard"), "a worn piece is not sold or thrown away (%s)" % who)


func test_sell_block() -> void:
	var cat := {"items": [], "sellRate": 0.25}
	var normal := {"itemId": "x", "category": "normal", "priceCoin": 1000, "priceGem": 0}
	eq(EquipmentUi.sell_block({"isLocked": false}, normal, cat), "", "sellable")
	eq(EquipmentUi.sell_block({"isLocked": true}, normal, cat), "Đã mặc nên không bán được", "ever worn")
	eq(EquipmentUi.sell_block({}, {"category": "crafted", "priceCoin": 0, "priceGem": 0}, cat), "Đồ chế tạo không bán được", "crafted")
	eq(EquipmentUi.sell_block({}, {"category": "normal", "priceCoin": 0, "priceGem": 0}, cat), "Trang bị này không bán được", "no price")
	eq(EquipmentUi.sell_block({}, normal, null), "", "the catalog loading: Bán waits, no reason")


func test_tier_fill() -> void:
	# The inside of the frame takes a deep shade of the tier colour, brighter toward the border.
	for lv in [1, 6, 10, 14, 16]:
		var a := UpgradeAura.inside(Vector2(232, 236), lv, 11.0, 11.0)
		var m: ShaderMaterial = a.material
		var deep: Color = m.get_shader_parameter("fill_deep")
		var edge: Color = m.get_shader_parameter("fill_edge")
		var tint := U.milestone_color(lv)
		check(float(m.get_shader_parameter("fill")) > 0.8, "+%d filled" % lv)
		check(deep.get_luminance() < 0.12, "+%d deep and dark" % lv)
		check(edge.get_luminance() > deep.get_luminance(), "+%d brighter toward the border" % lv)
		check(edge.get_luminance() < tint.get_luminance(), "+%d darker than the glow" % lv)
		a.free()
	var red: Color = UpgradeAura.fill_colors(5)[0]
	check(red.r > red.g * 3.0 and red.r > red.b * 3.0, "red → dark crimson")
	var purple: Color = UpgradeAura.fill_colors(4)[0]
	check(purple.b > purple.g and purple.r > purple.g, "purple → deep violet")
	var orange: Color = UpgradeAura.fill_colors(3)[0]
	check(orange.r > orange.g and orange.g > orange.b, "orange → dark amber")
	var sky: Color = UpgradeAura.fill_colors(2)[0]
	check(sky.b > sky.g and sky.b > sky.r, "sky blue → deep blue")
	var green: Color = UpgradeAura.fill_colors(1)[0]
	check(green.g > green.r and green.g > green.b, "green → dark emerald")
	var none := UpgradeAura.inside(Vector2(232, 236), 0, 11.0, 11.0)
	check(not none.visible, "+0 keeps the card's navy")
	none.free()
	var hex := UpgradeAura.around_frame(Vector2(132, 152), 10)
	check(float(hex.material.get_shader_parameter("fill")) > 0.8, "hexagons filled the same way")
	hex.free()
	var badge := EquipmentUi.worn_badge(30)
	eq(badge.custom_minimum_size, Vector2(30, 30), "the worn badge")
	badge.free()
