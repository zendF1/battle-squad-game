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
		if not data["guns"].has(kind):
			# A kind with no held sprites (the bazooka, the cannon, the seed launcher) is its hug art
			# in every tier.
			check(["bazooka", "cannon", "seed_launcher"].has(kind), "%s: only the bazooka, the cannon and the seed launcher have no held sprites" % kind)
			for tier in Art.GUN_TIERS[kind]:
				check(not Art.hug_meta(kind, tier).is_empty() and FileAccess.file_exists(Art.hug_gun_path(kind, tier)), "%s %s hug art" % [kind, tier])
				check(not FileAccess.file_exists(Art.gun_path(kind, tier)), "no old %s %s sprite" % [kind, tier])
				check(not Art.all_paths().has(Art.gun_path(kind, tier)), "%s %s sprite not listed" % [kind, tier])
			continue
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
	eq(Art.gun_meta("shock_rifle", "gold"), {}, "no crafted shock rifle")
	eq(Art.gun_meta("ray_gun", "iron"), {}, "unknown kind")
	var placeholder_ok := func(g: Dictionary) -> bool: return g["texture"] != null and g["grip"] is Vector2
	if not ResourceLoader.exists(Art.gun_path("shock_rifle", "basic")):
		check(placeholder_ok.call(Art.gun("shock_rifle", "gold")), "not imported yet: still a texture")
		return
	var g := Art.gun("shock_rifle", "gold")
	eq([g["kind"], g["tier"]], ["shock_rifle", "basic"], "missing tier → the kind's basic")
	g = Art.gun("ray_gun", "iron")
	eq([g["kind"], g["tier"]], [Art.FALLBACK_GUN_KIND, "basic"], "unknown kind → the blaster's basic")
	check(not g["hug"], "a held sprite")
	g = Art.gun("blaster", "diamond")
	eq([g["kind"], g["tier"]], ["blaster", "diamond"], "crafted blaster")
	eq(g["scale"], Art.PX_PER_UNIT / float(Art.guns_data()["pxPerUnit"]), "texture px → character px from weapons.json pxPerUnit")
	eq(Art.gun_scale(), g["scale"], "gun_scale()")
	# The bazooka, the cannon and the seed launcher have no held sprites: wherever a gun is shown
	# (the pedestal) it is the hug art.
	for kind in ["bazooka", "cannon", "seed_launcher"]:
		for tier in Art.GUN_TIERS[kind]:
			g = Art.gun(kind, tier)
			var h := Art.hug_meta(kind, tier)
			check(g["hug"] and g["kind"] == kind and g["tier"] == tier, "%s %s: its hug art" % [kind, tier])
			eq(g["texture"], Art.hug_gun(kind, tier)["texture"], "%s %s: the hug texture" % [kind, tier])
			eq([g["grip"], g["muzzle"]], [h["pivot"], h["muzzle"]], "%s %s: grip = the hold, the hug muzzle" % [kind, tier])
			near(float(g["scale"]), Art.PX_PER_UNIT / float(Art.hug_data()["pxPerUnit"]), 1e-6, "%s %s: hug.json pxPerUnit" % [kind, tier])
		g = Art.gun(kind, "gold")
		eq([g["kind"], g["tier"], g["hug"]], [kind, "basic", true], "%s in a tier it lacks → its basic hug art" % kind)


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
					continue # the side view draws a hand (hand.png, or none with a ready pose) over the grip
				# The hand is drawn in the frame at the grip: an opaque pixel there.
				var img := Image.load_from_file(ProjectSettings.globalize_path(Art.frame_path(id, anim, i)))
				if img != null:
					check(img.get_pixelv(Vector2i(a["grip"])).a > 0.5, "%s %s_%d hand at the grip" % [id, anim, i])
		check(float(anchors["shoot"][0]["flash"]) > 0.5 and float(anchors["shoot"][2]["flash"]) == 0.0, "%s muzzle flash on the first shoot frame" % id)
	eq(Art.gun_anchor("nope", "idle", 0), Art.gun_anchor("rookie", "idle", 0), "unknown character → rookie's anchors")
	eq(Art.gun_anchor("tanko", "dance", 0), Art.gun_anchor("tanko", "idle", 0), "unknown animation → idle")
	eq(Art.gun_anchor("tanko", "die", 99), Art.gun_anchor("tanko", "die", 3), "past the end → last frame")


func test_character_aim_snaps_to_its_directions() -> void:
	var C := load("res://scenes/character/character.gd")
	near(C.aim_elevation(30.0, 1), 45.0, 0.001, "30° facing right shows 45")
	near(C.aim_elevation(150.0, -1), 45.0, 0.001, "150° facing left is 45 up")
	near(C.aim_elevation(90.0, 1), 90.0, 0.001, "straight up reachable")
	near(C.aim_elevation(90.0, -1), 90.0, 0.001, "straight up reachable facing left")
	near(C.aim_elevation(-90.0, -1), -45.0, 0.001, "straight down shows -45")
	near(C.aim_elevation(-10.0, 1), 0.0, 0.001, "a little below level shows level")
	near(C.aim_elevation(190.0, -1), 0.0, 0.001, "a little below level, facing left")
	near(C.aim_elevation(-30.0, 1), -45.0, 0.001, "-30 shows -45")
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
## canvas, the soles on the pivot row, the hips of the run / idle frames centred on the pivot (no
## left / right jitter; a kneeling ready pose only over it). Rookie, Flora and Tanko have one.
func test_side_view_frames_share_one_pivot() -> void:
	for id in ["rookie", "flora", "tanko"]:
		check(Art.has_side_view(id), "%s has a side view" % id)
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
		var ready_stems := {} # the drawn ready pose's frames
		for anim in data.get("readyPose", {}).get("anims", []):
			for stem in data["anims"].get(anim, {}).get("frames", []):
				ready_stems[str(stem)] = true
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
				if ready_stems.has(str(stem)): # a kneeling pose, placed by its alignX (the head on the idle's): over the feet
					check(used.position.x < pivot.x and used.end.x > pivot.x, "%s over the pivot (%s vs %.1f)" % [path, used, pivot.x])
					continue
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
		check(look["hand"] != null or not data.has("hand"), "%s hand.png" % id)
		if data.has("readyPose"): # the gun is held only in the ready pose, by the pose's own fists
			check(not data.has("hand") and not FileAccess.file_exists(Art.side_dir(id) + "hand.png"), "%s with a ready pose: no hand.png" % id)


## The idle frame (idle_0.png) is the standing picture (art_source/characters/<id>/side_idle/
## idle_v1.png), not a run frame: its own pixels, on the shared canvas, about as tall as the run
## frames (the head the same size), inside the extent the HP bar / name tag sit over, and its head
## over the walk frames' (no jump idle <-> walk).
func test_side_view_idle_stands() -> void:
	for id in ["rookie", "flora", "tanko"]:
		var dir := Art.side_dir(id)
		var data = JSON.parse_string(FileAccess.get_file_as_string(dir + "side.json"))
		var idle := Image.load_from_file(ProjectSettings.globalize_path(dir + "idle_0.png"))
		check(idle != null, "%s idle_0.png loads" % id)
		if idle == null:
			continue
		var pivot := Vector2(float(data["pivot"][0]), float(data["pivot"][1]))
		eq(Vector2(idle.get_size()), Vector2(float(data["size"][0]), float(data["size"][1])), "%s idle_0 on the shared canvas" % id)
		var ir := _opaque_rect(idle)
		var hs: Array = []
		var heads: Array = []
		for stem in data["anims"]["walk"]["frames"]:
			var w := Image.load_from_file(ProjectSettings.globalize_path(dir + str(stem) + ".png"))
			check(w.get_data() != idle.get_data(), "%s idle_0 is not %s" % [id, stem])
			var wr := _opaque_rect(w)
			hs.append(wr.size.y)
			heads.append(_head_middle(w, wr))
		hs.sort()
		var med: float = hs[hs.size() / 2]
		check(absf(ir.size.y - med) <= 0.06 * med, "%s idle about as tall as the run frames (%d vs %d px)" % [id, ir.size.y, med])
		check(pivot.y - ir.position.y <= float(data["extent"]["top"]) + 0.5, "%s idle inside the extent's top" % id)
		check(ir.position.x >= pivot.x - float(data["extent"]["back"]) - 0.5 and ir.end.x <= pivot.x + float(data["extent"]["front"]) + 0.5, "%s idle inside the extent" % id)
		heads.sort()
		var hm: float = heads[heads.size() / 2]
		var h := _head_middle(idle, ir)
		check(absf(h - hm) <= 4.0, "%s idle head over the walk's (%.1f vs %.1f px)" % [id, h, hm])


