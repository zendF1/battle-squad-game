extends "res://tests/test_case.gd"
## MilestoneModel: parsing GET /milestones, sub-tracks, node labels per track, progress text,
## reward lines (unknown kinds ignored) and the badge counts.

const MilestoneModel := preload("res://screens/home/milestone_model.gd")


static func _node(id: String, track: String, target: String, required: int, progress: int, state: String,
		rewards: Dictionary = {"coin": 100}, description: String = "") -> Dictionary:
	return {"id": id, "track": track, "target": target, "required": required, "progress": progress, "state": state,
		"rewards": rewards, "description": description}


func _data() -> Dictionary:
	return {"claimableCount": 4, "tracks": [
		{"track": "character", "nodes": [
			_node("c5", "character", "char_level", 5, 37, "claimed"),
			_node("c40", "character", "char_level", 40, 37, "locked", {"gem": 50, "items": [{"kind": "stone", "level": 7, "qty": 2}]}),
		]},
		{"track": "upgrade", "nodes": [
			_node("s6", "upgrade", "set_level:6", 6, 4, "locked"),
			_node("w14", "upgrade", "weapon_upgrade_peak", 14, 16, "claimable", {"gem": 100}, "Mở khoá hào quang tím sau lưng"),
			_node("u14", "upgrade", "upgrade_peak", 14, 7, "locked"),
			_node("u3", "upgrade", "upgrade_peak", 3, 7, "claimable"),
		]},
		{"track": "combat", "nodes": [
			_node("m50", "combat", "matches", 50, 63, "claimable", {"coin": 3000, "gem": 10}),
			_node("m100", "combat", "matches", 100, 63, "locked"),
			_node("cw10", "combat", "char_wins", 10, 4, "locked"),
			_node("wn5", "combat", "wins", 5, 9, "claimable"),
		]},
		{"track": "rank", "nodes": [
			_node("r3", "rank", "rank_peak", 3, 2, "locked"),
			_node("title", "rank", "rank_peak", 2, 2, "claimable", {"items": [{"kind": "title", "id": "veteran"}]}),
		]},
	]}


func test_parse_and_counts() -> void:
	var p = MilestoneModel.parse(_data())
	check(p != null, "parsed")
	eq(MilestoneModel.claimable_total(p), 4, "claimable over the tracks (the title-only node left out)")
	eq(MilestoneModel.claimable_in(p, "upgrade"), 2, "upgrade tab dot")
	eq(MilestoneModel.claimable_in(p, "character"), 0, "character tab: none")
	eq(MilestoneModel.nodes(p, "rank").size(), 1, "a node with only an unknown reward kind is left out")
	eq(MilestoneModel.parse(null), null, "null")
	eq(MilestoneModel.parse({"tracks": "x"}), null, "malformed")
	var odd = MilestoneModel.parse({"tracks": [{"track": "combat", "nodes": [{"id": "x", "state": "weird", "rewards": {"coin": 5}}, "bad", {}]}]})
	eq(MilestoneModel.nodes(odd, "combat").size(), 1, "bad nodes skipped")
	eq(MilestoneModel.nodes(odd, "combat")[0]["state"], "locked", "unknown state is locked")
	eq(MilestoneModel.claimable_total(null), 0, "not loaded")


func test_groups_follow_the_sub_track_order() -> void:
	var p = MilestoneModel.parse(_data())
	var up := MilestoneModel.groups(p, "upgrade")
	eq(up.map(func(g): return g["title"]), ["Cường hoá", "Vũ khí", "Bộ trang bị hoàn chỉnh"], "upgrade groups")
	eq(up[0]["nodes"].map(func(n): return n["id"]), ["u14", "u3"], "server order kept inside a group")
	var combat := MilestoneModel.groups(p, "combat")
	eq(combat.map(func(g): return g["title"]), ["Số trận", "Số trận thắng", "Thắng với 1 nhân vật"], "combat groups")
	eq(MilestoneModel.groups(null, "combat"), [], "not loaded")
	var other = MilestoneModel.parse({"tracks": [{"track": "combat", "nodes": [_node("z", "combat", "kills", 9, 1, "locked")]}]})
	eq(MilestoneModel.groups(other, "combat")[0]["title"], "Khác", "unknown target")


