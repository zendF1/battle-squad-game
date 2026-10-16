extends "res://tests/test_case.gd"
## The full-body pictures of the screens outside the match (assets/characters/<id>/lobby/
## full.png + full.json, scenes/character/full_body.gd, ui/art.gd lobby_full()).

const Art := preload("res://ui/art.gd")
const FullMesh := preload("res://tools/full_mesh.gd")
const CharacterScene := preload("res://scenes/character/character.tscn")
const BONES := ["root", "hips", "chest", "head", "arm_l_upper", "arm_l_fore", "hand_l", "arm_r_upper", "arm_r_fore",
	"hand_r", "leg_l_thigh", "leg_l_shin", "foot_l", "leg_r_thigh", "leg_r_shin", "foot_r"]


func _image(id: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(Art.full_path(id)))


func test_every_character_has_a_full_body_picture() -> void:
	for id in Art.CHARACTERS:
		check(FileAccess.file_exists(Art.full_path(id)) and FileAccess.file_exists(Art.full_json_path(id)), "%s full.png + full.json" % id)
		check(Art.all_paths().has(Art.full_path(id)) and Art.all_paths().has(Art.full_json_path(id)), "%s listed" % id)
		var raw = JSON.parse_string(FileAccess.get_file_as_string(Art.full_json_path(id)))
		check(raw is Dictionary, "%s full.json parses" % id)
		var full := Art.lobby_full(id)
		check(not full.is_empty(), "%s lobby_full loads" % id)
		if full.is_empty():
			continue
		var img := _image(id)
		check(img != null, "%s full.png reads" % id)
		if img == null:
			continue
		eq(full["size"], Vector2(img.get_size()), "%s size matches the PNG" % id)
		var pv: Vector2 = full["pivot"]
		check(pv.y > img.get_height() - 16 and pv.y <= img.get_height() and absf(pv.x - img.get_width() / 2.0) < 40.0, "%s feet at the bottom centre: %s" % [id, pv])
		check(float(full["height"]) > 320.0 and float(full["height"]) <= 380.0, "%s about 375 px tall at most: %s" % [id, full["height"]])
		near(float(full["scale"]), 0.64, 0.001, "%s drawn 1:1 on the lobby stage" % id)


func test_skeleton_mesh_and_weights_are_sane() -> void:
	for id in Art.CHARACTERS:
		var full := Art.lobby_full(id)
		if full.is_empty():
			continue
		var names: Array = full["bones"].map(func(b): return b["name"])
		eq(names, BONES, "%s bones" % id)
		var img := _image(id)
		var box := Rect2(Vector2.ZERO, full["size"])
		for b in full["bones"]:
			check(box.grow(2).has_point(b["at"]) and box.grow(2).has_point(b["tip"]), "%s %s on the picture" % [id, b["name"]])
		near(full["bones"][0]["at"].distance_to(full["pivot"]), 0.0, 1.0, "%s root at the feet" % id)
		var v: PackedVector2Array = full["vertices"]
		check(v.size() > 100, "%s mesh vertices (%d)" % [id, v.size()])
		var tris := PackedInt32Array()
		for t in full["polygons"]:
			tris.append_array(t)
		eq(FullMesh.gaps(img, v, tris), 0, "%s every visible pixel is on the mesh" % id)
		var bad := 0
		for vi in v.size():
			var total := 0.0
			for w in full["weights"]:
				total += (w as PackedFloat32Array)[vi]
			if absf(total - 1.0) > 0.01:
				bad += 1
		eq(bad, 0, "%s every vertex's weights sum to 1" % id)
		var root_w: PackedFloat32Array = full["weights"][0]
		check(Array(root_w).all(func(x): return x == 0.0), "%s the root moves no vertex" % id)
		var anims: Dictionary = full["anims"]
		check(anims.get("idle") is Dictionary and bool(anims["idle"]["loop"]), "%s loops an idle" % id)
		for track in anims["idle"]["tracks"]:
			check(BONES.has(track), "%s idle track %s is a bone" % [id, track])
	check(Art.lobby_full("rookie")["anims"]["idle"]["tracks"].has("hand_l"), "Rookie's wave merged over the shared idle")
	check(Art.lobby_full("rookie")["anims"]["idle"]["tracks"].has("chest"), "the shared breathing kept")


func test_lobby_full_falls_back() -> void:
	eq(Art.parse_full("res://assets/characters/nope/lobby/full.json", "res://assets/characters/nope/lobby/full.png"), {}, "missing → {}")
	eq(Art.parse_full(Art.rig_path("rookie"), Art.full_path("rookie")), {}, "not a full-body json → {}")
	eq(Art.parse_full(Art.full_json_path("rookie"), "res://assets/characters/nope.png"), {}, "picture missing → {}")
	eq(Art.lobby_full("nobody")["pivot"], Art.lobby_full("rookie")["pivot"], "unknown id → Rookie's")


func test_character_prefers_the_full_body_picture() -> void:
	for id in Art.CHARACTERS:
		var c: Node2D = CharacterScene.instantiate()
		c.character_id = id
		c.lobby_rig = true
		var holder := Node.new()
		holder.add_child(c)
		c._ready()
		var full: Node2D = c.full()
		check(full != null and c.rig() == null, "%s drawn by its full-body picture" % id)
		if full == null:
			holder.free()
			continue
		check(not c.get_node("Flip/Sprite").visible, "%s frames hidden" % id)
		check(not c.holds_gun(), "%s no gun in hand" % id)
		eq(c.animation(), "idle", "%s idles" % id)
		c.play("shoot")
		check(c.get_node("Flip/Full/Anim").current_animation == "idle", "%s keeps the idle on shoot" % id)
		# The mesh's bounds in character px: feet on the origin.
		var mesh: Polygon2D = full.mesh()
		var r := Rect2()
		var first := true
		var xf: Transform2D = full.transform * mesh.get_parent().transform
		for p in mesh.polygon:
			var q: Vector2 = xf * p
			r = Rect2(q, Vector2.ZERO) if first else r.expand(q)
			first = false
		near(r.end.y, 0.0, 6.0, "%s feet on the origin" % id)
		check(r.size.y > 200.0 and r.size.y < 260.0, "%s about 150 units tall: %.0f" % [id, r.size.y])
		c.lobby_full = false
		c._apply_frames() # not in the tree: the setter only stores it
		check(c.full() == null and c.rig() != null, "%s lobby_full off: the rig" % id)
		holder.free()
	var m: Node2D = CharacterScene.instantiate()
	var holder := Node.new()
	holder.add_child(m)
	m._ready()
	check(m.full() == null and m.holds_gun(), "the match: frames with the gun")
	holder.free()
