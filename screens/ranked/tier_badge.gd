extends Control
## A rank tier's badge drawn in code (the icon style of mission_art.gd: bright shapes with a dark
## rounded outline) on a 96 × 96 canvas scaled to fit the control, readable from 24 to 96 px:
## a shield in the tier's colours (dark rim, light bevel, a lit face) with a star, the division
## as roman bars on its lower half (III lowest, I highest; master has none, a bigger gold star).
## From silver up feathered wings behind it, wider with each tier (diamond a gem on top, master a
## crown). An unknown tier ("") draws a grey shield without a star.

const RankModel := preload("res://screens/ranked/rank_model.gd")

const OUTLINE := Color(0.07, 0.07, 0.14)
const W := 4.0
const INNER := Color(0.09, 0.11, 0.27)
## [light, mid, dark] per tier.
const COLORS := {
	"bronze": [Color(1.0, 0.76, 0.52), Color(0.8, 0.48, 0.24), Color(0.5, 0.27, 0.12)],
	"silver": [Color(0.96, 0.98, 1.0), Color(0.7, 0.76, 0.87), Color(0.42, 0.47, 0.6)],
	"gold": [Color(1.0, 0.94, 0.58), Color(1.0, 0.77, 0.2), Color(0.76, 0.45, 0.08)],
	"platinum": [Color(0.78, 1.0, 0.95), Color(0.34, 0.83, 0.78), Color(0.1, 0.48, 0.5)],
	"diamond": [Color(0.8, 0.93, 1.0), Color(0.36, 0.62, 1.0), Color(0.16, 0.28, 0.72)],
	"master": [Color(1.0, 0.74, 0.96), Color(0.8, 0.32, 0.92), Color(0.42, 0.1, 0.56)],
	"": [Color(0.8, 0.82, 0.88), Color(0.5, 0.53, 0.62), Color(0.3, 0.32, 0.4)],
}
const CROWN := [Color(1.0, 0.92, 0.5), Color(1.0, 0.74, 0.18)]

var tier := "":
	set(v):
		tier = v if COLORS.has(v) else ""
		queue_redraw()
var division := 3:
	set(v):
		division = v
		queue_redraw()


static func make(t: String, div: int, px: float) -> Control:
	var c = load("res://screens/ranked/tier_badge.gd").new()
	c.tier = t
	c.division = div
	c.custom_minimum_size = Vector2(px, px)
	c.size = Vector2(px, px)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	resized.connect(queue_redraw)
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pivot_offset = size / 2.0


func _draw() -> void:
	var s := minf(size.x, size.y) / 96.0
	draw_set_transform((size - Vector2(96, 96) * s) / 2.0, 0.0, Vector2(s, s))
	var c: Array = COLORS[tier]
	var rank := RankModel.tier_index(tier)
	if rank >= 1:
		_wings(c, rank)
	if rank == 5:
		_crown()
	_poly(shield_points(0.0), c[2]) # the dark rim, outlined
	_fill(shield_points(2.5), c[0]) # a light bevel
	_gradient(shield_points(5.5), c[1].lightened(0.12), c[2].lerp(c[1], 0.35)) # the face
	_fill(_left_half(shield_points(5.5)), Color(1, 1, 1, 0.16)) # light from the left
	_fill(_gloss(), Color(1, 1, 1, 0.22))
	if rank == 4:
		_poly([Vector2(48, -1), Vector2(57, 8), Vector2(48, 18), Vector2(39, 8)], c[0], 3.0)
		_fill([Vector2(48, -1), Vector2(57, 8), Vector2(48, 8)], Color(1, 1, 1, 0.6))
	if tier == "":
		return
	var master := tier == "master"
	var star_c := Vector2(48, 39 if not master else 47)
	var r := 16.0 if not master else 21.0
	var star_fill: Color = c[0].lightened(0.35) if not master else CROWN[0]
	_poly(star_points(star_c, r, r * 0.46), star_fill, 3.5)
	_fill(star_points(star_c + Vector2(-1.5, -2.0), r * 0.42, r * 0.2), Color(1, 1, 1, 0.85))
	if not RankModel.single_division(tier): # one division (master): no bars
		_numeral(clampi(division, 1, 3), Color(1, 1, 1))


## The upper-left shine on the face.
static func _gloss() -> Array:
	return [Vector2(27, 21), Vector2(46, 15), Vector2(46, 19), Vector2(31, 25), Vector2(29, 44), Vector2(26, 44)]


func _gradient(pts: Array, top: Color, bottom: Color) -> void:
	var packed := PackedVector2Array(pts)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - 10.0) / 76.0, 0.0, 1.0)))
	draw_polygon(packed, cols)


