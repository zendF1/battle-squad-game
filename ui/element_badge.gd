extends Control
## A unit's element (ngũ hành, GET /gamedata elements) as a round badge with its glyph, drawn in
## code (original art): Kim a lightning bolt (sấm sét: a steel-silver disc, an electric yellow bolt), Mộc a leaf sprig
## (green), Thủy a droplet with a wave (blue), Hỏa a flame (orange-red), Thổ a stacked rock
## mountain (amber-brown); an element this client has no look for draws a neutral disc with the
## first letter of its game data name. The badge is a single-focus element: the glyph sits at the
## disc's exact centre (its polygons' bounding box centred on it, glyph_bounds()).
## Only the look is mapped by elementId (LOOKS / glyph()); names and rules come from the game data.
## Use make(id, diameter) in a layout, or draw_badge() from any CanvasItem's _draw (the match's
## name bars).

const GameData := preload("res://autoload/game_data_model.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")

## elementId -> {disc (the badge's colour), light (its lit top), rim, glyph (the glyph's main
## colour), shade (its shaded facets), ink (outlines)}.
const LOOKS := {
	"metal": {"disc": Color(0.36, 0.42, 0.54), "light": Color(0.74, 0.8, 0.9), "rim": Color(0.88, 0.9, 0.95),
		"glyph": Color(1.0, 0.93, 0.36), "shade": Color(1.0, 1.0, 0.86), "ink": Color(0.1, 0.11, 0.2)},
	"wood": {"disc": Color(0.16, 0.55, 0.27), "light": Color(0.46, 0.84, 0.42), "rim": Color(0.72, 0.95, 0.55),
		"glyph": Color(0.72, 0.97, 0.42), "shade": Color(0.36, 0.74, 0.22), "ink": Color(0.05, 0.2, 0.08)},
	"water": {"disc": Color(0.13, 0.42, 0.88), "light": Color(0.42, 0.76, 1.0), "rim": Color(0.7, 0.9, 1.0),
		"glyph": Color(0.9, 0.97, 1.0), "shade": Color(0.3, 0.66, 1.0), "ink": Color(0.04, 0.14, 0.38)},
	"fire": {"disc": Color(0.86, 0.26, 0.1), "light": Color(1.0, 0.56, 0.2), "rim": Color(1.0, 0.8, 0.45),
		"glyph": Color(1.0, 0.86, 0.3), "shade": Color(1.0, 0.98, 0.78), "ink": Color(0.36, 0.06, 0.02)},
	"earth": {"disc": Color(0.6, 0.38, 0.14), "light": Color(0.86, 0.62, 0.3), "rim": Color(0.98, 0.82, 0.5),
		"glyph": Color(0.98, 0.84, 0.58), "shade": Color(0.78, 0.56, 0.3), "ink": Color(0.24, 0.12, 0.03)},
}
const NEUTRAL := {"disc": Color(0.36, 0.38, 0.48), "light": Color(0.6, 0.62, 0.72), "rim": Color(0.82, 0.84, 0.9),
	"glyph": Color(0.95, 0.96, 1.0), "shade": Color(0.7, 0.72, 0.8), "ink": Color(0.1, 0.1, 0.16)}
## The glyph's half size against the disc's radius.
const GLYPH_K := 0.6

@export var element_id := "":
	set(v):
		element_id = v
		queue_redraw()

static var _glyphs := {} # elementId -> glyph() (centred)


## A badge of `diameter` px for element_id (an empty id still reserves the space but draws nothing).
static func make(id: String, diameter: int = 32):
	var b = new()
	b.element_id = id
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.size = Vector2(diameter, diameter)
	b.mouse_filter = MOUSE_FILTER_IGNORE
	b.size_flags_horizontal = SIZE_SHRINK_CENTER
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	if id != "":
		b.tooltip_text = GameData.element_name(id)
	return b


