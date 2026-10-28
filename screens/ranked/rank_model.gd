extends RefCounted
## Ranked ("Xếp hạng") without UI. The visible rank is the grade (cấp bậc: Binh nhì 3 ... Đại tá
## 1, the generals set at season end) from the season's rank points (điểm hạng); the old tiers
## (bronze..master, from the hidden rating) are never shown (the aiming aid still reads the tier,
## PlayerState.rank_tier()). Here: a grade's name and division ("Binh nhì 3"), the grade and
## division of a number of points (when a field is missing), the progress inside a division, the
## Home chip and popup texts from GET /rank/me, the ranked line of a match result
## (MatchEnded.rewards[me].grade) with its promotion / demotion, the matchmaking timer and the
## tips. Every grade (id, name, divisions, minPoints, win / loss points, general), the division
## size, the ladder's top, the ranked mode and the tips are the game data's (GET /gamedata grades,
## rank, matchmaking.tips).

const Fmt := preload("res://core/fmt.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const UP := 1
const SAME := 0
const DOWN := -1


## The grade ids, lowest first (the generals last).
static func grades() -> Array:
	return GameData.grade_ids()


static func grade_index(grade: String) -> int:
	return grades().find(grade)


## "Binh nhì"; "" for an unknown grade.
static func grade_name(grade: String) -> String:
	return GameData.grade_name(grade)


## A grade shown without a division (one division: the generals).
static func single_division(grade: String) -> bool:
	return GameData.grade_divisions(grade) <= 1


static func is_general(grade: String) -> bool:
	return GameData.grade_general(grade)


## The ranked mode / queue id (MatchStarted mode, MatchEnded rewards).
static func ranked_mode() -> String:
	return GameData.ranked_mode()


## A match (MatchStarted mode, the queue's id) that changes the rank: the game data's ranked flag
## of the lobby mode with that queue (GameData.is_ranked_queue).
static func is_ranked_mode(mode: String) -> bool:
	return GameData.is_ranked_queue(mode)


## A match that came from a queue (ranked or casual): "Chơi tiếp" queues again.
static func is_queue_mode(mode: String) -> bool:
	return GameData.is_lobby_queue(mode)


## "Binh nhì 3"; a grade with one division has none shown ("Thiếu tướng"); "" for an unknown
## grade.
static func label(grade: String, division: int) -> String:
	var n := grade_name(grade)
	if n == "":
		return ""
	if single_division(grade) or division < 1 or division > GameData.grade_divisions(grade):
		return n
	return "%s %d" % [n, division]


## The ladder grades (reached by playing: not the generals), lowest first.
static func _ladder() -> Array:
	return GameData.grade_list().filter(func(g): return not (g.get("general") is bool and g["general"]))


## The grade and division of a number of points, as the server's GradeOf: [grade, division]. The
## last ladder grade whose minPoints ≤ points (the first below every one), division divisions −
## floor((points − minPoints) / divisionPoints), at least 1: points past the ladder top's
## division 1 stay there. ["", 0] without grades.
static func of_points(points: int) -> Array:
	var ladder := _ladder()
	if ladder.is_empty():
		return ["", 0]
	var g: Dictionary = ladder[0]
	for e in ladder:
		if _num(e.get("minPoints"), 0) <= points:
			g = e
	var divisions := maxi(_num(g.get("divisions"), 1), 1)
	var per := GameData.division_points()
	var division := 1
	if per > 0:
		division = clampi(divisions - floori(float(points - _num(g.get("minPoints"), 0)) / per), 1, divisions)
	return [str(g.get("grade", "")), division]


## The first point of a rank [grade, division] (Binh nhì 2: 100); -1 for an unknown grade.
static func division_start(rank: Array) -> int:
	var grade := str(rank[0])
	if grade_index(grade) < 0:
		return -1
	var divisions := maxi(GameData.grade_divisions(grade), 1)
	var division := clampi(int(rank[1]), 1, divisions)
	return GameData.grade_min_points(grade) + (divisions - division) * GameData.division_points()


## Past the ladder: at the ladder top's last division (Đại tá 1) or a general; the points keep
## counting there with no bar to fill.
static func at_top(rank: Array) -> bool:
	var grade := str(rank[0])
	if is_general(grade):
		return true
	return grade != "" and grade == GameData.ladder_top() and int(rank[1]) <= 1


## How far into its division `points` are, 0..1 (the division's bar); 1 at the top.
static func progress(points: int, rank: Array) -> float:
	if at_top(rank):
		return 1.0
	var start := division_start(rank)
	var per := GameData.division_points()
	if start < 0 or per <= 0:
		return 0.0
	return clampf(float(points - start) / per, 0.0, 1.0)


## "45/100" in the division; "" at the top (the points line says the total).
static func progress_text(points: int, rank: Array) -> String:
	if at_top(rank):
		return ""
	var start := division_start(rank)
	var per := GameData.division_points()
	if start < 0 or per <= 0:
		return ""
	return "%s/%s" % [Fmt.thousands(clampi(points - start, 0, per)), Fmt.thousands(per)]


## UP when b is a higher rank than a (grade first, then division: 1 is the highest), DOWN when
## lower, SAME otherwise. Ranks are [grade, division].
static func compare(a: Array, b: Array) -> int:
	var ga := grade_index(str(a[0]))
	var gb := grade_index(str(b[0]))
	if ga != gb:
		return UP if gb > ga else DOWN
	if single_division(str(a[0])):
		return SAME
	var da := int(a[1])
	var db := int(b[1])
	if da == db:
		return SAME
	return UP if db < da else DOWN


static func _num(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float else fallback


static func _str(v: Variant) -> String:
	return str(v) if v is String else ""


## A rank [grade, division] from a dictionary's grade / division fields, else from `points`.
static func _rank_of(d: Dictionary, grade_key: String, div_key: String, points: int) -> Array:
	var grade := _str(d.get(grade_key))
	var fallback := of_points(points)
	if grade_index(grade) < 0:
		return fallback
	var divisions := maxi(GameData.grade_divisions(grade), 1)
	var div := _num(d.get(div_key), 0)
	if div < 1 or div > divisions:
		div = fallback[1] if grade == fallback[0] else divisions
	return [grade, div]


## A rank from a GET /rank/me data: {rankPoints, grade, gradeDivision, generalCandidate,
## rankBadge, wins, losses, draws, rankPos, season: {name, endsAt}} (0 points = Binh nhì 3 for
## missing parts) → {points, grade, division, candidate, badge, wins, losses, draws, rankPos,
## season: {name, endsAt}}.
static func from_me(data: Variant) -> Dictionary:
	var d: Dictionary = data if data is Dictionary else {}
	var points := maxi(_num(d.get("rankPoints"), 0), 0)
	var rank := _rank_of(d, "grade", "gradeDivision", points)
	var candidate := _str(d.get("generalCandidate"))
	var season: Dictionary = d["season"] if d.get("season") is Dictionary else {}
	return {"points": points, "grade": rank[0], "division": rank[1],
		"candidate": candidate if grade_index(candidate) >= 0 else "", "badge": badge_of(d),
		"wins": _num(d.get("wins"), 0), "losses": _num(d.get("losses"), 0), "draws": _num(d.get("draws"), 0),
		"rankPos": _num(d.get("rankPos"), 0),
		"season": {"name": _str(season.get("name")), "endsAt": _str(season.get("endsAt"))}}


## A payload's rankBadge (the final grade of last season: the frame and the badge), "" none or an
## unknown grade.
static func badge_of(d: Variant) -> String:
	if not d is Dictionary:
		return ""
	var b := _str(d.get("rankBadge"))
	return b if grade_index(b) >= 0 else ""


## "1.050 điểm".
static func points_text(points: int) -> String:
	return "%s điểm" % Fmt.thousands(points)


## The rank's line: "Binh nhì 2 · 45/100" inside the ladder, "Đại tá 1 · 4.230 điểm" at its top.
static func rank_line(rank: Dictionary) -> String:
	var r: Array = [rank["grade"], rank["division"]]
	var l := label(r[0], r[1])
	if at_top(r):
		return "%s · %s" % [l, points_text(int(rank["points"]))]
	var p := progress_text(int(rank["points"]), r)
	return "%s · %s" % [l, p] if p != "" else l


## The mode card's line, as rank_line().
static func mode_line(rank: Dictionary) -> String:
	return rank_line(rank)


## "Dự kiến: Thiếu tướng" for a general candidate (the grade the player would get if the season
## ended now), "" none.
static func candidate_text(candidate: String) -> String:
	var n := grade_name(candidate)
	return "Dự kiến: %s" % n if n != "" else ""


## "Hạng #12" in the season's leaderboard, "Chưa có thứ hạng" without a position.
static func position_text(pos: int) -> String:
	return "Hạng #%s" % Fmt.thousands(pos) if pos > 0 else "Chưa có thứ hạng"


## "Thắng 12 · Thua 8" (" · Hoà 1" when there are draws).
static func record_text(rank: Dictionary) -> String:
	var out := "Thắng %d · Thua %d" % [rank["wins"], rank["losses"]]
	if int(rank["draws"]) > 0:
		out += " · Hoà %d" % rank["draws"]
	return out


## "Mùa 1 · Kết thúc 30/11" (the date in the zone bias_minutes east of UTC); the name alone
## without an end date, "Mùa giải hiện tại" without a name.
static func season_text(rank: Dictionary, bias_minutes: int) -> String:
	var season: Dictionary = rank["season"]
	var season_name: String = season["name"] if season["name"] != "" else "Mùa giải hiện tại"
	var date := Fmt.short_date(season["endsAt"], bias_minutes)
	if date == "":
		return season_name
	return "%s · Kết thúc %s" % [season_name, date.substr(0, 5)]


## The ranked part of a match result for a reward (MatchEnded.rewards[me]) of a match in `mode`;
## {} when the match is not ranked or the reward carries no grade block. Else {old, new, change
## (the points), old_rank: [grade, division], new_rank, move: UP / SAME / DOWN}; a missing old
## count is newPoints - pointsChange, missing grades come from the points.
static func result_of(mode: String, reward: Variant) -> Dictionary:
	if not is_ranked_mode(mode) or not reward is Dictionary or not reward.get("grade") is Dictionary:
		return {}
	var g: Dictionary = reward["grade"]
	var new_points = g.get("newPoints")
	if not (new_points is int or new_points is float):
		return {}
	var np := int(new_points)
	var old := _num(g.get("oldPoints"), np - _num(g.get("pointsChange"), 0))
	var change := _num(g.get("pointsChange"), np - old)
	var new_rank := _rank_of(g, "newGrade", "newGradeDivision", np)
	var old_rank := _rank_of(g, "oldGrade", "oldGradeDivision", old)
	return {"old": old, "new": np, "change": change, "old_rank": old_rank, "new_rank": new_rank,
		"move": compare(old_rank, new_rank)}


## +30 → "+30", -15 → "-15", 0 → "±0".
static func change_text(change: int) -> String:
	return "±0" if change == 0 else Fmt.signed(change)


## "+30 điểm hạng", "-15 điểm hạng", "±0 điểm hạng".
static func points_change_text(change: int) -> String:
	return "%s điểm hạng" % change_text(change)


## "Điểm hạng 120 → 150"; at `shown` (the count-up's current value) instead of the new count while
## it counts.
static func points_line(result: Dictionary, shown: int = -1) -> String:
	var value: int = result["new"] if shown < 0 else shown
	return "Điểm hạng %s → %s" % [Fmt.thousands(result["old"]), Fmt.thousands(value)]


## "Thăng cấp!" / "Hạ cấp" / "" for the result's move.
static func move_text(move: int) -> String:
	match move:
		UP: return "Thăng cấp!"
		DOWN: return "Hạ cấp"
	return ""


## The rank one division above [grade, division] (the next grade's lowest division after a
## grade's highest); [] at the ladder top (the generals are never reached by playing).
static func next_rank(rank: Array) -> Array:
	var g := str(rank[0])
	var d := int(rank[1])
	if not single_division(g) and d > 1:
		return [g, d - 1]
	var i := grade_index(g)
	if i < 0 or i + 1 >= grades().size():
		return []
	var up: String = grades()[i + 1]
	if is_general(up) and not is_general(g):
		return []
	return [up, maxi(GameData.grade_divisions(up), 1)]


## The rank one division below [grade, division] (the lower grade's highest division under a
## grade's lowest); [] at the bottom.
static func prev_rank(rank: Array) -> Array:
	var g := str(rank[0])
	var d := int(rank[1])
	if not single_division(g) and d < GameData.grade_divisions(g):
		return [g, d + 1]
	var i := grade_index(g)
	if i <= 0:
		return []
	return [grades()[i - 1], 1]


## The rank popup of a match result (result_of()): {} when the rank did not move (only the points
## did: the rewards card's line says it). Else {move, kind ("division": a division up inside a
## grade, "grade": up into a higher grade, "down": a demotion), old_rank, new_rank, old, new,
## change (the points), steps (every rank passed on the way, [grade, division], the new one last),
## crown (up into the ladder top's division 1), title, label (the new rank's)}.
static func popup_of(result: Dictionary) -> Dictionary:
	if result.is_empty() or int(result.get("move", SAME)) == SAME:
		return {}
	var old_rank: Array = result["old_rank"]
	var new_rank: Array = result["new_rank"]
	if grade_index(str(old_rank[0])) < 0 or grade_index(str(new_rank[0])) < 0:
		return {}
	var move := int(result["move"])
	var steps: Array = []
	var at := old_rank
	while compare(at, new_rank) == move and steps.size() < 64:
		at = next_rank(at) if move == UP else prev_rank(at)
		if at.is_empty():
			break
		steps.append(at)
	if steps.is_empty():
		steps.append(new_rank)
	steps[-1] = new_rank
	var kind := "down"
	if move == UP:
		kind = "grade" if str(old_rank[0]) != str(new_rank[0]) else "division"
	return {"move": move, "kind": kind, "old_rank": old_rank, "new_rank": new_rank, "old": result["old"],
		"new": result["new"], "change": result["change"], "steps": steps, "crown": move == UP and at_top(new_rank),
		"title": "THĂNG CẤP!" if move == UP else "HẠ CẤP", "label": label(str(new_rank[0]), int(new_rank[1]))}


## Matchmaking elapsed time: 31 → "0:31", 65 → "1:05", 600 → "10:00".
static func timer_text(seconds: int) -> String:
	var s := maxi(seconds, 0)
	return "%d:%02d" % [s / 60, s % 60]


## The tip at `index`, wrapping around.
static func tip(index: int) -> String:
	var all := tips()
	return str(all[posmod(index, all.size())]) if not all.is_empty() else ""


## The tips shown while searching (matchmaking.tips), in order.
static func tips() -> Array:
	return GameData.tips()
