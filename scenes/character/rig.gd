extends Node2D
## A character's cutout rig: part pictures (assets/characters/<id>/lobby/parts/<part>.png) on a
## bone hierarchy (assets/characters/<id>/lobby/rig.json), animated by an AnimationPlayer built
## from the shared animations (assets/characters/lobby_anims.json, a rig.json may add or
## override one). Feet at this node's origin. Built by scenes/character/character.gd with
## lobby_rig on (the screens outside the match: the front view of the parts sheets) when the
## character has one (ui/art.gd rig()); the baked frames are the fallback and the match's view.
## The format is not tied to the front view: a side-view rig can use it later (with its own
## walk / shoot / hurt / die animations). See assets/README.md.
##
## Bones are plain Node2Ds (under Bones, never drawn); each part is a Sprite2D whose transform is
## copied from its bone after every animation step, so the draw order (rig.json `z`) is free of
## the hierarchy. The parts drawn under the gun sit in this node, the ones over it in `front`
## (a second node the owner puts after the gun), so the held gun goes between them. The gun
## follows the gun socket (rig.json `gun`: a point on the gripping hand) and turns with the
## shoulder: set_aim() adds an elevation to the gun arm on top of the animation.
## Bones with `set` "gun" show only while holding the gun, "free" only with the hands free
## (the lobby: the idle plays idle_free).

signal finished(anim: String)

## The muzzle flash 0..1 (animated by the `_flash` track of shoot).
var flash := 0.0
## Draws the parts over the gun: the owner adds it to the same parent, after the gun.
var front: Node2D

var _bones := {} # name -> Node2D
var _parts: Array = [] # [{sprite, bone, set, shade}]
var _skeleton: Node2D
var _aim_node: Node2D # between the torso and the gun arm: the aim turns it
var _player: AnimationPlayer
var _gun: Node2D
var _gun_bone: Node2D
var _gun_local := Transform2D.IDENTITY
var _gun_z := 0
var _hands_free := false
var _anim := ""
var _tint := Color.WHITE


## Builds the rig from Art.rig() data: {scale, bones, gun, textures, anims}.
func setup(data: Dictionary) -> void:
	scale = Vector2.ONE * float(data["scale"])
	_skeleton = Node2D.new()
	_skeleton.name = "Bones"
	add_child(_skeleton)
	front = Node2D.new()
	front.name = "RigFront"
	front.scale = scale
	var pivots := {}
	for b in data["bones"]:
		pivots[b["name"]] = b.get("pivot", Vector2.ZERO)
		var n := Node2D.new()
		n.name = b["name"]
		_bones[b["name"]] = n
	var gun_spec: Dictionary = data["gun"]
	_gun_z = int(gun_spec.get("z", 0))
	var aim_bone := _bone_of_gun_arm(data)
	for b in data["bones"]:
		var n: Node2D = _bones[b["name"]]
		var parent_name: String = b.get("parent", "")
		var parent: Node2D = _bones.get(parent_name, _skeleton)
		var at: Vector2 = b.get("at", Vector2.ZERO) - (pivots.get(parent_name, Vector2.ZERO) as Vector2)
		if b["name"] == aim_bone:
			_aim_node = Node2D.new()
			_aim_node.name = "Aim"
			_aim_node.position = at
			parent.add_child(_aim_node)
			parent = _aim_node
			at = Vector2.ZERO
		n.position = at
		n.rotation_degrees = float(b.get("rot", 0.0))
		n.set_meta("rest_pos", n.position)
		n.set_meta("rest_rot", n.rotation)
		parent.add_child(n)
	# Parts in draw order.
	var order: Array = data["bones"].filter(func(b): return b.has("part"))
	order.sort_custom(func(a, b): return int(a.get("z", 0)) < int(b.get("z", 0)))
	for b in order:
		var s := Sprite2D.new()
		s.name = b["name"]
		s.texture = data["textures"][b["part"]]
		s.centered = false
		s.flip_h = bool(b.get("flip", false))
		s.offset = -(b["pivot"] as Vector2)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # drawn about 1:1: no mipmaps (they blur)
		(front if int(b.get("z", 0)) > _gun_z else self).add_child(s)
		_parts.append({"sprite": s, "bone": _bones[b["name"]], "set": str(b.get("set", "")), "shade": float(b.get("shade", 1.0))})
	_gun_bone = _bones.get(str(gun_spec.get("bone", "")))
	if _gun_bone != null:
		var pv: Vector2 = pivots.get(str(gun_spec["bone"]), Vector2.ZERO)
		_gun_local = Transform2D(deg_to_rad(float(gun_spec.get("angle", 0.0))), (gun_spec["at"] as Vector2) - pv)
	_build_player(data["anims"])
	set_hands_free(false)
	play("idle")


## The bone the gun arm hangs from the torso by (its upper arm): the aim turns it.
static func _bone_of_gun_arm(data: Dictionary) -> String:
	var by_name := {}
	for b in data["bones"]:
		by_name[b["name"]] = b
	var name: String = str(data["gun"].get("bone", ""))
	while by_name.has(name) and by_name.has(str(by_name[name].get("parent", ""))) and str(by_name[name]["parent"]) != "torso":
		name = str(by_name[name]["parent"])
	return name


func _build_player(anims: Dictionary) -> void:
	_player = AnimationPlayer.new()
	_player.name = "Anim"
	add_child(_player)
	_player.root_node = NodePath("..")
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var lib := AnimationLibrary.new()
	for anim_name in anims:
		lib.add_animation(anim_name, build_animation(anims[anim_name], _bones, self))
	_player.add_animation_library("", lib)
	_player.animation_finished.connect(_on_finished)


