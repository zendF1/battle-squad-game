extends "res://tests/test_case.gd"
## Bom liên hoàn against the server's own chains (tests/fixtures/skill_bombchain.json, written by
## the server's TestBombChainOnRealMap with BOMBCHAIN_FIXTURE_OUT: Tanko rank 4 on
## grassland_valley at 600 px: "flat" the bot's best normal shot, "lob" its steep shot, one
## target; "pair" two enemies side by side, lobbed; "vertical" straight up, Tanko's own shaft)
## and its replay view.

const FIXTURE := "res://tests/fixtures/skill_bombchain.json"
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotLook := preload("res://match/views/shot_look.gd")
const BoulderShell := preload("res://match/views/skills/boulder_shell.gd")
const UnitShell := preload("res://match/views/unit_shell.gd")
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
	for k in ["flat", "lob", "pair", "vertical"]:
		check(cases.has(k), "case " + k)
		var tl = ShotTimeline.new(cases[k]["shot"])
		eq(tl.skill_id, "heavy_bomb", k + " skill")
		eq(tl.projectiles.size(), 6, k + " bombs at rank 4")
		for i in range(1, tl.projectiles.size()):
			eq(tl.kind(i), "bomb", "%s bomb %d kind" % [k, i])
			check(tl.launch_time(i) >= tl.launch_time(i - 1) + 0.1 - 1e-6, "%s bomb %d leaves 0.1 s after the previous" % [k, i])
		var falls: Array = tl.events_of("fall")
		# the lob hits the body every time (its bowl does not reach the feet): nobody falls
		check(not falls.is_empty() or k == "lob", k + " someone falls into the hole")
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
			eq(str(x.get("crater", "")), "bowl", k + " explosions carve the gun's bowl")
			check(not x.has("floor"), k + " no floor kept")
		if k == "vertical":
			continue # nobody under it
		check(not tl.events_of("damage").is_empty(), k + " hits")
		check(tl.events_of("status").any(func(e): return str(e.get("effectId", "")) == "root"), k + " root applied")


func test_bomb_size_and_order() -> void:
	near(BombChain.bomb_size_k(true) * ShotLook.SKILL_SCALE, BombChain.BOMB_SCALE, 1e-6, "bomb_size_k kept: 1.4 × a normal shell")
	var v := BombChain.new()
	var view: Node2D = ProjectileView.new()
	view.skill = true
	view.heading = Vector2(1, -1)
	var out: Node2D = v.projectile_view(1, {"kind": "bomb"}, view)
	check(out != view and out is BoulderShell, "each bomb is a dirt-wrapped boulder")
	eq(out.heading, Vector2(1, -1), "it keeps the path's start direction")
	eq(out.z_index, BombChain.BOMBS_Z, "boulders over the explosions")
	near(out.radius, UnitShell.player_shell_px() * BoulderShell.SIZE_K, 1e-4, "sized by a player's shell")
	var shape: PackedVector2Array = out.shape()
	check(shape.size() >= 10 and Array(shape).all(func(p): return p.length() > 0.7 and p.length() < 1.3), "a lumpy round outline")
	view.free()
	out.free()


func test_boulder_trail() -> void:
	var b := BoulderShell.new()
	var host := Node2D.new()
	host.add_child(b)
	b.set_tangent(Vector2(400, -200))
	for i in 20:
		b.position += Vector2(8, -4)
		b._process(1.0 / 60.0)
	check(b.trail_alive() > 0, "crumbs and dust fall off it as it flies")
	check(b.trail_alive() <= BoulderShell.POOL, "a fixed pool")
	host.free()


