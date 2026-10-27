extends Control
## The frame (khung) of a player's badge (rankBadge: last season's final grade) round a player
## card, over the control's rect (the card's rect). The real art (assets/ranks/frame_<grade>.png,
## Art.rank_frame(): a 512 × 640 portrait with a transparent window inset Art.RANK_FRAME_INSET each
## side) is stretched so its window covers the rect, its ornaments outside it. Without it, a
## placeholder drawn in code, richer by group (grade_badge.gd GROUPS) and by rank inside a group
## (GradeBadge.marks_of: more ornament with each step): enlisted a green border (studs from the
## third chevron); cadets and company officers silver with diamond studs (side diamonds from the
## third star); field officers gold with round studs, side diamonds and, from the third star,
## top / bottom notches; generals a red-and-gold double border, gold stars in the corners (and on
## the sides from the third) and a warm glow growing with each star. A crest at the top centre
## carries the badge (grade_badge.gd; on a plate of the frame's colours for the placeholder)
## (crest_px, 0 none). No badge ("") draws the plain default frame when `plain` (a thin light
## border, no crest), else nothing (a card that has its own rim).

const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const Art := preload("res://ui/art.gd")

var grade := "":
	set(v):
		grade = v
		_sync()
## Corner radius of the card it frames.
var radius := 22.0
## The crest's badge size (0: no crest).
var crest_px := 52.0
## Draw the plain default frame without a badge.
var plain := false
## A fill under the frame (transparent: none), so a frame with no card under it reads as one.
var fill := Color(0, 0, 0, 0)

var _badge: Control


static func make(g: String, r: float, crest: float, plain_default: bool = false) -> Control:
	var f = load("res://screens/ranked/grade_frame.gd").new()
	f.radius = r
	f.crest_px = crest
	f.plain = plain_default
	f.grade = g
	f.mouse_filter = MOUSE_FILTER_IGNORE
	return f


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(_sync)
	_sync()


## The badge on the crest (null without a badge or a crest).
func badge() -> Control:
	return _badge


## Where the real art goes for a card rect: stretched so its window (inset `inset` of the art each
## side) covers `card` exactly.
static func art_rect(card: Rect2, inset: float = Art.RANK_FRAME_INSET) -> Rect2:
	var k := 1.0 - 2.0 * inset
	var full := card.size / k
	return Rect2(card.position - full * inset, full)


func _sync() -> void:
	queue_redraw()
	var want := grade != "" and crest_px > 0.0
	if want and _badge == null:
		_badge = GradeBadge.make(grade, 0, crest_px)
		add_child(_badge)
	if _badge != null:
		_badge.visible = want
		_badge.grade = grade
		_badge.size = Vector2(crest_px, crest_px)
		_badge.position = Vector2((size.x - crest_px) / 2.0, -crest_px * 0.55)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if fill.a > 0.0 and (grade != "" or plain):
		var bg := StyleBoxFlat.new()
		bg.bg_color = fill
		bg.set_corner_radius_all(int(radius))
		bg.anti_aliasing = true
		draw_style_box(bg, r)
	if grade == "":
		if plain:
			draw_style_box(_box(Color(1, 1, 1, 0.22), 3, radius), r)
		return
	var tex := Art.rank_frame(grade)
	if tex != null: # the real art
		draw_texture_rect(tex, art_rect(r), false)
		return
	var c: Array = GradeBadge.colors(grade)
	var n := GradeBadge.marks_of(grade)
	match GradeBadge.group_of(grade):
		"general":
			for i in 2 + n: # the warm glow outside, wider with each star
				draw_style_box(_box(Color(c[0], 0.2 - i * 0.03), 4, radius + 4 + i * 3), r.grow(4 + i * 3))
			draw_style_box(_box(c[2], 11, radius + 3), r.grow(3))
			draw_style_box(_box(c[1], 8, radius + 2), r.grow(2))
			draw_style_box(_box(c[0], 3, radius - 3), r.grow(-3))
			for p in _corners(r, 4.0):
				_star(p, 12.0 + n, c[0])
			if n >= 3:
				for p in _sides(r):
					_star(p, 10.0, c[0])
		"field":
			draw_style_box(_box(c[2], 9, radius + 2), r.grow(2))
			draw_style_box(_box(c[1], 6, radius + 1), r.grow(1))
			draw_style_box(_box(Color(c[0], 0.9), 2, radius - 4), r.grow(-4))
			for p in _corners(r, 3.0):
				_stud(p, 6.0 + n * 0.5, c)
			for p in _sides(r).slice(2, 4):
				_diamond(p, 8.0, c)
			if n >= 3:
				for p in _sides(r).slice(0, 2):
					_notch(p, c)
		"cadet", "company":
			draw_style_box(_box(c[2], 8, radius + 2), r.grow(2))
			draw_style_box(_box(c[1], 5, radius + 1), r.grow(1))
			draw_style_box(_box(Color(c[0], 0.85), 2, radius - 3), r.grow(-3))
			for p in _corners(r, 3.0):
				_diamond(p, 7.0 + n * 0.5, c)
			if n >= 3:
				for p in _sides(r).slice(2, 4):
					_diamond(p, 6.0, c)
		_:
			draw_style_box(_box(c[2], 7, radius + 1), r.grow(1))
			draw_style_box(_box(c[1], 4, radius), r)
			draw_style_box(_box(Color(c[0], 0.7), 2, radius - 3), r.grow(-3))
			if n >= 3:
				for p in _corners(r, 3.0):
					_stud(p, 3.5 + (n - 3), c)
	if crest_px > 0.0:
		_crest(Vector2(size.x / 2.0, -crest_px * 0.05), c)


