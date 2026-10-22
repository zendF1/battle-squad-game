extends Control
## A boss or minion figure in a UI box (the Boss tab's cards, Matchmaking's boss card, the HUD's
## turn portrait, the result screen): BossArt drawn with its feet at the bottom centre, as tall
## as the box allows (wide figures, the crabs, fit its width), idling while `idle`.

const BossArt := preload("res://match/boss/boss_art.gd")

const FOOT_MARGIN := 0.06 # of the height, under the feet

var art := BossArt.GENERIC_BOSS:
	set(v):
		art = v
		queue_redraw()
var facing := 1
var idle := true
var flash := 0.0
var _t := 0.0


static func make(art_id: String, box: Vector2, face: int = 1) -> Control:
	var v = load("res://match/boss/boss_art_view.gd").new()
	v.art = art_id
	v.facing = face
	v.custom_minimum_size = box
	v.size = box
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_t = randf() * 3.0


func _process(delta: float) -> void:
	if idle and is_visible_in_tree():
		_t += delta
		queue_redraw()


## The figure's height in px in a box of `box_size`.
static func figure_height(art_id: String, box_size: Vector2) -> float:
	var w: float = BossArt.WIDTH.get(art_id, 1.0)
	return minf(box_size.y * (1.0 - FOOT_MARGIN) * 0.86, box_size.x / w * 0.92)


func _draw() -> void:
	var h := figure_height(art, size)
	var feet := Vector2(size.x / 2.0 - h * 0.04 * facing, size.y - size.y * FOOT_MARGIN)
	BossArt.draw(self, art, feet, h, _t, facing, flash)
