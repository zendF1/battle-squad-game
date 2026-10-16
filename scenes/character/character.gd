extends Node2D
## A character, feet at this node's origin, facing +x before the flip. Its art is the
## character's look (ui/art.gd character_look()): its side view (assets/characters/<id>/side/,
## frames made from hand-drawn art by tools/import_frames.gd, drawn at their own pivot and
## scale) or the code-baked SpriteFrames (assets/characters/<id>/<id>.tres): idle and walk
## loop; shoot and hurt play once and go back; die stays on its last frame. Code adds the red
## hurt flash and the grey of a knocked-out character, and for a side view the motion its
## side.json names per animation (motion_pose(): breathe, recoil, knockback, fall) on the Flip
## node round the feet, so a few drawn frames cover all five animations.
## Set `scale` for the size: Art.PX_PER_UNIT px per art unit at scale 1 (the baked art is about
## 150 units tall), e.g. 0.35 / Art.PX_PER_UNIT for the ~52 px match body.
## Facing left mirrors Flip round the feet (scale.x -1): the frames, the gun anchors, the gun
## (still the right way up: mirrored, not turned) and the muzzle; no position jump on a turn.
##
## The gun is its own sprite (Flip/Gun: the gun, the hand over its grip, the muzzle flash):
## set_weapon(kind, tier) picks it (ui/art.gd gun(); the character's basic gun until then). Each
## frame's gun anchor (assets/characters/<id>/gun_anchors.json) places its grip, angle, front /
## behind the body and the muzzle flash, so the gun follows every animation. aim() turns it to
## an aim angle (within the arm's reach) until clear_aim(); muzzle_position() is where shots
## start (visual only). hands_free shows no gun (the bare hand stays); weapon() still tells the
## gun set. Used by the lobby and Prep (ui/character_view.gd) and the match
## (match/views/player_view.gd).
##
## lobby_full (the screens outside the match, ui/character_view.gd): a character with a
## full-body picture (ui/art.gd lobby_full(): assets/characters/<id>/lobby/full.png skinned on
## its skeleton, scenes/character/full_body.gd) is drawn by it instead of the frames: one
## coherent drawing with no gun in hand (holds_gun() false; the screens show the gun beside it),
## idling. Order: full.png → frames. The match keeps the side-view frames.

const Art := preload("res://ui/art.gd")
const FullBody := preload("res://scenes/character/full_body.gd")

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
## No gun in hand: the frames show the bare hand, no gun or flash.
@export var hands_free := false:
	set(value):
		hands_free = value
		if is_node_ready():
			_apply_frames()
## Draw the character's full-body picture when it has one (outside the match), else the frames.
@export var lobby_full := false:
	set(value):
		lobby_full = value
		if is_node_ready():
			_apply_frames()
## 1 faces right, -1 left.
var facing := 1:
	set(value):
		facing = value
		if is_node_ready():
			_apply_motion()
			_update_gun()

var _walking := false
var _dead := false
var _hurt_left := 0.0
var _weapon_kind := "" # "" = the character's basic gun
var _weapon_tier := ""
var _gun := {} # Art.gun() of the gun shown
var _aiming := false
var _aim_up := 0.0 # degrees above level towards the facing side, clamped
var _full: FullBody # the skinned full-body picture, null otherwise
var _full_id := ""
var _look := {} # Art.character_look()
var _time := 0.0

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
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_update_gun)
	_sprite.animation_changed.connect(_update_gun)
	_apply_frames()
	_apply_motion()


func _process(delta: float) -> void:
	_time += delta
	_apply_motion()
	_hurt_left = maxf(0.0, _hurt_left - delta)
	var tint := DEAD_TINT if _dead else Color.WHITE.lerp(HURT_TINT, _hurt_left / HURT_FLASH_SEC)
	_sprite.self_modulate = tint
	_gun_sprite.self_modulate = tint
	_hand.self_modulate = tint
	if _full != null:
		_full.set_tint(tint)


func _apply_frames() -> void:
	var full := Art.lobby_full(character_id) if lobby_full else {}
	if not full.is_empty():
		_apply_full(full)
		return
	_drop_full()
	var anim := _sprite.animation
	_look = Art.character_look(character_id)
	_sprite.sprite_frames = _look["frames"]
	_sprite.offset = -_look["pivot"]
	_sprite.scale = Vector2.ONE * float(_look["scale"])
	_hand.texture = _look["hand"] if _look["hand"] != null else Art.texture(Art.HAND)
	_hand.scale = Vector2.ONE * float(_look["hand_scale"])
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
	else:
		play(_base())
	if _dead and _sprite.sprite_frames.has_animation("die"):
		_sprite.play("die")
		_sprite.frame = _sprite.sprite_frames.get_frame_count("die") - 1
	_gun_sprite.visible = not hands_free
	_apply_gun()


## The full-body picture of `data` (Art.lobby_full()) instead of the frames and the gun.
func _apply_full(data: Dictionary) -> void:
	if _full == null or _full_id != character_id:
		_drop_full()
		_full = FullBody.new()
		_full.name = "Full"
		_full.setup(data)
		_full_id = character_id
		_flip.add_child(_full)
		_flip.move_child(_full, _sprite.get_index() + 1)
	_sprite.visible = false
	_sprite.stop()
	_flip.transform = Transform2D(0.0, Vector2(facing, 1.0), 0.0, Vector2.ZERO)
	_gun_node.visible = false
	_flash.visible = false
	_full.play(_base())
	_apply_gun()


