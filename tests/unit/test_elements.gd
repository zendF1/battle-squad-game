extends "res://tests/test_case.gd"
## The elements (ngũ hành) of GET /gamedata: the accessors (cycle, rules, characters' and bosses'
## elements, a unit's), the detail line (ui/element_text.gd), the
## badge's visual mapping by elementId and its centred glyphs (ui/element_badge.gd).

const GameData := preload("res://autoload/game_data_model.gd")
const BossFixture := preload("res://tests/boss_fixture.gd")
const ElementBadge := preload("res://ui/element_badge.gd")
const ElementText := preload("res://ui/element_text.gd")


func test_elements_and_cycle() -> void:
	eq(GameData.element_ids(), ["metal", "wood", "water", "fire", "earth"], "by sortOrder")
	eq(GameData.element_ids().map(func(id): return GameData.element_name(id)), ["Kim", "Mộc", "Thủy", "Hỏa", "Thổ"], "names")
	eq(GameData.element_ids().map(func(id): return GameData.element_beats(id)), ["wood", "earth", "fire", "metal", "water"], "beats")
	eq(GameData.element_ids().map(func(id): return GameData.element_beaten_by(id)), ["fire", "metal", "earth", "water", "wood"], "beaten by")
	eq(GameData.element_name("void"), "void", "an unknown id reads as itself")
	eq([GameData.element_beats("void"), GameData.element_beaten_by(""), GameData.is_element("void")], ["", "", false], "unknown")


func test_element_effect() -> void:
	eq(GameData.element_effect("metal", "wood"), "strong", "Kim bắn Mộc")
	eq(GameData.element_effect("wood", "metal"), "weak", "Mộc bắn Kim")
	eq(GameData.element_effect("metal", "water"), "", "unrelated")
	eq(GameData.element_effect("fire", "fire"), "", "same")
	eq(GameData.element_effect("", "wood"), "", "none")


func test_rules() -> void:
	eq(GameData.element_rules(), {"pvpStrongPct": 10.0, "pvpWeakPct": 10.0, "bossStrongPct": 20.0, "bossTakenPct": 10.0}, "elementRules")
	GameData.reset("")
	GameData.take({"version": "x"}, "", false)
	eq(GameData.element_rules()["pvpStrongPct"], 0.0, "an older server: 0")
	eq([GameData.element_ids(), GameData.character_element("rookie")], [[], ""], "no elements")


func test_characters_bosses_units() -> void:
	BossFixture.take()
	eq(["rookie", "tanko", "spark", "flora"].map(func(id): return GameData.character_element(id)), ["fire", "earth", "metal", "wood"], "characters")
	eq(["steel_robot", "lava_crab", "ice_witch"].map(func(id): return GameData.boss_element(id)), ["metal", "fire", "water"], "bosses")
	eq(GameData.unit_element({"characterId": "spark"}), "metal", "a player: its character's")
	eq(GameData.unit_element({"characterId": "spark", "element": "water"}), "water", "the state's first")
	eq(GameData.unit_element({"role": "minion", "bossId": "ice_witch", "minionId": "snowman", "characterId": "flora"}), "water", "a minion: its boss's")
	eq(GameData.unit_element({"role": "boss", "bossId": "lava_crab"}), "fire", "the boss")


func test_detail_line() -> void:
	eq(ElementText.detail_line("water"), "Hệ: Thủy — khắc Hỏa, bị Thổ khắc", "water")
	eq(ElementText.detail_line("metal"), "Hệ: Kim — khắc Mộc, bị Hỏa khắc", "metal")
	eq(ElementText.detail_line(""), "", "none")
	eq(ElementText.detail_line("void"), "Hệ: void", "unknown: the id, no relations")


func test_badge_mapping() -> void:
	for id in ["metal", "wood", "water", "fire", "earth"]:
		check(ElementBadge.has_glyph(id), "%s has its own glyph" % id)
		check(not ElementBadge.glyph(id).is_empty(), "%s glyph parts" % id)
	eq(ElementBadge.look("void"), ElementBadge.NEUTRAL, "an unknown element: neutral")
	check(ElementBadge.glyph("void").is_empty(), "no glyph: the name's letter")
	var discs := {}
	for id in ElementBadge.LOOKS:
		discs[ElementBadge.look(id)["disc"]] = id
	eq(discs.size(), 5, "five distinct colours")
	# the hues the spec names: Thủy blue, Hỏa orange-red, Mộc green, Thổ amber-brown, Kim steel
	var water: Color = ElementBadge.look("water")["disc"]
	var fire: Color = ElementBadge.look("fire")["disc"]
	var wood: Color = ElementBadge.look("wood")["disc"]
	check(water.b > water.r and water.b > water.g, "water is blue")
	check(fire.r > fire.g and fire.r > fire.b, "fire is red-orange")
	check(wood.g > wood.r and wood.g > wood.b, "wood is green")
	var metal_glyph: Color = ElementBadge.look("metal")["glyph"]
	check(metal_glyph.r > 0.9 and metal_glyph.g > 0.85 and metal_glyph.b < 0.6, "Kim: an electric yellow bolt")


func test_glyphs_dead_centre() -> void:
	for id in ["metal", "wood", "water", "fire", "earth"]:
		var r := ElementBadge.glyph_bounds(id)
		near(r.get_center().x, 0.0, 1e-4, "%s centred across" % id)
		near(r.get_center().y, 0.0, 1e-4, "%s centred down" % id)
		check(r.size.x <= 2.0 and r.size.y <= 2.0 and maxf(r.size.x, r.size.y) > 1.2, "%s fills the disc's middle" % id)


func test_name_row() -> void:
	var l := Label.new()
	var row := ElementBadge.name_row(l, "fire", 30, 6)
	var b = row.get_node("ElementBadge")
	eq([b.visible, row.get_node("Spacer").visible, b.element_id], [true, true, "fire"], "badge and its balancing spacer")
	eq(row.get_node("Spacer").custom_minimum_size.x, 30.0, "the spacer as wide as the badge: the name stays centred")
	ElementBadge.set_row_element(row, "")
	eq([b.visible, row.get_node("Spacer").visible], [false, false], "no element: both hidden")
	row.free()


func test_backdrop_looks() -> void:
	var B := preload("res://ui/element_backdrop.gd")
	for id in ["water", "fire", "metal", "earth", "wood"]:
		check(B.LOOKS.has(id), "%s has its own backdrop" % id)
	eq(B.look("void"), B.PLAIN, "an unknown element: the plain one")
	var water: Color = B.look("water")["bottom"]
	var fire: Color = B.look("fire")["bottom"]
	check(water.b > water.r and fire.r > fire.b, "water blue, fire red")
	var b = B.new()
	b.size = Vector2(300, 200)
	b.radius = 20.0
	eq(b._span(100.0), Vector2(0, 300), "the middle: the full width")
	check(b._span(0.0).x > 19.0 and b._span(0.0).y < 281.0, "the top row: inside the round corners")
	for p in b._inside_ellipse(Vector2(150, 210), Vector2(260, 140)):
		var sp: Vector2 = b._span(p.y)
		check(p.y >= 0.0 and p.y <= 200.0 and p.x >= sp.x - 0.01 and p.x <= sp.y + 0.01, "the glow stays inside")
	b.free()