## An Animation of a lobby_anims.json spec moving `bones` (name -> Node2D with the metas
## rest_pos / rest_rot; paths from `root`, plus `root`'s flash). Also used by full_body.gd.
static func build_animation(spec: Dictionary, bones: Dictionary, root: Node) -> Animation:
	var a := Animation.new()
	a.length = maxf(0.05, float(spec.get("length", 1.0)))
	a.loop_mode = Animation.LOOP_LINEAR if bool(spec.get("loop", false)) else Animation.LOOP_NONE
	var tracks: Dictionary = spec.get("tracks", {})
	for bone_name in bones:
		var n: Node2D = bones[bone_name]
		var tr: Dictionary = tracks.get(bone_name, {})
		var path := path_of(n, root)
		var times: Array = tr.get("t", [0.0])
		var rest_pos: Vector2 = n.get_meta("rest_pos")
		var rest_rot: float = n.get_meta("rest_rot")
		var pos := a.add_track(Animation.TYPE_VALUE)
		var rot := a.add_track(Animation.TYPE_VALUE)
		var scl := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(pos, path + ":position")
		a.track_set_path(rot, path + ":rotation")
		a.track_set_path(scl, path + ":scale")
		for t in [pos, rot, scl]:
			a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
			a.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
		for k in times.size():
			var time := clampf(float(times[k]), 0.0, a.length)
			a.track_insert_key(pos, time, rest_pos + Vector2(_key(tr, "x", k, 0.0), _key(tr, "y", k, 0.0)))
			a.track_insert_key(rot, time, rest_rot + deg_to_rad(_key(tr, "rot", k, 0.0)))
			a.track_insert_key(scl, time, Vector2(_key(tr, "sx", k, 1.0), _key(tr, "sy", k, 1.0)))
	var fl := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(fl, ".:flash")
	var ft: Dictionary = tracks.get("_flash", {})
	var ftimes: Array = ft.get("t", [0.0])
	for k in ftimes.size():
		a.track_insert_key(fl, clampf(float(ftimes[k]), 0.0, a.length), _key(ft, "v", k, 0.0))
	return a


## The node's path from root (built by hand: the rig may not be in the tree yet).
static func path_of(n: Node, root: Node) -> String:
	var names: Array[String] = []
	while n != null and n != root:
		names.push_front(str(n.name))
		n = n.get_parent()
	return "/".join(names)


static func _key(track: Dictionary, field: String, k: int, default: float) -> float:
	var v = track.get(field)
	if not v is Array or v.is_empty():
		return default
	return float(v[mini(k, v.size() - 1)])


## Plays an animation by name (idle, walk, shoot, hurt, die; idle plays idle_free while the
## hands are free). A one-shot one restarts; a looping one already playing goes on.
func play(anim: String) -> void:
	var real := anim
	if anim == "idle" and _hands_free and _player.has_animation("idle_free"):
		real = "idle_free"
	if not _player.has_animation(real):
		return
	_anim = anim
	var looping := _player.get_animation(real).loop_mode != Animation.LOOP_NONE
	if _player.current_animation == real and looping and _player.is_playing():
		return
	_player.play(real)
	_player.seek(0.0, true)
	_sync()


## Jumps to the end of the animation playing (a knocked-out character already lying down).
func to_end() -> void:
	if _player.current_animation != "":
		_player.seek(_player.current_animation_length, true)
		_sync()


## The animation asked for last (idle while idle_free plays).
func animation() -> String:
	return _anim


func has_animation(anim: String) -> bool:
	return _player.has_animation(anim)


func set_hands_free(on: bool) -> void:
	_hands_free = on
	for p in _parts:
		var s: String = p["set"]
		p["sprite"].visible = s == "" or (s == "free") == on
	if _anim == "idle":
		_anim = ""
		play("idle")


## The gun arm's elevation in degrees above level (towards the facing side), on top of the
## animation; 0 = the animation's own hold.
func set_aim(up_deg: float) -> void:
	if _aim_node != null:
		_aim_node.rotation = deg_to_rad(-up_deg)
		_sync()


## The gun node the rig moves to the socket (it stays where the owner put it, between this
## node and `front`).
func attach_gun(gun: Node2D) -> void:
	_gun = gun
	_sync()


## Multiplies every part's colour (hurt flash, knocked-out grey).
func set_tint(c: Color) -> void:
	if c == _tint:
		return
	_tint = c
	for p in _parts:
		var k: float = p["shade"]
		p["sprite"].self_modulate = Color(c.r * k, c.g * k, c.b * k, c.a)


func advance(delta: float) -> void:
	_player.advance(delta)
	_sync()


func _process(delta: float) -> void:
	advance(delta)


## Copies the bones onto the parts and the gun socket onto the gun.
func _sync() -> void:
	for p in _parts:
		p["sprite"].transform = (p["bone"] as Node2D).get_relative_transform_to_parent(_skeleton)
	if front != null:
		front.transform = transform
	if _gun != null and _gun_bone != null:
		var socket := _gun_bone.get_relative_transform_to_parent(_skeleton) * _gun_local
		_gun.transform = transform * socket * Transform2D.IDENTITY.scaled(Vector2.ONE / scale)


func _on_finished(anim: StringName) -> void:
	finished.emit("idle" if anim == &"idle_free" else str(anim))
