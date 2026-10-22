extends Control
## The match background behind the terrain, by map theme (show_theme(), match/theme/map_themes.gd).
## A far layer in screen px on its own CanvasLayer behind the world (match/camera/match_camera.gd):
## fit() sizes it to the screen plus its parallax travel (PARALLAX of how far the camera can move,
## the sky above the map included) and a PAD for the shake, scroll() moves it (CameraModel.parallax()),
## so it covers the screen at every camera position. Three layers:
## - the backdrop, drawn once (again only when the size or the theme changes): grassland is
##   assets/env/sky_match.png (day-sky gradient, sun, distant hills) stretched over the span;
##   another theme its picture at assets/env/sky_<theme>.png when an artist dropped one, else the
##   code-drawn one (match/theme/backdrop_painter.gd);
## - the clouds (the theme's count, tint and height band), drifting slowly with the wind: the
##   only layer redrawn per frame (a few textured rects); they wrap around the width and scroll a
##   little more than the backdrop (CLOUD_PARALLAX: nearer);
## - the theme's particles (snow, embers, dust, wisps, stars: match/theme/sky_fx.gdshader on a
##   ColorRect, animated on the GPU).
## Images via ui/art.gd.

const Art := preload("res://ui/art.gd")
const MapThemes := preload("res://match/theme/map_themes.gd")
const Backdrop := preload("res://match/theme/backdrop_painter.gd")
const FX_SHADER := preload("res://match/theme/sky_fx.gdshader")

const CLOUD_PX := 2.0 # cloud image px per world px at cloud scale 1
const PARALLAX := 0.3 # the backdrop moves this share of the camera's motion
const CLOUD_PARALLAX := 0.5 # the clouds this share
const PAD := 32.0 # px past the screen on every side (the camera's shake)

## Wind of the current turn: the clouds drift its way, faster with more power.
var wind_dir := 0
var wind_power := 0.0
var map_theme := MapThemes.DEFAULT

var _clouds: Array = [] # [position, scale, speed factor, texture]
var _cloud_tint := Color.WHITE
var _drift := 0.0
var _cloud_shift := 0.0 # px the clouds are scrolled past the backdrop (their nearer parallax)
var _sky: Texture2D # the backdrop picture, null = code-drawn
var _cloud_layer: Control
var _fx: ColorRect


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_cloud_layer = Control.new()
	_cloud_layer.mouse_filter = MOUSE_FILTER_IGNORE
	_cloud_layer.draw.connect(_draw_clouds)
	add_child(_cloud_layer)
	_fx = ColorRect.new()
	_fx.mouse_filter = MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = FX_SHADER
	_fx.material = mat
	add_child(_fx)
	show_theme(map_theme)
	resized.connect(_layout)
	_layout()


## Switches the background to a theme (an unknown one is grassland).
func show_theme(theme_id: String) -> void:
	map_theme = theme_id if MapThemes.is_theme(theme_id) else MapThemes.DEFAULT
	var look := MapThemes.look(map_theme)
	_sky = null
	if map_theme == MapThemes.DEFAULT:
		_sky = Art.env("sky_match")
	else:
		var path := sky_override_path(map_theme)
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			_sky = Art.texture(path)
	var c: Array = look["clouds"]
	_cloud_tint = c[1]
	_clouds.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 # the same sky every match
	for i in int(c[0]):
		var tex := Art.env(Art.CLOUDS[i % Art.CLOUDS.size()])
		_clouds.append([Vector2(rng.randf(), rng.randf_range(c[2], c[3])), rng.randf_range(0.7, 1.4), rng.randf_range(0.6, 1.2), tex])
	if _fx != null:
		var fx: Array = look["fx"]
		_fx.visible = int(fx[0]) != MapThemes.FX_NONE
		var mat: ShaderMaterial = _fx.material
		mat.set_shader_parameter("mode", int(fx[0]))
		mat.set_shader_parameter("tint", fx[1])
		mat.set_shader_parameter("density", float(fx[2]))
	queue_redraw()


static func sky_override_path(theme_id: String) -> String:
	return Art.ROOT + "env/sky_%s.png" % theme_id


## Sizes the layer for a screen of view px and a parallax travel of travel px (CameraModel.parallax_travel(PARALLAX)).
func fit(view: Vector2, travel: Vector2) -> void:
	var s := (view + travel + Vector2(PAD, PAD) * 2.0).ceil()
	if s != size:
		size = s
	scroll(Vector2.ZERO)


## Puts the layer at offset (CameraModel.parallax(PARALLAX), screen px, <= 0); cloud_dx: the
## clouds' extra scroll (their parallax minus the backdrop's, screen px).
func scroll(offset: Vector2, cloud_dx: float = 0.0) -> void:
	position = (offset - Vector2(PAD, PAD)).round()
	_cloud_shift = cloud_dx


func _layout() -> void:
	if _cloud_layer == null:
		return
	_cloud_layer.size = size
	_fx.position = Vector2.ZERO
	_fx.size = size
	(_fx.material as ShaderMaterial).set_shader_parameter("rect_size", _fx.size)
	queue_redraw()


func _process(delta: float) -> void:
	_drift += delta * (6.0 + 10.0 * wind_power) * signf(wind_dir if wind_dir != 0 else 1)
	if _fx != null and _fx.visible:
		(_fx.material as ShaderMaterial).set_shader_parameter("wind", wind_power * signf(wind_dir))
	if _cloud_layer != null and not _clouds.is_empty():
		_cloud_layer.queue_redraw()


func _draw() -> void:
	if _sky != null:
		draw_texture_rect(_sky, Rect2(Vector2.ZERO, size), false)
	else:
		Backdrop.paint(self, map_theme, size.x, size.y, 0.0)


func _draw_clouds() -> void:
	# Clouds wrap around the width (a cloud leaving one side comes in on the other, off screen).
	var span := size.x + 400.0
	for c in _clouds:
		var p: Vector2 = c[0]
		var tex: Texture2D = c[3]
		var s: float = c[1] / CLOUD_PX
		var x := fposmod(p.x * span + _drift * float(c[2]) + _cloud_shift, span) - 200.0
		var sz := tex.get_size() * s
		_cloud_layer.draw_texture_rect(tex, Rect2(Vector2(x, p.y * size.y) - sz / 2, sz), false, _cloud_tint)
