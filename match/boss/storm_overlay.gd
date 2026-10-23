extends Node2D
## A storm over the whole screen while a boss's map-wide rain plays (boss mode v3): Phù Thuỷ
## Băng's Bão tuyết is a snowstorm (SNOW: flakes driven slantwise across the view, a few long
## streaks, a pale veil), Cua Dung Nham's map-wide fire bombs an ember storm (EMBER: sparks and ash
## drifting up through a warm haze). Screen space (a child of a CanvasLayer over the world, under
## the HUD), visual only. It fades in over FADE_IN, stays while the rain plays, and after release()
## fades out and frees itself (MAX_SEC at the latest).
## Cheap: the flakes are a fixed table made once; their positions come from the time (no
## per-frame state), one draw_circle each.

const SNOW := "snow"
const EMBER := "ember"
const FADE_IN := 0.5
const FADE_OUT := 0.9
const MAX_SEC := 9.0
const SNOW_FLAKES := 300
const EMBER_FLAKES := 120
const STREAKS := 34

var kind := SNOW
var size := Vector2(1600, 900) # the screen (set from the viewport when in the tree)
var wind := -1.0 # the drift's side (-1 left, 1 right)

var _t := 0.0
var _released := false
var _out := 0.0 # s into the fade out
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _speed := PackedFloat32Array()
var _r := PackedFloat32Array()
var _phase := PackedFloat32Array()


func _init(storm_kind: String = SNOW) -> void:
	kind = storm_kind
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := flake_count()
	for arr in [_x, _y, _speed, _r, _phase]:
		arr.resize(n)
	for i in n:
		_x[i] = rng.randf()
		_y[i] = rng.randf()
		_phase[i] = rng.randf() * TAU
		if kind == SNOW:
			var near := rng.randf() # near flakes are bigger and faster
			_r[i] = lerpf(1.4, 4.6, near * near)
			_speed[i] = lerpf(160.0, 520.0, near)
		else:
			_r[i] = rng.randf_range(1.2, 3.4)
			_speed[i] = rng.randf_range(40.0, 140.0)


func flake_count() -> int:
	return SNOW_FLAKES if kind == SNOW else EMBER_FLAKES


func _ready() -> void:
	var vp := get_viewport()
	if vp != null:
		size = vp.get_visible_rect().size


## The rain is over: fade out and go.
func release() -> void:
	_released = true


func is_released() -> bool:
	return _released


## How strong the storm is now (0..1).
func strength() -> float:
	var k := clampf(_t / FADE_IN, 0.0, 1.0)
	if _released:
		k *= clampf(1.0 - _out / FADE_OUT, 0.0, 1.0)
	return k


func _process(delta: float) -> void:
	_t += delta
	if _released:
		_out += delta
	if (_released and _out >= FADE_OUT) or _t >= MAX_SEC + FADE_OUT:
		queue_free()
		return
	if _t >= MAX_SEC and not _released:
		release()
	queue_redraw()


func _draw() -> void:
	var k := strength()
	if k <= 0.0:
		return
	if kind == SNOW:
		_draw_snow(k)
	else:
		_draw_embers(k)


func _draw_snow(k: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.96, 1.0, 0.22 * k))
	var drift := wind * 0.9 # sideways px per px of fall: a driving storm
	for i in _x.size():
		var fall := _speed[i] * _t
		var y := fposmod(_y[i] * (size.y + 40.0) + fall, size.y + 40.0) - 20.0
		var x := fposmod(_x[i] * (size.x + 80.0) + fall * drift + sin(_t * 1.7 + _phase[i]) * 10.0, size.x + 80.0) - 40.0
		var near := _r[i] / 4.6
		var c := Color(1, 1, 1, (0.6 + 0.4 * near) * k)
		if near > 0.55: # the near flakes blur along their way
			var v := Vector2(drift, 1.0).normalized() * _r[i] * 2.6
			draw_line(Vector2(x, y) - v, Vector2(x, y) + v, c, _r[i] * 1.4, true)
		else:
			draw_circle(Vector2(x, y), _r[i], c)
	# long wind streaks
	for s in STREAKS:
		var u := fposmod(_x[s] + _t * (0.9 + _phase[s] * 0.1), 1.0)
		var y := fposmod(_y[s] * size.y + _t * 60.0, size.y)
		var x := size.x * (u if wind > 0.0 else 1.0 - u)
		var l := 120.0 + 90.0 * _phase[s] / TAU
		var a := Vector2(x, y)
		draw_line(a, a + Vector2(l * signf(wind), l * 0.35), Color(1, 1, 1, 0.38 * k), 2.5, true)


func _draw_embers(k: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.45, 0.15, 0.08 * k))
	for i in _x.size():
		var rise := _speed[i] * _t
		var y := size.y + 20.0 - fposmod(_y[i] * (size.y + 40.0) + rise, size.y + 40.0)
		var x := fposmod(_x[i] * size.x + sin(_t * 1.3 + _phase[i]) * 24.0 + wind * rise * 0.3, size.x)
		var flick := 0.6 + 0.4 * sin(_t * 9.0 + _phase[i] * 3.0)
		var hot := Color(1.0, 0.62 + 0.3 * flick, 0.2, 0.75 * k * flick) if i % 3 != 0 else Color(0.35, 0.3, 0.3, 0.45 * k)
		draw_circle(Vector2(x, y), _r[i], hot)
