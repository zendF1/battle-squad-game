extends Node2D
## A character drawn on its bone rig (TEST: only the dev preview scenes/dev/rig_preview.tscn uses it;
## matches keep scenes/character/character.gd). Its parts (assets/characters/<id>/rig/: the
## standing picture cut along its outlines, the hidden areas painted) ride a Skeleton2D's Bone2Ds,
## posed every frame by the motion (rig_motion.gd: idle breathing, gun raised / aimed / fired, hurt,
## walking, dying) through the rig's solver (rig_model.gd: IK arms on the gun's grips, IK legs with the
## feet planted). The gun (its hug art, assets/weapons/<kind>/hug_<tier>.png with hug.json's hold /
## muzzle) is drawn under the far fist (rig.json gunUnder) so the far hand wraps the tube, the near
## arm over it; a second copy is slung across the back while the gun is down.
## Feet at this node's origin, facing +x; rig px (set `scale` for the size: rig height() px tall at
## scale 1). advance() (or _process when `auto`) steps it; muzzle_position() is the gun's tip here.

const RigModel := preload("res://scenes/character/rig/rig_model.gd")
const RigMotion := preload("res://scenes/character/rig/rig_motion.gd")

const HUG_DATA := "res://assets/weapons/hug.json"
const FLASH_TINT := Color(1.0, 0.9, 0.55)

var character_id := "rookie"
var gun_kind := "bazooka"
var gun_tier := "iron"
## Steps itself in _process (off: the owner calls advance()).
var auto := true
## Draws the bones, the grips and the hands over the figure.
var debug := false:
	set(v):
		debug = v
		if _overlay != null:
			_overlay.queue_redraw()

var model: RigModel
var motion := RigMotion.new()
var pose := {} # the last solve
var _figure: Node2D
var _skeleton: Skeleton2D
var _bones := {} # name -> Bone2D
var _sprites := {} # part name -> Sprite2D
var _gun: Sprite2D
var _back_gun: Sprite2D
var _flash: Node2D
var _overlay: Node2D
static var _textures := {}


func _ready() -> void:
	if model == null:
		setup()


## Loads the rig and builds the nodes. False when the rig is missing.
func setup() -> bool:
	var dir := "res://assets/characters/%s/rig" % character_id
	var data = JSON.parse_string(FileAccess.get_file_as_string(dir + "/rig.json"))
	if not data is Dictionary:
		return false
	var hug = JSON.parse_string(FileAccess.get_file_as_string(HUG_DATA))
	var meta := {}
	if hug is Dictionary and hug.get("guns") is Dictionary:
		meta = hug["guns"].get(gun_kind, {}).get(gun_tier, {})
	model = RigModel.new()
	if not model.setup(data, meta):
		model = null
		return false
	_figure = Node2D.new()
	_figure.name = "Figure"
	add_child(_figure)
	_skeleton = Skeleton2D.new()
	_skeleton.name = "Skeleton"
	_figure.add_child(_skeleton)
	for nm in model.bone_names:
		var b := Bone2D.new()
		b.name = nm
		var par: String = model.parent[nm]
		var local: Vector2 = model.rest[nm] - (model.rest[par] if par != "" else Vector2.ZERO)
		b.rest = Transform2D(0.0, local)
		b.transform = b.rest
		b.set_autocalculate_length_and_angle(false)
		b.set_length(6.0)
		(_bones[par] if par != "" else _skeleton).add_child(b)
		_bones[nm] = b
	var parts := Node2D.new()
	parts.name = "Parts"
	_figure.add_child(parts)
	var gun_tex := texture("res://assets/weapons/%s/hug_%s.png" % [gun_kind, gun_tier])
	_back_gun = _sprite("BackGun", gun_tex)
	parts.add_child(_back_gun)
	for p in model.parts:
		if p["name"] == model.gun_under:
			_gun = _sprite("Gun", gun_tex)
			parts.add_child(_gun)
		var s := _sprite(p["name"], texture(dir + "/" + p["png"]))
		parts.add_child(s)
		_sprites[p["name"]] = s
	if _gun == null:
		_gun = _sprite("Gun", gun_tex)
		parts.add_child(_gun)
	_flash = Node2D.new()
	_flash.name = "Flash"
	_flash.draw.connect(_draw_flash)
	_figure.add_child(_flash)
	_overlay = Node2D.new()
	_overlay.name = "Debug"
	_overlay.draw.connect(_draw_debug)
	_figure.add_child(_overlay)
	refresh()
	return true


func _sprite(nm: String, tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = nm
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


## A picture: the imported texture, else the PNG read from disk (a dev rig not imported yet), mipmapped.
static func texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	if tex == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	_textures[path] = tex
	return tex


func _process(delta: float) -> void:
	if auto and model != null:
		advance(delta)


func advance(delta: float) -> void:
	motion.advance(delta)
	refresh()


## Poses the nodes for the motion now.
func refresh() -> void:
	if model == null:
		return
	pose = model.solve(motion.sample())
	var g: Dictionary = pose["bones"]
	_figure.transform = pose["figure"]
	for nm in model.bone_names:
		var par: String = model.parent[nm]
		_bones[nm].transform = (g[par].affine_inverse() * g[nm]) if par != "" else g[nm]
	for p in model.parts:
		_sprites[p["name"]].transform = model.part_transform(g, p)
	_gun.transform = pose["gun"]
	_gun.modulate.a = pose["gun_alpha"]
	_gun.visible = pose["gun_alpha"] > 0.0
	_back_gun.transform = pose["back_gun"]
	_back_gun.modulate.a = pose["back_alpha"]
	_back_gun.visible = pose["back_alpha"] > 0.0
	_flash.queue_redraw()
	if debug:
		_overlay.queue_redraw()


## The figure's height (rig px).
func height() -> float:
	return model.height if model != null else 0.0


## The gun's tip, in this node's px.
func muzzle_position() -> Vector2:
	return pose.get("muzzle", Vector2.ZERO)


func _draw_flash() -> void:
	var f := float(pose.get("flash", 0.0))
	if f <= 0.0:
		return
	var tip: Vector2 = pose["gun"] * model.gun["muzzle"]
	var dir: Vector2 = pose["dir"]
	var n := dir.orthogonal()
	var ln := 34.0 * (0.6 + 0.4 * f)
	var w := 13.0 * f
	_flash.draw_colored_polygon(PackedVector2Array([tip - n * w, tip + dir * ln, tip + n * w, tip + dir * 6.0]),
			Color(FLASH_TINT, 0.9 * f))
	_flash.draw_circle(tip + dir * 5.0, 9.0 * f, Color(1, 1, 0.9, f))


func _draw_debug() -> void:
	if not debug or pose.is_empty():
		return
	var g: Dictionary = pose["bones"]
	for nm in model.bone_names:
		var par: String = model.parent[nm]
		if par != "":
			_overlay.draw_line(g[par].origin, g[nm].origin, Color(1, 0.2, 0.6), 1.5)
		_overlay.draw_circle(g[nm].origin, 2.5, Color(1, 1, 0.2))
	for p in pose["grips"]:
		_overlay.draw_circle(p, 3.0, Color(0.2, 1, 0.4))
