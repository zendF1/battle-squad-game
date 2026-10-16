extends "res://tests/test_case.gd"

const Art := preload("res://ui/art.gd")
## match/views/player_view.gd ART_SCALE: world px per character px (1.6 px per art unit).
const MATCH_ART_SCALE := 0.35


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
		if Art.has_side_view(id):
			continue # test_side_view_frames_share_one_pivot
		for anim in Art.ANIMS:
			for i in int(Art.ANIMS[anim]["frames"]):
				var img := Image.load_from_file(ProjectSettings.globalize_path(Art.frame_path(id, anim, i)))
				if img == null:
					check(false, "frame %s %s %d loads" % [id, anim, i])
					continue
				eq(img.get_size(), Art.FRAME_SIZE, "%s %s_%d canvas" % [id, anim, i])


func test_sprite_frames_have_every_animation() -> void:
	for id in Art.CHARACTERS:
		var look := Art.character_look(id)
		for anim in Art.ANIMS:
			check(look["frames"].has_animation(anim) and look["frames"].get_frame_count(anim) > 0, "%s look has %s" % [id, anim])
		if Art.has_side_view(id):
			continue
		var text := FileAccess.get_file_as_string(Art.frames_path(id))
		for anim in Art.ANIMS:
			check(text.contains('"name": &"%s"' % anim), "%s.tres has %s" % [id, anim])
			for i in int(Art.ANIMS[anim]["frames"]):
				check(text.contains(Art.frame_path(id, anim, i)), "%s.tres uses %s_%d" % [id, anim, i])


func test_character_scene_puts_the_feet_on_the_origin() -> void:
	# The scene previews Rookie's side idle in the editor (the code sets the look at runtime).
	var text := FileAccess.get_file_as_string("res://scenes/character/character.tscn")
	var pivot: Vector2 = Art.side_view("rookie")["pivot"]
	check(text.contains("offset = Vector2(%.2f, %.2f)" % [-pivot.x, -pivot.y]), "sprite offset is -the side view's pivot")
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
	var ppu := float(data.get("pxPerUnit", 0.0))
	check(ppu > 0.0, "guns have a px per unit")
	check(FileAccess.file_exists("res://" + str(data.get("source", ""))), "guns imported from art_source/weapons (tools/import_guns.gd)")
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
			# In the match a texture px is MATCH_ART_SCALE / pxPerUnit world px: the held gun about
			# 30–42 world px long next to a ~60 px tall character.
			var long := img.get_used_rect().size.x * MATCH_ART_SCALE / ppu
			check(long >= 30.0 and long <= 44.0, "%s %s %.1f world px long in the match" % [kind, tier, long])
	for tier in Art.GUN_NORMAL_TIERS + Art.GUN_CRAFTED_TIERS:
		check(Art.GUN_TIERS["blaster"].has(tier), "blaster in %s" % tier)
	for kind in Art.CHARACTER_GUNS.values():
		check(Art.GUN_KINDS.has(kind), "character gun %s exists" % kind)
	eq(Art.gun_path("shock_rifle", "dragon"), "res://assets/weapons/shock_rifle/dragon.png", "gun path")


## Every weapon icon (each character's gun in the shop tiers, the blaster in every tier) is a
## full-size picture with a gun on it (tools/import_guns.gd cuts them from the gun art).
func test_weapon_icons_present() -> void:
	var paths: Array[String] = []
	for kind in Art.EQUIP_WEAPON_KINDS:
		for tier in Art.EQUIP_KIND_TIERS:
			paths.append(Art.equipment_weapon_path(kind, tier))
	for tier in Art.EQUIP_TIERS:
		paths.append(Art.equipment_icon_path("weapon", tier))
	for path in paths:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			check(false, "%s loads" % path)
			continue
		eq(img.get_size(), Art.EQUIP_ICON_SIZE, "%s size" % path)
		check(img.get_used_rect().size.x >= Art.EQUIP_ICON_SIZE.x * 0.8, "%s: the gun fills the icon's width" % path)


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
	eq(g["scale"], Art.PX_PER_UNIT / float(Art.guns_data()["pxPerUnit"]), "texture px → character px from weapons.json pxPerUnit")