## The middle x of the top 12 % of the figure's rows (the cap / bandana / helmet).
func _head_middle(img: Image, r: Rect2i) -> float:
	var sum := 0.0
	var n := 0
	for y in range(r.position.y, r.position.y + int(r.size.y * 0.12)):
		var x0 := -1
		var x1 := -1
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				x1 = x
				if x0 < 0:
					x0 = x
		if x0 >= 0:
			sum += (x0 + x1 + 1) * 0.5
			n += 1
	return sum / maxi(1, n)


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


## Every character has a ready pose scene (scenes/character/poses/<id>_ready.tscn): a locked root
## → Body (locked) → one GunSocket (grouped) with a Preview (not centred); no hand sprites, no aim
## metadata. Rookie's Preview is its iron hug gun (pose_gun.gd: the picture once imported) with its
## hold on the socket's origin at the weapons' scale, the socket on the hug point between the fists.
## Flora's and Tanko's (side views, no hug art for their kind yet): their iron gun sprite as a
## stand-in (pose_gun.gd: replaced by the hug gun once there is one), its centre on the hug point;
## their Body follows the art (pose_body.gd): the side view's ready frame once imported. Spark's
## keeps its iron gun (grip on the origin) and the baked idle frame as the body. Rookie's, Flora's
## and Tanko's have an ArmFront after GunSocket (drawn over the gun; pose_arm.gd: the front arm
## once imported) at the Body's place; Spark's none until its side.json has a front arm cut.
func test_ready_pose_scenes() -> void:
	var PoseBody := load("res://scenes/character/poses/pose_body.gd")
	var PoseGun := load("res://scenes/character/poses/pose_gun.gd")
	var PoseArm := load("res://scenes/character/poses/pose_arm.gd")
	for id in Art.CHARACTERS:
		var path := "res://scenes/character/poses/%s_ready.tscn" % id
		check(ResourceLoader.exists(path), path)
		if not ResourceLoader.exists(path):
			continue
		var root: Node = load(path).instantiate()
		check(root is Node2D and root.get_meta("_edit_lock_", false), "%s root a locked Node2D" % id)
		check(not root.has_meta("aim_down") and not root.has_meta("aim_up"), "%s no aim metadata" % id)
		var names: Array = root.get_children().map(func(n): return str(n.name))
		var has_arm: bool = PoseArm.arm_path(id) != ""
		check(has_arm or not ["rookie", "flora", "tanko"].has(id), "%s has a front arm cut" % id)
		eq(names, ["Body", "GunSocket", "ArmFront"] if has_arm else ["Body", "GunSocket"], "%s Body, one GunSocket (and the ArmFront over it with a front arm cut), no hand sprites" % id)
		var arm := root.get_node_or_null("ArmFront") as Sprite2D
		var body0 := root.get_node_or_null("Body") as Sprite2D
		if arm != null and body0 != null:
			check(arm.get_meta("_edit_lock_", false), "%s ArmFront locked" % id)
			eq(arm.get_script(), PoseArm, "%s ArmFront shows the front arm once imported" % id)
			eq(str(arm.get("character_id")), id, "%s ArmFront's character" % id)
			eq([arm.position, arm.offset, arm.centered, arm.texture_filter], [body0.position, body0.offset, body0.centered, body0.texture_filter], "%s ArmFront at the Body's place" % id)
			check(arm.scale.is_equal_approx(body0.scale), "%s ArmFront at the Body's scale" % id)
			check(arm.texture == null or arm.texture.resource_path == PoseArm.arm_path(id), "%s ArmFront picture" % id)
			eq(PoseArm.arm_path(id), Art.side_dir(id) + "ready_arm_front.png", "%s the arm the importer cut" % id)
		var sock := root.get_node_or_null("GunSocket") as Node2D
		check(sock != null and sock.get_meta("_edit_group_", false), "%s GunSocket grouped" % id)
		var preview := root.get_node_or_null("GunSocket/Preview") as Sprite2D
		check(preview != null and not preview.centered, "%s GunSocket/Preview, not centred" % id)
		var kind := str(Art.CHARACTER_GUNS[id])
		var gs := float(Art.gun(kind, "iron")["scale"])
		if preview != null and not Art.hug_meta(kind, "iron").is_empty():
			# Rookie's bazooka, Tanko's cannon: the iron hug gun (none until the editor imports it:
			# pose_gun.gd puts it there), its hold on the socket's origin.
			eq(preview.get_script(), PoseGun, "%s Preview shows the hug gun once imported" % id)
			eq([str(preview.get("kind")), str(preview.get("tier"))], [kind, "iron"], "%s Preview: the iron %s" % [id, kind])
			check(preview.texture == null or preview.texture.resource_path == Art.hug_gun_path(kind, "iron"), "%s Preview picture" % id)
			check(not PoseGun.stand_in(preview), "%s no stand-in" % id)
			near(preview.offset.distance_to(-Art.hug_meta(kind, "iron")["pivot"]), 0.0, 0.01, "%s the hold on the socket's origin" % id)
			near(preview.scale.x, gs, 1e-4, "%s hug gun at the weapons' scale" % id)
			near(gs, Art.hug_scale(), 1e-6, "%s the %s is its hug art (hug.json's scale)" % [id, kind])
			var look := Art.side_view(id)
			var hug: Vector2 = (Art.gun_anchor(id, "draw", 0)["grip"] - look["pivot"]) * float(look["scale"])
			check(sock.position.distance_to(hug) < 0.05, "%s socket on the hug point (%s vs %s)" % [id, sock.position, hug])
			# The match draws it as the Preview shows it: the hold on the socket, as long as hug_iron.
			var rp := Art.ready_pose(id)
			check(rp["socket"].is_equal_approx(sock.transform), "%s ready_pose(): the socket" % id)
			eq(rp["pivot"], Art.hug_meta(kind, "iron")["pivot"], "%s ready_pose(): turned round the hold" % id)
			near(float(rp["length"]), Art.hug_meta(kind, "iron")["size"].x, 0.01, "%s ready_pose(): the hug gun's length" % id)
			check((rp["preview"] * rp["pivot"]).length() < 0.01, "%s ready_pose(): the hold on the hug point" % id)
		elif preview != null and Art.has_side_view(id):
			# No hug art for the kind yet: its iron gun sprite stands in, its centre (where the match
			# turns that sprite: Art.hug_gun()) on the socket's origin, on the hug point.
			eq(preview.get_script(), PoseGun, "%s Preview shows the hug gun once there is one" % id)
			eq([str(preview.get("kind")), str(preview.get("tier"))], [kind, "iron"], "%s Preview: the iron %s" % [id, kind])
			check(preview.texture != null and preview.texture.resource_path == Art.gun_path(kind, "iron"), "%s Preview is its iron %s" % [id, kind])
			check(PoseGun.stand_in(preview), "%s the gun sprite is a stand-in" % id)
			near(preview.offset.distance_to(-preview.texture.get_size() * 0.5), 0.0, 0.01, "%s its centre on the socket's origin" % id)
			near(preview.scale.x, gs, 1e-4, "%s gun at the weapons' scale (as long as in hand)" % id)
			var look := Art.side_view(id)
			var hug: Vector2 = (Art.gun_anchor(id, "draw", 0)["grip"] - look["pivot"]) * float(look["scale"])
			check(sock.position.distance_to(hug) < 0.05, "%s socket on the hug point (%s vs %s)" % [id, sock.position, hug])
		elif preview != null:
			check(preview.texture != null and preview.texture.resource_path == Art.gun_path(kind, "iron"), "%s Preview is its iron %s" % [id, kind])
			near(preview.offset.distance_to(-Art.gun(kind, "iron")["grip"]), 0.0, 0.01, "%s the grip on the socket's origin" % id)
			near(preview.scale.x, gs, 1e-4, "%s gun at the match scale" % id)
		var body := root.get_node_or_null("Body") as Sprite2D
		check(body != null and body.get_meta("_edit_lock_", false), "%s Body locked" % id)
		if id != "rookie" and body != null:
			eq(body.get_script(), PoseBody, "%s Body follows the art" % id)
			eq(str(body.get("character_id")), id, "%s Body's character" % id)
			var src: Dictionary = PoseBody.source(id)
			if Art.has_side_view(id):
				var look := Art.side_view(id)
				eq(src["path"], Art.side_dir(id) + "ready_0.png", "%s body: the side view's ready frame" % id)
				check(body.offset.is_equal_approx(-look["pivot"]), "%s the feet on the origin (%s)" % [id, body.offset])
				check(body.scale.is_equal_approx(Vector2.ONE * float(look["scale"])), "%s at the side view's scale" % id)
				check(body.texture == null or body.texture.resource_path == src["path"], "%s body picture (none until imported)" % id)
			else:
				eq(src["path"], Art.frame_path(id, "idle", 0), "%s stand-in body: the baked idle frame" % id)
				eq(src["pivot"], Art.FRAME_PIVOT, "%s stand-in pivot" % id)
				eq(body.offset, -Art.FRAME_PIVOT, "%s the feet on the origin" % id)
				check(Art.ready_pose(id).is_empty(), "%s no ready pose before its side view" % id)
		root.free()
		# The config the importer fills it from names this scene.
		var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://art_source/characters/%s/side_run/import.json" % id))
		check(cfg is Dictionary and str(cfg.get("poses", {}).get("ready", {}).get("scene", "")) == path, "%s import.json names %s" % [id, path])
		check(cfg is Dictionary and not cfg.get("poses", {}).get("ready", {}).has("hands"), "%s no hand cut-outs" % id)
		if cfg is Dictionary:
			eq(str(cfg.get("out", "")), Art.side_dir(id), "%s import.json writes its side view" % id)
	var rookie: Dictionary = PoseBody.source("rookie")
	eq(rookie["path"], Art.side_dir("rookie") + "ready_0.png", "an imported ready frame is the body")
	near(float(rookie["scale"]), float(Art.side_view("rookie")["scale"]), 1e-4, "at the side view's scale")
	eq(PoseBody.source("nope"), {}, "unknown id")
	# After an import (here: Rookie's art in Tanko's scene) the body is the ready frame where the
	# match draws it (Rookie's own scene has it at the same place).
	var scene: Node = load("res://scenes/character/poses/tanko_ready.tscn").instantiate()
	var body: Sprite2D = scene.get_node("Body")
	body.character_id = "rookie"
	body.sync()
	var mine: Node = load("res://scenes/character/poses/rookie_ready.tscn").instantiate()
	for prop in ["texture", "offset", "centered"]:
		eq(body.get(prop), mine.get_node("Body").get(prop), "synced body %s" % prop)
	check(body.scale.is_equal_approx(mine.get_node("Body").scale), "synced body scale")
	# An empty Preview takes no picture before the hug gun is imported; one with a picture keeps it.
	var pv: Sprite2D = mine.get_node("GunSocket/Preview")
	var had := pv.texture
	pv.sync()
	check(pv.texture == had or (pv.texture != null and pv.texture.resource_path == Art.hug_gun_path("bazooka", "iron")), "Preview sync")
	var tex := Art.texture(Art.gun_path("shock_rifle", "iron"))
	pv.texture = tex
	pv.sync()
	eq(pv.texture, tex, "a Preview with a picture is left as it is")
	check(not PoseGun.stand_in(pv), "another kind's gun is no stand-in")
	# A stand-in (its kind's gun sprite) waits for its kind's hug art: none for the shock rifle.
	var sr := Sprite2D.new()
	sr.set_script(PoseGun)
	sr.set("kind", "shock_rifle")
	sr.texture = tex
	check(PoseGun.stand_in(sr), "a Preview showing its kind's gun sprite stands in")
	sr.sync()
	eq(sr.texture, tex, "a stand-in gives way only to its hug gun")
	sr.free()
	# Flora's Preview: the hug seed launcher (empty until the editor imports it).
	var flora: Node = load("res://scenes/character/poses/flora_ready.tscn").instantiate()
	var fl: Sprite2D = flora.get_node("GunSocket/Preview")
	fl.sync()
	check(fl.texture == null or fl.texture.resource_path == Art.hug_gun_path("seed_launcher", "iron"), "Flora's Preview: the hug seed launcher or nothing yet")
	near(fl.offset.distance_to(-Art.hug_meta("seed_launcher", "iron")["pivot"]), 0.0, 0.01, "Flora's Preview: its hold on the socket")
	# Tanko's Preview: the hug cannon (empty until the editor imports it; sync() fills it then).
	var tk: Sprite2D = scene.get_node("GunSocket/Preview")
	tk.sync()
	check(tk.texture == null or tk.texture.resource_path == Art.hug_gun_path("cannon", "iron"), "Tanko's Preview: the hug cannon or nothing yet")
	near(tk.offset.distance_to(-Art.hug_meta("cannon", "iron")["pivot"]), 0.0, 0.01, "Tanko's Preview: its hold on the socket")
	flora.free()
	scene.free()
	mine.free()


