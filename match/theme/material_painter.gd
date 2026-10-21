extends RefCounted
## Code-drawn terrain materials of the map themes (match/theme/map_themes.gd), built pixel by
## pixel so they tile exactly. tools/bake_themes.gd saves them as assets/terrain/<id>_<part>.png
## (ui/art.gd terrain_part()); the match loads those (an artist can overwrite them) and paints a
## missing one here at run time. A material is three images, read by match/terrain/terrain.gdshader:
## - fill: FILL_SIZE square, tileable both ways, sampled by world position (1 px = 1 world px);
## - edge: EDGE_WIDTH wide, tileable horizontally: `cap` rows drawn in the air just above a
##   surface (the bottom one touches it), then the band rows from the surface down;
##   transparent = the fill (or air for a cap texel);
## - hang: EDGE_WIDTH wide: `hang` rows drawn in the air just under an underside (the top one
##   touches it): icicles, roots, drips; HANG_NONE (one transparent row) for none.
## grass_dirt is today's grassland ground: assets/terrain/dirt.png + grass_edge.png (6 cap rows),
## no hang; every other material is painted here.

const FILL_SIZE := 128
const EDGE_WIDTH := 128
const HANG_NONE := 0

## id -> {cap, band, hang (rows), hard (indestructible look), bottom_tint, rim, rim_mix}.
## bottom_tint: the fill's colour factor at the map's bottom; rim / rim_mix: the outline on walls
## and undersides (2 px of air beside or below), and for a hard material against soft ground too.
const SPECS := {
	"grass_dirt": {"cap": 6, "band": 18, "hang": 0, "hard": false,
		"bottom_tint": Color(0.53, 0.51, 0.56), "rim": Color(0.25, 0.16, 0.1), "rim_mix": 0.7},
	"mossy_stone": {"cap": 4, "band": 8, "hang": 0, "hard": true,
		"bottom_tint": Color(0.7, 0.7, 0.74), "rim": Color(0.16, 0.17, 0.2), "rim_mix": 0.85},
	"snow": {"cap": 5, "band": 14, "hang": 10, "hard": false,
		"bottom_tint": Color(0.62, 0.7, 0.86), "rim": Color(0.36, 0.5, 0.72), "rim_mix": 0.6},
	"ice_block": {"cap": 3, "band": 6, "hang": 8, "hard": true,
		"bottom_tint": Color(0.7, 0.78, 0.92), "rim": Color(0.1, 0.28, 0.55), "rim_mix": 0.85},
	"sand": {"cap": 6, "band": 10, "hang": 0, "hard": false,
		"bottom_tint": Color(0.72, 0.6, 0.5), "rim": Color(0.55, 0.38, 0.18), "rim_mix": 0.6},
	"driftwood": {"cap": 0, "band": 4, "hang": 0, "hard": true,
		"bottom_tint": Color(0.82, 0.8, 0.8), "rim": Color(0.24, 0.13, 0.06), "rim_mix": 0.9},
	"grave_soil": {"cap": 6, "band": 10, "hang": 9, "hard": false,
		"bottom_tint": Color(0.55, 0.55, 0.62), "rim": Color(0.08, 0.07, 0.1), "rim_mix": 0.7},
	"tomb_brick": {"cap": 3, "band": 4, "hang": 0, "hard": true,
		"bottom_tint": Color(0.7, 0.72, 0.76), "rim": Color(0.07, 0.09, 0.1), "rim_mix": 0.85},
	"dune_sand": {"cap": 0, "band": 8, "hang": 0, "hard": false,
		"bottom_tint": Color(0.68, 0.52, 0.42), "rim": Color(0.5, 0.28, 0.12), "rim_mix": 0.65},
	"sandstone": {"cap": 0, "band": 4, "hang": 0, "hard": true,
		"bottom_tint": Color(0.8, 0.74, 0.68), "rim": Color(0.38, 0.24, 0.12), "rim_mix": 0.85},
	"sky_earth": {"cap": 6, "band": 16, "hang": 10, "hard": false,
		"bottom_tint": Color(0.62, 0.55, 0.6), "rim": Color(0.3, 0.2, 0.15), "rim_mix": 0.7},
	"marble": {"cap": 0, "band": 4, "hang": 0, "hard": true,
		"bottom_tint": Color(0.82, 0.84, 0.9), "rim": Color(0.34, 0.4, 0.55), "rim_mix": 0.8},
	"basalt": {"cap": 0, "band": 6, "hang": 0, "hard": false,
		"bottom_tint": Color(0.6, 0.5, 0.5), "rim": Color(0.08, 0.04, 0.04), "rim_mix": 0.7},
	"temple_gold": {"cap": 0, "band": 5, "hang": 0, "hard": true,
		"bottom_tint": Color(0.78, 0.68, 0.6), "rim": Color(0.3, 0.12, 0.04), "rim_mix": 0.85},
	"gravel": {"cap": 0, "band": 5, "hang": 0, "hard": false,
		"bottom_tint": Color(0.6, 0.62, 0.66), "rim": Color(0.16, 0.15, 0.15), "rim_mix": 0.7},
	"steel_plate": {"cap": 0, "band": 4, "hang": 0, "hard": true,
		"bottom_tint": Color(0.75, 0.78, 0.84), "rim": Color(0.1, 0.13, 0.18), "rim_mix": 0.9},
	"asphalt": {"cap": 0, "band": 5, "hang": 0, "hard": false,
		"bottom_tint": Color(0.6, 0.6, 0.72), "rim": Color(0.06, 0.06, 0.12), "rim_mix": 0.7},
	"girder": {"cap": 0, "band": 4, "hang": 0, "hard": true,
		"bottom_tint": Color(0.75, 0.75, 0.88), "rim": Color(0.05, 0.06, 0.14), "rim_mix": 0.9},
	"rock_soil": {"cap": 6, "band": 14, "hang": 0, "hard": false,
		"bottom_tint": Color(0.58, 0.58, 0.62), "rim": Color(0.2, 0.18, 0.16), "rim_mix": 0.7},
	"stone_tile": {"cap": 4, "band": 4, "hang": 0, "hard": true,
		"bottom_tint": Color(0.75, 0.76, 0.8), "rim": Color(0.2, 0.22, 0.26), "rim_mix": 0.85},
	"cave_rock": {"cap": 3, "band": 6, "hang": 10, "hard": false,
		"bottom_tint": Color(0.55, 0.5, 0.62), "rim": Color(0.05, 0.03, 0.08), "rim_mix": 0.75},
	"boulder": {"cap": 0, "band": 3, "hang": 0, "hard": true,
		"bottom_tint": Color(0.7, 0.68, 0.76), "rim": Color(0.06, 0.05, 0.1), "rim_mix": 0.9},
}

