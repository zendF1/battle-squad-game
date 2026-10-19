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
## an aim angle until clear_aim(), snapped to one of 7 directions (scenes/character/aim_snap.gd:
## -45, 0, 45 each side and 90 up; visual only, the shot keeps the real angle); muzzle_position()
## is where shots start (visual only). hands_free shows no gun (the bare hand stays); weapon()
## still tells the gun set.
##
## holster (the match, match/views/player_view.gd): the gun is out only to shoot
## (scenes/character/gun_draw.gd): holstered in idle and walk (no gun, no hand over its grip: the
## character's own drawn arms), drawn by aim() / draw_gun() (from a low carry at the hip: turned
## down, smaller, fading in, eased out to the aim angle while the body leans into a ready stance;
## or the side view's drawn "draw" frames when it has them), out while aiming (idle frame, no walk
## swing), shoot() fires it (at once, or once drawn fast: it returns the wait) and it goes away
## fireHoldSec later; clear_aim() holsters it and walking holsters it first. Off: always out.
## A side view with a drawn ready pose (Rookie: side.json "draw" = the ready frame, kneeling with
## both fists on the chest, "fire" = it with the recoil, "gunDraw" all 0 s) switches to it and back
## at once. On it the character hugs a big gun (ui/art.gd hug_gun(): the held weapon's hug art, else
## its kind's in another tier, else its gun sprite turned round its centre) over the fists, no grip
## hand: placed by hand in the character's pose scene (ui/art.gd ready_pose():
## scenes/character/poses/<id>_ready.tscn, one GunSocket and its Preview) and drawn exactly as the
## Preview shows it (Art.gun_transform()), the whole socket turned round its origin (the hug point)
## to the same 7 directions; the shot kicks it back along its axis (HUG_KICK × the frame's flash).
## Its near arm (side.json readyPose.armFront: the sleeve and both fists cut from the ready frame,
## same canvas) is drawn over the gun (Flip/ArmFront, made here, mirrored with the body), so the
## fists hold the gun at every direction; shown only while the gun is hugged. Such a character
## never holds its gun outside the ready pose: on any other animation (hurt just after a shot,
## idle with holster off) the gun is put away (holds_gun() false), so Rookie's bazooka, Tanko's
## cannon and Flora's seed launcher, which have no held sprites, are only ever the hug art.
## Used by the lobby and Prep (ui/character_view.gd) and the match
## (match/views/player_view.gd).
##
## lobby_full (the screens outside the match, ui/character_view.gd): a character with a
## full-body picture (ui/art.gd lobby_full(): assets/characters/<id>/lobby/full.png skinned on
## its skeleton, scenes/character/full_body.gd) is drawn by it instead of the frames: one
## coherent drawing with no gun in hand (holds_gun() false; the screens show the gun beside it),
## idling. Order: full.png → frames. The match keeps the side-view frames.

const Art := preload("res://ui/art.gd")
const FullBody := preload("res://scenes/character/full_body.gd")
const GunDraw := preload("res://scenes/character/gun_draw.gd")
const AimSnap := preload("res://scenes/character/aim_snap.gd")

const HURT_FLASH_SEC := 0.45
const HURT_TINT := Color(1, 0.35, 0.35)
const DEAD_TINT := Color(0.55, 0.55, 0.6)
const DEAD_SHADOW := 1.45 # the shadow widens under a body lying down
## The muzzle flash (fx/common/muzzle.png) size in frame px at full flash, and its tint.
const FLASH_PX := 84.0
const FLASH_TINT := Color(1.0, 0.92, 0.65)
## The hugged gun's kick on a shot: this part of its drawn length back along its axis × the fire
## frame's muzzle flash (1, 0.35, 0).
const HUG_KICK := 0.05
## The animations that follow the base pose (idle / walk, or the armed hold) when it changes.
const BASE_ANIMS := ["idle", "walk", Art.DRAW_ANIM]

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
## The gun is out only to shoot (the match); false: always in hand.
@export var holster := false:
	set(value):
		holster = value
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
var _hug := {} # Art.hug_gun() of it: the gun the drawn ready pose hugs
var _hug_xf := Transform2D() # the hug gun's texture px → Gun node px (the socket's turn excluded)
var _in_pose := false # the gun is drawn as the hug gun
var _aiming := false
var _aim_up := 0.0 # degrees above level towards the facing side, snapped (AimSnap.elevation())
var _full: FullBody # the skinned full-body picture, null otherwise
var _full_id := ""
var _look := {} # Art.character_look()
var _time := 0.0
var _gun_draw := GunDraw.new() # the gun draw (holster on)