## The hug guns (tools/import_hug_guns.gd → assets/weapons/<kind>/hug_<tier>.png + hug.json) and
## the ready pose's choice: the weapon's hug art → its kind's in another tier → its gun sprite
## turned round its centre.
func test_hug_guns() -> void:
	var data := Art.hug_data()
	check(FileAccess.file_exists("res://" + str(data.get("source", ""))), "hug guns imported from art_source/weapons/hug")
	near(float(data.get("pxPerUnit", 0.0)), float(Art.guns_data()["pxPerUnit"]), 1e-6, "at the held guns' scale")
	var H := load("res://tools/import_hug_guns.gd")
	var iron_img := Image.load_from_file(ProjectSettings.globalize_path(Art.hug_gun_path("bazooka", "iron")))
	# Every bazooka tier has its own hug art, the same length (a tier swap does not resize the gun).
	for tier in Art.GUN_TIERS["bazooka"]:
		var m := Art.hug_meta("bazooka", tier)
		check(not m.is_empty(), "the %s bazooka's hug art" % tier)
		if m.is_empty():
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(Art.hug_gun_path("bazooka", tier)))
		check(img != null and Vector2(img.get_size()) == m["size"], "hug_%s.png at its size" % tier)
		if img == null:
			continue
		var used: Rect2i = H.tube_points(img)["rect"]
		near(m["pivot"].x, used.get_center().x, 1.0, "%s hold: the middle of the gun" % tier)
		check(m["pivot"].y > used.position.y + used.size.y * 0.3 and m["pivot"].y < used.end.y - used.size.y * 0.3, "%s hold: in the tube's height" % tier)
		near(m["muzzle"].x, float(used.end.x), 1.0, "%s muzzle: the warhead's tip" % tier)
		near(m["muzzle"].y, m["pivot"].y, 0.01, "%s muzzle: on the tube's axis" % tier)
		near(float(used.size.x) / 2.0, 57.0, 1.0, "%s 57 world px long" % tier)
		check(img.get_pixel(0, 0).a == 0.0, "%s the backdrop keyed out" % tier)
		var green := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.1 and c.g > 0.6 and c.g > maxf(c.r, c.b) + 0.3:
					green += 1
		eq(green, 0, "%s no green-screen pixels left" % tier)
		check(img.get_height() < 48 and used.size.y < 46, "%s the sparkle dropped (it would stretch the picture: %s)" % [tier, used])
		var h := Art.hug_gun("bazooka", tier)
		check(h["hug"] and h["tier"] == tier and h["texture"] != null and h["path"] == Art.hug_gun_path("bazooka", tier), "%s: its own hug art" % tier)
	# basic and steel are the iron picture recoloured (hug.json from / recolour): the same shape and
	# points; basic greyer (the old basic.png's desaturation), steel's olive more saturated, a little
	# yellower, its red warhead as iron's.
	var meta := Art.hug_meta("bazooka", "iron")
	var olive := {}
	var red := {}
	for tier in ["iron", "basic", "steel"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path(Art.hug_gun_path("bazooka", tier)))
		if tier != "iron":
			eq(Art.hug_meta("bazooka", tier), meta, "%s: the iron gun's size / hold / muzzle" % tier)
			var same := true
			for y in img.get_height():
				for x in img.get_width():
					if absf(img.get_pixel(x, y).a - iron_img.get_pixel(x, y).a) > 0.01:
						same = false
			check(same, "%s: the iron gun's shape" % tier)
		var o := Vector3.ZERO # hue (degrees), saturation, count
		var r := Vector2.ZERO # saturation, count
		for y in img.get_height():
			for x in img.get_width():
				var ic := iron_img.get_pixel(x, y)
				var c := img.get_pixel(x, y)
				if ic.a < 0.9 or ic.s < 0.15:
					continue
				if ic.h * 360.0 > 55.0 and ic.h * 360.0 < 125.0:
					o += Vector3(c.h * 360.0, c.s, 1.0)
				elif ic.h * 360.0 < 15.0 or ic.h * 360.0 > 345.0:
					r += Vector2(c.s, 1.0)
		olive[tier] = Vector2(o.x, o.y) / maxf(1.0, o.z)
		red[tier] = r.x / maxf(1.0, r.y)
	near(olive["basic"].y / olive["iron"].y, 0.55, 0.05, "basic: the olive desaturated like the old basic.png")
	near(red["basic"] / red["iron"], 0.55, 0.06, "basic: the warhead too")
	near(olive["steel"].y / olive["iron"].y, 1.25, 0.06, "steel: the olive more saturated (%s vs %s)" % [olive["steel"], olive["iron"]])
	check(olive["steel"].x < olive["iron"].x - 2.0 and olive["steel"].x > olive["iron"].x - 7.0, "steel: a little yellower (%s vs %s)" % [olive["steel"].x, olive["iron"].x])
	near(red["steel"], red["iron"], 0.01, "steel: the warhead as iron's")
	var hug := Art.hug_gun("bazooka", "gold")
	check(hug["hug"] and hug["tier"] == "iron", "a tier with no hug art: the iron one")
	hug = Art.hug_gun("blaster", "gold")
	check(not hug["hug"] and hug["kind"] == "blaster" and hug["tier"] == "gold", "no hug art: the gun sprite")
	eq(hug["pivot"], hug["size"] * 0.5, "turned round its centre, not the grip")
	eq(Art.pose_gun_meta(Art.hug_gun_path("bazooka", "iron")), meta, "a hug picture's meta")
	eq(Art.pose_gun_meta(Art.gun_path("shock_rifle", "iron"))["pivot"], Art.hug_gun("shock_rifle", "iron")["size"] * 0.5, "a gun sprite's: its centre")
	eq(Art.pose_gun_meta("res://assets/icons/coin.png"), {}, "any other picture")
	check(Art.all_paths().has(Art.HUG_DATA), "hug.json listed")
	for tier in Art.GUN_TIERS["bazooka"]:
		check(Art.all_paths().has(Art.hug_gun_path("bazooka", tier)), "hug_%s.png listed" % tier)
	# WYSIWYG: the Preview's own gun drawn as the Preview; another one with its pivot there, as long.
	var pose := {"preview": Transform2D(0.3, Vector2(2.0, 3.0), 0.0, Vector2(5, -7)) * Transform2D(0.0, Vector2(-10, -4)),
		"pivot": Vector2(10, 4), "length": 40.0}
	var own := {"pivot": Vector2(10, 4), "size": Vector2(40, 8)}
	check(Art.gun_transform(pose, own).is_equal_approx(pose["preview"]), "the Preview's gun as shown")
	var other := {"pivot": Vector2(5, 5), "size": Vector2(20, 10)}
	var xf := Art.gun_transform(pose, other)
	check((xf * Vector2(5, 5)).is_equal_approx(pose["preview"] * Vector2(10, 4)), "pivot on the Preview gun's pivot")
	near((xf * Vector2(20, 5) - xf * Vector2(0, 5)).length(), (pose["preview"] * Vector2(40, 4) - pose["preview"] * Vector2(0, 4)).length(), 1e-3, "as long")


