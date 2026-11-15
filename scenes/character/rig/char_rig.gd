@tool
extends Node2D
## A character drawn on its bone rig: Rookie, Spark, Tanko, Flora and Tide in a match (scenes/character/character.gd
## match_rig, set by match/views/player_view.gd; everywhere else the old art), their carry scenes
## (scenes/character/poses/carry_rig.gd) and the dev preview scenes/dev/rig_preview.tscn. Its parts
## (assets/characters/<id>/rig/: the standing picture cut along its outlines, the hidden areas
## painted) ride a Skeleton2D's Bone2Ds, posed every frame by the motion (rig_motion.gd: idle
## breathing, gun raised / aimed / fired, hurt, walking, dying) through the rig's solver
## (rig_model.gd: IK arms on the gun's grips, IK legs with the feet planted). The gun (its hug art,
## assets/weapons/<kind>/hug_<tier>.png with hug.json's hold / muzzle) is drawn under the near fist
## (rig.json gunUnder): the far arm behind it (holding the tube from behind), the body and the head
## under it (aiming high the tube covers the face), only the near arm over it. While it is down it is
## slung across the back (behind the body, riding the torso; rig_model.gd back / set_back(), from the
## carry scene), and raising swings it off the shoulder into the grips (drawn behind the body until
## rig_model.gd SWAP_FRONT, then in the hands' layer). Dead: it fades out. set_gun() swaps the gun
## (any kind: ui/art.gd hug_gun()'s art, every kind the same length). The parts and the gun are drawn
## mipmapped (a ~380 px rig shown ~70 px tall).
## The bones move only for the gun (drawn and aimed, the shot's recoil), hurt and death: standing is the
## picture itself (breathing), and walking moves no bone (the user's call): it plays the run frames
## (assets/characters/<id>/rig/run.json, written by art_source/characters/make_run_frames.py) over the
## slung gun, or without them the standing picture lifting with each step.
## Feet at this node's origin, facing +x; rig px (set `scale` for the size: rig height() px tall at
## scale 1). advance() (or _process when `auto`) steps it; muzzle_position() is the gun's tip here,
## fire_muzzle_position() where it is once raised at the aim the motion turns to.

const RigModel := preload("res://scenes/character/rig/rig_model.gd")
const RigMotion := preload("res://scenes/character/rig/rig_motion.gd")

const HUG_DATA := "res://assets/weapons/hug.json"
const FLASH_TINT := Color(1.0, 0.9, 0.55)
## The muzzle flash's size (about the side view's muzzle sprite at the match size).
const FLASH_SIZE := 2.5
## The run frames' rate when run.json gives none.
const RUN_FPS := 12.0
## A hit while running shows the rig's hurt (bones) this long before the frames come back.
const RUN_HURT_SEC := 0.6

var character_id := "rookie"
var gun_kind := "bazooka"
var gun_tier := "iron"
## The gun's art instead of gun_kind / gun_tier's hug art: {texture, pivot (its hold), muzzle, size}
## (ui/art.gd hug_gun()); set before setup(), later set_gun().
var gun_art := {}
## Draws the gun (off: hands free).
var show_gun := true
## Steps itself in _process (off: the owner calls advance()).
var auto := true
## Holds the rest pose (rig_model.gd solve({}): no breathing; the carry scene's Body), not the motion.
var still := false
## Draws the bones, the grips and the hands over the figure.
var debug := false:
	set(v):
		debug = v
		if _overlay != null:
			_overlay.queue_redraw()

var model: RigModel
var motion := RigMotion.new()
var pose := {} # the last solve
var sample := {} # the last motion sample (rig_motion.gd sample())
var _figure: Node2D
var _skeleton: Skeleton2D
var _bones := {} # name -> Bone2D
var _sprites := {} # part name -> Sprite2D
var _gun: Sprite2D
var _back_gun: Sprite2D
var _flash: Node2D
var _overlay: Node2D
var _run_sprite: Sprite2D
## The run frames: {frames: [Texture2D], xf: [Transform2D] (image px -> rig px), bob: [float] (rig px the
## torso sits lower than standing: the slung gun follows it), fps}; empty: no frames.
var run := {}
var _run_time := 0.0
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
	var meta := _gun_meta()
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
	var gun_tex := _gun_texture()
	_back_gun = _sprite("BackGun", gun_tex)
	parts.add_child(_back_gun)
	_run_sprite = _sprite("Run", null)
	_run_sprite.visible = false
	parts.add_child(_run_sprite) # over the slung gun, under every part
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
	load_run(dir)
	refresh()
	return true


