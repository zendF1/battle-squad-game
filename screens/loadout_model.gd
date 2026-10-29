extends RefCounted
## Loadout choice for Quick Play: one character (picked in the lobby, which saves it here) and
## up to max_items items (picked on the Loadout screen: the mode's maxItems, LobbyModel.max_items();
## Items.max_loadout(), the global rule, by default), plus how many of each item the
## player can still bring (GET /player/inventory: the unreserved quantity, rows with none left
## are not listed). The server refuses a QuickPlay with an item the player does not hold
## (RoomError LOADOUT_INVALID "You do not own item: <id>"), so once the counts are known an item
## with none left cannot be picked, set_counts() drops it from the choice (a saved loadout, or
## the last one used up in a match) and payload() never sends it. While the counts are unknown
## (the request failed) nothing is marked or refused: the server decides. The last choice is
## remembered in a ConfigFile (a convenience only), shared with the lobby (its mode).

## The characters (order, names, roles) and the default one are the game data's (GET /gamedata
## characters, defaultCharacterId). No character is owned for free (a player owns the starter picked
## at onboarding and what they bought), so the default id is only a placeholder until the lobby
## picks an owned one (start_character()).

const Items := preload("res://match/items.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const SETTINGS_PATH := "user://loadout.cfg"
const NOT_OWNED := "Chưa sở hữu"
const NOT_OWNED_HINT := "Chưa sở hữu vật phẩm này"

var character_id := ""
var items: Array[String] = [] # in the order picked
var max_items := 0 # how many items it takes (the mode's maxItems); set_max_items()
## Saved picks past max_items (a 6-item boss loadout opened for a 3-item mode): not shown nor
## sent, kept in the saved file, as the server keeps a saved loadout whole for a smaller mode.
var hidden_items: Array[String] = []
var item_counts: Variant = null # {itemId: quantity}, or null: unknown


func _init() -> void:
	character_id = default_character()
	max_items = Items.max_loadout()


## The mode's item slots (LobbyModel.max_items()): the first n picks are shown and sent, the
## rest set aside (hidden_items) and back when a mode with more slots opens.
func set_max_items(n: int) -> void:
	max_items = maxi(n, 0)
	_split(items + hidden_items)


func _split(all: Array) -> void:
	items.clear()
	hidden_items.clear()
	for id in all:
		var item := str(id)
		if items.has(item) or hidden_items.has(item):
			continue
		if items.size() < max_items:
			items.append(item)
		else:
			hidden_items.append(item)


## The game data's default character: a placeholder before anything is known (not always owned).
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


## Picks or drops an item. Returns false (and changes nothing) for an item past max_items, an unknown id
## or an item the player has none of.
func toggle_item(id: String) -> bool:
	if items.has(id):
		items.erase(id)
		return true
	if not Items.is_known(id) or items.size() >= max_items or not owns(id):
		return false
	items.append(id)
	hidden_items.erase(id)
	return true


func is_full() -> bool:
	return items.size() >= max_items


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


## The max_items slots, in the order picked: the item id, or "" for an empty slot.
func slots() -> Array[String]:
	var out: Array[String] = []
	for i in max_items:
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
	var all := items.duplicate()
	for id in hidden_items:
		if not all.has(id):
			all.append(id)
	cfg.set_value("loadout", "items", all) # the picks set aside by a smaller mode kept
	cfg.save(path)


## The character saved on this device ("" none yet).
static func saved_character(path: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return ""
	var id = cfg.get_value("loadout", "character_id", "")
	return id if id is String else ""


## The character to start with (the lobby on opening, the Loadout with nothing saved), never one
## known not to be owned: the one saved on this device, else the profile's main character
## (GET /player/profile currentCharacterId: the onboarding pick, the last lobby choice), else the
## first owned one in the game data's order, else "". characters: GET /player/characters data
## (null while not loaded: ownership unknown, nothing is ruled out).
static func start_character(path: String, profile: Variant, characters: Variant = null) -> String:
	var owned = parse_characters(characters)
	var saved := saved_character(path)
	if _startable(saved, owned):
		return saved
	var current = profile.get("currentCharacterId") if profile is Dictionary else null
	if current is String and _startable(current, owned):
		return current
	if owned is Array:
		for id in character_ids():
			if owned.has(id):
				return str(id)
	return ""


static func _startable(id: String, owned: Variant) -> bool:
	return is_character(id) and (not owned is Array or owned.has(id))


## Restores a saved choice, dropping anything this client does not know.
func restore(path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	select_character(str(cfg.get_value("loadout", "character_id", default_character())))
	var saved = cfg.get_value("loadout", "items", [])
	var known: Array = []
	if saved is Array:
		for id in saved:
			if Items.is_known(str(id)) and not known.has(str(id)):
				known.append(str(id))
	_split(known) # the first max_items shown, the rest set aside
