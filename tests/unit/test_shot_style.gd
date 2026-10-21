extends "res://tests/test_case.gd"

const ShotLook := preload("res://match/views/shot_look.gd")
const ProjectileView := preload("res://match/views/projectile_view.gd")
const Art := preload("res://ui/art.gd")
const EquipmentPainter := preload("res://tools/art/equipment_painter.gd")
const WeaponPainter := preload("res://tools/art/weapon_painter.gd")
const FxPainter := preload("res://tools/art/fx_painter.gd")

## The tiers from plainest to grandest.
const ORDER := ["basic", "iron", "steel", "mithril", "dragon", "silver", "gold", "titan", "diamond"]


func _p(character: String, weapon: Variant) -> Dictionary:
	return {"playerId": "p", "characterId": character, "weaponItemId": weapon}


func test_style_follows_the_gun() -> void:
	eq(ShotLook.style_for(_p("rookie", "rookie_weapon_lv30"), "weapon", ""), {"kind": "bazooka", "tier": "mithril", "skill": false, "item": ""}, "Mithril Bazooka")
	eq(ShotLook.style_for(_p("spark", "crafted_weapon_diamond"), "weapon", ""), {"kind": "blaster", "tier": "diamond", "skill": false, "item": ""}, "a crafted gun is a blaster, whoever holds it")
	eq(ShotLook.style_for(_p("tanko", "normal_weapon_lv20"), "weapon", ""), {"kind": "blaster", "tier": "steel", "skill": false, "item": ""}, "generic weapon: steel blaster")
	eq(ShotLook.style_for(_p("flora", "tanko_weapon_lv40"), "weapon", ""), {"kind": "cannon", "tier": "dragon", "skill": false, "item": ""}, "the gun decides, not the character")
	eq(ShotLook.style_for(_p("tanko", ""), "weapon", ""), {"kind": "cannon", "tier": "basic", "skill": false, "item": ""}, "no weapon: the character's basic gun")
	eq(ShotLook.style_for(_p("spark", null), "skill", ""), {"kind": "shock_rifle", "tier": "basic", "skill": true, "item": ""}, "bot (null weapon), skill shot")
	eq(ShotLook.style_for({}, "weapon", ""), {"kind": "bazooka", "tier": "basic", "skill": false, "item": ""}, "unknown shooter: basic bazooka")
	eq(ShotLook.style_for(_p("flora", "flora_weapon_lv10"), "item", "freeze_bomb"), {"kind": "seed_launcher", "tier": "iron", "skill": false, "item": "freeze_bomb"}, "item shot keeps the gun look")
	eq(ShotLook.style_for(_p("tanko", "crafted_weapon_gold"), "item", "air_strike"), {"kind": "bazooka", "tier": "basic", "skill": false, "item": "air_strike"}, "air strike drops plain bombs")
	eq(ShotLook.style_for(_p("rookie", ""), "weapon", "spider_net")["item"], "", "itemId ignored outside item shots")
	var catalog := {"items": {"w9": {"itemId": "w9", "slot": "weapon", "name": "Gold Blaster", "category": "crafted", "tier": "gold"}}}
	eq(ShotLook.style_for(_p("rookie", "w9"), "weapon", "", catalog), {"kind": "blaster", "tier": "gold", "skill": false, "item": ""}, "catalog entry")


func test_every_gun_kind_and_tier_has_a_look() -> void:
	for kind in Art.GUN_KINDS:
		check(ShotLook.KINDS.has(kind), "%s has a shot look" % kind)
		check(Art.SHOT_KINDS.has(kind), "%s has shot art" % kind)
	for kind in ShotLook.KINDS:
		check(Art.GUN_KINDS.has(kind), "look %s is a gun kind" % kind)
	eq(ShotLook.TIERS.keys(), ORDER, "tiers in rank order")
	for tier in [Art.GUN_BASIC] + Art.GUN_NORMAL_TIERS + Art.GUN_CRAFTED_TIERS:
		check(ShotLook.TIERS.has(tier), "tier %s has a look" % tier)
	eq(ShotLook.known_kind("ray_gun"), "bazooka", "unknown kind")
	eq(ShotLook.known_tier("mythic"), "basic", "unknown tier")
	for item in ProjectileView.ITEM_LOOKS:
		check(preload("res://match/items.gd").BY_ID.has(item), "item look %s is an item" % item)


