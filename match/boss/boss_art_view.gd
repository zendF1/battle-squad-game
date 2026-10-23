extends Control
## A boss or minion figure in a UI box (the Boss tab's cards, Matchmaking's boss card, the HUD's
## turn portrait, the result screen): BossArt drawn with its feet at the bottom centre, as tall
## as the box allows (wide figures, the crabs, fit its width), idling while `idle`.

const BossArt := preload("res://match/boss/boss_art.gd")
const Art := preload("res://ui/art.gd")

const FOOT_MARGIN := 0.06 # of the height, under the feet
const PICTURE_FILL := 0.96 # of the box a picture fills
const PICTURE_BOB := 0.012 # of its height, the idle float

var art := BossArt.GENERIC_BOSS:
	set(v):
		art = v
		queue_redraw()
var facing := 1
var idle := true
var flash := 0.0
var picture := "": # "", "portrait" or "bust"
	set(v):
		picture = v
		queue_redraw()
var _t := 0.0


static func make(art_id: String, box: Vector2, face: int = 1, picture_name: String = "") -> Control:
	var v = load("res://match/boss/boss_art_view.gd").new()
	v.art = art_id
	v.facing = face
	v.picture = picture_name
	v.custom_minimum_size = box
	v.size = box
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS # a picture drawn smaller than it is
	_t = randf() * 3.0


## The drawn picture shown (null: the code-drawn figure).
func picture_texture() -> Texture2D:
	return Art.boss_picture(art, picture) if picture != "" else null


## Where the picture is drawn in the box (its rect; empty without one): fitted, centred.
func picture_rect() -> Rect2:
	var tex := picture_texture()
	if tex == null or tex.get_width() <= 0 or tex.get_height() <= 0:
		return Rect2()
	var k := minf(size.x / tex.get_width(), size.y / tex.get_height()) * PICTURE_FILL
	var s := Vector2(tex.get_width(), tex.get_height()) * k
	return Rect2((size - s) / 2.0, s)


func _process(delta: float) -> void:
	if idle and is_visible_in_tree():
		_t += delta
		queue_redraw()


## The figure's height in px in a box of `box_size`.
static func figure_height(art_id: String, box_size: Vector2) -> float:
	var w: float = BossArt.WIDTH.get(art_id, 1.0)
	return minf(box_size.y * (1.0 - FOOT_MARGIN) * 0.86, box_size.x / w * 0.92)


func _draw() -> void:
	var tex := picture_texture()
	if tex != null:
		var r := picture_rect()
		r.position.y += sin(_t * 1.8) * r.size.y * PICTURE_BOB if idle else 0.0
		draw_texture_rect(tex, r, false, Color(1, 1, 1).lerp(Color(2, 2, 2), clampf(flash, 0.0, 1.0)))
		return
	var h := figure_height(art, size)
	var feet := Vector2(size.x / 2.0 - h * 0.04 * facing, size.y - size.y * FOOT_MARGIN)
	BossArt.draw(self, art, feet, h, _t, facing, flash)
