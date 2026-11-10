extends "res://tests/test_case.gd"
## A purchase is not a reward: the Shop's buys (stones, equipment, item offers / coin packs, top-ups)
## give at once through shop_tab.gd _bought() (ui/reward_fly.gd: the icon + ×N pops where the buy was
## tapped and flies home, nothing blocks), never the gift-box reward reveal.

const ShopTab := preload("res://screens/home/shop_tab.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const SOURCE := "res://screens/home/shop_tab.gd"


func test_no_gift_box_for_a_purchase() -> void:
	var src := FileAccess.get_file_as_string(SOURCE)
	check(not src.contains("RewardReveal"), "the Shop never opens the reward reveal")
	for fn in ["_purchase_stones", "_purchase(", "_purchase_equipment", "_on_top_up"]:
		var at := src.find("func " + fn)
		var next := src.find("\nfunc ", at + 1)
		check(at >= 0 and src.substr(at, next - at).contains("_bought("), "%s gives at once" % fn)


func test_bought_pops_and_never_blocks() -> void:
	var host := Control.new()
	host.size = Vector2(1600, 900)
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var shop = ShopTab.new()
	shop.overlay = host
	var fly: Control = shop._bought([RewardModel.tile("stone", "stone_3", 5, 3)], Vector2(300, 400))
	eq(fly.get_parent(), host, "over the Home shell")
	eq(fly.mouse_filter, Control.MOUSE_FILTER_IGNORE, "nothing to tap: the screen stays usable")
	eq((fly.find_children("*", "Label", true, false)[0] as Label).text, "×5", "icon + ×N")
	eq(shop._tap_point(), null, "not shown: from the centre")
	shop.free()
	host.free()