func test_tiers_escalate() -> void:
	for i in range(1, ORDER.size()):
		var lo: Dictionary = ShotLook.TIERS[ORDER[i - 1]]
		var hi: Dictionary = ShotLook.TIERS[ORDER[i]]
		eq(int(hi["rank"]), i, "%s rank" % ORDER[i])
		check(float(hi["impact"]["scale"]) >= float(lo["impact"]["scale"]) or ORDER[i] == "silver", "%s impact not smaller than %s" % [ORDER[i], ORDER[i - 1]])
		check(float(hi["scale"]) >= float(lo["scale"]) or ORDER[i] == "silver", "%s projectile not smaller" % ORDER[i])
	var basic: Dictionary = ShotLook.TIERS["basic"]["impact"]
	var diamond: Dictionary = ShotLook.TIERS["diamond"]["impact"]
	check(float(diamond["scale"]) > float(ShotLook.TIERS["dragon"]["impact"]["scale"]), "diamond grander than dragon")
	eq([basic["rings"], basic["sparkles"], basic["flare"], basic["screen"]], [0, 0, 0.0, 0.0], "basic is plain")
	eq(ShotLook.TIERS["iron"]["trail_fx"], {}, "iron plain trail")
	check(ShotLook.TIERS["mithril"]["glow"] > 0.0 and ShotLook.TIERS["mithril"]["impact"]["sparkles"] > 0, "mithril glows and sparkles")
	check(ShotLook.TIERS["dragon"]["trail_fx"]["tex"] == "ember" and ShotLook.TIERS["dragon"]["impact"]["rings"] >= 1, "dragon embers and a shockwave")
	check(ShotLook.TIERS["gold"]["trail_fx"]["tex"] == "coin" and ShotLook.TIERS["gold"]["impact"]["coins"] > 0, "gold coins")
	check(ShotLook.TIERS["titan"]["impact"]["rings"] == 2 and ShotLook.TIERS["titan"]["impact"]["crack"] and ShotLook.TIERS["titan"]["impact"]["screen"] > 0.0, "titan double ring, cracks, screen tint")
	check(ShotLook.TIERS["diamond"]["prismatic"] and diamond["shards"] > 0 and diamond["flare"] >= 1.0 and diamond["linger"] > 0.0, "diamond shards, prism, flare, lingering sparkles")
	for tier in ShotLook.TIERS:
		var fx: Dictionary = ShotLook.TIERS[tier]["trail_fx"]
		if not fx.is_empty():
			check(Art.TIER_FX.has(fx["tex"]), "%s trail overlay %s is art" % [tier, fx["tex"]])


func test_tier_colours_come_from_the_gun_palettes() -> void:
	for tier in ShotLook.TIERS:
		var t: Dictionary = ShotLook.TIERS[tier]
		if tier == "basic":
			eq(t["color"], null, "basic keeps the kind's colour")
			continue
		var pal: Array = EquipmentPainter.TIERS[tier] + ([WeaponPainter.DRAGON_GLOW] if tier == "dragon" else [])
		check(pal.has(t["color"]), "%s colour from its palette" % tier)
		check(pal.has(t["color2"]) or t["color2"] == EquipmentPainter.GOLD, "%s second colour from its palette" % tier)
	eq(ShotLook.accent("bazooka", "basic"), ShotLook.KINDS["bazooka"]["color"], "basic accent")
	check(ShotLook.accent("blaster", "gold").is_equal_approx(ShotLook.KINDS["blaster"]["color"].lerp(ShotLook.TIERS["gold"]["color"], 0.9)), "gold accent")


func test_particles_stay_capped() -> void:
	for kind in ShotLook.KINDS:
		for tier in ShotLook.TIERS:
			for skill in [false, true]:
				var c := ShotLook.impact_counts(kind, tier, skill)
				var total := 0
				for g in ShotLook.PARTICLE_GROUPS:
					total += int(c[g])
				check(total <= ShotLook.MAX_IMPACT_PARTICLES, "%s %s skill=%s: %d particles" % [kind, tier, skill, total])
				check(ShotLook.impact_scale(kind, tier, skill) <= 2.0, "%s %s burst scale" % [kind, tier])
	check(ShotLook.TRAIL_KIND_CAP + ShotLook.TRAIL_TIER_CAP <= ShotLook.MAX_TRAIL_PARTICLES, "trail caps")
	var plain := ShotLook.impact_counts("cannon", "basic")
	eq([plain["smoke"], plain["bits"], plain["sparkles"]], [11, 24, 0], "basic cannon keeps its blast")
	check(ShotLook.impact_counts("bazooka", "diamond")["shards"] > 0, "diamond throws shards")
	check(ShotLook.impact_counts("bazooka", "gold", true)["coins"] > ShotLook.impact_counts("bazooka", "gold")["coins"], "a skill shot throws more")
	near(ShotLook.impact_life("basic", 1.1), 1.1, 0.001, "basic life")
	check(ShotLook.impact_life("diamond", 1.1) > 1.1, "diamond sparkles linger")


