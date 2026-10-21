extends "res://tests/test_case.gd"

const MatchmakingModel := preload("res://screens/ranked/matchmaking_model.gd")


static func _p(id: String, extra: Dictionary = {}) -> Dictionary:
	var p := {"playerId": id, "displayName": id.capitalize(), "characterId": "spark", "isBot": id.begins_with("bot_"),
		"level": 40, "rating": 1050, "tier": "silver", "division": 2, "titleId": ""}
	p.merge(extra, true)
	return p


static func _found(team1: Array, team2: Array) -> Dictionary:
	return {"roomId": "r", "matchId": "m", "mapId": "grassland_valley", "mode": "ranked_2v2",
		"teams": [{"teamId": 1, "players": team1}, {"teamId": 2, "players": team2}]}


func _ids(slots: Array) -> Array:
	return slots.map(func(p): return "" if p.is_empty() else p["playerId"])


func test_my_team_left_me_first() -> void:
	var teams := MatchmakingModel.teams_of_found(_found([_p("p1"), _p("p2")], [_p("me"), _p("bot_ab12")]))
	eq(_ids(MatchmakingModel.slots(teams, "me")), ["me", "bot_ab12", "p1", "p2"], "my team left, me first")
	eq(_ids(MatchmakingModel.slots(teams, "p2")), ["p2", "p1", "me", "bot_ab12"], "the other side's view")
	eq(_ids(MatchmakingModel.slots(teams, "ghost")), ["p1", "p2", "me", "bot_ab12"], "not in it: the first team left")


func test_short_teams_are_padded() -> void:
	var teams := MatchmakingModel.teams_of_found(_found([_p("me")], []))
	eq(_ids(MatchmakingModel.slots(teams, "me")), ["me", "", "", ""], "empty slots")
	eq(_ids(MatchmakingModel.slots({}, "me")), ["", "", "", ""], "no teams")


func test_reveal_order_skips_me() -> void:
	var teams := MatchmakingModel.teams_of_found(_found([_p("me"), _p("mate")], [_p("bot_1"), _p("bot_2")]))
	var slots := MatchmakingModel.slots(teams, "me")
	eq(MatchmakingModel.reveal_order(slots, "me"), [1, 2, 3], "teammate then the enemies")
	var short := MatchmakingModel.slots(MatchmakingModel.teams_of_found(_found([_p("me")], [_p("e")])), "me")
	eq(MatchmakingModel.reveal_order(short, "me"), [2], "only the filled ones")


func test_parse_player() -> void:
	var bot := MatchmakingModel.parse_player({"playerId": "bot_x1", "characterId": "", "level": 1})
	eq(bot["isBot"], true, "a bot by its id")
	eq(bot["displayName"], "Bot", "a bot's default name")
	eq(bot["characterId"], "rookie", "default character")
	eq(bot["tier"], "", "no rank given")
	eq(MatchmakingModel.level_text(bot), "Lv.1 · Máy", "bot line")
	var p := MatchmakingModel.parse_player({"playerId": "p1", "displayName": "Smoke", "rating": 1250})
	eq([p["tier"], p["division"]], ["gold", 3], "tier from the rating")
	eq(MatchmakingModel.rank_text(p), "Vàng III", "rank line")
	eq(MatchmakingModel.level_text(p), "", "no level")
	eq(MatchmakingModel.parse_player({"displayName": "x"}), {}, "no id")
	eq(MatchmakingModel.parse_player("x"), {}, "not a player")
	var bad := MatchmakingModel.teams_of_found({"teams": [{"teamId": 1, "players": [{"playerId": "a"}, "junk", {}]}, "junk"]})
	eq(bad[1].size(), 1, "bad entries skipped")
	eq(MatchmakingModel.teams_of_found({"roomId": "r", "matchId": "m"}), {}, "an older MatchFound has no teams")


func test_teams_from_match_started() -> void:
	var started := {"mode": "ranked_2v2", "players": {
		"bot_b": {"playerId": "bot_b", "displayName": "Bot b", "teamId": 2, "characterId": "rookie", "isBot": true},
		"me": {"playerId": "me", "displayName": "Smoke", "teamId": 1, "characterId": "spark", "isBot": false},
		"bot_a": {"playerId": "bot_a", "displayName": "Bot a", "teamId": 2, "characterId": "rookie", "isBot": true},
		"bot_m": {"playerId": "bot_m", "displayName": "Bot m", "teamId": 1, "characterId": "rookie", "isBot": true}}}
	var slots := MatchmakingModel.slots(MatchmakingModel.teams_of_started(started), "me")
	eq(_ids(slots), ["me", "bot_m", "bot_a", "bot_b"], "from MatchStarted")
	eq(slots[0]["characterId"], "spark", "character kept")


func test_my_player_while_searching() -> void:
	var p := MatchmakingModel.my_player("me", "Smoke", "flora", 12, {"rating": 1300, "tier": "gold", "division": 2})
	eq([p["displayName"], p["characterId"], p["level"]], ["Smoke", "flora", 12], "profile")
	eq(MatchmakingModel.rank_text(p), "Vàng II", "rank")
	eq(MatchmakingModel.rank_text(MatchmakingModel.my_player("me", "S", "rookie", 1, {})), "Bạc III", "not loaded: the default")
