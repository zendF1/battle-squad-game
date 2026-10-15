extends "res://tests/test_case.gd"

const FakeChat := preload("res://screens/home/fake_chat.gd")


func test_lines_are_known_channels() -> void:
	check(FakeChat.LINES.size() >= 3 and FakeChat.LINES.size() <= 4, "three or four lines")
	for line in FakeChat.LINES:
		check(FakeChat.CHANNELS.has(line["channel"]), "channel " + line["channel"])


func test_bbcode() -> void:
	eq(FakeChat.bbcode({"channel": "Thế giới", "name": "HạNhàn", "text": "Ai đấu 2v2 không?"}),
		"[color=#ffcc38][lb]Thế giới[rb][/color] [color=#8cd1ff]HạNhàn:[/color] Ai đấu 2v2 không?", "channel, name, text")
	eq(FakeChat.bbcode({"channel": "Hệ thống", "name": "", "text": "Bảo trì"}),
		"[color=#ff7373][lb]Hệ thống[rb][/color] Bảo trì", "no sender")
	eq(FakeChat.bbcode({"channel": "Thế giới", "name": "a[b]", "text": "[b]x[/b]"}),
		"[color=#ffcc38][lb]Thế giới[rb][/color] [color=#8cd1ff]a[lb]b[rb]:[/color] [lb]b[rb]x[lb]/b[rb]", "brackets escaped")
