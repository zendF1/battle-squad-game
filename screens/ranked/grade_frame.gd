extends Control
## The frame (khung) of a player's badge (rankBadge: last season's final grade) round a player
## card: the card is the control's rect less `window_inset` each side. The real art
## (assets/ranks/frame_<grade>.png, Art.rank_frame()) is sliced with the layout of
## assets/ranks/ranks.json (written by tools/import_rank_art.gd: window, seat, stretch runs): drawn
## at one scale k (card width / window width when only stretchY runs exist; card height / window
## height when only stretchX; the smaller with both), the card's missing (or surplus) height /
## width shared out over the plain stretch bands, so the ornaments are never squashed; the badge
## sits on the art's medallion (seat). No layout file: the art stretched so its window
## (Art.RANK_FRAME_INSET each side) covers the card. Without the art, the frame drawn in code
## (grade_look.gd: richer in shape by tier, and by step inside a tier): a bevelled metal rim with
## corner brackets, a glow, side wings and a bottom plate from the field officers, the generals'
## red band, corner stars and rays; a round medallion on the top edge (laurel round it) carries
## the badge (grade_badge.gd) when crest_px > 0 (the real art's medallion always carries it).
## `back`: the tier's card background (GradeLook.FACE_CODE) behind the code frame, for a frame
## with no card of its own under it (the party slot). No badge ("") draws the plain default frame
## when `plain` (a thin light border, no crest), else nothing (a card that has its own rim).

const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const Art := preload("res://ui/art.gd")
const GradeLook := preload("res://screens/ranked/grade_look.gd")

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
## The card sits this far inside the control's rect (the code frame draws round the card).
var window_inset := 0.0
## The tier's background behind the code frame (a frame without a card under it).
var back := false:
	set(v):
		back = v
		_sync()
## With `back`: the background darkens from this y down (the card's px; the name's band).
var back_foot_y := 100000.0
## The medallion's centre below the rim's top edge (px; negative: higher).
var medal_drop := 0.0

const LAYOUT_PATH := "res://assets/ranks/ranks.json"
## The badge's size on the art's medallion, of the medallion's diameter.
const SEAT_FILL := 0.8
## The code frame's ornament scale: the card's width over the preview's (166 px), at most MAX_K.
const MAX_K := 1.45
## The badge's size on the code medallion at scale 1 (crest_px / MEDAL_PX: the medallion's scale).
const MEDAL_PX := 36.0

static var _layout: Variant = null # ranks.json's "frame" ({} none), read once

var _badge: Control
var _back: ColorRect


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


## A grade with real frame art and its layout (fit() applies).
static func has_art(g: String) -> bool:
	return g != "" and Art.rank_frame(g) != null and not layout().is_empty()


## Any of these grades has real frame art: a row of cards (or slots) then all fit() the same way,
## so mirrored cards keep one size.
static func any_art(grades: Array) -> bool:
	return grades.any(func(g): return g is String and has_art(g))


## How a framed card fits the space it owns (`box`, its own rect: the art's ornaments never cross
## into a neighbour's gap or a header): the art at the largest scale whose OUTER bounds fit `box`,
## the card content (`content`) shrunk uniformly (never grown) to the window of the largest sliced
## frame that fits, the frame centred in the box. {s (the content's scale), card (the window: the shrunk content's rect in box px),
## frame (the art's outer rect)}. Linear in the box, so every card of a row with the same box gets
## the same s and mirrored cards stay mirrored.
static func fit(fc: Dictionary, box: Vector2, content: Vector2) -> Dictionary:
	# the sliced frame scales with its window: size the frame round the full content once, then
	# take the largest scale (never above 1) at which it fits the box
	var full: Vector2 = slices(fc, content)["size"]
	var sc := minf(1.0, minf(box.x / full.x, box.y / full.y))
	var card := content * sc
	var sl := slices(fc, card)
	var frame_size: Vector2 = sl["size"]
	var origin := (box - frame_size) / 2.0
	return {"s": sc, "card": Rect2(origin + Rect2(sl["window"]).position, card), "frame": Rect2(origin, frame_size)}


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
	var code := grade != "" and Art.rank_frame(grade) == null and GradeLook.tier_of(grade) >= 0
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
		elif code: # in the code medallion's well
			var gm := _geom()
			var px: float = MEDAL_PX * float(gm["m"])
			_badge.size = Vector2(px, px)
			_badge.position = Vector2(gm["medal"]) - Vector2(px, px) / 2.0
		else:
			_badge.size = Vector2(crest_px, crest_px)
			_badge.position = Vector2((size.x - crest_px) / 2.0, -crest_px * 0.55)
	_sync_back(code)