## Tanko's cannon is hug art in every tier (art_source/weapons/hug/cannon_<tier>.png; basic the
## iron one desaturated): all 58 world px long, held in the middle, the muzzle the centre of the bore
## opening (the dragon's: its open mouth), keyed clean.
func test_hug_cannon() -> void:
	var H := load("res://tools/import_hug_guns.gd")
	var iron_img := Image.load_from_file(ProjectSettings.globalize_path(Art.hug_gun_path("cannon", "iron")))
	for tier in Art.GUN_TIERS["cannon"]:
		var m := Art.hug_meta("cannon", tier)
		check(not m.is_empty(), "the %s cannon's hug art" % tier)
		if m.is_empty():
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(Art.hug_gun_path("cannon", tier)))
		check(img != null and Vector2(img.get_size()) == m["size"], "cannon hug_%s.png at its size" % tier)
		if img == null:
			continue
		var used: Rect2i = H.tube_points(img)["rect"]
		near(float(used.size.x) / 2.0, 58.0, 1.0, "cannon %s 58 world px long" % tier)
		near(m["pivot"].x, used.get_center().x, 1.0, "cannon %s hold: the middle of the gun" % tier)
		check(m["pivot"].y > used.position.y + used.size.y * 0.3 and m["pivot"].y < used.end.y - used.size.y * 0.3, "cannon %s hold: in the tube's height" % tier)
		check(m["muzzle"].x > used.end.x - used.size.x * 0.12 and m["muzzle"].x < used.end.x - 2.0, "cannon %s muzzle: inside the right end (%s, gun %s)" % [tier, m["muzzle"], used])
		check(absf(m["muzzle"].y - m["pivot"].y) < used.size.y * 0.15, "cannon %s muzzle: near the tube's axis" % tier)
		if tier != "dragon": # the bore: dark, inside the rim
			var bore := img.get_pixelv(Vector2i(m["muzzle"]))
			check(bore.a > 0.9 and bore.v < 0.35, "cannon %s muzzle: in the dark bore (%s)" % [tier, bore])
		else: # the open mouth: between the upper teeth and the jaw
			var above := 0
			var below := 0
			for dy in range(1, 12):
				if img.get_pixelv(Vector2i(m["muzzle"]) - Vector2i(0, dy)).a > 0.5:
					above += 1
				if img.get_pixelv(Vector2i(m["muzzle"]) + Vector2i(0, dy)).a > 0.5:
					below += 1
			check(above > 0 and below > 0, "cannon dragon muzzle: in the mouth, the head above and the jaw below")
		check(img.get_pixel(0, 0).a == 0.0, "cannon %s the backdrop keyed out" % tier)
		var green := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.1 and c.g > 0.6 and c.g > maxf(c.r, c.b) + 0.3:
					green += 1
		eq(green, 0, "cannon %s no green-screen pixels left" % tier)
		check(used.size.y < used.size.x * 0.45, "cannon %s the sparkle dropped (%s)" % [tier, used])
		var h := Art.hug_gun("cannon", tier)
		check(h["hug"] and h["tier"] == tier and h["path"] == Art.hug_gun_path("cannon", tier), "cannon %s: its own hug art" % tier)
	# basic: the iron picture desaturated (the old basic.png's recolour), the same shape and points.
	eq(Art.hug_meta("cannon", "basic"), Art.hug_meta("cannon", "iron"), "basic: the iron cannon's size / hold / muzzle")
	var basic := Image.load_from_file(ProjectSettings.globalize_path(Art.hug_gun_path("cannon", "basic")))
	var same := true
	var sat := Vector3.ZERO # basic, iron, count
	for y in basic.get_height():
		for x in basic.get_width():
			var ic := iron_img.get_pixel(x, y)
			var c := basic.get_pixel(x, y)
			if absf(c.a - ic.a) > 0.01:
				same = false
			if ic.a > 0.9 and ic.s > 0.15:
				sat += Vector3(c.s, ic.s, 1.0)
	check(same, "basic: the iron cannon's shape")
	near(sat.x / sat.y, 0.55, 0.05, "basic: desaturated like the old basic.png")


