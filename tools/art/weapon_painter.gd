extends RefCounted
## The code-drawn guns the characters hold (bake source only, not used at runtime): one side view
## per kind × tier, facing right, drawn in art units (the characters' 1.6 px per unit) with the
## grip (where the hand holds it) at GRIP_PX of a SIZE canvas. tools/bake_art.gd saves them as
## assets/weapons/<kind>/<tier>.png and writes their grip and muzzle points to
## assets/weapons/weapons.json (paths in ui/art.gd).
##
## Kind = silhouette: bazooka (Rookie), cannon (Tanko), shock_rifle (Spark), seed_launcher
## (Flora), blaster (generic and crafted weapons). Tier = look: `basic` in the character's own
## gun colours (no weapon equipped), the shop tiers (iron, steel, mithril, dragon) and the
## crafted ones (silver, gold, titan, diamond) in the equipment icons' palettes
## (tools/art/equipment_painter.gd TIERS), with brighter trims; high tiers glow.

const EquipmentPainter := preload("res://tools/art/equipment_painter.gd")
const CharacterPainter := preload("res://tools/art/character_painter.gd")

const SIZE := Vector2i(224, 128)
const GRIP_PX := Vector2(96, 88)
const OUTLINE := Color(0.07, 0.07, 0.12)
const W := 3.0 # outline, units (the characters' outline)
const LEATHER := Color(0.48, 0.3, 0.17)
const SHOCK := Color(0.55, 0.95, 1.0)
const SEED := Color(0.45, 0.82, 0.38)
## The dragon tier's glow (fire); the other tiers glow in their light colour.
const DRAGON_GLOW := Color(1.0, 0.62, 0.28)
## Tiers that glow around the barrel and at the muzzle.
const GLOWING := ["mithril", "dragon", "gold", "titan", "diamond"]
## The character whose starter look a kind's basic tier has.
const BASIC_OF := {"bazooka": "rookie", "cannon": "tanko", "shock_rifle": "spark", "seed_launcher": "flora"}

## kind -> muzzle (units from the grip, where shots and the muzzle flash start) and the barrel
## axis for the glow: y, rear x, front x, half height.
const SHAPES := {
	"bazooka": {"muzzle": Vector2(47, -16), "axis": [-16.0, -31.0, 47.0, 12.0]},
	"cannon": {"muzzle": Vector2(50, -14), "axis": [-14.0, -46.0, 50.0, 15.0]},
	"shock_rifle": {"muzzle": Vector2(52, -14), "axis": [-15.0, -38.0, 52.0, 11.0]},
	"seed_launcher": {"muzzle": Vector2(48, -18), "axis": [-17.0, -30.0, 48.0, 13.0]},
	"blaster": {"muzzle": Vector2(46, -15.5), "axis": [-16.0, -16.0, 46.0, 10.0]},
}


## The grip and muzzle of a kind, px in the SIZE canvas drawn at `scale` px per unit.
static func points(kind: String, scale: float) -> Dictionary:
	var shape: Dictionary = SHAPES.get(kind, SHAPES["bazooka"])
	return {"grip": GRIP_PX, "muzzle": GRIP_PX + shape["muzzle"] * scale}


## Draws the gun on ci with its grip at GRIP_PX, scale px per unit.
static func paint(ci: CanvasItem, kind: String, tier: String, scale: float) -> void:
	var pal := palette(kind, tier)
	ci.draw_set_transform(GRIP_PX, 0.0, Vector2(scale, scale))
	if GLOWING.has(tier):
		_glow(ci, kind, pal)
	match kind:
		"cannon": _cannon(ci, pal)
		"shock_rifle": _shock_rifle(ci, pal)
		"seed_launcher": _seed_launcher(ci, pal)
		"blaster": _blaster(ci, pal)
		_: _bazooka(ci, pal)
	_extras(ci, kind, pal)
	ci.draw_set_transform(Vector2.ZERO)


## {main, light, dark, trim, metal (small parts), stock, outline, tier}.
static func palette(kind: String, tier: String) -> Dictionary:
	var main: Color
	var light: Color
	var dark: Color
	var trim: Color
	if EquipmentPainter.TIERS.has(tier):
		var t: Array = EquipmentPainter.TIERS[tier]
		main = t[0]
		light = t[1]
		dark = t[2]
		trim = t[3]
	else: # basic: the character's own gun colours
		var look: Dictionary = CharacterPainter.LOOKS.get(BASIC_OF.get(kind, ""), {})
		main = look.get("weapon", Color(0.5, 0.53, 0.6))
		light = main.lightened(0.35)
		dark = main.darkened(0.35)
		trim = main.darkened(0.2)
	var plain := tier == "iron" or not EquipmentPainter.TIERS.has(tier)
	var stock := LEATHER
	if kind == "shock_rifle" and not EquipmentPainter.TIERS.has(tier):
		stock = CharacterPainter.LOOKS["spark"]["trim"]
	return {"main": main, "light": light, "dark": dark, "trim": trim, "metal": dark if plain else trim,
		"stock": stock, "outline": OUTLINE, "tier": tier}