func test_quake_spikes_and_cracks() -> void:
	var fx := ChainFx.new()
	fx.quake(Vector2(500, 400), 20.0, func(_x): return 390.0, 0)
	eq(fx.spikes(), 6, "three stone spikes each side of the rim")
	eq(fx.cracks(), 4, "two cracks run out each side")
	eq(fx.rings(), 1, "a dust ring along the ground")
	check(fx.alive() > 0, "rocks and dust fly")
	eq(ChainFx.spike_k(0.0, 0.05), 0.0, "not before its delay")
	near(ChainFx.spike_k(0.05 + ChainFx.SPIKE_RISE, 0.05), 1.0, 1e-4, "erupted")
	check(ChainFx.spike_k(0.05 + ChainFx.SPIKE_RISE * 0.7, 0.05) > 1.0, "with an overshoot")
	near(ChainFx.spike_k(0.05 + ChainFx.SPIKE_RISE + ChainFx.SPIKE_HOLD + ChainFx.SPIKE_SINK * 0.5, 0.05), 0.5, 1e-4, "sinking back")
	eq(ChainFx.spike_k(5.0, 0.0), 0.0, "gone")
	var rocks := 0
	for i in 120:
		fx._process(1.0 / 60.0)
		for q in fx._pool:
			if q[0] == ChainFx.ROCK and q[3] < q[4]:
				rocks += 1
				check(q[1].y <= 390.01, "a rock never sinks into the ground: it bounces off it")
	check(rocks > 0, "rock chunks fly")
	eq([fx.spikes(), fx.cracks(), fx.rings()], [0, 0, 0], "they all go")
	fx.free()


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
	near(fx.radius, BombChain.FIRST_BLAST_PX * BombChain.EARTH_SHAKE, 1e-6, "the first blast's size (its shake: a bit heavier)")
	check(not fx.visible, "no fireball: the gun's explosion is hidden, the quake draws the earth burst")
	check(fx.skill, "the first keeps the skill look")
	near(v.rim_y(Vector2(1031, 630), 120.0), 516.0, 1e-6, "no terrain: the rim is the first explosion's y")
	var chain_fx: Node2D = layer.get_child(0)
	eq(chain_fx.alive(), ChainFx.QUAKE_PARTICLES, "no geyser for the surface blast: only its quake's rocks and dust")
	var fx2: Node2D = ExplosionFx.new()
	fx2.radius = 123.8
	fx2.skill = true
	fx2.position = Vector2(1031, 630)
	v.explosion({"type": "explode", "radius": 123.8}, fx2)
	near(fx2.radius, BombChain.SHAFT_BLAST_PX * BombChain.EARTH_SHAKE, 1e-6, "shaft blasts smaller")
	check(not fx2.visible, "no fireball down the shaft either")
	check(not fx2.skill, "no skill flash down the shaft")
	check(chain_fx.alive() > 0, "a geyser out of the hole")
	var n: int = chain_fx.alive()
	var fx3: Node2D = ExplosionFx.new()
	fx3.position = Vector2(1300, 510)
	v.explosion({"type": "explode", "radius": 80.0}, fx3)
	eq(chain_fx.alive(), n + ChainFx.QUAKE_PARTICLES, "a blast up on the surface throws no geyser (its quake only)")
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


## The rim is read from the terrain after the crater: the ground just past the bowl's widest.
## (The lob's bombs go off on the target's body and dig nothing, so the deepest explosion is the
## vertical chain's, at the bottom of Tanko's own shaft.)
func test_rim_from_terrain() -> void:
	var c: Dictionary = _cases()["vertical"]
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
	var edge := BombChain.rim_reach(float(last["radius"]))
	near(edge, float(last["radius"]) * 1.756 + 6.0, 0.01, "past the bowl's widest")
	near(rim, minf(mask.get_landing_y(at.x - edge, 0.0), mask.get_landing_y(at.x + edge, 0.0)), 1e-6, "higher edge")
	# the first bomb's bowl on the surface is not a hole
	var first: Dictionary = tl.events_of("explode")[0]
	var mask0 := TerrainMask.new()
	mask0.load_snapshot(c["terrain"])
	mask0.carve_bowl(float(first["position"]["x"]), float(first["position"]["y"]), float(first["radius"]))
	v.ctx["terrain"] = mask0
	var at0 := Vector2(float(first["position"]["x"]), float(first["position"]["y"]))
	check(at0.y - v.rim_y(at0, float(first["radius"])) <= BombChain.GEYSER_DEPTH, "the first bowl throws no geyser")


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
	v.process(tl.launch_time(1) * 0.5)
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
