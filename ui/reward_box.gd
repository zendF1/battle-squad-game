extends Control
## The container a reward comes out of, drawn in code (original art) on a 160 × 160 canvas scaled
## into the control's square: a chest in its kind's colours (ui/chest_icon.gd LOOKS: the stone
## chest oak and iron with a blue gem, the equipment chest dark red and gold with a violet gem,
## +16 richer: gold trim and a star on the lid), or a gift box (red with a gold ribbon and bow)
## for rewards that are not a chest's. Its lid is drawn apart so the reveal can lift it and throw
## it off (lid_offset, lid_turn, lid_alpha); leak (0..1) is the light escaping through the seam,
## the keyhole and short shafts, in `light` (the best reward's colour); open_glow (0..1) the
## light pouring out of the open box. Ignores the mouse.

const GameData := preload("res://autoload/game_data_model.gd")
const ChestIcon := preload("res://ui/chest_icon.gd")
const RewardGlow := preload("res://ui/reward_glow.gd")

const CANVAS := 160.0
const OUTLINE := Color(0.08, 0.06, 0.1)
const SEAM_Y := 84.0
const HINGE := Vector2(80, 84)
const GIFT := {"main": Color(0.9, 0.2, 0.32), "light": Color(1.0, 0.46, 0.52), "dark": Color(0.6, 0.08, 0.2),
	"ribbon": Color(1.0, 0.82, 0.26), "ribbon_light": Color(1.0, 0.95, 0.62)}

## "" draws the gift box; a chest id its chest.
var chest_id := "":
	set(v):
		chest_id = v
		queue_redraw()
var light := Color(1.0, 0.85, 0.4):
	set(v):
		light = v
		queue_redraw()
var leak := 0.0:
	set(v):
		leak = v
		queue_redraw()
var open_glow := 0.0:
	set(v):
		open_glow = v
		queue_redraw()
## The lid's move (canvas px), turn (rad) and alpha (the burst throws it off).
var lid_offset := Vector2.ZERO:
	set(v):
		lid_offset = v
		queue_redraw()
var lid_turn := 0.0:
	set(v):
		lid_turn = v
		queue_redraw()
var lid_alpha := 1.0:
	set(v):
		lid_alpha = v
		queue_redraw()

var _t := 0.0


static func make(id: String, px: float) -> Control:
	var c = load("res://ui/reward_box.gd").new()
	c.chest_id = id
	c.size = Vector2(px, px)
	c.custom_minimum_size = Vector2(px, px)
	return c


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if (leak > 0.0 or open_glow > 0.0) and is_visible_in_tree():
		_t += delta
		queue_redraw()


func is_gift() -> bool:
	return chest_id == ""


func _base() -> Transform2D:
	var s := minf(size.x, size.y) / CANVAS
	return Transform2D(0.0, Vector2(s, s), 0.0, (size - Vector2(CANVAS, CANVAS) * s) / 2.0)


func _draw() -> void:
	var base := _base()
	draw_set_transform_matrix(base)
	# The shadow on the ground
	_ellipse(Vector2(80, 146), Vector2(62, 9), Color(0, 0, 0, 0.32))
	if open_glow > 0.0:
		_light_column()
	if is_gift():
		_gift_body()
	else:
		_chest_body()
	if open_glow > 0.0:
		_mouth()
	if lid_alpha > 0.0:
		var lid := base * Transform2D(lid_turn, HINGE + lid_offset) * Transform2D(0.0, -HINGE)
		draw_set_transform_matrix(lid)
		if is_gift():
			_gift_lid()
		else:
			_chest_lid()
		draw_set_transform_matrix(base)
	if leak > 0.0 and lid_offset.length() < 4.0:
		_leak()
	draw_set_transform_matrix(Transform2D.IDENTITY)


# ── Chest ───────────────────────────────────────────────────────────────────

func _look() -> Dictionary:
	return ChestIcon.LOOKS.get(GameData.chest_kind(chest_id), ChestIcon.LOOKS["stone"])


func _rich() -> bool:
	return GameData.chest_upgrade_level(chest_id) >= 16


