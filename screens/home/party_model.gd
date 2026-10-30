extends RefCounted
## The party of a party mode (Đấu thường / Đấu hạng 2v2: one teammate; a boss: up to three; Home's
## teammate slots and the invite popups), without UI or socket: the lobby from LobbyUpdated (its
## queue: the mode the host chose; its size: that mode's partySize, capacity()), my role in it
## (host / member), the teammates, the invites I sent with
## their expiry, the invite shown to me, and the rows of the invite popup (OnlinePlayers).
## on_event(), tick() and the commands (invite(), respond(), kick(), set_ready(), confirm_ready(),
## set_character(), select_queue(), leave(), list()) return the actions the owner (screens/home/party.gd) carries out, in order:
##   ["send", event, data]  send it on the game socket
##   ["changed"]            the lobby (members, ready, status) changed: redraw the slot
##   ["players"]            the popup's rows changed (OnlinePlayers, an invite sent / answered)
##   ["invite", invite]     an invite to me (LobbyInvite): show it
##   ["invite_closed"]      the invite shown to me is gone (answered, expired)
##   ["toast", text]        tell the player
##   ["queue_started"]      the host started the queue and I am the member: off to Matchmaking
##   ["queue_refused"]      SetLobbyQueue refused (PARTY_TOO_LARGE): Home goes back to the lobby's queue
## Times are seconds on the owner's clock (`now`). An invite's lifetime is its expiresInSec
## (InviteSent / LobbyInvite), else the game data's matchmaking.inviteTimeoutSec.
## `queue` is the queue of the mode chosen on Home: every CreateLobby asks for it ({queue}), and
## select_queue() moves my lobby to another one (SetLobbyQueue, the host while preparing).
## Before the first invite without a lobby, CreateLobby goes first and the invite follows its
## LobbyUpdated; a CreateLobby refused because the server still has me in a lobby / a room leaves
## it (LeaveLobby / Leave) and asks again, once; an InviteToLobby answered LOBBY_REQUIRED /
## LOBBY_NOT_FOUND (my lobby is gone on the server) creates a new one and invites again (a CreateLobby
## answered LOBBY_NOT_FOUND, my old lobby closing, is asked again once); any other
## LOBBY_NOT_FOUND about my lobby (it closed under me: a SetReady, an UpdateLoadout, a
## SetLobbyQueue...) forgets it like LobbyDisbanded, with a toast (one answering my accepted
## invite is about the inviter's lobby: only the toast). The lobby
## filling up cancels my other invites on the server (it tells only their invitees): the
## "Đã mời" rows clear with the LobbyUpdated that fills it. Lobby errors are shown only within ERROR_WINDOW of
## a request of mine (other screens handle their own: the ranked queue, a match's leave).

const ErrorText := preload("res://screens/home/error_text.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
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
var queue := "" # the queue of the mode chosen on Home ("" the server's default)
var lobby := {} # parse_lobby() of the last LobbyUpdated; {} not in a lobby
var sent := {} # playerId -> expiry (s) of my invites still waiting
var incoming := {} # the invite shown to me: parse_invite() + expires_at; {} none
var players: Array = [] # parse_player() of the last OnlinePlayers
var _invite_after_create := "" # a playerId to invite once CreateLobby answers
var _inviting := "" # the playerId of the InviteToLobby waiting for its answer
var _create_retried := false
var _accepting := false # an accepted invite waits for its LobbyUpdated (a LOBBY_NOT_FOUND is about that lobby)
var _expect_until := -1.0 # a lobby error before this answers a request of mine


# ── Parsing ─────────────────────────────────────────────────────────────────

static func _num(v: Variant, fallback: int = 0) -> int:
	return int(v) if v is int or v is float else fallback


static func _str(v: Variant, fallback: String = "") -> String:
	return str(v) if v is String and str(v) != "" else fallback


## A LobbyMember: {playerId, displayName, characterId, level (0 unknown), rankBadge (last season's
## final grade: the slot's frame, "" none), ready, gun: {kind, tier}} (gun: the server's, else the character's basic gun); {} not a member.
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
		"level": _num(m.get("level")), "rankBadge": RankModel.badge_of(m), "ready": m.get("ready") == true, "gun": gun}


## A LobbyState: {lobbyId, hostPlayerId, status, queue, members: [parse_member()]} (the host always
## ready; queue: the server's, else the game data's rank.rankedMode, its default); {} without a
## lobbyId.
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
		"queue": _str(d.get("queue"), GameData.ranked_mode()), "members": members}


