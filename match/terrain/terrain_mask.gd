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
	var n := w * h
	var s := decode_rle(str(snap.get("solid", "")), n)
	var d := decode_rle(str(snap.get("destructible", "")), n)
	if n <= 0 or s.size() != n or d.size() != n:
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
func destroy_circle(cx: float, cy: float, radius: float) -> void:
	version += 1
	var icx := roundi(cx)
	var icy := roundi(cy)
	var ir := roundi(radius)
	var r2 := radius * radius
	for y in range(maxi(icy - ir, 0), mini(icy + ir, height - 1) + 1):
		var dy := float(y - icy)
		var row := y * width
		for x in range(maxi(icx - ir, 0), mini(icx + ir, width - 1) + 1):
			var dx := float(x - icx)
			if dx * dx + dy * dy <= r2:
				var i := row + x
				if destructible[i] != 0:
					solid[i] = 0
