extends RefCounted
## A queue mode's queue (Đấu hạng, Đấu thường: `queue`, the lobby's) over the game socket, without
## the socket: start(), cancel(), on_event()
## and tick() return the actions the owner (screens/matchmaking.gd) carries out, in order:
##   ["send", event, data]  send it on the socket
##   ["searching"]          in the queue (QueueStarted): the timer starts
##   ["found", data]        MatchFound: the cards flip
##   ["started", data]      MatchStarted: the owner holds the socket and opens the match
##   ["failed", message]    the queue ended with an error (back to Home with the message)
##   ["cancelled"]          the player's cancel went through (back to Home)
##
## Each step waits for its answer (the server takes them in order either way): CreateLobby {queue} →
## LobbyUpdated → UpdateLoadout {characterId, items} → LobbyUpdated → StartQueue → QueueStarted →
## MatchFound → MatchStarted (~3 s later; the server moves the socket into the battle room itself,
## nothing is sent to join). The lobby outlives a match, and CreateLobby from its host returns it,
## so "Chơi tiếp" runs the same steps. A server that refuses CreateLobby because the player is in
## a lobby or a room: LeaveLobby / Leave, then CreateLobby again (RETRIES times, RETRY_SEC apart).
## Cancel: CancelQueue → QueueCancelled, then LeaveLobby (a solo host disbands it); a cancel that
## came too late gets no QueueCancelled but MatchFound, and the match goes on. Every error after
## the lobby exists leaves it too. A step without an answer for STEP_TIMEOUT fails; a cancel
## without one after CANCEL_TIMEOUT leaves anyway; MatchStarted not coming FOUND_TIMEOUT after
## MatchFound fails.
## A party (keep_lobby, set by the owner while the lobby has two members): no step ever leaves
## the lobby (the teammate stays in it): a cancel is CancelQueue → QueueCancelled → back Home, an
## error goes Home with its message, ALREADY_IN_LOBBY (the lobby not reopened since the match yet)
## is asked again without leaving. start_member(): the party's member, whose host started the queue
## (QueueStarted already came): searching at once; its cancel leaves the lobby (LeaveLobby: the
## server cancels the queue for both), a host's cancel or an error ends it without leaving.

const ErrorText := preload("res://screens/home/error_text.gd")
const GameData := preload("res://autoload/game_data_model.gd")

enum Phase { IDLE, CREATING, WAIT_RETRY, LOADOUT, QUEUEING, SEARCHING, CANCELLING, FOUND, DONE }

const STEP_TIMEOUT := 10.0
const CANCEL_TIMEOUT := 3.0
## MatchStarted not coming this long after MatchFound gives up; at least the server's
## matchmaking.matchStartDelaySec + STEP_TIMEOUT (found_timeout()).
const FOUND_TIMEOUT := 20.0
const RETRY_SEC := 0.6
const RETRIES := 2

const NO_ANSWER := "Server không phản hồi, hãy thử lại"
const QUEUE_ENDED := "Đã dừng ghép trận"
const NOT_STARTED := "Không vào được trận, hãy thử lại"
const DISCONNECTED := "Mất kết nối, hãy thử lại khi online"

var phase := Phase.IDLE
var loadout := {} # {characterId, items}
var queue := "" # the queue CreateLobby asks for ("" the server's default)
var _wait := 0.0 # seconds left before the current step times out (or the retry is sent)
var _retries := 0
var _cancel_asked := false # cancel() while the lobby was being created
var _found := false # MatchFound came
var keep_lobby := false # a party: never leave the lobby (see above)
var member := false # start_member(): the party's member, in the host's queue


## How long MatchStarted may take after MatchFound.
static func found_timeout() -> float:
	return maxf(FOUND_TIMEOUT, GameData.match_start_delay_sec() + STEP_TIMEOUT)


func start(chosen: Dictionary, on_queue: String = "") -> Array:
	queue = on_queue
	loadout = {"characterId": str(chosen.get("characterId", GameData.default_character_id())), "items": chosen.get("items", []).duplicate()}
	_retries = 0
	_cancel_asked = false
	return _create()


## The party's member in the host's queue: searching at once.
func start_member() -> Array:
	member = true
	keep_lobby = true
	_cancel_asked = false
	phase = Phase.SEARCHING
	return [["searching"]]


func _create() -> Array:
	phase = Phase.CREATING
	_wait = STEP_TIMEOUT
	return [["send", "CreateLobby", {"queue": queue} if queue != "" else {}]]


## The player pressed "Hủy ghép". Nothing to do once the match is found.
func cancel() -> Array:
	match phase:
		Phase.CREATING:
			_cancel_asked = true # LeaveLobby once the lobby exists
			return []
		Phase.WAIT_RETRY:
			return _finish([["cancelled"]])
		Phase.LOADOUT:
			return _finish(_leave_then([["cancelled"]]))
		Phase.QUEUEING, Phase.SEARCHING:
			if member:
				return _finish([["send", "LeaveLobby", {}], ["cancelled"]])
			phase = Phase.CANCELLING
			_wait = CANCEL_TIMEOUT
			return [["send", "CancelQueue", {}]]
	return []


