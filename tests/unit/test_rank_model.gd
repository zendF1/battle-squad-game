extends "res://tests/test_case.gd"

const RankModel := preload("res://screens/ranked/rank_model.gd")
const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const GradeFrame := preload("res://screens/ranked/grade_frame.gd")
const Art := preload("res://ui/art.gd")


func test_grade_names_and_labels() -> void:
	eq(RankModel.grade_name("binh_nhi"), "Binh nhì", "the lowest")
	eq(RankModel.grade_name("dai_ta"), "Đại tá", "the ladder top")
	eq(RankModel.grade_name("dai_tuong"), "Đại tướng", "a general")
	eq(RankModel.grade_name("wood"), "", "unknown")
	eq(RankModel.label("binh_nhi", 3), "Binh nhì 3", "division after the name")
	eq(RankModel.label("thuong_uy", 1), "Thượng úy 1", "division 1")
	eq(RankModel.label("thieu_tuong", 1), "Thiếu tướng", "a general has no division")
	eq(RankModel.label("ha_si", 0), "Hạ sĩ", "no division known")
	eq(RankModel.label("", 3), "", "unknown grade")
	check(RankModel.is_general("trung_tuong") and not RankModel.is_general("dai_ta"), "the game data's general flag")
	eq(RankModel.grades().size(), 18, "every grade of the game data")


func test_division_from_points() -> void:
	eq(RankModel.of_points(0), ["binh_nhi", 3], "a new season: Binh nhì 3")
	eq(RankModel.of_points(99), ["binh_nhi", 3], "Binh nhì 3 ends at 99")
	eq(RankModel.of_points(100), ["binh_nhi", 2], "Binh nhì 2")
	eq(RankModel.of_points(299), ["binh_nhi", 1], "Binh nhì 1")
	eq(RankModel.of_points(300), ["binh_nhat", 3], "the next grade")
	eq(RankModel.of_points(1500), ["hoc_vien", 3], "Học viên 3")
	eq(RankModel.of_points(4099), ["dai_ta", 2], "Đại tá 2")
	eq(RankModel.of_points(4100), ["dai_ta", 1], "Đại tá 1 starts at 4100")
	eq(RankModel.of_points(9999), ["dai_ta", 1], "past the ladder: still Đại tá 1, never a general")
	eq(RankModel.of_points(-5), ["binh_nhi", 3], "below 0")
	eq(RankModel.division_start(["binh_nhi", 2]), 100, "a division's first point")
	eq(RankModel.division_start(["dai_ta", 1]), 4100, "Đại tá 1's")
	eq(RankModel.division_start(["wood", 1]), -1, "unknown")


func test_progress_inside_the_division() -> void:
	near(RankModel.progress(145, ["binh_nhi", 2]), 0.45, 0.001, "45 of 100")
	near(RankModel.progress(100, ["binh_nhi", 2]), 0.0, 0.001, "the division's start")
	eq(RankModel.progress_text(145, ["binh_nhi", 2]), "45/100", "points in the division")
	eq(RankModel.progress_text(4099, ["dai_ta", 2]), "99/100", "Đại tá 2's last")
	check(RankModel.at_top(["dai_ta", 1]) and not RankModel.at_top(["dai_ta", 2]), "only Đại tá 1 is the top")
	check(RankModel.at_top(["dai_tuong", 1]), "a general too")
	near(RankModel.progress(4230, ["dai_ta", 1]), 1.0, 0.001, "the top: a full bar")
	eq(RankModel.progress_text(4230, ["dai_ta", 1]), "", "no bar text at the top")


func test_from_me_and_its_texts() -> void:
	var r := RankModel.from_me({"rating": 1050, "tier": "silver", "rankPoints": 145, "grade": "binh_nhi", "gradeDivision": 2,
		"generalCandidate": "", "rankBadge": "trung_si", "wins": 12, "losses": 8, "draws": 0, "rankPos": 7,
		"season": {"seasonId": "s1", "name": "Mùa 1", "endsAt": "2026-11-30T17:00:00Z"}})
	eq([r["points"], r["grade"], r["division"], r["badge"]], [145, "binh_nhi", 2, "trung_si"], "fields")
	check(not r.has("tier") and not r.has("rating"), "the old tier and the rating are not shown")
	eq(RankModel.rank_line(r), "Binh nhì 2 · 45/100", "the chip / mode line")
	eq(RankModel.position_text(r["rankPos"]), "Hạng #7", "position")
	eq(RankModel.position_text(0), "Chưa có thứ hạng", "no position")
	eq(RankModel.record_text(r), "Thắng 12 · Thua 8", "record")
	eq(RankModel.season_text(r, 7 * 60), "Mùa 1 · Kết thúc 01/12", "season end, Vietnam time")
	var bare := RankModel.from_me({})
	eq([bare["points"], bare["grade"], bare["division"], bare["badge"]], [0, "binh_nhi", 3, ""], "no row: Binh nhì 3")
	eq(RankModel.rank_line(bare), "Binh nhì 3 · 0/100", "from the bottom")
	var odd := RankModel.from_me({"rankPoints": 1530, "grade": "nope", "gradeDivision": 9})
	eq([odd["grade"], odd["division"]], ["hoc_vien", 3], "bad grade and division: from the points")
	eq(RankModel.from_me(null)["points"], 0, "not a dictionary")


