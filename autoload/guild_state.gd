extends Node
## The signed-in player's guild (Bang hội, contract guilds.md) shared by the lobby, the guild page
## and the other features that ask "am I in a guild": an autoload like PlayerState, so it outlives
## Home. Everything parsed by screens/guild/guild_model.gd.
##
## Loads (coalesced, never blocking; each emits its signal once applied):
## - load_me(): GET /guilds/me → `guild` (GuildModel.parse_guild(), {} when not in one: a 404),
##   `known` true once answered; the lobby loads it each time it shows;
## - load_activity(): GET /guilds/{id}/activity → `activity` (quest + today's dungeon);
## - load_rankings(): GET /guilds/rankings → `rankings`;
## - load_invites(): GET /guilds/invites → `invites`.
## Actions run one at a time (`busy`, the action's name): create(name), accept(guild_id),
## decline(guild_id), invite(player_id), act(action, player_id) (kick / promote / demote /
## transfer), leave(), disband(), open_dungeon(boss_id). Each returns the Api result (ok, code,
## data) and reloads what it changed whatever the answer; create() refreshes the wallet.
##
## Hooks for the other features (chat's Bang hội tab, the friends list's "Mời vào bang hội"):
## guild_id() / in_guild() / my_role() / can_invite(), the `changed` signal, and
## invite_player(host, player_id): the invite with its toast. The chat / friends state
## (Router.social) is plugged in at start: its "Mời vào guild" action
## sends invite_player() (allowed while I may invite and the player is not in my guild), and each
## answer about my guild tells it my guild id (set_guild()).

signal changed # guild, known or loading changed (my membership, the roster, level / EXP)
signal activity_changed
signal rankings_changed
signal invites_changed
signal busy_changed

const GuildModel := preload("res://screens/guild/guild_model.gd")
const Coalescer := preload("res://core/coalescer.gd")
const ErrorText := preload("res://screens/home/error_text.gd")

var guild: Dictionary = {} # GuildModel.parse_guild() of my guild; {} not in one (or not known yet)
var known := false # a GET /guilds/me answered for this account (guild is the truth)
var loading := false
var error := "" # the last load_me() failure (Vietnamese)
var activity: Dictionary = {} # GuildModel.parse_activity() of my guild; {} not loaded
var activity_error := ""
var rankings: Array = [] # GuildModel.parse_rankings()
var rankings_loaded := false
var rankings_error := ""
var invites: Array = [] # GuildModel.parse_invites()
var invites_loaded := false
## The inviting guilds' summaries (GET /guilds/{id}: level, members), guild id → parse_guild();
## fetched after the invites, at most INVITE_DETAILS of them, each once a session.
var invite_guilds := {}
const INVITE_DETAILS := 10
var busy := "" # the action running ("" none)

var _player := "" # whose guild this is
var _me_gate := Coalescer.new()
var _activity_gate := Coalescer.new()
var _rankings_gate := Coalescer.new()
var _invites_gate := Coalescer.new()

## Tests swap in a fake with get_json / post_json / request.
var api: Object = null


func _api() -> Object:
	return api if api != null else Api


func _ready() -> void:
	changed.connect(_sync_social)
	_hook_social.call_deferred() # after the Router (an autoload after this one) made its parts


## The chat / friends state (Router.social, screens/social/social.gd); null before the Router made it.
func _social() -> Object:
	var s = Router.get("social") if is_instance_valid(Router) else null
	return s if s is Object and is_instance_valid(s) else null


func _hook_social() -> void:
	var s := _social()
	if s == null or not s.has_method("set_guild_invite"):
		return
	s.set_guild_invite(func(player_id: String, _display_name: String) -> void:
		var host = get_tree().current_scene
		invite_player(host if host is Control else null, player_id),
		func(player_id: String) -> bool: return can_invite() and GuildModel.role_of(guild, player_id) == "")
	_sync_social()


## Tells the chat my guild (the Bang hội conversation) once this account's guild is known.
func _sync_social() -> void:
	var s := _social()
	if s != null and known and s.has_method("set_guild"):
		s.set_guild(guild_id())


# ── For other features ──────────────────────────────────────────────────────

## My guild's id ("" not in one, or not known yet).
func guild_id() -> String:
	_check_account()
	return str(guild.get("id", ""))


func in_guild() -> bool:
	return guild_id() != ""


## My role in my guild (GuildModel.LEADER / DEPUTY / MEMBER; "" not in one).
func my_role() -> String:
	return GuildModel.role_of(guild, Session.player_id) if in_guild() else ""


## I may invite (leader or deputy).
func can_invite() -> bool:
	return GuildModel.can_manage(my_role())


## Invites `player_id` to my guild and says how it went as a toast on `host`.
func invite_player(host: Control, player_id: String) -> Dictionary:
	var res := await invite(player_id)
	if host != null and is_instance_valid(host):
		load("res://ui/ui.gd").toast(host, "Đã gửi lời mời vào bang hội" if res.ok else GuildModel.error_text(res, "invite"))
	return res


## Another account signed in on this device: forget the last one's guild.
func _check_account() -> void:
	if _player != Session.player_id:
		_player = Session.player_id
		guild = {}
		known = false
		activity = {}
		invites = []
		invites_loaded = false
		invite_guilds = {}


## Signed out (core/logout.gd): forgets the guild, its activity, the rankings, the invites and the
## action running, so the next sign-in starts empty. No signal: the scene goes to Login.
func reset_account() -> void:
	_player = ""
	guild = {}
	known = false
	loading = false
	error = ""
	activity = {}
	activity_error = ""
	rankings = []
	rankings_loaded = false
	rankings_error = ""
	invites = []
	invites_loaded = false
	invite_guilds = {}
	busy = ""


