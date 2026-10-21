extends Sprite2D
## Draws a TerrainMask: the solid bytes are an L8 image coloured by terrain.gdshader with the
## dirt and grass images (assets/terrain, via ui/art.gd). An explosion costs one byte edit pass
## (TerrainMask.carve) and one texture upload (refresh).

const Art := preload("res://ui/art.gd")

var _mask
var _image: Image
var _texture: ImageTexture


func _ready() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://match/terrain/terrain.gdshader")
	mat.set_shader_parameter("dirt_tex", Art.terrain("dirt"))
	mat.set_shader_parameter("grass_tex", Art.terrain("grass_edge"))
	mat.set_shader_parameter("tuft_rows", Art.GRASS_TUFT_ROWS)
	material = mat


func show_mask(mask) -> void:
	_mask = mask
	_image = Image.create_from_data(mask.width, mask.height, false, Image.FORMAT_L8, mask.solid)
	_texture = ImageTexture.create_from_image(_image)
	texture = _texture


func refresh() -> void:
	if _mask == null:
		return
	_image.set_data(_mask.width, _mask.height, false, Image.FORMAT_L8, _mask.solid)
	_texture.update(_image)
