extends "res://tests/test_case.gd"
## The title plate (ui/title_plate.gd): rarity → texture, the imported layouts, sizing a short
## and a long name (the stretch ranges widen, the ends keep their size, max_width shrinks the
## font), no plate without a title, and the shine on purple / red only.

const TitlePlate := preload("res://ui/title_plate.gd")
const Art := preload("res://ui/art.gd")

const LONG := "Bậc thầy chiến trường"


func test_rarity_to_texture() -> void:
	for r in Art.TITLE_RARITIES:
		eq(Art.title_path(r), "res://assets/ui/titles/title_%s.png" % r, "%s path" % r)
		check(FileAccess.file_exists(Art.title_path(r)), "%s plate exists" % r)
		check(Art.title_texture(r) != Art.placeholder(), "%s plate loads" % r)
	eq(Art.title_rarity("gold"), "blue", "unknown rarity → blue")
	eq(Art.title_path(""), Art.title_path("blue"), "missing rarity → blue")


func test_layouts_match_the_textures() -> void:
	for r in Art.TITLE_RARITIES:
		var m := Art.title_meta(r)
		var tex := Art.title_texture(r)
		eq(m["size"], Vector2(tex.get_width(), tex.get_height()), "%s size" % r)
		check(not m["stretch"].is_empty(), "%s has stretch ranges" % r)
		var box: Rect2 = m["text"]
		check(box.position.x > 0 and box.end.x < m["size"].x and box.position.y > 0 and box.end.y < m["size"].y, "%s text box inside" % r)
		var last := 0.0
		for s in m["stretch"]:
			check(s.x >= last and s.y > s.x and s.y <= m["size"].x, "%s stretch ranges ordered" % r)
			check(s.x > box.position.x - 10 and s.y < box.end.x + 10, "%s stretch inside the name's panel" % r)
			last = s.y
	eq(Art.title_meta("red")["stretch"].size(), 2, "red: two runs, the crown between them stays")


func test_short_name_keeps_the_plate() -> void:
	var m := Art.title_meta("blue")
	var l := TitlePlate.layout(m, "Lão làng", 50.0, 0.0, 0, TitlePlate.font())
	var s: float = 50.0 / m["size"].y
	near(l["size"].x, m["size"].x * s, 0.01, "native width")
	eq(l["extra"], 0.0, "no widening")
	eq(l["size"].y, 50.0, "height")
	check(l["font_size"] >= 14 and l["font_size"] <= 22, "font from the box: %d" % l["font_size"])


func test_long_name_widens_only_the_stretch() -> void:
	for r in Art.TITLE_RARITIES:
		var m := Art.title_meta(r)
		var f := TitlePlate.font()
		var l := TitlePlate.layout(m, LONG, 50.0, 0.0, 0, f)
		var s: float = 50.0 / m["size"].y
		check(l["extra"] > 0.0, "%s widened" % r)
		near(l["size"].x, m["size"].x * s + l["extra"], 0.01, "%s width = native + extra" % r)
		var need: float = f.get_string_size(LONG, HORIZONTAL_ALIGNMENT_LEFT, -1, l["font_size"]).x
		check(l["text_rect"].size.x >= need, "%s the name fits its box" % r)
		# The pieces: fixed ones at the plate's scale, stretched ones share the extra
		var fixed_w := 0.0
		var drawn := 0.0
		for p in l["pieces"]:
			drawn += p[1].size.x
			var stretched := false
			for st in m["stretch"]:
				if is_equal_approx(p[0].position.x, st.x) and is_equal_approx(p[0].end.x, st.y):
					stretched = true
			if not stretched:
				near(p[1].size.x, p[0].size.x * s, 0.01, "%s end piece unscaled" % r)
				fixed_w += p[1].size.x
		near(drawn, l["size"].x, 0.01, "%s pieces cover the plate" % r)
		near(l["pieces"][0][0].position.x, 0.0, 0.01, "%s from the left edge" % r)
		near(l["pieces"][-1][0].end.x, m["size"].x, 0.01, "%s to the right edge" % r)


