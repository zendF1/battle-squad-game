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
##
## Equipment: the catalog (GET /equipment/catalog, loaded once per session; a failed load is
## retried by the next need_equipment()) and the owned pieces (GET /player/equipment, coalesced
## like the characters; stale after a buy, an equip / unequip and when Home is shown again after
## a match). buy_equipment() runs POST /shop/equipment/buy {itemId, idempotencyKey} like buy();
## equip() / unequip() / move_equipment() / sell_equipment() / discard_equipment() run one action
## at a time (equip_busy) and reload the pieces and the characters (their stats include the
## equipment) whatever the answer.
##
## Upgrade stones: the owned stones (GET /player/stones → {stoneLevel: quantity}, coalesced, stale
## after anything that uses or adds stones). buy_stones() runs POST /shop/stones/buy {stoneLevel,
## quantity, idempotencyKey} like buy() (the key per player + level + quantity; the server says
## when it replayed); upgrade() (POST /player/equipment/upgrade, also an equipment action:
## equip_busy) and merge_stones() (POST /merge/stone) consume stones one at a time (stone_busy)
## and reload the stones whatever the answer.
##
## Milestones ("Mốc thưởng"): GET /milestones (MilestoneModel.parse, coalesced, stale after an
## equipment action and after a claim) and the claimable count for the lobby badge
## (milestone_count: from the list, GET /milestones/summary or a claim's answer; -1 unknown).
## claim_milestone(id) / claim_all_milestones() run POST /milestones/claim {id} /
## /milestones/claim-all one at a time (milestone_busy): the wallet and the stones take the
## answer's balances at once, the list reloads whatever the answer (MILESTONE_ALREADY_CLAIMED
## means another device or a retry already took it). take_new_milestones() is true once each
## time the count rose past what the player saw (the lobby's "Có mốc thưởng mới!").
##
## Rank: GET /rank/me (the current season's {rating, tier, ...}), loaded with the profile when
## Home is shown (load_rank(), coalesced); rank_tier() is its tier ("" until loaded, after a
## failure or for another account): the match's aiming aid shortens its guide arc by it.
##
## Titles ("Danh hiệu"): the worn one is the profile's equippedTitle (equipped_title()); the
## list GET /player/titles (TitleModel.parse, coalesced, stale after a milestone claim that gave a
## title). equip_title(id) / equip_title(null) run POST /player/titles/equip {titleId} one at a
## time (title_busy): the profile and the list take the answer's equipped title at once, the
## list reloads whatever the answer.

signal changed # profile, loading or error changed
signal assets_dirty # inventory, characters or purchases changed on the server
signal characters_changed # characters, characters_loading or characters_error changed
signal busy_changed # a purchase or top-up started or ended
signal equipment_changed # catalog, owned equipment, their loading / errors, or equip_busy changed
signal stones_changed # owned stones, their loading / error, or stone_busy changed
signal milestones_changed # milestones, their loading / error, milestone_count or milestone_busy changed
signal titles_changed # titles, their loading / error, title_busy or the worn title changed