func test_gun_anchors_cover_every_frame() -> void:
	for id in Art.CHARACTERS:
		var anchors := Art.gun_anchors(id)
		var look := Art.character_look(id)
		for anim in Art.ANIMS:
			var n: int = look["frames"].get_frame_count(anim)
			if not look["side"]:
				eq(n, int(Art.ANIMS[anim]["frames"]), "%s %s baked frames" % [id, anim])
			var frames: Array = anchors.get(anim, [])
			eq(frames.size(), n, "%s %s anchors" % [id, anim])
			for i in frames.size():
				var a: Dictionary = frames[i]
				check(Rect2(Vector2.ZERO, look["size"]).has_point(a["grip"]), "%s %s_%d grip inside the frame" % [id, anim, i])
				eq(a["front"], anim != "die", "%s %s_%d front" % [id, anim, i])
				if look["side"]:
					if anim != "die": # die turns the gun level with the fallen body
						check(absf(a["angle"]) <= 20.0, "%s %s_%d gun kept near level (%.1f°)" % [id, anim, i, a["angle"]])
					continue # the side view draws its own hand (hand.png) over the grip
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


func test_character_hands_free_hides_the_gun() -> void:
	var c: Node2D = preload("res://scenes/character/character.tscn").instantiate()
	c.hands_free = true
	c.set_weapon("blaster", "gold")
	var holder := Node.new() # not in the tree: _ready runs on add_child below only when inside one
	holder.add_child(c)
	c._ready()
	check(not c.get_node("Flip/Gun/Sprite").visible, "no gun sprite")
	check(not c.get_node("Flip/Gun/Flash").visible, "no muzzle flash")
	check(c.get_node("Flip/Gun/Hand").visible and c.get_node("Flip/Sprite").visible, "the frames with the bare hand")
	eq(c.weapon()["kind"], "blaster", "the gun set is still known")
	holder.free()


## A side view (assets/characters/<id>/side/, tools/import_frames.gd): every frame on one
## canvas, the soles on the pivot row, the hips centred on the pivot (no left / right jitter).
func test_side_view_frames_share_one_pivot() -> void:
	check(Art.has_side_view("rookie"), "rookie has a side view")
	for id in Art.CHARACTERS:
		if not Art.has_side_view(id):
			continue
		var look := Art.side_view(id)
		check(not look.is_empty(), "%s side view loads" % id)
		if look.is_empty():
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(Art.side_json_path(id)))
		var pivot: Vector2 = look["pivot"]
		var size: Vector2 = look["size"]
		check(Rect2(Vector2.ZERO, size).has_point(pivot - Vector2(0, 0.5)), "%s pivot inside the canvas" % id)
		near(float(look["scale"]), Art.PX_PER_UNIT / float(data["pxPerUnit"]), 0.0001, "%s scale" % id)
		var hips: Array = []
		var stems := {}
		for anim in data["anims"]:
			for stem in data["anims"][anim]["frames"]:
				stems[str(stem)] = true
		for stem in stems:
				var path := Art.side_dir(id) + str(stem) + ".png"
				var img := Image.load_from_file(ProjectSettings.globalize_path(path))
				if img == null:
					check(false, path + " loads")
					continue
				eq(Vector2(img.get_size()), size, "%s canvas" % path)
				var used := _opaque_rect(img)
				check(absf(used.end.y - pivot.y) <= 1.0, "%s soles on the pivot row (%d vs %.1f)" % [path, used.end.y, pivot.y])
				var faint := img.get_used_rect()
				check(faint.position.x > 0 and faint.position.y > 0 and faint.end.x < img.get_width() and faint.end.y < img.get_height(), "%s not cut at the edge" % path)
				# The hip rows' middle (the importer's hipRows) stays on the pivot.
				var y := int(pivot.y - float(look["height"]) * 0.23)
				var x0 := -1
				var x1 := -1
				for x in img.get_width():
					if img.get_pixel(x, y).a > 0.5:
						x1 = x
						if x0 < 0:
							x0 = x
				hips.append((x0 + x1 + 1) * 0.5)
		for h in hips:
			check(absf(float(h) - pivot.x) <= 0.12 * float(look["height"]), "%s hips near the pivot (%.1f vs %.1f)" % [id, h, pivot.x])
		var walk: Array = data["anims"]["walk"]["frames"]
		check(walk.size() >= 4 and bool(data["anims"]["walk"]["loop"]), "%s walk loops over its frames" % id)
		check(look["hand"] != null, "%s hand.png" % id)


