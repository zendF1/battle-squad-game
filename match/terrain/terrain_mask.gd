extends RefCounted
## Client copy of the server terrain (battle-squad internal/game/match/terrain.go). Every query
## must match the Go code exactly, including rounding: the server decides, the client predicts
## and draws. Parity is tested against tests/fixtures/terrain_parity.json.
##
## Masks are row-major (index = y * width + x), one byte per pixel: SOLID or 0. The solid bytes
## double as the L8 image the terrain view uploads.
##
## Carved pixels: a pixel is carved when it is air now but destructible. The server sets the
## destructible bit only on the map's own solid pixels and never clears it (a crater clears only
## the solid bit), so this holds for every snapshot, a rejoin included, and needs no map of its
## own. `edge` (one byte per pixel, for the terrain view) keeps it ready to draw: CARVED on a
## carved air pixel, 0 on the map's own air; on a solid pixel its scorch, 255 within SCORCH_FULL
## px of a carved pixel fading to 0 at SCORCH_FULL + SCORCH_FADE px (the black band along a
## crater's edge; the map's own surface is not darkened). Every carve updates it around the
## pixels it cleared and grows `dirty`, the region the view must upload again (take_dirty()).

## The terrain rules come from the game data (GET /gamedata terrain): playerHeight (the free space
## a player needs above the ground), maxClimbPerStep (Terrain.WalkTo), bowlDepth / bowlCeiling
## (Terrain.CarveBowl: the bowl's floor and its flat top, in crater radii under / above the centre).

const GameData := preload("res://autoload/game_data_model.gd")

const SOLID := 255
const CRATER_BOWL := "bowl" # the explode event's crater: Terrain.CarveBowl (every explosion, the bomb chain's too)
const CRATER_CIRCLE := "circle" # Terrain.DestroyCircle (no explosion sends it now; still carved)
const CARVED := 255 # edge byte of a carved air pixel
const SCORCH_FULL := 3.0 # px from a carved pixel at full scorch (near-black)
const SCORCH_FADE := 2.5 # px more over which the scorch fades out

var width := 0
var height := 0
var version := 0
var solid := PackedByteArray()
var destructible := PackedByteArray()
var edge := PackedByteArray() # see the top: CARVED / scorch per pixel (rebuild_edge())
var dirty := Rect2i() # pixels whose solid or edge bytes changed since take_dirty()

static var _stamp_offsets := PackedInt32Array() # dx, dy, scorch byte per pixel of the stamp


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
	rebuild_edge()
	return true


## The region changed since the last call (empty if none), and starts a new one.
func take_dirty() -> Rect2i:
	var d := dirty
	dirty = Rect2i()
	return d


## Whether the pixel (x, y) inside the map was carved: air now, destructible (the map's own ground).
func is_carved(x: int, y: int) -> bool:
	var i := y * width + x
	return solid[i] == 0 and destructible[i] != 0


## Recomputes `edge` from the masks: every carved pixel CARVED, the scorch of the solid pixels
## near the carved ones. PackedByteArray.find walks the masks in native code, so only the carved
## pixels (the craters so far, nothing on a fresh map) are visited one by one. The whole map is
## dirty.
func rebuild_edge() -> void:
	var n := width * height
	edge = PackedByteArray()
	edge.resize(n)
	edge.fill(0)
	dirty = Rect2i(0, 0, width, height)
	var i := 0
	while i < n:
		var air := solid.find(0, i) # start of the next air run
		if air < 0:
			break
		var end := solid.find(SOLID, air)
		if end < 0:
			end = n
		var j := air
		while j < end: # the carved runs inside this air run
			var c := destructible.find(SOLID, j)
			if c < 0 or c >= end:
				break
			var stop := destructible.find(0, c)
			if stop < 0 or stop > end:
				stop = end
			for k in range(c, stop):
				edge[k] = CARVED
			for k in range(c, stop):
				_scorch_around(k)
			j = stop
		i = end


