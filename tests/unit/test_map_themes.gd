extends "res://tests/test_case.gd"
## Map themes: the theme and name of a match (MatchStarted's mapTheme / mapName, else the map
## catalog from GET /maps, else grassland / the raw id), the catalog (parse, versions, cache,
## PlayerState.load_maps), every theme's look and materials (painted sizes within the shader's
## reach), the terrain view with soft / hard materials, the bottom band, the sky, the map toast
## and the matchmaking map line.

const MapThemes := preload("res://match/theme/map_themes.gd")
const MapCatalog := preload("res://match/theme/map_catalog.gd")
const Painter := preload("res://match/theme/material_painter.gd")
const Materials := preload("res://match/theme/theme_materials.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const TerrainView := preload("res://match/terrain/terrain_view.gd")
const BottomView := preload("res://match/views/bottom_view.gd")
const SkyView := preload("res://match/views/sky_view.gd")
const Hud := preload("res://match/hud.gd")
const Art := preload("res://ui/art.gd")
const MatchmakingModel := preload("res://screens/ranked/matchmaking_model.gd")
const PlayerStateScript := preload("res://autoload/player_state.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const MAPS := [
	{"mapId": "ice_bridge", "name": "Cầu băng", "theme": "ice", "width": 1600, "height": 900, "version": 2},
	{"mapId": "graveyard", "name": "Nghĩa trang", "theme": "graveyard", "width": 1600, "height": 900, "version": 1},
	{"mapId": "odd_map", "name": "Bản đồ lạ", "theme": "lava_moon", "version": 1},
]


func _catalog(list: Array = MAPS) -> void:
	MapCatalog.reset("")
	MapCatalog.take(MapCatalog.parse(list), false)


func test_theme_of_a_match() -> void:
	_catalog()
	eq(MapThemes.theme_of({"mapId": "ice_bridge", "mapTheme": "desert"}), "desert", "MatchStarted's mapTheme wins")
	eq(MapThemes.theme_of({"mapId": "ice_bridge"}), "ice", "no mapTheme: the catalog's")
	eq(MapThemes.theme_of({"mapId": "ice_bridge", "mapTheme": "moon"}), "ice", "an unknown mapTheme: the catalog's")
	eq(MapThemes.theme_of({"mapId": "odd_map"}), "grassland", "the catalog's theme unknown to the client: grassland")
	eq(MapThemes.theme_of({"mapId": "nowhere"}), "grassland", "unknown map: grassland")
	eq(MapThemes.theme_of({}), "grassland", "no map: grassland")
	MapCatalog.reset("")
	eq(MapThemes.theme_of({"mapId": "ice_bridge"}), "grassland", "no catalog: grassland (no client-side map table)")


func test_name_of_a_match() -> void:
	_catalog()
	eq(MapThemes.name_of({"mapId": "ice_bridge", "mapName": "Cầu Băng Mới"}), "Cầu Băng Mới", "mapName wins")
	eq(MapThemes.name_of({"mapId": "ice_bridge", "mapName": null}), "Cầu băng", "null mapName: the catalog's")
	eq(MapThemes.name_of({"mapId": "ice_bridge", "mapName": "  "}), "Cầu băng", "blank mapName: the catalog's")
	eq(MapThemes.name_of({"mapId": "lava_pit"}), "lava_pit", "unknown map: raw id")
	eq(MapThemes.name_of({}), "", "no map: no name")
	eq(MatchmakingModel.map_text({"mapId": "graveyard"}), "Bản đồ: Nghĩa trang", "matchmaking line")
	eq(MatchmakingModel.map_text({"mapId": "x", "mapName": "Đảo dừa"}), "Bản đồ: Đảo dừa", "matchmaking line from mapName")
	eq(MatchmakingModel.map_text({}), "", "no map: no line")
	eq(MatchmakingModel.map_text(null), "", "no payload")


func test_catalog_parse() -> void:
	var p = MapCatalog.parse(MAPS + [{"name": "no id"}, "junk", {"mapId": null}, {"mapId": "  "}])
	eq(p["maps"].keys().size(), 3, "bad entries skipped")
	eq(p["maps"]["ice_bridge"]["width"], 1600, "the server's fields kept")
	eq(p["version"], "graveyard:1,ice_bridge:2,odd_map:1", "no list version: made of the maps' own")
	var q = MapCatalog.parse({"version": "v7", "maps": MAPS})
	eq(q["version"], "v7", "the list's version")
	eq(q["maps"].size(), 3, "{version, maps} form")
	eq(MapCatalog.parse({"maps": null}), null, "not a list")
	eq(MapCatalog.parse(null), null, "nothing")
	var r = MapCatalog.parse([{"mapId": "a", "name": null, "theme": null}])
	eq(r["maps"]["a"]["name"], "", "null name")
	eq(r["maps"]["a"]["theme"], "", "null theme")


func test_catalog_take_and_versions() -> void:
	MapCatalog.reset("")
	check(MapCatalog.take(MapCatalog.parse(MAPS), false), "first list changes the catalog")
	check(not MapCatalog.take(MapCatalog.parse(MAPS), false), "same version: no change")
	var newer: Array = MAPS.duplicate(true)
	newer[0]["name"] = "Cầu băng 2"
	newer[0]["version"] = 3
	check(MapCatalog.take(MapCatalog.parse(newer), false), "a map's new version changes it")
	eq(MapCatalog.name_of("ice_bridge"), "Cầu băng 2", "renamed")
	eq(MapCatalog.theme_of("nowhere"), "", "unknown map: no theme")
	eq(MapCatalog.name_of(""), "", "no id")


func test_catalog_cache_round_trip() -> void:
	var path := OS.get_temp_dir().path_join("bsq_maps_test_%d.json" % Time.get_ticks_usec())
	MapCatalog.reset(path)
	MapCatalog.take(MapCatalog.parse({"version": "v9", "maps": MAPS}))
	check(FileAccess.file_exists(path), "saved with its version")
	MapCatalog.reset(path) # a new start: read back on the first lookup
	eq(MapCatalog.name_of("graveyard"), "Nghĩa trang", "name from the cache")
	eq(MapCatalog.version, "v9", "version from the cache")
	check(not MapCatalog.take(MapCatalog.parse({"version": "v9", "maps": MAPS})), "the cached version: no change")
	DirAccess.remove_absolute(path)
	MapCatalog.reset("")


class FakeApi:
	extends RefCounted
	var calls := 0
	var answer: Dictionary

	func get_json(path: String) -> Dictionary:
		calls += 1
		return answer if path == "/maps" else {"ok": true, "status": 200, "data": {}}


func test_player_state_load_maps() -> void:
	MapCatalog.reset("")
	var api := FakeApi.new()
	api.answer = {"ok": true, "status": 200, "code": "", "message": "", "data": MAPS}
	var s = PlayerStateScript.new()
	s.api = api
	var seen := [0]
	s.maps_changed.connect(func(): seen[0] += 1)
	s.load_maps()
	eq(api.calls, 1, "GET /maps")
	eq(seen[0], 1, "maps_changed")
	eq(MapCatalog.name_of("ice_bridge"), "Cầu băng", "names from the server")
	s.load_maps()
	eq(seen[0], 1, "same list: no signal")
	api.answer = {"ok": false, "status": 0, "code": "", "message": "", "data": null}
	s.load_maps()
	eq(MapCatalog.name_of("ice_bridge"), "Cầu băng", "a failure keeps the list")
	s.free()
	MapCatalog.reset("")


func test_every_theme_has_a_complete_look() -> void:
	eq(MapThemes.LOOKS.keys().size(), GameData.themes().size(), "one look per server theme")
	for t in GameData.themes():
		check(MapThemes.is_theme(t), "%s known" % t)
		var look: Dictionary = MapThemes.look(t)
		for key in ["clouds", "fx", "soft", "hard", "bottom"]:
			check(look.has(key), "%s has %s" % [t, key])
		check(Painter.SPECS.has(look["soft"]) and not Painter.spec(look["soft"])["hard"], "%s soft material is soft" % t)
		check(Painter.SPECS.has(look["hard"]) and Painter.spec(look["hard"])["hard"], "%s hard material is hard" % t)
		check(["none", "water", "lava", "abyss"].has(look["bottom"]["kind"]), "%s bottom kind" % t)
	eq(MapThemes.look("nope"), MapThemes.look("grassland"), "unknown theme: grassland")
	eq(MapThemes.look("grassland")["soft"], "grass_dirt", "grassland keeps today's ground")
	eq(MapThemes.look("grassland")["bottom"]["kind"], "none", "grassland: no bottom band")


## Every painted part fits the shader's reach (caps 8 px, bands 24, hangs 12) and the grid.
func test_materials_paint_within_the_shader_reach() -> void:
	var t0 := Time.get_ticks_usec()
	for id in Painter.ids():
		var sp := Painter.spec(id)
		check(int(sp["cap"]) <= 8, "%s cap <= 8" % id)
		check(int(sp["band"]) <= 24, "%s band <= 24" % id)
		check(int(sp["hang"]) <= 12, "%s hang <= 12" % id)
		if id == "grass_dirt":
			eq(Painter.paint(id, "fill"), null, "grassland's fill is dirt.png")
			continue
		var fill: Image = Painter.paint(id, "fill")
		check(fill != null and fill.get_width() == fill.get_height() and fill.get_width() % 32 == 0, "%s fill square, a multiple of 32" % id)
		var opaque := true
		for y in range(0, fill.get_height(), 7):
			for x in range(0, fill.get_width(), 5):
				opaque = opaque and fill.get_pixel(x, y).a > 0.99
		check(opaque, "%s fill opaque" % id)
		var edge: Image = Painter.paint(id, "edge")
		eq(edge.get_width(), Painter.EDGE_WIDTH, "%s edge width" % id)
		eq(edge.get_height(), int(sp["cap"]) + int(sp["band"]), "%s edge = cap + band rows" % id)
		var hang: Image = Painter.paint(id, "hang")
		eq(hang.get_height(), maxi(1, int(sp["hang"])), "%s hang rows" % id)
	print("    painted %d materials in %.0f ms" % [Painter.ids().size() - 1, (Time.get_ticks_usec() - t0) / 1000.0])


func test_material_textures() -> void:
	var g := Materials.material("grass_dirt")
	eq(g["fill"], Art.terrain("dirt"), "grassland: dirt.png")
	eq(g["edge"], Art.terrain("grass_edge"), "grassland: grass_edge.png")
	eq(g["cap"], Art.GRASS_TUFT_ROWS, "6 tuft rows")
	eq(g["hang_rows"], 0, "no hang")
	var ice := Materials.material("snow")
	eq(ice["hang_rows"], 10, "icicles")
	check(Materials.material("snow") == ice, "cached")
	eq(Materials.material("nope")["id"], "grass_dirt", "unknown: grassland")
	eq(Materials.override_path("snow", "fill"), "res://assets/terrain/themes/snow_fill.png", "artist override path")


static func _map_with_hard(w: int, h: int) -> TerrainMask:
	# Ground from y 600 down; a hard block (not destructible) x 400..560, y 500..600.
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid = PackedByteArray()
	m.solid.resize(w * h)
	m.destructible = PackedByteArray()
	m.destructible.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			if y >= 600:
				m.solid[i] = TerrainMask.SOLID
				m.destructible[i] = TerrainMask.SOLID
			elif y >= 500 and x >= 400 and x < 560:
				m.solid[i] = TerrainMask.SOLID
	m.rebuild_edge()
	return m


## Themed tiles upload the destructible mask once; a crater still uploads only its tiles.
func test_themed_view_uploads() -> void:
	var m := _map_with_hard(1600, 900)
	var v = TerrainView.new()
	v.show_theme("steel")
	v.show_mask(m)
	eq(v.uploads, 28, "every tile once (the dest texture is not re-uploaded)")
	var mat: ShaderMaterial = v.get_child(0).material
	check(mat.get_shader_parameter("dest_tex") != null, "dest texture set")
	eq(mat.get_shader_parameter("hard_fill"), Materials.material("steel_plate")["fill"], "steel's hard material")
	eq(mat.get_shader_parameter("soft_fill"), Materials.material("gravel")["fill"], "steel's soft material")
	m.carve(TerrainMask.CRATER_BOWL, 800, 600, 40)
	v.refresh()
	var up: int = v.uploads - 28
	check(up >= 1 and up <= 4, "a crater uploads %d tiles" % up)
	v.show_theme("grassland")
	eq(mat.get_shader_parameter("soft_fill"), Art.terrain("dirt"), "switching the theme re-sets the materials")
	eq(v.uploads - 28, up, "a theme switch uploads nothing")
	v.free()
	var plain = TerrainView.new() # never themed: grassland
	plain.show_mask(m)
	eq(plain.get_child(0).material.get_shader_parameter("soft_edge"), Art.terrain("grass_edge"), "default grassland")
	plain.free()


func test_bottom_band() -> void:
	var b = BottomView.new()
	b.setup("grassland", Vector2(1600, 900), 600)
	eq(b.kind, "none", "grassland: none")
	eq(b.band_rect(), Rect2(), "nothing drawn")
	b.setup("beach", Vector2(1600, 900), 600)
	eq(b.kind, "water", "beach: water")
	eq(b.band_rect(), Rect2(-600, 900 - BottomView.LIQUID_TOP, 2800, BottomView.LIQUID_TOP + BottomView.EXTRA), "over the map's bottom and past it")
	b.setup("temple", Vector2(2000, 1000), 600)
	eq(b.kind, "lava", "temple: lava")
	b.setup("cave", Vector2(1600, 900), 600)
	eq(b.kind, "abyss", "cave: abyss")
	eq(b.band_rect().position.y, 900 - BottomView.ABYSS_TOP, "the fog rises higher")
	eq(b.get_child_count(), 1, "one rect (the old ones freed)")
	b.free()


func test_sky_themes() -> void:
	var s = SkyView.new()
	s.show_theme("ice")
	eq(s.map_theme, "ice", "ice")
	eq(s._clouds.size(), int(MapThemes.look("ice")["clouds"][0]), "ice cloud count")
	eq(s._sky, null, "code-drawn backdrop")
	s.show_theme("cave")
	eq(s._clouds.size(), 0, "no clouds in a cave")
	s.show_theme("moon")
	eq(s.map_theme, "grassland", "unknown: grassland")
	eq(s._sky, Art.env("sky_match"), "grassland: sky_match.png")
	eq(s._clouds.size(), 8, "grassland's 8 clouds")
	s.free()


func test_map_toast() -> void:
	var hud = Hud.new()
	hud._ready()
	eq(hud.map_toast(), "", "none at first")
	hud.announce_map("Cầu băng")
	eq(hud.map_toast(), "Cầu băng", "the map's name")
	hud.free()


func test_match_screen_applies_the_theme() -> void:
	const MatchScreen := preload("res://match/match_screen.gd")
	var m: Node2D = MatchScreen.new()
	m._sky = SkyView.new()
	m._terrain_view = TerrainView.new()
	m._bottom = BottomView.new()
	m._players_layer = Node2D.new()
	m._hud = Hud.new()
	m._hud._ready()
	m._aim = preload("res://match/aim/aim_input.gd").new()
	m._shot_player = preload("res://match/shot/shot_player.gd").new()
	var mask := _map_with_hard(256, 256)
	var terrain := {"width": 256, "height": 256, "version": 1, "solid": _rle(mask.solid), "destructible": _rle(mask.destructible)}
	m._load_snapshot({"mapId": "x", "mapTheme": "cave", "terrain": terrain, "players": {}}, false)
	eq(m._theme, "cave", "MatchStarted's theme")
	eq(m._sky.map_theme, "cave", "on the sky")
	eq(m._terrain_view.map_theme, "cave", "on the terrain")
	eq(m._bottom.kind, "abyss", "on the bottom")
	m._load_snapshot({"mapId": "x", "terrain": terrain, "players": {}}, true)
	eq(m._theme, "cave", "a sync without mapTheme keeps it")
	m._load_snapshot({"mapId": "x", "mapTheme": "beach", "terrain": terrain, "players": {}}, true)
	eq(m._theme, "beach", "a sync with one switches")
	for n in [m._sky, m._terrain_view, m._bottom, m._players_layer, m._hud, m._aim, m._shot_player]:
		n.free()
	m.free()


static func _rle(bytes: PackedByteArray) -> String:
	var out := PackedByteArray()
	var cur := 0
	var run := 0
	for b in bytes:
		var v := 1 if b != 0 else 0
		if v != cur:
			_varint(out, run)
			cur = v
			run = 0
		run += 1
	_varint(out, run)
	return Marshalls.raw_to_base64(out)


static func _varint(out: PackedByteArray, v: int) -> void:
	while v >= 0x80:
		out.append((v & 0x7F) | 0x80)
		v >>= 7
	out.append(v)


## A theme an admin added with no art here draws as the game data's default theme; a default with
## no art falls back to grassland.
func test_unknown_theme_draws_the_default() -> void:
	eq(MapThemes.theme_of({"mapTheme": "volcano", "mapId": "nowhere"}), "grassland", "the default")
	var d: Dictionary = GameData.data.duplicate(true)
	d["version"] = "edited"
	d["mapThemes"]["default"] = "ice"
	d["mapThemes"]["themes"].append("volcano")
	GameData.take(d, "", false)
	eq(MapThemes.theme_of({"mapTheme": "volcano", "mapId": "nowhere"}), "ice", "the new default")
	eq(MapThemes.look("volcano"), MapThemes.look("ice"), "drawn like it")
	d["mapThemes"]["default"] = "lava_world"
	d["version"] = "edited2"
	GameData.take(d, "", false)
	eq(MapThemes.default_theme(), MapThemes.GRASSLAND, "a default with no art: grassland")
