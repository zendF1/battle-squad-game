extends Control
## A screen's background image (keys and files in ui/art.gd). The default, Art.BG_HOME (the night
## sky of the Home pages and the Loadout), is stretched over the rect as it always was; the bright
## screen backgrounds (the lobby stage, Matchmaking, the result screens; Art.background()) are
## drawn "cover" (Art.cover_source(): the aspect kept, the rect filled, the overflow cut off
## evenly), with a soft dark band at the top (`top_shade`) so the white header texts read on the
## bright sky. show_image() swaps the image with a short cross-fade; `blurred` draws the blurred
## copy (Art.blurred_background(), Matchmaking).

const Art := preload("res://ui/art.gd")

const FADE_SEC := 0.35
## The top band: this share of the height, from TOP_SHADE_ALPHA at the top edge to clear.
const TOP_SHADE_H := 0.24
const TOP_SHADE_ALPHA := 0.5
const TOP_SHADE_COLOR := Color(0.02, 0.04, 0.12)

## The key shown (Art.background_key(): lobby_bg for an image the project lacks).
var image := Art.BG_HOME
var blurred := false
## Draws the dark band at the top (the bright images only).
var top_shade := true

var _from := "" # the image fading out, "" none
var _fade := 1.0 # 0..1, the shown image's opacity over _from
var _tween: Tween

static var _shade_tex: GradientTexture2D


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## Shows the background `key` (Art.background_key()), cross-fading from the one shown when `fade`.
func show_image(key: String, fade: bool = true) -> void:
	key = key if key == Art.BG_HOME else Art.background_key(key)
	if key == image:
		return
	if _tween != null:
		_tween.kill()
	_from = image if fade and is_inside_tree() else ""
	image = key
	_fade = 0.0 if _from != "" else 1.0
	if _from != "":
		_tween = create_tween()
		_tween.tween_method(_set_fade, 0.0, 1.0, FADE_SEC).set_trans(Tween.TRANS_SINE)
	queue_redraw()


func _set_fade(v: float) -> void:
	_fade = v
	if v >= 1.0:
		_from = ""
	queue_redraw()


func _draw() -> void:
	if _from != "":
		_draw_image(_from, 1.0)
	_draw_image(image, _fade)
	if top_shade and image != Art.BG_HOME:
		var a := _fade if _from == Art.BG_HOME else 1.0 # fades in with a bright image over the night sky
		draw_texture_rect(_shade(), Rect2(0, 0, size.x, size.y * TOP_SHADE_H), false, Color(1, 1, 1, a))


func _draw_image(key: String, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var tint := Color(1, 1, 1, alpha)
	if key == Art.BG_HOME:
		draw_texture_rect(Art.env(Art.BG_HOME), Rect2(Vector2.ZERO, size), false, tint)
		return
	var tex := Art.blurred_background(key) if blurred else Art.background(key)
	draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), Art.cover_source(tex.get_size(), size), tint)


static func _shade() -> GradientTexture2D:
	if _shade_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(TOP_SHADE_COLOR, TOP_SHADE_ALPHA))
		g.set_color(1, Color(TOP_SHADE_COLOR, 0.0))
		g.add_point(0.45, Color(TOP_SHADE_COLOR, TOP_SHADE_ALPHA * 0.45))
		_shade_tex = GradientTexture2D.new()
		_shade_tex.gradient = g
		_shade_tex.fill_from = Vector2(0, 0)
		_shade_tex.fill_to = Vector2(0, 1)
		_shade_tex.width = 4
		_shade_tex.height = 128
	return _shade_tex
