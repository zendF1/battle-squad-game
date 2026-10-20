extends RefCounted
## Code-drawn icons (bake source only), one per ui/art.gd ICONS name, on a 96x96 transparent
## canvas: bright shapes with a dark rounded outline so they read on any panel or coloured
## button. tools/bake_art.gd saves them as assets/icons/<name>.png.

const OUTLINE := Color(0.07, 0.07, 0.14)
const W := 5.0 # outline width
const WHITE := Color(0.98, 0.98, 1.0)
const GOLD := Color(1.0, 0.8, 0.22)
const GOLD_DARK := Color(0.85, 0.5, 0.1)

static var _boxes := {}


static func paint(ci: CanvasItem, icon_name: String) -> void:
	match icon_name:
		"gem": _gem(ci)
		"coin": _coin(ci)
		"plus": _plus(ci)
		"weapon": _bomb(ci, Color(0.17, 0.18, 0.24), false)
		"skill": _skill(ci)
		"battle": _battle(ci)
		"characters": _characters(ci)
		"inventory": _inventory(ci)
		"history": _history(ci)
		"shop": _shop(ci)
		"upgrade": _upgrade(ci)
		"milestone": _milestone(ci)
		"swap": _swap(ci)
		"send": _send(ci)
		"back": _back(ci)
		"arrow_left": _triangle(ci, -1)
		"arrow_right": _triangle(ci, 1)
		"check": _check(ci)
		"close": _close(ci)
		"end_turn": _end_turn(ci)
		"medkit": _medkit(ci)
		"teleport": _teleport(ci)
		"power_shot": _power_shot(ci)
		"drill_bomb": _drill_bomb(ci)
		"spider_net": _spider_net(ci)
		"freeze_bomb": _bomb(ci, Color(0.5, 0.8, 1.0), true)
		"air_strike": _air_strike(ci)
		"wind_stopper": _wind_stopper(ci)
		_: _unknown(ci)


# ── Shapes ──────────────────────────────────────────────────────────────────

## A filled polygon with a rounded dark outline around it.
static func _poly(ci: CanvasItem, pts: Array, fill: Color, w: float = W) -> void:
	var packed := PackedVector2Array(pts)
	if w > 0.0:
		for o in Geometry2D.offset_polygon(packed, w, Geometry2D.JOIN_ROUND):
			ci.draw_colored_polygon(o, OUTLINE)
	ci.draw_colored_polygon(packed, fill)


static func _fill(ci: CanvasItem, pts: Array, fill: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), fill)


static func _disc(ci: CanvasItem, c: Vector2, r: float, fill: Color, w: float = W) -> void:
	if w > 0.0:
		ci.draw_circle(c, r + w, OUTLINE, true, -1.0, true)
	ci.draw_circle(c, r, fill, true, -1.0, true)


