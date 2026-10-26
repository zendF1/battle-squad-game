@tool
extends Node2D
## The WalkPreview of a carry scene (scenes/character/poses/<id>_carry.tscn), editor only: beside
## the character it plays the walk with the gun slung as the match draws it: each walk frame (the
## side view's walk frames, side.json) and the sibling CarrySocket's Preview moved by that frame's
## bob and sway (carry.json back.bob, ui/art.gd carry_walk_transform()), behind the body. It follows
## the socket live while it is dragged / turned / scaled; nothing here is saved or edited (no
## child nodes). `fps` is slower than the match so each frame can be seen; `playing` off holds
## `frame`. Anything missing (a frame or the gun not imported yet, no side.json / carry.json)
## just leaves that part out. In the game it draws nothing (ui/art.gd carry_pose() reads only
## CarrySocket and its Preview).

const Art := preload("res://ui/art.gd")

@export var character_id := "rookie"
@export var fps := 6.0
@export var playing := true
@export var frame := 0
## Draw outside the editor too (tests, preview pictures).
var always := false

var _time := 0.0
var _wait := 0.0
var _walk := {} # {stems, pivot, k, bob} read from side.json / carry.json
var _textures := {} # path -> Texture2D (imported frames only)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(Engine.is_editor_hint())


func _process(delta: float) -> void:
	_time += delta
	_wait -= delta
	if _wait <= 0.0: # the frames / bob may change on disk (tools/carry_bob.gd)
		_wait = 1.0
		_walk = {}
	queue_redraw()


## The walk frame shown now.
func shown_frame() -> int:
	var n: int = walk().get("stems", []).size()
	if n == 0:
		return 0
	return posmod(int(_time * fps) if playing else frame, n)


## {stems (walk frame PNG stems), dir, pivot (texture px), k (character px per texture px), bob
## (carry.json back.bob, Array of Vector2)}; {} without a side view.
func walk() -> Dictionary:
	if not _walk.is_empty():
		return _walk
	var dir := Art.side_dir(Art.known_character(character_id))
	if not FileAccess.file_exists(dir + "side.json"):
		return {}
	var side = JSON.parse_string(FileAccess.get_file_as_string(dir + "side.json"))
	if not side is Dictionary or float(side.get("pxPerUnit", 0.0)) <= 0.0 or not side.get("pivot") is Array:
		return {}
	var spec = side.get("anims", {}).get("walk") if side.get("anims") is Dictionary else null
	var stems: Array = spec.get("frames", []) if spec is Dictionary and spec.get("frames") is Array else []
	var bob: Array = Art.parse_carry(dir + "carry.json").get("back", {}).get("bob", [])
	_walk = {"stems": stems, "dir": dir, "pivot": Vector2(float(side["pivot"][0]), float(side["pivot"][1])),
		"k": Art.PX_PER_UNIT / float(side["pxPerUnit"]), "bob": bob}
	return _walk


## The sibling CarrySocket's Preview gun on walk frame i: its texture px → this node's px (the
## match's walk carry: the socket moved by the frame's bob and swayed); null transform when there
## is no socket / Preview.
func gun_transform(i: int) -> Variant:
	var sock: Node2D = get_parent().get_node_or_null("CarrySocket") as Node2D if get_parent() != null else null
	var pv: Sprite2D = sock.get_node_or_null("Preview") as Sprite2D if sock != null else null
	var w := walk()
	if pv == null or w.is_empty():
		return null
	var corner := Vector2.ZERO
	if pv.centered and pv.texture != null:
		corner = -pv.texture.get_size() * 0.5
	return Art.carry_walk_transform(sock.transform, w["bob"], i, w["k"]) * pv.transform * Transform2D(0.0, pv.offset + corner)


func _draw() -> void:
	if not (Engine.is_editor_hint() or always):
		return
	var w := walk()
	if w.is_empty() or (w["stems"] as Array).is_empty():
		return
	var i := shown_frame()
	var pv: Sprite2D = get_parent().get_node_or_null("CarrySocket/Preview") as Sprite2D if get_parent() != null else null
	var gx = gun_transform(i)
	if pv != null and pv.texture != null and gx is Transform2D: # behind the body, as in the match
		draw_set_transform_matrix(gx)
		draw_texture(pv.texture, Vector2.ZERO)
	var body := _texture(str(w["dir"]) + str(w["stems"][i]) + ".png")
	if body != null:
		draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE * float(w["k"]), 0.0, Vector2.ZERO) * Transform2D(0.0, -w["pivot"]))
		draw_texture(body, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D())
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(-70, 26), "walk %d/%d (chỉ xem)" % [i + 1, (w["stems"] as Array).size()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.85))


## A walk frame once the editor has imported it (outside the editor: read like the match).
func _texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var t: Texture2D = null
	if Engine.is_editor_hint():
		if FileAccess.file_exists(path + ".import") and FileAccess.get_file_as_string(path + ".import").contains("\npath") \
				and ResourceLoader.exists(path):
			var r = load(path)
			t = r if r is Texture2D else null
	elif Art.has_png(path):
		t = Art.texture(path)
	if t != null:
		_textures[path] = t
	return t
