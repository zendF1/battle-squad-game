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