## The tier's background behind the code frame (`back`): the face shader on the card's rect.
func _sync_back(code: bool) -> void:
	var on := back and code
	if on and _back == null:
		_back = ColorRect.new()
		_back.name = "Back"
		_back.mouse_filter = MOUSE_FILTER_IGNORE
		_back.show_behind_parent = true
		var mat := ShaderMaterial.new()
		mat.shader = GradeLook.face_shader()
		_back.material = mat
		add_child(_back)
		move_child(_back, 0)
	if _back == null:
		return
	_back.visible = on
	if not on:
		return
	var card := card_rect()
	_back.position = card.position
	_back.size = card.size
	var mat := _back.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", card.size)
	mat.set_shader_parameter("radius", maxf(radius - window_inset, 2.0))
	mat.set_shader_parameter("foot_y", back_foot_y)
	GradeLook.set_face(mat, grade)


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
	if fill.a > 0.0 and (grade != "" or plain) and not (_back != null and _back.visible):
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
	_draw_code()


## The code frame (grade_look.gd's look): the glow, the side wings, the metal rim, the red band
## and the inner line, the corner brackets, the bottom plate and the medallion on the top edge
## (rays behind it, laurel round it, a ribbon under it), all at the ornament scale of the card.
func _draw_code() -> void:
	var l := GradeLook.look(grade)
	if l.is_empty(): # an unknown grade outside the ladder: the plain frame
		draw_style_box(_box(Color(1, 1, 1, 0.22), 3, radius), Rect2(Vector2.ZERO, size))
		return
	var pal := GradeLook.palette(grade)
	var gm := _geom()
	var k: float = gm["k"]
	var card: Rect2 = gm["card"]
	var o: Rect2 = gm["outer"]
	var rw: float = gm["rim"]
	var crad: float = gm["radius"]
	var red: bool = l["red_band"]
	if crest_px > 0.0 and int(l["rays"]) > 0:
		_rays(gm["medal"], 70.0 * float(gm["m"]), int(l["rays"]), o.position.y, pal)
	var glow := float(l["glow"]) * k
	var rings := ceili(glow / 2.0)
	for i in rings: # the glow outside the rim, fading out
		var f := 1.0 - (i + 0.5) / float(rings)
		draw_style_box(_box(Color(pal["mid"], 0.55 * f * f), 2, crad + rw + 2.0 * (i + 1)), o.grow(2.0 * (i + 1)))
	if float(l["wing"]) > 0.0:
		var ww := float(l["wing"]) * k
		var wy := o.get_center().y
		for side in [[o.position.x, -1.0], [o.end.x, 1.0]]:
			var x: float = side[0]
			var d: float = side[1]
			GradeLook.plate(self, PackedVector2Array([Vector2(x, wy - 34 * k), Vector2(x + d * ww, wy - 12 * k),
				Vector2(x + d * (ww - 6 * k), wy), Vector2(x + d * ww, wy + 12 * k), Vector2(x, wy + 34 * k)]),
				pal["red"] if red else pal["lo"], pal, 2.5 * k)
			if l["wing_star"]:
				GradeLook.star(self, Vector2(x + d * (ww - 9 * k), wy), 4.5 * k, pal["hi"])
	var rim := GradeLook.round_rect(card.grow(rw / 2.0 - 1.0), crad + rw / 2.0 - 1.0)
	draw_polyline_colors(rim, GradeLook.metal_colors(pal, rim, o), rw, true)
	var line_in := 3.0 * k
	if red: # the generals' second band, on the card's edge
		draw_polyline(GradeLook.round_rect(card.grow(-1.25 * k), crad - 1.25 * k), pal["red"], 2.5 * k, true)
		line_in += 2.5 * k
	if float(l["inner_line"]) > 0.0:
		draw_polyline(GradeLook.round_rect(card.grow(-line_in), maxf(crad - line_in, 2.0)), Color(pal["hi"], l["inner_line"]), 1.2 * k, true)
	var bl := float(l["bracket_len"]) * k
	var corner := o.grow(2.0 * k)
	for c in [[corner.position, 1.0, 1.0], [Vector2(corner.end.x, corner.position.y), -1.0, 1.0],
			[Vector2(corner.position.x, corner.end.y), 1.0, -1.0], [corner.end, -1.0, -1.0]]:
		_bracket(c[0], c[1], c[2], bl, float(l["bracket_w"]) * k, k, l, pal)
	if float(l["plate"]) > 0.0:
		var pw := float(l["plate"]) * k
		var cx := o.get_center().x
		var by := o.end.y
		GradeLook.plate(self, PackedVector2Array([Vector2(cx - pw / 2, by - 2 * k), Vector2(cx + pw / 2, by - 2 * k),
			Vector2(cx + pw / 2 - 8 * k, by + 14 * k), Vector2(cx - pw / 2 + 8 * k, by + 14 * k)]),
			pal["red"] if red else pal["lo"], pal, 2.5 * k)
		var n := int(l["plate_stars"])
		for i in n:
			GradeLook.star(self, Vector2(cx + (i - (n - 1) / 2.0) * 16 * k, by + 6 * k), 5 * k, pal["hi"])
	if crest_px > 0.0:
		_medallion(gm["medal"], float(gm["m"]), l, pal)


