extends Node2D
## A unit's status effects drawn on its body (PlayerView makes two: the front one, over the figure
## and under the HP bar, holds the StatusLook; its `back` twin sits under the figure, over the team
## ring). Origin at the feet; `height` px is the figure's height over them, `width` its body's
## width (PlayerView: a player's art, a boss / minion's bodySize × its art's width), so everything
## scales with the body. The looks (StatusLook): the ice block round the body with frost at its
## base, flames licking up it with embers, a web wrapped over it, vines wound round the feet (in
## front of the legs and behind them), stars circling the head (the far ones behind it) and a soft
## aura behind the body with a few motes rising. Each pops in and out (StatusLook.pop_scale /
## pop_alpha; the vines grow up from the ground instead). All computed from the time in _draw();
## off (nothing to draw) it neither processes nor draws.

const StatusLook := preload("res://match/views/status_look.gd")

const REF_H := 53.0 # a player's figure height: the looks are sized for it × height / REF_H
const ICE := Color(0.62, 0.88, 1.0)
const ICE_EDGE := Color(0.88, 0.98, 1.0)
const FROST := Color(0.95, 0.99, 1.0)
const FLAME := Color(1.0, 0.42, 0.08)
const FLAME_CORE := Color(1.0, 0.86, 0.32)
const WEB := Color(0.95, 0.95, 1.0)
const VINE := Color(0.34, 0.62, 0.2)
const VINE_BACK := Color(0.2, 0.38, 0.12)
const VINE_OUT := Color(0.08, 0.16, 0.05)
const LEAF := Color(0.48, 0.82, 0.3)
const SOIL := Color(0.36, 0.25, 0.14)
const STAR := Color(1.0, 0.9, 0.3)
const STAR_OUT := Color(0.42, 0.24, 0.04)

var height := 53.0
var width := 30.0
var look := StatusLook.new()
var back: Node2D # the twin under the figure (draws through draw_back())

var _t := 0.0
static var _halo: GradientTexture2D


func _init() -> void:
	visible = false
	set_process(false)


## The twin under the figure: a plain node that calls back into draw_back().
func make_back() -> Node2D:
	back = Node2D.new()
	back.visible = false
	back.draw.connect(func() -> void: draw_back(back))
	return back


## Takes the unit's statusEffects.
func set_effects(effects: Variant) -> void:
	look.set_effects(effects)
	_wake()


## Every look pops out (death).
func clear() -> void:
	look.clear()
	_wake()


## Everything hidden at once (a bomber blown up).
func vanish() -> void:
	look = StatusLook.new()
	_wake()


## The looks drawn now (tests).
func looks() -> Array:
	return look.looks()


func _wake() -> void:
	var on := not look.is_empty()
	visible = on
	if back != null:
		back.visible = on
	set_process(on)
	queue_redraw()
	if back != null:
		back.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	look.step(delta)
	if look.is_empty():
		_wake()
		return
	queue_redraw()
	if back != null:
		back.queue_redraw()


func _s() -> float:
	return maxf(height / REF_H, 0.3)


func _draw() -> void:
	for l in look.layers():
		match str(l["look"]):
			"vines": _vines(self, l, true)
			"flames": _flames(l)
			"web": _web(l)
			"ice": _ice(l)
			"stars": _stars(self, l, true)
			"aura": _motes(l)


## The far parts: the aura's glow, the vines behind the legs, the stars behind the head.
func draw_back(ci: CanvasItem) -> void:
	for l in look.layers():
		match str(l["look"]):
			"aura": _aura(ci, l)
			"vines": _vines(ci, l, false)
			"stars": _stars(ci, l, false)


# ── Ice (freeze) ────────────────────────────────────────────────────────────

