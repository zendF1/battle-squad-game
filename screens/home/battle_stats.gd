extends RefCounted
## The "Chỉ số" table of Hồ sơ → Nhân vật: the battle stats GET /player/characters sends
## (`stats` per owned character: totals plus `base` / `fromPoints` / `fromEquipment`;
## `baseStats` for every character; `statMultipliers` per point) as display rows, and the
## preview of a pending stat draft. Data from an older server without these fields parses as
## {} and the table stays hidden.

## key: the stats field; point: the StatDraft / statMultipliers key whose points raise it;
## unit: "" a plain number, "+" a flat bonus, "%" a percent bonus.
const ROWS := [
	{"key": "maxHp", "point": "hp", "label": "Máu", "unit": ""},
	{"key": "defense", "point": "defense", "label": "Phòng thủ", "unit": ""},
	{"key": "damageBonus", "point": "damage", "label": "Sát thương", "unit": "+"},
	{"key": "moveEnergy", "point": "mobility", "label": "Năng lượng di chuyển", "unit": ""},
	{"key": "skillPowerBonus", "point": "skillPower", "label": "Sức mạnh kỹ năng", "unit": "%"},
	{"key": "terrainDamageBonus", "point": "terrainDamage", "label": "Phá địa hình", "unit": "%"},
]
const CRIT_LABEL := "Chí mạng"
const POINT_KEYS := ["hp", "damage", "mobility", "defense", "skillPower", "terrainDamage"]


static func _is_num(v: Variant) -> bool:
	return v is int or v is float


## A stats object (an entry's `stats` or a `baseStats` value) when every row value is a number,
## else {}.
static func parse(stats: Variant) -> Dictionary:
	if not stats is Dictionary:
		return {}
	for r in ROWS:
		if not _is_num(stats.get(r["key"])):
			return {}
	return stats


## A GET /player/characters entry's stats, or {}.
static func of(entry: Variant) -> Dictionary:
	return parse(entry.get("stats")) if entry is Dictionary else {}


## baseStats[id] from the GET /player/characters data, or {}.
static func base_of(data: Variant, id: String) -> Dictionary:
	var all = data.get("baseStats") if data is Dictionary else null
	return parse(all.get(id)) if all is Dictionary else {}


## statMultipliers (point key -> per-point value) from the GET /player/characters data, or {}
## when absent or malformed (no preview then).
static func multipliers(data: Variant) -> Dictionary:
	var m = data.get("statMultipliers") if data is Dictionary else null
	if not m is Dictionary:
		return {}
	var out := {}
	for k in POINT_KEYS:
		if not _is_num(m.get(k)):
			return {}
		out[k] = int(m[k])
	return out


## 200 → "200"; damage 10 → "+10"; skill power 15 → "+15%".
static func format(value: int, unit: String) -> String:
	match unit:
		"+":
			return "%+d" % value
		"%":
			return "%+d%%" % value
	return str(value)


## 2.25 → "2.3%", 3.0 → "3%".
static func format_chance(value: float) -> String:
	var t := "%.1f" % snappedf(value, 0.1)
	if t.ends_with(".0"):
		t = t.substr(0, t.length() - 2)
	return t + "%"


## The value after spending `points` more on the stat.
static func preview_value(total: int, points: int, per_point: int) -> int:
	return total + points * per_point


## Display rows in ROWS order: {key, point, label, value, preview, detail}. preview is
## "→ <new value>" while `pending` (point key -> points) has points for that stat and `mult` is
## known, else "". detail is "(gốc X, điểm +Y, trang bị +Z)" without the zero parts, and ""
## when neither points nor equipment add to it; damage starts with the weapon damage instead.
static func rows(stats: Dictionary, pending: Dictionary = {}, mult: Dictionary = {}) -> Array:
	var out := []
	if stats.is_empty():
		return out
	var base = stats.get("base")
	var fp = stats.get("fromPoints")
	var fe = stats.get("fromEquipment")
	for r in ROWS:
		var key: String = r["key"]
		var unit: String = r["unit"]
		var total := int(stats[key])
		var preview := ""
		var n := int(pending.get(r["point"], 0))
		if n > 0 and mult.has(r["point"]):
			preview = "→ " + format(preview_value(total, n, mult[r["point"]]), unit)
		var parts := []
		var from_points := int(fp.get(key, 0)) if fp is Dictionary and _is_num(fp.get(key)) else 0
		var from_equip := int(fe.get(key, 0)) if fe is Dictionary and _is_num(fe.get(key)) else 0
		if key == "damageBonus" and _is_num(stats.get("weaponDamage")):
			parts.append("vũ khí %d" % int(stats["weaponDamage"]))
		elif unit == "" and (from_points != 0 or from_equip != 0) and base is Dictionary and _is_num(base.get(key)):
			parts.append("gốc %d" % int(base[key]))
		if from_points != 0:
			parts.append("điểm " + format(from_points, "+" if unit == "" else unit))
		if from_equip != 0:
			parts.append("trang bị " + format(from_equip, "+" if unit == "" else unit))
		out.append({"key": key, "point": r["point"], "label": r["label"], "value": format(total, unit), "preview": preview,
			"detail": "(%s)" % ", ".join(parts) if not parts.is_empty() else ""})
	return out


## The "Chí mạng" row {label, value, detail} when the stats carry a crit chance above 0, else {}.
static func crit(stats: Dictionary) -> Dictionary:
	var c = stats.get("critChance")
	if not _is_num(c) or float(c) <= 0.0:
		return {}
	var fe = stats.get("fromEquipment")
	var detail := ""
	if fe is Dictionary and _is_num(fe.get("critChance")) and float(fe["critChance"]) > 0.0:
		detail = "(trang bị +%s)" % format_chance(float(fe["critChance"]))
	return {"label": CRIT_LABEL, "value": format_chance(float(c)), "detail": detail}


## A short line for a character card, "Máu 90 · Sát thương 55" (weapon damage + damage
## bonus); "" without stats.
static func card_line(stats: Dictionary) -> String:
	if stats.is_empty():
		return ""
	var dmg := int(stats["damageBonus"])
	if _is_num(stats.get("weaponDamage")):
		dmg += int(stats["weaponDamage"])
	return "Máu %d · Sát thương %d" % [int(stats["maxHp"]), dmg]
