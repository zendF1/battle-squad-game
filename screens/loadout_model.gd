extends RefCounted
## Loadout choice for Quick Play: one character and up to Items.MAX_LOADOUT items, plus what the
## player owns (GET /player/characters, GET /player/inventory). Ownership is advisory: a
## character or item not owned can still be picked, the server decides (QuickPlay answers
## RoomError LOADOUT_INVALID). When a request failed, ownership is unknown (null) and nothing is
## marked. The last choice is remembered in a ConfigFile (a convenience only), shared with the
## lobby, which picks the character there too.

const Items := preload("res://match/items.gd")
const Skills := preload("res://match/skills.gd")

const SETTINGS_PATH := "user://loadout.cfg"
const DEFAULT_CHARACTER := "rookie" # always owned
const NOT_OWNED := "Chưa sở hữu"

## Server configs/characters.yaml: id, name, role (Vietnamese).
const CHARACTERS := [
	{"id": "rookie", "name": "Rookie", "role": "Cân bằng"},
	{"id": "tanko", "name": "Tanko", "role": "Pháo thủ hạng nặng"},
	{"id": "spark", "name": "Spark", "role": "Khống chế"},
	{"id": "flora", "name": "Flora", "role": "Hỗ trợ"},
]

var character_id := DEFAULT_CHARACTER
var items: Array[String] = [] # in the order picked
var owned_characters: Variant = null # Array of characterIds, or null: unknown
var item_counts: Variant = null # {itemId: quantity}, or null: unknown


static func is_character(id: String) -> bool:
	for c in CHARACTERS:
		if c["id"] == id:
			return true
	return false


func select_character(id: String) -> void:
	if is_character(id):
		character_id = id


## Picks or drops an item. Returns false (and changes nothing) for a fourth item or an unknown id.
func toggle_item(id: String) -> bool:
	if items.has(id):
		items.erase(id)
		return true
	if not Items.is_known(id) or items.size() >= Items.MAX_LOADOUT:
		return false
	items.append(id)
	return true


func is_full() -> bool:
	return items.size() >= Items.MAX_LOADOUT


## The QuickPlay payload: base ({} or {"bot": "ai"}) plus the choice.
func payload(base: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out["characterId"] = character_id
	out["items"] = items.duplicate()
	return out


## "Cân bằng · Kỹ năng: Bắn 3 tia".
static func character_detail(id: String) -> String:
	var role := ""
	for c in CHARACTERS:
		if c["id"] == id:
			role = c["role"]
	var skill := Skills.for_character(id)
	if skill.is_empty():
		return role
	return "%s\nKỹ năng: %s" % [role, skill["name"]]


## "" when owned or unknown, NOT_OWNED otherwise.
func character_note(id: String) -> String:
	if id == DEFAULT_CHARACTER or not owned_characters is Array or owned_characters.has(id):
		return ""
	return NOT_OWNED


## "x5" when owned, NOT_OWNED when not, "" when unknown.
func item_note(id: String) -> String:
	if not item_counts is Dictionary:
		return ""
	var n := int(item_counts.get(id, 0))
	return "x%d" % n if n > 0 else NOT_OWNED


## GET /player/characters data {"characters": [{characterId, ...}]} → ids, or null if malformed.
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
	select_character(str(cfg.get_value("loadout", "character_id", DEFAULT_CHARACTER)))
	items.clear()
	var saved = cfg.get_value("loadout", "items", [])
	if saved is Array:
		for id in saved:
			if not items.has(str(id)):
				toggle_item(str(id))
