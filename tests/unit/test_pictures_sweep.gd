extends "res://tests/test_case.gd"
## Pictures, not words: status effects as pictures (match/views/status_glyph.gd, status_burst.gd),
## the level glyph rows (ui/glyph_icon.gd level_row / show_level), the result countdown and the
## inline reward tiles.

const StatusGlyph := preload("res://match/views/status_glyph.gd")
const StatusBurst := preload("res://match/views/status_burst.gd")
const Status := preload("res://match/status_effects.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const RewardStrip := preload("res://ui/reward_strip.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const ResultModel := preload("res://match/result_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")


func test_every_status_has_a_picture() -> void:
	for id in GameData.status_ids():
		check(StatusGlyph.has_picture(id), "%s: a picture" % id)
	for id in ["stun", "freeze", "burn", "net", "root", "poison", "blind", "power_shot", "drill_bomb"]:
		check(StatusGlyph.has_picture(id), "%s has a picture" % id)
	check(not StatusGlyph.has_picture("sleep"), "an effect the client does not know: no picture (its name instead)")
	check(StatusGlyph.color_of("freeze") != StatusGlyph.color_of("burn"), "each its colour")


func test_burst_is_the_picture() -> void:
	var b: Control = StatusBurst.make("freeze", true)
	check(b._glyph != null and b._glyph.effect == "freeze" and b._glyph.skip, "the freeze badge with the lost-turn mark")
	check(b.find_children("*", "Label", true, false).is_empty(), "no words")
	b._glyph.free()
	b.free()


func test_move_block_effect() -> void:
	eq(Status.move_block_effect([{"effectId": "root", "durationTurn": 1}]), "root", "rooted: its picture over the move buttons")
	eq(Status.move_block_effect([{"effectId": "stun", "durationTurn": 1}]), "", "a lost turn: the countdown instead")
	eq(Status.move_block_effect(null), "", "none")


func test_level_row() -> void:
	var l := Label.new()
	var row := GlyphIcon.level_row(l, 24)
	GlyphIcon.show_level(l, "19")
	var g: Control = row.get_node("LevelGlyph")
	check(g.visible and l.text == "19", "the glyph with the number, no \"Lv.\"")
	GlyphIcon.show_level(l, "Chưa sở hữu")
	check(not g.visible, "a word alone: no glyph")
	row.free()


func test_countdown_and_mini_tile() -> void:
	eq(ResultModel.countdown_text(12), "12", "the seconds beside the clock glyph")
	var t := RewardStrip.mini_tile(RewardModel.tile("stone", "stone_5", 2, 5), 40)
	var texts: Array = t.find_children("*", "Label", true, false).map(func(n): return (n as Label).text)
	eq(texts, ["×2"], "an inline reward: icon + ×N")
	eq(t.tooltip_text, RewardModel.name_of(RewardModel.tile("stone", "stone_5", 2, 5)), "its name only as the tooltip")
	t.free()
