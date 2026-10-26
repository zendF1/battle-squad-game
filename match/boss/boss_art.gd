extends RefCounted
## Placeholder art of the bosses and their minions, drawn in code (original designs, cartoon with
## a dark outline like the characters; the real art replaces it later): Rô-bốt Thép (a steel mech
## titan with a reactor core, a visor, an arm cannon and a claw), its Drone (a floating eye with two
## rotors), Cua Dung Nham (a basalt-shelled lava crab with glowing cracks, seen from the front and
## symmetric: three legs and a raised pincer facing outward on each side, the eye stalks in the
## middle), its Cua con (a small bright crab, the same build), Phù Thuỷ Băng (a hooded ice witch floating on frost
## mist with a crystal staff and orbiting shards) and its Người tuyết (a snowman with a pail, a
## scarf and a carrot nose); boss v4: Khổng Lồ Đá (a giant of stacked sandstone boulders with a
## glowing amber chest gem and rune lines, huge boulder fists, amber quartz on the shoulders; opts
## plates: the stone armour its totems give it), its Trụ đá (three stacked sandstone blocks, a grumpy
## face, an amber rune and crystal), Mộc Tinh (a gnarled bark trunk with a face, glowing yellow-green
## eyes and a leafy beard, branch arms with twig claws, roots, a round leaf crown with cream blossoms
## and golden fruits, an amber sap heart) and its Nấm độc (a sickly yellow-green spotted cap on a
## cream stem with an angry face; opts puff: its spore puff's squash). Any other boss / minion id
## gets a generic blob of its side.
##
## draw() paints one figure on any CanvasItem in a unit frame: the feet at `feet`, UNIT units tall
## (`height` px), facing right for facing > 0; t (seconds) drives the idle motion (bob, the core's
## pulse, rotors, shards); flash 0..1 whitens it (a hit). The art id comes from the boss / minion id
## (art_of()): only the presentation is mapped here, sizes come from the game data.
## opts (boss mode v2, what the game data / state says the unit does): flying (the feet are a point
## in the air: no shadow at them, a wider hover bob; the witch's cape streams behind her), lean
## (radians into a flight), tint (0..1: a bomber about to blow up glows red, BomberModel.pulse()),
## shards (the witch's orbiting crystals, boss mode v3: {phase: their angle, n: how many, size: their
## scale 0..1, reach: their orbit's scale}; she casts them as her blizzard: BossBody.cast_shards()).

const UNIT := 100.0
const SHIELD_MARGIN := 0.08 # of the height, the shield ball past the body
const OUT := Color(0.08, 0.06, 0.12)
const OUT_PX := 2.6 # outline width on screen, whatever the size
const ARTS := ["steel_robot", "drone", "lava_crab", "crab", "ice_witch", "snowman", "rock_giant", "stone_totem", "tree_spirit",
	"poison_mushroom"]
const GENERIC_BOSS := "generic_boss"
const GENERIC_MINION := "generic_minion"
## Where each figure floats (units above the feet the bob is around; 0 stands).
const HOVER := {"drone": 10.0, "ice_witch": 6.0}
## The shot look of each boss's skills (ShotLook kind × tier: the shells of its rain, its beam's
## colours); others use the default look.
const SHOT_LOOK := {"steel_robot": {"kind": "cannon", "tier": "titan"}, "lava_crab": {"kind": "bazooka", "tier": "dragon"},
	"ice_witch": {"kind": "shock_rifle", "tier": "iron"}, "rock_giant": {"kind": "cannon", "tier": "basic"},
	"tree_spirit": {"kind": "seed_launcher", "tier": "mithril"}}
## The point (unit frame, facing right) a boss's beam and muzzle flash leave from.
const MUZZLE := {"steel_robot": Vector2(64, -60), "lava_crab": Vector2(64, -58), "ice_witch": Vector2(30, -98),
	"drone": Vector2(10, -62), "crab": Vector2(60, -54), "snowman": Vector2(26, -58), "rock_giant": Vector2(52, -40),
	"stone_totem": Vector2(20, -72), "tree_spirit": Vector2(3, -27), "poison_mushroom": Vector2(0, -80)}
## The accent colour of each art (the HUD bar's name, the shield's tint, the card's glow).
const ACCENT := {"steel_robot": Color(1.0, 0.62, 0.22), "drone": Color(1.0, 0.35, 0.3), "lava_crab": Color(1.0, 0.45, 0.12),
	"crab": Color(1.0, 0.55, 0.3), "ice_witch": Color(0.5, 0.9, 1.0), "snowman": Color(0.7, 0.9, 1.0),
	"rock_giant": Color(1.0, 0.76, 0.24), "stone_totem": Color(1.0, 0.72, 0.28), "tree_spirit": Color(0.84, 1.0, 0.4),
	"poison_mushroom": Color(0.76, 0.9, 0.24),
	GENERIC_BOSS: Color(0.85, 0.5, 1.0), GENERIC_MINION: Color(0.85, 0.6, 0.9)}

## How wide each figure is for its height (the shield's ellipse, a UI box fitting it).
const WIDTH := {"lava_crab": 1.7, "crab": 1.7, "steel_robot": 1.35, "ice_witch": 1.1, "rock_giant": 1.4, "tree_spirit": 1.35,
	"stone_totem": 0.75, "poison_mushroom": 1.0}
## How far a figure reaches over its feet, of its height (the name and the bar above it): Mộc
## Tinh's crown and Khổng Lồ Đá's quartz stand over the unit height; 1 for the rest.
const TOP := {"tree_spirit": 1.12, "rock_giant": 1.04}
## The heart of a boss (unit frame, facing right): where the life it drains flows in (Mộc Tinh's sap
## heart) and its heal glows; others: the body's middle.
const HEART := {"tree_spirit": Vector2(3, -27), "rock_giant": Vector2(4, -60)}

static var _s := 1.0 # px per unit of the figure being drawn
static var _out_px := OUT_PX # the outline on screen: thinner on a small figure
static var _flash := 0.0
static var _tint := 0.0 # the warning's red glow (opts tint)
const WARN_RED := Color(1.0, 0.22, 0.16)


## The art id of a boss (role boss) or minion (role minion) from its bossId / minionId.
static func art_of(boss_id: String, minion_id: String = "") -> String:
	if minion_id != "":
		return minion_id if ARTS.has(minion_id) else GENERIC_MINION
	return boss_id if ARTS.has(boss_id) else GENERIC_BOSS


## The art of a match player dict (role, bossId, minionId); "" for a normal player.
static func art_of_player(p: Dictionary) -> String:
	match str(p.get("role", "")):
		"boss":
			return art_of(str(p.get("bossId", "")))
		"minion":
			return art_of("", str(p.get("minionId", "")) if str(p.get("minionId", "")) != "" else "?")
	return ""


static func accent(art: String) -> Color:
	return ACCENT.get(art, ACCENT[GENERIC_BOSS])


## The muzzle point (px from the feet, facing applied) of an art drawn `height` px tall.
static func muzzle(art: String, height: float, facing: int) -> Vector2:
	var m: Vector2 = MUZZLE.get(art, Vector2(20, -60))
	return Vector2(m.x * signf(facing if facing != 0 else 1), m.y) * height / UNIT


## The idle bob (units, up negative) at t; flying: round the feet (already in the air), wider.
static func bob(art: String, t: float, flying: bool = false) -> float:
	if flying:
		return -sin(t * 2.2) * 5.0 - sin(t * 0.9 + 1.0) * 2.0
	var hover: float = HOVER.get(art, 0.0)
	if hover > 0.0:
		return -hover - sin(t * 2.2) * 4.0
	return -absf(sin(t * 1.6)) * 1.2


# ── Drawing ─────────────────────────────────────────────────────────────────

## Draws `art` with its feet at `feet`, `height` px tall; dead: a fallen, greyed pose.
static func draw(ci: CanvasItem, art: String, feet: Vector2, height: float, t: float, facing: int = 1, flash: float = 0.0,
		opts: Dictionary = {}) -> void:
	_s = maxf(height / UNIT, 0.01)
	_out_px = OUT_PX * clampf(height / 110.0, 0.45, 1.0)
	_flash = clampf(flash, 0.0, 1.0)
	_opts = opts
	_tint = clampf(float(opts.get("tint", 0.0)), 0.0, 1.0)
	var flying := bool(opts.get("flying", false))
	var f := -1.0 if facing < 0 else 1.0
	if not flying: # the shadow on the ground, not bobbing (a flier's is drawn on the ground below it)
		ci.draw_set_transform(feet, 0.0, Vector2(_s, _s))
		_ellipse_fill(ci, Vector2.ZERO, _shadow_w(art), 6.0, Color(0, 0, 0, 0.28))
	ci.draw_set_transform(feet + Vector2(0, bob(art, t, flying) * _s), float(opts.get("lean", 0.0)), Vector2(f * _s, _s))
	match art:
		"steel_robot":
			_robot(ci, t)
		"drone":
			_drone(ci, t)
		"lava_crab":
			_crab(ci, t, false)
		"crab":
			_crab(ci, t, true)
		"ice_witch":
			_witch(ci, t)
		"snowman":
			_snowman(ci, t)
		"rock_giant":
			_giant(ci, t)
		"stone_totem":
			_totem(ci, t)
		"tree_spirit":
			_tree(ci, t)
		"poison_mushroom":
			_mushroom(ci, t)
		GENERIC_MINION:
			_blob(ci, t, Color(0.6, 0.45, 0.75))
		_:
			_blob(ci, t, Color(0.45, 0.3, 0.65))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_opts = {}
	_tint = 0.0


