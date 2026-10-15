extends SceneTree
## Headless test runner: runs every test_* method of every res://tests/unit/test_*.gd.
## Use tests/run.sh, which also fails the run on script errors.

const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	var passed := 0
	var failed := 0
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
