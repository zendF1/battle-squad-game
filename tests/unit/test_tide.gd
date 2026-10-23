extends "res://tests/test_case.gd"
## Tide (water): the game data (character, water orb with a bounce, snow nova), the water orb's
## bounce in the replay (ShotTimeline: the bounce point twice in the path with the same time, the
## arrival then the departure velocity; projectiles[].bounces as "bounce" events), the nova's ring
## timing (nova.gd / nova_fx.gd: castTime + distance / waveSpeed) and her placeholder art.

const GameData := preload("res://autoload/game_data_model.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const Skills := preload("res://match/skills.gd")
const NovaView := preload("res://match/views/skills/nova.gd")
const NovaFx := preload("res://match/views/skills/nova_fx.gd")
const WaterSplash := preload("res://match/views/water_splash.gd")
const Art := preload("res://ui/art.gd")

const G := 445.0


func test_game_data() -> void:
	eq([GameData.character_name("tide"), GameData.character_element("tide"), GameData.character_gun_kind("tide")], ["Tide", "water", "water_gun"], "Tide")
	eq(GameData.character_skill_id("tide"), "snow_nova", "her skill")
	eq(GameData.skill_effect_type("snow_nova"), "nova", "a nova")
	eq(GameData.skill_aim_kind("snow_nova"), "none", "fired on tap")
	eq(int(GameData.weapon("water_orb").get("bounces", 0)), 1, "the orb bounces once")
	eq(int(GameData.weapon("basic_rocket").get("bounces", -1)), 0, "the others do not")
	check(Skills.view_for_character("tide") is NovaView, "the nova's view")
	check(not bool(Skills.for_character("tide")["needs_aim"]), "no aiming")
	check(Skills.describe("tide", 0).contains("500") and Skills.describe("tide", 0).contains("130%"), "described at rank 0")
	eq(Art.character_gun("tide"), "water_gun", "her gun art")
	check(Art.PLACEHOLDER_CHARACTERS.has("tide"), "placeholder art until art_source/characters/tide/PROMPTS.md is drawn")


## A lob hitting the ground at t 1.0 (x 300, y 500), bouncing up-right, then exploding at 1.5.
func _bounce_shot() -> Dictionary:
	var path: Array = []
	var p := Vector2(100, 400)
	var v := Vector2(200, -100)
	for k in 21: # 0 .. 1.0 every 0.05
		var t := k * 0.05
		path.append({"position": {"x": p.x + v.x * t, "y": p.y + v.y * t + 0.5 * G * t * t}, "velocity": {"x": v.x, "y": v.y + G * t}, "time": t})
	var hit: Dictionary = path[-1]["position"]
	var arrive := Vector2(v.x, v.y + G * 1.0)
	var leave := Vector2(arrive.x * 0.85, -arrive.y * 0.55)
	path.append({"position": hit, "velocity": {"x": leave.x, "y": leave.y}, "time": 1.0}) # the bounce point again, leaving
	var b := Vector2(float(hit["x"]), float(hit["y"]))
	for k in range(1, 11):
		var t := k * 0.05
		path.append({"position": {"x": b.x + leave.x * t, "y": b.y + leave.y * t + 0.5 * G * t * t}, "velocity": {"x": leave.x, "y": leave.y + G * t}, "time": 1.0 + t})
	return {"shooterId": "tide", "actionMode": "weapon", "duration": 1.6,
		"projectiles": [{"projectileId": "p1", "kind": "", "path": path, "bounces": [{"t": 1.0, "position": hit}]}],
		"events": [{"t": 1.5, "type": "explode", "position": path[-1]["position"], "radius": 10, "projectileId": "p1"}]}


func test_bounce_replay() -> void:
	var shot := _bounce_shot()
	var tl := ShotTimeline.new(shot)
	var hit: Vector2 = tl.bounces(0)[0]["position"]
	eq(tl.bounces(0).size(), 1, "one bounce")
	near(tl.sample(0, 1.0).distance_to(hit), 0.0, 0.01, "at the bounce time: on the bounce point")
	near(tl.sample(0, 0.999).distance_to(hit), 0.0, 1.0, "just before: arriving there")
	near(tl.sample(0, 1.001).distance_to(hit), 0.0, 1.0, "just after: leaving it")
	check(tl.sample(0, 0.97).y < hit.y and tl.sample(0, 0.97).x < hit.x, "coming down onto it from the left")
	check(tl.sample(0, 1.05).y < hit.y and tl.sample(0, 1.05).x > hit.x, "going up off it to the right")
	check(tl.velocity(0, 0.98).y > 0.0 and tl.velocity(0, 1.02).y < 0.0, "falling before, rising after: the turn is at the bounce")
	# both legs exactly the server's arcs
	var b := hit
	var leave := Vector2(200 * 0.85, -(-100 + G) * 0.55)
	var t := 0.12
	near(tl.sample(0, 1.0 + t).distance_to(b + leave * t + Vector2(0, 0.5 * G * t * t)), 0.0, 0.05, "the leg after: the departure arc")
	near(tl.sample(0, 0.5).distance_to(Vector2(100 + 200 * 0.5, 400 - 50 + 0.5 * G * 0.25)), 0.0, 0.05, "the leg before: the shot's arc")
	var types: Array = tl.events.map(func(e): return str(e["type"]))
	eq(types, ["bounce", "explode"], "the bounce is an event in time order")
	eq(tl.events_of("bounce")[0]["projectileId"], "p1", "of its projectile")
	eq(shot["events"].size(), 1, "the payload's own list is left as it is")
	var tl2 := ShotTimeline.new({"projectiles": [{"projectileId": "x", "path": []}], "events": []})
	eq([tl2.bounces(0), tl2.events], [[], []], "no bounces: none")


func test_water_splash() -> void:
	var s := WaterSplash.new()
	s._ready()
	check(s.life() > 0.3, "a splash lasts a moment")
	var big := WaterSplash.new()
	big.big = true
	big._ready()
	check(big.life() > s.life() and big._drops.size() > s._drops.size(), "the burst: bigger and longer")
	s.free()
	big.free()


func test_nova_ring_timing() -> void:
	var fx := NovaFx.new()
	fx.t0 = 0.35
	fx.radius = 500.0
	fx.duration = 500.0 / 1400.0
	eq(fx.ring_radius(0.2), 0.0, "nothing before castTime")
	near(fx.ring_radius(0.35 + 0.1), 140.0, 1e-3, "at waveSpeed 1400 px/s")
	near(fx.ring_radius(5.0), 500.0, 1e-3, "stops at the radius")
	for d in [0.0, 120.0, 350.0, 500.0]:
		near(fx.reach_time(d), 0.35 + d / 1400.0, 1e-4, "the ring reaches %d px when the server hits it" % d)
		near(fx.ring_radius(fx.reach_time(d)), d, 1e-3, "and is there then (%d)" % d)
	eq(fx.sigil_k(0.3), 0.0, "the sigil flashes at the nova")
	check(fx.sigil_k(0.35 + 0.15) > 1.0, "popping in with an overshoot")
	eq(fx.sigil_k(0.35 + NovaFx.SIGIL_SEC + 0.1), 0.0, "then gone")
	check(fx.end_time() > fx.t0 + fx.duration, "it outlives the ring (the frost thaws after)")
	fx.free()


func test_nova_view_reads_the_event() -> void:
	var v = Skills.view_for_skill("snow_nova")
	var layer := Node2D.new()
	var tl := ShotTimeline.new({"shooterId": "tide", "actionMode": "skill", "skillId": "snow_nova", "projectiles": [], "duration": 1.0,
		"events": [{"t": 0.35, "type": "nova", "playerId": "tide", "position": {"x": 400, "y": 300}, "radius": 480, "duration": 0.34},
			{"t": 0.45, "type": "damage", "playerId": "e1", "amount": 300, "hp": 900, "cause": "nova"},
			{"t": 0.45, "type": "status", "playerId": "e1", "effectId": "freeze", "turns": 1}]})
	v.begin({"layer": layer, "timeline": tl, "views": {}, "players": {}, "shooter": "tide"})
	eq([v.t0(), v.radius(), v.ring_sec()], [0.35, 480.0, 0.34], "the event's numbers")
	eq(v.centre(), Vector2(400, 300), "at Tide's body centre")
	eq(v.frame_size(), Vector2(960, 576), "the camera frames the whole radius")
	check(not v.tracks_shells(), "no shells to follow")
	var fx: Node2D = v.fx()
	eq([fx.t0, fx.radius, fx.duration], [0.35, 480.0, 0.34], "the fx gets them")
	v.end()
	var w = Skills.view_for_skill("snow_nova")
	w.begin({"layer": layer, "timeline": ShotTimeline.new({"projectiles": [], "events": []}), "views": {}, "shooter": "tide"})
	near(w.t0(), GameData.skill_param("snow_nova", "castTime"), 1e-6, "no event: the params' castTime")
	near(w.ring_sec(), GameData.skill_param("snow_nova", "radius") / GameData.skill_param("snow_nova", "waveSpeed"), 1e-6, "radius / waveSpeed")
	layer.free()


func test_placeholder_art() -> void:
	check(Art.has_side_view("tide"), "her side view")
	var look := Art.character_look("tide")
	check(bool(look["side"]), "drawn from it (not rookie's)")
	check(not look["ready"].is_empty(), "with her ready pose (scenes/character/poses/tide_ready.tscn)")
	check(FileAccess.file_exists(Art.full_path("tide")) and FileAccess.file_exists(Art.portrait_path("tide")), "lobby picture and portrait")
	check(not Art.hug_meta("water_gun", "iron").is_empty(), "her water gun's hug art")