## The shield outline, `inset` units inside the outer one: a flat-topped crest curving to a
## point at the bottom.
static func shield_points(inset: float) -> Array:
	var top := 12.0 + inset
	var left := 20.0 + inset
	var right := 76.0 - inset
	var tip := 88.0 - inset * 1.3
	var out := []
	out.append(Vector2(left, top + 4))
	out.append(Vector2(left + (right - left) * 0.25, top + 1))
	out.append(Vector2(48, top - 3 + inset * 0.3))
	out.append(Vector2(right - (right - left) * 0.25, top + 1))
	out.append(Vector2(right, top + 4))
	# right side down, then the curve to the tip
	var shoulder := 50.0
	for i in 9:
		var t := i / 8.0
		var p := Vector2(right, shoulder).lerp(Vector2(48, tip), t)
		p.x += sin(t * PI) * (right - 48) * 0.28
		out.append(p)
	for i in range(1, 9):
		var t := i / 8.0
		var p := Vector2(48, tip).lerp(Vector2(left, shoulder), t)
		p.x -= sin(t * PI) * (48 - left) * 0.28
		out.append(p)
	return out


static func _left_half(pts: Array) -> Array:
	return pts.filter(func(p: Vector2) -> bool: return p.x <= 48.0)


## Roman bars (I, II, III) on the lower half.
func _numeral(n: int, color: Color) -> void:
	var w := 5.0
	var gap := 4.0
	var total := n * w + (n - 1) * gap
	var x := 48.0 - total / 2.0
	for i in n:
		_rect(Rect2(x + i * (w + gap), 60, w, 15), color)


## Feathered wings behind the shield, wider and with more feathers for higher tiers.
func _wings(c: Array, rank: int) -> void:
	var span: float = [0.0, 13.0, 16.0, 18.0, 20.0, 22.0][rank]
	var feathers := 2 if rank <= 2 else 3
	for side in [-1, 1]:
		var root_x: float = 48.0 + side * 18.0
		for f in range(feathers - 1, -1, -1):
			var y: float = 22.0 + f * 12.0 # the feather's tip height
			var reach: float = 4.0 + span * (1.0 - f * 0.2) * 0.6 # past the shield's edge (x 76 / 20), inside the canvas
			var tip := Vector2(48.0 + side * (28.0 + reach), y - 6.0)
			var pts := [Vector2(root_x, y - 4.0), tip, Vector2(tip.x - side * 7.0, y + 7.0), Vector2(root_x, y + 12.0)]
			_poly(pts, c[1] if f % 2 == 0 else c[2].lerp(c[1], 0.45), 3.0)
			_fill([pts[0], pts[1], Vector2(tip.x - side * 10.0, y)], Color(c[0], 0.6))


func _crown() -> void:
	var pts := [Vector2(30, 14), Vector2(28, -2), Vector2(38, 6), Vector2(48, -6), Vector2(58, 6), Vector2(68, -2), Vector2(66, 14)]
	_poly(pts, CROWN[1])
	_fill([Vector2(32, 12), Vector2(31, 3), Vector2(38, 9), Vector2(48, 0), Vector2(48, 12)], Color(CROWN[0], 0.8))
	for p in [Vector2(28, -2), Vector2(48, -6), Vector2(68, -2)]:
		_circle(p, 3.5, CROWN[0])


# ── Shapes ──────────────────────────────────────────────────────────────────

func _poly(pts: Array, fill: Color, w: float = W) -> void:
	var packed := PackedVector2Array(pts)
	if w > 0.0:
		for o in Geometry2D.offset_polygon(packed, w, Geometry2D.JOIN_ROUND):
			draw_colored_polygon(o, OUTLINE)
	draw_colored_polygon(packed, fill)


func _fill(pts: Array, fill: Color) -> void:
	var packed := PackedVector2Array(pts)
	if Geometry2D.triangulate_polygon(packed).is_empty():
		return
	draw_colored_polygon(packed, fill)


func _rect(r: Rect2, color: Color) -> void:
	draw_rect(r.grow(2.5), OUTLINE)
	draw_rect(r, color)


func _circle(c: Vector2, r: float, color: Color) -> void:
	draw_circle(c, r + 2.5, OUTLINE)
	draw_circle(c, r, color)


static func star_points(c: Vector2, outer: float, inner: float, points: int = 5, rot: float = -PI / 2) -> Array:
	var out := []
	for i in points * 2:
		out.append(c + Vector2.from_angle(rot + PI * i / points) * (outer if i % 2 == 0 else inner))
	return out
