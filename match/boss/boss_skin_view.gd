extends Node2D
## A boss's skinned idle (ui/art.gd boss_skin(): the Ice Witch's portrait on a skeleton, made by
## tools/import_boss_frames.gd): the lobby characters' skinning, reused as is (a FullBody,
## scenes/character/full_body.gd: the Polygon2D mesh on Bone2Ds, the AnimationPlayer playing the
## idle tracks of skin.json, match/boss/skin_idle.gd's motion), plus what moves on its own over it:
## the orbiting ice shards (their own sprites, drifting on small ellipses round their rest places,
## SkinIdle.shard()) and the staff crystal's pulsing glow (it follows the staff bone). The feet (the
## frost-mist hem's bottom centre) at this node's origin, picture px; the owner scales, mirrors and
## floats it (SkinIdle.hover()). advance() moves it on (not processed by itself). debug draws the
## deformed mesh and the bones over it.
## A glide skin (skin.json motion "glide": her side view, the fly) is posed by a SkinFly.Glide
## instead of its AnimationPlayer: glide(delta, flying) steps it and sets the bones (the stream and
## the ripple), the lean (the body turned round its middle) and the shards' trail.

const FullBody := preload("res://scenes/character/full_body.gd")
const SkinIdle := preload("res://match/boss/skin_idle.gd")
const SkinFly := preload("res://match/boss/skin_fly.gd")

const GLOW_COLOUR := Color(0.62, 0.95, 1.0)
const GLOW_R := 0.075 # of the height

var skin := {}
var debug := false:
	set(v):
		debug = v
		if _fx != null:
			_fx.queue_redraw()
var _body: Node2D # FullBody
var _fx: Node2D
var _t := 0.0
var glide_state: SkinFly.Glide # the glide's state (motion "glide"), null for the idle
static var _halo: GradientTexture2D


func setup(data: Dictionary) -> void:
	skin = data
	_body = FullBody.new()
	_body.name = "Body"
	add_child(_body)
	_body.setup(data)
	_body.set_process(false) # advance() drives it
	_body.mesh().texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS # drawn smaller than it is
	if str(data.get("motion", "idle")) == "glide":
		glide_state = SkinFly.Glide.new()
	_fx = Node2D.new()
	_fx.name = "Shards"
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func advance(delta: float) -> void:
	_t += delta
	if glide_state != null:
		_pose_glide()
	else:
		_body.advance(delta)
	_fx.queue_redraw()


## A glide skin: steps its Glide (flying or settling) and poses it; then advance() as for the idle.
func glide(delta: float, flying: bool) -> void:
	if glide_state != null:
		glide_state.step(delta, flying)
	advance(delta)


## The glide's bones, lean and (via _draw_fx) shards now.
func _pose_glide() -> void:
	var g := glide_state
	for b in skin.get("bones", []):
		var node: Node2D = _body.bone(str(b["name"]))
		if node == null:
			continue
		node.rotation = float(node.get_meta("rest_rot")) + deg_to_rad(float(g.bone(str(b["name"]))["rot"]))
	var lean := deg_to_rad(g.lean())
	var c := Vector2(0, -height() * 0.5) # she leans round her middle
	_body.rotation = lean
	_body.position = c - c.rotated(lean)


## Seconds into the idle.
func time() -> float:
	return _t


func height() -> float:
	return float(skin.get("height", 1.0))


## The mesh and the shards drawn through m (the boss's shader: hit flash, icy tint).
func set_shader_material(m: Material) -> void:
	_body.mesh().material = m
	_fx.material = m


func full_body() -> Node2D:
	return _body


## Shard i's centre now (px from the feet).
func shard_centre(i: int) -> Vector2:
	var s: Dictionary = skin["shards"][i]
	var rest: Vector2 = Vector2(s["at"]) + Vector2(s["size"]) / 2.0 - Vector2(skin["pivot"])
	return _body.transform * rest + Vector2(_shard_pose(i)["offset"]) * height()


