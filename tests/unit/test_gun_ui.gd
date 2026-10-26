extends "res://tests/test_case.gd"
## The guns outside the match are drawn from high-resolution pictures (assets/weapons/<kind>/ui_<tier>.png,
## Art.ui_gun_texture()), not the small match sprites magnified: every gun and tier has one on the
## match picture's canvas, at least twice as many px as the lobby / Nhân vật pedestal draws it
## (design px, so a 2× window stays sharp), and the gun icons at least twice the biggest icon box.

const Art := preload("res://ui/art.gd")
const PedestalGun := preload("res://screens/home/pedestal_gun.gd")

## The biggest box an equipment icon is shown in (screens/home/bag_page.gd: the Túi đồ card).
const BIGGEST_ICON_PX := 112


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
