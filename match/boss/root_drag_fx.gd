extends Node2D
## Mộc Tinh's Rễ kéo (ShotResolved pull): thick roots burst out of the ground under the farthest
## member, coil round its feet and haul it along the ground toward the tree: the root runs along
## the drag's ground path (`path`) from the member to where the drag ends, where it bursts out of
## the earth in a knot (`anchor`, the side toward the tree); thorny, with a few leaves, its slack
## taken in as the member comes; dirt kicks up behind the member. It holds while the drag lasts
## (`sec`) and withers away after. `target` is the dragged member's view (followed every frame).
## Drawn in code on the ground layer; freed when done.

const ROOT := Color(0.42, 0.28, 0.14)
const ROOT_DARK := Color(0.24, 0.15, 0.07)
const OUT := Color(0.1, 0.06, 0.03)
const LEAF := Color(0.45, 0.78, 0.28)
const THORN := Color(0.85, 0.82, 0.55)
const WITHER := 0.45

var anchor := Vector2.ZERO # where the root dives into the ground (the drag's end, toward the tree)
var path := PackedVector2Array() # the drag's ground path, from the member's start to its end
var target: Node2D = null
var sec := 1.0
var _t := 0.0
var _end := Vector2.ZERO # the member's feet when the drag ended (the target may move on later)


func _init(ground_path: PackedVector2Array = PackedVector2Array(), member: Node2D = null, seconds: float = 1.0) -> void:
	path = ground_path
	anchor = path[-1] if not path.is_empty() else Vector2.ZERO
	target = member
	sec = maxf(seconds, 0.2)
	z_index = 1


func _process(delta: float) -> void:
	_t += delta
	if _t <= sec and target != null and is_instance_valid(target):
		_end = target.position
	if _t >= sec + WITHER:
		queue_free()
		return
	queue_redraw()


## 0..1: the roots grow in, hold, then wither (tests).
func strength() -> float:
	if _t < 0.2:
		return _t / 0.2
	if _t <= sec:
		return 1.0
	return clampf(1.0 - (_t - sec) / WITHER, 0.0, 1.0)


func _feet() -> Vector2:
	if _t <= sec and target != null and is_instance_valid(target):
		return target.position
	return _end


func _draw() -> void:
	var k := strength()
	if k <= 0.0:
		return
	var feet := _feet()
	var dir := signf(path[-1].x - path[0].x) if path.size() >= 2 else 1.0 # toward the tree
	if dir == 0.0:
		dir = 1.0
	var a := anchor + Vector2(dir * 40.0, 0) # a little past the drag's end
	# the root along the ground from the member to where it dives in: the path's points still ahead
	var main := PackedVector2Array([feet])
	for p in path:
		if (p.x - feet.x) * dir > 4.0:
			main.append(p)
	main.append(a)
	var grow := clampf(_t / 0.2, 0.0, 1.0)
	var keep := maxi(2, int(ceil(main.size() * grow)))
	main = main.slice(0, keep)
	for i in main.size():
		main[i] += Vector2(0, -4.0 + sin(i * 1.9 + _t * 9.0) * 2.5)
	if main.size() >= 2:
		draw_polyline(main, Color(OUT, k), 17.0, true)
		draw_polyline(main, Color(ROOT, k), 12.0, true)
		draw_polyline(main, Color(ROOT_DARK, 0.6 * k), 4.0, true)
		for i in range(1, main.size() - 1):
			var d := (main[i + 1] - main[i - 1]).normalized()
			var side := d.orthogonal() * (1.0 if i % 2 == 0 else -1.0)
			var base := main[i]
			draw_colored_polygon(PackedVector2Array([base - d * 5.0, base + side * 14.0, base + d * 5.0]), Color(THORN, k))
			if i % 3 == 1:
				var leaf := base + side * 10.0
				draw_set_transform(leaf, side.angle(), Vector2(1.0, 0.45))
				draw_circle(Vector2(7, 0), 8.0, Color(LEAF, k))
				draw_set_transform(Vector2.ZERO)
	# the knot where it bursts out of the earth
	if grow >= 1.0:
		for j in 3:
			var x := (j - 1.0) * 16.0
			var h := (34.0 + 10.0 * sin(j * 2.3)) * k
			var tip := a + Vector2(x * 1.4 + dir * 10.0, -h)
			var pts := PackedVector2Array([a + Vector2(x, 6), a + Vector2(x * 1.2, -h * 0.5), tip])
			draw_polyline(pts, Color(OUT, k), 10.0, true)
			draw_polyline(pts, Color(ROOT, k), 6.0, true)
		draw_circle(a + Vector2(0, -4), 14.0 * k, Color(ROOT_DARK, k))
	# the coil round the member's feet and the roots bursting out of the ground there
	for i in 3:
		var r := 22.0 - 5.0 * i
		draw_set_transform(feet + Vector2(0, -6.0 - 9.0 * i), 0.0, Vector2(1.0, 0.35))
		draw_arc(Vector2.ZERO, r, 0.2 + _t * 2.0, PI * 1.7 + _t * 2.0, 18, Color(ROOT, k), 6.0, true)
		draw_set_transform(Vector2.ZERO)
	for j in 4:
		var x := (j - 1.5) * 14.0
		var h := (26.0 + 8.0 * sin(j * 1.7)) * k
		var tip := feet + Vector2(x * 1.3, -h)
		draw_polyline(PackedVector2Array([feet + Vector2(x, 4), feet + Vector2(x * 1.15, -h * 0.5), tip]), Color(OUT, k), 7.0, true)
		draw_polyline(PackedVector2Array([feet + Vector2(x, 4), feet + Vector2(x * 1.15, -h * 0.5), tip]), Color(ROOT, k), 4.0, true)
	# dirt kicked up behind the member
	if _t <= sec:
		var away := -dir
		for i in 5:
			var ph := fmod(_t * 3.0 + i * 0.2, 1.0)
			var p := feet + Vector2(away * (10.0 + 30.0 * ph), -6.0 - 22.0 * ph * (1.0 - ph) * 2.0)
			draw_circle(p, 4.0 + 3.0 * (1.0 - ph), Color(0.45, 0.33, 0.2, 0.7 * (1.0 - ph)))