func _chest_body() -> void:
	var look := _look()
	var wood: Array = look["wood"]
	var band: Array = look["band"]
	_box(Rect2(22, 84, 116, 56), wood[1], 5.0)
	draw_rect(Rect2(22, 84, 116, 9), wood[2])
	for y in [104.0, 122.0]:
		draw_rect(Rect2(26, y, 108, 3), Color(wood[0], 0.45))
	draw_rect(Rect2(22, 132, 116, 8), wood[2])
	var trim: Color = band[1]
	for x in [36.0, 112.0]:
		_box(Rect2(x, 84, 12, 56), trim, 3.0)
		draw_rect(Rect2(x, 84, 4, 56), Color(band[0], 0.85))
		for ry in [96.0, 128.0]:
			draw_circle(Vector2(x + 6, ry), 2.2, Color(band[0]))
	if _rich():
		_box(Rect2(22, 134, 116, 6), trim, 2.0)
	# The lock plate on the front, its keyhole
	_box(Rect2(68, 84, 24, 28), band[1], 3.5)
	draw_rect(Rect2(70, 86, 6, 24), Color(band[0], 0.7))
	draw_circle(Vector2(80, 96), 4.0, OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(77, 97), Vector2(83, 97), Vector2(81.5, 106), Vector2(78.5, 106)]), OUTLINE)
	if leak > 0.0 and lid_offset.length() < 4.0: # light through the keyhole
		draw_circle(Vector2(80, 96), 3.0, Color(light.lerp(Color.WHITE, 0.6), leak))
		draw_colored_polygon(PackedVector2Array([Vector2(78.5, 97), Vector2(81.5, 97), Vector2(80.8, 104), Vector2(79.2, 104)]),
			Color(light.lerp(Color.WHITE, 0.6), leak))


func _dome(i: int, n: int, inset: float = 0.0) -> Vector2:
	var a := PI + PI * i / n
	return Vector2(80 + cos(a) * (62 - inset), SEAM_Y + sin(a) * (44 - inset))


func _chest_lid() -> void:
	var look := _look()
	var wood: Array = look["wood"]
	var band: Array = look["band"]
	var gem: Array = look["gem"]
	var a := lid_alpha
	var lid := PackedVector2Array()
	lid.append(Vector2(16, SEAM_Y + 2))
	for i in 17:
		lid.append(_dome(i, 16))
	lid.append(Vector2(144, SEAM_Y + 2))
	for o in Geometry2D.offset_polygon(lid, 5.0, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(o, Color(OUTLINE, a))
	draw_colored_polygon(lid, Color(wood[1].lightened(0.08), a))
	# A darker lower lip and a highlight along the top
	draw_rect(Rect2(18, SEAM_Y - 8, 124, 9), Color(wood[2], a))
	var shine := PackedVector2Array()
	for i in range(3, 10):
		shine.append(_dome(i, 16, 9.0))
	draw_polyline(shine, Color(wood[0], 0.8 * a), 4.0, true)
	# The bands follow the dome
	for x in [36.0, 112.0]:
		var top := SEAM_Y - 44.0 * sqrt(maxf(0.0, 1.0 - pow((x + 6.0 - 80.0) / 62.0, 2.0)))
		_box(Rect2(x, top + 2, 12, SEAM_Y - top - 2), Color(band[1], a), 3.0, a)
		draw_rect(Rect2(x, top + 2, 4, SEAM_Y - top - 2), Color(band[0], 0.85 * a))
	if _rich():
		var trim := PackedVector2Array()
		for i in 17:
			trim.append(_dome(i, 16, 2.0))
		draw_polyline(trim, Color(band[0], a), 4.0, true)
	# The gem clasp
	_box(Rect2(70, SEAM_Y - 24, 20, 22), Color(band[1], a), 3.5, a)
	var g := PackedVector2Array([Vector2(80, SEAM_Y - 21), Vector2(87, SEAM_Y - 13), Vector2(80, SEAM_Y - 5), Vector2(73, SEAM_Y - 13)])
	draw_colored_polygon(g, Color(gem[1], a))
	draw_colored_polygon(PackedVector2Array([g[0], g[1], Vector2(80, SEAM_Y - 13), g[3]]), Color(gem[0], a))
	if _rich():
		var st := PackedVector2Array()
		for i in 10:
			st.append(Vector2(80, SEAM_Y - 34) + Vector2.from_angle(-PI / 2 + PI * i / 5.0) * (11.0 if i % 2 == 0 else 5.0))
		for o in Geometry2D.offset_polygon(st, 3.0, Geometry2D.JOIN_ROUND):
			draw_colored_polygon(o, Color(OUTLINE, a))
		draw_colored_polygon(st, Color(band[0], a))


# ── Gift box ────────────────────────────────────────────────────────────────

func _gift_body() -> void:
	_box(Rect2(30, 86, 100, 54), GIFT["main"], 5.0)
	draw_rect(Rect2(30, 86, 100, 8), GIFT["dark"])
	draw_rect(Rect2(34, 96, 6, 40), Color(GIFT["light"], 0.6))
	_box(Rect2(72, 86, 16, 54), GIFT["ribbon"], 2.0)
	draw_rect(Rect2(72, 86, 5, 54), GIFT["ribbon_light"])


func _gift_lid() -> void:
	var a := lid_alpha
	_box(Rect2(24, 68, 112, 20), Color(GIFT["main"].lightened(0.06), a), 5.0, a)
	draw_rect(Rect2(28, 70, 104, 5), Color(GIFT["light"], 0.7 * a))
	_box(Rect2(72, 68, 16, 20), Color(GIFT["ribbon"], a), 2.0, a)
	draw_rect(Rect2(72, 68, 5, 20), Color(GIFT["ribbon_light"], a))
	# The bow: two loops, two tails, the knot
	for side in [-1.0, 1.0]:
		var loop := PackedVector2Array()
		for i in 13:
			var t := TAU * i / 12.0
			loop.append(Vector2(80 + side * (20 + cos(t) * 17), 54 + sin(t) * 11).rotated(0.0))
		for o in Geometry2D.offset_polygon(loop, 4.0, Geometry2D.JOIN_ROUND):
			draw_colored_polygon(o, Color(OUTLINE, a))
		draw_colored_polygon(loop, Color(GIFT["ribbon"], a))
		var hole := PackedVector2Array()
		for i in 9:
			var t := TAU * i / 8.0
			hole.append(Vector2(80 + side * (21 + cos(t) * 7), 54 + sin(t) * 4))
		draw_colored_polygon(hole, Color(GIFT["ribbon"].darkened(0.35), a))
	draw_circle(Vector2(80, 58), 10.0, Color(OUTLINE, a))
	draw_circle(Vector2(80, 58), 7.0, Color(GIFT["ribbon_light"], a))


# ── Light ───────────────────────────────────────────────────────────────────

## The light escaping the closed box: the seam glows, short shafts flicker out of it.
func _leak() -> void:
	var c := light.lerp(Color.WHITE, 0.45)
	var y := SEAM_Y if not is_gift() else 87.0
	var x0 := 20.0 if not is_gift() else 26.0
	var x1 := 140.0 if not is_gift() else 134.0
	var tex := RewardGlow.radial()
	draw_texture_rect(tex, Rect2(Vector2(x0 - 16, y - 20), Vector2(x1 - x0 + 32, 40)), false, Color(light, 0.55 * leak))
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(c, leak), 2.0 + 4.0 * leak, true)
	var shafts := 3 + int(leak * 5.0)
	for i in shafts:
		var x := lerpf(x0 + 10, x1 - 10, (i + 0.5) / shafts)
		var flick := 0.6 + 0.4 * sin(_t * 9.0 + i * 1.7)
		var h := (14.0 + 34.0 * leak) * flick
		var lean := (x - 80.0) * 0.35
		var pts := PackedVector2Array([Vector2(x - 3, y), Vector2(x + 3, y), Vector2(x + 3 + lean, y - h), Vector2(x - 3 + lean * 1.1, y - h)])
		draw_polygon(pts, PackedColorArray([Color(c, 0.8 * leak), Color(c, 0.8 * leak), Color(c, 0.0), Color(c, 0.0)]))


