extends "res://tests/test_case.gd"
## Bom liên hoàn against the server's own chains (tests/fixtures/skill_bombchain.json, written by
## the server's TestBombChainOnRealMap with BOMBCHAIN_FIXTURE_OUT: Tanko rank 4 on
## grassland_valley at 600 px: "flat" the bot's best normal shot, "lob" its steep shot, one
## target; "pair" two enemies side by side, lobbed) and its replay view.

const FIXTURE := "res://tests/fixtures/skill_bombchain.json"
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotLook := preload("res://match/views/shot_look.gd")
const ProjectileView := preload("res://match/views/projectile_view.gd")
const ExplosionFx := preload("res://match/views/explosion_fx.gd")
const BombChain := preload("res://match/views/skills/bomb_chain.gd")
const ChainFx := preload("res://match/views/skills/bomb_chain_fx.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")


func _cases() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


## The server's pacing as the client replays it: the bombs leave at least 0.1 s apart, each
## explodes only once every fall started before it has landed (the target is never hit while
## still drawn falling), and every bomb flies the first one's arc (nothing steers it).
func test_server_chain_is_coherent_to_replay() -> void:
	var cases := _cases()
	for k in ["flat", "lob", "pair"]:
		check(cases.has(k), "case " + k)
		var tl = ShotTimeline.new(cases[k]["shot"])
		eq(tl.skill_id, "heavy_bomb", k + " skill")
		eq(tl.projectiles.size(), 7, k + " bombs at rank 4")
		for i in range(1, tl.projectiles.size()):
			eq(tl.kind(i), "bomb", "%s bomb %d kind" % [k, i])
			check(tl.launch_time(i) >= tl.launch_time(i - 1) + 0.1 - 1e-6, "%s bomb %d leaves 0.1 s after the previous" % [k, i])
		var falls: Array = tl.events_of("fall")
		check(not falls.is_empty(), k + " the target falls into the hole")
		for i in range(1, tl.projectiles.size()):
			var t0: float = tl.launch_time(i)
			var end := minf(tl.projectile_end(0), tl.projectile_end(i) - t0)
			for t in [0.2, end * 0.5, end - 0.05]:
				check(tl.sample(i, t0 + t).distance_to(tl.sample(0, t)) < 0.5, "%s bomb %d on the first one's arc at %.2f s" % [k, i, t])
		for x in tl.events_of("explode"):
			var t := float(x["t"])
			for f in falls:
				var start := float(f["t"])
				if start < t:
					check(start + float(f.get("duration", 0.0)) <= t + 1e-6,
						"%s: explosion at %.2f while %s falls until %.2f" % [k, t, str(f["playerId"]), start + float(f["duration"])])
			check(float(x.get("floor", 0.0)) > 0.0, k + " explosions keep the floor")
		check(not tl.events_of("damage").is_empty(), k + " hits")
		check(tl.events_of("status").any(func(e): return str(e.get("effectId", "")) == "root"), k + " root applied")


func test_bomb_size_and_order() -> void:
	near(BombChain.bomb_size_k(true) * ShotLook.SKILL_SCALE, BombChain.BOMB_SCALE, 1e-6, "a skill bomb is 1.4 × a normal shell")
	near(BombChain.bomb_size_k(false), BombChain.BOMB_SCALE, 1e-6, "without the skill look")
	var v := BombChain.new()
	var view: Node2D = ProjectileView.new()
	view.skill = true
	var out: Node2D = v.projectile_view(1, {"kind": "bomb"}, view)
	check(out == view, "the gun's own shell is kept")
	near(view.size_k * ShotLook.SKILL_SCALE, 1.4, 1e-6, "size_k set")
	eq(view.z_index, BombChain.BOMBS_Z, "bombs over the explosions")
	view.free()


