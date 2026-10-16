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


func test_equipment_art_covers_the_model() -> void:
	var M := preload("res://screens/home/equipment_model.gd")
	for slot in M.SLOTS:
		check(Art.EQUIP_SLOTS.has(slot), "slot %s has art" % slot)
	for tier in M.NORMAL_TIERS + M.CRAFTED_TIERS:
		check(Art.EQUIP_TIERS.has(tier), "tier %s has art" % tier)
	eq(Art.equipment_icon_path("boots", "gold"), "res://assets/icons/equipment/boots_gold.png", "icon path")
	eq(Art.equipment_slot_path("weapon"), "res://assets/icons/equipment/slot_weapon.png", "slot path")
	check(Art.all_paths().has(Art.EQUIP_BADGE), "badge listed")
	var img := Image.load_from_file(ProjectSettings.globalize_path(Art.equipment_icon_path("weapon", "iron")))
	check(img != null and img.get_size() == Art.EQUIP_ICON_SIZE, "icon size")
	img = Image.load_from_file(ProjectSettings.globalize_path(Art.equipment_frame_path("hex_empty")))
	check(img != null and img.get_size() == Art.EQUIP_FRAME_SIZE, "frame size")
	check(Art.equipment_icon("ring", "iron") != null, "unknown slot gets a texture")
	eq(Art.equipment_weapon_path("cannon", "dragon"), "res://assets/icons/equipment/weapon_cannon_dragon.png", "gun icon path")
	for kind in M.WEAPON_KINDS.values():
		check(Art.EQUIP_WEAPON_KINDS.has(kind), "gun %s has art" % kind)
		img = Image.load_from_file(ProjectSettings.globalize_path(Art.equipment_weapon_path(kind, "iron")))
		check(img != null and img.get_size() == Art.EQUIP_ICON_SIZE, "%s icon size" % kind)
	check(Art.equipment_icon("weapon", "gold", "bazooka") != null, "a gun in a crafted tier gets the blaster")


func test_gun_sprites_match_their_metadata() -> void:
	var data := Art.guns_data()
	eq(float(data.get("pxPerUnit", 0.0)), Art.PX_PER_UNIT, "guns drawn at the characters' px per unit")
	for kind in Art.GUN_KINDS:
		check(Art.GUN_TIERS[kind].has(Art.GUN_BASIC), "%s has a basic gun" % kind)
		for tier in Art.GUN_TIERS[kind]:
			var path := Art.gun_path(kind, tier)
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img == null:
				check(false, "%s loads" % path)
				continue
			var meta := Art.gun_meta(kind, tier)
			check(not meta.is_empty(), "%s %s in weapons.json" % [kind, tier])
			if meta.is_empty():
				continue
			var e: Dictionary = data["guns"][kind][tier]
			eq(Vector2i(int(e["size"][0]), int(e["size"][1])), img.get_size(), "%s %s size" % [kind, tier])
			var r := Rect2(Vector2.ZERO, Vector2(img.get_size()))
			check(r.has_point(meta["grip"]) and r.has_point(meta["muzzle"]), "%s %s grip / muzzle inside the image" % [kind, tier])
			check(meta["muzzle"].x > meta["grip"].x, "%s %s muzzle in front of the grip (facing right)" % [kind, tier])
			check(img.get_pixelv(Vector2i(meta["grip"])).a > 0.5, "%s %s grip on the gun" % [kind, tier])
	for tier in Art.GUN_NORMAL_TIERS + Art.GUN_CRAFTED_TIERS:
		check(Art.GUN_TIERS["blaster"].has(tier), "blaster in %s" % tier)
	for kind in Art.CHARACTER_GUNS.values():
		check(Art.GUN_KINDS.has(kind), "character gun %s exists" % kind)
	eq(Art.gun_path("shock_rifle", "dragon"), "res://assets/weapons/shock_rifle/dragon.png", "gun path")


