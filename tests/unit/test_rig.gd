extends "res://tests/test_case.gd"
## The lobby (front-view) cutout rigs (assets/characters/<id>/lobby/, scenes/character/rig.gd).

const Art := preload("res://ui/art.gd")
const BONES := ["root", "hips", "torso", "head", "arm_back_upper", "arm_back_fore", "arm_gun_upper", "arm_gun_fore",
	"arm_free_upper", "arm_free_fore", "thigh_back", "shin_back", "thigh_front", "shin_front"]


func _part_size(id: String, part: String) -> Vector2:
	var img := Image.load_from_file(ProjectSettings.globalize_path(Art.rig_part_path(id, part)))
	return Vector2.ZERO if img == null else Vector2(img.get_size())


func test_every_character_has_a_rig() -> void:
	for id in Art.CHARACTERS:
		var rig := Art.rig(id)
		check(not rig.is_empty(), "%s rig loads" % id)
		var paths := Art.rig_paths(id)
		check(paths.size() > 10, "%s rig lists its parts (%d)" % [id, paths.size()])
		for path in paths:
			check(FileAccess.file_exists(path), "missing " + path)
			check(Art.all_paths().has(path), "all_paths lists " + path)


func test_rig_bones_and_pivots_are_sane() -> void:
	for id in Art.CHARACTERS:
		var rig := Art.rig(id)
		if rig.is_empty():
			continue
		var by_name := {}
		var roots := 0
		for b in rig["bones"]:
			by_name[b["name"]] = b
			if b["parent"] == "":
				roots += 1
		eq(roots, 1, "%s has one root" % id)
		for name in BONES:
			check(by_name.has(name), "%s has bone %s" % [id, name])
		for b in rig["bones"]:
			check(b["set"] in ["", "gun", "free"], "%s %s set %s" % [id, b["name"], b["set"]])
			if not b.has("part"):
				continue
			var size := _part_size(id, b["part"])
			check(size.x > 16 and size.y > 16, "%s %s picture loads" % [id, b["part"]])
			var pv: Vector2 = b["pivot"]
			check(Rect2(Vector2.ZERO, size).grow(4).has_point(pv), "%s %s pivot %s inside its %s picture" % [id, b["name"], pv, size])
			var parent: Dictionary = by_name.get(b["parent"], {})
			if parent.has("part"):
				var psize := _part_size(id, parent["part"])
				check(Rect2(Vector2.ZERO, psize).grow(psize.length() * 0.25).has_point(b["at"]), "%s %s attaches on %s (%s)" % [id, b["name"], parent["name"], b["at"]])
		var g: Dictionary = rig["gun"]
		eq(g["bone"], "arm_gun_fore", "%s gun in the gripping hand" % id)
		check(Rect2(Vector2.ZERO, _part_size(id, by_name["arm_gun_fore"]["part"])).has_point(g["at"]), "%s grip on the hand picture" % id)
		check(by_name["arm_gun_upper"]["set"] == "gun" and by_name["arm_free_upper"]["set"] == "free", "%s gun and free arms" % id)


func test_rig_animations_are_well_formed() -> void:
	var anims: Dictionary = Art.rig("rookie")["anims"]
	for anim in Art.RIG_ANIM_NAMES:
		check(anims.has(anim), "animation " + anim)
	for anim in anims:
		var spec: Dictionary = anims[anim]
		var length := float(spec["length"])
		check(length > 0.0, "%s has a length" % anim)
		for track in spec["tracks"]:
			check(track == "_flash" or BONES.has(track) or track == "backpack", "%s track %s is a bone" % [anim, track])
			var tr: Dictionary = spec["tracks"][track]
			var t: Array = tr["t"]
			for i in t.size():
				check(float(t[i]) >= 0.0 and float(t[i]) <= length + 0.001, "%s %s key %d in the animation" % [anim, track, i])
				if i > 0:
					check(float(t[i]) > float(t[i - 1]), "%s %s keys in order" % [anim, track])
			for field in tr:
				if field != "t":
					eq((tr[field] as Array).size(), t.size(), "%s %s %s one value per key" % [anim, track, field])
	check(bool(anims["idle"]["loop"]) and bool(anims["idle_free"]["loop"]), "idles loop")


func test_character_uses_the_rig_with_feet_on_the_origin() -> void:
	for id in Art.CHARACTERS:
		var c: Node2D = preload("res://scenes/character/character.tscn").instantiate()
		c.character_id = id
		c.lobby_rig = true
		var holder := Node.new()
		holder.add_child(c)
		c._ready()
		var rig: Node2D = c.rig()
		check(rig != null, "%s drawn by the rig" % id)
		if rig == null:
			holder.free()
			continue
		var flip: Node2D = c.get_node("Flip")
		var order := []
		for n in flip.get_children():
			order.append(str(n.name))
		eq(order, ["Sprite", "Rig", "Gun", "RigFront"], "%s draw order: back parts, gun, front parts" % id)
		check(not c.get_node("Flip/Sprite").visible, "%s frames hidden" % id)
		# The rest pose's picture bounds in character px: feet at the origin, about 150 units tall.
		var box := Rect2()
		var first := true
		for layer in [rig, rig.front]:
			for s in layer.get_children():
				if not s is Sprite2D or not s.visible:
					continue
				var r := Rect2(s.offset, s.texture.get_size())
				for corner in [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]:
					var p: Vector2 = layer.transform * (s.transform * corner)
					box = Rect2(p, Vector2.ZERO) if first else box.expand(p)
					first = false
		near(box.end.y, 0.0, 6.0, "%s feet on the origin" % id)
		check(box.size.y > 200.0 and box.size.y < 270.0, "%s about 150 units tall: %.0f px" % [id, box.size.y])
		check(absf(box.get_center().x) < 140.0, "%s centred on the origin" % id)
		c.hands_free = true
		c._apply_frames() # not in the tree: the setter only stores it
		check(not c.get_node("Flip/Gun").visible, "%s hands free: no gun" % id)
		holder.free()


func test_the_match_keeps_the_frames() -> void:
	var c: Node2D = preload("res://scenes/character/character.tscn").instantiate()
	c.character_id = "tanko"
	var holder := Node.new()
	holder.add_child(c)
	c._ready()
	check(c.rig() == null, "no rig without lobby_rig (the match)")
	check(c.get_node("Flip/Sprite").visible, "the frames show")
	holder.free()


func test_character_view_uses_the_lobby_rig() -> void:
	var text := FileAccess.get_file_as_string("res://ui/character_view.gd")
	check(text.contains("lobby_rig = true"), "CharacterView turns the lobby rig on")
	text = FileAccess.get_file_as_string("res://match/views/player_view.gd")
	check(not text.contains("lobby_rig"), "the match does not")
