extends RefCounted
## The "Mốc thưởng" data without UI: GET /milestones parsed per track, the tabs, the sub-tracks
## ("Số trận", "Số trận thắng" ...) a track's nodes split into, each node's threshold ("Cấp 20",
## "+14", "Vũ khí +16", "Cả bộ +6", "50 trận", "Vàng"), progress ("37/50", locked nodes only),
## state and reward lines, and the claimable counts the badges show. Reward items of a kind
## this client does not know (a future {"kind": "title"}) are left out, never an error; a node
## left with nothing to show is left out too.

const Fmt := preload("res://core/fmt.gd")

const CLAIMED := "claimed"
const CLAIMABLE := "claimable"
const LOCKED := "locked"

## The page's tabs, in order: [track id, tab name].
const TABS := [["character", "Nhân vật"], ["upgrade", "Nâng cấp"], ["combat", "Chiến đấu"], ["rank", "Xếp hạng"]]

## Rank tier ids by the server's rank_peak order (bronze 1 … master 6).
const TIERS := ["", "bronze", "silver", "gold", "platinum", "diamond", "master"]
const TIER_NAMES := {"bronze": "Đồng", "silver": "Bạc", "gold": "Vàng", "platinum": "Bạch kim", "diamond": "Kim cương", "master": "Cao thủ"}

## Sub-tracks: target (or target prefix ending in ":") → [title, hint]. Order is the order shown.
const GROUPS := [
	["char_level", "Cấp nhân vật", "1 nhân vật bất kỳ đạt cấp"],
	["upgrade_peak", "Cường hoá", "1 trang bị bất kỳ đạt"],
	["weapon_upgrade_peak", "Vũ khí", "1 vũ khí đạt, mở khoá hào quang sau lưng"],
	["set_level:", "Bộ trang bị hoàn chỉnh", "1 nhân vật mặc đủ 6 món, món nào cũng đạt"],
	["matches", "Số trận", "Trận ghép hoặc đấu với máy, chơi đến hết"],
	["wins", "Số trận thắng", "Trận ghép hoặc đấu với máy"],
	["char_wins", "Thắng với 1 nhân vật", "Số trận thắng của nhân vật thắng nhiều nhất"],
	["rank_peak", "Hạng cao nhất", "Lần đầu đạt hạng, không mất khi tụt hạng"],
]


## GET /milestones data → {"tracks": {track: [node, ...]}, "claimable": n}; null when malformed.
## A node: {id, track, target, required, progress, state, rewards: {coin, gem, items}, description}.
static func parse(data: Variant) -> Variant:
	if not data is Dictionary or not data.get("tracks") is Array:
		return null
	var tracks := {}
	var claimable := 0
	for t in data["tracks"]:
		if not t is Dictionary or not t.get("nodes") is Array:
			continue
		var track := str(t.get("track", ""))
		var list: Array = tracks.get(track, [])
		for n in t["nodes"]:
			if not n is Dictionary or str(n.get("id", "")) == "":
				continue
			var node := {
				"id": str(n["id"]),
				"track": track,
				"target": str(n.get("target", "")),
				"required": _int(n.get("required")),
				"progress": _int(n.get("progress")),
				"state": str(n.get("state", LOCKED)),
				"rewards": parse_rewards(n.get("rewards")),
				"description": str(n.get("description", "")),
			}
			if reward_lines(node["rewards"]).is_empty():
				continue # only rewards this client cannot show (a future title): left out
			if not node["state"] in [CLAIMED, CLAIMABLE, LOCKED]:
				node["state"] = LOCKED
			if node["state"] == CLAIMABLE:
				claimable += 1
			list.append(node)
		tracks[track] = list
	return {"tracks": tracks, "claimable": claimable}


