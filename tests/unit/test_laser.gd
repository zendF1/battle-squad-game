extends "res://tests/test_case.gd"
## Tia laze (match/views/skills/laser.gd + laser_fx.gd) against the server's grassland laser scene
## (tests/fixtures/skill_laser.json, written by the server's TestExportLaserFixture): Spark with a
## dragon shock rifle on the right hill, the beam down through the hill into the valley hitting a
## Rookie then a Tanko; the stunned Rookie's next TurnStarted.

const FIXTURE := "res://tests/fixtures/skill_laser.json"
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const LaserFx := preload("res://match/views/skills/laser_fx.gd")
const LaserView := preload("res://match/views/skills/laser.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const ShotLook := preload("res://match/views/shot_look.gd")
const Status := preload("res://match/status_effects.gd")


func _case() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))["laser"]


func _pos(p: Dictionary) -> Vector2:
	return Vector2(float(p["position"]["x"]), float(p["position"]["y"]))


func test_fixture_two_enemies_nearest_first() -> void:
	var c := _case()
	var tl = ShotTimeline.new(c["shot"])
	eq(tl.skill_id, "shock_field", "laser skill")
	eq(tl.projectiles.size(), 0, "no projectile")
	var hits: Array = tl.events_of("damage").filter(func(e): return str(e.get("cause", "")) == "laser")
	eq(hits.size(), 2, "both enemies on the line are hit")
	if hits.size() != 2:
		return
	eq(str(hits[0]["playerId"]), "e1", "the nearer Rookie first")
	eq(str(hits[1]["playerId"]), "e2", "then the Tanko")
	check(float(hits[1]["t"]) > float(hits[0]["t"]), "the farther hit comes later")
	check(int(hits[1]["amount"]) < int(hits[0]["amount"]), "the second hit is weaker (×0.8)")
	eq(tl.events_of("status").size(), 2, "both stunned")
	eq(tl.events_of("explode").size(), 0, "no crater")
	eq(c["terrain"]["solid"], c["terrainAfter"]["solid"], "the terrain is untouched")
	var started: Dictionary = c["turnStarted"]
	eq(str(started.get("skipped", "")), "stun", "the stunned enemy loses the turn")
	eq(Status.skip_text(str(started["skipped"])), "Choáng — mất lượt", "its banner")


func _fx(c: Dictionary) -> Node2D:
	var mask := TerrainMask.new()
	mask.load_snapshot(c["terrain"])
	var tl = ShotTimeline.new(c["shot"])
	var fx: Node2D = LaserFx.new()
	fx.setup(tl.events_of("beam")[0], {"kind": "shock_rifle", "tier": "dragon"}, mask)
	return fx


## The drawn front (SWEEP_SPEED, the server's laserSweepSpeed) reaches every enemy by the time its
## damage event comes, and not long before.
func test_beam_front_reaches_each_hit_on_time() -> void:
	var c := _case()
	var fx := _fx(c)
	var tl = ShotTimeline.new(c["shot"])
	var beam: Dictionary = tl.events_of("beam")[0]
	near(fx.beam_t, float(beam["t"]), 1e-9, "the charge lasts until the beam event")
	check(fx.beam_t > 0.0, "a charge before the beam")
	eq(fx.front_at(fx.beam_t - 0.01), 0.0, "nothing out while charging")
	for e in tl.events_of("damage"):
		var body := _pos(c["players"][str(e["playerId"])]) - Vector2(0, 20)
		var s: float = (body - fx.from).dot(fx.dir)
		var front: float = fx.front_at(float(e["t"]))
		check(front >= s - 1.0, "%s: front %.0f reaches %.0f at the hit" % [e["playerId"], front, s])
		check(front <= s + 60.0, "%s: and not long before" % e["playerId"])
	near(fx.front_at(fx.beam_t + fx.beam_duration), fx.length(), 1e-3, "the beam ends at the map edge")
	fx.free()


func test_beam_crosses_the_hill() -> void:
	var fx := _fx(_case())
	check(fx.crossings.size() >= 2, "the beam goes into and out of the hill (%d spots)" % fx.crossings.size())
	if fx.crossings.size() >= 2:
		check(fx.crossings[1] - fx.crossings[0] > 50.0, "through a real stretch of ground")
	eq(LaserFx.ground_crossings(Vector2.ZERO, Vector2(100, 0), null).size(), 0, "no terrain: no spots")
	fx.free()


func test_palettes() -> void:
	var dragon := LaserFx.palette("shock_rifle", "dragon")
	check(dragon["glow"].r > dragon["glow"].b, "dragon: a red-orange beam like its shell")
	var steel := LaserFx.palette("shock_rifle", "steel")
	check(steel["glow"].b > steel["glow"].g, "steel: purple")
	var blaster := LaserFx.palette("blaster", "gold")
	eq(blaster["glow"], ShotLook.accent("blaster", "gold"), "a Blaster wearer: the blaster's colours")
	eq(LaserFx.palette("shock_rifle", "titan")["glow"], ShotLook.accent("shock_rifle", "titan"), "crafted tiers from the accents")


