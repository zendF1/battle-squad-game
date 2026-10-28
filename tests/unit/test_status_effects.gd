extends "res://tests/test_case.gd"

const Status := preload("res://match/status_effects.gd")
const GameData := preload("res://autoload/game_data_model.gd")


func test_has_needs_turns_left() -> void:
	var effects := [{"effectId": "freeze", "durationTurn": 1}, {"effectId": "net", "durationTurn": 0}]
	check(Status.has(effects, "freeze"), "freeze active")
	check(not Status.has(effects, "net"), "net expired")
	check(not Status.has(null, "freeze"), "null list")


func test_marker_text() -> void:
	eq(Status.marker_text([{"effectId": "net", "durationTurn": 1}]), "", "net is an icon now")
	eq(Status.marker_text([{"effectId": "freeze", "durationTurn": 1}, {"effectId": "power_shot", "durationTurn": 1}]), "", "a shot modifier is its icon on the use badge")
	eq(Status.marker_text([{"effectId": "heal", "durationTurn": 1}]), "", "heal shows nothing")
	eq(Status.marker_text([{"effectId": "power_shot", "durationTurn": 0}]), "", "expired")
	eq(Status.marker_text([{"effectId": "drill_bomb", "durationTurn": 1}, {"effectId": "drill_bomb", "durationTurn": 2}]), "", "an armed item: no text")
	eq(Status.marker_text(null), "", "null")
	for id in ["spider_net", "freeze_bomb", "air_strike"]:
		eq(Status.marker_text([{"effectId": id, "durationTurn": 1}]), "", "armed item %s: its icon, no text" % id)


func test_apply_overrides_or_adds() -> void:
	var base := [{"effectId": "net", "durationTurn": 1, "value": 0.0}]
	var again := Status.apply(base, "net", 2)
	eq(again.size(), 1, "same effect merged")
	eq(again[0]["durationTurn"], 2, "duration overridden")
	eq(base[0]["durationTurn"], 1, "input untouched")
	var added := Status.apply(base, "freeze", 1)
	eq(added.size(), 2, "new effect added")
	eq(Status.apply(null, "freeze", 1), [{"effectId": "freeze", "durationTurn": 1}], "from null")


func test_tick_drops_expired() -> void:
	var effects := [{"effectId": "net", "durationTurn": 1}, {"effectId": "freeze", "durationTurn": 2}]
	eq(Status.tick(effects), [{"effectId": "freeze", "durationTurn": 1}], "one turn less")
	eq(effects[1]["durationTurn"], 2, "input untouched")
	eq(Status.tick(null), [], "null")


func test_active_in_order() -> void:
	var effects := [{"effectId": "net", "durationTurn": 1}, {"effectId": "power_shot", "durationTurn": 1},
		{"effectId": "burn", "durationTurn": 1}, {"effectId": "stun", "durationTurn": 0}, {"effectId": "root", "durationTurn": 1},
		{"effectId": "burn", "durationTurn": 2}]
	eq(Status.active(effects), ["net", "power_shot", "burn", "root"], "active, list order, once")
	eq(Status.bad(effects), ["net", "burn", "root"], "the bad ones")
	eq(Status.active(null), [], "null")


func test_skip_and_root() -> void:
	eq(Status.skip_effect([{"effectId": "stun", "durationTurn": 1}]), "stun", "stun")
	eq(Status.skip_effect([{"effectId": "freeze", "durationTurn": 1}, {"effectId": "stun", "durationTurn": 1}]), "stun", "stun first")
	eq(Status.skip_effect([{"effectId": "freeze", "durationTurn": 1}]), "freeze", "freeze")
	eq(Status.skip_effect([{"effectId": "root", "durationTurn": 1}]), "", "root does not skip")
	check(Status.blocks_move([{"effectId": "root", "durationTurn": 1}]), "root blocks moving")
	check(Status.blocks_move([{"effectId": "freeze", "durationTurn": 1}]), "freeze blocks moving")
	check(not Status.blocks_move([{"effectId": "net", "durationTurn": 1}]), "net only slows")
	eq(Status.skip_text("stun"), "Choáng — mất lượt", "stun banner")
	eq(Status.move_block_text([{"effectId": "root", "durationTurn": 1}]), "Bị cầm chân", "root notice")
	eq(Status.move_block_text([{"effectId": "stun", "durationTurn": 1}]), "", "a lost turn has its own banner")


func test_remove_cleansed() -> void:
	var effects := [{"effectId": "burn", "durationTurn": 1}, {"effectId": "power_shot", "durationTurn": 1}, {"effectId": "root", "durationTurn": 1}]
	eq(Status.remove(effects, ["burn", "root"]), [{"effectId": "power_shot", "durationTurn": 1}], "cleansed")
	eq(effects.size(), 3, "input untouched")
	eq(Status.remove(effects, null).size(), 3, "no ids: unchanged")
	eq(Status.remove(null, ["burn"]), [], "null")
	eq(Status.bad(effects), ["burn", "root"], "the bad ones (cleansable)")


## A status effect an admin added: its rules and texts come from the game data, a bad one shows
## on the body (StatusLook's violet aura: no picture of its own).
func test_effects_from_the_game_data() -> void:
	var d: Dictionary = GameData.data.duplicate(true)
	d["version"] = "edited"
	d["statusEffects"].insert(0, {"effectId": "sleep", "name": "Ngủ", "marker": "Zzz", "banner": "Ngủ — mất lượt", "bad": true,
		"skipsTurn": true, "blocksMove": true})
	GameData.take(d, "", false)
	var effects := [{"effectId": "stun", "durationTurn": 1}, {"effectId": "sleep", "durationTurn": 2}]
	eq(Status.skip_effect(effects), "sleep", "the game data's order")
	eq(Status.skip_text("sleep"), "Ngủ — mất lượt", "its banner")
	eq(Status.bad(effects), ["stun", "sleep"], "a bad one")
	eq(Status.marker_text(effects), "Zzz", "its marker")
	check(Status.blocks_move([{"effectId": "sleep", "durationTurn": 1}]), "blocks moving")
	eq(Status.bad([{"effectId": "ghost", "durationTurn": 1}]), [], "an effect the game data does not know: not a bad one")
