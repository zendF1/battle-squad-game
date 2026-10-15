extends RefCounted
## Consumable items (server configs/items.yaml + match/item_effect.go; no API returns them).
##
## Each entry:
## - name: the Vietnamese label;
## - instant: true is used with UseItem {itemId} and acts at once (the turn goes on); false
##   arms the next shot, sent as Shoot {angle, power, actionMode: "item", itemId};
## - needs_target_x: the shot is aimed at a map column (Shoot.targetX) instead of a slingshot
##   arc (air_strike).
##
## The server answers both with ItemUsed (before ShotResolved for a shot item).

const MAX_LOADOUT := 3 # QuickPlay / SelectItems accept at most three items
# air_strike falls from the top of the map at targetX; the server ignores angle and power but
# still validates them.
const TARGET_X_ANGLE := 270.0
const TARGET_X_POWER := 80.0

## Loadout order.
const ORDER := ["medkit", "teleport", "power_shot", "drill_bomb", "spider_net", "freeze_bomb", "air_strike", "wind_stopper"]

const BY_ID := {
	"medkit": {"name": "Hộp cứu thương", "instant": true, "needs_target_x": false},
	"teleport": {"name": "Dịch chuyển", "instant": false, "needs_target_x": false},
	"power_shot": {"name": "Tăng lực", "instant": false, "needs_target_x": false},
	"drill_bomb": {"name": "Bom khoan", "instant": false, "needs_target_x": false},
	"spider_net": {"name": "Lưới nhện", "instant": false, "needs_target_x": false},
	"freeze_bomb": {"name": "Bom băng", "instant": false, "needs_target_x": false},
	"air_strike": {"name": "Không kích", "instant": false, "needs_target_x": true},
	"wind_stopper": {"name": "Dừng gió", "instant": true, "needs_target_x": false},
}


static func is_known(item_id: String) -> bool:
	return BY_ID.has(item_id)


## The Vietnamese label, or the id itself for an item this client does not know.
static func label(item_id: String) -> String:
	return str(BY_ID.get(item_id, {}).get("name", item_id))


static func is_instant(item_id: String) -> bool:
	return bool(BY_ID.get(item_id, {}).get("instant", false))


static func needs_target_x(item_id: String) -> bool:
	return bool(BY_ID.get(item_id, {}).get("needs_target_x", false))


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


## The Shoot payload for a shot item. target_x is used only by an item that needs it.
static func shot_payload(item_id: String, angle: float, power: float, target_x: float = NAN) -> Dictionary:
	if needs_target_x(item_id):
		return {"angle": TARGET_X_ANGLE, "power": TARGET_X_POWER, "actionMode": "item", "itemId": item_id, "targetX": target_x}
	return {"angle": angle, "power": power, "actionMode": "item", "itemId": item_id}
