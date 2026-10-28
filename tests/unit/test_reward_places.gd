extends "res://tests/test_case.gd"
## Every place a reward is opened or granted shows it with the reward reveal / glowing tiles:
## Kho đồ's chest cards (pictures only) and their open result, milestone / daily claims (a gift
## box; a new title's plate under the tiles), the season reward popup (tiles) and its claim.

const BossFixture := preload("res://tests/boss_fixture.gd")
const BagPage := preload("res://screens/home/bag_page.gd")
const MilestonePage := preload("res://screens/home/milestone_page.gd")
const MilestoneModel := preload("res://screens/home/milestone_model.gd")
const SeasonRewardPopup := preload("res://screens/ranked/season_reward_popup.gd")
const SeasonRewardModel := preload("res://screens/ranked/season_reward_model.gd")
const RewardReveal := preload("res://ui/reward_reveal.gd")
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


func test_milestone_claim_reveal_with_title() -> void:
	BossFixture.take()
	var host := _host()
	var lines := MilestoneModel.reward_lines(MilestoneModel.parse_rewards({"coin": 1000,
		"items": [{"kind": "title", "id": "t1", "name": "Lão làng", "rarity": "epic"}, {"kind": "stone", "level": 3, "qty": 2}]}))
	var r: Control = MilestonePage.show_rewards(host, "x", lines)
	if r.box == null:
		r._ready()
	check(r.get_script() == RewardReveal, "the reward reveal")
	check(r.box.is_gift(), "a gift box")
	eq(r.tiles.map(func(t): return t["kind"]), ["coin", "stone"], "the coin and stones as tiles")
	var titles: Control = r.find_child("Titles", true, false)
	check(titles != null, "the new title under the tiles")
	if titles != null:
		check(not _texts(titles).any(func(t): return "Danh hiệu mới" in t), "the plate says it, no line")
	host.free()


func test_season_popup_tiles() -> void:
	BossFixture.take()
	var host := _host()
	var r := SeasonRewardModel.parse_one({"seasonId": "s1", "seasonName": "Mùa 1", "grade": "dai_tuong", "coin": 2000, "gem": 15,
		"items": [{"kind": "chest", "id": "stone_chest", "qty": 25, "name": "Rương đá"}]})
	var p := SeasonRewardPopup.new()
	p.open_for(host, r)
	var tiles: Control = p.find_child("Lines", true, false)
	check(tiles != null and tiles.get_script() == RewardStrip, "the rewards as glowing tiles")
	var texts := _texts(p)
	check(not texts.any(func(t): return " xu" in t or "Rương đá" in t or "kim cương" in t), "no reward words: %s" % str(texts))
	host.free()
