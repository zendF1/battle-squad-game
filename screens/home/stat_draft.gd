extends RefCounted
## Stat points a player is about to spend on one character, before "Cộng điểm" sends them in one
## POST /player/character/allocate-stats. The pending total never exceeds the character's
## statPoints.

## key: the allocate-stats field; field: the GET /player/characters bonus; label: Vietnamese.
const STATS := [
	{"key": "hp", "field": "bonusHp", "label": "Máu"},
	{"key": "damage", "field": "bonusDamage", "label": "Sát thương"},
	{"key": "mobility", "field": "bonusMobility", "label": "Di chuyển"},
	{"key": "defense", "field": "bonusDefense", "label": "Phòng thủ"},
	{"key": "skillPower", "field": "bonusSkillPower", "label": "Sức mạnh kỹ năng"},
	{"key": "terrainDamage", "field": "bonusTerrainDmg", "label": "Phá địa hình"},
]

const ShopModel := preload("res://screens/home/shop_model.gd")
const Fmt := preload("res://core/fmt.gd")

var character_id := ""
var stat_points := 0
var current := {} # key -> allocated bonus
var _pending := {} # key -> points about to be added


## From a GET /player/characters entry.
func _init(c: Dictionary = {}) -> void:
	character_id = str(c.get("characterId", ""))
	stat_points = maxi(int(c.get("statPoints", 0)), 0)
	for s in STATS:
		current[s["key"]] = int(c.get(s["field"], 0))
		_pending[s["key"]] = 0


func pending(key: String) -> int:
	return int(_pending.get(key, 0))


func total_pending() -> int:
	var n := 0
	for key in _pending:
		n += _pending[key]
	return n


func remaining() -> int:
	return stat_points - total_pending()


func can_add(key: String) -> bool:
	return _pending.has(key) and remaining() > 0


func can_remove(key: String) -> bool:
	return pending(key) > 0


func add(key: String) -> bool:
	if not can_add(key):
		return false
	_pending[key] += 1
	return true


func remove(key: String) -> bool:
	if not can_remove(key):
		return false
	_pending[key] -= 1
	return true


func clear() -> void:
	for key in _pending:
		_pending[key] = 0


func can_submit() -> bool:
	return character_id != "" and total_pending() > 0 and total_pending() <= stat_points


## Whether a GET /player/characters entry has the state this draft was built from (same
## statPoints and bonuses), so its pending points are still valid.
func matches(c: Dictionary) -> bool:
	if str(c.get("characterId", "")) != character_id or maxi(int(c.get("statPoints", 0)), 0) != stat_points:
		return false
	for s in STATS:
		if int(c.get(s["field"], 0)) != current[s["key"]]:
			return false
	return true


## Drafts for freshly loaded characters (characterId -> entry): a character whose server state
## did not change keeps its draft (and pending points); the others, and `drop_id`, start empty.
static func rebuild(old: Dictionary, characters: Dictionary, drop_id: String = "") -> Dictionary:
	var out := {}
	for id in characters:
		var draft = old.get(id)
		if draft != null and id != drop_id and draft.matches(characters[id]):
			out[id] = draft
		else:
			out[id] = new(characters[id])
	return out


## The allocate-stats body: every stat, 0 when untouched.
func payload() -> Dictionary:
	var out := {"characterId": character_id}
	for s in STATS:
		out[s["key"]] = pending(s["key"])
	return out


## Whether any point is allocated (reset-stats refuses a character with none).
func has_allocated() -> bool:
	for key in current:
		if current[key] > 0:
			return true
	return false


## The reset fee {currency, amount} from the GET /player/characters data (resetStatsCost), or
## {} (unknown: no price shown, the server decides) when it is absent or malformed.
static func reset_cost(data: Variant) -> Dictionary:
	var c = data.get("resetStatsCost") if data is Dictionary else null
	if c is Dictionary and str(c.get("currency", "")) in ["coin", "gem"] and (c.get("amount") is float or c.get("amount") is int) and int(c["amount"]) >= 0:
		return {"currency": str(c["currency"]), "amount": int(c["amount"])}
	return {}


## "500 xu", "50 kim cương"; "" for an unknown fee ({}).
static func cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	return "%s %s" % [Fmt.thousands(int(cost.get("amount", 0))), ShopModel.currency_word(str(cost.get("currency", "")))]
