extends "res://tests/test_case.gd"
## The explosion's colours follow the shell (ShotLook.burst_palette(), ExplosionFx).

const ShotLook := preload("res://match/views/shot_look.gd")
const ExplosionFx := preload("res://match/views/explosion_fx.gd")
const Art := preload("res://ui/art.gd")

## The kinds with their own tier shells (the blaster's bolt is tinted instead).
const SHELL_KINDS := ["bazooka", "cannon", "shock_rifle", "seed_launcher"]
## Share of a shell's opaque pixels that must be near its palette's body colour.
const BODY_SHARE := 0.25
const BODY_DIST := 0.15


func _fx(kind: String, tier: String, lite: bool = false) -> Node2D:
	var fx: Node2D = ExplosionFx.new()
	fx.kind = kind
	fx.tier = tier
	fx.lite = lite
	fx._ready() # not in the tree
	return fx


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## The share of the shell picture's opaque pixels within BODY_DIST of colour c.
func _share_near(path: String, c: Color) -> float:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return 0.0
	img.convert(Image.FORMAT_RGBA8)
	var n := 0
	var near_n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var p := img.get_pixel(x, y)
			if p.a < 0.5:
				continue
			n += 1
			if _dist(p, c) < BODY_DIST:
				near_n += 1
	return float(near_n) / maxf(1.0, n)


func test_palette_per_kind_and_tier_from_the_shells() -> void:
	for kind in SHELL_KINDS:
		var outers: Array = []
		for tier in Art.GUN_NORMAL_TIERS:
			var name: String = "%s %s" % [kind, tier]
			check(Art.tier_projectile(kind, tier) != null, name + ": has its shell picture")
			var pal := ShotLook.burst_palette(kind, tier)
			for key in ShotLook.BURST_KEYS + ["smoke_color"]:
				check(pal.has(key), "%s: palette has %s" % [name, key])
			if pal.is_empty():
				continue
			var share := _share_near(Art.tier_projectile_path(kind, tier), pal["body"])
			check(share >= BODY_SHARE, "%s: body colour is the shell's (%.0f%% of it)" % [name, share * 100.0])
			check(Color(pal["core"]).get_luminance() > Color(pal["mid"]).get_luminance() and Color(pal["mid"]).get_luminance() > Color(pal["outer"]).get_luminance(),
				name + ": the ramp brightens to its core")
			check(Color(pal["outer"]).get_luminance() > Color(pal["smoke"]).get_luminance(), name + ": smoke is the ramp's dark end")
			for o in outers:
				check(_dist(o, pal["outer"]) > 0.15, name + ": its burst differs from the kind's other tiers")
			outers.append(pal["outer"])
			check(_dist(pal["outer"], ShotLook.KINDS[kind]["color"]) > 0.1 or tier == "dragon", name + ": not the kind's own colour")
		eq(ShotLook.burst_palette(kind, "iron"), ShotLook.burst_palette(kind, "iron"), kind + ": cached")
		check(is_same(ShotLook.burst_palette(kind, "iron"), ShotLook.burst_palette(kind, "iron")), kind + ": computed once")


func test_tier_families() -> void:
	for kind in ["bazooka", "cannon"]:
		var iron := ShotLook.burst_palette(kind, "iron")
		var core: Color = iron["core"]
		var mid: Color = iron["mid"]
		check(core.get_luminance() > 0.95 and core.s < 0.1, kind + " iron: a white-hot metallic core")
		check(mid.get_luminance() > 0.8 and mid.s < 0.15, kind + " iron: light steel, not a muddy grey")
	for kind in SHELL_KINDS:
		var ice := ShotLook.burst_palette(kind, "mithril")
		var outer: Color = ice["outer"]
		check(outer.b > outer.r + 0.3 and outer.g > outer.r + 0.3, kind + " mithril: icy cyan")
		check(Color(ice["core"]).get_luminance() > 0.97, kind + " mithril: white core")
		var lava := ShotLook.burst_palette(kind, "dragon")
		var red: Color = lava["outer"]
		check(red.r > 3.0 * red.g and red.r > 3.0 * red.b, kind + " dragon: deep red rim")
		check(bool(lava["lava"]) and Color(lava["smoke"]).get_luminance() < 0.15, kind + " dragon: lava, dark smoke")
	var purple := ShotLook.burst_palette("shock_rifle", "steel")
	check(Color(purple["mid"]).b > Color(purple["mid"]).g + 0.3, "steel shock rifle: purple like its orb")
	var orange := ShotLook.burst_palette("cannon", "steel")
	check(Color(orange["mid"]).r > Color(orange["mid"]).b + 0.5, "steel cannon: orange like its ball")


func test_basic_unchanged() -> void:
	for kind in ShotLook.KINDS:
		eq(ShotLook.burst_palette(kind, "basic"), {}, kind + " basic: no palette")
		var fx := _fx(kind, "basic")
		eq(fx.material, null, kind + " basic: no recolour material")
		check(fx._accent.is_equal_approx(ShotLook.accent(kind, "basic")), kind + " basic: the kind's accent")
		check(fx._smoke_color.is_equal_approx(ShotLook.KINDS[kind]["impact"]["smoke_color"]), kind + " basic: the kind's smoke")
		for d in fx._debris:
			var c: Color = d[2]
			var ok := false
			for k in ShotLook.KINDS[kind]["impact"]["colors"]:
				ok = ok or c.is_equal_approx(Color(k) * (ShotLook.accent(kind, "basic") if float(ShotLook.KINDS[kind]["body_tint"]) > 0.0 else Color.WHITE))
			check(ok, kind + " basic: the kind's debris colours")
		fx.free()
	eq(ShotLook.burst_palette("ray_gun", "mythic"), {}, "unknown kind / tier: basic bazooka, no palette")


