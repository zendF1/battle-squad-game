extends RefCounted
## Season rewards without UI: the unclaimed results of ended seasons (GET /rank/season-rewards →
## {rewards: [{seasonId, seasonName, grade, division, rankPos, rankPoints, coin, gem, items:
## [{kind, id, qty, name}]}]}, oldest first), the popup's heading ("Phần thưởng Mùa 1: Trung sĩ
## 2") and reward lines, the claim's wallet (POST /rank/season-rewards/claim → the same object
## plus wallet: {coin, gem, gemUnlocked}), and the season-end preview of a grade from the game
## data (seasonRewards). The gem of a season reward is locked gem (kim cương khoá).

const GameData := preload("res://autoload/game_data_model.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const Fmt := preload("res://core/fmt.gd")

const NBSP := "\u00a0"


static func _num(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


static func _str(v: Variant) -> String:
	return str(v) if v is String else ""


## One reward object (a GET row or a claim answer) → {seasonId, seasonName, grade, division,
## rankPos, rankPoints, coin, gem, items: [{kind, id, level, qty, name}]}; {} without a seasonId.
static func parse_one(r: Variant) -> Dictionary:
	if not r is Dictionary or _str(r.get("seasonId")) == "":
		return {}
	var items: Array = []
	if r.get("items") is Array:
		for it in r["items"]:
			if not it is Dictionary or _num(it.get("qty")) <= 0:
				continue
			items.append({"kind": _str(it.get("kind")), "id": _str(it.get("id")), "level": _num(it.get("level")),
				"qty": _num(it["qty"]), "name": _str(it.get("name"))})
	return {"seasonId": _str(r["seasonId"]), "seasonName": _str(r.get("seasonName")), "grade": _str(r.get("grade")),
		"division": _num(r.get("division")), "rankPos": _num(r.get("rankPos")), "rankPoints": maxi(_num(r.get("rankPoints")), 0),
		"coin": maxi(_num(r.get("coin")), 0), "gem": maxi(_num(r.get("gem")), 0), "items": items}


## GET /rank/season-rewards data → the unclaimed rewards (parse_one()), in the server's order
## (oldest first); [] for anything else.
static func parse(data: Variant) -> Array:
	var out: Array = []
	if data is Dictionary and data.get("rewards") is Array:
		for r in data["rewards"]:
			var one := parse_one(r)
			if not one.is_empty():
				out.append(one)
	return out


## "Phần thưởng Mùa 1: Trung sĩ 2" (a general without a division; the grade id when unknown).
static func heading(r: Dictionary) -> String:
	var g := RankModel.label(str(r["grade"]), int(r["division"]))
	if g == "":
		g = str(r["grade"])
	var season: String = r["seasonName"] if str(r["seasonName"]) != "" else "mùa trước"
	return "Phần thưởng %s: %s" % [season, g]


## "Hạng #3 · 4.230 điểm" (the final position and points); the points alone without a position.
static func standing_text(r: Dictionary) -> String:
	var pts := RankModel.points_text(int(r["rankPoints"]))
	return "%s · %s" % [RankModel.position_text(int(r["rankPos"])), pts] if int(r["rankPos"]) > 0 else pts


## An item's name: the answer's, else a chest's / an item's game data name, a stone's
## "Đá cấp N", else the id.
static func item_name(it: Dictionary) -> String:
	if str(it.get("name", "")) != "":
		return str(it["name"])
	match str(it.get("kind", "")):
		"chest":
			return GameData.chest_name(str(it.get("id", "")))
		"stone":
			return UpgradeModel.stone_name(int(it.get("level", 0)))
		"item":
			var n := GameData.item_name(str(it.get("id", "")))
			return n if n != "" else str(it.get("id", ""))
	return str(it.get("id", ""))


## The reward lines: [{kind: "coin" | "gem" | "chest" | "stone" | "item" | "title", id, level,
## qty, text}]: "40.000 xu", "400 kim cương khoá", "10 × Rương đá".
static func lines(r: Dictionary) -> Array:
	var out: Array = []
	if int(r.get("coin", 0)) > 0:
		out.append({"kind": "coin", "id": "", "level": 0, "qty": int(r["coin"]), "text": "%s xu" % Fmt.thousands(int(r["coin"]))})
	if int(r.get("gem", 0)) > 0:
		out.append({"kind": "gem", "id": "", "level": 0, "qty": int(r["gem"]), "text": "%s kim cương khoá" % Fmt.thousands(int(r["gem"]))})
	for it in r.get("items", []):
		var text := "Danh hiệu mới: %s" % item_name(it) if str(it["kind"]) == "title" else "%d × %s" % [int(it["qty"]), item_name(it)]
		out.append({"kind": str(it["kind"]), "id": str(it["id"]), "level": int(it.get("level", 0)), "qty": int(it["qty"]), "text": text})
	return out


## A claim answer's wallet {coin, gem, gemUnlocked} (only the numbers it has); {} none.
static func wallet_of(data: Variant) -> Dictionary:
	if not data is Dictionary or not data.get("wallet") is Dictionary:
		return {}
	var out := {}
	for k in ["coin", "gem", "gemUnlocked"]:
		var v = data["wallet"].get(k)
		if v is int or v is float:
			out[k] = int(v)
	return out


## The season-end preview of a grade (the game data's seasonRewards): "Cuối mùa: 2.000 xu · 1 ×
## Rương đá"; "" when the grade has no reward.
static func preview_text(grade: String) -> String:
	var sr := GameData.season_reward(grade)
	if sr.is_empty():
		return ""
	var parts := PackedStringArray()
	for l in lines({"coin": _num(sr.get("coin")), "gem": _num(sr.get("gem")), "items": parse_one({"seasonId": "-", "items": sr.get("items")})["items"]}):
		parts.append(str(l["text"]).replace(" × ", NBSP + "×" + NBSP)) # a wrapped line never splits "12 × Rương đá"
	return "Thưởng cuối mùa: %s" % " · ".join(parts) if not parts.is_empty() else ""