@onready var _flip: Node2D = $Flip
@onready var _sprite: AnimatedSprite2D = $Flip/Sprite
@onready var _shadow: Sprite2D = $Shadow
@onready var _gun_node: Node2D = $Flip/Gun
@onready var _gun_sprite: Sprite2D = $Flip/Gun/Sprite
@onready var _hand: Sprite2D = $Flip/Gun/Hand
@onready var _flash: Sprite2D = $Flip/Gun/Flash
var _arm: Sprite2D # Flip/ArmFront: the ready pose's near arm over the hugged gun


func _ready() -> void:
	_shadow.texture = Art.texture(Art.SHADOW)
	_hand.texture = Art.texture(Art.HAND)
	_flash.texture = Art.fx("muzzle")
	_arm = _flip.get_node_or_null("ArmFront") as Sprite2D
	if _arm == null:
		_arm = Sprite2D.new()
		_arm.name = "ArmFront"
		_arm.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_arm.centered = false
		_arm.visible = false
		_flip.add_child(_arm)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_update_gun)
	_sprite.animation_changed.connect(_update_gun)
	_apply_frames()
	_apply_motion()


func _process(delta: float) -> void:
	_time += delta
	if holster and _full == null:
		var ev := _gun_draw.update(delta)
		match ev:
			"fire":
				play(_shoot_anim())
			"holstered":
				_aiming = false
				if animation() in BASE_ANIMS or animation() == Art.FIRE_ANIM:
					play(_base())
		if _sprite.animation == Art.DRAW_ANIM:
			_sprite.frame = _draw_frame()
		if _gun_draw.armed() or ev != "":
			_update_gun()
	_apply_motion()
	_hurt_left = maxf(0.0, _hurt_left - delta)
	var tint := DEAD_TINT if _dead else Color.WHITE.lerp(HURT_TINT, _hurt_left / HURT_FLASH_SEC)
	_sprite.self_modulate = tint
	_gun_sprite.self_modulate = tint
	_arm.self_modulate = tint
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
	_gun_draw = GunDraw.new(_look.get("gun_draw", {}))
	_aiming = _aiming and not holster
	_sprite.sprite_frames = _look["frames"]
	_sprite.offset = -_look["pivot"]
	_sprite.scale = Vector2.ONE * float(_look["scale"])
	_hand.texture = _look["hand"] if _look["hand"] != null else Art.texture(Art.HAND)
	_hand.scale = Vector2.ONE * float(_look["hand_scale"])
	_arm.texture = _look.get("ready", {}).get("arm_front")
	_arm.offset = -_look["pivot"]
	_arm.scale = _sprite.scale
	if _sprite.sprite_frames.has_animation(anim) and not (holster and anim in BASE_ANIMS):
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
	_arm.visible = false
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
	_hug = {}
	if not _look.get("ready", {}).is_empty():
		_hug = Art.hug_gun(kind, tier)
		var rp := Art.ready_pose(character_id)
		var sock: Transform2D = rp["socket"]
		_hug_xf = Transform2D(sock.x, sock.y, Vector2.ZERO) * Art.gun_transform(rp, _hug)
	var tex_px := maxf(1.0, float(_flash.texture.get_width()))
	_flash.scale = Vector2.ONE * (FLASH_PX / tex_px)
	_set_pose_look(_in_pose, true)
	_update_gun()