# ── Kinds (units, grip at the origin, facing +x) ────────────────────────────

## A shoulder bazooka: tube, rear cone, flared muzzle, two bands, a sight.
static func _bazooka(ci: CanvasItem, pal: Dictionary) -> void:
	_rrect(ci, Rect2(-4, -10, 8, 15), 3, pal["stock"], pal)
	_poly(ci, [Vector2(-31, -28), Vector2(-24, -25), Vector2(-24, -7), Vector2(-31, -4)], pal["dark"], pal)
	_rrect(ci, Rect2(-24, -25, 62, 18), 8, pal["main"], pal)
	_fill(ci, EquipmentPainter._round_rect(Rect2(-21, -23, 56, 5), 2), Color(pal["light"], 0.75))
	_poly(ci, [Vector2(36, -26), Vector2(47, -31), Vector2(47, -1), Vector2(36, -6)], pal["dark"], pal)
	for x in [-12.0, 22.0]:
		_rrect(ci, Rect2(x, -26, 5, 20), 2, pal["metal"], pal, 2.0)
	_rrect(ci, Rect2(-4, -33, 11, 7), 2, pal["dark"], pal, 2.0)


## A heavy cannon held low: round breech, thick tapered barrel with bands, muzzle ring.
static func _cannon(ci: CanvasItem, pal: Dictionary) -> void:
	_rrect(ci, Rect2(-5, -8, 10, 13), 3, pal["stock"], pal)
	_disc(ci, Vector2(-34, -14), 13, pal["dark"], pal)
	_poly(ci, [Vector2(-34, -27), Vector2(40, -24), Vector2(40, -4), Vector2(-34, -1)], pal["main"], pal)
	_fill(ci, [Vector2(-32, -24), Vector2(38, -21), Vector2(38, -17), Vector2(-32, -19)], Color(pal["light"], 0.7))
	for x in [-14.0, 12.0]:
		_rrect(ci, Rect2(x, -26, 6, 26), 2, pal["metal"], pal, 2.0)
	_rrect(ci, Rect2(38, -30, 12, 32), 5, pal["metal"], pal)
	ci.draw_circle(Vector2(46, -14), 5.0, pal["outline"], true, -1.0, true)
	ci.draw_circle(Vector2(-45, -14), 4.0, pal["metal"], true, -1.0, true)


## A shock rifle: stock, body, barrel with glowing coils, an energy tank with a bolt.
static func _shock_rifle(ci: CanvasItem, pal: Dictionary) -> void:
	_poly(ci, [Vector2(-38, -19), Vector2(-22, -21), Vector2(-22, -8), Vector2(-36, -2)], pal["stock"], pal)
	_rrect(ci, Rect2(-4, -9, 8, 13), 3, pal["dark"], pal)
	_rrect(ci, Rect2(28, -18, 24, 8), 3, pal["dark"], pal)
	_rrect(ci, Rect2(-22, -23, 52, 16), 6, pal["main"], pal)
	_fill(ci, EquipmentPainter._round_rect(Rect2(-19, -21, 46, 4), 2), Color(pal["light"], 0.75))
	for x in [32.0, 39.0, 46.0]:
		_rrect(ci, Rect2(x, -21, 4, 14), 2, SHOCK, pal, 2.0)
	_rrect(ci, Rect2(-12, -34, 24, 11), 5, SHOCK, pal, 2.5)
	_fill(ci, [Vector2(2, -33), Vector2(-4, -28), Vector2(0, -28), Vector2(-3, -24), Vector2(5, -30), Vector2(1, -30)], Color(1, 1, 0.6))


## A seed launcher: wide tube, bell muzzle, a ring, a round hopper with a seed, a leaf.
static func _seed_launcher(ci: CanvasItem, pal: Dictionary) -> void:
	_rrect(ci, Rect2(-4, -9, 8, 13), 3, pal["stock"], pal)
	_rrect(ci, Rect2(-30, -26, 64, 18), 9, pal["main"], pal)
	_fill(ci, EquipmentPainter._round_rect(Rect2(-26, -24, 56, 5), 2), Color(pal["light"], 0.75))
	_poly(ci, [Vector2(32, -27), Vector2(48, -33), Vector2(48, -3), Vector2(32, -9)], pal["metal"], pal)
	_rrect(ci, Rect2(12, -28, 5, 22), 2, SEED.darkened(0.3), pal, 2.0)
	_disc(ci, Vector2(-8, -31), 10, pal["dark"], pal)
	_disc(ci, Vector2(-8, -33), 6, SEED, pal, 2.0)
	_poly(ci, [Vector2(-28, -24), Vector2(-38, -38), Vector2(-20, -30)], SEED, pal, 2.0)