static func _shadow_w(art: String) -> float:
	match art:
		"lava_crab", "crab":
			return 66.0
		"drone":
			return 22.0
		"rock_giant", "tree_spirit":
			return 58.0
		"stone_totem":
			return 28.0
	return 42.0


static func top(art: String) -> float:
	return float(TOP.get(art, 1.0))


## The heart point (px from the feet, facing applied) of an art drawn `height` px tall.
static func heart(art: String, height: float, facing: int) -> Vector2:
	var m: Vector2 = HEART.get(art, Vector2(0, -50))
	return Vector2(m.x * signf(facing if facing != 0 else 1), m.y) * height / UNIT


## How a minion's own blast looks (its detonation, its death blast): the ExplosionFx kind × tier
## of the burst and whether it is icy (frost shards and snow instead of fire and shrapnel).
const BLAST_LOOK := {"drone": {"kind": "cannon", "tier": "dragon", "icy": false},
	"crab": {"kind": "bazooka", "tier": "dragon", "icy": false},
	"snowman": {"kind": "shock_rifle", "tier": "mithril", "icy": true},
	"poison_mushroom": {"kind": "seed_launcher", "tier": "basic", "icy": false, "spore": true},
	GENERIC_MINION: {"kind": "bazooka", "tier": "dragon", "icy": false}}
## The storm a boss's map-wide rain blows across the screen (match/boss/storm_overlay.gd kind).
const STORM := {"ice_witch": "snow", "lava_crab": "ember", "tree_spirit": "spores"}
## The trail a flying figure leaves in the air (its colour; none: no trail).
const TRAIL := {"ice_witch": Color(0.75, 0.95, 1.0), "drone": Color(0.8, 0.82, 0.88, 0.6)}

static var _opts := {}


## The blast look of a minion art (BLAST_LOOK, the generic one for others).
static func blast_look(art: String) -> Dictionary:
	return BLAST_LOOK.get(art, BLAST_LOOK[GENERIC_MINION])


## The shield ball's radius (px) round a figure `height` px tall (match/views/shield_ball.gd, the
## boss's BossBody draws it): half its larger side (its width from WIDTH, its height) and a
## margin, so the ball covers the whole body.
static func shield_radius(art: String, height: float) -> float:
	var w: float = WIDTH.get(art, 1.0)
	return maxf(height * w, height) * 0.5 + height * SHIELD_MARGIN


# ── Primitives (unit frame) ─────────────────────────────────────────────────

static func _c(col: Color) -> Color:
	var c := col.lerp(Color(1, 1, 1, col.a), _flash * 0.85)
	return c.lerp(Color(WARN_RED, c.a), _tint * 0.5) if _tint > 0.0 else c


static func _w(px: float = -1.0) -> float:
	return (px if px >= 0.0 else _out_px) / _s


static func _shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline: bool = true) -> void:
	ci.draw_colored_polygon(pts, _c(fill))
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, OUT, _w(), true)


static func _circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, outline: bool = true) -> void:
	ci.draw_circle(c, r, _c(fill))
	if outline:
		ci.draw_arc(c, r, 0.0, TAU, 32, OUT, _w(), true)


static func _ellipse_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func _ellipse_fill(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	ci.draw_colored_polygon(_ellipse_pts(c, rx, ry), col)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, rot: float = 0.0) -> void:
	_shape(ci, _ellipse_pts(c, rx, ry, rot), fill)


static func _rrect(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	r = minf(r, minf(w, h) / 2.0)
	var corners := [[x + w - r, y + r, -PI / 2.0], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI / 2.0], [x + r, y + r, PI]]
	for c in corners:
		for i in 5:
			var a: float = c[2] + PI / 2.0 * i / 4.0
			pts.append(Vector2(c[0] + cos(a) * r, c[1] + sin(a) * r))
	return pts


static func _box(ci: CanvasItem, x: float, y: float, w: float, h: float, r: float, fill: Color) -> void:
	_shape(ci, _rrect(x, y, w, h, r), fill)


## A limb: a thick line with an outline (drawn as the outline line, then the fill over it).
static func _limb(ci: CanvasItem, pts: PackedVector2Array, width: float, fill: Color) -> void:
	ci.draw_polyline(pts, OUT, width + _w() * 2.0, true)
	ci.draw_polyline(pts, _c(fill), width, true)
	for p in [pts[0], pts[pts.size() - 1]]:
		ci.draw_circle(p, width / 2.0 + _w(), OUT)
		ci.draw_circle(p, width / 2.0, _c(fill))


static func _glow(ci: CanvasItem, c: Vector2, r: float, col: Color, strength: float = 1.0) -> void:
	for i in 4:
		var k := 1.0 + i * 0.55
		ci.draw_circle(c, r * k, Color(col, 0.16 * strength / k))


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, px: float) -> void:
	ci.draw_line(a, b, _c(col), _w(px), true)


# ── Rô-bốt Thép ─────────────────────────────────────────────────────────────

const STEEL := Color(0.56, 0.62, 0.7)
const STEEL_DARK := Color(0.34, 0.38, 0.46)
const STEEL_LIGHT := Color(0.78, 0.83, 0.9)
const HAZARD := Color(1.0, 0.78, 0.2)


static func _robot(ci: CanvasItem, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 3.2)
	# back arm (the claw) and back leg, darker
	_limb(ci, PackedVector2Array([Vector2(-30, -82), Vector2(-38, -64), Vector2(-36, -50)]), 11.0, STEEL_DARK)
	_shape(ci, PackedVector2Array([Vector2(-44, -50), Vector2(-28, -50), Vector2(-30, -38), Vector2(-36, -44), Vector2(-42, -38)]), STEEL_DARK)
	_box(ci, -26, -44, 16, 24, 4, STEEL_DARK)
	_box(ci, -28, -24, 20, 18, 4, STEEL_DARK)
	_box(ci, -33, -9, 28, 9, 4, Color(0.25, 0.27, 0.33))
	# front leg
	_box(ci, 6, -44, 16, 24, 4, STEEL)
	_circle(ci, Vector2(14, -24), 7.0, STEEL_LIGHT)
	_box(ci, 4, -22, 20, 16, 4, STEEL)
	_box(ci, 0, -9, 32, 9, 4, Color(0.3, 0.33, 0.4))
	# pelvis with hazard stripes
	_box(ci, -28, -52, 56, 12, 4, Color(0.2, 0.2, 0.24))
	for i in 5:
		var x := -24.0 + i * 11.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, -51), Vector2(x + 5, -51), Vector2(x + 1, -41), Vector2(x - 4, -41)]), _c(HAZARD))
	# torso
	_shape(ci, PackedVector2Array([Vector2(-34, -90), Vector2(34, -90), Vector2(38, -78), Vector2(28, -50), Vector2(-28, -50), Vector2(-38, -78)]), STEEL)
	_shape(ci, PackedVector2Array([Vector2(-22, -84), Vector2(22, -84), Vector2(18, -58), Vector2(-18, -58)]), STEEL_LIGHT)
	_line(ci, Vector2(-30, -60), Vector2(30, -60), STEEL_DARK, 1.6)
	for p in [Vector2(-28, -84), Vector2(28, -84), Vector2(-24, -56), Vector2(24, -56)]:
		ci.draw_circle(p, 1.8, _c(STEEL_DARK))
	# the reactor core
	_glow(ci, Vector2(2, -71), 10.0, Color(1.0, 0.55, 0.15), 0.6 + 0.6 * pulse)
	_circle(ci, Vector2(2, -71), 9.0, Color(0.3, 0.15, 0.08))
	ci.draw_circle(Vector2(2, -71), 6.5, _c(Color(1.0, 0.5, 0.12).lerp(Color(1.0, 0.85, 0.4), pulse)))
	ci.draw_circle(Vector2(0, -73), 2.2, Color(1, 1, 0.9, 0.9))
	# head: a dome with a visor slit
	_line(ci, Vector2(-4, -102), Vector2(-8, -112), STEEL_DARK, 2.2)
	ci.draw_circle(Vector2(-8, -112), 2.6, _c(Color(1.0, 0.3, 0.25)))
	_shape(ci, PackedVector2Array([Vector2(-14, -90), Vector2(-12, -101), Vector2(0, -106), Vector2(14, -102), Vector2(18, -90)]), STEEL_DARK)
	_box(ci, -2, -99, 18, 5, 2, Color(0.05, 0.08, 0.12))
	_glow(ci, Vector2(10, -96.5), 4.0, Color(0.4, 0.95, 1.0), 0.8 + 0.4 * pulse)
	ci.draw_rect(Rect2(0, -98, 15, 2.5), _c(Color(0.55, 1.0, 1.0)))
	# shoulders
	_circle(ci, Vector2(-31, -84), 12.0, STEEL_DARK)
	_shape(ci, PackedVector2Array([Vector2(18, -96), Vector2(42, -94), Vector2(48, -80), Vector2(40, -72), Vector2(20, -76)]), STEEL)
	_line(ci, Vector2(24, -90), Vector2(42, -88), STEEL_LIGHT, 1.6)
	# front arm: the cannon
	_limb(ci, PackedVector2Array([Vector2(36, -78), Vector2(38, -64)]), 12.0, STEEL_DARK)
	_box(ci, 28, -70, 36, 16, 5, STEEL)
	_box(ci, 58, -72, 10, 20, 3, STEEL_DARK)
	ci.draw_circle(Vector2(66, -62), 4.0, _c(Color(0.1, 0.08, 0.06)))
	_glow(ci, Vector2(66, -62), 3.0, Color(1.0, 0.5, 0.15), 0.5 + 0.5 * pulse)
	for x in [36.0, 44.0, 52.0]:
		_line(ci, Vector2(x, -69), Vector2(x, -55), STEEL_DARK, 1.4)