func _ice(l: Dictionary) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var k: float = l["scale"]
	var hw := width * 0.5 + 7.0 * s
	var h := height + 2.0 * s
	var raw := [Vector2(-0.9, 0.06), Vector2(0.94, 0.06), Vector2(1.06, -0.34), Vector2(0.9, -0.78), Vector2(0.5, -1.0),
		Vector2(-0.42, -0.97), Vector2(-1.0, -0.7), Vector2(-1.07, -0.26)]
	var pts := PackedVector2Array()
	for p in raw:
		pts.append(Vector2(p.x * hw, p.y * h) * k)
	draw_colored_polygon(pts, Color(ICE, 0.34 * a))
	# a deeper blue at the bottom of the block
	var low := PackedVector2Array([pts[0], pts[1], pts[2], Vector2(0.1 * hw, -0.3 * h) * k, pts[7]])
	draw_colored_polygon(low, Color(0.35, 0.65, 0.95, 0.18 * a))
	# facets: lines from the corners to an inner point
	var inner := Vector2(0.12 * hw, -0.56 * h) * k
	for i in [2, 4, 6, 0]:
		draw_line(pts[i], inner, Color(1, 1, 1, 0.22 * a), maxf(1.0, 1.2 * s), true)
	draw_line(inner, Vector2(-0.2 * hw, -0.2 * h) * k, Color(1, 1, 1, 0.18 * a), maxf(1.0, 1.0 * s), true)
	# the glint: a light band across the upper left
	var glint := PackedVector2Array([Vector2(-0.78, -0.66), Vector2(-0.5, -0.9), Vector2(-0.32, -0.88), Vector2(-0.68, -0.5)])
	for i in glint.size():
		glint[i] = Vector2(glint[i].x * hw, glint[i].y * h) * k
	draw_colored_polygon(glint, Color(1, 1, 1, 0.42 * a))
	var edge := pts.duplicate()
	edge.append(pts[0])
	draw_polyline(edge, Color(0.3, 0.62, 0.9, 0.7 * a), maxf(1.6, 3.0 * s), true)
	draw_polyline(edge, Color(ICE_EDGE, 0.9 * a), maxf(1.0, 1.4 * s), true)
	# frost heaped round the base, and a little on the top
	var n := maxi(4, int(width / (7.0 * s)))
	for i in n:
		var f := (i + 0.5) / n
		var x := lerpf(-0.95, 0.95, f) * hw
		var r := (1.8 + 1.6 * _hash(i * 1.7)) * s
		draw_circle(Vector2(x, 1.5 * s - r * 0.3) * k, r * k, Color(FROST, 0.75 * a))
	for i in 3:
		var p := Vector2(lerpf(-0.3, 0.45, i / 2.0) * hw, -0.98 * h + 1.5 * s)
		draw_circle(p * k, 2.2 * s * k, Color(FROST, 0.8 * a))
	# a few twinkles on the corners
	for i in 3:
		var tw := 0.5 + 0.5 * sin(_t * 3.2 + i * 2.1)
		var p: Vector2 = pts[[3, 5, 6][i]]
		_twinkle(self, p, (3.0 + 3.0 * tw) * s, Color(1, 1, 1, a * (0.35 + 0.65 * tw)))


func _twinkle(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(1.0, r * 0.28)
	ci.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), col, w, true)
	ci.draw_line(c - Vector2(0, r), c + Vector2(0, r), col, w, true)


# ── Flames (burn) ───────────────────────────────────────────────────────────

func _flames(l: Dictionary) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var k: float = l["scale"]
	# a warm glow over the body
	draw_set_transform(Vector2(0, -height * 0.45), 0.0, Vector2(width * 0.62, height * 0.55) * k / 32.0)
	draw_texture_rect(_halo_tex(), Rect2(-32, -32, 64, 64), false, Color(1.0, 0.45, 0.1, 0.32 * a))
	draw_set_transform(Vector2.ZERO)
	var n := clampi(roundi(width / (5.0 * s)), 5, 22)
	for i in n:
		var up := pow(_hash(i * 3.1), 1.6) # most of them low on the body
		var x := (lerpf(-0.5, 0.5, (i + 0.5) / n) + (_hash(i * 7.7) - 0.5) * 0.12) * width
		var y := -height * 0.62 * up
		var fh := (10.0 + 7.0 * _hash(i * 0.9)) * s * (1.0 - 0.4 * up) * (0.82 + 0.25 * sin(_t * 11.0 + i * 1.7))
		var sway := sin(_t * 7.0 + i * 2.3) * fh * 0.2
		_flame(Vector2(x, y) * k, fh * k, sway * k, a)
	var m := n + 4
	for j in m:
		var ph := fmod(_t * 0.85 + j * 0.287, 1.0)
		var x := lerpf(-0.5, 0.5, _hash(j * 1.31)) * width + sin(_t * 3.0 + j) * 4.0 * s
		var y := -height * (0.2 + ph * 0.95)
		var r := (1.8 + 1.1 * _hash(j * 2.7)) * s * (1.0 - ph * 0.5)
		draw_circle(Vector2(x, y) * k, r, Color(1.0, 0.5 + 0.4 * (1.0 - ph), 0.15, (1.0 - ph) * a))


