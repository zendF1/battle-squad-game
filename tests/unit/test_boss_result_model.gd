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
	eq(BossResultModel.title_text("boss_defeated"), "Hạ boss thành công!", "won")
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
	eq([r["badge"], r["left_text"]], ["Lượt thưởng lớn", "Còn 2 lượt thưởng lớn hôm nay"], "a big-reward run")
	eq(r["damage_text"], "Sát thương boss 4.000", "my damage")
	var normal := BossResultModel.reward({"expGained": 10, "coinGained": 20, "bonusRun": false, "bonusRunsLeft": 0}, "")
	eq([normal["badge"], normal["left_text"], normal["items"]], ["Thưởng thường", "Hết lượt thưởng lớn hôm nay", []], "a normal run")
	check(not BossResultModel.reward(null, "")["ok"], "rewards null: not granted")


func test_lose_info() -> void:
	BossFixture.take()
	var d := {"winningTeam": 2, "result": "party_defeated", "boss": {"bossId": "lava_crab", "round": 6, "turnLimit": 15,
		"bossHp": 9000, "bossMaxHp": 18000, "bossDamage": {"me": 9000}}}
	var info := BossResultModel.info(d, PLAYERS, "me", "", null)
	eq([info["outcome"], info["title"], info["boss"]["ratio"]], [ResultModel.LOSE, "Cả đội đã gục", 0.5], "lost")
	eq(info["boss"]["boss_id"], "lava_crab", "the boss block's boss")
	eq(info["ranking"][0]["playerId"], "me", "my damage first")
