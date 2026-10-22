extends RefCounted
## EXP bars, on the game data's levels (GET /gamedata levels): a player's exp is counted within
## the level and the next level needs level × player.expPerLevel; a character's exp is cumulative
## over character.levels (the total EXP to reach each level; maxLevel the last). The server's
## level, nextLevelExp and isMaxLevel win.

const GameData := preload("res://autoload/game_data_model.gd")


## Cumulative exp to reach `level` (level ≤ 1 → 0).
static func character_threshold(level: int) -> int:
	return GameData.character_exp_required(level) if level > 1 else 0


## The EXP a player at `level` needs for the next one (level × expPerLevel).
static func player_needed(level: int) -> int:
	return maxi(level, 1) * GameData.player_exp_per_level()


## GET /player/profile level + exp → {current, needed, ratio, text: "x / needed"}.
static func player(level: int, level_exp: int) -> Dictionary:
	var needed := player_needed(level)
	var current := clampi(level_exp, 0, needed)
	return {"current": current, "needed": needed, "ratio": float(current) / needed if needed > 0 else 0.0,
		"text": "%d / %d" % [current, needed]}


## A GET /player/characters entry → {level, is_max, current, needed, ratio, text}. Within-level
## progress uses the table; the server's nextLevelExp, when given, is the next threshold.
## Max level reads "MAX": isMaxLevel from the server, or (without the flag) a level at or past the
## table's last level.
static func character(c: Dictionary) -> Dictionary:
	var level := maxi(int(c.get("level", 1)), 1)
	var total_exp := maxi(int(c.get("exp", 0)), 0)
	var next_raw = c.get("nextLevelExp")
	var flag = c.get("isMaxLevel")
	var is_max := bool(flag) if flag != null else level >= GameData.character_max_level()
	if is_max:
		return {"level": level, "is_max": true, "current": 0, "needed": 0, "ratio": 1.0, "text": "MAX"}
	var base := character_threshold(level)
	var next := character_threshold(level + 1)
	if next_raw != null and int(next_raw) > base:
		next = int(next_raw)
	var needed := next - base
	var current := clampi(total_exp - base, 0, needed)
	return {"level": level, "is_max": false, "current": current, "needed": needed,
		"ratio": float(current) / needed if needed > 0 else 0.0, "text": "%d / %d" % [current, needed]}
