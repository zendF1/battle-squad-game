extends "res://tests/test_case.gd"
## Damage numbers by a damage event's elementEffect (match/views/damage_popup.gd style(),
## damage_tally.gd): "strong" bigger, warm gold-orange, the "Khắc hệ!" tag, a harder pop; "weak"
## smaller and greyish blue; none the usual red / critical gold.

const DamagePopup := preload("res://match/views/damage_popup.gd")
const DamageTally := preload("res://match/views/damage_tally.gd")


func test_styles() -> void:
	var plain := DamagePopup.style("")
	var crit := DamagePopup.style("", true)
	var strong := DamagePopup.style("strong")
	var weak := DamagePopup.style("weak")
	eq([plain["color"], crit["color"]], [DamagePopup.RED, DamagePopup.CRIT], "no effect: red, critical gold")
	check(int(strong["font_size"]) > int(plain["font_size"]) and int(weak["font_size"]) < int(plain["font_size"]), "strong bigger, weak smaller")
	eq([strong["tag"], plain["tag"], weak["tag"]], ["Khắc hệ!", "", ""], "only strong is tagged")
	var sc: Color = strong["color"]
	check(sc.r > 0.9 and sc.g > 0.45 and sc.g < 0.8 and sc.b < 0.3, "strong: warm gold-orange")
	var wc: Color = weak["color"]
	check(wc.b > wc.r and wc.s < 0.35, "weak: greyish blue")
	check(float(strong["pop"]) > float(plain["pop"]) and float(weak["pop"]) < float(plain["pop"]), "strong pops harder")
	eq(DamagePopup.style("strong", true)["color"], sc, "strong wins over critical")


func test_effect_of_event() -> void:
	eq(DamagePopup.effect_of({"type": "damage", "elementEffect": "strong"}), "strong", "strong")
	eq(DamagePopup.effect_of({"type": "damage", "elementEffect": "weak"}), "weak", "weak")
	eq(DamagePopup.effect_of({"type": "damage"}), "", "omitempty: none")
	eq(DamagePopup.effect_of({"elementEffect": "odd"}), "", "an unknown value: none")
	eq(DamagePopup.effect_of({"elementEffect": null}), "", "null")


func test_popup_tag() -> void:
	var p := DamagePopup.new()
	p.text = "-1.250"
	p.set_style(DamagePopup.style("strong"))
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	root.add_child(p)
	if p.tag() == null:
		p._ready() # the runner's _initialize does not send READY yet
	check(p.tag() != null and p.tag().text == "Khắc hệ!", "the tag over a strong number")
	eq(p.get_theme_font_size("font_size"), DamagePopup.STRONG_FONT, "its size")
	var w := DamagePopup.new()
	w.set_style(DamagePopup.style("weak"))
	root.add_child(w)
	if w.get_theme_font_size("font_size") != DamagePopup.WEAK_FONT:
		w._ready()
	eq(w.get_theme_font_size("font_size"), DamagePopup.WEAK_FONT, "weak size")
	check(w.tag() == null, "no tag on a weak one")
	eq(w.get_theme_color("font_color"), DamagePopup.WEAK, "weak colour")
	root.free()


func test_tally_effect() -> void:
	var t := DamageTally.new()
	t.add(100, false, "weak")
	eq(t.effect, "weak", "all weak so far")
	t.add(100, false, "")
	eq(t.effect, "", "a plain hit: plain")
	t.add(100, false, "strong")
	eq(t.effect, "strong", "a strong hit makes it strong")
	t.add(100, false, "weak")
	eq([t.effect, t.total], ["strong", 400], "stays strong, counts up")
	t.free()
