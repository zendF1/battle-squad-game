extends Sprite2D
## Draws a TerrainMask: the solid bytes are an L8 image colored by terrain.gdshader. An explosion
## costs one byte edit pass (TerrainMask.destroy_circle) and one texture upload (refresh).

var _mask
var _image: Image
var _texture: ImageTexture


func _ready() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://match/terrain/terrain.gdshader")
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