# ── Loads ───────────────────────────────────────────────────────────────────

func load_me() -> void:
	_check_account()
	if not _me_gate.ask():
		return
	loading = true
	error = ""
	changed.emit()
	while true:
		var t := _me_gate.ticket()
		var player := Session.player_id
		var res: Dictionary = await _api().get_json("/guilds/me")
		if not _me_gate.finish(t):
			continue
		if player != Session.player_id:
			break
		if res.ok:
			_take_guild(res.data)
		elif int(res.get("status", 0)) == 404:
			_take_guild(null)
		else:
			error = ErrorText.load_failed(res)
		break
	loading = false
	changed.emit()


func _take_guild(d: Variant) -> void:
	var before := guild_id()
	guild = GuildModel.parse_guild(d)
	known = true
	if guild_id() != before:
		activity = {}
		activity_changed.emit()


func load_activity() -> void:
	if not in_guild() or not _activity_gate.ask():
		return
	activity_error = ""
	while true:
		var t := _activity_gate.ticket()
		var id := guild_id()
		var res: Dictionary = await _api().get_json("/guilds/%s/activity" % id)
		if not _activity_gate.finish(t):
			continue
		if id != guild_id():
			break
		if res.ok:
			activity = GuildModel.parse_activity(res.data)
		else:
			activity_error = ErrorText.load_failed(res)
		break
	activity_changed.emit()


func load_rankings() -> void:
	if not _rankings_gate.ask():
		return
	rankings_error = ""
	while true:
		var t := _rankings_gate.ticket()
		var res: Dictionary = await _api().get_json("/guilds/rankings")
		if not _rankings_gate.finish(t):
			continue
		if res.ok:
			rankings = GuildModel.parse_rankings(res.data)
			rankings_loaded = true
		else:
			rankings_error = ErrorText.load_failed(res)
		break
	rankings_changed.emit()


func load_invites() -> void:
	_check_account()
	if not _invites_gate.ask():
		return
	while true:
		var t := _invites_gate.ticket()
		var res: Dictionary = await _api().get_json("/guilds/invites")
		if not _invites_gate.finish(t):
			continue
		if res.ok:
			invites = GuildModel.parse_invites(res.data)
			invites_loaded = true
		break
	invites_changed.emit()
	_load_invite_guilds()


## The invites' guild summaries not fetched yet (the first INVITE_DETAILS invites only).
func _load_invite_guilds() -> void:
	var asked := false
	for inv in invites.slice(0, INVITE_DETAILS):
		var id: String = inv["guild_id"]
		if invite_guilds.has(id):
			continue
		invite_guilds[id] = {} # asked
		var res: Dictionary = await _api().get_json("/guilds/%s" % id)
		if res.ok:
			invite_guilds[id] = GuildModel.parse_guild(res.data)
			asked = true
	if asked:
		invites_changed.emit()


## Mine and the guild's state after a change: the guild, its activity, the invites.
func reload() -> void:
	load_me()
	if in_guild():
		load_activity()
	load_invites()


# ── Actions ─────────────────────────────────────────────────────────────────

## POST /guilds {name}: pays the game data's createCost; the wallet refreshes whatever the answer.
func create(guild_name: String) -> Dictionary:
	var res := await _run("create", func() -> Dictionary: return await _api().post_json("/guilds", {"name": guild_name.strip_edges()}))
	if res.ok:
		_take_guild(res.data)
		changed.emit()
	PlayerState.refresh()
	return res


func accept(id: String) -> Dictionary:
	return await _guild_post("accept", id, null)


## POST /guilds/{id}/decline (idempotent): the invite leaves the list at once.
func decline(id: String) -> Dictionary:
	invites = invites.filter(func(i): return i["guild_id"] != id)
	invites_changed.emit()
	return await _guild_post("decline", id, null)


func invite(player_id: String) -> Dictionary:
	return await _guild_post("invite", guild_id(), {"playerId": player_id})


## kick / promote / demote / transfer on `player_id`.
func act(action: String, player_id: String) -> Dictionary:
	return await _guild_post(action, guild_id(), {"playerId": player_id})


func leave() -> Dictionary:
	return await _guild_post("leave", guild_id(), null)


func disband() -> Dictionary:
	return await _guild_post("disband", guild_id(), null)


## POST /guilds/{id}/dungeon {bossId}: today's challenge (activity reloads).
func open_dungeon(boss_id: String) -> Dictionary:
	var id := guild_id()
	var res := await _run("dungeon", func() -> Dictionary: return await _api().post_json("/guilds/%s/dungeon" % id, {"bossId": boss_id}))
	if res.ok and res.data is Dictionary:
		activity["dungeon"] = GuildModel.parse_dungeon(res.data)
		activity_changed.emit()
	load_activity()
	return res


func _guild_post(action: String, id: String, body: Variant) -> Dictionary:
	if id == "":
		return {"ok": false, "status": 404, "code": "NOT_FOUND", "message": "", "data": null}
	var res := await _run(action, func() -> Dictionary:
		return await _api().request(HTTPClient.METHOD_POST, "/guilds/%s/%s" % [id, action], body if body != null else {}))
	if action != "invite":
		reload()
	return res


func _run(action: String, call: Callable) -> Dictionary:
	if busy != "":
		return {"ok": false, "status": -1, "code": "BUSY", "message": "", "data": null}
	busy = action
	busy_changed.emit()
	var res: Dictionary = await call.call()
	busy = ""
	busy_changed.emit()
	return res
