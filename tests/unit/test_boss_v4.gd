extends "res://tests/test_case.gd"
## Boss mode v4 on the client (Khổng Lồ Đá, Mộc Tinh; the server's earth / wood contract): the
## eruption marks' lifecycle (BossMarks: a mark event, a MatchStateSync / TurnStarted restoring them,
## the eruption and the boss's death taking them; MarkView), the boss's turn start that leaves its
## turn open, the heals on the boss (a drain's life flow, a regen's), the poison status (its look, its
## tick), the minion auras (BossHudModel armorMinions / regenMinions, the links snapping, the plates,
## the armoured damage number), the mushroom's spore turn and spore death blast, the new projectile
## kinds, the art and the game data of the two bosses.

const BossFixture := preload("res://tests/boss_fixture.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const BossMarks := preload("res://match/boss/boss_marks.gd")
const MarkView := preload("res://match/boss/mark_view.gd")
const AuraLinks := preload("res://match/boss/aura_links.gd")
const SporeFx := preload("res://match/boss/spore_fx.gd")
const LifeStreamFx := preload("res://match/boss/life_stream_fx.gd")
const VineStrikeFx := preload("res://match/boss/vine_strike_fx.gd")
const BossHudModel := preload("res://match/boss/boss_hud_model.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const BossBody := preload("res://match/boss/boss_body.gd")
const StatusLook := preload("res://match/views/status_look.gd")
const DamagePopup := preload("res://match/views/damage_popup.gd")
const UnitShell := preload("res://match/views/unit_shell.gd")
const BossRain := preload("res://match/views/skills/boss_rain.gd")
const BossBeam := preload("res://match/views/skills/boss_beam.gd")
const ExplosionFx := preload("res://match/views/explosion_fx.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const SkyView := preload("res://match/views/sky_view.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const Hud := preload("res://match/hud.gd")
const MatchScreen := preload("res://match/match_screen.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const TerrainView := preload("res://match/terrain/terrain_view.gd")
const DT := 1.0 / 60.0


func _mark(id: String, pid: String, x: float, t: float = 0.6) -> Dictionary:
	return {"t": t, "type": "mark", "playerId": pid, "position": {"x": x, "y": 700.0}, "radius": 70, "markId": id, "skillId": "stone_spikes"}


# ── The game data ────────────────────────────────────────────────────────────

func test_game_data_of_the_new_bosses() -> void:
	BossFixture.take()
	var giant := GameData.boss("rock_giant")
	eq([giant["name"], giant["element"], giant["mapId"]], ["Khổng Lồ Đá", "earth", "arena_rock_giant_canyon"], "the giant")
	eq(GameData.boss("tree_spirit")["element"], "wood", "the tree is wood")
	eq(GameData.boss_skill("rock_giant", "stone_spikes")["kind"], "eruption", "Gai đá trồi erupts")
	eq(GameData.boss_skill("rock_giant", "stone_spikes")["radius"], 70, "its marks' reach")
	eq(GameData.boss_skill("tree_spirit", "vine_lash")["kind"], "ground_strike", "Roi dây leo strikes the ground")
	eq(GameData.boss_skill("tree_spirit", "life_drain")["drainPct"], 100, "the drain heals all it took")
	eq(GameData.boss_minion("rock_giant", "stone_totem")["bossDamageTakenFactor"], 0.4, "the totem's armour")
	eq(GameData.boss_minion("tree_spirit", "poison_mushroom")["behavior"], "spore", "the mushroom puffs")
	eq(GameData.status_name("poison"), "Trúng độc", "the poison status's name")
	eq(GameData.data["combat"]["poisonMaxHpPercent"], 4, "combat poisonMaxHpPercent")


# ── The art ──────────────────────────────────────────────────────────────────

func test_art_of_the_new_bosses_and_minions() -> void:
	eq([BossArt.art_of("rock_giant"), BossArt.art_of("tree_spirit")], ["rock_giant", "tree_spirit"], "drawn bosses, not the blob")
	eq([BossArt.art_of("", "stone_totem"), BossArt.art_of("", "poison_mushroom")], ["stone_totem", "poison_mushroom"], "their minions")
	check(BossArt.top("tree_spirit") > 1.0 and BossArt.top("steel_robot") == 1.0, "the crown stands over the unit height")
	var h := BossArt.heart("tree_spirit", 200.0, -1)
	check(h.x < 0.0 and h.y < 0.0, "the sap heart, mirrored facing left (%s)" % h)
	check(BossArt.blast_look("poison_mushroom").get("spore", false), "the mushroom blows up into spores")
	eq(BossArt.STORM.get("tree_spirit", ""), "spores", "its map-wide thorn rain blows spores over the screen")
	var sq := BossArt.mushroom_squash(0.0, 0.1)
	check(sq.y < 0.9, "puffing: squashed (%s)" % sq)
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8) # drawing every figure runs (no errors)
	img.fill(Color.BLACK)
	var ci := Node2D.new()
	for art in ["rock_giant", "stone_totem", "tree_spirit", "poison_mushroom"]:
		BossArt.draw(ci, art, Vector2.ZERO, 120.0, 1.3, 1, 0.0, {"plates": 1.0, "puff": 0.2, "heal": 1.0, "nod": 1.0})
		BossArt.draw(ci, art, Vector2.ZERO, 120.0, 1.3, -1, 0.5, {"plates_break": 0.3})
	ci.free()


func test_body_plates_heal_and_puff() -> void:
	var b := BossBody.new()
	b.setup("rock_giant", 200.0)
	b.set_armored(true)
	b._process(BossBody.PLATES_IN_SEC)
	near(b.plates_shown(), 1.0, 1e-6, "the plates popped on")
	b.set_armored(false)
	check(b.plates_breaking() and b.plates_shown() == 0.0, "they break off")
	b._process(BossArt.PLATE_BREAK_SEC + 0.05)
	check(not b.plates_breaking(), "then gone")
	b.set_armored(true, false)
	near(b.plates_shown(), 1.0, 1e-6, "a snapshot: on at once")
	b.heal_glow()
	check(b.heal_shown() > 0.9, "a heal's glow")
	b.free()
	var m := BossBody.new()
	m.setup("poison_mushroom", 50.0)
	m.puff()
	check(m.puffing(), "the mushroom puffs")
	m._process(BossBody.PUFF_SEC + 0.01)
	check(not m.puffing(), "and settles")
	m.free()


# ── The marks ────────────────────────────────────────────────────────────────

func test_marks_model_lifecycle() -> void:
	var marks := BossMarks.new()
	var m := marks.add_event(_mark("mark_1", "p0", 232.0), 3)
	eq([m["markId"], m["playerId"], m["position"], m["radius"], m["round"]], ["mark_1", "p0", Vector2(232, 700), 70.0, 3], "a mark event")
	check(marks.add_event(_mark("mark_1", "p0", 232.0)).is_empty(), "the same mark twice: once")
	check(marks.add_event({"type": "mark"}).is_empty(), "no id: none")
	eq(marks.mark_at(Vector2(260, 700))["markId"], "mark_1", "standing in it")
	check(marks.mark_at(Vector2(400, 700)).is_empty(), "walked out of it")
	var ch := marks.set_all([{"markId": "mark_1", "playerId": "p0", "position": {"x": 232, "y": 700}, "radius": 70, "round": 3},
		{"markId": "mark_2", "playerId": "p1", "position": {"x": 344, "y": 700}, "radius": 70, "round": 3}])
	eq(ch, {"added": ["mark_2"], "removed": []}, "a sync restores the missing one")
	eq(marks.set_all(null), {"added": [], "removed": []}, "a payload without marks keeps them")
	eq(marks.erupt("mark_1")["playerId"], "p0", "the eruption takes its mark")
	eq(marks.ids(), ["mark_2"], "the other waits")
	eq(marks.clear(), ["mark_2"], "the boss died: all gone")
	eq(marks.size(), 0, "none left")


func test_mark_view_opens_charges_erupts_and_fades() -> void:
	var v := MarkView.new()
	v.show_mark({"markId": "a", "position": Vector2(100, 700), "radius": 70.0})
	v.show_mark({"markId": "b", "position": Vector2(300, 700), "radius": 70.0}, false)
	eq(v.ids(), ["a", "b"], "both drawn")
	v.charge("a", 0.6)
	check(v.charging("a") and not v.charging("b"), "the one erupting next rumbles")
	v.erupt("a")
	eq(v.ids(), ["b"], "erupting: no longer a mark")
	v._process(MarkView.FLASH + 0.01)
	eq(v.drawn(), 1, "its flash is over")
	v.sync({})
	eq(v.ids(), [], "a sync without it: it fades")
	v._process(MarkView.FADE + 0.01)
	eq(v.drawn(), 0, "gone")
	near(MarkView.charge_k(0.3, 0.6), 0.5, 1e-6, "half way through its charge")
	v.free()


# ── match_screen ─────────────────────────────────────────────────────────────

func _ground(w: int, h: int, top: int) -> TerrainMask:
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid.resize(w * h)
	m.solid.fill(0)
	for x in w:
		for y in range(top, h):
			m.solid[y * w + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	return m


func _p(id: String, team: int, x: float, extra: Dictionary = {}) -> Dictionary:
	var p := {"playerId": id, "displayName": id, "teamId": team, "characterId": "rookie", "hp": 1000, "maxHp": 1000,
		"isAlive": true, "position": {"x": x, "y": 700.0}, "skillEnergy": 0, "items": [], "statusEffects": [], "moveEnergy": 100,
		"maxMoveEnergy": 100}
	p.merge(extra, true)
	return p


func _boss_block(boss: String, extra: Dictionary = {}) -> Dictionary:
	var b := {"bossId": boss, "playerId": "boss_" + boss, "round": 3, "turnLimit": 20, "marks": [], "damageTakenFactor": 1,
		"armorMinions": [], "regenPct": 0, "regenMinions": []}
	b.merge(extra, true)
	return b


## A boss match screen: me and p2 against the boss (rock_giant: two stone totems armouring it;
## tree_spirit: two poison mushrooms healing it).
func _screen(boss: String = "rock_giant") -> Node2D:
	BossFixture.take()
	var m: Node2D = MatchScreen.new()
	var bid := "boss_" + boss
	m._me = "me"
	m._current = bid
	m._turn_index = 5
	var kind := "stone_totem" if boss == "rock_giant" else "poison_mushroom"
	var minion := GameData.boss_minion(boss, kind)
	m._players = {"me": _p("me", 1, 300.0), "p2": _p("p2", 1, 500.0),
		bid: _p(bid, 2, 2000.0, {"role": "boss", "bossId": boss, "bodySize": 3.4, "hp": 19000, "maxHp": 20000, "characterId": ""})}
	var ids: Array = []
	for i in 2:
		var id := "minion_%s_%d" % [kind, i + 1]
		ids.append(id)
		m._players[id] = _p(id, 2, 1200.0 + i * 200.0, {"role": "minion", "bossId": boss, "minionId": kind, "bodySize": minion["bodySize"],
			"behavior": minion["behavior"], "characterId": ""})
	var blk := _boss_block(boss, {"armorMinions": ids, "damageTakenFactor": 0.4} if boss == "rock_giant" else {"regenMinions": ids, "regenPct": 6})
	m._mask = _ground(2400, 1120, 700)
	m._terrain_view = TerrainView.new()
	m._players_layer = Node2D.new()
	m._fx_layer = Node2D.new()
	m._screen_fx = CanvasLayer.new()
	m._sky = SkyView.new()
	m._lava_view = preload("res://match/boss/lava_view.gd").new()
	for id in m._players:
		var v: Node2D = PlayerView.new()
		v.walk.terrain = m._mask
		m._players_layer.add_child(v)
		v.setup(m._players[id], id == "me", 1)
		if not v.is_boss_side():
			v.get_child(1)._ready()
		m._views[id] = v
	m._hud = Hud.new()
	m._hud._ready()
	m._hud.boss_hud()._ready()
	m._aim = AimInput.new()
	m._shot_player = ShotPlayer.new()
	m._shot_player.layer = m._fx_layer
	m._shot_player.event_due.connect(m._on_shot_event)
	m._shot_player.fired.connect(m._on_shot_fired)
	m._shot_player.finished.connect(m._on_shot_finished)
	m.send_hook = func(_event: String, _data: Dictionary) -> void: pass
	m._load_boss({"boss": blk, "players": m._players})
	return m


func _free(m: Node2D) -> void:
	m._shot_player.stop()
	for n in [m._hud, m._aim, m._shot_player, m._players_layer, m._fx_layer, m._sky, m._terrain_view, m._screen_fx, m._lava_view]:
		n.free()
	m.free()


func _run(m: Node2D, sec: float) -> void:
	var t := 0.0
	while t < sec - 1e-9:
		m._shot_player._process(DT)
		for v in m._views.values():
			v._process(DT)
		m.mark_view()._process(DT)
		m.aura_links()._process(DT)
		m._process(DT)
		t += DT


func _fx_of(m: Node2D, script: Script) -> Array:
	return m._fx_layer.get_children().filter(func(n): return n.get_script() == script)


func test_marks_from_the_cast_through_sync_to_the_eruption() -> void:
	var m := _screen()
	m._on_event("ShotResolved", {"shooterId": "boss_rock_giant", "actionMode": "skill", "skillId": "stone_spikes", "projectiles": [],
		"events": [_mark("mark_1", "me", 300.0), _mark("mark_2", "p2", 500.0, 0.68)], "duration": 0.68})
	check(m._turn_resolved, "the cast is the boss's attack: it resolves the turn")
	_run(m, 0.75)
	eq(m.marks().ids(), ["mark_1", "mark_2"], "a mark under each member")
	eq(m.mark_view().ids(), ["mark_1", "mark_2"], "drawn on the ground")
	var marks := [{"markId": "mark_1", "ownerId": "boss_rock_giant", "skillId": "stone_spikes", "playerId": "me",
		"position": {"x": 300, "y": 700}, "radius": 70, "round": 3}]
	m._load_boss({"players": m._players, "boss": _boss_block("rock_giant", {"marks": marks})}) # a MatchStateSync's boss block
	eq(m.marks().ids(), ["mark_1"], "MatchStateSync's marks are the truth")
	eq(m.mark_view().ids(), ["mark_1"], "and drawn")
	m._apply("TurnStarted", {"currentPlayerId": "boss_rock_giant", "turnIndex": 7, "round": 4, "moveEnergy": 0,
		"marks": marks + [{"markId": "mark_3", "playerId": "p2", "position": {"x": 520, "y": 700}, "radius": 70, "round": 3}]})
	eq(m.marks().ids(), ["mark_1", "mark_3"], "TurnStarted marks restore one missing")
	m._on_event("ShotResolved", {"shooterId": "boss_rock_giant", "actionMode": "turn_start", "skillId": "stone_spikes", "projectiles": [],
		"events": [{"t": 0.6, "type": "eruption", "playerId": "me", "position": {"x": 300, "y": 700}, "radius": 70, "markId": "mark_1",
			"skillId": "stone_spikes"},
			{"t": 0.6, "type": "damage", "playerId": "me", "amount": 300, "hp": 700, "cause": "eruption"},
			{"t": 0.68, "type": "eruption", "playerId": "p2", "position": {"x": 520, "y": 700}, "radius": 70, "markId": "mark_3",
			"skillId": "stone_spikes"}], "duration": 0.68})
	check(not m._turn_resolved, "the turn start does not end the boss's turn")
	eq(m._hud.boss_hud().skill_text(), "", "no 'Triệu hồi' for it")
	check(m.mark_view().charging("mark_1"), "the marks rumble until they erupt")
	m._on_event("ActionSelected", {"playerId": "boss_rock_giant", "actionMode": "skill", "skillId": "giant_boulder"})
	eq(m._deferred.size(), 1, "the attack waits for the turn start's replay")
	_run(m, 0.64)
	check(not m.marks().has("mark_1") and m.marks().has("mark_3"), "the first erupted")
	check(m._views["me"].hops() == 1 and m._views["p2"].hops() == 0, "the member hit hops a little (only it)")
	_run(m, 0.2)
	eq(m.marks().size(), 0, "every mark erupted")
	_run(m, 0.5)
	eq(m._deferred.size(), 0, "then the attack plays")
	eq(m._hud.boss_hud().skill_text(), str(GameData.boss_skill("rock_giant", "giant_boulder")["name"]), "its name from the game data")
	_free(m)


func test_boss_death_clears_the_marks() -> void:
	var m := _screen()
	m._load_boss({"players": m._players, "boss": _boss_block("rock_giant", {
		"marks": [{"markId": "mark_1", "playerId": "me", "position": {"x": 300, "y": 700}, "radius": 70, "round": 3}],
		"armorMinions": ["minion_stone_totem_1"]})})
	eq(m.marks().ids(), ["mark_1"], "a mark waits")
	m._kill("boss_rock_giant")
	eq(m.marks().size(), 0, "the boss died: the marks vanish")
	eq(m.mark_view().ids(), [], "they fade off the ground")
	_free(m)


func test_ground_strike_bursts_vines() -> void:
	var m := _screen("tree_spirit")
	m._on_event("ShotResolved", {"shooterId": "boss_tree_spirit", "actionMode": "skill", "skillId": "vine_lash", "projectiles": [],
		"events": [{"t": 0.6, "type": "ground_strike", "playerId": "me", "position": {"x": 300, "y": 700}, "radius": 60, "skillId": "vine_lash"},
			{"t": 0.6, "type": "damage", "playerId": "me", "amount": 415, "hp": 585, "cause": "ground_strike"},
			{"t": 0.6, "type": "status", "playerId": "me", "effectId": "root", "turns": 1}], "duration": 0.6})
	_run(m, 0.62)
	var vines: Array = _fx_of(m, VineStrikeFx)
	eq(vines.size(), 1, "thorny vines under the member")
	eq(vines[0].position, Vector2(300, 700), "at its feet")
	check(m._views["me"].status_looks().has("stone"), "the root's look after it")
	near(VineStrikeFx.grow_at(VineStrikeFx.RISE + 0.1), 1.0, 1e-6, "standing")
	eq(VineStrikeFx.grow_at(VineStrikeFx.LIFE), 0.0, "sunk back")
	_free(m)


# ── Heals ────────────────────────────────────────────────────────────────────

func test_drain_flows_life_into_the_boss() -> void:
	var m := _screen("tree_spirit")
	m._players["boss_tree_spirit"]["hp"] = 15000
	m._set_hp("boss_tree_spirit", 15000)
	m._hud.boss_hud()._rise_from = -1.0
	m._on_event("ShotResolved", {"shooterId": "boss_tree_spirit", "actionMode": "skill", "skillId": "life_drain", "projectiles": [],
		"events": [{"t": 0.6, "type": "beam", "playerId": "boss_tree_spirit", "from": {"x": 2000, "y": 650}, "to": {"x": 0, "y": 680}, "duration": 0.8},
			{"t": 0.76, "type": "damage", "playerId": "me", "amount": 665, "hp": 335, "cause": "laser"},
			{"t": 0.96, "type": "heal", "playerId": "boss_tree_spirit", "amount": 665, "hp": 15665, "cause": "drain"}], "duration": 1.4})
	check(m._skill_view is BossBeam and m._skill_view.drains(), "a drain beam")
	eq(m._skill_view._fx.colors, BossBeam.DRAIN_PALETTE, "drawn green-gold")
	near(float(m._drain["until"]), 1.4, 1e-6, "the life flows until the beam ends")
	_run(m, 0.8)
	var streams: Array = _fx_of(m, LifeStreamFx)
	eq(streams.size(), 1, "the hit member's life flows to the boss")
	eq([streams[0].look, streams[0].target], [LifeStreamFx.DRAIN, m._views["boss_tree_spirit"]], "into the tree's heart")
	_run(m, 0.2)
	eq(m.boss_state()["hp"], 15665, "the heal on the HUD")
	check(m._views["boss_tree_spirit"].figure().heal_shown() > 0.5, "the boss glows")
	check(m._hud.boss_hud().rising(), "the bar fills back up")
	_run(m, 0.6)
	check(m._drain.is_empty(), "over with the replay")
	_free(m)


func test_regen_rises_from_the_mushrooms() -> void:
	var m := _screen("tree_spirit")
	m._players["boss_tree_spirit"]["hp"] = 15000
	m._boss.hp = 15000
	eq(m.aura_links().ids(AuraLinks.REGEN), ["minion_poison_mushroom_1", "minion_poison_mushroom_2"], "vine threads from each mushroom")
	m._on_event("ShotResolved", {"shooterId": "boss_tree_spirit", "actionMode": "turn_start", "projectiles": [], "duration": 0.6,
		"events": [{"t": 0.3, "type": "heal", "playerId": "boss_tree_spirit", "amount": 1290, "hp": 16290, "cause": "regen"}]})
	check(not m._turn_resolved, "a regen-only turn start leaves the turn open")
	var streams: Array = _fx_of(m, LifeStreamFx)
	eq(streams.size(), 1, "leaves rise from the mushrooms")
	eq([streams[0].look, streams[0].sources.size()], [LifeStreamFx.REGEN, 2], "from both")
	_run(m, 0.32)
	eq(m.boss_state()["hp"], 16290, "the boss healed")
	check(m.aura_links()._regen_pulse > 0.5, "the threads flare")
	_free(m)


# ── Poison ───────────────────────────────────────────────────────────────────

func test_poison_status_look_and_tick() -> void:
	BossFixture.take()
	eq(StatusLook.look_of("poison"), "poison", "poison has its own look")
	eq(StatusLook.looks_of([{"effectId": "poison", "durationTurn": 2}]).keys(), ["poison"], "drawn on the body")
	check(GameData.status_bad("poison") and not GameData.status_skips_turn("poison"), "bad, the turn is kept")
	var m := _screen("tree_spirit")
	m._on_event("ShotResolved", {"shooterId": "minion_poison_mushroom_1", "actionMode": "spore", "projectiles": [], "duration": 0.8,
		"events": [{"t": 0.2, "type": "spore", "playerId": "minion_poison_mushroom_1", "position": {"x": 1200, "y": 700}, "radius": 120},
			{"t": 0.2, "type": "damage", "playerId": "p2", "amount": 148, "hp": 852, "cause": "spore"},
			{"t": 0.2, "type": "status", "playerId": "p2", "effectId": "poison", "turns": 2}]})
	check(m._turn_resolved, "the mushroom's turn ends with its puff")
	_run(m, 0.25)
	eq(_fx_of(m, SporeFx).size(), 1, "a spore cloud")
	eq(_fx_of(m, SporeFx)[0].radius, 120.0, "out to its radius")
	check(m._views["minion_poison_mushroom_1"].figure().puffing(), "the mushroom puffs")
	check(m._views["p2"].status_looks().has("poison"), "p2 is poisoned: its look")
	_run(m, 0.7)
	m._apply("PlayerDamaged", [{"playerId": "p2", "damage": 40, "hp": 812, "shield": 0, "isAlive": true, "type": "poison"}])
	eq(m._players["p2"]["hp"], 812, "the tick's HP")
	var labels: Array = m._fx_layer.get_children().filter(func(n): return n is DamagePopup and n.text == "-40")
	eq(labels.size(), 1, "its number")
	eq(labels[0].get_theme_color("font_color"), DamagePopup.POISON, "green")
	var ticks: Array = _fx_of(m, SporeFx).filter(func(f): return f.mode == SporeFx.TICK)
	eq(ticks.size(), 1, "a puff of spores over the body")
	_free(m)


# ── The minion auras ─────────────────────────────────────────────────────────

func test_hud_model_aura_state() -> void:
	BossFixture.take()
	var b := BossHudModel.new()
	b.load_snapshot({"boss": _boss_block("rock_giant", {"armorMinions": ["t1", "t2"], "damageTakenFactor": 0.4}),
		"players": {"boss_rock_giant": {"role": "boss", "hp": 100, "maxHp": 100}}})
	check(b.armored() and b.state()["armored"], "the totems armour it")
	near(b.damage_taken_factor, 0.4, 1e-6, "40 % taken")
	check(b.minion_died("t1") and not b.minion_died("zz"), "a totem's death drops it")
	check(b.armored(), "one still stands")
	b.minion_died("t2")
	check(not b.armored(), "the last fell: no armour")
	check(b.minion_summoned("t3", GameData.boss_minion("rock_giant", "stone_totem")), "a new totem armours it again")
	check(not b.minion_summoned("x", {"bossDamageTakenFactor": 0}), "a minion without an aura does not")
	check(b.on_shield({"playerId": "boss_rock_giant", "shielded": false, "damageTakenFactor": 1, "armorMinions": [], "regenPct": 0,
		"regenMinions": []}), "BossShieldChanged with only the aura changed")
	check(not b.armored() and b.damage_taken_factor == 1.0, "the server's lists are the truth")
	check(not b.on_shield({"playerId": "boss_rock_giant", "shielded": false, "armorMinions": []}), "nothing changed")
	b.on_shield({"playerId": "boss_rock_giant", "shielded": false, "regenMinions": ["m1"], "regenPct": 3})
	eq(b.regen_minions, ["m1"], "the regen minions")
	b.kill("boss_rock_giant")
	eq([b.armor_minions, b.regen_minions], [[], []], "the boss's death ends the auras")


func test_armour_links_plates_and_the_armoured_number() -> void:
	var m := _screen()
	var boss = m._views["boss_rock_giant"]
	eq(m.aura_links().ids(AuraLinks.ARMOR), ["minion_stone_totem_1", "minion_stone_totem_2"], "a rune link from each totem")
	near(boss.figure().plates_shown(), 1.0, 1e-6, "the plates on from the snapshot")
	m._on_event("ShotResolved", {"shooterId": "me", "actionMode": "weapon", "projectiles": [], "duration": 1.0,
		"events": [{"t": 0.1, "type": "damage", "playerId": "boss_rock_giant", "amount": 120, "hp": 18880, "cause": "explosion"},
			{"t": 0.2, "type": "damage", "playerId": "boss_rock_giant", "amount": 110, "hp": 18770, "cause": "explosion"},
			{"t": 0.3, "type": "die", "playerId": "minion_stone_totem_1", "cause": "explosion"},
			{"t": 0.5, "type": "die", "playerId": "minion_stone_totem_2", "cause": "explosion"},
			{"t": 0.6, "type": "damage", "playerId": "boss_rock_giant", "amount": 300, "hp": 18470, "cause": "explosion"}]})
	_run(m, 0.25)
	var nums: Array = m._fx_layer.get_children().filter(func(n): return n is DamagePopup and n.text in ["-120", "-110"])
	eq(nums.size(), 2, "two hits on the armoured boss")
	check(nums[0]._style.get("armored", false) and nums[1]._style.get("armored", false), "both stone grey")
	eq([nums[0]._style["tag"], nums[1]._style["tag"]], [DamagePopup.ARMOR_TAG, ""], "'Giáp đá' over the first only")
	_run(m, 0.1)
	eq(m.aura_links().ids(AuraLinks.ARMOR), ["minion_stone_totem_2"], "the fallen totem's link is gone")
	eq(m.aura_links().breaking(), 1, "it snaps")
	check(m.boss_state()["armored"], "still armoured")
	_run(m, 0.2)
	check(not m.boss_state()["armored"], "the last totem fell: the armour is off")
	check(boss.figure().plates_breaking(), "the plates fly off")
	_run(m, 0.5)
	var after: Array = m._fx_layer.get_children().filter(func(n): return n is DamagePopup and n.text == "-300")
	check(not after[0]._style.get("armored", false), "an unarmoured hit: the usual number")
	m._on_event("ShotResolved", {"shooterId": "boss_rock_giant", "actionMode": "summon", "projectiles": [], "duration": 0.8,
		"events": [{"t": 0.6, "type": "summon", "playerId": "minion_stone_totem_3", "minionId": "stone_totem", "position": {"x": 1500, "y": 700},
			"hp": 1400, "maxHp": 1400, "displayName": "Trụ đá", "teamId": 2, "bodySize": 1, "behavior": "shooter", "movement": "none"}]})
	_run(m, 0.65)
	check(m.boss_state()["armored"], "a new totem: armoured again")
	eq(m.aura_links().ids(AuraLinks.ARMOR), ["minion_stone_totem_3"], "its link grows")
	check(boss.figure().armored, "the plates back on")
	_free(m)


func test_mushroom_death_blast_is_spores() -> void:
	var m := _screen("tree_spirit")
	m._on_event("ShotResolved", {"shooterId": "me", "actionMode": "weapon", "projectiles": [], "duration": 1.0, "events": [
		{"t": 0.2, "type": "damage", "playerId": "minion_poison_mushroom_1", "amount": 600, "hp": 0, "cause": "explosion"},
		{"t": 0.2, "type": "die", "playerId": "minion_poison_mushroom_1", "cause": "explosion"},
		{"t": 0.25, "type": "explode", "playerId": "minion_poison_mushroom_1", "position": {"x": 1200, "y": 700}, "radius": 10, "crater": 10,
			"blastRadius": 120, "terrainVersion": 1},
		{"t": 0.25, "type": "damage", "playerId": "p2", "amount": 50, "hp": 950, "cause": "death_blast"},
		{"t": 0.25, "type": "status", "playerId": "p2", "effectId": "poison", "turns": 2}]})
	_run(m, 0.3)
	var bursts: Array = _fx_of(m, SporeFx).filter(func(f): return f.mode == SporeFx.BURST)
	eq(bursts.size(), 1, "a burst of spores")
	eq(bursts[0].radius, 120.0, "as wide as the blast")
	eq(_fx_of(m, ExplosionFx).size(), 0, "no fire")
	eq(m.aura_links().ids(AuraLinks.REGEN), ["minion_poison_mushroom_2"], "its thread is gone")
	_free(m)


# ── Projectiles ──────────────────────────────────────────────────────────────

func test_new_projectile_kinds() -> void:
	for k in ["boulder", "giant_boulder", "pebble", "poison_thorn"]:
		check(UnitShell.is_kind(k), "%s has its own look" % k)
	var player := UnitShell.player_shell_px()
	var sizes := {"boulder": UnitShell.BOSS_SIZE, "giant_boulder": UnitShell.SIZE["giant_boulder"], "pebble": 1.0,
		"poison_thorn": UnitShell.SIZE["poison_thorn"]}
	for k in sizes:
		var v := UnitShell.new(k)
		v._ready()
		near(v.drawn_px(), player * float(sizes[k]), 0.01, "%s drawn %.1f × a player's shell" % [k, sizes[k]])
		v._process(0.02)
		v.free()
	check(UnitShell.SIZE["giant_boulder"] > 3.0, "the giant boulder is huge")
	var thorn := UnitShell.new("poison_thorn")
	thorn.set_tangent(Vector2(0, 1))
	near(thorn.draw_angle(), PI / 2.0, 1e-6, "a thorn points along its fall")
	thorn.free()
	BossFixture.take()
	var path := [{"time": 0.0, "position": {"x": 0.0, "y": 0.0}, "velocity": {"x": 0.0, "y": 100.0}},
		{"time": 1.0, "position": {"x": 0.0, "y": 100.0}, "velocity": {"x": 0.0, "y": 100.0}}]
	var one = BossRain.new().for_skill("giant_boulder")
	one.begin({"timeline": ShotTimeline.new({"actionMode": "skill", "skillId": "giant_boulder", "duration": 1.0, "events": [],
		"projectiles": [{"projectileId": "g", "kind": "giant_boulder", "path": path}]})})
	check(one.tracks_shells(), "the camera follows the single giant boulder")
	var many = BossRain.new().for_skill("boulder_rain")
	many.begin({"timeline": ShotTimeline.new({"actionMode": "skill", "skillId": "boulder_rain", "duration": 1.0, "events": [],
		"projectiles": [{"projectileId": "a", "kind": "boulder", "path": path}, {"projectileId": "b", "kind": "boulder", "path": path}]})})
	check(not many.tracks_shells(), "a rain of many: the ground they fall on")
