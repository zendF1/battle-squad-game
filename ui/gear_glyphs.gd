extends RefCounted
## The gear effects' pictures, drawn in code (placeholder art, original: bright flat shapes in a
## dark outline like ui/glyph_icon.gd) on a 96 × 96 canvas scaled into a square:
## - one passive per slot (by its gear kind, PASSIVES): weapon Bạo kích (a red burst with a blade tip
##   through it), helmet (a helmet over a broken red burst: crit taken less), gloves (a glove
##   throwing an effect spark), pants (a belt and legs with the spark: the same chance), armor
##   (a shield with a flame and a snowflake bouncing off: resist), boots (a boot with speed lines);
## - one awaken per slot (by its awaken kind, AWAKENS; drawn on a gold glowing disc: Thức tỉnh): armor Hồi
##   sinh (a heart rising from a ring of light), helmet Miễn chí mạng (a burst inside a bubble,
##   crossed out), pants Chắc chắn dính (the spark locked in a target), weapon Không gió (wind
##   gusts crossed out), gloves Chí mạng chắc chắn (a target hit dead centre with a gold star),
##   boots Gấp đôi thể lực (two boots, the second a ghost: twice the walk);
## - the 6-piece set effects ("set_shield".."set_fire": a starting shield bubble, a heart drinking a red
##   drop (heal from damage), a sparkling wash (cleanse), a flaming shell (fire));
## - the upgrade milestones' unlocks: "bullet_glow" (+10: a shell with a glowing tail) and
##   "rank_up" (+14: the skill's star with an up chevron).
## draw() for any CanvasItem (the match's badges and buttons), GearIcon (ui/gear_icon.gd) for a
## layout. Colours by set index (SET_COLORS) are visual mappings, the rules are the server's.

const OUTLINE := Color(0.07, 0.07, 0.14)
const W := 5.0
const RED := Color(1.0, 0.32, 0.26)
const ORANGE := Color(1.0, 0.58, 0.16)
const YELLOW := Color(1.0, 0.92, 0.45)
const STEEL := Color(0.86, 0.9, 0.98)
const STEEL_DARK := Color(0.55, 0.62, 0.74)
const BLUE := Color(0.32, 0.62, 1.0)
const TEAL := Color(0.25, 0.8, 0.7)
const GREEN := Color(0.42, 0.9, 0.45)
const LEATHER := Color(0.62, 0.38, 0.2)
const LEATHER_DARK := Color(0.42, 0.24, 0.12)
const SPARK := Color(0.82, 0.5, 1.0)
const SPARK_LIGHT := Color(0.95, 0.85, 1.0)
const ICE := Color(0.72, 0.92, 1.0)
const HEART := Color(1.0, 0.33, 0.4)
const GOLD := Color(1.0, 0.8, 0.22)
const GOLD_DARK := Color(0.86, 0.5, 0.1)
const WHITE := Color(0.97, 0.98, 1.0)
const WIND := Color(0.92, 0.97, 1.0)
## The awaken disc: gold glow behind the picture (Thức tỉnh).
const AWAKEN_GLOW := Color(1.0, 0.78, 0.25)
const AWAKEN_DISC := Color(0.32, 0.16, 0.05)
## The 6-piece set colours by tier index (1 Sắt / Bạc, 2 Thép / Vàng, 3 Mithril / Titan, 4 Rồng /
## Kim cương): the pips, the set aura round the character.
const SET_COLORS := {1: Color(0.78, 0.8, 0.86), 2: Color(0.4, 0.68, 1.0), 3: Color(0.35, 0.95, 0.85), 4: Color(1.0, 0.72, 0.18)}