## The rect of the pixels at least half opaque.
func _opaque_rect(img: Image) -> Rect2i:
	var r := Rect2i()
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				r = Rect2i(x, y, 1, 1) if r.size == Vector2i.ZERO else r.expand(Vector2i(x, y)).merge(Rect2i(x, y, 1, 1))
	return r


func test_side_view_motion_poses() -> void:
	var C := load("res://scenes/character/character.gd")
	var ext := {"back": 90.0, "front": 90.0, "top": 280.0}
	eq(C.motion_pose("", 0.5, 1.0, ext), {"pos": Vector2.ZERO, "rot": 0.0, "scale": Vector2.ONE}, "no motion")
	var kick: Dictionary = C.motion_pose("recoil", 0.12, 0.0, ext)
	check(kick["pos"].x < 0.0 and kick["rot"] < 0.0, "recoil kicks back")
	var rest: Dictionary = C.motion_pose("recoil", 1.0, 0.0, ext)
	check(rest["pos"].length() < 0.01 and absf(rest["rot"]) < 0.001, "recoil ends at rest")
	check(C.motion_pose("knockback", 0.2, 0.0, ext)["pos"].x < 0.0, "hurt pushes back")
	var lying: Dictionary = C.motion_pose("fall", 1.0, 0.0, ext)
	near(lying["rot"], -PI / 2, 0.01, "dead: on its back")
	check(lying["pos"].y < 0.0, "lifted so the backpack stays on the ground")
	var b: Dictionary = C.motion_pose("breathe", 0.0, 0.6, ext)
	check(b["scale"].y > 1.0 and b["scale"].y < 1.03, "breathing is subtle")


## Facing left mirrors round the feet: no jump, the gun mirrored (not upside down), the muzzle
## mirrored too.
func test_side_view_faces_left_round_the_feet() -> void:
	var c: Node2D = preload("res://scenes/character/character.tscn").instantiate()
	c.character_id = "rookie"
	var holder := Node2D.new()
	holder.add_child(c)
	c._ready() # not in the tree: the setters below skip their update, done by hand as they would
	var flip: Node2D = c.get_node("Flip")
	var gun: Node2D = c.get_node("Flip/Gun")
	var sprite: AnimatedSprite2D = c.get_node("Flip/Sprite")
	var look := Art.character_look("rookie")
	near(sprite.scale.x, float(look["scale"]), 0.0001, "side view drawn at its scale")
	eq(sprite.offset, -look["pivot"], "side view drawn at its pivot")
	var flash: Node2D = c.get_node("Flip/Gun/Flash")
	var muzzle := func() -> Vector2: return flip.transform * gun.transform * flash.position # out of the tree: local
	var right: Vector2 = muzzle.call()
	var grip_right: Vector2 = flip.transform * gun.position
	c.facing = -1
	c._apply_motion()
	c._update_gun()
	var left: Vector2 = muzzle.call()
	near(left.x, -right.x, 0.01, "muzzle mirrored round the feet")
	near(left.y, right.y, 0.01, "muzzle at the same height")
	near((flip.transform * gun.position).x, -grip_right.x, 0.01, "grip mirrored")
	check((flip.transform * gun.transform).y.y > 0.0, "the gun is not upside down")
	check((flip.transform * gun.transform).x.x < 0.0, "the gun points left")
	eq(flip.position, Vector2.ZERO, "no jump: the feet stay on the origin")
	check(right.x > 0.0, "facing right the muzzle is in front")
	holder.free()
