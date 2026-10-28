extends Control
## A grade's insignia (huy hiệu) drawn in code, placeholder art until real art: a shoulder board
## on a 96 × 96 canvas scaled to fit the control, readable from about 20 to 300 px, on light and
## dark grounds (a dark outline round everything). One look per grade id (LOOKS, art only: the
## names and the order are the game data's):
## - enlisted (Binh nhì..Thượng sĩ): a dark green board with 1–5 gold chevrons;
## - cadet (Học viên): the green board with one silver bar across;
## - company officers (Thiếu úy..Đại úy): one silver stripe down the board, 1–4 silver stars;
## - field officers (Thiếu tá..Đại tá): two gold stripes, 1–4 gold stars;
## - generals: a gold board with 1–4 big red stars.
## A gold button near the pointed end. Higher grades feel grander: field officers get a gold edge
## round the board, generals a warm glow behind it (stronger with each star). The real art
## (assets/ranks/badge_<grade>.png, Art.rank_badge()) is drawn instead when it is there. An
## unknown grade (an admin-added one) draws its group's
## board without marks (a general flag in the game data: the gold board); "" a grey board.
## The group's colours (GROUPS) also tint the grade's name, the frame (grade_frame.gd) and the
## rank popup's effects.

const RankModel := preload("res://screens/ranked/rank_model.gd")
const Art := preload("res://ui/art.gd")

const OUTLINE := Color(0.07, 0.07, 0.12)
const W := 3.5
## [group, marks] per grade id.
const LOOKS := {
	"binh_nhi": ["enlisted", 1], "binh_nhat": ["enlisted", 2], "ha_si": ["enlisted", 3], "trung_si": ["enlisted", 4],
	"thuong_si": ["enlisted", 5], "hoc_vien": ["cadet", 1],
	"thieu_uy": ["company", 1], "trung_uy": ["company", 2], "thuong_uy": ["company", 3], "dai_uy": ["company", 4],
	"thieu_ta": ["field", 1], "trung_ta": ["field", 2], "thuong_ta": ["field", 3], "dai_ta": ["field", 4],
	"thieu_tuong": ["general", 1], "trung_tuong": ["general", 2], "thuong_tuong": ["general", 3], "dai_tuong": ["general", 4],
}
## Per group: board [light, mid, dark], mark [light, main], text (the grade's name), frame
## [light, main, dark].
const GROUPS := {
	"enlisted": {"board": [Color(0.42, 0.6, 0.34), Color(0.2, 0.38, 0.19), Color(0.1, 0.21, 0.1)],
		"mark": [Color(1.0, 0.95, 0.62), Color(1.0, 0.78, 0.22)], "text": Color(0.62, 0.92, 0.55),
		"frame": [Color(0.66, 0.92, 0.55), Color(0.3, 0.66, 0.3), Color(0.12, 0.32, 0.14)]},
	"cadet": {"board": [Color(0.42, 0.6, 0.34), Color(0.2, 0.38, 0.19), Color(0.1, 0.21, 0.1)],
		"mark": [Color(1.0, 1.0, 1.0), Color(0.78, 0.83, 0.92)], "text": Color(0.84, 0.9, 1.0),
		"frame": [Color(0.96, 0.98, 1.0), Color(0.68, 0.74, 0.86), Color(0.36, 0.41, 0.54)]},
	"company": {"board": [Color(0.42, 0.6, 0.34), Color(0.2, 0.38, 0.19), Color(0.1, 0.21, 0.1)],
		"mark": [Color(1.0, 1.0, 1.0), Color(0.78, 0.83, 0.92)], "text": Color(0.84, 0.9, 1.0),
		"frame": [Color(0.96, 0.98, 1.0), Color(0.68, 0.74, 0.86), Color(0.36, 0.41, 0.54)]},
	"field": {"board": [Color(0.42, 0.6, 0.34), Color(0.2, 0.38, 0.19), Color(0.1, 0.21, 0.1)],
		"mark": [Color(1.0, 0.95, 0.62), Color(1.0, 0.76, 0.2)], "text": Color(1.0, 0.84, 0.36),
		"frame": [Color(1.0, 0.94, 0.6), Color(1.0, 0.74, 0.2), Color(0.66, 0.4, 0.06)]},
	"general": {"board": [Color(1.0, 0.92, 0.55), Color(0.98, 0.74, 0.2), Color(0.7, 0.44, 0.08)],
		"mark": [Color(1.0, 0.55, 0.45), Color(0.86, 0.12, 0.12)], "text": Color(1.0, 0.62, 0.38),
		"frame": [Color(1.0, 0.86, 0.4), Color(0.86, 0.16, 0.14), Color(0.42, 0.04, 0.06)]},
	"": {"board": [Color(0.78, 0.8, 0.86), Color(0.5, 0.53, 0.62), Color(0.3, 0.32, 0.4)],
		"mark": [Color(1, 1, 1), Color(0.8, 0.82, 0.88)], "text": Color(0.85, 0.87, 0.93),
		"frame": [Color(0.9, 0.92, 0.96), Color(0.6, 0.63, 0.72), Color(0.3, 0.32, 0.4)]},
}
const BUTTON := [Color(1.0, 0.94, 0.6), Color(0.92, 0.66, 0.16)]
## The ladder top's gold (the rank popup's crown effects).
const CROWN := [Color(1.0, 0.92, 0.5), Color(1.0, 0.74, 0.18)]