## A thick round-capped stroke along pts, outlined.
static func _stroke(ci: CanvasItem, pts: Array, color: Color, width: float, w: float = W) -> void:
	var packed := PackedVector2Array(pts)
	if w > 0.0:
		for o in Geometry2D.offset_polyline(packed, width / 2 + w, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			ci.draw_colored_polygon(o, OUTLINE)
	for o in Geometry2D.offset_polyline(packed, width / 2, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
		ci.draw_colored_polygon(o, color)


## A rounded rectangle with an outline (StyleBoxFlat, as the character art does).
static func _rect(ci: CanvasItem, r: Rect2, color: Color, radius: float, w: float = W) -> void:
	var key := [color, radius, w]
	var box: StyleBoxFlat = _boxes.get(key)
	if box == null:
		box = StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(int(radius))
		box.anti_aliasing = true
		if w > 0.0:
			box.border_color = OUTLINE
			box.set_border_width_all(int(w))
			box.set_expand_margin_all(w)
		box.corner_detail = 12
		_boxes[key] = box
	ci.draw_style_box(box, r)


static func _arc_pts(c: Vector2, r: float, a0: float, a1: float, n: int = 24) -> Array:
	var out := []
	for i in n + 1:
		out.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * r)
	return out


static func _star(c: Vector2, outer: float, inner: float, points: int, rot: float = -PI / 2) -> Array:
	var out := []
	for i in points * 2:
		out.append(c + Vector2.from_angle(rot + PI * i / points) * (outer if i % 2 == 0 else inner))
	return out


static func _sparkle(ci: CanvasItem, c: Vector2, r: float) -> void:
	_fill(ci, _star(c, r, r * 0.28, 4, 0.0), Color(1, 1, 1, 0.95))


# ── Wallet ──────────────────────────────────────────────────────────────────

static func _gem(ci: CanvasItem) -> void:
	var tl := Vector2(16, 38)
	var t0 := Vector2(31, 18)
	var t1 := Vector2(65, 18)
	var tr := Vector2(80, 38)
	var b := Vector2(48, 82)
	var m0 := Vector2(38, 38)
	var m1 := Vector2(58, 38)
	_poly(ci, [tl, t0, t1, tr, b], Color(0.36, 0.72, 1.0))
	_fill(ci, [t0, t1, m1, m0], Color(0.72, 0.92, 1.0))
	_fill(ci, [tl, t0, m0], Color(0.55, 0.84, 1.0))
	_fill(ci, [t1, tr, m1], Color(0.3, 0.6, 0.95))
	_fill(ci, [tl, m0, b], Color(0.42, 0.74, 1.0))
	_fill(ci, [m0, m1, b], Color(0.5, 0.82, 1.0))
	_fill(ci, [m1, tr, b], Color(0.22, 0.48, 0.88))
	_sparkle(ci, Vector2(33, 30), 9.0)


static func _coin(ci: CanvasItem) -> void:
	var c := Vector2(48, 48)
	_disc(ci, c, 37, GOLD_DARK)
	ci.draw_circle(c + Vector2(0, -2), 32, Color(1.0, 0.72, 0.18), true, -1.0, true)
	ci.draw_circle(c + Vector2(0, -2), 26, GOLD, true, -1.0, true)
	ci.draw_arc(c + Vector2(0, -2), 26, 0, TAU, 48, Color(0.88, 0.58, 0.12), 3.0, true)
	_fill(ci, _star(c + Vector2(0, -2), 15, 6.5, 5), Color(1.0, 0.93, 0.55))
	ci.draw_arc(c + Vector2(0, -2), 31, deg_to_rad(200), deg_to_rad(260), 12, Color(1, 1, 1, 0.65), 4.0, true)


static func _plus(ci: CanvasItem) -> void:
	_stroke(ci, [Vector2(48, 20), Vector2(48, 76)], WHITE, 16.0)
	_stroke(ci, [Vector2(20, 48), Vector2(76, 48)], WHITE, 16.0, 0.0)
	# Re-cover the vertical bar's outline where the bars cross.
	_stroke(ci, [Vector2(48, 20), Vector2(48, 76)], WHITE, 16.0, 0.0)


# ── Match ───────────────────────────────────────────────────────────────────

static func _bomb(ci: CanvasItem, body: Color, frost: bool) -> void:
	var c := Vector2(44, 56)
	var r := 27.0
	# Fuse and spark.
	_stroke(ci, [Vector2(62, 34), Vector2(70, 22), Vector2(80, 18)], Color(0.65, 0.5, 0.32), 6.0, 3.5)
	_fill(ci, _star(Vector2(82, 15), 13, 5, 6), Color(1.0, 0.62, 0.15))
	_fill(ci, _star(Vector2(82, 15), 7, 3, 6), Color(1.0, 0.95, 0.6))
	_disc(ci, c, r, body)
	ci.draw_circle(c + Vector2(4, 5), r * 0.74, body.darkened(0.18), true, -1.0, true)
	# Cap.
	ci.draw_set_transform(c + Vector2.from_angle(-PI / 4) * (r - 2), PI / 4, Vector2.ONE)
	_rect(ci, Rect2(-9, -8, 18, 14), Color(0.55, 0.58, 0.65) if not frost else Color(0.85, 0.95, 1.0), 3, 4.0)
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_circle(c + Vector2(-10, -10), r * 0.3, Color(1, 1, 1, 0.5), true, -1.0, true)
	ci.draw_circle(c + Vector2(-12, -13), r * 0.12, Color(1, 1, 1, 0.85), true, -1.0, true)
	if frost: # a snowflake on the ball
		var s := c + Vector2(3, 4)
		for i in 3:
			var d := Vector2.from_angle(PI / 3 * i + PI / 6) * 14.0
			ci.draw_line(s - d, s + d, WHITE, 3.5, true)
		for i in 6:
			var d := Vector2.from_angle(PI / 3 * i + PI / 6)
			var tip := s + d * 9.0
			ci.draw_line(tip, tip + d.rotated(0.7) * 5.0, WHITE, 2.5, true)
			ci.draw_line(tip, tip + d.rotated(-0.7) * 5.0, WHITE, 2.5, true)


static func _skill(ci: CanvasItem) -> void:
	var bolt := [Vector2(57, 6), Vector2(20, 54), Vector2(44, 54), Vector2(34, 90), Vector2(77, 38), Vector2(53, 38), Vector2(66, 6)]
	_poly(ci, bolt, Color(1.0, 0.82, 0.18))
	_fill(ci, [Vector2(57, 6), Vector2(20, 54), Vector2(30, 54), Vector2(62, 10)], Color(1.0, 0.95, 0.6))


static func _battle(ci: CanvasItem) -> void:
	for side in [-1.0, 1.0]:
		ci.draw_set_transform(Vector2(48, 50), side * PI / 4, Vector2.ONE)
		var blade := [Vector2(-6, 18), Vector2(-6, -30), Vector2(0, -42), Vector2(6, -30), Vector2(6, 18)]
		_poly(ci, blade, Color(0.86, 0.9, 0.97), 4.0)
		_fill(ci, [Vector2(0, 16), Vector2(0, -38), Vector2(6, -30), Vector2(6, 16)], Color(0.68, 0.73, 0.82))
		_rect(ci, Rect2(-16, 16, 32, 8), GOLD, 3, 4.0)
		_rect(ci, Rect2(-4, 24, 8, 14), Color(0.55, 0.35, 0.2), 2, 4.0)
		_disc(ci, Vector2(0, 42), 5, GOLD, 4.0)
	ci.draw_set_transform(Vector2.ZERO)


static func _triangle(ci: CanvasItem, dir: int) -> void:
	var tip := 48.0 + 24.0 * dir
	var back := 48.0 - 18.0 * dir
	for o in Geometry2D.offset_polygon(PackedVector2Array([Vector2(tip, 48), Vector2(back, 20), Vector2(back, 76)]), 5.0, Geometry2D.JOIN_ROUND):
		ci.draw_colored_polygon(o, OUTLINE)
	# Rounded corners: the inner white is the triangle offset inwards, then out again.
	for inner in Geometry2D.offset_polygon(PackedVector2Array([Vector2(tip - 6 * dir, 48), Vector2(back + 3 * dir, 26), Vector2(back + 3 * dir, 70)]), 3.0, Geometry2D.JOIN_ROUND):
		ci.draw_colored_polygon(inner, WHITE)


static func _end_turn(ci: CanvasItem) -> void:
	var tris := [[Vector2(14, 26), Vector2(14, 70), Vector2(42, 48)], [Vector2(42, 26), Vector2(42, 70), Vector2(70, 48)]]
	for t in tris:
		for o in Geometry2D.offset_polygon(PackedVector2Array(t), 5.0, Geometry2D.JOIN_ROUND):
			ci.draw_colored_polygon(o, OUTLINE)
	_rect(ci, Rect2(72, 26, 10, 44), WHITE, 3)
	for t in tris:
		_fill(ci, t, WHITE)


# ── Lobby navigation ────────────────────────────────────────────────────────

static func _characters(ci: CanvasItem) -> void:
	var body := _arc_pts(Vector2(48, 86), 30, PI, TAU, 24)
	body.append(Vector2(78, 88))
	body.append(Vector2(18, 88))
	_poly(ci, body, WHITE)
	_disc(ci, Vector2(48, 34), 17, WHITE)
	ci.draw_circle(Vector2(42, 28), 5, Color(1, 1, 1, 0.9), true, -1.0, true)
	_fill(ci, _arc_pts(Vector2(48, 86), 24, PI * 1.15, PI * 1.45, 8) + [Vector2(30, 80)], Color(0.85, 0.88, 0.95))


static func _inventory(ci: CanvasItem) -> void:
	_stroke(ci, _arc_pts(Vector2(48, 26), 12, PI, TAU, 12), Color(0.55, 0.25, 0.18), 6.0, 4.0)
	_rect(ci, Rect2(20, 26, 56, 60), Color(0.88, 0.38, 0.26), 14)
	_rect(ci, Rect2(20, 26, 56, 26), Color(0.72, 0.27, 0.2), 12)
	_rect(ci, Rect2(31, 60, 34, 20), Color(0.78, 0.31, 0.22), 6, 4.0)
	_rect(ci, Rect2(42, 46, 12, 10), GOLD, 3, 3.5)
	ci.draw_line(Vector2(27, 34), Vector2(40, 34), Color(1, 1, 1, 0.35), 3.0, true)


static func _history(ci: CanvasItem) -> void:
	_rect(ci, Rect2(24, 18, 48, 62), Color(0.98, 0.91, 0.72), 4)
	for y in [34.0, 46.0, 58.0]:
		ci.draw_line(Vector2(32, y), Vector2(64 if y < 58.0 else 54, y), Color(0.55, 0.38, 0.2), 3.5, true)
	_rect(ci, Rect2(16, 10, 64, 14), Color(0.88, 0.72, 0.48), 7)
	_rect(ci, Rect2(16, 74, 64, 14), Color(0.88, 0.72, 0.48), 7)
	ci.draw_line(Vector2(22, 14), Vector2(74, 14), Color(1, 1, 1, 0.4), 2.5, true)


static func _shop(ci: CanvasItem) -> void:
	_stroke(ci, [Vector2(8, 22), Vector2(20, 22), Vector2(30, 64), Vector2(74, 64)], WHITE, 6.0)
	_poly(ci, [Vector2(20, 30), Vector2(84, 30), Vector2(76, 58), Vector2(28, 58)], WHITE)
	for x in [36.0, 50.0, 64.0]:
		ci.draw_line(Vector2(x, 33), Vector2(x - 1.5, 55), Color(0.7, 0.74, 0.82), 3.0, true)
	ci.draw_line(Vector2(24, 44), Vector2(80, 44), Color(0.7, 0.74, 0.82), 3.0, true)
	_disc(ci, Vector2(36, 78), 7, Color(0.3, 0.32, 0.4))
	_disc(ci, Vector2(68, 78), 7, Color(0.3, 0.32, 0.4))


## Nâng cấp: a gold arrow rising out of a cut stone, a sparkle beside it.
static func _upgrade(ci: CanvasItem) -> void:
	var g := [Vector2(14, 64), Vector2(26, 52), Vector2(46, 52), Vector2(58, 64), Vector2(36, 88)]
	_poly(ci, g, Color(0.36, 0.72, 1.0))
	_fill(ci, [g[1], g[2], Vector2(42, 60), Vector2(30, 60)], Color(0.72, 0.92, 1.0))
	_fill(ci, [g[0], g[1], Vector2(30, 60)], Color(0.55, 0.84, 1.0))
	_fill(ci, [g[2], g[3], Vector2(42, 60)], Color(0.22, 0.48, 0.88))
	_fill(ci, [Vector2(30, 60), Vector2(42, 60), g[4]], Color(0.42, 0.74, 1.0))
	_fill(ci, [Vector2(42, 60), g[3], g[4]], Color(0.22, 0.48, 0.88))
	var arrow := [Vector2(62, 10), Vector2(88, 38), Vector2(73, 38), Vector2(73, 74), Vector2(51, 74), Vector2(51, 38), Vector2(36, 38)]
	_poly(ci, arrow, GOLD)
	_fill(ci, [Vector2(62, 18), Vector2(78, 34), Vector2(66, 34), Vector2(66, 68), Vector2(58, 68), Vector2(58, 34)], Color(1.0, 0.92, 0.55))
	_sparkle(ci, Vector2(84, 64), 10.0)
	_sparkle(ci, Vector2(22, 30), 7.0)


## Mốc thưởng: a red gift box with a gold ribbon and bow, a sparkle beside it.
static func _milestone(ci: CanvasItem) -> void:
	var red := Color(0.92, 0.26, 0.3)
	var red_dark := Color(0.72, 0.14, 0.22)
	# Bow loops first: the lid covers their base
	_poly(ci, [Vector2(48, 30), Vector2(26, 12), Vector2(18, 22), Vector2(28, 32)], GOLD)
	_poly(ci, [Vector2(48, 30), Vector2(70, 12), Vector2(78, 22), Vector2(68, 32)], GOLD)
	_fill(ci, [Vector2(46, 29), Vector2(27, 16), Vector2(22, 22)], Color(1.0, 0.92, 0.55))
	_rect(ci, Rect2(20, 46, 56, 38), red_dark, 6)
	_rect(ci, Rect2(14, 30, 68, 18), red, 6)
	_fill(ci, [Vector2(14, 44), Vector2(82, 44), Vector2(82, 48), Vector2(14, 48)], red_dark)
	_rect(ci, Rect2(41, 30, 14, 54), GOLD, 2, 0.0)
	ci.draw_line(Vector2(44, 32), Vector2(44, 82), Color(1.0, 0.92, 0.55), 3.0, true)
	_disc(ci, Vector2(48, 30), 7, GOLD, 3.0)
	ci.draw_line(Vector2(20, 34), Vector2(38, 34), Color(1, 1, 1, 0.35), 3.0, true)
	_sparkle(ci, Vector2(84, 58), 9.0)


# ── Buttons ─────────────────────────────────────────────────────────────────

static func _arrow(ci: CanvasItem, from: Vector2, to: Vector2, w: float = W) -> void:
	var d := (to - from).normalized()
	var n := Vector2(-d.y, d.x)
	_stroke(ci, [from, to - d * 6], WHITE, 10.0, w)
	_stroke(ci, [to - d * 18 + n * 16, to, to - d * 18 - n * 16], WHITE, 10.0, w)


static func _swap(ci: CanvasItem) -> void:
	# Outlines of both arrows first, then the white, so they read as one shape.
	_arrow(ci, Vector2(16, 32), Vector2(80, 32))
	_arrow(ci, Vector2(80, 64), Vector2(16, 64))
	_arrow(ci, Vector2(16, 32), Vector2(80, 32), 0.0)


static func _send(ci: CanvasItem) -> void:
	var plane := [Vector2(10, 46), Vector2(86, 14), Vector2(62, 84), Vector2(46, 58)]
	_poly(ci, plane, WHITE)
	_fill(ci, [Vector2(46, 58), Vector2(86, 14), Vector2(40, 74)], Color(0.78, 0.84, 0.95))
	ci.draw_line(Vector2(46, 58), Vector2(86, 14), Color(0.55, 0.62, 0.78), 2.5, true)


static func _back(ci: CanvasItem) -> void:
	_arrow(ci, Vector2(82, 48), Vector2(14, 48))


static func _check(ci: CanvasItem) -> void:
	_stroke(ci, [Vector2(18, 50), Vector2(40, 72), Vector2(80, 26)], GOLD, 13.0)


static func _close(ci: CanvasItem) -> void:
	_stroke(ci, [Vector2(24, 24), Vector2(72, 72)], WHITE, 12.0)
	_stroke(ci, [Vector2(72, 24), Vector2(24, 72)], WHITE, 12.0)
	_stroke(ci, [Vector2(24, 24), Vector2(72, 72)], WHITE, 12.0, 0.0)


static func _unknown(ci: CanvasItem) -> void:
	_disc(ci, Vector2(48, 48), 36, Color(0.55, 0.58, 0.68))
	var font := ThemeDB.fallback_font
	ci.draw_string_outline(font, Vector2(8, 70), "?", HORIZONTAL_ALIGNMENT_CENTER, 80, 60, 8, OUTLINE)
	ci.draw_string(font, Vector2(8, 70), "?", HORIZONTAL_ALIGNMENT_CENTER, 80, 60, WHITE)


# ── Items ───────────────────────────────────────────────────────────────────

static func _medkit(ci: CanvasItem) -> void:
	_rect(ci, Rect2(34, 14, 28, 18), Color(0.75, 0.78, 0.85), 6)
	_rect(ci, Rect2(40, 20, 16, 10), Color(0.15, 0.15, 0.2, 0.0), 2, 0.0)
	_rect(ci, Rect2(12, 26, 72, 58), WHITE, 12)
	ci.draw_rect(Rect2(16, 70, 64, 10), Color(0.85, 0.88, 0.94))
	_rect(ci, Rect2(41, 36, 14, 40), Color(0.92, 0.22, 0.24), 3, 0.0)
	_rect(ci, Rect2(28, 49, 40, 14), Color(0.92, 0.22, 0.24), 3, 0.0)
	ci.draw_line(Vector2(20, 34), Vector2(36, 34), Color(1, 1, 1, 0.9), 3.0, true)


static func _teleport(ci: CanvasItem) -> void:
	var c := Vector2(48, 50)
	var pts := []
	for i in 60:
		var t := float(i) / 59
		pts.append(c + Vector2.from_angle(t * TAU * 2.1) * lerpf(4.0, 34.0, t))
	_stroke(ci, pts, Color(0.62, 0.42, 1.0), 9.0)
	var inner := []
	for i in 40:
		var t := float(i) / 39
		inner.append(c + Vector2.from_angle(t * TAU * 2.1) * lerpf(4.0, 34.0, t))
	for o in Geometry2D.offset_polyline(PackedVector2Array(inner.slice(10)), 2.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
		ci.draw_colored_polygon(o, Color(0.6, 0.95, 1.0))
	_sparkle(ci, Vector2(76, 18), 9.0)
	_sparkle(ci, Vector2(18, 78), 7.0)


static func _power_shot(ci: CanvasItem) -> void:
	var c := Vector2(48, 48)
	_poly(ci, _star(c, 42, 24, 10, -PI / 2 + 0.15), Color(1.0, 0.45, 0.15))
	_fill(ci, _star(c, 27, 15, 10, -PI / 2 + 0.45), Color(1.0, 0.8, 0.25))
	ci.draw_circle(c, 10, Color(1, 0.98, 0.85), true, -1.0, true)


static func _drill_bomb(ci: CanvasItem) -> void:
	_poly(ci, [Vector2(26, 34), Vector2(70, 34), Vector2(48, 90)], Color(0.74, 0.77, 0.84))
	_fill(ci, [Vector2(48, 34), Vector2(70, 34), Vector2(48, 90)], Color(0.6, 0.63, 0.72))
	for i in 4:
		var y := 42.0 + i * 11.0
		var half := 22.0 * (90.0 - y) / 56.0
		ci.draw_line(Vector2(48 - half, y), Vector2(48 + half, y + 7), Color(0.35, 0.38, 0.46), 3.0, true)
	_rect(ci, Rect2(22, 12, 52, 24), Color(1.0, 0.6, 0.15), 8)
	ci.draw_line(Vector2(30, 18), Vector2(52, 18), Color(1, 1, 1, 0.5), 3.0, true)


static func _spider_net(ci: CanvasItem) -> void:
	var c := Vector2(48, 48)
	var spokes := 8
	var rings := [12.0, 24.0, 37.0]
	var lines := []
	for i in spokes:
		lines.append([c, c + Vector2.from_angle(TAU * i / spokes + 0.2) * 42.0])
	for r in rings:
		for i in spokes:
			var a0 := TAU * i / spokes + 0.2
			var a1 := TAU * (i + 1) / spokes + 0.2
			var mid: Vector2 = c + Vector2.from_angle((a0 + a1) / 2) * r * 0.86 # sags inwards
			lines.append([c + Vector2.from_angle(a0) * r, mid, c + Vector2.from_angle(a1) * r])
	for l in lines:
		for o in Geometry2D.offset_polyline(PackedVector2Array(l), 4.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			ci.draw_colored_polygon(o, OUTLINE)
	for l in lines:
		for o in Geometry2D.offset_polyline(PackedVector2Array(l), 1.6, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			ci.draw_colored_polygon(o, WHITE)


static func _air_strike(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2(48, 48), PI / 4, Vector2.ONE)
	var body := Color(0.8, 0.85, 0.93)
	_poly(ci, [Vector2(-40, 6), Vector2(-6, -10), Vector2(6, -10), Vector2(40, 6), Vector2(40, 13), Vector2(6, 6), Vector2(-6, 6), Vector2(-40, 13)], body, 4.5)
	_poly(ci, [Vector2(-16, 34), Vector2(-4, 28), Vector2(4, 28), Vector2(16, 34), Vector2(16, 40), Vector2(-16, 40)], body, 4.5)
	_rect(ci, Rect2(-7, -40, 14, 78), body, 7, 4.5)
	_fill(ci, _arc_pts(Vector2(0, -33), 7, PI, TAU, 10), Color(0.95, 0.3, 0.28))
	_rect(ci, Rect2(-3.5, -26, 7, 10), Color(0.35, 0.65, 0.95), 3, 0.0)
	ci.draw_set_transform(Vector2.ZERO)


static func _wind_stopper(ci: CanvasItem) -> void:
	# Wind lines behind a leaf.
	_stroke(ci, [Vector2(10, 30), Vector2(46, 30)] + _arc_pts(Vector2(46, 22), 8, PI / 2, -PI, 10), WHITE, 6.0, 4.0)
	_stroke(ci, [Vector2(10, 74), Vector2(56, 74)] + _arc_pts(Vector2(56, 82), 8, -PI / 2, PI, 10), WHITE, 6.0, 4.0)
	var leaf := []
	for i in 13:
		var t := float(i) / 12
		leaf.append(Vector2(26, 66).lerp(Vector2(82, 18), t) + Vector2(-1, -1).normalized() * sin(t * PI) * 16.0)
	for i in 13:
		var t := 1.0 - float(i) / 12
		leaf.append(Vector2(26, 66).lerp(Vector2(82, 18), t) + Vector2(1, 1).normalized() * sin(t * PI) * 16.0)
	_poly(ci, leaf, Color(0.4, 0.8, 0.35))
	ci.draw_line(Vector2(22, 70), Vector2(76, 24), Color(0.2, 0.5, 0.2), 3.5, true)