# ── Drone ───────────────────────────────────────────────────────────────────

static func _drone(ci: CanvasItem, t: float) -> void:
	var c := Vector2(0, -58)
	# rotor arms and spinning rotors
	for side in [-1.0, 1.0]:
		_limb(ci, PackedVector2Array([c + Vector2(side * 14, -14), c + Vector2(side * 30, -30)]), 5.0, STEEL_DARK)
		var w := 6.0 + absf(cos(t * 28.0 + side)) * 16.0
		ci.draw_colored_polygon(_ellipse_pts(c + Vector2(side * 30, -33), w, 3.0), Color(0.85, 0.9, 1.0, 0.55))
		ci.draw_circle(c + Vector2(side * 30, -32), 3.0, _c(STEEL))
	# skids
	_line(ci, c + Vector2(-14, 20), c + Vector2(-18, 32), STEEL_DARK, 2.0)
	_line(ci, c + Vector2(14, 20), c + Vector2(18, 32), STEEL_DARK, 2.0)
	_line(ci, c + Vector2(-24, 32), c + Vector2(-10, 32), STEEL_DARK, 2.4)
	_line(ci, c + Vector2(10, 32), c + Vector2(24, 32), STEEL_DARK, 2.4)
	# body
	_circle(ci, c, 26.0, Color(0.48, 0.55, 0.66))
	ci.draw_arc(c, 20.0, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.45), _w(3.0), true)
	_box(ci, -24, -60, 48, 8, 3, STEEL_DARK)
	# the eye
	var blink := 1.0 if fmod(t, 3.1) > 0.12 else 0.2
	_circle(ci, c + Vector2(8, 2), 12.0, Color(0.12, 0.1, 0.14))
	_glow(ci, c + Vector2(10, 2), 6.0, Color(1.0, 0.25, 0.2), 0.9)
	ci.draw_colored_polygon(_ellipse_pts(c + Vector2(10, 2), 7.0, 7.0 * blink), _c(Color(1.0, 0.3, 0.25)))
	ci.draw_circle(c + Vector2(12, 0), 2.2, Color(1, 0.95, 0.9))


# ── Cua Dung Nham / Cua con ─────────────────────────────────────────────────

static func _crab(ci: CanvasItem, t: float, baby: bool) -> void:
	# Symmetric, seen from the front: three legs and a claw on each side, both claws raised and
	# facing outward, the eye stalks in the middle.
	var shell := Color(0.85, 0.32, 0.14) if baby else Color(0.24, 0.16, 0.15)
	var shell_light := Color(1.0, 0.55, 0.3) if baby else Color(0.4, 0.26, 0.22)
	var limb := Color(0.95, 0.42, 0.18) if baby else Color(0.78, 0.26, 0.1)
	var glow := 0.5 + 0.5 * sin(t * 2.6)
	var step := sin(t * 5.0)
	var body := Vector2(0, -38)
	# legs: three a side, the back pair darker (behind the others)
	for i in [2, 1, 0]:
		var k := float(i)
		var col := limb.darkened(0.12 * k)
		for side in [-1.0, 1.0]:
			var root: Vector2 = body + Vector2(side * (18 + k * 9), 8)
			var lift := step * (1.5 if (i % 2 == 0) == (side > 0) else -1.5)
			var knee: Vector2 = root + Vector2(side * (10 + k * 2), -10 + k * 2 + lift)
			var tip := Vector2(root.x + side * (16 + k * 3), 0)
			_limb(ci, PackedVector2Array([root, knee, tip]), 6.5, col)
	# shell
	_ellipse(ci, body, 52, 30, shell)
	_shape(ci, PackedVector2Array([body + Vector2(-46, 10), body + Vector2(46, 10), body + Vector2(36, 24), body + Vector2(-36, 24)]),
		Color(1.0, 0.7, 0.45) if baby else Color(0.55, 0.3, 0.2))
	ci.draw_colored_polygon(_ellipse_pts(body + Vector2(0, -15), 34, 10), _c(Color(shell_light, 0.85)))
	if not baby:
		for sx in [-30, -10, 10, 30]:
			var sy := -20 if absi(sx) > 20 else -27
			_shape(ci, PackedVector2Array([body + Vector2(sx - 5, sy + 4), body + Vector2(sx, sy - 8), body + Vector2(sx + 5, sy + 4)]),
				Color(0.18, 0.12, 0.11))
		var lava := Color(1.0, 0.55, 0.12).lerp(Color(1.0, 0.85, 0.35), glow)
		var cracks := [[Vector2(-40, -2), Vector2(-28, -8), Vector2(-18, 2), Vector2(-7, -6)],
			[Vector2(-22, 12), Vector2(-9, 5), Vector2(0, 11)], [Vector2(0, -12), Vector2(0, -3)]]
		for crack in cracks.duplicate():
			if crack[0].x != 0.0:
				cracks.append(crack.map(func(p: Vector2) -> Vector2: return Vector2(-p.x, p.y)))
		for crack in cracks:
			var pts := PackedVector2Array()
			for p in crack:
				pts.append(body + p)
			ci.draw_polyline(pts, Color(1.0, 0.45, 0.1, 0.35 * (0.6 + glow)), _w(9.0), true)
			ci.draw_polyline(pts, _c(lava), _w(3.2), true)
		for side in [-1.0, 1.0]:
			var drip := fmod(t * 0.7 + (0.5 if side > 0 else 0.0), 1.0)
			ci.draw_circle(body + Vector2(side * 30, 22 + drip * 16), 2.6 * (1.0 - drip), Color(1.0, 0.6, 0.15, 1.0 - drip))
	# eye stalks, in the middle
	for side in [-1.0, 1.0]:
		var base: Vector2 = body + Vector2(side * 8, -24)
		var top: Vector2 = body + Vector2(side * 12, -48) + Vector2(0, sin(t * 2.0 + side) * 1.5)
		_limb(ci, PackedVector2Array([base, top]), 4.0, limb)
		_circle(ci, top, 6.5 if not baby else 8.0, Color(1.0, 0.92, 0.4) if not baby else Color(1, 1, 1))
		ci.draw_circle(top + Vector2(1.2, 0.6), 2.6 if not baby else 3.6, Color(0.08, 0.05, 0.05))
		if baby:
			ci.draw_circle(top + Vector2(2.2, -1.0), 1.2, Color(1, 1, 1))
	# a claw each side, raised, facing outward
	var size := 22.0 if not baby else 17.0
	for side in [-1.0, 1.0]:
		var open := 0.12 + 0.1 * (0.5 + 0.5 * sin(t * 1.7 + (0.9 if side > 0 else 0.0)))
		_claw(ci, body + Vector2(side * 40, -2), body + Vector2(side * 50, -16), size, limb, open, side)


