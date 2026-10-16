extends RefCounted
## Code-drawn equipment art (bake source only): one icon per slot × tier on a 128x128
## (weapons are guns: a blaster per tier, plus each character's gun - bazooka, cannon, shock rifle,
## seed launcher - in the normal tiers)
## transparent canvas (bright shapes with a dark rounded outline, like tools/art/icon_painter.gd),
## a white silhouette per slot for empty slots (tinted in the UI), the hexagon slot frames
## (empty, filled, selected) and the dark "+N" badge. tools/bake_art.gd saves them under
## assets/icons/equipment/ (paths in ui/art.gd). The weapon icons are superseded by the imported guns
## (tools/import_guns.gd): bake_art.gd skips them while assets/weapons/weapons.json has a "source".

const Art := preload("res://ui/art.gd")

const OUTLINE := Color(0.07, 0.07, 0.14)
const W := 5.0
const GOLD := Color(1.0, 0.8, 0.22)
const LEATHER := Color(0.48, 0.3, 0.17)

## tier -> main, light, dark, trim (normal: Sắt grey, Thép blue steel, Mithril teal, Rồng red
## with gold; crafted: Bạc, Vàng, Titan, Kim cương).
const TIERS := {
	"iron": [Color(0.6, 0.62, 0.66), Color(0.84, 0.86, 0.9), Color(0.4, 0.42, 0.47), LEATHER],
	"steel": [Color(0.42, 0.58, 0.82), Color(0.72, 0.84, 0.97), Color(0.24, 0.35, 0.56), Color(0.8, 0.83, 0.9)],
	"mithril": [Color(0.2, 0.72, 0.7), Color(0.62, 0.96, 0.9), Color(0.08, 0.44, 0.47), Color(0.85, 0.96, 1.0)],
	"dragon": [Color(0.82, 0.18, 0.16), Color(1.0, 0.5, 0.38), Color(0.5, 0.07, 0.1), GOLD],
	"silver": [Color(0.8, 0.83, 0.9), Color(0.98, 0.99, 1.0), Color(0.55, 0.58, 0.68), Color(0.52, 0.74, 1.0)],
	"gold": [Color(1.0, 0.76, 0.2), Color(1.0, 0.94, 0.58), Color(0.8, 0.47, 0.08), Color(0.92, 0.26, 0.3)],
	"titan": [Color(0.38, 0.36, 0.47), Color(0.63, 0.61, 0.74), Color(0.2, 0.19, 0.27), Color(1.0, 0.56, 0.16)],
	"diamond": [Color(0.55, 0.88, 1.0), Color(0.9, 0.99, 1.0), Color(0.27, 0.57, 0.86), Color(1.0, 1.0, 1.0)],
}

## The canvas of the hexagon frames and where the hexagon sits in it.
const FRAME_SIZE := Art.EQUIP_FRAME_SIZE
const HEX_RADIUS := 70.0
const BADGE_SIZE := Vector2i(52, 32)


## An item icon: slot (weapon, armor, helmet, pants, boots, gloves) in a tier's colours; a
## weapon's kind ("" blaster, bazooka, cannon, rifle, launcher) picks the gun.
static func paint(ci: CanvasItem, slot: String, tier: String, kind: String = "") -> void:
	var t: Array = TIERS.get(tier, TIERS["iron"])
	var pal := {"main": t[0], "light": t[1], "dark": t[2], "trim": t[3], "outline": OUTLINE, "tier": tier}
	if slot == "weapon":
		_gun(ci, kind, pal)
	else:
		_slot(ci, slot, pal)
	_extras(ci, slot, pal)


## The empty-slot silhouette: the slot shape in plain white (the UI tints it).
static func paint_slot(ci: CanvasItem, slot: String) -> void:
	var white := Color(1, 1, 1)
	var pal := {"main": white, "light": white, "dark": Color(0.8, 0.84, 0.92), "trim": Color(0.9, 0.92, 0.97),
		"outline": Color(0, 0, 0, 0), "tier": ""}
	_slot(ci, slot, pal)


