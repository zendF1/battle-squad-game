extends "res://tests/test_case.gd"
## The Ice Witch's drawn art: the importer's cutting and measuring (tools/import_boss_frames.gd on
## made-up sheets), the imported frames and pictures (ui/art.gd boss_side() / boss_picture()),
## which frame shows (BossAnim: the base loops, a skill's animation with its peak on its moment,
## the stun's slow sway, the shot → animation mapping), the boss body drawn from them (hurt, fly,
## the shattering death; the robot keeps its code art) and the UI pictures (BossArtView: portrait
## and bust, centred; the snowman keeps its figure).

const ImportBossFrames := preload("res://tools/import_boss_frames.gd")
const Art := preload("res://ui/art.gd")
const BossAnim := preload("res://match/boss/boss_anim.gd")
const BossBody := preload("res://match/boss/boss_body.gd")
const BossArtView := preload("res://match/boss/boss_art_view.gd")
const V3 := preload("res://tests/unit/test_boss_v3.gd")
const SkinIdle := preload("res://match/boss/skin_idle.gd")
const SkinFly := preload("res://match/boss/skin_fly.gd")
const BossSkinView := preload("res://match/boss/boss_skin_view.gd")

const CLOAK := Color8(70, 70, 170) # inside the default cloak colours
const MIST := Color8(200, 240, 250)


func _sheet(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8) # keyed already: transparent backdrop


func _rect(img: Image, r: Rect2i, c: Color) -> void:
	img.fill_rect(r, c)


# ── The importer ─────────────────────────────────────────────────────────────

func test_boundaries_at_the_empty_columns() -> void:
	var img := _sheet(300, 100)
	_rect(img, Rect2i(10, 10, 60, 80), CLOAK)
	_rect(img, Rect2i(120, 10, 60, 80), CLOAK) # an empty run 70..119 round the equal cut at 100
	_rect(img, Rect2i(205, 10, 70, 80), CLOAK) # touching the equal cut at 200: none empty near it
	_rect(img, Rect2i(180, 50, 25, 4), MIST) # a beam joining 2 and 3
	var cut := ImportBossFrames.boundaries(img, 3, {"search": 0.35})
	eq(int(cut["cuts"][0]), 95, "the middle of the widest empty run")
	eq(cut["fallback"], [2], "the second boundary has no empty column")
	var cut2 := ImportBossFrames.boundaries(img, 3, {"search": 0.35, "fallback": "equal"})
	eq(int(cut2["cuts"][1]), 200, "equal-width on request")
	var given := ImportBossFrames.boundaries(img, 3, {}, [90, 190])
	eq(given["cuts"], [90, 190], "the config's cuts")


func test_grid_cells_read_left_to_right_top_to_bottom() -> void:
	var img := _sheet(300, 200) # 3 × 2 cells of 100 × 100, 5 frames: the last cell empty
	for i in 5:
		var at := Vector2i((i % 3) * 100 + 15 + i * 2, (i / 3) * 100 + 12) # a little off the equal grid
		_rect(img, Rect2i(at, Vector2i(60 + i, 75)), CLOAK)
	var cells := ImportBossFrames.grid_cells(img, 3, 2, 5, {"search": 0.35})
	eq(cells.size(), 5, "the first five cells")
	for i in 5:
		var used := (cells[i] as Image).get_used_rect()
		eq(used.size, Vector2i(60 + i, 75), "cell %d holds its whole figure" % i)


func test_frames_laid_in_one_row_cut_at_the_gaps() -> void:
	var a := _sheet(80, 100)
	_rect(a, Rect2i(10, 20, 60, 70), CLOAK)
	var b := _sheet(90, 110)
	_rect(b, Rect2i(5, 30, 80, 70), CLOAK)
	var row := ImportBossFrames.laid_in_row([a, b, a], 20)
	eq((row["image"] as Image).get_size(), Vector2i(80 + 90 + 80 + 40, 110), "side by side, the gaps between")
	eq(row["offsets"], [0, 100, 210], "each frame's left")
	eq(row["cuts"], [90, 200], "cut in the middle of each gap")
	var parts := ImportBossFrames.split_frames(row["image"], row["cuts"], {"share": 0.8, "smallPiece": 10, "edgeFade": 4,
		"body": {}, "seedMargin": 0.2})
	eq((parts[1]["rect"] as Rect2i).position.x, 105, "the second frame's figure where it was laid")


