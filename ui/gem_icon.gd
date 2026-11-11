extends Control
## A ngọc khảm drawn in code (original art, in the style of ui/glyph_icon.gd: bright faceted shapes
## in a dark outline): each type its own colour AND cut, so the type reads without the colour —
## hp a green heart, damage a red blade-cut (a tall pointed diamond), defense a blue hexagonal
## shield cut, critical a yellow star cut; an unknown type a grey round cabochon. No number on it:
## the level shows as the upgrade aura a piece gets as its +level rises (screens/home/upgrade_aura.gd,
## the rounded square of the list icons, behind the gem), on the step GemModel.aura_step() gives
## the level (level 1 a faint green outline, level 10 the full red fire). Drawn on a 96 × 96 canvas
## scaled into the control's square and centred (inside the aura's line when it shows). make() for
## a layout; paint() draws one into any CanvasItem.

const GemModel := preload("res://screens/home/gem_model.gd")
const UpgradeAura := preload("res://screens/home/upgrade_aura.gd")

const OUTLINE := Color(0.07, 0.07, 0.14)
const W := 5.0
## The gem's share of the square inside its aura (the line runs round it).
const AURA_FIT := 0.78

@export var gem_type := "hp":
	set(v):
		gem_type = v
		queue_redraw()
@export var level := 1:
	set(v):
		level = v
		_sync_aura()
		queue_redraw()
## Show the level's aura (off for a gem that stands for its type, not a level).
@export var aura := true:
	set(v):
		aura = v
		_sync_aura()
		queue_redraw()
## The level the aura tops out at (the catalog's highest level of the type).
var glow_top := 10:
	set(v):
		glow_top = v
		_sync_aura()

var _aura # screens/home/upgrade_aura.gd, made when first shown


## A `px` square gem that ignores the mouse; with_aura false: the plain gem (a type picker).
static func make(type_id: String, gem_level: int, px: int, with_aura: bool = true) -> Control:
	var g = load("res://ui/gem_icon.gd").new()
	g.name = "GemIcon"
	g.gem_type = type_id
	g.aura = with_aura
	g.custom_minimum_size = Vector2(px, px)
	g.size = Vector2(px, px)
	var top := GemModel.max_level(PlayerState.catalog, type_id) if PlayerState.catalog != null else 0
	g.glow_top = top if top > 1 else 10 # the look only: without the catalog's levels, 10
	g.level = gem_level
	g.mouse_filter = MOUSE_FILTER_IGNORE
	g.size_flags_horizontal = SIZE_SHRINK_CENTER
	g.size_flags_vertical = SIZE_SHRINK_CENTER
	return g


func _init() -> void:
	resized.connect(_sync_aura)
	resized.connect(queue_redraw)


## The aura step shown ({tier: 0} none).
func aura_step() -> Dictionary:
	return GemModel.aura_step(level, glow_top) if aura else {"tier": 0, "lite": false}


## The aura node (null until one shows).
func aura_node() -> Control:
	return _aura


func _sync_aura() -> void:
	var st := aura_step()
	var side := minf(size.x, size.y)
	if _aura == null and (int(st["tier"]) <= 0 or side <= 0.0):
		return
	if _aura == null:
		_aura = UpgradeAura.new()
		_aura.name = "LevelAura"
		_aura.show_behind_parent = true # under the gem
		add_child(_aura)
	if side > 0.0:
		_aura.shape = UpgradeAura.Shape.RECT
		_aura.pad = snappedf(maxf(4.0, side * 0.07) / side, 0.005)
		_aura.radius = 0.2
		_aura.position = (size - Vector2(side, side)) / 2.0
		_aura.size = Vector2(side, side)
	_aura.step_lite = bool(st["lite"])
	_aura.step_tier = int(st["tier"])


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return
	if int(aura_step()["tier"]) > 0:
		side *= AURA_FIT
	var s := side / 96.0
	var origin := (size - Vector2(96, 96) * s) / 2.0
	draw_set_transform(origin, 0.0, Vector2(s, s))
	paint(self, gem_type)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draws a gem of `type_id` on the 96 canvas of `ci` (its cut and colour; the level is the aura's).
static func paint(ci: CanvasItem, type_id: String) -> void:
	var main := GemModel.color(type_id)
	match type_id:
		"hp": _heart(ci, main)
		"damage": _blade(ci, main)
		"defense": _hexagon(ci, main)
		"critical": _star(ci, main)
		_: _round(ci, main)


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

