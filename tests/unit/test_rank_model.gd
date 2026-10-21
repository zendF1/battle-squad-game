extends "res://tests/test_case.gd"

const RankModel := preload("res://screens/ranked/rank_model.gd")


func test_tier_names_and_numerals() -> void:
	eq(RankModel.tier_name("bronze"), "Đồng", "bronze")
	eq(RankModel.tier_name("platinum"), "Bạch kim", "platinum")
	eq(RankModel.tier_name("master"), "Cao thủ", "master")
	eq(RankModel.tier_name("wood"), "", "unknown")
	eq(RankModel.numeral(3), "III", "lowest division")
	eq(RankModel.numeral(2), "II", "II")
	eq(RankModel.numeral(1), "I", "highest division")
	eq(RankModel.numeral(0), "", "none")
	eq(RankModel.numeral(4), "", "out of range")
	eq(RankModel.label("silver", 2), "Bạc II", "label")
	eq(RankModel.label("diamond", 1), "Kim cương I", "two-word tier")
	eq(RankModel.label("master", 1), "Cao thủ", "master has no division")
	eq(RankModel.label("gold", 0), "Vàng", "no division known")
	eq(RankModel.label("", 3), "Chưa xếp hạng", "unknown tier")


func test_rating_to_tier_like_the_server() -> void:
	eq(RankModel.of_rating(0), ["bronze", 3], "floor")
	eq(RankModel.of_rating(333), ["bronze", 2], "bronze II")
	eq(RankModel.of_rating(999), ["bronze", 1], "bronze I")
	eq(RankModel.of_rating(1000), ["silver", 3], "default rating")
	eq(RankModel.of_rating(1066), ["silver", 2], "silver II")
	eq(RankModel.of_rating(1199), ["silver", 1], "silver I (capped)")
	eq(RankModel.of_rating(1200), ["gold", 3], "gold")
	eq(RankModel.of_rating(1499), ["gold", 1], "gold I")
	eq(RankModel.of_rating(1650), ["platinum", 2], "platinum II")
	eq(RankModel.of_rating(1800), ["diamond", 3], "diamond")
	eq(RankModel.of_rating(2200), ["master", 1], "master")
	eq(RankModel.of_rating(-5), ["bronze", 3], "below the floor")


func test_compare_ranks() -> void:
	eq(RankModel.compare(["silver", 3], ["silver", 2]), RankModel.UP, "division up")
	eq(RankModel.compare(["silver", 1], ["gold", 3]), RankModel.UP, "tier up")
	eq(RankModel.compare(["gold", 3], ["silver", 1]), RankModel.DOWN, "tier down")
	eq(RankModel.compare(["gold", 1], ["gold", 2]), RankModel.DOWN, "division down")
	eq(RankModel.compare(["gold", 2], ["gold", 2]), RankModel.SAME, "same")
	eq(RankModel.compare(["master", 1], ["master", 1]), RankModel.SAME, "master")


func test_from_me_and_its_texts() -> void:
	var r := RankModel.from_me({"rating": 1050, "tier": "silver", "division": 2, "wins": 12, "losses": 8, "draws": 0,
		"rankPos": 7, "season": {"seasonId": "s1", "name": "Mùa 1", "endsAt": "2026-11-30T17:00:00Z"}})
	eq(r["rating"], 1050, "rating")
	eq(RankModel.mode_line(r), "Bạc II · 1.050 điểm", "mode card line")
	eq(RankModel.position_text(r["rankPos"]), "Hạng #7", "position")
	eq(RankModel.position_text(0), "Chưa có thứ hạng", "no position")
	eq(RankModel.position_text(1234), "Hạng #1.234", "big position")
	eq(RankModel.record_text(r), "Thắng 12 · Thua 8", "record")
	r["draws"] = 2
	eq(RankModel.record_text(r), "Thắng 12 · Thua 8 · Hoà 2", "with draws")
	eq(RankModel.season_text(r, 0), "Mùa 1 · Kết thúc 30/11", "season, UTC")
	eq(RankModel.season_text(r, 7 * 60), "Mùa 1 · Kết thúc 01/12", "season, Vietnam time")
	var bare := RankModel.from_me({})
	eq([bare["rating"], bare["tier"], bare["division"]], [1000, "silver", 3], "the server's default")
	eq(RankModel.season_text(bare, 0), "Mùa giải hiện tại", "no season")
	var odd := RankModel.from_me({"rating": 1700, "tier": "nope", "division": 9})
	eq([odd["tier"], odd["division"]], ["platinum", 1], "bad tier and division from the rating")
	eq(RankModel.from_me(null)["rating"], 1000, "not a dictionary")


func test_result_of_a_ranked_reward() -> void:
	var reward := {"expGained": 50, "coinGained": 100, "ratingChange": 18, "newRating": 1068, "newTier": "silver",
		"newDivision": 2, "oldRating": 1050, "oldTier": "silver", "oldDivision": 3}
	var res := RankModel.result_of("ranked_2v2", reward)
	eq([res["old"], res["new"], res["change"]], [1050, 1068, 18], "ratings")
	eq(res["old_rank"], ["silver", 3], "old rank")
	eq(res["new_rank"], ["silver", 2], "new rank")
	eq(res["move"], RankModel.UP, "promoted")
	eq(RankModel.rating_line(res), "Điểm hạng 1.050 → 1.068 (+18)", "line")
	eq(RankModel.rating_line(res, 1059), "Điểm hạng 1.050 → 1.059 (+18)", "line while counting")
	eq(RankModel.move_text(res["move"]), "Thăng hạng!", "promotion text")
	eq(RankModel.result_of("pvp_1v1", reward), {}, "unranked modes show nothing")
	eq(RankModel.result_of("ranked_2v2", null), {}, "no reward")
	eq(RankModel.result_of("ranked_2v2", {"expGained": 5}), {}, "no rating in it")


func test_result_without_old_fields_and_demotion() -> void:
	var res := RankModel.result_of("ranked_2v2", {"ratingChange": -20, "newRating": 1190, "newTier": "silver", "newDivision": 1})
	eq(res["old"], 1210, "old from new - change")
	eq(res["old_rank"], ["gold", 3], "old tier from the rating")
	eq(res["move"], RankModel.DOWN, "demoted")
	eq(RankModel.rating_line(res), "Điểm hạng 1.210 → 1.190 (-20)", "falling line")
	eq(RankModel.move_text(res["move"]), "Rớt hạng", "demotion text")
	var same := RankModel.result_of("ranked_2v2", {"ratingChange": 0, "newRating": 1000, "oldRating": 1000})
	eq(same["move"], RankModel.SAME, "same rank")
	eq(RankModel.rating_line(same), "Điểm hạng 1.000 → 1.000 (±0)", "no change")
	eq(RankModel.move_text(same["move"]), "", "no move text")


func test_timer_and_tips() -> void:
	eq(RankModel.timer_text(0), "0:00", "start")
	eq(RankModel.timer_text(31), "0:31", "seconds")
	eq(RankModel.timer_text(65), "1:05", "minute")
	eq(RankModel.timer_text(600), "10:00", "ten minutes")
	eq(RankModel.timer_text(-3), "0:00", "never negative")
	check(RankModel.TIPS.size() >= 10, "at least ten tips")
	eq(RankModel.tip(0), RankModel.TIPS[0], "first tip")
	eq(RankModel.tip(RankModel.TIPS.size()), RankModel.TIPS[0], "wraps")
	eq(RankModel.tip(-1), RankModel.TIPS[-1], "wraps back")
