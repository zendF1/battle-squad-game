extends "res://tests/test_case.gd"
## Every runtime script compiles (a parse error in a screen no test instantiates would otherwise
## only show when the screen opens): each .gd under autoload/, core/, match/, screens/, ui/ loads
## and can be instantiated.

const ROOTS := ["res://autoload", "res://core", "res://match", "res://screens", "res://ui"]


static func _scripts(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_scripts(dir + "/" + d, out)


func test_every_runtime_script_compiles() -> void:
	var paths: Array = []
	for r in ROOTS:
		_scripts(r, paths)
	check(paths.size() > 100, "found the scripts (%d)" % paths.size())
	for p in paths:
		var s = load(p)
		check(s is GDScript and (s as GDScript).can_instantiate(), "%s compiles" % p)
