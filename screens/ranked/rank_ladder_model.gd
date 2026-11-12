extends RefCounted
## The rank ladder page (rank_ladder.gd) without UI: one column per grade of the game data, lowest
## first (the ladder grades, then the generals): its insignia, the pill on the shared track (a
## ladder grade's minPoints, a general's season leaderboard positions "#1", "#2–3"), its win / loss
## points and the tiles of what it gives as a season's final grade (seasonRewards: one reward for
## where the season ends, not cumulative). Where the player stands (GET /rank/me through
## RankModel.from_me()): the current grade's column, the column whose reward the season would give
## now (a general candidate's, else the current grade's), how far the track is filled (a position
## in column units: 2.5 is half way from the third pill to the fourth), the division's pips and the
## season's time left. Every number is the game data's or the server's.

const GameData := preload("res://autoload/game_data_model.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const Fmt := preload("res://core/fmt.gd")

const EN_DASH := "–"


static func _num(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


## The columns, lowest grade first: [{grade, name, general, min_points, win, loss, from_pos,
## to_pos (a general's leaderboard positions, 0 for a ladder grade), tiles (RewardModel tiles of
## its season reward, [] none)}].
static func columns() -> Array:
	var positions := {}
	for g in GameData.grade_generals():
		if g is Dictionary:
			positions[str(g.get("grade", ""))] = [_num(g.get("fromPos")), _num(g.get("toPos"))]
	var out: Array = []
	for g in GameData.grade_list():
		if not g is Dictionary or str(g.get("grade", "")) == "":
			continue
		var id := str(g["grade"])
		var general: bool = g.get("general") is bool and g["general"]
		var pos: Array = positions.get(id, [0, 0]) if general else [0, 0]
		var sr := GameData.season_reward(id)
		out.append({"grade": id, "name": str(g.get("name", "")), "general": general,
			"min_points": _num(g.get("minPoints")), "win": _num(g.get("winPoints")), "loss": _num(g.get("lossPoints")),
			"from_pos": pos[0], "to_pos": pos[1], "tiles": RewardModel.from_season(sr) if not sr.is_empty() else []})
	return out


## "#1", "#2–3", "#7–10": a general's leaderboard positions; "" unknown.
static func positions_text(from_pos: int, to_pos: int) -> String:
	if from_pos <= 0:
		return ""
	if to_pos <= from_pos:
		return "#%d" % from_pos
	return "#%d%s%d" % [from_pos, EN_DASH, to_pos]


## A column's pill: a ladder grade's points to reach it ("1.200"), a general's positions ("#2–3").
static func pill_text(col: Dictionary) -> String:
	if col.get("general", false):
		return positions_text(int(col.get("from_pos", 0)), int(col.get("to_pos", 0)))
	return Fmt.thousands(int(col.get("min_points", 0)))


static func index_of(cols: Array, grade: String) -> int:
	for i in cols.size():
		if str(cols[i]["grade"]) == grade:
			return i
	return -1


## The player's grade's column (RankModel.from_me() of /rank/me); -1 before the rank loads.
static func current_index(cols: Array, rank: Dictionary) -> int:
	if rank.is_empty():
		return -1
	return index_of(cols, str(rank.get("grade", "")))


## The column whose reward the season would give if it ended now: a general candidate's, else the
## current grade's; -1 before the rank loads.
static func reward_index(cols: Array, rank: Dictionary) -> int:
	if rank.is_empty():
		return -1
	var candidate := index_of(cols, str(rank.get("candidate", "")))
	return candidate if candidate >= 0 else current_index(cols, rank)


## How far the track is filled, in column units (the pill of column i sits at i): between the two
## ladder pills the points fall between, in proportion (Binh nhất 300 → Hạ sĩ 600: 450 points is
## 1.5); at the ladder's last grade the fill stops on its pill (the generals are given by
## leaderboard position, never by points); a general fills up to its own pill. -1 before the rank
## loads (no fill).
static func fill(cols: Array, rank: Dictionary) -> float:
	var at := current_index(cols, rank)
	if at < 0:
		return -1.0
	if cols[at]["general"]:
		return float(at)
	var points := int(rank.get("points", 0))
	var last := -1
	for i in cols.size():
		if cols[i]["general"]:
			break
		if int(cols[i]["min_points"]) <= points:
			last = i
	if last < 0:
		return 0.0
	if last + 1 >= cols.size() or cols[last + 1]["general"]:
		return float(last)
	var from := int(cols[last]["min_points"])
	var span := int(cols[last + 1]["min_points"]) - from
	if span <= 0:
		return float(last)
	return last + clampf(float(points - from) / span, 0.0, 1.0)


## A pill is reached (lit) when the fill got to it.
static func reached(index: int, fill_at: float) -> bool:
	return fill_at >= 0.0 and index <= fill_at + 0.0001


## The division's pips under the current insignia: [lit, total] (Binh nhì 3: [1, 3], Binh nhì 1:
## [3, 3]); [0, 0] for a grade without divisions or before the rank loads.
static func pips(rank: Dictionary) -> Array:
	if rank.is_empty():
		return [0, 0]
	var grade := str(rank.get("grade", ""))
	var total := GameData.grade_divisions(grade)
	if total <= 1:
		return [0, 0]
	var division := clampi(int(rank.get("division", total)), 1, total)
	return [total - division + 1, total]


## "Còn 18 ngày 4 giờ", "Còn 5 giờ 12 phút", "Còn 9 phút"; "Đã kết thúc" at 0; "" unknown (-1).
static func left_text(seconds: int) -> String:
	if seconds < 0:
		return ""
	if seconds == 0:
		return "Đã kết thúc"
	if seconds >= 86400:
		return "Còn %d ngày %d giờ" % [seconds / 86400, (seconds / 3600) % 24]
	if seconds >= 3600:
		return "Còn %d giờ %d phút" % [seconds / 3600, (seconds / 60) % 60]
	return "Còn %d phút" % maxi(1, ceili(seconds / 60.0))


## The bottom bar's season line: "Mùa 1 · Còn 18 ngày 4 giờ"; the name alone without an end time,
## "" without a name (the time alone then).
static func season_line(rank: Dictionary, now_unix: int) -> String:
	var season: Dictionary = rank.get("season", {}) if rank.get("season") is Dictionary else {}
	var season_name := str(season.get("name", ""))
	var ends := Fmt.unix_time(str(season.get("endsAt", "")))
	var left := left_text(maxi(0, ends - now_unix) if ends >= 0 else -1)
	if season_name == "":
		return left
	return "%s · %s" % [season_name, left] if left != "" else season_name


## The row's scroll that puts column `index` dead centre (the row is padded so every column can
## sit there), clamped to the row.
static func centre_scroll(index: int, count: int, col_w: float) -> float:
	return clampf(index * col_w, 0.0, maxf(count - 1, 0) * col_w)
