extends RefCounted
## Chests (rương) without UI: the owned chests (GET /chests → {chests: [{chestId, quantity}]}),
## a chest's odds from the game data ("60% Đá 5 · 30% Đá 6 · 10% Đá 7", "1 trang bị +14 ngẫu
## nhiên"), the open buttons ("Mở" one, "Mở 10" up to ten), POST /chests/open's answer
## ({chestId, opened, stones: [{level, qty}], equipment: [{equipmentId, itemId, upgradeLevel}]})
## as popup lines, and the chests a match gave (MatchEnded.rewards[me].chests: [{chestId,
## quantity}]). Names, kinds, odds and upgrade levels are the game data's (GET /gamedata chests).

const GameData := preload("res://autoload/game_data_model.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const Fmt := preload("res://core/fmt.gd")

## The most chests one POST /chests/open opens.
const MAX_OPEN := 10


static func _num(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


static func _str(v: Variant) -> String:
	return str(v) if v is String else ""


## The owned chests from a GET /chests data, quantity > 0: [{chestId, quantity, name}], in the game
## data's chest order (unknown chests last, by id); null when the data is not a chest list.
static func parse_owned(data: Variant) -> Variant:
	if not data is Dictionary or not data.get("chests") is Array:
		return null
	var by := {}
	for c in data["chests"]:
		if not c is Dictionary or _str(c.get("chestId")) == "":
			continue
		var id := _str(c["chestId"])
		by[id] = int(by.get(id, 0)) + maxi(_num(c.get("quantity")), 0)
	var order: Array = GameData.chests().map(func(c): return str(c.get("chestId", "")))
	var ids: Array = by.keys().filter(func(id): return int(by[id]) > 0)
	ids.sort_custom(func(a, b):
		var ia := order.find(a)
		var ib := order.find(b)
		if ia != ib:
			return ia >= 0 and (ib < 0 or ia < ib)
		return str(a) < str(b))
	return ids.map(func(id): return {"chestId": id, "quantity": int(by[id]), "name": GameData.chest_name(id)})


## A chest's odds: a stone chest "60% Đá 5 · 30% Đá 6 · 10% Đá 7" (each weight's share, rounded);
## an equipment chest "1 trang bị +14 ngẫu nhiên"; "" unknown.
static func odds_text(chest_id: String) -> String:
	var stones := GameData.chest_stones(chest_id)
	if not stones.is_empty():
		var total := 0.0
		for s in stones:
			total += float(s.get("weight", 0))
		var parts := PackedStringArray()
		for s in stones:
			parts.append("%d%% Đá %d" % [roundi(100.0 * float(s["weight"]) / total), int(s["level"])])
		return " · ".join(parts)
	var up := GameData.chest_upgrade_level(chest_id)
	if GameData.chest_kind(chest_id) == "equipment" or up > 0:
		return "1 trang bị +%d ngẫu nhiên" % up if up > 0 else "1 trang bị ngẫu nhiên"
	return ""


## The Kho đồ tab a chest is listed in: a stone chest (kind "stone", or rolls of stones) under
## "Nguyên liệu" with the stones (TAB_MATERIALS), an equipment chest (and any other) under "Vật
## phẩm" (TAB_ITEMS).
const TAB_MATERIALS := "materials"
const TAB_ITEMS := "items"


static func tab_of(chest_id: String) -> String:
	var kind := GameData.chest_kind(chest_id)
	if kind == "stone" or (kind == "" and not GameData.chest_stones(chest_id).is_empty()):
		return TAB_MATERIALS
	return TAB_ITEMS


## The owned chests (parse_owned()) split by tab: {materials: [...], items: [...]}, each in the
## owned list's order; empty lists for null.
static func by_tab(owned: Variant) -> Dictionary:
	var out := {TAB_MATERIALS: [], TAB_ITEMS: []}
	if owned is Array:
		for c in owned:
			if c is Dictionary:
				out[tab_of(str(c.get("chestId", "")))].append(c)
	return out


## A chest's odds as pictures: a stone chest's [{level, pct}] (each weight's share, rounded: the
## stone icon over "60%"), an equipment chest's [{upgrade: 14}] (a piece over "+14"); [] unknown.
static func odds_parts(chest_id: String) -> Array:
	var stones := GameData.chest_stones(chest_id)
	if not stones.is_empty():
		var total := 0.0
		for s in stones:
			total += float(s.get("weight", 0))
		return stones.map(func(s): return {"level": int(s["level"]), "pct": roundi(100.0 * float(s["weight"]) / total)})
	var up := GameData.chest_upgrade_level(chest_id)
	if GameData.chest_kind(chest_id) == "equipment" or up > 0:
		return [{"upgrade": up}]
	return []


## The open buttons for `owned` chests: [{text, count}]: "Mở" (1) with at least one, then "Mở 10"
## (min(owned, MAX_OPEN), its count in the text when fewer) with at least two.
static func open_buttons(owned: int) -> Array:
	var out: Array = []
	if owned >= 1:
		out.append({"text": "Mở", "count": 1})
	if owned >= 2:
		var n := mini(owned, MAX_OPEN)
		out.append({"text": "Mở %d" % n, "count": n})
	return out


## POST /chests/open's data → {chestId, opened, stones: [{level, qty}] (merged, by level),
## equipment: [{equipmentId, itemId, upgradeLevel}]}; {} when it is not an open result.
static func parse_open(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var levels := {}
	if data.get("stones") is Array:
		for s in data["stones"]:
			if s is Dictionary and _num(s.get("level")) >= 1 and _num(s.get("qty")) > 0:
				levels[_num(s["level"])] = int(levels.get(_num(s["level"]), 0)) + _num(s["qty"])
	var keys: Array = levels.keys()
	keys.sort()
	var equipment: Array = []
	if data.get("equipment") is Array:
		for e in data["equipment"]:
			if e is Dictionary and _str(e.get("itemId")) != "":
				equipment.append({"equipmentId": _str(e.get("equipmentId")), "itemId": _str(e["itemId"]),
					"upgradeLevel": maxi(_num(e.get("upgradeLevel")), 0)})
	return {"chestId": _str(data.get("chestId")), "opened": maxi(_num(data.get("opened")), 0),
		"stones": keys.map(func(lv): return {"level": lv, "qty": levels[lv]}), "equipment": equipment}


## An open result's lines: [{kind: "stone", level, qty, text: "3 × Đá cấp 5"} | {kind:
## "equipment", itemId, upgradeLevel, text: "Giáp Rồng +14"}] (the piece's name from the catalog,
## else its id).
static func open_lines(result: Dictionary, catalog: Variant) -> Array:
	var out: Array = []
	for s in result.get("stones", []):
		out.append({"kind": "stone", "level": int(s["level"]), "qty": int(s["qty"]),
			"text": "%d × %s" % [int(s["qty"]), UpgradeModel.stone_name(int(s["level"]))]})
	for e in result.get("equipment", []):
		var item := EquipmentModel.item_of(catalog, str(e["itemId"]))
		var n := EquipmentModel.display_name(item) if not item.is_empty() else str(e["itemId"])
		var up := int(e["upgradeLevel"])
		out.append({"kind": "equipment", "itemId": str(e["itemId"]), "upgradeLevel": up,
			"text": "%s +%d" % [n, up] if up > 0 else n})
	return out


## "Mở 3 Rương đá".
static func opened_text(result: Dictionary) -> String:
	return "Mở %d %s" % [int(result.get("opened", 0)), GameData.chest_name(str(result.get("chestId", "")))]


## The chests a match gave (MatchEnded.rewards[me].chests): [{chestId, qty, name, text: "2 ×
## Rương đá"}], quantity > 0.
static func match_chests(v: Variant) -> Array:
	var out: Array = []
	if not v is Array:
		return out
	for c in v:
		if not c is Dictionary or _str(c.get("chestId")) == "":
			continue
		var qty := _num(c.get("quantity"))
		if qty <= 0:
			continue
		var id := _str(c["chestId"])
		out.append({"chestId": id, "qty": qty, "name": GameData.chest_name(id), "text": "%d × %s" % [qty, GameData.chest_name(id)]})
	return out


## "×12".
static func count_text(qty: int) -> String:
	return "×%s" % Fmt.thousands(qty)
