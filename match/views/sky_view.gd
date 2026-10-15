extends Control
## The match background behind the terrain: assets/env/sky_match.png (day-sky gradient, sun,
## distant hills) stretched over the map and a margin past its left and right edges (so a
## viewport wider than the map, stretch "expand", shows sky there), and the cloud images
## drifting slowly with the wind. Its rect is the map. Images via ui/art.gd.

const Art := preload("res://ui/art.gd")

const CLOUDS := 8
const CLOUD_PX := 2.0 # cloud image px per world px at cloud scale 1

## Wind of the current turn: the clouds drift its way, faster with more power.
var wind_dir := 0
var wind_power := 0.0

var _clouds: Array = [] # [position, scale, speed factor, texture]
var _drift := 0.0
var _sky: Texture2D


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_sky = Art.env("sky_match")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 # the same sky every match
	for i in CLOUDS:
		var tex := Art.env(Art.CLOUDS[i % Art.CLOUDS.size()])
		_clouds.append([Vector2(rng.randf(), rng.randf_range(0.14, 0.4)), rng.randf_range(0.7, 1.4), rng.randf_range(0.6, 1.2), tex])
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_drift += delta * (6.0 + 10.0 * wind_power) * signf(wind_dir if wind_dir != 0 else 1)
	queue_redraw()


func _draw() -> void:
	var x0 := -Art.SKY_MARGIN
	var x1 := size.x + Art.SKY_MARGIN
	draw_texture_rect(_sky, Rect2(x0, 0, x1 - x0, size.y), false)
	# Clouds wrap around the painted width.
	var span := x1 - x0
	for c in _clouds:
		var p: Vector2 = c[0]
		var tex: Texture2D = c[3]
		var s: float = c[1] / CLOUD_PX
		var x := fposmod(p.x * span + _drift * float(c[2]), span) + x0
		var sz := tex.get_size() * s
		draw_texture_rect(tex, Rect2(Vector2(x, p.y * size.y) - sz / 2, sz), false)
