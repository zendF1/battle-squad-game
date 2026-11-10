extends "res://tests/test_case.gd"
## screens/social/chat_model.gd: the message shape of contracts/chat.md (sender fields included),
## dedup by id, cursors, the lobby box's lines, the BBCode, the length limit and the poll cadence
## from the game data (tests/fixtures/gamedata.json chat block).

const ChatModel := preload("res://screens/social/chat_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")


static func msg(id: int, channel: String = "world", who: String = "p2", text: String = "hi") -> Dictionary:
	return {"id": id, "channel": channel, "scope": channel, "playerId": who, "displayName": "Tên " + who,
		"level": 12, "characterId": "rookie", "text": text, "createdAt": "2026-10-30T00:00:00Z"}


func test_game_data_chat_block() -> void:
	eq(GameData.chat_max_length(), 500, "maxLength from the fixture")
	near(GameData.chat_poll_sec(), 3.0, 0.001, "pollSec from the fixture")
	GameData.reset("")
	GameData.take({"version": "x"}, "", false)
	eq(GameData.chat_max_length(), 0, "an older server: no limit known")
	eq(GameData.chat_poll_sec(), 0.0, "no cadence known")


func test_parse_message_with_sender_fields() -> void:
	var m := ChatModel.parse_message(msg(5))
	eq(m["id"], 5, "id")
	eq(m["displayName"], "Tên p2", "name")
	eq(m["level"], 12, "level")
	eq(m["characterId"], "rookie", "character")
	var old := ChatModel.parse_message({"id": 6, "channel": "world", "playerId": "p", "text": "x"})
	eq(old["displayName"], "", "an older server: no name")
	eq(old["level"], 0, "no level")
	check(ChatModel.parse_message({"id": 0, "text": "x"}).is_empty(), "no id: not a message")
	check(ChatModel.parse_message({"id": 3}).is_empty(), "no text: not a message")
	check(ChatModel.parse_message("x").is_empty(), "not a dictionary")
	eq(ChatModel.parse_list({"messages": [msg(1), {"bad": true}, msg(2)]}).size(), 2, "the unusable one left out")
	eq(ChatModel.parse_list({"messages": []}).size(), 0, "empty")


func test_merge_dedupes_sorts_and_keeps_the_newest() -> void:
	var a := ChatModel.merge([msg(3), msg(1)], [msg(2), msg(3, "world", "p2", "edited")])
	eq(a.map(func(m): return m["id"]), [1, 2, 3], "sorted, one per id")
	eq(a[2]["text"], "edited", "a later copy replaces")
	var many: Array = []
	for i in 10:
		many.append(msg(i + 1))
	eq(ChatModel.merge([], many, 4).map(func(m): return m["id"]), [7, 8, 9, 10], "the newest kept")
	eq(ChatModel.last_id(a), 3, "cursor: the last id")
	eq(ChatModel.last_id([]), 0, "no messages: 0")


func test_queries_and_bodies() -> void:
	eq(ChatModel.path("world"), "/chat/world/messages", "path")
	eq(ChatModel.history_query("", 0), "", "world, first time: newest page")
	eq(ChatModel.history_query("", 42), "?after=42", "after the cursor")
	eq(ChatModel.history_query("a b/c", 7), "?target=a%20b%2Fc&after=7", "the target percent-encoded")
	eq(ChatModel.send_body("hi", ""), {"text": "hi"}, "world: no target")
	eq(ChatModel.send_body("hi", "g1"), {"text": "hi", "target": "g1"}, "guild / dm: the target")
	eq(ChatModel.key("dm", "p9"), "dm:p9", "a DM's key")
	eq(ChatModel.key("world"), "world", "world's key")


func test_box_lines_merge_world_and_guild_by_id() -> void:
	var world := [msg(1), msg(4)]
	var guild := [msg(2, "guild"), msg(3, "guild"), msg(5, "guild")]
	var lines := ChatModel.box_lines([world, guild], "p2", 4)
	eq(lines.size(), 4, "the newest four")
	eq(lines.map(func(l): return l["channel"]), ["Bang hội", "Bang hội", "Thế giới", "Bang hội"], "in id order with the channel's name")
	eq(lines[0]["name"], "Tên p2", "the sender's name")
	check(lines[0]["mine"], "mine marked")
	check(not ChatModel.box_lines([world], "me", 4)[0]["mine"], "someone else's")


