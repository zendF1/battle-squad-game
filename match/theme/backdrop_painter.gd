extends RefCounted
## The far background of each map theme (match/theme/map_themes.gd), drawn in code onto a
## CanvasItem once per match (match/views/sky_view.gd redraws it only when its size or theme
## changes): a sky gradient, a sun or moon glow and two or three silhouette layers (mountains,
## dunes and pyramids, a skyline, factories, stone pillars, a cave's rock). Coordinates are the
## map's (0..w, 0..h); it paints `margin` px past the left and right edges too. All shapes come
## from seeded noise, so every match of a theme shows the same picture.
## An artist's picture at assets/env/sky_<theme>.png replaces the code-drawn one (stretched over
## the same span, like grassland's sky_match.png).

static var _glow: GradientTexture2D


static func glow_texture() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	return _glow


static func paint(ci: CanvasItem, theme: String, w: float, h: float, margin: float) -> void:
	var x0 := -margin
	var x1 := w + margin
	match theme:
		"ice":
			_ice(ci, x0, x1, w, h)
		"beach":
			_beach(ci, x0, x1, w, h)
		"graveyard":
			_graveyard(ci, x0, x1, w, h)
		"desert":
			_desert(ci, x0, x1, w, h)
		"sky":
			_sky(ci, x0, x1, w, h)
		"temple":
			_temple(ci, x0, x1, w, h)
		"steel":
			_steel(ci, x0, x1, w, h)
		"city_night":
			_city(ci, x0, x1, w, h)
		"stone":
			_stone(ci, x0, x1, w, h)
		"cave":
			_cave(ci, x0, x1, w, h)


# ── Helpers ─────────────────────────────────────────────────────────────────

## Vertical gradient over [y0, y1]: stops [[t, colour], ...] (t 0..1, increasing).
static func _grad(ci: CanvasItem, x0: float, x1: float, y0: float, y1: float, stops: Array) -> void:
	for i in stops.size() - 1:
		var a: Array = stops[i]
		var b: Array = stops[i + 1]
		var ya := lerpf(y0, y1, a[0])
		var yb := lerpf(y0, y1, b[0])
		ci.draw_polygon(PackedVector2Array([Vector2(x0, ya), Vector2(x1, ya), Vector2(x1, yb), Vector2(x0, yb)]),
			PackedColorArray([a[1], a[1], b[1], b[1]]))


