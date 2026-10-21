extends Node2D
## While a shell flies above the top of the screen (ShotPlayer.high_shells(): normal shells, the
## flare, the bombs), an arrow on the top edge under it points up at it, following its x, with
## how high it is (px above the top). On its own CanvasLayer over the HUD (match_screen), so the
## top row (timer, wind, portrait) never hides it; screen coordinates are the world's (no camera).

const LobbyUi := preload("res://ui/lobby_ui.gd")

const EDGE := 18.0 # keep the arrow this far inside the screen's sides
const TIP_Y := 6.0 # the arrow's tip, just under the top edge
const SIZE := Vector2(30, 26)
const FILL := Color(1.0, 0.9, 0.35)
const OUTLINE := Color(0.03, 0.04, 0.12, 0.85)
const FONT_SIZE := 18

var shot_player # ShotPlayer
var _arrows: Array = [] # [{x, height}] drawn now


## The arrows for shells at these positions on a screen `width` px wide: one per shell above the
## top (y < 0), x kept EDGE inside the sides, height = how far above the top it is.
static func arrows(shells: PackedVector2Array, width: float) -> Array:
	var out: Array = []
	for p in shells:
		if p.y < 0.0:
			out.append({"x": clampf(p.x, EDGE, width - EDGE), "height": -p.y})
	return out


func _process(_delta: float) -> void:
	var now: Array = arrows(shot_player.high_shells(), get_viewport_rect().size.x) if shot_player != null else []
	if now.is_empty() and _arrows.is_empty():
		return
	_arrows = now
	queue_redraw()


## The arrows shown now ([{x, height}]).
func shown() -> Array:
	return _arrows


func _draw() -> void:
	var font := LobbyUi.bold()
	for a in _arrows:
		var tip := Vector2(a["x"], TIP_Y)
		var w := SIZE.x / 2.0
		var tri := PackedVector2Array([tip, tip + Vector2(w, SIZE.y * 0.6), tip + Vector2(w * 0.4, SIZE.y * 0.6),
			tip + Vector2(w * 0.4, SIZE.y), tip + Vector2(-w * 0.4, SIZE.y), tip + Vector2(-w * 0.4, SIZE.y * 0.6), tip + Vector2(-w, SIZE.y * 0.6)])
		draw_colored_polygon(tri, FILL)
		var rim := tri.duplicate()
		rim.append(tip)
		draw_polyline(rim, OUTLINE, 3.0, true)
		var text := "%d" % roundi(float(a["height"]))
		var pos := Vector2(tip.x - 40.0, tip.y + SIZE.y + FONT_SIZE + 2)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80.0, FONT_SIZE, 5, OUTLINE)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80.0, FONT_SIZE, Color.WHITE)