## A pincer: an arm from `root` to the wrist `at`, a fat hand with a fixed finger below and a
## moving one above, `size` units long, opening by `open`, pointing right (side 1) or left (-1).
static func _claw(ci: CanvasItem, root: Vector2, at: Vector2, size: float, col: Color, open: float, side: float = 1.0) -> void:
	var m := Vector2(side, 1.0)
	_limb(ci, PackedVector2Array([root, at]), size * 0.42, col.darkened(0.08))
	var hand := at + Vector2(size * 0.5, -size * 0.12) * m
	var lower := PackedVector2Array([hand + Vector2(size * 0.1, size * 0.18) * m, hand + Vector2(size * 0.55, size * 0.28) * m,
		hand + Vector2(size * 1.15, size * 0.12 + open * size * 0.3) * m, hand + Vector2(size * 0.95, -size * 0.02) * m,
		hand + Vector2(size * 0.35, -size * 0.05) * m])
	var upper := PackedVector2Array([hand + Vector2(size * 0.15, -size * 0.3) * m, hand + Vector2(size * 0.6, -size * 0.55 - open * size * 0.5) * m,
		hand + Vector2(size * 1.1, -size * 0.45 - open * size * 0.9) * m, hand + Vector2(size * 0.9, -size * 0.2 - open * size * 0.4) * m,
		hand + Vector2(size * 0.4, -size * 0.1) * m])
	_shape(ci, lower, col.darkened(0.15))
	_shape(ci, upper, col)
	_ellipse(ci, hand, size * 0.55, size * 0.38, col, -0.2 * side)
	ci.draw_colored_polygon(_ellipse_pts(hand + Vector2(-size * 0.12, -size * 0.14) * m, size * 0.3, size * 0.12, -0.2 * side),
		_c(Color(1, 1, 1, 0.22)))
	ci.draw_circle(hand + Vector2(size * 1.08, -size * 0.43 - open * size * 0.88) * m, size * 0.09, _c(Color(0.15, 0.08, 0.06)))
	ci.draw_circle(hand + Vector2(size * 1.12, size * 0.12 + open * size * 0.3) * m, size * 0.09, _c(Color(0.15, 0.08, 0.06)))


# ── Phù Thuỷ Băng ───────────────────────────────────────────────────────────

const ROBE := Color(0.22, 0.2, 0.5)
const ROBE_LIGHT := Color(0.36, 0.48, 0.88)
const FROST := Color(0.85, 0.96, 1.0)
const ICE := Color(0.45, 0.88, 1.0)


## One of the witch's ice shards drawn in px on ci (centre c, half length r, turned rot): the
## drawn witch's death shatter (match/boss/boss_body.gd).
static func shard(ci: CanvasItem, c: Vector2, r: float, rot: float, alpha: float = 1.0) -> void:
	_s = 1.0
	_out_px = clampf(r * 0.18, 1.0, OUT_PX)
	_flash = 0.0
	_tint = 0.0
	_shard(ci, c, r, rot, alpha)


static func _shard(ci: CanvasItem, c: Vector2, r: float, rot: float, alpha: float = 1.0) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r).rotated(rot), c + Vector2(r * 0.45, 0).rotated(rot), c + Vector2(0, r).rotated(rot),
		c + Vector2(-r * 0.45, 0).rotated(rot)])
	ci.draw_colored_polygon(pts, _c(Color(ICE, alpha)))
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Color(OUT, alpha), _w(2.0), true)
	ci.draw_line(pts[0], pts[2], Color(1, 1, 1, 0.6 * alpha), _w(1.2), true)


## The witch's orbiting shards now: {phase, n, size, reach} (opts shards, else the idle three).
static func _shards(t: float) -> Dictionary:
	var s = _opts.get("shards")
	if s is Dictionary:
		return s
	return {"phase": t * 0.9, "n": 3, "size": 1.0, "reach": 1.0}


static func _witch(ci: CanvasItem, t: float) -> void:
	var glow := 0.5 + 0.5 * sin(t * 2.4)
	var sh := _shards(t)
	var sn := int(sh["n"])
	var ssize := float(sh["size"])
	var sreach := float(sh["reach"])
	# shards behind
	for i in sn:
		var a := float(sh["phase"]) + TAU * i / maxf(sn, 1)
		if sin(a) < 0.0 and ssize > 0.02:
			_shard(ci, Vector2(cos(a) * 44 * sreach, -58 + sin(a) * 8 * sreach), 7.0 * ssize, a, 0.8)
	if _opts.get("flying", false):
		_cape(ci, t, float(_opts.get("lean", 0.0)))
	# frost mist under the hem
	for i in 4:
		var x := -26.0 + i * 17.0 + sin(t * 1.5 + i) * 3.0
		ci.draw_colored_polygon(_ellipse_pts(Vector2(x, -6), 14, 6), Color(0.8, 0.95, 1.0, 0.35))
	# back sleeve
	_limb(ci, PackedVector2Array([Vector2(-10, -72), Vector2(-22, -54), Vector2(-18, -42)]), 9.0, ROBE.darkened(0.2))
	# the robe, its hem wavy with frost trim
	var hem := PackedVector2Array()
	for i in 9:
		var x := 30.0 - i * 7.5
		hem.append(Vector2(x, -12 + (4.0 if i % 2 == 0 else -1.0) + sin(t * 2.0 + i) * 1.5))
	var robe := PackedVector2Array([Vector2(-12, -76), Vector2(12, -76)])
	robe.append_array(hem)
	_shape(ci, robe, ROBE)
	_shape(ci, PackedVector2Array([Vector2(-2, -74), Vector2(8, -74), Vector2(18, -16), Vector2(-6, -14)]), ROBE_LIGHT)
	for i in hem.size() - 1:
		var a := hem[i] + Vector2(0, -3)
		var b := hem[i + 1] + Vector2(0, -3)
		ci.draw_line(a, b, _c(FROST), _w(4.0), true)
	# belt with a crystal
	_box(ci, -12, -54, 26, 5, 2, Color(0.15, 0.13, 0.32))
	_shard(ci, Vector2(2, -51.5), 4.5, 0.0)
	# the staff
	_limb(ci, PackedVector2Array([Vector2(30, -88), Vector2(30, -14)]), 4.0, Color(0.72, 0.78, 0.9))
	_glow(ci, Vector2(30, -98), 9.0, ICE, 0.7 + 0.6 * glow)
	_shape(ci, PackedVector2Array([Vector2(30, -112), Vector2(37, -98), Vector2(30, -86), Vector2(23, -98)]), ICE.lightened(0.2))
	ci.draw_line(Vector2(30, -110), Vector2(30, -88), Color(1, 1, 1, 0.7), _w(1.4), true)
	# front sleeve holding the staff
	_limb(ci, PackedVector2Array([Vector2(8, -72), Vector2(20, -60), Vector2(28, -58)]), 9.0, ROBE)
	_circle(ci, Vector2(29, -58), 4.0, Color(0.78, 0.88, 1.0))
	# hood, face and hair
	_shape(ci, PackedVector2Array([Vector2(-14, -74), Vector2(-20, -92), Vector2(-26, -108), Vector2(-6, -100), Vector2(10, -98), Vector2(18, -84),
		Vector2(14, -72)]), ROBE.darkened(0.1))
	_circle(ci, Vector2(5, -84), 9.0, Color(0.78, 0.88, 1.0))
	for i in 3:
		var x := -8.0 + i * 4.0
		_line(ci, Vector2(x, -92), Vector2(x - 3 + sin(t * 2.0 + i) * 1.5, -66), Color(0.95, 0.98, 1.0), 3.0)
	_glow(ci, Vector2(8, -85), 2.5, ICE, 0.8 + 0.5 * glow)
	ci.draw_circle(Vector2(8, -85.5), 1.8, _c(Color(0.6, 1.0, 1.0)))
	ci.draw_circle(Vector2(3, -85.5), 1.5, _c(Color(0.6, 1.0, 1.0)))
	_line(ci, Vector2(4, -79), Vector2(9, -79.5), Color(0.3, 0.35, 0.6), 1.4)
	# shards in front
	for i in sn:
		var a := float(sh["phase"]) + TAU * i / maxf(sn, 1)
		if sin(a) >= 0.0 and ssize > 0.02:
			_shard(ci, Vector2(cos(a) * 44 * sreach, -58 + sin(a) * 8 * sreach), 8.0 * ssize, a)


## The witch's cape when she flies: from her shoulders it streams back and down, rippling, with a
## frost trim (longer while she leans into a flight).
static func _cape(ci: CanvasItem, t: float, lean: float) -> void:
	var stream := 1.0 + absf(lean) * 2.0
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 7: # the outer edge from the far shoulder back and down, billowing; the inner one down her back
		var k := float(i) / 6.0
		outer.append(Vector2(8.0 - k * 46.0 * stream + sin(t * 3.4 + k * 2.6) * 3.0 * k, -80.0 + k * 60.0 + cos(t * 3.0 + k * 2.0) * 2.0 * k))
		inner.append(Vector2(-6.0 - k * 6.0, -80.0 + k * 62.0))
	var col := _c(Color(0.18, 0.26, 0.6))
	for i in 6: # in triangles (the edges may cross as it streams back): it never fails to fill
		_tri(ci, inner[i], outer[i], outer[i + 1], col)
		_tri(ci, inner[i], outer[i + 1], inner[i + 1], col)
	ci.draw_polyline(outer, OUT, _w(), true)
	ci.draw_line(outer[6], inner[6], OUT, _w(), true)
	var fold := PackedVector2Array()
	for i in 7:
		fold.append(inner[i].lerp(outer[i], 0.55))
	ci.draw_polyline(fold, _c(Color(0.3, 0.42, 0.8, 0.8)), _w(4.0), true)
	ci.draw_line(outer[6] + Vector2(0, -2), inner[6] + Vector2(0, -2), _c(Color(FROST, 0.9)), _w(3.0), true)