## The scorch bytes the stamp gives the pixels round a carved one: dx, dy, value triples for
## every offset nearer than SCORCH_FULL + SCORCH_FADE (255 up to SCORCH_FULL, linear to 0).
static func stamp_offsets() -> PackedInt32Array:
	if _stamp_offsets.is_empty():
		var reach := SCORCH_FULL + SCORCH_FADE
		var n := ceili(reach)
		for dy in range(-n, n + 1):
			for dx in range(-n, n + 1):
				var v := roundi(255.0 * clampf((reach - sqrt(float(dx * dx + dy * dy))) / SCORCH_FADE, 0.0, 1.0))
				if v > 0 and (dx != 0 or dy != 0):
					_stamp_offsets.append_array([dx, dy, v])
	return _stamp_offsets


## The carved pixel i scorches the solid pixels round it, if it touches one (a carved pixel deep
## inside a crater has nothing to scorch).
func _scorch_around(i: int) -> void:
	var x := i % width
	var y := i / width
	if not ((x > 0 and solid[i - 1] != 0) or (x < width - 1 and solid[i + 1] != 0)
			or (y > 0 and solid[i - width] != 0) or (y < height - 1 and solid[i + width] != 0)):
		return
	var offs := stamp_offsets()
	for k in range(0, offs.size(), 3):
		var nx := x + offs[k]
		var ny := y + offs[k + 1]
		if nx < 0 or ny < 0 or nx >= width or ny >= height:
			continue
		var j := ny * width + nx
		if solid[j] != 0 and edge[j] < offs[k + 2]:
			edge[j] = offs[k + 2]


## After a carve cleared the pixels `cleared`: marks them carved, scorches round them and grows
## `dirty` over them and their scorch.
func _carved(cleared: PackedInt32Array) -> void:
	if cleared.is_empty():
		return
	if edge.size() != width * height: # a mask built by hand (tests): everything, the pixels just cleared too
		rebuild_edge()
		return
	var x0 := width
	var y0 := height
	var x1 := -1
	var y1 := -1
	for i in cleared:
		edge[i] = CARVED
		var x := i % width
		var y := i / width
		x0 = mini(x0, x)
		x1 = maxi(x1, x)
		y0 = mini(y0, y)
		y1 = maxi(y1, y)
	for i in cleared:
		_scorch_around(i)
	var reach := ceili(SCORCH_FULL + SCORCH_FADE)
	var r := Rect2i(x0 - reach, y0 - reach, x1 - x0 + 1 + 2 * reach, y1 - y0 + 1 + 2 * reach).intersection(Rect2i(0, 0, width, height))
	dirty = dirty.merge(r) if dirty.has_area() else r


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
func destroy_circle(cx: float, cy: float, radius: float) -> void:
	version += 1
	var icx := roundi(cx)
	var icy := roundi(cy)
	var ir := roundi(radius)
	var r2 := radius * radius
	var cleared := PackedInt32Array()
	for y in range(maxi(icy - ir, 0), mini(icy + ir, height - 1) + 1):
		var dy := float(y - icy)
		var row := y * width
		for x in range(maxi(icx - ir, 0), mini(icx + ir, width - 1) + 1):
			var dx := float(x - icx)
			if dx * dx + dy * dy <= r2:
				var i := row + x
				if destructible[i] != 0 and solid[i] != 0:
					solid[i] = 0
					cleared.append(i)
	_carved(cleared)


## Terrain.Carve: the explode event's crater of this shape (CRATER_BOWL, also "", or
## CRATER_CIRCLE) at (cx, cy).
func carve(shape: String, cx: float, cy: float, radius: float) -> void:
	if shape == CRATER_CIRCLE:
		destroy_circle(cx, cy, radius)
	else:
		carve_bowl(cx, cy, radius)


