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


func test_destroy_circle_matches_server() -> void:
	var f := _fixture()
	var m := TerrainMask.new()
	check(m.load_snapshot(f["before"]), "load before snapshot")
	for op in f["ops"]:
		m.destroy_circle(float(op["x"]), float(op["y"]), float(op["radius"]))
	var n := m.width * m.height
	eq(_diff_count(m.solid, TerrainMask.decode_rle(f["after"]["solid"], n)), 0, "solid pixels differing from server")
	eq(_diff_count(m.destructible, TerrainMask.decode_rle(f["after"]["destructible"], n)), 0, "destructible pixels differing")
	eq(m.version, int(f["after"]["version"]), "version after ops")
