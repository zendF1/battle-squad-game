extends RefCounted
## EXP bars. A player's exp is counted within the level and the next level needs level*100. A
## character's exp is cumulative over the server's level table (character_levels).

## The server's default character level table (game_settings character_levels, migrations 006 +
## 019): cumulative exp to reach a level. L1 = 0, L2..L10 below, then the step to the next level
## grows by 25: threshold(L) = 5200 + 1200n + 25n(n+1)/2 with n = L - 10 (L40 = 52825, L80 = 151325).
## Admin may change the table; the server's level, nextLevelExp and isMaxLevel win.
const CHARACTER_CURVE := [0, 200, 400, 700, 1100, 1600, 2200, 3000, 4000, 5200]
const CHARACTER_MAX_LEVEL := 80


## Cumulative exp to reach `level` on the default table (level ≤ 1 → 0).
static func character_threshold(level: int) -> int:
	if level <= 1:
		return 0
	if level <= CHARACTER_CURVE.size():
		return CHARACTER_CURVE[level - 1]
	var n := level - CHARACTER_CURVE.size()
	return 5200 + 1200 * n + 25 * n * (n + 1) / 2


## GET /player/profile level + exp → {current, needed, ratio, text: "x / level*100"}.
static func player(level: int, level_exp: int) -> Dictionary:
	var needed := maxi(level, 1) * 100
	var current := clampi(level_exp, 0, needed)
	return {"current": current, "needed": needed, "ratio": float(current) / needed, "text": "%d / %d" % [current, needed]}


## A GET /player/characters entry → {level, is_max, current, needed, ratio, text}. Within-level
## progress uses the default table; the server's nextLevelExp, when given, is the next threshold.
## Max level reads "MAX": isMaxLevel from the server, or (without the flag) a level at or past the
## default table's last level.
static func character(c: Dictionary) -> Dictionary:
	var level := maxi(int(c.get("level", 1)), 1)
	var total_exp := maxi(int(c.get("exp", 0)), 0)
	var next_raw = c.get("nextLevelExp")
	var flag = c.get("isMaxLevel")
	var is_max := bool(flag) if flag != null else level >= CHARACTER_MAX_LEVEL
	if is_max:
		return {"level": level, "is_max": true, "current": 0, "needed": 0, "ratio": 1.0, "text": "MAX"}
	var base := character_threshold(level)
	var next := character_threshold(level + 1)
	if next_raw != null and int(next_raw) > base:
		next = int(next_raw)
	var needed := next - base
	var current := clampi(total_exp - base, 0, needed)
	return {"level": level, "is_max": false, "current": current, "needed": needed,
		"ratio": float(current) / needed, "text": "%d / %d" % [current, needed]}