func _shard_pose(i: int) -> Dictionary:
	return glide_state.shard(i) if glide_state != null else SkinIdle.shard(i, _t)


## Where the staff crystal is now (px from the feet), carried by the staff bone.
func crystal() -> Vector2:
	var glow: Vector2 = skin.get("glow", Vector2.ZERO)
	var b: Node2D = _body.bone("staff")
	if b == null:
		return glow - Vector2(skin["pivot"])
	return _to_self(b) * (glow - _rest_at("staff"))


## A bone's joint at rest (picture px).
func _rest_at(bone_name: String) -> Vector2:
	for b in skin.get("bones", []):
		if str(b["name"]) == bone_name:
			return b["at"]
	return Vector2.ZERO


## n's transform into this node (built by hand: it may not be in the tree).
func _to_self(n: Node) -> Transform2D:
	var t := Transform2D.IDENTITY
	while n != null and n != self:
		if n is Node2D:
			t = (n as Node2D).transform * t
		n = n.get_parent()
	return t


func _draw_fx() -> void:
	var h := height()
	var g := SkinIdle.glow(_t)
	var r := h * GLOW_R * (0.85 + 0.3 * g)
	var at := crystal()
	_fx.draw_texture_rect(halo(), Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(GLOW_COLOUR, 0.25 + 0.4 * g))
	for i in skin.get("shards", []).size():
		var s: Dictionary = skin["shards"][i]
		var pose := _shard_pose(i)
		var size: Vector2 = s["size"]
		_fx.draw_set_transform(shard_centre(i), float(pose["rot"]) + _body.rotation, Vector2.ONE * float(pose["scale"]))
		_fx.draw_texture_rect(s["texture"], Rect2(-size / 2.0, size), false)
	_fx.draw_set_transform(Vector2.ZERO)
	if debug:
		_draw_debug()


## The mesh as the bones bend it now (the skinning done here: Σ w · bone now · bone at rest⁻¹) and
## the bones (joint → tip).
func _draw_debug() -> void:
	var bones: Array = skin["bones"]
	var mats: Array = []
	var offset: Transform2D = _to_self(_body.mesh()) # the mesh's space (the Body node) into this one
	for b in bones:
		var node: Node2D = _body.bone(str(b["name"]))
		mats.append(_to_self(node) * Transform2D(0.0, -Vector2(b["at"])))
	var verts: PackedVector2Array = skin["vertices"]
	var moved := PackedVector2Array()
	moved.resize(verts.size())
	for vi in verts.size():
		var p := Vector2.ZERO
		var total := 0.0
		for bi in bones.size():
			var w: float = skin["weights"][bi][vi]
			if w > 0.0:
				p += (mats[bi] as Transform2D) * verts[vi] * w
				total += w
		moved[vi] = p / total if total > 0.0 else offset * verts[vi]
	for tri in skin["polygons"]:
		var pts := PackedVector2Array([moved[tri[0]], moved[tri[1]], moved[tri[2]], moved[tri[0]]])
		_fx.draw_polyline(pts, Color(1.0, 0.25, 0.6, 0.55), 1.0)
	for b in bones:
		var node: Node2D = _body.bone(str(b["name"]))
		var a: Vector2 = _to_self(node) * Vector2.ZERO
		var tip: Vector2 = _to_self(node) * (Vector2(b["tip"]) - Vector2(b["at"]))
		_fx.draw_line(a, tip, Color(1, 0.9, 0.1), 3.0)
		_fx.draw_circle(a, 5.0, Color(0.1, 1.0, 0.4))


static func halo() -> GradientTexture2D:
	if _halo == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_halo = GradientTexture2D.new()
		_halo.gradient = g
		_halo.fill = GradientTexture2D.FILL_RADIAL
		_halo.fill_from = Vector2(0.5, 0.5)
		_halo.fill_to = Vector2(1.0, 0.5)
		_halo.width = 64
		_halo.height = 64
	return _halo
