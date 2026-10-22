extends "res://tests/test_case.gd"

const Skills := preload("res://match/skills.gd")
const SkillView := preload("res://match/views/skills/skill_view.gd")
const GameData := preload("res://autoload/game_data_model.gd")


func test_every_character_has_its_server_skill() -> void:
	eq(Skills.for_character("rookie")["id"], "triple_shot", "rookie")
	eq(Skills.for_character("tanko")["id"], "heavy_bomb", "tanko")
	eq(Skills.for_character("spark")["id"], "shock_field", "spark")
	eq(Skills.for_character("flora")["id"], "healing_bloom", "flora")
	check(Skills.for_character("nobody").is_empty(), "unknown character has no skill")


func test_names() -> void:
	eq(Skills.for_character("rookie")["name"], "Mưa tên lửa", "rookie")
	eq(Skills.for_character("tanko")["name"], "Bom liên hoàn", "tanko")
	eq(Skills.for_character("spark")["name"], "Tia laze", "spark")
	eq(Skills.for_character("flora")["name"], "Hoa hồi xuân", "flora")


func test_aim_mode_per_skill() -> void:
	eq(Skills.for_character("rookie")["aim"], SkillView.AIM_ARC, "rain: aimed like a shot")
	eq(Skills.for_character("tanko")["aim"], SkillView.AIM_ARC, "bombs: aimed like a shot")
	eq(Skills.for_character("spark")["aim"], SkillView.AIM_LINE, "laser: a straight line")
	eq(Skills.for_character("flora")["aim"], SkillView.AIM_NONE, "bloom: no aim")
	for id in GameData.character_ids():
		var s := Skills.for_character(id)
		eq(s["needs_aim"], s["aim"] != SkillView.AIM_NONE, "needs_aim " + id)
	eq(Skills.for_character("rookie")["offsets"], [0.0], "one arc: the flare")
	eq(Skills.for_character("tanko")["offsets"], [0.0], "one arc: the bombs' trajectory")
	eq(Skills.for_character("spark")["offsets"], [], "no arc for a line")
	eq(Skills.for_character("flora")["offsets"], [], "no arc without aim")
	check(GameData.no_aim_power() >= GameData.power_min() and GameData.no_aim_power() <= GameData.power_max(), "no-aim power in range")


func test_view_for_skill() -> void:
	eq(Skills.view_for_skill("shock_field").skill_id(), "shock_field", "laser view")
	var unknown = Skills.view_for_skill("mystery")
	eq(unknown.get_script(), SkillView, "unknown skill: the base view")
	eq([unknown.skill_id(), unknown.skill_name(), unknown.describe(0), unknown.aim_mode()], ["mystery", "", "", SkillView.AIM_ARC],
		"no name or description, aimed like a shot")
	check(is_nan(unknown.aim_angle(null)), "base view puts the gun away")


func test_rank_of_player() -> void:
	eq(Skills.rank_of({"skillRank": 3}), 3, "server field")
	eq(Skills.rank_of({"skillRank": 9.0}), 4, "clamped")
	eq(Skills.rank_of({"weaponItemId": "rookie_weapon_lv40", "characterId": "rookie"}), 4, "lv40 → dragon 4")
	eq(Skills.rank_of({"weaponItemId": "tanko_weapon_lv10", "characterId": "tanko"}), 1, "lv10 → iron 1")
	eq(Skills.rank_of({"weaponItemId": "crafted_weapon_silver", "characterId": "spark"}), 2, "crafted silver 2")
	eq(Skills.rank_of({"weaponItemId": "crafted_weapon_diamond"}), 4, "crafted diamond 4")
	eq(Skills.rank_of({"weaponItemId": "", "characterId": "rookie"}), 0, "none")
	eq(Skills.rank_of({"isBot": true}), 0, "bot")


