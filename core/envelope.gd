extends RefCounted
## Game server WebSocket messages: {"event": "<Name>", "data": ...} (server: ws.Message).


static func encode(event: String, data = null) -> String:
	var msg := {"event": event}
	if data != null:
		msg["data"] = data
	return JSON.stringify(msg)


## Returns {"event": String, "data": Variant}, or {} when text is not a valid message.
static func decode(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed = json.data
	if not (parsed is Dictionary) or not (parsed.get("event") is String):
		return {}
	return {"event": parsed["event"], "data": parsed.get("data")}
