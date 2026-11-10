extends "res://tests/test_case.gd"
## Nhiệm Vụ Ngày chest claims (screens/home/daily_page.gd): a mission reward is fixed, so it arrives
## at once through ui/reward_fly.gd, never the gift-box reward reveal.

const DailyPage := preload("res://screens/home/daily_page.gd")
const RewardFly := preload("res://ui/reward_fly.gd")


func test_claimed_tiles_from_the_answer() -> void:
	var tiles := DailyPage.claimed_tiles({"rewards": {"coin": 500, "gem": 10, "items": [{"kind": "stone", "level": 3, "qty": 2}]}}, {})
	var kinds := tiles.map(func(t): return [t["kind"], int(t["qty"])])
	check(kinds.has(["coin", 500]) and kinds.has(["gem", 10]) and kinds.has(["stone", 2]), "coin, kim cương khoá, stones (%s)" % [kinds])
	var gem: Array = tiles.filter(func(t): return t["kind"] == "gem")
	check(gem[0].get("locked", false), "the gem is kim cương khoá")


func test_claimed_tiles_fall_back_to_the_chest() -> void:
	var chest := {"rewards": {"coin": 200, "gem": 0, "items": []}}
	var tiles := DailyPage.claimed_tiles({"state": {}}, chest)
	eq(tiles.map(func(t): return [t["kind"], int(t["qty"])]), [["coin", 200]], "the chest's own rewards")
	eq(DailyPage.claimed_tiles(null, {}), [], "nothing")


func test_no_reward_reveal() -> void:
	var src := (DailyPage as GDScript).source_code
	check(not src.contains("show_rewards(") and not src.contains("RewardReveal"), "no gift box for a mission reward")
	check(src.contains("RewardFly.play("), "the rewards fly to the wallet / bag")
