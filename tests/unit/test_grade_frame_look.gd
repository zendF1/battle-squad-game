extends "res://tests/test_case.gd"

const GradeLook := preload("res://screens/ranked/grade_look.gd")
const GradePedestal := preload("res://screens/ranked/grade_pedestal.gd")


func test_tiers_by_group() -> void:
	eq(GradeLook.tier_of(""), -1, "no badge: no tier")
	eq(GradeLook.tier_of("trung_si"), 0, "enlisted")
	eq(GradeLook.tier_of("hoc_vien"), 1, "cadets with the officers")
	eq(GradeLook.tier_of("dai_uy"), 1, "company officers")
	eq(GradeLook.tier_of("dai_ta"), 2, "field officers")
	eq(GradeLook.tier_of("thuong_tuong"), 3, "generals")
	eq(GradeLook.tier_of("not_a_grade"), -1, "a grade outside the ladder: plain")


func test_no_badge_is_plain() -> void:
	eq(GradeLook.look(""), {}, "no look without a badge")
	eq(GradeLook.palette(""), {}, "no palette without a badge")
	var mat := ShaderMaterial.new()
	mat.shader = GradeLook.face_shader()
	GradeLook.set_face(mat, "")
	eq(mat.get_shader_parameter("ranked"), 0.0, "the plain face")
	GradeLook.set_face(mat, "dai_ta")
	eq(mat.get_shader_parameter("ranked"), 1.0, "a badge holder's background")
	eq(mat.get_shader_parameter("b1"), GradeLook.PALETTES[2]["b1"], "the tier's colours")


func test_palette_per_tier() -> void:
	eq(GradeLook.palette("binh_nhi"), GradeLook.PALETTES[0], "green")
	eq(GradeLook.palette("thieu_uy"), GradeLook.PALETTES[1], "silver")
	eq(GradeLook.palette("thieu_ta"), GradeLook.PALETTES[2], "gold")
	eq(GradeLook.palette("dai_tuong"), GradeLook.PALETTES[3], "red-gold")
	var pal: Dictionary = GradeLook.PALETTES[2]
	eq(GradeLook.metal(pal, 0.0), pal["hi"], "the metal starts light")
	check(GradeLook.metal(pal, 0.6).is_equal_approx(pal["lo"]), "dark in the middle")
	eq(GradeLook.metal(pal, 1.0), pal["hi"], "light again at the end")


## The tiers escalate by shape: each adds ornaments the one below has none of.
func test_shapes_escalate_by_tier() -> void:
	var e := GradeLook.look("trung_si")
	var o := GradeLook.look("dai_uy")
	var f := GradeLook.look("dai_ta")
	var g := GradeLook.look("thuong_tuong")
	check(not e["gems"] and e["glow"] == 0.0 and e["leaves"] == 0 and e["dais_tiers"] == 1, "enlisted: plain rim and medallion, one-tier dais")
	check(o["gems"] and o["glow"] > 0.0 and o["leaves"] > 0 and o["dais_tiers"] == 2 and o["wing"] == 0.0, "officers: gems, glow, laurel, two tiers, no wings")
	check(f["wing"] > 0.0 and f["plate"] > 0.0 and f["plate_stars"] == 1 and f["dais_glow"] > 0.0 and not f["red_band"], "field: wings, a one-star plate, a glowing dais")
	check(g["red_band"] and g["corner_stars"] > 0 and g["wing_star"] and g["ribbon"] and g["rays"] > 0 and g["dais_red"], "generals: red band, stars, ribbon, rays, red dais")
	for pair in [[e, o], [o, f], [f, g]]:
		check(pair[1]["rim"] > pair[0]["rim"] and pair[1]["bracket_len"] > pair[0]["bracket_len"] and pair[1]["glow"] > pair[0]["glow"],
			"a thicker rim, longer brackets, more glow up the tiers")
	eq([e["rim"], o["rim"], f["rim"], g["rim"]], [4.0, 6.0, 7.0, 8.0], "the preview's rims")
	eq([e["sparkles"], o["sparkles"], f["sparkles"], g["sparkles"]], [0, 4, 8, 14], "the preview's sparkles at its grades")


## Inside a tier each step adds a little (GradeBadge.marks_of).
func test_steps_inside_a_tier() -> void:
	check(GradeLook.look("thuong_si")["bracket_len"] > GradeLook.look("binh_nhi")["bracket_len"], "enlisted: longer brackets")
	check(GradeLook.look("dai_uy")["leaves"] > GradeLook.look("hoc_vien")["leaves"], "officers: more laurel")
	check(GradeLook.look("dai_ta")["leaves"] > GradeLook.look("thieu_ta")["leaves"], "field: more laurel")
	check(GradeLook.look("dai_ta")["glow"] > GradeLook.look("thieu_ta")["glow"], "field: more glow")
	var low := GradeLook.look("thieu_tuong")
	var high := GradeLook.look("dai_tuong")
	check(high["rays"] > low["rays"] and high["plate_stars"] > low["plate_stars"], "generals: more rays and plate stars")
	eq([low["plate_stars"], GradeLook.look("thuong_tuong")["plate_stars"], high["plate_stars"]], [1, 3, 4], "a general's plate: the grade's stars")
	eq(GradeLook.look("thuong_tuong")["rays"], 12, "the preview's twelve rays")


func test_shapes_helpers() -> void:
	var rr := GradeLook.round_rect(Rect2(0, 0, 100, 60), 10.0)
	eq(rr[0], rr[rr.size() - 1], "the rounded rect path is closed")
	near(rr[0].x, 50.0, 0.001, "it starts at the top edge's middle")
	var b := GradeLook.bounds(rr)
	check(b.grow(0.01).encloses(Rect2(0.5, 0.5, 99, 59)) and Rect2(-0.01, -0.01, 100.02, 60.02).encloses(b), "it stays in the rect")
	var arc := GradeLook.ellipse(Vector2.ZERO, 10, 5, 4, 0.0, PI)
	eq(arc.size(), 5, "an arc has both ends")
	near(arc[2].y, 5.0, 0.001, "the front half is below the centre")


func test_pedestal_without_badge_draws_nothing() -> void:
	var c := Control.new()
	check(not GradePedestal.draw(c, Vector2.ZERO, 100.0, ""), "no badge: the caller's plain dais")
	c.free()