func test_above_dai_ta_and_the_general_candidate() -> void:
	var r := RankModel.from_me({"rankPoints": 4230, "grade": "dai_ta", "gradeDivision": 1, "generalCandidate": "thieu_tuong"})
	eq(RankModel.rank_line(r), "Đại tá 1 · 4.230 điểm", "above Đại tá 1: the total")
	eq(r["candidate"], "thieu_tuong", "the candidate")
	eq(RankModel.candidate_text(r["candidate"]), "Dự kiến: Thiếu tướng", "its label")
	eq(RankModel.candidate_text(""), "", "none")
	eq(RankModel.from_me({"generalCandidate": "wood"})["candidate"], "", "an unknown grade is no candidate")
	var general := RankModel.from_me({"rankPoints": 5000, "grade": "dai_tuong", "gradeDivision": 1})
	eq(RankModel.rank_line(general), "Đại tướng · 5.000 điểm", "a general (at season end)")


func test_result_of_a_ranked_reward() -> void:
	var reward := {"expGained": 50, "coinGained": 210, "bonusCoin": 150, "ratingChange": 18, "newRating": 1068,
		"grade": {"oldPoints": 280, "newPoints": 310, "pointsChange": 30, "oldGrade": "binh_nhi", "oldGradeDivision": 1,
		"newGrade": "binh_nhat", "newGradeDivision": 3}}
	var res := RankModel.result_of("ranked_2v2", reward)
	eq([res["old"], res["new"], res["change"]], [280, 310, 30], "points")
	eq(res["old_rank"], ["binh_nhi", 1], "old rank")
	eq(res["new_rank"], ["binh_nhat", 3], "new rank")
	eq(res["move"], RankModel.UP, "promoted")
	eq(RankModel.points_change_text(res["change"]), "+30 điểm hạng", "the points line")
	eq(RankModel.points_change_text(-15), "-15 điểm hạng", "a loss")
	eq(RankModel.points_change_text(0), "±0 điểm hạng", "a draw")
	eq(RankModel.points_line(res), "Điểm hạng 280 → 310", "the count")
	eq(RankModel.move_text(res["move"]), "Thăng cấp!", "promotion text")
	eq(RankModel.result_of("casual_2v2", reward), {}, "not ranked: nothing")
	eq(RankModel.result_of("ranked_2v2", null), {}, "no reward")
	eq(RankModel.result_of("ranked_2v2", {"newRating": 1068, "ratingChange": 18}), {}, "the hidden rating is never shown")


func test_result_without_old_fields_and_demotion() -> void:
	var res := RankModel.result_of("ranked_2v2", {"grade": {"newPoints": 285, "pointsChange": -15}})
	eq([res["old"], res["new"], res["change"]], [300, 285, -15], "old from new - change")
	eq([res["old_rank"], res["new_rank"], res["move"]], [["binh_nhat", 3], ["binh_nhi", 1], RankModel.DOWN],
		"ranks from the points")
	var bottom := RankModel.result_of("ranked_2v2", {"grade": {"oldPoints": 0, "newPoints": 0, "pointsChange": 0}})
	eq(bottom["move"], RankModel.SAME, "never below 0: same rank")


func _popup(old_rank: Array, new_rank: Array, old := 290, new := 320) -> Dictionary:
	return RankModel.popup_of({"old": old, "new": new, "change": new - old, "old_rank": old_rank, "new_rank": new_rank,
		"move": RankModel.compare(old_rank, new_rank)})


func test_rank_popup_division_up() -> void:
	var p := _popup(["trung_si", 2], ["trung_si", 1])
	eq([p["kind"], p["move"], p["steps"], p["crown"], p["title"], p["label"]],
		["division", RankModel.UP, [["trung_si", 1]], false, "THĂNG CẤP!", "Trung sĩ 1"], "Trung sĩ 2 → 1")


func test_rank_popup_grade_up() -> void:
	var p := _popup(["binh_nhi", 1], ["binh_nhat", 3])
	eq([p["kind"], p["steps"], p["label"]], ["grade", [["binh_nhat", 3]], "Binh nhất 3"], "Binh nhì 1 → Binh nhất 3")
	var far := _popup(["binh_nhi", 2], ["binh_nhat", 2])
	eq(far["steps"], [["binh_nhi", 1], ["binh_nhat", 3], ["binh_nhat", 2]], "every division passed")