func test_bbcode() -> void:
	eq(ChatModel.bbcode({"channel": "Thế giới", "name": "HạNhàn", "text": "Ai đấu 2v2 không?"}),
		"[color=#ffcc38][lb]Thế giới[rb][/color] [color=#8cd1ff]HạNhàn:[/color] Ai đấu 2v2 không?", "channel, name, text")
	eq(ChatModel.bbcode({"channel": "Hệ thống", "name": "", "text": "Bảo trì"}),
		"[color=#ff7373][lb]Hệ thống[rb][/color] Bảo trì", "no sender")
	eq(ChatModel.bbcode({"channel": "Thế giới", "name": "a[b]", "text": "[b]x[/b]"}),
		"[color=#ffcc38][lb]Thế giới[rb][/color] [color=#8cd1ff]a[lb]b[rb]:[/color] [lb]b[rb]x[lb]/b[rb]", "brackets escaped")
	eq(ChatModel.bbcode({"channel": "", "name": "Tôi", "text": "gg", "mine": true}),
		"[color=#ffdb73]Tôi:[/color] gg", "a match line: no tag, mine in gold")


func test_match_line_names() -> void:
	var m := ChatModel.parse_message({"id": 9, "channel": "match", "playerId": "p3", "text": "gg"})
	var line := ChatModel.match_line(m, {"p3": "Rồng"}, "me")
	eq(line["name"], "Rồng", "no name in the message: the match's player")
	check(not line["mine"], "not mine")
	eq(ChatModel.match_line(m, {}, "p3")["name"], "?", "unknown: ?")
	check(ChatModel.match_line(m, {}, "p3")["mine"], "mine")


func test_text_problem_and_cadence() -> void:
	eq(ChatModel.text_problem("   ", 500), ChatModel.EMPTY_TEXT, "empty after trimming")
	eq(ChatModel.text_problem(" hi ", 500), "", "fine")
	eq(ChatModel.text_problem("abcdef", 5), "Tối đa 5 ký tự", "too long")
	eq(ChatModel.text_problem("ầầầầầ", 5), "", "code points, not bytes")
	eq(ChatModel.text_problem("abcdef", 0), "", "no limit known")
	eq(ChatModel.clean("  x  "), "x", "trimmed")
	eq(ChatModel.poll_interval(3.0), 3.0, "the open conversation: pollSec")
	eq(ChatModel.poll_interval(3.0, ChatModel.LOBBY_FACTOR), 9.0, "the lobby box: slower")
	check(ChatModel.BACKGROUND_FACTOR > ChatModel.LOBBY_FACTOR, "behind a page: slower still")
	eq(ChatModel.poll_interval(0.0), 0.0, "no cadence: no timed polling")
	eq(ChatModel.next_backoff(0.0), 2.0, "first 429: twice")
	eq(ChatModel.next_backoff(2.0), 4.0, "doubling")
	eq(ChatModel.next_backoff(ChatModel.BACKOFF_MAX), ChatModel.BACKOFF_MAX, "capped")
	eq(ChatModel.level_text(7), "Lv.7", "level")
	eq(ChatModel.level_text(0), "", "no level")
	eq(ChatModel.clock("2026-10-30T14:05:00Z", 0), "14:05", "UTC")
	eq(ChatModel.clock("2026-10-30T14:05:00Z", 420), "21:05", "in +07:00")
	eq(ChatModel.clock("2026-10-30T09:54:40.671383+07:00", 420), "09:54", "the server's offset and fraction")
	eq(ChatModel.clock("2026-10-30T09:54:40+07:00", 0), "02:54", "to UTC")
	eq(ChatModel.clock("2026-10-30T01:00:00-02:30", 0), "03:30", "a negative offset")
	check(ChatModel.clock("2026-10-30T14:05:00Z").length() == 5, "the device's zone")
	eq(ChatModel.clock("nope"), "", "unreadable")
	eq(ChatModel.clock(""), "", "none")
