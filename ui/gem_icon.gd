extends Control
## A ngọc khảm drawn in code (original art, in the style of ui/glyph_icon.gd: bright faceted shapes
## in a dark outline): each type its own colour AND cut, so the type reads without the colour —
## hp a green heart, damage a red blade-cut (a tall pointed diamond), defense a blue hexagonal
## shield cut, critical a yellow star cut; an unknown type a grey round cabochon. The level is drawn
## small on the gem (a dark disc with the number at the bottom right); higher levels glow brighter
## behind (from the middle of the range) with sparkles. Drawn on a 96 × 96 canvas scaled into the
## control's square and centred. make() for a layout; paint() draws one into any CanvasItem.

const GemModel := preload("res://screens/home/gem_model.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")

const OUTLINE := Color(0.07, 0.07, 0.14)
const W := 5.0

@export var gem_type := "hp":
	set(v):
		gem_type = v
		queue_redraw()
@export var level := 1:
	set(v):
		level = v
		queue_redraw()
## Draw the level number (off where a bigger number says it beside the gem).
@export var show_level := true:
	set(v):
		show_level = v
		queue_redraw()
## The level the glow tops out at (the catalog's highest level of the type).
var glow_top := 10


## A `px` square gem that ignores the mouse.
static func make(type_id: String, gem_level: int, px: int, with_level: bool = true) -> Control:
	var g = load("res://ui/gem_icon.gd").new()
	g.name = "GemIcon"
	g.gem_type = type_id
	g.level = gem_level
	g.show_level = with_level
	var top := GemModel.max_level(PlayerState.catalog, type_id) if PlayerState.catalog != null else 0
	g.glow_top = top if top > 1 else 10 # the look only: without the catalog's levels, 10
	g.custom_minimum_size = Vector2(px, px)
	g.size = Vector2(px, px)
	g.mouse_filter = MOUSE_FILTER_IGNORE
	g.size_flags_horizontal = SIZE_SHRINK_CENTER
	g.size_flags_vertical = SIZE_SHRINK_CENTER
	return g


func _init() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := minf(size.x, size.y) / 96.0
	if s <= 0.0:
		return
	var origin := (size - Vector2(96, 96) * s) / 2.0
	draw_set_transform(origin, 0.0, Vector2(s, s))
	var k := clampf(float(level - 1) / maxf(glow_top - 1, 1), 0.0, 1.0)
	paint(self, gem_type, k)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if show_level and level >= 1:
		_level_badge(origin, s)


## Draws a gem of `type_id` on the 96 canvas of `ci`; `k` 0..1 how high its level is in the range
## (the glow and the sparkles).
static func paint(ci: CanvasItem, type_id: String, k: float = 0.0) -> void:
	var main := GemModel.color(type_id)
	if k >= 0.45:
		for i in 8:
			ci.draw_circle(Vector2(48, 48), 47.0 - i * 4.0, Color(main.lightened(0.3), (k - 0.35) * 0.09), true, -1.0, true)
	match type_id:
		"hp": _heart(ci, main)
		"damage": _blade(ci, main)
		"defense": _hexagon(ci, main)
		"critical": _star(ci, main)
		_: _round(ci, main)
	var spots := [Vector2(20, 22), Vector2(78, 18), Vector2(84, 70)]
	var n := 0 if k < 0.6 else (1 if k < 0.8 else (2 if k < 0.99 else 3))
	for i in n:
		_sparkle(ci, spots[i], 7.0 - i)


func _level_badge(origin: Vector2, s: float) -> void:
	var r := maxf(9.0, 15.0 * s)
	var at := origin + Vector2(80, 80) * s
	at = Vector2(minf(at.x, size.x - r), minf(at.y, size.y - r))
	draw_circle(at, r, OUTLINE, true, -1.0, true)
	draw_circle(at, r - maxf(1.5, r * 0.14), Color(0.16, 0.18, 0.3), true, -1.0, true)
	var font := LobbyUi.bold()
	var fs := int(r * (1.25 if level < 10 else 1.0))
	var text := str(level)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, at + Vector2(-w.x / 2.0, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


# ── Cuts ────────────────────────────────────────────────────────────────────

static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color) -> void:
	for o in Geometry2D.offset_polygon(pts, W, Geometry2D.JOIN_ROUND):
		ci.draw_colored_polygon(o, OUTLINE)
	ci.draw_colored_polygon(pts, fill)


static func _fill(ci: CanvasItem, pts: Array, fill: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), fill)


