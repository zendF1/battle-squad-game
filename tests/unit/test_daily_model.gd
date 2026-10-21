extends "res://tests/test_case.gd"
## DailyModel: parsing GET /missions/daily, the row order and buttons, the bars' fill between
## the chest thresholds, the countdowns, the claimable count and the reward lines.

const DailyModel := preload("res://screens/home/daily_model.gd")
const Fmt := preload("res://core/fmt.gd")


static func _m(id: String, state: String, progress: int = 0, required: int = 3, go: String = "play", activity: int = 20) -> Dictionary:
	return {"id": id, "title": "T " + id, "target": "play_match", "required": required, "progress": progress,
		"activity": activity, "goto": go, "state": state}


static func _c(id: String, track: String, threshold: int, state: String, rewards: Variant = {"coin": 300, "gem": 0, "items": []}) -> Dictionary:
	return {"id": id, "track": track, "threshold": threshold, "state": state, "rewards": rewards}


func _data() -> Dictionary:
	return {
		"day": "2026-10-21", "dayResetAt": "2026-10-21T17:00:00Z", "week": "2026-W43", "weekResetAt": "2026-10-26T17:00:00Z",
		"activity": 40, "weeklyActivity": 150,
		"missions": [
			_m("login", "claimed", 1, 1, "none", 10),
			_m("play3", "progress", 1, 3),
			_m("win1", "claimable", 1, 1),
			_m("dmg", "progress", 1250, 3000),
			_m("kill3", "claimable", 3, 3),
			_m("upg", "claimed", 1, 1, "equipment", 10),
			_m("shop", "progress", 0, 1, "shop", 10),
		],
		"chests": [_c("chest_d40", "daily", 40, "claimable"), _c("chest_d20", "daily", 20, "claimed"), _c("chest_d60", "daily", 60, "locked")],
		"weekly": [_c("chest_w150", "weekly", 150, "claimable", {"coin": 2000}), _c("chest_w300", "weekly", 300, "locked", {"gem": 30})],
	}


func test_parse() -> void:
	var p = DailyModel.parse(_data())
	check(p != null, "parsed")
	eq(p["activity"], 40, "activity")
	eq(p["weekly_activity"], 150, "weekly")
	eq(p["day_reset"], Fmt.unix_time("2026-10-21T17:00:00Z"), "day reset as unix")
	eq(p["missions"].size(), 7, "missions")
	eq(p["missions"][3]["progress"], 1250, "progress")
	eq(p["chests"].map(func(c): return c["threshold"]), [20, 40, 60], "chests by threshold")
	eq(p["weekly"][0]["rewards"]["coin"], 2000, "weekly rewards parsed (milestone format)")
	eq(DailyModel.parse(null), null, "null")
	eq(DailyModel.parse({"missions": "x"}), null, "malformed")


func test_parse_cleans_bad_entries() -> void:
	var p = DailyModel.parse({"missions": [
		{"id": "a", "state": "weird", "goto": "moon", "required": 5, "progress": 99},
		{"id": "", "state": "claimable"}, "bad",
		{"id": "b", "required": 0, "progress": -3},
	], "chests": [{"id": "c", "state": "odd", "threshold": 20}, {"state": "locked"}], "weekly": null})
	eq(p["missions"].size(), 2, "bad missions skipped")
	eq(p["missions"][0]["state"], DailyModel.PROGRESS, "unknown state: not done")
	eq(p["missions"][0]["goto"], DailyModel.GOTO_NONE, "unknown goto: none")
	eq(p["missions"][0]["progress"], 5, "progress capped at the requirement")
	eq(p["missions"][1]["required"], 1, "required at least 1")
	eq(p["missions"][1]["progress"], 0, "no negative progress")
	eq(p["chests"].size(), 1, "chest without id skipped")
	eq(p["chests"][0]["state"], DailyModel.LOCKED, "unknown chest state: locked")
	eq(p["weekly"], [], "no weekly")
	eq(p["day_reset"], -1, "no reset time")


func test_rows_sorted_claimable_progress_claimed() -> void:
	var p = DailyModel.parse(_data())
	var ids: Array = DailyModel.sorted_missions(p["missions"]).map(func(m): return m["id"])
	eq(ids, ["win1", "kill3", "play3", "dmg", "shop", "login", "upg"], "claimable, progress, claimed; server order inside")
	eq(p["missions"][0]["id"], "login", "the parsed list keeps the server order")


func test_buttons() -> void:
	eq(DailyModel.button(_m("a", "progress", 1, 3, "play")), {"text": "Đi ngay", "action": "go", "enabled": true}, "play")
	eq(DailyModel.button(_m("a", "progress", 0, 1, "shop"))["action"], DailyModel.ACTION_GO, "shop")
	eq(DailyModel.button(_m("a", "progress", 0, 1, "equipment"))["action"], DailyModel.ACTION_GO, "equipment")
	eq(DailyModel.button(_m("a", "progress", 0, 1, "none")), {"text": "Chưa xong", "action": "none", "enabled": false}, "nowhere to go")
	eq(DailyModel.button(_m("a", "claimable", 1, 1)), {"text": "Nhận", "action": "claim", "enabled": true}, "claimable")
	eq(DailyModel.button(_m("a", "claimed", 1, 1)), {"text": "Đã nhận", "action": "none", "enabled": false}, "claimed")


