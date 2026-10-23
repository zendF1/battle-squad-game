extends Node2D
## The impact of a boss's or minion's projectile (UnitShell's kinds, boss mode v3), drawn in code
## on the fx layer at the explode, as wide as its blast (radius), each kind its own (original art):
## - steel_shell: a hot flash, sparks flying out and falling, grey smoke rolling up;
## - magma_bomb: a lava splash (glowing drops arcing out), a molten flash, embers rising;
## - ice_shard / ice_spike: the ice shatters (crystal splinters spinning out), a frost ring;
## - drone_bolt: an energy pop (a ring and short sparks in the drone's red);
## - crab_spit: an orange splat (droplets and a flattened blob fading);
## - snowball: a powder burst (white puffs swelling and falling apart, a few snow chunks).
## Stateless: everything comes from its age (seeded per impact); it frees itself after LIFE s.

const UnitShell := preload("res://match/views/unit_shell.gd")

const LIFE := 0.8
const GRAVITY := 700.0
const PIECES := 10

var kind := UnitShell.STEEL_SHELL
var radius := 40.0
var _t := 0.0
var _seed := 0.0


func _init(kind_id: String = UnitShell.STEEL_SHELL, reach: float = 40.0) -> void:
	kind = kind_id
	radius = clampf(reach, 18.0, 140.0)
	_seed = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func age() -> float:
	return _t


func _n(i: float, j: float) -> float:
	return fposmod(sin((i + _seed) * 12.9898 + j * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	var k := clampf(_t / LIFE, 0.0, 1.0)
	var life := 1.0 - k
	match kind:
		UnitShell.STEEL_SHELL:
			_flash(Color(1.0, 0.85, 0.5), k, 0.5)
			_puffs(Color(0.55, 0.56, 0.6), k, 5, -40.0)
			_sparks(Color(1.0, 0.85, 0.4), k, 1.2)
		UnitShell.MAGMA_BOMB:
			_flash(Color(1.0, 0.5, 0.12), k, 0.7)
			_drops(Color(1.0, 0.5, 0.1), k, 7.0, 1.0)
			_puffs(Color(0.3, 0.2, 0.2), k, 4, -50.0)
		UnitShell.ICE_SHARD, UnitShell.ICE_SPIKE:
			_ring(Color(0.75, 0.95, 1.0), k)
			_splinters(Color(0.55, 0.9, 1.0), k)
			_flash(Color(0.85, 0.97, 1.0), k, 0.35)
		UnitShell.DRONE_BOLT:
			_ring(Color(1.0, 0.4, 0.3), k)
			_flash(Color(1.0, 0.6, 0.45), k, 0.4)
			_sparks(Color(1.0, 0.5, 0.35), k, 0.7)
		UnitShell.CRAB_SPIT:
			draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, radius * 0.45 * (0.6 + 0.4 * k), Color(1.0, 0.55, 0.15, 0.7 * life))
			draw_set_transform(Vector2.ZERO)
			_drops(Color(1.0, 0.6, 0.2), k, 5.0, 0.7)
		UnitShell.SNOWBALL:
			_puffs(Color(0.97, 0.99, 1.0), k, 7, 10.0)
			_drops(Color(0.92, 0.96, 1.0), k, 5.5, 0.8)


func _flash(col: Color, k: float, share: float) -> void:
	var f := clampf(k / share, 0.0, 1.0)
	if f >= 1.0:
		return
	var r := radius * (0.4 + 0.6 * f)
	draw_circle(Vector2.ZERO, r, Color(col, 0.35 * (1.0 - f)))
	draw_circle(Vector2.ZERO, r * 0.5, Color(1, 1, 1, 0.6 * (1.0 - f)))


func _ring(col: Color, k: float) -> void:
	var r := radius * (0.3 + 0.9 * (1.0 - (1.0 - k) * (1.0 - k)))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(col, 0.85 * (1.0 - k)), 4.0 * (1.0 - k) + 1.0, true)


func _puffs(col: Color, k: float, n: int, rise: float) -> void:
	for i in n:
		var a := TAU * (i + _n(i, 1.0) * 0.6) / n
		var d := radius * (0.25 + 0.55 * _n(i, 2.0)) * (1.0 - (1.0 - k) * (1.0 - k))
		var p := Vector2.from_angle(a) * d * Vector2(1.0, 0.6) + Vector2(0, rise * k)
		draw_circle(p, radius * (0.18 + 0.22 * k) * (0.7 + 0.3 * _n(i, 3.0)), Color(col, 0.55 * (1.0 - k)))


func _sparks(col: Color, k: float, speed: float) -> void:
	for i in PIECES:
		var a := -PI * 0.5 + (_n(i, 4.0) - 0.5) * PI * 1.6
		var v := Vector2.from_angle(a) * radius * (3.0 + 3.0 * _n(i, 5.0)) * speed
		var p := v * _t + Vector2(0, 0.5 * GRAVITY * _t * _t)
		var tail := (v + Vector2(0, GRAVITY * _t)).normalized() * 7.0
		draw_line(p - tail, p, Color(col, 1.0 - k), 2.0, true)


func _drops(col: Color, k: float, size: float, speed: float) -> void:
	for i in PIECES:
		var a := -PI * 0.5 + (_n(i, 6.0) - 0.5) * PI * 1.3
		var v := Vector2.from_angle(a) * radius * (2.2 + 2.5 * _n(i, 7.0)) * speed
		var p := v * _t + Vector2(0, 0.5 * GRAVITY * _t * _t)
		draw_circle(p, size * (1.0 - 0.6 * k) * (0.6 + 0.4 * _n(i, 8.0)), Color(col, 1.0 - k * k))


func _splinters(col: Color, k: float) -> void:
	for i in PIECES:
		var a := TAU * (i + _n(i, 9.0) * 0.5) / PIECES
		var v := Vector2.from_angle(a) * radius * (2.5 + 2.0 * _n(i, 10.0))
		var p := v * _t + Vector2(0, 0.5 * GRAVITY * 0.6 * _t * _t)
		var rot := a + _t * (8.0 + 6.0 * _n(i, 11.0))
		var r := 4.0 + 3.0 * _n(i, 12.0)
		var pts := PackedVector2Array([p + Vector2(0, -r).rotated(rot), p + Vector2(r * 0.45, 0).rotated(rot), p + Vector2(0, r).rotated(rot),
			p + Vector2(-r * 0.45, 0).rotated(rot)])
		draw_colored_polygon(pts, Color(col, 1.0 - k))
		draw_line(pts[0], pts[2], Color(1, 1, 1, 0.7 * (1.0 - k)), 1.0, true)
