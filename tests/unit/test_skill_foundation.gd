extends "res://tests/test_case.gd"
## The skill foundation against real server timelines (tests/fixtures/skill_shots.json, written
## by the server's TestExportSkillFixture: the four skills at rank 4 on grassland_valley).

const FIXTURE := "res://tests/fixtures/skill_shots.json"
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const SkillView := preload("res://match/views/skills/skill_view.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const Hud := preload("res://match/hud.gd")
const MatchScreen := preload("res://match/match_screen.gd")


func _cases() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func test_fixture_timelines_parse() -> void:
	var c := _cases()
	for k in ["rain", "chain", "laser", "bloom"]:
		check(c.has(k), "case " + k)
	var rain = ShotTimeline.new(c["rain"]["shot"])
	eq(rain.action_mode, "skill", "skill shot")
	eq(rain.skill_id, "triple_shot", "skill id")
	eq(rain.kind(0), "flare", "the flare first")
	eq(rain.kind(1), "missile", "then missiles")
	check(rain.launch_time(1) > rain.projectile_end(0), "missiles leave after the flare lands")
	eq(rain.events_of("flare").size(), 1, "flare event")
	eq(int(rain.events_of("rain")[0]["count"]), 28, "rank 4 rain: 28")
	check(rain.skill_energies.has("rookie"), "skillEnergies")
	var chain = ShotTimeline.new(c["chain"]["shot"])
	for i in chain.projectiles.size():
		eq(chain.kind(i), "bomb", "bomb %d" % i)
		if i == 0:
			near(chain.launch_time(i), 0.0, 1e-6, "the first bomb leaves with the shot")
		else:
			check(chain.launch_time(i) >= chain.launch_time(i - 1) + 0.1 - 1e-6, "bomb %d leaves at least 0.1 s after the previous" % i)
	var laser = ShotTimeline.new(c["laser"]["shot"])
	eq(laser.projectiles.size(), 0, "laser: no projectile")
	eq(laser.events_of("beam").size(), 1, "beam event")
	var angle: float = Skills().view_for_skill("shock_field").aim_angle(laser)
	check(not is_nan(angle), "the gun points along the beam")
	var bloom = ShotTimeline.new(c["bloom"]["shot"])
	eq(bloom.kind(0), "seed", "seeds")
	check(bloom.events_of("shield").size() > 0 and bloom.events_of("cleanse").size() > 0, "shield and cleanse events")


func Skills():
	return preload("res://match/skills.gd")


func test_old_server_fallbacks() -> void:
	var tl = ShotTimeline.new({"projectiles": [{"projectileId": "a", "path": [{"time": 0.4, "position": {"x": 0, "y": 0}}]}]})
	eq(tl.kind(0), "", "no kind: a normal shell")
	near(tl.launch_time(0), 0.4, 1e-9, "no launchDelay: the first sample's time")
	eq(tl.skill_energies, {}, "no skillEnergies")
	eq(tl.skill_id, "", "no skill id")
	eq(ShotTimeline.new({"projectiles": null, "events": null}).projectiles, [], "null lists")


## A SkillView recording its calls.
class FakeView extends "res://match/views/skills/skill_view.gd":
	var calls: Array = []
	func projectile_view(i: int, p: Dictionary, view: Node2D) -> Node2D:
		calls.append("view:%d:%s" % [i, str(p.get("kind", ""))])
		return view
	func process(_t: float) -> void:
		if not calls.has("process"):
			calls.append("process")
	func end() -> void:
		calls.append("end")


func test_shot_player_hides_until_launch_and_calls_the_skill_view() -> void:
	var c := _cases()
	var tl = ShotTimeline.new(c["chain"]["shot"])
	var player = ShotPlayer.new()
	player.layer = Node2D.new()
	var fake := FakeView.new()
	player.skill_view = fake
	player.play(tl)
	eq(fake.calls.slice(0, 2), ["view:0:bomb", "view:1:bomb"], "a view per projectile")
	check(player.layer.get_child(0).visible and not player.layer.get_child(1).visible, "only the first bomb is out at t 0")
	var t := (tl.launch_time(1) + tl.launch_time(2)) * 0.5 # between the second and the third launch
	player._process(t)
	check(player.layer.get_child(1).visible, "the second bomb out after its launch")
	check(not player.layer.get_child(2).visible, "the third not yet")
	check(fake.calls.has("process"), "process every frame")
	near(player.spawn_offset(1, 0.3).length(), 0.0, 1e-9, "no muzzle given: no offset")
	player.stop()
	check(fake.calls.has("end"), "end when it stops")
	player.layer.free()
	player.free()


func test_chain_carves_bowls_like_the_server() -> void:
	var c: Dictionary = _cases()["chain"]
	var m := TerrainMask.new()
	check(m.load_snapshot(c["terrain"]), "load the terrain before")
	for e in c["shot"]["events"]:
		if e["type"] == "explode":
			eq(str(e.get("crater", "")), TerrainMask.CRATER_BOWL, "the chain digs the gun's own bowls")
			check(not e.has("floor"), "no floor kept")
			m.carve(str(e.get("crater", "")), float(e["position"]["x"]), float(e["position"]["y"]), float(e["radius"]))
	var after := TerrainMask.new()
	after.load_snapshot(c["terrainAfter"])
	var diff := 0
	for i in m.solid.size():
		if m.solid[i] != after.solid[i]:
			diff += 1
	eq(diff, 0, "solid pixels differing from the server after the chain")


func test_beam_end_reaches_the_map_edge() -> void:
	var t := TerrainMask.new()
	t.width = 1600
	t.height = 900
	eq(AimInput.beam_end(Vector2(200, 400), 0.0, t), Vector2(1600, 400), "right")
	var down: Vector2 = AimInput.beam_end(Vector2(200, 400), -45.0, t)
	near(down.y, 900.0, 1e-3, "down to the bottom")
	near(down.x, 700.0, 1e-3, "at 45°")
	var up: Vector2 = AimInput.beam_end(Vector2(200, 400), 90.0, t)
	near(up.y, 0.0, 1e-3, "up to the top")


func _view(p: Dictionary) -> Node2D:
	var holder := Node2D.new()
	var v: Node2D = PlayerView.new()
	holder.add_child(v)
	var base := {"playerId": "p", "teamId": 1, "characterId": "rookie", "hp": 1000, "maxHp": 1500, "isAlive": true,
		"position": {"x": 0.0, "y": 0.0}}
	base.merge(p, true)
	v.setup(base, false, 1)
	return v


func test_player_view_shield_and_icons() -> void:
	var v := _view({"shield": 300, "statusEffects": [{"effectId": "burn", "durationTurn": 1}, {"effectId": "power_shot", "durationTurn": 1}]})
	eq(v.shield, 300, "shield from the payload")
	eq(v.status_icons(), ["burn", "shield"], "effect icons, then the shield")
	eq(v.status_text(), "x1.5", "shot modifiers stay text")
	var f: Dictionary = v.bar_fractions()
	near(f["hp"], 1000.0 / 1500.0, 1e-6, "hp share")
	near(f["shield"], 300.0 / 1500.0, 1e-6, "shield after it")
	v.set_hp(1500)
	v.set_shield(500)
	f = v.bar_fractions()
	near(f["hp"] + f["shield"], 1.0, 1e-6, "past the max: the bar spans HP + shield")
	near(f["shield"], 500.0 / 2000.0, 1e-6, "shield share")
	v.set_shield(0)
	v.set_status([])
	eq(v.status_icons(), [], "cleared")
	eq(_view({}).shield, 0, "no shield field: 0")
	v.get_parent().free()


func test_hud_notice_and_skip_banner() -> void:
	var h: Control = Hud.new()
	h._ready()
	h.set_move_notice("Bị cầm chân")
	eq(h.move_notice(), "Bị cầm chân", "root notice")
	h.set_move_notice("")
	eq(h.move_notice(), "", "hidden")
	h.announce_skip("Choáng — mất lượt")
	eq(h.skip_text(), "Choáng — mất lượt", "skip banner")
	h.announce_skip("")
	eq(h.skip_text(), "", "hidden")
	h.free()


func test_shield_popup_text() -> void:
	eq(MatchScreen.shield_text(1250), "+1.250 khiên", "shield gain")