## The gun sprite and the muzzle as the held gun (its grip on the Gun node's origin) or, pose on,
## as the ready pose's hug gun (_hug_xf: the hold on the hug point). force: set it again (a new gun).
func _set_pose_look(pose: bool, force: bool = false) -> void:
	if pose == _in_pose and not force:
		return
	_in_pose = pose
	if pose and not _hug.is_empty():
		_gun_sprite.texture = _hug["texture"]
		_gun_sprite.offset = Vector2.ZERO
		_gun_sprite.transform = _hug_xf
		_flash.position = _hug_xf * _hug["muzzle"]
		return
	var s: float = _gun["scale"]
	_gun_sprite.texture = _gun["texture"]
	_gun_sprite.transform = Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO)
	_gun_sprite.offset = -_gun["grip"]
	_flash.position = (_gun["muzzle"] - _gun["grip"]) * s


## Turns the gun to an aim angle in degrees (0 right, 90 up, 180 left), measured towards the side
## the character faces and snapped to -45, 0, 45 or 90 above level (AimSnap). Face the aim side
## first (AimSnap.side()); an angle behind it is held at 90 up or -45.
## With holster on it draws the gun (not while walking: walk first).
func aim(angle: float) -> void:
	_aim_up = aim_elevation(angle, facing)
	_aiming = true
	if holster:
		_start_draw()
	_update_gun()


## holster on: draws the gun at level (an aim with no angle yet, e.g. a drag just started); a gun
## being put away comes back from where it is.
func draw_gun() -> void:
	if not holster:
		return
	if not _gun_draw.armed():
		_aim_up = 0.0
	_aiming = true
	_start_draw()
	_update_gun()


func _start_draw() -> void:
	if _dead or _walking or _full != null:
		return
	_gun_draw.draw()
	if animation() in BASE_ANIMS:
		play(_base())


## The gun draw's state (scenes/character/gun_draw.gd STATE_NAMES).
func gun_state() -> String:
	return _gun_draw.state_name() if holster else "aiming"



## An aim angle (0 right, 90 up, 180 left) as degrees above level towards the facing side (1
## right, -1 left), snapped to -45, 0, 45 or 90 (AimSnap.elevation()): the gun turns by minus this.
static func aim_elevation(angle: float, facing_dir: int) -> float:
	return AimSnap.elevation(angle, facing_dir)


## Back to the animation's own hold; with holster on, the gun is put away.
func clear_aim() -> void:
	if holster:
		_gun_draw.holster()
		if not _gun_draw.armed():
			_aiming = false
			if animation() in BASE_ANIMS or animation() == Art.FIRE_ANIM: # put away at once
				play(_base())
		_update_gun()
		return
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


## Where the muzzle will be when a shot leaves (global, visual only): the gun all the way out
## at the aim, on the first shoot frame (shoot() just called: the gun may still be drawing).
func fire_muzzle_position() -> Vector2:
	if _gun.is_empty() or _full != null:
		return global_position
	var anim := _shoot_anim()
	var pose := _gun_pose(anim, 0, 1.0)
	return global_transform * _flip_transform(anim, 0.0, 1.0) * pose["xf"] * _muzzle_for(anim)


## The muzzle in Gun node px on anim: the hug gun's on the ready pose, else the held gun's.
func _muzzle_for(anim: String) -> Vector2:
	if _is_ready_anim(anim) and not hands_free and not _hug.is_empty():
		return _hug_xf * _hug["muzzle"]
	return (_gun["muzzle"] - _gun["grip"]) * float(_gun["scale"])


