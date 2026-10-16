extends "res://tests/test_case.gd"

const BattleStats := preload("res://screens/home/battle_stats.gd")

# Shaped like the server's GET /player/characters (JSON numbers parse as floats).
# Tanko with 20 HP / 3 mobility / 10 skill points and full Dragon +0 gear.
const STATS := {
	"maxHp": 2860.0, "defense": 124.0, "damageBonus": 250.0, "moveEnergy": 104.0, "skillPowerBonus": 10.0,
	"terrainDamageBonus": 0.0, "critChance": 2.25, "weaponDamage": 600.0,
	"base": {"maxHp": 1950.0, "defense": 80.0, "damageBonus": 0.0, "moveEnergy": 100.0, "skillPowerBonus": 0.0, "terrainDamageBonus": 0.0},
	"fromPoints": {"maxHp": 40.0, "defense": 0.0, "damageBonus": 0.0, "moveEnergy": 3.0, "skillPowerBonus": 10.0, "terrainDamageBonus": 0.0},
	"fromEquipment": {"maxHp": 870.0, "defense": 44.0, "damageBonus": 250.0, "moveEnergy": 1.0, "skillPowerBonus": 0.0, "terrainDamageBonus": 0.0, "critChance": 2.25},
	# Equipment adds points; fromEquipment is them × statMultipliers (crit is a percent).
	"equipmentPoints": {"hp": 435.0, "damage": 50.0, "defense": 44.0, "mobility": 1.0, "crit": 2.25},
}
# The server defaults.
const MULT := {"hp": 2.0, "damage": 5.0, "mobility": 1.0, "defense": 1.0, "skillPower": 1.0, "terrainDamage": 1.0}


func _by_key(rows: Array) -> Dictionary:
	var out := {}
	for r in rows:
		out[r["key"]] = r
	return out


func test_rows_values_and_breakdown() -> void:
	var rows := BattleStats.rows(STATS)
	eq(rows.map(func(r): return r["label"]), ["Máu", "Phòng thủ", "Sát thương", "Năng lượng di chuyển", "Sức mạnh kỹ năng", "Phá địa hình"], "order")
	var r := _by_key(rows)
	eq(r["maxHp"]["value"], "2.860", "hp total, thousands separator")
	eq(r["maxHp"]["detail"], "(gốc 1.950, điểm +40, trang bị +870 từ 435 điểm)", "hp breakdown with the equipment points")
	eq(r["defense"]["detail"], "(gốc 80, trang bị +44 từ 44 điểm)", "zero parts left out")
	eq(r["damageBonus"]["value"], "+250", "damage is a flat bonus")
	eq(r["damageBonus"]["detail"], "(vũ khí 600, trang bị +250 từ 50 điểm)", "damage starts with the weapon")
	eq(r["moveEnergy"]["detail"], "(gốc 100, điểm +3, trang bị +1 từ 1 điểm)", "move energy")
	eq(r["skillPowerBonus"]["value"], "+10%", "percent")
	eq(r["skillPowerBonus"]["detail"], "(điểm +10%)", "percent part, no gốc 0")
	eq(r["terrainDamageBonus"]["value"], "+0%", "zero percent")
	eq(r["terrainDamageBonus"]["detail"], "", "nothing adds to it")
	check(rows.all(func(x): return x["preview"] == ""), "no preview without pending points")


func test_equipment_part_without_points_from_an_older_server() -> void:
	var old := STATS.duplicate(true)
	old.erase("equipmentPoints")
	eq(_by_key(BattleStats.rows(old))["maxHp"]["detail"], "(gốc 1.950, điểm +40, trang bị +870)", "converted value only")


func test_preview_uses_multipliers_times_pending() -> void:
	var mult := BattleStats.multipliers({"statMultipliers": MULT})
	eq(mult, {"hp": 2, "damage": 5, "mobility": 1, "defense": 1, "skillPower": 1, "terrainDamage": 1}, "parsed")
	var r := _by_key(BattleStats.rows(STATS, {"hp": 2, "damage": 79, "mobility": 4, "skillPower": 1, "defense": 0}, mult))
	eq(r["maxHp"]["preview"], "→ 2.864", "2860 + 2 × 2")
	eq(r["damageBonus"]["preview"], "→ +645", "250 + 79 × 5")
	eq(r["moveEnergy"]["preview"], "→ 108", "104 + 4 × 1")
	eq(r["skillPowerBonus"]["preview"], "→ +11%", "10 + 1 × 1")
	eq(r["defense"]["preview"], "", "no points pending")
	eq(BattleStats.preview_value(1500, 79, 2), 1658, "1500 → 1658")
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
	var data := {"baseStats": {"spark": {"maxHp": 1350.0, "defense": 40.0, "damageBonus": 0.0, "moveEnergy": 100.0,
		"skillPowerBonus": 0.0, "terrainDamageBonus": 0.0, "weaponDamage": 440.0}}}
	var b := BattleStats.base_of(data, "spark")
	var r := _by_key(BattleStats.rows(b))
	eq(r["maxHp"]["value"], "1.350", "base hp")
	eq(r["maxHp"]["detail"], "", "no breakdown for base stats")
	eq(r["damageBonus"]["detail"], "(vũ khí 440)", "weapon damage shown")
	eq(BattleStats.card_line(b), "Máu 1.350 · Sát thương 440", "card line")
	eq(BattleStats.card_line(STATS), "Máu 2.860 · Sát thương 850", "card line: weapon + bonus")
	var big := b.duplicate()
	big["weaponDamage"] = 1200.0
	eq(_by_key(BattleStats.rows(big))["damageBonus"]["detail"], "(vũ khí 1.200)", "weapon damage thousands separator")
	eq(BattleStats.base_of(data, "flora"), {}, "unknown character")
	eq(BattleStats.crit(b), {}, "no crit at base")
