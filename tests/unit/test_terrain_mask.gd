extends "res://tests/test_case.gd"

const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const FIXTURE := "res://tests/fixtures/terrain_parity.json"


func _fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func _diff_count(a: PackedByteArray, b: PackedByteArray) -> int:
	if a.size() != b.size():
		return -1
	var n := 0
	for i in a.size():
		if a[i] != b[i]:
			n += 1
	return n


func test_decode_rle_runs_start_with_air() -> void:
	# air 2, solid 3, air 1 → varints [2, 3, 1]
	var bytes := TerrainMask.decode_rle(Marshalls.raw_to_base64(PackedByteArray([2, 3, 1])), 6)
	eq(bytes, PackedByteArray([0, 0, 255, 255, 255, 0]), "decoded mask")


func test_decode_rle_multibyte_varint() -> void:
	# 300 = 0xAC 0x02 as an unsigned varint, then a 1-pixel solid run
	var bytes := TerrainMask.decode_rle(Marshalls.raw_to_base64(PackedByteArray([0xAC, 0x02, 1])), 301)
	eq(bytes.size(), 301, "size")
	eq(bytes[299], 0, "last air pixel")
	eq(bytes[300], 255, "solid pixel")


func test_load_snapshot_rejects_wrong_size() -> void:
	var m := TerrainMask.new()
	var ok := m.load_snapshot({"width": 4, "height": 2, "version": 0,
		"solid": Marshalls.raw_to_base64(PackedByteArray([3])), "destructible": Marshalls.raw_to_base64(PackedByteArray([3]))})
	check(not ok, "3 pixels for a 4x2 map must be rejected")


func test_decode_rle_rejects_mask_longer_than_size() -> void:
	# air 2, solid 5 covers 7 pixels but only 6 are allowed
	var bytes := TerrainMask.decode_rle(Marshalls.raw_to_base64(PackedByteArray([2, 5])), 6)
	eq(bytes.size(), 0, "overflowing mask is rejected")
	var m := TerrainMask.new()
	var enc := Marshalls.raw_to_base64(PackedByteArray([2, 5]))
	check(not m.load_snapshot({"width": 3, "height": 2, "version": 0, "solid": enc, "destructible": enc}),
		"7 pixels for a 3x2 map must be rejected")


func test_load_snapshot_rejects_non_positive_size() -> void:
	var enc := Marshalls.raw_to_base64(PackedByteArray([2]))
	for size in [[-2, 3], [3, -2], [0, 4], [4, 0], [-2, -3]]:
		var m := TerrainMask.new()
		check(not m.load_snapshot({"width": size[0], "height": size[1], "version": 0, "solid": enc, "destructible": enc}),
			"%dx%d must be rejected" % [size[0], size[1]])


func test_is_solid_bounds() -> void:
	var m := TerrainMask.new()
	m.load_snapshot({"width": 2, "height": 2, "version": 0,
		"solid": Marshalls.raw_to_base64(PackedByteArray([2, 2])), "destructible": Marshalls.raw_to_base64(PackedByteArray([4]))})
	check(not m.is_solid(0, 0), "top row is air")
	check(m.is_solid(1, 1), "bottom row is solid")
	check(not m.is_solid(-1, 1), "left of map is air")
	check(not m.is_solid(2, 1), "right of map is air")
	check(not m.is_solid(0, -1), "sky is air")
	check(m.is_solid(0, 5), "below map is solid floor")


func test_craters_match_server() -> void:
	var f := _fixture()
	var m := TerrainMask.new()
	check(m.load_snapshot(f["before"]), "load before snapshot")
	var shapes := {}
	for op in f["ops"]:
		shapes[str(op["crater"])] = true
		m.carve(str(op["crater"]), float(op["x"]), float(op["y"]), float(op["radius"]))
	eq(shapes.keys().size(), 2, "the fixture has circles and bowls")
	var n := m.width * m.height
	eq(_diff_count(m.solid, TerrainMask.decode_rle(f["after"]["solid"], n)), 0, "solid pixels differing from server")
	eq(_diff_count(m.destructible, TerrainMask.decode_rle(f["after"]["destructible"], n)), 0, "destructible pixels differing")
	eq(m.version, int(f["after"]["version"]), "version after ops")


func _after_mask(f: Dictionary):
	var m := TerrainMask.new()
	m.load_snapshot(f["after"])
	return m


func test_get_landing_y_matches_server() -> void:
	var f := _fixture()
	var m = _after_mask(f)
	for c in f["landings"]:
		eq(m.get_landing_y(float(c["x"]), float(c["startY"])), float(c["y"]),
			"landing at x=%s startY=%s" % [c["x"], c["startY"]])


func test_walk_to_matches_server() -> void:
	var f := _fixture()
	var m = _after_mask(f)
	for c in f["walks"]:
		eq(m.walk_to(float(c["startX"]), float(c["startY"]), float(c["targetX"])), Vector2(float(c["x"]), float(c["y"])),
			"walk %s,%s -> %s" % [c["startX"], c["startY"], c["targetX"]])


