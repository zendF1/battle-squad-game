@tool
extends Sprite2D
## The Body of a pose scene (scenes/character/poses/<id>_ready.tscn), editor only: it shows the
## character's ready frame where the match draws it (the feet on the scene's origin, at the
## match's scale), so the gun can be placed on it by hand. Its picture follows the art with no
## edit: the side view's ready frame (assets/characters/<id>/side/, side.json "draw", written by
## tools/import_frames.gd) once it is imported, else the baked idle frame as a stand-in. Checked
## when the scene opens and every second while it is open. Hand* sprites of the scene that have no
## picture yet get the side view's ready hands where they were drawn (side.json readyPose.hands),
## so they show up after an import; a hand with a picture is never touched (placed by hand).
## In the game it does nothing (ui/art.gd ready_pose() reads only GunSocket and Hand*; the root's
## aim_down / aim_up metadata is no longer read).

const Art := preload("res://ui/art.gd")

@export var character_id := ""

var _wait := 0.0


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		sync()


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = 1.0
		sync()


## Puts the current picture on the body (and the hands on empty Hand* sprites).
func sync() -> void:
	var src := source(character_id)
	if src.is_empty():
		return
	if texture == null or texture.resource_path != src["path"]:
		var t = load(src["path"])
		if t is Texture2D:
			texture = t
	centered = false
	offset = -src["pivot"]
	scale = Vector2.ONE * float(src["scale"])
	var root := get_parent()
	if root == null:
		return
	for hname in src["hands"]:
		var node := root.get_node_or_null(str(hname)) as Sprite2D
		var h: Dictionary = src["hands"][hname]
		if node == null or node.texture != null or not _imported(h["path"]):
			continue
		var t = load(h["path"])
		if t is Texture2D:
			node.texture = t
			node.position = h["position"]
			node.scale = Vector2.ONE * float(src["scale"])


## The picture the body shows for a character: {path, pivot (texture px), scale (scene px per
## texture px), hands {name: {path, position (scene px)}}}: the side view's ready frame once its
## side.json and PNG are imported, else the baked idle frame (no hands); {} for an unknown id.
static func source(id: String) -> Dictionary:
	if not Art.CHARACTERS.has(id):
		return {}
	var dir := Art.ROOT + "characters/%s/%s/" % [id, Art.SIDE_VIEW]
	var data = JSON.parse_string(FileAccess.get_file_as_string(dir + "side.json")) if FileAccess.file_exists(dir + "side.json") else null
	if data is Dictionary and float(data.get("pxPerUnit", 0.0)) > 0.0 and data.get("pivot") is Array:
		var draw = data.get("anims", {}).get(Art.DRAW_ANIM) if data.get("anims") is Dictionary else null
		var frames = draw.get("frames") if draw is Dictionary else null
		if frames is Array and not frames.is_empty() and _imported(dir + str(frames[0]) + ".png"):
			var k := Art.PX_PER_UNIT / float(data["pxPerUnit"])
			var pivot := Vector2(float(data["pivot"][0]), float(data["pivot"][1]))
			var hands := {}
			var rp = data.get("readyPose")
			if rp is Dictionary and rp.get("hands") is Dictionary:
				for hname in rp["hands"]:
					var h = rp["hands"][hname]
					if h is Dictionary and h.get("center") is Array and str(h.get("stem", "")) != "":
						hands[str(hname)] = {"path": dir + str(h["stem"]) + ".png",
							"position": (Vector2(float(h["center"][0]), float(h["center"][1])) - pivot) * k}
			return {"path": dir + str(frames[0]) + ".png", "pivot": pivot, "scale": k, "hands": hands}
	return {"path": Art.ROOT + "characters/%s/idle_0.png" % id, "pivot": Art.FRAME_PIVOT, "scale": 1.0, "hands": {}}


## The editor has imported the PNG (a fresh .import written by a tool has no imported copy yet).
static func _imported(path: String) -> bool:
	return FileAccess.file_exists(path) and FileAccess.file_exists(path + ".import") \
		and FileAccess.get_file_as_string(path + ".import").contains("\npath")
