extends RefCounted
## Code-drawn terrain textures (bake source only), built pixel by pixel so they tile exactly:
## - dirt(): DIRT_SIZE, tileable both ways: the top-of-ground dirt colour with soft strata,
##   pebbles and grit (terrain.gdshader darkens it with depth and adds the crater rim);
## - grass_edge(): GRASS_WIDTH wide, tileable horizontally: GRASS_TUFT_ROWS rows of tufts (air,
##   bottom row just above the surface), then GRASS_BAND_ROWS rows of grass from the surface
##   down (light top, a darker underside, a wavy thickness); transparent = dirt / air.
## The colours are the ones terrain.gdshader used to compute.

const DIRT_SIZE := 128
const GRASS_WIDTH := 128
const GRASS_TUFT_ROWS := preload("res://ui/art.gd").GRASS_TUFT_ROWS
const GRASS_BAND_ROWS := 18

const GRASS_LIGHT := Color(0.55, 0.82, 0.32)
const GRASS := Color(0.36, 0.66, 0.24)
const GRASS_DARK := Color(0.22, 0.45, 0.17)
const DIRT := Color(0.62, 0.43, 0.25)


static func _hash(x: int, y: int, salt: int = 0) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h ^ (h >> 16)) / float(0x7fffffff)


static func dirt() -> Image:
	var n := DIRT_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var fx := TAU * x / n
			var fy := TAU * y / n
			var strata := sin(fy * 2.0 + sin(fx) * 1.6) * 0.05 + sin(fy * 5.0 + sin(fx * 2.0) * 0.8) * 0.025
			var c := DIRT * (1.0 + strata)
			var g := _hash(x >> 1, y >> 1)
			if g > 0.93:
				c = c * 0.8 # dark grit
			elif g < 0.05:
				c = c * 1.14 # light grit
			c.a = 1.0
			img.set_pixel(x, y, c)
	# Pebbles: small rounded dark stones with a light top, wrapped across the edges.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 14:
		var at := Vector2(rng.randf() * n, rng.randf() * n)
		var r := rng.randf_range(1.6, 3.4)
		var shade := rng.randf_range(0.62, 0.78)
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var d := Vector2(dx, dy)
				if d.length() > r:
					continue
				var px := posmod(int(at.x) + dx, n)
				var py := posmod(int(at.y) + dy, n)
				var base := DIRT * shade
				if dy < -r * 0.4:
					base = DIRT * (shade + 0.18)
				base.a = 1.0
				img.set_pixel(px, py, base)
	return img


## Grass band thickness (rows from the surface) of column x.
static func thickness(x: int) -> float:
	var f := TAU * x / GRASS_WIDTH
	return 7.0 + 2.0 * sin(f * 2.0) + 1.5 * sin(f * 5.0 + 1.0)


static func grass_edge() -> Image:
	var w := GRASS_WIDTH
	var h := GRASS_TUFT_ROWS + GRASS_BAND_ROWS
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in w:
		# Tufts: blade height 0..5 per column, taller in small clumps.
		var col := _hash(x, 7)
		var blade := int(floor(col * col * 5.0))
		if _hash(int(x / 3.0), 11) > 0.8:
			blade = mini(blade + 2, GRASS_TUFT_ROWS - 1)
		for d in range(1, blade + 1):
			var tip := d == blade
			img.set_pixel(x, GRASS_TUFT_ROWS - d, GRASS.lerp(GRASS_LIGHT, 0.7 if tip else 0.45))
		# Band.
		var thick := thickness(x)
		for d in range(1, GRASS_BAND_ROWS + 1):
			if float(d) > thick:
				break
			var c := GRASS
			if d <= 2:
				c = GRASS_LIGHT
			if float(d) > thick - 2.0:
				c = GRASS_DARK
			elif _hash(x, d, 3) > 0.9:
				c = GRASS.lerp(GRASS_LIGHT, 0.4) # a few lighter specks
			img.set_pixel(x, GRASS_TUFT_ROWS + d - 1, c)
	return img
