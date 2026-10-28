extends "res://tests/test_case.gd"
## match/boss/boss_result_model.gd: the boss result's title, damage ranking, MVP, the boss's HP
## left and my rewards (the run's table, items named from the game data).

const BossFixture := preload("res://tests/boss_fixture.gd")
const BossResultModel := preload("res://match/boss/boss_result_model.gd")
const ResultModel := preload("res://match/result_model.gd")

const PLAYERS := {
	"me": {"playerId": "me", "displayName": "Tôi", "teamId": 1, "characterId": "rookie"},
	"p2": {"playerId": "p2", "displayName": "Bạn", "teamId": 1, "characterId": "tanko"},
	"bot_1a": {"playerId": "bot_1a", "displayName": "Bot Mây", "teamId": 1, "characterId": "spark", "isBot": true},
	"boss_steel_robot": {"playerId": "boss_steel_robot", "displayName": "Rô-bốt Thép", "teamId": 2, "role": "boss", "bossId": "steel_robot"},
	"minion_drone_1": {"playerId": "minion_drone_1", "teamId": 2, "role": "minion", "minionId": "drone"}}

const WIN := {"winningTeam": 1, "result": "boss_defeated", "mvpPlayerId": "p2",
	"boss": {"bossId": "steel_robot", "result": "boss_defeated", "round": 9, "turnLimit": 15, "bossHp": 0, "bossMaxHp": 12000,
		"bossDamage": {"me": 4000, "p2": 6000, "bot_1a": 2000}},
	"rewards": {"me": {"expGained": 393, "coinGained": 1058, "levelUp": false, "bossDamage": 4000, "minionDamage": 1000,
		"bonusRun": true, "bonusRunsLeft": 2, "items": [{"itemId": "medkit", "quantity": 2}, {"itemId": "teleport", "quantity": 1}]}}}


func test_titles() -> void:
	eq(BossResultModel.title_text("boss_defeated"), "CHIẾN THẮNG", "won: the same title as any match's win")
	eq(BossResultModel.title_text("party_defeated"), "Cả đội đã gục", "the party fell")
	eq(BossResultModel.title_text("boss_escaped"), "Boss đã trốn thoát", "it escaped")
	eq(BossResultModel.result_of({"winningTeam": 2, "boss": {"result": "boss_escaped"}}, 1), "boss_escaped", "from the boss block")
	eq(BossResultModel.result_of({"winningTeam": 1}, 1), "boss_defeated", "no result: by the winner")
	eq(BossResultModel.result_of({"winningTeam": 2}, 1), "party_defeated", "lost")


func test_ranking_and_mvp() -> void:
	BossFixture.take()
	var info := BossResultModel.info(WIN, PLAYERS, "me", "steel_robot", WIN["rewards"]["me"])
	var rows: Array = info["ranking"]
	eq(rows.map(func(r): return r["playerId"]), ["p2", "me", "bot_1a"], "most damage first, the boss side left out")
	eq(rows.map(func(r): return r["ratio"]), [1.0, 4000.0 / 6000.0, 2000.0 / 6000.0], "bars to the top damage")
	eq(rows.map(func(r): return r["mvp"]), [true, false, false], "the server's MVP")
	check(rows[1]["mine"] and rows[2]["isBot"], "me and the bot")
	eq(info["outcome"], ResultModel.WIN, "a win")
	eq(info["round_text"], "Vòng 9/15", "the round")
	eq([info["boss"]["name"], info["boss"]["hp_text"], info["boss"]["art"]], ["Rô-bốt Thép", "0 / 12.000", "steel_robot"], "the boss")
	var d: Dictionary = WIN.duplicate(true)
	d.erase("mvpPlayerId")
	eq(BossResultModel.mvp_of(d, PLAYERS, "me"), "p2", "no MVP sent: the most damage")
	d["boss"]["bossDamage"] = {}
	eq(BossResultModel.mvp_of(d, PLAYERS, "me"), "", "nobody hit it")
	eq(BossResultModel.ranking(d, PLAYERS, "me", "")[0]["playerId"], "me", "ties: me first")


