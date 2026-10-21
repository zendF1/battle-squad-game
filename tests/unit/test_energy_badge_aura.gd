extends "res://tests/test_case.gd"
## Skill energy shown on the replay's time (match/shot/energy_reveal.gd), the use badge over a
## player (match/views/use_badge.gd) and the full-energy aura (match/views/energy_aura.gd), alone
## and through match_screen's own handlers with a real ShotPlayer driven frame by frame.

const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const EnergyReveal := preload("res://match/shot/energy_reveal.gd")
const UseBadge := preload("res://match/views/use_badge.gd")
const Art := preload("res://ui/art.gd")
const SkillGlyphs := preload("res://match/views/skill_glyphs.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const SkyView := preload("res://match/views/sky_view.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const Hud := preload("res://match/hud.gd")
const MatchScreen := preload("res://match/match_screen.gd")

const DT := 1.0 / 60.0
const HIT_E1 := 0.8 # s: the shell reaches e1
const HIT_E2 := 0.95


## A shot by `shooter` (one shell, 1.2 s) hitting e1 at HIT_E1 and e2 at HIT_E2; energies after it.
func _shot(shooter: String, mode: String, energies: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var d := {"shooterId": shooter, "actionMode": mode, "skillEnergy": int(energies.get(shooter, 0)),
		"skillEnergies": energies, "duration": 1.2,
		"projectiles": [{"projectileId": "p1", "path": [
			{"time": 0.0, "position": {"x": 100.0, "y": 480.0}, "velocity": {"x": 500.0, "y": -300.0}},
			{"time": 1.0, "position": {"x": 600.0, "y": 480.0}, "velocity": {"x": 500.0, "y": 300.0}}]}],
		"events": [
			{"t": HIT_E1, "type": "damage", "playerId": "e1", "amount": 120, "hp": 880},
			{"t": HIT_E2, "type": "damage", "playerId": "e2", "amount": 80, "hp": 920},
			{"t": 1.1, "type": "damage", "playerId": "e1", "amount": 30, "hp": 850}]}
	d.merge(extra, true)
	return d


func _player(id: String, team: int, character: String, x: float, energy: int) -> Dictionary:
	return {"playerId": id, "displayName": id, "teamId": team, "characterId": character, "hp": 1000, "maxHp": 1000,
		"isAlive": true, "position": {"x": x, "y": 500.0}, "skillEnergy": energy, "items": ["medkit", "drill_bomb"],
		"statusEffects": [], "moveEnergy": 100, "maxMoveEnergy": 100}


## match_screen without its scene but with real views, HUD, aim and ShotPlayer (not in the tree:
## driven by hand). Me (rookie, team 1) at 100 skill energy, my ally a1, enemies e1 and e2.
func _screen(me_energy: int = 40) -> Node2D:
	var m: Node2D = MatchScreen.new()
	m._me = "me"
	m._current = "me"
	m._players = {"me": _player("me", 1, "rookie", 100.0, me_energy), "a1": _player("a1", 1, "flora", 250.0, 30),
		"e1": _player("e1", 2, "tanko", 600.0, 50), "e2": _player("e2", 2, "spark", 700.0, 90)}
	m._players_layer = Node2D.new()
	m._fx_layer = Node2D.new()
	m._sky = SkyView.new()
	for id in m._players:
		var v: Node2D = PlayerView.new()
		m._players_layer.add_child(v)
		v.setup(m._players[id], id == "me", 1)
		v.get_child(1)._ready() # the character, not in the tree
		m._views[id] = v
	m._hud = Hud.new()
	m._hud._ready()
	m._aim = AimInput.new()
	m._shot_player = ShotPlayer.new()
	m._shot_player.layer = m._fx_layer
	m._shot_player.event_due.connect(m._on_shot_event)
	m._shot_player.fired.connect(m._on_shot_fired)
	m._shot_player.finished.connect(m._on_shot_finished)
	return m


func _free(m: Node2D) -> void:
	m._shot_player.stop()
	m._hud.free()
	m._aim.free()
	m._shot_player.free()
	m._players_layer.free()
	m._fx_layer.free()
	m._sky.free()
	m.free()


## Runs the replay until replay time t (the lead-in counted from 0 as negative time).
func _run_to(m: Node2D, t: float) -> void:
	var guard := 0
	while m._shot_player.is_playing() and m._shot_player._t < t - 1e-9 and guard < 2000:
		m._shot_player._process(DT)
		guard += 1


func _energy(m: Node2D, id: String) -> int:
	return int(m._players[id]["skillEnergy"])


# ── EnergyReveal ─────────────────────────────────────────────────────────────

func test_reveal_waits_for_each_hit() -> void:
	var players := {"me": {"skillEnergy": 40}, "a1": {"skillEnergy": 30}, "e1": {"skillEnergy": 50}, "e2": {"skillEnergy": 90}}
	var r := EnergyReveal.new()
	r.begin(ShotTimeline.new(_shot("me", "weapon", {"me": 40, "a1": 30, "e1": 60, "e2": 100})), players)
	eq(r.pending(), {"e1": 60, "e2": 100}, "only the changed energies wait")
	eq(r.fired(), {}, "a normal shot spends nothing at the fire moment")
	eq(r.on_event({"type": "explode", "playerId": "e1"}), {}, "not a damage event")
	eq(r.on_event({"type": "damage", "playerId": "e1", "amount": 0}), {}, "a 0 damage event shows nothing")
	eq(r.on_event({"type": "damage", "playerId": "e1", "amount": 120}), {"e1": 60}, "e1's first hit")
	eq(r.on_event({"type": "damage", "playerId": "e1", "amount": 30}), {}, "its next hit: already shown")
	eq(r.on_event({"type": "damage", "playerId": "a1", "amount": 30}), {}, "a friendly hit: no energy")
	eq(r.finish(), {"e2": 100}, "the rest at the end")
	eq(r.finish(), {}, "once")


func test_reveal_skill_shooter_spends_at_fire() -> void:
	var players := {"me": {"skillEnergy": 100}, "e1": {"skillEnergy": 50}}
	var r := EnergyReveal.new()
	r.begin(ShotTimeline.new(_shot("me", "skill", {"me": 0, "e1": 60}, {"skillId": "triple_shot"})), players)
	eq(r.on_event({"type": "damage", "playerId": "me", "amount": 40}), {}, "not before the fire moment")
	eq(r.fired(), {"me": 0}, "the skill's shooter at the fire moment")
	eq(r.fired(), {}, "once")
	eq(r.pending(), {"e1": 60}, "the victim still waits")
	# An older server: skillEnergy only (the shooter's).
	var old := _shot("me", "skill", {}, {"skillId": "triple_shot"})
	old.erase("skillEnergies")
	old["skillEnergy"] = 0
	r.begin(ShotTimeline.new(old), players)
	eq(r.fired(), {"me": 0}, "skillEnergy alone still resets the shooter")
	r.begin(ShotTimeline.new(_shot("me", "skill", {"me": 0})), players)
	r.clear()
	eq([r.fired(), r.finish()], [{}, {}], "clear() drops it all")


# ── Through match_screen ─────────────────────────────────────────────────────

func test_screen_shows_energy_at_each_damage_event() -> void:
	var m := _screen(40)
	m._apply("ShotResolved", _shot("me", "weapon", {"me": 40, "a1": 30, "e1": 60, "e2": 100}))
	eq([_energy(m, "e1"), _energy(m, "e2")], [50, 90], "nothing shown when the message arrives")
	check(not m._views["e2"].aura_on(), "no aura yet")
	_run_to(m, HIT_E1 - 0.05)
	eq([_energy(m, "e1"), _energy(m, "e2")], [50, 90], "the shell still in the air")
	_run_to(m, HIT_E1 + DT)
	eq(_energy(m, "e1"), 60, "e1's +10 with its hit")
	eq(m._views["e1"].hp, 880, "after its HP drop")
	eq(_energy(m, "e2"), 90, "e2 not hit yet")
	_run_to(m, HIT_E2 + DT)
	eq(_energy(m, "e2"), 100, "e2's +10 with its hit")
	check(m._views["e2"].aura_on(), "e2 full: its aura on")
	eq(m._views["e2"].skill_energy, 100, "the view follows")
	_run_to(m, 5.0)
	check(not m._shot_player.is_playing(), "replay over")
	eq([_energy(m, "me"), _energy(m, "a1"), _energy(m, "e1"), _energy(m, "e2")], [40, 30, 60, 100], "the server's values at the end")
	eq(m._views["me"].badge(), {}, "a normal shot: no badge")
	_free(m)


func test_screen_unhit_change_waits_for_the_end() -> void:
	var m := _screen(40)
	# a1's energy changed although nothing hit it on screen: shown at the replay's end.
	m._apply("ShotResolved", _shot("me", "weapon", {"me": 40, "a1": 70, "e1": 50, "e2": 90}))
	_run_to(m, 1.15)
	eq(_energy(m, "a1"), 30, "not during the replay")
	_run_to(m, 5.0)
	eq(_energy(m, "a1"), 70, "at its end")
	_free(m)


func test_screen_skill_resets_at_fire_and_drops_the_aura() -> void:
	var m := _screen(100)
	m._refresh_controls()
	check(m._views["me"].aura_on(), "ready: my aura on")
	near(m._hud.slots()["skill"]["ring"], 1.0, 1e-6, "full ring")
	m._apply("ShotResolved", _shot("me", "skill", {"me": 0, "a1": 30, "e1": 60, "e2": 100}, {"skillId": "test_unknown"}))
	eq(_energy(m, "me"), 100, "still 100 when the message arrives")
	check(m._views["me"].aura_on(), "the aura stays while the gun is drawn")
	eq(m._views["me"].badge(), {}, "no badge before the fire moment")
	# A held gun fires at once (no lead-in) off the tree; a bot's holstered gun is drawn first:
	# the replay waits that long (ShotPlayer.play(lead_in)).
	m._shot_player._t = minf(m._shot_player._t, -0.2)
	m._shot_player._process(0.1)
	eq(_energy(m, "me"), 100, "mid lead-in: unchanged")
	_run_to(m, DT)
	eq(_energy(m, "me"), 0, "spent at the fire moment")
	check(not m._views["me"].aura_on(), "the aura gone at the fire moment")
	near(m._hud.slots()["skill"]["ring"], 0.0, 1e-6, "the skill slot empties with it")
	eq(m._views["me"].badge(), {"kind": "skill", "id": "test_unknown", "name": "Kỹ năng"}, "the skill's badge from the fire moment")
	_run_to(m, 1.15)
	eq(m._views["me"].badge()["kind"], "skill", "held through the flight")
	_run_to(m, 5.0)
	eq(m._views["me"].badge(), {}, "released at the end (not in the tree: at once)")
	_free(m)


func test_screen_resync_sets_energy_directly() -> void:
	var m := _screen(40)
	m._apply("ShotResolved", _shot("me", "weapon", {"me": 40, "a1": 30, "e1": 60, "e2": 100}))
	_run_to(m, 0.3)
	var snap := {"currentPlayerId": "me", "turnIndex": 4, "players": m._players.duplicate(true), "wind": {"direction": 0, "power": 0.0}}
	snap["players"]["e1"]["skillEnergy"] = 70
	snap["players"]["e2"]["skillEnergy"] = 100
	m._load_snapshot(snap, true)
	check(not m._shot_player.is_playing(), "the replay dropped")
	eq([_energy(m, "e1"), _energy(m, "e2")], [70, 100], "the snapshot's values at once")
	check(m._views["e2"].aura_on() and not m._views["e1"].aura_on(), "auras from the snapshot")
	eq(m._energy_reveal.pending(), {}, "nothing left waiting")
	_free(m)


func test_screen_turn_started_after_the_replay() -> void:
	var m := _screen(70)
	m._apply("ShotResolved", _shot("me", "weapon", {"me": 70, "a1": 30, "e1": 60, "e2": 90}))
	# The end-of-turn +20 comes in TurnStarted while the shell flies: it waits with the rest.
	m._on_event("TurnStarted", {"currentPlayerId": "e1", "turnIndex": 5, "moveEnergy": 100,
		"skillEnergy": {"me": 90, "a1": 30, "e1": 60, "e2": 90}, "wind": {"direction": 1, "power": 1.0}})
	_run_to(m, 1.15)
	eq(_energy(m, "me"), 70, "no +20 during the replay")
	eq(m._current, "me", "the turn waits too")
	_run_to(m, 5.0)
	eq(_energy(m, "me"), 90, "+20 once the replay is over")
	eq(m._current, "e1", "the next turn")
	near(m._hud.slots()["skill"]["ring"], 0.9, 1e-6, "my slot shows it")
	m._apply("TurnStarted", {"currentPlayerId": "me", "turnIndex": 6, "moveEnergy": 100,
		"skillEnergy": {"me": 100, "a1": 30, "e1": 60, "e2": 90}})
	check(m._views["me"].aura_on(), "reaching 100 at a turn start lights the aura")
	check(m._hud.slots()["skill"]["disabled"] == false, "and the skill can be used")
	_free(m)


# ── Badges ───────────────────────────────────────────────────────────────────

func test_badge_content() -> void:
	eq(UseBadge.content("weapon", "", ""), {}, "a normal shot: nothing")
	eq(UseBadge.content("", "", ""), {}, "no mode: nothing")
	eq(UseBadge.content("skill", "triple_shot", ""), {"kind": "skill", "id": "triple_shot", "name": "Mưa tên lửa"}, "rain")
	eq(UseBadge.content("skill", "heavy_bomb", "")["name"], "Bom liên hoàn", "bomb chain")
	eq(UseBadge.content("skill", "shock_field", "")["name"], "Tia laze", "laser")
	eq(UseBadge.content("skill", "healing_bloom", "")["name"], "Hoa hồi xuân", "bloom")
	eq(UseBadge.content("skill", "nope", "")["name"], "Kỹ năng", "an unknown skill")
	eq(UseBadge.content("item", "", "drill_bomb"), {"kind": "item", "id": "drill_bomb", "name": "Bom khoan"}, "a shot item")
	eq(UseBadge.content("item", "", "teleport")["name"], "Dịch chuyển", "teleport (a shot)")
	eq(UseBadge.content("item", "", "medkit")["name"], "Hộp cứu thương", "an instant item")
	eq(UseBadge.content("item", "", ""), {}, "an item shot without an id")
	for id in SkillGlyphs.IDS:
		check(SkillGlyphs.has(id), "%s has a glyph" % id)
		check(SkillGlyphs.color(id) != SkillGlyphs.DEFAULT_COLOR, "%s its own colour" % id)


func test_screen_badges_per_action() -> void:
	var m := _screen(40)
	# An instant item: at once, for ITEM_BADGE_SEC.
	var players := {"e1": m._players["e1"].duplicate(true)}
	m._apply("ItemUsed", {"playerId": "e1", "itemId": "medkit", "players": players, "wind": {"direction": 0, "power": 0.0}})
	eq(m._views["e1"].badge(), {"kind": "item", "id": "medkit", "name": "Hộp cứu thương"}, "medkit badge on its user")
	eq(m._views["me"].badge(), {}, "no one else's")
	# A shot item: its ItemUsed shows nothing, its shot shows one badge from the fire moment.
	m._apply("ItemUsed", {"playerId": "me", "itemId": "drill_bomb", "players": {"me": m._players["me"].duplicate(true)}})
	eq(m._views["me"].badge(), {}, "the shot item's ItemUsed: no badge (its shot has it)")
	m._apply("ShotResolved", _shot("me", "item", {"me": 40, "a1": 30, "e1": 60, "e2": 90}, {"itemId": "drill_bomb"}))
	_run_to(m, 0.5)
	eq(m._views["me"].badge(), {"kind": "item", "id": "drill_bomb", "name": "Bom khoan"}, "one badge for the item shot")
	_run_to(m, 5.0)
	eq(m._views["me"].badge(), {}, "gone after the replay")
	# A bot's skill (another player): everyone sees it.
	m._current = "e2"
	m._players["e2"]["skillEnergy"] = 100
	m._views["e2"].set_skill_energy(100)
	m._apply("ShotResolved", _shot("e2", "skill", {"me": 50, "a1": 30, "e1": 60, "e2": 0}, {"skillId": "shock_field"}))
	_run_to(m, 0.1)
	eq(m._views["e2"].badge()["name"], "Tia laze", "an enemy's skill badge")
	check(not m._views["e2"].aura_on(), "its aura gone at the fire moment")
	_free(m)


func test_badge_sits_above_the_name_and_hp_bar() -> void:
	var m := _screen(40)
	m._views["me"].set_active(true) # the turn arrow
	m._views["a1"].set_status([{"effectId": "drill_bomb", "durationTurn": 1}]) # a shot marker
	for id in ["me", "a1", "e1"]:
		var v: Node2D = m._views[id]
		v.show_badge(UseBadge.content("skill", "triple_shot", ""))
		var b: Node2D = v.badge_node()
		var box: Rect2 = b.rect()
		box.position += b.position
		var hp_top: float = -v._art_top - 14.0
		check(box.end.y < hp_top, "%s: over the HP bar" % id)
		check(box.end.y < v._name.position.y - v._title_rise, "%s: over the name and title" % id)
		if id != "e1":
			check(box.end.y < v._name.position.y - 26.0 - v._title_rise, "%s: over the markers / the arrow" % id)
		eq(box.size, Vector2(UseBadge.HEIGHT, UseBadge.HEIGHT), "%s: a round icon-only badge (no name)" % id)
	var plain: Node2D = m._views["e1"].badge_node()
	check(plain.position.y > m._views["me"].badge_node().position.y, "no arrow or markers: lower, on the name")
	_free(m)


# ── Aura ─────────────────────────────────────────────────────────────────────

func test_aura_on_at_full_and_off_on_drop_or_death() -> void:
	var m := _screen(100)
	var v: Node2D = m._views["me"]
	check(v.aura_on(), "100 from the snapshot: on")
	check(not m._views["e1"].aura_on(), "50: off")
	v.set_skill_energy(90)
	check(not v.aura_on(), "drops below 100: off")
	v.set_skill_energy(100)
	check(v.aura_on(), "back to 100: on")
	var aura: Node2D = v._aura
	check(aura.is_processing(), "it animates while on")
	v.set_skill_energy(0)
	check(not aura.is_processing() and not aura.visible, "off: neither processes nor draws")
	v.set_skill_energy(100)
	v.set_dead()
	check(not v.aura_on(), "dead: off")
	v.set_skill_energy(100)
	check(not v.aura_on(), "stays off when dead")
	_free(m)



## The badge shows only an icon: an item's own, or the lightning "skill" icon for every skill.
func test_badge_icon_only() -> void:
	var b = UseBadge.new()
	b.show_use(UseBadge.content("skill", "heavy_bomb", ""))
	eq(b._tex, Art.icon("skill"), "a skill: the lightning icon")
	eq(b.rect().size, Vector2(UseBadge.HEIGHT, UseBadge.HEIGHT), "round, no name")
	b.show_use(UseBadge.content("item", "", "drill_bomb"))
	eq(b._tex, Art.item_icon("drill_bomb"), "an item: its own icon")
	eq(b.rect().size, Vector2(UseBadge.HEIGHT, UseBadge.HEIGHT), "round, no name")
	b.free()
