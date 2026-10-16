extends Node2D
## A character, feet at this node's origin, facing +x before the flip. Its art is the
## character's SpriteFrames (assets/characters/<id>/<id>.tres, via ui/art.gd): idle and walk
## loop; shoot and hurt play once and go back; die stays on its last frame. Code adds only what
## is a tint or a tween: the red hurt flash and the grey of a knocked-out character.
## Set `scale` for the size: Art.PX_PER_UNIT px per art unit at scale 1 (the art is about 150
## units tall), e.g. 0.35 / Art.PX_PER_UNIT for the ~52 px match body.
##
## The gun is its own sprite (Flip/Gun: the gun, the hand over its grip, the muzzle flash):
## set_weapon(kind, tier) picks it (ui/art.gd gun(); the character's basic gun until then). Each
## frame's gun anchor (assets/characters/<id>/gun_anchors.json) places its grip, angle, front /
## behind the body and the muzzle flash, so the gun follows every animation. aim() turns it to
## an aim angle (within the arm's reach) until clear_aim(); muzzle_position() is where shots
## start (visual only). hands_free (the lobby stage) shows no gun: the free pose (both arms
## hanging, ui/art.gd free_frames()) idles instead; weapon() still tells the gun set.
## Used by the lobby and Prep (ui/character_view.gd) and the match (match/views/player_view.gd).
##
## lobby_rig (the screens outside the match, ui/character_view.gd): a character with a lobby
## rig (ui/art.gd rig(): assets/characters/<id>/lobby/rig.json + parts/, the front view) is drawn
## by scenes/character/rig.gd instead of the frames: the same API, the gun held by the rig's
## gripping hand (between its back and front parts), the free pose's idle_free in hands_free; it
## only idles (walk, shoot, hurt, die keep its pose). The match keeps the side-view frames.

const Art := preload("res://ui/art.gd")
const Rig := preload("res://scenes/character/rig.gd")

const HURT_FLASH_SEC := 0.45
const HURT_TINT := Color(1, 0.35, 0.35)
const DEAD_TINT := Color(0.55, 0.55, 0.6)
const DEAD_SHADOW := 1.45 # the shadow widens under a body lying down
## How far the arm turns the gun: degrees above (+) / below (-) level, towards the facing side.
const AIM_UP := 70.0
const AIM_DOWN := -35.0
## The muzzle flash (fx/common/muzzle.png) size in frame px at full flash, and its tint.
const FLASH_PX := 84.0
const FLASH_TINT := Color(1.0, 0.92, 0.65)

@export var character_id := Art.DEFAULT_CHARACTER:
	set(value):
		character_id = Art.known_character(value)
		if is_node_ready():
			_apply_frames()
## No gun in hand: the free pose's idle (the front arm hangs) and no gun, hand or flash. While
## those frames are missing (not imported yet) the normal frames show with the bare hand.
@export var hands_free := false:
	set(value):
		hands_free = value
		if is_node_ready():
			_apply_frames()
## Draw the character's lobby (front-view) rig when it has one, else the frames.
@export var lobby_rig := false:
	set(value):
		lobby_rig = value
		if is_node_ready():
			_apply_frames()
## 1 faces right, -1 left.
var facing := 1:
	set(value):
		facing = value
		if is_node_ready():
			_flip.scale.x = facing
			_update_gun()

var _walking := false
var _dead := false
var _hurt_left := 0.0
var _weapon_kind := "" # "" = the character's basic gun
var _weapon_tier := ""
var _gun := {} # Art.gun() of the gun shown
var _aiming := false
var _aim_up := 0.0 # degrees above level towards the facing side, clamped
var _free_pose := false # the free pose's frames are shown (hands_free)
var _rig: Rig # the cutout rig, null on the frames
var _rig_id := ""

