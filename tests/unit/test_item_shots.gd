extends "res://tests/test_case.gd"
## The five shot items (server contract boss-tiers-items.md): their game data, icons, the
## timelines (two shells on one path, three in a fan, the signal / strike / nuke / laser) and
## the replay visuals (match/views/items/).

const GameData := preload("res://autoload/game_data_model.gd")
const Art := preload("res://ui/art.gd")
const Items := preload("res://match/items.gd")
const Fixture := preload("res://tests/item_shot_fixture.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const ProjectileView := preload("res://match/views/projectile_view.gd")
const ItemViews := preload("res://match/views/items/item_views.gd")
const PoisonShot := preload("res://match/views/items/poison_shot.gd")
const StrikeShot := preload("res://match/views/items/strike_shot.gd")
const SignalShell := preload("res://match/views/items/signal_shell.gd")
const NukeShell := preload("res://match/views/items/nuke_shell.gd")
const StrikeFx := preload("res://match/views/items/strike_fx.gd")
const NukeBlast := preload("res://match/views/items/nuke_blast.gd")
const SporeFx := preload("res://match/boss/spore_fx.gd")

const NEW := ["poison_bomb", "double_shot", "triple_shot", "nuke_bomb", "laser_strike"]


func test_game_data() -> void:
	for id in NEW:
		check(Items.is_known(id), "%s in GET /gamedata items" % id)
		check(not Items.is_instant(id) and not Items.needs_target_x(id), "%s: a shot item aimed like a shot" % id)
		check(GameData.item_description(id) != "", "%s: a description" % id)
	eq(Items.order().slice(-5), NEW, "in the server's order, after the old ones")
	eq([Items.label("double_shot"), Items.label("nuke_bomb")], ["Bắn đôi (x2)", "Bom huỷ diệt"], "names from the game data")
	eq([GameData.item_type("poison_bomb"), GameData.item_type("triple_shot"), GameData.item_type("laser_strike")],
		["poison", "fan_shot", "laser"], "types")
	eq([GameData.item_param("triple_shot", "spreadDeg"), GameData.item_param("laser_strike", "beams")], [5.0, 5.0], "params")
	eq(GameData.item_param("medkit", "beams", -1.0), -1.0, "no params: the fallback")
	eq(GameData.item_description("nope"), "", "unknown item: no description")


func test_icons() -> void:
	var unknown := Art.icon_path(Art.UNKNOWN_ICON)
	for id in NEW:
		check(Art.ICONS.has(id), "%s has an icon" % id)
		check(ResourceLoader.exists(Art.icon_path(id)), "%s: its icon is imported" % id)
		check(Art.item_icon(id).resource_path != unknown, "%s: not the unknown icon" % id)
	eq(ProjectileView.ITEM_LOOKS["poison_bomb"]["mark"], "toxic", "the poison shell: green with bubbles")


func test_views_by_type() -> void:
	check(ItemViews.view_for(ShotTimeline.new(Fixture.poison())).get_script() == PoisonShot, "poison: the cloud")
	check(ItemViews.view_for(ShotTimeline.new(Fixture.nuke())).get_script() == StrikeShot, "nuke: the strike")
	check(ItemViews.view_for(ShotTimeline.new(Fixture.laser())).get_script() == StrikeShot, "laser: the strike")
	check(ItemViews.view_for(ShotTimeline.new(Fixture.double())) == null, "double: plain shells")
	check(ItemViews.view_for(ShotTimeline.new(Fixture.triple())) == null, "triple: plain shells")
	var odd := Fixture.laser()
	odd["itemId"] = "future_item"
	check(ItemViews.view_for(ShotTimeline.new(odd)).get_script() == StrikeShot, "an unknown item with a strike event: a strike")
	eq(StrikeShot.strike_kind({"kind": "laser"}), "laser", "kind sent")
	eq(StrikeShot.strike_kind({"itemId": "laser_strike"}), "laser", "kind from the item's type")
	eq(StrikeShot.strike_kind({}), "nuke", "unknown: a nuke")


func test_timelines() -> void:
	var d = ShotTimeline.new(Fixture.double())
	eq(d.projectiles.size(), 2, "two shells")
	near(d.launch_time(1) - d.launch_time(0), 0.25, 1e-9, "the second 0.25 s behind")
	eq(d.sample(1, 0.25 + 0.3), d.sample(0, 0.3), "on the same path")
	eq(d.events_of("explode").size(), 2, "each its own explosion")
	var t = ShotTimeline.new(Fixture.triple())
	eq(t.projectiles.size(), 3, "three shells")
	var v0: Vector2 = t.start_velocity(0)
	var v1: Vector2 = t.start_velocity(1)
	var v2: Vector2 = t.start_velocity(2)
	near(rad_to_deg(v0.angle_to(v1)), -5.0, 0.01, "fanned 5° apart (lower)")
	near(rad_to_deg(v1.angle_to(v2)), -5.0, 0.01, "fanned 5° apart (higher)")
	near(t.launch_time(2), 0.0, 1e-9, "fired together")
	var n = ShotTimeline.new(Fixture.nuke())
	eq([n.kind(0), n.kind(1)], ["signal", "nuke"], "the signal, then the nuke")
	var strike: Dictionary = n.events_of("strike")[0]
	near(n.launch_time(1), float(strike["t"]) + 0.5, 1e-9, "the nuke leaves delaySec after the signal lands")
	near(n.projectile_end(1), float(n.events_of("explode")[0]["t"]), 1e-9, "it explodes where it lands")
	check(n.sample(1, n.launch_time(1)).y < 0.0, "from above the map")
	check(ShotPlayer.ARROW_KINDS.has("signal") and not ShotPlayer.ARROW_KINDS.has("nuke"),
		"the signal gets the off-screen arrow like a shell, the falling nuke does not")


func test_poison_cloud() -> void:
	var layer := Node2D.new()
	var v: Variant = PoisonShot.new()
	v.begin({"layer": layer, "timeline": ShotTimeline.new(Fixture.poison())})
	var e: Dictionary = Fixture.poison()["events"][0]
	var fx := _fx(40.0)
	v.explosion(e, fx)
	var clouds := layer.get_children().filter(func(c): return c.get_script() == SporeFx)
	eq(clouds.size(), 2, "a pop and a lingering cloud")
	near(clouds[0].radius, PoisonShot.cloud_reach(40.0), 1e-6, "over the blast")
	near(PoisonShot.cloud_reach(4.0), PoisonShot.MIN_REACH, 1e-6, "never tiny")
	fx.free()
	layer.free()


func test_nuke_replay() -> void:
	var payload := Fixture.nuke()
	var timeline = ShotTimeline.new(payload)
	var layer := Node2D.new()
	var v: Variant = StrikeShot.new()
	v.begin({"layer": layer, "timeline": timeline})
	var shell := ProjectileView.new()
	var sig = v.projectile_view(0, timeline.projectiles[0], shell)
	check(sig is SignalShell and not sig.laser, "the signal: a red flare")
	var bomb = v.projectile_view(1, timeline.projectiles[1], shell)
	check(bomb is NukeShell, "the falling nuke")
	check(v.projectile_view(0, {"kind": ""}, shell) == shell, "any other shell kept")
	v.on_event(timeline.events_of("strike")[0])
	var st: Dictionary = v.state()
	eq([st["kind"], st["radius"]], ["nuke", 100.0], "the strike")
	eq(st["fx"]["kind"], "nuke", "its marker")
	var fx := _fx(45.0)
	v.explosion(timeline.events_of("explode")[0], fx)
	eq(fx.radius, 100.0, "the burst covers the blast's reach")
	eq(layer.get_children().filter(func(c): return c.get_script() == NukeBlast).size(), 1, "the mushroom cloud")
	check(v.state()["fx"]["hit"], "the marker knows it hit")
	v.end()
	for n in [shell, sig, bomb, fx]:
		n.free()
	layer.free()


func test_laser_replay() -> void:
	var timeline = ShotTimeline.new(Fixture.laser())
	var layer := Node2D.new()
	var v: Variant = StrikeShot.new()
	v.begin({"layer": layer, "timeline": timeline})
	var shell := ProjectileView.new()
	var sig = v.projectile_view(0, timeline.projectiles[0], shell)
	check(sig is SignalShell and sig.laser, "the signal: the laser's colour")
	v.on_event(timeline.events_of("strike")[0])
	eq(v.state()["fx"]["beams"], 5, "five beams")
	var fx := _fx(5.4)
	v.explosion(timeline.events_of("explode")[0], fx)
	eq(fx.radius, 40.0, "the burst: the strike's radius, not the small crater")
	check(v.state()["fx"]["hit"], "the beams fire")
	eq(layer.get_children().filter(func(c): return c.get_script() == NukeBlast).size(), 0, "no mushroom")
	v.end()
	for n in [shell, sig, fx]:
		n.free()
	layer.free()


func test_beam_angles() -> void:
	var a := StrikeFx.beam_angles(5)
	eq(a.size(), 5, "one per beam")
	for x in a:
		check(sin(x) < -0.3, "from the sky")
	near(a[0] + a[4], -PI, 1e-6, "mirrored about the vertical")
	near(a[2], -PI / 2, 1e-6, "the middle one straight down")
	eq(StrikeFx.beam_angles(1), [-PI / 2], "a single beam from above")


func test_shot_player_flies_both_shells() -> void:
	var timeline = ShotTimeline.new(Fixture.double())
	var layer := Node2D.new()
	var player = ShotPlayer.new()
	player.layer = layer
	player.play(timeline)
	var due: Array = []
	player.event_due.connect(func(e): due.append(e))
	player._process(0.1)
	eq(layer.get_children().filter(func(c): return c.visible).size(), 1, "the first one out")
	player._process(0.3)
	eq(layer.get_children().filter(func(c): return c.visible).size(), 2, "then the second")
	while player.is_playing():
		player._process(0.05)
	eq(due.filter(func(e): return e["type"] == "explode").size(), 2, "two explosions")
	player.free()
	layer.free()


static func _fx(r: float) -> Node2D:
	var fx := Node2D.new()
	fx.set_script(preload("res://match/views/explosion_fx.gd"))
	fx.radius = r
	return fx
