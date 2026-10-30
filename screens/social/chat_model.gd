extends RefCounted
## Chat, pure (contract: the server's docs/contracts/chat.md). Conversations: Thế giới (world),
## Bang hội (guild, target the guild id), a friend's DM (dm, target their player id) over REST
## (POST / GET /chat/{channel}/messages), and the live match's (match) over the game socket
## (ChatSend / ChatHistory / ChatMessage / ChatError). A message: {id, channel, scope, playerId, text,
## createdAt, displayName, level, characterId} (the sender's name, level and current character as
## the server read them when it was sent). Ids grow across all conversations: a conversation's
## messages are kept sorted by id, deduplicated by id, and its cursor is its last id (`after`).
## The length limit and the poll cadence come from the game data (GameData.chat_max_length(),
## chat_poll_sec()).

const WORLD := "world"
const GUILD := "guild"
const DM := "dm"
const MATCH := "match"
const SYSTEM := "system" # a line the client adds (the match start): no sender

## Lines kept per conversation on the client (older ones drop off the top).
const KEEP := 100
## How many times less often than pollSec a conversation is polled where it is not the one open
## in the chat popup (the API's request limiter applies to everyone's polls): the lobby box while the
## lobby shows (LOBBY_FACTOR), behind a lobby page (BACKGROUND_FACTOR); never with the app in the
## background, never a DM that is not open.
const LOBBY_FACTOR := 3.0
const BACKGROUND_FACTOR := 9.0
## After a 429 a conversation waits pollSec × its backoff (doubling from 2 up to this) before the
## next poll; a good answer resets it.
const BACKOFF_MAX := 16.0
## Newest lines the lobby box shows.
const BOX_LINES := 4

const CHANNEL_NAMES := {WORLD: "Thế giới", GUILD: "Bang hội", DM: "Bạn bè", MATCH: "Trận", SYSTEM: "Hệ thống"}
const CHANNEL_COLORS := {
	"Thế giới": Color(1.0, 0.8, 0.22),
	"Bang hội": Color(0.45, 0.9, 0.55),
	"Bạn bè": Color(0.95, 0.6, 1.0),
	"Trận": Color(0.55, 0.82, 1.0),
	"Hệ thống": Color(1.0, 0.45, 0.45),
}
const NAME_COLOR := Color(0.55, 0.82, 1.0)
const MY_NAME_COLOR := Color(1.0, 0.86, 0.45)
const PLACEHOLDER := "Nhấn để chat..."
const INPUT_HINT := "Nhập tin nhắn..."
const EMPTY_TEXT := "Nhập tin nhắn trước khi gửi"
const NO_MESSAGES := "Chưa có tin nhắn nào"


## The key of a conversation: "world", "guild:<id>", "dm:<playerId>", "match".
static func key(channel: String, target: String = "") -> String:
	return channel if target == "" else "%s:%s" % [channel, target]


## The REST path of a channel's messages.
static func path(channel: String) -> String:
	return "/chat/%s/messages" % channel


## The GET query: the target (percent-encoded, never changed otherwise) and the cursor; the server's
## default page size.
static func history_query(target: String, after: int) -> String:
	var parts: Array = []
	if target != "":
		parts.append("target=" + target.uri_encode())
	if after > 0:
		parts.append("after=%d" % after)
	return "" if parts.is_empty() else "?" + "&".join(parts)


## The POST body: the text, and the target when there is one.
static func send_body(text: String, target: String) -> Dictionary:
	var body := {"text": text}
	if target != "":
		body["target"] = target
	return body


## One message from the server, or {} when it is not one (no id, no text).
static func parse_message(v: Variant) -> Dictionary:
	if not v is Dictionary:
		return {}
	var id = v.get("id")
	if not (id is int or id is float) or int(id) <= 0 or not v.get("text") is String:
		return {}
	var level = v.get("level")
	return {
		"id": int(id),
		"channel": str(v.get("channel", "")),
		"scope": str(v.get("scope", "")),
		"playerId": str(v.get("playerId", "")),
		"text": str(v["text"]),
		"createdAt": str(v.get("createdAt", "")),
		"displayName": str(v.get("displayName", "")) if v.get("displayName") is String else "",
		"level": int(level) if level is int or level is float else 0,
		"characterId": str(v.get("characterId", "")) if v.get("characterId") is String else "",
	}


## The messages of a history answer ({messages: [...]}, REST data or the ChatHistory event), the
## unusable ones left out.
static func parse_list(data: Variant) -> Array:
	var out: Array = []
	var list = data.get("messages") if data is Dictionary else data
	if list is Array:
		for v in list:
			var m := parse_message(v)
			if not m.is_empty():
				out.append(m)
	return out


## `existing` with `incoming` added: one per id (a later copy replaces it), sorted by id, the
## newest `keep`.
static func merge(existing: Array, incoming: Array, keep: int = KEEP) -> Array:
	var by_id := {}
	for m in existing:
		by_id[int(m["id"])] = m
	for m in incoming:
		by_id[int(m["id"])] = m
	var ids := by_id.keys()
	ids.sort()
	if ids.size() > keep:
		ids = ids.slice(ids.size() - keep)
	var out: Array = []
	for id in ids:
		out.append(by_id[id])
	return out