static func _glow_at(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(glow_texture(), Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


## A rolling ridge: base - amp × (two sines), closed down to `bottom`.
static func _ridge(ci: CanvasItem, x0: float, x1: float, bottom: float, base: float, amp: float, freq: float, phase: float, col: Color) -> void:
	var poly := PackedVector2Array()
	var steps := 96
	for i in steps + 1:
		var x := lerpf(x0, x1, float(i) / steps)
		poly.append(Vector2(x, base - amp * (sin(x * freq + phase) * 0.7 + sin(x * freq * 2.7 + phase * 2.0) * 0.3)))
	poly.append(Vector2(x1, bottom))
	poly.append(Vector2(x0, bottom))
	ci.draw_colored_polygon(poly, col)


## Jagged mountains: peaks of random width and height along the base, closed to `bottom`;
## `cap` (alpha > 0) paints a snow cap on the top part of each peak.
static func _peaks(ci: CanvasItem, x0: float, x1: float, bottom: float, base: float, height: float, seed_: int,
		col: Color, cap: Color = Color(0, 0, 0, 0), shade: Color = Color(0, 0, 0, 0)) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var x := x0 - 80.0
	var pts := PackedVector2Array([Vector2(x, base)])
	var tops: Array = []
	while x < x1 + 80.0:
		var half := rng.randf_range(70.0, 170.0)
		var top := Vector2(x + half, base - height * rng.randf_range(0.45, 1.0))
		pts.append(Vector2(x + half * 0.5, lerpf(base, top.y, rng.randf_range(0.35, 0.6)))) # a shoulder
		pts.append(top)
		x += half * 2.0
		pts.append(Vector2(x - half * 0.4, lerpf(base, top.y, rng.randf_range(0.3, 0.55))))
		pts.append(Vector2(x, base - height * rng.randf_range(0.05, 0.25)))
		tops.append([top, half])
	pts.append(Vector2(x, bottom))
	pts.append(Vector2(x0 - 80.0, bottom))
	ci.draw_colored_polygon(pts, col)
	for t in tops:
		var top: Vector2 = t[0]
		var half: float = t[1]
		if shade.a > 0.0: # the shaded right face
			ci.draw_colored_polygon(PackedVector2Array([top, Vector2(top.x + half * 0.9, base), Vector2(top.x + half * 0.15, base)]), shade)
		if cap.a > 0.0:
			var k := 0.28
			var drop := (base - top.y) * k
			ci.draw_colored_polygon(PackedVector2Array([top, Vector2(top.x + half * k * 0.9, top.y + drop),
				Vector2(top.x + half * k * 0.35, top.y + drop * 0.75), Vector2(top.x, top.y + drop * 1.05),
				Vector2(top.x - half * k * 0.4, top.y + drop * 0.7), Vector2(top.x - half * k * 0.85, top.y + drop)]), cap)


static func _cloud_bank(ci: CanvasItem, x0: float, x1: float, y: float, r: float, seed_: int, col: Color, below: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var x := x0
	while x < x1 + r:
		var rr := r * rng.randf_range(0.6, 1.2)
		ci.draw_circle(Vector2(x, y + rng.randf_range(-r * 0.3, r * 0.3)), rr, col, true, -1.0, true)
		x += rr * 1.1
	ci.draw_rect(Rect2(x0, y, x1 - x0, below - y), col)


# ── Themes ──────────────────────────────────────────────────────────────────

static func _ice(ci: CanvasItem, x0: float, x1: float, w: float, h: float) -> void:
	_grad(ci, x0, x1, 0, h, [[0.0, Color(0.27, 0.5, 0.85)], [0.55, Color(0.66, 0.83, 0.98)], [1.0, Color(0.85, 0.93, 1.0)]])
	_glow_at(ci, Vector2(w * 0.2, h * 0.14), 260, Color(1, 1, 1, 0.45))
	_peaks(ci, x0, x1, h, h * 0.62, h * 0.32, 3, Color(0.68, 0.78, 0.93), Color(0.96, 0.98, 1.0), Color(0.6, 0.7, 0.88))
	_grad(ci, x0, x1, h * 0.5, h * 0.66, [[0.0, Color(1, 1, 1, 0)], [1.0, Color(0.92, 0.96, 1.0, 0.7)]])
	_peaks(ci, x0, x1, h, h * 0.78, h * 0.24, 7, Color(0.5, 0.63, 0.86), Color(0.92, 0.96, 1.0), Color(0.43, 0.55, 0.8))
	_grad(ci, x0, x1, h * 0.7, h, [[0.0, Color(0.85, 0.92, 1.0, 0)], [1.0, Color(0.8, 0.9, 1.0, 0.8)]])


static func _palm(ci: CanvasItem, foot: Vector2, s: float, col: Color) -> void:
	var top := foot + Vector2(10, -46) * s
	var trunk := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		trunk.append(foot.lerp(top, t) + Vector2(sin(t * PI) * 6.0 * s, 0))
	ci.draw_polyline(trunk, col, 3.0 * s, true)
	for a in [-2.6, -2.0, -1.3, -0.6, 0.1]:
		var tip := top + Vector2.from_angle(a) * 24.0 * s
		var mid := top.lerp(tip, 0.5) + Vector2(0, -6 * s)
		ci.draw_polyline(PackedVector2Array([top, mid, tip + Vector2(0, 6 * s)]), col, 3.2 * s, true)


static func _beach(ci: CanvasItem, x0: float, x1: float, w: float, h: float) -> void:
	var horizon := h * 0.72
	_grad(ci, x0, x1, 0, horizon, [[0.0, Color(0.25, 0.68, 0.95)], [0.7, Color(0.6, 0.88, 0.98)], [1.0, Color(0.88, 0.97, 0.98)]])
	_glow_at(ci, Vector2(w * 0.82, h * 0.12), 240, Color(1, 1, 0.9, 0.6))
	ci.draw_circle(Vector2(w * 0.82, h * 0.12), 34, Color(1, 1, 0.92, 0.95), true, -1.0, true)
	# Distant islands with palms on the horizon.
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var x := x0 + 60.0
	while x < x1:
		var half := rng.randf_range(50, 110)
		var hump := PackedVector2Array()
		for i in 17:
			var t := i / 16.0
			hump.append(Vector2(x - half + t * half * 2.0, horizon - sin(t * PI) * half * 0.2))
		ci.draw_colored_polygon(hump, Color(0.48, 0.76, 0.66))
		for p in rng.randi_range(1, 3):
			_palm(ci, Vector2(x + rng.randf_range(-half * 0.5, half * 0.5), horizon - half * 0.12), rng.randf_range(0.5, 0.75), Color(0.38, 0.64, 0.56))
		x += half * 2.0 + rng.randf_range(160, 420)
	_grad(ci, x0, x1, horizon, h, [[0.0, Color(0.36, 0.82, 0.88)], [1.0, Color(0.12, 0.58, 0.78)]])
	for i in 90: # glints on the sea
		var gx := rng.randf_range(x0, x1)
		var gy := rng.randf_range(horizon + 6, h)
		var seg := lerpf(6.0, 26.0, (gy - horizon) / (h - horizon))
		ci.draw_line(Vector2(gx, gy), Vector2(gx + seg, gy), Color(1, 1, 1, 0.45), 2.0)


static func _dead_tree(ci: CanvasItem, at: Vector2, seg: float, angle: float, width: float, depth: int, rng: RandomNumberGenerator, col: Color) -> void:
	var end := at + Vector2.from_angle(angle) * seg
	ci.draw_line(at, end, col, width, true)
	if depth <= 0:
		return
	for k in 2:
		var a := angle + (rng.randf_range(0.3, 0.75) * (1 if k == 0 else -1))
		_dead_tree(ci, end, seg * rng.randf_range(0.55, 0.75), a, maxf(1.0, width * 0.65), depth - 1, rng, col)


static func _graveyard(ci: CanvasItem, x0: float, x1: float, w: float, h: float) -> void:
	_grad(ci, x0, x1, 0, h, [[0.0, Color(0.03, 0.08, 0.11)], [0.6, Color(0.1, 0.27, 0.28)], [1.0, Color(0.14, 0.32, 0.29)]])
	var moon := Vector2(w * 0.78, h * 0.17)
	_glow_at(ci, moon, 200, Color(0.8, 1.0, 0.9, 0.35))
	ci.draw_circle(moon, 52, Color(0.94, 0.96, 0.84), true, -1.0, true)
	for c in [[Vector2(-14, -10), 9.0], [Vector2(16, 8), 12.0], [Vector2(-4, 20), 6.0]]:
		ci.draw_circle(moon + c[0], c[1], Color(0.84, 0.88, 0.74), true, -1.0, true)
	_ridge(ci, x0, x1, h, h * 0.6, h * 0.06, 0.004, 0.7, Color(0.08, 0.2, 0.21))
	# A crooked old house on the far hill.
	var hx := w * 0.3
	var hy := h * 0.6 - 10
	var house := Color(0.06, 0.14, 0.16)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(hx - 70, hy), Vector2(hx - 70, hy - 70), Vector2(hx - 80, hy - 70), Vector2(hx - 30, hy - 120),
		Vector2(hx + 20, hy - 72), Vector2(hx + 20, hy - 130), Vector2(hx + 4, hy - 130), Vector2(hx + 30, hy - 175), Vector2(hx + 56, hy - 130),
		Vector2(hx + 42, hy - 130), Vector2(hx + 42, hy - 60), Vector2(hx + 70, hy - 60), Vector2(hx + 70, hy)]), house)
	for win in [Vector2(hx - 50, hy - 55), Vector2(hx - 22, hy - 55), Vector2(hx + 24, hy - 112)]:
		ci.draw_rect(Rect2(win, Vector2(12, 16)), Color(1.0, 0.85, 0.35, 0.85))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var tree := Color(0.04, 0.1, 0.11)
	for i in 7:
		var tx := lerpf(x0, x1, (i + rng.randf_range(0.2, 0.8)) / 7.0)
		_dead_tree(ci, Vector2(tx, h * 0.74), rng.randf_range(50, 80), -PI / 2 + rng.randf_range(-0.15, 0.15), 9.0, 4, rng, tree)
	_ridge(ci, x0, x1, h, h * 0.76, h * 0.035, 0.007, 2.1, Color(0.05, 0.13, 0.13))
	var stone := Color(0.05, 0.11, 0.12)
	var x := x0
	while x < x1: # tombstones and crosses on the near hill
		var y := h * 0.76 - h * 0.035 * (sin(x * 0.007 + 2.1) * 0.7 + sin(x * 0.007 * 2.7 + 4.2) * 0.3) + 4
		if rng.randf() < 0.5:
			ci.draw_rect(Rect2(x - 9, y - 26, 18, 26), stone)
			ci.draw_circle(Vector2(x, y - 26), 9, stone, true, -1.0, true)
		else:
			ci.draw_rect(Rect2(x - 2.5, y - 34, 5, 34), stone)
			ci.draw_rect(Rect2(x - 11, y - 26, 22, 5), stone)
		x += rng.randf_range(50, 130)
	_grad(ci, x0, x1, h * 0.7, h, [[0.0, Color(0.5, 0.9, 0.75, 0)], [1.0, Color(0.4, 0.75, 0.65, 0.35)]])