## The passives by their GET /gamedata gear kind ("proc_chance_pants": the pants' picture of the
## gloves' shared kind), the awakens by theirs, the 6-piece set effects as "set_<effect>".
const PASSIVES := ["crit_damage", "crit_taken", "proc_chance", "proc_chance_pants", "resist", "move_cost"]
const AWAKENS := ["revive", "crit_immune", "sure_proc", "no_wind", "sure_crit", "double_energy"]
const SET_EFFECTS := ["set_shield", "set_lifesteal", "set_cleanse", "set_fire"]
const MILESTONES := ["bullet_glow", "rank_up"]


## Every kind this file draws.
static func kinds() -> Array:
	return PASSIVES + AWAKENS + SET_EFFECTS + MILESTONES


## The picture of a slot's passive kind: the pants draw their own for the shared proc_chance.
static func passive_kind(kind: String, slot: String = "") -> String:
	return kind + "_pants" if kind == "proc_chance" and slot == "pants" else kind


static func has(kind: String) -> bool:
	return kinds().has(kind)


## The colour of a set index (white for an unknown one).
static func set_color(index: int) -> Color:
	return SET_COLORS.get(index, Color.WHITE)


## Draws `kind` in a square of side `size` centred at c on ci (nothing for an unknown kind).
static func draw(ci: CanvasItem, kind: String, c: Vector2, size: float) -> void:
	if not has(kind):
		return
	var s := size / 96.0
	ci.draw_set_transform(c - Vector2(size, size) / 2.0, 0.0, Vector2(s, s))
	if AWAKENS.has(kind):
		_awaken_disc(ci)
	match kind:
		"crit_damage": _crit_damage(ci)
		"crit_taken": _crit_guard(ci)
		"proc_chance": _glove(ci)
		"proc_chance_pants": _pants(ci)
		"resist": _resist(ci)
		"move_cost": _stride(ci)
		"revive": _revive(ci)
		"crit_immune": _crit_immune(ci)
		"sure_proc": _sure_proc(ci)
		"no_wind": _no_wind(ci)
		"sure_crit": _sure_crit(ci)
		"double_energy": _double_energy(ci)
		"set_shield": _set_shield(ci)
		"set_lifesteal": _set_heal(ci)
		"set_cleanse": _set_cleanse(ci)
		"set_fire": _set_fire(ci)
		"bullet_glow": _bullet_glow(ci)
		"rank_up": _rank_up(ci)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── Helpers ─────────────────────────────────────────────────────────────────

static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float = W) -> void:
	if w > 0.0:
		for o in Geometry2D.offset_polygon(pts, w, Geometry2D.JOIN_ROUND):
			ci.draw_colored_polygon(o, OUTLINE)
	ci.draw_colored_polygon(pts, fill)


