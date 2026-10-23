extends RefCounted
## Placeholder art of the bosses and their minions, drawn in code (original designs, cartoon with
## a dark outline like the characters; the real art replaces it later): Rô-bốt Thép (a steel mech
## titan with a reactor core, a visor, an arm cannon and a claw), its Drone (a floating eye with two
## rotors), Cua Dung Nham (a basalt-shelled lava crab with glowing cracks, eye stalks and two
## pincers), its Cua con (a small bright crab), Phù Thuỷ Băng (a hooded ice witch floating on frost
## mist with a crystal staff and orbiting shards) and its Người tuyết (a snowman with a pail, a
## scarf and a carrot nose). Any other boss / minion id gets a generic blob of its side.
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
const ARTS := ["steel_robot", "drone", "lava_crab", "crab", "ice_witch", "snowman"]
const GENERIC_BOSS := "generic_boss"
const GENERIC_MINION := "generic_minion"
## Where each figure floats (units above the feet the bob is around; 0 stands).
const HOVER := {"drone": 10.0, "ice_witch": 6.0}
## The shot look of each boss's skills (ShotLook kind × tier: the shells of its rain, its beam's
## colours); others use the default look.
const SHOT_LOOK := {"steel_robot": {"kind": "cannon", "tier": "titan"}, "lava_crab": {"kind": "bazooka", "tier": "dragon"},
	"ice_witch": {"kind": "shock_rifle", "tier": "iron"}}
## The point (unit frame, facing right) a boss's beam and muzzle flash leave from.
const MUZZLE := {"steel_robot": Vector2(64, -60), "lava_crab": Vector2(62, -50), "ice_witch": Vector2(30, -98),
	"drone": Vector2(10, -62), "crab": Vector2(60, -40), "snowman": Vector2(26, -58)}
## The accent colour of each art (the HUD bar's name, the shield's tint, the card's glow).
const ACCENT := {"steel_robot": Color(1.0, 0.62, 0.22), "drone": Color(1.0, 0.35, 0.3), "lava_crab": Color(1.0, 0.45, 0.12),
	"crab": Color(1.0, 0.55, 0.3), "ice_witch": Color(0.5, 0.9, 1.0), "snowman": Color(0.7, 0.9, 1.0),
	GENERIC_BOSS: Color(0.85, 0.5, 1.0), GENERIC_MINION: Color(0.85, 0.6, 0.9)}

## How wide each figure is for its height (the shield's ellipse, a UI box fitting it).
const WIDTH := {"lava_crab": 1.7, "crab": 1.7, "steel_robot": 1.35, "ice_witch": 1.1}

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
	return 42.0


## How a minion's own blast looks (its detonation, its death blast): the ExplosionFx kind × tier
## of the burst and whether it is icy (frost shards and snow instead of fire and shrapnel).
const BLAST_LOOK := {"drone": {"kind": "cannon", "tier": "dragon", "icy": false},
	"crab": {"kind": "bazooka", "tier": "dragon", "icy": false},
	"snowman": {"kind": "shock_rifle", "tier": "mithril", "icy": true},
	GENERIC_MINION: {"kind": "bazooka", "tier": "dragon", "icy": false}}
