extends "res://tests/test_case.gd"
## A script in the export loading one from a folder export_presets.cfg excludes works in the editor
## but fails on device, and every script depending on it fails to compile (shield_ball.gd
## preloading tools/art/equipment_painter.gd once broke match_screen and player_view on iOS).
## The rest of what only breaks in a build is caught by tools/check_export.sh.

const PRESETS := "res://export_presets.cfg"
const SKIP := [".godot", "build"]


func test_no_load_from_excluded_folders() -> void:
	var excluded := _excluded_dirs()
	check(not excluded.is_empty(), "export_presets.cfg excludes folders")
	var bad: Array[String] = []
	for path in _files("res://", excluded):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			for dir in excluded:
				for pat in ['load("res://%s', 'extends "res://%s', 'path="res://%s']: # load( covers preload(
					if lines[i].contains(pat % dir):
						bad.append("%s:%d" % [path, i + 1])
	eq(bad, [] as Array[String], "exported scripts load nothing from the excluded folders %s" % [excluded])


## The folders every preset's exclude_filter leaves out ("art_source/", ...).
func _excluded_dirs() -> Array[String]:
	var cfg := ConfigFile.new()
	var out: Array[String] = []
	if cfg.load(PRESETS) != OK:
		return out
	for section in cfg.get_sections():
		if not section.ends_with(".options") and cfg.has_section_key(section, "exclude_filter"):
			for f in str(cfg.get_value(section, "exclude_filter")).split(",", false):
				var dir := f.strip_edges().trim_suffix("*")
				if dir.ends_with("/") and not out.has(dir):
					out.append(dir)
	return out


## Every .gd / .tscn / .tres under dir outside the skipped folders (res:// relative prefixes).
func _files(dir: String, skip: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for sub in DirAccess.get_directories_at(dir):
		if not SKIP.has(sub) and not skip.has((dir + sub).trim_prefix("res://") + "/"):
			out.append_array(_files(dir + sub + "/", skip))
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["gd", "tscn", "tres"]:
			out.append(dir + f)
	return out
