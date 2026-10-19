@tool
extends Sprite2D
## The Body of a pose scene (scenes/character/poses/<id>_ready.tscn), editor only: it shows the
## character's ready frame where the match draws it (the feet on the scene's origin, at the
## match's scale), so the gun can be placed on it by hand. Its picture follows the art with no
## edit: the side view's ready frame (assets/characters/<id>/side/, side.json "draw", written by
## tools/import_frames.gd) once it is imported (until then: no picture, already at its place),
## else the baked idle frame as a stand-in (a character without a side view). Checked when the
## scene opens and every second while it is open.
## In the game it does nothing (ui/art.gd ready_pose() reads only GunSocket and its Preview).

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


## Puts the current picture on the body (a ready frame not imported yet: only its place).
func sync() -> void:
	var src := source(character_id)
	if src.is_empty():
		return
	if (texture == null or texture.resource_path != src["path"]) and _imported(src["path"]):
		var t = load(src["path"])
		if t is Texture2D:
			texture = t
	centered = false
	offset = -src["pivot"]
	scale = Vector2.ONE * float(src["scale"])


## The picture the body shows for a character: {path, pivot (texture px), scale (scene px per
## texture px)}: the side view's ready frame when its side.json has one (sync() loads it once the
## editor has imported it), else the baked idle frame; {} for an unknown id.
static func source(id: String) -> Dictionary:
	if not Art.CHARACTERS.has(id):
		return {}
	var dir := Art.ROOT + "characters/%s/%s/" % [id, Art.SIDE_VIEW]
	var data = JSON.parse_string(FileAccess.get_file_as_string(dir + "side.json")) if FileAccess.file_exists(dir + "side.json") else null
	if data is Dictionary and float(data.get("pxPerUnit", 0.0)) > 0.0 and data.get("pivot") is Array:
		var draw = data.get("anims", {}).get(Art.DRAW_ANIM) if data.get("anims") is Dictionary else null
		var frames = draw.get("frames") if draw is Dictionary else null
		if frames is Array and not frames.is_empty() and FileAccess.file_exists(dir + str(frames[0]) + ".png"):
			var k := Art.PX_PER_UNIT / float(data["pxPerUnit"])
			var pivot := Vector2(float(data["pivot"][0]), float(data["pivot"][1]))
			return {"path": dir + str(frames[0]) + ".png", "pivot": pivot, "scale": k}
	return {"path": Art.ROOT + "characters/%s/idle_0.png" % id, "pivot": Art.FRAME_PIVOT, "scale": 1.0}


## The editor has imported the PNG (a fresh .import written by a tool has no imported copy yet).
static func _imported(path: String) -> bool:
	return FileAccess.file_exists(path) and FileAccess.file_exists(path + ".import") \
		and FileAccess.get_file_as_string(path + ".import").contains("\npath")
