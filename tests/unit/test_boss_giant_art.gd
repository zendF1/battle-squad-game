extends "res://tests/test_case.gd"
## Khổng Lồ Đá (rock_giant)'s drawn art in a match (match/boss/boss_body.gd and friends): its
## constants (BossArt HEART / MUZZLE / TOP / WIDTH / DEATH), the points per frame (Art.boss_points()),
## the skin's amber gem and eyes, no hover, the plates carried by the frames' joints, the heart and
## the muzzle per frame, its skills' animations (BossAnim.action_for() with the recorded shots of
## tests/fixtures/boss_v5_shots.json and the game data of boss_gamedata.json), the stomp's dust and
## shockwave ring, and the crumble.

const Art := preload("res://ui/art.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const BossAnim := preload("res://match/boss/boss_anim.gd")
const BossBody := preload("res://match/boss/boss_body.gd")
const BossSkinView := preload("res://match/boss/boss_skin_view.gd")
const SkinIdle := preload("res://match/boss/skin_idle.gd")
const SHOTS := "res://tests/fixtures/boss_v5_shots.json"
const GAMEDATA := "res://tests/fixtures/boss_gamedata.json"
const DT := 1.0 / 60.0


static func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## The giant's skill (game data fixture) by id.
static func _skill(id: String) -> Dictionary:
	for b in _json(GAMEDATA)["bosses"]:
		if str(b.get("bossId", "")) == "rock_giant":
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


func _giant(h: float = 200.0) -> BossBody:
	var b := BossBody.new()
	b.setup("rock_giant", h)
	return b


func test_constants_of_the_drawn_giant() -> void:
	eq(BossArt.HEART["rock_giant"], Vector2(6.67, -50.91), "the heart is the chest gem")
	eq(BossArt.MUZZLE["rock_giant"], Vector2(63.95, -74.94), "the muzzle is the throwing knuckles at the throw's peak")
	near(BossArt.top("rock_giant"), 1.0, 1e-6, "the horns are its top")
	near(float(BossArt.WIDTH["rock_giant"]), 0.92, 1e-6, "its width")
	eq(BossArt.death_of("rock_giant"), "crumble", "it crumbles")
	eq([BossArt.death_of("ice_witch"), BossArt.death_of("steel_robot")], ["shatter", "crash"], "the witch shatters, the saucer crashes")
	eq(BossArt.FRAME_PLATES.size(), BossArt.PLATES.size(), "a drawn plate for each plate")
	var side := Art.boss_side("rock_giant")
	check(not side.is_empty(), "the giant is drawn from frames")
	near(BossArt.shield_radius("rock_giant", 100.0), 50.0 + 100.0 * BossArt.SHIELD_MARGIN, 1e-4, "the ball round its height (narrower than tall)")


func test_points_per_frame() -> void:
	var pts := Art.boss_points("rock_giant")
	check(not pts.is_empty(), "points.json is read")
	var side := Art.boss_side("rock_giant")
	for anim in side["anims"]:
		eq(pts["frames"][anim].size(), side["anims"][anim]["frames"].size(), "a point set per %s frame" % anim)
	var idle: Dictionary = pts["frames"]["idle"][0]
	check(idle["heart"] is Vector2 and idle["chest"] is Vector3, "points and joints")
	for j in ["chest", "pauldron_l", "pauldron_r", "pelvis", "head"]:
		check(pts["rest"].get(j) is Vector2, "rest joint %s" % j)
	var peak: Dictionary = pts["frames"]["throw"][int(side["anims"]["throw"]["peak"])]
	check(Vector2(peak["hand_r"]).distance_to(BossArt.MUZZLE["rock_giant"]) < 0.05, "the throw's peak knuckles = MUZZLE")
	check(Art.boss_points("ice_witch").is_empty(), "the witch has none")
	var parts := Art.boss_parts("rock_giant")
	eq(parts["parts"].size(), 18, "18 death pieces")
	eq(int(parts["parts"]["helmet"]["z"]), 17, "the helmet in front")


func test_skin_glow_eyes_and_no_hover() -> void:
	var skin := Art.boss_skin("rock_giant")
	check(not skin.is_empty(), "a skinned idle")
	check(not SkinIdle.hovers(skin), "it breathes on its feet")
	check(SkinIdle.hovers(Art.boss_skin("ice_witch")), "the witch floats")
	var v := BossSkinView.new()
	v.setup(skin)
	eq(v.glow_colour(), Color(1.0, 0.76, 0.24), "the gem's amber")
	eq(v.eyes().size(), 2, "two eyes")
	var rest_eye: Vector2 = v.eyes()[0]
	v.advance(0.7)
	check(Vector2(v.eyes()[0]).distance_to(rest_eye) < 6.0, "the eyes ride the head, a little")
	check(v.crystal().distance_to(Vector2(skin["glow"]) - Vector2(skin["pivot"])) < 6.0, "the glow is the gem on the torso")
	v.free()
	var w := BossSkinView.new()
	w.setup(Art.boss_skin("ice_witch"))
	eq(w.glow_colour(), BossSkinView.GLOW_COLOUR, "the witch's crystal stays cyan")
	eq(w.eyes().size(), 0, "no eyes drawn on her")
	w.free()
	var dims: Array = []
	for i in 240:
		dims.append(SkinIdle.eyes(i * SkinIdle.PERIOD / 240.0))
	check(dims.min() < 0.4 and dims.max() > 0.8, "the eyes flicker and dim once a loop (%s..%s)" % [dims.min(), dims.max()])
	var b := _giant()
	for i in 90:
		b._process(DT)
		near(b._bob_px(), 0.0, 1e-6, "no float")
	b.free()
	var wb := BossBody.new()
	wb.setup("ice_witch", 160.0)
	var moved := false
	for i in 60:
		wb._process(DT)
		moved = moved or absf(wb._bob_px()) > 0.5
	check(moved, "the witch still floats")
	wb.free()


func test_plates_follow_the_frames() -> void:
	var b := _giant()
	b.set_armored(true, false)
	var names: Array = []
	for c in b.get_children():
		names.append(str(c.name))
	check(names.find("Plates") > names.find("Frames") and names.find("Plates") > names.find("Skin"), "drawn over the frames and the skin (%s)" % [names])
	b._process(DT)
	check(b.showing_skin(), "idle: the skin")
	var on_skin := b.plate_poses()
	eq(on_skin.size(), BossArt.FRAME_PLATES.size(), "a pose per plate")
	for i in on_skin.size():
		var c := Vector2(on_skin[i] * Vector2(BossArt.FRAME_PLATES[i]["at"]))
		check(c.distance_to(BossArt.FRAME_PLATES[i]["at"]) < 2.0, "on the skin near its rest (%d: %s)" % [i, c])
	b.play_action({"anim": "throw"})
	for i in 200:
		if b.shown_frame() == ["throw", 4]:
			break
		b._process(1.0 / 120.0)
	eq(b.shown_frame(), ["throw", 4], "the throw's peak shows")
	var pts := Art.boss_points("rock_giant")
	var f: Dictionary = pts["frames"]["throw"][4]
	var poses := b.plate_poses()
	var pad: Vector3 = f["pauldron_r"]
	var rest: Vector2 = pts["rest"]["pauldron_r"]
	var want := Vector2(pad.x, pad.y) + (Vector2(BossArt.FRAME_PLATES[1]["at"]) - rest).rotated(deg_to_rad(pad.z))
	check(Vector2(poses[1] * Vector2(BossArt.FRAME_PLATES[1]["at"])).distance_to(want) < 1e-3, "the right pad's plate rides its joint")
	var hand := b.to_local(b.muzzle_position())
	var unit := Vector2(f["hand_r"]) * 2.0 # 200 px tall: 2 px a unit
	check(hand.distance_to(unit) < 0.5, "the muzzle is the knuckles (%s / %s)" % [hand, unit])
	var heart := b.to_local(b.heart_position())
	check(heart.distance_to(Vector2(f["heart"]) * 2.0) < 0.5, "the heart is the frame's gem")
	b.face(-1)
	check(b.to_local(b.heart_position()).x < 0.0 == (Vector2(f["heart"]).x > 0.0), "mirrored facing left")
	b.set_armored(false)
	check(b.plates_breaking(), "they break off")
	b.free()
	var d := _giant()
	d.set_armored(true, false)
	d.die()
	check(d.plates_breaking() and d.plates_shown() == 0.0, "its death breaks them off")
	d.free()


func test_skills_play_their_animations() -> void:
	var shots := _json(SHOTS)
	var quake: Dictionary = shots["earthquake"]["shot"]
	var a := BossAnim.action_for("skill", "earthquake", _skill("earthquake"), quake["events"], _launches(quake))
	eq(a["anim"], "stomp", "the earthquake stomps")
	near(a["at"], 0.6, 1e-6, "its peak on the quake")
	var roll: Dictionary = shots["rolling_boulder"]["shot"]
	a = BossAnim.action_for("skill", "rolling_boulder", _skill("rolling_boulder"), roll["events"], _launches(roll))
	eq(a["anim"], "roll", "the rolling boulder is pushed")
	near(a["at"], float(_launches(roll).min()), 1e-6, "its peak as the boulder leaves")
	var totems: Dictionary = shots["totem_raise"]["shot"]
	a = BossAnim.action_for("summon", "totem_raise", {}, totems["events"], [])
	eq(a["anim"], "summon", "the totems raised")
	near(a["at"], 0.6, 1e-6, "on the first totem")
	check(not _skill("giant_boulder").is_empty() and _skill("giant_boulder")["kind"] == "rain", "the giant boulder is a rain from the boss")
	a = BossAnim.action_for("skill", "giant_boulder", _skill("giant_boulder"), [], [0.7])
	eq([a["anim"], a["at"]], ["throw", 0.7], "the giant boulder is thrown, the peak as it leaves")
	eq(BossAnim.action_for("skill", "boulder_rain", {"kind": "rain"}, [], [0.5])["anim"], "throw", "the older boulder rain too")
	var mark := {"t": 0.55, "type": "mark", "playerId": "p0", "position": {"x": 300, "y": 700}, "radius": 70, "markId": "mark_1"}
	a = BossAnim.action_for("skill", "stone_spikes", _skill("stone_spikes"), [mark], [])
	eq([a["anim"], a["at"]], ["spikes", 0.55], "the spikes: fists on the ground as the marks open")
	var erupt := {"t": 0.6, "type": "eruption", "playerId": "p0", "markId": "mark_1"}
	a = BossAnim.action_for("turn_start", "stone_spikes", _skill("stone_spikes"), [erupt], [])
	eq([a["anim"], a["at"]], ["spikes", 0.6], "and again as they erupt on its turn start")
	eq(BossAnim.action_for("turn_start", "", {}, [], [])["anim"], "cast", "another turn start: as before")
	eq(BossAnim.action_for("skill", "ice_spikes", {}, [], [0.4])["anim"], "cast", "the witch unchanged")
	var anim := BossAnim.new(Art.boss_side("rock_giant")["anims"])
	eq(anim.resolve("cast"), "throw", "a plain shot: it throws")
	eq(anim.resolve("hurt"), "hurt", "its own")
	check(anim.play("cast") > 0.0 and anim.playing() == "throw", "played")
	var witch := BossAnim.new(Art.boss_side("ice_witch")["anims"])
	eq(witch.resolve("cast"), "cast", "the witch casts")
	var b := _giant()
	b.hurt()
	eq(b.shown_frame()[0], "hurt", "a hit: its hurt frames")
	b.free()


func test_stomp_dust_and_ring() -> void:
	var b := _giant()
	b.play_action({"anim": "stomp"})
	var peak := int(Art.boss_side("rock_giant")["anims"]["stomp"]["peak"])
	var ring = null
	for i in 120:
		b._process(1.0 / 60.0)
		ring = b.get_node_or_null("StompRing")
		if ring != null:
			break
	check(ring != null, "the stomp's shockwave ring")
	eq(b.shown_frame(), ["stomp", peak], "at its peak frame")
	var foot: Vector2 = ring.wave["origin"]
	check(foot.x > 0.0 and absf(foot.y) < 5.0, "at the right foot, on the ground (%s)" % foot)
	check(b._dust.size() >= BossBody.STOMP_PUFFS and b._pebbles.size() >= BossBody.STOMP_PEBBLES, "dust and pebbles")
	for i in 30:
		b._process(1.0 / 60.0)
	var rings := 0
	for c in b.get_children():
		rings += 1 if str(c.name).begins_with("StompRing") else 0
	eq(rings, 1, "once")
	b._process(2.0)
	check(b._dust.is_empty(), "the dust settles")
	b.free()


func test_crumble_phases() -> void:
	var b := _giant()
	b._process(0.2)
	b.die()
	eq(b.death_phase(), "crack", "the death frames crack it")
	eq(b.shown_frame(), ["death", 0], "from its first death frame")
	var swap := b.crumble_swap_sec()
	near(swap, 2.0 / 6.0, 1e-4, "the parts take over on death frame 2")
	b._process(swap * 0.6)
	eq(b.shown_frame(), ["death", 1], "frame 1")
	eq(b.rubble_count(), 0, "still whole")
	b._process(swap * 0.4 + 0.01)
	eq(b.death_phase(), "crumble", "it falls apart")
	eq(b.rubble_count(), 18, "into its parts")
	var horns: Array = b.rubble().filter(func(r): return str(r["name"]).begins_with("horn"))
	eq(horns.size(), 2, "both horns")
	var horn_at: Vector2 = horns[0]["c"]
	var chest: Dictionary = b.rubble().filter(func(r): return r["name"] == "chest")[0]
	var chest_at: Vector2 = chest["c"]
	check(b._dust.size() > 0 and b._pebbles.size() > 0, "a dust burst and pebbles")
	var zs: Array = b.rubble().map(func(r): return int(r["z"]))
	var sorted := zs.duplicate()
	sorted.sort()
	eq(zs, sorted, "drawn back to front")
	b._process(BossBody.HORN_DELAY * 0.5)
	check(Vector2(horns[0]["c"]).distance_to(horn_at) < 0.01, "the horns hold on a moment")
	check(Vector2(chest["c"]).distance_to(chest_at) > 1.0, "while the rest falls")
	for i in int(BossBody.CRUMBLE_FALL / DT):
		b._process(DT)
	eq(b.death_phase(), "fade", "then it fades")
	for r in b.rubble():
		var sz: Vector2 = r["size"]
		var hh := 0.5 * (absf(sz.x * sin(float(r["rot"]))) + absf(sz.y * cos(float(r["rot"])))) * 0.8
		check(absf(Vector2(r["c"]).y + hh - float(r["ground"])) < 1.0, "%s settled on the ground" % r["name"])
		check(Vector2(r["v"]).length() < 40.0, "%s at rest (%s)" % [r["name"], r["v"]])
	check(absf(float(horns[0]["rot"])) > 0.5, "the horns tumbled")
	b._process(BossBody.CRUMBLE_FADE + 0.05)
	eq(b.death_phase(), "gone", "gone")
	near(b.death_progress(), 1.0, 1e-6, "done")
	b.free()
