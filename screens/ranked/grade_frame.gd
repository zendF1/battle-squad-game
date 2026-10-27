extends Control
## The frame (khung) of a player's badge (rankBadge: last season's final grade) round a player
## card: the card is the control's rect less `window_inset` each side. The real art
## (assets/ranks/frame_<grade>.png, Art.rank_frame()) is sliced with the layout of
## assets/ranks/ranks.json (written by tools/import_rank_art.gd: window, seat, stretch runs): drawn
## at one scale k (card width / window width when only stretchY runs exist; card height / window
## height when only stretchX; the smaller with both), the card's missing (or surplus) height /
## width shared out over the plain stretch bands, so the ornaments are never squashed; the badge
## sits on the art's medallion (seat). No layout file: the art stretched so its window
## (Art.RANK_FRAME_INSET each side) covers the card. Without the art, a
## placeholder drawn in code, richer by group (grade_badge.gd GROUPS) and by rank inside a group
## (GradeBadge.marks_of: more ornament with each step): enlisted a green border (studs from the
## third chevron); cadets and company officers silver with diamond studs (side diamonds from the
## third star); field officers gold with round studs, side diamonds and, from the third star,
## top / bottom notches; generals a red-and-gold double border, gold stars in the corners (and on
## the sides from the third) and a warm glow growing with each star. A crest at the top centre
## carries the badge (grade_badge.gd; on a plate of the frame's colours for the placeholder)
## (crest_px, 0 none; the real art's medallion always carries it). No badge ("") draws the plain default frame when `plain` (a thin light
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
## The card sits this far inside the control's rect (the code frame draws round the whole rect).
var window_inset := 0.0

const LAYOUT_PATH := "res://assets/ranks/ranks.json"
## The badge's size on the art's medallion, of the medallion's diameter.
const SEAT_FILL := 0.8

static var _layout: Variant = null # ranks.json's "frame" ({} none), read once

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


