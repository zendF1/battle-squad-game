extends "res://tests/test_case.gd"

const RankLadderModel := preload("res://screens/ranked/rank_ladder_model.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")


static func _rank(points: int, extra: Dictionary = {}) -> Dictionary:
	var me := {"rankPoints": points}
	me.merge(extra, true)
	return RankModel.from_me(me)


func test_columns_follow_the_game_data() -> void:
	var cols := RankLadderModel.columns()
	eq(cols.size(), GameData.grade_list().size(), "one column per grade")
	eq(cols.map(func(c): return c["grade"]), GameData.grade_ids(), "lowest first, the generals last")
	var first: Dictionary = cols[0]
	eq([first["grade"], first["min_points"], first["win"], first["loss"], first["general"]],
		["binh_nhi", 0, 30, 5, false], "a ladder grade's numbers")
	var top: Dictionary = cols[RankLadderModel.index_of(cols, "dai_tuong")]
	check(top["general"], "a general")
	eq([top["from_pos"], top["to_pos"]], [1, 1], "its leaderboard positions (grades.generals)")
	var tiles: Array = first["tiles"]
	var kinds := tiles.map(func(t): return t["kind"])
	check(kinds.has("coin") and kinds.has("chest"), "the season reward as tiles: %s" % str(kinds))
	var coin: Dictionary = tiles.filter(func(t): return t["kind"] == "coin")[0]
	eq(coin["qty"], int(GameData.season_reward("binh_nhi")["coin"]), "the game data's coins")


func test_pill_texts() -> void:
	var cols := RankLadderModel.columns()
	eq(RankLadderModel.pill_text(cols[RankLadderModel.index_of(cols, "binh_nhat")]), "300", "the points to reach it")
	eq(RankLadderModel.pill_text(cols[RankLadderModel.index_of(cols, "dai_ta")]), "3.900", "thousands separator")
	eq(RankLadderModel.pill_text(cols[RankLadderModel.index_of(cols, "dai_tuong")]), "#1", "one position")
	eq(RankLadderModel.pill_text(cols[RankLadderModel.index_of(cols, "thuong_tuong")]), "#2–3", "a range")
	eq(RankLadderModel.pill_text(cols[RankLadderModel.index_of(cols, "thieu_tuong")]), "#7–10", "a wider range")
	eq(RankLadderModel.positions_text(0, 0), "", "unknown positions")


func test_current_and_reward_index() -> void:
	var cols := RankLadderModel.columns()
	eq(RankLadderModel.current_index(cols, {}), -1, "before the rank loads")
	eq(RankLadderModel.reward_index(cols, {}), -1, "no reward column either")
	var r := _rank(950, {"grade": "trung_si", "gradeDivision": 3})
	eq(RankLadderModel.current_index(cols, r), RankLadderModel.index_of(cols, "trung_si"), "the grade's column")
	eq(RankLadderModel.reward_index(cols, r), RankLadderModel.index_of(cols, "trung_si"), "the current grade's reward")
	var top := _rank(5200, {"grade": "dai_ta", "gradeDivision": 1, "generalCandidate": "trung_tuong"})
	eq(RankLadderModel.current_index(cols, top), RankLadderModel.index_of(cols, "dai_ta"), "still Đại tá")
	eq(RankLadderModel.reward_index(cols, top), RankLadderModel.index_of(cols, "trung_tuong"), "a candidate's general reward")


func test_fill_between_the_pills() -> void:
	var cols := RankLadderModel.columns()
	near(RankLadderModel.fill(cols, _rank(0)), 0.0, 0.0001, "on the first pill")
	near(RankLadderModel.fill(cols, _rank(150)), 0.5, 0.0001, "half way to Binh nhất (300)")
	near(RankLadderModel.fill(cols, _rank(450)), 1.5, 0.0001, "Binh nhất 300 → Hạ sĩ 600")
	near(RankLadderModel.fill(cols, _rank(600)), 2.0, 0.0001, "exactly on Hạ sĩ")
	var top := RankLadderModel.index_of(cols, "dai_ta")
	near(RankLadderModel.fill(cols, _rank(4050)), float(top), 0.0001, "the ladder top: stops on its pill")
	near(RankLadderModel.fill(cols, _rank(9999)), float(top), 0.0001, "points never reach the generals")
	var general := RankLadderModel.index_of(cols, "trung_tuong")
	near(RankLadderModel.fill(cols, _rank(4300, {"grade": "trung_tuong"})), float(general), 0.0001, "a general: its own pill")
	eq(RankLadderModel.fill(cols, {}), -1.0, "no fill before the rank loads")
	check(RankLadderModel.reached(1, 1.5) and not RankLadderModel.reached(2, 1.5), "pills up to the fill are lit")
	check(not RankLadderModel.reached(0, -1.0), "nothing lit without a rank")


func test_pips_and_scroll() -> void:
	eq(RankLadderModel.pips(_rank(0)), [1, 3], "Binh nhì 3: one pip")
	eq(RankLadderModel.pips(_rank(299)), [3, 3], "Binh nhì 1: all three")
	eq(RankLadderModel.pips(_rank(4300, {"grade": "dai_tuong"})), [0, 0], "a general has no divisions")
	eq(RankLadderModel.pips({}), [0, 0], "no rank")
	near(RankLadderModel.centre_scroll(3, 18, 300.0), 900.0, 0.001, "column 3 dead centre")
	near(RankLadderModel.centre_scroll(-1, 18, 300.0), 0.0, 0.001, "unknown: the first")
	near(RankLadderModel.centre_scroll(40, 18, 300.0), 5100.0, 0.001, "clamped to the last")


func test_season_line() -> void:
	eq(RankLadderModel.left_text(-1), "", "unknown end")
	eq(RankLadderModel.left_text(0), "Đã kết thúc", "ended")
	eq(RankLadderModel.left_text(18 * 86400 + 4 * 3600 + 59), "Còn 18 ngày 4 giờ", "days and hours")
	eq(RankLadderModel.left_text(5 * 3600 + 12 * 60), "Còn 5 giờ 12 phút", "hours and minutes")
	eq(RankLadderModel.left_text(30), "Còn 1 phút", "under a minute rounds up")
	var r := _rank(100, {"season": {"name": "Mùa 1", "endsAt": "2026-11-30T17:00:00Z"}})
	var now := _unix("2026-11-12T13:00:00Z")
	eq(RankLadderModel.season_line(r, now), "Mùa 1 · Còn 18 ngày 4 giờ", "name and time left")
	eq(RankLadderModel.season_line(_rank(100, {"season": {"name": "Mùa 1"}}), now), "Mùa 1", "no end time")
	eq(RankLadderModel.season_line(_rank(100), now), "", "no season")


static func _unix(iso: String) -> int:
	return preload("res://core/fmt.gd").unix_time(iso)