const PARTS := ["fill", "edge", "hang"]


static func ids() -> Array:
	return SPECS.keys()


static func spec(id: String) -> Dictionary:
	return SPECS.get(id, SPECS["grass_dirt"])


## The image of a material part ("fill", "edge", "hang"); grass_dirt's fill and edge are the
## shipped dirt.png / grass_edge.png (null here: ui/art.gd loads them).
static func paint(id: String, part: String) -> Image:
	if not SPECS.has(id) or (id == "grass_dirt" and part != "hang"):
		return null
	match part:
		"fill":
			return _fill(id)
		"edge":
			return _edge(id)
		"hang":
			return _hang(id)
	return null


# ── Noise ───────────────────────────────────────────────────────────────────

static func _hash(x: int, y: int, salt: int = 0) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h ^ (h >> 16)) / float(0x7fffffff)


## Value noise tiling over `period` px with `cells` lattice cells per period, 0..1.
static func _vnoise(x: float, y: float, period: int, cells: int, salt: int) -> float:
	var fx := x / period * cells
	var fy := y / period * cells
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _hash(posmod(ix, cells), posmod(iy, cells), salt)
	var b := _hash(posmod(ix + 1, cells), posmod(iy, cells), salt)
	var c := _hash(posmod(ix, cells), posmod(iy + 1, cells), salt)
	var d := _hash(posmod(ix + 1, cells), posmod(iy + 1, cells), salt)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func _fbm(x: float, y: float, period: int, salt: int) -> float:
	return _vnoise(x, y, period, 4, salt) * 0.55 + _vnoise(x, y, period, 8, salt + 1) * 0.3 + _vnoise(x, y, period, 16, salt + 2) * 0.15


static func _rgb(c: Color, k: float) -> Color:
	return Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1), 1.0)


