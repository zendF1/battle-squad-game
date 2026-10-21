extends "res://tests/test_case.gd"

const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
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
		m.carve(str(op["crater"]), float(op["x"]), float(op["y"]), float(op["radius"]), float(op.get("floor", 0.0)))
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


## Terrain.CarveBowl's shape (the server's TestCarveBowlShape): dx² + 2·r·dy <= r² under a flat
## top 1.5·r above the centre.
func test_bowl_shape() -> void:
	var m := _solid(400, 300)
	m.carve_bowl(200, 150, 20)
	eq(m.version, 1, "one operation")
	for c in [[200, 160, true], [200, 161, false], [220, 150, true], [221, 150, false],
			[210, 157, true], [210, 158, false], [200, 120, true], [200, 119, false],
			[240, 120, true], [241, 120, false], [230, 140, false]]:
		eq(not m.is_solid(c[0], c[1]), c[2], "(%d, %d) carved" % [c[0], c[1]])
	m = _solid(100, 100)
	m.carve_bowl(50, 50, 20, 55.0)
	check(not m.is_solid(50, 54) and m.is_solid(50, 55), "rows >= floor kept")
	m.carve_bowl(90, 90, 0.0)
	check(m.is_solid(90, 90) and m.version == 2, "a zero radius carves nothing, still an operation")
	m = _solid(100, 100)
	m.carve("circle", 50, 50, 10)
	check(not m.is_solid(50, 59) and not m.is_solid(50, 41), "circle")
	m = _solid(100, 100)
	m.carve("", 50, 50, 10)
	check(not m.is_solid(50, 55) and m.is_solid(50, 56), "no shape: the bowl")


## Every real shot in the fixtures (rain missiles' bowls, the bomb chain's circles, bloom, laser)
## replayed through carve() from its explode events ends on the server's terrainAfter.
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
					m.carve(str(e.get("crater", "")), float(e["position"]["x"]), float(e["position"]["y"]), float(e.get("radius", 0.0)), float(e.get("floor", 0.0)))
			var after := TerrainMask.new()
			after.load_snapshot(c["terrainAfter"])
			eq(_diff_count(m.solid, after.solid), 0, "%s/%s: solid pixels differing from the server" % [path, key])
	check(shapes.has("bowl") and shapes.has("circle"), "bowls and circles replayed: %s" % [shapes.keys()])


func _solid(w: int, h: int) -> TerrainMask:
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid.resize(w * h)
	m.solid.fill(TerrainMask.SOLID)
	m.destructible = m.solid.duplicate()
	return m