func test_shot_art() -> void:
	for kind in Art.SHOT_KINDS:
		for i in Art.EXPLOSION_FRAMES:
			var img := Image.load_from_file(ProjectSettings.globalize_path(Art.shot_path(kind, "impact_%d" % i)))
			check(img != null and img.get_size() == FxPainter.EXPLOSION_SIZE, "%s impact frame %d size" % [kind, i])
		var trail := Image.load_from_file(ProjectSettings.globalize_path(Art.shot_path(kind, "trail")))
		check(trail != null and trail.get_size() == FxPainter.SHOT_TRAIL_SIZE, "%s trail size" % kind)
	for fx_name in Art.TIER_FX:
		var img := Image.load_from_file(ProjectSettings.globalize_path(Art.tier_fx_path(fx_name)))
		check(img != null and img.get_size() == FxPainter.TIER_FX_SIZES.get(fx_name, Vector2i.ZERO), "tier overlay %s size" % fx_name)
	for kind in Art.SHOT_KINDS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(Art.shot_path(kind, "projectile")))
		check(img != null and img.get_size() == FxPainter.shot_projectile_size(kind), "%s projectile size" % kind)
	var rocket := Image.load_from_file(ProjectSettings.globalize_path(Art.shot_path("bazooka", "projectile")))
	check(rocket.get_width() >= rocket.get_height() * 2, "the bazooka's projectile is a long rocket")
	var bomb_img := Image.load_from_file(ProjectSettings.globalize_path(Art.FX["bomb"]))
	check(bomb_img != null and bomb_img.get_size() == FxPainter.BOMB_SIZE, "the round bomb is kept")
	var bomb := Art.fx("bomb")
	check(bomb != Art.placeholder(), "the bomb loads (imported or not yet)")
	check(Art.shot("nope", "projectile", bomb) == bomb, "unknown kind: fallback")
	eq(Art.shot_path("shock_rifle", "trail"), "res://assets/fx/shock_rifle/trail.png", "shot path")
	eq(Art.FX["bomb"], "res://assets/fx/common/bomb.png", "the bomb is a common effect, not the bazooka's")
	check(Art.FX["bomb"] != Art.shot_path("bazooka", "projectile"), "the bazooka fires a rocket")
	eq(Art.explosion_path(2), "res://assets/fx/bazooka/impact_2.png", "fallback impact is the bazooka's")
	eq(Art.tier_fx_path("ring"), "res://assets/fx/tiers/ring.png", "overlay path")
	eq(Art.tier_fx("nope"), null, "unknown overlay: left out")


func _view(kind: String, item: String = "", heading: Vector2 = Vector2.ZERO) -> Node2D:
	var v: Node2D = ProjectileView.new()
	v.kind = kind
	v.item = item
	v.heading = heading
	v._ready() # not in the tree
	return v


## Every projectile is drawn turned to its flight: the start heading before it moves, then the
## direction it moves in (a spinning kind turns on top of that).
func test_projectile_faces_its_flight() -> void:
	var v := _view("bazooka", "", Vector2(-3, -3))
	near(v.draw_angle(), Vector2(-1, -1).angle(), 1e-5, "faces its start heading")
	var plain := _view("bazooka")
	near(plain.draw_angle(), 0.0, 1e-6, "no heading: +x")
	v.position = Vector2(0, 10)
	v._process(0.016)
	near(v.draw_angle(), PI / 2, 1e-5, "falling: points down")
	v.position = Vector2(-10, 10)
	v._process(0.016)
	near(v.draw_angle(), PI, 1e-5, "then left")
	var pod := _view("seed_launcher", "", Vector2.RIGHT)
	pod._process(0.5)
	near(pod.draw_angle(), 0.5 * float(ShotLook.KINDS["seed_launcher"]["spin"]), 1e-4, "a pod spins on top")
	for view in [v, plain, pod]:
		view.free()


## The bazooka fires a rocket with an exhaust flame; an air strike drops the round bomb with its
## fuse; a kind with no picture of its own falls back to the bomb.
func test_rocket_and_bomb() -> void:
	var rocket := _view("bazooka")
	check(rocket._exhaust and not rocket._fuse, "rocket: exhaust, no fuse")
	check(rocket._tex != Art.fx("bomb"), "rocket: not the bomb")
	var strike := _view("bazooka", "air_strike")
	check(strike._tex == Art.fx("bomb"), "air strike: the bomb")
	check(strike._fuse and not strike._exhaust, "air strike: fuse, no exhaust")
	var frozen := _view("bazooka", "freeze_bomb")
	check(frozen._tex == rocket._tex and frozen._exhaust, "an item shot keeps the gun's rocket")
	var cannon := _view("cannon")
	check(not cannon._fuse and not cannon._exhaust, "cannon ball: neither")
	for view in [rocket, strike, frozen, cannon]:
		view.free()


## The rocket's trail is exhaust: born behind it, fire turning into grey smoke; the other kinds
## keep one colour.
func test_rocket_trail_turns_to_smoke() -> void:
	var t: Dictionary = ShotLook.KINDS["bazooka"]["trail"]
	check(float(t["back"]) > 0.0, "born behind the rocket")
	check(Color(t["hot"]).r > Color(t["cool"]).r and Color(t["hot"]).s > Color(t["cool"]).s, "hot fire to grey smoke")
	check(float(t["size"][1]) > float(t["size"][0]), "puffs grow")
	for kind in ShotLook.KINDS:
		if kind != "bazooka":
			check(not ShotLook.KINDS[kind]["trail"].has("hot"), "%s trail unchanged" % kind)
			check(not ShotLook.KINDS[kind]["exhaust"], "%s no exhaust" % kind)


