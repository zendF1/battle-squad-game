extends Texture2D
## A bigger texture standing in at a smaller size: it reports `logical` as its size (so a Button
## lays its icon out exactly as with an icon of that size: a Button's minimum size counts its icon's
## px) and draws `source` (all its px) wherever it is drawn. ui/art.gd button_icon(): the icons are
## baked at twice their paint size for the big boxes outside buttons (Art.ICON_SIZE), the buttons
## keep the layout of the paint size (Art.ICON_PAINT_SIZE).

var source: Texture2D
var logical := Vector2i(96, 96)


static func of(src: Texture2D, size: Vector2i) -> Texture2D:
	var t = load("res://ui/logical_size_texture.gd").new()
	t.source = src
	t.logical = size
	return t


func _get_width() -> int:
	return logical.x


func _get_height() -> int:
	return logical.y


func _has_alpha() -> bool:
	return source.has_alpha()


func _is_pixel_opaque(x: int, y: int) -> bool:
	var k := Vector2(source.get_size()) / Vector2(logical)
	var img := source.get_image()
	if img == null:
		return true
	return img.get_pixel(clampi(int(x * k.x), 0, img.get_width() - 1), clampi(int(y * k.y), 0, img.get_height() - 1)).a > 0.5


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	source.draw_rect(to_canvas_item, Rect2(pos, Vector2(logical)), false, modulate, transpose)


func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	source.draw_rect(to_canvas_item, rect, tile, modulate, transpose)


func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	var k := Vector2(source.get_size()) / Vector2(logical)
	source.draw_rect_region(to_canvas_item, rect, Rect2(src_rect.position * k, src_rect.size * k), modulate, transpose, clip_uv)
