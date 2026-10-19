@tool
extends Sprite2D
## The Preview of a pose scene's GunSocket (scenes/character/poses/<id>_ready.tscn), editor only
## while it has no picture: it shows the `kind` / `tier` hug gun (assets/weapons/<kind>/hug_<tier>.png,
## tools/import_hug_guns.gd) once the editor has imported it, so a fresh hug gun turns up with no
## edit (a scene can only name an imported picture). A Preview with a picture is never touched;
## its position / scale / offset are the scene's (placed by hand). Checked when the scene opens and
## every second while it is open. In the game it does nothing: ui/art.gd ready_pose() reads the
## Preview (one with no picture yet stands for its kind / tier's hug_gun()).

const Art := preload("res://ui/art.gd")

@export var kind := "bazooka"
@export var tier := "iron"

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


## Puts the hug gun on an empty Preview once it is imported.
func sync() -> void:
	if texture != null:
		return
	var path := Art.hug_gun_path(kind, tier)
	if not _imported(path):
		return
	var t = load(path)
	if t is Texture2D:
		texture = t


## The editor has imported the PNG (a fresh .import written by a tool has no imported copy yet).
static func _imported(path: String) -> bool:
	return FileAccess.file_exists(path) and FileAccess.file_exists(path + ".import") \
		and FileAccess.get_file_as_string(path + ".import").contains("\npath")
