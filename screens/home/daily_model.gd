extends RefCounted
## The "Nhiệm Vụ Ngày" data without UI: GET /missions/daily (DailyState) parsed, the mission rows
## in display order (claimable, then in progress, then claimed; the server's order inside each),
## a row's button (state + goto), the activity bars' fill between the chest thresholds, the
## countdown texts and the claimable count the lobby's red dot shows. Rewards are the milestone
## format ({coin, gem, items}; MilestoneModel.parse_rewards / reward_lines), item lines named.

const Fmt := preload("res://core/fmt.gd")
const Items := preload("res://match/items.gd")
const MilestoneModel := preload("res://screens/home/milestone_model.gd")

## Mission states.
const PROGRESS := "progress"
const CLAIMABLE := "claimable"
const CLAIMED := "claimed"
## Chest states (daily chests and weekly rewards).
const LOCKED := "locked"

## Where "Đi ngay" leads.
const GOTO_PLAY := "play"
const GOTO_SHOP := "shop"
const GOTO_EQUIPMENT := "equipment"
const GOTO_NONE := "none"
const GOTOS := [GOTO_PLAY, GOTO_SHOP, GOTO_EQUIPMENT]

## A row's button: what it does.
const ACTION_GO := "go"
const ACTION_CLAIM := "claim"
const ACTION_NONE := "none"


## DailyState → {day, week, day_reset, week_reset (unix seconds, -1 unknown), activity,
## weekly_activity, missions: [{id, title, target, required, progress, activity, goto, state,
## order}], chests / weekly: [{id, track, threshold, state, rewards}] by threshold}; null when
## malformed. Bad entries are skipped; an unknown state reads as not done / locked.
static func parse(data: Variant) -> Variant:
	if not data is Dictionary or not data.get("missions") is Array:
		return null
	var missions: Array = []
	for m in data["missions"]:
		if not m is Dictionary or str(m.get("id", "")) == "":
			continue
		var state := str(m.get("state", PROGRESS))
		if not state in [PROGRESS, CLAIMABLE, CLAIMED]:
			state = PROGRESS
		var go := str(m.get("goto", GOTO_NONE))
		var required := maxi(1, _int(m.get("required")))
		missions.append({
			"id": str(m["id"]),
			"title": str(m.get("title", m["id"])),
			"target": str(m.get("target", "")),
			"required": required,
			"progress": clampi(_int(m.get("progress")), 0, required),
			"activity": maxi(0, _int(m.get("activity"))),
			"goto": go if go in GOTOS else GOTO_NONE,
			"state": state,
			"order": missions.size(),
		})
	return {
		"day": str(data.get("day", "")),
		"week": str(data.get("week", "")),
		"day_reset": Fmt.unix_time(str(data.get("dayResetAt", ""))),
		"week_reset": Fmt.unix_time(str(data.get("weekResetAt", ""))),
		"activity": maxi(0, _int(data.get("activity"))),
		"weekly_activity": maxi(0, _int(data.get("weeklyActivity"))),
		"missions": missions,
		"chests": _chests(data.get("chests")),
		"weekly": _chests(data.get("weekly")),
	}


static func _chests(list: Variant) -> Array:
	var out: Array = []
	if not list is Array:
		return out
	for c in list:
		if not c is Dictionary or str(c.get("id", "")) == "":
			continue
		var state := str(c.get("state", LOCKED))
		out.append({
			"id": str(c["id"]),
			"track": str(c.get("track", "")),
			"threshold": maxi(0, _int(c.get("threshold"))),
			"state": state if state in [LOCKED, CLAIMABLE, CLAIMED] else LOCKED,
			"rewards": MilestoneModel.parse_rewards(c.get("rewards")),
		})
	out.sort_custom(func(a, b): return a["threshold"] < b["threshold"])
	return out