func busy() -> bool:
	return phase != Phase.IDLE and phase != Phase.DONE


## True once nothing can stop the match (MatchFound).
func found() -> bool:
	return phase == Phase.FOUND or (phase == Phase.DONE and _found)


func _finish(actions: Array) -> Array:
	phase = Phase.DONE
	return actions


func _fail(message: String, leave: bool) -> Array:
	var out: Array = [["send", "LeaveLobby", {}]] if leave and not keep_lobby else []
	out.append(["failed", message])
	return _finish(out)


func tick(delta: float) -> Array:
	if phase in [Phase.IDLE, Phase.DONE, Phase.SEARCHING]:
		return []
	_wait -= delta
	if _wait > 0.0:
		return []
	match phase:
		Phase.WAIT_RETRY:
			if _cancel_asked:
				return _finish([["cancelled"]])
			return _create()
		Phase.CREATING:
			return _finish([["cancelled"]]) if _cancel_asked else _fail(NO_ANSWER, false)
		Phase.LOADOUT, Phase.QUEUEING:
			return _fail(NO_ANSWER, true)
		Phase.CANCELLING:
			return _finish(_leave_then([["cancelled"]]))
		Phase.FOUND:
			return _fail(NOT_STARTED, false)
	return []


## The socket closed: the server cancels the queue and drops the lobby by itself.
func on_disconnected() -> Array:
	if not busy():
		return []
	return _fail(DISCONNECTED, false)


func on_event(event: String, data: Variant) -> Array:
	if not busy():
		return []
	if event == "MatchFound" and phase in [Phase.QUEUEING, Phase.SEARCHING, Phase.CANCELLING]:
		phase = Phase.FOUND # a cancel that lost the race: the match goes on
		_found = true
		_wait = found_timeout()
		return [["found", data]]
	if event == "MatchStarted" and phase == Phase.FOUND:
		return _finish([["started", data]])
	var err := event == "LobbyError" or event == "Error"
	match phase:
		Phase.CREATING:
			if event == "LobbyUpdated":
				if _cancel_asked:
					return _finish(_leave_then([["cancelled"]]))
				phase = Phase.LOADOUT
				_wait = STEP_TIMEOUT
				return [["send", "UpdateLoadout", loadout.duplicate(true)]]
			if err:
				return _on_create_error(data)
		Phase.LOADOUT:
			if event == "LobbyUpdated":
				phase = Phase.QUEUEING
				_wait = STEP_TIMEOUT
				return [["send", "StartQueue", {}]]
			if err:
				return _fail(ErrorText.lobby_error(data), true)
		Phase.QUEUEING:
			if event == "QueueStarted":
				phase = Phase.SEARCHING
				return [["searching"]]
			if err:
				return _fail(ErrorText.lobby_error(data), true)
			if event == "QueueCancelled":
				return _fail(QUEUE_ENDED, true)
		Phase.SEARCHING:
			if event == "QueueCancelled":
				return _fail(QUEUE_ENDED, true)
			if event == "LobbyDisbanded":
				return _fail(QUEUE_ENDED, false)
			if err:
				return _fail(ErrorText.lobby_error(data), true)
		Phase.CANCELLING:
			if event == "QueueCancelled" or err:
				return _finish(_leave_then([["cancelled"]]))
			if event == "LobbyDisbanded":
				return _finish([["cancelled"]])
	return []


## LeaveLobby then `actions`; a party keeps its lobby: `actions` only.
func _leave_then(actions: Array) -> Array:
	return actions if keep_lobby else [["send", "LeaveLobby", {}]] + actions


## CreateLobby refused: still in the last lobby or a room (leave it and try again), the old
## lobby not gone yet (try again), anything else fails.
func _on_create_error(data: Variant) -> Array:
	var code := ErrorText.lobby_code(data)
	var leave := []
	match code:
		"ALREADY_IN_LOBBY":
			leave = [] if keep_lobby else [["send", "LeaveLobby", {}]] # a party: the lobby reopens, ask again
		"IN_ROOM":
			leave = [["send", "Leave", {}]]
		"LOBBY_CREATE_FAILED":
			pass
		"LOBBY_REQUIRED", "NOT_IN_QUEUE":
			return [] # a late answer to the last match's LeaveLobby / CancelQueue, not to CreateLobby
		_:
			return _finish([["cancelled"]]) if _cancel_asked else _fail(ErrorText.lobby_error(data), false)
	if _retries >= RETRIES:
		return _fail(ErrorText.lobby_error(data), code == "ALREADY_IN_LOBBY")
	_retries += 1
	phase = Phase.WAIT_RETRY
	_wait = RETRY_SEC
	return leave