static func _stroke(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, w: float = W) -> void:
	if w > 0.0:
		for o in Geometry2D.offset_polyline(pts, width / 2.0 + w, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			ci.draw_colored_polygon(o, OUTLINE)
	for o in Geometry2D.offset_polyline(pts, width / 2.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
		ci.draw_colored_polygon(o, color)


static func _disc(ci: CanvasItem, c: Vector2, r: float, fill: Color, w: float = W) -> void:
	if w > 0.0:
		ci.draw_circle(c, r + w, OUTLINE, true, -1.0, true)
	ci.draw_circle(c, r, fill, true, -1.0, true)


static func _star(c: Vector2, outer: float, inner: float, points: int, rot: float = -PI / 2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		pts.append(c + Vector2.from_angle(rot + PI * i / points) * r)
	return pts


static func _arc_pts(c: Vector2, r: float, from: float, to: float, n: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(c + Vector2.from_angle(lerpf(from, to, float(i) / n)) * r)
	return pts


static func _slash(ci: CanvasItem) -> void:
	_stroke(ci, PackedVector2Array([Vector2(16, 16), Vector2(80, 80)]), RED, 8.0)


## The element spark (the effect a hit can apply): a four-point star, light core.
static func _spark(ci: CanvasItem, c: Vector2, r: float) -> void:
	_poly(ci, _star(c, r, r * 0.32, 4, 0.0), SPARK, 4.0)
	ci.draw_colored_polygon(_star(c, r * 0.6, r * 0.2, 4, 0.0), SPARK_LIGHT)


static func _boot_shape(ci: CanvasItem, o: Vector2, k: float, fill: Color, w: float = W) -> void:
	var pts := PackedVector2Array()
	for p in [Vector2(30, 16), Vector2(54, 16), Vector2(56, 56), Vector2(80, 64), Vector2(86, 74), Vector2(84, 84),
			Vector2(22, 84), Vector2(24, 60)]:
		pts.append(o + (p - Vector2(48, 50)) * k)
	_poly(ci, pts, fill, w)
	var sole := PackedVector2Array()
	for p in [Vector2(22, 76), Vector2(84, 76), Vector2(84, 84), Vector2(22, 84)]:
		sole.append(o + (p - Vector2(48, 50)) * k)
	ci.draw_colored_polygon(sole, fill.darkened(0.35))


static func _burst(ci: CanvasItem, c: Vector2, r: float, fill: Color, core: Color, w: float = W) -> void:
	_poly(ci, _star(c, r, r * 0.55, 8, -PI / 8), fill, w)
	ci.draw_colored_polygon(_star(c, r * 0.62, r * 0.34, 8, -PI / 8), core)


static func _shield_pts(c: Vector2, k: float) -> PackedVector2Array:
	var pts := PackedVector2Array([c + Vector2(0, -36) * k, c + Vector2(30, -26) * k])
	for i in 9: # the right side curving down to the point
		var t := float(i) / 8.0
		pts.append(c + Vector2(28.0 * cos(t * PI / 2.0), -4.0 + 40.0 * sin(t * PI / 2.0)) * k)
	for i in range(7, -1, -1):
		var t := float(i) / 8.0
		pts.append(c + Vector2(-28.0 * cos(t * PI / 2.0), -4.0 + 40.0 * sin(t * PI / 2.0)) * k)
	pts.append(c + Vector2(-30, -26) * k)
	return pts


# ── Passives ────────────────────────────────────────────────────────────────

## Bạo kích: a red burst, a blade's tip driving through it.
static func _crit_damage(ci: CanvasItem) -> void:
	_burst(ci, Vector2(48, 52), 38, RED, ORANGE)
	ci.draw_circle(Vector2(48, 52), 9, YELLOW, true, -1.0, true)
	_poly(ci, PackedVector2Array([Vector2(14, 86), Vector2(62, 30), Vector2(84, 12), Vector2(70, 36), Vector2(22, 92)]), STEEL, 4.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(18, 89), Vector2(66, 33), Vector2(70, 36), Vector2(22, 92)]), STEEL_DARK)


## Crit taken less: the helmet over a red burst broken in two.
static func _crit_guard(ci: CanvasItem) -> void:
	_burst(ci, Vector2(30, 66), 24, RED, ORANGE, 4.0)
	_stroke(ci, PackedVector2Array([Vector2(16, 52), Vector2(30, 66), Vector2(22, 82)]), OUTLINE, 4.0, 0.0)
	var dome := _arc_pts(Vector2(56, 50), 32, PI, TAU, 16)
	dome.append_array(PackedVector2Array([Vector2(88, 64), Vector2(70, 64), Vector2(70, 56), Vector2(42, 56), Vector2(42, 64), Vector2(24, 64)]))
	_poly(ci, dome, BLUE)
	ci.draw_colored_polygon(_arc_pts(Vector2(56, 50), 24, PI * 1.15, PI * 1.5, 8) + PackedVector2Array([Vector2(56, 40)]), Color(1, 1, 1, 0.4))
	_stroke(ci, PackedVector2Array([Vector2(56, 18), Vector2(56, 52)]), GOLD, 5.0, 0.0)


## Effect chance (gloves): a fist with the element spark flying off it.
static func _glove(ci: CanvasItem) -> void:
	_poly(ci, PackedVector2Array([Vector2(14, 50), Vector2(20, 36), Vector2(50, 32), Vector2(58, 40), Vector2(58, 72),
		Vector2(48, 82), Vector2(22, 82), Vector2(14, 72)]), LEATHER)
	for x in [24.0, 34.0, 44.0]:
		_stroke(ci, PackedVector2Array([Vector2(x, 38), Vector2(x, 52)]), LEATHER_DARK, 3.0, 0.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(14, 72), Vector2(58, 72), Vector2(48, 82), Vector2(22, 82)]), LEATHER_DARK)
	_spark(ci, Vector2(70, 28), 22)
	ci.draw_circle(Vector2(84, 54), 5, SPARK_LIGHT, true, -1.0, true)


