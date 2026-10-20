extends "res://tests/test_case.gd"
## Missile rain replay against the server's rain fixture (tests/fixtures/skill_rain.json,
## written by the server's TestExportRainFixture: rank 4, dragon bazooka, grassland_valley, a
## Tanko and a Spark, and the Tanko's burn tick at its next turn start).

const FIXTURE := "res://tests/fixtures/skill_rain.json"
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const ShotLook := preload("res://match/views/shot_look.gd")
const ProjectileView := preload("res://match/views/projectile_view.gd")
const RainView := preload("res://match/views/skills/rain.gd")
const BurnFx := preload("res://match/views/skills/burn_fx.gd")
const DamagePopup := preload("res://match/views/damage_popup.gd")


func _fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func _begun(tl, layer: Node2D) -> RainView:
	var v := RainView.new()
	v.begin({"layer": layer, "timeline": tl, "style": {"kind": "bazooka", "tier": "dragon", "skill": true, "item": ""}})
	return v


func test_fixture_shape() -> void:
	var f := _fixture()
	var tl = ShotTimeline.new(f["rain"]["shot"])
	eq(tl.skill_id, "triple_shot", "the rain's skill id")
	eq(tl.kind(0), "flare", "the flare first")
	eq(tl.projectiles.size(), 15, "the flare and 14 missiles at rank 4")
	var rain: Dictionary = tl.events_of("rain")[0]
	eq(int(rain["count"]), 14, "rain count")
	near(float(rain["radius"]), 150.0, 1e-6, "rain spread at rank 4")
	near(float(rain["t"]) - float(tl.events_of("flare")[0]["t"]), 0.5, 1e-6, "the rain starts 0.5 s after the flare lands")
	for i in range(1, tl.projectiles.size()):
		eq(tl.kind(i), "missile", "missile %d" % i)
		check(tl.launch_time(i) >= float(rain["t"]) - 1e-6, "missile %d leaves with the rain" % i)
		var top: Vector2 = tl.sample(i, tl.launch_time(i))
		var bottom: Vector2 = tl.sample(i, tl.projectile_end(i))
		check(top.y < 0.0, "missile %d starts above the map" % i)
		near(bottom.x, top.x, 0.5, "missile %d falls straight down" % i)
		check(tl.projectile_end(i) - tl.launch_time(i) < 1.0, "missile %d falls fast" % i)
	var tick: Dictionary = f["burnTick"][0]
	eq(str(tick["type"]), "burn", "the burn tick")
	eq(int(tick["damage"]), int(f["rain"]["players"][str(tick["playerId"])]["maxHp"]) / 10, "10% of max HP")


func test_projectile_views() -> void:
	var tl = ShotTimeline.new(_fixture()["rain"]["shot"])
	var layer := Node2D.new()
	var v := _begun(tl, layer)
	var flare := ProjectileView.new()
	flare.skill = true
	check(v.projectile_view(0, tl.projectiles[0], flare) == flare, "the flare keeps the gun's shell")
	near(flare.trail_length, RainView.FLARE_TRAIL, 1e-6, "the flare's own trail is short: its red smoke is the trail")
	check(flare.skill, "the flare is the skill's big shell")
	var missile := ProjectileView.new()
	missile.skill = true
	check(v.projectile_view(1, tl.projectiles[1], missile) == missile, "a missile keeps the gun's shell")
	check(not missile.skill, "missiles at normal size")
	near(missile.trail_length, RainView.MISSILE_TRAIL, 1e-6, "missiles with a short trail")
	flare.free()
	missile.free()
	layer.free()


func test_missile_bursts_are_smaller() -> void:
	var tl = ShotTimeline.new(_fixture()["rain"]["shot"])
	var layer := Node2D.new()
	var v := _begun(tl, layer)
	var e: Dictionary = tl.events_of("explode")[0]
	check(v.is_missile(str(e["projectileId"])), "the rain's explosions are missiles'")
	var boom = load("res://match/views/explosion_fx.gd").new()
	boom.radius = 40.0
	boom.skill = true
	v.explosion(e, boom)
	near(boom.radius, 40.0 * RainView.MISSILE_BURST, 1e-6, "smaller burst")
	check(not boom.skill, "not the skill's bigger burst")
	var other = load("res://match/views/explosion_fx.gd").new()
	other.radius = 40.0
	other.skill = true
	v.explosion({"projectileId": "someone-else"}, other)
	near(other.radius, 40.0, 1e-6, "another explosion unchanged")
	check(other.skill, "another explosion keeps its look")
	boom.free()
	other.free()
	layer.free()


