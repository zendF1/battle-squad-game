extends RefCounted
## Đăng xuất (spec ../battle-squad/docs/specs/2026-10-30-settings-account-link.md, "settings with a
## left menu"): the settings popup's Tài khoản section asks first (confirm_text()), then run():
## - everything of the account on this device is forgotten at once, so the next sign-in (another
##   account) shows nothing of this one: the party (LeaveLobby while the socket is up), the chat /
##   friends state, the match / queue payloads and the mode picked (Router.reset_account()); the game
##   socket closed, no redial (GameSocket.close()); the profile and every per-account cache
##   (PlayerState.reset_account(): characters, bag, stones, milestones, titles, missions, rank,
##   chests, season rewards, leaderboards, the rewards watch); the guild (GuildState.reset_account());
##   the tokens and the player's id / name (Session.clear_tokens()); the last character / items /
##   mode picked (user://loadout.cfg);
## - then POST /auth/logout {refreshToken} revokes the refresh session on the server, not awaited:
##   the player is on the login screen at once, even offline.
## Kept: the device install id (a guest's "Chơi ngay" on this device gets the same account back),
## the terms tick, game data, the map list and legal texts (not the account's), and the purchase
## idempotency keys (per player: a retried purchase of this account still settles once).

const LoadoutModel := preload("res://screens/loadout_model.gd")
const AccountLink := preload("res://core/account_link.gd")

## The confirm's line: how to get this account back after logging out.
const GUEST_TEXT := "Bấm \"Chơi ngay\" trên máy này để vào lại tài khoản."
const LINKED_TEXT := "Đăng nhập lại bằng %s để vào lại tài khoản."

## What logout clears: the autoloads, or stand-ins set by the tests.
var session: Object
var api: Object
var player_state: Object
var guild_state: Object
var socket: Object
var router: Object
## Per-account files under user:// removed on logout.
var files: Array[String] = [LoadoutModel.SETTINGS_PATH]


func _init() -> void:
	session = Session
	api = Api
	player_state = PlayerState
	guild_state = GuildState
	socket = GameSocket
	router = Router


## The confirm's line for `profile`. A guest is not lost by logging out (the device install id stays,
## so "Chơi ngay" on this device signs into it again); a linked account comes back with its provider.
static func confirm_text(profile: Variant) -> String:
	var linked := AccountLink.linked_providers(profile)
	if linked.is_empty():
		return GUEST_TEXT
	var names := PackedStringArray()
	for p in linked:
		names.append(AccountLink.provider_name(p))
	return LINKED_TEXT % " hoặc ".join(names)


## Logs out: clears this device's copy of the account, then revokes the refresh session (not awaited).
func run() -> void:
	var refresh: String = session.refresh_token
	clear()
	if refresh != "":
		api.request(HTTPClient.METHOD_POST, "/auth/logout", {"refreshToken": refresh}, false, false)


## Forgets everything of the signed-in account on this device (see the file's header).
func clear() -> void:
	router.reset_account()
	socket.close()
	player_state.reset_account()
	guild_state.reset_account()
	session.clear_tokens()
	for path in files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