func test_gun_fallbacks() -> void:
	eq(Art.gun_meta("cannon", "gold"), {}, "no crafted cannon")
	eq(Art.gun_meta("ray_gun", "iron"), {}, "unknown kind")
	var placeholder_ok := func(g: Dictionary) -> bool: return g["texture"] != null and g["grip"] is Vector2
	if not ResourceLoader.exists(Art.gun_path("cannon", "basic")):
		check(placeholder_ok.call(Art.gun("cannon", "gold")), "not imported yet: still a texture")
		return
	var g := Art.gun("cannon", "gold")
	eq([g["kind"], g["tier"]], ["cannon", "basic"], "missing tier → the kind's basic")
	g = Art.gun("ray_gun", "iron")
	eq([g["kind"], g["tier"]], ["bazooka", "basic"], "unknown kind → Rookie's basic bazooka")
	g = Art.gun("blaster", "diamond")
	eq([g["kind"], g["tier"]], ["blaster", "diamond"], "crafted blaster")
	eq(g["scale"], 1.0, "drawn 1:1 on the frames")


func test_gun_anchors_cover_every_frame() -> void:
	for id in Art.CHARACTERS:
		var anchors := Art.gun_anchors(id)
		for anim in Art.ANIMS:
			var n: int = Art.ANIMS[anim]["frames"]
			var frames: Array = anchors.get(anim, [])
			eq(frames.size(), n, "%s %s anchors" % [id, anim])
			for i in frames.size():
				var a: Dictionary = frames[i]
				check(Rect2(Vector2.ZERO, Vector2(Art.FRAME_SIZE)).has_point(a["grip"]), "%s %s_%d grip inside the frame" % [id, anim, i])
				eq(a["front"], anim != "die", "%s %s_%d front" % [id, anim, i])
				# The hand is drawn in the frame at the grip: an opaque pixel there.
				var img := Image.load_from_file(ProjectSettings.globalize_path(Art.frame_path(id, anim, i)))
				if img != null:
					check(img.get_pixelv(Vector2i(a["grip"])).a > 0.5, "%s %s_%d hand at the grip" % [id, anim, i])
		check(float(anchors["shoot"][0]["flash"]) > 0.5 and float(anchors["shoot"][2]["flash"]) == 0.0, "%s muzzle flash on the first shoot frame" % id)
	eq(Art.gun_anchor("nope", "idle", 0), Art.gun_anchor("rookie", "idle", 0), "unknown character → rookie's anchors")
	eq(Art.gun_anchor("tanko", "dance", 0), Art.gun_anchor("tanko", "idle", 0), "unknown animation → idle")
	eq(Art.gun_anchor("tanko", "die", 99), Art.gun_anchor("tanko", "die", 3), "past the end → last frame")


func test_character_aim_stays_in_the_arm_reach() -> void:
	var C := load("res://scenes/character/character.gd")
	near(C.aim_elevation(30.0, 1), 30.0, 0.001, "30° facing right")
	near(C.aim_elevation(150.0, -1), 30.0, 0.001, "150° facing left is 30° up")
	near(C.aim_elevation(90.0, 1), C.AIM_UP, 0.001, "straight up: clamped")
	near(C.aim_elevation(-90.0, -1), C.AIM_DOWN, 0.001, "straight down: clamped")
	near(C.aim_elevation(-10.0, 1), -10.0, 0.001, "a little below level")
	near(C.aim_elevation(190.0, -1), -10.0, 0.001, "a little below level, facing left")
	var text := FileAccess.get_file_as_string("res://scenes/character/character.tscn")
	for node in ['name="Gun" type="Node2D" parent="Flip"', 'name="Sprite" type="Sprite2D" parent="Flip/Gun"', 'name="Hand" type="Sprite2D" parent="Flip/Gun"', 'name="Flash" type="Sprite2D" parent="Flip/Gun"']:
		check(text.contains(node), "character.tscn has " + node)