func _flier(kind: String, tier: String, skill: bool = false) -> Node2D:
	var v: Node2D = ProjectileView.new()
	v.kind = kind
	v.tier = tier
	v.skill = skill
	v.heading = Vector2.RIGHT
	v._ready() # not in the tree
	return v


## The four normal tiers fly with their own theme; basic and the crafted tiers keep their trail.
func test_flight_themes_per_tier() -> void:
	eq(ShotLook.THEMES.keys(), ["iron", "steel", "mithril", "dragon"], "themed tiers")
	for tier in ["basic", "silver", "gold", "titan", "diamond", "mythic"]:
		eq(ShotLook.tier_theme(tier), {}, "%s: no theme" % tier)
		eq(ShotLook.trail_fx(tier), ShotLook.TIERS[ShotLook.known_tier(tier)]["trail_fx"], "%s keeps its trail" % tier)
	var iron := ShotLook.trail_fx("iron")
	check(iron["mode"] == "puff" and iron["tex"] == "smoke" and float(iron["size"][1]) > float(iron["size"][0]), "iron: grey smoke puffs that grow")
	check(Color(iron["color"]).s < 0.15 and Color(iron["color2"]).s < 0.15, "iron smoke is grey")
	var steel := ShotLook.trail_fx("steel")
	check(steel["mode"] == "streak" and float(steel["shed"][0]) > 0.0 and float(steel["gravity"]) > 0.0, "steel: falling spark streaks shed off the shell")
	check(Color(steel["color"]).v > 0.9 and Color(steel["color"]).h < 0.2, "steel sparks yellow-white")
	var mithril := ShotLook.tier_theme("mithril")
	eq(mithril["ribbon"]["style"], "light", "mithril: a light streak")
	eq(mithril["trail"]["tex"], "shard", "mithril: ice glints")
	check(Color(mithril["trail"]["color2"]).b > Color(mithril["trail"]["color2"]).r, "mithril glints icy blue")
	var dragon := ShotLook.tier_theme("dragon")
	eq(dragon["ribbon"]["style"], "fire", "dragon: a fire tail")
	eq(ShotLook.trail_fx("dragon")["tex"], "ember", "dragon keeps its embers")
	check(ShotLook.fire(1.0).v > 0.95 and ShotLook.fire(1.0).s < 0.3, "fire: a white-yellow core")
	check(ShotLook.fire(0.5).r > ShotLook.fire(0.5).b * 3.0, "fire: orange-red in the middle")
	check(ShotLook.fire(0.0).v < 0.3, "fire: dark smoke at the tail")
	for tier in ShotLook.THEMES:
		var fx := ShotLook.trail_fx(tier)
		for key in ["tex", "tex2"]:
			if fx.has(key):
				check(ProjectileView.overlay_texture(str(fx[key])) != null, "%s %s loads" % [tier, fx[key]])
		var rb: Dictionary = ShotLook.THEMES[tier]["ribbon"]
		if not rb.is_empty():
			check(int(rb["points"]) <= ShotLook.MAX_RIBBON_POINTS, "%s ribbon points capped" % tier)
	for tier in ShotLook.TIERS:
		var v := _flier("cannon", tier)
		eq(v._tier_fx, ShotLook.trail_fx(tier), "%s view flies its trail" % tier)
		eq(v._ribbon_spec.is_empty(), not ["mithril", "dragon"].has(tier), "%s ribbon" % tier)
		v.free()


## Flying fast and long, every kind × tier (skill too) stays within the trail caps; steel's sparks
## move off the shell, the other particles stay where they were born.
func test_trail_caps_every_kind_and_tier() -> void:
	for kind in ShotLook.KINDS:
		for tier in ShotLook.TIERS:
			for skill in [false, true]:
				var v := _flier(kind, tier, skill)
				for i in 120:
					v.position += Vector2(23.0, -4.0 + i * 0.1)
					v._process(1.0 / 60.0)
				var label := "%s %s skill=%s" % [kind, tier, skill]
				check(v._particles.size() <= ShotLook.TRAIL_KIND_CAP, label + ": kind trail capped")
				check(v._tier_particles.size() <= ShotLook.TRAIL_TIER_CAP, label + ": tier trail capped")
				check(v._particles.size() + v._tier_particles.size() <= ShotLook.MAX_TRAIL_PARTICLES, label + ": total capped")
				if not v._ribbon_spec.is_empty():
					check(v._ribbon.size() <= int(v._ribbon_spec["points"]) and v._ribbon.size() >= 2, label + ": ribbon kept")
				if ShotLook.tier_theme(tier).has("trail") or not ShotLook.TIERS[tier]["trail_fx"].is_empty():
					check(v._tier_particles.size() > 0, label + ": sheds its tier particles")
				var moving: int = v._tier_particles.filter(func(q): return q[4] != Vector2.ZERO).size()
				if tier == "steel":
					check(moving > 0, label + ": sparks thrown off")
				else:
					eq(moving, 0, label + ": particles stay put")
				v.free()


