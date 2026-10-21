extends Node2D
## Draws a TerrainMask in CHUNK × CHUNK px tiles (one Sprite2D each). A tile's textures are its
## solid bytes (L8, the sprite's texture), its edge bytes (L8, TerrainMask.edge: carved air,
## scorch) and its destructible bytes (L8: soft vs hard ground; they never change, so they are
## uploaded once per show_mask()), coloured by terrain.gdshader with the map theme's soft and hard
## materials (show_theme(): match/theme/theme_materials.gd; grassland by default: the dirt and
## grass images of assets/terrain). The shader reads neighbours (up to APRON_TOP px above a pixel, APRON_BOTTOM below,
## APRON_SIDE to the sides), so a tile's textures cover its rect grown by those aprons (inside
## the map). An explosion costs one byte edit pass (TerrainMask.carve) and, in refresh(), one
## upload of the tiles whose textures overlap the region it changed (TerrainMask.take_dirty());
## nothing is done per frame.

const MapThemes := preload("res://match/theme/map_themes.gd")
const Materials := preload("res://match/theme/theme_materials.gd")
const SHADER := preload("res://match/terrain/terrain.gdshader")

const CHUNK := 256
const APRON_TOP := 64 # the shader looks 60 px up (open face above; a hang 12 px)
const APRON_BOTTOM := 8 # caps look up to 8 px down
const APRON_SIDE := 4 # the burnt rim looks 2 px sideways

var uploads := 0 # tile uploads so far (tests)
var map_theme := MapThemes.DEFAULT
var _soft: Dictionary = {}
var _hard: Dictionary = {}
var _mask
var _tiles: Array[Dictionary] = [] # {rect, tex_rect: Rect2i (world px), sprite, solid, edge, dest: ImageTexture}


## The materials of a theme (MapThemes.LOOKS soft / hard); call before show_mask(). An unknown
## theme is grassland.
func show_theme(theme_id: String) -> void:
	map_theme = theme_id if MapThemes.is_theme(theme_id) else MapThemes.DEFAULT
	var look := MapThemes.look(map_theme)
	_soft = Materials.material(look["soft"])
	_hard = Materials.material(look["hard"])
	for t in _tiles:
		_apply_materials(t["sprite"].material)


func _apply_materials(mat: ShaderMaterial) -> void:
	if _soft.is_empty():
		show_theme(map_theme)
	for side in [["soft", _soft], ["hard", _hard]]:
		var p: String = side[0]
		var m: Dictionary = side[1]
		mat.set_shader_parameter(p + "_fill", m["fill"])
		mat.set_shader_parameter(p + "_edge", m["edge"])
		mat.set_shader_parameter(p + "_hang", m["hang"])
		mat.set_shader_parameter(p + "_cap", m["cap"])
		mat.set_shader_parameter(p + "_hang_rows", m["hang_rows"])
		mat.set_shader_parameter(p + "_bottom_tint", m["bottom_tint"])
		mat.set_shader_parameter(p + "_rim", m["rim"])
		mat.set_shader_parameter(p + "_rim_mix", m["rim_mix"])


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
			_apply_materials(mat)
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
			var soft_bytes: PackedByteArray = mask.destructible if mask.destructible.size() == mask.width * mask.height else mask.solid
			var dest := ImageTexture.create_from_image(_image(soft_bytes, tex_rect))
			tile["dest"] = dest
			mat.set_shader_parameter("dest_tex", dest)
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


## The L8 image of a mask's bytes over rect r (world px).
func _image(bytes: PackedByteArray, r: Rect2i) -> Image:
	var w: int = _mask.width
	var out := PackedByteArray()
	for y in range(r.position.y, r.end.y):
		var a: int = y * w + r.position.x
		out.append_array(bytes.slice(a, a + r.size.x))
	return Image.create_from_data(r.size.x, r.size.y, false, Image.FORMAT_L8, out)


func _upload(tile: Dictionary) -> void:
	var r: Rect2i = tile["tex_rect"]
	var solid_img := _image(_mask.solid, r)
	var edge_img := _image(_mask.edge, r)
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