## A flame tongue standing at `base` (its round bottom), `h` px tall, its tip swayed by `sway`:
## a deep red rim, the orange flame, a yellow core.
func _flame(base: Vector2, h: float, sway: float, a: float) -> void:
	var cols := [Color(0.85, 0.16, 0.04, 0.85 * a), Color(FLAME, 0.95 * a), Color(FLAME_CORE, a)]
	var sizes := [1.0, 0.78, 0.45]
	for layer in 3:
		var hh: float = h * sizes[layer]
		var r := hh / 3.2
		var c := base + Vector2(0, -r * 0.15 * layer)
		var pts := PackedVector2Array()
		for i in 14:
			var ang := TAU * i / 14.0
			var v := Vector2(sin(ang), -cos(ang))
			if v.y < 0.0:
				var up := -v.y
				v.x *= 1.0 - up * 0.85
				v.y *= 2.2
				v.x += sway / maxf(r, 0.01) * up * (1.0 - 0.2 * layer)
			pts.append(c + v * r)
		draw_colored_polygon(pts, cols[layer])


# ── Web (net) ───────────────────────────────────────────────────────────────

func _web(l: Dictionary) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var k: float = l["scale"]
	var c := Vector2(0, -height * 0.52)
	var rx := (width * 0.5 + 6.0 * s) * k
	var ry := (height * 0.5 + 5.0 * s) * k
	var spokes := 9
	var dirs: Array[Vector2] = []
	for i in spokes:
		var ang := TAU * i / spokes + 0.25 + (_hash(i * 5.3) - 0.5) * 0.25
		dirs.append(Vector2(cos(ang) * rx, sin(ang) * ry))
	var lw := maxf(1.0, 1.3 * s)
	var shade := Color(0, 0, 0, 0.22 * a)
	var col := Color(WEB, 0.82 * a)
	var lines := PackedVector2Array()
	for d in dirs:
		lines.append(c)
		lines.append(c + d)
	for ring in [0.3, 0.58, 0.86]:
		for i in spokes:
			var p0: Vector2 = c + dirs[i] * ring
			var p1: Vector2 = c + dirs[(i + 1) % spokes] * ring
			var mid: Vector2 = (p0 + p1) * 0.5
			mid = mid.lerp(c, 0.12) # each thread sags in toward the middle
			lines.append(p0)
			lines.append(mid)
			lines.append(mid)
			lines.append(p1)
	# two threads anchored on the ground
	for side in [-1.0, 1.0]:
		lines.append(c + Vector2(side * rx * 0.62, ry * 0.75))
		lines.append(Vector2(side * rx * 0.9, 0))
	var offset := PackedVector2Array()
	for p in lines:
		offset.append(p + Vector2(0.8, 1.2) * s)
	draw_multiline(offset, shade, lw + 1.0)
	draw_multiline(lines, col, lw)
	draw_circle(c, 2.4 * s * k, Color(WEB, 0.9 * a))


# ── Vines (root) ────────────────────────────────────────────────────────────

## front: the parts of the vines in front of the legs (and the soil), else those behind.
func _vines(ci: CanvasItem, l: Dictionary, front: bool) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var grow := clampf(float(l["k"]) * 1.15, 0.0, 1.0) if not l["popping_out"] else 1.0
	grow = 1.0 - pow(1.0 - grow, 2.0)
	var n := clampi(roundi(width / (13.0 * s)) + 1, 2, 8)
	var reach := width * 0.24
	for i in n:
		var x0 := lerpf(-0.5, 0.5, i / float(n - 1)) * width
		var vh := height * (0.3 + 0.12 * _hash(i * 2.9)) * grow
		var phase := i * 1.9 + 0.4
		var steps := 12
		var prev := Vector2(x0, 0)
		for j in range(1, steps + 1):
			var f := j / float(steps)
			var q := phase + f * 5.2
			var p := Vector2(x0 + sin(q) * reach * (1.0 - f * 0.35), -vh * f)
			var near := cos(q) > 0.0
			if near == front:
				var w := lerpf(3.6, 1.4, f) * s
				ci.draw_line(prev, p, Color(VINE_OUT, a), w + 2.0 * s, true)
				ci.draw_line(prev, p, Color(VINE if front else VINE_BACK, a), w, true)
				if front and (j == 5 or j == 9):
					_leaf(ci, p, (4.0 + _hash(i + j) * 2.0) * s * grow, sin(q) * 0.9 + (0.6 if j == 9 else -0.4), a)
			prev = p
	if front: # churned soil and root claws at the feet
		ci.draw_set_transform(Vector2(0, 1.0 * s), 0.0, Vector2(1.0, 0.32))
		ci.draw_circle(Vector2.ZERO, (width * 0.5 + 3.0 * s) * grow, Color(SOIL, 0.7 * a))
		ci.draw_set_transform(Vector2.ZERO)
		for side in [-1.0, 1.0]:
			var r0 := Vector2(side * width * 0.55, 1.0 * s)
			var r1 := r0 + Vector2(side * 6.0, -9.0 * grow) * s
			var r2 := r1 + Vector2(-side * 5.0, -4.0 * grow) * s
			ci.draw_polyline(PackedVector2Array([r0, r1, r2]), Color(0.45, 0.3, 0.16, a), 2.6 * s, true)


