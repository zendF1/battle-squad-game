extends RefCounted
## Placeholder lines for the lobby chat box until chat exists: static messages, each with its
## channel and sender, and their BBCode for a RichTextLabel ("[Thế giới] Tên: tin nhắn" with a
## coloured channel tag and name).

const CHANNELS := {
	"Thế giới": Color(1.0, 0.8, 0.22),
	"Bang hội": Color(0.45, 0.9, 0.55),
	"Hệ thống": Color(1.0, 0.45, 0.45),
}
const NAME_COLOR := Color(0.55, 0.82, 1.0)
const PLACEHOLDER := "Nhấn để chat..."
const COMING_SOON := "Chat sẽ có sau"

## Oldest first; the box shows them all.
const LINES := [
	{"channel": "Hệ thống", "name": "", "text": "Chào mừng đến Battle Squad!"},
	{"channel": "Thế giới", "name": "HạNhàn", "text": "Ai đấu 2v2 không?"},
	{"channel": "Bang hội", "name": "TrinhSát", "text": "Tối nay 8h đi săn nhé"},
	{"channel": "Thế giới", "name": "MítTơTi", "text": "Bom băng combo quá mạnh"},
]


## "[color=#ffcc38][Thế giới][/color] [color=#8cd1ff]HạNhàn:[/color] Ai đấu 2v2 không?"; a line
## without a sender has no name part. Brackets in the text are escaped.
static func bbcode(line: Dictionary) -> String:
	var channel := str(line.get("channel", ""))
	var color: Color = CHANNELS.get(channel, Color.WHITE)
	var out := "[color=#%s][lb]%s[rb][/color] " % [color.to_html(false), channel]
	var sender := str(line.get("name", ""))
	if sender != "":
		out += "[color=#%s]%s:[/color] " % [NAME_COLOR.to_html(false), _escape(sender)]
	return out + _escape(str(line.get("text", "")))


static func _escape(value: String) -> String:
	var out := ""
	for ch in value:
		out += "[lb]" if ch == "[" else ("[rb]" if ch == "]" else ch)
	return out
