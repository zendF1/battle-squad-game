extends Control
## A boss card's backdrop for its element (GET /gamedata bosses[].element), drawn in code and
## mapped by elementId (visual only), subtle and slowly animated so the figure in front stays the
## focus and its name readable:
## - water: deep blue water, soft waves rolling across, bubbles rising;
## - fire: dark red, a lava glow welling up from below, embers drifting up;
## - metal: dark steel-violet, faint lightning streaks flickering now and then;
## - earth: warm amber rock strata, dust motes drifting;
## - wood: deep green, leaf silhouettes swaying;
## any other element (or none): a plain dark gradient. Its rect's corners are rounded by `radius`
## (the card's), and nothing is drawn past them.

const LOOKS := {
	"water": {"top": Color(0.03, 0.1, 0.26), "bottom": Color(0.05, 0.3, 0.52)},
	"fire": {"top": Color(0.14, 0.02, 0.03), "bottom": Color(0.42, 0.08, 0.03)},
	"metal": {"top": Color(0.08, 0.07, 0.15), "bottom": Color(0.2, 0.2, 0.31)},
	"earth": {"top": Color(0.17, 0.1, 0.05), "bottom": Color(0.42, 0.26, 0.1)},
	"wood": {"top": Color(0.02, 0.11, 0.06), "bottom": Color(0.07, 0.27, 0.12)},
}
const PLAIN := {"top": Color(0.08, 0.04, 0.1), "bottom": Color(0.14, 0.06, 0.12)}

@export var element_id := "":
	set(v):
		element_id = v
		queue_redraw()
var radius := 18.0
## How strong the decorations are (0..1).
var strength := 1.0

var _t := 0.0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## The look of an element id (PLAIN for one without its own).
static func look(id: String) -> Dictionary:
	return LOOKS.get(id, PLAIN)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()


## The x range inside the rounded rect at y.
func _span(y: float) -> Vector2:
	var r := minf(radius, minf(size.x, size.y) * 0.5)
	var inset := 0.0
	if y < r:
		inset = r - sqrt(maxf(r * r - (r - y) * (r - y), 0.0))
	elif y > size.y - r:
		var dy := y - (size.y - r)
		inset = r - sqrt(maxf(r * r - dy * dy, 0.0))
	return Vector2(inset, size.x - inset)


## The rounded rect's outline, top-left corner first, clockwise.
func _outline() -> PackedVector2Array:
	var r := minf(radius, minf(size.x, size.y) * 0.5)
	var pts := PackedVector2Array()
	for c in [[Vector2(r, r), PI], [Vector2(size.x - r, r), PI * 1.5], [Vector2(size.x - r, size.y - r), 0.0], [Vector2(r, size.y - r), PI * 0.5]]:
		for i in 7:
			var a: float = float(c[1]) + PI * 0.5 * i / 6.0
			pts.append(c[0] + Vector2(cos(a), sin(a)) * r)
	return pts


static func _hash(x: float) -> float:
	var v := sin(x * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var l := look(element_id)
	var pts := _outline()
	var cols := PackedColorArray()
	for p in pts:
		cols.append((l["top"] as Color).lerp(l["bottom"], clampf(p.y / size.y, 0.0, 1.0)))
	draw_polygon(pts, cols)
	match element_id:
		"water": _water()
		"fire": _fire()
		"metal": _metal()
		"earth": _earth()
		"wood": _wood()


## An ellipse at c (radii r) with every point pulled inside the rounded rect.
func _inside_ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var p := c + Vector2(cos(a) * r.x, sin(a) * r.y)
		p.y = clampf(p.y, 0.0, size.y)
		var sp := _span(p.y)
		p.x = clampf(p.x, sp.x, sp.y)
		if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.5:
			pts.append(p)
	if pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) <= 0.5:
		pts.remove_at(pts.size() - 1)
	return pts


## A filled band under a wavy line from y0 (amplitude amp, phase ph) down to y1, inside the corners.
func _band(y0: float, y1: float, amp: float, waves: float, ph: float, col: Color) -> void:
	var top := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var x := size.x * i / float(n)
		var y := y0 + sin(i / float(n) * TAU * waves + ph) * amp
		var sp := _span(y)
		top.append(Vector2(clampf(x, sp.x, sp.y), y))
	var poly := top.duplicate()
	var spb := _span(y1)
	poly.append(Vector2(spb.y, y1))
	poly.append(Vector2(spb.x, y1))
	draw_colored_polygon(poly, col)


func _water() -> void:
	var k := strength
	for i in 3:
		var y0 := size.y * (0.52 + i * 0.14)
		_band(y0, size.y - 1.0, 7.0 + i * 2.0, 1.5 + i * 0.4, _t * (0.7 + i * 0.25) + i * 1.3, Color(0.45, 0.75, 1.0, (0.06 + i * 0.03) * k))
	for i in 14: # bubbles rising and wobbling
		var speed := 18.0 + 16.0 * _hash(i * 3.7)
		var x := size.x * (0.08 + 0.84 * _hash(i * 1.9)) + sin(_t * 1.6 + i) * 4.0
		var y := size.y - fposmod(_t * speed + _hash(i * 5.1) * size.y, size.y + 20.0)
		var r := 2.0 + 4.0 * _hash(i * 7.3)
		var a := 0.35 * k * clampf(y / (size.y * 0.3), 0.0, 1.0)
		draw_arc(Vector2(x, y), r, 0.0, TAU, 14, Color(0.8, 0.95, 1.0, a), 1.4, true)
		draw_circle(Vector2(x - r * 0.3, y - r * 0.3), r * 0.25, Color(1, 1, 1, a))