## The light pouring up out of the open box.
func _light_column() -> void:
	var c := light.lerp(Color.WHITE, 0.35)
	var o := open_glow
	var flick := 0.92 + 0.08 * sin(_t * 7.0)
	var pts := PackedVector2Array([Vector2(34, 88), Vector2(126, 88), Vector2(170, -140), Vector2(-10, -140)])
	draw_polygon(pts, PackedColorArray([Color(c, 0.75 * o * flick), Color(c, 0.75 * o * flick), Color(c, 0.0), Color(c, 0.0)]))
	var core := PackedVector2Array([Vector2(56, 88), Vector2(104, 88), Vector2(118, -60), Vector2(42, -60)])
	draw_polygon(core, PackedColorArray([Color(1, 1, 1, 0.8 * o), Color(1, 1, 1, 0.8 * o), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))


## The open mouth: a bright opening where the lid was.
func _mouth() -> void:
	var y := SEAM_Y if not is_gift() else 87.0
	var w := 58.0 if not is_gift() else 50.0
	_ellipse(Vector2(80, y), Vector2(w, 9), Color(OUTLINE, 0.9))
	_ellipse(Vector2(80, y), Vector2(w - 4, 6.5), light.lerp(Color.WHITE, 0.55 + 0.3 * open_glow))
	draw_texture_rect(RewardGlow.radial(), Rect2(Vector2(80 - w * 1.4, y - 30), Vector2(w * 2.8, 60)), false, Color(light, 0.8 * open_glow))


# ── Helpers ─────────────────────────────────────────────────────────────────

func _box(r: Rect2, color: Color, w: float, a: float = 1.0) -> void:
	draw_rect(r.grow(w), Color(OUTLINE, a))
	draw_rect(r, color)


func _ellipse(at: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(at + Vector2(cos(TAU * i / 32.0) * radii.x, sin(TAU * i / 32.0) * radii.y))
	draw_colored_polygon(pts, color)
