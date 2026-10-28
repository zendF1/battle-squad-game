extends "res://tests/test_case.gd"
## The drill bomb (battle-squad docs/contracts/shop-quantity.md §3): the tunnel carve
## (Terrain.CarveTunnel), its bit-by-bit opening (TunnelDig), the drilling shell (projectiles[].drill)
## and the "drill" event through match_screen.

const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const TerrainView := preload("res://match/terrain/terrain_view.gd")
const TunnelDig := preload("res://match/terrain/tunnel_dig.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const ProjectileView := preload("res://match/views/projectile_view.gd")
const DrillFx := preload("res://match/views/drill_fx.gd")
const MatchScreen := preload("res://match/match_screen.gd")
const Fixture := preload("res://tests/item_shot_fixture.gd")
const Items := preload("res://match/items.gd")


## w × h, solid and destructible from row `top` down.
static func _ground(w: int, h: int, top: int) -> TerrainMask:
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid.resize(w * h)
	m.solid.fill(0)
	for y in range(top, h):
		for x in w:
			m.solid[y * w + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	m.rebuild_edge()
	return m


static func _air(m: TerrainMask) -> int:
	var n := 0
	for b in m.solid:
		if b == 0:
			n += 1
	return n


## The contract's carve, written out pixel by pixel.
static func _reference(m: TerrainMask, path: PackedVector2Array, r: float) -> PackedByteArray:
	var out := m.solid.duplicate()
	var reach := ceili(r)
	for p in path:
		for y in range(roundi(p.y) - reach, roundi(p.y) + reach + 1):
			for x in range(roundi(p.x) - reach, roundi(p.x) + reach + 1):
				if x < 0 or y < 0 or x >= m.width or y >= m.height:
					continue
				var dx := x - roundi(p.x)
				var dy := y - roundi(p.y)
				if float(dx * dx + dy * dy) <= r * r and m.destructible[y * m.width + x] != 0:
					out[y * m.width + x] = 0
	return out


func _event(path: Array, t := 1.0, duration := 0.4, radius := 6.0) -> Dictionary:
	return {"t": t, "type": "drill", "projectileId": "d1", "position": path[0], "to": path[-1], "path": path, "radius": radius,
		"crater": "tunnel", "duration": duration, "terrainVersion": 1}


func test_tunnel_carve() -> void:
	var m := _ground(80, 60, 20)
	var path := PackedVector2Array([Vector2(10, 18), Vector2(13, 21), Vector2(16, 24), Vector2(19, 27), Vector2(78, 58)])
	var want := _reference(m, path, 6.0)
	m.carve_tunnel(path, 6.0)
	eq(m.version, 1, "one version step for the whole tunnel")
	eq(m.solid, want, "every pixel within r of a path point, inside the map")
	check(not m.is_carved(10, 10), "the map's own air stays uncarved")
	check(m.is_carved(16, 24), "the tunnel is carved")
	var undestructible := _ground(20, 20, 5)
	undestructible.destructible.fill(0)
	undestructible.carve_tunnel(PackedVector2Array([Vector2(10, 10)]), 4.0)
	eq(_air(undestructible), 100, "indestructible ground stays")


func test_parts_carve_like_the_whole() -> void:
	var path := PackedVector2Array()
	for i in 12:
		path.append(Vector2(20 + i * 3, 22 + i * 2))
	var whole := _ground(80, 60, 20)
	whole.carve_tunnel(path, 5.0)
	var parts := _ground(80, 60, 20)
	parts.carve_tunnel_points(path, 5.0, 0, 5)
	parts.carve_tunnel_points(path, 5.0, 5, 12)
	eq(parts.solid, whole.solid, "a tunnel opened in parts is the same tunnel")
	eq(parts.version, 0, "the parts take no version step")


func test_dig_opens_behind_the_bit() -> void:
	var path: Array = []
	for i in 10:
		path.append({"x": 20 + i * 3, "y": 22 + i * 3})
	var dig = TunnelDig.from_event(_event(path, 1.0, 0.4))
	eq([dig.t, dig.duration, dig.radius, dig.path.size()], [1.0, 0.4, 6.0, 10], "read from the event")
	eq([dig.entry(), dig.end()], [Vector2(20, 22), Vector2(47, 49)], "entry and end")
	eq([dig.due(-1.0), dig.due(0.0), dig.due(0.2), dig.due(0.4), dig.due(9.0)], [1, 1, 5, 10, 10], "the points reached")
	var m := _ground(80, 60, 20)
	dig.start(m)
	eq(m.version, 1, "the version step at the start")
	eq(dig.carved, 1, "the entry at once")
	check(dig.advance(m, 0.2), "half way")
	eq(dig.carved, 5, "five points open")
	check(not m.is_carved(44, 46), "not past the bit yet")
	check(not dig.advance(m, 0.2), "nothing new at the same time")
	check(dig.finish(m), "the rest")
	check(dig.done() and m.is_carved(44, 46), "all open")
	eq(m.version, 1, "still one version step")
	var whole := _ground(80, 60, 20)
	whole.carve_tunnel(dig.path, 6.0)
	eq(m.solid, whole.solid, "the same tunnel as the whole carve")
	var bare = TunnelDig.from_event({"t": 0.5, "type": "drill", "position": {"x": 3, "y": 4}, "to": {"x": 9, "y": 12}, "radius": 12})
	eq(bare.path, PackedVector2Array([Vector2(3, 4), Vector2(9, 12)]), "no path: entry to end")
	eq(bare.due(0.0), 2, "no duration: all at once")
	eq(TunnelDig.from_event({"type": "drill"}), null, "nothing to dig")


func test_drilling_shell() -> void:
	var payload := Fixture.drill()
	var timeline = ShotTimeline.new(payload)
	check(timeline.is_drill(0), "projectiles[].drill")
	check(not ShotTimeline.new(Fixture.poison()).is_drill(0), "others do not drill")
	eq(timeline.events_of("drill").size(), 1, "one drill event")
	var layer := Node2D.new()
	var player = ShotPlayer.new()
	player.layer = layer
	player.play(timeline)
	var view = layer.get_child(0)
	check(view is ProjectileView and view.drill, "drawn as a drill bit")
	eq(view.spin_rate(), 0.0, "the bit points along its flight (its flutes turn)")
	player.stop()
	player.free()
	layer.free()
	var drill: Dictionary = timeline.events_of("drill")[0]
	var explode: Dictionary = timeline.events_of("explode")[0]
	check(float(drill["t"]) <= float(explode["t"]), "the drill before the explode")
	check(float(drill["duration"]) > 0.0 and drill["path"].size() > 3, "the fixture bores")
	eq(Items.pierce("drill_bomb"), 120.0, "the game data's pierce")


func test_drill_fx_runs_and_frees() -> void:
	var path: Array = []
	for i in 8:
		path.append({"x": 100 + i * 4, "y": 100 + i * 4})
	var fx = DrillFx.new(TunnelDig.from_event(_event(path, 0.0, 0.3)))
	var root := Node2D.new()
	root.add_child(fx)
	fx._ready()
	check(fx._clods.size() > 0 and fx._puffs.size() > 0, "a burst at the entry")
	check(fx.bore_dir(true).is_equal_approx(Vector2(1, 1).normalized()), "bores along the path")
	for i in 10:
		fx._process(0.03)
	check(fx._grit.size() > 0, "grit off the bit while it bores")
	for i in 120:
		if fx.is_queued_for_deletion():
			break
		fx._process(0.03)
	check(fx.is_queued_for_deletion(), "gone once the dust settles")
	root.free()


func test_screen_drill_event() -> void:
	var m: Node2D = MatchScreen.new()
	m._mask = _ground(400, 200, 100)
	m._terrain_view = TerrainView.new()
	m._fx_layer = Node2D.new()
	m._shot_player = ShotPlayer.new()
	m._shot_player.layer = m._fx_layer
	var path: Array = []
	for i in 20:
		path.append({"x": 100 + i * 3, "y": 98 + i * 3})
	m._on_shot_event(_event(path, 0.0, 0.5, 8.0))
	eq(m._mask.version, 1, "the tunnel's version step")
	eq(m._digs.size(), 1, "the tunnel opens as the bit bores")
	eq(m._fx_layer.get_children().filter(func(c): return c is DrillFx).size(), 1, "dirt and dust")
	check(not m._mask.is_carved(150, 148), "its far end still closed")
	m._on_shot_event({"t": 0.5, "type": "explode", "projectileId": "d1", "position": path[-1], "radius": 10, "crater": "bowl",
		"terrainVersion": 2})
	eq(m._digs.size(), 0, "the explode opens the rest first")
	check(m._mask.is_carved(150, 148), "the whole tunnel open")
	eq(m._mask.version, 2, "the explode after it")
	check(not m._resync_after_shot, "versions match: no resync")
	m._shot_player.free()
	for n in m._fx_layer.get_children():
		n.free()
	m._fx_layer.free()
	m._terrain_view.free()
	m.free()
