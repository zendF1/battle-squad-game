extends Node2D
## While a shell flies above the top of the view (ShotPlayer.high_shells(): normal shells, the
## flare, the bombs), a small arrow just inside the top edge under it follows its x and turns with
## its velocity (ShotPlayer.high_shell_velocities()): tip up-slanted while it rises, down-slanted
## while it falls. While aiming (AimInput.high_xs() / high_dirs()), one where the previewed shell
## will come back into view, its tip along the way it falls there (down into the ground, slanted
## with its drift), so the shooter can line it up. No height or distance shown. Drawn like the
## guide arc: half transparent white over a faint dark rim, readable on any sky. On its own
## CanvasLayer over the HUD (match_screen), so the top row (timer, wind, portrait) never hides it.
## The world goes through the match camera (the viewport's canvas transform): a shell is high
## when it is above the view's top, its arrow under its screen x; the aim's re-entry xs are world
## xs at the view's top (AimInput.view_top).

const LENGTH := 16.0 # tip to tail (60% of the old 26 px arrow)
const WIDTH := 18.0 # across the head (60% of 30 px)
const HEAD := 0.6 # the head's share of the length
const SHAFT := 0.4 # the shaft's width against the head's
const TOP := 4.0 # the arrow stays this far under the top edge, however it turns
## The arrow's centre: under the top edge by TOP plus the farthest its outline reaches from the
## centre (the head's corners, ~9.1 px), so a turned arrow never leaves the screen.
const CENTRE_Y := TOP + 9.2
const EDGE := 14.0 # its centre is kept this far inside the screen's sides
const FILL := Color(1, 1, 1, 0.48) # AimInput.GUIDE_COLOR
const RIM := Color(0.03, 0.04, 0.12, 0.35) # a faint dark rim (AimInput.GUIDE_SHADOW, a little firmer)
const RIM_WIDTH := 2.5
const UP := Vector2(0, -1) # an in-flight shell with no velocity known
const DOWN := Vector2(0, 1) # a previewed one with no direction known

var shot_player # ShotPlayer
var aim # AimInput (optional): the arrows while aiming
var _arrows: Array = [] # [{x, height, dir}] drawn now


## The arrows for shells at these positions on a screen `width` px wide: one per shell above the
## top (y < 0), x kept EDGE inside the sides, height = how far above the top it is, dir = the unit
## direction of its velocity (velocities in the same order; UP when missing).
static func arrows(shells: PackedVector2Array, width: float, velocities := PackedVector2Array()) -> Array:
	var out: Array = []
	for i in shells.size():
		var p := shells[i]
		if p.y < 0.0:
			var v := velocities[i] if i < velocities.size() else Vector2.ZERO
			out.append({"x": clampf(p.x, EDGE, width - EDGE), "height": -p.y, "dir": v.normalized() if v != Vector2.ZERO else UP})
	return out


func _process(_delta: float) -> void:
	var width := get_viewport_rect().size.x
	var xf := get_viewport().get_canvas_transform() # world -> screen
	var top := (xf.affine_inverse() * Vector2.ZERO).y
	var now: Array = []
	if shot_player != null:
		var shells: PackedVector2Array = shot_player.high_shells(top)
		for i in shells.size():
			shells[i] = xf * shells[i]
		now = arrows(shells, width, shot_player.high_shell_velocities(top))
	if aim != null:
		var xs: PackedFloat32Array = aim.high_xs().duplicate()
		for i in xs.size():
			xs[i] = (xf * Vector2(xs[i], top)).x
		now.append_array(aim_arrows(xs, width, aim.high_dirs()))
	if now.is_empty() and _arrows.is_empty():
		return
	_arrows = now
	queue_redraw()


## The arrows while aiming: one per x where a previewed shell comes back into view (height 0),
## turned along dirs (the way it falls there; DOWN when missing).
static func aim_arrows(xs: PackedFloat32Array, width: float, dirs := PackedVector2Array()) -> Array:
	var out: Array = []
	for i in xs.size():
		var d := dirs[i] if i < dirs.size() else Vector2.ZERO
		out.append({"x": clampf(xs[i], EDGE, width - EDGE), "height": 0.0, "dir": d.normalized() if d != Vector2.ZERO else DOWN})
	return out


## The arrows shown now ([{x, height, dir}]).
func shown() -> Array:
	return _arrows


## Arrow a's outline on the screen: tip first, pointing along a.dir, centred at (a.x, CENTRE_Y).
static func outline(a: Dictionary) -> PackedVector2Array:
	var d: Vector2 = a["dir"]
	var n := Vector2(-d.y, d.x)
	var c := Vector2(float(a["x"]), CENTRE_Y)
	var tip := c + d * LENGTH / 2.0
	var base := tip - d * LENGTH * HEAD # where the head meets the shaft
	var tail := c - d * LENGTH / 2.0
	var w := WIDTH / 2.0
	var s := w * SHAFT
	return PackedVector2Array([tip, base + n * w, base + n * s, tail + n * s, tail - n * s, base - n * s, base - n * w])


func _draw() -> void:
	for a in _arrows:
		var tri := outline(a)
		var rim := tri.duplicate()
		rim.append(tri[0])
		draw_polyline(rim, RIM, RIM_WIDTH, true) # under the fill: only its outer half shows
		draw_colored_polygon(tri, FILL)
