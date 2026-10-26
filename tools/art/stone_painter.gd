extends RefCounted
## Code-drawn upgrade stones (bake source only): one icon per stone level 1..12 on a 128x128 canvas (baked 3 x: ui/art.gd STONE_ICON_SIZE), a cut
## gem with a dark rounded outline (like tools/art/icon_painter.gd) whose colour and cut escalate
## with the level: 1–3 a small hexagonal crystal (grey, grey-green, green), 4–6 an octagonal
## brilliant (light blue to deep blue), 7–9 a tall faceted crystal (violet to magenta), 10–12 a
## crown-cut jewel on a glow with sparkles (gold, orange, red with gold trim; 12 adds rays).
## Within a band each level is a little bigger and has one more sparkle. tools/bake_art.gd saves
## them as assets/icons/stones/stone_<level>.png (ui/art.gd stone_path()).

const OUTLINE := Color(0.07, 0.07, 0.14)
const W := 5.0
const GOLD := Color(1.0, 0.84, 0.3)
const C := Vector2(64, 66)

## Main colour per level (index = level).
const MAIN := [
	Color(0, 0, 0),
	Color(0.66, 0.69, 0.74), Color(0.55, 0.74, 0.62), Color(0.32, 0.84, 0.46),
	Color(0.48, 0.78, 1.0), Color(0.3, 0.58, 1.0), Color(0.22, 0.4, 0.95),
	Color(0.66, 0.46, 1.0), Color(0.72, 0.32, 0.95), Color(0.86, 0.3, 0.92),
	Color(1.0, 0.78, 0.2), Color(1.0, 0.52, 0.16), Color(0.95, 0.2, 0.2),
]


static func paint(ci: CanvasItem, level: int) -> void:
	level = clampi(level, 1, MAIN.size() - 1)
	var band := (level - 1) / 3 # 0..3
	var step := (level - 1) % 3 # 0..2 within the band
	var main: Color = MAIN[level]
	var pal := {"main": main, "light": main.lightened(0.5), "mid": main.lightened(0.2), "dark": main.darkened(0.42),
		"deep": main.darkened(0.6)}
	if band == 3:
		_glow(ci, main, 0.55 + 0.15 * step)
		if level == 12:
			_rays(ci, main.lightened(0.3))
	var scale := 0.82 + 0.09 * step + 0.05 * band
	match band:
		0: _hex_crystal(ci, pal, scale)
		1: _brilliant(ci, pal, scale)
		2: _tall_crystal(ci, pal, scale)
		_: _crown_jewel(ci, pal, scale, level == 12)
	# Sparkles: one per step, more on the top band.
	var spots := [Vector2(40, 36), Vector2(94, 52), Vector2(86, 100), Vector2(30, 92), Vector2(100, 28)]
	var n := step + 1 + (2 if band == 3 else (1 if band == 2 else 0))
	for i in mini(n, spots.size()):
		_sparkle(ci, spots[i], 9.0 - i * 1.0 + band)


# ── Cuts ────────────────────────────────────────────────────────────────────

static func _p(v: Vector2, scale: float) -> Vector2:
	return C + (v - C) * scale


static func _hex_crystal(ci: CanvasItem, pal: Dictionary, k: float) -> void:
	var top := _p(Vector2(64, 22), k)
	var tl := _p(Vector2(32, 42), k)
	var tr := _p(Vector2(96, 42), k)
	var bl := _p(Vector2(32, 88), k)
	var br := _p(Vector2(96, 88), k)
	var bot := _p(Vector2(64, 108), k)
	var mt := _p(Vector2(64, 50), k)
	var mb := _p(Vector2(64, 82), k)
	_poly(ci, [top, tr, br, bot, bl, tl], pal["main"])
	_fill(ci, [top, tr, mt, tl], pal["light"])
	_fill(ci, [tl, mt, mb, bl], pal["mid"])
	_fill(ci, [tr, br, mb, mt], pal["dark"])
	_fill(ci, [bl, mb, bot], pal["main"])
	_fill(ci, [mb, br, bot], pal["deep"])
	ci.draw_line(_p(Vector2(44, 46), k), _p(Vector2(58, 38), k), Color(1, 1, 1, 0.7), 3.0, true)


static func _brilliant(ci: CanvasItem, pal: Dictionary, k: float) -> void:
	var outer: Array = []
	var inner: Array = []
	for i in 8:
		var a := -PI / 2 + PI / 8 + i * PI / 4
		outer.append(_p(C + Vector2.from_angle(a) * 46, k))
		inner.append(_p(C + Vector2.from_angle(a) * 24, k))
	_poly(ci, outer, pal["main"])
	var shades := ["light", "light", "mid", "dark", "deep", "dark", "mid", "main"]
	for i in 8:
		var j := (i + 1) % 8
		_fill(ci, [outer[i], outer[j], inner[j], inner[i]], pal[shades[i]])
	_fill(ci, inner, pal["mid"])
	_fill(ci, [inner[6], inner[7], inner[0], C + (inner[0] - C) * 0.2], pal["light"])
	ci.draw_line(inner[6], inner[0], Color(1, 1, 1, 0.75), 3.0, true)