func test_split_keeps_a_reaching_piece_whole_and_cuts_a_shared_one() -> void:
	var img := _sheet(300, 100)
	_rect(img, Rect2i(20, 20, 50, 70), CLOAK)
	_rect(img, Rect2i(70, 30, 50, 4), MIST) # frame 0's staff reaching past the cut at 100
	_rect(img, Rect2i(170, 20, 50, 70), CLOAK)
	_rect(img, Rect2i(220, 40, 40, 6), MIST)
	_rect(img, Rect2i(255, 10, 40, 80), MIST) # a flash touching frame 1's beam, no cloak in it
	var parts := ImportBossFrames.split_frames(img, [100, 250], {"share": 0.8, "smallPiece": 10, "edgeFade": 4,
		"body": {}, "seedMargin": 0.2})
	eq(parts.size(), 3, "three frames")
	eq((parts[0]["rect"] as Rect2i).end.x, 120, "the staff stays with its figure over the cut")
	eq((parts[1]["rect"] as Rect2i).position.x, 170, "nothing of frame 0 in frame 1")
	check((parts[1]["rect"] as Rect2i).end.x >= 290, "the flash goes with the figure it touches (through the piece)")


func test_measure_finds_the_hood_and_the_hem() -> void:
	var img := _sheet(200, 200)
	_rect(img, Rect2i(80, 20, 40, 30), CLOAK) # the hood
	_rect(img, Rect2i(60, 50, 80, 90), CLOAK) # the cloak
	_rect(img, Rect2i(70, 140, 60, 40), MIST) # the frost mist to y 179
	_rect(img, Rect2i(140, 10, 6, 150), MIST) # the staff beside her
	var m := ImportBossFrames.measure(img, {})
	check(bool(m["ok"]), "a body found")
	eq(int(m["top"]), 20, "the hood's top")
	near(m["feet"].y, 180.0, 0.01, "the feet: under the mist")
	near(m["feet"].x, 100.0, 1.0, "the skirt's middle, not the staff")
	check(not bool(ImportBossFrames.measure(_sheet(50, 50), {})["ok"]), "no cloak: nothing")


# ── The imported art ─────────────────────────────────────────────────────────

func test_the_witch_has_frames_and_pictures() -> void:
	var side := Art.boss_side("ice_witch")
	check(not side.is_empty(), "assets/bosses/ice_witch/side/side.json loads")
	for anim in ["fly", "cast", "burst", "blizzard", "summon", "hurt"]:
		check(side["anims"].has(anim) and not side["anims"][anim]["frames"].is_empty(), "%s frames" % anim)
	check(not side["anims"].has("idle"), "no idle frames: the idle is skinned")
	eq(side["anims"]["burst"]["peak"], 2, "the burst's flash is its third frame")
	check(bool(side["anims"]["fly"]["loop"]), "fly loops")
	var png := Image.load_from_file(ProjectSettings.globalize_path("res://assets/bosses/ice_witch/side/fly_0.png"))
	eq(Vector2(png.get_size()), side["size"], "every frame on the shared canvas")
	check(side["pivot"].y > side["height"], "the feet under the body's top")
	check(Art.boss_picture("ice_witch", "portrait") != null and Art.boss_picture("ice_witch", "bust") != null, "portrait and bust")
	check(Art.boss_side("steel_robot").is_empty() and Art.boss_picture("lava_crab", "portrait") == null, "others: none (code art)")


# ── Which frame shows ───────────────────────────────────────────────────────

func _anims() -> Dictionary:
	return {"idle": {"frames": 7, "fps": 7.0, "loop": true}, "fly": {"frames": 4, "fps": 8.0, "loop": true},
		"burst": {"frames": 6, "fps": 10.0, "loop": false, "peak": 2}, "hurt": {"frames": 2, "fps": 8.0, "loop": false}}


func test_anim_base_loops_and_a_peak_on_its_moment() -> void:
	var a := BossAnim.new(_anims())
	a.step(1.0)
	eq(a.frame(), ["idle", 0], "idle loops (7 frames at 7 fps: a second round)")
	a.set_flying(true)
	a.step(0.3)
	eq(a.frame()[0], "fly", "flying: the fly loop")
	a.set_flying(false)
	var d := a.play("burst", {"at": 0.6, "hold": 0.4})
	near(d, 0.6 + 0.4 + 3 * 0.1, 0.001, "the lead, the held peak, the rest at fps")
	a.step(0.55)
	eq(a.frame(), ["burst", 1], "before the beams")
	a.step(0.1)
	eq(a.frame(), ["burst", 2], "the flash with the beams")
	a.step(0.3)
	eq(a.frame(), ["burst", 2], "held over them")
	a.step(0.12)
	eq(a.frame(), ["burst", 3], "then on")
	a.step(0.5)
	eq(a.frame()[0], "idle", "back to idle")
	eq(a.play("nope"), 0.0, "no such animation: nothing")