func test_labels_per_track() -> void:
	var cases := [
		[_node("a", "character", "char_level", 20, 12, "locked"), "Cấp 20", "12/20", "1 nhân vật đạt cấp 20"],
		[_node("b", "upgrade", "upgrade_peak", 14, 7, "locked"), "+14", "+7/+14", "1 trang bị đạt +14"],
		[_node("c", "upgrade", "weapon_upgrade_peak", 16, 14, "locked"), "Vũ khí +16", "+14/+16", "Vũ khí đạt +16"],
		[_node("d", "upgrade", "set_level:6", 6, 4, "locked"), "Cả bộ +6", "4/6 món", "Cả bộ trang bị +6"],
		[_node("e", "combat", "matches", 1000, 37, "locked"), "1.000 trận", "37/1.000", "Chơi 1.000 trận"],
		[_node("f", "combat", "wins", 25, 9, "locked"), "25 thắng", "9/25", "Thắng 25 trận"],
		[_node("g", "combat", "char_wins", 10, 4, "locked"), "10 thắng", "4/10", "Thắng 10 trận với 1 nhân vật"],
		[_node("h", "rank", "rank_peak", 3, 2, "locked"), "Vàng", "Đang: Bạc", "Đạt hạng Vàng"],
		[_node("i", "rank", "rank_peak", 6, 0, "locked"), "Cao thủ", "Đang: Chưa có hạng", "Đạt hạng Cao thủ"],
	]
	for c in cases:
		var n: Dictionary = c[0]
		eq(MilestoneModel.threshold(n), c[1], "%s threshold" % n["target"])
		eq(MilestoneModel.progress_text(n), c[2], "%s progress" % n["target"])
		eq(MilestoneModel.title(n), c[3], "%s title" % n["target"])
	var over := _node("x", "combat", "matches", 50, 63, "claimable")
	eq(MilestoneModel.progress_text(over), "", "no progress on a claimable node")
	eq(MilestoneModel.state_text(over), "Nhận", "claimable")
	over["state"] = "claimed"
	eq(MilestoneModel.state_text(over), "Đã nhận", "claimed")
	over["state"] = "locked"
	over["progress"] = 99
	eq(MilestoneModel.progress_text(over), "50/50", "progress capped")


func test_reward_lines() -> void:
	var r := MilestoneModel.parse_rewards({"coin": 2000, "gem": 30, "items": [
		{"kind": "stone", "level": 4, "qty": 3}, {"kind": "title", "id": "veteran"}, {"kind": "item", "id": "medkit", "qty": 2},
		{"kind": "stone", "level": 9, "qty": 0}, "bad"]})
	var lines := MilestoneModel.reward_lines(r)
	eq(lines.map(func(l): return l["text"]), ["2.000 xu", "30 kim cương", "3 × Đá cấp 4", "2 × medkit"], "popup lines")
	eq(lines.map(func(l): return l["short"]), ["2.000", "30", "×3", "×2"], "node amounts")
	eq(lines[2]["level"], 4, "stone level for its icon")
	eq(MilestoneModel.reward_lines(MilestoneModel.parse_rewards(null)), [], "nothing")
	eq(MilestoneModel.reward_lines({"coin": 0, "gem": 0, "items": [{"kind": "title", "id": "x", "qty": 1}]}), [], "unknown kind only")


func test_focus_and_badge() -> void:
	var nodes := [_node("a", "", "wins", 1, 1, "claimed"), _node("b", "", "wins", 2, 1, "locked"), _node("c", "", "wins", 3, 3, "claimable")]
	eq(MilestoneModel.focus_index(nodes), 2, "first claimable")
	nodes[2]["state"] = "locked"
	eq(MilestoneModel.focus_index(nodes), 1, "else first locked")
	eq(MilestoneModel.focus_index([_node("a", "", "wins", 1, 1, "claimed")]), 0, "all claimed: the last")
	eq(MilestoneModel.focus_index([]), 0, "empty")
	eq(MilestoneModel.badge_text(0), "", "hidden at 0")
	eq(MilestoneModel.badge_text(-1), "", "unknown")
	eq(MilestoneModel.badge_text(3), "3", "count")
	eq(MilestoneModel.badge_text(12), "9+", "capped")


func test_claim_error_texts() -> void:
	const ErrorText := preload("res://screens/home/error_text.gd")
	eq(ErrorText.milestone({"status": 409, "code": "MILESTONE_ALREADY_CLAIMED"}), "Mốc này đã nhận rồi", "already")
	eq(ErrorText.milestone({"status": 400, "code": "MILESTONE_NOT_REACHED"}), "Chưa đạt mốc này", "not reached")
	eq(ErrorText.milestone({"status": 0, "code": ""}), ErrorText.OFFLINE, "offline")
	eq(ErrorText.milestone({"status": -1, "code": "BUSY"}), "Đang nhận thưởng, chờ chút", "busy")
	eq(ErrorText.milestone({"status": 500, "code": "X", "message": "boom"}), "Nhận thưởng thất bại: boom", "other")


func test_rewards_merge_and_sort_stones() -> void:
	var r := MilestoneModel.parse_rewards({"items": [{"kind": "stone", "level": 9, "qty": 1}, {"kind": "stone", "level": 7, "qty": 2},
		{"kind": "stone", "level": 7, "qty": 1}]})
	eq(MilestoneModel.reward_lines(r).map(func(l): return l["text"]), ["3 × Đá cấp 7", "1 × Đá cấp 9"], "merged, by level")