func test_explosions_and_geyser() -> void:
	var layer := Node2D.new()
	var shooter := Node2D.new()
	var target := Node2D.new()
	target.z_index = 0
	var v := BombChain.new()
	var tl = ShotTimeline.new(_cases()["lob"]["shot"])
	v.begin({"layer": layer, "timeline": tl, "style": {"kind": "cannon", "tier": "dragon", "skill": true}, "views": {"e1": target}, "shooter": "nobody"})
	eq(target.z_index, BombChain.PLAYERS_Z, "players over the explosions during the chain")
	check(v.merges_damage(), "the chain's hits count up in one number")
	var fx: Node2D = ExplosionFx.new()
	fx.radius = 145.6
	fx.skill = true
	fx.position = Vector2(1042, 516)
	v.explosion({"type": "explode", "radius": 145.6}, fx)
	near(fx.radius, BombChain.FIRST_BLAST_PX, 1e-6, "the first blast drawn big but not over the whole hole")
	check(fx.skill, "the first keeps the skill look")
	near(v.rim_y(Vector2(1031, 630), 120.0), 516.0, 1e-6, "no terrain: the rim is the first explosion's y")
	var chain_fx: Node2D = layer.get_child(0)
	eq(chain_fx.alive(), 0, "no geyser for the surface blast")
	var fx2: Node2D = ExplosionFx.new()
	fx2.radius = 123.8
	fx2.skill = true
	fx2.position = Vector2(1031, 630)
	v.explosion({"type": "explode", "radius": 123.8}, fx2)
	near(fx2.radius, BombChain.SHAFT_BLAST_PX, 1e-6, "shaft blasts smaller")
	check(not fx2.skill, "no skill flash down the shaft")
	check(chain_fx.alive() > 0, "a geyser out of the hole")
	var n: int = chain_fx.alive()
	var fx3: Node2D = ExplosionFx.new()
	fx3.position = Vector2(1300, 510)
	v.explosion({"type": "explode", "radius": 80.0}, fx3)
	eq(chain_fx.alive(), n, "a blast up on the surface throws no geyser")
	fx3.free()
	for i in 40:
		v.explosion({"type": "explode", "radius": 60.0}, fx2)
	check(chain_fx.alive() <= ChainFx.MAX, "the pool is bounded")
	v.end()
	eq(target.z_index, 0, "players' order restored")
	fx.free()
	fx2.free()
	layer.free()
	shooter.free()
	target.free()


## The rim is read from the terrain after the crater: the ground just past both crater edges.
## (The lob's later bombs go off on the target's body in its small shaft, so the deepest
## explosion is the pair's, down the shaft between the two enemies.)
func test_rim_from_terrain() -> void:
	var c: Dictionary = _cases()["pair"]
	var mask := TerrainMask.new()
	mask.load_snapshot(c["terrainAfter"])
	var v := BombChain.new()
	v.begin({"terrain": mask, "views": {}})
	var tl = ShotTimeline.new(c["shot"])
	var last: Dictionary = tl.events_of("explode")[-1]
	for x in tl.events_of("explode"):
		if float(x["position"]["y"]) > float(last["position"]["y"]):
			last = x
	var at := Vector2(float(last["position"]["x"]), float(last["position"]["y"]))
	var rim := v.rim_y(at, float(last["radius"]))
	check(at.y - rim > BombChain.GEYSER_DEPTH, "the deepest bomb is down a hole: %.0f under the rim %.0f" % [at.y - rim, rim])
	near(rim, minf(mask.get_landing_y(at.x - float(last["radius"]) - 6.0, 0.0), mask.get_landing_y(at.x + float(last["radius"]) + 6.0, 0.0)), 1e-6, "higher edge")


class FakeShooter extends Node2D:
	var shots := 0
	func gun_state() -> String:
		return "aiming"
	func shoot(_with_gun: bool = true) -> float:
		shots += 1
		return 0.0
	func muzzle_position() -> Vector2:
		return Vector2(470, 590)


func test_gun_kicks_for_each_later_bomb() -> void:
	var layer := Node2D.new()
	var shooter := FakeShooter.new()
	var v := BombChain.new()
	var tl = ShotTimeline.new(_cases()["lob"]["shot"])
	v.begin({"layer": layer, "timeline": tl, "style": {}, "views": {"tanko": shooter}, "shooter": "tanko"})
	v.process(0.1)
	eq(shooter.shots, 0, "the first bomb leaves with the shot itself")
	v.process(tl.launch_time(2) + 0.01)
	eq(shooter.shots, 2, "two more kicks by the third bomb")
	v.process(10.0)
	eq(shooter.shots, tl.projectiles.size() - 1, "one kick per later bomb")
	check(layer.get_child(0).alive() > 0, "muzzle smoke")
	v.end()
	layer.free()
	shooter.free()


func test_chain_fx_frees_itself_after_finish() -> void:
	var fx: Node2D = ChainFx.new()
	fx.puff(Vector2.ZERO)
	check(fx.alive() > 0, "puff spawns")
	fx.finish()
	check(not fx.is_queued_for_deletion(), "waits for its particles")
	fx.free()
	var empty: Node2D = ChainFx.new()
	var holder := Node.new()
	holder.add_child(empty)
	empty.finish()
	check(empty.is_queued_for_deletion(), "nothing left: freed at once")
	holder.free()