## The frame layout of assets/ranks/ranks.json ("frame": size, window, seat, stretchX, stretchY in
## texture px), {} when the file is missing or unreadable (read once per run).
static func layout() -> Dictionary:
	if _layout == null:
		_layout = {}
		if FileAccess.file_exists(LAYOUT_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
			if parsed is Dictionary and parsed.get("frame") is Dictionary and _valid(parsed["frame"]):
				_layout = parsed["frame"]
	return _layout


static func _valid(fc: Dictionary) -> bool:
	return fc.get("size") is Array and fc["size"].size() == 2 and fc.get("window") is Array and fc["window"].size() == 4 \
		and float(fc["window"][2]) > 0.0 and float(fc["window"][3]) > 0.0


## How the art of layout `fc` frames a card of size `card` (tools/import_rank_art.gd sliced(), in
## texture px): {k (the ornaments' scale), xs, ys ([[src0, src1, dst0, dst1], ...] per axis, dst
## from the drawn frame's origin), size (the drawn frame), window (the card's rect in it), seat
## (the medallion's centre in it), seat_r}.
static func slices(fc: Dictionary, card: Vector2) -> Dictionary:
	var s := Vector2(float(fc["size"][0]), float(fc["size"][1]))
	var w: Array = fc["window"]
	var win := Rect2(float(w[0]), float(w[1]), float(w[2]), float(w[3]))
	var runs_x: Array = fc.get("stretchX", []) if fc.get("stretchX") is Array else []
	var runs_y: Array = fc.get("stretchY", []) if fc.get("stretchY") is Array else []
	var k := minf(card.x / win.size.x, card.y / win.size.y)
	if runs_x.is_empty() and not runs_y.is_empty():
		k = card.x / win.size.x
	elif runs_y.is_empty() and not runs_x.is_empty():
		k = card.y / win.size.y
	var xs := segments(s.x, runs_x, card.x - win.size.x * k, k)
	var ys := segments(s.y, runs_y, card.y - win.size.y * k, k)
	var x0 := mapped(win.position.x, xs)
	var y0 := mapped(win.position.y, ys)
	var seat: Dictionary = fc.get("seat", {}) if fc.get("seat") is Dictionary else {}
	var sc: Array = seat.get("centre", [s.x / 2.0, win.position.y]) if seat.get("centre") is Array else [s.x / 2.0, win.position.y]
	return {"k": k, "xs": xs, "ys": ys, "size": Vector2(xs[-1][3], ys[-1][3]),
		"window": Rect2(x0, y0, mapped(win.end.x, xs) - x0, mapped(win.end.y, ys) - y0),
		"seat": Vector2(mapped(float(sc[0]), xs), mapped(float(sc[1]), ys)), "seat_r": float(seat.get("radius", 0.0)) * k}


## [[src0, src1, dst0, dst1], ...] along one axis of `length` texture px: the fixed parts × k, the
## runs ([from, to] px) × k plus their share (by length) of `extra` (never under 1 px).
static func segments(length: float, runs: Array, extra: float, k: float) -> Array:
	var cuts := [0.0]
	var run_px := 0.0
	for r in runs:
		cuts.append(float(r[0]))
		cuts.append(float(r[1]))
		run_px += float(r[1]) - float(r[0])
	cuts.append(length)
	var out := []
	var at := 0.0
	for i in cuts.size() - 1:
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		var d := (b - a) * k
		if i % 2 == 1 and run_px > 0.0: # a run
			d = maxf(1.0, d + extra * (b - a) / run_px)
		out.append([a, b, at, at + d])
		at += d
	return out


## A texture coordinate along one axis → its place in the drawn frame.
static func mapped(v: float, segs: Array) -> float:
	for sg in segs:
		if v <= sg[1]:
			return sg[2] + (v - sg[0]) / maxf(0.001, sg[1] - sg[0]) * (sg[3] - sg[2])
	return segs[-1][3]


## The card's rect in this control.
func card_rect() -> Rect2:
	return Rect2(Vector2.ONE * window_inset, size - Vector2.ONE * window_inset * 2.0)


## Where the real art goes for a card rect without a layout file: stretched so its window (inset
## `inset` of the art each side) covers `card` exactly.
static func art_rect(card: Rect2, inset: float = Art.RANK_FRAME_INSET) -> Rect2:
	var k := 1.0 - 2.0 * inset
	var full := card.size / k
	return Rect2(card.position - full * inset, full)


func _sync() -> void:
	queue_redraw()
	var seat := _art_seat()
	var want := grade != "" and (crest_px > 0.0 or not seat.is_empty()) # the art's medallion always carries it
	if want and _badge == null:
		_badge = GradeBadge.make(grade, 0, maxf(crest_px, 24.0))
		add_child(_badge)
	if _badge != null:
		_badge.visible = want
		_badge.grade = grade
		if not seat.is_empty(): # on the art's medallion
			var px: float = seat["px"]
			_badge.size = Vector2(px, px)
			_badge.position = seat["centre"] - Vector2(px, px) / 2.0
		else:
			_badge.size = Vector2(crest_px, crest_px)
			_badge.position = Vector2((size.x - crest_px) / 2.0, -crest_px * 0.55)


## The real art's medallion in this control: {centre, px (the badge's size)}; {} without the art,
## its layout or a seat.
func _art_seat() -> Dictionary:
	if grade == "" or Art.rank_frame(grade) == null:
		return {}
	var fc := layout()
	if fc.is_empty():
		return {}
	var card := card_rect()
	var sl := slices(fc, card.size)
	if float(sl["seat_r"]) <= 0.0:
		return {}
	var origin: Vector2 = card.position - Rect2(sl["window"]).position
	return {"centre": origin + Vector2(sl["seat"]), "px": float(sl["seat_r"]) * 2.0 * SEAT_FILL}


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
		_draw_art(tex)
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


## The real art round the card: sliced by the layout (ornaments at one scale, the plain bands
## stretched), else stretched whole.
func _draw_art(tex: Texture2D) -> void:
	var card := card_rect()
	var fc := layout()
	if fc.is_empty():
		draw_texture_rect(tex, art_rect(card), false)
		return
	var sl := slices(fc, card.size)
	var origin: Vector2 = card.position - Rect2(sl["window"]).position
	var t := tex.get_size() / Vector2(float(fc["size"][0]), float(fc["size"][1])) # layout px → texture px
	for sy in sl["ys"]:
		for sx in sl["xs"]:
			var src := Rect2(sx[0] * t.x, sy[0] * t.y, (sx[1] - sx[0]) * t.x, (sy[1] - sy[0]) * t.y)
			var dst := Rect2(origin + Vector2(sx[2], sy[2]), Vector2(sx[3] - sx[2], sy[3] - sy[2]))
			if src.has_area() and dst.has_area():
				draw_texture_rect_region(tex, dst, src)


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
