extends "res://tests/test_case.gd"

const StatDraft := preload("res://screens/home/stat_draft.gd")

const ROW := {"characterId": "tanko", "statPoints": 3, "bonusHp": 2, "bonusDamage": 0, "bonusMobility": 1,
	"bonusDefense": 0, "bonusSkillPower": 0, "bonusTerrainDmg": 4}


func test_reads_current_bonuses() -> void:
	var d := StatDraft.new(ROW)
	eq(d.current, {"hp": 2, "damage": 0, "mobility": 1, "defense": 0, "skillPower": 0, "terrainDamage": 4}, "current")
	eq(d.remaining(), 3, "remaining")
	check(d.has_allocated(), "has allocated")
	check(not StatDraft.new({"characterId": "x", "statPoints": 1}).has_allocated(), "nothing allocated")


func test_pending_cannot_exceed_stat_points() -> void:
	var d := StatDraft.new(ROW)
	check(d.add("hp") and d.add("hp") and d.add("skillPower"), "three adds")
	check(not d.add("damage"), "fourth refused")
	check(not d.can_add("hp"), "no points left")
	eq(d.total_pending(), 3, "total")
	eq(d.remaining(), 0, "remaining")
	check(not d.add("bogus"), "unknown stat")


func test_remove_and_clear() -> void:
	var d := StatDraft.new(ROW)
	check(not d.remove("hp"), "nothing pending to remove")
	d.add("defense")
	check(d.remove("defense"), "removed")
	eq(d.pending("defense"), 0, "back to 0")
	d.add("hp")
	d.add("damage")
	d.clear()
	eq(d.total_pending(), 0, "cleared")
	check(not d.can_submit(), "nothing to submit")


func test_payload_lists_every_stat() -> void:
	var d := StatDraft.new(ROW)
	d.add("hp")
	d.add("terrainDamage")
	d.add("terrainDamage")
	check(d.can_submit(), "can submit")
	eq(d.payload(), {"characterId": "tanko", "hp": 1, "damage": 0, "mobility": 0, "defense": 0, "skillPower": 0, "terrainDamage": 2}, "payload")


func test_no_points_no_submit() -> void:
	var d := StatDraft.new({"characterId": "rookie", "statPoints": 0})
	check(not d.add("hp"), "no points")
	check(not d.can_submit(), "no submit")


func test_rebuild_keeps_draft_of_unchanged_character() -> void:
	var spark := {"characterId": "spark", "statPoints": 2}
	var old := {"tanko": StatDraft.new(ROW), "spark": StatDraft.new(spark)}
	old["tanko"].add("hp")
	old["spark"].add("damage")
	var changed_spark := spark.duplicate()
	changed_spark["statPoints"] = 1
	changed_spark["bonusDamage"] = 1
	var out := StatDraft.rebuild(old, {"tanko": ROW.duplicate(), "spark": changed_spark, "flora": {"characterId": "flora", "statPoints": 4}})
	check(out["tanko"] == old["tanko"] and out["tanko"].pending("hp") == 1, "unchanged server state keeps the pending point")
	check(out["spark"] != old["spark"] and out["spark"].total_pending() == 0 and out["spark"].stat_points == 1, "spent elsewhere: fresh draft")
	check(out["flora"].total_pending() == 0 and out["flora"].stat_points == 4, "new character: fresh draft")
	eq(out.size(), 3, "only the loaded characters")


func test_rebuild_drops_on_bonus_change_or_drop_id() -> void:
	var d := StatDraft.new(ROW)
	d.add("defense")
	var moved := ROW.duplicate()
	moved["bonusHp"] = 1
	moved["bonusDamage"] = 1 # same total, different stats
	check(not d.matches(moved), "bonus change detected")
	check(StatDraft.rebuild({"tanko": d}, {"tanko": moved})["tanko"].total_pending() == 0, "dropped")
	check(d.matches(ROW), "matches its own row")
	check(StatDraft.rebuild({"tanko": d}, {"tanko": ROW}, "tanko")["tanko"].total_pending() == 0, "drop_id starts over even when unchanged")


func test_reset_cost() -> void:
	eq(StatDraft.reset_cost({"characters": [], "resetStatsCost": {"currency": "gem", "amount": 50.0}}), {"currency": "gem", "amount": 50}, "from the response")
	eq(StatDraft.reset_cost({"characters": []}), {"currency": "coin", "amount": 500}, "absent: 500 xu")
	eq(StatDraft.reset_cost({"resetStatsCost": {"currency": "ruby", "amount": 5}}), {"currency": "coin", "amount": 500}, "unknown currency")
	eq(StatDraft.reset_cost(null), {"currency": "coin", "amount": 500}, "no data")
	eq(StatDraft.cost_text({"currency": "coin", "amount": 1500}), "1.500 xu", "coin text")
	eq(StatDraft.cost_text({"currency": "gem", "amount": 50}), "50 kim cương", "gem text")
