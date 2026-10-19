@tool
extends Sprite2D
## The ArmFront of a pose scene (scenes/character/poses/<id>_ready.tscn), editor only while it has
## no picture: it shows the character's front arm (side.json readyPose.armFront, cut from the ready
## frame by tools/import_frames.gd: the near sleeve and both fists) once the editor has imported it,
## so a fresh cut turns up with no edit (a scene can only name an imported picture). Drawn after
## GunSocket, over the gun, at the Body's place (same scale / offset: the same canvas). A picture
## set is never touched. Checked when the scene opens and every second while it is open. In the
## game it does nothing: scenes/character/character.gd draws the arm from side.json.

const Art := preload("res://ui/art.gd")

@export var character_id := "rookie"

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


## Puts the front arm on an empty ArmFront once it is imported.
func sync() -> void:
	if texture != null:
		return
	var path := arm_path(character_id)
	if path == "" or not _imported(path):
		return
	var t = load(path)
	if t is Texture2D:
		texture = t


## The character's front arm PNG (side.json readyPose.armFront), "" when it has none.
static func arm_path(id: String) -> String:
	var dir := Art.side_dir(Art.known_character(id))
	if not FileAccess.file_exists(dir + "side.json"):
		return ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(dir + "side.json"))
	var rp = data.get("readyPose") if data is Dictionary else null
	if not rp is Dictionary or str(rp.get("armFront", "")) == "":
		return ""
	return dir + str(rp["armFront"]) + ".png"


## The editor has imported the PNG (a fresh .import written by a tool has no imported copy yet).
static func _imported(path: String) -> bool:
	return FileAccess.file_exists(path) and FileAccess.file_exists(path + ".import") \
		and FileAccess.get_file_as_string(path + ".import").contains("\npath")