## Is there a rig for this character (assets/characters/<id>/rig/rig.json)?
static func available(id: String) -> bool:
	return id != "" and FileAccess.file_exists("res://assets/characters/%s/rig/rig.json" % id)


## The gun's {size, hold, muzzle}: gun_art's, else hug.json's entry of gun_kind / gun_tier.
func _gun_meta() -> Dictionary:
	if not gun_art.is_empty():
		return {"size": gun_art.get("size"), "hold": gun_art.get("pivot"), "muzzle": gun_art.get("muzzle")}
	var hug = JSON.parse_string(FileAccess.get_file_as_string(HUG_DATA))
	if hug is Dictionary and hug.get("guns") is Dictionary and hug["guns"].get(gun_kind) is Dictionary:
		return hug["guns"][gun_kind].get(gun_tier, {})
	return {}


func _gun_texture() -> Texture2D:
	if gun_art.get("texture") is Texture2D:
		return mipmapped(gun_art["texture"])
	return texture("res://assets/weapons/%s/hug_%s.png" % [gun_kind, gun_tier])


## Swaps the gun for `art` (ui/art.gd hug_gun(): {texture, pivot, muzzle, size}).
func set_gun(art: Dictionary) -> void:
	gun_art = art
	if model == null:
		return
	model.set_gun(_gun_meta())
	var tex := _gun_texture()
	_gun.texture = tex
	_back_gun.texture = tex
	refresh()


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
		tex = mipmapped(load(path))
	if tex == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	_textures[path] = tex
	return tex