## Effect chance (pants): legs under a belt, the element spark at the hip.
static func _pants(ci: CanvasItem) -> void:
	_poly(ci, PackedVector2Array([Vector2(16, 30), Vector2(62, 30), Vector2(66, 88), Vector2(46, 88), Vector2(39, 52),
		Vector2(32, 88), Vector2(12, 88)]), BLUE.darkened(0.25))
	_poly(ci, PackedVector2Array([Vector2(14, 24), Vector2(64, 24), Vector2(64, 34), Vector2(14, 34)]), LEATHER_DARK, 3.0)
	ci.draw_rect(Rect2(34, 25, 10, 8), GOLD)
	_spark(ci, Vector2(74, 30), 20)


## Resist (armor): a shield, a flame and a snowflake bouncing off it.
static func _resist(ci: CanvasItem) -> void:
	_poly(ci, _shield_pts(Vector2(56, 52), 1.05), TEAL)
	ci.draw_colored_polygon(_shield_pts(Vector2(56, 52), 0.7), TEAL.lightened(0.3))
	# a small flame flying off the top left
	_poly(ci, PackedVector2Array([Vector2(16, 14), Vector2(26, 26), Vector2(24, 36), Vector2(14, 38), Vector2(8, 28)]), ORANGE, 3.5)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(16, 24), Vector2(21, 30), Vector2(18, 35), Vector2(13, 31)]), YELLOW)
	# a snowflake off the bottom left
	for i in 3:
		var d := Vector2.from_angle(PI * i / 3.0) * 10.0
		_stroke(ci, PackedVector2Array([Vector2(16, 72) - d, Vector2(16, 72) + d]), ICE, 3.5, 2.5)
	_stroke(ci, PackedVector2Array([Vector2(28, 30), Vector2(36, 36)]), WHITE, 3.0, 0.0)
	_stroke(ci, PackedVector2Array([Vector2(28, 70), Vector2(36, 66)]), WHITE, 3.0, 0.0)


## Walk further (boots): a boot with speed lines behind it.
static func _stride(ci: CanvasItem) -> void:
	_boot_shape(ci, Vector2(58, 50), 0.82, LEATHER)
	for i in 3:
		var y := 36.0 + i * 16.0
		_stroke(ci, PackedVector2Array([Vector2(8 + i * 3, y), Vector2(26, y)]), GREEN, 5.0, 3.0)


# ── Awakens (Thức tỉnh) ─────────────────────────────────────────────────────

static func _awaken_disc(ci: CanvasItem) -> void:
	for i in 4:
		ci.draw_circle(Vector2(48, 48), 48 - i * 2.5, Color(AWAKEN_GLOW, 0.12 + i * 0.06), true, -1.0, true)
	ci.draw_circle(Vector2(48, 48), 38, OUTLINE, true, -1.0, true)
	ci.draw_circle(Vector2(48, 48), 35, AWAKEN_DISC, true, -1.0, true)
	ci.draw_arc(Vector2(48, 48), 35, 0, TAU, 40, GOLD, 3.0, true)


