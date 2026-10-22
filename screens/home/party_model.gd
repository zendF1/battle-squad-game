extends RefCounted
## The ranked 2v2 party (Home's teammate slot and the invite popups), without UI or socket: the
## lobby from LobbyUpdated, my role in it (host / member), the teammate, the invites I sent with
## their expiry, the invite shown to me, and the rows of the invite popup (OnlinePlayers).
## on_event(), tick() and the commands (invite(), respond(), kick(), set_ready(), confirm_ready(),
## set_character(), leave(), list()) return the actions the owner (screens/home/party.gd) carries out, in order:
##   ["send", event, data]  send it on the game socket
##   ["changed"]            the lobby (members, ready, status) changed: redraw the slot
##   ["players"]            the popup's rows changed (OnlinePlayers, an invite sent / answered)
##   ["invite", invite]     an invite to me (LobbyInvite): show it
##   ["invite_closed"]      the invite shown to me is gone (answered, expired)
##   ["toast", text]        tell the player
##   ["queue_started"]      the host started the queue and I am the member: off to Matchmaking
## Times are seconds on the owner's clock (`now`). An invite's lifetime is its expiresInSec
## (InviteSent / LobbyInvite), else the game data's matchmaking.inviteTimeoutSec.
## Before the first invite without a lobby, CreateLobby goes first and the invite follows its
## LobbyUpdated; a CreateLobby refused because the server still has me in a lobby / a room leaves
## it (LeaveLobby / Leave) and asks again, once; an InviteToLobby answered LOBBY_REQUIRED /
## LOBBY_NOT_FOUND (my lobby is gone on the server) creates a new one and invites again. The lobby
## filling up cancels my other invites on the server (it tells only their invitees): the
## "Đã mời" rows clear with the LobbyUpdated of two members. Lobby errors are shown only within ERROR_WINDOW of
## a request of mine (other screens handle their own: the ranked queue, a match's leave).