## A filled triangle (skipped when it has no area: the renderer cannot triangulate it).
static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	if absf((b - a).cross(c - a)) > 0.01:
		ci.draw_colored_polygon(PackedVector2Array([a, b, c]), col)


# ── Người tuyết ─────────────────────────────────────────────────────────────

const SNOW := Color(0.95, 0.98, 1.0)
const SNOW_SHADE := Color(0.7, 0.82, 0.96)


static func _snowball(ci: CanvasItem, c: Vector2, r: float) -> void:
	_circle(ci, c, r, SNOW)
	ci.draw_arc(c, r * 0.8, PI * 0.05, PI * 0.75, 16, _c(Color(SNOW_SHADE, 0.9)), _w(r * 0.3), true)


static func _snowman(ci: CanvasItem, t: float) -> void:
	var wave := sin(t * 2.4) * 0.15
	# stick arms (behind the middle ball)
	_line(ci, Vector2(-12, -60), Vector2(-34, -72 + wave * 20), Color(0.42, 0.27, 0.14), 3.4)
	_line(ci, Vector2(-30, -70 + wave * 18), Vector2(-36, -80 + wave * 18), Color(0.42, 0.27, 0.14), 2.4)
	_line(ci, Vector2(12, -60), Vector2(34, -50 - wave * 20), Color(0.42, 0.27, 0.14), 3.4)
	_line(ci, Vector2(30, -52 - wave * 18), Vector2(38, -58 - wave * 18), Color(0.42, 0.27, 0.14), 2.4)
	_snowball(ci, Vector2(0, -24), 24.0)
	_snowball(ci, Vector2(0, -58), 17.0)
	_snowball(ci, Vector2(0, -84), 13.0)
	for y in [-64.0, -54.0, -32.0, -20.0]:
		ci.draw_circle(Vector2(4, y), 2.4, _c(Color(0.12, 0.12, 0.16)))
	# scarf
	_shape(ci, PackedVector2Array([Vector2(-13, -74), Vector2(13, -74), Vector2(12, -68), Vector2(-12, -68)]), Color(0.9, 0.25, 0.3))
	_shape(ci, PackedVector2Array([Vector2(-8, -70), Vector2(-2, -70), Vector2(-6 + wave * 6, -52), Vector2(-13 + wave * 6, -54)]), Color(0.8, 0.2, 0.26))
	# face: coal eyes, the carrot, a smile
	ci.draw_circle(Vector2(3, -88), 2.2, _c(Color(0.1, 0.1, 0.14)))
	ci.draw_circle(Vector2(9, -88), 2.2, _c(Color(0.1, 0.1, 0.14)))
	_shape(ci, PackedVector2Array([Vector2(7, -85), Vector2(24, -82), Vector2(7, -80)]), Color(1.0, 0.55, 0.15))
	for i in 4:
		ci.draw_circle(Vector2(1 + i * 3.0, -77 + absf(i - 1.5) * -0.8), 1.2, _c(Color(0.1, 0.1, 0.14)))
	# the pail, a little tilted
	_shape(ci, PackedVector2Array([Vector2(-11, -94), Vector2(9, -98), Vector2(6, -110), Vector2(-8, -107)]), Color(0.3, 0.5, 0.85))
	_line(ci, Vector2(-12, -94), Vector2(10, -98.5), Color(0.2, 0.35, 0.65), 2.6)


# ── Boss v4 helpers ─────────────────────────────────────────────────────────

## A lumpy round stone (c, rx × ry, its bumps by seed) lit from the upper left: the shade colour
## filled to the outline, the lit body over it shifted up-left, a highlight, an ink outline.
static func _boulder(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, seed: float, strata: int = 0) -> void:
	var pts := PackedVector2Array()
	var n := 20
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + 0.06 * sin(a * 3.0 + seed) + 0.035 * sin(a * 5.0 + seed * 2.3)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry) * k)
	ci.draw_colored_polygon(pts, _c(col.darkened(0.3)))
	var lit := PackedVector2Array()
	for p in pts:
		lit.append(c + (p - c) * 0.84 + Vector2(-rx * 0.1, -ry * 0.12))
	ci.draw_colored_polygon(lit, _c(col))
	for j in strata: # rock strata lines across it
		var fy := -0.45 + 0.9 * (j + 1) / float(strata + 1)
		var line := PackedVector2Array()
		var half := sqrt(maxf(0.0, 1.0 - fy * fy)) * rx * 0.8
		for q in 7:
			var u := lerpf(-1.0, 1.0, q / 6.0)
			line.append(c + Vector2(u * half, fy * ry + u * u * ry * 0.06 + sin(u * 5.0 + seed + j) * 1.2))
		ci.draw_polyline(line, _c(col.darkened(0.42)), _w(1.6), true)
	ci.draw_colored_polygon(_ellipse_pts(c + Vector2(-rx * 0.36, -ry * 0.42), rx * 0.3, ry * 0.16, -0.35, 12), _c(Color(col.lightened(0.32), 0.85)))
	var ring := pts.duplicate()
	ring.append(pts[0])
	ci.draw_polyline(ring, OUT, _w(), true)


## A glowing line (an amber rune): a soft wide glow, then a bright core.
static func _rune(ci: CanvasItem, pts: PackedVector2Array, col: Color, strength: float, width: float = 2.2) -> void:
	ci.draw_polyline(pts, Color(col, 0.28 * strength), _w(width * 4.0), true)
	ci.draw_polyline(pts, _c(col.lerp(Color(1, 0.97, 0.8), 0.35 * strength)), _w(width), true)


## A quartz crystal growing from base: a six-sided prism with a point, `len` long, `w` half wide,
## leaning `rot` (radians from upright), a lit facet and a light edge.
static func _crystal(ci: CanvasItem, base: Vector2, length: float, w: float, rot: float, col: Color) -> void:
	var up := Vector2(0, -1).rotated(rot)
	var side := Vector2(1, 0).rotated(rot)
	var tip := base + up * length
	var sh := base + up * length * 0.72
	var pts := PackedVector2Array([base - side * w, sh - side * w, tip, sh + side * w, base + side * w])
	ci.draw_colored_polygon(pts, _c(col.darkened(0.18)))
	ci.draw_colored_polygon(PackedVector2Array([base - side * w, sh - side * w, tip, sh, base]), _c(col.lightened(0.18)))
	var ring := pts.duplicate()
	ring.append(pts[0])
	ci.draw_polyline(ring, OUT, _w(1.6), true)
	ci.draw_line(base + side * w * 0.05, tip, _c(Color(1, 1, 1, 0.55)), _w(1.0), true)


## A tapering limb (a root, a branch): pts from its thick end, w0 → w1 wide, an outline.
static func _taper(ci: CanvasItem, pts: PackedVector2Array, w0: float, w1: float, col: Color) -> void:
	var n := pts.size()
	if n < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var d := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-d.y, d.x)
		var w := lerpf(w0, w1, i / float(n - 1)) * 0.5
		left.append(pts[i] + nrm * w)
		right.append(pts[i] - nrm * w)
	right.reverse()
	var poly := left.duplicate()
	poly.append_array(right)
	ci.draw_colored_polygon(poly, _c(col))
	poly.append(poly[0])
	ci.draw_polyline(poly, OUT, _w(), true)


# ── Khổng Lồ Đá ─────────────────────────────────────────────────────────────

const SAND := Color(0.69, 0.48, 0.27) # #B07A45
const SAND_DARK := Color(0.43, 0.29, 0.18) # #6E4A2E
const SAND_LIGHT := Color(0.85, 0.65, 0.4) # #D9A766
const AMBER := Color(1.0, 0.76, 0.24) # #FFC23D
const PLATE := Color(0.6, 0.56, 0.5)
const PLATE_DARK := Color(0.42, 0.38, 0.33)
## The stone plates of the giant's armour (unit frame): polygons and the way each flies off when
## the armour breaks (its push, px/s, and spin).
const PLATES := [
	{"pts": [Vector2(-40, -94), Vector2(-20, -100), Vector2(-14, -84), Vector2(-26, -72), Vector2(-44, -78)], "v": Vector2(-90, -150), "spin": -4.0},
	{"pts": [Vector2(18, -98), Vector2(42, -94), Vector2(48, -78), Vector2(32, -70), Vector2(16, -82)], "v": Vector2(100, -170), "spin": 4.5},
	{"pts": [Vector2(-24, -76), Vector2(-4, -80), Vector2(-2, -58), Vector2(-14, -46), Vector2(-28, -56)], "v": Vector2(-70, -60), "spin": -3.0},
	{"pts": [Vector2(10, -80), Vector2(32, -74), Vector2(34, -54), Vector2(20, -44), Vector2(8, -56)], "v": Vector2(80, -80), "spin": 3.2},
	{"pts": [Vector2(-18, -40), Vector2(20, -40), Vector2(16, -26), Vector2(-14, -26)], "v": Vector2(10, -40), "spin": 1.5},
]
const PLATE_BREAK_SEC := 0.9 # the plates fly off and fade over this
const PLATE_GRAVITY := 520.0 # units/s²