static func _desert(ci: CanvasItem, x0: float, x1: float, w: float, h: float) -> void:
	_grad(ci, x0, x1, 0, h, [[0.0, Color(0.96, 0.56, 0.32)], [0.5, Color(1.0, 0.8, 0.5)], [1.0, Color(1.0, 0.9, 0.68)]])
	var sun := Vector2(w * 0.68, h * 0.4)
	_glow_at(ci, sun, 320, Color(1, 0.95, 0.7, 0.55))
	ci.draw_circle(sun, 64, Color(1, 0.95, 0.75, 0.9), true, -1.0, true)
	# Pyramids: a lit and a shaded face.
	for p in [[w * 0.18, 230.0], [w * 0.36, 150.0], [w * 0.86, 190.0], [w * 1.25, 120.0], [-w * 0.15, 140.0]]:
		var cx: float = p[0]
		var ph: float = p[1]
		var base := h * 0.66
		var top := Vector2(cx, base - ph)
		ci.draw_colored_polygon(PackedVector2Array([top, Vector2(cx - ph * 1.1, base), Vector2(cx, base)]), Color(0.93, 0.66, 0.4))
		ci.draw_colored_polygon(PackedVector2Array([top, Vector2(cx, base), Vector2(cx + ph * 1.1, base)]), Color(0.78, 0.5, 0.3))
	_ridge(ci, x0, x1, h, h * 0.68, h * 0.04, 0.003, 0.3, Color(0.95, 0.7, 0.42))
	_ridge(ci, x0, x1, h, h * 0.8, h * 0.05, 0.005, 1.9, Color(0.88, 0.6, 0.34))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var cactus := Color(0.55, 0.5, 0.25)
	for i in 6:
		var cx := lerpf(x0, x1, (i + rng.randf()) / 6.0)
		var cy := h * 0.8 - h * 0.05 * (sin(cx * 0.005 + 1.9) * 0.7 + sin(cx * 0.005 * 2.7 + 3.8) * 0.3) + 6
		var ch := rng.randf_range(30, 52)
		ci.draw_line(Vector2(cx, cy), Vector2(cx, cy - ch), cactus, 8.0, true)
		ci.draw_polyline(PackedVector2Array([Vector2(cx, cy - ch * 0.45), Vector2(cx - 12, cy - ch * 0.45), Vector2(cx - 12, cy - ch * 0.75)]), cactus, 6.0, true)
		ci.draw_polyline(PackedVector2Array([Vector2(cx, cy - ch * 0.6), Vector2(cx + 11, cy - ch * 0.6), Vector2(cx + 11, cy - ch * 0.9)]), cactus, 6.0, true)


