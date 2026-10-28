extends "res://tests/test_case.gd"
## ui/element_chain.gd: an element's place in the cycle as badges (beaten by → element → beats),
## from the game data's elements, in place of the "Hệ: Kim — khắc Mộc, bị Hỏa khắc" line.

const ElementChain := preload("res://ui/element_chain.gd")
const GameData := preload("res://autoload/game_data_model.gd")


func test_chain_from_the_game_data() -> void:
	var chain = ElementChain.make("metal", 56)
	eq(chain.shown(), [GameData.element_beaten_by("metal"), "metal", GameData.element_beats("metal")], "beaten by → metal → beats")
	eq(chain.shown(), ["fire", "metal", "wood"], "Hỏa → Kim → Mộc in the fixture")
	check(chain.visible, "shown")
	chain.set_element("water")
	eq(chain.shown(), ["earth", "water", "fire"], "Thổ → Thủy → Hỏa")
	chain.set_element("")
	check(not chain.visible, "no element: nothing")
	chain.free()


func test_a_part_the_data_lacks_is_left_out() -> void:
	var d: Dictionary = GameData.data.duplicate(true)
	d["elements"] = [{"elementId": "light", "name": "Quang", "beats": ""}]
	d["version"] = "one-element"
	GameData.take(d, "", false)
	var chain = ElementChain.make("light", 56)
	eq(chain.shown(), ["", "light", ""], "no rule: only the element")
	chain.free()
