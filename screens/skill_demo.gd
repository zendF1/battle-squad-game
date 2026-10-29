extends SubViewportContainer
## A small looping replay of a character's special skill (the first-login pick's right panel,
## screens/onboarding.gd): a recorded server scene (assets/skill_demos/skill_demos.json, by skill
## id: the players and the terrain before the shot and the ShotResolved the server sent; exported
## by the server's match tests on grassland_valley, the starting gun) replayed with the match's own
## pieces: the sky and terrain views, PlayerViews, ShotPlayer with the skill's SkillView, the
## explosions, craters, damage numbers, heals, shields and status bursts as match_screen draws
## them. Never simulated here: every path, hit and number is the server's. After the replay it
## holds a moment, then the scene is rebuilt and the shot plays again; show_skill() restarts it on
## another skill. A skill with no recorded scene shows nothing (has_demo() false).

const DEMOS_PATH := "res://assets/skill_demos/skill_demos.json"

const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const TerrainView := preload("res://match/terrain/terrain_view.gd")
const SkyView := preload("res://match/views/sky_view.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const ExplosionFx := preload("res://match/views/explosion_fx.gd")
const ShotLook := preload("res://match/views/shot_look.gd")
const DamagePopup := preload("res://match/views/damage_popup.gd")
const DamageTally := preload("res://match/views/damage_tally.gd")
const StatusGlyph := preload("res://match/views/status_glyph.gd")
const StatusBurst := preload("res://match/views/status_burst.gd")
const WaterSplash := preload("res://match/views/water_splash.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const MapThemes := preload("res://match/theme/map_themes.gd")
const Skills := preload("res://match/skills.gd")
const Status := preload("res://match/status_effects.gd")
const GameData := preload("res://autoload/game_data_model.gd")

## Seconds before the shot (the scene settles) and after it (the result shows) each loop.
const LEAD_SEC := 0.6
const HOLD_SEC := 1.4
## World px kept round the players and the hits when framing the scene.
const FRAME_PAD := Vector2(60, 50)
## Smallest world area framed (a close-up shot still shows some ground and sky).
const FRAME_MIN := Vector2(360, 300)
## World px above a player's feet the frame keeps (its body, name and HP bar).
const BODY_TOP := 190.0
## A status burst's size against the match's (beside the damage number, not over it).
const BURST_SCALE := 0.6

static var _demos = null # skill id -> scene, read once

var _vp: SubViewport
var _sky: SkyView
var _terrain: TerrainView
var _mask := TerrainMask.new()
var _players_layer: Node2D
var _fx: Node2D
var _shot: ShotPlayer
var _camera: Camera2D
var _skill_id := ""
var _case := {}
var _players := {}
var _views := {}
var _timeline: ShotTimeline
var _skill_view = null
var _tallies := {}
var _wait := -1.0 # seconds to the next step (the shot, or a restart); -1 none
var _next := "" # "play" or "restart"
var _loops := 0
var _framed_for := Vector2i.ZERO # the viewport size the camera was last fitted to


func _init() -> void:
	stretch = true
	mouse_filter = MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.name = "DemoViewport"
	_vp.handle_input_locally = false
	_vp.gui_disable_input = true
	_vp.msaa_2d = Viewport.MSAA_2X
	add_child(_vp)
	var far := CanvasLayer.new()
	far.layer = -1
	_vp.add_child(far)
	_sky = SkyView.new()
	far.add_child(_sky)
	_terrain = TerrainView.new()
	_vp.add_child(_terrain)
	_players_layer = Node2D.new()
	_vp.add_child(_players_layer)
	_fx = Node2D.new()
	_vp.add_child(_fx)
	_shot = ShotPlayer.new()
	_shot.layer = _fx
	_vp.add_child(_shot)
	_shot.event_due.connect(_on_event)
	_shot.finished.connect(_on_finished)
	_camera = Camera2D.new()
	_vp.add_child(_camera)


## The recorded scenes by skill id ({} when the file is missing or unreadable).
static func demos() -> Dictionary:
	if _demos == null:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DEMOS_PATH)) if FileAccess.file_exists(DEMOS_PATH) else null
		_demos = parsed if parsed is Dictionary else {}
	return _demos


## A recorded scene of skill `skill_id` exists.
static func has_demo(skill_id: String) -> bool:
	var c = demos().get(skill_id)
	return c is Dictionary and c.get("shot") is Dictionary and c.get("terrain") is Dictionary


## Plays skill `skill_id`'s scene from the start, looping ("" or none recorded: nothing).
func show_skill(skill_id: String) -> void:
	_skill_id = skill_id
	_case = demos().get(skill_id, {}) if has_demo(skill_id) else {}
	_loops = 0
	_restart()


## The skill shown.
func skill_id() -> String:
	return _skill_id


## How many times the shot has started since show_skill() (tests, smoke runs).
func loops() -> int:
	return _loops


## The PlayerViews of the scene by player id (tests).
func views() -> Dictionary:
	return _views