@onready var _flip: Node2D = $Flip
@onready var _sprite: AnimatedSprite2D = $Flip/Sprite
@onready var _shadow: Sprite2D = $Shadow
@onready var _gun_node: Node2D = $Flip/Gun
@onready var _gun_sprite: Sprite2D = $Flip/Gun/Sprite
@onready var _hand: Sprite2D = $Flip/Gun/Hand
@onready var _flash: Sprite2D = $Flip/Gun/Flash


func _ready() -> void:
	_shadow.texture = Art.texture(Art.SHADOW)
	_hand.texture = Art.texture(Art.HAND)
	_flash.texture = Art.fx("muzzle")
	_flip.scale.x = facing
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_update_gun)
	_sprite.animation_changed.connect(_update_gun)
	_apply_frames()


func _process(delta: float) -> void:
	_hurt_left = maxf(0.0, _hurt_left - delta)
	var tint := DEAD_TINT if _dead else Color.WHITE.lerp(HURT_TINT, _hurt_left / HURT_FLASH_SEC)
	_sprite.self_modulate = tint
	_gun_sprite.self_modulate = tint
	_hand.self_modulate = tint
	if _rig != null:
		_rig.set_tint(tint)
		_flash.visible = _rig.flash > 0.0 and not hands_free
		_flash.modulate = Color(FLASH_TINT, clampf(_rig.flash, 0.0, 1.0))


func _apply_frames() -> void:
	var data := Art.rig(character_id) if lobby_rig else {}
	if not data.is_empty():
		_apply_rig(data)
		return
	_drop_rig()
	var anim := _sprite.animation
	var free := Art.free_frames(character_id) if hands_free else null
	_free_pose = free != null
	_sprite.sprite_frames = free if _free_pose else Art.character_frames(character_id)
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
	else:
		play(_base())
	if _dead and _sprite.sprite_frames.has_animation("die"):
		_sprite.play("die")
		_sprite.frame = _sprite.sprite_frames.get_frame_count("die") - 1
	_gun_node.visible = not _free_pose
	_gun_sprite.visible = not hands_free
	_apply_gun()


## The rig of `data` (Art.rig()) instead of the frames: Flip holds Sprite (hidden), the rig (the
## parts under the gun), Gun, the rig's front (the parts over it).
func _apply_rig(data: Dictionary) -> void:
	var anim := animation()
	if _rig == null or _rig_id != character_id:
		_drop_rig()
		_rig = Rig.new()
		_rig.name = "Rig"
		_rig.setup(data)
		_rig_id = character_id
		_flip.add_child(_rig)
		_flip.move_child(_rig, _gun_node.get_index())
		_flip.add_child(_rig.front)
		_flip.move_child(_rig.front, _gun_node.get_index() + 1)
		_rig.attach_gun(_gun_node)
		_rig.finished.connect(_on_rig_finished)
	_sprite.visible = false
	_sprite.stop()
	_hand.visible = false
	_free_pose = hands_free
	_rig.set_hands_free(hands_free)
	if _dead:
		_rig.play("die")
		_rig.to_end()
	elif _rig.has_animation(anim):
		_rig.play(anim)
	else:
		_rig.play(_base())
	_gun_node.visible = not hands_free
	_gun_sprite.visible = not hands_free
	_apply_gun()


func _drop_rig() -> void:
	if _rig == null:
		return
	_rig.front.queue_free()
	_rig.queue_free()
	_flip.remove_child(_rig.front)
	_flip.remove_child(_rig)
	_rig = null
	_rig_id = ""
	_sprite.visible = true
	_hand.visible = true
	_gun_node.transform = Transform2D.IDENTITY


## The cutout rig drawing the character (null: the frames).
func rig() -> Node2D:
	return _rig


## The gun held: kind (Art.GUN_KINDS) and tier (Art.GUN_TIERS; a missing one falls back to the
## kind's basic). "" for kind: the character's own basic gun.
func set_weapon(kind: String, tier: String = Art.GUN_BASIC) -> void:
	_weapon_kind = kind
	_weapon_tier = tier
	if is_node_ready():
		_apply_gun()


