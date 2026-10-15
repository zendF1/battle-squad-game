extends RefCounted
## EXP bars. A player's exp is counted within the level and the next level needs level*100. A
## character's exp is cumulative over a fixed curve (server character_progression defaults).

## Cumulative exp at which a character reaches level i+1 (L1 = 0 ... L10 = 5200).
const CHARACTER_CURVE := [0, 200, 400, 700, 1100, 1600, 2200, 3000, 4000, 5200]
const CHARACTER_MAX_LEVEL := 10


## GET /player/profile level + exp → {current, needed, ratio, text: "x / level*100"}.
static func player(level: int, level_exp: int) -> Dictionary:
	var needed := maxi(level, 1) * 100
	var current := clampi(level_exp, 0, needed)
	return {"current": current, "needed": needed, "ratio": float(current) / needed, "text": "%d / %d" % [current, needed]}


## A GET /player/characters entry → {level, is_max, current, needed, ratio, text}. Within-level
## progress uses the curve; the server's nextLevelExp, when given, is the next threshold.
## Max level (isMaxLevel, level ≥ 10 or nextLevelExp null past the curve) reads "MAX".
static func character(c: Dictionary) -> Dictionary:
	var level := clampi(int(c.get("level", 1)), 1, CHARACTER_MAX_LEVEL)
	var total_exp := maxi(int(c.get("exp", 0)), 0)
	var next_raw = c.get("nextLevelExp")
	var is_max := bool(c.get("isMaxLevel", false)) or level >= CHARACTER_MAX_LEVEL
	if is_max:
		return {"level": level, "is_max": true, "current": 0, "needed": 0, "ratio": 1.0, "text": "MAX"}
	var base: int = CHARACTER_CURVE[level - 1]
	var next: int = CHARACTER_CURVE[level]
	if next_raw != null and int(next_raw) > base:
		next = int(next_raw)
	var needed := next - base
	var current := clampi(total_exp - base, 0, needed)
	return {"level": level, "is_max": false, "current": current, "needed": needed,
		"ratio": float(current) / needed, "text": "%d / %d" % [current, needed]}
