extends RefCounted
## Client copy of the server terrain (battle-squad internal/game/match/terrain.go). Every query
## must match the Go code exactly, including rounding: the server decides, the client predicts
## and draws. Parity is tested against tests/fixtures/terrain_parity.json.
##
## Masks are row-major (index = y * width + x), one byte per pixel: SOLID or 0. The solid bytes
## double as the L8 image the terrain view uploads.

const SOLID := 255
const PLAYER_HEIGHT := 40 # match.PlayerHeight
const MAX_CLIMB_PER_STEP := 3 # Terrain.WalkTo maxClimbPerStep
const CRATER_BOWL := "bowl" # the explode event's crater: Terrain.CarveBowl (every explosion but the bomb chain)
const CRATER_CIRCLE := "circle" # Terrain.DestroyCircleAbove (the bomb chain's shaft)
const BOWL_CEILING := 1.5 # bowlCeiling: the bowl's flat top, in crater radii above the centre

var width := 0
var height := 0
var version := 0
var solid := PackedByteArray()
var destructible := PackedByteArray()


## Loads a TerrainSnapshot {width, height, version, solid, destructible}. Returns false if the
## encoded masks do not cover width * height pixels.
func load_snapshot(snap: Dictionary) -> bool:
	var w := int(snap.get("width", 0))
	var h := int(snap.get("height", 0))
	if w <= 0 or h <= 0:
		return false
	var n := w * h
	var s := decode_rle(str(snap.get("solid", "")), n)
	var d := decode_rle(str(snap.get("destructible", "")), n)
	if s.size() != n or d.size() != n:
		return false
	width = w
	height = h
	version = int(snap.get("version", 0))
	solid = s
	destructible = d
	return true


## Decodes the server's mask encoding: alternating air/solid run lengths (air first) as unsigned
## varints, base64 (std). Whole runs are appended at once, so large maps decode quickly.
static func decode_rle(encoded: String, n: int) -> PackedByteArray:
	var raw := Marshalls.base64_to_raw(encoded)
	var zeros := PackedByteArray()
	zeros.resize(n)
	zeros.fill(0)
	var ones := PackedByteArray()
	ones.resize(n)
	ones.fill(SOLID)

	var out := PackedByteArray()
	var current_solid := false
	var value := 0
	var shift := 0
	for b in raw:
		value |= (b & 0x7F) << shift
		if b & 0x80:
			shift += 7
			continue
		if value > 0:
			if out.size() + value > n:
				return PackedByteArray()
			out.append_array(ones.slice(0, value) if current_solid else zeros.slice(0, value))
		current_solid = not current_solid
		value = 0
		shift = 0
	return out


## Terrain.IsSolid: outside left/right and above the map is air; below the map is solid floor.
func is_solid(x: float, y: float) -> bool:
	var ix := roundi(x)
	var iy := roundi(y)
	if ix < 0 or ix >= width:
		return false
	if iy < 0:
		return false
	if iy >= height:
		return true
	return solid[iy * width + ix] != 0


## Terrain.DestroyCircle: clears destructible solid pixels within radius of (cx, cy).
## floor_y > 0 keeps the rows y >= floor_y (Terrain.DestroyCircleAbove: the explode event's floor).
func destroy_circle(cx: float, cy: float, radius: float, floor_y: float = 0.0) -> void:
	version += 1
	var icx := roundi(cx)
	var icy := roundi(cy)
	var ir := roundi(radius)
	var r2 := radius * radius
	var max_y := height - 1
	if floor_y > 0.0:
		max_y = mini(max_y, ceili(floor_y) - 1)
	for y in range(maxi(icy - ir, 0), mini(icy + ir, max_y) + 1):
		var dy := float(y - icy)
		var row := y * width
		for x in range(maxi(icx - ir, 0), mini(icx + ir, width - 1) + 1):
			var dx := float(x - icx)
			if dx * dx + dy * dy <= r2:
				var i := row + x
				if destructible[i] != 0:
					solid[i] = 0