## A name with its element's badge before it: [badge, label, a spacer as wide as the badge] in a
## centred row, so the name itself stays dead centre (balanced; false: no spacer). Update it with
## set_row_element().
static func name_row(label: Control, id: String, diameter: int, gap: int = 8, balanced: bool = true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", gap)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var b = make(id, diameter)
	b.name = "ElementBadge"
	row.add_child(b)
	row.add_child(label)
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.custom_minimum_size = Vector2(diameter, diameter) if balanced else Vector2.ZERO
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	set_row_element(row, id)
	return row


## A clipped name in a name_row(): as wide as its text, at most max_w (then trimmed with "…"), so
## the badge sits right beside it.
static func fit_label(label: Label, max_w: float) -> void:
	var font: Font = label.get_theme_font("font")
	var fs: int = label.get_theme_font_size("font_size")
	var w := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0
	label.custom_minimum_size.x = minf(ceilf(w), max_w)


## Shows element id's badge in a name_row() (none: the badge and its spacer hidden).
static func set_row_element(row: Node, id: String) -> void:
	var b = row.get_node_or_null("ElementBadge")
	if b == null:
		return
	b.element_id = id
	b.tooltip_text = GameData.element_name(id) if id != "" else ""
	b.visible = id != ""
	var spacer = row.get_node_or_null("Spacer")
	if spacer != null:
		spacer.visible = id != "" and spacer.custom_minimum_size.x > 0.0


## The look of an element id (NEUTRAL for one without its own).
static func look(id: String) -> Dictionary:
	return LOOKS.get(id, NEUTRAL)


## The element has its own glyph.
static func has_glyph(id: String) -> bool:
	return LOOKS.has(id)


func _init() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	if element_id == "":
		return
	draw_badge(self, size / 2.0, minf(size.x, size.y) / 2.0, element_id)


## Draws the badge of element_id centred on `centre`, `radius` px (ci: any CanvasItem in its _draw).
static func draw_badge(ci: CanvasItem, centre: Vector2, radius: float, id: String, alpha: float = 1.0) -> void:
	if id == "" or radius <= 0.5:
		return
	var l := look(id)
	var a := alpha
	ci.draw_circle(centre, radius, Color(l["ink"], 0.95 * a))
	ci.draw_circle(centre, radius * 0.9, Color(l["rim"], a))
	ci.draw_circle(centre, radius * 0.8, Color(l["disc"], a))
	# the disc lit from the top left: a lighter offset disc fading into it
	for i in 4:
		var f := 0.62 - i * 0.12
		ci.draw_circle(centre + Vector2(-0.16, -0.2) * radius * (1.0 - f), radius * f, Color(l["light"], 0.16 * a))
	# a glossy sliver along the top
	var gloss := PackedVector2Array()
	for i in 13:
		var t := lerpf(PI * 1.12, PI * 1.88, i / 12.0)
		gloss.append(centre + Vector2(cos(t), sin(t)) * radius * 0.7)
	for i in 13:
		var t := lerpf(PI * 1.88, PI * 1.12, i / 12.0)
		gloss.append(centre + Vector2(cos(t) * 0.62, sin(t) * 0.42 - 0.16) * radius * 0.7)
	ci.draw_colored_polygon(gloss, Color(1, 1, 1, 0.18 * a))
	if not has_glyph(id):
		_letter(ci, centre, radius, id, l, a)
		return
	var k := radius * GLYPH_K
	var ink_w := maxf(1.0, radius * 0.07)
	for part in glyph(id):
		var pts := PackedVector2Array()
		for p in part["pts"]:
			pts.append(centre + p * k)
		match str(part["kind"]):
			"fill":
				ci.draw_colored_polygon(pts, Color(l[part["color"]], a))
			"outline":
				var closed := pts.duplicate()
				closed.append(pts[0])
				ci.draw_polyline(closed, Color(l["ink"], a), ink_w, true)
			"line":
				ci.draw_polyline(pts, Color(l[part["color"]], a), maxf(1.0, radius * float(part.get("width", 0.07))), true)
			"spark":
				ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.92 * a))


## A neutral badge's letter: the element's game data name's first letter, centred.
static func _letter(ci: CanvasItem, centre: Vector2, radius: float, id: String, l: Dictionary, a: float) -> void:
	var font := LobbyUi.bold()
	var letter := GameData.element_name(id).left(1).to_upper()
	var px := int(radius * 1.05)
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var base := centre + Vector2(-w / 2.0, font.get_ascent(px) * 0.5 - font.get_descent(px) * 0.5 + px * 0.06)
	ci.draw_string_outline(font, base, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(2, int(radius * 0.14)), Color(l["ink"], a))
	ci.draw_string(font, base, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(l["glyph"], a))


## The glyph of an element as drawing parts in unit coordinates (about -1..1, y down), its
## bounding box centred on (0, 0): [{kind: fill / outline / line / spark, pts, color (a LOOKS
## key), width}]; [] for an element without one.
static func glyph(id: String) -> Array:
	if _glyphs.has(id):
		return _glyphs[id]
	var parts: Array = []
	match id:
		"metal": parts = _bolt()
		"wood": parts = _sprig()
		"water": parts = _drop()
		"fire": parts = _flame()
		"earth": parts = _rocks()
	parts = _centred(parts)
	_glyphs[id] = parts
	return parts