func test_anim_stunned_slow_and_swaying() -> void:
	var a := BossAnim.new(_anims())
	var b := BossAnim.new(_anims())
	b.stunned = true
	for i in 30:
		a.step(1.0 / 60.0)
		b.step(1.0 / 60.0)
	check(int(b.frame()[1]) < int(a.frame()[1]), "the stunned idle runs slower")
	eq(a.sway(), 0.0, "no sway awake")
	check(absf(b.sway()) > 0.0 and absf(b.sway()) <= BossAnim.SWAY_RAD, "a slight sway stunned")


func test_action_for_the_witch_skills() -> void:
	var beam := [{"t": 0.6, "type": "beam", "duration": 0.8}, {"t": 0.6, "type": "beam", "duration": 0.8}]
	var burst := BossAnim.action_for("skill", "frost_beam", {}, beam, [])
	eq([burst["anim"], burst["at"]], ["burst", 0.6], "the frost beam: the burst, its flash on the beams")
	near(float(burst["hold"]), 0.48, 0.001, "held over most of them")
	var bliz := BossAnim.action_for("skill", "blizzard", {}, [], [0.7, 0.5, 1.5])
	eq([bliz["anim"], bliz["at"]], ["blizzard", 0.5], "the blizzard: on the first shard leaving")
	near(float(bliz["hold"]), 1.0, 0.001, "its whirl while they leave")
	eq(BossAnim.action_for("skill", "ice_spikes", {}, [], [0.4])["anim"], "cast", "the ice spikes: the cast")
	var summon := BossAnim.action_for("summon", "", {}, [{"t": 0.6, "type": "summon"}], [])
	eq([summon["anim"], summon["at"]], ["summon", 0.6], "the summon on its event")
	eq(BossAnim.action_for("skill", "new_beam", {"kind": "beam"}, [], [])["anim"], "burst", "an unknown beam skill by its kind")
	eq(BossAnim.action_for("skill", "new_rain", {"kind": "rain", "launchFrom": "boss"}, [], [])["anim"], "blizzard",
		"a rain from round the boss")
	eq(BossAnim.action_for("skill", "x", {}, [], [])["at"], -1.0, "no moment: its own pace")


# ── The body ────────────────────────────────────────────────────────────────

func test_witch_body_draws_frames_hurt_and_flight() -> void:
	var b := BossBody.new()
	b.setup("ice_witch", 162.4)
	check(b.has_frames() and b.anim() != null, "the witch is drawn from her frames")
	eq(b.shown_frame()[0], "idle", "idle")
	check(b.showing_skin(), "her idle is the skinned one")
	b.hurt()
	check(not b.showing_skin(), "a hit plays the hurt frames")
	eq(b.shown_frame()[0], "hurt", "a hit plays hurt")
	check(b.is_flashing(), "and flashes")
	b._process(0.5)
	eq(b.shown_frame()[0], "idle", "briefly")
	check(b.showing_skin(), "back to the skinned idle")
	var before := b._bob_px()
	b.set_flight(true)
	b._process(1.0 / 60.0)
	eq(b.shown_frame()[0], "fly", "a hover move: fly")
	check(not b.showing_skin() and not b.skin_view().visible, "not the idle")
	check(b.showing_glide() and b.glide_view().visible, "she glides on her side view")
	near(b._bob_px(), before, b.art_height() * 0.004, "the float carries on: no jump from idle to fly")
	b.set_flight(false)
	b._process(1.0 / 60.0)
	check(b.showing_glide(), "landing: the glide settles before the idle")
	for i in 120:
		b._process(1.0 / 60.0)
	check(not b.showing_glide() and b.showing_skin(), "then the skinned idle")
	check(b.play_action({"anim": "burst", "at": 0.4}) > 0.4, "the burst plays")
	b.hurt()
	eq(b.shown_frame()[0], "burst", "a hit does not cut a skill's animation")
	b.set_stunned(true)
	b._process(2.0)
	check(b.anim().stunned, "stunned: the slow idle")
	var robot := BossBody.new()
	robot.setup("steel_robot", 150.0)
	check(not robot.has_frames() and robot.anim() == null, "the robot keeps its code art")
	b.free()
	robot.free()


