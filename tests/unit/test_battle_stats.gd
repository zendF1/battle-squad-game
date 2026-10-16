extends "res://tests/test_case.gd"

const BattleStats := preload("res://screens/home/battle_stats.gd")

# Shaped like the server's GET /player/characters (JSON numbers parse as floats).
const STATS := {
	"maxHp": 1330.0, "defense": 90.0, "damageBonus": 55.0, "moveEnergy": 106.0, "skillPowerBonus": 10.0,
	"terrainDamageBonus": 0.0, "critChance": 2.25, "weaponDamage": 75.0,
	"base": {"maxHp": 130.0, "defense": 80.0, "damageBonus": 0.0, "moveEnergy": 100.0, "skillPowerBonus": 0.0, "terrainDamageBonus": 0.0},
	"fromPoints": {"maxHp": 100.0, "defense": 0.0, "damageBonus": 0.0, "moveEnergy": 3.0, "skillPowerBonus": 10.0, "terrainDamageBonus": 0.0},
	"fromEquipment": {"maxHp": 1100.0, "defense": 10.0, "damageBonus": 55.0, "moveEnergy": 3.0, "skillPowerBonus": 0.0, "terrainDamageBonus": 0.0, "critChance": 2.25},
	# Equipment adds points; fromEquipment is them × statMultipliers (crit is a percent).
	"equipmentPoints": {"hp": 22.0, "damage": 11.0, "defense": 2.0, "mobility": 1.0, "crit": 2.25},
}
const MULT := {"hp": 50.0, "damage": 5.0, "mobility": 3.0, "defense": 5.0, "skillPower": 5.0, "terrainDamage": 3.0}


func _by_key(rows: Array) -> Dictionary:
	var out := {}
	for r in rows:
		out[r["key"]] = r
	return out


func test_rows_values_and_breakdown() -> void:
	var rows := BattleStats.rows(STATS)
	eq(rows.map(func(r): return r["label"]), ["Máu", "Phòng thủ", "Sát thương", "Năng lượng di chuyển", "Sức mạnh kỹ năng", "Phá địa hình"], "order")
	var r := _by_key(rows)
	eq(r["maxHp"]["value"], "1.330", "hp total, thousands separator")
	eq(r["maxHp"]["detail"], "(gốc 130, điểm +100, trang bị +1.100 từ 22 điểm)", "hp breakdown with the equipment points")
	eq(r["defense"]["detail"], "(gốc 80, trang bị +10 từ 2 điểm)", "zero parts left out")
	eq(r["damageBonus"]["value"], "+55", "damage is a flat bonus")
	eq(r["damageBonus"]["detail"], "(vũ khí 75, trang bị +55 từ 11 điểm)", "damage starts with the weapon")
	eq(r["moveEnergy"]["detail"], "(gốc 100, điểm +3, trang bị +3 từ 1 điểm)", "move energy")
	eq(r["skillPowerBonus"]["value"], "+10%", "percent")
	eq(r["skillPowerBonus"]["detail"], "(điểm +10%)", "percent part, no gốc 0")
	eq(r["terrainDamageBonus"]["value"], "+0%", "zero percent")
	eq(r["terrainDamageBonus"]["detail"], "", "nothing adds to it")
	check(rows.all(func(x): return x["preview"] == ""), "no preview without pending points")


func test_equipment_part_without_points_from_an_older_server() -> void:
	var old := STATS.duplicate(true)
	old.erase("equipmentPoints")
	eq(_by_key(BattleStats.rows(old))["maxHp"]["detail"], "(gốc 130, điểm +100, trang bị +1.100)", "converted value only")


func test_preview_uses_multipliers_times_pending() -> void:
	var mult := BattleStats.multipliers({"statMultipliers": MULT})
	eq(mult, {"hp": 50, "damage": 5, "mobility": 3, "defense": 5, "skillPower": 5, "terrainDamage": 3}, "parsed")
	var r := _by_key(BattleStats.rows(STATS, {"hp": 2, "mobility": 4, "skillPower": 1, "defense": 0}, mult))
	eq(r["maxHp"]["preview"], "→ 1.430", "1330 + 2 × 50")
	eq(r["moveEnergy"]["preview"], "→ 118", "106 + 4 × 3")
	eq(r["skillPowerBonus"]["preview"], "→ +15%", "10 + 1 × 5")
	eq(r["defense"]["preview"], "", "no points pending")
	eq(BattleStats.preview_value(200, 1, 50), 250, "200 → 250")
	# Unknown multipliers: no preview rather than a wrong one.
	eq(_by_key(BattleStats.rows(STATS, {"hp": 2}, {}))["maxHp"]["preview"], "", "no multipliers")
	eq(BattleStats.multipliers({"statMultipliers": {"hp": 50}}), {}, "partial multipliers rejected")
	eq(BattleStats.multipliers({}), {}, "absent")


func test_crit_row_only_when_present() -> void:
	eq(BattleStats.crit(STATS), {"label": "Chí mạng", "value": "2.3%", "detail": "(trang bị +2.3%)"}, "crit")
	var no_crit := STATS.duplicate(true)
	no_crit.erase("critChance")
	eq(BattleStats.crit(no_crit), {}, "omitted when the server sends none")
	eq(BattleStats.format_chance(3.0), "3%", "whole percent")


func test_old_server_without_stats_hides_the_table() -> void:
	var entry := {"characterId": "rookie", "statPoints": 3, "bonusHp": 2}
	eq(BattleStats.of(entry), {}, "no stats")
	eq(BattleStats.rows(BattleStats.of(entry)), [], "no rows")
	eq(BattleStats.of({"stats": {"maxHp": 100}}), {}, "partial stats rejected")
	eq(BattleStats.of({"stats": "x"}), {}, "malformed")
	eq(BattleStats.base_of({"characters": []}, "tanko"), {}, "no baseStats")
	eq(BattleStats.base_of(null, "tanko"), {}, "no data")
	eq(BattleStats.card_line({}), "", "no card line")


func test_base_stats_for_unowned_characters() -> void:
	var data := {"baseStats": {"spark": {"maxHp": 90.0, "defense": 40.0, "damageBonus": 0.0, "moveEnergy": 100.0,
		"skillPowerBonus": 0.0, "terrainDamageBonus": 0.0, "weaponDamage": 55.0}}}
	var b := BattleStats.base_of(data, "spark")
	var r := _by_key(BattleStats.rows(b))
	eq(r["maxHp"]["value"], "90", "base hp")
	eq(r["maxHp"]["detail"], "", "no breakdown for base stats")
	eq(r["damageBonus"]["detail"], "(vũ khí 55)", "weapon damage shown")
	eq(BattleStats.card_line(b), "Máu 90 · Sát thương 55", "card line")
	eq(BattleStats.base_of(data, "flora"), {}, "unknown character")
	eq(BattleStats.crit(b), {}, "no crit at base")
