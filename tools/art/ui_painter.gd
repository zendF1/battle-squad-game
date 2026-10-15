extends RefCounted
## Code-drawn UI 9-patches (bake source only): the StyleBoxFlat looks the lobby UI used, drawn
## into small textures. ui/art.gd UI_BOXES has the texture margins the game slices them with;
## tools/bake_art.gd saves them as assets/ui/<name>.png.

const GOLD := Color(1.0, 0.8, 0.22)
const GOLD_DARK := Color(0.85, 0.45, 0.08)
const PANEL := Color(0.04, 0.06, 0.16, 0.62)
const PANEL_BORDER := Color(1, 1, 1, 0.1)

## name -> [canvas size, the stylebox rect inset (glow room), StyleBoxFlat params].
## Params: bg, radius, border colour, border width, bottom border (lip), shadow colour, shadow size.
const BOXES := {
	"button_primary": [Vector2i(104, 110), 12, [GOLD, 22, GOLD_DARK, 3, 8, Color(1.0, 0.7, 0.2, 0.35), 10]],
	"button_primary_pressed": [Vector2i(104, 110), 12, [Color(0.94, 0.75, 0.2), 22, GOLD_DARK, 3, 3, Color(1.0, 0.7, 0.2, 0.3), 8]],
	"button_navy": [Vector2i(64, 64), 0, [Color(0.2, 0.34, 0.66, 0.9), 14, Color(1, 1, 1, 0.12), 2, 2, Color.TRANSPARENT, 0]],
	"button_orange": [Vector2i(80, 80), 0, [Color(0.92, 0.45, 0.16), 22, Color(1, 1, 1, 0.5), 3, 6, Color.TRANSPARENT, 0]],
	"button_disabled": [Vector2i(64, 64), 0, [Color(0.12, 0.15, 0.3, 0.6), 14, Color(1, 1, 1, 0.08), 2, 2, Color.TRANSPARENT, 0]],
	"panel": [Vector2i(72, 72), 0, [PANEL, 20, PANEL_BORDER, 2, 2, Color.TRANSPARENT, 0]],
	"panel_selected": [Vector2i(64, 64), 0, [Color(0.2, 0.38, 0.75, 0.95), 16, GOLD, 3, 3, Color.TRANSPARENT, 0]],
	"pill": [Vector2i(56, 56), 0, [Color(0.02, 0.03, 0.1, 0.6), 27, PANEL_BORDER, 2, 2, Color.TRANSPARENT, 0]],
}


static func paint(ci: CanvasItem, box_name: String, size: Vector2) -> void:
	if box_name == "avatar_frame":
		_avatar_frame(ci, size)
		return
	var spec: Array = BOXES[box_name]
	var inset: int = spec[1]
	var p: Array = spec[2]
	var b := StyleBoxFlat.new()
	b.bg_color = p[0]
	b.set_corner_radius_all(p[1])
	b.corner_detail = 16
	b.anti_aliasing = true
	b.border_color = p[2]
	b.set_border_width_all(p[3])
	b.border_width_bottom = p[4]
	if p[6] > 0:
		b.shadow_color = p[5]
		b.shadow_size = p[6]
	ci.draw_style_box(b, Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2))
	# A soft light band across the top of the buttons (a little gloss).
	if box_name.begins_with("button") and box_name != "button_disabled":
		var gloss := StyleBoxFlat.new()
		gloss.bg_color = Color(1, 1, 1, 0.08)
		gloss.set_corner_radius_all(maxi(int(p[1]) - 4, 2))
		gloss.corner_detail = 16
		gloss.anti_aliasing = true
		var r := Rect2(Vector2(inset, inset) + Vector2(p[3] + 2, p[3] + 2), Vector2(size.x - inset * 2 - (p[3] + 2) * 2, (size.y - inset * 2) * 0.32))
		ci.draw_style_box(gloss, r)


## A white rounded frame (transparent inside) laid over the tinted avatar square.
static func _avatar_frame(ci: CanvasItem, size: Vector2) -> void:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0, 0, 0, 0)
	b.draw_center = false
	b.set_corner_radius_all(20)
	b.corner_detail = 16
	b.anti_aliasing = true
	b.border_color = Color(1, 1, 1, 0.92)
	b.set_border_width_all(4)
	ci.draw_style_box(b, Rect2(Vector2(1, 1), size - Vector2(2, 2)))
	var inner := StyleBoxFlat.new()
	inner.draw_center = false
	inner.set_corner_radius_all(16)
	inner.corner_detail = 16
	inner.anti_aliasing = true
	inner.border_color = Color(0, 0, 0, 0.18)
	inner.set_border_width_all(0)
	inner.border_width_bottom = 5
	ci.draw_style_box(inner, Rect2(Vector2(5, 5), size - Vector2(10, 10)))
