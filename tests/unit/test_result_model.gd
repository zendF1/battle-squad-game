extends "res://tests/test_case.gd"

const ResultModel := preload("res://match/result_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")

const PLAYERS := {
	"me": {"playerId": "me", "displayName": "Smoke", "teamId": 2, "characterId": "spark", "isBot": false,
		"title": {"id": "smith", "name": "Thợ rèn", "rarity": "blue"}},
	"mate": {"playerId": "mate", "displayName": "Mít", "teamId": 2, "characterId": "flora", "isBot": false},
	"bot_a": {"playerId": "bot_a", "displayName": "Bot a", "teamId": 1, "characterId": "rookie", "isBot": true},
	"bot_b": {"playerId": "bot_b", "displayName": "Bot b", "teamId": 1, "characterId": "rookie", "isBot": true},
}


func test_outcome_and_title() -> void:
	eq(ResultModel.outcome(2, 2), ResultModel.WIN, "win")
	eq(ResultModel.outcome(2, 1), ResultModel.LOSE, "lose")
	eq(ResultModel.outcome(2, 0), ResultModel.DRAW, "draw")
	eq(ResultModel.title_text(ResultModel.WIN), "CHIẾN THẮNG", "win title")
	eq(ResultModel.title_text(ResultModel.LOSE), "THẤT BẠI", "lose title")
	eq(ResultModel.title_text(ResultModel.DRAW), "HOÀ", "draw title")


func test_winners_left_me_first() -> void:
	eq(ResultModel.sides(PLAYERS, "me", 2), {"left": ["me", "mate"], "right": ["bot_a", "bot_b"]}, "my win")
	eq(ResultModel.sides(PLAYERS, "me", 1), {"left": ["bot_a", "bot_b"], "right": ["me", "mate"]}, "my loss: the winners left")
	eq(ResultModel.sides(PLAYERS, "me", 0), {"left": ["me", "mate"], "right": ["bot_a", "bot_b"]}, "a draw: my team left")
	eq(ResultModel.sides(PLAYERS, "mate", 2)["left"], ["mate", "me"], "the viewer first")


func test_mvp() -> void:
	var order := ["me", "mate", "bot_a", "bot_b"]
	eq(ResultModel.mvp(PLAYERS, order, {}, "bot_b", {}), "bot_b", "the server's pick")
	eq(ResultModel.mvp(PLAYERS, order, {}, "ghost", {"mate": 10}), "mate", "an unknown pick: the tally")
	var stats := {"me": {"damageDealt": 900}, "mate": {"damageDealt": 1200}, "bot_a": {"damageDealt": 300}}
	eq(ResultModel.mvp(PLAYERS, order, stats, "", {"me": 5000}), "mate", "most damage from the stats")
	eq(ResultModel.mvp(PLAYERS, order, null, null, {"me": 400, "bot_a": 400}), "me", "a tie: the first")
	eq(ResultModel.mvp(PLAYERS, order, null, null, {}), "", "nobody dealt any")
	eq(ResultModel.damage_of("mate", stats, {}), 1200, "damage from stats")
	eq(ResultModel.damage_of("bot_b", stats, {"bot_b": 70}), 70, "damage from the tally")
	eq(ResultModel.damage_of("bot_b", null, {}), -1, "unknown")
	eq(ResultModel.damage_text(1240), "Sát thương 1.240", "damage line")
	eq(ResultModel.damage_text(-1), "", "no line")