static func _giant(ci: CanvasItem, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 2.2)
	var sway := sin(t * 1.2) * 1.6
	var heal := clampf(float(_opts.get("heal", 0.0)), 0.0, 1.0)
	var glow := 0.55 + 0.45 * pulse + heal * 0.5
	# the back arm and its fist (behind everything, darker)
	_limb(ci, PackedVector2Array([Vector2(-28, -82), Vector2(-40, -62), Vector2(-46, -42)]), 15.0, SAND_DARK.lightened(0.06))
	_boulder(ci, Vector2(-47 - sway * 0.4, -26), 17.0, 15.5, SAND_DARK.lightened(0.1), 4.2, 1)
	# stumpy legs on flat stone feet
	_boulder(ci, Vector2(-14, -16), 13.0, 13.0, SAND_DARK.lightened(0.04), 1.1)
	_box(ci, -30, -8, 28, 8, 3, SAND_DARK)
	_boulder(ci, Vector2(13, -15), 13.0, 13.0, SAND, 2.7)
	_box(ci, -1, -8, 30, 8, 3, SAND_DARK.lightened(0.12))
	# the belly boulder, then the huge chest boulder
	_boulder(ci, Vector2(0, -33), 27.0, 16.0, SAND_DARK.lightened(0.14), 5.3, 1)
	_boulder(ci, Vector2(3, -61), 36.0, 29.0, SAND, 0.6, 2)
	# rune lines from the gem across the chest and down the arm
	var runes := [[Vector2(4, -60), Vector2(-6, -66), Vector2(-14, -64), Vector2(-24, -72)],
		[Vector2(4, -60), Vector2(16, -66), Vector2(24, -64), Vector2(32, -72)],
		[Vector2(4, -60), Vector2(2, -50), Vector2(-6, -44)], [Vector2(4, -60), Vector2(12, -48), Vector2(20, -44)]]
	for r in runes:
		_rune(ci, PackedVector2Array(r), AMBER, glow)
	# the amber gem
	_glow(ci, Vector2(4, -60), 9.0, AMBER, glow)
	_shape(ci, PackedVector2Array([Vector2(4, -71), Vector2(12, -60), Vector2(4, -49), Vector2(-4, -60)]), AMBER.darkened(0.12))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(4, -69), Vector2(9, -60), Vector2(4, -57), Vector2(-1, -61)]),
		_c(AMBER.lerp(Color(1, 0.97, 0.8), 0.5 + 0.3 * pulse)))
	ci.draw_circle(Vector2(2, -64), 1.8, Color(1, 1, 1, 0.9))
	# the head, sunk between the shoulders: a heavy brow, glowing eyes, a stern frown
	_boulder(ci, Vector2(8, -93), 14.0, 11.5, SAND, 3.4)
	_shape(ci, PackedVector2Array([Vector2(-3, -97), Vector2(8, -101), Vector2(21, -98), Vector2(20, -94), Vector2(8, -96), Vector2(-2, -94)]),
		SAND_DARK)
	for ex in [5.0, 15.0]:
		_glow(ci, Vector2(ex, -91.5), 2.6, AMBER, 0.8 + 0.4 * pulse)
		ci.draw_colored_polygon(_ellipse_pts(Vector2(ex, -91.5), 2.6, 1.5, 0.0, 10), _c(AMBER.lerp(Color(1, 0.95, 0.7), 0.4)))
	_line(ci, Vector2(5, -85), Vector2(14, -86.5), SAND_DARK.darkened(0.3), 1.6)
	# the shoulders, amber quartz growing from them
	_boulder(ci, Vector2(-28, -82), 15.0, 13.0, SAND_DARK.lightened(0.16), 2.2, 1)
	for c in [[Vector2(-34, -92), 12.0, -0.5], [Vector2(-27, -94), 16.0, -0.12], [Vector2(-20, -92), 10.0, 0.3]]:
		_crystal(ci, c[0], c[1], 3.4, c[2], AMBER.lerp(Color(1.0, 0.88, 0.5), 0.3))
	# the front arm down to its enormous fist (bigger than the head), under its shoulder
	_limb(ci, PackedVector2Array([Vector2(38, -72), Vector2(46, -58), Vector2(50, -42)]), 16.0, SAND)
	_rune(ci, PackedVector2Array([Vector2(39, -68), Vector2(44, -60), Vector2(47, -48)]), AMBER, glow * 0.8, 1.8)
	_boulder(ci, Vector2(32, -80), 16.0, 14.0, SAND, 6.1, 1)
	for c in [[Vector2(26, -91), 11.0, -0.35], [Vector2(33, -93), 17.0, 0.1], [Vector2(41, -89), 12.0, 0.5]]:
		_crystal(ci, c[0], c[1], 3.6, c[2], AMBER.lerp(Color(1.0, 0.88, 0.5), 0.3))
	var fist := Vector2(52 + sway * 0.5, -26)
	_boulder(ci, fist, 19.0, 17.0, SAND, 7.7, 1)
	for k in 3: # knuckles
		var a := Vector2(fist.x + 6.0 + k * 0.5, fist.y - 9.0 + k * 7.0)
		_line(ci, a, a + Vector2(9, 1), SAND_DARK, 1.6)
	_plates(ci, t)


## The stone armour on the giant (opts plates 0..1 popping in; plates_break s since it broke: the
## plates fly off and fade, PLATE_BREAK_SEC).
static func _plates(ci: CanvasItem, t: float) -> void:
	var k := clampf(float(_opts.get("plates", 0.0)), 0.0, 1.0)
	var brk := float(_opts.get("plates_break", -1.0))
	if k <= 0.0 and (brk < 0.0 or brk >= PLATE_BREAK_SEC):
		return
	var glow := 0.55 + 0.45 * sin(t * 3.0)
	for i in PLATES.size():
		var pl: Dictionary = PLATES[i]
		var src: Array = pl["pts"]
		var c := Vector2.ZERO
		for p in src:
			c += p
		c /= src.size()
		var off := Vector2.ZERO
		var rot := 0.0
		var a := 1.0
		var grow := 1.0
		if brk >= 0.0:
			off = Vector2(pl["v"]) * brk + Vector2(0, 0.5 * PLATE_GRAVITY * brk * brk)
			rot = float(pl["spin"]) * brk
			a = clampf(1.0 - (brk - PLATE_BREAK_SEC * 0.45) / (PLATE_BREAK_SEC * 0.55), 0.0, 1.0)
		else:
			var u := clampf(k * 1.4 - i * 0.08, 0.0, 1.0) # one after another
			grow = 0.3 + 0.7 * u + 0.12 * sin(u * PI)
			a = minf(1.0, u * 3.0)
		if a <= 0.0:
			continue
		var pts := PackedVector2Array()
		for p in src:
			pts.append(c + off + ((p - c) * grow).rotated(rot))
		ci.draw_colored_polygon(pts, _c(Color(PLATE_DARK, a)))
		var lit := PackedVector2Array()
		for p in pts:
			lit.append((c + off) + (p - (c + off)) * 0.78 + Vector2(-1.5, -1.5))
		ci.draw_colored_polygon(lit, _c(Color(PLATE, a)))
		var ring := pts.duplicate()
		ring.append(pts[0])
		if brk < 0.0: # the rune edge glows while it holds
			ci.draw_polyline(ring, Color(AMBER, 0.35 * glow * a), _w(5.0), true)
		ci.draw_polyline(ring, Color(OUT, a), _w(), true)
		ci.draw_line(lit[0], lit[1], _c(Color(1, 1, 1, 0.35 * a)), _w(1.2), true)
		if brk < 0.0:
			ci.draw_circle(c + Vector2(0.5, 0.5), 1.8, Color(AMBER.lightened(0.3), 0.6 + 0.4 * glow))


# ── Trụ đá ──────────────────────────────────────────────────────────────────