## The storm a boss's map-wide rain blows across the screen (match/boss/storm_overlay.gd kind).
const STORM := {"ice_witch": "snow", "lava_crab": "ember"}
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
	var shell := Color(0.85, 0.32, 0.14) if baby else Color(0.24, 0.16, 0.15)
	var shell_light := Color(1.0, 0.55, 0.3) if baby else Color(0.4, 0.26, 0.22)
	var limb := Color(0.95, 0.42, 0.18) if baby else Color(0.78, 0.26, 0.1)
	var limb_dark := limb.darkened(0.3)
	var glow := 0.5 + 0.5 * sin(t * 2.6)
	var step := sin(t * 5.0)
	var body := Vector2(0, -38)
	# legs: three a side, the far side darker
	for i in 3:
		var k := float(i)
		for side in [-1.0, 1.0]:
			var col := limb_dark if side < 0 else limb
			var root := body + Vector2(side * (18 + k * 9), 8)
			var knee := root + Vector2(side * (10 + k * 2), -10 + k * 2 + step * (1.5 if i % 2 == 0 else -1.5))
			var tip := Vector2(root.x + side * (16 + k * 3), 0)
			_limb(ci, PackedVector2Array([root, knee, tip]), 6.5, col)
	# the far claw (behind the shell)
	var open := 0.12 + 0.1 * (0.5 + 0.5 * sin(t * 1.7))
	_claw(ci, body + Vector2(30, -14), body + Vector2(44, -30), 20.0 if not baby else 15.0, limb_dark, open)
	# shell
	_ellipse(ci, body, 52, 30, shell)
	_shape(ci, PackedVector2Array([body + Vector2(-46, 10), body + Vector2(46, 10), body + Vector2(36, 24), body + Vector2(-36, 24)]),
		Color(1.0, 0.7, 0.45) if baby else Color(0.55, 0.3, 0.2))
	ci.draw_colored_polygon(_ellipse_pts(body + Vector2(-8, -14), 34, 10), _c(Color(shell_light, 0.85)))
	if not baby:
		for s in [[-30, -20], [-6, -27], [18, -24], [38, -14]]:
			_shape(ci, PackedVector2Array([body + Vector2(s[0] - 5, s[1] + 4), body + Vector2(s[0], s[1] - 8), body + Vector2(s[0] + 5, s[1] + 4)]),
				Color(0.18, 0.12, 0.11))
		var lava := Color(1.0, 0.55, 0.12).lerp(Color(1.0, 0.85, 0.35), glow)
		for crack in [[Vector2(-38, -2), Vector2(-24, -8), Vector2(-16, 2), Vector2(-4, -6)], [Vector2(6, -14), Vector2(16, -4), Vector2(30, -10)],
				[Vector2(-20, 10), Vector2(-6, 4), Vector2(10, 12), Vector2(26, 4)]]:
			var pts := PackedVector2Array()
			for p in crack:
				pts.append(body + p)
			ci.draw_polyline(pts, Color(1.0, 0.45, 0.1, 0.35 * (0.6 + glow)), _w(9.0), true)
			ci.draw_polyline(pts, _c(lava), _w(3.2), true)
		var drip := fmod(t * 0.7, 1.0)
		ci.draw_circle(body + Vector2(-30, 22 + drip * 16), 2.6 * (1.0 - drip), Color(1.0, 0.6, 0.15, 1.0 - drip))
	# eye stalks
	for e in [[Vector2(8, -24), Vector2(10, -48)], [Vector2(22, -22), Vector2(28, -44)]]:
		var top: Vector2 = body + e[1] + Vector2(0, sin(t * 2.0 + e[1].x) * 1.5)
		_limb(ci, PackedVector2Array([body + e[0], top]), 4.0, limb)
		_circle(ci, top, 6.5 if not baby else 8.0, Color(1.0, 0.92, 0.4) if not baby else Color(1, 1, 1))
		ci.draw_circle(top + Vector2(2, 0), 2.6 if not baby else 3.6, Color(0.08, 0.05, 0.05))
		if baby:
			ci.draw_circle(top + Vector2(3, -1.5), 1.2, Color(1, 1, 1))
	# the near claw
	_claw(ci, body + Vector2(38, 4), body + Vector2(54, -4), 25.0 if not baby else 18.0, limb, open + 0.05)


## A pincer: an arm from `root` to the wrist `at`, a fat hand with a fixed finger below and a
## moving one above, `size` units long, opening by `open`.
static func _claw(ci: CanvasItem, root: Vector2, at: Vector2, size: float, col: Color, open: float) -> void:
	_limb(ci, PackedVector2Array([root, at]), size * 0.42, col.darkened(0.08))
	var hand := at + Vector2(size * 0.5, -size * 0.12)
	var lower := PackedVector2Array([hand + Vector2(size * 0.1, size * 0.18), hand + Vector2(size * 0.55, size * 0.28),
		hand + Vector2(size * 1.15, size * 0.12 + open * size * 0.3), hand + Vector2(size * 0.95, -size * 0.02), hand + Vector2(size * 0.35, -size * 0.05)])
	var upper := PackedVector2Array([hand + Vector2(size * 0.15, -size * 0.3), hand + Vector2(size * 0.6, -size * 0.55 - open * size * 0.5),
		hand + Vector2(size * 1.1, -size * 0.45 - open * size * 0.9), hand + Vector2(size * 0.9, -size * 0.2 - open * size * 0.4),
		hand + Vector2(size * 0.4, -size * 0.1)])
	_shape(ci, lower, col.darkened(0.15))
	_shape(ci, upper, col)
	_ellipse(ci, hand, size * 0.55, size * 0.38, col, -0.2)
	ci.draw_colored_polygon(_ellipse_pts(hand + Vector2(-size * 0.12, -size * 0.14), size * 0.3, size * 0.12, -0.2), _c(Color(1, 1, 1, 0.22)))
	ci.draw_circle(hand + Vector2(size * 1.08, -size * 0.43 - open * size * 0.88), size * 0.09, _c(Color(0.15, 0.08, 0.06)))
	ci.draw_circle(hand + Vector2(size * 1.12, size * 0.12 + open * size * 0.3), size * 0.09, _c(Color(0.15, 0.08, 0.06)))


# ── Phù Thuỷ Băng ───────────────────────────────────────────────────────────

const ROBE := Color(0.22, 0.2, 0.5)
const ROBE_LIGHT := Color(0.36, 0.48, 0.88)
const FROST := Color(0.85, 0.96, 1.0)
const ICE := Color(0.45, 0.88, 1.0)


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


# ── Generic ─────────────────────────────────────────────────────────────────

static func _blob(ci: CanvasItem, t: float, col: Color) -> void:
	var squash := 1.0 + sin(t * 2.0) * 0.03
	_shape(ci, _ellipse_pts(Vector2(0, -42 * squash), 34, 42 * squash), col)
	ci.draw_colored_polygon(_ellipse_pts(Vector2(-8, -62), 16, 9), Color(1, 1, 1, 0.25))
	for x in [6.0, 20.0]:
		_circle(ci, Vector2(x, -52), 6.0, Color(1, 1, 0.85))
		ci.draw_circle(Vector2(x + 2, -52), 2.6, Color(0.1, 0.05, 0.1))
	_line(ci, Vector2(4, -34), Vector2(22, -36), Color(0.2, 0.08, 0.2), 2.4)