## Flora's seed launcher is hug art in every tier (art_source/weapons/hug/seed_launcher_<tier>.png
## on magenta; basic the iron one desaturated): all 45 world px long (the back end stays above her
## soles aiming straight up), held in the middle, the muzzle in what sits in the bore (pod /
## crystal / the dragon's seed), keyed clean: no magenta left, the glows un-mixed into their own
## colour.
func test_hug_seed_launcher() -> void:
	var H := load("res://tools/import_hug_guns.gd")
	var iron_img := Image.load_from_file(ProjectSettings.globalize_path(Art.hug_gun_path("seed_launcher", "iron")))
	var rp := Art.ready_pose("flora")
	for tier in Art.GUN_TIERS["seed_launcher"]:
		var m := Art.hug_meta("seed_launcher", tier)
		check(not m.is_empty(), "the %s seed launcher's hug art" % tier)
		if m.is_empty():
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(Art.hug_gun_path("seed_launcher", tier)))
		check(img != null and Vector2(img.get_size()) == m["size"], "seed launcher hug_%s.png at its size" % tier)
		if img == null:
			continue
		eq(m["size"].x, Art.hug_meta("seed_launcher", "iron")["size"].x, "seed launcher %s as wide as the iron one (drawn at its length)" % tier)
		var solid := img.duplicate() as Image # the gun without its glow (alpha > 127 only)
		var used: Rect2i = H.tube_points(solid)["rect"]
		near(float(used.size.x) / 2.0, 45.0, 1.0, "seed launcher %s 45 world px long" % tier)
		near(m["pivot"].x, used.get_center().x, 1.0, "seed launcher %s hold: the middle of the gun" % tier)
		check(m["pivot"].y > used.position.y + used.size.y * 0.3 and m["pivot"].y < used.end.y - used.size.y * 0.3, "seed launcher %s hold: in the tube's height" % tier)
		check(m["muzzle"].x > used.end.x - used.size.x * 0.2 and m["muzzle"].x < used.end.x - 4.0, "seed launcher %s muzzle: in the bore, not the tip (%s, gun %s)" % [tier, m["muzzle"], used])
		check(absf(m["muzzle"].y - m["pivot"].y) < used.size.y * 0.15, "seed launcher %s muzzle: near the tube's axis" % tier)
		var bore := img.get_pixelv(Vector2i(m["muzzle"]))
		check(bore.a > 0.9, "seed launcher %s muzzle: on the pod / crystal / seed (%s)" % [tier, bore])
		check(img.get_pixel(0, 0).a == 0.0 and img.get_pixel(img.get_width() - 1, 0).a == 0.0, "seed launcher %s the backdrop keyed out" % tier)
		var pink := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.1 and minf(c.r, c.b) > c.g + 0.15 and c.h > 0.75 and c.h < 0.9:
					pink += 1
		eq(pink, 0, "seed launcher %s no magenta / purple px left" % tier)
		check(used.size.y < used.size.x * 0.5, "seed launcher %s the sparkle dropped (%s)" % [tier, used])
		var h := Art.hug_gun("seed_launcher", tier)
		check(h["hug"] and h["tier"] == tier and h["path"] == Art.hug_gun_path("seed_launcher", tier), "seed launcher %s: its own hug art" % tier)
		# Aiming straight up the back end is at or above Flora's soles (the pose's origin).
		if not rp.is_empty():
			var back: Vector2 = rp["socket"] * Transform2D(-PI / 2.0, Vector2.ZERO) * rp["preview"] * (Vector2(used.position.x, m["pivot"].y))
			check(back.y <= 0.0, "seed launcher %s at 90°: the back end above the ground (%s)" % [tier, back])
	# The glows: a soft rim of their own colour (partly transparent, no key tint) past the solid gun.
	for t in [["mithril", Color8(90, 255, 230)], ["dragon", Color8(250, 200, 40)]]:
		var img := Image.load_from_file(ProjectSettings.globalize_path(Art.hug_gun_path("seed_launcher", t[0])))
		var soft := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.05 and c.a < 0.45 and absf(c.h - t[1].h) < 0.08:
					soft += 1
		check(soft > 10, "seed launcher %s: a soft glow of its own colour (%d px)" % [t[0], soft])
	# basic: the iron picture desaturated (the old basic.png's recolour), the same shape and points.
	eq(Art.hug_meta("seed_launcher", "basic"), Art.hug_meta("seed_launcher", "iron"), "basic: the iron seed launcher's size / hold / muzzle")
	var basic := Image.load_from_file(ProjectSettings.globalize_path(Art.hug_gun_path("seed_launcher", "basic")))
	var same := true
	var sat := Vector3.ZERO
	for y in basic.get_height():
		for x in basic.get_width():
			var ic := iron_img.get_pixel(x, y)
			var c := basic.get_pixel(x, y)
			if absf(c.a - ic.a) > 0.01:
				same = false
			if ic.a > 0.9 and ic.s > 0.15:
				sat += Vector3(c.s, ic.s, 1.0)
	check(same, "basic: the iron seed launcher's shape")
	near(sat.x / sat.y, 0.55, 0.05, "basic: desaturated like the old basic.png")


## tools/import_frames.gd key_background() on magenta: the spill is the part of red and blue above
## green (a pink rim turns grey, a red keeps its red), a glow painted into the backdrop is un-mixed
## into its own colour; import_hug_guns.gd despill() with two channels / a hue range, fade_outside().
func test_key_background_magenta() -> void:
	var I := load("res://tools/import_frames.gd")
	var H := load("res://tools/import_hug_guns.gd")
	eq(I.key_channels(Color8(245, 5, 239)), [0, 2], "magenta: red and blue")
	eq(I.key_channels(Color8(9, 243, 9)), [1], "green screen: green")
	var key := Color8(245, 5, 239)
	var img := Image.create(40, 30, false, Image.FORMAT_RGBA8)
	img.fill(key)
	img.fill_rect(Rect2i(4, 4, 20, 20), Color8(20, 20, 24)) # the outline
	img.fill_rect(Rect2i(8, 8, 12, 12), Color8(200, 40, 50)) # a red inside
	for y in range(4, 24):
		img.set_pixel(3, y, Color8(130, 12, 128)) # half outline, half backdrop
		img.set_pixel(24, y, Color8(60, 15, 62)) # a pink-tinted outline px next to the backdrop
	# A glow (cyan) painted into the backdrop right of the figure: the key blended toward it.
	var g := Color8(90, 255, 230)
	for x in range(25, 34):
		var t := 0.7 * (1.0 - float(x - 25) / 9.0)
		for y in range(8, 20):
			img.set_pixel(x, y, key.lerp(g, t))
	var opts := {"key": "corners", "corner": 2, "tolerance": 45, "soft": 45, "holeMin": 20, "spill": 2}
	var plain: Image = img.duplicate()
	I.key_background(plain, opts)
	var tinted := plain.get_pixel(26, 12)
	check(tinted.a > 0.9 and tinted.r > g.r + 0.2, "without glow: the glow stays an opaque key blend (%s)" % tinted)
	opts["glow"] = {"colour": [90, 255, 230]}
	I.key_background(img, opts)
	near(img.get_pixel(0, 0).a, 0.0, 1e-6, "backdrop")
	var rim := img.get_pixel(3, 10)
	check(rim.a > 0.3 and minf(rim.r, rim.b) <= rim.g + 1.0 / 255.0, "the half-backdrop rim kept, no pink (%s)" % rim)
	var edge := img.get_pixel(24, 10)
	check(minf(edge.r, edge.b) <= edge.g + 1.0 / 255.0, "the tinted outline px despilled (%s)" % edge)
	eq(img.get_pixel(10, 10), Color8(200, 40, 50), "the red inside stays")
	var glow := img.get_pixel(26, 12)
	check(glow.a > 0.3 and glow.a < 0.9, "glow: partly transparent (%f)" % glow.a)
	check(absf(glow.r - g.r) < 0.06 and absf(glow.g - g.g) < 0.06 and absf(glow.b - g.b) < 0.06, "glow: its own colour, no key tint (%s)" % glow)
	check(img.get_pixel(32, 12).a < glow.a, "glow: fading out")
	var away: Image = plain.duplicate()
	away.fill(key)
	for x in range(25, 34):
		for y in range(8, 20):
			away.set_pixel(x, y, key.lerp(g, 0.7 * (1.0 - float(x - 25) / 9.0)))
	opts["glow"] = {"colour": [90, 255, 230], "alpha": 0.0}
	I.key_background(away, opts)
	near(away.get_pixel(26, 12).a, 0.0, 1e-6, "glow alpha 0: keyed away")
	# despill() with a second channel: a pink tint loses the part above green; a hue range keeps reds.
	var sp := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	sp.set_pixel(0, 0, Color8(120, 20, 110))
	sp.set_pixel(1, 0, Color8(200, 40, 70))
	sp.set_pixel(2, 0, Color8(90, 200, 220))
	var sq: Image = sp.duplicate()
	eq(H.despill(sp, 0, 2), 2, "the purple and the crimson")
	eq([sp.get_pixel(0, 0), sp.get_pixel(1, 0), sp.get_pixel(2, 0)], [Color8(30, 20, 20), Color8(170, 40, 40), Color8(90, 200, 220)], "lowered by the part above green; the cyan kept")
	eq(H.despill(sq, 0, 2, Vector2(270, 320)), 1, "hues 270-320: only the purple")
	eq(sq.get_pixel(1, 0), Color8(200, 40, 70), "the crimson kept")
	# fade_outside(): alpha faded to nothing over the band round a rect.
	var f := Image.create(20, 1, false, Image.FORMAT_RGBA8)
	f.fill(Color.WHITE)
	H.fade_outside(f, Rect2i(0, 0, 10, 1), 4)
	eq([f.get_pixel(9, 0).a, f.get_pixel(14, 0).a], [1.0, 0.0], "inside kept, past the band gone")
	check(f.get_pixel(11, 0).a > 0.4 and f.get_pixel(11, 0).a < 0.9, "in the band: faded (%f)" % f.get_pixel(11, 0).a)


## [[kind, tier]] for every kind × tier.
func _kind_tiers(kinds: Array, tiers: Array) -> Array:
	var out := []
	for k in kinds:
		for t in tiers:
			out.append([k, t])
	return out