static func _sky(ci: CanvasItem, x0: float, x1: float, w: float, h: float) -> void:
	_grad(ci, x0, x1, 0, h, [[0.0, Color(0.36, 0.66, 0.98)], [0.45, Color(0.72, 0.88, 1.0)], [0.72, Color(1.0, 0.95, 0.78)], [1.0, Color(0.98, 0.9, 0.72)]])
	_glow_at(ci, Vector2(w * 0.5, h * 0.7), 420, Color(1, 0.95, 0.75, 0.5))
	# Far floating islands: a grassy top over a tapering rock.
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 7:
		var cx := lerpf(x0, x1, (i + rng.randf_range(0.2, 0.8)) / 7.0)
		var cy := h * rng.randf_range(0.3, 0.6)
		var half := rng.randf_range(40, 90)
		var depth := half * rng.randf_range(0.55, 0.8)
		var rock := Color(0.7, 0.75, 0.92)
		var under := PackedVector2Array()
		var steps := 14
		for k in steps + 1:
			var t := float(k) / steps
			var d := pow(sin(t * PI), 0.45) * depth * (0.85 + 0.15 * sin(t * 23.0 + i))
			under.append(Vector2(cx - half + t * half * 2.0, cy + d))
		ci.draw_colored_polygon(under, rock)
		var low := PackedVector2Array([Vector2(cx - half * 0.7, cy + depth * 0.25)]) # the lower part a shade darker
		for k in range(3, steps - 2):
			low.append(under[k])
		low.append(Vector2(cx + half * 0.7, cy + depth * 0.25))
		ci.draw_colored_polygon(low, Color(0.62, 0.66, 0.86))
		var top := PackedVector2Array()
		for k in steps + 1:
			var t := float(k) / steps
			top.append(Vector2(cx - half - 4 + t * (half * 2.0 + 8), cy - 3 - sin(t * PI) * 6))
		for k in range(steps, -1, -1):
			var t := float(k) / steps
			top.append(Vector2(cx - half - 4 + t * (half * 2.0 + 8), cy + 5 + sin(t * 11.0 + i) * 1.5))
		ci.draw_colored_polygon(top, Color(0.6, 0.86, 0.66))
	_cloud_bank(ci, x0, x1, h * 0.74, 46, 43, Color(1, 1, 1, 0.75), h)
	_cloud_bank(ci, x0, x1, h * 0.8, 38, 44, Color(1, 0.98, 0.94), h)


