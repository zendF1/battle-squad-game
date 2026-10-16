extends RefCounted
## The code-drawn characters (bake source only, not used at runtime): a chibi body, head, eyes,
## a hat and the character's gun (Rookie bazooka, Tanko cannon, Spark shock rifle, Flora seed
## launcher), in its own colours. tools/bake_art.gd renders every
## animation frame and the portrait from here into assets/characters/<id>/.
##
## The art is drawn in UNITS: feet at the origin, up is -y, facing +x, about ART_HEIGHT units
## tall. frame_pose() samples the animations (idle, walk, shoot, hurt, die) the match used to
## animate in code.

const OUTLINE := Color(0.07, 0.07, 0.12)
const SKIN := Color(1.0, 0.82, 0.66)
## Height of the art in units, from the feet to the top of the tallest hat.
const ART_HEIGHT := 150.0

## Per character: body, trim (belt, shoes, hat details), hat, weapon colours, body width.
const LOOKS := {
	"rookie": {"body": Color(0.25, 0.55, 1.0), "trim": Color(0.16, 0.25, 0.5), "hat": Color(0.36, 0.62, 0.3),
		"weapon": Color(0.55, 0.6, 0.68), "glow": Color(1.0, 0.75, 0.3), "width": 44.0},
	"tanko": {"body": Color(0.42, 0.5, 0.3), "trim": Color(0.27, 0.3, 0.2), "hat": Color(0.55, 0.57, 0.6),
		"weapon": Color(0.3, 0.32, 0.36), "glow": Color(1.0, 0.5, 0.2), "width": 58.0},
	"spark": {"body": Color(0.56, 0.36, 0.9), "trim": Color(0.3, 0.18, 0.55), "hat": Color(1.0, 0.85, 0.25),
		"weapon": Color(0.72, 0.74, 0.8), "glow": Color(0.55, 0.95, 1.0), "width": 40.0},
	"flora": {"body": Color(0.3, 0.75, 0.5), "trim": Color(0.16, 0.45, 0.3), "hat": Color(1.0, 0.5, 0.7),
		"weapon": Color(0.6, 0.42, 0.25), "glow": Color(1.0, 0.92, 0.4), "width": 42.0},
}
## Where each weapon fires from (units): the shoot flash is drawn here.
const MUZZLES := {
	"rookie": Vector2(74, -72), "tanko": Vector2(90, -49), "spark": Vector2(86, -59), "flora": Vector2(84, -61),
}

static var _boxes := {} # [color, radius, outline] -> StyleBoxFlat, so a redraw allocates nothing


## Frame i of n of an animation: {"pose": paint() pose, "rot": radians about the feet,
## "offset": units the whole body moves (feet included)}. The values are the ones the match
## animated in code (match/views/character_sprite.gd before the bake).
static func frame_pose(anim: String, i: int, n: int) -> Dictionary:
	var f := float(i) / n
	match anim:
		"walk": # leg swing, a bob on each step, a forward lean
			var s := sin(TAU * f)
			return {"pose": {"legs": s, "bob": absf(s) * 4.0}, "rot": 0.06, "offset": Vector2.ZERO}
		"shoot": # recoil easing out, muzzle flash in the first frame(s), a lean back
			var k := 1.0 - f
			return {"pose": {"bob": 1.2, "recoil": 14.0 * k * k, "flash": clampf((k - 0.55) / 0.45, 0.0, 1.0)},
				"rot": -0.08 * k, "offset": Vector2.ZERO}
		"hurt": # knocked back with a wobble, squinting
			var k := 1.0 - f * 0.9
			return {"pose": {"bob": 0.0, "hurt": true}, "rot": sin(k * 18.0) * 0.18 * k, "offset": Vector2(-14.0 * k, 0)}
		"die": # falls on its back; the body width lifts the centre off the ground
			var k := ease(float(i + 1) / n, 0.4)
			return {"pose": {"ko": true}, "rot": -PI / 2 * k, "offset": Vector2(0, -24.0 * k)}
	# idle: breathing (the upper body rises and falls)
	return {"pose": {"bob": (sin(TAU * f) * 0.5 + 0.5) * 2.5}, "rot": 0.0, "offset": Vector2.ZERO}


