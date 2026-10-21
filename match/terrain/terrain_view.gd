extends Node2D
## Draws a TerrainMask in CHUNK × CHUNK px tiles (one Sprite2D each). A tile's textures are its
## solid bytes (L8, the sprite's texture) and its edge bytes (L8, TerrainMask.edge: carved air,
## scorch), coloured by terrain.gdshader with the dirt and grass images (assets/terrain, via
## ui/art.gd). The shader reads neighbours (up to APRON_TOP px above a pixel, APRON_BOTTOM below,
## APRON_SIDE to the sides), so a tile's textures cover its rect grown by those aprons (inside
## the map). An explosion costs one byte edit pass (TerrainMask.carve) and, in refresh(), one
## upload of the tiles whose textures overlap the region it changed (TerrainMask.take_dirty());
## nothing is done per frame.

const Art := preload("res://ui/art.gd")
const SHADER := preload("res://match/terrain/terrain.gdshader")

const CHUNK := 256
const APRON_TOP := 64 # the shader looks 60 px up (open face above)
const APRON_BOTTOM := 8 # tufts look up to tuft_rows (6) down
const APRON_SIDE := 4 # the burnt rim looks 2 px sideways

var uploads := 0 # tile uploads so far (tests)
var _mask
var _tiles: Array[Dictionary] = [] # {rect, tex_rect: Rect2i (world px), sprite, solid, edge: ImageTexture}


func show_mask(mask) -> void:
	_mask = mask
	for t in _tiles:
		t["sprite"].queue_free()
	_tiles.clear()
	if mask.edge.size() != mask.width * mask.height:
		mask.rebuild_edge()
	var map := Rect2i(0, 0, mask.width, mask.height)
	for y0 in range(0, mask.height, CHUNK):
		for x0 in range(0, mask.width, CHUNK):
			var rect := Rect2i(x0, y0, CHUNK, CHUNK).intersection(map)
			var tex_rect := Rect2i(x0 - APRON_SIDE, y0 - APRON_TOP, rect.size.x + 2 * APRON_SIDE,
				rect.size.y + APRON_TOP + APRON_BOTTOM).intersection(map)
			var mat := ShaderMaterial.new()
			mat.shader = SHADER
			mat.set_shader_parameter("dirt_tex", Art.terrain("dirt"))
			mat.set_shader_parameter("grass_tex", Art.terrain("grass_edge"))
			mat.set_shader_parameter("tuft_rows", Art.GRASS_TUFT_ROWS)
			mat.set_shader_parameter("tex_origin", tex_rect.position)
			mat.set_shader_parameter("map_size", Vector2i(mask.width, mask.height))
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = Vector2(rect.position)
			sprite.region_enabled = true
			sprite.region_rect = Rect2(rect.position - tex_rect.position, rect.size)
			sprite.material = mat
			add_child(sprite)
			var tile := {"rect": rect, "tex_rect": tex_rect, "sprite": sprite, "solid": null, "edge": null}
			_tiles.append(tile)
			_upload(tile)
	mask.take_dirty()


## Uploads the tiles whose textures overlap what the mask changed since the last call
## (TerrainMask.take_dirty()); nothing when it did not change.
func refresh() -> void:
	if _mask == null:
		return
	var d: Rect2i = _mask.take_dirty()
	if not d.has_area():
		return
	for t in _tiles:
		if t["tex_rect"].intersects(d):
			_upload(t)


## The tiles' world rects and their textures' (tests).
func tile_rects() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for t in _tiles:
		out.append(t["rect"])
	return out


func tile_texture_rects() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for t in _tiles:
		out.append(t["tex_rect"])
	return out


func _upload(tile: Dictionary) -> void:
	var r: Rect2i = tile["tex_rect"]
	var w: int = _mask.width
	var solid := PackedByteArray()
	var edge := PackedByteArray()
	for y in range(r.position.y, r.end.y):
		var a: int = y * w + r.position.x
		solid.append_array(_mask.solid.slice(a, a + r.size.x))
		edge.append_array(_mask.edge.slice(a, a + r.size.x))
	var solid_img := Image.create_from_data(r.size.x, r.size.y, false, Image.FORMAT_L8, solid)
	var edge_img := Image.create_from_data(r.size.x, r.size.y, false, Image.FORMAT_L8, edge)
	if tile["solid"] == null:
		tile["solid"] = ImageTexture.create_from_image(solid_img)
		tile["edge"] = ImageTexture.create_from_image(edge_img)
		tile["sprite"].texture = tile["solid"]
		tile["sprite"].material.set_shader_parameter("solid_tex", tile["solid"])
		tile["sprite"].material.set_shader_parameter("edge_tex", tile["edge"])
	else:
		tile["solid"].update(solid_img)
		tile["edge"].update(edge_img)
	uploads += 1
