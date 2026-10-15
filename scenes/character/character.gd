extends Node2D
## A character, feet at this node's origin, facing +x before the flip. Its art is the
## character's SpriteFrames (assets/characters/<id>/<id>.tres, via ui/art.gd): idle and walk
## loop; shoot and hurt play once and go back; die stays on its last frame. Code adds only what
## is a tint or a tween: the red hurt flash and the grey of a knocked-out character.
## Set `scale` for the size: Art.PX_PER_UNIT px per art unit at scale 1 (the art is about 150
## units tall), e.g. 0.35 / Art.PX_PER_UNIT for the ~52 px match body.
## Used by the lobby and Prep (ui/character_view.gd) and the match (match/views/player_view.gd).

const Art := preload("res://ui/art.gd")

const HURT_FLASH_SEC := 0.45
const HURT_TINT := Color(1, 0.35, 0.35)
const DEAD_TINT := Color(0.55, 0.55, 0.6)
const DEAD_SHADOW := 1.45 # the shadow widens under a body lying down

@export var character_id := Art.DEFAULT_CHARACTER:
	set(value):
		character_id = Art.known_character(value)
		if is_node_ready():
			_apply_frames()
## 1 faces right, -1 left.
var facing := 1:
	set(value):
		facing = value
		if is_node_ready():
			_flip.scale.x = facing

var _walking := false
var _dead := false
var _hurt_left := 0.0

@onready var _flip: Node2D = $Flip
@onready var _sprite: AnimatedSprite2D = $Flip/Sprite
@onready var _shadow: Sprite2D = $Shadow


func _ready() -> void:
	_shadow.texture = Art.texture(Art.SHADOW)
	_flip.scale.x = facing
	_sprite.animation_finished.connect(_on_animation_finished)
	_apply_frames()


func _process(delta: float) -> void:
	_hurt_left = maxf(0.0, _hurt_left - delta)
	if _dead:
		_sprite.self_modulate = DEAD_TINT
	else:
		_sprite.self_modulate = Color.WHITE.lerp(HURT_TINT, _hurt_left / HURT_FLASH_SEC)


func _apply_frames() -> void:
	var anim := _sprite.animation
	_sprite.sprite_frames = Art.character_frames(character_id)
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
	else:
		play(_base())
	if _dead:
		_sprite.play("die")
		_sprite.frame = _sprite.sprite_frames.get_frame_count("die") - 1


## Plays an animation by name (idle, walk, shoot, hurt, die).
func play(anim: String) -> void:
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)


func animation() -> String:
	return _sprite.animation


## dir > 0 faces right, < 0 left, 0 keeps the facing.
func face(dir: float) -> void:
	if dir == 0.0 or _dead:
		return
	facing = 1 if dir > 0.0 else -1


func set_walking(on: bool) -> void:
	if on == _walking:
		return
	_walking = on
	if _sprite.animation in ["idle", "walk"]:
		play(_base())


func is_walking() -> bool:
	return _walking


## Recoil and muzzle flash.
func shoot() -> void:
	if not _dead:
		play("shoot")


## Knocked back with a red flash.
func hurt() -> void:
	if not _dead:
		_hurt_left = HURT_FLASH_SEC
		play("hurt")


func die() -> void:
	if _dead:
		return
	_dead = true
	_walking = false
	_hurt_left = 0.0
	play("die")
	_shadow.scale.x = DEAD_SHADOW


func is_dead() -> bool:
	return _dead


## The ground shadow (the lobby shrinks it while the character hops).
func shadow() -> Sprite2D:
	return _shadow


func _base() -> String:
	return "walk" if _walking else "idle"


func _on_animation_finished() -> void:
	if _sprite.animation != "die":
		play(_base())
