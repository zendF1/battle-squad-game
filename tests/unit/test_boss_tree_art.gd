extends "res://tests/test_case.gd"
## Mộc Tinh (tree_spirit)'s drawn art in a match (match/boss/boss_body.gd and friends): its constants
## (BossArt HEART / MUZZLE / TOP / WIDTH / ACCENT / DEATH, the heart's mint light), the points per frame
## (Art.boss_points(): canopy, rootTip, glow levels), the skin's mint heart, eyes, no hover, its skills'
## animations (BossAnim.action_for() with the recorded shots of tests/fixtures/boss_v5_shots.json and
## the game data of boss_gamedata.json), the muzzle on the canopy while the thorns shake out, the
## dragging root's tip (and RootDragFx joined to it), the idle's falling leaves and the wither.

const Art := preload("res://ui/art.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const BossAnim := preload("res://match/boss/boss_anim.gd")
const BossBody := preload("res://match/boss/boss_body.gd")
const BossSkinView := preload("res://match/boss/boss_skin_view.gd")
const SkinIdle := preload("res://match/boss/skin_idle.gd")
const RootDragFx := preload("res://match/boss/root_drag_fx.gd")
const FallingLeaves := preload("res://match/boss/falling_leaves.gd")
const SHOTS := "res://tests/fixtures/boss_v5_shots.json"
const GAMEDATA := "res://tests/fixtures/boss_gamedata.json"
const DT := 1.0 / 60.0


static func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## The tree's skill (game data fixture) by id.
static func _skill(id: String) -> Dictionary:
	for b in _json(GAMEDATA)["bosses"]:
		if str(b.get("bossId", "")) == "tree_spirit":
			for s in b["skills"]:
				if str(s["skillId"]) == id:
					return s
	return {}


static func _launches(shot: Dictionary) -> Array:
	var out: Array = []
	for p in shot.get("projectiles", []):
		var path: Array = p.get("path", [])
		out.append(float(path[0]["time"]) if not path.is_empty() else float(p.get("launchDelay", 0.0)))
	return out


func _tree(h: float = 200.0) -> BossBody:
	var b := BossBody.new()
	b.setup("tree_spirit", h)
	return b


## Plays anim on b and steps until its frame index shows (or a few s pass).
func _until_frame(b: BossBody, anim: String, index: int) -> void:
	for i in 300:
		if b.shown_frame() == [anim, index]:
			return
		b._process(DT)


func test_constants_of_the_drawn_tree() -> void:
	eq(BossArt.HEART["tree_spirit"], Vector2(0.85, -21.65), "the heart on the trunk under the mouth")
	eq(BossArt.MUZZLE["tree_spirit"], Vector2(0, -85.19), "the muzzle is the canopy")
	near(BossArt.top("tree_spirit"), 1.0, 1e-6, "the drawn canopy is its top")
	near(float(BossArt.WIDTH["tree_spirit"]), 1.067, 1e-6, "its width")
	eq(BossArt.death_of("tree_spirit"), "wither", "it withers")
	eq([BossArt.death_of("rock_giant"), BossArt.death_of("ice_witch"), BossArt.death_of("steel_robot")], ["crumble", "shatter", "crash"],
		"the others die as before")
	eq(BossArt.accent("tree_spirit"), BossArt.MINT, "its accent is the glows' mint")
	eq(BossArt.heart_light("tree_spirit"), BossArt.MINT, "the heal lights its heart mint")
	eq(BossArt.heart_light("rock_giant"), Color(0.6, 1.0, 0.4).lerp(BossArt.AMBER, 0.35), "the giant's gem stays amber")
	eq(BossArt.MUZZLE_FOLLOW["tree_spirit"], {"anim": "poison_thorns", "point": "canopy"}, "the thorns leave the canopy")
	var side := Art.boss_side("tree_spirit")
	check(not side.is_empty(), "the tree is drawn from frames")
	for anim in ["idle", "vine_lash", "poison_thorns", "life_drain", "root_drag", "summon", "hurt", "death"]:
		check(side["anims"].has(anim), "its %s" % anim)
	eq([side["anims"]["vine_lash"]["peak"], side["anims"]["poison_thorns"]["peak"], side["anims"]["life_drain"]["peak"],
		side["anims"]["root_drag"]["peak"], side["anims"]["summon"]["peak"]], [3, 4, 3, 4, 2], "the peaks")


func test_points_per_frame() -> void:
	var pts := Art.boss_points("tree_spirit")
	check(not pts.is_empty(), "points.json is read")
	var side := Art.boss_side("tree_spirit")
	for anim in side["anims"]:
		eq(pts["frames"][anim].size(), side["anims"][anim]["frames"].size(), "a point set per %s frame" % anim)
	var idle: Dictionary = pts["frames"]["idle"][0]
	for key in ["heart", "canopy", "eyes", "mushrooms"]:
		check(idle.get(key) is Vector2, "the point %s" % key)
	check(Vector2(idle["heart"]).distance_to(BossArt.HEART["tree_spirit"]) < 0.05, "the rest heart = HEART")
	check(idle.get("glow") is float and idle.get("eyesLit") is float, "the levels are kept")
	var thorns: Dictionary = pts["frames"]["poison_thorns"][int(side["anims"]["poison_thorns"]["peak"])]
	check(Vector2(thorns["canopy"]).distance_to(BossArt.MUZZLE["tree_spirit"]) < 3.0, "the thorns' peak canopy near MUZZLE")
	var drag: Array = pts["frames"]["root_drag"]
	eq(drag.map(func(f): return f.has("rootTip")), [false, true, true, true, true, true, true, false], "the root's tip while it shows")
	var reach: Vector2 = drag[int(side["anims"]["root_drag"]["peak"])]["rootTip"]
	check(reach.x > 60.0 and absf(reach.y) < 15.0, "at full reach along the ground (%s)" % reach)
	near(float(pts["frames"]["death"][3]["glow"]), 0.0, 1e-6, "the glows out at death")
	near(float(pts["frames"]["life_drain"][3]["glow"]), 2.0, 1e-6, "blazing at the drain's peak")
	var parts := Art.boss_parts("tree_spirit")
	eq(parts["parts"].size(), 11, "11 death pieces")
	eq(int(parts["parts"]["canopy_mr"]["z"]), 10, "a canopy clump in front")
	eq(int(parts["parts"]["trunk"]["z"]), 4, "the trunk behind the clumps")


func test_skin_mint_heart_eyes_and_no_hover() -> void:
	var skin := Art.boss_skin("tree_spirit")
	check(not skin.is_empty(), "a skinned idle")
	check(not SkinIdle.hovers(skin), "it breathes on its roots")
	var v := BossSkinView.new()
	v.setup(skin)
	eq(v.glow_colour(), BossArt.MINT, "the heart's mint")
	eq(v.eyes().size(), 2, "two eyes")
	check(v.crystal().distance_to(Vector2(skin["glow"]) - Vector2(skin["pivot"])) < 6.0, "the glow is the heart on the trunk")
	v.free()
	var b := _tree()
	for i in 90:
		b._process(DT)
		near(b._bob_px(), 0.0, 1e-6, "no float")
	check(b.showing_skin(), "its skinned idle shows")
	b.free()


func test_skills_play_their_animations() -> void:
	var shots := _json(SHOTS)
	var strike := {"t": 0.62, "type": "ground_strike", "playerId": "p0", "position": {"x": 300, "y": 700}, "radius": 60, "skillId": "vine_lash"}
	var a := BossAnim.action_for("skill", "vine_lash", _skill("vine_lash"), [strike], [])
	eq([a["anim"], a["at"]], ["vine_lash", 0.62], "the vines lash, the peak on the ground strike")
	var thorns: Dictionary = shots["poison_thorns"]["shot"]
	a = BossAnim.action_for("skill", "poison_thorns", _skill("poison_thorns"), thorns["events"], _launches(thorns))
	eq(a["anim"], "poison_thorns", "the thorns shake out")
	near(a["at"], float(_launches(thorns).min()), 1e-6, "its peak as they launch")
	var beam := {"t": 0.6, "type": "beam", "playerId": "boss_tree_spirit", "from": {"x": 2000, "y": 650}, "to": {"x": 0, "y": 680}, "duration": 0.8}
	a = BossAnim.action_for("skill", "life_drain", _skill("life_drain"), [beam], [])
	eq([a["anim"], a["at"]], ["life_drain", 0.6], "the drain, the peak on the beam")
	near(a["hold"], 0.48, 1e-6, "held over the beam")
	var drag: Dictionary = shots["root_drag"]["shot"]
	var pull: Dictionary = drag["events"][0]
	a = BossAnim.action_for("skill", "root_drag", _skill("root_drag"), drag["events"], [])
	eq([a["anim"], a["at"]], ["root_drag", float(pull["t"])], "the root drag, at full reach on the pull")
	near(a["hold"], float(pull["duration"]) * 0.75, 1e-6, "hooked while the member is hauled in")
	a = BossAnim.action_for("summon", "", {}, [{"t": 0.5, "type": "summon"}], [])
	eq([a["anim"], a["at"]], ["summon", 0.5], "the mushrooms raised")
	var anim := BossAnim.new(Art.boss_side("tree_spirit")["anims"])
	eq([anim.resolve("cast"), anim.resolve("burst"), anim.resolve("blizzard")], ["poison_thorns", "life_drain", "poison_thorns"],
		"a plain shot shakes thorns out, a beam drains")
	var giant := BossAnim.new(Art.boss_side("rock_giant")["anims"])
	eq([giant.resolve("cast"), giant.resolve("burst")], ["throw", "throw"], "the giant still throws")
	var witch := BossAnim.new(Art.boss_side("ice_witch")["anims"])
	eq(witch.resolve("cast"), "cast", "the witch casts")
	var held := BossAnim.new(Art.boss_side("tree_spirit")["anims"])
	held.play("life_drain", {"at": 0.6, "hold": 0.48})
	held.step(0.65)
	eq(held.frame(), ["life_drain", 3], "the drain's peak")
	held.step(0.4)
	eq(held.frame(), ["life_drain", 3], "held over the beam")
	held.step(0.2)
	check(int(held.frame()[1]) > 3, "then the second swell")


func test_muzzle_heart_and_root_tip_follow_the_frames() -> void:
	var b := _tree(200.0)
	b.face(-1)
	b._process(DT)
	var rest_muzzle := b.muzzle_position()
	check(rest_muzzle.distance_to(BossArt.muzzle("tree_spirit", 200.0, -1)) < 3.0, "at rest the canopy (%s)" % rest_muzzle)
	check(b.root_tip_position() == Vector2.INF, "no root out in the idle")
	b.play_action({"anim": "poison_thorns"})
	_until_frame(b, "poison_thorns", 4)
	var pts: Dictionary = Art.boss_points("tree_spirit")["frames"]["poison_thorns"][4]
	var c: Vector2 = pts["canopy"]
	check(b.muzzle_position().distance_to(Vector2(-c.x, c.y) * 2.0) < 0.5, "the thorns leave the shown canopy, mirrored")
	var h: Vector2 = pts["heart"]
	check(b.heart_position().distance_to(Vector2(-h.x, h.y) * 2.0) < 0.5, "the heart of the shown frame")
	b.play_action({"anim": "root_drag"})
	_until_frame(b, "root_drag", 4)
	var tip: Vector2 = Art.boss_points("tree_spirit")["frames"]["root_drag"][4]["rootTip"]
	check(b.root_tip_position().distance_to(Vector2(-tip.x, tip.y) * 2.0) < 0.5, "the root's tip at full reach, toward the party")
	b.free()


func test_root_drag_fx_joins_the_drawn_root() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var b := _tree(200.0)
	b.position = Vector2(1000, 500)
	b.face(-1)
	root.add_child(b)
	b.play_action({"anim": "root_drag"})
	_until_frame(b, "root_drag", 4)
	var tip := b.root_tip_position()
	var near_path := PackedVector2Array([Vector2(500, 500), Vector2(600, 500), Vector2(tip.x - 150.0, 500)])
	var fx := RootDragFx.new(near_path, null, 1.0)
	fx.tree = b
	root.add_child(fx)
	fx._process(DT)
	check(fx.joined(), "the drag ends near the drawn root: joined")
	check(fx.root_end().distance_to(tip) < 0.5, "the ground root ends at its tip")
	var far := RootDragFx.new(PackedVector2Array([Vector2(0, 500), Vector2(200, 500)]), null, 1.0)
	far.tree = b
	root.add_child(far)
	far._process(DT)
	check(not far.joined(), "far from the tree: it dives into the ground as before")
	eq(far.root_end(), Vector2(240, 500), "past the drag's end")
	var none := RootDragFx.new(near_path, null, 1.0)
	root.add_child(none)
	none._process(DT)
	check(not none.joined(), "no tree: as before")
	for n in [fx, far, none, b]:
		root.remove_child(n)
		n.free()


func test_idle_leaves_fall_now_and_then() -> void:
	var b := _tree(200.0)
	var seen := 0
	var landed := false
	var max_y := -INF
	for i in int(14.0 / DT):
		b._process(DT)
		seen = maxi(seen, b.leaf_count())
		for l in b._leaves.leaves:
			max_y = maxf(max_y, Vector2(l["p"]).y)
			landed = landed or float(l["landed"]) >= 0.0
	check(seen >= 1 and seen <= 3, "a leaf now and then, subtle (%d at once)" % seen)
	check(landed and max_y > -5.0, "they fall to the ground (%s)" % max_y)
	b.free()
	var g := BossBody.new()
	g.setup("rock_giant", 200.0)
	for i in int(8.0 / DT):
		g._process(DT)
	eq(g.leaf_count(), 0, "the giant has no leaves")
	g.free()
	var fl := FallingLeaves.new()
	fl.add(Vector2(0, -100), 4.0, Color.GREEN, 0.0)
	for i in 600:
		fl.step(DT, 200.0)
	eq(fl.count(), 0, "a leaf lies a moment and is gone")


func test_wither_phases() -> void:
	var b := _tree(200.0)
	b._process(0.2)
	b.die()
	eq(b.death_phase(), "wither", "its death frames wither it")
	eq(b.shown_frame(), ["death", 0], "from its first death frame")
	var swap := b.crumble_swap_sec()
	near(swap, 3.0 / 6.0 + BossBody.WITHER_HOLD, 1e-4, "the parts take over after death frame 3")
	b._process(0.4)
	eq(b.shown_frame(), ["death", 2], "frame 2")
	check(b.leaf_count() > 3, "withered leaves fall (%d)" % b.leaf_count())
	b._process(0.15)
	eq(b.shown_frame(), ["death", 3], "frame 3, held")
	eq(b.rubble_count(), 0, "still whole")
	b._process(swap - 0.55 + 0.01)
	eq(b.death_phase(), "drop", "the clumps drop")
	eq(b.rubble_count(), 11, "into its parts")
	check(b.wither_cover() > 0.9, "the frame still over them (no cut edges)")
	var by := {}
	for r in b.rubble():
		by[r["name"]] = r
	for n in ["trunk", "root_l", "root_r", "tendril_l", "tendril_r"]:
		check(bool(by[n]["anchored"]), "%s stays on the ground" % n)
	for n in BossBody.WITHER_DROP:
		check(not bool(by[n]["anchored"]), "%s drops" % n)
	var clump_at: Vector2 = by["canopy_ml"]["c"]
	var twig_at: Vector2 = by["branch_r"]["c"]
	var trunk_at: Vector2 = by["trunk"]["c"]
	b._process(BossBody.WITHER_COVER + 0.02)
	near(b.wither_cover(), 0.0, 1e-6, "the frame gone as they separate")
	check(Vector2(by["canopy_ml"]["c"]).y > clump_at.y + 5.0, "the first clump falls")
	check(Vector2(by["branch_r"]["c"]).distance_to(twig_at) < 0.01, "the twigs a beat later")
	for i in int(BossBody.WITHER_FALL / DT):
		b._process(DT)
	eq(b.death_phase(), "fade", "then it fades")
	for n in BossBody.WITHER_DROP:
		var r: Dictionary = by[n]
		var sz: Vector2 = r["size"]
		var hh := 0.5 * (absf(sz.x * sin(float(r["rot"]))) + absf(sz.y * cos(float(r["rot"])))) * 0.8
		check(absf(Vector2(r["c"]).y + hh - float(r["ground"])) < 1.0, "%s settled on the ground" % n)
		check(Vector2(r["v"]).length() < 40.0, "%s at rest (%s)" % [n, r["v"]])
	var t: Dictionary = by["trunk"]
	check(float(t["sy"]) < 1.0 - BossBody.WITHER_SAG * 0.9, "the trunk sagged (%s)" % t["sy"])
	check(Vector2(t["c"]).y > trunk_at.y and Vector2(t["c"]).x == trunk_at.x, "toward its feet, in place")
	b._process(BossBody.WITHER_FADE + 0.05)
	eq(b.death_phase(), "gone", "gone")
	near(b.death_progress(), 1.0, 1e-6, "done")
	b.free()