func _clear() -> void:
	_shot.stop()
	if _skill_view != null:
		_skill_view.end()
	_skill_view = null
	_tallies.clear()
	for n in _fx.get_children():
		n.queue_free()
	for v in _views.values():
		v.queue_free()
	_views.clear()
	_players.clear()


## Rebuilds the scene before the shot and plays it after LEAD_SEC.
func _restart() -> void:
	_clear()
	_wait = -1.0
	visible = not _case.is_empty()
	if _case.is_empty():
		return
	var theme := MapThemes.theme_of({"mapId": str(_case.get("mapId", ""))})
	_sky.show_theme(theme)
	_terrain.show_theme(theme)
	if _mask.load_snapshot(_case["terrain"]):
		_terrain.show_mask(_mask)
	var shooter := str(_case.get("shooter", ""))
	var raw: Dictionary = _case.get("players", {})
	var team := int(raw.get(shooter, {}).get("teamId", 1))
	for id in raw:
		var p: Dictionary = raw[id].duplicate(true)
		p["displayName"] = GameData.character_name(str(p.get("characterId", ""))) # the recorded ids mean nothing
		_players[id] = p
		var view := PlayerView.new()
		view.walk.terrain = _mask
		_players_layer.add_child(view)
		view.setup(p, false, team)
		_views[id] = view
	var cx: float = _views[shooter].position.x if _views.has(shooter) else _mask.width / 2.0
	for id in _views:
		if id != shooter:
			_views[id].face(-1.0 if _views[id].position.x > cx else 1.0) # towards the shooter
	if _views.has(shooter):
		var others := _views.values().filter(func(v): return v != _views[shooter])
		var mean: float = cx
		if not others.is_empty():
			mean = others.reduce(func(a, v): return a + v.position.x, 0.0) / others.size()
		_views[shooter].face(1.0 if mean >= cx else -1.0)
	_frame()
	_next = "play"
	_wait = LEAD_SEC


## The camera on the players and the shot's hits, fitted into the viewport.
func _frame() -> void:
	if _case.is_empty() or _vp == null:
		return
	_framed_for = _vp.size
	var view_size := Vector2(_vp.size)
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	var r := frame_rect(_case)
	var zoom := minf(view_size.x / r.size.x, view_size.y / r.size.y)
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position = r.get_center()
	_sky.fit(view_size, Vector2.ZERO)


## The world rect a scene is framed on: its players (feet to above the head), its hits and
## centres (explode, flare, rain, nova positions), padded, at least FRAME_MIN.
static func frame_rect(scene: Dictionary) -> Rect2:
	var pts: Array[Vector2] = []
	var players: Dictionary = scene.get("players", {})
	for id in players:
		var pos = players[id].get("position")
		if pos is Dictionary:
			var feet := Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
			pts.append(feet)
			pts.append(feet - Vector2(0, BODY_TOP))
	var shot: Dictionary = scene.get("shot", {})
	for e in shot.get("events", []):
		if e is Dictionary and e.get("position") is Dictionary and str(e.get("type", "")) != "nova":
			pts.append(Vector2(float(e["position"].get("x", 0)), float(e["position"].get("y", 0))))
	if pts.is_empty():
		return Rect2(Vector2.ZERO, FRAME_MIN)
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	r = r.grow_individual(FRAME_PAD.x, FRAME_PAD.y, FRAME_PAD.x, FRAME_PAD.y * 0.6)
	var c := r.get_center()
	r.size = r.size.max(FRAME_MIN)
	r.position = c - r.size / 2.0
	return r


func _process(delta: float) -> void:
	if _vp.size != _framed_for:
		_frame() # the container resized the viewport (stretch)
	if _wait < 0.0:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = -1.0
	if _next == "play":
		_play()
	else:
		_restart()


## Fires the recorded shot as match_screen does: the skill's view begun, the shooter's gun
## pointed and fired (its lead-in), the timeline replayed.
func _play() -> void:
	var shot: Dictionary = _case["shot"]
	var shooter := str(_case.get("shooter", ""))
	_timeline = ShotTimeline.new(shot)
	_shot.style = ShotLook.style_for(_players.get(shooter, {}), str(shot.get("actionMode", "skill")), "", null)
	_skill_view = Skills.view_for_skill(_timeline.skill_id)
	_skill_view.begin({"layer": _fx, "timeline": _timeline, "style": _shot.style, "views": _views, "players": _players,
		"shooter": shooter, "terrain": _mask, "screen": null, "wind": 0})
	_shot.skill_view = _skill_view
	var lead_in := _show_shooting(shooter)
	_loops += 1
	_shot.play(_timeline, lead_in)