## Terrain.Carve: the explode event's crater of this shape (CRATER_BOWL, also "", or
## CRATER_CIRCLE) at (cx, cy); floor_y > 0 keeps the rows y >= floor_y.
func carve(shape: String, cx: float, cy: float, radius: float, floor_y: float = 0.0) -> void:
	if shape == CRATER_CIRCLE:
		destroy_circle(cx, cy, radius, floor_y)
	else:
		carve_bowl(cx, cy, radius, floor_y)


## Terrain.CarveBowl: clears the destructible solid pixels of a shallow bowl round (cx, cy), the
## pixels (dx, dy) from the rounded centre with dx² + 2·r·dy <= r² (a floor r/2 under the centre,
## r to each side at its height) and dy >= -BOWL_CEILING·r (a flat top), so a player in it can
## walk out. Same float operations in the same order as the Go code: bit-identical.
func carve_bowl(cx: float, cy: float, radius: float, floor_y: float = 0.0) -> void:
	version += 1
	if radius <= 0.0:
		return
	var icx := roundi(cx)
	var icy := roundi(cy)
	var reach := ceili(2.0 * radius) + 1
	var top := -BOWL_CEILING * radius
	var r2 := radius * radius
	var max_y := height - 1
	if floor_y > 0.0:
		max_y = mini(max_y, ceili(floor_y) - 1)
	for y in range(maxi(icy - ceili(BOWL_CEILING * radius) - 1, 0), mini(icy + ceili(radius / 2.0) + 1, max_y) + 1):
		var dy := float(y - icy)
		if dy < top:
			continue
		var lift := 2.0 * radius * dy
		var row := y * width
		for x in range(maxi(icx - reach, 0), mini(icx + reach, width - 1) + 1):
			var dx := x - icx
			if float(dx * dx) + lift <= r2:
				var i := row + x
				if destructible[i] != 0:
					solid[i] = 0


## Terrain.GetLandingY: first solid pixel at or below start_y in column x; height if none.
func get_landing_y(x: float, start_y: float) -> float:
	var ix := roundi(x)
	if ix < 0 or ix >= width:
		return float(height)
	var iy := maxi(roundi(start_y), 0)
	while iy < height:
		if solid[iy * width + ix] != 0:
			return float(iy)
		iy += 1
	return float(height)


## Terrain.WalkTo: walks column by column toward target_x along the surface; stops at walls
## taller than MAX_CLIMB_PER_STEP or where the body does not fit. Returns the end position.
func walk_to(start_x: float, start_y: float, target_x: float) -> Vector2:
	var cur_x := roundi(start_x)
	var cur_y := roundi(start_y)
	var end_x := roundi(target_x)
	if cur_x == end_x:
		return Vector2(start_x, start_y)
	var dir := 1 if end_x > cur_x else -1
	while cur_x != end_x:
		var next_x := cur_x + dir
		if next_x < 0 or next_x >= width:
			break
		var next_y := _step_surface(next_x, cur_y, MAX_CLIMB_PER_STEP)
		if next_y < 0:
			break
		cur_x = next_x
		cur_y = next_y
	return Vector2(cur_x, cur_y)


## Terrain.hasHeadroom: the PLAYER_HEIGHT pixels above surface_y in column x are free.
func _has_headroom(x: int, surface_y: int) -> bool:
	var y := maxi(surface_y - PLAYER_HEIGHT, 0)
	while y < surface_y and y < height:
		if solid[y * width + x] != 0:
			return false
		y += 1
	return true


## Terrain.stepSurface: surface Y after stepping into column x from cur_y, or -1 when blocked.
func _step_surface(x: int, cur_y: int, max_climb: int) -> int:
	var feet := cur_y - 1
	if feet >= height:
		return height
	if feet < 0 or solid[feet * width + x] == 0:
		# Flat or downhill: cross at the current height, then drop to the first solid pixel.
		if not _has_headroom(x, cur_y):
			return -1
		return int(get_landing_y(x, feet))
	# Uphill: climb to the top of the solid run, up to max_climb pixels.
	var y := feet
	while y > 0 and solid[(y - 1) * width + x] != 0:
		y -= 1
		if cur_y - y > max_climb:
			return -1
	if cur_y - y > max_climb or not _has_headroom(x, y):
		return -1
	return y
