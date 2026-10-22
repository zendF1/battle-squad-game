extends SceneTree
## Headless test runner: runs every test_* method of every res://tests/unit/test_*.gd.
## Use tests/run.sh, which also fails the run on script errors. Every test starts with the game
## data of tests/fixtures/gamedata.json (a real GET /gamedata answer) and no cache file.

const TEST_DIR := "res://tests/unit"
const GameData := preload("res://autoload/game_data_model.gd")
const FIXTURE := "res://tests/fixtures/gamedata.json"


func _initialize() -> void:
	var passed := 0
	var failed := 0
	var fixture = GameData.parse(JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)))
	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load(TEST_DIR + "/" + file)
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			GameData.reset("")
			GameData.take(fixture, "", false)
			var test = script.new()
			test.call(method_name)
			if test.failures.is_empty():
				passed += 1
			else:
				failed += 1
				print("FAIL %s::%s" % [file, method_name])
				for failure in test.failures:
					print("    " + failure)
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