func test_missing_shell_falls_back_to_the_kind_colours() -> void:
	for tier in Art.GUN_NORMAL_TIERS:
		eq(ShotLook.burst_palette_for("cannon", tier, false), {}, "cannon %s without its shell picture: the kind's colours" % tier)
		check(not ShotLook.burst_palette_for("cannon", tier, true).is_empty(), "cannon %s with it: its palette" % tier)
		var blaster_has := Art.tier_projectile("blaster", tier) != null
		if not blaster_has:
			eq(ShotLook.burst_palette("blaster", tier), {}, "blaster %s (no shell picture): the accent colours" % tier)
			var fx := _fx("blaster", tier)
			eq(fx.material, null, "blaster %s: no recolour material" % tier)
			check(fx._accent.is_equal_approx(ShotLook.accent("blaster", tier)), "blaster %s: the bolt's accent" % tier)
			fx.free()


func test_crafted_keep_their_impact_features() -> void:
	for tier in Art.GUN_CRAFTED_TIERS:
		var pal := ShotLook.burst_palette("blaster", tier)
		check(not pal.is_empty(), tier + ": its own palette")
		check(_dist(pal["body"], ShotLook.TIERS[tier]["color"]) < 0.05, tier + ": from its shell's colour")
		check(_dist(pal["spark2"], ShotLook.TIERS[tier]["color2"]) < 0.15 or _dist(pal["spark2"], ShotLook.TIERS[tier]["color"]) < 0.15, tier + ": second colour from the tier")
	var silver := _fx("blaster", "silver")
	check(silver.material != null and int(silver._ti["rings"]) == 1 and silver._sparkles.size() > 0 and float(silver._ti["flare"]) > 0.0, "silver: ring, sparkles, flare")
	var gold := _fx("blaster", "gold")
	check(gold._coins.size() > 0 and float(gold._ti["screen"]) > 0.0, "gold: coins and the screen tint")
	var titan := _fx("blaster", "titan")
	check(int(titan._ti["rings"]) == 2 and bool(titan._ti["crack"]) and titan._embers.size() > 0, "titan: double ring, cracks, embers")
	var diamond := _fx("blaster", "diamond")
	check(diamond._prismatic and diamond._shards.size() > 0 and diamond._life > ExplosionFx.LIFE, "diamond: prism, shards, lingering sparkles")
	check(diamond._accent.is_equal_approx(ShotLook.burst_palette("blaster", "diamond")["flash"]), "diamond: its flash in the shell's ice blue")
	for fx in [silver, gold, titan, diamond]:
		fx.free()


func test_explosion_takes_the_palette() -> void:
	var fx := _fx("cannon", "dragon")
	var pal := ShotLook.burst_palette("cannon", "dragon")
	var m: ShaderMaterial = fx.material
	check(m != null and m == ExplosionFx.burst_material("cannon", "dragon"), "one cached material per kind × tier")
	check(Color(m.get_shader_parameter("core_c")).is_equal_approx(pal["core"]) and Color(m.get_shader_parameter("outer_c")).is_equal_approx(pal["outer"]), "the frames' ramp")
	var lum: Array = ShotLook.KINDS["cannon"]["impact"]["lum"]
	check(Vector2(m.get_shader_parameter("lum")).is_equal_approx(Vector2(lum[0], lum[1])), "the kind's luminance range")
	check(fx._accent.is_equal_approx(pal["flash"]), "flash in the palette")
	check(fx._smoke_color.is_equal_approx(pal["smoke_color"]) and not fx._smoke_color.is_equal_approx(ShotLook.KINDS["cannon"]["impact"]["smoke_color"]), "smoke tinted")
	var lava := 0
	var bits := 0
	for e in fx._embers:
		lava += 1 if float(e[5]) >= 1.0 else 0
	for d in fx._debris:
		for b in pal["bits"]:
			bits += 1 if Color(d[2]).is_equal_approx(b) else 0
	check(lava > 0 and lava < fx._embers.size(), "dragon: some embers are heavy lava blobs")
	check(bits > 0 and bits < fx._debris.size(), "lava and charred bits among the dirt")
	fx.free()
	var shock := _fx("shock_rifle", "steel")
	var sp := ShotLook.burst_palette("shock_rifle", "steel")
	for d in shock._debris:
		check([sp["spark"], sp["spark2"], sp["mid"]].has(d[2]), "shock sparks in the palette")
	shock.free()
	for kind in SHELL_KINDS:
		var a := _fx(kind, "mithril")
		var b := _fx(kind, "mithril", true)
		check(a.material != null and a.material == b.material, kind + ": the rain's lite burst takes the palette too")
		a.free()
		b.free()
	check(ExplosionFx.burst_material("bazooka", "basic") == null and ExplosionFx.burst_material("blaster", "iron") == null, "no material without a palette")