## tools/import_frames.gd key_background() on a tiny green-screen picture: the corner colour is the
## key; the backdrop goes (an enclosed pure-green hole too), the dark figure stays with no green rim,
## an enclosed greenish highlight stays as it is; clean() then drops a detached sparkle.
func test_key_background() -> void:
	var I := load("res://tools/import_frames.gd")
	var key := Color8(58, 243, 41)
	var img := Image.create(40, 30, false, Image.FORMAT_RGBA8)
	img.fill(key)
	img.set_pixel(39, 29, Color8(62, 240, 44)) # backdrop noise
	img.fill_rect(Rect2i(4, 4, 20, 20), Color8(20, 20, 24)) # the figure (its outline colour)
	for y in range(4, 24):
		img.set_pixel(3, y, Color8(39, 131, 33)) # half outline, half backdrop
	img.fill_rect(Rect2i(8, 8, 6, 6), key) # an enclosed backdrop hole (36 px)
	img.fill_rect(Rect2i(16, 16, 3, 3), Color8(120, 150, 80)) # the art's own green
	img.fill_rect(Rect2i(32, 22, 2, 2), Color8(100, 248, 90)) # a light sparkle on the backdrop
	eq(I.corner_colour(img, 4).to_html(false), key.to_html(false), "the key: the corners' colour")
	var cleared: int = I.key_background(img, {"key": "corners", "corner": 4, "tolerance": 45, "soft": 45, "holeMin": 20, "spill": 2})
	check(cleared > 40 * 30 - 20 * 20 - 30, "the backdrop cleared (%d px)" % cleared)
	near(img.get_pixel(0, 0).a, 0.0, 1e-6, "backdrop")
	near(img.get_pixel(39, 29).a, 0.0, 1e-6, "backdrop noise")
	near(img.get_pixel(10, 10).a, 0.0, 1e-6, "the enclosed hole")
	eq(img.get_pixel(5, 5), Color8(20, 20, 24), "the figure stays")
	eq(img.get_pixel(17, 17), Color8(120, 150, 80), "the art's own green stays")
	var rim := img.get_pixel(3, 10)
	check(rim.a > 0.5 and rim.g <= maxf(rim.r, rim.b) + 1e-6, "the half-backdrop rim kept, despilled (%s)" % rim)
	var spark := img.get_pixel(32, 22)
	check(spark.a > 0.0 and spark.a < 1.0, "the sparkle half keyed (%f)" % spark.a)
	I.clean(img, {"alphaCut": 24, "keepPieces": 0.02, "defringe": {"band": 0}})
	near(img.get_pixel(32, 22).a, 0.0, 1e-6, "clean(): the detached sparkle dropped")
	eq(img.get_pixel(5, 5), Color8(20, 20, 24), "clean(): the figure stays")
	# holePure: an enclosed shaded pocket of backdrop (near the key, none of it pure) stays by
	# default, holePure 0 keys it as a hole.
	var pocket := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	pocket.fill(key)
	pocket.fill_rect(Rect2i(4, 4, 12, 12), Color8(20, 20, 24))
	pocket.fill_rect(Rect2i(8, 8, 4, 4), Color8(70, 200, 60)) # 16 px, d ≈ 50 from the key
	var p2 := pocket.duplicate()
	I.key_background(pocket, {"key": "corners", "corner": 2, "tolerance": 45, "soft": 45, "holeMin": 10, "spill": 0})
	near(pocket.get_pixel(9, 9).a, 1.0, 1e-6, "a shaded pocket kept by default")
	I.key_background(p2, {"key": "corners", "corner": 2, "tolerance": 45, "soft": 45, "holeMin": 10, "holePure": 0, "spill": 0})
	check(p2.get_pixel(9, 9).a < 0.2, "holePure 0: the pocket keyed (%f)" % p2.get_pixel(9, 9).a)
	eq(p2.get_pixel(5, 5), Color8(20, 20, 24), "the figure round it stays")
	# spillFrom "keyed": a pocket only partly keyed (nothing cleared near it, Flora's hair wedges)
	# keeps a green tint by default; measured from the keyed pixels it is despilled too.
	var wedge := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	wedge.fill(key)
	wedge.fill_rect(Rect2i(4, 4, 12, 12), Color8(20, 20, 24))
	wedge.fill_rect(Rect2i(8, 8, 4, 4), Color8(40, 180, 30)) # d ≈ 66: a ≈ 0.5
	var w2: Image = wedge.duplicate()
	var opts := {"key": "corners", "corner": 2, "tolerance": 45, "soft": 45, "holeMin": 10, "holePure": 0, "spill": 2}
	I.key_background(wedge, opts)
	var tint := wedge.get_pixel(9, 9)
	check(tint.a > 0.2 and tint.g > maxf(tint.r, tint.b) + 0.1, "by default the partly keyed pocket stays green (%s)" % tint)
	opts["spillFrom"] = "keyed"
	I.key_background(w2, opts)
	var despilled := w2.get_pixel(9, 9)
	check(despilled.a > 0.2 and despilled.g <= maxf(despilled.r, despilled.b) + 1e-6, "spillFrom keyed: despilled (%s)" % despilled)
	eq(w2.get_pixel(5, 5), Color8(20, 20, 24), "spillFrom keyed: the figure's dark outline stays")


## tools/import_guns.gd recolour(): HSV multipliers on every pixel, a hue shift, limited to a hue
## range (the hug guns' steel: the olive only, the red warhead kept).
func test_recolour() -> void:
	var G := load("res://tools/import_guns.gd")
	var img := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	var olive := Color.from_hsv(90.0 / 360.0, 0.4, 0.5)
	var red := Color.from_hsv(0.0, 0.7, 0.7)
	img.set_pixel(0, 0, olive)
	img.set_pixel(1, 0, red)
	img.set_pixel(2, 0, Color(olive, 0.0))
	var a: Image = img.duplicate()
	G.recolour(a, {"saturation": 0.5, "value": 0.9})
	near(a.get_pixel(0, 0).s, 0.2, 0.01, "saturation ×0.5")
	near(a.get_pixel(1, 0).v, 0.63, 0.01, "value ×0.9 (every hue)")
	eq(a.get_pixel(2, 0), img.get_pixel(2, 0), "a clear pixel untouched")
	var b: Image = img.duplicate()
	G.recolour(b, {"hueRange": [45, 135], "hue": -5.0, "saturation": 1.25})
	near(b.get_pixel(0, 0).h * 360.0, 85.0, 1.0, "hue shifted")
	near(b.get_pixel(0, 0).s, 0.5, 0.01, "saturation ×1.25")
	eq(b.get_pixel(1, 0), img.get_pixel(1, 0), "outside the hue range: kept")


## tools/import_frames.gd arm_mask(): on a synthetic outlined drawing (an arm: a blue box with a
## 2 px dark outline and a ring crease, touching a same-blue torso through the outline) the flood
## fill from the seed stops at the outline, the grow takes the outline, what the crease encloses is
## filled, the polygon limits it, and nothing past the outline (the torso, the backdrop) is cut.
func test_arm_mask() -> void:
	var I := load("res://tools/import_frames.gd")
	var blue := Color8(70, 120, 170)
	var ink := Color8(24, 22, 30)
	var img := Image.create(40, 30, false, Image.FORMAT_RGBA8) # clear backdrop
	img.fill_rect(Rect2i(20, 4, 18, 22), blue) # the torso, same blue as the sleeve
	img.fill_rect(Rect2i(4, 8, 18, 12), ink) # the arm's outline (2 px) ...
	img.fill_rect(Rect2i(6, 10, 14, 8), blue) # ... and its sleeve
	img.fill_rect(Rect2i(14, 12, 5, 5), ink) # a ring crease in the sleeve ...
	img.fill_rect(Rect2i(15, 13, 3, 3), blue) # ... round a piece the fill cannot reach
	img.set_pixel(8, 12, Color8(200, 160, 120)) # a detail drawn in another colour
	var ac := {"polygon": [[0, 0], [30, 0], [30, 30], [0, 30]], "seeds": [[8, 14]], "darkMax": 80, "grow": 2, "feather": 0}
	var m: PackedFloat32Array = I.arm_mask(img, ac)
	eq(m.size(), 40 * 30, "one value per pixel")
	near(m[14 * 40 + 8], 1.0, 1e-6, "the seed's sleeve")
	near(m[12 * 40 + 8], 1.0, 1e-6, "a detail inside it")
	near(m[14 * 40 + 4], 1.0, 1e-6, "grown: the outer outline column")
	near(m[9 * 40 + 5], 1.0, 1e-6, "grown: the outline corner")
	near(m[14 * 40 + 14], 1.0, 1e-6, "the crease (grown over)")
	near(m[14 * 40 + 16], 1.0, 1e-6, "the piece the crease walls in, enclosed: filled")
	near(m[14 * 40 + 20], 1.0, 1e-6, "grown: the outline next to the torso")
	near(m[14 * 40 + 24], 0.0, 1e-6, "the torso past the outline: not cut")
	near(m[14 * 40 + 2], 0.0, 1e-6, "the backdrop: not cut")
	near(m[4 * 40 + 4], 0.0, 1e-6, "nor above")
	# Without grow the fill stops before the outline (it is the barrier).
	ac["grow"] = 0
	m = I.arm_mask(img, ac)
	near(m[14 * 40 + 6], 1.0, 1e-6, "no grow: the sleeve's edge")
	near(m[14 * 40 + 5], 0.0, 1e-6, "no grow: the outline is not filled into")
	# The polygon limits the cut: its right part stays out.
	ac["grow"] = 2
	ac["polygon"] = [[0, 0], [10, 0], [10, 30], [0, 30]]
	m = I.arm_mask(img, ac)
	near(m[14 * 40 + 8], 1.0, 1e-6, "inside the polygon")
	near(m[14 * 40 + 11], 0.0, 1e-6, "outside the polygon: not cut")
	# The feather is inward: the edge softer, nothing outside.
	ac["polygon"] = [[0, 0], [30, 0], [30, 30], [0, 30]]
	ac["feather"] = 1
	m = I.arm_mask(img, ac)
	check(m[14 * 40 + 4] > 0.0 and m[14 * 40 + 4] < 1.0, "feathered edge (%f)" % m[14 * 40 + 4])
	near(m[14 * 40 + 8], 1.0, 1e-6, "full inside")
	near(m[14 * 40 + 3], 0.0, 1e-6, "nothing outside the cut")
	# A seed on the outline cuts nothing; apply_mask() keeps only the cut.
	var none: PackedFloat32Array = I.arm_mask(img, {"polygon": [[0, 0], [30, 0], [30, 30], [0, 30]], "seeds": [[4, 14]]})
	check(Array(none).all(func(v): return v == 0.0), "a seed on the outline: nothing")
	var cut: Image = I.apply_mask(img, m)
	near(cut.get_pixel(24, 14).a, 0.0, 1e-6, "apply_mask: the torso gone")
	eq(cut.get_pixel(8, 14), blue, "apply_mask: the sleeve as drawn")