## Places the gun at the current frame's anchor (and the draw's pose, holster on).
func _update_gun() -> void:
	if _gun_node == null or _gun.is_empty() or _full != null:
		return
	var anim := str(_sprite.animation)
	# A character with a drawn ready pose shows its gun only on it (hugged): out on any other
	# animation (hurt just after a shot, idle with holster off) it is put away, never held.
	var posed: bool = not _look.get("ready", {}).is_empty()
	var out: bool = (not holster or _gun_draw.armed()) and (not posed or _is_ready_anim(anim))
	_gun_node.visible = out
	# On the ready pose the character hugs the hug gun over its fists: no grip hand.
	var in_pose := out and not hands_free and _is_ready_anim(anim)
	_set_pose_look(in_pose)
	_hand.visible = not in_pose
	# The near arm over the hugged gun (the body under it has the same arm: no hole round it).
	_arm.visible = in_pose and _arm.texture != null
	if not out:
		_flash.visible = false
		return
	var pose := _gun_pose(anim, _sprite.frame, _gun_draw.shown() if holster else 1.0)
	_gun_node.transform = pose["xf"]
	_gun_node.modulate.a = _gun_draw.alpha() if holster else 1.0
	var top := _flip.get_child_count() - 1
	if _arm.visible: # the arm on top, the gun right under it
		if _arm.get_index() != top:
			_flip.move_child(_arm, top)
		top -= 1
	var at := top if bool(pose["front"]) else 0
	if _gun_node.get_index() != at:
		_flip.move_child(_gun_node, at)
	var flash: float = pose["flash"]
	_flash.visible = flash > 0.0 and not hands_free
	_flash.modulate = Color(FLASH_TINT, clampf(flash, 0.0, 1.0))


## The gun on frame `frame` of `anim`, k of the way out (the draw's shown(); 1: out), in Flip's
## coordinates: {pos, rot (radians), scale, front, flash}. Out of the way it is the low carry
## (gun_draw.gd TIMINGS carry*) blending to the anchor and the aim; on drawn "draw" frames with
## their own anchors those anchors place it and only the aim blends in.
func _gun_pose(anim: String, frame: int, k: float) -> Dictionary:
	var a := Art.gun_anchor(character_id, anim, frame)
	var grip: Vector2 = a["grip"]
	var deg: float = a["angle"]
	var up := _aim_up if _aiming and not _dead else 0.0
	if _is_ready_anim(anim):
		# The ready pose: the hug gun on the pose scene's socket, the socket turned by the aim round
		# its origin (the hug point), kicked back along the gun's axis by the frame's flash.
		var sock: Transform2D = Art.ready_pose(character_id)["socket"]
		var kick := Vector2.ZERO
		if not _hug.is_empty():
			var axis: Vector2 = _hug_xf.basis_xform(Vector2(float(_hug["size"].x), 0.0))
			kick = -axis * HUG_KICK * float(a["flash"])
		var turn := Transform2D(deg_to_rad(deg - up), sock.origin)
		return {"xf": turn * Transform2D(0.0, kick), "front": true, "flash": float(a["flash"])}
	var pos: Vector2 = (grip - _look.get("pivot", Art.FRAME_PIVOT)) * float(_look.get("scale", 1.0))
	var sc := 1.0
	if holster and k < 1.0:
		if anim == Art.DRAW_ANIM and _look.get("anchors", {}).has(Art.DRAW_ANIM):
			deg -= up * k
		else:
			var t := _gun_draw.timings
			var off := Vector2(float(t["carryOffset"][0]), float(t["carryOffset"][1])) * art_height()
			pos += off * (1.0 - k)
			deg = lerpf(float(t["carryAngle"]), deg - up, k)
			sc = lerpf(float(t["carryScale"]), 1.0, k)
	else:
		deg -= up
	return {"xf": Transform2D(deg_to_rad(deg), Vector2(sc, sc), 0.0, pos), "front": bool(a["front"]), "flash": float(a["flash"])}


## The frame of the drawn "draw" animation for the draw's progress.
func _draw_frame() -> int:
	var n := _sprite.sprite_frames.get_frame_count(Art.DRAW_ANIM) if _sprite.sprite_frames.has_animation(Art.DRAW_ANIM) else 0
	return clampi(int(_gun_draw.progress * n), 0, maxi(0, n - 1))


## The side view's motion of the current animation on Flip (round the feet), mirrored with the
## facing; the baked frames and the full-body picture have none.
func _apply_motion() -> void:
	_flip.transform = _flip_transform(str(_sprite.animation), _progress(), _gun_draw.progress)