## The bounding box of a glyph's parts (unit coordinates): centred on (0, 0) for every glyph.
static func glyph_bounds(id: String) -> Rect2:
	var parts := glyph(id)
	if parts.is_empty():
		return Rect2()
	var r := Rect2(parts[0]["pts"][0], Vector2.ZERO)
	for part in parts:
		for p in part["pts"]:
			r = r.expand(p)
	return r


static func _centred(parts: Array) -> Array:
	if parts.is_empty():
		return parts
	var r := Rect2(parts[0]["pts"][0], Vector2.ZERO)
	for part in parts:
		for p in part["pts"]:
			r = r.expand(p)
	var off := -r.get_center()
	for part in parts:
		var moved := PackedVector2Array()
		for p in part["pts"]:
			moved.append(p + off)
		part["pts"] = moved
	return parts


static func _fill(pts: PackedVector2Array, color: String = "glyph") -> Dictionary:
	return {"kind": "fill", "pts": pts, "color": color}


static func _outline(pts: PackedVector2Array) -> Dictionary:
	return {"kind": "outline", "pts": pts, "color": "ink"}


## A 4-point sparkle at c.
static func _spark(c: Vector2, r: float) -> Dictionary:
	var pts := PackedVector2Array()
	for i in 8:
		var ang := TAU * i / 8.0 - PI / 2.0
		pts.append(c + Vector2.from_angle(ang) * (r if i % 2 == 0 else r * 0.28))
	return {"kind": "spark", "pts": pts, "color": "glyph"}


## Kim (sấm sét): a bold zig-zag lightning bolt in electric yellow, a white-hot streak down its
## upper part.
static func _bolt() -> Array:
	var bolt := PackedVector2Array([Vector2(-0.2, -0.94), Vector2(0.56, -0.94), Vector2(0.2, -0.26), Vector2(0.66, -0.26),
		Vector2(-0.4, 0.98), Vector2(-0.06, 0.08), Vector2(-0.6, 0.08)])
	var streak := PackedVector2Array([Vector2(-0.08, -0.82), Vector2(0.2, -0.82), Vector2(-0.06, -0.18), Vector2(-0.34, -0.06)])
	return [_fill(bolt), _fill(streak, "shade"), _outline(bolt)]


## Mộc: a sprig, a curved stem with a leaf each side and one on top.
static func _sprig() -> Array:
	var out: Array = []
	var stem := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		stem.append(Vector2(0.1 * sin(t * PI) - 0.08, lerpf(0.86, -0.3, t)))
	out.append({"kind": "line", "pts": stem, "color": "ink", "width": 0.17})
	out.append({"kind": "line", "pts": stem, "color": "shade", "width": 0.09})
	for leaf in [[Vector2(-0.04, 0.3), -2.45, 0.64], [Vector2(0.02, 0.02), -0.62, 0.66], [Vector2(-0.06, -0.3), -1.62, 0.6]]:
		var pts := _leaf(leaf[0], float(leaf[1]), float(leaf[2]))
		out.append(_fill(pts))
		out.append(_outline(pts))
		var tip: Vector2 = leaf[0] + Vector2.from_angle(float(leaf[1])) * float(leaf[2]) * 0.82
		out.append({"kind": "line", "pts": PackedVector2Array([leaf[0], tip]), "color": "shade", "width": 0.06})
	return out