## Terrain.CarveBowl's shape (the server's TestCarveBowlShape): dx² + (r/k)·dy <= r², k =
## bowlDepth 0.72 (the fixture), under a flat top 1.5·r above the centre.
func test_bowl_shape() -> void:
	eq(GameData.bowl_depth(), 0.72, "the cases are for k 0.72")
	var m := _solid(400, 300)
	m.carve_bowl(200, 150, 20)
	eq(m.version, 1, "one operation")
	for c in [[200, 164, true], [200, 165, false], [220, 150, true], [221, 150, false],
			[210, 160, true], [210, 161, false], [200, 120, true], [200, 119, false],
			[235, 120, true], [236, 120, false], [230, 140, false]]:
		eq(not m.is_solid(c[0], c[1]), c[2], "(%d, %d) carved" % [c[0], c[1]])
	m = _solid(100, 100)
	m.carve_bowl(50, 95, 20)
	check(not m.is_solid(50, 99) and m.is_solid(50, 100), "the bottom row carved (no floor), below the map solid")
	m.carve_bowl(90, 50, 0.0)
	check(m.is_solid(90, 50) and m.version == 2, "a zero radius carves nothing, still an operation")
	m = _solid(100, 100)
	m.carve("circle", 50, 50, 10)
	check(not m.is_solid(50, 59) and not m.is_solid(50, 41), "circle")
	m = _solid(100, 100)
	m.carve("", 50, 50, 10)
	check(not m.is_solid(50, 57) and m.is_solid(50, 58), "no shape: the bowl")


## Every real shot in the fixtures (rain missiles' and the bomb chain's bowls, bloom, laser)
## replayed through carve() from its explode events ends on the server's terrainAfter; its
## carved pixels and scorch, kept up crater by crater, are what a rejoin rebuilds from
## terrainAfter alone (rebuild_edge()).
func test_fixture_shots_carve_like_the_server() -> void:
	var shapes := {}
	for path in ["skill_shots", "skill_rain", "skill_bombchain", "skill_laser", "skill_bloom"]:
		var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/%s.json" % path))
		for key in all:
			var c = all[key]
			if not (c is Dictionary) or not c.has("terrainAfter"):
				continue
			var m := TerrainMask.new()
			check(m.load_snapshot(c["terrain"]), "%s/%s: load" % [path, key])
			for e in c["shot"]["events"]:
				if e["type"] == "explode":
					shapes[str(e.get("crater", ""))] = true
					check(not e.has("floor"), "%s/%s: no floor any more" % [path, key])
					m.carve(str(e.get("crater", "")), float(e["position"]["x"]), float(e["position"]["y"]), float(e.get("radius", 0.0)))
			var after := TerrainMask.new()
			after.load_snapshot(c["terrainAfter"])
			eq(_diff_count(m.solid, after.solid), 0, "%s/%s: solid pixels differing from the server" % [path, key])
			_check_edges_alike(m, after, "%s/%s" % [path, key])
	eq(shapes.keys(), ["bowl"], "every shot carves bowls")


func _solid(w: int, h: int) -> TerrainMask:
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid.resize(w * h)
	m.solid.fill(TerrainMask.SOLID)
	m.destructible = m.solid.duplicate()
	return m


## The edge bytes kept up crater by crater (a) and rebuilt from the final masks (b): the same
## carved pixels; the scorch the same but where a crater cut through an older one's scorched
## edge (b scorches from the carved pixels that touch the ground now only).
func _check_edges_alike(a: TerrainMask, b: TerrainMask, what: String) -> void:
	var carved := 0
	var scorched := 0
	var off := 0
	for i in a.edge.size():
		if (a.edge[i] == TerrainMask.CARVED and a.solid[i] == 0) != (b.edge[i] == TerrainMask.CARVED and b.solid[i] == 0):
			carved += 1
		if a.solid[i] != 0:
			scorched += 1 if a.edge[i] > 0 else 0
			off += 1 if absi(a.edge[i] - b.edge[i]) > 0 else 0
	eq(carved, 0, what + ": carved pixels differing")
	check(off <= scorched / 50, "%s: %d of %d scorched pixels differ from the rebuilt ones" % [what, off, scorched])


