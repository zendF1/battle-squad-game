extends "res://tests/test_case.gd"
## The shield bubble: ShieldState (gain, keep, break; the caster's gun tier kept while the shield
## lasts, the fallbacks), the tint per gun tier, ShieldBall's breath, pop in and pop out, the round
## boss shield, and PlayerView's bubble following the player's shield.

const ShieldState := preload("res://match/views/shield_state.gd")
const ShieldBall := preload("res://match/views/shield_ball.gd")
const EquipmentPainter := preload("res://tools/art/equipment_painter.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const PlayerView := preload("res://match/views/player_view.gd")


func test_gain_keep_break() -> void:
	var s := ShieldState.new()
	eq(s.update("p2", 0), ShieldState.NONE, "no shield")
	eq(s.update("p2", 180, "dragon", "iron"), ShieldState.GAIN, "Flora's bloom: a shield comes up")
	eq(s.tier_of("p2"), "dragon", "in the caster's gun tier")
	eq(s.update("p2", 90), ShieldState.KEEP, "a hit takes some: still up")
	eq(s.tier_of("p2"), "dragon", "the caster's tier kept while it lasts")
	eq(s.update("p2", 0), ShieldState.BREAK, "broken")
	check(not s.has("p2") and s.tier_of("p2") == "", "and forgotten")
	eq(s.update("p2", 0), ShieldState.NONE, "still none")
	eq(s.update("p3", 120, "", "mithril"), ShieldState.GAIN, "a reconnect's shield, no caster known")
	eq(s.tier_of("p3"), "mithril", "takes the player's own gun tier")
	eq(s.update("p3", 200, "gold", "mithril"), ShieldState.KEEP, "a new bloom on top")
	eq(s.tier_of("p3"), "gold", "takes the new caster's tier")
	s.update("p4", 50, "", "")
	eq(s.colour_of("p4"), ShieldBall.DEFAULT_TINT, "nothing known: the default cyan")


func test_tier_colours() -> void:
	var dragon := ShieldBall.tier_colour("dragon")
	check(dragon.r > 0.8 and dragon.g < 0.45 and dragon.b < 0.4, "a dragon gun: a red bubble (%s)" % dragon)
	eq(ShieldBall.tier_colour("basic"), ShieldBall.DEFAULT_TINT, "the basic gun: the default")
	eq(ShieldBall.tier_colour("nope"), ShieldBall.DEFAULT_TINT, "an unknown tier: the default")
	for tier in EquipmentPainter.TIERS:
		check(ShieldBall.tier_colour(tier) != ShieldBall.DEFAULT_TINT or tier == "diamond", "%s has its own colour" % tier)
	var mithril := ShieldBall.tier_colour("mithril")
	check(mithril.g > mithril.r, "mithril: teal")


func test_breath() -> void:
	near(ShieldBall.pulse(0.0), 1.0, 0.001, "the breath round 1")
	near(ShieldBall.pulse(ShieldBall.PULSE_SEC / 4.0), 1.0 + ShieldBall.PULSE_AMP, 0.001, "swells")
	near(ShieldBall.pulse(ShieldBall.PULSE_SEC * 0.75), 1.0 - ShieldBall.PULSE_AMP, 0.001, "shrinks")
	check(ShieldBall.PULSE_AMP >= 0.04 and ShieldBall.PULSE_AMP <= 0.06, "a few percent")
	check(ShieldBall.PULSE_SEC >= 1.6 and ShieldBall.PULSE_SEC <= 2.0, "slow")


func test_pop_in_and_out() -> void:
	var b := ShieldBall.new()
	check(not b.is_on(), "none at first")
	b.show_ball()
	var p := b.pop_state()
	near(p.x, ShieldBall.POP_FROM, 0.01, "pops in from small")
	near(p.y, 0.0, 0.01, "fading in")
	var top := 0.0
	for i in 30:
		b._process(1.0 / 60.0)
		top = maxf(top, b.pop_state().x)
	check(top > 1.02, "overshoots (%f)" % top)
	eq(b.pop_state(), Vector2.ONE, "then settles")
	b.hide_ball()
	check(b.is_on() and b.popping_out(), "popping out")
	b._process(ShieldBall.POP_OUT_SEC * 0.5)
	check(b.pop_state().x > 1.0 and b.pop_state().y < 1.0, "swelling as it fades")
	b._process(ShieldBall.POP_OUT_SEC)
	check(not b.is_on(), "gone")
	b.show_ball(false)
	eq(b.pop_state(), Vector2.ONE, "a snapshot's shield: there at once")
	b.free()


func test_boss_shield_is_round() -> void:
	near(BossArt.shield_radius("lava_crab", 100.0), 85.0 + 100.0 * BossArt.SHIELD_MARGIN, 0.01, "the wide crab: half its width and a margin")
	near(BossArt.shield_radius("steel_robot", 100.0), 67.5 + 100.0 * BossArt.SHIELD_MARGIN, 0.01, "the robot")
	near(BossArt.shield_radius("ice_witch", 100.0), 55.0 + 100.0 * BossArt.SHIELD_MARGIN, 0.01, "the witch")
	near(BossArt.shield_radius("snowman", 100.0), 50.0 + 100.0 * BossArt.SHIELD_MARGIN, 0.01, "a narrow one: half its height")


func test_player_bubble_follows_the_shield() -> void:
	var v := PlayerView.new()
	v.setup({"playerId": "p2", "teamId": 1, "characterId": "flora", "hp": 1000, "maxHp": 1000, "position": {"x": 100, "y": 200}}, false, 1)
	var b := v.shield_bubble()
	check(b != null and not b.is_on(), "no shield, no bubble")
	near(b.position.x, 0.0, 0.001, "centred on the body")
	check(b.position.y < -20.0 and b.radius > 28.0 and b.radius < 60.0, "round a player's body (%f at %f)" % [b.radius, b.position.y])
	v.set_shield_tint(ShieldBall.tier_colour("dragon"))
	v.set_shield(150)
	check(b.is_on() and b.pop_state().x < 1.0, "pops in")
	eq(b.tint, ShieldBall.tier_colour("dragon"), "in the caster's colour")
	v.set_shield(60)
	check(b.is_on() and not b.popping_out(), "kept while some is left")
	v.set_shield(0)
	check(b.popping_out(), "pops out when it breaks")
	v.free()
	var w := PlayerView.new()
	w.setup({"playerId": "p3", "teamId": 1, "characterId": "rookie", "hp": 900, "maxHp": 1000, "shield": 80, "position": {"x": 0, "y": 0}}, false, 1)
	check(w.shield_bubble().is_on() and w.shield_bubble().pop_state() == Vector2.ONE, "a snapshot's shield: up at once")
	w.free()


## A view with what match_screen._set_shield asks of it.
class FakeView extends Node2D:
	var shield := 0
	var tint := Color.BLACK

	func set_shield(value: int, _animate: bool = true) -> void:
		shield = value

	func set_shield_tint(c: Color) -> void:
		tint = c


func test_the_casters_gun_colours_the_bubble() -> void:
	var MatchScreen = load("res://match/match_screen.gd")
	var m = MatchScreen.new()
	m._players = {"flora": {"playerId": "flora", "characterId": "flora", "teamId": 1, "weaponItemId": "crafted_flora_dragon"},
		"basic": {"playerId": "basic", "characterId": "flora", "teamId": 1},
		"p2": {"playerId": "p2", "characterId": "rookie", "teamId": 1}}
	var v := FakeView.new()
	m._views = {"p2": v}
	m._set_shield("p2", 150, "flora")
	eq(v.shield, 150, "the shield shown")
	eq(v.tint, ShieldBall.tier_colour("dragon"), "Flora's dragon gun: a red bubble")
	eq(m.shield_state().tier_of("p2"), "dragon", "remembered")
	m._set_shield("p2", 70)
	eq(v.tint, ShieldBall.tier_colour("dragon"), "a hit keeps its colour")
	m._set_shield("p2", 0)
	check(not m.shield_state().has("p2"), "broken")
	m._set_shield("p2", 120, "basic")
	eq(v.tint, ShieldBall.DEFAULT_TINT, "a basic gun: the default cyan")
	v.free()
	m.free()