static func _totem(ci: CanvasItem, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 2.6)
	var nod := float(_opts.get("nod", 0.0)) # a shot: the top block nods forward
	_box(ci, -25, -8, 50, 8, 3, SAND_DARK)
	_shape(ci, _rrect(-21, -35, 42, 28, 5), SAND_DARK.lightened(0.1))
	_line(ci, Vector2(-18, -22), Vector2(18, -21), SAND_DARK.darkened(0.25), 1.4)
	_shape(ci, _rrect(-18, -61, 36, 27, 5), SAND)
	ci.draw_colored_polygon(_rrect(-15, -58, 14, 10, 3), _c(SAND_LIGHT))
	# the rune on the middle block
	var rune := PackedVector2Array([Vector2(-6, -54), Vector2(0, -42), Vector2(6, -54)])
	_rune(ci, rune, AMBER, 0.6 + 0.6 * pulse, 2.0)
	_rune(ci, PackedVector2Array([Vector2(-4, -48), Vector2(4, -48)]), AMBER, 0.6 + 0.6 * pulse, 1.6)
	# the top block with its grumpy face, tilting with a nod
	var top := Transform2D(nod * 0.25, Vector2(0, -61))
	var pts := PackedVector2Array()
	for p in _rrect(-20, -31, 40, 31, 6):
		pts.append(top * p)
	_shape(ci, pts, SAND)
	var face := func(p: Vector2) -> Vector2: return top * p
	ci.draw_colored_polygon(PackedVector2Array([face.call(Vector2(-17, -28)), face.call(Vector2(0, -28)), face.call(Vector2(-4, -21)),
		face.call(Vector2(-17, -20))]), _c(SAND_LIGHT))
	_line(ci, face.call(Vector2(-12, -20)), face.call(Vector2(-1, -17)), SAND_DARK.darkened(0.3), 2.4) # the brows, frowning
	_line(ci, face.call(Vector2(5, -17)), face.call(Vector2(16, -20)), SAND_DARK.darkened(0.3), 2.4)
	for ex in [-6.0, 10.0]:
		_glow(ci, face.call(Vector2(ex, -13)), 2.6, AMBER, 0.7 + 0.5 * pulse)
		ci.draw_circle(face.call(Vector2(ex, -13)), 2.3, _c(AMBER.lerp(Color(1, 0.95, 0.7), 0.35)))
	_line(ci, face.call(Vector2(-3, -5)), face.call(Vector2(9, -6)), SAND_DARK.darkened(0.35), 2.0)
	# a small amber crystal on top
	_crystal(ci, face.call(Vector2(3, -30)), 12.0, 3.6, 0.15 + nod * 0.25, AMBER)
	_glow(ci, face.call(Vector2(3, -38)), 3.0, AMBER, 0.4 + 0.5 * pulse)


# ── Mộc Tinh ────────────────────────────────────────────────────────────────

const BARK := Color(0.48, 0.32, 0.2) # #7A5232
const BARK_DARK := Color(0.3, 0.2, 0.125) # #4D3320
const BARK_LIGHT := Color(0.66, 0.48, 0.31) # #A87A4F
const SAP := Color(1.0, 0.79, 0.3) # #FFC94D
const SPIRIT_EYE := Color(0.84, 1.0, 0.4) # #D6FF66
const LEAF_MID := Color(0.31, 0.66, 0.24) # #4FA83D
const LEAF_LIGHT := Color(0.56, 0.85, 0.35) # #8FD95A
const LEAF_DARK := Color(0.18, 0.42, 0.165) # #2E6B2A
const BLOSSOM := Color(1.0, 0.97, 0.86)
const FRUIT := Color(1.0, 0.8, 0.25)
## The crown's leaf clumps [centre, radius] (unit frame), back to front.
const CROWN := [[Vector2(-34, -78), 17.0], [Vector2(34, -80), 17.0], [Vector2(-22, -96), 19.0], [Vector2(20, -98), 20.0],
	[Vector2(0, -104), 18.0], [Vector2(-40, -90), 13.0], [Vector2(42, -92), 13.0], [Vector2(0, -86), 22.0]]


static func _tree(ci: CanvasItem, t: float) -> void:
	var sway := sin(t * 1.1)
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	var heal := clampf(float(_opts.get("heal", 0.0)), 0.0, 1.0)
	# roots spread on the ground
	for r in [[Vector2(-12, -10), Vector2(-30, -5), Vector2(-52, 0), 11.0], [Vector2(-4, -8), Vector2(-14, -2), Vector2(-28, 1), 8.0],
			[Vector2(12, -10), Vector2(30, -5), Vector2(54, 0), 11.0], [Vector2(6, -8), Vector2(18, -2), Vector2(32, 1), 8.0]]:
		_taper(ci, PackedVector2Array([r[0], r[1], r[2]]), r[3], 2.5, BARK_DARK.lightened(0.12))
	# the back branch arm with its twig claws
	var back := PackedVector2Array([Vector2(-18, -56), Vector2(-34, -54 + sway), Vector2(-46, -44 + sway * 1.5)])
	_taper(ci, back, 9.0, 5.0, BARK_DARK.lightened(0.05))
	for f in [-0.6, 0.0, 0.6]:
		_taper(ci, PackedVector2Array([back[2], back[2] + Vector2(-7, 6).rotated(f)]), 3.6, 1.0, BARK_DARK.lightened(0.05))
	# the gnarled trunk
	var trunk := PackedVector2Array([Vector2(-22, -2), Vector2(-26, -14), Vector2(-21, -30), Vector2(-24, -48), Vector2(-19, -66),
		Vector2(-6, -72), Vector2(8, -72), Vector2(20, -66), Vector2(23, -50), Vector2(20, -32), Vector2(26, -14), Vector2(23, -2)])
	_shape(ci, trunk, BARK)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-20, -4), Vector2(-24, -14), Vector2(-19, -30), Vector2(-22, -48), Vector2(-17, -64),
		Vector2(-10, -66), Vector2(-14, -46), Vector2(-11, -26), Vector2(-14, -6)]), _c(BARK_LIGHT))
	for g in [[Vector2(-4, -6), Vector2(-7, -18), Vector2(-3, -30)], [Vector2(12, -4), Vector2(14, -16), Vector2(10, -34)],
			[Vector2(17, -40), Vector2(19, -52), Vector2(15, -62)]]:
		ci.draw_polyline(PackedVector2Array(g), _c(BARK_DARK), _w(2.0), true)
	# the sap heart: a glowing amber knot
	var hb := 0.6 + 0.4 * pulse + heal * 0.8
	_glow(ci, Vector2(3, -27), 9.0, SAP, hb)
	_ellipse(ci, Vector2(3, -27), 8.0, 7.0, BARK_DARK)
	ci.draw_colored_polygon(_ellipse_pts(Vector2(3, -27), 5.6, 4.8), _c(SAP.lerp(Color(1, 0.97, 0.8), 0.25 * pulse + 0.4 * heal)))
	ci.draw_arc(Vector2(3, -27), 3.0, PI * 1.1, PI * 1.7, 8, Color(1, 1, 1, 0.75), _w(1.2), true)
	# the face in the bark: a heavy brow, glowing eyes, a wide crack of a mouth and a leafy beard
	_shape(ci, PackedVector2Array([Vector2(-13, -62), Vector2(2, -66), Vector2(19, -62), Vector2(18, -57), Vector2(3, -59), Vector2(-12, -57)]),
		BARK_DARK)
	for ex in [-5.0, 11.0]:
		_glow(ci, Vector2(ex, -53), 3.2, SPIRIT_EYE, 0.8 + 0.5 * pulse + heal * 0.5)
		ci.draw_colored_polygon(_ellipse_pts(Vector2(ex, -53), 3.0, 2.2, 0.0, 10), _c(SPIRIT_EYE))
		ci.draw_circle(Vector2(ex + 0.8, -53), 1.0, Color(1, 1, 1, 0.9))
	ci.draw_polyline(PackedVector2Array([Vector2(-8, -43), Vector2(-3, -45), Vector2(2, -42), Vector2(7, -45), Vector2(13, -43)]),
		_c(BARK_DARK.darkened(0.4)), _w(3.0), true)
	for i in 6: # the beard of hanging leaves, swaying
		var x := -8.0 + i * 4.0
		var tip := Vector2(x + sway * 1.6 * (0.5 + i * 0.1), -30.0 - absf(i - 2.5) * 1.6)
		_leaf_hang(ci, Vector2(x, -41), tip, LEAF_MID if i % 2 == 0 else LEAF_DARK.lightened(0.15))
	# the front branch arm reaching forward, twig claws and a few leaves
	var arm := PackedVector2Array([Vector2(18, -56), Vector2(34, -54 - sway), Vector2(48, -42 - sway * 1.5)])
	_taper(ci, arm, 10.0, 5.0, BARK)
	for f in [-0.7, 0.0, 0.7]:
		_taper(ci, PackedVector2Array([arm[2], arm[2] + Vector2(8, 5).rotated(f)]), 3.8, 1.0, BARK)
	_leaf_hang(ci, Vector2(30, -55 - sway), Vector2(34, -64 - sway), LEAF_LIGHT)
	_leaf_hang(ci, Vector2(38, -50 - sway), Vector2(42, -42 - sway), LEAF_MID)
	_crown(ci, t, sway)


## A leaf hanging from `at` to `tip`: a pointed oval, a midrib, an outline.
static func _leaf_hang(ci: CanvasItem, at: Vector2, tip: Vector2, col: Color) -> void:
	var d := tip - at
	var n := Vector2(-d.y, d.x).normalized() * d.length() * 0.28
	var pts := PackedVector2Array([at, at + d * 0.5 + n, tip, at + d * 0.5 - n])
	_shape(ci, pts, col)
	ci.draw_line(at, tip, _c(col.darkened(0.35)), _w(0.9), true)