## The black band: the ground within SCORCH_FULL px of a carved pixel is fully scorched, fading
## out over SCORCH_FADE px; the crater is marked carved, the sky over it and the map's own
## surface away from it are not touched.
func test_scorch_along_a_carved_edge() -> void:
	var m := _ground(400, 200, 100)
	m.carve_bowl(200, 103, 20) # 14 px floor under the centre: the last carved row 117
	eq(m.edge[117 * 400 + 200], TerrainMask.CARVED, "the crater floor is carved")
	check(m.is_carved(200, 117) and not m.is_carved(200, 50) and not m.is_carved(200, 118), "is_carved")
	eq(m.edge[50 * 400 + 200], 0, "the sky over it is the map's own air")
	for d in [1, 2, 3]:
		eq(m.edge[(117 + d) * 400 + 200], 255, "%d px under the floor: full scorch" % d)
	var four: int = m.edge[121 * 400 + 200]
	var five: int = m.edge[122 * 400 + 200]
	check(four > five and five > 0 and four < 255, "fading: 4 px %d, 5 px %d" % [four, five])
	eq(m.edge[124 * 400 + 200], 0, "7 px under: none")
	eq(m.edge[100 * 400 + 260], 0, "the map's own surface away from the crater")
	eq(m.edge[100 * 400 + 30], 0, "nor the surface at the far side")
	# an overlapping crater: its pixels become carved, the edge it leaves scorched in turn
	m.carve_bowl(220, 110, 20)
	var floor_y := 110
	while m.solid[(floor_y + 1) * 400 + 220] == 0:
		floor_y += 1
	eq(m.edge[(floor_y + 1) * 400 + 220], 255, "the second crater's floor is scorched")
	eq(m.edge[floor_y * 400 + 220], TerrainMask.CARVED, "its air carved")
	var scorched_air := 0
	for i in m.edge.size():
		if m.solid[i] == 0 and m.edge[i] != 0 and m.edge[i] != TerrainMask.CARVED:
			scorched_air += 1
	eq(scorched_air, 0, "air carries no scorch")


## A rejoin's snapshot has no list of craters: the carved pixels are the destructible air, so a
## mask loaded at a later version shows the same craters and band as one that carved them.
func test_rebuilt_edge_matches_the_carved_one() -> void:
	var m := _ground(600, 300, 120)
	for c in [[150.0, 123.0, 20.0], [170.0, 130.0, 52.0], [400.0, 123.0, 12.0], [420.0, 126.0, 24.0]]:
		m.carve_bowl(c[0], c[1], c[2])
	var r := TerrainMask.new()
	r.width = m.width
	r.height = m.height
	r.solid = m.solid.duplicate()
	r.destructible = m.destructible.duplicate()
	r.rebuild_edge()
	_check_edges_alike(m, r, "rebuilt")
	eq(r.take_dirty(), Rect2i(0, 0, 600, 300), "a rebuild is all dirty")
	eq(r.take_dirty(), Rect2i(), "then clean")


## A carve dirties the crater and its band only; nothing cleared, nothing dirty.
func test_carve_dirty_region() -> void:
	var m := _ground(400, 200, 100)
	m.rebuild_edge()
	m.take_dirty()
	m.carve_bowl(200, 103, 20)
	var d := m.take_dirty()
	check(d.has_point(Vector2i(200, 117)) and d.has_point(Vector2i(200, 122)), "the floor and its band: %s" % [d])
	check(d.size.x <= 2 * 36 + 12 and d.size.y <= 20 + 12 + 12, "no bigger than the bowl and its band: %s" % [d])
	m.carve_bowl(200, 20, 20) # in the sky
	eq(m.take_dirty(), Rect2i(), "nothing carved in the sky")


## The view draws the map in tiles and a crater uploads only the tiles its region touches.
func test_view_uploads_only_touched_tiles() -> void:
	const TerrainView := preload("res://match/terrain/terrain_view.gd")
	var m := _ground(1600, 900, 500)
	var v = TerrainView.new()
	v.show_mask(m)
	var tiles: Array[Rect2i] = v.tile_rects()
	eq(tiles.size(), 7 * 4, "1600 × 900 in 256 px tiles")
	var area := 0
	for t in tiles:
		area += t.get_area()
	eq(area, 1600 * 900, "the tiles cover the map once")
	for t in v.tile_texture_rects():
		check(Rect2i(0, 0, 1600, 900).encloses(t), "a tile's texture inside the map")
	eq(v.uploads, 28, "every tile uploaded once")
	var t0 := Time.get_ticks_usec()
	m.carve_bowl(640, 503, 52) # Tanko's crater in the middle of a tile
	var carve_us := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	v.refresh()
	var refresh_us := Time.get_ticks_usec() - t0
	var up: int = v.uploads - 28
	check(up >= 1 and up <= 4, "a crater uploads %d tiles" % up)
	print("    Tanko crater: carve + scorch %.1f ms, %d tile uploads %.1f ms" % [carve_us / 1000.0, up, refresh_us / 1000.0])
	v.refresh()
	eq(v.uploads - 28, up, "no change: no upload")
	v.free()


## A w × h mask, solid from row top down (the map's own ground, destructible).
func _ground(w: int, h: int, top: int) -> TerrainMask:
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid.resize(w * h)
	m.solid.fill(0)
	for y in range(top, h):
		for x in w:
			m.solid[y * w + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	return m
