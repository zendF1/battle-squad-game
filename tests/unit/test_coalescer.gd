extends "res://tests/test_case.gd"

const Coalescer := preload("res://core/coalescer.gd")


func test_single_refresh_applies_its_answer() -> void:
	var g := Coalescer.new()
	check(g.ask(), "first ask starts a fetch")
	var t := g.ticket()
	check(g.finish(t), "answer applied")
	check(not g.running, "idle")
	check(g.ask(), "a later ask starts again")


func test_answer_in_flight_is_dropped_when_a_newer_refresh_was_asked() -> void:
	var g := Coalescer.new()
	check(g.ask(), "fetch 1")
	var t1 := g.ticket()
	check(not g.ask(), "asked during fetch 1: no second fetch in parallel")
	check(not g.ask(), "asked again: still coalesced")
	check(not g.finish(t1), "fetch 1 answer is stale: dropped")
	check(g.running, "still running: fetch again")
	var t2 := g.ticket()
	check(g.finish(t2), "fetch 2 answer is the latest: applied")
	check(not g.running, "idle")


func test_ask_during_refetch_drops_that_answer_too() -> void:
	var g := Coalescer.new()
	g.ask()
	var t1 := g.ticket()
	g.ask()
	check(not g.finish(t1), "dropped")
	var t2 := g.ticket()
	g.ask()
	check(not g.finish(t2), "asked during the refetch: dropped as well")
	check(g.finish(g.ticket()), "third answer applied")