func test_rewards() -> void:
	BossFixture.take()
	var r := BossResultModel.reward(WIN["rewards"]["me"], "")
	check(r["ok"], "granted")
	eq([r["exp"], r["coin"], r["boss_damage"], r["minion_damage"]], [393, 1058, 4000, 1000], "numbers")
	eq(r["items"].map(func(i): return [i["itemId"], i["qty"]]), [["medkit", 2], ["teleport", 1]], "items")
	check(str(r["items"][0]["name"]) != "medkit" and str(r["items"][0]["name"]) != "", "named from the game data")
	eq([r["bonus_run"], r["gift_text"]], [true, "×2"], "a big-reward run: the gift box lit, 2 left")
	check(not r.has("badge") and not r.has("left_text"), "no run sentence")
	eq(r["damage_text"], "Sát thương boss 4.000", "my damage")
	var normal := BossResultModel.reward({"expGained": 10, "coinGained": 20, "bonusRun": false, "bonusRunsLeft": 0}, "")
	eq([normal["bonus_run"], normal["gift_text"], normal["items"]], [false, "×0", []], "a normal run: dimmed, none left")
	eq(BossResultModel.reward({"expGained": 1}, "")["gift_text"], "", "runs left unknown: no count")
	check(not BossResultModel.reward(null, "")["ok"], "rewards null: not granted")


func test_lose_info() -> void:
	BossFixture.take()
	var d := {"winningTeam": 2, "result": "party_defeated", "boss": {"bossId": "lava_crab", "round": 6, "turnLimit": 15,
		"bossHp": 9000, "bossMaxHp": 18000, "bossDamage": {"me": 9000}}}
	var info := BossResultModel.info(d, PLAYERS, "me", "", null)
	eq([info["outcome"], info["title"], info["boss"]["ratio"]], [ResultModel.LOSE, "Cả đội đã gục", 0.5], "lost")
	eq(info["boss"]["boss_id"], "lava_crab", "the boss block's boss")
	eq(info["ranking"][0]["playerId"], "me", "my damage first")


## The podium: a step per party player, left to right #3, #1, #2, #4, #1 tallest down to #4;
## a smaller party keeps the order of the ranks it has; 0 damage still stands on a step.
func test_podium_order_and_heights() -> void:
	BossFixture.take()
	var players: Dictionary = PLAYERS.duplicate(true)
	players["p4"] = {"playerId": "p4", "displayName": "Bốn", "teamId": 1, "characterId": "flora"}
	var d: Dictionary = WIN.duplicate(true)
	d["boss"]["bossDamage"]["p4"] = 0
	var info := BossResultModel.info(d, players, "me", "steel_robot", null)
	var steps: Array = info["podium"]
	eq(steps.map(func(s): return s["rank"]), [3, 1, 2, 4], "ranks left to right")
	eq(steps.map(func(s): return s["entry"]["playerId"]), ["bot_1a", "p2", "me", "p4"], "the players on them")
	var h: Array = steps.map(func(s): return s["step_h"])
	check(h[1] > h[2] and h[2] > h[0] and h[0] > h[3], "#1 tallest, then #2, #3, #4 lowest (%s)" % [h])
	eq(steps[3]["entry"]["damage"], 0, "no damage: still a step")
	check(steps[1]["entry"]["mvp"], "the MVP on #1")
	var ranks := func(n: int) -> Array:
		var rows: Array = []
		for i in n:
			rows.append({"playerId": "p%d" % i})
		return BossResultModel.podium(rows).map(func(s): return s["rank"])
	eq([ranks.call(1), ranks.call(2), ranks.call(3), ranks.call(0)], [[1], [1, 2], [3, 1, 2], []], "smaller parties")
	eq(ranks.call(5), [5, 3, 1, 2, 4], "a fifth at an end, on the lowest step")
	eq(BossResultModel.step_height(9), BossResultModel.step_height(4), "past 4: the lowest")


func test_subtitle() -> void:
	BossFixture.take()
	var win := BossResultModel.info(WIN, PLAYERS, "me", "steel_robot", null)
	eq(BossResultModel.subtitle(win), "Rô-bốt Thép · Vòng 9/15", "a win: the boss and the round")
	var d := {"winningTeam": 2, "result": "boss_escaped", "boss": {"bossId": "lava_crab", "round": 15, "turnLimit": 15,
		"bossHp": 3400, "bossMaxHp": 12000, "bossDamage": {"me": 9000}}}
	var lose := BossResultModel.info(d, PLAYERS, "me", "", null)
	eq(BossResultModel.subtitle(lose), "Cua Dung Nham · Vòng 15/15 · Máu boss còn 3.400 / 12.000", "a loss: the HP left too")