## The round leaf crown (CROWN's clumps under one outline), light on top, dark under, cream
## blossoms and glowing golden fruits in it; it sways a little.
static func _crown(ci: CanvasItem, t: float, sway: float) -> void:
	var off := Vector2(sway * 1.4, 0)
	for i in 7: # single leaves sticking out of the rim, rustling
		var a := PI * 1.12 + PI * 0.76 * i / 6.0
		var p := Vector2(0, -88) + off + Vector2(cos(a) * 46.0, sin(a) * 27.0)
		var out := Vector2.from_angle(a + sin(t * 2.0 + i) * 0.12) * 9.0
		_leaf_hang(ci, p, p + out, LEAF_LIGHT if i % 2 == 0 else LEAF_MID)
	for c in CROWN: # one outline round them all: the clumps' outline discs first
		ci.draw_circle(c[0] + off * (1.0 + c[0].y / -100.0), c[1] + _w(), OUT)
	for c in CROWN:
		var p: Vector2 = c[0] + off * (1.0 + c[0].y / -100.0)
		ci.draw_circle(p, c[1], _c(LEAF_DARK))
		ci.draw_circle(p + Vector2(-c[1] * 0.12, -c[1] * 0.16), c[1] * 0.84, _c(LEAF_MID))
		ci.draw_circle(p + Vector2(-c[1] * 0.3, -c[1] * 0.38), c[1] * 0.42, _c(LEAF_LIGHT))
	for b in [Vector2(-26, -100), Vector2(14, -110), Vector2(32, -88), Vector2(-38, -82), Vector2(4, -92)]:
		_blossom(ci, b + off, 3.6)
	var fruit_glow := 0.6 + 0.4 * sin(t * 2.4)
	for f in [Vector2(-14, -74), Vector2(24, -76), Vector2(40, -98), Vector2(-44, -94)]:
		var p: Vector2 = f + off + Vector2(0, sin(t * 1.8 + f.x) * 0.8)
		_glow(ci, p, 3.0, FRUIT, fruit_glow)
		_circle(ci, p, 3.4, FRUIT)
		ci.draw_circle(p + Vector2(-1, -1.2), 1.0, Color(1, 1, 0.9, 0.9))


static func _blossom(ci: CanvasItem, c: Vector2, r: float) -> void:
	for i in 5:
		var a := TAU * i / 5.0 - PI / 2.0
		_circle(ci, c + Vector2.from_angle(a) * r * 0.7, r * 0.55, BLOSSOM)
	ci.draw_circle(c, r * 0.4, _c(FRUIT))


# ── Nấm độc ─────────────────────────────────────────────────────────────────

const CAP := Color(0.72, 0.85, 0.21) # #B8D936
const CAP_DARK := Color(0.48, 0.6, 0.12) # #7A9A1F
const CAP_SPOT := Color(0.4, 0.46, 0.13)
const STEM := Color(0.95, 0.9, 0.78) # #F2E6C8
const SPORE := Color(0.82, 0.95, 0.35)


## Its squash now (x, y scale) from opts puff (s since its spore puff began: squashed hard, sprung
## up, settling; < 0 none) and the idle wobble.
static func mushroom_squash(t: float, puff: float) -> Vector2:
	var s := 1.0 + sin(t * 3.0) * 0.035
	if puff >= 0.0 and puff < 0.7:
		if puff < 0.18:
			s = lerpf(1.0, 0.72, puff / 0.18)
		elif puff < 0.34:
			s = lerpf(0.72, 1.22, (puff - 0.18) / 0.16)
		else:
			s = 1.0 + 0.22 * cos((puff - 0.34) / 0.36 * PI * 1.5) * (1.0 - (puff - 0.34) / 0.36)
	return Vector2(1.0 / sqrt(s), s)


static func _mushroom(ci: CanvasItem, t: float) -> void:
	var sq := mushroom_squash(t, float(_opts.get("puff", -1.0)))
	var wob := sin(t * 3.0 + 0.6) * 0.05
	var xf := Transform2D(0.0, sq, 0.0, Vector2.ZERO)
	var P := func(p: Vector2) -> Vector2: return xf * p
	var ps := func(arr: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in arr:
			out.append(xf * p)
		return out
	# tiny feet
	for fx in [-9.0, 9.0]:
		_shape(ci, ps.call(Array(_ellipse_pts(Vector2(fx, -3), 7.0, 4.0))), STEM.darkened(0.12))
	# the stem: its body, an angry face
	_shape(ci, ps.call([Vector2(-14, -4), Vector2(-17, -24), Vector2(-14, -46), Vector2(14, -46), Vector2(17, -24), Vector2(14, -4)]), STEM)
	ci.draw_colored_polygon(ps.call([Vector2(6, -6), Vector2(13, -8), Vector2(15, -24), Vector2(12, -42), Vector2(8, -42), Vector2(10, -24)]),
		_c(STEM.darkened(0.12)))
	_line(ci, P.call(Vector2(-10, -33)), P.call(Vector2(-3, -29)), Color(0.22, 0.2, 0.1), 2.2)
	_line(ci, P.call(Vector2(3, -29)), P.call(Vector2(10, -33)), Color(0.22, 0.2, 0.1), 2.2)
	for ex in [-6.0, 6.0]:
		ci.draw_circle(P.call(Vector2(ex, -25)), 2.4, _c(Color(0.16, 0.14, 0.08)))
		ci.draw_circle(P.call(Vector2(ex + 0.8, -25.8)), 0.8, Color(1, 1, 1, 0.9))
	ci.draw_polyline(ps.call([Vector2(-5, -15), Vector2(0, -18), Vector2(5, -15)]), _c(Color(0.22, 0.2, 0.1)), _w(2.0), true)
	# the cap: a big dome with a pale rim of gills, spots, wobbling
	var cap := Transform2D(wob, Vector2(0, -44))
	var dome := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		dome.append(xf * (cap * Vector2(cos(a) * 42.0, sin(a) * 40.0)))
	for i in 7: # the underside, a shallow curve
		var u := lerpf(1.0, -1.0, i / 6.0)
		dome.append(xf * (cap * Vector2(u * 40.0, 6.0 - u * u * 4.0)))
	ci.draw_colored_polygon(dome, _c(CAP_DARK))
	var lit := PackedVector2Array()
	for i in 15:
		var a := PI + PI * (i + 1) / 16.0
		lit.append(xf * (cap * Vector2(cos(a) * 37.0 - 3.0, sin(a) * 35.0 - 1.0)))
	lit.append(xf * (cap * Vector2(-36, -2)))
	ci.draw_colored_polygon(lit, _c(CAP))
	ci.draw_colored_polygon(ps.call([cap * Vector2(-38, 0), cap * Vector2(38, 0), cap * Vector2(34, 5), cap * Vector2(-34, 5)]),
		_c(STEM.darkened(0.2)))
	for sp in [[Vector2(-20, -18), 6.0], [Vector2(6, -28), 7.5], [Vector2(24, -14), 5.0], [Vector2(-6, -10), 4.0], [Vector2(-28, -6), 3.6]]:
		ci.draw_colored_polygon(ps.call(Array(_ellipse_pts(cap * sp[0], sp[1], sp[1] * 0.8, wob, 12))), _c(CAP_SPOT))
	ci.draw_colored_polygon(ps.call(Array(_ellipse_pts(cap * Vector2(-16, -30), 9.0, 4.0, -0.5, 12))), _c(Color(1, 1, 0.85, 0.45)))
	var ring := dome.duplicate()
	ring.append(dome[0])
	ci.draw_polyline(ring, OUT, _w(), true)
	# faint spores floating round the cap
	for i in 5:
		var ph := fmod(t * 0.35 + i / 5.0, 1.0)
		var p := Vector2(sin(i * 2.4 + t * 0.8) * 44.0, -60.0 - ph * 44.0)
		ci.draw_circle(p, 1.8 + (i % 2), Color(SPORE, 0.55 * sin(ph * PI)))


# ── Generic ─────────────────────────────────────────────────────────────────

static func _blob(ci: CanvasItem, t: float, col: Color) -> void:
	var squash := 1.0 + sin(t * 2.0) * 0.03
	_shape(ci, _ellipse_pts(Vector2(0, -42 * squash), 34, 42 * squash), col)
	ci.draw_colored_polygon(_ellipse_pts(Vector2(-8, -62), 16, 9), Color(1, 1, 1, 0.25))
	for x in [6.0, 20.0]:
		_circle(ci, Vector2(x, -52), 6.0, Color(1, 1, 0.85))
		ci.draw_circle(Vector2(x + 2, -52), 2.6, Color(0.1, 0.05, 0.1))
	_line(ci, Vector2(4, -34), Vector2(22, -36), Color(0.2, 0.08, 0.2), 2.4)