static func _slot(ci: CanvasItem, slot: String, pal: Dictionary) -> void:
	match slot:
		"weapon": _gun(ci, "", pal)
		"armor": _vest(ci, pal)
		"helmet": _cap(ci, pal)
		"pants": _pants(ci, pal)
		"boots": _boots(ci, pal)
		"gloves": _gloves(ci, pal)


# ── Helpers ─────────────────────────────────────────────────────────────────

static func _poly(ci: CanvasItem, pts: Array, fill: Color, pal: Dictionary, w: float = W) -> void:
	var packed := PackedVector2Array(pts)
	if w > 0.0 and pal["outline"].a > 0.0:
		for o in Geometry2D.offset_polygon(packed, w, Geometry2D.JOIN_ROUND):
			ci.draw_colored_polygon(o, pal["outline"])
	ci.draw_colored_polygon(packed, fill)


static func _fill(ci: CanvasItem, pts: Array, fill: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), fill)


static func _disc(ci: CanvasItem, c: Vector2, r: float, fill: Color, pal: Dictionary, w: float = W) -> void:
	if w > 0.0 and pal["outline"].a > 0.0:
		ci.draw_circle(c, r + w, pal["outline"], true, -1.0, true)
	ci.draw_circle(c, r, fill, true, -1.0, true)