## The cursor of a conversation: its last id, 0 none.
static func last_id(messages: Array) -> int:
	return int(messages[-1]["id"]) if not messages.is_empty() else 0


## The sender's name: the message's, else `names` (playerId -> name: a match's players), else "?".
static func sender_name(m: Dictionary, names: Dictionary = {}) -> String:
	var n := str(m.get("displayName", ""))
	if n == "":
		n = str(names.get(str(m.get("playerId", "")), ""))
	return n if n != "" else "?"


## The lobby box's lines: the newest `n` of the conversations' messages (ids order them across
## conversations), each as a line for bbcode() with its channel's name (mine: `me` sent it).
static func box_lines(conversations: Array, me: String, n: int = BOX_LINES) -> Array:
	var all: Array = []
	for list in conversations:
		all = merge(all, list, n)
	return all.map(func(m): return {"channel": CHANNEL_NAMES.get(m["channel"], ""), "name": sender_name(m), "text": m["text"],
		"mine": str(m["playerId"]) == me})


## A HUD line of a match message: no channel tag (the HUD shows only the match's), mine marked.
static func match_line(m: Dictionary, names: Dictionary, me: String) -> Dictionary:
	return {"channel": "", "name": sender_name(m, names), "text": m["text"], "mine": str(m.get("playerId", "")) == me}


## "[color=#ffcc38][lb]Thế giới[rb][/color] [color=#8cd1ff]HạNhàn:[/color] Ai đấu 2v2 không?" for a
## line {channel (its Vietnamese name, "" none), name ("" none), text, mine}: no tag without a
## channel, no name part without a sender, my name in gold. Brackets in the text are escaped.
static func bbcode(line: Dictionary) -> String:
	var out := ""
	var channel := str(line.get("channel", ""))
	if channel != "":
		var color: Color = CHANNEL_COLORS.get(channel, Color.WHITE)
		out = "[color=#%s][lb]%s[rb][/color] " % [color.to_html(false), channel]
	var sender := str(line.get("name", ""))
	if sender != "":
		var c: Color = MY_NAME_COLOR if line.get("mine", false) else NAME_COLOR
		out += "[color=#%s]%s:[/color] " % [c.to_html(false), escape(sender)]
	return out + escape(str(line.get("text", "")))


static func escape(value: String) -> String:
	var out := ""
	for ch in value:
		out += "[lb]" if ch == "[" else ("[rb]" if ch == "]" else ch)
	return out


## The text to send (edges trimmed), "" when there is nothing to send.
static func clean(raw: String) -> String:
	return raw.strip_edges()


## What stops `raw` from being sent ("" nothing): empty, or longer than `max_length` characters
## (0: no limit known).
static func text_problem(raw: String, max_length: int) -> String:
	var t := clean(raw)
	if t == "":
		return EMPTY_TEXT
	if max_length > 0 and t.length() > max_length:
		return "Tối đa %d ký tự" % max_length
	return ""


## Seconds between two polls of a conversation (0: no timed polling): pollSec × `factor` (1 the
## open conversation, LOBBY_FACTOR, BACKGROUND_FACTOR).
static func poll_interval(poll_sec: float, factor: float = 1.0) -> float:
	if poll_sec <= 0.0:
		return 0.0
	return poll_sec * factor


## The next backoff factor after a 429 (`current` 0: none yet).
static func next_backoff(current: float) -> float:
	return minf(maxf(2.0, current * 2.0), BACKOFF_MAX)


## "Lv.12", "" without a level.
static func level_text(level: int) -> String:
	return "Lv.%d" % level if level > 0 else ""


## "14:05" of a createdAt (RFC 3339: "…Z" or "…+07:00", fractions allowed) in the time zone
## `bias_min` minutes from UTC (-1: the device's), "" when unreadable.
static func clock(created_at: String, bias_min: int = -1) -> String:
	var unix := unix_of(created_at)
	if unix <= 0:
		return ""
	var bias := bias_min if bias_min != -1 else int(Time.get_time_zone_from_system().get("bias", 0))
	var t := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%02d:%02d" % [t["hour"], t["minute"]]


## Unix seconds of an RFC 3339 time, 0 when unreadable.
static func unix_of(created_at: String) -> int:
	var t := created_at.strip_edges()
	var at := t.find("T")
	if at < 0:
		return 0
	var offset := 0
	if t.ends_with("Z") or t.ends_with("z"):
		t = t.left(-1)
	else:
		var sign_at := maxi(t.rfind("+"), t.rfind("-"))
		if sign_at > at:
			var zone := t.substr(sign_at + 1).split(":")
			if zone.size() == 2 and zone[0].is_valid_int() and zone[1].is_valid_int():
				offset = (int(zone[0]) * 60 + int(zone[1])) * (1 if t[sign_at] == "+" else -1)
			t = t.left(sign_at)
	t = t.split(".")[0]
	var unix := Time.get_unix_time_from_datetime_string(t)
	return unix - offset * 60 if unix > 0 else 0
