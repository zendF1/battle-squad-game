extends Node2D
## A player's character in the match, feet at the origin (the server position), facing +x before
## the flip. Placeholder art: ui/character_art.gd's code drawing, animated here in code: idle
## breathing, walk (leg swing + bob), shoot (recoil + muzzle flash), hurt (red flash + knockback
## wobble) and dead (falls over, grey). Every animation lives in this one node, so a real
## AnimatedSprite2D can replace it later behind the same calls: character_id, face(),
## set_walking(), shoot(), hurt(), die().

const CharacterArt := preload("res://ui/character_art.gd")

## Units → px: the art (ART_HEIGHT units) stands about 52 px tall over the 28x40 server body.
const SCALE := 0.35
const WALK_CYCLE := 9.0 # rad/s of leg swing
const SHOOT_SEC := 0.35
const HURT_SEC := 0.45
const DIE_SEC := 0.5

var character_id := "rookie":
	set(value):
		character_id = CharacterArt.known_id(value)
		queue_redraw()
## 1 faces right, -1 left.
var facing := 1

var _t := randf() * 10.0 # idle phase, so players do not breathe in step
var _walking := false
var _walk_t := 0.0
var _shoot_left := 0.0
var _hurt_left := 0.0
var _dead := false
var _die_t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _walking:
		_walk_t += delta
	_shoot_left = maxf(0.0, _shoot_left - delta)
	_hurt_left = maxf(0.0, _hurt_left - delta)
	if _dead:
		_die_t = minf(DIE_SEC, _die_t + delta)
	# Hurt: a red flash fading out (self_modulate keeps the owner's modulate free).
	var red := _hurt_left / HURT_SEC
	self_modulate = Color(1, 1, 1).lerp(Color(1, 0.35, 0.35), red) if not _dead else Color(0.55, 0.55, 0.6)
	if is_visible_in_tree():
		queue_redraw()


## dir > 0 faces right, < 0 left, 0 keeps the facing.
func face(dir: float) -> void:
	if dir == 0.0 or _dead:
		return
	facing = 1 if dir > 0.0 else -1


func set_walking(on: bool) -> void:
	if on == _walking:
		return
	_walking = on
	if not on:
		_walk_t = 0.0


func is_walking() -> bool:
	return _walking


func shoot() -> void:
	if not _dead:
		_shoot_left = SHOOT_SEC


func hurt() -> void:
	if not _dead:
		_hurt_left = HURT_SEC


func die() -> void:
	if _dead:
		return
	_dead = true
	_walking = false
	_die_t = 0.0


func is_dead() -> bool:
	return _dead


func _draw() -> void:
	var pose := {}
	var lean := 0.0
	var offset := Vector2.ZERO
	if _walking:
		var s := sin(_walk_t * WALK_CYCLE)
		pose["legs"] = s
		pose["bob"] = absf(s) * 4.0
		lean = 0.06
	else:
		pose["bob"] = (sin(_t * 2.4) * 0.5 + 0.5) * 2.5
	if _shoot_left > 0.0:
		var k := _shoot_left / SHOOT_SEC # 1 → 0
		pose["recoil"] = 14.0 * k * k
		pose["flash"] = clampf((k - 0.55) / 0.45, 0.0, 1.0)
		lean -= 0.08 * k
	if _hurt_left > 0.0:
		var k := _hurt_left / HURT_SEC
		lean += sin(k * 18.0) * 0.18 * k # wobble
		offset.x -= 5.0 * k # knocked back (away from the facing)
	var rot := lean
	if _dead:
		# Falls on its back; the body width lifts the centre off the ground.
		var k := ease(_die_t / DIE_SEC, 0.4)
		rot = -PI / 2 * k
		offset.y -= 24.0 * SCALE * k
		pose["ko"] = true
		pose["bob"] = 0.0
		pose.erase("legs")
	# Ground shadow (not flipped, not rotated).
	draw_set_transform(Vector2(offset.x * facing, 0), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 15.0 if not _dead else 22.0, Color(0, 0, 0, 0.28))
	var xform := Transform2D(rot * facing, Vector2(SCALE * facing, SCALE), 0.0, Vector2(offset.x * facing, offset.y))
	CharacterArt.paint(self, xform, character_id, pose)
	draw_set_transform(Vector2.ZERO)