static func _tall_crystal(ci: CanvasItem, pal: Dictionary, k: float) -> void:
	var top := _p(Vector2(64, 12), k)
	var sl := _p(Vector2(36, 40), k)
	var sr := _p(Vector2(92, 40), k)
	var gl := _p(Vector2(36, 86), k)
	var gr := _p(Vector2(92, 86), k)
	var bot := _p(Vector2(64, 116), k)
	var m1 := _p(Vector2(56, 40), k)
	var m2 := _p(Vector2(72, 40), k)
	var n1 := _p(Vector2(56, 86), k)
	var n2 := _p(Vector2(72, 86), k)
	_poly(ci, [top, sr, gr, bot, gl, sl], pal["main"])
	_fill(ci, [top, m2, m1], pal["light"])
	_fill(ci, [top, m1, sl], pal["mid"])
	_fill(ci, [top, sr, m2], pal["dark"])
	_fill(ci, [sl, m1, n1, gl], pal["mid"])
	_fill(ci, [m1, m2, n2, n1], pal["light"].lerp(pal["main"], 0.4))
	_fill(ci, [m2, sr, gr, n2], pal["dark"])
	_fill(ci, [gl, n1, bot], pal["main"])
	_fill(ci, [n1, n2, bot], pal["mid"])
	_fill(ci, [n2, gr, bot], pal["deep"])
	ci.draw_line(_p(Vector2(60, 48), k), _p(Vector2(60, 78), k), Color(1, 1, 1, 0.6), 3.0, true)


static func _crown_jewel(ci: CanvasItem, pal: Dictionary, k: float, trim: bool) -> void:
	# A round-cut jewel: wide crown on top, pointed pavilion below, a gold girdle.
	var crown_l := _p(Vector2(22, 54), k)
	var crown_r := _p(Vector2(106, 54), k)
	var table_l := _p(Vector2(44, 30), k)
	var table_r := _p(Vector2(84, 30), k)
	var bot := _p(Vector2(64, 114), k)
	_poly(ci, [table_l, table_r, crown_r, bot, crown_l], pal["main"])
	var g := [_p(Vector2(22, 54), k), _p(Vector2(43, 54), k), _p(Vector2(64, 54), k), _p(Vector2(85, 54), k), _p(Vector2(106, 54), k)]
	var t := [table_l, _p(Vector2(54, 30), k), _p(Vector2(64, 30), k), _p(Vector2(74, 30), k), table_r]
	var crown_shades := ["mid", "light", "light", "mid"]
	for i in 4:
		_fill(ci, [t[i], t[i + 1], g[i + 1], g[i]], pal[crown_shades[i]])
	_fill(ci, [table_l, table_r, _p(Vector2(74, 40), k), _p(Vector2(54, 40), k)], pal["light"].lightened(0.3))
	var pav_shades := ["mid", "main", "dark", "deep"]
	for i in 4:
		_fill(ci, [g[i], g[i + 1], bot], pal[pav_shades[i]])
	var girdle: Color = GOLD if trim else (pal["light"] as Color).lerp(GOLD, 0.5)
	ci.draw_line(g[0], g[4], OUTLINE, 7.0, true)
	ci.draw_line(g[0], g[4], girdle, 3.5, true)
	if trim:
		for i in [1, 2, 3]:
			ci.draw_circle(g[i], 3.5, GOLD, true, -1.0, true)


# ── Effects ─────────────────────────────────────────────────────────────────

static func _glow(ci: CanvasItem, color: Color, strength: float) -> void:
	for i in 10:
		var r := 62.0 - i * 4.5
		ci.draw_circle(C, r, Color(color.lightened(0.2), strength * 0.06), true, -1.0, true)


static func _rays(ci: CanvasItem, color: Color) -> void:
	for i in 12:
		var a := i * TAU / 12
		var d := Vector2.from_angle(a)
		var side := Vector2(-d.y, d.x)
		ci.draw_colored_polygon(PackedVector2Array([C + d * 30 + side * 5, C + d * 63, C + d * 30 - side * 5]), Color(color, 0.45))


# ── Shapes ──────────────────────────────────────────────────────────────────

static func _poly(ci: CanvasItem, pts: Array, fill: Color, w: float = W) -> void:
	var packed := PackedVector2Array(pts)
	for o in Geometry2D.offset_polygon(packed, w, Geometry2D.JOIN_ROUND):
		ci.draw_colored_polygon(o, OUTLINE)
	ci.draw_colored_polygon(packed, fill)


static func _fill(ci: CanvasItem, pts: Array, fill: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), fill)


static func _sparkle(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(c + Vector2.from_angle(PI * i / 4) * (r if i % 2 == 0 else r * 0.28))
	ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.95))