## Hồi sinh: a heart rising out of a ring of light.
static func _revive(ci: CanvasItem) -> void:
	ci.draw_arc(Vector2(48, 70), 20, PI * 0.05, PI * 0.95, 12, YELLOW, 5.0, true)
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		pts.append(Vector2(48, 44) + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * 1.25)
	_poly(ci, pts, HEART, 4.0)
	_stroke(ci, PackedVector2Array([Vector2(48, 30), Vector2(48, 14)]), WHITE, 4.0, 2.5)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(40, 18), Vector2(48, 8), Vector2(56, 18)]), WHITE)


## Miễn chí mạng: a red burst inside a bubble, crossed out.
static func _crit_immune(ci: CanvasItem) -> void:
	_burst(ci, Vector2(48, 48), 20, RED, ORANGE, 3.5)
	ci.draw_arc(Vector2(48, 48), 28, 0, TAU, 32, ICE, 4.0, true)
	_stroke(ci, PackedVector2Array([Vector2(28, 28), Vector2(68, 68)]), WHITE, 5.0, 3.0)


## Chắc chắn dính: the element spark locked in a target.
static func _sure_proc(ci: CanvasItem) -> void:
	ci.draw_arc(Vector2(48, 48), 26, 0, TAU, 32, WHITE, 3.5, true)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		ci.draw_line(Vector2(48, 48) + d * 20, Vector2(48, 48) + d * 31, WHITE, 3.5, true)
	_spark(ci, Vector2(48, 48), 17)


## Không gió: the wind's gusts, crossed out.
static func _no_wind(ci: CanvasItem) -> void:
	for g in [[38.0, 26.0, 62.0], [50.0, 20.0, 72.0], [62.0, 28.0, 60.0]]:
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(Vector2(lerpf(g[1], g[2], i / 6.0), g[0] + sin(i / 6.0 * PI) * -2.0))
		_stroke(ci, pts, WIND, 4.5, 2.5)
	_stroke(ci, PackedVector2Array([Vector2(26, 26), Vector2(70, 70)]), RED, 6.0, 2.5)


## Chí mạng chắc chắn: a red target hit dead centre, a gold star on it.
static func _sure_crit(ci: CanvasItem) -> void:
	ci.draw_circle(Vector2(48, 48), 26, RED, true, -1.0, true)
	ci.draw_circle(Vector2(48, 48), 18, WHITE, true, -1.0, true)
	ci.draw_circle(Vector2(48, 48), 10, RED, true, -1.0, true)
	_poly(ci, _star(Vector2(48, 48), 13, 5.5, 5), GOLD, 2.5)


## Gấp đôi thể lực: a boot with its ghost twin ahead of it.
static func _double_energy(ci: CanvasItem) -> void:
	_boot_shape(ci, Vector2(56, 46), 0.42, Color(GREEN, 0.75), 0.0)
	_boot_shape(ci, Vector2(42, 52), 0.42, LEATHER, 3.0)
	_stroke(ci, PackedVector2Array([Vector2(26, 72), Vector2(70, 72)]), GREEN, 5.0, 2.5)



# ── 6-piece set effects ─────────────────────────────────────────────────────

## Sắt / Bạc: a shield bubble at the start.
static func _set_shield(ci: CanvasItem) -> void:
	ci.draw_circle(Vector2(48, 48), 40, Color(ICE, 0.25), true, -1.0, true)
	ci.draw_arc(Vector2(48, 48), 40, 0, TAU, 40, OUTLINE, 9.0, true)
	ci.draw_arc(Vector2(48, 48), 40, 0, TAU, 40, ICE, 5.0, true)
	ci.draw_arc(Vector2(48, 48), 30, PI * 1.1, PI * 1.45, 10, WHITE, 5.0, true)
	_poly(ci, _shield_pts(Vector2(48, 50), 0.7), BLUE, 4.0)