var grade := "":
	set(v):
		grade = v
		queue_redraw()
## Kept for the callers' symmetry with the rank ([grade, division]); the insignia shows the grade.
var division := 0


static func make(g: String, div: int, px: float) -> Control:
	var c = load("res://screens/ranked/grade_badge.gd").new()
	c.grade = g
	c.division = div
	c.custom_minimum_size = Vector2(px, px)
	c.size = Vector2(px, px)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


## The grade's group ("enlisted", "cadet", "company", "field", "general"; "" unknown).
static func group_of(g: String) -> String:
	if LOOKS.has(g):
		return LOOKS[g][0]
	if g != "" and RankModel.is_general(g):
		return "general"
	return "enlisted" if RankModel.grade_index(g) >= 0 else ""


static func marks_of(g: String) -> int:
	return int(LOOKS[g][1]) if LOOKS.has(g) else 0


static func style(g: String) -> Dictionary:
	return GROUPS[group_of(g)]


## [light, mid, dark] of the grade's frame (effects, glows).
static func colors(g: String) -> Array:
	return style(g)["frame"]


## The colour of the grade's name.
static func text_color(g: String) -> Color:
	return style(g)["text"]


func _ready() -> void:
	resized.connect(queue_redraw)
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pivot_offset = size / 2.0


func _draw() -> void:
	var side := minf(size.x, size.y)
	var tex := Art.rank_badge(grade)
	if tex != null: # the real art
		draw_texture_rect(tex, Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side)), false)
		return
	var s := side / 96.0
	draw_set_transform((size - Vector2(96, 96) * s) / 2.0, 0.0, Vector2(s, s))
	var st := style(grade)
	var board: Array = st["board"]
	var mark: Array = st["mark"]
	var group := group_of(grade)
	if group == "general": # a warm glow behind, stronger with each star
		for i in 4:
			draw_circle(Vector2(48, 50), 30.0 + i * 5.0, Color(1.0, 0.75, 0.3, (0.06 + 0.03 * marks_of(grade)) * (1.0 - i * 0.22)))
	if group == "field" or group == "general": # a gold edge round the board
		_poly(board_points(-2.2), Color(1.0, 0.82, 0.3), 2.0)
	_poly(board_points(0.0), board[2]) # the rim, outlined
	_gradient(board_points(3.0), board[1].lightened(0.1), board[2].lerp(board[1], 0.4))
	_fill(_half(board_points(3.0)), Color(1, 1, 1, 0.1)) # light from the left
	_line(board_points(6.5), Color(board[0], 0.55), 1.6) # the piping
	match group:
		"enlisted":
			_chevrons(marks_of(grade), mark)
		"cadet":
			_rect(Rect2(28, 54, 40, 9), mark[1], mark[0])
		"company":
			_rect(Rect2(44.5, 30, 7, 56), mark[1], mark[0])
			_stars(marks_of(grade), 7.5, mark, 0.0)
		"field":
			_rect(Rect2(33, 30, 6, 56), mark[1], mark[0])
			_rect(Rect2(57, 30, 6, 56), mark[1], mark[0])
			_stars(marks_of(grade), 8.0, mark, 0.0)
		"general":
			_stars(marks_of(grade), 10.0, mark, 0.0)
	_circle(Vector2(48, 19), 5.0, BUTTON[1])
	draw_circle(Vector2(46.8, 17.8), 2.0, BUTTON[0])


