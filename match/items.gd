extends RefCounted
## Consumable items: the game data (GET /gamedata items, itemRules; autoload/game_data_model.gd)
## says which items exist (in loadout order), their Vietnamese names and how each is used:
## - instant: used with UseItem {itemId}, acts at once (the turn goes on); otherwise it arms the
##   next shot, sent as Shoot {angle, power, actionMode: "item", itemId};
## - aimKind targetX: the shot is aimed at a map column (Shoot.targetX) instead of a slingshot arc
##   (the air strike; the server fires it at itemRules.airStrike angle / power).
## An item id the game data does not know is never offered (hand() leaves it out); a known item
## with no art draws the generic icon (ui/art.gd).
##
## The server answers both with ItemUsed (before ShotResolved for a shot item).

const GameData := preload("res://autoload/game_data_model.gd")


## The item ids in loadout order.
static func order() -> Array:
	return GameData.item_ids()


## How many items a player brings at most (itemRules.maxLoadout).
static func max_loadout() -> int:
	return GameData.max_loadout()


static func is_known(item_id: String) -> bool:
	return GameData.is_item(item_id)


## The Vietnamese label, or the id itself for an item the game data does not know.
static func label(item_id: String) -> String:
	return GameData.item_name(item_id)


static func is_instant(item_id: String) -> bool:
	return GameData.item_instant(item_id)


static func needs_target_x(item_id: String) -> bool:
	return GameData.item_aim_kind(item_id) == "targetX"


## The buttons for players[id].items (the items left): one entry per known item id, in hand
## order, with how many of it are left. [{"id", "count"}].
static func hand(items: Variant) -> Array:
	var out: Array = []
	var index := {}
	if not items is Array:
		return out
	for it in items:
		var id := str(it)
		if not is_known(id):
			continue
		if index.has(id):
			out[index[id]]["count"] += 1
		else:
			index[id] = out.size()
			out.append({"id": id, "count": 1})
	return out


static func button_label(item_id: String, count: int) -> String:
	return label(item_id) if count <= 1 else "%s x%d" % [label(item_id), count]


## The Shoot payload for a shot item. target_x is used only by an item that needs it (sent with
## the air strike's angle and power, which the server validates).
static func shot_payload(item_id: String, angle: float, power: float, target_x: float = NAN) -> Dictionary:
	if needs_target_x(item_id):
		return {"angle": GameData.air_strike_angle(), "power": GameData.air_strike_power(), "actionMode": "item",
			"itemId": item_id, "targetX": target_x}
	return {"angle": angle, "power": power, "actionMode": "item", "itemId": item_id}


## Terrain a shot armed with this item drills through (px): a terrain_pierce item's value, 0
## for any other.
static func pierce(item_id: String) -> float:
	return GameData.item_value(item_id) if GameData.item_type(item_id) == "terrain_pierce" else 0.0


## True for an item that moves its user (a teleport: blocked while the player cannot move).
static func moves_user(item_id: String) -> bool:
	return GameData.item_type(item_id) == "teleport"