static func _int(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


## The missions to show, claimable first, then in progress, then claimed; the server's order
## inside each group.
static func sorted_missions(missions: Array) -> Array:
	var rank := {CLAIMABLE: 0, PROGRESS: 1, CLAIMED: 2}
	var out := missions.duplicate()
	out.sort_custom(func(a, b):
		var ra: int = rank.get(a["state"], 1)
		var rb: int = rank.get(b["state"], 1)
		if ra != rb:
			return ra < rb
		return int(a.get("order", 0)) < int(b.get("order", 0)))
	return out


## A row's button: {text, action (ACTION_*), enabled}. Not done: "Đi ngay" when the mission
## says where to do it, else a disabled "Chưa xong"; done: "Nhận"; claimed: a disabled "Đã nhận".
static func button(mission: Dictionary) -> Dictionary:
	match str(mission.get("state", "")):
		CLAIMABLE:
			return {"text": "Nhận", "action": ACTION_CLAIM, "enabled": true}
		CLAIMED:
			return {"text": "Đã nhận", "action": ACTION_NONE, "enabled": false}
	if str(mission.get("goto", GOTO_NONE)) in GOTOS:
		return {"text": "Đi ngay", "action": ACTION_GO, "enabled": true}
	return {"text": "Chưa xong", "action": ACTION_NONE, "enabled": false}


## "1/3", "1.250/3.000" (the progress is capped at the requirement).
static func progress_text(mission: Dictionary) -> String:
	var req: int = maxi(1, int(mission.get("required", 1)))
	return "%s/%s" % [Fmt.thousands(clampi(int(mission.get("progress", 0)), 0, req)), Fmt.thousands(req)]


static func progress_ratio(mission: Dictionary) -> float:
	var req: int = maxi(1, int(mission.get("required", 1)))
	return clampf(float(mission.get("progress", 0)) / req, 0.0, 1.0)


## How full an activity bar is (0..1) at `value`, the markers (chest thresholds, ascending) at
## equal steps: marker i sits at (i + 1) / n, the bar fills linearly between two markers (from 0
## to the first one). [] → 0.
static func bar_fill(value: float, thresholds: Array) -> float:
	var n := thresholds.size()
	if n == 0:
		return 0.0
	var prev := 0.0
	for i in n:
		var t := float(thresholds[i])
		if value < t:
			var span := maxf(t - prev, 0.0001)
			return clampf((float(i) + (value - prev) / span) / n, 0.0, 1.0)
		prev = t
	return 1.0


## Where marker i of n sits along a bar (0..1).
static func marker_at(i: int, n: int) -> float:
	return float(i + 1) / maxi(1, n)


static func thresholds(chests: Array) -> Array:
	return chests.map(func(c): return c["threshold"])


## The claimable missions, chests and weekly rewards (the lobby's red dot); 0 when not loaded.
static func claimable_count(parsed: Variant) -> int:
	if not parsed is Dictionary:
		return 0
	var n := 0
	for key in ["missions", "chests", "weekly"]:
		n += parsed[key].filter(func(e): return e["state"] == CLAIMABLE).size()
	return n


## A mission by id, {} when not there.
static func mission(parsed: Variant, id: String) -> Dictionary:
	if parsed is Dictionary:
		for m in parsed["missions"]:
			if m["id"] == id:
				return m
	return {}


## A chest or weekly reward by id, {} when not there.
static func chest(parsed: Variant, id: String) -> Dictionary:
	if parsed is Dictionary:
		for key in ["chests", "weekly"]:
			for c in parsed[key]:
				if c["id"] == id:
					return c
	return {}


## "Rương 40 năng động" (daily), "Quà tuần 300 năng động" (weekly).
static func chest_title(c: Dictionary) -> String:
	if str(c.get("track", "")) == "weekly":
		return "Quà tuần %d năng động" % int(c.get("threshold", 0))
	return "Rương %d năng động" % int(c.get("threshold", 0))


## The line under a chest's rewards in its popup: "Đã nhận", "Nhận ngay" or "Cần 60 năng động
## (đang có 40)".
static func chest_hint(c: Dictionary, value: int) -> String:
	match str(c.get("state", "")):
		CLAIMED: return "Đã nhận"
		CLAIMABLE: return "Nhận ngay"
	return "Cần %d năng động (đang có %d)" % [int(c.get("threshold", 0)), value]


## The rewards as MilestoneModel.reward_lines, item lines with the item's Vietnamese name
## ("2 × Hộp cứu thương").
static func reward_lines(rewards: Dictionary) -> Array:
	var lines := MilestoneModel.reward_lines(rewards)
	for l in lines:
		if l["kind"] == "item":
			l["text"] = "%d × %s" % [int(l["qty"]), Items.label(str(l["id"]))]
	return lines


## Seconds left until `reset_unix` (never negative; -1 when the reset time is unknown).
static func seconds_left(reset_unix: int, now_unix: int) -> int:
	if reset_unix < 0:
		return -1
	return maxi(0, reset_unix - now_unix)


## "05:12:33" (hours past 24 keep counting: "49:00:00"); "" when unknown.
static func clock(seconds: int) -> String:
	if seconds < 0:
		return ""
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]


## The header's "Làm mới sau 05:12:33"; "" when unknown.
static func day_countdown(reset_unix: int, now_unix: int) -> String:
	var s := seconds_left(reset_unix, now_unix)
	return "Làm mới sau %s" % clock(s) if s >= 0 else ""


## The weekly strip's "Làm mới sau 3 ngày 05:12" (under a day: "Làm mới sau 05:12:33").
static func week_countdown(reset_unix: int, now_unix: int) -> String:
	var s := seconds_left(reset_unix, now_unix)
	if s < 0:
		return ""
	if s < 86400:
		return "Làm mới sau %s" % clock(s)
	return "Làm mới sau %d ngày %02d:%02d" % [s / 86400, (s / 3600) % 24, (s / 60) % 60]