## The board, `inset` units inside the outer one: pointed at the top (the collar end, its button),
## square at the bottom with rounded corners.
static func board_points(inset: float) -> Array:
	var l := 23.0 + inset
	var r := 73.0 - inset
	var top := 4.0 + inset * 1.15
	var bottom := 92.0 - inset
	var shoulder := 22.0 + inset * 0.3
	var out := [Vector2(48, top), Vector2(r, shoulder)]
	var rad := 6.0
	for i in range(0, 5):
		var a := PI * 0.5 * i / 4.0
		out.append(Vector2(r - rad + cos(a) * rad, bottom - rad + sin(a) * rad))
	for i in range(0, 5):
		var a := PI * 0.5 + PI * 0.5 * i / 4.0
		out.append(Vector2(l + rad + cos(a) * rad, bottom - rad + sin(a) * rad))
	out.append(Vector2(l, shoulder))
	return out


static func _half(pts: Array) -> Array:
	return pts.filter(func(p: Vector2) -> bool: return p.x <= 48.0)


## n chevrons (^) stacked from the bottom.
func _chevrons(n: int, mark: Array) -> void:
	var count := clampi(n, 1, 5)
	var gap := 10.5 if count >= 4 else 12.5
	var h := 7.0 if count >= 4 else 8.0
	var y0 := 84.0 - (5 - count) * 3.0 # fewer chevrons sit a little higher
	for i in count:
		var y := y0 - i * gap
		var pts := [Vector2(29, y), Vector2(48, y - 9), Vector2(67, y), Vector2(67, y - h), Vector2(48, y - 9 - h), Vector2(29, y - h)]
		_poly(pts, mark[1], 2.5)
		_fill([pts[5], pts[4], Vector2(48, y - 9 - h * 0.45), Vector2(29, y - h * 0.45)], Color(mark[0], 0.85))


## n stars stacked from the bottom on the board's middle.
func _stars(n: int, r: float, mark: Array, dx: float) -> void:
	var count := clampi(n, 1, 4)
	var gap := r * 2.05
	var y0 := 80.0
	if count * gap > 54.0:
		gap = 54.0 / count
	for i in count:
		var c := Vector2(48 + dx, y0 - i * gap)
		_poly(star_points(c, r, r * 0.45), mark[1], 2.5)
		_fill(star_points(c + Vector2(-0.6, -0.8), r * 0.45, r * 0.2), Color(mark[0], 0.95))


func _gradient(pts: Array, top: Color, bottom: Color) -> void:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - 6.0) / 86.0, 0.0, 1.0)))
	draw_polygon(PackedVector2Array(pts), cols)


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


func _line(pts: Array, color: Color, w: float) -> void:
	var packed := PackedVector2Array(pts)
	packed.append(pts[0])
	draw_polyline(packed, color, w, true)


func _rect(r: Rect2, color: Color, light: Color) -> void:
	draw_rect(r.grow(2.2), OUTLINE)
	draw_rect(r, color)
	draw_rect(Rect2(r.position, Vector2(r.size.x * 0.45, r.size.y)) if r.size.y > r.size.x else Rect2(r.position, Vector2(r.size.x, r.size.y * 0.45)), Color(light, 0.7))


func _circle(c: Vector2, r: float, color: Color) -> void:
	draw_circle(c, r + 2.2, OUTLINE)
	draw_circle(c, r, color)


static func star_points(c: Vector2, outer: float, inner: float, points: int = 5, rot: float = -PI / 2) -> Array:
	var out := []
	for i in points * 2:
		out.append(c + Vector2.from_angle(rot + PI * i / points) * (outer if i % 2 == 0 else inner))
	return out
