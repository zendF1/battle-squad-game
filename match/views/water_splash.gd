extends Node2D
## Water hitting the ground, drawn in code at its position (Tide's water orb, visual only):
## - a bounce (big false): a flat splash ring spreading on the ground, a little crown of water
##   and droplets thrown up off it, falling back;
## - its burst (big true): a wider ring, a dome of water bursting up and droplets flying out all
##   round, over the gun's own impact (ExplosionFx water_gun).
## Fixed droplets from a seed, all computed from the age in _draw(); frees itself after LIFE.

const LIFE := 0.7
const BIG_LIFE := 0.9
const GRAVITY := 900.0
const WATER := Color(0.55, 0.85, 1.0)
const WATER_DARK := Color(0.16, 0.48, 0.86)
const FOAM := Color(0.92, 0.98, 1.0)

var big := false
## The size (px): the ring's widest half width.
var radius := 34.0
var _age := 0.0
var _drops: Array = [] # [velocity, size]


func _ready() -> void:
	z_index = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(position)
	var n := 22 if big else 11
	for i in n:
		var ang: float
		if big:
			ang = rng.randf_range(-PI, 0.2 * PI) if i % 3 != 0 else rng.randf_range(-PI, PI)
		else:
			ang = rng.randf_range(-PI * 0.92, -PI * 0.08) # up off the ground
		var sp := rng.randf_range(160.0, 380.0) * (1.4 if big else 1.0) * radius / 34.0
		_drops.append([Vector2.from_angle(ang) * sp, rng.randf_range(2.2, 4.4) * (1.25 if big else 1.0)])


## How long it lasts (s).
func life() -> float:
	return BIG_LIFE if big else LIFE


func _process(delta: float) -> void:
	_age += delta
	if _age >= life():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var f := clampf(_age / life(), 0.0, 1.0)
	var fade := 1.0 - f
	# the ring spreading on the ground (flattened)
	var rr := radius * (0.35 + 0.9 * (1.0 - pow(1.0 - f, 2.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3 if not big else 0.45))
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(WATER_DARK, 0.5 * fade), maxf(2.0, 8.0 * fade), true)
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(FOAM, 0.95 * fade), maxf(1.5, 5.0 * fade), true)
	draw_arc(Vector2.ZERO, rr * 0.72, 0.0, TAU, 32, Color(WATER, 0.7 * fade), maxf(1.0, 3.5 * fade), true)
	draw_set_transform(Vector2.ZERO)
	# the crown / dome of water rising and sinking
	var up := sin(minf(f * 2.2, 1.0) * PI) * radius * (0.9 if big else 0.55)
	if up > 1.0:
		var w := radius * (0.55 if big else 0.4) * (0.8 + 0.4 * f)
		var crown := PackedVector2Array()
		for i in 13:
			var t := i / 12.0
			var x := lerpf(-w, w, t)
			var spike := 1.0 + (0.35 * sin(t * PI * 6.0) if not big else 0.0)
			crown.append(Vector2(x, -up * sin(t * PI) * spike))
		crown.append(Vector2(w * 0.8, 2.0))
		crown.append(Vector2(-w * 0.8, 2.0))
		draw_colored_polygon(crown, Color(WATER, 0.6 * fade))
		draw_polyline(crown, Color(WATER_DARK, 0.7 * fade), 1.6, true)
	# droplets up and falling back
	for d in _drops:
		var v: Vector2 = d[0]
		var p: Vector2 = v * _age + Vector2(0, 0.5 * GRAVITY * _age * _age)
		if p.y > 4.0 and not big:
			continue # back in the puddle
		var s: float = d[1] * (1.0 - 0.4 * f)
		var vel := v + Vector2(0, GRAVITY * _age)
		var tail := -vel.normalized() * s * 2.2
		draw_line(p, p + tail, Color(WATER, 0.7 * fade), s * 1.1, true)
		draw_circle(p, s, Color(WATER, 0.95 * fade))
		draw_circle(p - Vector2(s, s) * 0.3, s * 0.35, Color(1, 1, 1, 0.9 * fade))
