extends Node2D
## Cua Dung Nham's Kẹp càng grab (ShotResolved pincer {position: the target's body centre}): a big
## lava-crab claw lunges in from the crab's side and snaps shut on the target (the two halves
## close over SNAP s), holds it with a squeeze, a burst of sparks and a white "clack" ring on the
## snap, then opens and fades. Drawn in code in the crab's colours; `side` -1 when the crab is on
## the target's left. Freed when done.

const LIFE := 0.95
const SNAP := 0.16
const HOLD_END := 0.6
const SHELL := Color(0.86, 0.3, 0.14)
const SHELL_DARK := Color(0.55, 0.14, 0.08)
const GLOW := Color(1.0, 0.62, 0.18)
const OUT := Color(0.12, 0.04, 0.03)
const SIZE := 46.0

var side := 1.0 # the crab is on this side of the target (+1 right)
var _t := 0.0


func _init(crab_side: float = 1.0) -> void:
	side = 1.0 if crab_side >= 0.0 else -1.0
	z_index = 4


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


## How shut the claw is now: 0 open .. 1 shut (tests).
func closed() -> float:
	if _t < SNAP:
		return pow(_t / SNAP, 2.0)
	if _t < HOLD_END:
		return 1.0
	return clampf(1.0 - (_t - HOLD_END) / 0.25, 0.0, 1.0)


func _draw() -> void:
	var fade := clampf(1.0 - (_t - HOLD_END - 0.1) / 0.25, 0.0, 1.0)
	var lunge := clampf(_t / SNAP, 0.0, 1.0)
	var shut := closed()
	var squeeze := 1.0 + (0.05 * sin(_t * 40.0) if _t > SNAP and _t < HOLD_END else 0.0)
	# the tips land just past the target's centre when the lunge is done
	draw_set_transform(Vector2(side * SIZE * (0.85 + 0.7 * (1.0 - lunge)), 0), 0.0, Vector2(side * squeeze, squeeze))
	_arm(fade)
	var open := (1.0 - shut) * 0.62 + 0.04
	_jaw(-1.0, open * 0.35, fade) # the fixed upper jaw barely moves
	_jaw(1.0, open, fade) # the lower one snaps
	draw_set_transform(Vector2.ZERO)
	if _t >= SNAP:
		var k := clampf((_t - SNAP) / 0.3, 0.0, 1.0)
		draw_arc(Vector2.ZERO, SIZE * (0.4 + 1.1 * k), 0.0, TAU, 40, Color(1, 1, 1, 0.8 * (1.0 - k)), 5.0 * (1.0 - k) + 1.0, true)
		for i in 10:
			var a := TAU * i / 10.0 + 0.3
			var d := SIZE * (0.35 + 1.2 * k)
			var p := Vector2.from_angle(a) * d
			draw_line(p, p + Vector2.from_angle(a) * 10.0 * (1.0 - k), Color(GLOW, 1.0 - k), 3.0, true)


static func _bez(a: Vector2, b: Vector2, c: Vector2, n: int, out: PackedVector2Array) -> void:
	for i in n + 1:
		var u := float(i) / n
		out.append(a.lerp(b, u).lerp(b.lerp(c, u), u))


## The palm behind the hinge and the arm back toward the crab.
func _arm(fade: float) -> void:
	var arm := PackedVector2Array([Vector2(SIZE * 1.2, -SIZE * 0.22), Vector2(SIZE * 2.3, -SIZE * 0.3),
		Vector2(SIZE * 2.3, SIZE * 0.3), Vector2(SIZE * 1.2, SIZE * 0.22)])
	draw_colored_polygon(arm, Color(SHELL_DARK, fade))
	arm.append(arm[0])
	draw_polyline(arm, Color(OUT, fade), 3.0, true)
	var palm := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		palm.append(Vector2(SIZE * 0.95, 0) + Vector2(cos(a) * SIZE * 0.5, sin(a) * SIZE * 0.52))
	draw_colored_polygon(palm, Color(SHELL, fade))
	draw_circle(Vector2(SIZE * 0.85, -SIZE * 0.2), SIZE * 0.16, Color(1.0, 0.6, 0.4, 0.5 * fade))
	palm.append(palm[0])
	draw_polyline(palm, Color(OUT, fade), 3.0, true)


## One jaw (up -1: the upper, +1: the lower), its tip toward -x, turned open by `open` radians
## round the hinge.
func _jaw(up: float, open: float, fade: float) -> void:
	var hinge := Vector2(SIZE * 0.6, 0)
	var tip := Vector2(-SIZE * 0.95, up * SIZE * 0.04)
	var pts := PackedVector2Array()
	_bez(Vector2(SIZE * 0.75, up * SIZE * 0.5), Vector2(-SIZE * 0.45, up * SIZE * 0.7), tip, 10, pts) # the outer edge
	var inner := PackedVector2Array()
	_bez(tip, Vector2(-SIZE * 0.3, up * SIZE * 0.06), Vector2(SIZE * 0.7, up * SIZE * 0.04), 8, inner) # the biting edge
	pts.append_array(inner.slice(1))
	var rot := -up * open # the upper jaw turns up, the lower down (y points down)
	var turned := PackedVector2Array()
	for p in pts:
		turned.append(hinge + (p - hinge).rotated(rot))
	draw_colored_polygon(turned, Color(SHELL, fade))
	# teeth along the biting edge
	for i in range(2, inner.size() - 2, 2):
		var b := inner[i]
		var tooth := PackedVector2Array([b + Vector2(-4, 0), b + Vector2(0, -up * 8.0), b + Vector2(4, 0)])
		var rt := PackedVector2Array()
		for p in tooth:
			rt.append(hinge + (p - hinge).rotated(rot))
		draw_colored_polygon(rt, Color(1.0, 0.92, 0.75, fade))
	turned.append(turned[0])
	draw_polyline(turned, Color(OUT, fade), 3.0, true)
	# a glowing lava crack along it
	var crack := PackedVector2Array()
	_bez(Vector2(SIZE * 0.5, up * SIZE * 0.3), Vector2(-SIZE * 0.2, up * SIZE * 0.42), Vector2(-SIZE * 0.7, up * SIZE * 0.12), 6, crack)
	var rc := PackedVector2Array()
	for p in crack:
		rc.append(hinge + (p - hinge).rotated(rot))
	draw_polyline(rc, Color(GLOW, 0.9 * fade), 2.5, true)
