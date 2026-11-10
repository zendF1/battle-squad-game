extends Control
## A gear effect's picture (ui/gear_glyphs.gd) as a square control, centred: a passive, an awaken,
## a 6-piece set effect or an upgrade milestone's unlock. `dim` draws it faded (an awaken already
## used, a set effect not reached).

const GearGlyphs := preload("res://ui/gear_glyphs.gd")

var kind := "":
	set(v):
		kind = v
		queue_redraw()
var dim := false:
	set(v):
		dim = v
		modulate = Color(1, 1, 1, 0.38) if v else Color.WHITE


## A `px` square icon of `icon_kind` that ignores the mouse.
static func make(icon_kind: String, px: int):
	var g = new()
	g.kind = icon_kind
	g.name = "Gear_" + icon_kind
	g.custom_minimum_size = Vector2(px, px)
	g.size = Vector2(px, px)
	g.mouse_filter = MOUSE_FILTER_IGNORE
	g.size_flags_horizontal = SIZE_SHRINK_CENTER
	g.size_flags_vertical = SIZE_SHRINK_CENTER
	return g


func _init() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s > 0.0:
		GearGlyphs.draw(self, kind, size / 2.0, s)