func test_rank_popup_demotion_and_none() -> void:
	var p := _popup(["hoc_vien", 3], ["thuong_si", 1], 1500, 1485)
	eq([p["kind"], p["move"], p["steps"], p["title"], p["crown"]], ["down", RankModel.DOWN, [["thuong_si", 1]], "HẠ CẤP", false],
		"Học viên 3 → Thượng sĩ 1")
	eq(_popup(["ha_si", 2], ["ha_si", 2]), {}, "only the points moved: no popup")
	eq(RankModel.popup_of({}), {}, "not ranked")


func test_rank_popup_ladder_top() -> void:
	var p := _popup(["dai_ta", 2], ["dai_ta", 1], 4090, 4110)
	eq([p["kind"], p["crown"], p["label"]], ["division", true, "Đại tá 1"], "the crown at Đại tá 1")
	eq(RankModel.next_rank(["dai_ta", 1]), [], "the generals are never reached by playing")
	eq(RankModel.prev_rank(["binh_nhi", 3]), [], "nothing under Binh nhì 3")
	eq(RankModel.next_rank(["binh_nhi", 1]), ["binh_nhat", 3], "a grade's top → the next grade's lowest")
	eq(RankModel.prev_rank(["binh_nhat", 3]), ["binh_nhi", 1], "a grade's lowest → the lower grade's top")
	eq(_popup(["dai_ta", 1], ["dai_ta", 1], 4300, 4320), {}, "points above the top: no popup")


func test_badge_groups_and_looks() -> void:
	eq([GradeBadge.group_of("binh_nhi"), GradeBadge.marks_of("binh_nhi")], ["enlisted", 1], "one chevron")
	eq([GradeBadge.group_of("thuong_si"), GradeBadge.marks_of("thuong_si")], ["enlisted", 5], "five chevrons")
	eq(GradeBadge.group_of("hoc_vien"), "cadet", "a bar")
	eq([GradeBadge.group_of("dai_uy"), GradeBadge.marks_of("dai_uy")], ["company", 4], "four stars, one stripe")
	eq([GradeBadge.group_of("thieu_ta"), GradeBadge.marks_of("thieu_ta")], ["field", 1], "one star, two stripes")
	eq([GradeBadge.group_of("dai_tuong"), GradeBadge.marks_of("dai_tuong")], ["general", 4], "four big stars")
	eq(GradeBadge.group_of(""), "", "no badge")
	eq(GradeBadge.group_of("wood"), "", "unknown")
	for g in RankModel.grades():
		check(GradeBadge.LOOKS.has(g), "%s has a look" % g)
	check(GradeBadge.text_color("dai_ta") != GradeBadge.text_color("binh_nhi"), "groups read apart")


func test_badge_of_payloads() -> void:
	eq(RankModel.badge_of({"rankBadge": "dai_ta"}), "dai_ta", "a grade")
	eq(RankModel.badge_of({"rankBadge": ""}), "", "none")
	eq(RankModel.badge_of({}), "", "absent (omitempty)")
	eq(RankModel.badge_of({"rankBadge": "gold"}), "", "an old tier is no badge")
	eq(RankModel.badge_of(null), "", "not a dictionary")


func test_timer_and_tips() -> void:
	eq(RankModel.timer_text(0), "0:00", "start")
	eq(RankModel.timer_text(31), "0:31", "seconds")
	eq(RankModel.timer_text(65), "1:05", "minute")
	eq(RankModel.timer_text(600), "10:00", "ten minutes")
	eq(RankModel.timer_text(-3), "0:00", "never negative")
	check(RankModel.tips().size() >= 10, "at least ten tips")
	eq(RankModel.tip(0), RankModel.tips()[0], "first tip")
	eq(RankModel.tip(RankModel.tips().size()), RankModel.tips()[0], "wraps")
	eq(RankModel.tip(-1), RankModel.tips()[-1], "wraps back")


func test_grades_follow_the_game_data() -> void:
	var d: Dictionary = GameData.data.duplicate(true)
	d["grades"]["divisionPoints"] = 50
	d["version"] = "grades-test"
	GameData.take(d, "", false)
	eq(RankModel.of_points(60), ["binh_nhi", 2], "the division size is the game data's")
	eq(RankModel.progress_text(60, ["binh_nhi", 2]), "10/50", "and its bar")


func test_rank_art_is_optional_and_frames_fit_the_card() -> void:
	eq(Art.rank_frame_path("dai_ta"), "res://assets/ranks/frame_dai_ta.png", "frame file")
	eq(Art.rank_badge_path("dai_ta"), "res://assets/ranks/badge_dai_ta.png", "badge file")
	eq(Art.rank_badge(""), null, "no badge: no art")
	if not Art.has_png(Art.rank_badge_path("no_such_grade")):
		eq(Art.rank_badge("no_such_grade"), null, "a missing file: null, the code drawing")
	var r := GradeFrame.art_rect(Rect2(10, 20, 380, 500), 0.12)
	near(r.size.x * 0.76, 380.0, 0.01, "the art's window spans the card's width")
	near(r.position.x + r.size.x * 0.12, 10.0, 0.01, "the window's left on the card's")
	near(r.position.y + r.size.y * 0.12, 20.0, 0.01, "the window's top on the card's")