## Terrain.CarveBowl: clears the destructible solid pixels of a bowl round (cx, cy), the pixels
## (dx, dy) from the rounded centre with dx² + (r/k)·dy <= r², k = bowlDepth (a floor k·r under
## the centre, r to each side at its height) and dy >= -bowlCeiling·r (a flat top), so a player
## in it can walk out. Same float operations in the same order as the Go code: bit-identical.
func carve_bowl(cx: float, cy: float, radius: float) -> void:
	version += 1
	var depth := GameData.bowl_depth()
	var ceiling := GameData.bowl_ceiling()
	if radius <= 0.0 or depth <= 0.0:
		return
	var icx := roundi(cx)
	var icy := roundi(cy)
	var reach := ceili(2.0 * radius) + 1
	var top := -ceiling * radius
	var r2 := radius * radius
	var lean := radius / depth
	var cleared := PackedInt32Array()
	for y in range(maxi(icy - ceili(ceiling * radius) - 1, 0), mini(icy + ceili(depth * radius) + 1, height - 1) + 1):
		var dy := float(y - icy)
		if dy < top:
			continue
		var lift := lean * dy
		var row := y * width
		for x in range(maxi(icx - reach, 0), mini(icx + reach, width - 1) + 1):
			var dx := x - icx
			if float(dx * dx) + lift <= r2:
				var i := row + x
				if destructible[i] != 0 and solid[i] != 0:
					solid[i] = 0
					cleared.append(i)
	_carved(cleared)


## Terrain.CarveTunnel: the drill event's tunnel, one version step (like one explode) for the
## whole path (carve_tunnel_points() over every point).
func carve_tunnel(path: PackedVector2Array, radius: float) -> void:
	version += 1
	carve_tunnel_points(path, radius, 0, path.size())


## Points [from, to) of a tunnel's path carved without a version step (the drill bores it bit by
## bit: match/terrain/tunnel_dig.gd; the version step is taken once when it starts). For every
## point p (rounded; the server sends whole px): the destructible solid pixels (x, y) with x in [p.x - ceil(r), p.x + ceil(r)], y in
## [p.y - ceil(r), p.y + ceil(r)], inside the map, and float(dx·dx + dy·dy) <= r·r. Clearing is
## a union, so any split into parts carves the same pixels as the whole.
func carve_tunnel_points(path: PackedVector2Array, radius: float, from: int, to: int) -> void:
	if radius <= 0.0:
		return
	var reach := ceili(radius)
	var r2 := radius * radius
	var cleared := PackedInt32Array()
	for k in range(maxi(from, 0), mini(to, path.size())):
		var px := roundi(path[k].x)
		var py := roundi(path[k].y)
		for y in range(maxi(py - reach, 0), mini(py + reach, height - 1) + 1):
			var dy := y - py
			var row := y * width
			for x in range(maxi(px - reach, 0), mini(px + reach, width - 1) + 1):
				var dx := x - px
				if float(dx * dx + dy * dy) <= r2:
					var i := row + x
					if destructible[i] != 0 and solid[i] != 0:
						solid[i] = 0
						cleared.append(i)
	_carved(cleared)


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
## taller than maxClimbPerStep or where the body does not fit. A step into a hole down to the
## bottom of the map ends the walk there, y = height (the player falls out of the map). Returns
## the end position. A walk from below the map goes nowhere (that player is dead: no walking along
## the bottom).
func walk_to(start_x: float, start_y: float, target_x: float) -> Vector2:
	var cur_x := roundi(start_x)
	var cur_y := roundi(start_y)
	var end_x := roundi(target_x)
	if cur_x == end_x or cur_y >= height:
		return Vector2(start_x, start_y)
	var dir := 1 if end_x > cur_x else -1
	var climb := GameData.max_climb_per_step()
	while cur_x != end_x:
		var next_x := cur_x + dir
		if next_x < 0 or next_x >= width:
			break
		var next_y := _step_surface(next_x, cur_y, climb)
		if next_y < 0:
			break
		cur_x = next_x
		cur_y = next_y
		if cur_y >= height:
			break # fell out of the map
	return Vector2(cur_x, cur_y)


## Terrain.hasHeadroom: the playerHeight pixels above surface_y in column x are free.
func _has_headroom(x: int, surface_y: int) -> bool:
	var y := maxi(surface_y - GameData.player_height(), 0)
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
