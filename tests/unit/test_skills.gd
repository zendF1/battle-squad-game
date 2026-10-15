extends "res://tests/test_case.gd"

const Skills := preload("res://match/skills.gd")


func test_every_character_has_its_server_skill() -> void:
	eq(Skills.for_character("rookie")["id"], "triple_shot", "rookie")
	eq(Skills.for_character("tanko")["id"], "heavy_bomb", "tanko")
	eq(Skills.for_character("spark")["id"], "shock_field", "spark")
	eq(Skills.for_character("flora")["id"], "healing_bloom", "flora")
	check(Skills.for_character("nobody").is_empty(), "unknown character has no skill")


func test_preview_offsets_match_server_projectiles() -> void:
	eq(Skills.for_character("rookie")["offsets"], [-10.0, 0.0, 10.0], "triple_shot angles")
	eq(Skills.for_character("tanko")["offsets"], [0.0], "heavy_bomb one arc")
	eq(Skills.for_character("spark")["offsets"], [0.0], "shock_field one arc")


func test_only_heal_fires_without_aim() -> void:
	for id in Skills.BY_CHARACTER:
		eq(Skills.BY_CHARACTER[id]["needs_aim"], id != "flora", "needs_aim " + id)
	# The values the server validates even when it ignores them.
	check(Skills.NO_AIM_POWER >= 0.0 and Skills.NO_AIM_POWER <= 100.0, "heal power in range")


func test_ready_only_at_full_energy() -> void:
	check(not Skills.is_ready(0), "0")
	check(not Skills.is_ready(99), "99")
	check(Skills.is_ready(100), "100")


func test_button_label() -> void:
	var rookie := Skills.for_character("rookie")
	eq(Skills.button_label(rookie, 40), "Bắn 3 tia 40/100", "charging")
	eq(Skills.button_label(rookie, 0), "Bắn 3 tia 0/100", "empty")
	eq(Skills.button_label(rookie, 100), "Bắn 3 tia", "ready")
	eq(Skills.button_label(Skills.for_character("flora"), 100), "Hồi máu", "heal ready")


func test_status_labels() -> void:
	eq(Skills.status_label("net"), "Bị lưới", "net")
	eq(Skills.status_label("heal"), "", "heal shows nothing extra")
	eq(Skills.status_label("unknown"), "", "unknown")