## Draws frame i of n of anim with the feet at `feet` (ci's local space), scale px per unit.
static func paint_frame(ci: CanvasItem, feet: Vector2, scale: float, id: String, anim: String, i: int, n: int) -> void:
	var fp := frame_pose(anim, i, n)
	var xform := Transform2D(fp["rot"], Vector2(scale, scale), 0.0, feet + fp["offset"] * scale)
	paint(ci, xform, id, fp["pose"])
	ci.draw_set_transform(Vector2.ZERO)


## Known character id, or "rookie" (unknown or missing ids, e.g. a bot without one).
static func known_id(id: String) -> String:
	return id if LOOKS.has(id) else "rookie"


## Draws the character onto ci with xform (units → ci's local space; feet at the origin, facing
## +x). pose (all optional):
## - bob: units the upper body is lifted (the feet stay put);
## - legs: -1..1 leg swing (walking);
## - recoil: units the weapon is pushed back; flash: 0..1 muzzle flash;
## - ko: true draws closed (X) eyes; hurt: true squints (> <) with a frown.
## Leaves ci's draw transform changed: the caller resets it.
static func paint(ci: CanvasItem, xform: Transform2D, id: String, pose: Dictionary = {}) -> void:
	id = known_id(id)
	var look: Dictionary = LOOKS[id]
	var bob: float = pose.get("bob", 0.0)
	ci.draw_set_transform_matrix(xform)
	_legs(ci, look, pose.get("legs", 0.0))
	var upper := xform * Transform2D(0.0, Vector2(0, -bob))
	ci.draw_set_transform_matrix(upper)
	_body(ci, look, bool(pose.get("ko", false)), bool(pose.get("hurt", false)))
	match id:
		"tanko":
			_tanko_hat(ci, look)
		"spark":
			_spark_hat(ci, look)
		"flora":
			_flora_hat(ci, look)
		_:
			_rookie_hat(ci, look)
	var recoil: float = pose.get("recoil", 0.0)
	ci.draw_set_transform_matrix(upper * Transform2D(0.0, Vector2(-recoil, 0)))
	match id:
		"tanko":
			_tanko_weapon(ci, look)
		"spark":
			_spark_weapon(ci, look)
		"flora":
			_flora_weapon(ci, look)
		_:
			_rookie_weapon(ci, look)
	var flash: float = pose.get("flash", 0.0)
	if flash > 0.0:
		var at: Vector2 = MUZZLES[id]
		ci.draw_circle(at, 24.0 * flash, Color(look["glow"], 0.4 * flash))
		ci.draw_circle(at, 13.0 * flash, Color(1.0, 0.95, 0.6, 0.9 * flash))


## Legs and shoes; swing moves them apart (one forward and raised, one back).
static func _legs(ci: CanvasItem, look: Dictionary, swing: float) -> void:
	var w: float = look["width"]
	for side in [-1.0, 1.0]:
		var s: float = swing * side
		var x: float = w * 0.3 * side + s * 7.0
		var up: float = maxf(s, 0.0) * 6.0
		_rect(ci, Rect2(x - 7, -30 - up, 14, 24), look["trim"].darkened(0.2), 5)
		_rect(ci, Rect2(x - 10, -10 - up, 20, 10), Color(0.18, 0.14, 0.12), 5)