## An OnlinePlayer: {playerId, displayName, level, rankBadge ("" none), characterId, status (idle /
## in_lobby / in_match)}; {} not a player.
static func parse_player(p: Variant) -> Dictionary:
	if not p is Dictionary or _str(p.get("playerId")) == "":
		return {}
	var id := _str(p.get("playerId"))
	var status := _str(p.get("status"), IDLE)
	return {"playerId": id, "displayName": _str(p.get("displayName"), id.left(8)), "level": _num(p.get("level")),
		"rankBadge": RankModel.badge_of(p),
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


## The queue of my lobby (the mode its host chose); "" not in a lobby.
func lobby_queue() -> String:
	return str(lobby.get("queue", "")) if in_lobby() else ""


## Me and at least one teammate in the lobby.
func in_party() -> bool:
	return not teammate().is_empty()


## The first other member of my lobby; {} none.
func teammate() -> Dictionary:
	var all := teammates()
	return all[0] if not all.is_empty() else {}


## The other members of my lobby, in its order; [] none.
func teammates() -> Array:
	if not in_lobby():
		return []
	return lobby["members"].filter(func(m): return m["playerId"] != me)


## How many the party holds: the partySize of the mode with my lobby's queue (else the queue chosen
## on Home): 2 for 2v2, 4 for a boss; 2 when the game data does not say.
func capacity() -> int:
	return capacity_of(lobby_queue() if in_lobby() else queue)


static func capacity_of(q: String) -> int:
	var size = GameData.lobby_mode_of_queue(q).get("partySize")
	return maxi(int(size), 1) if size is int or size is float else 2


## My lobby has as many members as its mode holds (no more invites).
func is_full() -> bool:
	return in_lobby() and lobby["members"].size() >= capacity()


## The members (me too); 1 not in a lobby.
func member_count() -> int:
	return lobby["members"].size() if in_lobby() else 1


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
	if teammates().any(func(m): return not bool(m.get("ready", false))):
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
	return {"text": "Mời", "disabled": is_full() or is_member()}


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
	if player_id == "" or player_id == me or is_full() or is_member():
		return []
	_expect(now)
	_create_retried = false
	if not in_lobby():
		_invite_after_create = player_id
		return [_create_lobby()]
	_inviting = player_id
	return [["send", "InviteToLobby", {"playerId": player_id}]]


## CreateLobby {queue} (the mode chosen on Home); {} without one.
func _create_lobby() -> Array:
	return ["send", "CreateLobby", {"queue": queue} if queue != "" else {}]


## The host chose another mode on Home: remembered for CreateLobby, and my lobby (while preparing)
## moves to its queue: SetLobbyQueue {queue}.
func select_queue(q: String, now: float) -> Array:
	queue = q
	if q == "" or not is_host() or str(lobby.get("status", "")) != "preparing" or lobby_queue() == q:
		return []
	_expect(now)
	return [["send", "SetLobbyQueue", {"queue": q}]]


## Answers the invite shown to me.
func respond(accept: bool, now: float) -> Array:
	if incoming.is_empty():
		return []
	var id: String = incoming["inviteId"]
	incoming = {}
	_accepting = accept
	_expect(now)
	return [["send", "RespondInvite", {"inviteId": id, "accept": accept}], ["invite_closed"]]


## The host takes a teammate out: player_id, or the first teammate for "".
func kick(now: float, player_id: String = "") -> Array:
	var mate := teammate()
	if player_id != "":
		mate = {}
		for m in teammates():
			if m["playerId"] == player_id:
				mate = m
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
	_accepting = false
	lobby = next
	var out: Array = [["changed"]]
	if is_full():
		sent.clear() # the server cancelled the other invites
		out.append(["players"])
	if _invite_after_create != "":
		var id := _invite_after_create
		_invite_after_create = ""
		if is_host() and not is_full():
			_inviting = id
			out.append(["send", "InviteToLobby", {"playerId": id}])
	return out


func _on_error(data: Variant, now: float) -> Array:
	var code := ErrorText.lobby_code(data)
	var accepting := _accepting # this error answers my accepted invite
	_accepting = false
	if code == "PARTY_TOO_LARGE":
		# SetLobbyQueue to a mode smaller than the party: the lobby keeps its queue.
		_expect_until = -1.0
		return [["toast", ErrorText.lobby_error(data)], ["queue_refused"], ["changed"]]
	if _invite_after_create != "":
		# The CreateLobby before an invite was refused.
		if not _create_retried and code in ["ALREADY_IN_LOBBY", "IN_ROOM", "LOBBY_NOT_FOUND"]:
			_create_retried = true
			_expect(now)
			if code == "LOBBY_NOT_FOUND": # my old lobby was closing: the server forgot it, ask again
				lobby = {}
				return [_create_lobby()]
			return [["send", "LeaveLobby" if code == "ALREADY_IN_LOBBY" else "Leave", {}], _create_lobby()]
		_invite_after_create = ""
		return [["toast", ErrorText.lobby_error(data)]]
	if code == "LOBBY_NOT_FOUND" and _inviting == "":
		if not accepting and in_lobby():
			# My lobby closed under me (the server already dropped me from it).
			forget()
			_expect_until = -1.0
			return [["toast", ErrorText.lobby_error(data)], ["changed"]]
	if _inviting != "" and now <= _expect_until:
		var id := _inviting
		_inviting = ""
		if code in ["LOBBY_REQUIRED", "LOBBY_NOT_FOUND"] and not _create_retried:
			# My lobby is gone on the server: a new one, then the invite again.
			lobby = {}
			_create_retried = true
			_invite_after_create = id
			_expect(now)
			return [["changed"], _create_lobby()]
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