## tools/import_hug_guns.gd -- <kind>_<tier> ...: which pictures, the name split and the tube's
## hold / muzzle.
func test_import_hug_guns_arguments() -> void:
	var H := load("res://tools/import_hug_guns.gd")
	var dir := "res://art_source/weapons/hug/"
	eq(H.split_name("bazooka_iron"), {"kind": "bazooka", "tier": "iron"}, "kind_tier")
	eq(H.split_name("shock_rifle_dragon"), {"kind": "shock_rifle", "tier": "dragon"}, "a kind with an underscore")
	eq(H.split_name("blaster_gold"), {"kind": "blaster", "tier": "gold"}, "a crafted tier")
	eq(H.split_name("bazooka_gold"), {}, "not one of the kind's tiers")
	eq(H.split_name("ray_iron"), {}, "unknown kind")
	eq(H.split_name("bazooka"), {}, "no tier")
	var all: Dictionary = H.sources_for([], dir)
	for tier in ["iron", "mithril", "dragon"]:
		check(all["guns"].has({"kind": "bazooka", "tier": tier, "name": "bazooka_" + tier, "source": "bazooka_" + tier}), "no argument: every picture (%s)" % tier)
	eq(all["unknown"], [], "no argument: nothing unknown")
	eq(H.sources_for(["bazooka_iron.png"], dir), {"guns": [{"kind": "bazooka", "tier": "iron", "name": "bazooka_iron", "source": "bazooka_iron"}], "unknown": []}, "a name")
	eq(H.sources_for(["shock_rifle_iron", "nope"], dir)["unknown"], ["shock_rifle_iron", "nope"], "no picture / not a gun")
	# Guns made from another tier's picture (hug.json from + recolour).
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(dir + "hug.json"))
	var derived: Dictionary = H.derived_of(cfg)
	eq(derived, {"bazooka_basic": "bazooka_iron", "bazooka_steel": "bazooka_iron", "cannon_basic": "cannon_iron", "seed_launcher_basic": "seed_launcher_iron"}, "hug.json: the bazooka's basic and steel, the cannon's and the seed launcher's basic from the iron picture")
	eq(H.derived_of({"guns": {"bazooka_steel": {"from": "gold"}, "bazooka_iron": {"from": "iron"}, "ray_iron": {"from": "steel"}, "bazooka_basic": {"length": 50}}}), {}, "not a tier of the kind / itself / not a gun / no from")
	all = H.sources_for([], dir, derived)
	check(all["guns"].has({"kind": "bazooka", "tier": "steel", "name": "bazooka_steel", "source": "bazooka_iron"}), "no argument: the derived guns too")
	eq(all["guns"].size(), 15, "every bazooka, cannon and seed launcher tier (%s)" % [all["guns"]])
	var named: Dictionary = H.sources_for(["bazooka_iron"], dir, derived)
	eq(named["guns"].map(func(g): return g["name"]), ["bazooka_iron", "bazooka_basic", "bazooka_steel"], "naming a picture takes the guns made from it")
	eq(H.sources_for(["bazooka_steel"], dir, derived)["guns"], [{"kind": "bazooka", "tier": "steel", "name": "bazooka_steel", "source": "bazooka_iron"}], "a derived gun by name")
	eq(H.sources_for(["bazooka_mithril"], dir, derived)["guns"].size(), 1, "another picture: only it")
	# despill(): the key's channel capped at the other two.
	var sp := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	sp.set_pixel(0, 0, Color8(20, 60, 20))
	sp.set_pixel(1, 0, Color8(200, 100, 50))
	sp.set_pixel(2, 0, Color8(0, 255, 0, 0))
	eq(H.despill(sp, 1), 1, "one pixel greener than its red / blue")
	eq([sp.get_pixel(0, 0), sp.get_pixel(1, 0)], [Color8(20, 20, 20), Color8(200, 100, 50)], "capped; the other kept")
	# A tube 30 px long, 6 px thick, with a sight on top: the hold is the tube's middle.
	var img := Image.create(40, 20, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(5, 8, 30, 6), Color.WHITE)
	img.fill_rect(Rect2i(24, 4, 4, 4), Color.WHITE)
	var tp: Dictionary = H.tube_points(img)
	eq(tp["rect"], Rect2i(5, 4, 30, 10), "the gun's bounds")
	eq(tp["hold"], Vector2(20, 11), "hold: the middle, at the tube's height (not lifted by the sight)")
	eq(tp["muzzle"], Vector2(35, 11), "muzzle: the right end on the axis")
	eq(H.tube_points(Image.create(4, 4, false, Image.FORMAT_RGBA8)), {}, "empty")


## Rookie's weapon icons come from the hug art (tools/import_hug_guns.gd, hug.json "icons"), drawn
## like the other weapon icons (art_source/weapons/guns_v1.json "icons": size, margin, tilt);
## import_guns.gd no longer cuts the old bazooka from guns_v1.png.
func test_hug_gun_icons() -> void:
	var H := load("res://tools/import_hug_guns.gd")
	var G := load("res://tools/import_guns.gd")
	var held: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(G.CONFIG))
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art_source/weapons/hug/hug.json"))
	check(not held["guns"].has("bazooka") and not held["icons"]["files"].has("weapon_bazooka_<tier>"), "guns_v1.json: no bazooka sprites / icons")
	check(Array(held["cells"].keys()).all(func(k): return not str(k).begins_with("bazooka/")), "guns_v1.json: no bazooka cells")
	check(not held["guns"].has("cannon") and not held["icons"]["files"].has("weapon_cannon_<tier>"), "guns_v1.json: no cannon sprites / icons")
	check(Array(held["cells"].keys()).all(func(k): return not str(k).begins_with("cannon/")), "guns_v1.json: no cannon cells")
	check(not held["guns"].has("seed_launcher") and not held["icons"]["files"].has("weapon_launcher_<tier>"), "guns_v1.json: no seed launcher sprites / icons")
	check(Array(held["cells"].keys()).all(func(k): return not str(k).begins_with("seed_launcher/")), "guns_v1.json: no seed launcher cells")
	var ic: Dictionary = H.icon_config(cfg, held)
	for key in ["size", "margin", "tiltDeg"]:
		eq(ic[key], held["icons"][key], "hug icons: the held guns' %s" % key)
	eq(ic["files"], {"weapon_bazooka_<tier>": {"gun": "bazooka", "tiers": Art.EQUIP_KIND_TIERS},
		"weapon_cannon_<tier>": {"gun": "cannon", "tiers": Art.EQUIP_KIND_TIERS},
		"weapon_launcher_<tier>": {"gun": "seed_launcher", "tiers": Art.EQUIP_KIND_TIERS}}, "hug.json: the bazooka's, the cannon's and the seed launcher's icons in the shop tiers")
	eq(H.icon_config({"icons": {"margin": 3}}, held)["margin"], 3, "hug.json overrides")
	eq(H.icon_config({}, {})["files"], {}, "no icons")
	# icon_canvases(): every tier the same tube length, the holds on the same canvas px.
	var a := Image.create(40, 20, false, Image.FORMAT_RGBA8)
	a.fill_rect(Rect2i(5, 8, 30, 6), Color.WHITE)
	var b := Image.create(80, 40, false, Image.FORMAT_RGBA8)
	b.fill_rect(Rect2i(10, 16, 60, 12), Color.RED)
	var pics := {}
	for t in [["iron", a], ["dragon", b]]:
		var tp: Dictionary = H.tube_points(t[1])
		pics[t[0]] = {"image": t[1], "rect": t[1].get_used_rect(), "tube": tp, "hold": tp["hold"]}
	var cv: Dictionary = H.icon_canvases(pics, ["iron", "dragon"])
	eq(cv["iron"].get_size(), cv["dragon"].get_size(), "one canvas size")
	var ra := _opaque_rect(cv["iron"])
	var rb := _opaque_rect(cv["dragon"])
	check(absi(ra.size.x - rb.size.x) <= 1 and absi(ra.size.y - rb.size.y) <= 1 and absi(ra.position.x - rb.position.x) <= 1, "the same tube at the same place (%s vs %s)" % [ra, rb])
	# The icons: the new gun (no hand grips), turned muzzle up-right like the others.
	for kt in _kind_tiers(["bazooka", "cannon", "launcher"], Art.EQUIP_KIND_TIERS): # equipment kinds
		var kind: String = kt[0]
		var tier: String = kt[1]
		var img := Image.load_from_file(ProjectSettings.globalize_path(Art.equipment_weapon_path(kind, tier)))
		if img == null:
			check(false, "%s %s icon loads" % [kind, tier])
			continue
		var u := img.get_used_rect()
		var mid := func(x: int) -> float:
			var sum := 0.0
			var n := 0
			for y in img.get_height():
				if img.get_pixel(x, y).a > 0.5:
					sum += y
					n += 1
			return sum / maxf(1.0, n)
		# The tube's middle line near both ends (the seed launcher's: inside its back cap and before
		# the flared muzzle / the pod).
		var xa := u.position.x + (6 if kind != "launcher" else int(u.size.x * 0.1))
		var xb := u.end.x - 12 if kind != "launcher" else u.position.x + int(u.size.x * 0.7)
		var rise: float = mid.call(xa) - mid.call(xb)
		var slope := rise / float(xb - xa)
		near(rad_to_deg(atan(slope)), -float(held["icons"]["tiltDeg"]), 4.0, "%s %s icon: the tube turned %s° (muzzle up)" % [kind, tier, held["icons"]["tiltDeg"]])
		check(u.size.y < u.size.x * 0.6, "%s %s icon: a long thick tube, no grips below it (%s)" % [kind, tier, u])