static func _temple(ci: CanvasItem, x0: float, x1: float, w: float, h: float) -> void:
	_grad(ci, x0, x1, 0, h, [[0.0, Color(0.22, 0.04, 0.06)], [0.45, Color(0.62, 0.14, 0.07)], [0.78, Color(0.98, 0.45, 0.12)], [1.0, Color(1.0, 0.68, 0.24)]])
	# Volcanoes with lava runs.
	for v in [[w * 0.25, 300.0], [w * 0.8, 360.0], [w * 1.3, 240.0], [-w * 0.2, 260.0]]:
		var cx: float = v[0]
		var vh: float = v[1]
		var base := h * 0.74
		var top := base - vh
		ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - vh * 1.4, base), Vector2(cx - 34, top), Vector2(cx + 34, top), Vector2(cx + vh * 1.4, base)]), Color(0.24, 0.07, 0.07))
		_glow_at(ci, Vector2(cx, top), 90, Color(1, 0.55, 0.15, 0.7))
		for k in [-1.0, 0.4, 1.0]:
			ci.draw_polyline(PackedVector2Array([Vector2(cx + k * 20, top + 4), Vector2(cx + k * 40, top + vh * 0.35), Vector2(cx + k * 70, top + vh * 0.6)]), Color(1, 0.5, 0.12, 0.85), 4.0, true)
	_ridge(ci, x0, x1, h, h * 0.76, h * 0.03, 0.004, 1.2, Color(0.3, 0.08, 0.07))
	# Temples: a stepped base, pillars, a roof.
	var col := Color(0.36, 0.1, 0.07)
	for t in [w * 0.12, w * 0.55, w * 0.95]:
		var base := h * 0.77
		ci.draw_rect(Rect2(t - 90, base - 16, 180, 16), col)
		ci.draw_rect(Rect2(t - 74, base - 28, 148, 12), col)
		for k in 5:
			ci.draw_rect(Rect2(t - 62 + k * 28, base - 96, 12, 68), col)
		ci.draw_rect(Rect2(t - 76, base - 106, 152, 12), col)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(t - 82, base - 106), Vector2(t, base - 140), Vector2(t + 82, base - 106)]), col)
	_grad(ci, x0, x1, h * 0.75, h, [[0.0, Color(1, 0.6, 0.2, 0)], [1.0, Color(1, 0.55, 0.15, 0.5)]])