## Thép / Vàng: a heart drinking a red drop (heal from the damage dealt).
static func _set_heal(ci: CanvasItem) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		pts.append(Vector2(42, 56) + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * 1.9)
	_poly(ci, pts, GREEN)
	_stroke(ci, PackedVector2Array([Vector2(42, 44), Vector2(42, 68)]), WHITE, 6.0, 0.0)
	_stroke(ci, PackedVector2Array([Vector2(30, 56), Vector2(54, 56)]), WHITE, 6.0, 0.0)
	var drop := PackedVector2Array([Vector2(76, 8)])
	drop.append_array(_arc_pts(Vector2(76, 28), 11, -PI * 0.15, PI * 1.15, 12))
	_poly(ci, drop, RED, 4.0)


## Mithril / Titan: a sparkling wash (a bad effect cleared).
static func _set_cleanse(ci: CanvasItem) -> void:
	var drop := PackedVector2Array([Vector2(48, 8)])
	drop.append_array(_arc_pts(Vector2(48, 58), 28, -PI * 0.12, PI * 1.12, 20))
	_poly(ci, drop, Color(0.45, 0.85, 1.0))
	ci.draw_colored_polygon(_arc_pts(Vector2(48, 58), 18, PI * 0.9, PI * 1.35, 8) + PackedVector2Array([Vector2(48, 58)]), Color(1, 1, 1, 0.45))
	_poly(ci, _star(Vector2(74, 22), 13, 4.5, 4, 0.0), WHITE, 3.0)
	_poly(ci, _star(Vector2(20, 30), 9, 3.5, 4, 0.0), WHITE, 3.0)


## Rồng / Kim cương: a shell on fire.
static func _set_fire(ci: CanvasItem) -> void:
	_poly(ci, PackedVector2Array([Vector2(8, 70), Vector2(30, 40), Vector2(44, 56), Vector2(40, 78), Vector2(22, 88)]), RED, 4.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(18, 72), Vector2(32, 52), Vector2(40, 62), Vector2(36, 76)]), ORANGE)
	_disc(ci, Vector2(60, 40), 22, Color(0.3, 0.3, 0.36))
	ci.draw_circle(Vector2(53, 33), 7, Color(1, 1, 1, 0.35), true, -1.0, true)
	_poly(ci, PackedVector2Array([Vector2(56, 22), Vector2(66, 4), Vector2(76, 16), Vector2(86, 10), Vector2(80, 32), Vector2(66, 30)]), ORANGE, 3.5)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(64, 24), Vector2(68, 14), Vector2(74, 22), Vector2(70, 28)]), YELLOW)


# ── Milestones ──────────────────────────────────────────────────────────────

## +10: a shell with a glowing tail.
static func _bullet_glow(ci: CanvasItem) -> void:
	for i in 6:
		var t := float(i) / 5.0
		ci.draw_circle(Vector2(lerpf(14, 52, t), lerpf(70, 44, t)), lerpf(6, 18, t), Color(ORANGE, 0.18 + 0.12 * t), true, -1.0, true)
	ci.draw_circle(Vector2(64, 36), 24, Color(YELLOW, 0.35), true, -1.0, true)
	_poly(ci, PackedVector2Array([Vector2(46, 42), Vector2(66, 22), Vector2(84, 16), Vector2(78, 34), Vector2(58, 54)]), STEEL, 4.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(52, 48), Vector2(72, 28), Vector2(78, 34), Vector2(58, 54)]), STEEL_DARK)


## +14: the skill's star with an up chevron (the skill a rank higher).
static func _rank_up(ci: CanvasItem) -> void:
	_poly(ci, _star(Vector2(40, 54), 34, 15, 5), GOLD)
	ci.draw_colored_polygon(_star(Vector2(40, 54), 20, 9, 5), YELLOW)
	_stroke(ci, PackedVector2Array([Vector2(66, 36), Vector2(78, 22), Vector2(90, 36)]), GREEN, 7.0, 4.0)
	_stroke(ci, PackedVector2Array([Vector2(66, 54), Vector2(78, 40), Vector2(90, 54)]), GREEN, 7.0, 4.0)