## The plate behind the crest's badge: a rounded diamond of the frame's colours.
func _crest(at: Vector2, c: Array) -> void:
	var h := crest_px * 0.62
	var pts := PackedVector2Array([at + Vector2(0, -h), at + Vector2(h * 1.15, 0), at + Vector2(0, h * 0.8), at + Vector2(-h * 1.15, 0)])
	for o in Geometry2D.offset_polygon(pts, 4.0, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(o, GradeBadge.OUTLINE)
	draw_colored_polygon(pts, c[1])
	var inner := Geometry2D.offset_polygon(pts, -4.0, Geometry2D.JOIN_ROUND)
	if not inner.is_empty():
		draw_colored_polygon(inner[0], c[2])


static func _corners(r: Rect2, inset: float) -> Array:
	return [r.position + Vector2(inset, inset), Vector2(r.end.x - inset, r.position.y + inset),
		r.end - Vector2(inset, inset), Vector2(r.position.x + inset, r.end.y - inset)]


## The middles of the top, bottom, left and right edges.
static func _sides(r: Rect2) -> Array:
	var c := r.get_center()
	return [Vector2(c.x, r.position.y), Vector2(c.x, r.end.y), Vector2(r.position.x, c.y), Vector2(r.end.x, c.y)]


func _stud(p: Vector2, rad: float, c: Array) -> void:
	draw_circle(p, rad + 2.5, GradeBadge.OUTLINE)
	draw_circle(p, rad, c[1])
	draw_circle(p + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.4, c[0])


func _diamond(p: Vector2, rad: float, c: Array) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -rad), p + Vector2(rad, 0), p + Vector2(0, rad), p + Vector2(-rad, 0)])
	for o in Geometry2D.offset_polygon(pts, 2.5, Geometry2D.JOIN_MITER):
		draw_colored_polygon(o, GradeBadge.OUTLINE)
	draw_colored_polygon(pts, c[1])
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -rad), p + Vector2(rad * 0.5, -rad * 0.5), p, p + Vector2(-rad * 0.5, -rad * 0.5)]), c[0])


## A small bar across an edge's middle (field officers from the third star).
func _notch(p: Vector2, c: Array) -> void:
	var rr := Rect2(p - Vector2(22, 4), Vector2(44, 8))
	draw_rect(rr.grow(2.5), GradeBadge.OUTLINE)
	draw_rect(rr, c[1])
	draw_rect(Rect2(rr.position, Vector2(rr.size.x, 3)), c[0])


func _star(p: Vector2, rad: float, color: Color) -> void:
	var pts := PackedVector2Array(GradeBadge.star_points(p, rad, rad * 0.45))
	for o in Geometry2D.offset_polygon(pts, 2.5, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(o, GradeBadge.OUTLINE)
	draw_colored_polygon(pts, color)


static var _boxes := {}


static func _box(color: Color, width: int, rad: float) -> StyleBoxFlat:
	var key := [color, width, rad]
	if not _boxes.has(key):
		var b := StyleBoxFlat.new()
		b.draw_center = false
		b.border_color = color
		b.set_border_width_all(width)
		b.set_corner_radius_all(int(maxf(rad, 0.0)))
		b.anti_aliasing = true
		b.corner_detail = 12
		_boxes[key] = b
	return _boxes[key]
