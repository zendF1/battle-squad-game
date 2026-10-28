extends "res://tests/test_case.gd"
## The pictures outside the match have at least twice the px they are drawn with at the 1600 × 900
## design size (a 2560 × 1440 window shows them 1.6 ×, 4K 2.4 ×), so a big window stays sharp.
## The guns outside the match are drawn from high-resolution pictures (assets/weapons/<kind>/ui_<tier>.png,
## Art.ui_gun_texture()), not the small match sprites magnified: every gun and tier has one on the
## match picture's canvas, at least twice as many px as the lobby / Nhân vật pedestal draws it
## (design px, so a 2× window stays sharp), and the gun icons at least twice the biggest icon box.

const Art := preload("res://ui/art.gd")
const PedestalGun := preload("res://screens/home/pedestal_gun.gd")

## The biggest box an equipment icon is shown in (screens/home/bag_page.gd: the Kho đồ card).
const BIGGEST_ICON_PX := 112
## The biggest box an icon (assets/icons/<name>.png) is shown in (the Kho đồ item rows, 64).
const BIGGEST_ITEM_ICON_PX := 64
## The biggest box a stone is shown in (screens/home/upgrade_page.gd: the Ghép đá result, 150).
const BIGGEST_STONE_PX := 150
## The biggest box a slot silhouette is shown in (screens/home/character_page.gd: an empty slot, 70).
const BIGGEST_SLOT_PX := 70
## The lobby stage draws a character at 2.5 px per art unit (screens/home/lobby.gd), the Nhân vật
## page and Prep no bigger.
const LOBBY_PX_PER_UNIT := 2.5


func test_every_gun_has_a_ui_picture_on_the_match_canvas() -> void:
	for kind in Art.GUN_KINDS:
		for tier in Art.GUN_TIERS[kind]:
			var g := Art.gun(kind, tier)
			eq([g["kind"], g["tier"]], [kind, tier], "%s %s: its own picture" % [kind, tier])
			var path := Art.ui_gun_path(kind, tier)
			check(FileAccess.file_exists(path), "%s exists" % path)
			check(FileAccess.file_exists(path + ".import") and FileAccess.get_file_as_string(path + ".import").contains("mipmaps/generate=true"),
				"%s is imported with mipmaps (drawn smaller on the party slots and Prep)" % path)
			var ui := Art.ui_gun_texture(g)
			check(ui != null and ui != g["texture"], "%s %s: the UI picture, not the match one" % [kind, tier])
			if ui == null:
				continue
			var r: Vector2 = ui.get_size() / g["texture"].get_size()
			near(r.x, r.y, 0.05 * r.x, "%s %s: the same canvas as the match picture (%s)" % [kind, tier, r])


func test_the_pedestal_draws_at_most_half_the_ui_picture_px() -> void:
	for kind in Art.GUN_KINDS:
		for tier in Art.GUN_TIERS[kind]:
			var p := PedestalGun.new()
			p.set_gun(kind, tier)
			var l: Dictionary = p._layout()
			var drawn: float = l["part"].size.x * float(l["k"]) # design px of the gun's length on the stage
			var g := Art.gun(kind, tier)
			var ui := Art.ui_gun_texture(g)
			var ui_px: float = l["part"].size.x * ui.get_size().x / g["texture"].get_size().x # its px in the UI picture
			check(drawn > 150.0, "%s %s: drawn big on the stage (%.0f px)" % [kind, tier, drawn])
			check(ui_px >= 2.0 * drawn, "%s %s: %.0f UI px for %.0f design px" % [kind, tier, ui_px, drawn])
			p.free()


func test_gun_icons_are_twice_the_biggest_icon_box() -> void:
	var paths: Array = []
	for kind in Art.EQUIP_WEAPON_KINDS:
		for tier in Art.EQUIP_KIND_TIERS:
			paths.append(Art.equipment_weapon_path(kind, tier))
	for tier in Art.EQUIP_TIERS:
		paths.append(Art.equipment_icon_path("weapon", tier))
	for path in paths:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		check(img != null and img.get_width() >= 2 * BIGGEST_ICON_PX, "%s: %s px for a %d px box" % [path, img.get_size() if img else null, BIGGEST_ICON_PX])


func test_ui_gun_texture_fallback() -> void:
	var fake := {"kind": "nope", "tier": "iron", "texture": Art.placeholder()}
	eq(Art.ui_gun_texture(fake), Art.placeholder(), "no UI picture: the match texture")
	eq(Art.ui_gun_texture({"texture": Art.placeholder()}), Art.placeholder(), "no kind: the match texture")
	eq(Art.ui_gun_path("water_gun", "dragon"), "res://assets/weapons/water_gun/ui_dragon.png", "path")


func test_full_body_pictures_have_twice_the_px_the_lobby_draws() -> void:
	for id in Art.CHARACTERS:
		var full := Art.lobby_full(id)
		if full.is_empty():
			check(false, "%s full body loads" % id)
			continue
		var stage := LOBBY_PX_PER_UNIT / Art.PX_PER_UNIT # character px → design px on the lobby stage
		var drawn := float(full["height"]) * float(full["scale"]) * stage # design px tall
		check(drawn > 300.0 and drawn < 400.0, "%s drawn %.0f design px tall on the stage" % [id, drawn])
		check(float(full["height"]) >= 2.0 * drawn - 0.5, "%s: %.0f px for %.0f design px" % [id, full["height"], drawn])
		var path := Art.full_path(id) + ".import"
		check(FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).contains("mipmaps/generate=true"),
			"%s full.png mipmapped (drawn smaller on the party slots and Prep)" % id)


func test_equipment_item_and_stone_icons_are_twice_their_biggest_box() -> void:
	for slot in Art.EQUIP_SLOTS:
		if slot == "weapon":
			continue
		for tier in Art.EQUIP_TIERS:
			var img := Image.load_from_file(ProjectSettings.globalize_path(Art.equipment_icon_path(slot, tier)))
			check(img != null and img.get_width() >= 2 * BIGGEST_ICON_PX, "%s %s icon: %s px for a %d px box" % [slot, tier, img.get_size() if img else null, BIGGEST_ICON_PX])
	for slot in Art.EQUIP_SLOTS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(Art.equipment_slot_path(slot)))
		check(img != null and img.get_width() >= 2 * BIGGEST_SLOT_PX, "slot %s silhouette: %s px for a %d px box" % [slot, img.get_size() if img else null, BIGGEST_SLOT_PX])
	for icon_name in Art.ICONS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(Art.icon_path(icon_name)))
		check(img != null and img.get_width() >= 2 * BIGGEST_ITEM_ICON_PX, "icon %s: %s px for a %d px box" % [icon_name, img.get_size() if img else null, BIGGEST_ITEM_ICON_PX])
	for level in range(1, Art.STONE_LEVELS + 1):
		var img := Image.load_from_file(ProjectSettings.globalize_path(Art.stone_path(level)))
		check(img != null and img.get_width() >= 2 * BIGGEST_STONE_PX, "stone %d: %s px for a %d px box" % [level, img.get_size() if img else null, BIGGEST_STONE_PX])
