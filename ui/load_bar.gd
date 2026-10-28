extends Control
## The loading screen's progress (screens/splash.gd): a capsule in the logo's colours (light blue rim,
## navy outline, dark track, the wordmark's yellow-to-orange fill with a gloss line), a glint pulsing
## at the fill's head. No number, no words. head_to() sets where the fill creeps to while a step runs
## (it eases toward it and never quite gets there, so a slow step still moves); finish() fills it.

const RIM := Color(0.29, 0.47, 0.8)
const OUTLINE := Color(0.08, 0.1, 0.2)
const TRACK := Color(0.05, 0.08, 0.2, 0.85)
const FILL_TOP := Color(1.0, 0.85, 0.3)
const FILL_BOTTOM := Color(0.97, 0.58, 0.1)
const RIM_W := 4.0
const OUTLINE_W := 4.0
## How fast the shown value closes on the target (per second, exponential).
const EASE := 1.8

## The shown fill, 0..1.
var value := 0.0
var _target := 0.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## The fill creeps toward `to` (0..1) while the step that ends there runs.
func head_to(to: float) -> void:
	_target = clampf(to, value, 1.0)


## Full at once (the last step finished).
func finish() -> void:
	_target = 1.0
	value = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	value += (_target - value) * (1.0 - exp(-delta * EASE))
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_colored_polygon(_capsule(r), RIM)
	var o := r.grow(-RIM_W)
	draw_colored_polygon(_capsule(o), OUTLINE)
	var t := o.grow(-OUTLINE_W)
	draw_colored_polygon(_capsule(t), TRACK)
	if value <= 0.001:
		return
	var f := t.grow(-2.0)
	var w := maxf(f.size.y, f.size.x * value)
	var fill := Rect2(f.position, Vector2(w, f.size.y))
	var pts := _capsule(fill)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(FILL_TOP.lerp(FILL_BOTTOM, clampf((p.y - fill.position.y) / fill.size.y, 0.0, 1.0)))
	var a := clampf(f.size.x * value / f.size.y, 0.0, 1.0) # a sliver grows in from the left end
	if a < 1.0:
		for i in cols.size():
			cols[i].a = a
	draw_polygon(pts, cols)
	var gloss := Rect2(fill.position + Vector2(fill.size.y * 0.35, fill.size.y * 0.18), Vector2(maxf(fill.size.x - fill.size.y * 0.7, 0.0), fill.size.y * 0.22))
	if gloss.size.x > 0.0:
		draw_colored_polygon(_capsule(gloss), Color(1, 1, 1, 0.45 * a))
	var head := Vector2(fill.end.x - fill.size.y * 0.5, fill.position.y + fill.size.y * 0.5)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	draw_circle(head, fill.size.y * (0.32 + 0.08 * pulse), Color(1, 1, 0.85, (0.35 + 0.3 * pulse) * a), true, -1.0, true)


## A rect's capsule outline (half-round ends).
static func _capsule(r: Rect2, seg: int = 12) -> PackedVector2Array:
	var rad := minf(r.size.y, r.size.x) / 2.0
	var cl := Vector2(r.position.x + rad, r.position.y + r.size.y / 2.0)
	var cr := Vector2(r.end.x - rad, cl.y)
	var pts := PackedVector2Array()
	for i in seg + 1:
		pts.append(cr + Vector2.from_angle(-PI / 2 + PI * i / seg) * rad)
	for i in seg + 1:
		pts.append(cl + Vector2.from_angle(PI / 2 + PI * i / seg) * rad)
	return pts