func test_entries() -> void:
	var me := ResultModel.entry("me", PLAYERS["me"], {}, "me", 40, {"rating": 1300, "tier": "gold", "division": 2}, 900)
	eq([me["mine"], me["tier"], me["division"], me["level"]], [true, "gold", 2, 40], "me: my rank and level")
	eq(me["title"]["name"], "Thợ rèn", "title from the match player")
	eq(ResultModel.level_text(me), "Lv.40", "level line")
	var mate := ResultModel.entry("mate", PLAYERS["mate"], {"level": 33, "tier": "silver", "division": 1}, "me", 40, {}, -1)
	eq([mate["mine"], mate["tier"], mate["level"], mate["title"]], [false, "silver", 33, {}], "roster rank")
	var bot := ResultModel.entry("bot_a", PLAYERS["bot_a"], {}, "me", 40, {}, 0)
	eq([bot["tier"], ResultModel.level_text(bot)], ["", ""], "a quick play bot: no line")
	var ranked_bot := ResultModel.entry("bot_a", PLAYERS["bot_a"], {"level": 30}, "me", 40, {}, 0)
	eq(ResultModel.level_text(ranked_bot), "Lv.30 · Máy", "a ranked bot")
	eq(ResultModel.entry("me", PLAYERS["me"], {}, "me", 7, {}, 0)["tier"], "", "my rank not loaded")


func test_rewards() -> void:
	var r := ResultModel.reward({"expGained": 120, "coinGained": 200, "ratingChange": 0, "levelUp": true, "newLevel": 41,
		"charLevelUp": true, "charNewLevel": 13}, "pvp_1v1")
	eq([r["ok"], r["exp"], r["coin"], r["level_up"], r["new_level"], r["char_level_up"], r["char_level"]],
		[true, 120, 200, true, 41, true, 13], "fields")
	eq(r["rank"], {}, "no rating outside ranked")
	var ranked := ResultModel.reward({"expGained": 50, "coinGained": 80, "ratingChange": 22, "newRating": 1212,
		"newTier": "gold", "newDivision": 3, "oldRating": 1190, "oldTier": "silver", "oldDivision": 1}, "ranked_2v2")
	eq(ranked["rank"]["move"], 1, "promoted")
	eq(ResultModel.reward(null, "ranked_2v2")["ok"], false, "granting failed")
	eq(ResultModel.reward({"expGained": -3}, "pvp_1v1")["exp"], 0, "never negative")


func test_exp_steps() -> void:
	eq(ResultModel.exp_steps(40, 1000, 400), {"from": 0.25, "to": 0.35, "levels": 0, "level": 40}, "inside the level")
	eq(ResultModel.exp_steps(2, 150, 100), {"from": 0.75, "to": 50.0 / 300.0, "levels": 1, "level": 3}, "one level up")
	eq(ResultModel.exp_steps(1, 0, 400), {"from": 0.0, "to": 100.0 / 300.0, "levels": 2, "level": 3}, "two levels")
	eq(ResultModel.exp_steps(0, -5, 0)["from"], 0.0, "bad input")


func test_buttons_and_countdown() -> void:
	eq(ResultModel.again_text("ranked_2v2", false), "Chơi tiếp", "ranked")
	eq(ResultModel.again_text("pvp_1v1", true), "Chơi lại", "quick play")
	eq(ResultModel.again_text("pvp_1v1", false), "", "nothing to replay")
	eq(ResultModel.countdown_text(19), "Tự động về sảnh sau 19 giây", "countdown")


func test_lobby_error_texts() -> void:
	eq(ErrorText.lobby_error({"error": {"code": "QUEUE_FAILED", "message": "x"}}), "Không vào được hàng chờ, hãy thử lại", "known")
	eq(ErrorText.lobby_error({"error": {"code": "LOADOUT_INVALID", "message": "You do not own item: medkit"}}),
		"Bạn chưa sở hữu vật phẩm Hộp cứu thương", "loadout like QuickPlay")
	eq(ErrorText.lobby_error({"code": "too_many_items", "message": "m"}), "Chỉ mang tối đa 3 vật phẩm", "flat")
	eq(ErrorText.lobby_error({"error": {"code": "X", "message": "boom"}}), "Lỗi ghép trận: boom", "unknown")
	eq(ErrorText.lobby_error(null), "Lỗi ghép trận, hãy thử lại", "nothing")
	eq(ErrorText.lobby_code({"error": {"code": "IN_ROOM"}}), "IN_ROOM", "code")


