extends RefCounted
## Friends, pure (contract: the server's docs/contracts/friends.md). GET /friends → {friends,
## incoming, outgoing}: a friend {playerId, displayName, nickname (mine for them, private), level,
## characterId}; a request received / sent {playerId, displayName, level, characterId}. Player ids are
## opaque: kept exactly as sent and percent-encoded as one path component. The relation to a player
## decides the "Kết bạn" button (friend_button()).

const NONE := "none"
const FRIEND := "friend"
const INCOMING := "incoming" # they asked me
const OUTGOING := "outgoing" # I asked them
const SELF := "self"

## The friends page's tabs.
const TABS := ["Bạn bè", "Lời mời", "Đã gửi"]
const TAB_FRIENDS := 0
const TAB_INCOMING := 1
const TAB_OUTGOING := 2
const EMPTY := ["Chưa có bạn bè", "Không có lời mời nào", "Chưa gửi lời mời nào"]

const REQUESTS := "/friends/requests"


## A GET /friends answer, or {} when it is not one.
static func parse(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	return {"friends": _entries(data.get("friends")), "incoming": _entries(data.get("incoming")),
		"outgoing": _entries(data.get("outgoing"))}


static func _entries(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for e in v:
			if e is Dictionary and e.get("playerId") is String and str(e["playerId"]) != "":
				var level = e.get("level")
				out.append({"playerId": str(e["playerId"]),
					"displayName": str(e.get("displayName", "")) if e.get("displayName") is String else "",
					"nickname": str(e.get("nickname", "")) if e.get("nickname") is String else "",
					"level": int(level) if level is int or level is float else 0,
					"characterId": str(e.get("characterId", "")) if e.get("characterId") is String else ""})
	return out


## The name shown for an entry: my nickname for them first, else their name, else "?".
static func shown_name(e: Dictionary) -> String:
	var nick := str(e.get("nickname", ""))
	if nick != "":
		return nick
	var n := str(e.get("displayName", ""))
	return n if n != "" else "?"


## Their own name under the nickname, "" when no nickname is set (the name is already shown).
static func real_name(e: Dictionary) -> String:
	return str(e.get("displayName", "")) if str(e.get("nickname", "")) != "" else ""


## The entries of a tab (TAB_FRIENDS / TAB_INCOMING / TAB_OUTGOING).
static func tab_entries(model: Dictionary, tab: int) -> Array:
	match tab:
		TAB_INCOMING: return model.get("incoming", [])
		TAB_OUTGOING: return model.get("outgoing", [])
	return model.get("friends", [])


## My relation to `player_id` (NONE when the list is not loaded).
static func relation(model: Dictionary, player_id: String, me: String) -> String:
	if player_id == me:
		return SELF
	for k in [FRIEND, INCOMING, OUTGOING]:
		for e in model.get("friends" if k == FRIEND else k, []):
			if str(e["playerId"]) == player_id:
				return k
	return NONE


## The friend entry of `player_id`, {} when not a friend.
static func friend(model: Dictionary, player_id: String) -> Dictionary:
	for e in model.get("friends", []):
		if str(e["playerId"]) == player_id:
			return e
	return {}


## The "Kết bạn" button for a relation: {visible, text, tip, disabled, action ("request", "accept",
## "")}. Hidden for myself and for a friend (Nhắn tin says it), "Đã gửi" off after my request,
## "Đồng ý" when they asked me.
static func friend_button(rel: String) -> Dictionary:
	match rel:
		OUTGOING:
			return {"visible": true, "text": "Đã gửi", "tip": "Đã gửi lời mời kết bạn", "disabled": true, "action": ""}
		INCOMING:
			return {"visible": true, "text": "Đồng ý", "tip": "Đồng ý kết bạn", "disabled": false, "action": "accept"}
		NONE:
			return {"visible": true, "text": "Kết bạn", "tip": "Kết bạn", "disabled": false, "action": "request"}
	return {"visible": false, "text": "", "tip": "", "disabled": true, "action": ""}


## Shows a Kết bạn button for a player of a list: a real player, not me (bots never).
static func can_befriend(player_id: String, is_bot: bool, me: String) -> bool:
	return player_id != "" and player_id != me and not is_bot and not player_id.begins_with("bot_")


## One path component of a player id (the server decodes it once).
static func path_id(player_id: String) -> String:
	return player_id.uri_encode()


static func accept_path(player_id: String) -> String:
	return "%s/%s/accept" % [REQUESTS, path_id(player_id)]


static func friend_path(player_id: String) -> String:
	return "/friends/%s" % path_id(player_id)


static func nickname_path(player_id: String) -> String:
	return "/friends/%s/nickname" % path_id(player_id)


## The model after a change I made, before GET /friends answers: `player_id` moved to `to` (FRIEND,
## OUTGOING, NONE: removed everywhere) with `entry`'s fields.
static func moved(model: Dictionary, player_id: String, to: String, entry: Dictionary = {}) -> Dictionary:
	var out := {"friends": [], "incoming": [], "outgoing": []}
	var found := entry.duplicate()
	for k in out:
		for e in model.get(k, []):
			if str(e["playerId"]) == player_id:
				for f in e:
					if not found.has(f) or str(found[f]) == "":
						found[f] = e[f]
			else:
				out[k].append(e)
	if to != NONE:
		found["playerId"] = player_id
		for f in ["displayName", "nickname", "characterId"]:
			if not found.has(f):
				found[f] = ""
		if not found.has("level"):
			found["level"] = 0
		out["friends" if to == FRIEND else to].append(found)
	return out


## A friend's nickname changed (an empty one resets it).
static func renamed(model: Dictionary, player_id: String, nickname: String) -> Dictionary:
	var out := model.duplicate(true)
	for e in out.get("friends", []):
		if str(e["playerId"]) == player_id:
			e["nickname"] = nickname
	return out


## The red count on the friends button and the Lời mời tab: the requests waiting for me.
static func pending_count(model: Dictionary) -> int:
	return model.get("incoming", []).size()
