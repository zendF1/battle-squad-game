extends Node2D
## The bottom of a themed map, in front of the terrain and behind the players: a liquid band
## (water, lava) or the dark of an abyss with fog, one ColorRect coloured by
## match/theme/bottom.gdshader (animated on the GPU, nothing per frame here). It spans the map
## and the sky's margin past both sides, and reaches EXTRA px under the map for a viewport
## taller than the map. Kind "none" (grassland) draws nothing. Only a look: falling past the
## map's bottom is out of the map whatever is drawn.

const MapThemes := preload("res://match/theme/map_themes.gd")
const SHADER := preload("res://match/theme/bottom.gdshader")

const KINDS := {"water": 1, "lava": 2, "abyss": 3}
## px above the map's bottom: where the liquid's surface sits, and how high the rect starts
## (the lava's glow and the back wave above the surface; the abyss's fog).
const LIQUID_SURFACE := 30.0
const LIQUID_TOP := 110.0
const ABYSS_TOP := 170.0
const EXTRA := 400.0

var kind := "none"
var _rect: ColorRect


func setup(theme: String, map_size: Vector2, margin: float) -> void:
	var bottom: Dictionary = MapThemes.look(theme).get("bottom", {})
	kind = str(bottom.get("kind", "none"))
	if _rect != null:
		remove_child(_rect)
		_rect.queue_free()
		_rect = null
	if not KINDS.has(kind):
		kind = "none"
		return
	var top := ABYSS_TOP if kind == "abyss" else LIQUID_TOP
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.position = Vector2(-margin, map_size.y - top)
	_rect.size = Vector2(map_size.x + 2.0 * margin, top + EXTRA)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("kind", KINDS[kind])
	mat.set_shader_parameter("rect_size", _rect.size)
	mat.set_shader_parameter("x_origin", -margin)
	mat.set_shader_parameter("surface", top if kind == "abyss" else top - LIQUID_SURFACE)
	for key in ["top", "deep", "foam"]:
		if bottom.has(key):
			mat.set_shader_parameter(key + "_color", bottom[key])
	if bottom.has("fog"):
		mat.set_shader_parameter("fog_color", bottom["fog"])
	mat.set_shader_parameter("glow_color", bottom.get("glow", bottom.get("top", Color(1, 0.6, 0.2))))
	_rect.material = mat
	add_child(_rect)


## The rect drawn (tests): empty for none.
func band_rect() -> Rect2:
	return Rect2(_rect.position, _rect.size) if _rect != null else Rect2()