func _drop_full() -> void:
	if _full == null:
		return
	_flip.remove_child(_full)
	_full.queue_free()
	_full = null
	_full_id = ""
	_sprite.visible = true
	_gun_node.visible = true


## The skinned full-body picture drawing the character (null: the frames).
func full() -> Node2D:
	return _full


## A gun is drawn in the character's hand (false: hands free or the full-body picture).
func holds_gun() -> bool:
	return _gun_node.visible and _gun_sprite.visible


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


## Places the gun at the current frame's anchor.
func _update_gun() -> void:
	if not is_node_ready() or _gun.is_empty() or _full != null:
		return
	var a := Art.gun_anchor(character_id, str(_sprite.animation), _sprite.frame)
	_gun_node.position = (a["grip"] - _look.get("pivot", Art.FRAME_PIVOT)) * float(_look.get("scale", 1.0))
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


## The side view's motion of the current animation on Flip (round the feet), mirrored with the
## facing; the baked frames and the full-body picture have none.
func _apply_motion() -> void:
	var motion := ""
	if _full == null and not _look.is_empty():
		motion = str(_look["motions"].get(str(_sprite.animation), ""))
	var pose := motion_pose(motion, _progress(), _time, _extent())
	_flip.transform = Transform2D(float(pose["rot"]) * facing, Vector2(facing * pose["scale"].x, pose["scale"].y), 0.0,
		Vector2(pose["pos"].x * facing, pose["pos"].y))


## How far the current one-shot animation is (0..1; die stays at 1 once over).
func _progress() -> float:
	var n := _sprite.sprite_frames.get_frame_count(_sprite.animation) if _sprite.sprite_frames != null else 0
	if n <= 0:
		return 0.0
	if not _sprite.is_playing():
		return 1.0
	return clampf((_sprite.frame + _sprite.get_frame_progress()) / n, 0.0, 1.0)


## The figure's size round the feet in character px: {back, front, top}.
func _extent() -> Dictionary:
	var k := float(_look.get("scale", 1.0))
	var e: Dictionary = _look.get("extent", {"back": 0.0, "front": 0.0, "top": 0.0})
	return {"back": float(e["back"]) * k, "front": float(e["front"]) * k, "top": float(e["top"]) * k}


## The figure's height above the feet in character px (the art's top).
func art_height() -> float:
	var look := _look if not _look.is_empty() else Art.character_look(character_id)
	return float(look["extent"]["top"]) * float(look["scale"])


## The pose a side-view motion gives the body round the feet, facing right: {pos (character px),
## rot (radians, + clockwise), scale}. t: the one-shot animation's progress 0..1; time: seconds
## (loops); extent {back, front, top} of the figure in character px.
##   breathe   (idle): a slow vertical stretch, about 1.5 %.
##   recoil    (shoot): kicked back and leaning back, then easing forward again.
##   knockback (hurt): pushed back, squashed, a wobble that dies out.
##   fall      (die): falls on its back round the heels, lifted so the backpack stays on the
##             ground, slid forward so it lies over its feet position; a small bounce at the end.
static func motion_pose(motion: String, t: float, time: float, extent: Dictionary) -> Dictionary:
	var pos := Vector2.ZERO
	var rot := 0.0
	var sc := Vector2.ONE
	var top := maxf(1.0, float(extent.get("top", 240.0)))
	match motion:
		"breathe":
			var b := sin(time * TAU / 2.4)
			sc = Vector2(1.0 - 0.004 * b, 1.0 + 0.015 * b)
		"recoil":
			var e := t / 0.12 if t < 0.12 else pow(1.0 - (t - 0.12) / 0.88, 2.0)
			pos.x = -0.035 * top * e
			rot = deg_to_rad(-4.0) * e
			sc = Vector2(1.0, 1.0 - 0.02 * e)
		"knockback":
			var push := t / 0.2 if t < 0.2 else 1.0 - smoothstep(0.2, 1.0, t)
			pos.x = -0.06 * top * push
			rot = deg_to_rad(-3.0) * push + deg_to_rad(-7.0) * sin(t * TAU * 1.5) * (1.0 - t)
			sc = Vector2(1.0 + 0.02 * push, 1.0 - 0.04 * push)
		"fall":
			var f := pow(t / 0.75, 2.0) if t < 0.75 else 1.0 - 0.06 * sin((t - 0.75) / 0.25 * PI)
			var a := PI * 0.5 * f
			rot = -a
			pos = Vector2(0.45 * top * sin(a), -0.8 * float(extent.get("back", 0.0)) * sin(a))
	return {"pos": pos, "rot": rot, "scale": sc}


## Plays an animation by name (idle, walk, shoot, hurt, die).
func play(anim: String) -> void:
	if _full != null:
		_full.play(anim)
	elif _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)


func animation() -> String:
	if _full != null:
		return _full.animation()
	return str(_sprite.animation)


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
	if _sprite.animation != "die":
		play(_base())