## A long jump (e.g. a teleport of the drawn shell) starts the ribbon again instead of filling it
## with points on a straight line; the points keep their spacing.
func test_ribbon_spacing() -> void:
	var v := _flier("bazooka", "dragon")
	var every := float(v._ribbon_spec["every"])
	for i in 10:
		v.position += Vector2(4.0, 0.0)
		v._process(1.0 / 60.0)
	for i in range(1, v._ribbon.size()):
		near(v._ribbon[i].distance_to(v._ribbon[i - 1]), every, 0.01, "ribbon step %d" % i)
	v.position += Vector2(5000.0, 0.0)
	v._process(1.0 / 60.0)
	check(v._ribbon.size() <= int(v._ribbon_spec["points"]), "a jump keeps the cap")
	near(v._ribbon[-1].x, v.position.x, every, "the tail restarts at the shell")
	v.free()


## A tier's own shell picture: assets/fx/<kind>/projectile_<tier>.png for the normal tiers only;
## missing → the kind's projectile.png, tinted as before.
func test_tier_projectile_paths_and_fallback() -> void:
	for kind in Art.SHOT_KINDS:
		for tier in Art.PROJECTILE_TIERS:
			eq(Art.tier_projectile_path(kind, tier), "res://assets/fx/%s/projectile_%s.png" % [kind, tier], "%s %s path" % [kind, tier])
	eq(Art.PROJECTILE_TIERS, ["iron", "steel", "mithril", "dragon"], "normal tiers")
	for tier in ["basic", "silver", "gold", "titan", "diamond"]:
		eq(Art.tier_projectile("bazooka", tier), null, "%s keeps projectile.png" % tier)
	eq(Art.tier_projectile("ray_gun", "iron"), null, "unknown kind")
	for kind in Art.SHOT_KINDS:
		for tier in Art.PROJECTILE_TIERS:
			if FileAccess.file_exists(Art.tier_projectile_path(kind, tier)):
				continue # the art is in: test_tier_projectile_drawn covers it
			eq(Art.tier_projectile(kind, tier), null, "%s %s missing: none" % [kind, tier])
			var v := _flier(kind, tier)
			check(not v._tier_body and v._tex == Art.shot(kind, "projectile", Art.fx("bomb")), "%s %s: the kind's projectile.png" % [kind, tier])
			check(v.body_size().is_equal_approx(v._tex.get_size() / ProjectileView.BOMB_PX), "%s %s: its size" % [kind, tier])
			check(v.body_color().is_equal_approx(Color.WHITE.lerp(ShotLook.accent(kind, tier), float(ShotLook.KINDS[kind]["body_tint"]))), "%s %s: tinted as before" % [kind, tier])
			v.free()


## With its own picture the shell is drawn untinted (only an item's tint), as big as the kind's
## projectile.png draws its shell whatever the picture's resolution (fitted, keeping its aspect).
func test_tier_projectile_drawn() -> void:
	var base := Vector2(44, 20)
	check(ProjectileView.fit_size(Vector2(352, 160), base).is_equal_approx(base), "4x picture: same size")
	check(ProjectileView.fit_size(Vector2(300, 300), base).is_equal_approx(Vector2(20, 20)), "square into a long rocket: fits the height")
	check(ProjectileView.fit_size(Vector2(500, 100), base).is_equal_approx(Vector2(44, 8.8)), "longer: fits the length")
	var pic := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	pic.fill(Color(1, 1, 1, 0))
	pic.fill_rect(Rect2i(2, 1, 4, 2), Color.WHITE)
	var drawn := ProjectileView.base_content(ImageTexture.create_from_image(pic))
	check(drawn.is_equal_approx(Vector2(4, 2)), "the drawn part of a picture: %s" % drawn)
	var own := ImageTexture.create_from_image(Image.create(352, 160, false, Image.FORMAT_RGBA8))
	var path := Art.tier_projectile_path("blaster", "dragon")
	var had: bool = Art._textures.has(path)
	var before = Art._textures.get(path)
	Art._textures[path] = own # as if the picture were in (loaded, cached)
	var v := _flier("blaster", "dragon")
	check(v._tier_body and v._tex == own, "the tier's picture")
	var plain := Art.shot("blaster", "projectile", Art.fx("bomb"))
	check(v.body_size().is_equal_approx(ProjectileView.fit_size(Vector2(352, 160), ProjectileView.base_content(plain) / ProjectileView.BOMB_PX)), "fitted into projectile.png's drawn part")
	eq(v.body_color(), Color.WHITE, "untinted (the blaster's bolt tint is for projectile.png only)")
	v.free()
	var item: Node2D = ProjectileView.new()
	item.kind = "blaster"
	item.tier = "dragon"
	item.item = "freeze_bomb"
	item._ready()
	eq(item.body_color(), ProjectileView.ITEM_LOOKS["freeze_bomb"]["tint"], "an item's tint still applies")
	item.free()
	var strike: Node2D = ProjectileView.new()
	strike.kind = "blaster"
	strike.tier = "dragon"
	strike.item = "air_strike"
	strike._ready()
	check(not strike._tier_body and strike._tex == Art.fx("bomb"), "an air strike drops the bomb")
	strike.free()
	if had:
		Art._textures[path] = before
	else:
		Art._textures.erase(path)


