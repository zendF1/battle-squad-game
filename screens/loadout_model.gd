extends RefCounted
## Loadout choice for Quick Play: one character (picked in the lobby, which saves it here) and
## up to Items.max_loadout() items (picked on the Loadout screen), plus how many of each item the
## player can still bring (GET /player/inventory: the unreserved quantity, rows with none left
## are not listed). The server refuses a QuickPlay with an item the player does not hold
## (RoomError LOADOUT_INVALID "You do not own item: <id>"), so once the counts are known an item
## with none left cannot be picked, set_counts() drops it from the choice (a saved loadout, or
## the last one used up in a match) and payload() never sends it. While the counts are unknown
## (the request failed) nothing is marked or refused: the server decides. The last choice is
## remembered in a ConfigFile (a convenience only), shared with the lobby (its mode).

## The characters (order, names, roles) and the default one (always owned) are the game data's
## (GET /gamedata characters, defaultCharacterId).

const Items := preload("res://match/items.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const SETTINGS_PATH := "user://loadout.cfg"
const NOT_OWNED := "Chưa sở hữu"
const NOT_OWNED_HINT := "Chưa sở hữu vật phẩm này"

var character_id := ""
var items: Array[String] = [] # in the order picked
var item_counts: Variant = null # {itemId: quantity}, or null: unknown


func _init() -> void:
	character_id = default_character()


## The character every player owns and plays when none is picked.
static func default_character() -> String:
	return GameData.default_character_id()


## The character ids in display order.
static func character_ids() -> Array:
	return GameData.character_ids()


static func is_character(id: String) -> bool:
	return GameData.is_character(id)


func select_character(id: String) -> void:
	if is_character(id):
		character_id = id


## Picks or drops an item. Returns false (and changes nothing) for a fourth item, an unknown id
## or an item the player has none of.
func toggle_item(id: String) -> bool:
	if items.has(id):
		items.erase(id)
		return true
	if not Items.is_known(id) or items.size() >= Items.max_loadout() or not owns(id):
		return false
	items.append(id)
	return true


func is_full() -> bool:
	return items.size() >= Items.max_loadout()


## True unless the counts are known and the player has none of the item left.
func owns(id: String) -> bool:
	return not item_counts is Dictionary or int(item_counts.get(id, 0)) > 0


## Takes GET /player/inventory counts (parse_inventory, null: unknown) and drops the picked items
## the player has none of. Returns the dropped ids, in the order they were picked.
func set_counts(counts: Variant) -> Array[String]:
	item_counts = counts if counts is Dictionary else null
	return drop_unowned()


## Drops the picked items the player has none of (nothing while the counts are unknown).
func drop_unowned() -> Array[String]:
	var dropped: Array[String] = []
	for id in items.duplicate():
		if not owns(id):
			items.erase(id)
			dropped.append(id)
	return dropped


## The QuickPlay payload: base ({} or {"bot": "ai"}) plus the choice, without an item the
## player has none of.
func payload(base: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out["characterId"] = character_id
	var sent: Array[String] = []
	for id in items:
		if owns(id):
			sent.append(id)
	out["items"] = sent
	return out


## The Items.max_loadout() slots, in the order picked: the item id, or "" for an empty slot.
func slots() -> Array[String]:
	var out: Array[String] = []
	for i in Items.max_loadout():
		out.append(items[i] if i < items.size() else "")
	return out


## "x5" when owned, NOT_OWNED when not, "" when unknown.
func item_note(id: String) -> String:
	if not item_counts is Dictionary:
		return ""
	var n := int(item_counts.get(id, 0))
	return "x%d" % n if n > 0 else NOT_OWNED


## GET /player/characters data {"characters": [{characterId, ...}]} → ids, or null if malformed
## (the Shop marks owned characters with it).
static func parse_characters(data: Variant) -> Variant:
	if not data is Dictionary or not data.get("characters") is Array:
		return null
	var ids: Array = []
	for c in data["characters"]:
		if c is Dictionary and str(c.get("characterId", "")) != "":
			ids.append(str(c["characterId"]))
	return ids


## GET /player/inventory data [{itemId, quantity, ...}] → {itemId: total quantity}, or null.
static func parse_inventory(data: Variant) -> Variant:
	if not data is Array:
		return null
	var counts := {}
	for row in data:
		if row is Dictionary and str(row.get("itemId", "")) != "":
			var id := str(row["itemId"])
			counts[id] = int(counts.get(id, 0)) + maxi(int(row.get("quantity", 0)), 0)
	return counts


## Saves the choice, keeping the rest of the file (the lobby's mode).
func remember(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path) # a missing file starts empty
	cfg.set_value("loadout", "character_id", character_id)
	cfg.set_value("loadout", "items", items.duplicate())
	cfg.save(path)


## Restores a saved choice, dropping anything this client does not know.
func restore(path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	select_character(str(cfg.get_value("loadout", "character_id", default_character())))
	items.clear()
	var saved = cfg.get_value("loadout", "items", [])
	if saved is Array:
		for id in saved:
			if not items.has(str(id)):
				toggle_item(str(id))
