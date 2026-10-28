extends RefCounted
## The Boss tab of "Chọn chế độ" without UI: one card per lobby mode of category boss
## (LobbyModel.modes(), the game data's order) joined to its boss (GET /gamedata bosses, by
## modeId, else by the mode's queue boss:<bossId>): the boss's art id, name, its description (the
## card's "i" popup) and the big-reward runs left today from GET /boss/runs, shown as a gift box
## with "×2", and the refill time "00:00" by a clock (its resetAt in the device's zone). Every
## number and text is the server's; only the wording around them is the client's.

const LobbyModel := preload("res://screens/home/lobby_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const Fmt := preload("res://core/fmt.gd")

const CATEGORY := LobbyModel.CATEGORY_BOSS
const RUNS_LOADING := "×…"


static func _num(v: Variant, fallback: int = -1) -> int:
	return int(v) if v is int or v is float else fallback


## The cards in order: [{index (LobbyModel mode index), id (modeId), boss_id, name, description,
## party_size, runs_left (-1 unknown), runs_max, runs_text ("×2" by the gift box), reset_text
## ("00:00" by the clock), selected, element (the boss's elementId, "" none)}]. runs: GET /boss/runs data ({} / null: not loaded yet);
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
	var name := str(b.get("name", "")) if str(b.get("name", "")) != "" else str(mode["name"])
	var desc := str(b.get("description", "")) if str(b.get("description", "")) != "" else str(mode["description"])
	var run := runs_of(runs, boss_id)
	var max_runs := _num(run.get("dailyBonusRuns"), _num(b.get("dailyBonusRuns"), 0))
	var left := _num(run.get("bonusRunsLeft"), -1)
	return {"index": index, "id": mode["id"], "boss_id": boss_id, "name": name, "description": desc,
		"party_size": int(mode.get("party_size", 0)), "runs_left": left, "runs_max": max_runs,
		"runs_text": runs_text(left, max_runs), "reset_text": reset_text(runs, bias_minutes), "selected": index == current,
		"element": GameData.boss_element(boss_id)}


## The GET /boss/runs entry of a boss ({} none / not loaded).
static func runs_of(runs: Variant, boss_id: String) -> Dictionary:
	if not runs is Dictionary or not runs.get("bosses") is Array:
		return {}
	for r in runs["bosses"]:
		if r is Dictionary and str(r.get("bossId", "")) == boss_id:
			return r
	return {}


## The big-reward runs left, shown by the gift box: "×2"; RUNS_LOADING while unknown; "" for a
## boss with no big runs.
static func runs_text(left: int, max_runs: int) -> String:
	if max_runs <= 0 and left < 0:
		return ""
	if left < 0:
		return RUNS_LOADING
	return "×%d" % maxi(left, 0)


## When the runs refill, shown by a clock: "00:00", GET /boss/runs resetAt in the zone
## bias_minutes east of UTC; "" unknown.
static func reset_text(runs: Variant, bias_minutes: int) -> String:
	if not runs is Dictionary:
		return ""
	var unix := Fmt.unix_time(str(runs.get("resetAt", "")))
	if unix < 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(unix + bias_minutes * 60)
	return "%02d:%02d" % [d.hour, d.minute]