func test_witch_death_cracks_freezes_and_shatters() -> void:
	var b := BossBody.new()
	b.setup("ice_witch", 162.4)
	b.die()
	eq(b.death_phase(), "crack", "first the cracks")
	eq(b.shown_frame(), ["hurt", 0], "on her first hurt frame")
	b._process(BossBody.CRACK_SEC + 0.01)
	eq(b.death_phase(), "freeze", "a held freeze-frame")
	eq(b.shatter_count(), 0, "not broken yet")
	b._process(BossBody.FREEZE_END - BossBody.CRACK_SEC)
	eq(b.death_phase(), "shatter", "then she shatters")
	eq(b.shatter_count(), BossBody.SHATTER_SHARDS, "into shards")
	check(b.modulate.a == 1.0, "no fade of the whole body (the frame fades in the drawing)")
	b._process(BossBody.FRAMES_DEATH_SEC)
	eq(b.death_phase(), "gone", "over in about 1.35 s")
	near(b.death_progress(), 1.0, 0.001, "done")
	b.free()


func test_a_witch_shot_plays_its_animation() -> void:
	var v3 = V3.new()
	var m: Node2D = v3._screen()
	var witch = m._views["boss_ice_witch"].figure()
	check(witch.has_frames(), "the match's witch has frames")
	var beams: Array = []
	for i in 20:
		beams.append({"t": 0.6, "type": "beam", "playerId": "boss_ice_witch", "from": {"x": 1200, "y": 380},
			"to": {"x": 1200 + 1000 * cos(TAU * i / 20.0), "y": 380 + 1000 * sin(TAU * i / 20.0)}, "duration": 0.8})
	m._on_event("ShotResolved", {"shooterId": "boss_ice_witch", "actionMode": "skill", "skillId": "frost_beam", "duration": 2.0,
		"projectiles": [], "events": beams})
	eq(witch.anim().playing(), "burst", "the frost beam plays the burst")
	for i in 37: # 0.62 s
		witch._process(1.0 / 60.0)
	eq(witch.shown_frame(), ["burst", 2], "its flash as the beams fire")
	v3._free(m)


# ── The UI pictures ──────────────────────────────────────────────────────────

func test_art_view_pictures_centred() -> void:
	var bust = BossArtView.make("ice_witch", Vector2(70, 70), 1, "bust")
	check(bust.picture_texture() != null, "the HP bar's icon is the bust")
	var r: Rect2 = bust.picture_rect()
	near(r.get_center().x, 35.0, 0.01, "centred across")
	near(r.get_center().y, 35.0, 0.01, "and down")
	var card = BossArtView.make("ice_witch", Vector2(300, 210), -1, "portrait")
	check(card.picture_texture() == Art.boss_picture("ice_witch", "portrait"), "the cards show the portrait")
	check(card.picture_rect().size.y <= 210.0 and card.picture_rect().get_center().is_equal_approx(Vector2(150, 105)), "fitted, dead centre")
	var snowman = BossArtView.make("snowman", Vector2(70, 70), 1, "bust")
	check(snowman.picture_texture() == null, "a minion keeps its figure")
	var robot = BossArtView.make("steel_robot", Vector2(70, 70), 1, "bust")
	check(robot.picture_texture() == null, "a boss without a picture too")
	for v in [bust, card, snowman, robot]:
		v.free()


# ── The skinned idle ─────────────────────────────────────────────────────────