func _levels(raw: Dictionary) -> Dictionary:
	return ResultModel.reward(raw, "pvp_1v1")


func test_count_steps() -> void:
	eq(ResultModel.count_steps(3, 4), [4], "one level")
	eq(ResultModel.count_steps(3, 6), [4, 5, 6], "each level counted")
	eq(ResultModel.count_steps(5, 5), [], "no level")
	eq(ResultModel.count_steps(6, 5), [], "never down")


func test_level_ups_player_only() -> void:
	var r := _levels({"expGained": 120, "levelUp": true, "newLevel": 4})
	eq(ResultModel.level_ups(r, {"level": 3, "exp": 250}, "spark", "Spark"),
		[{"kind": "player", "from": 3, "to": 4, "steps": [4]}], "old from the profile, new from MatchEnded")


func test_level_ups_multiple_levels() -> void:
	var r := _levels({"expGained": 520, "levelUp": true, "newLevel": 5})
	eq(ResultModel.level_ups(r, {"level": 3, "exp": 250}, "spark", "Spark")[0]["steps"], [4, 5], "two levels")
	eq(ResultModel.level_ups(r, {}, "spark", "Spark")[0], {"kind": "player", "from": 4, "to": 5, "steps": [5]},
		"no profile: one level")
	eq(ResultModel.level_ups(r, {"level": 9, "exp": 0}, "spark", "Spark")[0]["from"], 4, "a stale profile: one level")
	var no_new := _levels({"expGained": 520, "levelUp": true})
	eq(ResultModel.level_ups(no_new, {"level": 3, "exp": 250}, "spark", "Spark")[0]["to"], 5,
		"no newLevel: from the EXP gained")


func test_level_ups_character_only() -> void:
	var r := _levels({"expGained": 120, "levelUp": false, "newLevel": 3, "charLevelUp": true, "charNewLevel": 13,
		"charLevelsGained": 3})
	eq(ResultModel.level_ups(r, {"level": 3, "exp": 0}, "spark", "Spark"),
		[{"kind": "character", "character_id": "spark", "name": "Spark", "from": 10, "to": 13, "steps": [11, 12, 13]}],
		"the character's levels gained")
	var no_count := _levels({"charLevelUp": true, "charNewLevel": 13})
	eq(ResultModel.level_ups(no_count, {}, "spark", "Spark")[0]["from"], 12, "no count: one level")


func test_level_ups_both_and_none() -> void:
	var r := _levels({"expGained": 520, "levelUp": true, "newLevel": 5, "charLevelUp": true, "charNewLevel": 13,
		"charLevelsGained": 1})
	var stages := ResultModel.level_ups(r, {"level": 3, "exp": 250}, "spark", "Spark")
	eq(stages.map(func(s): return s["kind"]), ["player", "character"], "the player first, then the character")
	eq(stages[1]["steps"], [13], "the character's step")
	eq(ResultModel.level_ups(_levels({"expGained": 50, "newLevel": 3}), {"level": 3, "exp": 0}, "spark", "Spark"), [],
		"no level up")
	eq(ResultModel.level_ups(ResultModel.reward(null, "pvp_1v1"), {}, "spark", "Spark"), [], "granting failed")


func test_podium_top() -> void:
	var a := {"playerId": "a", "damage": 300}
	var b := {"playerId": "b", "damage": 900}
	eq(ResultModel.podium_top([a, b], "a"), "a", "the MVP won: the top step")
	eq(ResultModel.podium_top([a, b], "x"), "b", "the MVP lost: the winner with the most damage")
	eq(ResultModel.podium_top([a], "a"), "", "one winner: one step")
	eq(ResultModel.podium_top([{"playerId": "a", "damage": 0}, {"playerId": "b", "damage": 0}], ""), "", "no damage: level")
