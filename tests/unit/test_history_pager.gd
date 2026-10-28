extends "res://tests/test_case.gd"

const HistoryPager := preload("res://screens/home/history_pager.gd")
const MapCatalog := preload("res://match/theme/map_catalog.gd")


static func _page(from: int, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"matchId": "m%d" % (from + i), "result": "win"})
	return out


func test_pages_until_short_page() -> void:
	var p := HistoryPager.new(2)
	eq(p.begin(), "/player/match-history?page=1&limit=2", "first page")
	eq(p.begin(), "", "one request at a time")
	eq(p.finish({"ok": true, "data": _page(0, 2)}), 2, "added")
	check(p.can_load(), "full page: more")
	eq(p.begin(), "/player/match-history?page=2&limit=2", "second page")
	p.finish({"ok": true, "data": _page(2, 1)})
	check(p.done, "short page ends")
	eq(p.begin(), "", "nothing after the end")
	eq(p.rows.size(), 3, "rows")


func test_failed_page_is_retried() -> void:
	var p := HistoryPager.new(20)
	p.begin()
	p.finish({"ok": false, "status": 0, "message": "network error"}, "Không kết nối được server")
	eq(p.error, "Không kết nối được server", "error kept")
	check(not p.loading and not p.done, "can retry")
	eq(p.begin(), "/player/match-history?page=1&limit=20", "same page")
	eq(p.error, "", "error cleared on retry")


func test_null_page_and_duplicates() -> void:
	var p := HistoryPager.new(2)
	p.begin()
	p.finish({"ok": true, "data": _page(0, 2)})
	p.begin()
	eq(p.finish({"ok": true, "data": [{"matchId": "m1"}, {"matchId": "m9"}]}), 1, "shifted row skipped")
	p.begin()
	p.finish({"ok": true, "data": null})
	check(p.done, "null page is empty")
	eq(p.rows.size(), 3, "rows")
	p.reset()
	eq(p.rows.size(), 0, "reset")
	eq(p.begin(), "/player/match-history?page=1&limit=2", "from the start")


func test_row_text() -> void:
	var t := HistoryPager.row_text({"matchId": "m", "mode": "pvp_1v1", "mapId": "desert", "result": "loss",
		"expGained": 40, "coinGained": 1250, "ratingChange": -12, "playedAt": "2026-10-15T08:05:00Z"}, 420)
	eq(t["result"], "Thua", "result")
	eq(t["tone"], "loss", "tone")
	eq(t["mode"], "Đấu 1v1", "mode")
	eq(t["map"], "desert", "map")
	eq(t["exp"], "+40 EXP", "exp")
	eq(t["coin"], "+1.250 xu", "coin")
	eq(t["points"], "", "not ranked: no points, never the hidden rating")
	var ranked := HistoryPager.row_text({"matchId": "r", "mode": "ranked_2v2", "result": "win", "ratingChange": 14, "rankPointsChange": 30}, 0)
	eq([ranked["points"], ranked["points_change"]], ["+30 điểm hạng", 30], "a ranked win's rank points")
	eq(HistoryPager.row_text({"mode": "ranked_2v2", "result": "loss", "rankPointsChange": -15}, 0)["points"], "-15 điểm hạng", "a loss")
	eq(HistoryPager.row_text({"mode": "ranked_2v2", "result": "draw"}, 0)["points"], "±0 điểm hạng", "a draw (0 or absent)")
	check(not ranked.has("rating"), "the hidden rating is gone")
	eq(t["date"], "15/10 15:05", "local date (UTC+7)")
	eq(HistoryPager.row_text({"result": "draw", "mode": "custom_x"}, 0)["result"], "Hoà", "draw")
	eq(HistoryPager.row_text({"result": "win", "mode": "custom_x", "ratingChange": 8}, 0)["mode"], "custom_x", "unknown mode raw")


func test_mode_and_map_labels() -> void:
	MapCatalog.reset("") # names from GET /maps, no cache file
	MapCatalog.take(MapCatalog.parse([{"mapId": "grassland_valley", "name": "Thung lũng cỏ", "theme": "grassland"}]), false)
	var t := HistoryPager.row_text({"mode": "pvp_2v2", "mapId": "grassland_valley", "result": "win"}, 0)
	eq(t["mode"], "Đấu 2v2", "pvp_2v2")
	eq(t["map"], "Thung lũng cỏ", "grassland_valley")
	eq(HistoryPager.row_text({"mapId": "lava_pit"}, 0)["map"], "lava_pit", "unknown map raw")
	MapCatalog.reset("")
	eq(HistoryPager.row_text({"mapId": "grassland_valley"}, 0)["map"], "grassland_valley", "no catalog yet: raw id")