## Torso, belt, arms, head and eyes (shared); the hat and weapon come after.
static func _body(ci: CanvasItem, look: Dictionary, ko: bool, hurt: bool = false) -> void:
	var w: float = look["width"]
	# Torso and belt.
	_rect(ci, Rect2(-w / 2, -74, w, 48), look["body"], 14)
	_rect(ci, Rect2(-w / 2 + 2, -40, w - 4, 7), look["trim"], 3, 0.0)
	_rect(ci, Rect2(-5, -42, 10, 11), look["glow"], 3, 2.0)
	# Arms.
	_rect(ci, Rect2(-w / 2 - 11, -70, 13, 32), look["body"].darkened(0.1), 6)
	_rect(ci, Rect2(w / 2 - 2, -70, 13, 32), look["body"].darkened(0.1), 6)
	_circle(ci, Vector2(-w / 2 - 4.5, -38), 6.5, SKIN)
	# Head.
	_circle(ci, Vector2(0, -102), 30, SKIN)
	for x in [-11.0, 11.0]:
		if ko:
			ci.draw_line(Vector2(x - 5, -106), Vector2(x + 5, -96), OUTLINE, 3.0)
			ci.draw_line(Vector2(x - 5, -96), Vector2(x + 5, -106), OUTLINE, 3.0)
			continue
		if hurt: # squeezed shut: > <
			var d := 1.0 if x < 0.0 else -1.0
			ci.draw_polyline(PackedVector2Array([Vector2(x - 5 * d, -106), Vector2(x + 4 * d, -101), Vector2(x - 5 * d, -96)]), OUTLINE, 3.0, true)
			continue
		_circle(ci, Vector2(x, -101), 7.5, Color.WHITE, 2.0)
		ci.draw_circle(Vector2(x + 2, -100), 4.0, OUTLINE)
		ci.draw_circle(Vector2(x + 3.5, -102), 1.4, Color.WHITE)
	if ko or hurt:
		ci.draw_arc(Vector2(1, -84), 6.0, deg_to_rad(200), deg_to_rad(340), 10, OUTLINE, 2.5)
	else:
		ci.draw_arc(Vector2(1, -90), 6.0, deg_to_rad(20), deg_to_rad(160), 10, OUTLINE, 2.5)
	ci.draw_circle(Vector2(-19, -91), 4.0, Color(1, 0.5, 0.5, 0.45))
	ci.draw_circle(Vector2(21, -91), 4.0, Color(1, 0.5, 0.5, 0.45))


## A cap.
static func _rookie_hat(ci: CanvasItem, look: Dictionary) -> void:
	_polygon(ci, [Vector2(-31, -110), Vector2(-26, -128), Vector2(-8, -137), Vector2(14, -136), Vector2(29, -122), Vector2(31, -110)], look["hat"])
	_rect(ci, Rect2(10, -114, 34, 7), look["hat"].darkened(0.2), 3)
	ci.draw_circle(Vector2(0, -128), 4.0, look["glow"])


## A short bazooka over the right shoulder, pointing forward.
static func _rookie_weapon(ci: CanvasItem, look: Dictionary) -> void:
	_rect(ci, Rect2(6, -80, 62, 16), look["weapon"], 7)
	_rect(ci, Rect2(60, -82, 12, 20), look["weapon"].darkened(0.25), 4)
	_rect(ci, Rect2(28, -68, 8, 14), look["weapon"].darkened(0.3), 3)
	_circle(ci, Vector2(33, -52), 6.5, SKIN)


## A helmet.
static func _tanko_hat(ci: CanvasItem, look: Dictionary) -> void:
	_polygon(ci, [Vector2(-32, -112), Vector2(-30, -130), Vector2(-15, -144), Vector2(15, -144), Vector2(30, -130), Vector2(32, -112)], look["hat"])
	_rect(ci, Rect2(-35, -118, 70, 8), look["hat"].darkened(0.25), 3)
	_rect(ci, Rect2(-4, -143, 8, 24), look["hat"].lightened(0.2), 3, 0.0)


## A heavy two-handed cannon held low across the body.
static func _tanko_weapon(ci: CanvasItem, look: Dictionary) -> void:
	_rect(ci, Rect2(-6, -62, 88, 26), look["weapon"], 9)
	_rect(ci, Rect2(72, -66, 16, 34), look["weapon"].darkened(0.3), 5)
	_rect(ci, Rect2(10, -58, 30, 6), look["glow"], 2, 0.0)
	_rect(ci, Rect2(4, -38, 14, 12), look["weapon"].darkened(0.2), 3)
	_circle(ci, Vector2(36, -36), 7.0, SKIN)


## Spiky hair.
static func _spark_hat(ci: CanvasItem, look: Dictionary) -> void:
	_polygon(ci, [Vector2(-31, -104), Vector2(-38, -126), Vector2(-20, -122), Vector2(-16, -146), Vector2(-2, -128),
		Vector2(8, -150), Vector2(14, -126), Vector2(34, -136), Vector2(28, -116), Vector2(33, -104), Vector2(20, -118),
		Vector2(0, -114), Vector2(-20, -118)], look["hat"])


