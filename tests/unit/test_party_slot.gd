extends "res://tests/test_case.gd"
## screens/home/party_slot.gd: the teammate stands in the open scene like the lobby stage's
## character (title plate, element + name, level, the figure on its rank's dais), smaller; no card,
## no frame.

const PartySlot := preload("res://screens/home/party_slot.gd")
const PartyModel := preload("res://screens/home/party_model.gd")
const TitlePlate := preload("res://ui/title_plate.gd")

const GENERAL := {"playerId": "p2", "displayName": "Daniel Hayes", "characterId": "rookie", "level": 36,
	"rankBadge": "dai_tuong", "ready": true}


func _slot() -> Control:
	var s := PartySlot.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	if not s.is_node_ready(): # the test runner's root may still be setting up
		s._ready()
	return s


func _nodes(n: Node, out: Array) -> Array:
	for c in n.get_children():
		out.append(c)
		_nodes(c, out)
	return out


func test_no_card_no_frame() -> void:
	var s := _slot()
	s.show_member(PartyModel.parse_member(GENERAL), true)
	for n in _nodes(s, []):
		var path := str(n.get_script().resource_path) if n.get_script() != null else ""
		check(not path.ends_with("grade_frame.gd") and not path.ends_with("player_card.gd"),
			"no frame or card round the teammate (%s)" % n.name)
	check(not "fit_art" in s, "no frame art to fit")
	s.free()


func test_head_like_the_stage() -> void:
	var s := _slot()
	var m := PartyModel.parse_member(GENERAL)
	s.show_member(m, true)
	var head: Control = s.get_node("Body/Head")
	near(head.position.x + head.size.x / 2.0, PartySlot.SIZE.x / 2.0, 0.01, "the head centred over the figure")
	near(head.position.y, PartySlot.head_y(false), 0.01, "no title: the name at the stage's gap")
	check(head.position.y >= 0.0, "the head inside the slot")
	m["title"] = {"id": "t1", "name": "Cao thủ", "rarity": "red"}
	s.show_member(m, true)
	near(head.position.y, PartySlot.head_y(true), 0.01, "a title's plate rises above the name")
	check(PartySlot.head_y(true) >= 0.0, "the plate inside the slot")
	check(PartySlot.head_y(true) < PartySlot.head_y(false), "the name stays put under the plate")
	s.free()


func test_member_title_parsed() -> void:
	eq(PartyModel.parse_member(GENERAL)["title"], {}, "no equippedTitle: no plate")
	var t: Dictionary = PartyModel.parse_member(GENERAL.merged({"equippedTitle": {"id": "t1", "name": "Cao thủ", "rarity": "red"}}))["title"]
	eq(t.get("name"), "Cao thủ", "the member's equippedTitle")
