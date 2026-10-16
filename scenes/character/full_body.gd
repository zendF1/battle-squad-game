extends Node2D
## A character's full-body picture (assets/characters/<id>/lobby/full.png: one coherent drawing,
## cut from art_source/characters/lineup_v1.png) skinned on a skeleton: a Polygon2D mesh over
## the picture (uv = vertex at rest, so it draws 1:1), weighted to Bone2Ds under a Skeleton2D
## (root at the feet, hips, chest, head, each arm shoulder → elbow → hand, each leg hip → knee
## → foot), animated by an AnimationPlayer built from the shared
## assets/characters/lobby_full_anims.json merged with the character's own tracks (full.json
## anims). Everything comes from ui/art.gd lobby_full() (full.json: bones, mesh, weights; made by
## tools/cut_sheet.gd). Feet at this node's origin. Built by scenes/character/character.gd for
## the screens outside the match (lobby_rig + lobby_full); it only idles and draws no gun (the
## pose has no gun hand). See assets/README.md.

const Rig := preload("res://scenes/character/rig.gd")

## Target of an animation's `_flash` track (unused: no gun).
var flash := 0.0

var _bones := {} # name -> Bone2D
var _skeleton: Skeleton2D
var _mesh: Polygon2D
var _player: AnimationPlayer
var _anim := ""


## Builds it from Art.lobby_full() data.
func setup(data: Dictionary) -> void:
	scale = Vector2.ONE * float(data["scale"])
	var body := Node2D.new()
	body.name = "Body"
	body.position = -(data["pivot"] as Vector2)
	add_child(body)
	_skeleton = Skeleton2D.new()
	_skeleton.name = "Skeleton"
	body.add_child(_skeleton)
	var at_of := {"": Vector2.ZERO}
	for b in data["bones"]:
		var bone := Bone2D.new()
		bone.name = b["name"]
		var at: Vector2 = b["at"]
		bone.position = at - (at_of[b["parent"]] as Vector2)
		at_of[b["name"]] = at
		var seg: Vector2 = (b["tip"] as Vector2) - at
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(maxf(1.0, seg.length()))
		bone.set_bone_angle(seg.angle())
		bone.rest = bone.transform
		bone.set_meta("rest_pos", bone.position)
		bone.set_meta("rest_rot", bone.rotation)
		(_bones.get(b["parent"], _skeleton) as Node).add_child(bone)
		_bones[b["name"]] = bone
	_mesh = Polygon2D.new()
	_mesh.name = "Mesh"
	_mesh.texture = data["texture"]
	_mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # drawn about 1:1: no mipmaps (they blur)
	_mesh.polygon = data["vertices"]
	_mesh.uv = data["vertices"]
	_mesh.polygons = data["polygons"]
	body.add_child(_mesh)
	_mesh.skeleton = NodePath("../Skeleton")
	var bones: Array = data["bones"]
	for i in bones.size():
		var w: PackedFloat32Array = data["weights"][i]
		var used := false
		for x in w:
			if x > 0.0:
				used = true
				break
		if used:
			_mesh.add_bone(NodePath(Rig.path_of(_bones[bones[i]["name"]], _skeleton)), w)
	_player = AnimationPlayer.new()
	_player.name = "Anim"
	add_child(_player)
	_player.root_node = NodePath("..")
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var lib := AnimationLibrary.new()
	for anim_name in data["anims"]:
		lib.add_animation(anim_name, Rig.build_animation(data["anims"][anim_name], _bones, self))
	_player.add_animation_library("", lib)
	play("idle")


## Plays an animation by name; one it does not have (walk, shoot ...) keeps the idle.
func play(anim: String) -> void:
	var real := anim if _player.has_animation(anim) else "idle"
	_anim = anim
	if _player.current_animation == real and _player.is_playing():
		return
	_player.play(real)
	_player.seek(0.0, true)


## The animation asked for last.
func animation() -> String:
	return _anim


func has_animation(anim: String) -> bool:
	return _player.has_animation(anim)


## The bone `bone_name` (tests).
func bone(bone_name: String) -> Bone2D:
	return _bones.get(bone_name)


## The skinned mesh.
func mesh() -> Polygon2D:
	return _mesh


## Multiplies the picture's colour (hurt flash, knocked-out grey).
func set_tint(c: Color) -> void:
	_mesh.self_modulate = c


func advance(delta: float) -> void:
	_player.advance(delta)


func _process(delta: float) -> void:
	advance(delta)