## A chunky blaster pistol: angled grip, body, barrel, muzzle ring, energy cell, trigger guard.
static func _blaster(ci: CanvasItem, pal: Dictionary) -> void:
	_poly(ci, [Vector2(-7, -9), Vector2(5, -9), Vector2(6, 11), Vector2(-8, 11)], pal["stock"], pal)
	_rrect(ci, Rect2(24, -20, 16, 9), 3, pal["dark"], pal)
	_disc(ci, Vector2(41, -15.5), 5, pal["metal"], pal, 2.0)
	_rrect(ci, Rect2(-16, -24, 42, 16), 6, pal["main"], pal)
	_fill(ci, EquipmentPainter._round_rect(Rect2(-13, -22, 36, 4), 2), Color(pal["light"], 0.75))
	_rrect(ci, Rect2(-10, -15, 18, 4), 2, pal["metal"], pal, 1.5)
	ci.draw_arc(Vector2(10, -6), 5.0, 0.2, PI - 0.2, 10, pal["outline"], 2.0, true)


# ── Tier details ────────────────────────────────────────────────────────────

## A soft halo around the barrel and a bright point at the muzzle (high tiers).
static func _glow(ci: CanvasItem, kind: String, pal: Dictionary) -> void:
	var shape: Dictionary = SHAPES.get(kind, SHAPES["bazooka"])
	var axis: Array = shape["axis"]
	var c: Color = DRAGON_GLOW if pal["tier"] == "dragon" else pal["light"]
	var y: float = axis[0]
	var h: float = axis[3]
	for layer in [[h + 8.0, 0.07], [h + 4.0, 0.1]]:
		var x: float = axis[1] + h
		while x <= axis[2] - h + 0.1:
			ci.draw_circle(Vector2(x, y), layer[0], Color(c, layer[1]), true, -1.0, true)
			x += 4.0
	ci.draw_circle(shape["muzzle"], 7.0, Color(c, 0.35), true, -1.0, true)


## Rồng: a gold stripe; Vàng / Kim cương / Bạc: sparkles; Titan: orange rivets.
static func _extras(ci: CanvasItem, kind: String, pal: Dictionary) -> void:
	var shape: Dictionary = SHAPES.get(kind, SHAPES["bazooka"])
	var axis: Array = shape["axis"]
	var top := Vector2(lerpf(axis[1], axis[2], 0.62), axis[0] - axis[3] - 4.0)
	match pal["tier"]:
		"dragon":
			var y: float = axis[0] + axis[3] * 0.35
			ci.draw_line(Vector2(axis[1] + axis[3] + 2.0, y), Vector2(axis[2] - axis[3] - 2.0, y), EquipmentPainter.GOLD, 2.5, true)
		"gold":
			EquipmentPainter._sparkle(ci, top, 6.0)
		"diamond":
			EquipmentPainter._sparkle(ci, top, 7.0)
			EquipmentPainter._sparkle(ci, Vector2(axis[1] + axis[3], axis[0] - axis[3] + 2.0), 4.0)
		"silver":
			EquipmentPainter._sparkle(ci, top, 5.0, Color(1, 1, 1, 0.85))
		"titan":
			for x in [lerpf(axis[1], axis[2], 0.3), lerpf(axis[1], axis[2], 0.55)]:
				ci.draw_circle(Vector2(x, axis[0]), 2.6, pal["trim"], true, -1.0, true)
				ci.draw_circle(Vector2(x, axis[0]), 1.1, Color(1, 0.92, 0.7), true, -1.0, true)


# ── Helpers (equipment_painter's, with the characters' outline width) ───────

static func _poly(ci: CanvasItem, pts: Array, fill: Color, pal: Dictionary, w: float = W) -> void:
	EquipmentPainter._poly(ci, pts, fill, pal, w)


static func _rrect(ci: CanvasItem, r: Rect2, radius: float, fill: Color, pal: Dictionary, w: float = W) -> void:
	EquipmentPainter._rrect(ci, r, radius, fill, pal, w)


static func _disc(ci: CanvasItem, c: Vector2, r: float, fill: Color, pal: Dictionary, w: float = W) -> void:
	EquipmentPainter._disc(ci, c, r, fill, pal, w)


static func _fill(ci: CanvasItem, pts: Array, fill: Color) -> void:
	EquipmentPainter._fill(ci, pts, fill)