func test_describe_has_rank_numbers() -> void:
	check(Skills.describe("rookie", 0).contains("12 tên lửa"), "rain rank 0: 12")
	check(Skills.describe("rookie", 4).contains("28 tên lửa"), "rain rank 4: 28")
	check(Skills.describe("tanko", 2).contains("4 quả"), "bombs rank 2: 4")
	check(Skills.describe("tanko", 0).contains("mỗi quả 60%"), "bombs rank 0: 60% each")
	check(Skills.describe("tanko", 0).contains("tối đa 120%"), "bombs rank 0: cap 120%")
	check(Skills.describe("tanko", 4).contains("mỗi quả 34%") and Skills.describe("tanko", 4).contains("tối đa 180%"), "bombs rank 4: 34% each, cap 180%")
	check(Skills.describe("spark", 4).contains("190%"), "laser rank 4: 190%")
	check(Skills.describe("flora", 4).contains("60%") and Skills.describe("flora", 4).contains("50%"), "bloom rank 4")
	eq(Skills.describe("nobody"), "", "unknown")


func test_ready_only_at_full_energy() -> void:
	check(not Skills.is_ready(0), "0")
	check(not Skills.is_ready(99), "99")
	check(Skills.is_ready(100), "100")
	eq(Skills.full_energy(), 100, "the game data's max")


func test_button_label() -> void:
	var rookie := Skills.for_character("rookie")
	eq(Skills.button_label(rookie, 40), "Mưa tên lửa 40/100", "charging")
	eq(Skills.button_label(rookie, 0), "Mưa tên lửa 0/100", "empty")
	eq(Skills.button_label(rookie, 100), "Mưa tên lửa", "ready")


func test_status_labels() -> void:
	eq(Skills.status_label("net"), "Bị lưới", "net")
	eq(Skills.status_label("burn"), "Bỏng", "burn")
	eq(Skills.status_label("root"), "Bị cầm chân", "root")
	eq(Skills.status_label("stun"), "Choáng", "stun")
	eq(Skills.status_label("heal"), "", "heal shows nothing extra")
	eq(Skills.status_label("unknown"), "", "unknown")


## A skill an admin added: a known effect type gets that type's view and the game data's texts; an
## unknown effect type gets the base view (default replay) and never crashes.
func test_skills_from_the_game_data() -> void:
	var d: Dictionary = GameData.data.duplicate(true)
	d["version"] = "edited"
	d["characters"][0]["skillId"] = "meteor"
	d["skills"].append({"skillId": "meteor", "characterId": "rookie", "name": "Mưa sao băng", "effectType": "missile_rain",
		"aimKind": "arc", "description": "{count} sao băng, mỗi quả {damagePct}%; {missing} giữ nguyên.",
		"ranks": [{"rank": 0, "values": {"count": 6, "damagePct": 12.5}}, {"rank": 2, "values": {"count": 10, "damagePct": 30}}]})
	d["skills"].append({"skillId": "quake", "characterId": "tanko", "name": "Động đất", "effectType": "earthquake", "aimKind": "none"})
	GameData.take(d, "", false)
	var meteor := Skills.for_character("rookie")
	eq([meteor["id"], meteor["name"], meteor["aim"]], ["meteor", "Mưa sao băng", SkillView.AIM_ARC], "rookie's new skill")
	eq(Skills.view_for_skill("meteor").get_script(), Skills.VIEWS["missile_rain"], "its effect type's view")
	eq(Skills.describe("rookie", 0), "6 sao băng, mỗi quả 12.5%; {missing} giữ nguyên.", "rank 0 values")
	eq(Skills.describe("rookie", 3), "10 sao băng, mỗi quả 30%; {missing} giữ nguyên.", "a rank with no entry: the one below")
	var quake = Skills.view_for_skill("quake")
	eq(quake.get_script(), SkillView, "unknown effect type: the base view")
	eq([quake.skill_name(), quake.aim_mode()], ["Động đất", SkillView.AIM_NONE], "its name and aim from the game data")
