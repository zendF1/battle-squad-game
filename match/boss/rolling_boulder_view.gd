extends Node2D
## Khổng Lồ Đá's Đá lăn boulder, drawn in code at the skill's radius: a round sandstone boulder,
## shaded, with cracks, chips and amber rune glints. Thrown (the projectile kind
## "rolling_boulder", ShotPlayer moves it; set_tangent() tumbles it) and then rolling along the
## roll event's ground path (BossMoves: set_roll() turns it by the distance rolled over its radius
## and kicks dust off the ground behind it). The same node class and size for both, so the throw
## lands into the roll without a jump. Its centre is drawn `radius` px over the path point (the
## path is the ground). settle() fades it out when the replay ends.

const GROUP := "boss_roll"
const STONE := Color(0.72, 0.58, 0.4)
const STONE_DARK := Color(0.46, 0.35, 0.24)
const STONE_LIGHT := Color(0.88, 0.76, 0.56)
const OUT := Color(0.16, 0.11, 0.07)
const RUNE := Color(1.0, 0.72, 0.28)
const DUST := Color(0.78, 0.66, 0.5)
const PUFFS := 18

var radius := 60.0
var on_ground := false # rolling (the centre is lifted off the path), else thrown (centred on the path)
var _spin := 0.0
var _t := 0.0
var _shape := PackedVector2Array()
var _puffs: Array = [] # [global position, age, size]
var _last := Vector2.INF
var _fade := -1.0 # s into the fade out, -1 none


func _init(r: float = 60.0) -> void:
	radius = maxf(r, 12.0)
	z_index = 2
	add_to_group(GROUP)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 22:
		var a := TAU * i / 22.0
		_shape.append(Vector2.from_angle(a) * radius * rng.randf_range(0.9, 1.04))


## Thrown: it tumbles as it flies.
func set_tangent(v: Vector2) -> void:
	if not on_ground and v.length() > 1.0:
		_spin = _t * 6.0 * (-1.0 if v.x < 0.0 else 1.0)


## Rolling: `distance` px rolled along the ground heading `heading`.
func set_roll(distance: float, heading: Vector2) -> void:
	on_ground = true
	_spin = distance / radius * (-1.0 if heading.x < 0.0 else 1.0)
	queue_redraw()


## The replay ended: it fades out and goes.
func settle() -> void:
	if _fade < 0.0:
		_fade = 0.0


## The camera's focus helper (match_screen asks every focused node).
func is_boss_side() -> bool:
	return false


func spin() -> float:
	return _spin


func _process(delta: float) -> void:
	_t += delta
	if _fade >= 0.0:
		_fade += delta
		modulate.a = clampf(1.0 - _fade / 0.45, 0.0, 1.0)
		if _fade >= 0.45:
			queue_free()
			return
	for p in _puffs:
		p[1] = float(p[1]) + delta
	while not _puffs.is_empty() and float(_puffs[0][1]) > 0.7:
		_puffs.pop_front()
	if on_ground and is_inside_tree():
		if _last != Vector2.INF and global_position.distance_to(_last) > radius * 0.3:
			_puffs.append([global_position + Vector2(0, -2), 0.0, radius * randf_range(0.25, 0.4)])
			if _puffs.size() > PUFFS:
				_puffs.pop_front()
			_last = global_position
		elif _last == Vector2.INF:
			_last = global_position
	queue_redraw()


func _draw() -> void:
	for p in _puffs:
		var k := float(p[1]) / 0.7
		draw_circle(to_local(p[0]) + Vector2(0, -12.0 * k), float(p[2]) * (0.6 + 0.8 * k), Color(DUST, 0.4 * (1.0 - k)))
	var c := Vector2(0, -radius) if on_ground else Vector2.ZERO
	if on_ground:
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, radius * 0.9, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO)
	draw_set_transform(c, _spin)
	draw_colored_polygon(_shape, STONE_DARK)
	var lit := PackedVector2Array()
	for p in _shape:
		lit.append(p * 0.86 + Vector2(-radius * 0.08, -radius * 0.1))
	draw_colored_polygon(lit, STONE)
	draw_circle(Vector2(-radius * 0.32, -radius * 0.34), radius * 0.3, Color(STONE_LIGHT, 0.7))
	# cracks and chips
	draw_polyline(PackedVector2Array([Vector2(-radius * 0.6, radius * 0.1), Vector2(-radius * 0.2, radius * 0.05),
		Vector2(0, radius * 0.35), Vector2(radius * 0.35, radius * 0.4)]), OUT, 3.0, true)
	draw_polyline(PackedVector2Array([Vector2(radius * 0.1, -radius * 0.7), Vector2(radius * 0.22, -radius * 0.3),
		Vector2(radius * 0.55, -radius * 0.2)]), OUT, 2.5, true)
	draw_circle(Vector2(radius * 0.45, radius * 0.1), radius * 0.09, STONE_DARK)
	draw_circle(Vector2(-radius * 0.15, radius * 0.6), radius * 0.07, STONE_DARK)
	# amber rune glints
	var glow := 0.6 + 0.4 * sin(_t * 5.0)
	draw_polyline(PackedVector2Array([Vector2(-radius * 0.1, -radius * 0.2), Vector2(radius * 0.05, radius * 0.0),
		Vector2(-radius * 0.08, radius * 0.18)]), Color(RUNE, 0.9 * glow), 3.0, true)
	var outline := _shape.duplicate()
	outline.append(_shape[0])
	draw_polyline(outline, OUT, 3.5, true)
	draw_set_transform(Vector2.ZERO)
