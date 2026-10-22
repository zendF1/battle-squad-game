extends RefCounted
## GET /player/match-history?page&limit paging for "Lịch sử": pages are 1-based, newest first,
## and a page shorter than `limit` is the last one. One request at a time; a failed page is
## retried with the same number. Rows already shown are skipped (a match finished between two
## requests shifts the offsets).

const Fmt := preload("res://core/fmt.gd")
const MapCatalog := preload("res://match/theme/map_catalog.gd") # map names from GET /maps; unknown ids raw

const RESULTS := {
	"win": {"text": "Thắng", "tone": "win"},
	"loss": {"text": "Thua", "tone": "loss"},
	"draw": {"text": "Hoà", "tone": "draw"},
}
const GameData := preload("res://autoload/game_data_model.gd") # match mode names (modes.match)

var limit: int
var rows: Array = []
var next_page := 1
var loading := false
var done := false
var error := ""
var _seen := {}


func _init(page_limit: int = 20) -> void:
	limit = page_limit


func can_load() -> bool:
	return not loading and not done


## The path for the next page, marking it in flight; "" when nothing should be requested.
func begin() -> String:
	if not can_load():
		return ""
	loading = true
	error = ""
	return "/player/match-history?page=%d&limit=%d" % [next_page, limit]


## Takes the Api result for the page begin() asked for. Returns the number of rows added.
func finish(res: Dictionary, error_text: String = "") -> int:
	loading = false
	if not res.get("ok", false):
		error = error_text if error_text != "" else str(res.get("message", ""))
		return 0
	var data = res.get("data")
	var page: Array = data if data is Array else [] # an empty page is null
	var added := 0
	for e in page:
		if not e is Dictionary:
			continue
		var id := str(e.get("matchId", ""))
		if id != "":
			if _seen.has(id):
				continue
			_seen[id] = true
		rows.append(e)
		added += 1
	next_page += 1
	if page.size() < limit:
		done = true
	return added


func reset() -> void:
	rows.clear()
	_seen.clear()
	next_page = 1
	loading = false
	done = false
	error = ""


## A history entry as row texts: {result, tone (win|loss|draw), mode, map, exp, coin, rating, date}.
static func row_text(e: Dictionary, bias_minutes: int) -> Dictionary:
	var r: Dictionary = RESULTS.get(str(e.get("result", "")), {"text": str(e.get("result", "?")), "tone": "draw"})
	var mode := str(e.get("mode", ""))
	return {
		"result": r["text"],
		"tone": r["tone"],
		"mode": GameData.match_mode_name(mode),
		"map": MapCatalog.name_of(str(e.get("mapId", ""))),
		"exp": "+%d EXP" % int(e.get("expGained", 0)),
		"coin": "+%s xu" % Fmt.thousands(int(e.get("coinGained", 0))),
		"rating": Fmt.signed(int(e.get("ratingChange", 0))),
		"date": Fmt.short_date(str(e.get("playedAt", "")), bias_minutes),
	}
