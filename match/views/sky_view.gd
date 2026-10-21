extends Control
## The match background behind the terrain, by map theme (show_theme(), match/theme/map_themes.gd).
## Its rect is the map; everything is painted Art.SKY_MARGIN px past the map's left and right
## edges too (a viewport wider than the map, stretch "expand", shows sky there). Three layers:
## - the backdrop, drawn once (again only when the size or the theme changes): grassland is
##   assets/env/sky_match.png (day-sky gradient, sun, distant hills) stretched over the span;
##   another theme its picture at assets/env/sky_<theme>.png when an artist dropped one, else the
##   code-drawn one (match/theme/backdrop_painter.gd);
## - the clouds (the theme's count, tint and height band), drifting slowly with the wind: the
##   only layer redrawn per frame (a few textured rects);
## - the theme's particles (snow, embers, dust, wisps, stars: match/theme/sky_fx.gdshader on a
##   ColorRect, animated on the GPU).
## Images via ui/art.gd.

const Art := preload("res://ui/art.gd")
const MapThemes := preload("res://match/theme/map_themes.gd")
const Backdrop := preload("res://match/theme/backdrop_painter.gd")
const FX_SHADER := preload("res://match/theme/sky_fx.gdshader")

const CLOUD_PX := 2.0 # cloud image px per world px at cloud scale 1

## Wind of the current turn: the clouds drift its way, faster with more power.
var wind_dir := 0
var wind_power := 0.0
var map_theme := MapThemes.DEFAULT

var _clouds: Array = [] # [position, scale, speed factor, texture]
var _cloud_tint := Color.WHITE
var _drift := 0.0
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


func _layout() -> void:
	if _cloud_layer == null:
		return
	_cloud_layer.size = size
	_fx.position = Vector2(-Art.SKY_MARGIN, 0)
	_fx.size = Vector2(size.x + 2.0 * Art.SKY_MARGIN, size.y)
	(_fx.material as ShaderMaterial).set_shader_parameter("rect_size", _fx.size)
	queue_redraw()


func _process(delta: float) -> void:
	_drift += delta * (6.0 + 10.0 * wind_power) * signf(wind_dir if wind_dir != 0 else 1)
	if _fx != null and _fx.visible:
		(_fx.material as ShaderMaterial).set_shader_parameter("wind", wind_power * signf(wind_dir))
	if _cloud_layer != null and not _clouds.is_empty():
		_cloud_layer.queue_redraw()


func _draw() -> void:
	var x0 := -Art.SKY_MARGIN
	var x1 := size.x + Art.SKY_MARGIN
	if _sky != null:
		draw_texture_rect(_sky, Rect2(x0, 0, x1 - x0, size.y), false)
	else:
		Backdrop.paint(self, map_theme, size.x, size.y, Art.SKY_MARGIN)


func _draw_clouds() -> void:
	# Clouds wrap around the painted width.
	var x0 := -Art.SKY_MARGIN
	var span := size.x + 2.0 * Art.SKY_MARGIN
	for c in _clouds:
		var p: Vector2 = c[0]
		var tex: Texture2D = c[3]
		var s: float = c[1] / CLOUD_PX
		var x := fposmod(p.x * span + _drift * float(c[2]), span) + x0
		var sz := tex.get_size() * s
		_cloud_layer.draw_texture_rect(tex, Rect2(Vector2(x, p.y * size.y) - sz / 2, sz), false, _cloud_tint)