const IdempotencyKeys := preload("res://core/idempotency_keys.gd")
const Coalescer := preload("res://core/coalescer.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const MilestoneModel := preload("res://screens/home/milestone_model.gd")
const TitleModel := preload("res://screens/home/title_model.gd")

## What a payment refreshes once it succeeded.
const AFTER_WALLET := 0 # the wallet only (a top-up)
const AFTER_ASSETS := 1 # wallet, characters, inventory (assets_changed)
const AFTER_EQUIPMENT := 2 # wallet and the owned equipment
const AFTER_STONES := 3 # wallet and the owned stones

var profile: Dictionary = {} # last GET /player/profile data; {} until loaded
var loading := false
var error := "" # last refresh failure (Vietnamese), "" after a success

## POST /shop/purchase idempotencyKey and POST /iap/verify mock purchaseToken, per player+target.
var purchase_keys := IdempotencyKeys.new("", "user://purchase_keys.cfg")
var iap_tokens := IdempotencyKeys.new("mock_", "user://iap_tokens.cfg")
## POST /shop/equipment/buy idempotencyKey, per player+item.
var equipment_keys := IdempotencyKeys.new("", "user://equipment_keys.cfg")
## POST /shop/stones/buy idempotencyKey, per player+level+quantity.
var stone_keys := IdempotencyKeys.new("", "user://stone_keys.cfg")

## Last GET /player/characters data ({characters, resetStatsCost}); null until loaded.
var characters: Variant = null
var characters_loading := false
var characters_error := "" # Vietnamese; "" after a success
var characters_stale := true # loaded before the last asset change (or never)
var characters_version := 0 # bumped each time a GET /player/characters answer is applied
var _characters_player := "" # whose characters these are

## The offerId / productId being bought, "" when none: one purchase or top-up at a time.
var busy_id := ""

## EquipmentModel.parse_catalog() of GET /equipment/catalog; null until loaded.
var catalog: Variant = null
var catalog_loading := false
var catalog_error := "" # Vietnamese; "" after a success
## The owned pieces (GET /player/equipment, newest first); null until loaded.
var equipment: Variant = null
var equipment_loading := false
var equipment_error := "" # Vietnamese; "" after a success
var equipment_stale := true # loaded before the last change (or never)
var equipment_version := 0 # bumped each time a GET /player/equipment answer is applied
var _equipment_player := ""
## The equipmentId of the equip / unequip running, "" when none.
var equip_busy := ""

## The owned upgrade stones ({stoneLevel: quantity}, levels with none left out); null until loaded.
var stones: Variant = null
var stones_loading := false
var stones_error := "" # Vietnamese; "" after a success
var stones_stale := true
var stones_version := 0 # bumped each time a GET /player/stones answer is applied
var _stones_player := ""
## "upgrade" / "merge" while a request consuming stones runs, "" when none.
var stone_busy := ""
var _stones_gate := Coalescer.new()

## MilestoneModel.parse() of GET /milestones; null until loaded.
var milestones: Variant = null
var milestones_loading := false
var milestones_error := "" # Vietnamese; "" after a success
var milestones_stale := true
var milestones_version := 0 # bumped each time a GET /milestones answer is applied
var _milestones_player := ""
var _milestones_gate := Coalescer.new()
var _summary_gate := Coalescer.new()
## The claimable milestones (badge), -1 while unknown; milestone_seen: the count the player was
## last told about (take_new_milestones()).
var milestone_count := -1
var milestone_seen := -1
## "all" or the id being claimed, "" when none.
var milestone_busy := ""

## TitleModel.parse() of GET /player/titles; null until loaded.
var titles: Variant = null
var titles_loading := false
var titles_error := "" # Vietnamese; "" after a success
var titles_stale := true
var titles_version := 0 # bumped each time a GET /player/titles answer is applied
var _titles_player := ""
var _titles_gate := Coalescer.new()
## True while POST /player/titles/equip runs.
var title_busy := false

## Last GET /rank/me data; {} until loaded.
var rank: Dictionary = {}
var _rank_player := ""
var _rank_gate := Coalescer.new()

var _equipment_gate := Coalescer.new()
var _profile_gate := Coalescer.new()
var _characters_gate := Coalescer.new()
var _known_ids := {} # purchaseIds / transactionIds this client has seen (replay detection)
## The REST client: the Api autoload, or a stand-in set by the tests.
var api: Object = null


func _api() -> Object:
	return api if api != null else Api


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


## The worn title {id, name, rarity}, {} when none (the profile's equippedTitle).
func equipped_title() -> Dictionary:
	return TitleModel.from_profile(profile)


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
		var res: Dictionary = await _api().get_json("/player/profile")
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
		var res: Dictionary = await _api().get_json("/player/characters")
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


## Loads GET /rank/me; a failure keeps the last answer for this account.
func load_rank() -> void:
	if not _rank_gate.ask():
		return
	while true:
		var t := _rank_gate.ticket()
		var player := Session.player_id
		var res: Dictionary = await _api().get_json("/rank/me")
		if not _rank_gate.finish(t):
			continue
		if res.ok and res.data is Dictionary:
			rank = res.data
			_rank_player = player
		break


## The signed-in player's rank tier (ratingToTier ids: bronze ... master), "" when unknown.
func rank_tier() -> String:
	if rank.is_empty() or _rank_player != Session.player_id:
		return ""
	return str(rank.get("tier", ""))


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
	return await _pay("/shop/purchase", purchase_keys, offer_id, "purchaseId", AFTER_ASSETS,
		func(key: String) -> Dictionary: return {"offerId": offer_id, "idempotencyKey": key})


## POST /iap/verify {productId, platform, purchaseToken} with a mock token, like buy().
func top_up(product_id: String, platform: String) -> Dictionary:
	return await _pay("/iap/verify", iap_tokens, product_id, "transactionId", AFTER_WALLET,
		func(key: String) -> Dictionary: return {"productId": product_id, "platform": platform, "purchaseToken": key})


## POST /shop/equipment/buy {itemId, idempotencyKey}, like buy(); the answer's equipmentId is
## a replay when this client already listed that piece.
func buy_equipment(item_id: String) -> Dictionary:
	return await _pay("/shop/equipment/buy", equipment_keys, item_id, "equipmentId", AFTER_EQUIPMENT,
		func(key: String) -> Dictionary: return {"itemId": item_id, "idempotencyKey": key})


## POST /shop/stones/buy {stoneLevel, quantity, idempotencyKey}, like buy(); the key is per
## level and quantity (a retry of the same buy), "replay" comes from the server's answer. On
## success the wallet takes the answer's balance and the stones reload.
func buy_stones(stone_level: int, quantity: int) -> Dictionary:
	return await _pay("/shop/stones/buy", stone_keys, "stone_%d_x%d" % [stone_level, quantity], "", AFTER_STONES,
		func(key: String) -> Dictionary: return {"stoneLevel": stone_level, "quantity": quantity, "idempotencyKey": key})


## after: AFTER_WALLET, AFTER_ASSETS, AFTER_EQUIPMENT or AFTER_STONES (what to refresh on success).
func _pay(path: String, keys: IdempotencyKeys, id: String, id_field: String, after: int, make_body: Callable) -> Dictionary:
	if busy_id != "":
		return {"ok": false, "status": -1, "code": "BUSY", "message": "", "data": null, "replay": false}
	var target := key_target(id)
	var carried := keys.has_key(target)
	var known := _known_ids.duplicate() # before the request: its own answer is not "known"
	var started := int(Time.get_unix_time_from_system())
	var body: Dictionary = make_body.call(keys.key_for(target))
	busy_id = id
	busy_changed.emit()
	var res: Dictionary = await _api().post_json(path, body)
	keys.settle(target, res.status)
	busy_id = ""
	var out := res.duplicate()
	out["replay"] = false
	if res.ok:
		var data: Dictionary = res.data if res.data is Dictionary else {}
		var result_id := str(data.get(id_field, "")) if id_field != "" else ""
		if data.get("replay") is bool:
			out["replay"] = data["replay"] # the server knows (POST /shop/stones/buy)
		else:
			out["replay"] = IdempotencyKeys.is_replay(carried, result_id, known, str(data.get("createdAt", "")), started)
		if result_id != "":
			_known_ids[result_id] = true
		_take_balance(data)
		_after_pay(after)
	elif not IdempotencyKeys.is_definite(res.status):
		# No clear answer (network, 5xx): it may have gone through. The key is kept for the retry;
		# show whatever the server has now.
		_after_pay(after)
	busy_changed.emit()
	return out


func _after_pay(after: int) -> void:
	match after:
		AFTER_ASSETS:
			assets_changed()
		AFTER_EQUIPMENT:
			refresh()
			equipment_dirty()
		AFTER_STONES:
			refresh()
			stones_dirty()
		_:
			refresh()


## An answer with {currency, balance} (stone buy, sell): the wallet shows it at once; the refresh
## that follows confirms it.
func _take_balance(data: Dictionary) -> void:
	var currency := str(data.get("currency", ""))
	var balance = data.get("balance")
	if not profile.is_empty() and currency in ["coin", "gem"] and (balance is int or balance is float):
		profile[currency] = int(balance)
		changed.emit()


## Per-player key target ids, so another account on this device never sends them.
func key_target(id: String) -> String:
	return "%s/%s" % [Session.player_id, id]


# ── Equipment ───────────────────────────────────────────────────────────────

## Loads the catalog unless it is loaded or loading, and the owned pieces unless a fresh copy is
## cached or already on its way.
func need_equipment() -> void:
	if catalog == null and not catalog_loading:
		load_catalog()
	if _equipment_player != Session.player_id:
		equipment = null # another account signed in on this device
	if not _equipment_gate.running and (equipment == null or equipment_stale):
		load_equipment()


func load_catalog() -> void:
	if catalog_loading:
		return
	catalog_loading = true
	catalog_error = ""
	equipment_changed.emit()
	var res: Dictionary = await _api().get_json("/equipment/catalog")
	catalog_loading = false
	var parsed = EquipmentModel.parse_catalog(res.data) if res.ok else null
	if parsed != null:
		catalog = parsed
	else:
		catalog_error = ErrorText.load_failed(res) if not res.ok else "Dữ liệu trang bị không hợp lệ"
	equipment_changed.emit()


func load_equipment() -> void:
	if not _equipment_gate.ask():
		return
	equipment_loading = true
	equipment_error = ""
	equipment_changed.emit()
	while true:
		var t := _equipment_gate.ticket()
		var player := Session.player_id
		var res: Dictionary = await _api().get_json("/player/equipment")
		if not _equipment_gate.finish(t):
			continue
		var parsed = EquipmentModel.parse_owned(res.data) if res.ok else null
		if parsed is Array:
			equipment = parsed
			equipment_stale = false
			equipment_version += 1
			_equipment_player = player
			for p in parsed:
				_known_ids[str(p["equipmentId"])] = true
		else:
			equipment_error = ErrorText.load_failed(res) if not res.ok else "Dữ liệu trang bị không hợp lệ"
		break
	equipment_loading = false
	equipment_changed.emit()


## The owned pieces changed on the server: reload them (again, when a load is in flight).
func equipment_dirty() -> void:
	equipment_stale = true
	load_equipment()


## Retries whatever equipment load failed.
func retry_equipment() -> void:
	if catalog_error != "":
		load_catalog()
	if equipment_error != "":
		load_equipment()


## POST /player/equipment/equip {equipmentId, characterId}. The server takes off the piece the
## character wore in that slot. {ok: false, code: "BUSY"} while another action runs.
func equip(equipment_id: String, character_id: String) -> Dictionary:
	return await _equip_steps(equipment_id, [["/player/equipment/equip", {"equipmentId": equipment_id, "characterId": character_id}, []]])


## POST /player/equipment/unequip {equipmentId}.
func unequip(equipment_id: String) -> Dictionary:
	return await _equip_steps(equipment_id, [["/player/equipment/unequip", {"equipmentId": equipment_id}, []]])


## A piece another character wears goes to `character_id`: unequip, then equip (the server
## refuses to equip a worn piece). Stops at the first failure; an unequip answered
## EQUIP_NOT_EQUIPPED counts as done (someone took it off meanwhile). When the equip fails after
## the unequip went through, the answer has "unequipped": true (the piece is now worn by nobody).
func move_equipment(equipment_id: String, character_id: String) -> Dictionary:
	return await _equip_steps(equipment_id, [["/player/equipment/unequip", {"equipmentId": equipment_id}, ["EQUIP_NOT_EQUIPPED"]],
		["/player/equipment/equip", {"equipmentId": equipment_id, "characterId": character_id}, []]])


## POST /player/equipment/sell {equipmentId}: the piece is gone, its gems back in the bag, part of
## its upgrade stones refunded, floor(price × sellRate) credited. Only a piece never worn
## (isLocked false) sells, so there is no unequip step. On success the wallet takes the answer's
## balance at once and refreshes.
func sell_equipment(equipment_id: String) -> Dictionary:
	var res := await _equip_steps(equipment_id, _remove_steps("/player/equipment/sell", equipment_id, false))
	if res.ok:
		_take_balance(res.data if res.data is Dictionary else {})
		refresh()
	return res


## POST /player/equipment/dismantle {equipmentId} ("Vứt"): the piece is gone, its gems back in the
## bag, part of its upgrade stones refunded, nothing credited; allowed for locked pieces. worn:
## someone wears it, so it is taken off first (like move_equipment(): EQUIP_NOT_EQUIPPED counts as
## done; "unequipped": true when the dismantle then failed).
func discard_equipment(equipment_id: String, worn: bool) -> Dictionary:
	return await _equip_steps(equipment_id, _remove_steps("/player/equipment/dismantle", equipment_id, worn))


func _remove_steps(path: String, equipment_id: String, worn: bool) -> Array:
	var steps: Array = []
	if worn:
		steps.append(["/player/equipment/unequip", {"equipmentId": equipment_id}, ["EQUIP_NOT_EQUIPPED"]])
	steps.append([path, {"equipmentId": equipment_id}, []])
	return steps


# ── Stones ──────────────────────────────────────────────────────────────────

## Loads the owned stones unless a fresh copy is cached or already on its way.
func need_stones() -> void:
	if _stones_player != Session.player_id:
		stones = null # another account signed in on this device
	if not _stones_gate.running and (stones == null or stones_stale):
		load_stones()


func load_stones() -> void:
	if not _stones_gate.ask():
		return
	stones_loading = true
	stones_error = ""
	stones_changed.emit()
	while true:
		var t := _stones_gate.ticket()
		var player := Session.player_id
		var res: Dictionary = await _api().get_json("/player/stones")
		if not _stones_gate.finish(t):
			continue
		var parsed = UpgradeModel.parse_stones(res.data) if res.ok else null
		if parsed is Dictionary:
			stones = parsed
			stones_stale = false
			stones_version += 1
			_stones_player = player
		else:
			stones_error = ErrorText.load_failed(res) if not res.ok else "Dữ liệu đá nâng cấp không hợp lệ"
		break
	stones_loading = false
	stones_changed.emit()


## The owned stones changed on the server: reload them (again, when a load is in flight).
func stones_dirty() -> void:
	stones_stale = true
	load_stones()


## The stones are loaded and nothing that uses them is running.
func stones_ready() -> bool:
	return stones != null and not stones_stale and not _stones_gate.running and stone_busy == ""


## POST /player/equipment/upgrade {equipmentId, stones: [{stoneLevel, quantity}], careful?,
## expectedLevel?} → {success, newLevel, percent, careful, gemSpent, gemBalance?}. Every stone sent
## is consumed, whatever the roll; careful also spends the step's gems (the wallet takes
## gemBalance at once, then refreshes). expected_level (>= 0): the level shown, so a retry of an
## attempt that already rolled is refused (EQUIP_MODIFIED) instead of rolling the next step. One
## stone action at a time ({ok: false, code: "BUSY"}), and an equipment action (equip_busy): the
## pieces, the characters and the stones reload afterwards whatever the answer.
func upgrade(equipment_id: String, stone_list: Array, careful: bool = false, expected_level: int = -1) -> Dictionary:
	if stone_busy != "":
		return {"ok": false, "status": -1, "code": "BUSY", "message": "", "data": null}
	if equipment_id == "" or equip_busy != "":
		return await _equip_steps(equipment_id, []) # NO_EQUIPMENT / BUSY, nothing sent
	stone_busy = "upgrade"
	stones_changed.emit()
	var body := {"equipmentId": equipment_id, "stones": stone_list}
	if careful:
		body["careful"] = true
	if expected_level >= 0:
		body["expectedLevel"] = expected_level
	var res := await _equip_steps(equipment_id, [["/player/equipment/upgrade", body, []]])
	stone_busy = ""
	stones_dirty()
	if careful:
		var data: Dictionary = res.data if res.ok and res.data is Dictionary else {}
		var balance = data.get("gemBalance")
		if not profile.is_empty() and (balance is int or balance is float):
			profile["gem"] = int(balance)
			changed.emit()
		refresh() # the wallet's truth, also after a refusal or no answer
	return res


## POST /merge/stone {stoneLevel, count} → {success, message}: count stones of the level are
## consumed, one of the next level is added on success. One stone action at a time; the stones
## reload afterwards whatever the answer.
func merge_stones(stone_level: int, count: int) -> Dictionary:
	if stone_busy != "":
		return {"ok": false, "status": -1, "code": "BUSY", "message": "", "data": null}
	stone_busy = "merge"
	stones_changed.emit()
	var res: Dictionary = await _api().post_json("/merge/stone", {"stoneLevel": stone_level, "count": count})
	stone_busy = ""
	stones_dirty()
	return res


## The owned pieces are loaded and no load or action is running: buttons built from them are
## current.
func equipment_ready() -> bool:
	return equipment != null and not equipment_stale and not _equipment_gate.running and equip_busy == ""


## The can-wear check has what it needs (catalog and characters loaded).
func can_wear_known() -> bool:
	return catalog != null and characters != null


## steps: [path, body, codes that count as done]. Adds "unequipped": true when a later step
## failed after a first one went through.
func _equip_steps(equipment_id: String, steps: Array) -> Dictionary:
	if equipment_id == "":
		return {"ok": false, "status": -1, "code": "NO_EQUIPMENT", "message": "thiếu mã trang bị", "data": null}
	if equip_busy != "":
		return {"ok": false, "status": -1, "code": "BUSY", "message": "", "data": null}
	equip_busy = equipment_id
	equipment_changed.emit()
	var res := {}
	var done := 0
	for step in steps:
		res = await _api().post_json(step[0], step[1])
		var allowed: Array = step[2] if step.size() > 2 else []
		if not res.ok and not allowed.has(str(res.get("code", ""))):
			break
		res = res.duplicate()
		res["ok"] = true
		done += 1
	res = res.duplicate()
	res["unequipped"] = not res.ok and done > 0
	equip_busy = ""
	# Even a refusal may come from a stale view (or a move failed halfway): show the truth.
	equipment_dirty()
	milestones_dirty() # an upgrade or a worn set can reach a milestone
	characters_stale = true
	load_characters()
	equipment_changed.emit()
	return res


# ── Milestones ──────────────────────────────────────────────────────────────

## Loads GET /milestones unless a fresh copy is cached or already on its way.
func need_milestones() -> void:
	if _milestones_player != Session.player_id:
		milestones = null # another account signed in on this device
		milestone_count = -1
		milestone_seen = -1
	if not _milestones_gate.running and (milestones == null or milestones_stale):
		load_milestones()


func load_milestones() -> void:
	if not _milestones_gate.ask():
		return
	milestones_loading = true
	milestones_error = ""
	milestones_changed.emit()
	while true:
		var t := _milestones_gate.ticket()
		var player := Session.player_id
		var res: Dictionary = await _api().get_json("/milestones")
		if not _milestones_gate.finish(t):
			continue
		var parsed = MilestoneModel.parse(res.data) if res.ok else null
		if parsed != null:
			milestones = parsed
			milestones_stale = false
			milestones_version += 1
			_milestones_player = player
			_set_milestone_count(MilestoneModel.claimable_total(parsed))
		else:
			milestones_error = ErrorText.load_failed(res) if not res.ok else "Dữ liệu mốc thưởng không hợp lệ"
		break
	milestones_loading = false
	milestones_changed.emit()


## Refreshes the badge count (GET /milestones/summary); the list goes stale when it differs.
func load_milestone_summary() -> void:
	if not _summary_gate.ask():
		return
	while true:
		var t := _summary_gate.ticket()
		var res: Dictionary = await _api().get_json("/milestones/summary")
		if not _summary_gate.finish(t):
			continue
		var data = res.data if res.ok else null
		if data is Dictionary and (data.get("claimableCount") is int or data.get("claimableCount") is float):
			var n := int(data["claimableCount"])
			if milestones != null and n != MilestoneModel.claimable_total(milestones):
				milestones_stale = true
			_set_milestone_count(n)
		break
	milestones_changed.emit()


## Something that moves milestone progress happened (an upgrade, an equip): the list is stale
## and the badge count reloads.
func milestones_dirty() -> void:
	milestones_stale = true
	load_milestone_summary()


func _set_milestone_count(n: int) -> void:
	milestone_count = maxi(0, n)
	if milestone_seen < 0 or milestone_count < milestone_seen:
		milestone_seen = milestone_count # first count of the session, or a claim: nothing new


## True once each time the claimable count rose past the one the player was last told about.
func take_new_milestones() -> bool:
	if milestone_count < 0 or milestone_count <= milestone_seen:
		return false
	milestone_seen = milestone_count
	return true


## POST /milestones/claim {id} → {claimed, rewards, coin, gem, stones, claimableCount}.
## {ok: false, code: "BUSY"} while another claim runs.
func claim_milestone(id: String) -> Dictionary:
	return await _claim("/milestones/claim", {"id": id}, id)


## POST /milestones/claim-all, like claim_milestone().
func claim_all_milestones() -> Dictionary:
	return await _claim("/milestones/claim-all", {}, "all")


func _claim(path: String, body: Dictionary, busy: String) -> Dictionary:
	if milestone_busy != "":
		return {"ok": false, "status": -1, "code": "BUSY", "message": "", "data": null}
	milestone_busy = busy
	milestones_changed.emit()
	var res: Dictionary = await _api().post_json(path, body)
	milestone_busy = ""
	if res.ok and res.data is Dictionary:
		var data: Dictionary = res.data
		if not profile.is_empty():
			for currency in ["coin", "gem"]:
				if data.get(currency) is int or data.get(currency) is float:
					profile[currency] = int(data[currency])
			changed.emit()
		var parsed = UpgradeModel.parse_stones(data.get("stones"))
		if parsed is Dictionary and data.get("stones") is Array:
			stones = parsed
			stones_version += 1
			stones_changed.emit()
		if data.get("claimableCount") is int or data.get("claimableCount") is float:
			_set_milestone_count(int(data["claimableCount"]))
		var rewards := MilestoneModel.parse_rewards(data.get("rewards"))
		if rewards["items"].any(func(it): return it["kind"] == "title"):
			titles_stale = true
			if titles != null:
				load_titles()
	refresh() # the wallet's truth, also after a refusal or no answer
	milestones_stale = true
	load_milestones()
	return res


# ── Titles ──────────────────────────────────────────────────────────────────

## Loads GET /player/titles unless a fresh copy is cached or already on its way.
func need_titles() -> void:
	if _titles_player != Session.player_id:
		titles = null # another account signed in on this device
	if not _titles_gate.running and (titles == null or titles_stale):
		load_titles()


func load_titles() -> void:
	if not _titles_gate.ask():
		return
	titles_loading = true
	titles_error = ""
	titles_changed.emit()
	while true:
		var t := _titles_gate.ticket()
		var player := Session.player_id
		var res: Dictionary = await _api().get_json("/player/titles")
		if not _titles_gate.finish(t):
			continue
		var parsed = TitleModel.parse(res.data) if res.ok else null
		if parsed != null:
			titles = parsed
			titles_stale = false
			titles_version += 1
			_titles_player = player
			_take_equipped(parsed["equipped"])
		else:
			titles_error = ErrorText.load_failed(res) if not res.ok else "Dữ liệu danh hiệu không hợp lệ"
		break
	titles_loading = false
	titles_changed.emit()


## POST /player/titles/equip {titleId: id, or null to take the title off} → {equipped}.
## {ok: false, code: "BUSY"} while another one runs.
func equip_title(id: Variant) -> Dictionary:
	if title_busy:
		return {"ok": false, "status": -1, "code": "BUSY", "message": "", "data": null}
	title_busy = true
	titles_changed.emit()
	var title_id: Variant = null if id == null or str(id) == "" else str(id)
	var res: Dictionary = await _api().post_json("/player/titles/equip", {"titleId": title_id})
	title_busy = false
	if res.ok and res.data is Dictionary:
		var worn := TitleModel.parse_title(res.data.get("equipped"))
		_take_equipped(worn)
		if titles is Dictionary:
			titles["equipped"] = worn
			titles_version += 1
	titles_stale = true
	load_titles() # the truth, also after a refusal (TITLE_NOT_OWNED) or no answer
	titles_changed.emit()
	return res


## The worn title as the server said: the profile copy follows (the lobby, Prep and Hồ sơ draw it).
func _take_equipped(worn: Dictionary) -> void:
	if profile.is_empty():
		return
	var before := TitleModel.from_profile(profile)
	if before == worn:
		return
	profile["equippedTitle"] = worn.duplicate() if not worn.is_empty() else null
	changed.emit()
