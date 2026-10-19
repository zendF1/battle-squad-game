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
