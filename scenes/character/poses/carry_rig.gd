@tool
extends Node2D
## The bone rig of a rigged character's carry scene (scenes/character/poses/<id>_carry.tscn,
## scenes/character/rig/char_rig.gd), live in the editor: the rig drawn at the match's scale (the side
## view's art height, feet at this node's origin, facing right), its back sling and gun length read
## every frame from the sibling CarrySocket and its Preview (RigModel.sling(), what the match uses:
## character.gd rig_back()), so dragging / turning / scaling them shows at once what the match draws.
##   rest  the Body: the rig standing in its rest pose without its gun (the Preview is the slung gun,
##         drawn behind it)
##   held  the HeldPreview: the rig holding the gun at each of `aims` (degrees up), `spacing` px apart:
##         the Preview's scale is the held gun's length too
##   walk  the WalkPreview: the rig walking in place with the gun slung
## Nothing here is saved (the rigs are internal children); in the game it draws nothing (ui/art.gd
## carry_pose() reads only CarrySocket and its Preview) unless `always` (tests, preview pictures).

const Art := preload("res://ui/art.gd")
const CharRig := preload("res://scenes/character/rig/char_rig.gd")
const RigModel := preload("res://scenes/character/rig/rig_model.gd")

@export var character_id := "rookie":
	set(v):
		character_id = v
		_dirty = true
@export_enum("rest", "held", "walk") var mode := "rest":
	set(v):
		mode = v
		_dirty = true
@export var aims: Array = [0.0, 45.0, 90.0]:
	set(v):
		aims = v
		_dirty = true
@export var spacing := 300.0
## Draw outside the editor too (tests, preview pictures).
var always := false:
	set(v):
		always = v
		set_process(_active())
		_dirty = true

var rigs: Array = []
var _dirty := true
var _tex: Texture2D


func _ready() -> void:
	set_process(_active())
	if _active():
		build()


func _active() -> bool:
	return Engine.is_editor_hint() or always


func _process(delta: float) -> void:
	var pv := _preview()
	if _dirty or (pv != null and pv.texture != _tex):
		build()
	sync(delta)


## Makes the rigs (none without a rig for character_id).
func build() -> void:
	_dirty = false
	for r in rigs:
		remove_child(r)
		r.free()
	rigs.clear()
	var pv := _preview()
	_tex = pv.texture if pv != null else null
	if not CharRig.available(character_id):
		return
	var n := aims.size() if mode == "held" else 1
	for i in n:
		var r := CharRig.new()
		r.name = "Rig%d" % i
		r.character_id = character_id
		r.auto = false
		r.gun_art = _gun_art()
		if not r.setup():
			r.free()
			continue
		match mode:
			"rest":
				r.still = true
				r.show_gun = false
			"held":
				var deg := float(aims[i])
				r.motion.raised = 1.0
				r.motion.raise_target = 1.0
				r.motion.aim = deg
				r.motion.aim_target = deg
				r.position.x = i * spacing
			"walk":
				r.motion.set_walking(true)
				r.motion.walk = 1.0
		add_child(r)
		rigs.append(r)
	sync(0.0)


## The sling and the gun's length from the sibling CarrySocket / Preview now, on every rig.
func sync(delta: float) -> void:
	if rigs.is_empty():
		return
	var h: float = rigs[0].height()
	var top := art_height()
	if h <= 0.0 or top <= 0.0:
		return
	var s := sling(h / top)
	for r in rigs:
		r.scale = Vector2.ONE * (top / h)
		if not s.is_empty():
			r.model.set_back(s["pos"], s["deg"], s["frac"], s["lift"], s["length"])
		if mode == "walk":
			r.advance(delta)
		else:
			r.refresh()


## The side view's art height (character px): the match draws the rig that tall.
func art_height() -> float:
	var look: Dictionary = Art.character_look(character_id)
	return float(look["extent"]["top"]) * float(look["scale"])


## RigModel.sling() of the sibling CarrySocket / Preview at k rig px per scene px ({}: none).
func sling(k: float) -> Dictionary:
	var pv := _preview()
	if pv == null:
		return {}
	var meta := _meta(pv.texture)
	if meta.is_empty():
		return {}
	var size: Vector2 = meta["size"]
	var corner := -size * 0.5 if pv.centered else Vector2.ZERO
	var preview := pv.transform * Transform2D(0.0, pv.offset + corner)
	var sock: Node2D = pv.get_parent()
	return RigModel.sling(sock.transform, preview, size, float(meta["pivot"].y), k)


func _preview() -> Sprite2D:
	var sock: Node2D = get_parent().get_node_or_null("CarrySocket") as Node2D if get_parent() != null else null
	return sock.get_node_or_null("Preview") as Sprite2D if sock != null else null


## The Preview gun's {size, pivot (its hold), muzzle}: its hug.json entry, else its picture's middle row.
func _meta(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {}
	var meta := Art.pose_gun_meta(tex.resource_path)
	if meta.is_empty():
		var size := tex.get_size()
		meta = {"size": size, "pivot": size * 0.5, "muzzle": Vector2(size.x, size.y * 0.5)}
	return meta


## The rigs' gun: the Preview's picture (else the rig's default hug gun).
func _gun_art() -> Dictionary:
	var pv := _preview()
	if pv == null or pv.texture == null:
		return {}
	var meta := _meta(pv.texture)
	return {"texture": pv.texture, "pivot": meta["pivot"], "muzzle": meta["muzzle"], "size": meta["size"]}