const ErrorText := preload("res://screens/home/error_text.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const IDLE := "idle"
const IN_LOBBY := "in_lobby"
const IN_MATCH := "in_match"
const ERROR_WINDOW := 5.0 # s after a request of mine its LobbyError is mine to show

const KICKED := "Bạn đã bị mời ra khỏi đội"
const HOST_LEFT := "Chủ phòng đã rời đội"
const EXPIRED := "Lời mời đã hết hạn"
const DECLINED := "%s đã từ chối lời mời"

## The start button of each state: {text, disabled, action ("start" / "ready" / "unready")}.
const START := "BẮT ĐẦU"
const WAIT_MATE := "Chờ đồng đội sẵn sàng"
const READY := "SẴN SÀNG"
const UNREADY := "HUỶ SẴN SÀNG"

var me := ""
var lobby := {} # parse_lobby() of the last LobbyUpdated; {} not in a lobby
var sent := {} # playerId -> expiry (s) of my invites still waiting
var incoming := {} # the invite shown to me: parse_invite() + expires_at; {} none
var players: Array = [] # parse_player() of the last OnlinePlayers
var _invite_after_create := "" # a playerId to invite once CreateLobby answers
var _inviting := "" # the playerId of the InviteToLobby waiting for its answer
var _create_retried := false
var _expect_until := -1.0 # a lobby error before this answers a request of mine


# ── Parsing ─────────────────────────────────────────────────────────────────

static func _num(v: Variant, fallback: int = 0) -> int:
	return int(v) if v is int or v is float else fallback


static func _str(v: Variant, fallback: String = "") -> String:
	return str(v) if v is String and str(v) != "" else fallback


## A LobbyMember: {playerId, displayName, characterId, level (0 unknown), rating, tier, division,
## ready, gun: {kind, tier}} (gun: the server's, else the character's basic gun); {} not a member.
static func parse_member(m: Variant) -> Dictionary:
	if not m is Dictionary or _str(m.get("playerId")) == "":
		return {}
	var id := _str(m.get("playerId"))
	var character := _str(m.get("characterId"), GameData.default_character_id())
	var basic := EquipmentModel.gun("", {}, character)
	var g = m.get("gun")
	var gun := basic.duplicate()
	if g is Dictionary:
		gun = {"kind": _str(g.get("kind"), basic["kind"]), "tier": _str(g.get("tier"), basic["tier"])}
	return {"playerId": id, "displayName": _str(m.get("displayName"), id.left(8)), "characterId": character,
		"level": _num(m.get("level")), "rating": _num(m.get("rating"), -1), "tier": _str(m.get("tier")),
		"division": clampi(_num(m.get("division")), 0, 3), "ready": m.get("ready") == true, "gun": gun}


## A LobbyState: {lobbyId, hostPlayerId, status, members: [parse_member()]} (the host always
## ready); {} without a lobbyId.
static func parse_lobby(d: Variant) -> Dictionary:
	if not d is Dictionary or _str(d.get("lobbyId")) == "":
		return {}
	var host := _str(d.get("hostPlayerId"))
	var members: Array = []
	if d.get("members") is Array:
		for m in d["members"]:
			var p := parse_member(m)
			if not p.is_empty():
				if p["playerId"] == host:
					p["ready"] = true
				members.append(p)
	return {"lobbyId": _str(d.get("lobbyId")), "hostPlayerId": host, "status": _str(d.get("status"), "preparing"),
		"members": members}


## An OnlinePlayer: {playerId, displayName, level, tier, division, characterId, status (idle /
## in_lobby / in_match)}; {} not a player.
static func parse_player(p: Variant) -> Dictionary:
	if not p is Dictionary or _str(p.get("playerId")) == "":
		return {}
	var id := _str(p.get("playerId"))
	var status := _str(p.get("status"), IDLE)
	return {"playerId": id, "displayName": _str(p.get("displayName"), id.left(8)), "level": _num(p.get("level")),
		"tier": _str(p.get("tier")), "division": clampi(_num(p.get("division")), 0, 3),
		"characterId": _str(p.get("characterId"), GameData.default_character_id()), "status": status}


## A LobbyInvite: {inviteId, lobbyId, mode, expiresInSec, from: parse_player()}; {} without an id.
static func parse_invite(d: Variant) -> Dictionary:
	if not d is Dictionary or _str(d.get("inviteId")) == "":
		return {}
	return {"inviteId": _str(d.get("inviteId")), "lobbyId": _str(d.get("lobbyId")), "mode": _str(d.get("mode")),
		"expiresInSec": _lifetime(d.get("expiresInSec")), "from": parse_player(d.get("from"))}


## An invite's lifetime: the payload's seconds, else the game data's inviteTimeoutSec.
static func _lifetime(v: Variant) -> int:
	var n := _num(v, -1)
	return n if n > 0 else GameData.invite_timeout_sec()


# ── State ───────────────────────────────────────────────────────────────────

func in_lobby() -> bool:
	return not lobby.is_empty()


func is_host() -> bool:
	return in_lobby() and lobby["hostPlayerId"] == me


## In someone else's lobby.
func is_member() -> bool:
	return in_lobby() and lobby["hostPlayerId"] != me


## Two in the lobby: me and a teammate.
func in_party() -> bool:
	return not teammate().is_empty()


## The other member of my lobby; {} none.
func teammate() -> Dictionary:
	if not in_lobby():
		return {}
	for m in lobby["members"]:
		if m["playerId"] != me:
			return m
	return {}


## My member entry; {} not in a lobby.
func my_member() -> Dictionary:
	if not in_lobby():
		return {}
	for m in lobby["members"]:
		if m["playerId"] == me:
			return m
	return {}


## The member's ready (the host is always ready).
func my_ready() -> bool:
	return bool(my_member().get("ready", false))


## The start button: {text, disabled, action}. Alone: BẮT ĐẦU. Host with a teammate not ready:
## "Chờ đồng đội sẵn sàng", disabled. Member: SẴN SÀNG / HUỶ SẴN SÀNG.
func start_button() -> Dictionary:
	if is_member():
		return {"text": UNREADY, "disabled": false, "action": "unready"} if my_ready() \
			else {"text": READY, "disabled": false, "action": "ready"}
	if in_party() and not bool(teammate().get("ready", false)):
		return {"text": WAIT_MATE, "disabled": true, "action": "start"}
	return {"text": START, "disabled": false, "action": "start"}


## Seconds left of my invite to player_id (0: none waiting).
func sent_left(player_id: String, now: float) -> int:
	if not sent.has(player_id):
		return 0
	return maxi(ceili(float(sent[player_id]) - now), 0)


## The popup row's button for an OnlinePlayer: {text, disabled}. In a match: "Đang trận"; in a
## lobby with someone: "Bận"; invited: "Đã mời (12s)"; my party full: "Mời" off; else "Mời".
func row_button(p: Dictionary, now: float) -> Dictionary:
	match str(p.get("status", IDLE)):
		IN_MATCH:
			return {"text": "Đang trận", "disabled": true}
		IN_LOBBY:
			return {"text": "Bận", "disabled": true}
	var left := sent_left(str(p.get("playerId", "")), now)
	if left > 0:
		return {"text": "Đã mời (%ds)" % left, "disabled": true}
	return {"text": "Mời", "disabled": in_party() or is_member()}


## Seconds left of the invite shown to me.
func incoming_left(now: float) -> float:
	return maxf(float(incoming.get("expires_at", 0.0)) - now, 0.0) if not incoming.is_empty() else 0.0


## 1 → 0 over the invite's lifetime (its countdown bar).
func incoming_ratio(now: float) -> float:
	if incoming.is_empty():
		return 0.0
	return clampf(incoming_left(now) / maxf(float(incoming["expiresInSec"]), 1.0), 0.0, 1.0)


# ── Commands ────────────────────────────────────────────────────────────────

func _expect(now: float) -> void:
	_expect_until = now + ERROR_WINDOW


## ListOnlinePlayers {query?}: "" lists everyone.
func list(query: String) -> Array:
	var q := query.strip_edges()
	return [["send", "ListOnlinePlayers", {"query": q} if q != "" else {}]]


## Invites player_id; without a lobby CreateLobby goes first (the invite follows LobbyUpdated).
func invite(player_id: String, now: float) -> Array:
	if player_id == "" or player_id == me or in_party() or is_member():
		return []
	_expect(now)
	_create_retried = false
	if not in_lobby():
		_invite_after_create = player_id
		return [["send", "CreateLobby", {}]]
	_inviting = player_id
	return [["send", "InviteToLobby", {"playerId": player_id}]]


## Answers the invite shown to me.
func respond(accept: bool, now: float) -> Array:
	if incoming.is_empty():
		return []
	var id: String = incoming["inviteId"]
	incoming = {}
	_expect(now)
	return [["send", "RespondInvite", {"inviteId": id, "accept": accept}], ["invite_closed"]]


## The host takes the teammate out.
func kick(now: float) -> Array:
	var mate := teammate()
	if not is_host() or mate.is_empty():
		return []
	_expect(now)
	return [["send", "KickMember", {"playerId": mate["playerId"]}]]


## The member's SẴN SÀNG / HUỶ SẴN SÀNG.
func set_ready(value: bool, now: float) -> Array:
	if not is_member():
		return []
	_expect(now)
	return [["send", "SetReady", {"ready": value}]]


## The member confirmed the Loadout: its character and items, then ready.
func confirm_ready(loadout: Dictionary, now: float) -> Array:
	if not is_member():
		return []
	_expect(now)
	return [["send", "UpdateLoadout", loadout.duplicate(true)], ["send", "SetReady", {"ready": true}]]


## The stage character changed on Home while a teammate is in the lobby: UpdateLoadout
## {characterId} (the items kept), so the teammate's slot shows it.
func set_character(character_id: String, now: float) -> Array:
	if not in_party() or str(lobby.get("status", "")) != "preparing" or character_id == "" \
			or str(my_member().get("characterId", "")) == character_id:
		return []
	_expect(now)
	return [["send", "UpdateLoadout", {"characterId": character_id}]]


## Leaves the lobby (a host's leaving disbands it on the server): LeaveLobby, the state cleared.
func leave() -> Array:
	var was := in_lobby()
	forget()
	return [["send", "LeaveLobby", {}], ["changed"]] if was else [["send", "LeaveLobby", {}]]


## Not in a lobby any more (left, or the connection closed): the lobby and my invites cleared.
func forget() -> void:
	lobby = {}
	sent.clear()
	_invite_after_create = ""
	_inviting = ""


## Expiries: my invites past their time drop (the server's InviteExpired also says so), the
## invite shown to me closes.
func tick(now: float) -> Array:
	var out: Array = []
	var gone: Array = []
	for id in sent:
		if float(sent[id]) <= now:
			gone.append(id)
	for id in gone:
		sent.erase(id)
	if not gone.is_empty():
		out.append(["players"])
	if not incoming.is_empty() and incoming_left(now) <= 0.0:
		incoming = {}
		out.append(["invite_closed"])
	return out


## The game socket closed: the server dropped me from my lobby.
func on_disconnected() -> Array:
	var was := in_lobby() or not incoming.is_empty()
	forget()
	var out: Array = []
	if not incoming.is_empty():
		incoming = {}
		out.append(["invite_closed"])
	if was:
		out.append(["changed"])
	return out


func on_event(event: String, data: Variant, now: float) -> Array:
	match event:
		"LobbyUpdated":
			return _on_lobby(data)
		"LobbyDisbanded":
			var host_left := data is Dictionary and str(data.get("reason", "")) == "host_left"
			var member := is_member()
			if not in_lobby():
				return []
			forget()
			return [["toast", HOST_LEFT], ["changed"]] if host_left and member else [["changed"]]
		"LobbyKicked":
			if not in_lobby():
				return []
			forget()
			return [["toast", KICKED], ["changed"]]
		"OnlinePlayers":
			players = []
			if data is Dictionary and data.get("players") is Array:
				for p in data["players"]:
					var row := parse_player(p)
					if not row.is_empty() and row["playerId"] != me:
						players.append(row)
			return [["players"]]
		"InviteSent":
			if not data is Dictionary or _str(data.get("playerId")) == "":
				return []
			sent[_str(data.get("playerId"))] = now + _lifetime(data.get("expiresInSec"))
			if _inviting == _str(data.get("playerId")):
				_inviting = ""
			return [["players"]]
		"InviteDeclined":
			if not data is Dictionary:
				return []
			var id := _str(data.get("playerId"))
			sent.erase(id)
			var who := _str(data.get("displayName"), _name_of(id))
			return [["toast", DECLINED % who], ["players"]]
		"InviteExpired":
			if not data is Dictionary:
				return []
			var invite_id := _str(data.get("inviteId"))
			if invite_id != "":
				if not incoming.is_empty() and incoming["inviteId"] == invite_id:
					incoming = {}
					return [["invite_closed"]]
				return []
			var id := _str(data.get("playerId"))
			if not sent.has(id):
				return []
			sent.erase(id)
			return [["toast", EXPIRED], ["players"]]
		"LobbyInvite":
			var inv := parse_invite(data)
			if inv.is_empty():
				return []
			inv["expires_at"] = now + float(inv["expiresInSec"])
			incoming = inv
			return [["invite", inv]]
		"QueueStarted":
			return [["queue_started"]] if is_member() else []
		"LobbyError", "Error":
			return _on_error(data, now)
	return []


func _on_lobby(data: Variant) -> Array:
	var next := parse_lobby(data)
	if next.is_empty():
		return []
	var mine := false
	for m in next["members"]:
		if m["playerId"] == me:
			mine = true
	if not mine:
		return [] # not about my lobby
	lobby = next
	var out: Array = [["changed"]]
	if in_party():
		sent.clear() # the server cancelled the other invites
		out.append(["players"])
	if _invite_after_create != "":
		var id := _invite_after_create
		_invite_after_create = ""
		if is_host() and not in_party():
			_inviting = id
			out.append(["send", "InviteToLobby", {"playerId": id}])
	return out


func _on_error(data: Variant, now: float) -> Array:
	var code := ErrorText.lobby_code(data)
	if _invite_after_create != "":
		# The CreateLobby before an invite was refused.
		if not _create_retried and code in ["ALREADY_IN_LOBBY", "IN_ROOM"]:
			_create_retried = true
			_expect(now)
			return [["send", "LeaveLobby" if code == "ALREADY_IN_LOBBY" else "Leave", {}], ["send", "CreateLobby", {}]]
		_invite_after_create = ""
		return [["toast", ErrorText.lobby_error(data)]]
	if _inviting != "" and now <= _expect_until:
		var id := _inviting
		_inviting = ""
		if code in ["LOBBY_REQUIRED", "LOBBY_NOT_FOUND"] and not _create_retried:
			# My lobby is gone on the server: a new one, then the invite again.
			lobby = {}
			_create_retried = true
			_invite_after_create = id
			_expect(now)
			return [["changed"], ["send", "CreateLobby", {}]]
		return [["toast", ErrorText.lobby_error(data)]]
	if now > _expect_until or code in ["LOBBY_REQUIRED", "NOT_IN_QUEUE"]:
		return [] # not an answer to me (a late one to a match's LeaveLobby, the queue's own)
	_expect_until = -1.0
	return [["toast", ErrorText.lobby_error(data)]]


func _name_of(id: String) -> String:
	for p in players:
		if p["playerId"] == id:
			return p["displayName"]
	return id.left(8)
