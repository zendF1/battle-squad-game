extends Node2D
## The burn tick at a burning player's turn start (match_screen, PlayerDamaged type burn; the
## missile rain sets the burn): a fire flash over the body, flames licking up from the feet to
## the head and a few embers, ~0.8 s; its "-N" is match_screen's orange floating number. Set
## position to the player's feet before adding it; it frees itself. Fixed pools, no per-frame
## allocation.

const Art := preload("res://ui/art.gd")
const ShotLook := preload("res://match/views/shot_look.gd")

const LIFE := 0.85
const FLAMES := 13
const EMBERS := 10
const BODY := 62.0 # px: feet to head

var _t := 0.0
var _glow: Texture2D
var _smoke: Texture2D
var _rng := RandomNumberGenerator.new()
var _f_off := PackedVector2Array() # flame: start offset from the feet
var _f_rise := PackedFloat32Array() # px/s up
var _f_delay := PackedFloat32Array()
var _f_size := PackedFloat32Array()
var _e_pos := PackedVector2Array()
var _e_vel := PackedVector2Array()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_glow = Art.tier_fx("glow")
	if _glow == null:
		_glow = Art.fx("muzzle")
	_smoke = Art.fx("smoke")
	_rng.randomize()
	_f_off.resize(FLAMES)
	_f_rise.resize(FLAMES)
	_f_delay.resize(FLAMES)
	_f_size.resize(FLAMES)
	for i in FLAMES:
		_f_off[i] = Vector2(_rng.randf_range(-17, 17), -_rng.randf_range(0, BODY * 0.75))
		_f_rise[i] = _rng.randf_range(70, 130)
		_f_delay[i] = _rng.randf_range(0.0, 0.3)
		_f_size[i] = _rng.randf_range(18, 30)
	_e_pos.resize(EMBERS)
	_e_vel.resize(EMBERS)
	for i in EMBERS:
		_e_pos[i] = Vector2(_rng.randf_range(-12, 12), -_rng.randf_range(10, BODY))
		_e_vel[i] = Vector2(_rng.randf_range(-40, 40), -_rng.randf_range(70, 150))


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	for i in EMBERS:
		_e_pos[i] += _e_vel[i] * delta
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	# the flash over the body: orange, a small hot core
	if _t < 0.3:
		var f := _t / 0.3
		var r := lerpf(44.0, 90.0, ease(f, 0.4))
		var c := Vector2(0, -BODY * 0.45)
		draw_texture_rect(_glow, Rect2(c - Vector2(r, r), Vector2(r, r) * 2), false, Color(1.0, 0.38, 0.08, 0.5 * (1.0 - f)))
		var h := 18.0 * (1.0 - f)
		draw_texture_rect(_glow, Rect2(c - Vector2(h, h), Vector2(h, h) * 2), false, Color(1, 0.85, 0.5, 0.6 * (1.0 - f)))
	# flames: tongues (tall glows) from orange through red to smoke as they rise
	for i in FLAMES:
		var a := _t - _f_delay[i]
		if a < 0.0:
			continue
		var life := LIFE - _f_delay[i]
		var f := clampf(a / life, 0.0, 1.0)
		var p: Vector2 = _f_off[i] + Vector2(sin(_t * 19.0 + i) * 3.0, -_f_rise[i] * a)
		var r := _f_size[i] * (1.0 - 0.5 * f) * (0.9 + 0.1 * sin(_t * 41.0 + i * 2.0))
		var col := ShotLook.fire(0.58 * (1.0 - f))
		var tex := _glow if f < 0.65 else _smoke
		draw_set_transform(p, sin(_t * 13.0 + i) * 0.15, Vector2(0.62, 1.35))
		draw_texture_rect(tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(col, 0.85 * (1.0 - f * f)))
		if f < 0.4: # the hot heart of the tongue
			var h := r * 0.45
			draw_texture_rect(_glow, Rect2(-Vector2(h, h), Vector2(h, h) * 2), false, Color(1.0, 0.7, 0.25, 0.7 * (1.0 - f / 0.4)))
	draw_set_transform(Vector2.ZERO)
	for i in EMBERS:
		var c := Color(1.0, 0.6, 0.15, 1.0 - k)
		draw_circle(_e_pos[i], 1.8 * (1.0 - k) + 0.6, c, true, -1.0, true)