static func _stroke(ci: CanvasItem, pts: Array, color: Color, width: float, pal: Dictionary, w: float = W) -> void:
	var packed := PackedVector2Array(pts)
	if w > 0.0 and pal["outline"].a > 0.0:
		for o in Geometry2D.offset_polyline(packed, width / 2 + w, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			ci.draw_colored_polygon(o, pal["outline"])
	for o in Geometry2D.offset_polyline(packed, width / 2, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
		ci.draw_colored_polygon(o, color)


## A rectangle with rounded corners as a polygon (outline-able like _poly).
static func _round_rect(r: Rect2, radius: float) -> Array:
	var inner := PackedVector2Array([r.position + Vector2(radius, radius), Vector2(r.end.x - radius, r.position.y + radius),
		r.end - Vector2(radius, radius), Vector2(r.position.x + radius, r.end.y - radius)])
	var out := Geometry2D.offset_polygon(inner, radius, Geometry2D.JOIN_ROUND)
	return Array(out[0]) if not out.is_empty() else []


static func _rrect(ci: CanvasItem, r: Rect2, radius: float, fill: Color, pal: Dictionary, w: float = W) -> void:
	_poly(ci, _round_rect(r, radius), fill, pal, w)


static func _star(c: Vector2, outer: float, inner: float, points: int, rot: float = -PI / 2) -> Array:
	var out := []
	for i in points * 2:
		out.append(c + Vector2.from_angle(rot + PI * i / points) * (outer if i % 2 == 0 else inner))
	return out


static func _ellipse(c: Vector2, rx: float, ry: float, a0: float, a1: float, n: int = 28) -> Array:
	var out := []
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func _sparkle(ci: CanvasItem, c: Vector2, r: float, color: Color = Color(1, 1, 1, 0.95)) -> void:
	_fill(ci, _star(c, r, r * 0.26, 4, 0.0), color)


# ── Slots ───────────────────────────────────────────────────────────────────

## A gun pointing right and a little up, drawn about the canvas centre: "" a blaster pistol,
## "bazooka", "cannon", "rifle" (shock rifle) or "launcher" (seed launcher).
static func _gun(ci: CanvasItem, kind: String, pal: Dictionary) -> void:
	# The long guns are drawn a little smaller so the outline stays inside the canvas.
	ci.draw_set_transform(Vector2(64, 66), -0.26, Vector2.ONE * (1.0 if kind == "" else 0.9))
	match kind:
		"bazooka": _bazooka(ci, pal)
		"cannon": _cannon(ci, pal)
		"rifle": _rifle(ci, pal)
		"launcher": _launcher(ci, pal)
		_: _blaster(ci, pal)
	ci.draw_set_transform(Vector2.ZERO)


## The metal colour of small parts: the tier trim, the dark tone on Sắt (its trim is leather).
static func _metal(pal: Dictionary) -> Color:
	return pal["trim"] if pal["tier"] != "iron" else pal["dark"]


## A chunky blaster pistol: body, barrel, muzzle ring, angled grip, energy cell.
static func _blaster(ci: CanvasItem, pal: Dictionary) -> void:
	_poly(ci, [Vector2(-22, 0), Vector2(-6, 0), Vector2(-2, 34), Vector2(-24, 34)], LEATHER if pal["tier"] != "" else pal["dark"], pal)
	_rrect(ci, Rect2(28, -15, 26, 14), 4, pal["dark"], pal)
	_disc(ci, Vector2(54, -8), 9, _metal(pal), pal)
	_rrect(ci, Rect2(-40, -24, 74, 28), 10, pal["main"], pal)
	_fill(ci, _round_rect(Rect2(-36, -21, 66, 9), 4), Color(pal["light"], 0.75))
	_rrect(ci, Rect2(-28, -6, 30, 7), 3, _metal(pal), pal, 3.0)
	ci.draw_arc(Vector2(-6, 8), 9, 0.2, PI - 0.2, 10, pal["outline"] if pal["outline"].a > 0 else pal["dark"], 4.0, true)


## A shoulder bazooka: long tube, flared muzzle, rear cone, sight and grip.
static func _bazooka(ci: CanvasItem, pal: Dictionary) -> void:
	_rrect(ci, Rect2(-14, 6, 12, 26), 4, LEATHER, pal)
	_poly(ci, [Vector2(-56, -18), Vector2(-46, -12), Vector2(-46, 10), Vector2(-56, 16)], pal["dark"], pal)
	_rrect(ci, Rect2(-46, -14, 92, 26), 12, pal["main"], pal)
	_fill(ci, _round_rect(Rect2(-42, -11, 84, 8), 4), Color(pal["light"], 0.75))
	_poly(ci, [Vector2(40, -14), Vector2(58, -22), Vector2(58, 20), Vector2(40, 12)], pal["dark"], pal)
	for x in [-24.0, 18.0]:
		_rrect(ci, Rect2(x, -16, 8, 30), 3, _metal(pal), pal, 3.0)
	_rrect(ci, Rect2(-8, -28, 18, 12), 3, pal["dark"], pal, 3.0)


## A heavy cannon: thick barrel with bands, muzzle ring, round breech, a wheel under it.
static func _cannon(ci: CanvasItem, pal: Dictionary) -> void:
	_disc(ci, Vector2(-18, 26), 14, LEATHER, pal)
	ci.draw_circle(Vector2(-18, 26), 5, _metal(pal), true, -1.0, true)
	_disc(ci, Vector2(-40, -4), 22, pal["dark"], pal)
	_poly(ci, [Vector2(-40, -26), Vector2(44, -20), Vector2(44, 14), Vector2(-40, 18)], pal["main"], pal)
	_fill(ci, [Vector2(-38, -22), Vector2(42, -17), Vector2(42, -9), Vector2(-38, -12)], Color(pal["light"], 0.7))
	_rrect(ci, Rect2(40, -28, 18, 50), 7, _metal(pal), pal)
	ci.draw_circle(Vector2(52, -3), 8, pal["outline"] if pal["outline"].a > 0 else pal["dark"], true, -1.0, true)
	for x in [-14.0, 14.0]:
		_rrect(ci, Rect2(x, -25, 8, 42), 3, _metal(pal), pal, 3.0)
	ci.draw_circle(Vector2(-56, -4), 6, _metal(pal), true, -1.0, true)


## A shock rifle: stock, long body, barrel with glowing coils, an energy tank with a bolt.
static func _rifle(ci: CanvasItem, pal: Dictionary) -> void:
	var glow: Color = Color(0.55, 0.95, 1.0) if pal["tier"] != "" else pal["light"]
	_poly(ci, [Vector2(-60, -6), Vector2(-30, -10), Vector2(-30, 10), Vector2(-58, 20)], LEATHER if pal["tier"] != "" else pal["dark"], pal)
	_rrect(ci, Rect2(-14, 4, 11, 24), 4, pal["dark"], pal)
	_rrect(ci, Rect2(28, -9, 32, 10), 4, pal["dark"], pal)
	_rrect(ci, Rect2(-34, -16, 64, 22), 8, pal["main"], pal)
	_fill(ci, _round_rect(Rect2(-30, -13, 56, 7), 3), Color(pal["light"], 0.75))
	for x in [34.0, 43.0, 52.0]:
		_rrect(ci, Rect2(x, -13, 5, 18), 2, glow, pal, 2.5)
	_rrect(ci, Rect2(-18, -32, 30, 14), 6, glow, pal, 3.0)
	_fill(ci, [Vector2(-1, -31), Vector2(-8, -24), Vector2(-3, -24), Vector2(-7, -18), Vector2(2, -26), Vector2(-3, -26)], Color(1, 1, 0.6) if pal["tier"] != "" else pal["dark"])


## A seed launcher: wide tube with a bell muzzle, a round hopper holding a seed, a leaf.
static func _launcher(ci: CanvasItem, pal: Dictionary) -> void:
	var seed_c: Color = Color(0.45, 0.8, 0.35) if pal["tier"] != "" else pal["light"]
	_rrect(ci, Rect2(-20, 8, 12, 24), 4, LEATHER if pal["tier"] != "" else pal["dark"], pal)
	_rrect(ci, Rect2(-50, -10, 88, 24), 11, pal["main"], pal)
	_fill(ci, _round_rect(Rect2(-46, -7, 80, 7), 3), Color(pal["light"], 0.75))
	_poly(ci, [Vector2(34, -10), Vector2(56, -20), Vector2(56, 22), Vector2(34, 14)], _metal(pal), pal)
	_disc(ci, Vector2(-10, -22), 16, pal["dark"], pal)
	_disc(ci, Vector2(-10, -24), 9, seed_c, pal, 3.0)
	_poly(ci, [Vector2(-48, -10), Vector2(-62, -30), Vector2(-40, -22)], seed_c, pal, 3.0)
	_rrect(ci, Rect2(4, -12, 7, 28), 3, _metal(pal), pal, 3.0)


## A vest: shoulders, V neck, centre seam, belt, light left side.
static func _vest(ci: CanvasItem, pal: Dictionary) -> void:
	var body := [Vector2(34, 44), Vector2(48, 24), Vector2(64, 40), Vector2(80, 24), Vector2(94, 44), Vector2(94, 106), Vector2(34, 106)]
	_poly(ci, body, pal["main"], pal)
	_fill(ci, [Vector2(38, 46), Vector2(48, 30), Vector2(54, 36), Vector2(54, 102), Vector2(38, 102)], Color(pal["light"], 0.55))
	_disc(ci, Vector2(34, 46), 14, pal["dark"] if pal["tier"] != "" else pal["main"], pal)
	_disc(ci, Vector2(94, 46), 14, pal["dark"] if pal["tier"] != "" else pal["main"], pal)
	ci.draw_circle(Vector2(31, 42), 5, Color(pal["light"], 0.8), true, -1.0, true)
	ci.draw_circle(Vector2(91, 42), 5, Color(pal["light"], 0.6), true, -1.0, true)
	_fill(ci, [Vector2(50, 26), Vector2(64, 54), Vector2(78, 26), Vector2(64, 40)], pal["dark"])
	ci.draw_line(Vector2(64, 56), Vector2(64, 104), pal["dark"], 3.0, true)
	_rrect(ci, Rect2(34, 84, 60, 11), 3, pal["trim"], pal, 3.0)
	_rrect(ci, Rect2(57, 82, 14, 15), 3, GOLD if pal["tier"] != "" else pal["trim"], pal, 3.0)


## A helmet: dome, band, brim, highlight; a crest on Rồng.
static func _cap(ci: CanvasItem, pal: Dictionary) -> void:
	if pal["tier"] == "dragon":
		_poly(ci, [Vector2(52, 34), Vector2(64, 8), Vector2(76, 34)], GOLD, pal, 4.0)
	var dome := _ellipse(Vector2(64, 80), 42, 52, PI, TAU)
	_poly(ci, dome, pal["main"], pal)
	_fill(ci, _ellipse(Vector2(64, 80), 42, 52, PI, PI * 1.38, 12) + [Vector2(54, 80), Vector2(22, 80)], Color(pal["light"], 0.6))
	_rrect(ci, Rect2(24, 66, 80, 12), 3, pal["trim"], pal, 3.0)
	_rrect(ci, Rect2(14, 76, 100, 16), 8, pal["dark"], pal)
	ci.draw_arc(Vector2(64, 80), 32, PI * 1.12, PI * 1.36, 10, Color(1, 1, 1, 0.7 if pal["tier"] != "" else 0.0), 5.0, true)


## Trousers: waistband, two legs, seams.
static func _pants(ci: CanvasItem, pal: Dictionary) -> void:
	var legs := [Vector2(32, 34), Vector2(96, 34), Vector2(102, 106), Vector2(72, 106), Vector2(64, 60), Vector2(56, 106), Vector2(26, 106)]
	_poly(ci, legs, pal["main"], pal)
	_fill(ci, [Vector2(34, 38), Vector2(46, 38), Vector2(40, 102), Vector2(30, 102)], Color(pal["light"], 0.55))
	ci.draw_line(Vector2(64, 40), Vector2(64, 58), pal["dark"], 3.0, true)
	_fill(ci, [Vector2(27, 96), Vector2(56, 96), Vector2(56, 106), Vector2(26, 106)], pal["dark"])
	_fill(ci, [Vector2(72, 96), Vector2(101, 96), Vector2(102, 106), Vector2(72, 106)], pal["dark"])
	_rrect(ci, Rect2(30, 22, 68, 15), 4, pal["trim"], pal)
	_rrect(ci, Rect2(56, 23, 16, 13), 3, GOLD if pal["tier"] != "" else pal["dark"], pal, 3.0)


## A boot from the side: shaft, foot, sole, cuff.
static func _boots(ci: CanvasItem, pal: Dictionary) -> void:
	var boot := [Vector2(40, 26), Vector2(74, 26), Vector2(76, 70), Vector2(100, 78), Vector2(108, 92), Vector2(108, 102), Vector2(36, 102), Vector2(38, 70)]
	_poly(ci, boot, pal["main"], pal)
	_fill(ci, [Vector2(44, 30), Vector2(54, 30), Vector2(54, 96), Vector2(42, 96)], Color(pal["light"], 0.55))
	ci.draw_line(Vector2(76, 72), Vector2(70, 98), pal["dark"], 3.0, true)
	_rrect(ci, Rect2(32, 96, 80, 12), 4, pal["dark"], pal)
	_rrect(ci, Rect2(34, 18, 46, 14), 4, pal["trim"], pal)
	ci.draw_circle(Vector2(96, 86), 4, Color(1, 1, 1, 0.55 if pal["tier"] != "" else 0.0), true, -1.0, true)


## A glove: four fingers, thumb, back of the hand, cuff.
static func _gloves(ci: CanvasItem, pal: Dictionary) -> void:
	for i in 4:
		var x := 42.0 + i * 13.0
		var top := 22.0 if i == 1 or i == 2 else 30.0
		_stroke(ci, [Vector2(x, 58), Vector2(x, top)], pal["main"], 12.0, pal)
	_stroke(ci, [Vector2(38, 74), Vector2(22, 56)], pal["main"], 13.0, pal)
	_rrect(ci, Rect2(34, 48, 56, 42), 12, pal["main"], pal)
	for i in 4: # re-draw the finger roots over the hand's outline
		var x := 42.0 + i * 13.0
		_stroke(ci, [Vector2(x, 56), Vector2(x, 50)], pal["main"], 12.0, pal, 0.0)
	_fill(ci, _round_rect(Rect2(38, 52, 16, 34), 6), Color(pal["light"], 0.55))
	ci.draw_line(Vector2(52, 66), Vector2(80, 66), pal["dark"], 3.0, true)
	_rrect(ci, Rect2(32, 88, 60, 20), 5, pal["trim"], pal)


## Per tier: Rồng gold studs, Vàng / Kim cương sparkles, Titan rivets, Bạc a soft glint.
static func _extras(ci: CanvasItem, slot: String, pal: Dictionary) -> void:
	match pal["tier"]:
		"gold":
			_sparkle(ci, Vector2(100, 30), 12)
			_sparkle(ci, Vector2(28, 98), 7)
		"diamond":
			_sparkle(ci, Vector2(102, 28), 14)
			_sparkle(ci, Vector2(26, 30), 8)
			_sparkle(ci, Vector2(100, 100), 7)
		"silver":
			_sparkle(ci, Vector2(100, 30), 9, Color(1, 1, 1, 0.85))
		"titan":
			var at := {"weapon": [Vector2(84, 58)], "armor": [Vector2(42, 64), Vector2(86, 64)], "helmet": [Vector2(40, 72), Vector2(88, 72)],
				"pants": [Vector2(40, 29), Vector2(88, 29)], "boots": [Vector2(46, 25), Vector2(70, 25)], "gloves": [Vector2(40, 98), Vector2(84, 98)]}
			for p in at.get(slot, []):
				ci.draw_circle(p, 4.5, pal["trim"], true, -1.0, true)
				ci.draw_circle(p, 2.0, Color(1, 0.92, 0.7), true, -1.0, true)
		"dragon":
			if slot != "weapon" and slot != "helmet":
				_sparkle(ci, Vector2(102, 28), 9, Color(1.0, 0.85, 0.4, 0.95))


# ── Frames ──────────────────────────────────────────────────────────────────

## The hexagon (pointy top) centred in FRAME_SIZE, radius r, corners rounded.
static func hexagon(r: float) -> PackedVector2Array:
	var c := Vector2(FRAME_SIZE) / 2
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(c + Vector2.from_angle(-PI / 2 + i * PI / 3) * (r - 8))
	var out := Geometry2D.offset_polygon(pts, 8, Geometry2D.JOIN_ROUND)
	return out[0] if not out.is_empty() else pts


## The slot frame: "hex_empty" (dark, faint rim), "hex_filled" (blue, light rim) or
## "hex_selected" (blue, gold rim and glow).
static func paint_frame(ci: CanvasItem, frame: String) -> void:
	var outer := hexagon(HEX_RADIUS)
	var closed := outer.duplicate()
	closed.append(outer[0])
	if frame == "hex_selected":
		var glow := hexagon(HEX_RADIUS + 2)
		glow.append(glow[0])
		ci.draw_polyline(glow, Color(GOLD, 0.35), 8.0, true)
	if frame == "hex_empty":
		ci.draw_colored_polygon(outer, Color(0.04, 0.07, 0.2, 0.62))
		var inner := hexagon(HEX_RADIUS - 9)
		inner.append(inner[0])
		ci.draw_polyline(inner, Color(1, 1, 1, 0.07), 2.0, true)
		ci.draw_polyline(closed, Color(0.7, 0.82, 1.0, 0.32), 3.0, true)
		return
	var colors := PackedColorArray()
	for p in outer:
		var k := clampf(p.y / float(FRAME_SIZE.y), 0.0, 1.0)
		colors.append(Color(0.24, 0.4, 0.78, 0.94).lerp(Color(0.09, 0.14, 0.38, 0.94), k))
	ci.draw_polygon(outer, colors)
	var shine := hexagon(HEX_RADIUS - 10)
	var top := PackedVector2Array()
	for p in shine:
		if p.y < FRAME_SIZE.y * 0.45:
			top.append(p)
	if top.size() >= 3:
		ci.draw_colored_polygon(top, Color(1, 1, 1, 0.07))
	if frame == "hex_selected":
		ci.draw_polyline(closed, GOLD, 6.0, true)
	else:
		ci.draw_polyline(closed, Color(0.75, 0.88, 1.0, 0.75), 4.0, true)


## The "+N" badge: a dark pill with a gold rim (a 9-patch, ui/art.gd EQUIP_BADGE_MARGINS).
static func paint_badge(ci: CanvasItem) -> void:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0.04, 0.05, 0.14, 0.92)
	b.set_corner_radius_all(BADGE_SIZE.y / 2)
	b.corner_detail = 16
	b.anti_aliasing = true
	b.border_color = Color(GOLD, 0.95)
	b.set_border_width_all(2)
	ci.draw_style_box(b, Rect2(Vector2(1, 1), Vector2(BADGE_SIZE) - Vector2(2, 2)))
