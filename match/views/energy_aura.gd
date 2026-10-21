extends Node2D
## The full-energy aura round a player whose skill is ready (shown skill energy 100,
## player_view.gd set_skill_energy()): one node per player, drawn behind the character (over its
## team ring, under the body, the HP bar and the aim): a soft gold-white glow round the body, a
## flickering flame-like rim whose tongues lick upwards round the silhouette, a ring pulsing out
## at the feet and sparks rising past the body. Everything is computed from the time in _draw():
## no nodes, particles or arrays made per frame (the two polygons are kept and refilled). Off, it
## neither processes nor draws.

const GOLD := Color(1.0, 0.78, 0.22)
const FLAME := Color(1.0, 0.58, 0.1)
const WHITE := Color(1.0, 0.97, 0.8)
const SPARKS := 12
const FLAME_POINTS := 36
const WIDTH := 20.0 # the rim's half width round the body
const PULSE_HZ := 1.1
const RING_SEC := 1.3 # one feet ring's life

## px above the feet the art reaches (PlayerView's art top): sets the aura's height.
var height := 56.0

var _t := 0.0
var _outer := PackedVector2Array()
var _inner := PackedVector2Array()
var _edge := PackedVector2Array() # the outer rim closed (its first point again at the end)


func _init() -> void:
	visible = false
	set_process(false)
	_outer.resize(FLAME_POINTS)
	_inner.resize(FLAME_POINTS)
	_edge.resize(FLAME_POINTS + 1)


func set_on(on: bool) -> void:
	if on == visible:
		return
	visible = on
	set_process(on)
	if on:
		_t = 0.0
		queue_redraw()


func is_on() -> bool:
	return visible


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## The flame rim's point i of FLAME_POINTS round the body (centre cy, half height hh, scaled by
## grow): an egg whose upper half breaks into flickering tongues (every other point reaches
## out), flat at the feet (never into the ground).
func _rim(i: int, cy: float, hh: float, grow: float, phase: float) -> Vector2:
	var a := TAU * i / FLAME_POINTS
	var d := Vector2(sin(a), -cos(a)) # 0 at the top, clockwise
	var up := clampf(-d.y + 0.25, 0.0, 1.0) # the tongues start a little under the middle
	var flick := 0.5 + 0.5 * sin(_t * 8.0 + i * 2.1 + phase) * sin(_t * 5.1 + i * 0.7)
	var tongue := up * (0.28 + 0.42 * flick) if i % 2 == 0 else up * 0.06
	var p := Vector2(d.x * WIDTH * grow * (1.0 - 0.3 * maxf(0.0, -d.y)), d.y * hh * grow)
	p += d * (WIDTH * tongue)
	p.y -= up * up * 9.0 * flick * (1.0 if i % 2 == 0 else 0.3)
	return Vector2(p.x, minf(cy + p.y, 1.0))


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * TAU * PULSE_HZ)
	var cy := -height * 0.5
	var hh := height * 0.52
	# The soft halo: stacked ellipses, faint, breathing with the pulse.
	draw_set_transform(Vector2(0, cy), 0.0, Vector2(1.0, hh / WIDTH))
	for i in 3:
		draw_circle(Vector2.ZERO, WIDTH * (1.75 - i * 0.25) * (1.0 + 0.06 * pulse), Color(GOLD, 0.07 + 0.03 * i))
	draw_set_transform(Vector2.ZERO)
	# The flame: an orange outer fire with a bright rim, a pale gold inner one (the body covers
	# the middle, so the fire shows round its outline).
	for i in FLAME_POINTS:
		_outer[i] = _rim(i, cy, hh, 1.12 + 0.05 * pulse, 0.0)
		_edge[i] = _outer[i]
		_inner[i] = _rim(i, cy + 1.0, hh, 0.86, 2.5)
	_edge[FLAME_POINTS] = _outer[0]
	draw_colored_polygon(_outer, Color(FLAME, 0.34 + 0.1 * pulse))
	draw_colored_polygon(_inner, Color(WHITE, 0.3 + 0.1 * pulse))
	draw_polyline(_edge, Color(GOLD.lightened(0.3), 0.75 + 0.2 * pulse), 1.6, true)
	# The feet ring: one spreading and fading, one steady.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
	var life := fmod(_t, RING_SEC) / RING_SEC
	draw_arc(Vector2.ZERO, 16.0 + 22.0 * life, 0.0, TAU, 32, Color(WHITE, 0.85 * (1.0 - life)), 3.0, true)
	draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 32, Color(FLAME, 0.6 + 0.3 * pulse), 3.0, true)
	draw_set_transform(Vector2.ZERO)
	# Sparks rising past the body, each on its own loop: a gold halo round a white core.
	for i in SPARKS:
		var speed := 0.5 + 0.12 * (i % 4)
		var phase := fmod(_t * speed + i * 0.618, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * WIDTH * (0.5 + 0.8 * fmod(i * 0.37, 1.0)) + sin(_t * 3.0 + i) * 3.0
		var y := -2.0 - phase * (height + 30.0)
		var fade := sin(phase * PI)
		var r := 1.5 + 1.3 * fmod(i * 0.53, 1.0)
		draw_line(Vector2(x, y), Vector2(x, y + 6.0 * r), Color(FLAME, 0.5 * fade), r * 1.2, true)
		draw_circle(Vector2(x, y), r * 1.9, Color(GOLD, 0.4 * fade))
		draw_circle(Vector2(x, y), r, Color(WHITE, fade))