static var _mipmapped := {} # texture -> its mipmapped copy
## tex with mipmaps (a copy made once when its import has none), so it shrinks smoothly.
static func mipmapped(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _mipmapped.has(tex):
		return _mipmapped[tex]
	var out := tex
	var img := tex.get_image()
	if img != null and not img.is_empty() and not img.has_mipmaps():
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		out = ImageTexture.create_from_image(img)
	_mipmapped[tex] = out
	return out


func _process(delta: float) -> void:
	if auto and model != null and not Engine.is_editor_hint():
		advance(delta)


func advance(delta: float) -> void:
	motion.advance(delta)
	_run_time = _run_time + delta if motion.walk > 0.0 else 0.0
	refresh()


## Reads the run frames (dir/run.json: {frames: [png paths relative to dir], xf: [[x.x, x.y, y.x, y.y,
## origin x, origin y]] image px -> rig px, bob: [rig px], fps}); none: the run stays the standing picture.
func load_run(dir: String) -> void:
	var path := dir + "/run.json"
	if not FileAccess.file_exists(path):
		set_run([], [], [], 0.0)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		set_run([], [], [], 0.0)
		return
	var frames := []
	var xfs := []
	for i in (data.get("frames", []) as Array).size():
		frames.append(texture(dir + "/" + str(data["frames"][i])))
		var v: Array = data["xf"][i] if i < (data.get("xf", []) as Array).size() else [1, 0, 0, 1, 0, 0]
		xfs.append(Transform2D(Vector2(v[0], v[1]), Vector2(v[2], v[3]), Vector2(v[4], v[5])))
	set_run(frames, xfs, data.get("bob", []), float(data.get("fps", RUN_FPS)))


## The run frames (textures, their image px -> rig px transforms, the torso's drop per frame, the rate);
## empty frames: walking shows the standing picture lifting with each step.
func set_run(frames: Array, xfs: Array, bob: Array, fps: float) -> void:
	var ok := not frames.is_empty() and xfs.size() == frames.size() and not frames.has(null)
	run = {"frames": frames, "xf": xfs, "bob": bob, "fps": fps if fps > 0.0 else RUN_FPS} if ok else {}
	if _flash != null:
		refresh()


func has_run_frames() -> bool:
	return not run.is_empty()


## The run frames are drawn now (walking, the gun on the back, not hit just now, alive) instead of the parts;
## off the frame set_walking(false) comes (the blend out is the standing picture's).
func run_frames_shown() -> bool:
	return has_run_frames() and not still and motion.walk >= 0.5 and motion.walk_target > 0.0 and motion.raised <= 0.0 \
		and not motion.is_dead() and motion.hurt_age >= RUN_HURT_SEC


## The run frame shown now (its index in run.frames).
func run_frame() -> int:
	var n: int = (run.get("frames", []) as Array).size()
	return int(_run_time * float(run.get("fps", RUN_FPS))) % n if n > 0 else 0


## Poses the nodes for the motion now.
func refresh() -> void:
	if model == null:
		return
	var s := {"raise": 0.0} if still else motion.sample()
	if has_run_frames():
		s["lift"] = 0.0 # the frames run on their own
	sample = s
	pose = model.solve(s)
	var g: Dictionary = pose["bones"]
	_figure.transform = pose["figure"]
	for nm in model.bone_names:
		var par: String = model.parent[nm]
		_bones[nm].transform = (g[par].affine_inverse() * g[nm]) if par != "" else g[nm]
	for p in model.parts:
		_sprites[p["name"]].transform = model.part_transform(g, p)
	# one gun: behind the body on the back sling and on the way off it, in the hands' layer once up
	var front: bool = pose["gun_front"]
	var alpha: float = pose["gun_alpha"]
	for sp in [_gun, _back_gun]:
		sp.transform = pose["gun"]
		sp.modulate.a = alpha
	_gun.visible = show_gun and front and alpha > 0.0
	_back_gun.visible = show_gun and not front and alpha > 0.0
	# walking: the run frame over the slung gun (riding the frame's torso), the parts hidden
	var frames_on := run_frames_shown()
	for p in model.parts:
		_sprites[p["name"]].visible = not frames_on
	_run_sprite.visible = frames_on
	if frames_on:
		var i := run_frame()
		_run_sprite.texture = run["frames"][i]
		_run_sprite.transform = run["xf"][i]
		var bob: Array = run["bob"]
		_back_gun.transform = Transform2D(0.0, Vector2(0.0, float(bob[i]) if i < bob.size() else 0.0)) * pose["gun"]
	_place_gun()
	_flash.queue_redraw()
	if debug:
		_overlay.queue_redraw()


## The gun in the parts' order: right under rig.json's gunUnder part (the near fist): over the far
## arm (upper arm, forearm and fist: it holds the tube from behind), the body and the head (aiming
## high the tube covers the face), under the near arm (fist, forearm, upper arm) that hugs it.
func _place_gun() -> void:
	var parts := _gun.get_parent()
	var under: Node = _sprites.get(model.gun_under)
	if under == null:
		return
	var at := under.get_index()
	if _gun.get_index() < at:
		at -= 1
	if _gun.get_index() != at:
		parts.move_child(_gun, at)


## The gun is drawn slung on the back (behind the body) now.
func back_gun_shown() -> bool:
	return _back_gun.visible


## The gun is drawn in the hands' layer now (raised, or most of the way up).
func hand_gun_shown() -> bool:
	return _gun.visible


## The gun's axis now, degrees above level towards the facing side (over 90: pointing back, as on the
## sling and swinging off it).
func gun_elevation() -> float:
	var d: Vector2 = pose.get("dir", Vector2.RIGHT)
	return -rad_to_deg(d.angle())


## The head is drawn over the gun now (never: the tube is over the head at every aim, covering the
## face aiming high).
func head_over_gun() -> bool:
	return _sprites.has("head") and _sprites["head"].get_index() > _gun.get_index()


## The figure's height (rig px).
func height() -> float:
	return model.height if model != null else 0.0


## The gun's tip, in this node's px.
func muzzle_position() -> Vector2:
	return pose.get("muzzle", Vector2.ZERO)


## Where the gun's tip will be once raised all the way at the aim the motion turns to (its target),
## at the shot's first instant (no kick yet), in this node's px: where a shot leaves.
func fire_muzzle_position() -> Vector2:
	if model == null:
		return Vector2.ZERO
	var m := RigMotion.new()
	m.time = motion.time + motion.raise_left() # when it leaves (the gun up)
	m.aim = motion.aim_target
	m.aim_target = motion.aim_target
	m.raised = 1.0
	m.raise_target = 1.0
	m.shot_age = 0.0
	m.hurt_age = motion.hurt_age + motion.raise_left()
	return model.solve(m.sample())["muzzle"]


## Seconds until the gun is all the way up when raised from where it is now (fast: a shot fired
## with the gun down, RigMotion fastRaiseSec).
func raise_left(fast: bool = false) -> float:
	return motion.raise_left(fast)


func _draw_flash() -> void:
	var f := float(pose.get("flash", 0.0))
	if f <= 0.0:
		return
	var tip: Vector2 = pose["gun"] * model.gun["muzzle"]
	var dir: Vector2 = pose["dir"]
	var n := dir.orthogonal()
	var k := FLASH_SIZE
	var ln := 34.0 * k * (0.6 + 0.4 * f)
	var w := 13.0 * k * f
	_flash.draw_colored_polygon(PackedVector2Array([tip - n * w, tip + dir * ln, tip + n * w, tip + dir * 6.0 * k]),
			Color(FLASH_TINT, 0.9 * f))
	_flash.draw_circle(tip + dir * 5.0 * k, 9.0 * k * f, Color(1, 1, 0.9, f))


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
