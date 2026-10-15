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