## A shock rifle held at the chest: stock, body, barrel with glowing coils, an energy tank.
static func _spark_weapon(ci: CanvasItem, look: Dictionary) -> void:
	var metal: Color = look["weapon"]
	_polygon(ci, [Vector2(-4, -64), Vector2(14, -66), Vector2(14, -52), Vector2(-2, -46)], look["trim"])
	_rect(ci, Rect2(10, -68, 52, 16), metal, 6)
	_rect(ci, Rect2(58, -63, 26, 8), metal.darkened(0.3), 3)
	for x in [64.0, 71.0, 78.0]:
		_rect(ci, Rect2(x, -66, 4, 14), look["glow"], 2, 2.0)
	_rect(ci, Rect2(22, -80, 26, 12), look["glow"], 5)
	_polygon(ci, [Vector2(37, -79), Vector2(31, -73), Vector2(35, -73), Vector2(32, -69), Vector2(40, -75), Vector2(36, -75)], Color(1, 1, 0.6), 1.5)
	_rect(ci, Rect2(26, -54, 8, 12), metal.darkened(0.3), 3)
	_circle(ci, Vector2(31, -46), 6.5, SKIN)


## Leafy hair with a flower.
static func _flora_hat(ci: CanvasItem, look: Dictionary) -> void:
	var leaf: Color = look["body"].darkened(0.15)
	_polygon(ci, [Vector2(-31, -106), Vector2(-28, -124), Vector2(-12, -134), Vector2(10, -134), Vector2(28, -124), Vector2(31, -106), Vector2(18, -120), Vector2(-18, -120)], leaf)
	var c := Vector2(-18, -128)
	for i in 5:
		_circle(ci, c + Vector2.from_angle(TAU * i / 5.0) * 9.0, 7.0, look["hat"], 2.0)
	_circle(ci, c, 5.0, look["glow"], 2.0)


## A seed launcher: a wide wooden tube with a flared bell, a round hopper with a seed on top.
static func _flora_weapon(ci: CanvasItem, look: Dictionary) -> void:
	var wood: Color = look["weapon"]
	var seed_c := Color(0.45, 0.85, 0.4)
	_rect(ci, Rect2(4, -71, 66, 20), wood, 9)
	_polygon(ci, [Vector2(66, -72), Vector2(84, -78), Vector2(84, -44), Vector2(66, -50)], wood.darkened(0.25))
	_rect(ci, Rect2(44, -73, 6, 24), seed_c.darkened(0.3), 2)
	_circle(ci, Vector2(28, -78), 11.0, wood.darkened(0.15))
	_circle(ci, Vector2(28, -80), 6.5, seed_c, 2.0)
	_polygon(ci, [Vector2(6, -70), Vector2(-6, -86), Vector2(14, -78)], seed_c, 2.0)
	_rect(ci, Rect2(28, -54, 8, 12), wood.darkened(0.3), 3)
	_circle(ci, Vector2(33, -46), 6.5, SKIN)


static func _rect(ci: CanvasItem, r: Rect2, color: Color, radius: float, outline: float = 3.0) -> void:
	var key := [color, radius, outline]
	var box: StyleBoxFlat = _boxes.get(key)
	if box == null:
		box = StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(int(radius))
		box.anti_aliasing = true
		if outline > 0.0:
			box.border_color = OUTLINE
			box.set_border_width_all(int(outline))
			box.set_expand_margin_all(outline / 2)
		_boxes[key] = box
	ci.draw_style_box(box, r)


static func _circle(ci: CanvasItem, center: Vector2, radius: float, color: Color, outline: float = 3.0) -> void:
	if outline > 0.0:
		ci.draw_circle(center, radius + outline / 2, OUTLINE)
	ci.draw_circle(center, radius - outline / 2, color)


static func _polygon(ci: CanvasItem, points: Array, color: Color, outline: float = 3.0) -> void:
	var packed := PackedVector2Array(points)
	ci.draw_colored_polygon(packed, color)
	if outline > 0.0:
		packed.append(packed[0])
		ci.draw_polyline(packed, OUTLINE, outline, true)
