extends "res://tests/test_case.gd"
## The weapon milestone back aura (scenes/character/back_aura.gd): level → ring, the node's
## sprites, the match player's weaponUpgradeLevel (missing → 0), the worn weapon's level outside
## the match, the screens that show it, the keyed pictures, and the piece popup's weapon rows.

const BackAura := preload("res://scenes/character/back_aura.gd")
const CharacterView := preload("res://ui/character_view.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const EquipmentUi := preload("res://screens/home/equipment_ui.gd")
const U := preload("res://screens/home/upgrade_model.gd")


static func labels(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Label:
			out.append(c)
		out.append_array(labels(c))
	return out


func test_level_to_aura() -> void:
	for lv in [-1, 0, 1, 6, 10, 13]:
		eq(BackAura.aura_for(lv), "", "+%d: none" % lv)
	eq(BackAura.aura_for(14), "purple", "+14 purple")
	eq(BackAura.aura_for(15), "purple", "+15 purple")
	eq(BackAura.aura_for(16), "red", "+16 red")
	eq(BackAura.aura_for(17), "red", "above +16 red")


func test_node_sprites() -> void:
	var a := BackAura.new()
	a.diameter = 200.0
	var ring: Sprite2D = a.get_node("Ring")
	var inner: Sprite2D = a.get_node("Inner")
	eq(a.aura(), "", "starts with none")
	check(not ring.visible and not inner.visible and not a.is_processing(), "+0: hidden, idle")
	a.level = 14
	eq(a.aura(), "purple", "+14")
	check(ring.visible and not inner.visible and a.is_processing(), "+14: one ring, turning")
	check(ring.texture != null and ring.texture.get_width() == 512, "the purple picture")
	near(ring.scale.x * ring.texture.get_width(), 200.0, 200.0 * BackAura.PULSE_SCALE + 0.01, "sized to the diameter")
	a.level = 16
	eq(a.aura(), "red", "+16")
	check(ring.visible and inner.visible, "+16: two rings")
	check(inner.scale.x < ring.scale.x and inner.modulate.a < ring.modulate.a, "the second ring smaller and fainter")
	var r0 := ring.rotation
	var i0 := inner.rotation
	a._process(0.5)
	check(wrapf(ring.rotation - r0, -PI, PI) > 0.0, "the ring turns clockwise")
	check(wrapf(inner.rotation - i0, -PI, PI) < 0.0, "the second ring turns the other way")
	near(wrapf(ring.rotation - r0, -PI, PI), TAU / 8.0 * 0.5, 0.001, "red: a turn in 8 s")
	a.level = 9
	check(not ring.visible and not inner.visible and not a.is_processing(), "back below +14: hidden")
	a.free()


func test_match_player_level() -> void:
	eq(EquipmentModel.player_weapon_level({"weaponUpgradeLevel": 16}), 16, "+16")
	eq(EquipmentModel.player_weapon_level({"weaponUpgradeLevel": 14.0}), 14, "a JSON number")
	eq(EquipmentModel.player_weapon_level({"weaponItemId": "rookie_weapon_lv30"}), 0, "older server: no field")
	eq(EquipmentModel.player_weapon_level({"weaponUpgradeLevel": null}), 0, "null")
	eq(EquipmentModel.player_weapon_level({"weaponUpgradeLevel": "16"}), 0, "not a number")
	eq(EquipmentModel.player_weapon_level({"weaponUpgradeLevel": 99}), 16, "clamped")
	eq(EquipmentModel.player_weapon_level({"weaponUpgradeLevel": -2}), 0, "clamped at 0")


func test_worn_weapon_level() -> void:
	var owned := [
		{"equipmentId": "a", "slot": "armor", "itemId": "normal_armor_lv40", "isEquipped": true, "equippedOn": "spark", "upgradeLevel": 16},
		{"equipmentId": "w", "slot": "weapon", "itemId": "spark_weapon_lv40", "isEquipped": true, "equippedOn": "spark", "upgradeLevel": 14},
		{"equipmentId": "x", "slot": "weapon", "itemId": "rookie_weapon_lv40", "isEquipped": false, "equippedOn": null, "upgradeLevel": 16},
	]
	eq(CharacterView.worn_weapon_level(owned, "spark"), 14, "the worn weapon, not the +16 armour")
	eq(CharacterView.worn_weapon_level(owned, "rookie"), 0, "a +16 weapon in the bag does not count")
	eq(CharacterView.worn_weapon_level(null, "spark"), 0, "not loaded")


func test_screens_with_a_loadout_show_it() -> void:
	for path in ["res://screens/home/lobby.gd", "res://screens/loadout.gd", "res://screens/home/character_page.gd"]:
		check(FileAccess.get_file_as_string(path).contains("_art.back_aura = true"), "%s shows the back aura" % path)
	check(not FileAccess.get_file_as_string("res://screens/home/character_shop_ui.gd").contains("back_aura"), "the shop cards do not")
	check(not FileAccess.get_file_as_string("res://match/views/player_view.gd").contains("BackAura"), "not on the small match sprites")


func test_pictures_are_keyed() -> void:
	for colour in ["purple", "red"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/fx/back_aura_%s.png" % colour))
		check(img != null and img.get_width() == 512 and img.get_height() == 512, "%s 512²" % colour)
		if img == null:
			continue
		check(img.detect_alpha() != Image.ALPHA_NONE, "%s has alpha" % colour)
		for p in [Vector2i(2, 2), Vector2i(509, 2), Vector2i(2, 509), Vector2i(509, 509), Vector2i(256, 256), Vector2i(452, 452)]:
			check(img.get_pixelv(p).a < 0.02, "%s transparent at %s (corners, the hole, the watermark)" % [colour, p])
		# The ring itself is opaque and keeps its hue (red stays red).
		var sum := Color(0, 0, 0, 0)
		var n := 0
		for y in range(0, 512, 4):
			for x in range(0, 512, 4):
				var c := img.get_pixel(x, y)
				if c.a > 0.6:
					sum += Color(c.r, c.g, c.b, 1)
					n += 1
		check(n > 500, "%s has a solid ring" % colour)
		if n == 0:
			continue
		var avg := sum / n
		if colour == "red":
			check(avg.r > 0.6 and avg.b < 0.2 * avg.r and avg.g < 0.4 * avg.r, "red stays red, not pink: %s" % avg)
		else:
			check(avg.b > avg.g and avg.r > avg.g, "purple: %s" % avg)


func test_popup_rows_weapon_vs_armour() -> void:
	var weapon := U.milestone_rows(null, 15, true)
	eq(weapon.map(func(r): return r["back_aura"]), ["", "", "· hào quang tím sau lưng", "· hào quang đỏ sau lưng"], "weapon rows")
	var armour := U.milestone_rows(null, 15)
	eq(armour.map(func(r): return r["back_aura"]), ["", "", "", ""], "armour rows")
	var col := EquipmentUi.milestone_list(null, 15, true)
	var rows := col.get_children().filter(func(r): return r.has_meta("reached"))
	var texts := labels(col).map(func(l): return l.text)
	check(texts.has("+40% chỉ số") and texts.has("· hào quang tím sau lưng") and texts.has("· hào quang đỏ sau lưng"), "weapon: the bonus then the aura")
	near(rows[3].modulate.a, U.UNREACHED_ALPHA, 0.001, "+16 not reached: the row (and its aura text) dimmed")
	near(rows[2].modulate.a, 1.0, 0.001, "+14 reached: bright")
	col.free()
	col = EquipmentUi.milestone_list(null, 15)
	check(not labels(col).any(func(l): return l.text.contains("sau lưng")), "armour: no aura text")
	col.free()