## tools/import_frames.gd -- <character_id> | <config.json>: which configs, the frame pattern and
## the anims for the frames and poses there.
func test_import_frames_arguments() -> void:
	var I := load("res://tools/import_frames.gd")
	var cfg_of := func(id: String) -> String: return "res://art_source/characters/%s/side_run/import.json" % id
	for id in Art.CHARACTERS:
		eq(I.configs_for([id]), {"configs": [cfg_of.call(id)], "unknown": []}, "-- " + id)
	eq(I.configs_for(["tanko", "flora"])["configs"], [cfg_of.call("tanko"), cfg_of.call("flora")], "two ids")
	var all: Array = I.configs_for([])["configs"]
	for id in Art.CHARACTERS:
		check(all.has(cfg_of.call(id)), "no argument: every character (%s)" % id)
	eq(I.configs_for(["res://x/import.json"]), {"configs": ["res://x/import.json"], "unknown": []}, "a config path")
	eq(I.configs_for(["nope"]), {"configs": [], "unknown": ["nope"]}, "unknown id")
	eq(I.configs_for(["../rookie"])["unknown"], ["../rookie"], "not a folder name")
	var frames: Array = I.frame_files("frame_*.png", "res://art_source/characters/rookie/side_run/")
	eq(frames, ["frame_1.png", "frame_2.png", "frame_3.png", "frame_4.png", "frame_5.png", "frame_6.png", "frame_7.png", "frame_8.png"], "pattern")
	eq(I.frame_files(["b.png", "a.png"], "res://"), ["b.png", "a.png"], "a list stays as listed")
	var tmp := OS.get_temp_dir().path_join("bsq_frames_%d/" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tmp)
	for f in ["frame_10.png", "frame_2.png", "frame_1.png", "other.png"]:
		FileAccess.open(tmp + f, FileAccess.WRITE).close()
	eq(I.frame_files("frame_*.png", tmp), ["frame_1.png", "frame_2.png", "frame_10.png"], "natural order")
	for f in DirAccess.get_files_at(tmp):
		DirAccess.remove_absolute(tmp + f)
	DirAccess.remove_absolute(tmp)
	# Anims: Rookie's as written; fewer frames / no ready picture drop what cannot be shown.
	var rookie = JSON.parse_string(FileAccess.get_file_as_string(cfg_of.call("rookie")))
	var full: Dictionary = I.resolve_anims(rookie["anims"], 8, ["ready"])
	eq(full.keys(), rookie["anims"].keys(), "Rookie: every anim, same order")
	eq(full["walk"]["frames"], rookie["anims"]["walk"]["frames"], "Rookie: the walk as listed")
	var short: Dictionary = I.resolve_anims(rookie["anims"], 6, [])
	eq(short["walk"]["frames"].map(func(i): return int(i)), [0, 1, 2, 3, 4, 5], "past the last frame dropped")
	check(not short.has("draw") and not short.has("fire"), "no ready picture: no draw / fire")
	check(short.has("shoot") and short.has("die"), "the idle reuses stay")
	var spark = JSON.parse_string(FileAccess.get_file_as_string(cfg_of.call("spark")))
	eq(str(spark["frames"]), "frame_*.png", "the template takes every frame_N.png")
	eq(I.resolve_anims(spark["anims"], 5, ["ready"])["walk"]["frames"], [0, 1, 2, 3, 4], "walk: all the frames")
	eq(I.resolve_anims(spark["anims"], 5, ["ready"]).keys(), rookie["anims"].keys(), "the template's anims are Rookie's")
	# Flora's and Tanko's, filled for their 8 run frames: every anim.
	for id in ["flora", "tanko"]:
		var c = JSON.parse_string(FileAccess.get_file_as_string(cfg_of.call(id)))
		eq(I.resolve_anims(c["anims"], 8, ["ready"]).keys(), rookie["anims"].keys(), "%s: every anim" % id)
		eq(I.resolve_anims(c["anims"], 8, ["ready"])["walk"]["frames"], range(8), "%s: the walk over the 8 frames" % id)
		check(c["poses"]["ready"].has("alignX") and c["poses"]["ready"].has("armFront") and c["poses"]["ready"]["gun"].has("grip"), "%s: the pose placed, its arm cut and hug point set" % id)
	# The idle is the standing picture (poses.stand), the run frame it was before as the fallback.
	for id in ["rookie", "flora", "tanko", "spark"]:
		var c = JSON.parse_string(FileAccess.get_file_as_string(cfg_of.call(id)))
		eq(c["anims"]["idle"]["frames"], ["stand"], "%s idles on the standing picture" % id)
		eq(str(c["poses"]["stand"]["src"]), "../side_idle/idle_v1.png", "%s: the standing picture's file" % id)
		check(not c["poses"]["stand"].has("background"), "%s: the standing picture is already transparent (no keying)" % id)
		var both: Dictionary = I.resolve_anims(c["anims"], 8, ["stand", "ready"])
		eq(both["idle"]["frames"], ["stand"], "%s: idle on the stand pose" % id)
		check(not both["idle"].has("fallback"), "%s: the fallback is not passed on" % id)
		eq(I.ready_pose_name(both), "ready", "%s: the draw anim's pose is the ready pose" % id)
		var old: Dictionary = I.resolve_anims(c["anims"], 8, ["ready"])
		eq(old["idle"]["frames"].map(func(i): return int(i)), [6] if id == "tanko" else [0], "%s: no standing picture: the old idle run frame" % id)
		eq(old.keys(), both.keys(), "%s: the same anims either way" % id)
		if id != "spark":
			check(FileAccess.file_exists("res://art_source/characters/%s/side_idle/idle_v1.png" % id), "%s: idle_v1.png there" % id)
			check(c["poses"]["stand"].has("alignX") and float(c["poses"]["stand"]["scale"]) > 0.9 and float(c["poses"]["stand"]["scale"]) < 1.1, "%s: the stand pose placed, near the run frames' size" % id)
	eq(I.ready_pose_name({"idle": {"frames": ["stand"]}}), "", "no draw anim: no ready pose")
	check(not DirAccess.dir_exists_absolute("res://art_source/characters/rookie/side_idle") or not FileAccess.file_exists("res://art_source/characters/rookie/side_idle/import.json"), "side_idle is no config of its own")
