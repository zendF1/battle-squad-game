extends Node
## The signed-in player's profile (GET /player/profile: name, level, exp, coin, gem), shared by
## the Home shell's top bar and tabs. An autoload because it outlives the Home scene: back from
## a match (Router rebuilds Home) the bar shows the last values at once while refresh() fetches
## the new ones, and the pending purchase keys must survive the same rebuild.
##
## refresh() never blocks: it starts a request and emits `changed` when it ends. A refresh asked
## while one is in flight runs again afterwards, so an answer that may predate a purchase is
## never the last word. Screens that change the player's assets (purchase, IAP, stat reset)
## call assets_changed(): the wallet refreshes and `assets_dirty` tells the other tabs to reload
## characters / inventory.

signal changed # profile, loading or error changed
signal assets_dirty # inventory, characters or purchases changed on the server

const IdempotencyKeys := preload("res://core/idempotency_keys.gd")

var profile: Dictionary = {} # last GET /player/profile data; {} until loaded
var loading := false
var error := "" # last refresh failure (Vietnamese), "" after a success

## POST /shop/purchase idempotencyKey and POST /iap/verify mock purchaseToken, per player+target.
var purchase_keys := IdempotencyKeys.new("", "user://purchase_keys.cfg")
var iap_tokens := IdempotencyKeys.new("mock_", "user://iap_tokens.cfg")

var _again := false


func is_loaded() -> bool:
	return not profile.is_empty()


func display_name() -> String:
	return str(profile.get("displayName", Session.display_name))


func level() -> int:
	return int(profile.get("level", 1))


func player_exp() -> int:
	return int(profile.get("exp", 0))


func coin() -> int:
	return int(profile.get("coin", 0))


func gem() -> int:
	return int(profile.get("gem", 0))


## Takes a GET /player/profile data (also used by Splash, which already fetched it).
func apply(data: Variant) -> void:
	if not data is Dictionary:
		return
	profile = data
	error = ""
	Session.set_profile(str(data.get("playerId", "")), str(data.get("displayName", "")))
	changed.emit()


func refresh() -> void:
	if loading:
		_again = true
		return
	if str(profile.get("playerId", Session.player_id)) != Session.player_id:
		profile = {} # another account signed in on this device
	loading = true
	changed.emit()
	while true:
		_again = false
		var res: Dictionary = await Api.get_json("/player/profile")
		if res.ok and res.data is Dictionary:
			apply(res.data)
		else:
			error = "Không tải được hồ sơ" if res.status != 0 else "Mất kết nối"
		if not _again:
			break
	loading = false
	changed.emit()


## A display name the server accepted: shown at once, then confirmed by a refresh.
func renamed(name: String) -> void:
	profile["displayName"] = name
	Session.set_profile("", name)
	changed.emit()
	refresh()


func assets_changed() -> void:
	refresh()
	assets_dirty.emit()


## Per-player key target ids, so another account on this device never sends them.
func key_target(id: String) -> String:
	return "%s/%s" % [Session.player_id, id]