func _leaf(ci: CanvasItem, at: Vector2, r: float, rot: float, a: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := TAU * i / 10.0
		pts.append(at + Vector2(cos(ang) * r, sin(ang) * r * 0.45).rotated(rot) + Vector2(r, 0).rotated(rot))
	ci.draw_colored_polygon(pts, Color(LEAF, a))
	ci.draw_line(at, at + Vector2(r * 1.8, 0).rotated(rot), Color(VINE_OUT, 0.6 * a), maxf(1.0, r * 0.18), true)


# ── Stars (stun) ────────────────────────────────────────────────────────────

## front: the stars on the near half of their circle, else the far ones (behind the head).
func _stars(ci: CanvasItem, l: Dictionary, front: bool) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var k: float = l["scale"]
	var head := Vector2(0, -height * 0.96)
	var rx := maxf(width * 0.42, 17.0 * s) * k
	var ry := rx * 0.3
	var n := 4 if width < 80.0 * s else 5
	for i in n:
		var ang := _t * 4.0 + TAU * i / n
		var depth := sin(ang)
		if (depth >= 0.0) != front:
			continue
		var p := head + Vector2(cos(ang) * rx, depth * ry)
		var r := 6.5 * s * k * (0.82 + 0.18 * depth)
		var col := Color(STAR, a * (0.75 + 0.25 * depth))
		_star(ci, p, r, ang * 0.6, col)


func _star(ci: CanvasItem, c: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(rot + TAU * i / 10.0 - PI / 2.0) * rr)
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(STAR_OUT, col.a), maxf(1.0, r * 0.18), true)


# ── Aura (buffs) ────────────────────────────────────────────────────────────

func _aura(ci: CanvasItem, l: Dictionary) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var k: float = l["scale"]
	var col: Color = l["color"]
	var pulse := 0.5 + 0.5 * sin(_t * 2.4)
	var size := Vector2(width + 30.0 * s, height + 26.0 * s) * k * (1.0 + 0.04 * pulse)
	ci.draw_set_transform(Vector2(0, -height * 0.5), 0.0, size / 64.0)
	ci.draw_texture_rect(_halo_tex(), Rect2(-32, -32, 64, 64), false, Color(col, (0.42 + 0.14 * pulse) * a))
	ci.draw_set_transform(Vector2.ZERO)


## A few motes in the aura's colour rising past the body.
func _motes(l: Dictionary) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var col: Color = l["color"]
	var n := clampi(roundi(width / (8.0 * s)), 4, 12)
	for j in n:
		var ph := fmod(_t * 0.5 + j / float(n), 1.0)
		var x := lerpf(-0.55, 0.55, _hash(j * 1.73)) * width + sin(_t * 2.0 + j * 1.3) * 3.0 * s
		var y := -height * (0.05 + ph * 0.95)
		var fade := sin(ph * PI)
		draw_circle(Vector2(x, y), 1.6 * s, Color(col.lightened(0.45), 0.7 * fade * a))


# ── Helpers ─────────────────────────────────────────────────────────────────

static func _hash(x: float) -> float:
	var v := sin(x * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)


static func _halo_tex() -> GradientTexture2D:
	if _halo == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0)])
		_halo = GradientTexture2D.new()
		_halo.gradient = g
		_halo.fill = GradientTexture2D.FILL_RADIAL
		_halo.fill_from = Vector2(0.5, 0.5)
		_halo.fill_to = Vector2(1.0, 0.5)
		_halo.width = 64
		_halo.height = 64
	return _halo
