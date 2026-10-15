extends Node
## The signed-in player's profile (GET /player/profile: name, level, exp, coin, gem) and owned
## characters (GET /player/characters), shared by the Home shell's top bar and tabs. An autoload
## because it outlives the Home scene: back from a match (Router rebuilds Home) the bar shows the
## last values at once while refresh() fetches the new ones, and a purchase in flight when Home
## is freed still settles its key here (an await on a freed node never resumes).
##
## refresh() / load_characters() never block: they start a request and emit `changed` /
## `characters_changed` when it ends. A refresh asked while one is in flight runs again
## afterwards and only that newer answer is applied (core/coalescer.gd), so an answer that may
## predate a purchase is never the last word. buy() / top_up() run POST /shop/purchase and
## POST /iap/verify with the stored idempotency key, settle it, and refresh the assets.
## Screens that change the player's assets call assets_changed(): the wallet refreshes, the
## characters cache goes stale and `assets_dirty` tells the tabs to reload what they show.

signal changed # profile, loading or error changed
signal assets_dirty # inventory, characters or purchases changed on the server
signal characters_changed # characters, characters_loading or characters_error changed
signal busy_changed # a purchase or top-up started or ended

const IdempotencyKeys := preload("res://core/idempotency_keys.gd")
const Coalescer := preload("res://core/coalescer.gd")
const ErrorText := preload("res://screens/home/error_text.gd")

var profile: Dictionary = {} # last GET /player/profile data; {} until loaded
var loading := false
var error := "" # last refresh failure (Vietnamese), "" after a success

## POST /shop/purchase idempotencyKey and POST /iap/verify mock purchaseToken, per player+target.
var purchase_keys := IdempotencyKeys.new("", "user://purchase_keys.cfg")
var iap_tokens := IdempotencyKeys.new("mock_", "user://iap_tokens.cfg")

## Last GET /player/characters data ({characters, resetStatsCost}); null until loaded.
var characters: Variant = null
var characters_loading := false
var characters_error := "" # Vietnamese; "" after a success
var characters_stale := true # loaded before the last asset change (or never)
var characters_version := 0 # bumped each time a GET /player/characters answer is applied
var _characters_player := "" # whose characters these are

## The offerId / productId being bought, "" when none: one purchase or top-up at a time.
var busy_id := ""

var _profile_gate := Coalescer.new()
var _characters_gate := Coalescer.new()
var _known_ids := {} # purchaseIds / transactionIds this client has seen (replay detection)


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
	if not _profile_gate.ask():
		return
	if str(profile.get("playerId", Session.player_id)) != Session.player_id:
		profile = {} # another account signed in on this device
	loading = true
	changed.emit()
	while true:
		var t := _profile_gate.ticket()
		var res: Dictionary = await Api.get_json("/player/profile")
		if not _profile_gate.finish(t):
			continue # a newer refresh was asked meanwhile: this answer may be stale
		if res.ok and res.data is Dictionary:
			apply(res.data)
		else:
			error = "Không tải được hồ sơ" if res.status != 0 else "Mất kết nối"
		break
	loading = false
	changed.emit()


## Loads GET /player/characters unless a fresh copy is cached or already on its way (an asset
## change during that request makes it fetch again by itself).
func need_characters() -> void:
	if _characters_player != Session.player_id:
		characters = null # another account signed in on this device
	if not _characters_gate.running and (characters == null or characters_stale):
		load_characters()


func load_characters() -> void:
	if not _characters_gate.ask():
		return
	characters_loading = true
	characters_error = ""
	characters_changed.emit()
	while true:
		var t := _characters_gate.ticket()
		var player := Session.player_id
		var res: Dictionary = await Api.get_json("/player/characters")
		if not _characters_gate.finish(t):
			continue
		var data = res.data if res.ok else null
		if data is Dictionary and data.get("characters") is Array:
			characters = data
			characters_stale = false
			characters_version += 1
			_characters_player = player
		else:
			characters_error = ErrorText.load_failed(res) if not res.ok else "Dữ liệu nhân vật không hợp lệ"
		break
	characters_loading = false
	characters_changed.emit()


## A display name the server accepted: shown at once, then confirmed by a refresh.
func renamed(name: String) -> void:
	profile["displayName"] = name
	Session.set_profile("", name)
	changed.emit()
	refresh()


func assets_changed() -> void:
	refresh()
	characters_stale = true
	if _characters_gate.running:
		load_characters() # the answer in flight may predate the change: fetch again
	assets_dirty.emit()


## Ids already listed by GET /shop/purchases, so a replayed answer is recognised.
func note_purchases(purchases: Array) -> void:
	for p in purchases:
		if p is Dictionary and str(p.get("purchaseId", "")) != "":
			_known_ids[str(p["purchaseId"])] = true


## POST /shop/purchase {offerId, idempotencyKey}. Returns the Api result plus "replay": true
## when the server answered an earlier request with the same key (nothing new was bought).
## {ok: false, code: "BUSY"} while another purchase or top-up runs.
func buy(offer_id: String) -> Dictionary:
	return await _pay("/shop/purchase", purchase_keys, offer_id, "purchaseId", true,
		func(key: String) -> Dictionary: return {"offerId": offer_id, "idempotencyKey": key})


## POST /iap/verify {productId, platform, purchaseToken} with a mock token, like buy().
func top_up(product_id: String, platform: String) -> Dictionary:
	return await _pay("/iap/verify", iap_tokens, product_id, "transactionId", false,
		func(key: String) -> Dictionary: return {"productId": product_id, "platform": platform, "purchaseToken": key})


## assets: the purchase changes inventory / characters (else only the wallet is refreshed).
func _pay(path: String, keys: IdempotencyKeys, id: String, id_field: String, assets: bool, make_body: Callable) -> Dictionary:
	if busy_id != "":
		return {"ok": false, "status": -1, "code": "BUSY", "message": "", "data": null, "replay": false}
	var target := key_target(id)
	var carried := keys.has_key(target)
	var known := _known_ids.duplicate() # before the request: its own answer is not "known"
	var started := int(Time.get_unix_time_from_system())
	var body: Dictionary = make_body.call(keys.key_for(target))
	busy_id = id
	busy_changed.emit()
	var res: Dictionary = await Api.post_json(path, body)
	keys.settle(target, res.status)
	busy_id = ""
	var out := res.duplicate()
	out["replay"] = false
	if res.ok:
		var data: Dictionary = res.data if res.data is Dictionary else {}
		var result_id := str(data.get(id_field, ""))
		out["replay"] = IdempotencyKeys.is_replay(carried, result_id, known, str(data.get("createdAt", "")), started)
		if result_id != "":
			_known_ids[result_id] = true
		if assets:
			assets_changed()
		else:
			refresh()
	busy_changed.emit()
	return out


## Per-player key target ids, so another account on this device never sends them.
func key_target(id: String) -> String:
	return "%s/%s" % [Session.player_id, id]
