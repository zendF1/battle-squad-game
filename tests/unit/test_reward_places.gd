extends "res://tests/test_case.gd"
## Every place a reward is opened or granted: Kho đồ's chest cards (pictures only) and their open
## result (random contents: the reward reveal); a milestone claim (fixed rewards: instant, the icons
## fly with ui/reward_fly.gd, no gift box; a title is just added). Season rewards are mail now.

const BossFixture := preload("res://tests/boss_fixture.gd")
const BagPage := preload("res://screens/home/bag_page.gd")
const MilestonePage := preload("res://screens/home/milestone_page.gd")
const MilestoneModel := preload("res://screens/home/milestone_model.gd")
const RewardReveal := preload("res://ui/reward_reveal.gd")
const RewardFly := preload("res://ui/reward_fly.gd")
const RewardStrip := preload("res://ui/reward_strip.gd")
const ChestModel := preload("res://screens/home/chest_model.gd")


static func _texts(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).map(func(l): return (l as Label).text).filter(func(t): return t != "")


static func _host() -> Control:
	var host := Control.new()
	host.size = Vector2(1600, 900)
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	return host


func test_chest_card_is_pictures() -> void:
	BossFixture.take()
	var page := BagPage.new()
	var card: Control = page._chest_card({"chestId": "stone_chest", "quantity": 12, "name": "Rương đá"})
	var texts := _texts(card)
	check(not texts.any(func(t): return "Rương" in t or "Mở" in t or "Đá" in t), "no words on the card: %s" % str(texts))
	check(texts.has("×12"), "the count")
	check(texts.has("×1") and texts.has("×10"), "the open buttons: ×1, ×10")
	var open10: Button = card.find_child("Open10", true, false)
	check(open10 != null and open10.text == "", "an open button is the chest's picture over its count")
	card.free()
	page.free()


func test_open_result_is_the_reveal() -> void:
	BossFixture.take()
	var host := _host()
	var r: Control = BagPage.show_open_result(host, ChestModel.parse_open({"chestId": "equip_chest_16", "opened": 2,
		"equipment": [{"itemId": "a", "upgradeLevel": 16}, {"itemId": "b", "upgradeLevel": 16}]}))
	if r.box == null:
		r._ready()
	check(r.get_script() == RewardReveal, "the reward reveal")
	eq(r.chest_id, "equip_chest_16", "the chest opened")
	eq(r.count, 2, "two at once")
	eq(r.tiles.size(), 2, "two pieces")
	host.free()


func test_milestone_claim_flies_instantly_with_title() -> void:
	BossFixture.take()
	var host := _host()
	var lines := MilestoneModel.reward_lines(MilestoneModel.parse_rewards({"coin": 1000,
		"items": [{"kind": "title", "id": "t1", "name": "Lão làng", "rarity": "epic"}, {"kind": "stone", "level": 3, "qty": 2}]}))
	var r: Control = MilestonePage.show_rewards(host, lines, Vector2(400, 300))
	check(r != null and r.get_script() == RewardFly, "the rewards fly to the wallet / bag")
	check(not host.get_children().any(func(c): return c.get_script() == RewardReveal), "no reward reveal")
	check(host.find_child("Titles", true, false) == null, "no title plate to wear: the title is just added")
	var only_title := MilestoneModel.reward_lines(MilestoneModel.parse_rewards({
		"items": [{"kind": "title", "id": "t1", "name": "Lão làng", "rarity": "epic"}]}))
	check(MilestonePage.show_rewards(host, only_title) == null, "a title alone: nothing flies, no reveal")
	check(not host.get_children().any(func(c): return c.get_script() == RewardReveal), "still no reveal")
	host.free()


func test_no_reward_reveal_in_milestone_claims() -> void:
	var src := FileAccess.get_file_as_string("res://screens/home/milestone_page.gd")
	check(not src.contains("RewardReveal"), "no gift box for a milestone")
	check(src.contains("RewardFly.play("), "the rewards fly")
