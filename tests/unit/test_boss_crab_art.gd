extends "res://tests/test_case.gd"
## Cua Dung Nham (lava_crab)'s drawn art in a match (match/boss/boss_body.gd and friends) and its Cua con
## (crab): the constants (BossArt HEART / MUZZLE / TOP / WIDTH / DEATH / STOMP / DRIPS / SPOUT), the
## points per frame (Art.boss_points(): shellTop, clawR, knuckle, drips), the skin's ember glow, its
## skills' animations (BossAnim.action_for() with the recorded pincer shot of
## tests/fixtures/boss_v5_shots.json and the game data of boss_gamedata.json: the pincer waits for the
## crawl), the walk loop while it walks, the muzzle on the shell top while it fires bombs, the slam's
## chips and its ring at the claw (ShockwaveFx.slam_origin()), the spout, the lava drips, the drawn
## pincer's grab (PincerFx drawn: no code claw), the cooling death; the minion's frames
## (lava_crab/minion), walk, prime with the red tint, its fading death.

const Art := preload("res://ui/art.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const BossAnim := preload("res://match/boss/boss_anim.gd")
const BossBody := preload("res://match/boss/boss_body.gd")
const BossSkinView := preload("res://match/boss/boss_skin_view.gd")
const SkinIdle := preload("res://match/boss/skin_idle.gd")
const LavaDrips := preload("res://match/boss/lava_drips.gd")
const PincerFx := preload("res://match/boss/pincer_fx.gd")
const ShockwaveFx := preload("res://match/boss/shockwave_fx.gd")
const BomberModel := preload("res://match/boss/bomber_model.gd")
const V5 := preload("res://tests/unit/test_boss_v5.gd")
const SHOTS := "res://tests/fixtures/boss_v5_shots.json"
const GAMEDATA := "res://tests/fixtures/boss_gamedata.json"
const DT := 1.0 / 60.0


static func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _boss() -> Dictionary:
	for b in _json(GAMEDATA)["bosses"]:
		if str(b.get("bossId", "")) == "lava_crab":
			return b
	return {}


static func _skill(id: String) -> Dictionary:
	for s in _boss()["skills"]:
		if str(s["skillId"]) == id:
			return s
	return {}


func _crab(h: float = 200.0) -> BossBody:
	var b := BossBody.new()
	b.setup("lava_crab", h)
	return b


func _minion(h: float = 100.0) -> BossBody:
	var b := BossBody.new()
	b.setup("crab", h)
	b.bomber = true
	return b


## Steps b until its frame index of anim shows (or a few s pass).
func _until_frame(b: BossBody, anim: String, index: int) -> void:
	for i in 300:
		if b.shown_frame() == [anim, index]:
			return
		b._process(DT)


func test_constants_of_the_drawn_crab() -> void:
	eq(BossArt.HEART["lava_crab"], Vector2(7.51, -51.96), "the heart: the shell's middle")
	eq(BossArt.MUZZLE["lava_crab"], Vector2(5.63, -76.06), "the muzzle: the shell's top crack")
	eq(BossArt.MUZZLE_FOLLOW["lava_crab"], {"anim": "fire_bombs", "point": "shellTop"}, "the bombs leave the shell top")
	near(BossArt.top("lava_crab"), 1.0, 1e-6, "the raised claw is its top")
	near(float(BossArt.WIDTH["lava_crab"]), 1.768, 1e-6, "its width")
	near(float(BossArt.WIDTH["crab"]), 1.768, 1e-6, "the little one's")
	eq(BossArt.death_of("lava_crab"), "cool", "it cools to stone")
	eq(BossArt.death_of("crab"), "fade", "the little one fades")
	eq([BossArt.death_of("rock_giant"), BossArt.death_of("tree_spirit"), BossArt.death_of("ice_witch"), BossArt.death_of("steel_robot")],
		["crumble", "wither", "shatter", "crash"], "the others die as before")
	eq(BossArt.heart_light("lava_crab"), BossArt.EMBER, "its heart lights ember")
	eq(BossArt.STOMP["lava_crab"]["anim"], "claw_slam", "the slam's peak")
	eq(BossArt.STOMP["lava_crab"]["foot"], Vector2(81.69, 0.31), "at the claw's impact (rig_v1.json slamImpact)")
	check(not bool(BossArt.STOMP["lava_crab"]["ring"]) and bool(BossArt.STOMP["rock_giant"].get("ring", true)),
		"the crab's ring is the game's shockwave's, the giant keeps its own")
	eq(Art.boss_dir("crab"), Art.ROOT + "bosses/lava_crab/minion/", "the little crab's art under the boss's")
	eq(Art.boss_dir("lava_crab"), Art.ROOT + "bosses/lava_crab/", "the boss's own")
	var side := Art.boss_side("lava_crab")
	check(not side.is_empty(), "the crab is drawn from frames")
	for anim in ["idle", "walk", "fire_bombs", "claw_slam", "pincer", "summon", "hurt", "death"]:
		check(side["anims"].has(anim), "its %s" % anim)
	eq([side["anims"]["fire_bombs"]["peak"], side["anims"]["claw_slam"]["peak"], side["anims"]["pincer"]["peak"],
		side["anims"]["summon"]["peak"]], [4, 4, 5, 3], "the peaks")
	check(bool(side["anims"]["walk"]["loop"]) and side["anims"]["walk"]["frames"].size() == 8, "a walk loop of 8")


func test_points_per_frame() -> void:
	var pts := Art.boss_points("lava_crab")
	check(not pts.is_empty(), "points.json is read")
	var side := Art.boss_side("lava_crab")
	for anim in side["anims"]:
		eq(pts["frames"][anim].size(), side["anims"][anim]["frames"].size(), "a point set per %s frame" % anim)
	var idle: Dictionary = pts["frames"]["idle"][0]
	for key in ["heart", "shellTop", "eyes", "clawL", "clawR", "knuckle"] + BossArt.DRIPS["lava_crab"]["tips"]:
		check(idle.get(key) is Vector2, "the point %s" % key)
	check(Vector2(idle["heart"]).distance_to(BossArt.HEART["lava_crab"]) < 0.1, "the rest heart = HEART")
	check(Vector2(idle["shellTop"]).distance_to(BossArt.MUZZLE["lava_crab"]) < 0.1, "the rest shell top = MUZZLE")
	check(idle.get("glow") is float and idle.get("eyesLit") is float, "the levels are kept")
	eq(pts["frames"]["fire_bombs"][4]["shellTop"], Vector2(5.63, -81.65), "the spout's shell top at fire_bombs' peak")
	eq(pts["frames"]["pincer"][5]["clawR"], Vector2(119.78, -23.98), "the pincer's grip at its peak")
	check(Vector2(pts["frames"]["claw_slam"][4]["clawR"]).y > -15.0, "the claw on the ground at the slam's peak")
	check(float(pts["frames"]["death"][4]["glow"]) < 0.0, "cooled to stone at the end")
	var parts := Art.boss_parts("lava_crab")
	eq(parts["parts"].size(), 16, "16 death pieces")
	for n in BossBody.COOL_PARTS:
		check(parts["parts"].has(n), "the piece %s" % n)


func test_skin_ember_glow_and_no_hover() -> void:
	var skin := Art.boss_skin("lava_crab")
	check(not skin.is_empty(), "a skinned idle")
	check(not SkinIdle.hovers(skin), "it breathes on its legs")
	var v := BossSkinView.new()
	v.setup(skin)
	eq(v.glow_colour(), Color(1.0, 0.55, 0.16), "the shell's ember")
	eq(v.eyes().size(), 2, "two eyes")
	v.free()
	var b := _crab()
	for i in 60:
		b._process(DT)
		near(b._bob_px(), 0.0, 1e-6, "no float")
	check(b.showing_skin(), "its skinned idle shows")
	b.free()


func test_skills_play_their_animations() -> void:
	var launches := [0.9, 1.0, 1.1]
	var a := BossAnim.action_for("skill", "fire_bombs", _skill("fire_bombs"), [{"t": 0.6, "type": "rain", "radius": 2000}], launches)
	eq([a["anim"], a["at"]], ["fire_bombs", 0.9], "the bombs: the spout as the first leaves")
	var slam := [{"t": 0.6, "type": "explode", "position": {"x": 1000, "y": 700}, "radius": 14},
		{"t": 0.68, "type": "explode", "position": {"x": 850, "y": 700}, "radius": 14}]
	a = BossAnim.action_for("skill", "claw_slam", _skill("claw_slam"), slam, [])
	eq([a["anim"], a["at"]], ["claw_slam", 0.6], "the claw hits the ground on the slam")
	var shot: Dictionary = _json(SHOTS)["pincer"]["shot"]
	var pincer_t := 0.0
	for e in shot["events"]:
		if str(e["type"]) == "pincer":
			pincer_t = float(e["t"])
	a = BossAnim.action_for("skill", "pincer", _skill("pincer"), shot["events"], [])
	eq(a["anim"], "pincer", "the pincer")
	near(float(a["delay"]) + float(a["at"]), pincer_t, 1e-6, "its snap on the pincer event")
	near(float(a["at"]), float(BossAnim.PEAK_LEAD["pincer"]), 1e-6, "it reaches only at the end of the crawl")
	var walk_only: Array = shot["events"].filter(func(e): return str(e["type"]) == "move")
	a = BossAnim.action_for("skill", "pincer", _skill("pincer"), walk_only, [])
	eq(a["anim"], "", "out of reach: it only crawls")
	a = BossAnim.action_for("summon", str(_boss()["summon"]["skillId"]), {}, [{"t": 0.5, "type": "summon"}], [])
	eq([a["anim"], a["at"]], ["summon", 0.5], "the little crabs called")
	var anim := BossAnim.new(Art.boss_side("lava_crab")["anims"])
	var total := anim.play("pincer", {"at": 0.45, "delay": 1.0})
	eq(anim.frame()[0], "idle", "waiting: the base shows")
	eq(anim.pending(), "pincer", "the pincer waits")
	anim.set_walking(true)
	anim.step(0.5)
	eq(anim.frame()[0], "walk", "it crawls meanwhile")
	anim.step(0.5 + 0.46)
	eq(anim.frame(), ["pincer", 5], "the snap on time")
	anim.step(total)
	eq(anim.frame()[0], "walk", "back to the base")
	anim.set_walking(false)
	eq(anim.frame()[0], "idle", "and idle when it stops")


func test_walk_loop_while_walking() -> void:
	var b := _crab()
	b._process(DT)
	check(b.showing_skin(), "idle: the skin")
	b.set_walking(true)
	var seen := {}
	for i in 40:
		b._process(DT)
		seen[b.shown_frame()[1]] = true
		eq(b.shown_frame()[0], "walk", "the walk loop")
	check(not b.showing_skin() and seen.size() >= 6, "its frames step on (%d)" % seen.size())
	b.set_walking(false)
	b._process(DT)
	check(b.showing_skin(), "back to the idle when it stops")
	var giant := BossBody.new()
	giant.setup("rock_giant", 200.0)
	giant.set_walking(true)
	giant._process(DT)
	eq(giant.shown_frame()[0], "idle", "no walk: the giant keeps its idle")
	giant.free()
	b.free()


func test_muzzle_heart_and_slam_point_follow_the_frames() -> void:
	var b := _crab(200.0)
	b.face(-1)
	b._process(DT)
	check(b.muzzle_position().distance_to(BossArt.muzzle("lava_crab", 200.0, -1)) < 0.5, "at rest the shell top")
	b.play_action({"anim": "fire_bombs"})
	_until_frame(b, "fire_bombs", 4)
	var pts: Dictionary = Art.boss_points("lava_crab")["frames"]["fire_bombs"][4]
	var c: Vector2 = pts["shellTop"]
	check(b.muzzle_position().distance_to(Vector2(-c.x, c.y) * 2.0) < 0.5, "the bombs leave the shown shell top, mirrored")
	var h: Vector2 = pts["heart"]
	check(b.heart_position().distance_to(Vector2(-h.x, h.y) * 2.0) < 0.5, "the heart of the shown frame")
	check(b.slam_point().distance_to(Vector2(-81.69, 0.31) * 2.0) < 0.5, "the slam hits in front of it, toward the party")
	var witch := BossBody.new()
	witch.setup("ice_witch", 200.0)
	eq(witch.slam_point(), Vector2.INF, "no slam point for the others")
	witch.free()
	b.free()


func test_slam_chips_and_the_ring_at_the_claw() -> void:
	var b := _crab(200.0)
	b.face(-1)
	b.play_action({"anim": "claw_slam"})
	_until_frame(b, "claw_slam", 4)
	var embers := b._pebbles.filter(func(p): return bool(p.get("ember", false))).size()
	check(embers > 0 and b._pebbles.size() > embers, "basalt chips and embers thrown up (%d / %d)" % [embers, b._pebbles.size()])
	eq(b.get_children().filter(func(n): return n.name == "StompRing").size(), 0, "no ring of its own")
	var foot := Vector2(-81.69, 0.31) * 2.0
	check(b._dust.any(func(d): return Vector2(d["p"]).distance_to(foot) < 40.0), "dust at the impact")
	b.free()
	var root := (Engine.get_main_loop() as SceneTree).root
	var crab := _crab(200.0)
	crab.position = Vector2(1000, 700)
	crab.face(-1)
	root.add_child(crab)
	var wave := ShockwaveFx.new()
	wave.setup({"origin": Vector2(1000, 700), "t0": 0.0, "left": [[Vector2(850, 700), 0.08]], "right": [[Vector2(1150, 700), 0.08]]})
	wave.slammer = crab
	root.add_child(wave)
	check(wave.slam_origin().distance_to(Vector2(1000 - 163.38, 700)) < 1.0, "the slam's ring opens at the claw (%s)" % wave.slam_origin())
	var plain := ShockwaveFx.new()
	plain.setup({"origin": Vector2(1000, 700), "t0": 0.0, "left": [], "right": []})
	root.add_child(plain)
	eq(plain.slam_origin(), Vector2(1000, 700), "no slammer: the server's slam position")
	for n in [crab, wave, plain]:
		root.remove_child(n)
		n.free()


func test_spout_and_drips() -> void:
	var b := _crab(200.0)
	b.play_action({"anim": "fire_bombs"})
	_until_frame(b, "fire_bombs", 4)
	check(b.drip_count() >= int(BossArt.SPOUT["lava_crab"]["globs"]), "the spout's globs (%d)" % b.drip_count())
	check(b.drips().drops.all(func(d): return Vector2(d["v"]).y < 0.0), "shooting up")
	b.free()
	var c := _crab(200.0)
	var seen := 0
	var sizzled := false
	for i in int(10.0 / DT):
		c._process(DT)
		seen = maxi(seen, c.drip_count())
		sizzled = sizzled or c.drips().sizzling() > 0
	check(seen >= 1 and seen <= 4, "a drop now and then (%d at once)" % seen)
	check(sizzled, "they sizzle on the ground")
	c.die()
	for i in int(1.5 / DT):
		c._process(DT)
	eq(c.drip_count(), 0, "none once it is dead")
	c.free()
	var g := BossBody.new()
	g.setup("rock_giant", 200.0)
	for i in int(6.0 / DT):
		g._process(DT)
	eq(g.drip_count(), 0, "the giant has no lava drips")
	g.free()
	var d := LavaDrips.new()
	d.add(Vector2(0, -100), 2.0, 0.0)
	for i in 120:
		d.step(DT, 200.0)
	eq(d.count(), 0, "a drop falls, sizzles and is gone")


func test_cool_phases() -> void:
	var b := _crab(200.0)
	b._process(0.2)
	b.die()
	eq(b.death_phase(), "cool", "its death frames cool it")
	eq(b.shown_frame(), ["death", 0], "from its first death frame")
	var swap := b.crumble_swap_sec()
	near(swap, 4.0 / 6.0 + BossBody.COOL_HOLD, 1e-4, "the parts take over after death frame 4")
	b._process(0.7)
	eq(b.shown_frame(), ["death", 4], "the last frame, held")
	check(b._dust.size() > 2, "smoke rises off the shell (%d)" % b._dust.size())
	eq(b.rubble_count(), 0, "still whole")
	b._process(swap - 0.7 + 0.01)
	eq(b.death_phase(), "split", "it splits")
	eq(b.rubble_count(), 16, "into its parts")
	check(b.wither_cover() > 0.9, "the frame still over them")
	var by := {}
	for r in b.rubble():
		by[r["name"]] = r
	var l0: Vector2 = by["shell_l"]["c"]
	var r0: Vector2 = by["shell_r"]["c"]
	for i in int(0.4 / DT):
		b._process(DT)
	near(b.wither_cover(), 0.0, 1e-6, "the frame gone as they separate")
	check(Vector2(by["shell_r"]["c"]).x - Vector2(by["shell_l"]["c"]).x > r0.x - l0.x + 20.0, "the shell's halves move apart")
	for i in int(BossBody.COOL_FALL / DT):
		b._process(DT)
	eq(b.death_phase(), "fade", "then it fades")
	for r in b.rubble():
		var sz: Vector2 = r["size"]
		var hh := 0.5 * (absf(sz.x * sin(float(r["rot"]))) + absf(sz.y * cos(float(r["rot"])))) * 0.8
		check(Vector2(r["c"]).y + hh <= float(r["ground"]) + 1.0, "%s on or over the ground" % r["name"])
		check(Vector2(r["v"]).length() < 60.0, "%s at rest (%s)" % [r["name"], r["v"]])
	b._process(BossBody.COOL_FADE + 0.05)
	eq(b.death_phase(), "gone", "gone")
	near(b.death_progress(), 1.0, 1e-6, "done")
	b.free()


func test_drawn_pincer_grab() -> void:
	var fx := PincerFx.new(1.0, true)
	check(fx.drawn, "the drawn crab's own pincer grabs")
	var code := PincerFx.new(-1.0)
	check(not code.drawn and code.side == -1.0, "the code claw otherwise")
	for f in [fx, code]:
		f._process(PincerFx.SNAP + 0.01)
		near(f.closed(), 1.0, 1e-6, "shut on the target")
		f.free()
	var v5 = V5.new()
	var m: Node2D = v5._screen("lava_crab", "pincer")
	var shot: Dictionary = _json(SHOTS)["pincer"]["shot"]
	var crab: Node2D = m._views["boss_lava_crab"]
	var body: Node2D = crab.figure()
	check(body.has_frames(), "the crab is drawn")
	m._on_event("ShotResolved", shot)
	var walked := false
	var snapped := false
	var t := 0.0
	while t < 2.0:
		m._shot_player._process(DT)
		m._process(DT)
		for v in m._views.values():
			v._process(DT)
			v.figure()._process(DT)
		walked = walked or body.shown_frame()[0] == "walk"
		var grabs: Array = V5._fx(m, PincerFx)
		if not grabs.is_empty():
			check(grabs[0].drawn, "no code claw")
			if not snapped:
				eq(body.shown_frame(), ["pincer", 5], "the drawn pincer snaps with it")
			snapped = true
		t += DT
	check(walked, "it crawls on its walk loop")
	check(snapped, "then grabs")
	v5._free(m)


func test_minion_frames_walk_prime_and_fade() -> void:
	var side := Art.boss_side("crab")
	check(not side.is_empty(), "the little crab is drawn from frames")
	near(float(side["height"]), 160.0, 1e-6, "its body 160 px")
	for anim in ["idle", "walk", "prime", "hurt"]:
		check(side["anims"].has(anim), "its %s" % anim)
	check(not Art.boss_points("crab").is_empty(), "its points")
	eq(BossArt.muzzle("crab", 100.0, 1), Vector2(16, -43), "it spits from its mouth")
	var b := _minion()
	b._process(DT)
	eq(b.shown_frame()[0], "idle", "idle")
	b.set_walking(true)
	b._process(DT)
	eq(b.shown_frame()[0], "walk", "walks")
	b.set_walking(false)
	b.warn = true
	var hot := 0.0
	for i in int(BomberModel.PULSE_SEC / DT) + 2:
		b._process(DT)
		eq(b.shown_frame()[0], "prime", "about to blow up")
		hot = maxf(hot, float(b._mat.get_shader_parameter("tint")))
	check(hot > 0.5, "the red pulse on its frames (%f)" % hot)
	b.warn = false
	b._process(DT)
	eq(b.shown_frame()[0], "idle", "calm again")
	near(float(b._mat.get_shader_parameter("tint")), 0.0, 1e-6, "no tint")
	b.prime(0.5)
	b._process(DT)
	eq(b.shown_frame()[0], "prime", "its detonation's lead-in")
	b.free()
	var d := _minion()
	d._process(DT)
	d.die()
	d._process(0.3)
	eq(d.death_phase(), "fade", "it fades")
	eq(d.shown_frame()[0], "hurt", "on its hurt frame")
	near(float(d._frame_look()["icy"]), 0.0, 1e-6, "not iced like the witch")
	check(d.modulate.a < 1.0 and d.rotation != 0.0, "sinking, tilting, fading")
	d._process(BossBody.DEATH_SEC)
	eq(d.death_phase(), "gone", "gone")
	d.free()