## The importer's pure parts: the white flood key, the edge alpha, the watermark finder, the fit.
func test_projectile_importer() -> void:
	var Imp := preload("res://tools/import_projectiles.gd")
	# A dark-outlined red box on white, with a white hole inside the outline (kept: not reached).
	var img := Image.create(40, 30, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	for y in range(8, 22):
		for x in range(10, 30):
			var outline := x < 12 or x >= 28 or y < 10 or y >= 20
			img.set_pixel(x, y, Color(0.08, 0.06, 0.06) if outline else Color(0.9, 0.2, 0.15))
	img.set_pixel(20, 15, Color.WHITE)
	var k: Image = Imp.white_keyed(img, 0.1, 0.6)
	eq(k.get_pixel(0, 0).a, 0.0, "the white background is transparent")
	eq(k.get_pixel(5, 15).a, 0.0, "beside the object too")
	near(k.get_pixel(20, 15).a, 1.0, 0.001, "white inside the outline is kept")
	near(k.get_pixel(15, 15).a, 1.0, 0.001, "the body opaque")
	var body := k.get_pixel(15, 15)
	check(absf(body.r - 0.9) < 0.01 and absf(body.g - 0.2) < 0.01 and absf(body.b - 0.15) < 0.01, "its colour kept")
	near(k.get_pixel(10, 15).a, 1.0, 0.01, "the dark outline at the edge stays opaque")
	near(Imp.edge_alpha(Color(0.7, 0.7, 0.7), 0.6), 0.5, 0.001, "a light grey edge px is half transparent")
	check(Imp.unmix_white(Color(0.5, 0.5, 0.5), 0.5).is_equal_approx(Color(0, 0, 0)), "un-mixed from white: black")
	var r: Rect2i = Imp.content_rect(k, 0.03, 2)
	eq(r, Rect2i(8, 6, 24, 18), "trimmed to the content plus the margin")
	# A grey star in the bottom-right corner is found; the object reaching the corner is not one.
	var wm := Image.create(200, 200, false, Image.FORMAT_RGB8)
	wm.fill(Color.WHITE)
	for y in range(182, 189):
		for x in range(182, 189):
			wm.set_pixel(x, y, Color(0.72, 0.72, 0.72))
	var found: Dictionary = Imp.found_watermark(wm, Color.WHITE, 0.16)
	check(not found.is_empty() and Vector2(found["centre"][0], found["centre"][1]).distance_to(Vector2(185.5, 185.5)) < 1.0, "the star's centre")
	Imp.paint_disc(wm, Vector2(found["centre"][0], found["centre"][1]), float(found["radius"]), Color.WHITE)
	eq(Imp.found_watermark(wm, Color.WHITE, 0.16), {}, "painted out")
	var black := Image.create(200, 200, false, Image.FORMAT_RGB8)
	black.fill(Color.BLACK)
	for y in range(185, 190):
		for x in range(180, 186):
			black.set_pixel(x, y, Color(0.5, 0.5, 0.52))
	check(not Imp.found_watermark(black, Color.BLACK, 0.16).is_empty(), "on black too")
	for y in range(150, 200):
		for x in range(150, 200):
			black.set_pixel(x, y, Color(0.6, 0.6, 0.6))
	eq(Imp.found_watermark(black, Color.BLACK, 0.16), {}, "something big in the corner: not a watermark")
	eq(Imp.found_watermark(Image.create(50, 50, false, Image.FORMAT_RGB8), Color.BLACK, 0.16), {}, "nothing there")
	check(Imp.fitted(Vector2(1000, 500), Vector2(352, 160)).is_equal_approx(Vector2(320, 160)), "scaled down to fit 4x")
	check(Imp.fitted(Vector2(100, 50), Vector2(352, 160)).is_equal_approx(Vector2(100, 50)), "never up")
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://art_source/fx/projectiles/projectiles.json"))
	check(cfg is Dictionary, "the config parses")
	for kind in Art.SHOT_KINDS:
		check(["solid", "glow"].has(cfg["modes"].get(kind, "")), "%s has a mode" % kind)
	eq(cfg["modes"]["shock_rifle"], "glow", "shock rifle on black")
	eq(cfg["modes"]["cannon"], "solid", "cannon on white")
	# Glow mode: a soft halo keeps its bright colour fading out (linear); a dark solid shell
	# stays opaque in its own dark colour (smoothstep).
	var lin := {"alphaCurve": "linear", "alphaFloor": 0.035, "alphaGamma": 1.0, "alphaBoost": 1.0}
	var smooth := {"alphaCurve": "smoothstep", "alphaLo": 0.03, "alphaHi": 0.22}
	eq(Imp.glow_alpha(0.02, lin), 0.0, "black: transparent")
	check(Imp.glow_alpha(0.3, lin) <= 0.3 and Imp.glow_alpha(0.3, lin) > 0.2, "a halo px stays see-through")
	near(Imp.glow_alpha(0.3, smooth), 1.0, 0.001, "the maroon shell opaque")
	eq(Imp.glow_alpha(0.02, smooth), 0.0, "black: transparent (smoothstep)")
	var px := Image.create(2, 1, false, Image.FORMAT_RGB8)
	px.set_pixel(0, 0, Color(0.0, 0.3, 0.3)) # cyan haze
	px.set_pixel(1, 0, Color(0.45, 0.05, 0.02)) # maroon shell
	var halo: Image = Imp.black_keyed(px, lin)
	check(halo.get_pixel(0, 0).g > 0.95 and halo.get_pixel(0, 0).a < 0.35, "the haze: bright cyan, faint")
	var shell: Image = Imp.black_keyed(px, smooth)
	check(shell.get_pixel(1, 0).a > 0.99 and absf(shell.get_pixel(1, 0).r - 0.45) < 0.01, "the shell: opaque, its own dark red")
	eq(cfg["files"]["shock_rifle_dragon"]["alphaCurve"], "smoothstep", "the lava orb keyed with the smoothstep")
	# Through the whole pipeline: keyed, trimmed and fitted.
	var big := Image.create(400, 300, false, Image.FORMAT_RGB8)
	big.fill(Color.WHITE)
	for y in range(100, 200):
		for x in range(50, 350):
			big.set_pixel(x, y, Color(0.05, 0.05, 0.05) if (x < 56 or x >= 344 or y < 106 or y >= 194) else Color(0.3, 0.5, 0.2))
	var done: Image = Imp.processed(big, "solid", cfg, {}, Vector2(176, 80))
	check(done.get_width() <= 176 and done.get_height() <= 80 and done.get_width() > 150, "fitted: %s" % done.get_size())
	near(done.get_pixel(0, 0).a, 0.0, 0.01, "its corner transparent")
	near(done.get_pixel(done.get_width() / 2, done.get_height() / 2).a, 1.0, 0.01, "its middle opaque")


## The imported bazooka, cannon, seed and shock shells: keyed (transparent corners, opaque body), about 4x
## the base picture, flying at its size, untinted.
func test_imported_tier_shells() -> void:
	for kind in ["bazooka", "cannon", "seed_launcher", "shock_rifle"]:
		_check_tier_shells(kind)
	check(float(ShotLook.KINDS["seed_launcher"]["tier_body_scale"]) > 1.0, "the long seeds drawn larger than the round pod's box")
	var ball := ProjectileView.base_content(Art.shot("cannon", "projectile", Art.fx("bomb")))
	check(ball.x < 50.0 and ball.x > 40.0, "the cannon ball's drawn part, not its 64 px frame: %s" % ball)


func _check_tier_shells(kind: String) -> void:
	var base := Image.load_from_file(ProjectSettings.globalize_path(Art.shot_path(kind, "projectile")))
	for tier in Art.PROJECTILE_TIERS:
		var path := Art.tier_projectile_path(kind, tier)
		check(FileAccess.file_exists(path), "%s %s shell imported" % [kind, tier])
		check(FileAccess.file_exists("res://art_source/fx/projectiles/%s_%s.png" % [kind, tier]), "%s %s source kept" % [kind, tier])
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		check(img.get_width() <= base.get_width() * 4 and img.get_height() <= base.get_height() * 4 and img.get_width() >= base.get_width() * 3, "%s %s about 4x: %s" % [kind, tier, img.get_size()])
		for corner in [Vector2i(0, 0), Vector2i(img.get_width() - 1, 0), Vector2i(0, img.get_height() - 1), Vector2i(img.get_width() - 1, img.get_height() - 1)]:
			eq(img.get_pixelv(corner).a, 0.0, "%s %s corner transparent" % [kind, tier])
		near(img.get_pixel(img.get_width() / 2, img.get_height() / 2).a, 1.0, 0.001, "%s %s body opaque" % [kind, tier])
		var v := _flier(kind, tier)
		check(v._tier_body, "%s %s flies its own shell" % [kind, tier])
		var box := ProjectileView.base_content(Art.shot(kind, "projectile", Art.fx("bomb"))) / ProjectileView.BOMB_PX * float(ShotLook.KINDS[kind].get("tier_body_scale", 1.0))
		check(v.body_size().x <= box.x + 0.01 and v.body_size().y <= box.y + 0.01 and (is_equal_approx(v.body_size().x, box.x) or is_equal_approx(v.body_size().y, box.y)), "%s %s as big as the base shell: %s in %s" % [kind, tier, v.body_size(), box])
		eq(v.body_color(), Color.WHITE, "%s %s untinted" % [kind, tier])
		eq(v._exhaust, kind == "bazooka", "%s %s keeps its exhaust" % [kind, tier])
		eq(v.body_color(), Color.WHITE, "%s %s: no blaster tint" % [kind, tier])
		v.free()
	for tier in ["basic", "gold", "diamond"]:
		var v := _flier(kind, tier)
		check(not v._tier_body, "%s %s keeps projectile.png" % [kind, tier])
		v.free()


## A ShotResolved-like timeline of one ballistic shell: start p0, velocity v0, gravity g, samples
## every 0.05 s for `dur` s.
func _arc(p0: Vector2, v0: Vector2, g: float, dur: float) -> Dictionary:
	var path: Array = []
	var t := 0.0
	while t <= dur + 1e-6:
		var p := p0 + v0 * t + Vector2(0, 0.5 * g * t * t)
		var v := v0 + Vector2(0, g * t)
		path.append({"time": t, "position": {"x": p.x, "y": p.y}, "velocity": {"x": v.x, "y": v.y}})
		t += 0.05
	return {"duration": dur, "projectiles": [{"projectileId": "p1", "path": path}], "events": []}


## Replayed by shot_player.gd along a real arc, the shell's nose follows the path's tangent going
## up, at the apex and coming down, both ways; flying left it is flipped so its top stays on top.
func test_nose_follows_the_curve() -> void:
	var ShotTimeline := preload("res://match/shot/shot_timeline.gd")
	var ShotPlayer := preload("res://match/shot/shot_player.gd")
	var g := 900.0
	for side in [1.0, -1.0]:
		for shot in [Vector2(300, -650), Vector2(620, -250)]: # a high lob, a flatter shot
			var v0 := Vector2(shot.x * side, shot.y)
			var apex := -v0.y / g
			var tl := ShotTimeline.new(_arc(Vector2(500, 600), v0, g, apex * 2.0))
			for kind_tier in [["bazooka", "dragon"], ["seed_launcher", "mithril"], ["blaster", "basic"], ["bazooka", "basic"]]:
				var sp := ShotPlayer.new()
				var layer := Node2D.new()
				sp.layer = layer
				sp.style = {"kind": kind_tier[0], "tier": kind_tier[1], "skill": false, "item": ""}
				sp.play(tl)
				var v: Node2D = layer.get_child(0)
				v._ready()
				var dt := 1.0 / 60.0
				var t := 0.0
				var checks := {0.25 * apex: "up", apex: "apex", 1.75 * apex: "down"}
				var label := "%s %s %s %s" % [kind_tier[0], kind_tier[1], "lob" if shot.y < -400 else "flat", "right" if side > 0 else "left"]
				var seen := 0
				while t < apex * 1.8:
					t += dt
					sp._process(dt)
					v._process(dt)
					for at in checks:
						if absf(t - at) < dt * 0.5:
							seen += 1
							var want := (v0 + Vector2(0, g * t)).angle()
							var got: float = v._dir.angle()
							check(absf(wrapf(got - want, -PI, PI)) < deg_to_rad(4.0), "%s %s: nose %.1f° vs path %.1f°" % [label, checks[at], rad_to_deg(got), rad_to_deg(want)])
							if v.spin_rate() == 0.0:
								near(wrapf(v.draw_angle() - want, -PI, PI), 0.0, deg_to_rad(4.0), "%s %s: drawn angle" % [label, checks[at]])
				eq(seen, 3, "%s: up, apex and down checked" % label)
				eq(v.flipped(), side < 0.0 and v.spin_rate() == 0.0, "%s: flipped when flying left" % label)
				sp.stop()
				sp.free()
				layer.free()


## The pointed per-tier seeds face their flight (no spin); the round basic pod keeps spinning;
## a shell flying left is drawn flipped vertically (never a spinning one).
func test_seed_spin_and_flip() -> void:
	var seed := _flier("seed_launcher", "mithril")
	check(seed._tier_body, "the mithril seed picture is in")
	eq(seed.spin_rate(), 0.0, "a per-tier seed does not spin")
	seed._process(0.5)
	near(seed.draw_angle(), 0.0, 1e-5, "it faces its flight")
	var pod := _flier("seed_launcher", "basic")
	eq(pod.spin_rate(), float(ShotLook.KINDS["seed_launcher"]["spin"]), "the basic pod spins")
	var left := _flier("bazooka", "iron")
	left.heading = Vector2(-1, 0.2)
	left._ready()
	check(left.flipped(), "flying left: flipped")
	left.heading = Vector2(1, 0.2)
	left._ready()
	check(not left.flipped(), "flying right: not flipped")
	pod.heading = Vector2(-1, 0)
	pod._ready()
	check(not pod.flipped(), "a spinning pod is never flipped")
	for v in [seed, pod, left]:
		v.free()


## A per-tier shell picture keeps a steady size (a fast size pulse reads as stutter); the basic
## plasma orb still pulses.
func test_tier_shell_does_not_pulse() -> void:
	var orb := _flier("shock_rifle", "dragon")
	check(orb._tier_body, "the dragon orb picture is in")
	var basic := _flier("shock_rifle", "basic")
	var steady := true
	var pulses := false
	for i in 12:
		orb._process(0.013)
		basic._process(0.013)
		steady = steady and orb.body_pulse() == 1.0
		pulses = pulses or absf(basic.body_pulse() - 1.0) > 0.01
	check(steady, "the dragon orb keeps its size")
	check(pulses, "the basic orb still pulses")
	for v in [orb, basic]:
		v.free()
