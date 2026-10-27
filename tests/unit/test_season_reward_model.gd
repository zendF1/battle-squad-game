extends "res://tests/test_case.gd"

const SeasonRewardModel := preload("res://screens/ranked/season_reward_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")

## A GET /rank/season-rewards answer, shaped like the contract (spec 8a).
const ANSWER := {"rewards": [
	{"seasonId": "s1", "seasonName": "Mùa 1", "grade": "trung_si", "division": 2, "rankPos": 57, "rankPoints": 1080,
		"coin": 5000, "gem": 20, "items": [{"kind": "chest", "id": "stone_chest", "qty": 2, "name": "Rương đá"}]},
	{"seasonId": "s2", "seasonName": "Mùa 2", "grade": "dai_tuong", "division": 1, "rankPos": 1, "rankPoints": 6120,
		"coin": 150000, "gem": 1500, "items": [{"kind": "chest", "id": "stone_chest", "qty": 25, "name": "Rương đá"},
		{"kind": "chest", "id": "equip_chest_16", "qty": 1, "name": "Rương trang bị +16"},
		{"kind": "chest", "id": "equip_chest_14", "qty": 1}]},
	{"seasonName": "no id"}]}


func test_parse() -> void:
	var list := SeasonRewardModel.parse(ANSWER)
	eq(list.size(), 2, "rows without a seasonId are skipped")
	eq([list[0]["seasonId"], list[0]["grade"], list[0]["division"], list[0]["coin"], list[0]["gem"]], ["s1", "trung_si", 2, 5000, 20],
		"fields")
	eq(list[1]["items"].size(), 3, "items")
	eq(SeasonRewardModel.parse({}), [], "nothing")
	eq(SeasonRewardModel.parse(null), [], "no data")


func test_heading_and_lines() -> void:
	var list := SeasonRewardModel.parse(ANSWER)
	eq(SeasonRewardModel.heading(list[0]), "Phần thưởng Mùa 1: Trung sĩ 2", "with the division")
	eq(SeasonRewardModel.heading(list[1]), "Phần thưởng Mùa 2: Đại tướng", "a general: no division")
	eq(SeasonRewardModel.standing_text(list[1]), "Hạng #1 · 6.120 điểm", "final standing")
	eq(SeasonRewardModel.lines(list[0]).map(func(l): return l["text"]), ["5.000 xu", "20 kim cương khoá", "2 × Rương đá"],
		"coin, locked gem, chests")
	var big := SeasonRewardModel.lines(list[1])
	eq(big[-1]["text"], "1 × Rương trang bị +14", "a missing name: the game data's")
	eq(big.map(func(l): return l["kind"]), ["coin", "gem", "chest", "chest", "chest"], "kinds")
	eq(SeasonRewardModel.lines({"coin": 0, "gem": 0, "items": []}), [], "nothing")


func test_claim_wallet() -> void:
	var claim := (ANSWER["rewards"][0] as Dictionary).duplicate(true)
	claim["wallet"] = {"coin": 12500, "gem": 120, "gemUnlocked": 30}
	eq(SeasonRewardModel.parse_one(claim)["seasonId"], "s1", "the claim answer is the same object")
	eq(SeasonRewardModel.wallet_of(claim), {"coin": 12500, "gem": 120, "gemUnlocked": 30}, "the wallet")
	eq(SeasonRewardModel.wallet_of({"wallet": {"coin": 5}}), {"coin": 5}, "only what it has")
	eq(SeasonRewardModel.wallet_of({}), {}, "none")


func test_season_end_preview_from_game_data() -> void:
	eq(GameData.season_rewards().size(), 18, "a reward per grade")
	eq(SeasonRewardModel.preview_text("binh_nhi"), "Thưởng cuối mùa: 2.000 xu · 1\u00a0×\u00a0Rương đá", "the lowest grade")
	eq(SeasonRewardModel.preview_text("dai_ta"),
		"Thưởng cuối mùa: 40.000 xu · 400 kim cương khoá · 10\u00a0×\u00a0Rương đá · 1\u00a0×\u00a0Rương trang bị +14", "Đại tá")
	eq(SeasonRewardModel.preview_text("wood"), "", "unknown grade")
	var rr := GameData.ranked_rewards()
	eq([int(rr.get("winCoin")), int(rr.get("lossCoin"))], [150, 60], "the ranked bonus is the game data's")


func test_stone_items_with_level() -> void:
	var r := SeasonRewardModel.parse_one({"seasonId": "s3", "grade": "ha_si", "division": 1, "coin": 0, "gem": 0,
		"items": [{"kind": "stone", "id": "", "level": 7, "qty": 2, "name": ""}]})
	eq(SeasonRewardModel.lines(r).map(func(l): return l["text"]), ["2 × Đá cấp 7"], "a stone item named by its level")