static func _int(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


## {coin, gem, items} with only the item kinds this client can show (stone, item).
static func parse_rewards(r: Variant) -> Dictionary:
	var out := {"coin": 0, "gem": 0, "items": []}
	if not r is Dictionary:
		return out
	out["coin"] = maxi(0, _int(r.get("coin")))
	out["gem"] = maxi(0, _int(r.get("gem")))
	if r.get("items") is Array:
		for it in r["items"]:
			if not it is Dictionary:
				continue
			var kind := str(it.get("kind", ""))
			var qty := _int(it.get("qty"))
			if qty <= 0:
				continue
			var entry := {}
			if kind == "stone" and _int(it.get("level")) >= 1:
				entry = {"kind": "stone", "level": _int(it["level"]), "qty": qty}
			elif kind == "item" and str(it.get("id", "")) != "":
				entry = {"kind": "item", "id": str(it["id"]), "qty": qty}
			if not entry.is_empty():
				_merge_item(out["items"], entry)
	# Stones by level, then items in the server's order
	out["items"].sort_custom(func(a, b):
		if a["kind"] != b["kind"]:
			return a["kind"] == "stone"
		return a["kind"] == "stone" and int(a["level"]) < int(b["level"]))
	return out


## Adds entry to items, adding to the quantity of the same stone level / item id.
static func _merge_item(items: Array, entry: Dictionary) -> void:
	for e in items:
		if e["kind"] == entry["kind"] and e.get("level") == entry.get("level") and e.get("id") == entry.get("id"):
			e["qty"] += entry["qty"]
			return
	items.append(entry)


## The nodes of a track ([] when not loaded or empty).
static func nodes(parsed: Variant, track: String) -> Array:
	if not parsed is Dictionary:
		return []
	return parsed["tracks"].get(track, [])


static func claimable_in(parsed: Variant, track: String) -> int:
	return nodes(parsed, track).filter(func(n): return n["state"] == CLAIMABLE).size()


## The claimable count over every track (0 when not loaded).
static func claimable_total(parsed: Variant) -> int:
	return int(parsed["claimable"]) if parsed is Dictionary else 0


## The group key of a target: its GROUPS entry, or the target itself.
static func group_key(target: String) -> String:
	for g in GROUPS:
		var key: String = g[0]
		if target == key or (key.ends_with(":") and target.begins_with(key)):
			return key
	return target


## A track's nodes split into sub-tracks, in GROUPS order (unknown targets last):
## [{key, title, hint, nodes}].
static func groups(parsed: Variant, track: String) -> Array:
	var by_key := {}
	var order: Array = []
	for n in nodes(parsed, track):
		var key := group_key(n["target"])
		if not by_key.has(key):
			by_key[key] = []
			order.append(key)
		by_key[key].append(n)
	var rank := func(key: String) -> int:
		for i in GROUPS.size():
			if GROUPS[i][0] == key:
				return i
		return GROUPS.size()
	order.sort_custom(func(a, b): return rank.call(a) < rank.call(b))
	var out: Array = []
	for key in order:
		var title := "Khác"
		var hint := ""
		for g in GROUPS:
			if g[0] == key:
				title = g[1]
				hint = g[2]
		out.append({"key": key, "title": title, "hint": hint, "nodes": by_key[key]})
	return out


static func tier_name(order: int) -> String:
	if order < 1 or order >= TIERS.size():
		return "Chưa có hạng"
	return TIER_NAMES[TIERS[order]]


## The set level of a "set_level:N" target (0 when not one).
static func set_level(target: String) -> int:
	return int(target.trim_prefix("set_level:")) if target.begins_with("set_level:") else 0


## What reaching the node means, short: "Cấp 20", "+14", "Vũ khí +16", "Cả bộ +6", "50 trận",
## "25 thắng", "Vàng".
static func threshold(node: Dictionary) -> String:
	var req: int = node["required"]
	var target: String = node["target"]
	match group_key(target):
		"char_level": return "Cấp %d" % req
		"upgrade_peak": return "+%d" % req
		"weapon_upgrade_peak": return "Vũ khí +%d" % req
		"set_level:": return "Cả bộ +%d" % set_level(target)
		"matches": return "%s trận" % Fmt.thousands(req)
		"wins", "char_wins": return "%s thắng" % Fmt.thousands(req)
		"rank_peak": return tier_name(req)
	return Fmt.thousands(req)


## The progress under a locked node ("37/50", "+7/+14", "4/6 món", "Đang: Bạc"); "" otherwise.
static func progress_text(node: Dictionary) -> String:
	if node["state"] != LOCKED:
		return ""
	var p: int = mini(node["progress"], node["required"])
	var req: int = node["required"]
	match group_key(node["target"]):
		"upgrade_peak", "weapon_upgrade_peak": return "+%d/+%d" % [p, req]
		"set_level:": return "%d/%d món" % [p, req]
		"rank_peak": return "Đang: %s" % tier_name(node["progress"])
	return "%s/%s" % [Fmt.thousands(p), Fmt.thousands(req)]


## A node's longer name, for the claim popup: "1 nhân vật đạt cấp 20", "1 trang bị đạt +14",
## "Vũ khí đạt +16", "Cả bộ trang bị +6", "Chơi 50 trận", "Thắng 25 trận",
## "Thắng 10 trận với 1 nhân vật", "Đạt hạng Vàng".
static func title(node: Dictionary) -> String:
	var req: int = node["required"]
	match group_key(node["target"]):
		"char_level": return "1 nhân vật đạt cấp %d" % req
		"upgrade_peak": return "1 trang bị đạt +%d" % req
		"weapon_upgrade_peak": return "Vũ khí đạt +%d" % req
		"set_level:": return "Cả bộ trang bị +%d" % set_level(node["target"])
		"matches": return "Chơi %s trận" % Fmt.thousands(req)
		"wins": return "Thắng %s trận" % Fmt.thousands(req)
		"char_wins": return "Thắng %s trận với 1 nhân vật" % Fmt.thousands(req)
		"rank_peak": return "Đạt hạng %s" % tier_name(req)
	return threshold(node)


## The state line under a node: "Đã nhận", "Nhận" or the progress.
static func state_text(node: Dictionary) -> String:
	match node["state"]:
		CLAIMED: return "Đã nhận"
		CLAIMABLE: return "Nhận"
	return progress_text(node)


## The rewards as lines: [{kind: "coin"|"gem"|"stone"|"item", qty, level?, id?, short, text}];
## short is what the node shows next to the icon ("1.000", "×3"), text the popup line
## ("1.000 xu", "20 kim cương", "3 × Đá cấp 4").
static func reward_lines(rewards: Dictionary) -> Array:
	var out: Array = []
	if int(rewards.get("coin", 0)) > 0:
		var n := int(rewards["coin"])
		out.append({"kind": "coin", "qty": n, "short": Fmt.thousands(n), "text": "%s xu" % Fmt.thousands(n)})
	if int(rewards.get("gem", 0)) > 0:
		var n := int(rewards["gem"])
		out.append({"kind": "gem", "qty": n, "short": Fmt.thousands(n), "text": "%s kim cương" % Fmt.thousands(n)})
	for it in rewards.get("items", []):
		if not it is Dictionary:
			continue
		var qty := int(it.get("qty", 0))
		match str(it.get("kind", "")):
			"stone":
				out.append({"kind": "stone", "level": int(it.get("level", 1)), "qty": qty, "short": "×%d" % qty,
					"text": "%d × Đá cấp %d" % [qty, int(it.get("level", 1))]})
			"item":
				out.append({"kind": "item", "id": str(it.get("id", "")), "qty": qty, "short": "×%d" % qty,
					"text": "%d × %s" % [qty, str(it.get("id", ""))]})
	return out


## The index of the node a path scrolls to: the first claimable, else the first locked, else the
## last.
static func focus_index(group_nodes: Array) -> int:
	for i in group_nodes.size():
		if group_nodes[i]["state"] == CLAIMABLE:
			return i
	for i in group_nodes.size():
		if group_nodes[i]["state"] == LOCKED:
			return i
	return maxi(0, group_nodes.size() - 1)


## The badge text: "" at 0, "9+" above 9.
static func badge_text(count: int) -> String:
	if count <= 0:
		return ""
	return "9+" if count > 9 else str(count)