## hp: a faceted heart.
static func _heart(ci: CanvasItem, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := i * TAU / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(Vector2(48, 46) + Vector2(x, y) * 2.55)
	_poly(ci, pts, c)
	var mid := Vector2(48, 50)
	var top := Vector2(48, 30)
	var bot := Vector2(48, 86)
	_fill(ci, [Vector2(14, 34), Vector2(28, 16), top, mid], c.lightened(0.35))
	_fill(ci, [top, Vector2(68, 16), Vector2(82, 34), mid], c.lightened(0.12))
	_fill(ci, [Vector2(14, 34), mid, bot, Vector2(26, 64)], c.darkened(0.1))
	_fill(ci, [Vector2(82, 34), Vector2(70, 64), bot, mid], c.darkened(0.35))
	ci.draw_line(Vector2(24, 26), Vector2(32, 20), Color(1, 1, 1, 0.75), 3.5, true)


## damage: a tall pointed blade-cut diamond.
static func _blade(ci: CanvasItem, c: Color) -> void:
	var top := Vector2(48, 4)
	var l := Vector2(22, 46)
	var r := Vector2(74, 46)
	var bot := Vector2(48, 92)
	var cl := Vector2(40, 46)
	var cr := Vector2(56, 46)
	_poly(ci, PackedVector2Array([top, r, bot, l]), c)
	_fill(ci, [top, cl, l], c.lightened(0.4))
	_fill(ci, [top, cr, cl], c.lightened(0.2))
	_fill(ci, [top, r, cr], c.darkened(0.15))
	_fill(ci, [l, cl, bot], c.darkened(0.05))
	_fill(ci, [cl, cr, bot], c.darkened(0.25))
	_fill(ci, [cr, r, bot], c.darkened(0.45))
	ci.draw_line(Vector2(42, 18), Vector2(32, 40), Color(1, 1, 1, 0.75), 3.0, true)


## defense: a hexagonal shield cut with its table.
static func _hexagon(ci: CanvasItem, c: Color) -> void:
	var outer := PackedVector2Array()
	var inner: Array = []
	for i in 6:
		var a := -PI / 2 + i * TAU / 6.0
		outer.append(Vector2(48, 48) + Vector2.from_angle(a) * 44.0)
		inner.append(Vector2(48, 48) + Vector2.from_angle(a) * 22.0)
	_poly(ci, outer, c)
	var shades := [c.lightened(0.4), c.lightened(0.15), c.darkened(0.2), c.darkened(0.4), c.darkened(0.1), c.lightened(0.25)]
	for i in 6:
		var j := (i + 1) % 6
		_fill(ci, [outer[i], outer[j], inner[j], inner[i]], shades[i])
	_fill(ci, inner, c.lightened(0.1))
	ci.draw_line(inner[5], inner[0], Color(1, 1, 1, 0.8), 3.0, true)


## critical: a five-point star cut.
static func _star(ci: CanvasItem, c: Color) -> void:
	var centre := Vector2(48, 50)
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5.0
		pts.append(centre + Vector2.from_angle(a) * (46.0 if i % 2 == 0 else 20.0))
	_poly(ci, pts, c)
	for i in 10:
		var j := (i + 1) % 10
		var shade := c.lightened(0.35) if i % 2 == 0 else c.darkened(0.2)
		if i >= 5:
			shade = shade.darkened(0.15)
		_fill(ci, [centre, pts[i], pts[j]], shade)
	ci.draw_circle(centre, 6.0, c.lightened(0.6), true, -1.0, true)
	ci.draw_line(Vector2(44, 14), Vector2(41, 30), Color(1, 1, 1, 0.8), 3.0, true)


## An unknown type: a round cabochon.
static func _round(ci: CanvasItem, c: Color) -> void:
	ci.draw_circle(Vector2(48, 48), 40.0 + W, OUTLINE, true, -1.0, true)
	ci.draw_circle(Vector2(48, 48), 40.0, c, true, -1.0, true)
	ci.draw_circle(Vector2(40, 38), 18.0, c.lightened(0.3), true, -1.0, true)
	ci.draw_circle(Vector2(34, 32), 6.0, Color(1, 1, 1, 0.7), true, -1.0, true)


static func _sparkle(ci: CanvasItem, at: Vector2, s: float) -> void:
	var col := Color(1, 1, 0.92, 0.95)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 1.6), at + Vector2(s * 0.35, 0), at + Vector2(0, s * 1.6), at + Vector2(-s * 0.35, 0)]), col)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 1.6, 0), at + Vector2(0, s * 0.35), at + Vector2(s * 1.6, 0), at + Vector2(0, -s * 0.35)]), col)