func test_skin_idle_pose_is_small_and_loops() -> void:
	var worst_rot := 0.0
	var worst_shard := 0.0
	for k in 97:
		var t := SkinIdle.PERIOD * k / 96.0
		check(absf(SkinIdle.hover(t)) <= SkinIdle.HOVER + 1e-6, "the float stays within its amplitude")
		for b in SkinIdle.MOTION:
			worst_rot = maxf(worst_rot, absf(float(SkinIdle.bone(b, t)["rot"])))
		for i in 4:
			worst_shard = maxf(worst_shard, (SkinIdle.shard(i, t)["offset"] as Vector2).length())
		check(SkinIdle.glow(t) >= 0.0 and SkinIdle.glow(t) <= 1.0, "the glow 0..1")
	check(worst_rot <= 3.0, "no bone turns more than 3 degrees (%.2f)" % worst_rot)
	check(worst_shard <= 0.035 and worst_shard > 0.005, "the shards drift a little round their places (%.4f of the height)" % worst_shard)
	check(SkinIdle.HOVER >= 0.02 and SkinIdle.HOVER <= 0.03 and SkinIdle.PERIOD == 2.4, "a 2-3 % float over 2.4 s")
	for t in [0.0, 0.7, 1.9]:
		near(SkinIdle.hover(t + SkinIdle.PERIOD), SkinIdle.hover(t), 1e-5, "the float loops")
		for b in SkinIdle.MOTION:
			near(float(SkinIdle.bone(b, t + SkinIdle.PERIOD)["rot"]), float(SkinIdle.bone(b, t)["rot"]), 1e-4, "%s loops" % b)
		for i in 4:
			check((SkinIdle.shard(i, t + SkinIdle.PERIOD)["offset"] as Vector2).is_equal_approx(SkinIdle.shard(i, t)["offset"]), "shard %d loops" % i)
	var a := SkinIdle.shard(0, 0.3)["offset"] as Vector2
	var c := SkinIdle.shard(1, 0.3)["offset"] as Vector2
	check(not a.is_equal_approx(c), "each shard its own phase")
	var tr := SkinIdle.tracks(["head", "mist_3", "root"], 360.0)
	check(tr["tracks"].has("head") and not tr["tracks"].has("root"), "tracks for the moving bones")
	var head: Dictionary = tr["tracks"]["head"]
	eq(head["t"].size(), SkinIdle.KEYS, "keys over one loop")
	near(float(head["rot"][0]), float(head["rot"][head["rot"].size() - 1]), 1e-3, "the last key is the first: no seam")
	var m1 := absf(float(SkinIdle.MOTION["mist_1"]["lag"]))
	check(float(SkinIdle.MOTION["mist_3"]["lag"]) > float(SkinIdle.MOTION["mist_2"]["lag"]) and float(SkinIdle.MOTION["mist_2"]["lag"]) > m1,
		"the mist ripples down")


func test_the_witch_skin_data() -> void:
	var sk := Art.boss_skin("ice_witch")
	check(not sk.is_empty(), "assets/bosses/ice_witch/skin/idle/skin.json loads")
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://assets/bosses/ice_witch/skin/idle/skin.json"))
	eq(int(raw["gaps"]), 0, "the mesh covers every visible px")
	eq(sk["shards"].size(), 4, "four shards of her own")
	var names: Array = sk["bones"].map(func(b): return b["name"])
	for b in ["root", "torso", "head", "arm_staff", "staff", "arm_free", "cape_l", "cape_r", "mist_1", "mist_2", "mist_3"]:
		check(names.has(b), "the %s bone" % b)
	near(float(sk["height"]), 360.0, 0.01, "its body's height")
	check(sk["anims"]["idle"]["loop"] and is_equal_approx(float(sk["anims"]["idle"]["length"]), SkinIdle.PERIOD), "the idle loops over the period")
	check(Art.boss_skin("steel_robot").is_empty(), "others: none")


func test_skin_view_moves_gently() -> void:
	var v := BossSkinView.new()
	v.setup(Art.boss_skin("ice_witch"))
	var rest: Array = []
	for i in 4:
		rest.append(v.shard_centre(i))
	var crystal0 := v.crystal()
	var worst := 0.0
	var crystal_worst := 0.0
	for k in 60:
		v.advance(SkinIdle.PERIOD / 60.0)
		for i in 4:
			worst = maxf(worst, v.shard_centre(i).distance_to(rest[i]))
		crystal_worst = maxf(crystal_worst, v.crystal().distance_to(crystal0))
	check(worst > 1.0 and worst < v.height() * 0.08, "the shards drift a little (%.1f px)" % worst)
	check(crystal_worst > 0.2 and crystal_worst < v.height() * 0.05, "the crystal follows the staff's tilt (%.1f px)" % crystal_worst)
	check(v.full_body().bone("staff") != null and v.full_body().has_animation("idle"), "the lobby's skinning plays her idle")
	v.free()