## Flip's transform for `anim`'s motion at progress t, with the ready stance of a gun draw at
## progress p (holster on, no drawn "draw" frames: those draw the stance).
func _flip_transform(anim: String, t: float, p: float) -> Transform2D:
	var motion := ""
	if _full == null and not _look.is_empty():
		motion = str(_look["motions"].get(anim, ""))
	var pose := motion_pose(motion, t, _time, _extent())
	if holster and _full == null and p > 0.0 and not bool(_look.get("draw_frames", false)):
		var r := ready_pose(p, _gun_draw.timings)
		pose["rot"] = float(pose["rot"]) + float(r["rot"])
		pose["scale"] = pose["scale"] * r["scale"]
	return Transform2D(float(pose["rot"]) * facing, Vector2(facing * pose["scale"].x, pose["scale"].y), 0.0,
		Vector2(pose["pos"].x * facing, pose["pos"].y))


## The ready stance of a gun draw at progress p (0..1) with gun_draw.gd timings: {rot (radians,
## + leans forward), scale}: leaning forward and squatting a little as the gun comes out (eased
## out like the gun), with a squash-and-stretch bump through the middle of the draw.
static func ready_pose(p: float, timings: Dictionary) -> Dictionary:
	p = clampf(p, 0.0, 1.0)
	var k := 1.0 - pow(1.0 - p, 3.0)
	var bump := sin(p * PI) * float(timings.get("squash", 0.0))
	var crouch := float(timings.get("crouch", 0.0)) * k
	return {"rot": deg_to_rad(float(timings.get("leanDeg", 0.0))) * k,
		"scale": Vector2(1.0 + crouch * 0.5 + bump * 0.5, 1.0 - crouch - bump)}


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
	elif anim == Art.DRAW_ANIM and _sprite.sprite_frames.has_animation(anim):
		_sprite.animation = anim # shown by the draw's progress, not played
		_sprite.stop()
		_sprite.frame = _draw_frame()
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


## holster on: starting to walk with the gun drawn or out (not firing) puts it away first; the
## walk plays once it is holstered.
func set_walking(on: bool) -> void:
	if on == _walking:
		return
	_walking = on
	if on and holster and ((_gun_draw.state == GunDraw.DRAWING and not _gun_draw.fire_pending()) or _gun_draw.state == GunDraw.AIMING):
		_gun_draw.holster()
	if animation() in BASE_ANIMS:
		play(_base())


func is_walking() -> bool:
	return _walking


## Recoil and muzzle flash. holster on: fires the gun, at once when it is out, else once drawn
## fast; returns the seconds until the shot leaves (0: now). with_gun false (a shot not from the
## gun, e.g. an air strike): only the body's recoil, the gun stays as it is.
func shoot(with_gun: bool = true) -> float:
	if _dead:
		return 0.0
	if not holster or not with_gun or _full != null:
		play("shoot")
		return 0.0
	var wait := _gun_draw.fire()
	if wait <= 0.0:
		play(_shoot_anim())
	elif animation() in BASE_ANIMS:
		play(_base())
	_update_gun()
	return wait


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
	_gun_draw.reset()
	_aiming = false
	play("die")
	_shadow.scale.x = DEAD_SHADOW


func is_dead() -> bool:
	return _dead


## The ground shadow (the lobby shrinks it while the character hops).
func shadow() -> Sprite2D:
	return _shadow


## anim is the drawn ready pose's (its hug gun on the pose scene's socket).
func _is_ready_anim(anim: String) -> bool:
	return _full == null and not _look.is_empty() and anim in _look.get("ready", {}).get("anims", [])


## The shot's animation: the drawn "fire" frames (the ready pose's recoil) with holster on and a
## side view that has them, else shoot.
func _shoot_anim() -> String:
	if holster and _full == null and bool(_look.get("fire_frames", false)):
		return Art.FIRE_ANIM
	return "shoot"


func _base() -> String:
	if holster and _full == null and _gun_draw.armed():
		return Art.DRAW_ANIM if bool(_look.get("draw_frames", false)) else "idle"
	return "walk" if _walking else "idle"


func _on_animation_finished() -> void:
	if _sprite.animation != "die":
		play(_base())
		_update_gun()