static func _factory(ci: CanvasItem, x0: float, x1: float, base: float, seed_: int, col: Color, smoke: Color, scale: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var x := x0
	while x < x1:
		var bw := rng.randf_range(80, 180) * scale
		var bh := rng.randf_range(50, 130) * scale
		ci.draw_rect(Rect2(x, base - bh, bw, bh), col)
		if rng.randf() < 0.5: # saw-tooth roof
			var n := 3
			for k in n:
				var sx := x + bw * k / n
				ci.draw_colored_polygon(PackedVector2Array([Vector2(sx, base - bh), Vector2(sx + bw / n, base - bh), Vector2(sx + bw / n, base - bh - 18 * scale)]), col)
		if rng.randf() < 0.6: # a chimney and its smoke
			var cx := x + bw * rng.randf_range(0.2, 0.8)
			var ch := rng.randf_range(60, 120) * scale
			ci.draw_rect(Rect2(cx - 7 * scale, base - bh - ch, 14 * scale, ch), col)
			for k in 4:
				ci.draw_circle(Vector2(cx + k * 14 * scale, base - bh - ch - 14 * scale - k * 16 * scale), (10 + k * 5) * scale, smoke, true, -1.0, true)
		if rng.randf() < 0.25: # a crane
			var cx := x + bw * 0.5
			ci.draw_line(Vector2(cx, base - bh), Vector2(cx, base - bh - 120 * scale), col, 5 * scale)
			ci.draw_line(Vector2(cx - 30 * scale, base - bh - 112 * scale), Vector2(cx + 110 * scale, base - bh - 112 * scale), col, 5 * scale)
			ci.draw_line(Vector2(cx + 90 * scale, base - bh - 112 * scale), Vector2(cx + 90 * scale, base - bh - 70 * scale), col, 2 * scale)
		x += bw + rng.randf_range(0, 50) * scale


static func _steel(ci: CanvasItem, x0: float, x1: float, w: float, h: float) -> void:
	_grad(ci, x0, x1, 0, h, [[0.0, Color(0.36, 0.56, 0.6)], [0.6, Color(0.64, 0.8, 0.78)], [1.0, Color(0.74, 0.86, 0.82)]])
	_glow_at(ci, Vector2(w * 0.3, h * 0.2), 260, Color(1, 1, 0.92, 0.35))
	_factory(ci, x0, x1, h * 0.7, 51, Color(0.5, 0.65, 0.66), Color(0.8, 0.88, 0.86, 0.5), 1.0)
	_grad(ci, x0, x1, h * 0.55, h * 0.72, [[0.0, Color(0.7, 0.84, 0.82, 0)], [1.0, Color(0.7, 0.84, 0.82, 0.6)]])
	_factory(ci, x0, x1, h * 0.84, 53, Color(0.36, 0.5, 0.52), Color(0.7, 0.8, 0.8, 0.45), 1.25)
	ci.draw_rect(Rect2(x0, h * 0.84, x1 - x0, h * 0.16), Color(0.32, 0.45, 0.47))
	for k in int((x1 - x0) / 40.0): # a fence along the quay
		var fx := x0 + k * 40.0
		ci.draw_line(Vector2(fx, h * 0.84), Vector2(fx, h * 0.84 - 22), Color(0.28, 0.4, 0.42), 3.0)
	ci.draw_line(Vector2(x0, h * 0.84 - 18), Vector2(x1, h * 0.84 - 18), Color(0.28, 0.4, 0.42), 3.0)


static func _skyline(ci: CanvasItem, x0: float, x1: float, base: float, seed_: int, col: Color, hmin: float, hmax: float, lit: Array, lit_share: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var x := x0
	while x < x1:
		var bw := rng.randf_range(40, 110)
		var bh := rng.randf_range(hmin, hmax)
		ci.draw_rect(Rect2(x, base - bh, bw, bh), col)
		var roof := rng.randf()
		if roof < 0.3: # an antenna with a red light
			ci.draw_line(Vector2(x + bw / 2, base - bh), Vector2(x + bw / 2, base - bh - 40), col, 3.0)
			ci.draw_circle(Vector2(x + bw / 2, base - bh - 40), 3.0, Color(1, 0.3, 0.35), true, -1.0, true)
		elif roof < 0.5: # a stepped top
			ci.draw_rect(Rect2(x + bw * 0.2, base - bh - 24, bw * 0.6, 24), col)
		if not lit.is_empty():
			var wc: Color = lit[rng.randi() % lit.size()]
			var yy := base - bh + 10
			while yy < base - 8:
				var xx := x + 6
				while xx < x + bw - 8:
					if rng.randf() < lit_share:
						ci.draw_rect(Rect2(xx, yy, 5, 7), wc)
					xx += 10
				yy += 13
		x += bw + rng.randf_range(2, 18)


static func _city(ci: CanvasItem, x0: float, x1: float, w: float, h: float) -> void:
	_grad(ci, x0, x1, 0, h, [[0.0, Color(0.02, 0.02, 0.12)], [0.5, Color(0.1, 0.05, 0.28)], [0.8, Color(0.36, 0.1, 0.46)], [1.0, Color(0.16, 0.06, 0.26)]])
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	for i in 160: # stars (sky_fx twinkles a few more)
		var s := Vector2(rng.randf_range(x0, x1), rng.randf_range(0, h * 0.5))
		ci.draw_rect(Rect2(s, Vector2.ONE * rng.randf_range(1.0, 2.2)), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
	_glow_at(ci, Vector2(w * 0.15, h * 0.14), 140, Color(0.9, 0.85, 1.0, 0.35))
	ci.draw_circle(Vector2(w * 0.15, h * 0.14), 30, Color(0.95, 0.93, 1.0), true, -1.0, true)
	_skyline(ci, x0, x1, h * 0.84, 63, Color(0.16, 0.08, 0.32), 140, 330, [Color(0.7, 0.4, 1.0, 0.5)], 0.12)
	_grad(ci, x0, x1, h * 0.6, h * 0.86, [[0.0, Color(1, 0.3, 0.8, 0)], [1.0, Color(1, 0.3, 0.8, 0.35)]])
	_skyline(ci, x0, x1, h * 0.9, 67, Color(0.05, 0.03, 0.14), 70, 220,
		[Color(1, 0.45, 0.85), Color(0.35, 0.95, 1.0), Color(1, 0.85, 0.4)], 0.32)
	ci.draw_rect(Rect2(x0, h * 0.9, x1 - x0, h * 0.1), Color(0.04, 0.02, 0.1))


static func _pillar(ci: CanvasItem, cx: float, base: float, pw: float, ph: float, col: Color, top: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(cx - pw * 0.6, base))
	pts.append(Vector2(cx - pw * 0.5, base - ph * 0.6))
	pts.append(Vector2(cx - pw * 0.42, base - ph))
	pts.append(Vector2(cx + pw * 0.38, base - ph))
	pts.append(Vector2(cx + pw * 0.5, base - ph * 0.55))
	pts.append(Vector2(cx + pw * 0.62, base))
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(Vector2(cx - pw * 0.15, base - ph), pw * 0.34, top, true, -1.0, true)
	ci.draw_circle(Vector2(cx + pw * 0.18, base - ph + 2), pw * 0.28, top, true, -1.0, true)


static func _stone(ci: CanvasItem, x0: float, x1: float, w: float, h: float) -> void:
	_grad(ci, x0, x1, 0, h, [[0.0, Color(0.6, 0.8, 0.95)], [0.55, Color(0.98, 0.95, 0.8)], [1.0, Color(0.94, 0.9, 0.74)]])
	_glow_at(ci, Vector2(w * 0.6, h * 0.5), 360, Color(1, 0.98, 0.85, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var x := x0
	while x < x1:
		_pillar(ci, x, h * 0.72, rng.randf_range(30, 60), rng.randf_range(120, 280), Color(0.74, 0.76, 0.72), Color(0.64, 0.78, 0.6))
		x += rng.randf_range(40, 110)
	_grad(ci, x0, x1, h * 0.45, h * 0.74, [[0.0, Color(0.98, 0.96, 0.85, 0)], [1.0, Color(0.98, 0.96, 0.85, 0.65)]])
	x = x0
	while x < x1:
		_pillar(ci, x, h * 0.86, rng.randf_range(50, 90), rng.randf_range(110, 260), Color(0.56, 0.6, 0.56), Color(0.42, 0.62, 0.38))
		x += rng.randf_range(110, 240)
	_ridge(ci, x0, x1, h, h * 0.86, h * 0.02, 0.006, 0.4, Color(0.48, 0.55, 0.46))


static func _crystal(ci: CanvasItem, at: Vector2, s: float, col: Color, rng: RandomNumberGenerator) -> void:
	_glow_at(ci, at + Vector2(0, -s * 14), s * 46, Color(col, 0.35))
	for k in 3:
		var a := -PI / 2 + (k - 1) * 0.45 + rng.randf_range(-0.1, 0.1)
		var seg := s * rng.randf_range(16, 30)
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * s * 4.5
		var tip := at + dir * seg
		ci.draw_colored_polygon(PackedVector2Array([at - side, at + side, tip + side * 0.6 - dir * s * 4, tip, tip - side * 0.6 - dir * s * 4]), col)
		ci.draw_colored_polygon(PackedVector2Array([at, at + side, tip + side * 0.6 - dir * s * 4, tip]), Color(col.lightened(0.35), 1.0))


static func _cave(ci: CanvasItem, x0: float, x1: float, w: float, h: float) -> void:
	_grad(ci, x0, x1, 0, h, [[0.0, Color(0.06, 0.04, 0.09)], [0.45, Color(0.18, 0.12, 0.24)], [1.0, Color(0.08, 0.05, 0.12)]])
	# Light shafts from cracks in the roof.
	for s in [w * 0.22, w * 0.6, w * 0.9]:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(s - 20, 0), Vector2(s + 24, 0), Vector2(s + 140, h * 0.8), Vector2(s + 10, h * 0.8)]), Color(0.7, 0.6, 1.0, 0.07))
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	# Back walls: a rock ridge rising from the floor, another hanging from the roof.
	_ridge(ci, x0, x1, h, h * 0.7, h * 0.08, 0.005, 0.9, Color(0.13, 0.09, 0.18))
	var roof := PackedVector2Array([Vector2(x0, 0)])
	for i in 97:
		var x := lerpf(x0, x1, i / 96.0)
		roof.append(Vector2(x, h * 0.1 + h * 0.05 * sin(x * 0.006 + 2.0) + h * 0.03 * sin(x * 0.017)))
	roof.append(Vector2(x1, 0))
	ci.draw_colored_polygon(roof, Color(0.1, 0.07, 0.14))
	var x := x0
	while x < x1: # stalactites from the roof
		var sw := rng.randf_range(14, 40)
		var sl := rng.randf_range(40, 150)
		var top := h * 0.1 + h * 0.05 * sin(x * 0.006 + 2.0) + h * 0.03 * sin(x * 0.017) - 4
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - sw / 2, top), Vector2(x + sw / 2, top), Vector2(x + sw * 0.1, top + sl), Vector2(x - sw * 0.05, top + sl)]), Color(0.1, 0.07, 0.14))
		x += rng.randf_range(30, 90)
	for i in 6:
		var cx := lerpf(x0, x1, (i + rng.randf_range(0.2, 0.8)) / 6.0)
		var cy := h * 0.7 - h * 0.08 * (sin(cx * 0.005 + 0.9) * 0.7 + sin(cx * 0.005 * 2.7 + 1.8) * 0.3) + 6
		_crystal(ci, Vector2(cx, cy), rng.randf_range(0.8, 1.3), Color(0.45, 0.85, 1.0) if i % 2 == 0 else Color(0.75, 0.45, 1.0), rng)
	_ridge(ci, x0, x1, h, h * 0.84, h * 0.04, 0.009, 2.7, Color(0.08, 0.05, 0.11))