func test_max_width_shrinks_the_font() -> void:
	var m := Art.title_meta("purple")
	var f := TitlePlate.font()
	var free := TitlePlate.layout(m, LONG, 50.0, 0.0, 0, f)
	var capped := TitlePlate.layout(m, LONG, 50.0, free["size"].x - 40.0, 0, f)
	check(capped["size"].x <= free["size"].x - 40.0 + 0.01, "within max width")
	check(capped["font_size"] < free["font_size"], "smaller font")
	var tiny := TitlePlate.layout(m, LONG, 50.0, 10.0, 0, f)
	check(tiny["font_size"] >= TitlePlate.MIN_FONT and tiny["font_size"] < capped["font_size"], "shrinks until it fits, never below the minimum: %d" % tiny["font_size"])
	var never := TitlePlate.layout(m, LONG + " " + LONG + " " + LONG, 50.0, 10.0, 0, f)
	eq(never["font_size"], TitlePlate.MIN_FONT, "stops at the minimum")
	near(tiny["size"].x, m["size"].x * 50.0 / m["size"].y, 0.01, "max width under the native width: native")
	var fixed := TitlePlate.layout(m, "Cao thủ", 26.0, 0.0, 12, f)
	eq(fixed["font_size"], 12, "an explicit font size")


func test_node_sizes_and_none() -> void:
	var p := TitlePlate.new()
	p.plate_height = 40
	p.set_title({})
	check(not p.has_title() and not p.visible, "no title: hidden")
	eq(p.custom_minimum_size, Vector2.ZERO, "no title: no room")
	p.set_title({"id": "old_hand", "name": "Lão làng", "rarity": "orange"})
	check(p.has_title() and p.visible, "shown")
	eq(p.rarity(), "orange", "rarity")
	eq(p.custom_minimum_size, p.plate_size(), "min size = plate")
	near(p.plate_size().y, 40.0, 0.01, "height")
	check(p.name_font_size() > 0, "font")
	var w := p.plate_size().x
	p.set_title({"id": "battle_master", "name": LONG, "rarity": "orange"})
	check(p.plate_size().x > w, "a longer name widens it")
	p.set_title({"id": "x", "name": "Không rõ", "rarity": "rainbow"})
	eq(p.rarity(), "blue", "unknown rarity draws blue")
	p.free()


func test_shine_on_purple_and_red_only() -> void:
	for c in [["blue", false], ["orange", false], ["purple", true], ["red", true]]:
		var p := TitlePlate.new()
		p.set_title({"id": "t", "name": "Cao thủ", "rarity": c[0]})
		var banner: Control = p.get_child(0)
		eq(banner.material != null, c[1], "%s shine" % c[0])
		p.shine = false
		check(banner.material == null, "%s shine off" % c[0])
		p.free()


func _player(p: Dictionary) -> Node2D:
	var holder := Node2D.new()
	var v: Node2D = load("res://match/views/player_view.gd").new()
	holder.add_child(v)
	var base := {"playerId": "p", "teamId": 1, "characterId": "rookie", "hp": 100, "maxHp": 100, "isAlive": true, "position": {"x": 0.0, "y": 0.0}}
	base.merge(p, true)
	v.setup(base, false, 1)
	return v


func test_match_player_plate() -> void:
	var v := _player({"title": {"id": "grandmaster", "name": "Cao thủ", "rarity": "red"}})
	eq(v.title(), {"id": "grandmaster", "name": "Cao thủ", "rarity": "red"}, "worn title shown")
	var plate: Control = v._title
	var name_label: Control = v._name
	check(plate.visible, "plate visible")
	check(plate.position.y + plate.size.y <= name_label.position.y + 4, "above the name")
	check(plate.plate_size().x <= v.TITLE_MAX_W + 0.01, "small: within %d px" % v.TITLE_MAX_W)
	check(v._status.position.y + v._status.size.y <= plate.position.y + 4, "the status markers above the plate")
	var bar_top: float = -v._art_top - 12 - 2
	check(plate.position.y + (plate.size.y + plate.plate_size().y) / 2.0 < bar_top, "clear of the HP bar")
	v.get_parent().free()
	var bot := _player({"playerId": "bot", "isBot": true})
	eq(bot.title(), {}, "a bot: none")
	check(not bot._title.visible, "no empty plate")
	eq(bot._title_rise, 0.0, "nothing raised")
	bot.get_parent().free()
	var odd := _player({"title": {"id": "x"}})
	eq(odd.title(), {}, "malformed: none")
	odd.get_parent().free()