## A leaf from `base` along angle `ang`, `length` long: a pointed lens.
static func _leaf(base: Vector2, ang: float, length: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir := Vector2.from_angle(ang)
	var nrm := dir.orthogonal()
	for i in 11:
		var t := i / 10.0
		pts.append(base + dir * length * t + nrm * sin(t * PI) * length * 0.3 * (1.0 - 0.25 * t))
	for i in range(9, 0, -1):
		var t := i / 10.0
		pts.append(base + dir * length * t - nrm * sin(t * PI) * length * 0.3 * (1.0 - 0.25 * t))
	return pts


## Thủy: a droplet (a round bottom drawn up to a point) with a wave across its lower part.
static func _drop() -> Array:
	var c := Vector2(0, 0.28)
	var r := 0.6
	var outline := _drop_shape(c, r, -0.92)
	# the part of the drop under a wavy line at y0: the wave left to right, then the circle back
	var y0 := 0.2
	var s0 := clampf((y0 - c.y) / r, -1.0, 1.0)
	var a0 := asin(s0) # the circle's angle (y down) where the wave meets its right side
	var half := cos(a0) * r
	var wave := PackedVector2Array()
	for i in 15:
		var t := i / 14.0
		wave.append(Vector2(lerpf(-half, half, t), y0 - sin(t * TAU) * 0.07))
	for i in range(1, 20):
		var ang := lerpf(a0, PI - a0, i / 20.0)
		wave.append(c + Vector2(cos(ang), sin(ang)) * r)
	var shine := _drop_shape(Vector2(-0.24, 0.06), 0.1, -0.22)
	return [_fill(outline), _fill(wave, "shade"), _outline(outline), {"kind": "spark", "pts": shine, "color": "glyph"}]


## A drop shape: a circle of radius r at c drawn up to a point at tip_y (the tip, then round the
## circle from the right tangent point under the bottom to the left one).
static func _drop_shape(c: Vector2, r: float, tip_y: float) -> PackedVector2Array:
	var a := acos(clampf(r / (c.y - tip_y), -1.0, 1.0)) # at the centre, from up to a tangent point
	var out := PackedVector2Array([Vector2(c.x, tip_y)])
	var start := -PI / 2.0 + a
	var stop := -PI / 2.0 - a + TAU
	for i in 25:
		var ang := lerpf(start, stop, i / 24.0)
		out.append(c + Vector2(cos(ang), sin(ang)) * r)
	return out


## Hỏa: a flame, an outer tongue licking up to the right and a bright inner one.
static func _flame() -> Array:
	var outer := _tongue(Vector2(0, 0.42), 0.56, 1.42, 0.16)
	var inner := _tongue(Vector2(0.02, 0.44), 0.28, 0.76, 0.08)
	return [_fill(outer), _outline(outer), _fill(inner, "shade")]


## A flame tongue whose round bottom sits on `base`: a belly of half width w, `h` tall to its
## tip, the tip leaning `lean` to the right, a small lick out of its left side.
static func _tongue(base: Vector2, w: float, h: float, lean: float) -> PackedVector2Array:
	var n := 18
	var out := PackedVector2Array()
	var belly := base.y - w * 0.5 # the widest row
	for i in n + 1: # right side, from the belly up to the tip
		var t := i / float(n)
		out.append(Vector2(base.x + _flame_w(t, w) + lean * t * t, lerpf(belly, base.y - h, t)))
	for i in range(n - 1, -1, -1): # left side, from the tip down to the belly
		var t := i / float(n)
		var lick := 0.22 * w * sin((t - 0.3) / 0.3 * PI) if t > 0.3 and t < 0.6 else 0.0
		out.append(Vector2(base.x - _flame_w(t, w) - lick + lean * t * t * 0.4, lerpf(belly, base.y - h, t)))
	for i in range(1, 12): # the round bottom, left to right under the belly
		var ang := lerpf(PI, 0.0, i / 12.0)
		out.append(Vector2(base.x + cos(ang) * w, belly + sin(ang) * w * 0.5))
	return out


## The flame's half width at t (0 the belly .. 1 the tip).
static func _flame_w(t: float, w: float) -> float:
	return w * pow(1.0 - t, 0.85) * (1.0 + 0.25 * sin(t * PI))


## Thổ: a mountain of stacked rocks, two peaks with lit and shaded facets and a boulder in front.
static func _rocks() -> Array:
	var back := PackedVector2Array([Vector2(-0.12, 0.42), Vector2(0.3, -0.5), Vector2(0.5, -0.34), Vector2(0.88, 0.42)])
	var back_shade := PackedVector2Array([Vector2(0.3, -0.5), Vector2(0.5, -0.34), Vector2(0.88, 0.42), Vector2(0.42, 0.42)])
	var front := PackedVector2Array([Vector2(-0.88, 0.42), Vector2(-0.24, -0.72), Vector2(0.04, -0.5), Vector2(0.48, 0.42)])
	var front_shade := PackedVector2Array([Vector2(-0.24, -0.72), Vector2(0.04, -0.5), Vector2(0.48, 0.42), Vector2(-0.08, 0.42)])
	var cap := PackedVector2Array([Vector2(-0.24, -0.72), Vector2(-0.42, -0.38), Vector2(-0.28, -0.44), Vector2(-0.18, -0.34), Vector2(-0.06, -0.46),
		Vector2(0.04, -0.5)])
	var boulder := PackedVector2Array()
	for i in 14:
		var ang := TAU * i / 14.0
		boulder.append(Vector2(-0.52, 0.3) + Vector2(cos(ang) * 0.3, sin(ang) * 0.2 - (0.04 if sin(ang) < 0 else 0.0)))
	var boulder_top := PackedVector2Array()
	for i in 8:
		var ang := lerpf(PI * 1.05, PI * 1.95, i / 7.0)
		boulder_top.append(Vector2(-0.52, 0.3) + Vector2(cos(ang) * 0.24, sin(ang) * 0.16))
	return [_fill(back), _fill(back_shade, "shade"), _outline(back),
		_fill(front), _fill(front_shade, "shade"), _fill(cap, "light"), _outline(front),
		_fill(boulder, "shade"), _fill(boulder_top), _outline(boulder)]
