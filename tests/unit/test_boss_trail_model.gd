extends "res://tests/test_case.gd"
## ui/boss_trail_model.gd and ui/boss_trail.gd: a boss's bonus runs of the day from the server's
## counts: rules 1 has none, the server alone says whether the gold can still be earned.

const BossFixture := preload("res://tests/boss_fixture.gd")
const T := preload("res://ui/boss_trail_model.gd")
const BossTrail := preload("res://ui/boss_trail.gd")
const Fmt := preload("res://core/fmt.gd")


static func row(done: int, wins: int, eligible: bool, granted: bool, extra: Dictionary = {}) -> Dictionary:
	var r := {"bossId": "steel_robot", "rewardVersion": 2, "bonusRunsCompleted": done, "bonusWins": wins, "perfectRequiredWins": 3,
		"perfectRewardEligible": eligible, "perfectRewardGranted": granted}
	r.merge(extra, true)
	return r


func test_every_day_of_three_runs() -> void:
	BossFixture.take()
	eq(T.of(row(0, 0, true, false))["pips"], ["open", "open", "open"], "a new day")
	eq(T.of(row(1, 1, true, false))["pips"], ["win", "open", "open"], "one win")
	eq(T.of(row(2, 1, false, false))["pips"], ["win", "loss", "open"], "a win and a loss: the wins first")
	eq(T.of(row(3, 0, false, false))["pips"], ["loss", "loss", "loss"], "three losses")
	eq(T.of(row(3, 2, false, false))["pips"], ["win", "win", "loss"], "two wins and a loss")
	eq(T.of(row(3, 3, false, true))["pips"], ["win", "win", "win"], "three wins")


func test_gold_state_is_the_servers() -> void:
	BossFixture.take()
	eq(T.of(row(0, 0, true, false))["gold"], T.GOAL, "eligible")
	eq(T.of(row(1, 1, false, false))["gold"], T.LOST, "an abandon: one win, yet the server took it away")
	eq(T.of(row(3, 3, false, true))["gold"], T.WON, "granted")
	eq(T.of(row(3, 3, true, false))["gold"], T.GOAL, "three wins but not granted: never claimed by the client")


func test_abandon_is_not_a_pip() -> void:
	BossFixture.take()
	var t := T.of(row(1, 1, false, false))
	eq(t["pips"], ["win", "open", "open"], "the abandoned run is not counted")
	eq([t["wins"], t["done"]], [1, 1], "the counts")


func test_rules_1_has_no_trail() -> void:
	BossFixture.take()
	eq(T.of(row(1, 1, true, false, {"rewardVersion": 1})), {}, "rules 1")
	eq(T.of({"bossId": "steel_robot", "bonusRunsLeft": 2}), {}, "no rewardVersion")
	eq(T.of(row(1, 1, true, false, {"rewardVersion": 0})), {}, "0 reads as 1")
	eq(T.of(null), {}, "not loaded")
	eq(T.version_of({"rewardVersion": 2.0}), 2, "a JSON number")
	eq(T.version_of({}), 1, "missing")


func test_counts_are_clamped() -> void:
	BossFixture.take()
	eq(T.of(row(9, 9, false, true))["pips"], ["win", "win", "win"], "never more pips than wins needed")
	eq(T.of(row(0, 2, true, false))["pips"], ["win", "win", "open"], "wins never exceed the runs")


func test_pips_fall_back_on_the_game_data() -> void:
	BossFixture.take()
	var r := row(1, 1, true, false)
	r.erase("perfectRequiredWins")
	eq(T.of(r)["pips"].size(), 3, "the boss's perfect.requiredWins")


func test_rules_from_the_game_data() -> void:
	BossFixture.take()
	var r := T.rules("steel_robot")
	eq(r["win"], [{"chestId": "stone_chest_silver", "qty": 1}], "a win")
	eq(r["loss"], [{"chestId": "stone_chest_bronze", "qty": 1}], "a loss")
	eq(r["perfect"], [{"chestId": "stone_chest_gold", "qty": 1}], "the gold")
	eq(r["required"], 3, "wins")
	eq(T.rules("nobody"), {}, "unknown boss")
	eq(T.gold_chest("nobody"), T.GOLD_CHEST, "the picture still draws")


func test_reset_in_msec() -> void:
	var runs := {"resetAt": "2026-11-20T17:00:00Z"}
	var reset := Fmt.unix_time("2026-11-20T17:00:00Z")
	eq(T.reset_in_msec(runs, reset - 5), 5000, "before the reset")
	eq(T.reset_in_msec(runs, reset), -1, "a clock past it never marks a fresh answer expired")
	eq(T.reset_in_msec({}, reset), -1, "no resetAt")
	eq(T.reset_in_msec(null, reset), -1, "no answer")


func test_runs_are_not_kept_past_the_reset() -> void:
	PlayerState.boss_runs = {"resetAt": "2099-01-01T17:00:00Z", "bosses": []}
	PlayerState._boss_runs_player = Session.player_id
	PlayerState._boss_runs_until_msec = Time.get_ticks_msec() + 60000
	check(not PlayerState.my_boss_runs().is_empty(), "before the reset")
	PlayerState._boss_runs_until_msec = Time.get_ticks_msec() - 1
	eq(PlayerState.my_boss_runs(), {}, "past the reset: not shown")
	PlayerState._boss_runs_until_msec = -1
	check(not PlayerState.my_boss_runs().is_empty(), "the reset unknown: the age limit reloads it")
	PlayerState.boss_runs = {}


func test_trail_widget() -> void:
	BossFixture.take()
	var t: HBoxContainer = BossTrail.make(T.of(row(2, 1, false, false)), 30, 40)
	eq(t.pips.map(func(p): return p.get_meta("state")), ["win", "loss", "open"], "a pip per run")
	eq(t.chest.get_meta("state"), T.LOST, "the chest")
	check(t.chest.find_child("Glow", true, false) == null, "no glow on a lost chest")
	check((t.chest.get_node("Chest") as CanvasItem).material != null, "drawn grey")
	check(t.find_children("*", "Label", true, false).is_empty(), "no words, no numbers")
	t.free()
	var won: HBoxContainer = BossTrail.make(T.of(row(3, 3, false, true)), 30, 40)
	check(won.chest.find_child("Earned", true, false) != null, "the check on the earned chest")
	check(won.chest.find_child("Glow", true, false) != null, "glowing")
	won.free()
	var goal: HBoxContainer = BossTrail.make(T.of(row(1, 1, true, false)), 30, 40)
	check((goal.chest.get_node("Chest") as CanvasItem).material == null, "the goal in colour")
	check(goal.chest.find_child("Earned", true, false) == null, "not earned yet")
	goal.free()
