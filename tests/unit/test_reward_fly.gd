extends "res://tests/test_case.gd"
## ui/reward_fly.gd: a purchase's arrival (no gift box, no "Nhận"): the icon + "×N" pops, never takes
## input, and flies to the wallet pill or the bag button (the same target the reward reveal uses).

const RewardFly := preload("res://ui/reward_fly.gd")
const RewardModel := preload("res://ui/reward_model.gd")


static func _host() -> Control:
	var host := Control.new()
	host.size = Vector2(1600, 900)
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	for spec in [["CoinPill", Vector2(1200, 20)], ["BagButton", Vector2(1500, 800)]]:
		var c := Control.new()
		c.name = spec[0]
		c.position = spec[1]
		c.size = Vector2(100, 40)
		host.add_child(c)
	return host


func test_pops_without_blocking() -> void:
	var host := _host()
	var layer: Control = RewardFly.play(host, [RewardModel.tile("stone", "stone_3", 5, 3)], Vector2(400, 300))
	eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never takes input")
	var labels := layer.find_children("*", "Label", true, false)
	eq(labels.size(), 1, "one count")
	eq((labels[0] as Label).text, "×5", "the quantity, no name")
	check(layer.find_children("RewardReveal", "", true, false).is_empty() and host.get_node_or_null("RewardReveal") == null, "no gift box")
	var tile: Control = layer.get_node("Tile0")
	near(tile.position.x + tile.get_combined_minimum_size().x / 2.0, 400.0, 1.0, "starts where the buy happened")
	check(RewardFly.duration(1) < 1.6, "short")
	host.free()


func test_targets() -> void:
	var host := _host()
	var probe := Control.new()
	probe.size = Vector2(10, 10)
	host.add_child(probe)
	eq(RewardFly.target_for(probe, RewardModel.tile("coin", "coin", 100)), Vector2(1250, 40), "coins: the coin pill")
	eq(RewardFly.target_for(probe, RewardModel.tile("stone", "stone_1", 1, 1)), Vector2(1550, 820), "the rest: the bag button")
	host.free()