func test_progress_text() -> void:
	eq(DailyModel.progress_text(_m("a", "progress", 1, 3)), "1/3", "small")
	eq(DailyModel.progress_text(_m("a", "progress", 1250, 3000)), "1.250/3.000", "thousands")
	eq(DailyModel.progress_text(_m("a", "progress", 9, 3)), "3/3", "capped")
	near(DailyModel.progress_ratio(_m("a", "progress", 1, 4)), 0.25, 0.0001, "ratio")


func test_bar_fill_between_thresholds() -> void:
	var t := [20, 40, 60, 80, 100]
	near(DailyModel.bar_fill(0, t), 0.0, 0.0001, "empty")
	near(DailyModel.bar_fill(10, t), 0.1, 0.0001, "half way to the first chest")
	near(DailyModel.bar_fill(20, t), 0.2, 0.0001, "at the first chest")
	near(DailyModel.bar_fill(50, t), 0.5, 0.0001, "between 40 and 60")
	near(DailyModel.bar_fill(140, t), 1.0, 0.0001, "past the last")
	var w := [150, 300, 450, 600]
	near(DailyModel.bar_fill(150, w), 0.25, 0.0001, "weekly first marker")
	near(DailyModel.bar_fill(375, w), 0.625, 0.0001, "weekly between markers")
	# Uneven thresholds: each step is the same length on the bar
	near(DailyModel.bar_fill(30, [10, 50]), 0.75, 0.0001, "uneven: half way from 10 to 50")
	near(DailyModel.bar_fill(5, [10, 50]), 0.25, 0.0001, "uneven: half way to the first")
	eq(DailyModel.bar_fill(5, []), 0.0, "no markers")
	near(DailyModel.marker_at(0, 5), 0.2, 0.0001, "first marker")
	near(DailyModel.marker_at(4, 5), 1.0, 0.0001, "last marker at the end")


func test_countdowns() -> void:
	var reset := Fmt.unix_time("2026-10-21T17:00:00Z")
	eq(DailyModel.day_countdown(reset, reset - (5 * 3600 + 12 * 60 + 33)), "Làm mới sau 05:12:33", "day")
	eq(DailyModel.day_countdown(reset, reset + 10), "Làm mới sau 00:00:00", "past: zero")
	eq(DailyModel.day_countdown(-1, reset), "", "unknown")
	eq(DailyModel.clock(49 * 3600), "49:00:00", "hours past a day")
	eq(DailyModel.week_countdown(reset, reset - (3 * 86400 + 5 * 3600 + 12 * 60 + 40)), "Làm mới sau 3 ngày 05:12", "week")
	eq(DailyModel.week_countdown(reset, reset - 3661), "Làm mới sau 01:01:01", "under a day")
	eq(DailyModel.seconds_left(reset, reset - 5), 5, "seconds left")


func test_claimable_count_and_lookup() -> void:
	var p = DailyModel.parse(_data())
	eq(DailyModel.claimable_count(p), 4, "2 missions + chest 40 + weekly 150")
	eq(DailyModel.claimable_count(null), 0, "not loaded")
	eq(DailyModel.mission(p, "dmg")["required"], 3000, "mission by id")
	eq(DailyModel.mission(p, "nope"), {}, "missing mission")
	eq(DailyModel.chest(p, "chest_w150")["track"], "weekly", "weekly by id")
	eq(DailyModel.chest(null, "chest_d20"), {}, "not loaded")


func test_chest_texts_and_rewards() -> void:
	eq(DailyModel.chest_title(_c("x", "daily", 40, "locked")), "Rương 40 năng động", "daily")
	eq(DailyModel.chest_title(_c("x", "weekly", 300, "locked")), "Quà tuần 300 năng động", "weekly")
	eq(DailyModel.chest_hint(_c("x", "daily", 60, "locked"), 40), "Cần 60 năng động (đang có 40)", "locked hint")
	eq(DailyModel.chest_hint(_c("x", "daily", 20, "claimed"), 40), "Đã nhận", "claimed hint")
	var p = DailyModel.parse({"missions": [], "chests": [_c("d80", "daily", 80, "locked",
		{"coin": 500, "items": [{"kind": "item", "id": "medkit", "qty": 2}, {"kind": "stone", "level": 1, "qty": 3}]})]})
	var lines := DailyModel.reward_lines(p["chests"][0]["rewards"])
	eq(lines.map(func(l): return l["text"]), ["500 xu", "3 × Đá cấp 1", "2 × Hộp cứu thương"], "item lines named")


func test_claim_error_texts() -> void:
	const ErrorText := preload("res://screens/home/error_text.gd")
	eq(ErrorText.mission({"status": 409, "code": "MISSION_ALREADY_CLAIMED"}), "Nhiệm vụ này đã nhận rồi", "already")
	eq(ErrorText.mission({"status": 400, "code": "CHEST_LOCKED"}), "Chưa đủ năng động để nhận", "locked")
	eq(ErrorText.mission({"status": 0, "code": ""}), ErrorText.OFFLINE, "offline")
	eq(ErrorText.mission({"status": -1, "code": "BUSY"}), "Đang nhận thưởng, chờ chút", "busy")
	eq(ErrorText.mission({"status": 500, "code": "X", "message": "boom"}), "Nhận thưởng thất bại: boom", "other: the server's message")