func _fire() -> void:
	var k := strength
	var pulse := 0.85 + 0.15 * sin(_t * 1.7)
	for i in 6: # the lava glow welling up from below (kept inside the corners)
		var f := i / 5.0
		var rx := size.x * (0.75 - f * 0.12) * pulse
		draw_colored_polygon(_inside_ellipse(Vector2(size.x * 0.5, size.y + 10.0), Vector2(rx, rx * 0.55)), Color(1.0, 0.36 + f * 0.1, 0.06, 0.05 * k))
	_band(size.y * 0.86, size.y - 1.0, 4.0, 2.0, _t * 0.6, Color(1.0, 0.45, 0.1, 0.22 * k))
	for i in 18: # embers drifting up
		var speed := 22.0 + 30.0 * _hash(i * 2.3)
		var y := size.y - fposmod(_t * speed + _hash(i * 4.9) * size.y, size.y)
		var x := size.x * (0.06 + 0.88 * _hash(i * 1.3)) + sin(_t * 1.2 + i * 2.0) * 8.0
		var sp := _span(y)
		if x < sp.x + 2.0 or x > sp.y - 2.0:
			continue
		var fade := clampf(y / size.y, 0.0, 1.0)
		draw_circle(Vector2(x, y), 1.6 + 1.6 * _hash(i * 6.1), Color(1.0, 0.62 + 0.3 * _hash(i), 0.2, 0.55 * fade * k))


func _metal() -> void:
	var k := strength
	for i in 5: # faint steel sheen bands
		var y := size.y * (0.15 + i * 0.18)
		var sp := _span(y)
		draw_line(Vector2(sp.x, y), Vector2(sp.y, y + size.y * 0.06), Color(0.7, 0.72, 0.9, 0.04 * k), 10.0)
	for i in 3: # lightning streaks flickering now and then
		var period := 2.3 + i * 0.9
		var phase := fposmod(_t + i * 0.83, period)
		if phase > 0.32:
			continue
		var a := (1.0 - phase / 0.32) * 0.45 * k * (0.6 + 0.4 * sin(phase * 60.0))
		var x := size.x * (0.2 + 0.6 * _hash(floorf((_t + i * 0.83) / period) * 3.1 + i))
		var pts := PackedVector2Array()
		var y := size.y * 0.04
		var cx := x
		while y < size.y * 0.7:
			pts.append(Vector2(cx, y))
			y += size.y * (0.06 + 0.05 * _hash(y + i))
			cx += (_hash(y * 0.37 + i) - 0.5) * size.x * 0.14
		draw_polyline(pts, Color(0.75, 0.82, 1.0, a * 0.5), 5.0, true)
		draw_polyline(pts, Color(0.95, 0.95, 1.0, a), 1.6, true)


func _earth() -> void:
	var k := strength
	var tones := [Color(0.62, 0.4, 0.16), Color(0.36, 0.22, 0.1), Color(0.72, 0.52, 0.24), Color(0.3, 0.18, 0.08)]
	for i in 5: # rock strata, darker and lighter layers
		var y0 := size.y * (0.38 + i * 0.13)
		_band(y0, size.y - 1.0, 4.0 + i, 1.0 + 0.3 * i, i * 1.7 + _t * 0.05, Color(tones[i % tones.size()], 0.16 * k))
	for i in 16: # dust motes drifting
		var x := fposmod(size.x * _hash(i * 2.7) + _t * (6.0 + 8.0 * _hash(i)), size.x)
		var y := size.y * (0.1 + 0.8 * _hash(i * 4.1)) + sin(_t * 0.8 + i) * 5.0
		var sp := _span(y)
		if x < sp.x + 2.0 or x > sp.y - 2.0:
			continue
		draw_circle(Vector2(x, y), 1.2 + 1.8 * _hash(i * 9.3), Color(0.95, 0.8, 0.55, 0.22 * k))


func _wood() -> void:
	var k := strength
	for i in 9: # leaf silhouettes swaying
		var x := size.x * (0.05 + 0.9 * _hash(i * 3.3))
		var y := size.y * (0.08 + 0.84 * _hash(i * 1.1))
		var r := size.x * (0.06 + 0.06 * _hash(i * 7.7))
		var rot := _hash(i * 5.5) * TAU + sin(_t * 0.9 + i) * 0.25
		var sp := _span(y)
		if x - r < sp.x or x + r > sp.y:
			continue
		var pts := PackedVector2Array()
		var dir := Vector2.from_angle(rot)
		var nrm := dir.orthogonal()
		for j in 11:
			var t := j / 10.0
			pts.append(Vector2(x, y) + dir * r * (t * 2.0 - 1.0) + nrm * sin(t * PI) * r * 0.42)
		for j in range(9, 0, -1):
			var t := j / 10.0
			pts.append(Vector2(x, y) + dir * r * (t * 2.0 - 1.0) - nrm * sin(t * PI) * r * 0.42)
		var col := Color(0.2, 0.55, 0.22, 0.16 * k) if i % 2 == 0 else Color(0.02, 0.08, 0.03, 0.3 * k)
		draw_colored_polygon(pts, col)
		draw_line(Vector2(x, y) - dir * r, Vector2(x, y) + dir * r, Color(col, col.a * 0.8), 1.0, true)
