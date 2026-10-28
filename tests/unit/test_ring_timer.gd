extends "res://tests/test_case.gd"
## screens/ranked/ring_timer.gd: the matchmaking timer ring (fills with the wait, one lap per
## LAP_SEC, empty again after each lap; full and bursting once the match is found).

const RingTimer := preload("res://screens/ranked/ring_timer.gd")


func test_fills_with_the_time_waited() -> void:
	var r := RingTimer.new()
	eq(r.fill(), 0.0, "empty at the start")
	r.tick(10.0)
	near(r.fill(), 10.0 / RingTimer.LAP_SEC, 0.0001, "a third after 10 s")
	r.tick(5.0)
	near(r.fill(), 0.5, 0.0001, "half after 15 s")
	eq(r.seconds(), 15, "the seconds waited")
	r.tick(3.0, false)
	near(r.fill(), 0.5, 0.0001, "not searching (in the queue's start): no fill")


func test_starts_again_after_each_lap() -> void:
	eq(RingTimer.LAP_SEC, 30.0, "30 s per lap")
	near(RingTimer.lap_fill(29.9), 29.9 / 30.0, 0.0001, "nearly full at the end of the lap")
	eq(RingTimer.lap_fill(30.0), 0.0, "empty again at 30 s")
	near(RingTimer.lap_fill(45.0), 0.5, 0.0001, "half way through the second lap")
	eq(RingTimer.lap_fill(90.0), 0.0, "every lap")
	eq(RingTimer.lap_fill(-3.0), 0.0, "never before the start")
	var r := RingTimer.new()
	r.tick(31.0)
	near(r.fill(), 1.0 / 30.0, 0.0001, "the ring after 31 s")
	eq(r.seconds(), 31, "the seconds keep counting")


func test_runs_to_full_on_found_then_bursts() -> void:
	var r := RingTimer.new()
	r.tick(12.0)
	check(not r.is_found() and r.burst() == 0.0 and not r.bursting(), "no burst while searching")
	r.find()
	check(r.is_found(), "found")
	near(r.fill(), 0.4, 0.0001, "from where it was")
	r.tick(RingTimer.FILL_SEC * 0.5)
	check(r.fill() > 0.4 and r.fill() < 1.0, "on its way to full")
	eq(r.burst(), 0.0, "no burst before full")
	eq(r.seconds(), 12, "the timer stops at the find")
	r.tick(RingTimer.FILL_SEC * 0.5)
	eq(r.fill(), 1.0, "full after FILL_SEC")
	r.tick(RingTimer.BURST_SEC * 0.5)
	near(r.burst(), 0.5, 0.0001, "the burst half way")
	check(r.bursting(), "drawn while it plays")
	r.tick(RingTimer.BURST_SEC)
	eq(r.burst(), 1.0, "over")
	check(not r.bursting(), "no longer drawn")
	eq(r.fill(), 1.0, "stays full")


func test_found_late_in_a_lap_and_found_twice() -> void:
	var r := RingTimer.new()
	r.tick(59.0)
	r.find()
	near(r.fill(), 29.0 / 30.0, 0.0001, "found at the end of the second lap")
	r.tick(0.1)
	r.find() # a second MatchFound changes nothing
	r.tick(RingTimer.FILL_SEC)
	eq(r.fill(), 1.0, "full")
	var fresh := RingTimer.new()
	fresh.find()
	fresh.tick(RingTimer.FILL_SEC)
	eq(fresh.fill(), 1.0, "found at once: full too")
