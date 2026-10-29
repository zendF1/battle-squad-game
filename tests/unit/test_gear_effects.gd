extends "res://tests/test_case.gd"
## The gear effects (server contract docs/contracts/gear-effects.md): GET /gamedata gear, a piece's
## passive / awaken, a gear profile's lines and set, the match's awaken buttons, the milestone
## unlocks, the bullet glow, the set aura, the walk's cost factor, the widgets (passive chip, set
## pips, awaken popup, the piece popup's gear row and milestones) and match_screen's handling of
## AwakenUsed / AwakenRefused / GearEffect and the new shot events.

const GameData := preload("res://autoload/game_data_model.gd")
const GearModel := preload("res://screens/home/gear_model.gd")
const GearUi := preload("res://screens/home/gear_ui.gd")
const GearGlyphs := preload("res://ui/gear_glyphs.gd")
const GearIcon := preload("res://ui/gear_icon.gd")
const GearFx := preload("res://match/views/gear_fx.gd")
const SetAura := preload("res://scenes/character/set_aura.gd")
const ShotLook := preload("res://match/views/shot_look.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const EquipmentUi := preload("res://screens/home/equipment_ui.gd")
const LeaderboardModel := preload("res://screens/home/leaderboard_model.gd")
const ShowcaseModel := preload("res://screens/home/showcase_model.gd")
const MoveSync := preload("res://match/move/move_sync.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const UseBadge := preload("res://match/views/use_badge.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const SkyView := preload("res://match/views/sky_view.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const Hud := preload("res://match/hud.gd")
const MatchScreen := preload("res://match/match_screen.gd")
const CharacterPage := preload("res://screens/home/character_page.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")

const PROFILE := {"critDamage": 60.4, "critTaken": 37.75, "procChance": 30, "procEffect": "burn", "resist": 0, "moveCost": 26.43,
	"skillRankBonus": 1, "set": {"index": 4, "pieces": 6, "crafted": 2, "reached": [2, 4, 6]}, "setAura": 4,
	"awaken": ["weapon", "armor", "helmet", "pants", "boots", "gloves"]}


# ── Game data ───────────────────────────────────────────────────────────────

func test_gamedata_gear() -> void:
	eq(GameData.gear_slots().size(), 6, "six slots")
	eq(GameData.gear_passive_kind("weapon"), "crit_damage", "weapon passive")
	eq(GameData.gear_passive_kind("pants"), "proc_chance", "pants share the gloves' kind")
	eq(GameData.gear_awaken_kind("armor"), "revive", "armor awaken")
	check(GameData.gear_awaken_button("boots") and GameData.gear_awaken_button("weapon") and GameData.gear_awaken_button("gloves"),
		"weapon / gloves / boots are buttons")
	check(not GameData.gear_awaken_button("armor") and not GameData.gear_awaken_button("helmet"), "armor / helmet are automatic")
	eq(GameData.gear_slot_of_awaken("double_energy"), "boots", "slot of an awaken")
	eq([GameData.gear_glow_level(), GameData.gear_skill_rank_level(), GameData.gear_awaken_level()], [10, 14, 16], "milestones")
	eq(GameData.gear_set_thresholds(), [2, 4, 6], "set thresholds")
	eq(GameData.gear_set_size(), 6, "pips")
	eq(GameData.gear_set_effect(4), "fire", "6-piece effect of index 4")
	eq(GameData.gear_set_effect(9), "", "unknown index")
	eq(GameData.gear_value("reviveHpPct"), 20.0, "revive %")
	eq(GameData.gear_set_effect_value(2), 5.0, "lifesteal %")


func test_gamedata_without_gear() -> void:
	GameData.reset("")
	GameData.take({"version": "old"}, "", false)
	eq(GameData.gear_slots(), [], "an older server: no slots")
	eq(GameData.gear_awaken_kind("armor"), "", "no awaken")
	eq(GameData.gear_glow_level(), 0, "no glow level")
	eq(ShotLook.bullet_aura(16), null, "no glow without the game data's level")
	eq(GearModel.milestone_unlocks(16, "weapon"), [], "no unlocks")


# ── Pieces and profiles ─────────────────────────────────────────────────────

func test_piece_passive() -> void:
	var piece := {"slot": "weapon", "upgradeLevel": 16, "tierIndex": 4, "passive": {"kind": "crit_damage", "value": 48.32}, "hasAwaken": true}
	var p := GearModel.piece_passive(piece)
	eq(p["kind"], "crit_damage", "kind")
	near(p["value"], 48.32, 1e-6, "the server's value, not recomputed")
	eq(p["glyph"], "crit_damage", "its picture")
	check(GearModel.has_awaken(piece), "+16 has its awaken")
	eq(GearModel.tier_index(piece), 4, "tier index")
	var pants := GearModel.piece_passive({"slot": "pants"}, {"slot": "pants", "passive": {"kind": "proc_chance", "value": 4}})
	eq(pants["glyph"], "proc_chance_pants", "the pants' own picture, from the catalog item at +0")
	eq(GearModel.piece_passive({"slot": "armor"}), {}, "none (an older server)")
	check(not GearModel.has_awaken({"upgradeLevel": 16}), "no hasAwaken: no awaken")


func test_value_text() -> void:
	eq(GearModel.value_text("crit_damage", 48.32), "+48.3%", "raised")
	eq(GearModel.value_text("crit_taken", 30.0), "−30%", "lowered: crit taken")
	eq(GearModel.value_text("move_cost", 21.14), "−21.1%", "lowered: walk cost")
	eq(GearModel.value_text("resist", 0.0), "", "zero: nothing")


func test_profile_lines_and_set() -> void:
	var lines := GearModel.profile_lines(PROFILE)
	eq(lines.map(func(l): return l["kind"]), ["crit_damage", "crit_taken", "proc_chance", "move_cost"], "order, zeros left out")
	eq(lines[2]["glyph"], "proc_chance", "the gloves' picture for the shared kind")
	var s := GearModel.set_state(PROFILE)
	eq([s["index"], s["pieces"], s["size"]], [4, 6, 6], "set")
	eq(s["glyph"], "set_fire", "6-piece picture")
	check(s["complete"], "6 reached: complete")
	var half := GearModel.set_state({"set": {"index": 1, "pieces": 3, "reached": [2]}})
	check(not half["complete"], "3 pieces: not complete")
	eq(half["effect"], "shield", "index 1 effect")
	eq(GearModel.set_state({}), {}, "no set")
	eq(GearModel.set_aura(PROFILE), 4, "aura")
	eq(GearModel.set_aura({}), 0, "none")
	eq(GearModel.awaken_slots(PROFILE).size(), 6, "awaken slots")
	eq(GearModel.profile_of({"gear": PROFILE}), PROFILE, "profile of a holder")
	eq(GearModel.profile_of(null), {}, "none")


func test_awaken_buttons() -> void:
	var gear := {"awaken": ["weapon", "armor", "boots", "gloves"], "awakenUsed": ["gloves"], "armed": []}
	var mine := {"can_act": true, "can_shoot": true, "rooted": false}
	var b := GearModel.awaken_buttons(gear, mine)
	eq(b.map(func(a): return a["slot"]), ["weapon", "boots", "gloves"], "buttons only, the server's order")
	eq(b.map(func(a): return a["used"]), [false, false, true], "gloves used")
	eq(b.map(func(a): return a["enabled"]), [true, true, false], "used: off")
	var shot := GearModel.awaken_buttons(gear, {"can_act": true, "can_shoot": false, "rooted": false})
	eq(shot.map(func(a): return a["enabled"]), [false, true, false], "after the shot armed: the boots still")
	var rooted := GearModel.awaken_buttons(gear, {"can_act": true, "can_shoot": true, "rooted": true})
	eq(rooted.map(func(a): return a["enabled"]), [true, false, false], "rooted: no boots")
	var other := GearModel.awaken_buttons(gear, {"can_act": false, "can_shoot": false})
	check(other.all(func(a): return not a["enabled"]), "not my turn: all off")
	var armed := GearModel.mark_armed(gear, "weapon")
	check(GearModel.armed(armed, "weapon") and not GearModel.armed(gear, "weapon"), "armed on a copy")
	eq(GearModel.awaken_buttons(armed, mine)[0]["used"], true, "armed counts as used")
	check(not GearModel.armed(GearModel.clear_armed(armed), "weapon"), "cleared")
	eq(GearModel.mark_used({}, "boots")["awakenUsed"], ["boots"], "marked used")
	eq(GearModel.awaken_buttons({}, mine), [], "no gear: no buttons")


func test_milestone_unlocks() -> void:
	eq(GearModel.milestone_unlocks(10, "weapon"), ["bullet_glow"], "+10 weapon: the bullet glow")
	eq(GearModel.milestone_unlocks(14, "weapon"), ["rank_up"], "+14 weapon: the skill rank up")
	eq(GearModel.milestone_unlocks(16, "weapon"), ["no_wind"], "+16 weapon: its awaken")
	eq(GearModel.milestone_unlocks(16, "armor"), ["revive"], "+16 armor: its awaken")
	eq(GearModel.milestone_unlocks(10, "armor"), [], "+10 armor: nothing more")
	eq(GearModel.milestone_unlocks(6, "weapon"), [], "+6: nothing more")


func test_turn_wind() -> void:
	var wind := {"direction": -1, "power": 3.4}
	eq(GearModel.turn_wind(wind, {"armed": []}), {"direction": -1, "power": 3.4}, "the turn's wind")
	eq(GearModel.turn_wind(wind, {"armed": ["gloves"]}), {"direction": -1, "power": 3.4}, "the gloves keep it")
	eq(GearModel.turn_wind(wind, {"armed": ["weapon"]}), {"direction": -1, "power": 0.0}, "the weapon awaken armed: none")
	eq(GearModel.turn_wind(wind, {}, true), {"direction": -1, "power": 0.0}, "sent / replaying: none")
	eq(GearModel.turn_wind({}, {}), {"direction": 0, "power": 0.0}, "no wind data")


func test_move_cost_factor() -> void:
	near(GearModel.move_cost_factor({"moveCost": 26.43}), 0.7357, 1e-6, "1 − moveCost / 100")
	eq(GearModel.move_cost_factor({}), 1.0, "none")


# ── Pictures ────────────────────────────────────────────────────────────────

func test_glyph_kinds() -> void:
	for e in GameData.gear_slots():
		check(GearGlyphs.has(GearGlyphs.passive_kind(str(e["passive"]), str(e["slot"]))), "passive picture of %s" % e["slot"])
		check(GearGlyphs.has(str(e["awaken"])), "awaken picture of %s" % e["slot"])
	for i in range(1, 5):
		check(GearGlyphs.has("set_" + GameData.gear_set_effect(i)), "set picture %d" % i)
	check(GearGlyphs.has("bullet_glow") and GearGlyphs.has("rank_up"), "milestone pictures")
	check(GearGlyphs.set_color(4) != GearGlyphs.set_color(1), "set colours differ")
	for k in ["resist", "revive", "crit_immune", "proc", "set_shield", "set_heal", "set_cleanse", "set_fire", "no_wind", "double_energy"]:
		check(not GearFx.look_of(k).is_empty(), "fx look of %s" % k)
	eq(GearFx.look_of("nope"), {}, "unknown fx")


func test_bullet_aura() -> void:
	eq(ShotLook.bullet_aura(0), null, "+0: none")
	eq(ShotLook.bullet_aura(9), null, "+9: none")
	eq(ShotLook.bullet_aura(10), UpgradeModel.milestone_color(10), "+10: orange")
	eq(ShotLook.bullet_aura(14), UpgradeModel.milestone_color(14), "+14: purple")
	eq(ShotLook.bullet_aura(16), UpgradeModel.milestone_color(16), "+16: red")
	var st := ShotLook.style_for({"characterId": "rookie", "weaponItemId": "rookie_weapon_lv40", "weaponUpgradeLevel": 14}, "weapon", "")
	eq(st.get("aura"), UpgradeModel.milestone_color(14), "every shot of the player's weapon")
	check(not ShotLook.style_for({"characterId": "rookie", "weaponUpgradeLevel": 3}, "weapon", "").has("aura"), "below +10: no aura")
	check(not ShotLook.style_for({"characterId": "rookie", "weaponUpgradeLevel": 16}, "item", "air_strike").has("aura"), "an air strike: not the gun's")


func test_set_aura_node() -> void:
	var a := SetAura.new()
	check(not a.visible, "hidden by default")
	a.index = 3
	check(a.visible and a.is_processing(), "shown with an index")
	eq(a.color(), GearGlyphs.set_color(3), "its colour")
	a.index = 0
	check(not a.visible, "0 hides it")
	a.free()


func test_showcase_look_set_aura() -> void:
	var lk := LeaderboardModel.look_of("rookie", {"characterId": "rookie", "setAura": 4})
	eq(lk["set_aura"], 4, "look setAura")
	eq(LeaderboardModel.look_of("rookie", {"characterId": "rookie"})["set_aura"], 0, "leaderboard rows: none")
	var c := ShowcaseModel.character({"characterId": "rookie", "look": {"characterId": "rookie"}, "gear": {"setAura": 2}})
	eq(c["gear"]["setAura"], 2, "gear kept")
	eq(ShowcaseModel.look(c)["set_aura"], 2, "the gear profile's aura when the look has none")


# ── Walk ────────────────────────────────────────────────────────────────────

func test_move_sync_cost_factor() -> void:
	var m := TerrainMask.new()
	m.width = 2000
	m.height = 400
	m.solid = PackedByteArray()
	m.solid.resize(m.width * m.height)
	for y in range(300, 400):
		for x in m.width:
			m.solid[y * m.width + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	var s := MoveSync.new()
	s.terrain = m
	var base: Array = s.simulate(Vector2(500, 300), 10, 2000.0)
	s.cost_factor = 0.5
	var far: Array = s.simulate(Vector2(500, 300), 10, 2000.0)
	near(far[0].x - 500.0, (base[0].x - 500.0) * 2.0, 1.5, "half the cost: twice as far on the same energy")
	var short: Array = s.simulate(Vector2(500, 300), 100, 500.0 + 40.0)
	eq(short[1], 100 - roundi(40.0 * GameData.energy_per_px() * 0.5), "half the energy per px")
	s.reset(Vector2(500, 300), 10)
	s.set_server_energy(40)
	eq(s.energy, 40, "the boots' awaken: the server's new energy")


# ── Widgets ─────────────────────────────────────────────────────────────────

static func _labels(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Label:
			out.append(c.text)
		out.append_array(_labels(c))
	return out


static func _find(n: Node, cls) -> Array:
	var out: Array = []
	for c in n.get_children():
		if is_instance_of(c, cls):
			out.append(c)
		out.append_array(_find(c, cls))
	return out


func test_passive_chip_and_set_row() -> void:
	var chip := GearUi.passive_chip({"kind": "crit_damage", "value": 48.32, "glyph": "crit_damage"})
	eq(_labels(chip), ["+48.3%"], "its value only, no name")
	eq(_find(chip, GearIcon)[0].kind, "crit_damage", "its picture")
	chip.free()
	var row := GearUi.set_row(GearModel.set_state({"set": {"index": 2, "pieces": 4, "reached": [2, 4]}}))
	var pips: Control = row.get_node("SetPips")
	eq(pips.get_meta("filled"), 4, "four pips filled")
	check(row.get_node("SetEffect").dim, "6-piece picture dim until reached")
	row.free()
	var full := GearUi.set_row(GearModel.set_state(PROFILE))
	check(not full.get_node("SetEffect").dim, "reached: bright")
	full.free()
	var none := GearUi.set_row({})
	eq(none.get_child_count(), 0, "no set: empty")
	none.free()


func test_stat_chip_and_grid() -> void:
	var chip := GearUi.stat_chip("heart", "+1.232", "Máu +616 điểm (+1.232)", 26, 18)
	eq(_labels(chip), ["+1.232"], "the value only")
	eq(chip.tooltip_text, "Máu +616 điểm (+1.232)", "the words in the tooltip")
	var chips: Array = [chip]
	for i in 4:
		chips.append(GearUi.passive_chip({"kind": "crit_damage", "value": 60.4, "glyph": "crit_damage"}, 26, 18))
	var grid := GearUi.chip_grid(chips, 300, 3)
	eq(grid.columns, 3, "3 columns")
	for c in grid.get_children():
		eq((c as Control).custom_minimum_size.x, 100.0, "equal cells")
	grid.free()


## The Nhân vật page's block under the hexagons (a full +16 set, every passive, every stat): the set
## row, the passives grid, then the stats grid, below the hexagons, inside the column and above
## the screen's bottom at the smallest height (no overlap at 16:9).
func test_character_page_gear_block() -> void:
	var page: Control = CharacterPage.new()
	page._build_slots()
	var gear := {"critDamage": 60.4, "critTaken": 12.5, "procChance": 12.5, "resist": 16.9, "moveCost": 8.8,
		"set": {"index": 4, "pieces": 6, "crafted": 0, "reached": [2, 4, 6]}}
	var stats := EquipmentModel.bonus_chips({"fromEquipment": {"maxHp": 1232, "defense": 58, "damageBonus": 635, "moveEnergy": 20, "critChance": 17.1},
		"equipmentPoints": {"hp": 616, "damage": 127, "defense": 58, "mobility": 20, "crit": 17.1}})
	page._render_gear_block(gear, stats)
	var box: VBoxContainer = page._gear_box
	var kids := box.get_children().filter(func(n): return not n.is_queued_for_deletion())
	eq(kids.map(func(n): return str(n.name)), ["SetRow", "Passives", "Stats"], "set, passives, stats")
	eq(kids[1].get_child_count(), 5, "five passives")
	eq(kids[2].get_child_count(), 5, "five stats")
	var hexes_bottom := -INF
	for b in page._slot_buttons.values():
		hexes_bottom = maxf(hexes_bottom, b.get_parent().offset_top + b.position.y + b.size.y)
	check(box.offset_top >= hexes_bottom, "below the hexagons")
	check(box.offset_bottom <= 450.0, "inside the 900-high screen")
	var need := box.get_combined_minimum_size()
	check(need.y <= box.offset_bottom - box.offset_top, "its rows fit (%s)" % need.y)
	check(need.x <= CharacterPage.SLOTS_W, "inside the column (%s)" % need.x)
	page._render_gear_block({}, [])
	eq(box.get_children().filter(func(n): return not n.is_queued_for_deletion()).size(), 0, "nothing worn: empty")
	page.free()


func test_awaken_popup_text() -> void:
	eq(GearUi.awaken_text("revive"), "Lần đầu hết máu: sống lại với 20% máu", "the game data's number")
	eq(GearUi.awaken_text("double_energy"), "Bấm trong lượt: thể lực lượt này ×2", "boots factor")
	eq(GearUi.awaken_text("unknown"), "", "unknown kind")
	var host := Control.new()
	var m := GearUi.open_awaken(host, "armor")
	eq(_find(m, GearIcon)[0].kind, "revive", "the awaken's picture, big")
	host.free()


func test_milestone_list_unlocks() -> void:
	var col := EquipmentUi.milestone_list(null, 16, true, "weapon")
	for k in ["bullet_glow", "rank_up", "no_wind"]:
		check(col.find_child("Unlock_" + k, true, false) != null, "weapon row shows %s" % k)
	col.free()
	var armor := EquipmentUi.milestone_list(null, 3, false, "armor")
	check(armor.find_child("Unlock_revive", true, false) != null, "armor +16 row: its awaken")
	check(armor.find_child("Unlock_bullet_glow", true, false) == null, "no bullet glow on armour")
	armor.free()


# ── HUD and badge ───────────────────────────────────────────────────────────

func test_hud_awakens() -> void:
	var h: Control = Hud.new()
	h._ready()
	h._portrait_art._ready()
	h._portrait_art.character()._ready()
	eq(h.awakens(), {}, "none at the start")
	h.set_awakens([{"slot": "weapon", "used": false, "enabled": true}, {"slot": "boots", "used": true, "enabled": false}])
	eq(h.awakens(), {"weapon": {"used": false, "enabled": true}, "boots": {"used": true, "enabled": false}}, "two buttons")
	var got := []
	h.awaken_pressed.connect(func(s): got.append(s))
	var b: Button = h.find_child("Awaken_weapon", true, false)
	b.pressed.emit()
	eq(got, ["weapon"], "the press names the slot")
	check((h.find_child("Awaken_boots", true, false) as Button).disabled, "used: off")
	h.set_awakens([])
	eq(h.awakens(), {}, "[] hides the row")
	h.set_energy_glow(true)
	check(h.energy_glow(), "energy glow on")
	h.set_wind(1, 3.2)
	eq(h.wind_shown(), 3.2, "the wind")
	h.set_wind(1, 0.0)
	eq(h.wind_shown(), 0.0, "no wind")
	eq(h._wind.text, "0", "reads 0")
	check(not h._wind_arrow.visible, "no arrow")
	h.free()


func test_use_badge_awaken() -> void:
	var c := UseBadge.content_awaken("boots")
	eq(c["kind"], UseBadge.KIND_AWAKEN, "awaken badge")
	eq(c["id"], "boots", "its slot")
	eq(UseBadge.content_awaken(""), {}, "none")


# ── match_screen ────────────────────────────────────────────────────────────

func _player(id: String, team: int, character: String, x: float, gear: Dictionary) -> Dictionary:
	return {"playerId": id, "displayName": id, "teamId": team, "characterId": character, "hp": 1000, "maxHp": 1000,
		"isAlive": true, "position": {"x": x, "y": 500.0}, "skillEnergy": 0, "items": [], "statusEffects": [],
		"moveEnergy": 100, "maxMoveEnergy": 100, "gear": gear}


func _screen() -> Node2D:
	var m: Node2D = MatchScreen.new()
	m._me = "me"
	m._current = "me"
	m._wind = {"direction": 1, "power": 2.5}
	m._players = {"me": _player("me", 1, "rookie", 100.0, {"awaken": ["weapon", "boots", "gloves"], "awakenUsed": [], "armed": [], "setAura": 4, "moveCost": 20}),
		"e1": _player("e1", 2, "tanko", 600.0, {"resist": 20, "setAura": 0})}
	m._players_layer = Node2D.new()
	m._fx_layer = Node2D.new()
	m._sky = SkyView.new()
	for id in m._players:
		var v: Node2D = PlayerView.new()
		m._players_layer.add_child(v)
		v.setup(m._players[id], id == "me", 1)
		v.get_child(1)._ready()
		v.set_set_aura(GearModel.set_aura(m._players[id]["gear"]))
		m._views[id] = v
	m._hud = Hud.new()
	m._hud._ready()
	m._aim = AimInput.new()
	m._shot_player = ShotPlayer.new()
	m._shot_player.layer = m._fx_layer
	m._shot_player.event_due.connect(m._on_shot_event)
	m._shot_player.fired.connect(m._on_shot_fired)
	m._shot_player.finished.connect(m._on_shot_finished)
	m.send_hook = func(e: String, d: Dictionary) -> void: m.set_meta("sent", m.get_meta("sent", []) + [[e, d]])
	return m


func _free(m: Node2D) -> void:
	m._shot_player.stop()
	for n in [m._hud, m._aim, m._shot_player, m._players_layer, m._fx_layer, m._sky]:
		n.free()
	m.free()


func _fx(m: Node2D) -> Array:
	return m._fx_layer.get_children().filter(func(n): return n is GearFx).map(func(n): return n.kind)


func test_match_set_aura_and_buttons() -> void:
	var m := _screen()
	eq(m._views["me"].set_aura_index(), 4, "my 6-piece aura")
	eq(m._views["e1"].set_aura_index(), 0, "none")
	near(m._move_cost_factor(), 0.8, 1e-6, "my boots' passive on the walk")
	m._refresh_controls()
	eq(m._hud.awakens().keys(), ["weapon", "boots", "gloves"], "my awaken buttons")
	check(m._hud.awakens()["weapon"]["enabled"], "my turn: on")
	m._on_awaken_pressed("weapon")
	eq(m.get_meta("sent", []), [["Awaken", {"slot": "weapon"}]], "Awaken {slot} sent")
	check(not m._hud.awakens()["weapon"]["enabled"], "off until answered")
	eq(m._aim.wind_power, 0.0, "the aim preview ignores the wind once sent")
	eq(m._hud.wind_shown(), 0.0, "the readout shows no wind once sent")
	m._on_awaken_pressed("weapon")
	eq(m.get_meta("sent", []).size(), 1, "not twice")
	m._apply("AwakenRefused", {"slot": "weapon", "code": "AWAKEN_BLOCKED"})
	check(m._hud.awakens()["weapon"]["enabled"], "refused: the button is back")
	near(m._hud.wind_shown(), 2.5, 1e-6, "refused: the wind is back")
	near(m._aim.wind_power, 2.5, 1e-6, "and in the aim preview")
	_free(m)


func test_match_awaken_used() -> void:
	var m := _screen()
	m._moves.reset(Vector2(100, 500), 100)
	m._apply("AwakenUsed", {"playerId": "me", "slot": "boots", "moveEnergy": 200})
	check(m._players["me"]["gear"]["awakenUsed"].has("boots"), "marked used")
	eq(m._views["me"].badge().get("kind", ""), UseBadge.KIND_AWAKEN, "its badge over me")
	check(m._hud.energy_glow(), "my energy bar glows")
	eq(m._moves.energy, 200, "the server's new energy")
	check(m._hud.awakens()["boots"]["used"], "the button greyed")
	m._apply("AwakenUsed", {"playerId": "e1", "slot": "gloves"})
	eq(m._views["e1"].badge().get("id", ""), "gloves", "everyone sees the other's awaken")
	check(GearModel.armed(m._players["e1"]["gear"], "gloves"), "armed for its shot")
	m._apply("TurnStarted", {"currentPlayerId": "e1", "turnIndex": 2, "moveEnergy": 100})
	check(not m._hud.energy_glow(), "the glow ends with the turn")
	check(not GearModel.armed(m._players["e1"]["gear"], "gloves"), "armed cleared at the turn change")
	_free(m)


func test_match_gear_events() -> void:
	var m := _screen()
	m._on_shot_event({"t": 0, "type": "resist", "playerId": "e1", "effectId": "burn"})
	m._on_shot_event({"t": 0, "type": "crit_immune", "playerId": "e1"})
	m._on_shot_event({"t": 0, "type": "status", "playerId": "e1", "effectId": "burn", "turns": 1, "cause": "proc"})
	m._on_shot_event({"t": 0, "type": "heal", "playerId": "me", "amount": 5, "hp": 1000, "cause": "set_heal"})
	m._on_shot_event({"t": 0, "type": "damage", "playerId": "me", "amount": 1000, "hp": 0})
	m._on_shot_event({"t": 0, "type": "awaken", "playerId": "me", "slot": "armor"})
	m._on_shot_event({"t": 0, "type": "revive", "playerId": "me", "hp": 200})
	eq(_fx(m), ["resist", "crit_immune", "proc", "set_heal", "revive"], "each event's picture")
	eq(m._views["me"].hp, 200, "revived with the server's hp")
	check(m._players["me"]["isAlive"], "alive")
	eq(m._views["me"].badge().get("id", ""), "armor", "the armor's awaken badge")
	m._apply("GearEffect", {"events": [{"t": 0, "type": "cleanse", "playerId": "e1", "effectIds": ["burn"], "cause": "set_cleanse"}]})
	check(_fx(m).has("set_cleanse"), "the 3-set cleanse outside a shot")
	eq(m._players["e1"]["statusEffects"].filter(func(s): return str(s.get("effectId", s)) == "burn").size(), 0, "the effect cleared")
	_free(m)


func test_match_wind_ignored_shot() -> void:
	var m := _screen()
	m._apply("AwakenUsed", {"playerId": "me", "slot": "weapon"})
	eq(m._hud.wind_shown(), 0.0, "armed: the readout shows 0")
	eq(m._sky.wind_power, 0.0, "and the sky is calm")
	m._refresh_controls()
	eq(m._aim.wind_power, 0.0, "and the aim preview has no wind")
	m._apply("ShotResolved", {"shooterId": "me", "actionMode": "weapon", "duration": 0.5, "awakened": ["weapon"],
		"projectiles": [{"projectileId": "p1", "path": [
			{"time": 0.0, "position": {"x": 100.0, "y": 480.0}, "velocity": {"x": 500.0, "y": -300.0}},
			{"time": 0.5, "position": {"x": 350.0, "y": 480.0}, "velocity": {"x": 500.0, "y": 300.0}}]}], "events": []})
	eq(m._hud.wind_shown(), 0.0, "0 for the shot's replay")
	m._on_shot_finished()
	near(m._hud.wind_shown(), 2.5, 1e-6, "back after the replay")
	_free(m)


## Watching another player's turn: their weapon awaken brings the wind to 0 for me too, until the
## turn passes.
func test_match_wind_other_awaken() -> void:
	var m := _screen()
	m._players["e1"]["gear"] = {"awaken": ["weapon"], "awakenUsed": [], "armed": []}
	m._apply("TurnStarted", {"currentPlayerId": "e1", "turnIndex": 2, "moveEnergy": 100, "wind": {"direction": 1, "power": 4.0}})
	near(m._hud.wind_shown(), 4.0, 1e-6, "their turn's wind")
	m._apply("AwakenUsed", {"playerId": "e1", "slot": "weapon"})
	eq(m._hud.wind_shown(), 0.0, "their weapon awaken: 0 for everyone")
	eq(m._hud._wind.text, "0", "reads 0")
	m._apply("AwakenUsed", {"playerId": "e1", "slot": "gloves"})
	eq(m._hud.wind_shown(), 0.0, "still 0")
	m._apply("TurnStarted", {"currentPlayerId": "me", "turnIndex": 3, "moveEnergy": 100, "wind": {"direction": -1, "power": 1.5}})
	near(m._hud.wind_shown(), 1.5, 1e-6, "the next turn's wind")
	_free(m)
