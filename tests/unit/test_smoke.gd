extends "res://tests/test_case.gd"


func test_runner_reports_assertions() -> void:
	eq(1 + 1, 2, "arithmetic")
