extends Control
## The mark on a login button (ui/login_button.gd), drawn in code in the largest centred square of the
## rect: "apple" (the black Apple mark of Apple's white sign-in button), "google" (the four-colour G),
## "facebook" (the white f in the #1877F2 circle) and "guest" (the game's own: a white play triangle on
## the logo's gold, ringed navy). The shapes are built in a unit box (-1..1, y down) and scaled.

const KINDS := ["apple", "google", "facebook", "guest"]

const APPLE_BLACK := Color(0.0, 0.0, 0.0)
const GOOGLE_BLUE := Color("#4285F4")
const GOOGLE_GREEN := Color("#34A853")
const GOOGLE_YELLOW := Color("#FBBC05")
const GOOGLE_RED := Color("#EA4335")
const FACEBOOK_BLUE := Color("#1877F2")
const GUEST_GOLD := Color(1.0, 0.76, 0.16)
const GUEST_ORANGE := Color(0.96, 0.5, 0.08)
const GUEST_NAVY := Color(0.09, 0.14, 0.38)

var kind := "guest":
	set(value):
		kind = value
		queue_redraw()

static var _apple: PackedVector2Array


func _init(mark_kind: String = "guest") -> void:
	kind = mark_kind
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	match kind:
		"apple":
			_fill(_place(apple_shape(), c + Vector2(0.01, 0.05) * s, s), APPLE_BLACK)
			_fill(_place(apple_leaf(), c + Vector2(0.01, 0.05) * s, s), APPLE_BLACK)
		"google":
			_draw_google(c, s)
		"facebook":
			_draw_facebook(c, s)
		_:
			_draw_guest(c, s)


## The Apple mark's outline (unit box): a smooth body (Bézier, notch on top, two lobes at the bottom)
## with the bite cut out of the right side.
static func apple_shape() -> PackedVector2Array:
	if _apple.is_empty():
		var curve := Curve2D.new()
		# point, in-handle, out-handle (relative), clockwise from the notch at the top
		for k in [
			[Vector2(0.0, -0.4), Vector2(-0.1, -0.07), Vector2(0.1, -0.07)],
			[Vector2(0.38, -0.53), Vector2(-0.15, 0.0), Vector2(0.22, 0.0)],
			[Vector2(0.75, -0.1), Vector2(0.0, -0.26), Vector2(0.0, 0.34)],
			[Vector2(0.4, 0.78), Vector2(0.18, 0.0), Vector2(-0.13, 0.0)],
			[Vector2(0.0, 0.7), Vector2(0.1, 0.0), Vector2(-0.1, 0.0)],
			[Vector2(-0.4, 0.78), Vector2(0.13, 0.0), Vector2(-0.18, 0.0)],
			[Vector2(-0.77, -0.08), Vector2(0.0, 0.34), Vector2(0.0, -0.26)],
			[Vector2(-0.38, -0.53), Vector2(-0.22, 0.0), Vector2(0.15, 0.0)],
			[Vector2(0.0, -0.4), Vector2(-0.1, -0.07), Vector2(0.1, -0.07)],
		]:
			curve.add_point(k[0], k[1], k[2])
		var body := curve.tessellate(5, 3)
		body.remove_at(body.size() - 1) # the closing point repeats the first
		_apple = _largest(Geometry2D.clip_polygons(body, _circle(Vector2(0.94, -0.13), 0.33)))
	return _apple


## The leaf: a pointed lens leaning right, over the notch.
static func apple_leaf() -> PackedVector2Array:
	var base := Vector2(0.03, -0.5)
	var tip := Vector2(0.33, -0.88)
	var normal := (tip - base).orthogonal().normalized()
	var out := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		out.append(base.lerp(tip, t) + normal * sin(PI * t) * 0.11)
	for i in range(11, 0, -1):
		var t := i / 12.0
		out.append(base.lerp(tip, t) - normal * sin(PI * t) * 0.11)
	return out


func _draw_google(c: Vector2, s: float) -> void:
	var w := 0.36 * s
	var r := 0.9 * s - w / 2.0
	# Godot angles: 0 = right, growing clockwise (y down); the G opens at the upper right.
	for seg in [[0.0, 42.0, GOOGLE_BLUE], [42.0, 140.0, GOOGLE_GREEN], [140.0, 218.0, GOOGLE_YELLOW],
			[218.0, 318.0, GOOGLE_RED]]:
		draw_arc(c, r, deg_to_rad(seg[0]), deg_to_rad(seg[1]), 24, seg[2], w, true)
	draw_rect(Rect2(c + Vector2(0.02, -0.17) * s, Vector2(0.86, 0.34) * s), GOOGLE_BLUE)


func _draw_facebook(c: Vector2, s: float) -> void:
	draw_circle(c, 0.92 * s, FACEBOOK_BLUE, true, -1.0, true)
	var disc := _circle(Vector2.ZERO, 0.92)
	var stem := PackedVector2Array([Vector2(0.0, -0.32), Vector2(0.27, -0.32), Vector2(0.27, 1.0), Vector2(0.0, 1.0)])
	for part in Geometry2D.intersect_polygons(stem, disc):
		_fill(_place(part, c, s), Color.WHITE)
	_fill(_place(_rect(Vector2(-0.24, 0.0), Vector2(0.52, 0.24)), c, s), Color.WHITE)
	# The top: an arc from the stem bending right, then a short bar.
	draw_arc(c + Vector2(0.43, -0.32) * s, 0.295 * s, PI, PI * 1.5, 16, Color.WHITE, 0.27 * s, true)
	_fill(_place(_rect(Vector2(0.42, -0.75), Vector2(0.58, -0.48)), c, s), Color.WHITE)


func _draw_guest(c: Vector2, s: float) -> void:
	draw_circle(c, 0.92 * s, GUEST_NAVY, true, -1.0, true)
	draw_circle(c, 0.76 * s, GUEST_ORANGE, true, -1.0, true)
	draw_circle(c + Vector2(0.0, -0.06) * s, 0.66 * s, GUEST_GOLD, true, -1.0, true)
	var tri := PackedVector2Array([Vector2(-0.2, -0.38), Vector2(0.42, 0.0), Vector2(-0.2, 0.38)])
	_fill(_place(tri, c, s), Color.WHITE)


func _fill(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	draw_colored_polygon(points, color)
	var ring := points.duplicate()
	ring.append(points[0])
	draw_polyline(ring, color, 1.0, true) # a soft edge: polygons draw without anti-aliasing


static func _place(points: PackedVector2Array, c: Vector2, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(c + p * s)
	return out


static func _circle(center: Vector2, r: float, n: int = 40) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(center + Vector2(cos(a), sin(a)) * r)
	return out


static func _rect(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])


## The outer polygon of a Geometry2D result: the biggest by area (a hole lies inside it).
static func _largest(polys: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := -1.0
	for p in polys:
		var area := absf(_area(p))
		if area > best_area:
			best = p
			best_area = area
	return best


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a / 2.0