func test_hits_and_lifetime() -> void:
	var c := _case()
	var fx := _fx(c)
	var body := _pos(c["players"]["e1"]) - Vector2(0, 20)
	var at: Vector2 = fx.hit(body, 0.42)
	check(at.distance_to(body) <= 34.0, "the flash on the beam next to the body")
	near((at - fx.from).normalized().dot(fx.dir), 1.0, 1e-3, "on the beam")
	eq(fx.hit_count(), 1, "one hit")
	for i in LaserFx.MAX_HITS + 2:
		fx.hit(body, 0.5)
	eq(fx.hit_count(), LaserFx.MAX_HITS, "hits capped")
	check(fx.done_at() >= 0.5 + LaserFx.HIT_LIFE, "kept until the last hit stops crackling")
	check(not fx.is_released(), "driven by the replay")
	fx.release()
	check(fx.is_released(), "runs on its own after the replay")
	fx.free()


## The charge orb is a bright energy ball at every tier (the dragon's dark-red shell read as a dark
## ball): a bright body, a white-hot centre on top, the shell only faint inside; it grows over the
## charge and is gone when the beam is.
func test_charge_orb_is_bright_at_every_tier() -> void:
	var c := _case()
	var beam: Dictionary = ShotTimeline.new(c["shot"]).events_of("beam")[0]
	check(LaserFx.SHELL_ALPHA <= 0.35, "the shell only faint in the orb")
	var styles := []
	for tier in ShotLook.TIERS:
		styles.append({"kind": "shock_rifle", "tier": tier})
	styles.append({"kind": "blaster", "tier": "basic"})
	styles.append({"kind": "blaster", "tier": "gold"})
	for st in styles:
		var fx: Node2D = LaserFx.new()
		fx.setup(beam, st)
		var name := "%s %s" % [st["kind"], st["tier"]]
		check(fx.orb_body(1.0).v >= 0.85, "%s: a bright orb body (v %.2f)" % [name, fx.orb_body(1.0).v])
		check(fx.colors["core"].v >= 0.95, "%s: a bright core" % name)
		check(fx.orb_size(fx.beam_t) > fx.orb_size(0.0) * 2.0, "%s: grows over the charge" % name)
		near(fx.orb_size(fx.beam_t + fx.beam_duration), 0.0, 1e-6, "%s: gone with the beam" % name)
		fx.free()


## laser.gd: begin adds the beam to the layer, a laser damage event adds a hit and a burst, end
## releases it; no beam event (an old server) draws nothing.
func test_view_hooks() -> void:
	var c := _case()
	var tl = ShotTimeline.new(c["shot"])
	var layer := Node2D.new()
	var e1 := Node2D.new()
	e1.position = _pos(c["players"]["e1"])
	var view = LaserView.new()
	view.begin({"layer": layer, "timeline": tl, "style": {"kind": "shock_rifle", "tier": "dragon"},
		"views": {"e1": e1}, "players": c["players"], "shooter": "spark", "terrain": null})
	eq(layer.get_child_count(), 1, "the beam fx")
	var fx = layer.get_child(0)
	view.process(0.1)
	for e in tl.events_of("damage"):
		view.on_event(e)
	eq(fx.hit_count(), 1, "the hit with a view (e1)")
	eq(layer.get_child_count(), 2, "and its burst")
	view.on_event({"type": "damage", "playerId": "e1", "cause": "explosion", "t": 0.5})
	eq(fx.hit_count(), 1, "not for other damage")
	view.end()
	check(fx.is_released(), "released at the end")
	near(view.aim_angle(tl), float(c["angle"]), 0.01, "the gun points along the beam")
	var old = LaserView.new()
	var layer2 := Node2D.new()
	old.begin({"layer": layer2, "timeline": ShotTimeline.new({"events": [{"t": 0.1, "type": "damage", "playerId": "e1", "cause": "laser"}]})})
	eq(layer2.get_child_count(), 0, "no beam event: nothing")
	old.on_event({"type": "damage", "cause": "laser", "playerId": "e1"})
	old.end()
	layer.free()
	layer2.free()
	e1.free()


func test_aim_line_reads_as_a_beam() -> void:
	var aim = AimInput.new()
	check(AimInput.LINE_COLOR.b > 0.9 and AimInput.LINE_COLOR.a > AimInput.ARC_COLOR.a, "a brighter blue line")
	check(AimInput.LINE_GLOW_WIDTH > AimInput.LINE_WIDTH, "over a wider glow")
	aim.free()