## The shooter points its gun along its first projectile (or the skill's beam) and fires; the
## replay's lead-in (match_screen _show_shooting()).
func _show_shooting(shooter: String) -> float:
	if not _views.has(shooter):
		return 0.0
	var view = _views[shooter]
	if _timeline.projectiles.is_empty():
		var beam: float = _skill_view.aim_angle(_timeline) if _skill_view != null else NAN
		if is_nan(beam):
			view.clear_aim()
			return view.shoot(false)
		view.face_angle(beam)
		view.aim(beam)
		return view.shoot()
	var start: Vector2 = _timeline.sample(0, 0.0)
	var d: Vector2 = _timeline.sample(0, 0.05) - start
	if start.distance_to(view.position) > ShotPlayer.SPAWN_NEAR:
		view.shoot(false)
		return 0.0
	if d.length() > 0.01:
		var angle := rad_to_deg(atan2(-d.y, d.x))
		view.face_angle(angle)
		view.aim(angle)
	var lead_in: float = view.shoot()
	_shot.muzzle = _fx.to_local(view.fire_muzzle_position())
	return lead_in


func _on_event(e: Dictionary) -> void:
	var id := str(e.get("playerId", ""))
	match str(e.get("type", "")):
		"explode":
			var p := _vec(e.get("position"))
			var radius := float(e.get("radius", 0.0))
			_mask.carve(str(e.get("crater", TerrainMask.CRATER_BOWL)), p.x, p.y, radius)
			_terrain.refresh()
			var fx := ExplosionFx.new()
			fx.radius = maxf(radius, _timeline.blast_radius(str(e.get("projectileId", ""))))
			fx.kind = str(_shot.style.get("kind", ""))
			fx.tier = str(_shot.style.get("tier", ""))
			fx.skill = true
			fx.position = p
			if _skill_view != null:
				_skill_view.explosion(e, fx)
			_fx.add_child(fx)
		"damage":
			_set_hp(id, int(e.get("hp", 0)))
			if e.get("shield") is int or e.get("shield") is float:
				if _views.has(id):
					_views[id].set_shield(int(e["shield"]))
			var crit := bool(e.get("critical", false))
			if _skill_view != null and _skill_view.merges_damage():
				_tally(id, int(e.get("amount", 0)), crit, DamagePopup.effect_of(e))
			else:
				_popup(id, DamagePopup.damage_text(int(e.get("amount", 0))), Color.WHITE, Vector2.ZERO,
					DamagePopup.style(DamagePopup.effect_of(e), crit))
		"heal":
			_set_hp(id, int(e.get("hp", 0)))
			if int(e.get("amount", 0)) > 0:
				_popup(id, DamagePopup.heal_text(int(e.get("amount", 0))), DamagePopup.HEAL)
		"shield":
			if (e.get("shield") is int or e.get("shield") is float) and _views.has(id):
				_views[id].set_shield(int(e["shield"]))
			if int(e.get("amount", 0)) > 0:
				_popup(id, DamagePopup.heal_text(int(e.get("amount", 0))), Color(0.62, 0.9, 1.0), Vector2(0, -28))
		"status":
			if _players.has(id):
				_players[id]["statusEffects"] = Status.apply(_players[id].get("statusEffects"), str(e.get("effectId", "")), int(e.get("turns", 1)))
				_views[id].set_status(_players[id]["statusEffects"])
				var eff := str(e.get("effectId", ""))
				if StatusGlyph.has_picture(eff):
					var holder := Node2D.new() # the burst smaller than in a match: the scene is small
					holder.scale = Vector2.ONE * BURST_SCALE
					holder.position = _views[id].position + Vector2(-60, -150)
					holder.add_child(StatusBurst.make(eff, GameData.status_skips_turn(eff)))
					_fx.add_child(holder)
		"fall":
			if _views.has(id) and e.get("to") is Dictionary:
				_views[id].move_to(_vec(e["to"]), float(e.get("duration", 0.0)), Tween.TRANS_QUAD, Tween.EASE_IN)
		"bounce":
			if e.get("position") is Dictionary:
				var splash := WaterSplash.new()
				splash.radius = 42.0
				splash.position = _vec(e["position"])
				_fx.add_child(splash)
		"die":
			if _views.has(id):
				_views[id].set_dead()
	if _skill_view != null:
		_skill_view.on_event(e)


func _on_finished() -> void:
	_next = "restart"
	_wait = HOLD_SEC


func _set_hp(id: String, hp: int) -> void:
	if _players.has(id):
		_players[id]["hp"] = hp
		_views[id].set_hp(hp)


func _tally(id: String, amount: int, critical: bool, element_effect: String) -> void:
	if not _views.has(id):
		return
	var t = _tallies.get(id)
	if t == null or not is_instance_valid(t) or t.is_queued_for_deletion() or t.is_fading():
		t = DamageTally.new()
		t.follow = _views[id]
		_fx.add_child(t)
		_tallies[id] = t
	t.add(amount, critical, element_effect)


func _popup(id: String, text: String, color: Color, offset: Vector2 = Vector2.ZERO, st: Dictionary = {}) -> void:
	if not _views.has(id):
		return
	var label := DamagePopup.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	if not st.is_empty():
		label.set_style(st)
	label.position = _views[id].position + Vector2(0, -140) + offset
	_fx.add_child(label)


static func _vec(v: Variant) -> Vector2:
	return Vector2(float(v.get("x", 0)), float(v.get("y", 0))) if v is Dictionary else Vector2.ZERO
