extends RefCounted
## The Boss tab of "Chọn chế độ" without UI: one card per lobby mode of category boss
## (LobbyModel.modes(), the game data's order) joined to its boss (GET /gamedata bosses, by
## modeId, else by the mode's queue boss:<bossId>): the boss's art id, name, "Lv đề xuất N", its
## description and the big-reward runs left today from GET /boss/runs ("Lượt thưởng lớn: 2/3",
## "Làm mới lúc 00:00" from its resetAt in the device's zone). Every number and text is the
## server's; only the wording around them is the client's.

const LobbyModel := preload("res://screens/home/lobby_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const Fmt := preload("res://core/fmt.gd")

const CATEGORY := "boss"
const RUNS_LOADING := "Lượt thưởng lớn: ..."


static func _num(v: Variant, fallback: int = -1) -> int:
	return int(v) if v is int or v is float else fallback


## The cards in order: [{index (LobbyModel mode index), id (modeId), boss_id, name, level (0
## unknown), level_text ("Lv đề xuất 10"), description, runs_left (-1 unknown), runs_max,
## runs_text, reset_text, selected, element (the boss's elementId, "" none)}]. runs: GET /boss/runs data ({} / null: not loaded yet);
## bias_minutes: the device's zone east of UTC (Time.get_time_zone_from_system().bias).
static func cards(current: int, runs: Variant, bias_minutes: int) -> Array:
	var out: Array = []
	var all := LobbyModel.modes()
	for i in all.size():
		var m: Dictionary = all[i]
		if m["category"] != CATEGORY:
			continue
		out.append(card(i, m, current, runs, bias_minutes))
	return out


## One card (see cards()).
static func card(index: int, mode: Dictionary, current: int, runs: Variant, bias_minutes: int) -> Dictionary:
	var b := GameData.boss_of_mode(str(mode["id"]))
	if b.is_empty():
		b = GameData.boss_of_queue(str(mode["queue"]))
	var boss_id := str(b.get("bossId", ""))
	var level := _num(b.get("recommendedLevel"), 0)
	var name := str(b.get("name", "")) if str(b.get("name", "")) != "" else str(mode["name"])
	var desc := str(b.get("description", "")) if str(b.get("description", "")) != "" else str(mode["description"])
	var run := runs_of(runs, boss_id)
	var max_runs := _num(run.get("dailyBonusRuns"), _num(b.get("dailyBonusRuns"), 0))
	var left := _num(run.get("bonusRunsLeft"), -1)
	return {"index": index, "id": mode["id"], "boss_id": boss_id, "name": name, "level": level,
		"level_text": level_text(level), "description": desc, "runs_left": left, "runs_max": max_runs,
		"runs_text": runs_text(left, max_runs), "reset_text": reset_text(runs, bias_minutes), "selected": index == current,
		"element": GameData.boss_element(boss_id)}


## "Lv đề xuất 10"; "" without a level.
static func level_text(level: int) -> String:
	return "Lv đề xuất %d" % level if level > 0 else ""


## The GET /boss/runs entry of a boss ({} none / not loaded).
static func runs_of(runs: Variant, boss_id: String) -> Dictionary:
	if not runs is Dictionary or not runs.get("bosses") is Array:
		return {}
	for r in runs["bosses"]:
		if r is Dictionary and str(r.get("bossId", "")) == boss_id:
			return r
	return {}


## "Lượt thưởng lớn: 2/3" (left of max); RUNS_LOADING while unknown; "" for a boss with no big
## runs.
static func runs_text(left: int, max_runs: int) -> String:
	if max_runs <= 0 and left < 0:
		return ""
	if left < 0:
		return RUNS_LOADING
	return "Lượt thưởng lớn: %d/%d" % [clampi(left, 0, maxi(max_runs, left)), maxi(max_runs, left)]


## "Làm mới lúc 00:00": GET /boss/runs resetAt in the zone bias_minutes east of UTC; "" unknown.
static func reset_text(runs: Variant, bias_minutes: int) -> String:
	if not runs is Dictionary:
		return ""
	var unix := Fmt.unix_time(str(runs.get("resetAt", "")))
	if unix < 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(unix + bias_minutes * 60)
	return "Làm mới lúc %02d:%02d" % [d.hour, d.minute]