## The code frame's geometry in this control: k (the ornament scale), card (the card's rect),
## radius (its corners), rim (the rim's width), outer (the rim's outer edge), m (the medallion's
## scale), medal (its centre: on the rim's top edge).
func _geom() -> Dictionary:
	var l := GradeLook.look(grade)
	var card := card_rect()
	var k := clampf(card.size.x / 166.0, 1.0, MAX_K)
	var rw := float(l.get("rim", 4.0)) * k
	var outer := card.grow(rw - 1.0)
	var m := crest_px / MEDAL_PX
	return {"k": k, "card": card, "radius": maxf(radius - window_inset, 2.0), "rim": rw, "outer": outer, "m": m,
		"medal": Vector2(outer.get_center().x, outer.position.y + medal_drop)}


## A corner bracket at p (sx, sy: the way into the card), a gem in its bend from the officers on,
## stars past its ends for the generals.
func _bracket(p: Vector2, sx: float, sy: float, bl: float, bw: float, k: float, l: Dictionary, pal: Dictionary) -> void:
	var pts := PackedVector2Array([p + Vector2(0, sy * bl)])
	var a := p + Vector2(0, sy * 6 * k)
	var b := p + Vector2(sx * 6 * k, 0)
	for i in 7: # the rounded bend (a quadratic curve round p)
		var t := i / 6.0
		pts.append(a.lerp(p, t).lerp(p.lerp(b, t), t))
	pts.append(p + Vector2(sx * bl, 0))
	draw_polyline_colors(pts, GradeLook.metal_colors(pal, pts, GradeLook.bounds(pts)), bw, true)
	if l["gems"]:
		GradeLook.diamond(self, p + Vector2(sx, sy) * 5 * k, 5.6 * k, pal["red"] if l["red_band"] else pal["mid"], pal["hi"], k)
	for i in int(l["corner_stars"]) / 2:
		GradeLook.star(self, p + Vector2(sx * (bl + 6 * k), 0), 4 * k, pal["hi"])
		GradeLook.star(self, p + Vector2(0, sy * (bl + 6 * k)), 4 * k, pal["hi"])


## Rays fanning out of the medallion (the generals'), only above the card's top edge.
func _rays(c: Vector2, length: float, n: int, top: float, pal: Dictionary) -> void:
	var above := PackedVector2Array([Vector2(c.x - length * 2, c.y - length * 2), Vector2(c.x + length * 2, c.y - length * 2),
		Vector2(c.x + length * 2, top), Vector2(c.x - length * 2, top)])
	for i in n:
		var a := i * TAU / n
		var tri := PackedVector2Array([c, c + Vector2(cos(a - 0.09), sin(a - 0.09)) * length, c + Vector2(cos(a + 0.09), sin(a + 0.09)) * length])
		for poly in Geometry2D.intersect_polygons(tri, above):
			var cols := PackedColorArray()
			for p in poly:
				cols.append(Color(pal["hi"], 0.55 * (1.0 - clampf(p.distance_to(c) / length, 0.0, 1.0))))
			draw_polygon(poly, cols)


## The round medallion carrying the badge: laurel leaves round it (more with the tier and the
## step), a metal ring, the dark well (the badge on it, a child), a red ribbon under it (generals).
func _medallion(c: Vector2, m: float, l: Dictionary, pal: Dictionary) -> void:
	for i in int(l["leaves"]):
		for side in [-1.0, 1.0]:
			var deg: float = 90.0 + side * (30.0 + i * 26.0)
			var at := c + Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * 31.0 * m
			var leaf := GradeLook.ellipse(Vector2.ZERO, 7.5 * m, 3.2 * m, 16)
			var xf := Transform2D(deg_to_rad(deg + 90.0 - side * 25.0), at)
			leaf = xf * leaf
			draw_colored_polygon(leaf, pal["mid"])
			leaf.append(leaf[0])
			draw_polyline(leaf, pal["lo"], 0.7 * m, true)
	draw_circle(c, 25.0 * m + 1.75 * m, pal["lo"])
	var ring := GradeLook.ellipse(c, 25.0 * m, 25.0 * m, 48)
	ring.append(ring[0])
	draw_polyline_colors(ring, GradeLook.metal_colors(pal, ring, GradeLook.bounds(ring)), 3.5 * m, true)
	draw_circle(c, 20.0 * m, GradeLook.WELL)
	if l["ribbon"]:
		GradeLook.plate(self, PackedVector2Array([c + Vector2(-11, 26) * m, c + Vector2(-6, 42) * m, c + Vector2(0, 36) * m,
			c + Vector2(6, 42) * m, c + Vector2(11, 26) * m]), pal["red"], {"hi": pal["hi"], "mid": pal["hi"], "lo": pal["hi"]}, m)


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