func test_portrait_card_is_the_skinned_idle() -> void:
	var card = BossArtView.make("ice_witch", Vector2(300, 210), -1, "portrait")
	check(card.skin_view() != null, "the card's portrait is alive")
	var sk: Dictionary = card.skin_view().skin
	var k: float = card.skin_view().scale.x
	var centre: Vector2 = card.skin_view().position + (Vector2(sk["size"]) / 2.0 - Vector2(sk["pivot"])) * k
	near(centre.x, 150.0, 0.5, "centred across")
	near(centre.y, 105.0, 0.03 * 210.0, "and down (its float)")
	var bust = BossArtView.make("ice_witch", Vector2(70, 70), 1, "bust")
	check(bust.skin_view() == null, "the bust stays a picture")
	card.free()
	bust.free()


# ── The skinned glide ────────────────────────────────────────────────────────

func test_glide_blends_in_streams_and_settles() -> void:
	var g := SkinFly.Glide.new()
	var dt := 1.0 / 60.0
	check(not g.active(), "at rest: no glide")
	var last_lean := g.lean()
	var last_cape := float(g.bone("cape_1")["rot"])
	var worst_step := 0.0
	var worst_rot := 0.0
	var at_02 := 0.0
	for i in 150: # 2.5 s of flight
		g.step(dt, true)
		worst_step = maxf(worst_step, absf(g.lean() - last_lean))
		worst_step = maxf(worst_step, absf(float(g.bone("cape_1")["rot"]) - last_cape))
		last_lean = g.lean()
		last_cape = float(g.bone("cape_1")["rot"])
		for b in SkinFly.MOTION:
			worst_rot = maxf(worst_rot, absf(float(g.bone(b)["rot"])))
		if i == 11:
			at_02 = g.lean()
	near(at_02, SkinFly.LEAN_DEG, 0.01, "the lean blended in by 0.2 s")
	check(SkinFly.LEAN_DEG >= 12.0 and SkinFly.LEAN_DEG <= 18.0, "a 12-18 degree lean")
	check(worst_rot <= 25.0, "no bone turns more than 25 degrees (%.1f)" % worst_rot)
	check(worst_step < 2.0, "continuous: under 2 degrees a frame (%.2f)" % worst_step)
	check(g.stream > 0.95 and g.stream < 1.05, "the cape streams back")
	check((g.shard(0)["offset"] as Vector2).x < -0.04, "the shards trail behind")
	check(absf(g.hover()) <= SkinFly.HOVER + 1e-6 and SkinFly.HOVER < SkinIdle.HOVER, "a smaller bob than the idle's")
	var over := 1.0
	for i in 120: # landing
		g.step(dt, false)
		over = minf(over, g.stream)
		worst_step = maxf(worst_step, absf(g.lean() - last_lean))
		last_lean = g.lean()
	check(over < -0.02 and over > -0.4, "the cape settles with a little overshoot (%.3f)" % over)
	near(g.lean(), 0.0, 0.001, "the lean eased out")
	check(worst_step < 2.0, "the landing is continuous too")
	check(not g.active(), "settled")
	check((g.shard(0)["offset"] as Vector2).length() < 0.012, "the shards caught up")
	var tr := SkinFly.tracks(["mist_3", "root"], 360.0)
	near(float(tr["tracks"]["mist_3"]["rot"][0]), float(tr["tracks"]["mist_3"]["rot"][SkinFly.KEYS - 1]), 1e-3, "the glide loop has no seam")
	check(float(SkinFly.MOTION["mist_3"]["lag"]) > float(SkinFly.MOTION["mist_2"]["lag"]) and float(SkinFly.MOTION["mist_2"]["lag"]) > float(SkinFly.MOTION["mist_1"]["lag"]),
		"a travelling wave down the mist")


func test_the_witch_glide_skin() -> void:
	var sk := Art.boss_skin("ice_witch", "fly")
	check(not sk.is_empty() and sk["motion"] == "glide", "assets/bosses/ice_witch/skin/fly/ is the glide")
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://assets/bosses/ice_witch/skin/fly/skin.json"))
	eq(int(raw["gaps"]), 0, "its mesh covers every visible px")
	eq(sk["shards"].size(), 2, "the two shards behind her")
	near(float(sk["height"]), float(Art.boss_skin("ice_witch")["height"]), 0.01, "the same body height as the idle")
	var v := BossSkinView.new()
	v.setup(sk)
	var head0: Vector2 = v.crystal()
	for i in 30:
		v.glide(1.0 / 60.0, true)
	check(absf(v.full_body().rotation - deg_to_rad(SkinFly.LEAN_DEG)) < 0.01, "the body leans forward")
	check(v.crystal().x > head0.x, "the staff's crystal goes forward with the lean")
	v.free()
