extends Node2D
## A shell in flight (moved by shot_player.gd): the bomb image (assets/fx/bomb.png, flying
## towards +x, fuse behind) turned along its flight, a flickering spark (assets/fx/muzzle.png)
## on the fuse and a short fading trail of its last positions (drawn in code).

const Art := preload("res://ui/art.gd")

const TRAIL := 10 # positions kept for the trail
const BOMB_PX := 2.0 # bomb image px per world px
const SPARK := Vector2(-11, -3) # fuse tip, world px from the bomb centre (flying +x)

var _trail := PackedVector2Array() # global positions, oldest first
var _dir := Vector2.RIGHT
var _t := 0.0
var _bomb: Texture2D
var _spark: Texture2D


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_bomb = Art.fx("bomb")
	_spark = Art.fx("muzzle")
	_trail.append(global_position)


func _process(delta: float) -> void:
	_t += delta
	var p := global_position
	if _trail.is_empty() or p.distance_squared_to(_trail[-1]) > 0.25:
		var v := p - _trail[-1] if not _trail.is_empty() else Vector2.ZERO
		if v.length_squared() > 0.01:
			_dir = v.normalized()
		_trail.append(p)
		if _trail.size() > TRAIL:
			_trail.remove_at(0)
	queue_redraw()


func _draw() -> void:
	var n := _trail.size()
	for i in range(1, n):
		var k := float(i) / n
		var a := _trail[i - 1] - global_position
		var b := _trail[i] - global_position
		draw_line(a, b, Color(1.0, 0.85, 0.55, 0.45 * k), 2.0 + 6.0 * k, true)
	draw_set_transform(Vector2.ZERO, _dir.angle(), Vector2.ONE)
	var size := _bomb.get_size() / BOMB_PX
	draw_texture_rect(_bomb, Rect2(-size / 2, size), false)
	var flicker := 0.75 + 0.25 * sin(_t * 40.0)
	var spark := Vector2(14, 14) * flicker
	draw_texture_rect(_spark, Rect2(SPARK - spark / 2, spark), false)
	draw_set_transform(Vector2.ZERO)
