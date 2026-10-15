extends "res://tests/test_case.gd"

const Art := preload("res://ui/art.gd")


func test_every_art_path_exists() -> void:
	var paths := Art.all_paths()
	check(paths.size() > 100, "all_paths lists the art (%d)" % paths.size())
	for path in paths:
		check(FileAccess.file_exists(path), "missing file " + path)
		if path.ends_with(".png"):
			check(FileAccess.file_exists(path + ".import"), "missing import settings " + path + ".import")


func test_item_icons_exist() -> void:
	for id in preload("res://match/items.gd").ORDER:
		check(Art.ICONS.has(id), "item %s has an icon" % id)


func test_character_frames_match_the_layout() -> void:
	for id in Art.CHARACTERS:
		for anim in Art.ANIMS:
			for i in int(Art.ANIMS[anim]["frames"]):
				var img := Image.load_from_file(ProjectSettings.globalize_path(Art.frame_path(id, anim, i)))
				if img == null:
					check(false, "frame %s %s %d loads" % [id, anim, i])
					continue
				eq(img.get_size(), Art.FRAME_SIZE, "%s %s_%d canvas" % [id, anim, i])


func test_sprite_frames_have_every_animation() -> void:
	for id in Art.CHARACTERS:
		var text := FileAccess.get_file_as_string(Art.frames_path(id))
		for anim in Art.ANIMS:
			check(text.contains('"name": &"%s"' % anim), "%s.tres has %s" % [id, anim])
			for i in int(Art.ANIMS[anim]["frames"]):
				check(text.contains(Art.frame_path(id, anim, i)), "%s.tres uses %s_%d" % [id, anim, i])


func test_character_scene_puts_the_feet_on_the_origin() -> void:
	var text := FileAccess.get_file_as_string("res://scenes/character/character.tscn")
	check(text.contains("offset = Vector2(%d, %d)" % [-int(Art.FRAME_PIVOT.x), -int(Art.FRAME_PIVOT.y)]), "sprite offset is -FRAME_PIVOT")
	check(text.contains("centered = false"), "sprite not centred")


func test_fallbacks() -> void:
	eq(Art.known_character(""), "rookie", "missing id")
	eq(Art.known_character("nope"), "rookie", "unknown id")
	eq(Art.known_character("flora"), "flora", "known id")
	eq(Art.icon_path("gem"), "res://assets/icons/gem.png", "icon path")
	check(Art.item_icon("nope") != null, "unknown item gets a texture")
	check(Art.texture("res://assets/nope.png") == Art.placeholder(), "missing file gets the placeholder")
