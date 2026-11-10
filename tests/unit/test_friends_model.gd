extends "res://tests/test_case.gd"
## screens/social/friends_model.gd: GET /friends (contracts/friends.md with level and characterId),
## nickname first, the relation and its Kết bạn button, paths, local changes.

const FriendsModel := preload("res://screens/social/friends_model.gd")

const ANSWER := {
	"friends": [{"playerId": "a1", "displayName": "SấmSét99", "nickname": "Bạn thân", "level": 12, "characterId": "rookie"},
		{"playerId": "a2", "displayName": "Gió", "nickname": "", "level": 3, "characterId": ""}],
	"incoming": [{"playerId": "d4", "displayName": "MâyXanh", "level": 7, "characterId": "tide"}],
	"outgoing": [{"playerId": "o5", "displayName": "Đá", "level": 1, "characterId": "tanko"}],
}


func test_parse() -> void:
	var m := FriendsModel.parse(ANSWER)
	eq(m["friends"].size(), 2, "friends")
	eq(m["incoming"][0]["level"], 7, "level")
	eq(m["incoming"][0]["characterId"], "tide", "character")
	eq(m["incoming"][0]["nickname"], "", "requests have no nickname")
	var old := FriendsModel.parse({"friends": [{"playerId": "x", "displayName": "X", "nickname": ""}], "incoming": [], "outgoing": []})
	eq(old["friends"][0]["level"], 0, "an older server: no level")
	check(FriendsModel.parse(null).is_empty(), "not an answer")
	eq(FriendsModel.parse({"friends": [{"displayName": "no id"}]})["friends"].size(), 0, "no id: dropped")


func test_names() -> void:
	var m := FriendsModel.parse(ANSWER)
	eq(FriendsModel.shown_name(m["friends"][0]), "Bạn thân", "nickname first")
	eq(FriendsModel.real_name(m["friends"][0]), "SấmSét99", "their name under it")
	eq(FriendsModel.shown_name(m["friends"][1]), "Gió", "no nickname: their name")
	eq(FriendsModel.real_name(m["friends"][1]), "", "not twice")


func test_relation_and_button() -> void:
	var m := FriendsModel.parse(ANSWER)
	eq(FriendsModel.relation(m, "a1", "me"), FriendsModel.FRIEND, "friend")
	eq(FriendsModel.relation(m, "d4", "me"), FriendsModel.INCOMING, "asked me")
	eq(FriendsModel.relation(m, "o5", "me"), FriendsModel.OUTGOING, "I asked")
	eq(FriendsModel.relation(m, "zz", "me"), FriendsModel.NONE, "stranger")
	eq(FriendsModel.relation(m, "me", "me"), FriendsModel.SELF, "me")
	eq(FriendsModel.relation({}, "a1", "me"), FriendsModel.NONE, "not loaded")
	check(not FriendsModel.friend_button(FriendsModel.FRIEND)["visible"], "a friend: hidden")
	check(not FriendsModel.friend_button(FriendsModel.SELF)["visible"], "me: hidden")
	var sent := FriendsModel.friend_button(FriendsModel.OUTGOING)
	check(sent["visible"] and sent["disabled"], "sent: off")
	eq(FriendsModel.friend_button(FriendsModel.INCOMING)["action"], "accept", "they asked: accept")
	eq(FriendsModel.friend_button(FriendsModel.NONE)["action"], "request", "stranger: request")
	check(FriendsModel.can_befriend("p2", false, "me"), "a real player")
	check(not FriendsModel.can_befriend("bot_1", false, "me"), "a bot by id")
	check(not FriendsModel.can_befriend("p2", true, "me"), "a bot")
	check(not FriendsModel.can_befriend("me", false, "me"), "me")


func test_paths_keep_ids_exact() -> void:
	eq(FriendsModel.accept_path("A-b/c"), "/friends/requests/A-b%2Fc/accept", "one path component")
	eq(FriendsModel.friend_path("0000AbC"), "/friends/0000AbC", "case kept")
	eq(FriendsModel.nickname_path("x y"), "/friends/x%20y/nickname", "nickname")


func test_local_changes() -> void:
	var m := FriendsModel.parse(ANSWER)
	var sent := FriendsModel.moved(m, "new", FriendsModel.OUTGOING, {"displayName": "Mới", "level": 4, "characterId": "flora"})
	eq(FriendsModel.relation(sent, "new", "me"), FriendsModel.OUTGOING, "my request shows")
	eq(sent["outgoing"][-1]["displayName"], "Mới", "with its name")
	var accepted := FriendsModel.moved(m, "d4", FriendsModel.FRIEND)
	eq(FriendsModel.relation(accepted, "d4", "me"), FriendsModel.FRIEND, "accepted")
	eq(accepted["incoming"].size(), 0, "no longer waiting")
	eq(FriendsModel.friend(accepted, "d4")["displayName"], "MâyXanh", "its fields kept")
	var gone := FriendsModel.moved(m, "a1", FriendsModel.NONE)
	eq(FriendsModel.relation(gone, "a1", "me"), FriendsModel.NONE, "removed")
	var renamed := FriendsModel.renamed(m, "a2", "Gió Lớn")
	eq(FriendsModel.shown_name(FriendsModel.friend(renamed, "a2")), "Gió Lớn", "renamed")
	eq(FriendsModel.shown_name(FriendsModel.friend(m, "a2")), "Gió", "the old model untouched")
	eq(FriendsModel.pending_count(m), 1, "one waiting")
	eq(FriendsModel.tab_entries(m, FriendsModel.TAB_OUTGOING).size(), 1, "the Đã gửi tab")
