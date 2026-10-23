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
	for anim in ["idle", "fly", "cast", "burst", "blizzard", "summon", "hurt"]:
		check(side["anims"].has(anim) and not side["anims"][anim]["frames"].is_empty(), "%s frames" % anim)
	eq(side["anims"]["burst"]["peak"], 2, "the burst's flash is its third frame")
	check(bool(side["anims"]["idle"]["loop"]) and bool(side["anims"]["fly"]["loop"]), "idle and fly loop")
	var tex: Texture2D = side["anims"]["idle"]["frames"][0]
	eq(Vector2(tex.get_size()), side["size"], "every frame on the shared canvas")
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
	b.hurt()
	eq(b.shown_frame()[0], "hurt", "a hit plays hurt")
	check(b.is_flashing(), "and flashes")
	b._process(0.5)
	eq(b.shown_frame()[0], "idle", "briefly")
	b.set_flight(true)
	b._process(0.05)
	eq(b.shown_frame()[0], "fly", "a hover move: fly")
	b.set_flight(false)
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
