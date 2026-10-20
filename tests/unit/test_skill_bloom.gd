extends "res://tests/test_case.gd"
## Hoa hồi xuân's replay (match/views/skills/bloom.gd, bloom_fx.gd) against the server's bloom
## timeline (tests/fixtures/skill_bloom.json, written by the server's TestExportBloomFixture:
## rank 4 on grassland_valley, Flora at x 200 rooted, a teammate across the map at 1400 burned
## and rooted).

const FIXTURE := "res://tests/fixtures/skill_bloom.json"
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const Bloom := preload("res://match/views/skills/bloom.gd")
const BloomFx := preload("res://match/views/skills/bloom_fx.gd")
const ProjectileView := preload("res://match/views/projectile_view.gd")


func _case() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))["bloom"]


func _timeline() -> ShotTimeline:
	return ShotTimeline.new(_case()["shot"])


## Stand-ins for the player views (bloom.gd only reads their position).
func _views(layer: Node2D) -> Dictionary:
	var views := {}
	var players: Dictionary = _case()["players"]
	for id in players:
		var v := Node2D.new()
		v.position = Vector2(float(players[id]["position"]["x"]), float(players[id]["position"]["y"]))
		layer.add_child(v)
		views[id] = v
	return views


func _begin() -> Array:
	var layer := Node2D.new()
	Engine.get_main_loop().root.add_child(layer)
	var views := _views(layer)
	var bloom = Bloom.new()
	bloom.begin({"layer": layer, "timeline": _timeline(), "style": {}, "views": views, "players": {}, "shooter": "flora"})
	return [bloom, layer, views]


func test_seeds_leave_the_screen_and_fall_onto_their_allies() -> void:
	var tl := _timeline()
	var players: Dictionary = _case()["players"]
	eq(tl.projectiles.size(), 2, "one seed per living ally (Flora and her teammate)")
	var exits := []
	for i in tl.projectiles.size():
		eq(tl.kind(i), "seed", "seed %d" % i)
		var plan: Dictionary = Bloom.seed_plan(tl, i)
		var land := tl.projectile_end(i)
		check(plan["exit"] > 0.0 and plan["exit"] < plan["shaft"] and plan["shaft"] < land, "seed %d leaves, then its shaft, then it lands: %s" % [i, plan])
		exits.append(plan["exit"])
		var ally: Dictionary = players[str(tl.projectiles[i]["hitPlayerId"])]
		var back: Vector2 = tl.sample(i, plan["shaft"] + Bloom.FALL_LEAD)
		near(back.x, float(ally["position"]["x"]), 0.5, "seed %d comes back into view right above its ally" % i)
		check(back.y >= Bloom.OFF_SCREEN, "seed %d in view after its shaft's lead" % i)
		check(tl.sample(i, plan["shaft"]).y < Bloom.OFF_SCREEN, "the shaft shows before seed %d is in view" % i)
	near(exits[0], exits[1], 1e-6, "the seeds rise together")
	var heals := tl.events_of("heal")
	eq(heals.size(), 2, "a heal per ally")
	near(float(heals[0]["t"]), tl.projectile_end(0), 1e-6, "the heal lands with the seed")
	check(tl.duration > tl.projectile_end(0) + 0.5, "the replay lasts on for the bloom")


func test_seed_plan_old_server_path() -> void:
	# A seed that never leaves the screen (the first server's arc): no exit, the shaft 0.5 s before
	var tl := ShotTimeline.new({"projectiles": [{"kind": "seed", "path": [
		{"time": 0.0, "position": {"x": 100, "y": 500}, "velocity": {"x": 0, "y": -400}},
		{"time": 0.5, "position": {"x": 200, "y": 200}, "velocity": {"x": 200, "y": 0}},
		{"time": 1.1, "position": {"x": 400, "y": 480}, "velocity": {"x": 200, "y": 600}}]}]})
	var plan: Dictionary = Bloom.seed_plan(tl, 0)
	eq(plan["exit"], -1.0, "no exit")
	near(plan["shaft"], 0.6, 1e-6, "shaft OLD_FALL before landing")


func test_begin_plans_the_exit_and_shafts() -> void:
	var r := _begin()
	var bloom = r[0]
	var fx = bloom.fx
	check(fx != null and fx.get_parent() == r[1], "the fx on the fx layer")
	eq(fx._exits.size(), 1, "one burst where the seeds leave the screen")
	eq(fx._shafts.size(), 2, "a shaft over each ally")
	check(fx.busy(bloom._last_land), "busy until the seeds land")
	r[1].free()


func test_seed_glow_only_on_seeds() -> void:
	var bloom = Bloom.new()
	var seed_view := Node2D.new()
	eq(bloom.projectile_view(0, {"kind": "seed"}, seed_view), seed_view, "the gun's own shell stays")
	eq(seed_view.get_child_count(), 1, "a glow behind the seed")
	var other := Node2D.new()
	bloom.projectile_view(0, {"kind": ""}, other)
	eq(other.get_child_count(), 0, "no glow on another projectile")
	seed_view.free()
	other.free()


func test_events_spawn_the_bloom_shield_and_cleanse() -> void:
	var r := _begin()
	var bloom = r[0]
	var tl := _timeline()
	for e in tl.events:
		bloom.on_event(e)
	var fx = bloom.fx
	eq(fx._blooms.size(), 2, "a bloom on each ally")
	eq(fx._shields.size(), 2, "both overflowed into shield")
	eq(fx._cleanses.size(), 2, "both cleansed")
	bloom.on_event({"t": 1.4, "type": "shield", "playerId": "flora", "amount": 0})
	eq(fx._shields.size(), 2, "no shield gained: no bubble")
	bloom.on_event({"t": 1.4, "type": "heal", "playerId": "nobody", "amount": 10})
	eq(fx._blooms.size(), 2, "an unknown player is ignored")
	bloom.on_event({"t": 1.4, "type": "damage", "playerId": "flora", "amount": 10})
	eq(fx._blooms.size(), 2, "other events draw nothing")
	r[1].free()


func test_fx_outlives_the_replay_then_frees_itself() -> void:
	var r := _begin()
	var bloom = r[0]
	var fx = bloom.fx
	var tl := _timeline()
	for e in tl.events:
		bloom.on_event(e)
	bloom.process(tl.duration)
	bloom.end()
	check(not fx.is_queued_for_deletion(), "the bloom plays on after the replay")
	fx._process(0.016)
	near(fx.t, tl.duration, 1e-6, "synced to the replay's last frame")
	fx._process(0.1)
	near(fx.t, tl.duration + 0.1, 1e-6, "then its own clock")
	for k in 40:
		if fx.is_queued_for_deletion():
			break
		fx._process(0.1)
	check(fx.is_queued_for_deletion(), "freed once the last effect is over")
	r[1].free()


func test_dropped_replay_takes_the_fx_away() -> void:
	var r := _begin()
	var bloom = r[0]
	var fx = bloom.fx
	bloom.process(0.3)
	bloom.end()
	check(fx.is_queued_for_deletion(), "a replay stopped before the seeds land: no lone shafts")
	r[1].free()


func test_bloom_aims_nothing() -> void:
	var bloom = Bloom.new()
	eq(bloom.aim_mode(), Bloom.AIM_NONE, "fired on tap")
	check(bloom.describe(4).contains("60%") and bloom.describe(4).contains("50%"), "rank 4: Flora 60 %, teammates 50 %")