static func _blank(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _disc(img: Image, at: Vector2, r: float, col: Color, light: Color = Color(0, 0, 0, 0)) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var n := ceili(r) + 1
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			if Vector2(dx, dy).length() > r:
				continue
			var c := col
			if light.a > 0.0 and dy < -r * 0.35 and dx < r * 0.3:
				c = light
			img.set_pixel(posmod(int(at.x) + dx, w), posmod(int(at.y) + dy, h), c)


# ── Fills ───────────────────────────────────────────────────────────────────

## Ground: base colour varied by noise, soft wavy strata, 2 px grit, wrapped pebbles.
static func _earth(base: Color, salt: int, vary: float, strata: float, grit_dark: Color, grit_light: Color,
		pebbles: int, pebble: Color, pebble_r: Vector2 = Vector2(1.6, 3.4)) -> Image:
	var n := FILL_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var fx := TAU * x / n
			var fy := TAU * y / n
			var k := 1.0 + (_fbm(x, y, n, salt) - 0.5) * vary
			k += sin(fy * 2.0 + sin(fx) * 1.6) * strata + sin(fy * 5.0 + sin(fx * 2.0) * 0.8) * strata * 0.5
			var c := _rgb(base, k)
			var g := _hash(x >> 1, y >> 1, salt + 9)
			if g > 0.94:
				c = grit_dark
			elif g < 0.04:
				c = grit_light
			img.set_pixel(x, y, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	for i in pebbles:
		var at := Vector2(rng.randf() * n, rng.randf() * n)
		var shade := rng.randf_range(0.85, 1.15)
		_disc(img, at, rng.randf_range(pebble_r.x, pebble_r.y), _rgb(pebble, shade), _rgb(pebble, shade * 1.3))
	return img


## Blocks in rows of bh px, bw wide, every other row shifted by bw / 2: each block its own shade,
## a lit top-left and a shaded bottom-right edge, `mortar` px of mortar between them.
static func _bricks(size: Vector2i, bw: int, bh: int, base: Color, vary: float, mortar_col: Color, mortar: int,
		salt: int, light: float = 1.18, shade: float = 0.78, grain: float = 0.08) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var row := y / bh
		var ly := y % bh
		var shift := (bw / 2) if row % 2 == 1 else 0
		for x in size.x:
			var sx := posmod(x + shift, size.x)
			var col := sx / bw
			var lx := sx % bw
			var c: Color
			if lx < mortar or ly < mortar:
				c = mortar_col
			else:
				var k := 1.0 + (_hash(col, row, salt) - 0.5) * vary
				k += (_fbm(x, y, size.x, salt + 3) - 0.5) * grain * 2.0
				if ly < mortar + 2 or lx < mortar + 1:
					k *= light
				elif ly >= bh - 2 or lx >= bw - 1:
					k *= shade
				c = _rgb(base, k)
			img.set_pixel(x, y, c)
	return img


## Riveted plates pw px square: bevel, rivets in the corners, faint brushed stripes; `brace`
## draws an X brace inside each plate (a girder truss).
static func _plates(pw: int, base: Color, rivet: Color, seam: Color, salt: int, brace: bool, glow: Color = Color(0, 0, 0, 0)) -> Image:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var lx := x % pw
			var ly := y % pw
			var k := 1.0 + sin((x + y * 0.3) * 0.9) * 0.025 + (_hash(x / pw, y / pw, salt) - 0.5) * 0.08
			if ly <= 1 or lx <= 1:
				k *= 1.22
			elif ly >= pw - 2 or lx >= pw - 2:
				k *= 0.7
			var c := _rgb(base, k)
			if lx == 0 or ly == 0:
				c = seam
			if brace:
				var d1 := absi(lx - ly)
				var d2 := absi(lx - (pw - 1 - ly))
				if (d1 <= 1 or d2 <= 1) and lx > 2 and ly > 2 and lx < pw - 3 and ly < pw - 3:
					c = _rgb(base, 0.62 if mini(d1, d2) == 0 else 0.8)
			img.set_pixel(x, y, c)
	for py in range(0, n, pw):
		for px in range(0, n, pw):
			for corner in [Vector2(4, 4), Vector2(pw - 5, 4), Vector2(4, pw - 5), Vector2(pw - 5, pw - 5)]:
				var at: Vector2 = Vector2(px, py) + corner
				_disc(img, at, 1.6, _rgb(rivet, 0.7))
				img.set_pixel(int(at.x) - 1, int(at.y) - 1, _rgb(rivet, 1.35))
	if glow.a > 0.0: # a light strip along the plate's middle
		for x in n:
			for y in [pw / 2, pw / 2 + 1]:
				if x % pw > 3 and x % pw < pw - 4:
					for py in range(0, n, pw):
						img.set_pixel(x, py + y, glow)
	return img


static func _planks(base: Color, salt: int) -> Image:
	var n := 64
	var ph := 8
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		var row := y / ph
		var ly := y % ph
		var joint := int(_hash(row, 0, salt) * n)
		for x in n:
			var k := 1.0 + (_hash(row, 1, salt) - 0.5) * 0.18
			k += sin(x * 0.35 + sin(x * 0.07 + row) * 3.0 + ly * 0.8) * 0.06
			if ly == 0:
				k *= 0.55
			elif ly == 1:
				k *= 1.2
			elif ly == ph - 1:
				k *= 0.8
			var c := _rgb(base, k)
			var jx := posmod(x - joint, n)
			if jx == 0:
				c = _rgb(base, 0.5)
			elif jx == 3 or jx == n - 3:
				if ly == 3 or ly == 5:
					c = Color(0.3, 0.28, 0.26) # nails
			img.set_pixel(x, y, c)
	return img


static func _ice(base: Color, salt: int) -> Image:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var k := 1.0 + (_fbm(x, y, n, salt) - 0.5) * 0.22
			var diag := posmod(x + y, 32)
			if diag < 3:
				k *= 1.28 # shine streak
			elif diag < 5:
				k *= 1.12
			var c := _rgb(base, k)
			if x % 32 == 0 or y % 32 == 0:
				c = _rgb(base, 0.82)
			elif x % 32 == 1 or y % 32 == 1:
				c = _rgb(base, 1.25)
			img.set_pixel(x, y, c)
	# Cracks: short jagged dark lines.
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	for i in 5:
		var p := Vector2(rng.randf() * n, rng.randf() * n)
		var dir := Vector2.from_angle(rng.randf() * TAU)
		for s in 10:
			img.set_pixel(posmod(int(p.x), n), posmod(int(p.y), n), _rgb(base, 0.72))
			dir = dir.rotated(rng.randf_range(-0.6, 0.6))
			p += dir
	for i in 8:
		var at := Vector2i(rng.randi() % n, rng.randi() % n)
		img.set_pixel(at.x, at.y, Color(1, 1, 1))
	return img


static func _marble(base: Color, vein: Color, salt: int, block: int) -> Image:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var v := _fbm(x, y, n, salt)
			var s := absf(sin((x * 0.09 + y * 0.05 + v * 6.0)))
			var c := _rgb(base, 1.0 + (v - 0.5) * 0.08)
			if s < 0.06:
				c = vein
			elif s < 0.14:
				c = c.lerp(vein, 0.35)
			var lx := x % block
			var ly := y % block
			if lx == 0 or ly == 0:
				c = _rgb(base, 0.8)
			elif lx == 1 or ly == 1:
				c = _rgb(base, 1.08)
			img.set_pixel(x, y, c)
	return img


## Rounded cobbles packed in a grid (Voronoi-ish from jittered centres), dark gaps between them.
static func _cobbles(base: Color, gap: Color, cell: int, salt: int, moss: Color = Color(0, 0, 0, 0)) -> Image:
	var n := 64
	var cells := n / cell
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var best := 1e9
			var second := 1e9
			var best_id := Vector2i.ZERO
			var best_c := Vector2.ZERO
			var cx := x / cell
			var cy := y / cell
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var gx := cx + ox
					var gy := cy + oy
					var wx := posmod(gx, cells)
					var wy := posmod(gy, cells)
					var c := Vector2(gx + 0.25 + _hash(wx, wy, salt) * 0.5, gy + 0.25 + _hash(wx, wy, salt + 1) * 0.5) * cell
					var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
					if d < best:
						second = best
						best = d
						best_id = Vector2i(wx, wy)
						best_c = c
					elif d < second:
						second = d
			var edge := second - best
			var col: Color
			if edge < 1.6:
				col = gap
			else:
				var k := 1.0 + (_hash(best_id.x, best_id.y, salt + 2) - 0.5) * 0.25
				var rel := (Vector2(x, y) - best_c) / cell
				k *= 1.0 - rel.y * 0.35 - rel.x * 0.15 # lit from the top left
				if edge < 3.0:
					k *= 0.82
				col = _rgb(base, k)
				if moss.a > 0.0 and rel.y < -0.2 and _fbm(x, y, n, salt + 5) > 0.55:
					col = moss
			img.set_pixel(x, y, col)
	return img


static func _fill(id: String) -> Image:
	match id:
		"mossy_stone":
			return _cobbles(Color(0.6, 0.62, 0.66), Color(0.26, 0.27, 0.3), 16, 21, Color(0.42, 0.62, 0.26))
		"snow":
			var img := _earth(Color(0.86, 0.92, 1.0), 31, 0.1, 0.03, Color(0.74, 0.83, 0.97), Color(1, 1, 1), 10, Color(0.7, 0.8, 0.95), Vector2(1.5, 3.0))
			return img
		"ice_block":
			return _ice(Color(0.52, 0.82, 0.98), 41)
		"sand":
			return _earth(Color(0.96, 0.82, 0.52), 51, 0.12, 0.04, Color(0.82, 0.66, 0.38), Color(1.0, 0.94, 0.74), 9, Color(0.98, 0.9, 0.84), Vector2(1.2, 2.2))
		"driftwood":
			return _planks(Color(0.68, 0.46, 0.27), 61)
		"grave_soil":
			return _earth(Color(0.34, 0.28, 0.36), 71, 0.14, 0.05, Color(0.28, 0.23, 0.3), Color(0.42, 0.36, 0.42), 12, Color(0.56, 0.56, 0.6), Vector2(1.5, 3.0))
		"tomb_brick":
			return _bricks(Vector2i(64, 64), 32, 16, Color(0.5, 0.56, 0.56), 0.22, Color(0.2, 0.24, 0.25), 2, 81)
		"dune_sand":
			return _earth(Color(0.94, 0.66, 0.36), 91, 0.1, 0.07, Color(0.8, 0.52, 0.26), Color(1.0, 0.82, 0.55), 4, Color(0.8, 0.55, 0.32), Vector2(1.2, 2.0))
		"sandstone":
			return _bricks(Vector2i(64, 64), 32, 16, Color(0.9, 0.78, 0.55), 0.14, Color(0.6, 0.46, 0.3), 2, 101, 1.15, 0.8, 0.12)
		"sky_earth":
			return _earth(Color(0.66, 0.46, 0.3), 111, 0.12, 0.05, Color(0.56, 0.38, 0.25), Color(0.76, 0.56, 0.38), 16, Color(0.6, 0.58, 0.62))
		"marble":
			return _marble(Color(0.94, 0.95, 0.98), Color(0.7, 0.74, 0.86), 121, 32)
		"basalt":
			var img := _earth(Color(0.44, 0.25, 0.21), 131, 0.14, 0.05, Color(0.36, 0.2, 0.17), Color(0.52, 0.31, 0.25), 10, Color(0.34, 0.24, 0.24))
			var rng := RandomNumberGenerator.new()
			rng.seed = 132
			for i in 18: # ember specks
				var at := Vector2i(rng.randi() % FILL_SIZE, rng.randi() % FILL_SIZE)
				img.set_pixel(at.x, at.y, Color(1.0, 0.55, 0.15))
				img.set_pixel((at.x + 1) % FILL_SIZE, at.y, Color(0.85, 0.3, 0.08))
			return img
		"temple_gold":
			var img := _bricks(Vector2i(64, 64), 32, 32, Color(0.92, 0.66, 0.22), 0.1, Color(0.45, 0.22, 0.06), 2, 141, 1.2, 0.75, 0.06)
			for y in 64: # an engraved square in each block
				for x in 64:
					var lx := x % 32
					var ly := y % 32
					if (lx == 9 or lx == 23) and ly >= 9 and ly <= 23 or (ly == 9 or ly == 23) and lx >= 9 and lx <= 23:
						img.set_pixel(x, y, Color(0.62, 0.36, 0.08))
					elif (lx == 10 or ly == 10) and lx >= 10 and lx <= 22 and ly >= 10 and ly <= 22:
						img.set_pixel(x, y, Color(1.0, 0.86, 0.45))
			return img
		"gravel":
			return _earth(Color(0.52, 0.5, 0.47), 151, 0.1, 0.03, Color(0.45, 0.43, 0.41), Color(0.6, 0.58, 0.55), 26, Color(0.62, 0.6, 0.58), Vector2(1.4, 2.6))
		"steel_plate":
			return _plates(32, Color(0.56, 0.64, 0.7), Color(0.75, 0.8, 0.85), Color(0.22, 0.27, 0.32), 161, false)
		"asphalt":
			return _earth(Color(0.33, 0.34, 0.44), 171, 0.08, 0.02, Color(0.29, 0.3, 0.39), Color(0.38, 0.39, 0.5), 14, Color(0.44, 0.44, 0.54), Vector2(1.2, 2.2))
		"girder":
			return _plates(32, Color(0.48, 0.5, 0.66), Color(0.75, 0.78, 0.9), Color(0.14, 0.15, 0.26), 181, true)
		"rock_soil":
			return _earth(Color(0.56, 0.49, 0.41), 191, 0.12, 0.05, Color(0.47, 0.41, 0.34), Color(0.64, 0.57, 0.48), 18, Color(0.66, 0.66, 0.68), Vector2(1.8, 3.6))
		"stone_tile":
			var img := _bricks(Vector2i(64, 64), 32, 32, Color(0.82, 0.84, 0.86), 0.1, Color(0.5, 0.52, 0.56), 2, 201, 1.12, 0.82, 0.08)
			var rng := RandomNumberGenerator.new()
			rng.seed = 202
			for i in 4: # cracks
				var p := Vector2(rng.randf() * 64, rng.randf() * 64)
				var dir := Vector2.from_angle(rng.randf() * TAU)
				for s in 9:
					img.set_pixel(posmod(int(p.x), 64), posmod(int(p.y), 64), Color(0.5, 0.52, 0.56))
					dir = dir.rotated(rng.randf_range(-0.7, 0.7))
					p += dir
			return img
		"cave_rock":
			var img := _earth(Color(0.46, 0.4, 0.56), 211, 0.14, 0.06, Color(0.39, 0.34, 0.48), Color(0.53, 0.47, 0.63), 12, Color(0.56, 0.5, 0.66))
			var rng := RandomNumberGenerator.new()
			rng.seed = 212
			for i in 10: # crystal glints
				var at := Vector2i(rng.randi() % FILL_SIZE, rng.randi() % FILL_SIZE)
				var c := Color(0.55, 0.9, 1.0) if i % 2 == 0 else Color(0.85, 0.55, 1.0)
				img.set_pixel(at.x, at.y, c)
				img.set_pixel(at.x, (at.y + 1) % FILL_SIZE, _rgb(c, 0.7))
			return img
		"boulder":
			return _cobbles(Color(0.5, 0.48, 0.58), Color(0.12, 0.1, 0.16), 21, 221)
	return null


# ── Edges (cap + band) ──────────────────────────────────────────────────────

## Band thickness (rows from the surface) of column x: base ± a wave, tiling over w.
static func _thick(x: int, w: int, base: float, amp: float, phase: float = 1.0) -> float:
	var f := TAU * x / w
	return base + amp * sin(f * 2.0 + phase) + amp * 0.75 * sin(f * 5.0 + phase * 2.0)


## Paints the band of column x: `top` for the first `top_rows`, `mid`, `dark` the last 2 rows.
static func _band_col(img: Image, cap: int, x: int, thick: float, top: Color, mid: Color, dark: Color, top_rows: int = 2, speck: Color = Color(0, 0, 0, 0), salt: int = 0) -> void:
	var rows := img.get_height() - cap
	for d in range(1, rows + 1):
		if float(d) > thick:
			break
		var c := mid
		if d <= top_rows:
			c = top
		if float(d) > thick - 2.0:
			c = dark
		elif speck.a > 0.0 and _hash(x, d, salt) > 0.9:
			c = speck
		img.set_pixel(x, cap + d - 1, c)


## Blades in the cap rows: height 0..cap-1 per column, taller in clumps; `tip` on the tips.
static func _tufts(img: Image, cap: int, x: int, salt: int, blade: Color, tip: Color, density: float = 1.0) -> void:
	if _hash(x, 4, salt) > density:
		return
	var col := _hash(x, 7, salt)
	var h := int(floor(col * col * (cap - 1)))
	if _hash(int(x / 3.0), 11, salt) > 0.8:
		h = mini(h + 2, cap - 1)
	for d in range(1, h + 1):
		img.set_pixel(x, cap - d, tip if d == h else blade)


static func _edge(id: String) -> Image:
	var s := spec(id)
	var cap: int = s["cap"]
	var w := EDGE_WIDTH
	var img := _blank(w, cap + int(s["band"]))
	for x in w:
		match id:
			"mossy_stone":
				_tufts(img, cap, x, 21, Color(0.36, 0.6, 0.24), Color(0.55, 0.8, 0.32), 0.6)
				_band_col(img, cap, x, _thick(x, w, 4.0, 1.4), Color(0.55, 0.8, 0.32), Color(0.38, 0.62, 0.24), Color(0.26, 0.42, 0.18), 1)
			"snow", "ice_block":
				# Snow puffs: rounded bumps over the surface.
				var bump := (sin(TAU * x / w * 6.0) * 0.5 + 0.5) * (cap - 1) * (0.6 + 0.4 * sin(TAU * x / w * 2.0 + 1.0))
				for d in range(1, cap + 1):
					if float(d) <= bump:
						img.set_pixel(x, cap - d, Color(1, 1, 1) if float(d) > bump - 1.5 else Color(0.94, 0.97, 1.0))
				var thick := _thick(x, w, 9.0, 2.0) if id == "snow" else _thick(x, w, 3.6, 1.0)
				_band_col(img, cap, x, thick, Color(1, 1, 1), Color(0.95, 0.98, 1.0), Color(0.7, 0.82, 0.97), 3)
			"sand":
				_tufts(img, cap, x, 51, Color(0.52, 0.66, 0.26), Color(0.7, 0.8, 0.34), 0.22)
				_band_col(img, cap, x, _thick(x, w, 6.0, 1.5), Color(1.0, 0.95, 0.75), Color(0.99, 0.88, 0.6), Color(0.9, 0.74, 0.45), 2, Color(1, 1, 1), 52)
			"driftwood":
				_band_col(img, cap, x, 3.0, Color(0.9, 0.7, 0.45), Color(0.8, 0.58, 0.35), Color(0.8, 0.58, 0.35), 1)
			"grave_soil":
				var dead := _hash(x, 3, 71) > 0.82
				_tufts(img, cap, x, 71, Color(0.4, 0.38, 0.26) if dead else Color(0.2, 0.42, 0.34), Color(0.55, 0.5, 0.34) if dead else Color(0.3, 0.58, 0.44), 0.8)
				_band_col(img, cap, x, _thick(x, w, 6.0, 1.6), Color(0.3, 0.56, 0.42), Color(0.2, 0.42, 0.32), Color(0.13, 0.27, 0.22), 2, Color(0.34, 0.6, 0.46), 72)
			"tomb_brick":
				_tufts(img, cap, x, 81, Color(0.3, 0.5, 0.36), Color(0.42, 0.64, 0.44), 0.35)
				_band_col(img, cap, x, 3.0, Color(0.72, 0.78, 0.76), Color(0.62, 0.68, 0.66), Color(0.62, 0.68, 0.66), 1)
			"dune_sand":
				_band_col(img, cap, x, _thick(x, w, 5.0, 1.4), Color(1.0, 0.86, 0.6), Color(0.98, 0.76, 0.46), Color(0.88, 0.62, 0.34), 2)
			"sandstone":
				_band_col(img, cap, x, 3.0, Color(1.0, 0.92, 0.72), Color(0.95, 0.84, 0.62), Color(0.95, 0.84, 0.62), 1)
			"sky_earth":
				var flower := _hash(x, 5, 111) > 0.93
				_tufts(img, cap, x, 111, Color(0.4, 0.75, 0.3), Color(1.0, 0.85, 0.3) if flower else Color(0.62, 0.9, 0.38))
				if flower:
					img.set_pixel(x, cap - 1, Color(0.4, 0.75, 0.3))
					img.set_pixel(x, cap - 2, Color(1.0, 0.55, 0.7))
				_band_col(img, cap, x, _thick(x, w, 8.0, 2.0), Color(0.66, 0.92, 0.36), Color(0.44, 0.76, 0.28), Color(0.28, 0.52, 0.2), 2, Color(0.7, 0.95, 0.42), 112)
			"marble":
				_band_col(img, cap, x, 3.0, Color(1, 0.88, 0.5), Color(0.95, 0.75, 0.3), Color(0.95, 0.75, 0.3), 1)
			"basalt":
				var glow := _hash(x / 4, 2, 131) > 0.75
				_band_col(img, cap, x, _thick(x, w, 3.5, 1.0), Color(1.0, 0.55, 0.2) if glow else Color(0.5, 0.28, 0.22), Color(0.26, 0.14, 0.12), Color(0.2, 0.1, 0.1), 1)
			"temple_gold":
				_band_col(img, cap, x, 4.0, Color(1.0, 0.95, 0.6), Color(1.0, 0.82, 0.32), Color(0.75, 0.45, 0.1), 2)
			"gravel":
				_band_col(img, cap, x, 4.0, Color(0.78, 0.76, 0.7), Color(0.62, 0.6, 0.56), Color(0.4, 0.38, 0.36), 1)
			"steel_plate":
				var stripe := posmod(x, 16) < 8
				_band_col(img, cap, x, 4.0, Color(0.92, 0.95, 0.98), Color(0.95, 0.78, 0.2) if stripe else Color(0.2, 0.2, 0.22), Color(0.4, 0.45, 0.5), 1)
			"asphalt":
				_band_col(img, cap, x, 4.0, Color(0.7, 0.7, 0.78), Color(0.55, 0.55, 0.64), Color(0.36, 0.36, 0.46), 1)
			"girder":
				_band_col(img, cap, x, 3.0, Color(0.55, 1.0, 1.0), Color(0.25, 0.85, 0.95), Color(0.25, 0.85, 0.95), 1)
			"rock_soil":
				_tufts(img, cap, x, 191, Color(0.38, 0.62, 0.28), Color(0.55, 0.8, 0.34))
				_band_col(img, cap, x, _thick(x, w, 6.0, 1.8), Color(0.55, 0.8, 0.34), Color(0.38, 0.62, 0.26), Color(0.26, 0.42, 0.18), 2)
			"stone_tile":
				_tufts(img, cap, x, 201, Color(0.4, 0.62, 0.3), Color(0.56, 0.8, 0.38), 0.4)
				_band_col(img, cap, x, 3.0, Color(0.95, 0.96, 0.97), Color(0.88, 0.9, 0.92), Color(0.88, 0.9, 0.92), 1)
			"cave_rock":
				_band_col(img, cap, x, _thick(x, w, 3.0, 1.0), Color(0.7, 0.66, 0.82), Color(0.58, 0.53, 0.7), Color(0.4, 0.36, 0.5), 1)
			"boulder":
				_band_col(img, cap, x, 2.0, Color(0.68, 0.66, 0.76), Color(0.6, 0.58, 0.7), Color(0.6, 0.58, 0.7), 1)
	# Pebbles on cave rock: small stones sitting on the surface.
	if id == "cave_rock":
		var rng := RandomNumberGenerator.new()
		rng.seed = 213
		for i in 9:
			var x := rng.randi() % w
			var r := rng.randi_range(1, 2)
			for dx in range(-r, r + 1):
				for d in range(1, r + 1):
					img.set_pixel(posmod(x + dx, w), cap - d, Color(0.5, 0.46, 0.6) if d < r else Color(0.62, 0.58, 0.72))
	return img


# ── Hangs ───────────────────────────────────────────────────────────────────

static func _hang(id: String) -> Image:
	var rows: int = spec(id)["hang"]
	if rows <= HANG_NONE:
		return _blank(1, 1)
	var w := EDGE_WIDTH
	var img := _blank(w, rows)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match id:
		"snow", "ice_block":
			for i in 14: # icicles: tapering triangles
				var x := rng.randi() % w
				var half := rng.randi_range(1, 2)
				var length := rng.randi_range(3, rows)
				for d in length:
					var hw := int(round(half * (1.0 - float(d) / length)))
					for dx in range(-hw, hw + 1):
						var c := Color(0.82, 0.94, 1.0) if dx < 0 or hw == 0 else Color(0.6, 0.82, 0.98)
						img.set_pixel(posmod(x + dx, w), d, c)
				img.set_pixel(x, 0, Color(1, 1, 1))
		"grave_soil", "sky_earth":
			var col := Color(0.38, 0.27, 0.2) if id == "grave_soil" else Color(0.32, 0.62, 0.26)
			var leaf := Color(0.45, 0.32, 0.24) if id == "grave_soil" else Color(0.48, 0.82, 0.34)
			for i in 9: # roots / vines: wavy threads
				var x := float(rng.randi() % w)
				var length := rng.randi_range(4, rows)
				var ph := rng.randf() * TAU
				for d in length:
					var xx := posmod(int(round(x + sin(d * 0.7 + ph) * 1.2)), w)
					img.set_pixel(xx, d, col)
					if id == "sky_earth" and d % 3 == 2:
						img.set_pixel(posmod(xx + 1, w), d, leaf)
		"cave_rock":
			for i in 12: # stalactite drips
				var x := rng.randi() % w
				var half := rng.randi_range(1, 3)
				var length := rng.randi_range(3, rows)
				for d in length:
					var hw := int(round(half * (1.0 - float(d) / length)))
					for dx in range(-hw, hw + 1):
						img.set_pixel(posmod(x + dx, w), d, Color(0.42, 0.38, 0.52) if dx <= 0 else Color(0.3, 0.27, 0.38))
	return img
