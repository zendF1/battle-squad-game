extends Control
## A screen's background image (keys and files in ui/art.gd). The default, Art.BG_HOME (the night
## sky of the Home pages and the Loadout), is stretched over the rect as it always was; the bright
## screen backgrounds (the lobby stage, Matchmaking, the result screens; Art.background()) are
## drawn "cover" (Art.cover_source(): the aspect kept, the rect filled, the overflow cut off
## evenly), with a soft dark band at the top (`top_shade`) so the white header texts read on the
## bright sky. show_image() swaps the image with a short cross-fade; `blurred` draws the blurred
## copy (Art.blurred_background(), Matchmaking). With a `keep` region (the first screens: the squad on
## the login picture) the picture is drawn framed instead (Art.frame_rect()): cover unless that cuts
## into `keep`, then just small enough to show it all, the uncovered band filled with the picture's
## edge colours (Art.edge_strip()) fading onto it.

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
## The part of the picture (texture UV 0..1) that stays on screen at any aspect ratio, and where the
## crop / the uncovered band goes (Art.frame_rect()). No area: plain cover.
var keep := Rect2()
var align := Vector2(0.5, 0.5)
## The uncovered band's fade onto the picture: this share of the drawn picture's height (width).
const EDGE_FADE := 0.12

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
	if keep.has_area():
		_draw_framed(key, tex, tint)
		return
	draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), Art.cover_source(tex.get_size(), size), tint)


func _draw_framed(key: String, tex: Texture2D, tint: Color) -> void:
	var r := Art.frame_rect(tex.get_size(), size, keep, align)
	var gap_top := r.position.y
	var gap_bottom := size.y - r.end.y
	var gap_left := r.position.x
	var gap_right := size.x - r.end.x
	if gap_top > 0.5 or gap_bottom > 0.5 or gap_left > 0.5 or gap_right > 0.5:
		# under everything: the mean of the top and bottom edges (the corners of a band on two sides)
		draw_rect(Rect2(Vector2.ZERO, size), Color(Art.edge_mean(key), tint.a))
	draw_texture_rect(tex, r, false, tint)
	var fy := r.size.y * EDGE_FADE
	var fx := r.size.x * EDGE_FADE
	if gap_top > 0.5:
		_band(Art.SIDE_TOP, key, Rect2(r.position.x, 0, r.size.x, gap_top), Rect2(r.position.x, gap_top, r.size.x, fy), tint)
	if gap_bottom > 0.5:
		_band(Art.SIDE_BOTTOM, key, Rect2(r.position.x, r.end.y, r.size.x, gap_bottom), Rect2(r.position.x, r.end.y - fy, r.size.x, fy), tint)
	if gap_left > 0.5:
		_band(Art.SIDE_LEFT, key, Rect2(0, r.position.y, gap_left, r.size.y), Rect2(gap_left, r.position.y, fx, r.size.y), tint)
	if gap_right > 0.5:
		_band(Art.SIDE_RIGHT, key, Rect2(r.end.x, r.position.y, gap_right, r.size.y), Rect2(r.end.x - fx, r.position.y, fx, r.size.y), tint)


## An uncovered band (`gap`) painted with the picture's `side` edge colours, and the same colours fading
## over the picture's edge (`fade`: opaque at the edge, clear inside).
func _band(side: int, key: String, gap: Rect2, fade: Rect2, tint: Color) -> void:
	var strip := Art.edge_strip(key, side)
	draw_texture_rect(strip, gap, false, tint)
	var clear := Color(tint, 0.0)
	var pts := PackedVector2Array([fade.position, Vector2(fade.end.x, fade.position.y), fade.end, Vector2(fade.position.x, fade.end.y)])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var cols: PackedColorArray
	match side:
		Art.SIDE_TOP: cols = PackedColorArray([tint, tint, clear, clear])
		Art.SIDE_BOTTOM: cols = PackedColorArray([clear, clear, tint, tint])
		Art.SIDE_LEFT: cols = PackedColorArray([tint, clear, clear, tint])
		_: cols = PackedColorArray([clear, tint, tint, clear])
	draw_polygon(pts, cols, uvs, strip)


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