## {kind, tier} of the gun shown (after the fallbacks).
func weapon() -> Dictionary:
	return {"kind": str(_gun.get("kind", "")), "tier": str(_gun.get("tier", ""))}


func _apply_gun() -> void:
	var kind := _weapon_kind
	var tier := _weapon_tier
	if kind == "":
		kind = str(Art.CHARACTER_GUNS.get(character_id, Art.DEFAULT_GUN_KIND))
		tier = Art.GUN_BASIC
	_gun = Art.gun(kind, tier)
	_gun_sprite.texture = _gun["texture"]
	_gun_sprite.scale = Vector2.ONE * float(_gun["scale"])
	_gun_sprite.offset = -_gun["grip"]
	var s: float = _gun["scale"]
	_flash.position = (_gun["muzzle"] - _gun["grip"]) * s
	var tex_px := maxf(1.0, float(_flash.texture.get_width()))
	_flash.scale = Vector2.ONE * (FLASH_PX / tex_px)
	_update_gun()


## Turns the gun to an aim angle in degrees (0 right, 90 up, 180 left), measured towards the side
## the character faces and clamped to the arm's reach (AIM_DOWN..AIM_UP). Face the aim side first.
func aim(angle: float) -> void:
	_aim_up = aim_elevation(angle, facing)
	_aiming = true
	_update_gun()


## An aim angle (0 right, 90 up, 180 left) as degrees above level towards the facing side (1
## right, -1 left), clamped to AIM_DOWN..AIM_UP: the gun turns by minus this.
static func aim_elevation(angle: float, facing_dir: int) -> float:
	var up := angle if facing_dir > 0 else 180.0 - angle
	return clampf(wrapf(up, -180.0, 180.0), AIM_DOWN, AIM_UP)


## Back to the animation's own hold.
func clear_aim() -> void:
	if not _aiming:
		return
	_aiming = false
	_update_gun()


func is_aiming() -> bool:
	return _aiming


## The gun's muzzle in global coordinates (where a shot leaves; visual only).
func muzzle_position() -> Vector2:
	if _gun.is_empty():
		return global_position
	return _gun_node.global_transform * _flash.position


## Places the gun at the current frame's anchor (the rig: turns the gun arm to the aim).
func _update_gun() -> void:
	if not is_node_ready() or _gun.is_empty():
		return
	if _rig != null:
		_rig.set_aim(_aim_up if _aiming and not _dead else 0.0)
		return
	var a := Art.gun_anchor(character_id, str(_sprite.animation), _sprite.frame)
	_gun_node.position = a["grip"] - Art.FRAME_PIVOT
	var deg: float = a["angle"]
	if _aiming and not _dead:
		deg -= _aim_up
	_gun_node.rotation = deg_to_rad(deg)
	var at := _flip.get_child_count() - 1 if bool(a["front"]) else 0
	if _gun_node.get_index() != at:
		_flip.move_child(_gun_node, at)
	var flash: float = a["flash"]
	_flash.visible = flash > 0.0 and not hands_free
	_flash.modulate = Color(FLASH_TINT, clampf(flash, 0.0, 1.0))


## Plays an animation by name (idle, walk, shoot, hurt, die).
func play(anim: String) -> void:
	if _rig != null:
		_rig.play(anim)
	elif _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)


func animation() -> String:
	return _rig.animation() if _rig != null else str(_sprite.animation)


## dir > 0 faces right, < 0 left, 0 keeps the facing.
func face(dir: float) -> void:
	if dir == 0.0 or _dead:
		return
	facing = 1 if dir > 0.0 else -1


func set_walking(on: bool) -> void:
	if on == _walking:
		return
	_walking = on
	if animation() in ["idle", "walk"]:
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
	if _rig == null and _sprite.animation != "die":
		play(_base())


func _on_rig_finished(anim: String) -> void:
	if anim != "die" and not _dead:
		play(_base())
