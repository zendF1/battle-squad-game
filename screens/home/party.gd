extends Node
## The 2v2 party of a party mode (Đấu thường / Đấu hạng) over the game socket (screens/home/party_model.gd does the deciding), kept
## by the Router (Router.party) so it lives through every scene: Home → Loadout → Matchmaking →
## Match → Home. It sends what the model asks, re-emits the rest as signals for Home (the slot, the
## popups, toasts), and when the host starts the queue while I am the member it takes me to
## Matchmaking as the party's member (Router.ranked_member) from wherever I am.

signal changed
signal players_changed
signal invite_received(invite: Dictionary)
signal invite_closed
signal notice(text: String)

const PartyModel := preload("res://screens/home/party_model.gd")

var model := PartyModel.new()


func _ready() -> void:
	GameSocket.event_received.connect(_on_event)
	GameSocket.disconnected.connect(func() -> void: _run(model.on_disconnected()))


## Seconds on the party's clock (the invites' expiries).
static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	_run(model.tick(now()))


func _on_event(event: String, data: Variant) -> void:
	model.me = Session.player_id
	_run(model.on_event(event, data, now()))


func list(query: String) -> void:
	_run(model.list(query))


func invite(player_id: String) -> void:
	model.me = Session.player_id
	_run(model.invite(player_id, now()))


func respond(accept: bool) -> void:
	_run(model.respond(accept, now()))


func kick() -> void:
	_run(model.kick(now()))


func set_ready(value: bool) -> void:
	_run(model.set_ready(value, now()))


## The member's Loadout confirmed: UpdateLoadout {characterId, items} + SetReady true.
func confirm_ready(loadout: Dictionary) -> void:
	_run(model.confirm_ready(loadout, now()))


## The Home stage's character, for the teammate's slot (only with a teammate).
func set_character(character_id: String) -> void:
	_run(model.set_character(character_id, now()))


## The mode chosen on Home: its queue for CreateLobby, and SetLobbyQueue when I host a lobby.
func select_queue(queue: String) -> void:
	model.me = Session.player_id
	_run(model.select_queue(queue, now()))


## LeaveLobby (every LeaveLobby of the client goes through here, so the party knows it left).
func leave() -> void:
	_run(model.leave())


func _run(actions: Array) -> void:
	for a in actions:
		match a[0]:
			"send":
				GameSocket.send(a[1], a[2])
			"changed":
				changed.emit()
			"players":
				players_changed.emit()
			"invite":
				invite_received.emit(a[1])
			"invite_closed":
				invite_closed.emit()
			"toast":
				notice.emit(str(a[1]))
			"queue_started":
				_to_matchmaking()


## The host's queue started: Matchmaking as the member (my lobby character on my card), on the
## lobby's queue.
func _to_matchmaking() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == Router.MATCHMAKING:
		return
	var mine := model.my_member()
	Router.ranked_member = true
	Router.queue = model.lobby_queue()
	Router.ranked_loadout = {"characterId": str(mine.get("characterId", "")), "items": []}
	Router.go(Router.MATCHMAKING)
