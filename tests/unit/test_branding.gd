extends "res://tests/test_case.gd"
## The first screens' art: the logo and the two pictures are in the project, the framed drawing
## (ui/art.gd frame_rect(): cover, but the squad / the forts never cut), the edge colours a tall screen's
## band is painted with, the boot splash and app icon
## settings pointing at files that exist (export-time files, never loaded at run time).

const Art := preload("res://ui/art.gd")
const Brand := preload("res://ui/brand.gd")
const Splash := preload("res://screens/splash.gd")
const Login := preload("res://screens/login.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")

const TEX := Vector2(2048, 1144)


func test_branding_art_is_in_the_project() -> void:
	check(Art.logo() != null, "the logo")
	for key in [Art.BG_LOGIN, Art.BG_LOADING]:
		eq(Art.background_key(key), key, "%s has its picture" % key)
		var t := Art.background(key)
		check(t.get_width() <= 2048, "%s at most 2048 wide" % key)
	check(GlyphIcon.KINDS.has("offline") and GlyphIcon.KINDS.has("retry"), "the failure glyphs")


func test_frame_rect_is_cover_when_keep_fits() -> void:
	var r := Art.frame_rect(TEX, Vector2(1600, 900), Login.KEEP, Login.ALIGN)
	check(r.position.x <= 0.0 and r.position.y <= 0.0 and r.end.x >= 1600.0 and r.end.y >= 900.0, "16:9 covered: %s" % r)
	near(r.size.x / r.size.y, TEX.x / TEX.y, 0.0001, "aspect kept")
	var c := Art.frame_rect(TEX, Vector2(1600, 900))
	near(c.size.y, 900.0, 0.01, "no keep: cover, full height")
	near(c.position.x * 2.0 + c.size.x, 1600.0, 0.01, "no keep: centred")


func test_frame_rect_never_cuts_the_keep_region() -> void:
	for keep in [Login.KEEP, Splash.KEEP]:
		for rect in [Vector2(1600, 900), Vector2(1600, 1200), Vector2(1950, 900), Vector2(2100, 900), Vector2(3200, 900)]:
			var r := Art.frame_rect(TEX, rect, keep, Login.ALIGN)
			var k0: Vector2 = r.position + keep.position * r.size
			var k1: Vector2 = r.position + keep.end * r.size
			check(k0.x >= -0.01 and k0.y >= -0.01 and k1.x <= rect.x + 0.01 and k1.y <= rect.y + 0.01, "%s in %s: keep on screen (%s..%s)" % [keep, rect, k0, k1])
			near(r.size.x / r.size.y, TEX.x / TEX.y, 0.0001, "aspect kept")
	# 4:3: the picture shrinks to the keep width, the sky band goes on top (align 0.8)
	var r := Art.frame_rect(TEX, Vector2(1600, 1200), Login.KEEP, Login.ALIGN)
	check(r.position.y > 0.0, "a band above the picture")
	check(r.end.y < 1200.0 and 1200.0 - r.end.y < r.position.y, "less below than above")
	near(r.size.x * Login.KEEP.size.x, 1600.0, 0.5, "keep spans the width")


func test_edge_strips_follow_the_picture() -> void:
	var top := Art.edge_strip(Art.BG_LOGIN, Art.SIDE_TOP)
	eq(top.get_size(), Vector2(Art.EDGE_STRIP_PX, 1), "top strip across")
	eq(Art.edge_strip(Art.BG_LOGIN, Art.SIDE_LEFT).get_size(), Vector2(1, Art.EDGE_STRIP_PX), "left strip down")
	check(Art.edge_strip(Art.BG_LOGIN, Art.SIDE_TOP) == top, "made once")
	var sky := top.get_image().get_pixel(Art.EDGE_STRIP_PX / 2, 0)
	check(sky.b > sky.r and sky.b > sky.g * 0.9, "the login picture's top is sky blue: %s" % sky)
	var grass := Art.edge_strip(Art.BG_LOGIN, Art.SIDE_BOTTOM).get_image().get_pixel(Art.EDGE_STRIP_PX / 2, 0)
	check(grass.g > grass.r and grass.g > grass.b, "its bottom is grass: %s" % grass)


func test_boot_splash_and_icons_point_at_files() -> void:
	var splash := str(ProjectSettings.get_setting("application/boot_splash/image"))
	check(FileAccess.file_exists(splash), "boot splash %s" % splash)
	eq(int(ProjectSettings.get_setting("application/boot_splash/stretch_mode")), 4, "boot splash cover")
	var bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	check(bg.is_equal_approx(Brand.SPLASH_BG), "boot splash colour = Brand.SPLASH_BG")
	var img := Image.load_from_file(ProjectSettings.globalize_path(splash))
	var corner := img.get_pixel(4, 4)
	check(absf(corner.r - Brand.SPLASH_BG.r) < 0.01 and absf(corner.g - Brand.SPLASH_BG.g) < 0.01 and absf(corner.b - Brand.SPLASH_BG.b) < 0.01, "splash.png drawn on SPLASH_BG: %s" % corner)
	var icon := str(ProjectSettings.get_setting("application/config/icon"))
	check(FileAccess.file_exists(icon), "project icon %s" % icon)
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK, "presets")
	var n := 0
	for section in cfg.get_sections():
		for key in cfg.get_section_keys(section):
			if key.begins_with("icons/") or key == "application/icon" or key.begins_with("storyboard/custom_image"):
				var path := str(cfg.get_value(section, key))
				check(FileAccess.file_exists(path), "%s %s exists" % [key, path])
				n += 1
				if key.begins_with("icons/"):
					var i := Image.load_from_file(ProjectSettings.globalize_path(path))
					check(not i.detect_alpha(), "%s has no alpha (App Store)" % key)
					var want := key.get_slice("_", key.get_slice_count("_") - 1).get_slice("x", 0)
					eq(i.get_width(), int(want), "%s size" % key)
	check(n >= 18, "iOS icons, the macOS icon and the launch images set (%d)" % n)


static func _count(node: Node, cls: String) -> int:
	var n := 1 if node.get_class() == cls else 0
	for c in node.get_children():
		n += _count(c, cls)
	return n