func test_flare_light_column_and_fade() -> void:
	var tl = ShotTimeline.new(_fixture()["rain"]["shot"])
	var layer := Node2D.new()
	var v := _begun(tl, layer)
	eq(layer.get_child_count(), 1, "one overlay for the light and the smoke")
	var fx = layer.get_child(0)
	v.process(tl.projectile_end(0) * 0.5)
	check(v.fx_state()["flying"], "the red light follows the flare in flight")
	for k in 20:
		v.process(tl.projectile_end(0) * (0.5 + k * 0.01))
		fx._process(1.0 / 60.0)
	check(int(v.fx_state()["puffs"]) > 0, "a red smoke trail behind the flare")
	var flare: Dictionary = tl.events_of("flare")[0]
	v.on_event(flare)
	v.process(float(flare["t"]) + 0.01)
	var s: Dictionary = v.fx_state()
	check(s["landed"] and s["column"] and not s["flying"], "landed: the signal column, the light is on the ground")
	var before := int(s["puffs"])
	for k in 30:
		fx._process(1.0 / 60.0)
	check(int(v.fx_state()["puffs"]) > before, "the column keeps rising")
	v.on_event(tl.events_of("rain")[0])
	check(v.fx_state()["raining"], "the rain started")
	for k in 600:
		fx._process(1.0 / 60.0) # a long rain: the pool never grows
	check(int(v.fx_state()["puffs"]) <= RainView.RainFx.POOL, "fixed pool")
	v.end()
	check(fx.state()["fading"] and not fx.state()["column"], "after the replay the column stops and fades")
	for k in 300:
		fx._process(1.0 / 60.0)
	check(fx.is_queued_for_deletion(), "then the overlay frees itself")
	eq(v.fx_state(), {}, "the view lets go of it at the end")
	layer.remove_child(fx) # queued: deleted at the end of the frame
	layer.free()


func test_flare_lost_draws_no_column() -> void:
	# The flare left the map: the server sends only the flare, no flare / rain events.
	var tl = ShotTimeline.new({"actionMode": "skill", "skillId": "triple_shot", "duration": 1.0,
		"projectiles": [{"projectileId": "f", "kind": "flare", "path": [{"position": {"x": 0, "y": 0}, "velocity": {"x": -150, "y": 0}, "time": 0.0},
			{"position": {"x": -150, "y": 300}, "velocity": {"x": -150, "y": 600}, "time": 1.0}]}], "events": []})
	var layer := Node2D.new()
	var v := _begun(tl, layer)
	v.process(0.5)
	v.process(1.2)
	var s: Dictionary = v.fx_state()
	check(not s["flying"] and not s["landed"], "no light after it is gone, no column")
	v.end()
	layer.get_child(0).free()
	layer.free()


func test_trail_length_shortens_the_shell_trail() -> void:
	var full := ProjectileView.new()
	full.kind = "bazooka"
	full.tier = "dragon"
	full._ready()
	var short := ProjectileView.new()
	short.kind = "bazooka"
	short.tier = "dragon"
	short.trail_length = 0.4
	short._ready()
	var points := int(ShotLook.tier_theme("dragon")["ribbon"]["points"])
	eq(int(full._ribbon_spec["points"]), points, "full tail by default")
	eq(int(short._ribbon_spec["points"]), int(points * 0.4), "a shorter tail")
	eq(int(ShotLook.tier_theme("dragon")["ribbon"]["points"]), points, "the shared theme is not changed")
	check(short._trail_keep < full._trail_keep, "a shorter line")
	near(float(short._kind_trail["life"]), float(ShotLook.KINDS["bazooka"]["trail"]["life"]) * 0.4, 1e-6, "shorter-lived smoke")
	near(float(ShotLook.KINDS["bazooka"]["trail"]["life"]), float(full._kind_trail["life"]), 1e-6, "the shared spec is not changed")
	full.free()
	short.free()


func test_popup_stagger() -> void:
	eq(DamagePopup.stagger(0), Vector2.ZERO, "the first number at its usual spot")
	var seen := {}
	for n in range(1, 5):
		var o: Vector2 = DamagePopup.stagger(n)
		check(o != Vector2.ZERO and not seen.has(o), "number %d in a row steps aside" % n)
		seen[o] = true
	eq(DamagePopup.stagger(5), Vector2.ZERO, "then it starts over")


func test_burn_flash_frees_itself() -> void:
	var b := BurnFx.new()
	b._ready()
	var steps := 0
	while not b.is_queued_for_deletion() and steps < 200:
		b._process(1.0 / 60.0)
		steps += 1
	check(b.is_queued_for_deletion(), "the burn flash ends")
	near(steps / 60.0, BurnFx.LIFE, 0.05, "after its life")


func test_describe_counts() -> void:
	var v := RainView.new()
	check(v.describe(0).contains("6 tên lửa"), "rank 0: 6 missiles")
	check(v.describe(4).contains("14 tên lửa"), "rank 4: 14 missiles")
	eq(v.skill_name(), "Mưa tên lửa", "name")
